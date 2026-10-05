#!/usr/bin/env node
// gen-modbus-dp.js - генерация CTL-скрипта точки данных WinCC OA из карты.
//
// Зачем он нужен. Раньше скрипт точки писался руками, и на каждой новой карте
// повторялись одни и те же ошибки ввода: объявить FLOAT там, где count=1;
// забыть _distrib; не поставить _poll_group. Генератор убирает сам этот класс
// ошибок: адреса, _datatype и _direction берутся из карты по правилу,
// которое одновременно использует сервер (tools/modbus-sim/regtype.js).
//
// Использование:
//   node tools/gen-modbus-dp.js <map.json> --out <file.ctl> [ключи]
//
// Ключи:
//   --out <file>     куда писать CTL (обязательно)
//   --dp <префикс>   имя точки; по умолчанию префикс берётся из имени устройства
//   --dpt <префикс>  имя типа; по умолчанию <dp>_t
//   --drv <N>        номер драйвера Modbus (по умолчанию 2)
//   --keep           не удалять существующие точку и тип перед созданием
//   --no-verify      не добавлять блок проверки данных
//
// Скрипт сам находит группу опроса в проекте, ничего не спрашивая.

'use strict';

const fs = require('fs');
const path = require('path');
const regtype = require('./modbus-sim/regtype.js');
const { freePrologue, helperCtl } = require('./node-busy.js');
// Проверка занятости узлов. Правило живёт в отдельном модуле, потому что
// нужно и генератору Modbus, и генератору OPC UA, а две копии через месяц
// обязательно разойдутся.

const args = process.argv.slice(2);
const file = args.find((a) => !a.startsWith('--'));
function opt(name, def) {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
}
const flag = (name) => args.includes(`--${name}`);

if (!file) {
  console.error('Укажите карту: node tools/gen-modbus-dp.js <map.json> --out <file.ctl>');
  process.exit(2);
}
const outFile = opt('out', null);
if (!outFile) {
  console.error('Обязателен ключ --out <file.ctl>');
  process.exit(2);
}

const driver = Number(opt('drv', '2'));
const keep = flag('keep');
const verify = !flag('no-verify');

// ------------------------------------------------------------------ карта

let map;
try {
  const raw = fs.readFileSync(file, 'utf8').replace(/^\s*\/\/.*$/gm, '');
  map = JSON.parse(raw);
} catch (e) {
  console.error(`Не удалось прочитать карту ${file}: ${e.message}`);
  process.exit(2);
}

if (!Array.isArray(map.devices) || map.devices.length === 0) {
  console.error('В карте нет устройств.');
  process.exit(1);
}

// ------------------------------------------------------- сбор элементов

// Имена элементов уникальны внутри точки, а имена вида в разных пространствах
// регулярно совпадают ("Humidity" есть и во входах, и в holding), поэтому
// первое вхождение остаётся чистым, а последующие получают суффикс.
const SPACES = ['input', 'coils', 'ireg', 'holding'];
const SPACE_TITLE = {
  input: 'дискретные входы FC 2',
  coils: 'coils FC 1',
  ireg: 'входные регистры FC 4',
  holding: 'holding регистры FC 3',
};

function baseName(dev) {
  const n = dev.name || `slave${dev.id}`;
  return regtype.safeName(n, `slave${dev.id}`).toLowerCase();
}

function buildElements(dev) {
  const used = new Set();
  const out = [];
  const skipped = [];

  for (const space of SPACES) {
    const list = dev[space];
    if (!Array.isArray(list)) continue;

    for (const reg of list) {
      const c = regtype.classify(reg, space);
      if (!c) {
        skipped.push(`${space} ${reg.name}: неподдерживаемый count=${reg.count}`);
        continue;
      }
      const fallback = `Reg_${reg.addr}`;
      const base = regtype.safeName(reg.name, fallback);
      const name = regtype.uniqueName(used, base);
      const addr = `M.${dev.id}.${regtype.SPACE_FC[space]}.${reg.addr}`;
      out.push({
        name, space, addr, fc: regtype.SPACE_FC[space],
        datatype: c.datatype, dpeType: c.dpeType,
        direction: c.direction, label: c.label,
        words: c.words, mapName: reg.name,
      });
    }
  }
  return { out, skipped };
}

// ------------------------------------------------------------ генерация CTL

const dpPrefix = opt('dp', null);
const blocks = [];
const warnings = [];

for (const dev of map.devices) {
  const prefix = dpPrefix || baseName(dev);
  const dpName = prefix;
  const dptName = opt('dpt', `${prefix}_t`);
  const { out: els, skipped } = buildElements(dev);
  skipped.forEach((s) => warnings.push(`slave ${dev.id}: пропущено - ${s}`));

  const L = [];
  L.push(`  // ---- slave ${dev.id} «${dev.name}» : ${els.length} элементов ----`);
  L.push(`  killDP("${dpName}", "${dptName}");`);
  if (keep) {
    L.push(`  DebugN("  --keep: существующая точка не удаляется");`);
  }

  L.push('');
  L.push(`  dyn_dyn_string names;`);
  L.push(`  dyn_dyn_int    types;`);
  L.push(`  names[1] = makeDynString("${dptName}");`);
  L.push(`  types[1] = makeDynInt(DPEL_STRUCT);`);
  els.forEach((e, i) => {
    L.push(`  names[${i + 2}] = makeDynString("", "${e.name}");`);
    L.push(`  types[${i + 2}] = makeDynInt(0, ${e.dpeType});`);
  });
  L.push(`  int rcT = dpTypeCreate(names, types);`);
  L.push(`  chk(rcT == 0, "${dptName}: тип создан, элементов ${els.length}", "rc=" + rcT);`);
  L.push('');
  L.push(`  int rcC = dpCreate("${dpName}", "${dptName}");`);
  L.push(`  chk(rcC == 0, "${dpName}: точка создана", "rc=" + rcC);`);
  L.push('');
  L.push(`  DebugN("  -- адреса --");`);
  els.forEach((e) => {
    L.push(`  cfg("${dpName}", "${e.name}", "${e.addr}", ${e.datatype}, ${e.direction}, grp);`);
  });
  L.push('');
  L.push(`  elemCount += ${els.length};`);

  blocks.push({ dev, dpName, dptName, els, body: L.join('\n') });
}

// --------------------------------------------------------------- файлы

const header = [];
header.push('// СГЕНЕРИРОВАНО АВТОМАТИЧЕСКИ: tools/gen-modbus-dp.js');
header.push(`// Карта   : ${file}`);
header.push(`// Порядок слов: ${map.wordOrder || 'не задан'}`);
header.push(`// Драйвер : ${driver}`);
if (keep) header.push('// Режим   : --keep, существующие точки не удаляются');
header.push('//');
header.push('// Не правьте этот файл руками: он перезаписывается при следующей');
header.push('// генерации. Правьте карту и запускайте генератор заново.');
header.push('//');
header.push('// Карта элементов:');

for (const b of blocks) {
  header.push(`//`);
  header.push(`//   точка ${b.dpName}, тип ${b.dptName}, slave ${b.dev.id}`);
  for (const space of SPACES) {
    const list = b.els.filter((e) => e.space === space);
    if (!list.length) continue;
    header.push(`//     ${SPACE_TITLE[space]}:`);
    for (const e of list) {
      const nm = e.mapName === e.name ? e.name : `${e.name}  (в карте: ${e.mapName})`;
      header.push(`//       ${e.addr.padEnd(12)} ${String(e.datatype).padEnd(4)} ${e.label.padEnd(8)} ${nm}`);
    }
  }
}
header.push('');

const out = [];
// Все узлы, которые собираемся занять, для проверки одним проходом.
const busyRefs = [];
for (const b of blocks) { for (const e of b.els) { busyRefs.push(e.addr); } }

out.push(header.join('\n'));
out.push('');
out.push('// Сгенерировано: делаем точку, привязываем адреса, проверяем данные.');
out.push('int dpdPass = 0;');
out.push('int dpdFail = 0;');
out.push('int elemCount = 0;');
out.push('');
out.push('const int DRV = ' + driver + ';');
out.push('');
out.push('main()');
out.push('{');
out.push('  DebugN("=== точка данных по карте ===");');
out.push('  string grp = findPollGroup();');
out.push('  DebugN("группа опроса: \'" + grp + "\'");');
out.push('  if (grp == "")');
out.push('  {');
out.push('    DebugN("  FAIL группа опроса не найдена.");');
out.push('    DebugN("  Создайте её: панель системы -> Drivers -> Poll groups.");');
out.push('    dpdFail++;');
out.push('    return;');
out.push('  }');
out.push('');
out.push(freePrologue(busyRefs));
out.push('');
for (const b of blocks) {
  out.push(b.body);
  out.push('');
}
if (verify) {
  out.push('  // ------------------------- проверка данных -------------------------');
  out.push('  DebugN("=== ждём данные ===");');
  out.push('  for (int i = 1; i <= 30; i++) { if (allFresh()) { break; } delay(1); }');
  out.push('');
  out.push('  // Один общий срез, потом одна пауза, потом второй срез. Проверять');
  out.push('  // каждый элемент в отдельном цикле со своей паузой нельзя: при');
  out.push('  // 40 элементах и паузе 6 с проверка растягивается на четыре минуты.');
  out.push('  dyn_string names = allElems();');
  out.push('  int nAll = dynlen(names);');
  out.push('  dyn_string first = makeDynString();');
  out.push('  for (int i = 1; i <= nAll; i++)');
  out.push('  {');
  out.push('    dyn_anytype v;');
  out.push('    dpGet(names[i] + ":_online.._value", v);');
  out.push('    first[dynlen(first) + 1] = "" + v;');
  out.push('  }');
  out.push('');
  out.push('  DebugN("=== значения, первый срез ===");');
  out.push('  for (int i = 1; i <= nAll; i++)');
  out.push('  {');
  out.push('    dyn_anytype v; bool b; int q; time t;');
  out.push('    dpGet(names[i] + ":_online.._value", v);');
  out.push('    dpGet(names[i] + ":_online.._bad", b);');
  out.push('    dpGet(names[i] + ":_online.._quality_code", q);');
  out.push('    dpGet(names[i] + ":_online.._stime", t);');
  out.push('    DebugN("     ", names[i], ": v=", v, " q=", q, " bad=", b);');
  out.push('  }');
  out.push('');
  out.push('  DebugN("=== ждём 6 с, второй срез ===");');
  out.push('  delay(6);');
  out.push('  int good = 0, fresh = 0, live = 0;');
  out.push('  for (int i = 1; i <= nAll; i++)');
  out.push('  {');
  out.push('    dyn_anytype v; bool b; int q; time t;');
  out.push('    dpGet(names[i] + ":_online.._value", v);');
  out.push('    dpGet(names[i] + ":_online.._bad", b);');
  out.push('    dpGet(names[i] + ":_online.._quality_code", q);');
  out.push('    dpGet(names[i] + ":_online.._stime", t);');
  out.push('    if (q == 128 && !b) { good++; }');
  out.push('    else { DebugN("   НЕ GOOD: ", names[i], " q=", q, " bad=", b); }');
  out.push('    if (t != makeTime(1970, 1, 1, 3, 0, 0)) { fresh++; }');
  out.push('    else { DebugN("   НЕТ ДАННЫХ: ", names[i]); }');
  out.push('    if (("" + v) != first[i]) { live++; }');
  out.push('  }');
  out.push('  DebugN("=== итог ===");');
  out.push('  DebugN("  элементов всего  : ", nAll);');
  out.push('  DebugN("  quality = 128    : ", good);');
  out.push('  DebugN("  данные пришли    : ", fresh);');
  out.push('  DebugN("  значения меняются: ", live);');
  out.push('  chk(good == nAll, "все элементы GOOD", "" + good);');
  out.push('  chk(fresh == nAll, "данные у всех элементов", "" + fresh);');
  out.push('  chk(live > 0, "хотя бы часть значений меняется", "" + live);');
  out.push('');
}
out.push('  DebugN("");');
out.push('  DebugN("PASS=", dpdPass, "  FAIL=", dpdFail);');
out.push('  DebugN("=== конец ===");');
out.push('}');
out.push('');
out.push('// ------------------------------------------------------------------');
out.push('// Привязка адреса. Рецепт проверен на CTL 3.18; порядок атрибутов важен.');
out.push('// Без _distrib драйвер не считает точку своей и молчит без ошибок.');
out.push(helperCtl);
out.push('');
out.push('void cfg(string dp, string el, string addr, int datatype, int direction, string grp)');
out.push('{');
out.push('  string dpe = dp + "." + el;');
out.push('  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,');
out.push('                    dpe + ":_distrib.._driver", DRV);');
out.push('  int rc = dpSetTimedWait(0,');
out.push('                    dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,');
out.push('                    dpe + ":_address.._reference", addr,');
out.push('                    dpe + ":_address.._active",    TRUE,');
out.push('                    dpe + ":_address.._drv_ident", "MODBUS",');
out.push('                    dpe + ":_address.._datatype",  datatype,');
out.push('                    dpe + ":_address.._direction", direction,');
out.push('                    dpe + ":_address.._poll_group", grp);');
out.push('  string got;');
out.push('  dpGet(dpe + ":_address.._reference", got);');
out.push('  chk((rc == 0) && (got == addr), dp + "." + el + " " + addr, "rc=" + rc + " got=\'" + got + "\'");');
out.push('}');
out.push('');
out.push('void killDP(string dp, string dpt)');
out.push('{');
out.push('  if (dpExists(dp)) { dpDelete(dp); }');
out.push('  for (int i = 1; i <= 30; i++) { if (!dpExists(dp)) { break; } delay(1); }');
out.push('  for (int j = 1; j <= 30; j++)');
out.push('  {');
out.push('    dyn_dyn_string pn; dyn_dyn_int pt;');
out.push('    if (dpTypeGet(dpt, pn, pt) != 0) { break; }');
out.push('    dpTypeDelete(dpt); delay(1);');
out.push('  }');
out.push('}');
out.push('');
if (verify) {
  out.push('// Имена элементов берём из типа точки: функции dpGetAllDPEs в CTL нет.');
  out.push('dyn_string allElems()');
  out.push('{');
  out.push('  dyn_string res = makeDynString();');
  out.push('  dyn_string dps = makeDynString();');
  for (const b of blocks) out.push(`  dps[dynlen(dps) + 1] = "${b.dpName}";`);
  out.push('  for (int d = 1; d <= dynlen(dps); d++)');
  out.push('  {');
  out.push('    string tpn = dpTypeName(dps[d] + ".");');
  out.push('    dyn_dyn_string nm; dyn_dyn_int ty;');
  out.push('    if (dpTypeGet(tpn, nm, ty) != 0) { continue; }');
  out.push('    for (int k = 2; k <= dynlen(nm); k++)');
  out.push('    { res[dynlen(res) + 1] = dps[d] + "." + nm[k][dynlen(nm[k])]; }');
  out.push('  }');
  out.push('  return res;');
  out.push('}');
  out.push('');
  out.push('bool allFresh()');
  out.push('{');
  out.push('  dyn_string all = allElems();');
  out.push('  if (dynlen(all) == 0) { return false; }');
  out.push('  for (int i = 1; i <= dynlen(all); i++)');
  out.push('  {');
  out.push('    time t; dpGet(all[i] + ":_online.._stime", t);');
  out.push('    if (t == makeTime(1970, 1, 1, 3, 0, 0)) { return false; }');
  out.push('  }');
  out.push('  return true;');
  out.push('}');
out.push('');
}
out.push('// Группа опроса: берём первую точку типа _PollGroup, имя уже с системным');
out.push('// префиксом, то есть "System1:_1s".');
out.push('string findPollGroup()');
out.push('{');
out.push('  dyn_string all = dpNames("_**");');
out.push('  for (int i = 1; i <= dynlen(all); i++)');
out.push('  { if (dpTypeName(all[i] + ".") == "_PollGroup") { return all[i]; } }');
out.push('  return "";');
out.push('}');
out.push('');
out.push('void chk(bool ok, string what, string extra)');
out.push('{');
out.push('  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }');
out.push('  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra); }');
out.push('}');
out.push('');

fs.mkdirSync(path.dirname(path.resolve(outFile)), { recursive: true });
fs.writeFileSync(outFile, out.join('\n'), 'utf8');

// -------------------------------------------------------------- отчёт

console.log('='.repeat(70));
console.log(`Карта : ${file}`);
console.log(`CTL   : ${outFile}`);
console.log('='.repeat(70));
for (const b of blocks) {
  const byLabel = {};
  for (const e of b.els) { byLabel[e.label] = (byLabel[e.label] || 0) + 1; }
  console.log(`slave ${b.dev.id} «${b.dev.name}» -> ${b.dpName} / ${b.dptName}: ${b.els.length} элементов`);
  console.log(`   типы: ${Object.entries(byLabel).map(([k, v]) => `${k}=${v}`).join(', ')}`);
  console.log(`   направления: ${[...new Set(b.els.map((e) => e.direction))].join(', ')}`);
}
const total = blocks.reduce((s, b) => s + b.els.length, 0);
console.log(`Всего элементов: ${total}`);
const renamed = blocks.flatMap((b) =>
  b.els.filter((e) => e.mapName !== e.name).map((e) => `${e.mapName} -> ${e.name}`));
if (renamed.length) {
  console.log(`Переименовано из-за коллизий имён: ${renamed.length}`);
  renamed.forEach((r) => console.log(`   ${r}`));
}
if (warnings.length) {
  console.log(`ПРЕДУПРЕЖДЕНИЙ: ${warnings.length}`);
  warnings.forEach((w) => console.log(`   ~ ${w}`));
}
console.log('='.repeat(70));
