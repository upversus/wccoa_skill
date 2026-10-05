#!/usr/bin/env node
// gen-opcua-dp.js - генерация CTL-скрипта точки данных WinCC OA из карты OPC UA.
//
// Зачем. Ручной перенос карты в скрипт даёт молчаливые ошибки, ровно как для
// Modbus: неверный код _datatype, неверный тип элемента, элемент без узла на
// сервере. Здесь всё выводится механически, а источником истины служит сам
// сервер, а не запись в карте.
//
// Использование:
//   node tools/gen-opcua-dp.js <map.csv|map.json> --out <file.ctl> [ключи]
//
// Ключи:
//   --out <file>      куда писать CTL, обязателен
//   --endpoint <url>  OPC UA endpoint, нужен для сверки с сервером
//   --path <folder>   папка на сервере для CSV-карт Kepware,
//                     например "Simulation Examples.Functions"
//   --dp <имя>        имя точки, по умолчанию из префикса файла
//   --dpt <имя>       имя типа, по умолчанию <dp>_t
//   --drv <N>         номер драйвера OPC UA, по умолчанию 3
//   --no-resolve      не обращаться к серверу, взять типы из карты
//   --no-verify       не добавлять блок проверки данных
//   --keep            не удалять существующую точку перед созданием
//   --allow-missing   не считать ошибкой теги, которых нет на сервере

'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

// ------------------------------------------------------------------ ключи

const args = process.argv.slice(2);
const file = args.find((a) => !a.startsWith('--'));
function opt(name, def) {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
}
const flag = (name) => args.includes(`--${name}`);

if (!file) {
  console.error('Укажите карту: node tools/gen-opcua-dp.js <map.csv|map.json> --out <file.ctl>');
  process.exit(2);
}
const outFile = opt('out', null);
if (!outFile) {
  console.error('Обязателен ключ --out <file.ctl>');
  process.exit(2);
}

const endpoint = opt('endpoint', null);
const folder = opt('path', null);
const driver = Number(opt('drv', '3'));
const resolve = endpoint && !flag('no-resolve');
const verify = !flag('no-verify');
const keep = flag('keep');
const allowMissing = flag('allow-missing');

// ------------------------------------------------- таблицы типов OPC UA
// Источник: scripts/libs/examples/opcuactl..., точнее
// C:\Sybcom\Kaskad\3.18\scripts\libs\examples\opcuaImportExample.ctl
// enum OPCUATransformation. НЕ брать из примеров проекта: там таблица
// урезанная, и на ней путаешь UInt16 с Int16.

const T = {
  Boolean: 751, SByte: 752, Byte: 753, Int16: 754, UInt16: 755,
  Int32: 756, UInt32: 757, Int64: 758, UInt64: 759, Float: 760,
  Double: 761, String: 762, DateTime: 763, Guid: 764, ByteString: 765,
  XmlElement: 766, NodeId: 767, LocalizedText: 768,
};

// Тип элемента точки данных. Беззнаковые требуют беззнакового элемента:
// UInt16 в DPEL_INT станет отрицательным после 32767.
const ELEM = {
  Boolean: 'DPEL_BOOL',
  SByte: 'DPEL_INT', Byte: 'DPEL_UINT',
  Int16: 'DPEL_INT', UInt16: 'DPEL_UINT',
  Int32: 'DPEL_INT', UInt32: 'DPEL_UINT',
  Int64: 'DPEL_LONG', UInt64: 'DPEL_ULONG',
  Float: 'DPEL_FLOAT', Double: 'DPEL_FLOAT',
  String: 'DPEL_STRING', DateTime: 'DPEL_TIME',
  Guid: 'DPEL_STRING', ByteString: 'DPEL_BLOB',
  XmlElement: 'DPEL_STRING', NodeId: 'DPEL_STRING',
  LocalizedText: 'DPEL_LANGSTRING',
};

// Типы, которые не имеет смысла тащить в точку: диагностика и метаданные.
const SKIP_SUFFIX = /\._(System|Statistics|Hints|Features|Alarms|Address|ClientAccess|Description|Name|NegateValue|Scaling\w*|EngineeringUnits)$/;

// Направление по доступу: бит 0 AccessLevel - чтение, бит 1 - запись.
const DIR_RO = 4;   // inputPolling
const DIR_RW = 7;   // inputOutputPolling

// Типы Kepware из CSV -> типы OPC UA, для сверки.
const KEEWARE = {
  Boolean: 'Boolean', Short: 'Int16', Word: 'UInt16',
  Long: 'Int32', LLong: 'Int64', QWord: 'UInt64',
  Float: 'Float', Double: 'Double', String: 'String',
};

// ------------------------------------------------------------------ карта

function safeName(raw, fallback) {
  let s = String(raw == null ? '' : raw)
    .replace(/[^A-Za-z0-9_]/g, '_')
    .replace(/_+/g, '_')
    .replace(/^([0-9])/, '_$1');
  if (s === '' || s === '_') { s = fallback; }
  return s;
}
function uniqueName(used, base) {
  let n = base; let k = 2;
  while (used.has(n)) { n = `${base}_${k}`; k += 1; }
  used.add(n);
  return n;
}

function splitCsvLine(line) {
  const out = [];
  let cur = '';
  let q = false;
  for (let i = 0; i < line.length; i += 1) {
    const c = line[i];
    if (q) {
      if (c === '"') {
        if (line[i + 1] === '"') { cur += '"'; i += 1; } else { q = false; }
      } else { cur += c; }
    } else if (c === '"') { q = true; }
    else if (c === ',') { out.push(cur); cur = ''; }
    else { cur += c; }
  }
  out.push(cur);
  return out;
}

function readCsv(file) {
  // BOM обязан быть снят: иначе первый заголовок становится "﻿Tag Name"
  // и поиск столбца по имени молча не находит.
  const text = fs.readFileSync(file, 'utf8').replace(/^﻿/, '');
  const lines = text.split(/\r?\n/).filter((l) => l.trim() !== '');
  if (!lines.length) { throw new Error('CSV пуст'); }
  const head = splitCsvLine(lines[0]).map((h) => h.trim());
  const col = (name) => {
    const i = head.indexOf(name);
    if (i < 0) { throw new Error(`В CSV нет столбца "${name}". Есть: ${head.join(', ')}`); }
    return i;
  };
  const iName = col('Tag Name');
  const iType = head.indexOf('Data Type');
  const iAcc = head.indexOf('Client Access');
  return lines.slice(1).map((l) => {
    const f = splitCsvLine(l);
    return {
      name: (f[iName] || '').trim(),
      mapType: iType >= 0 ? (f[iType] || '').trim() : '',
      access: iAcc >= 0 ? (f[iAcc] || '').trim() : 'RO',
    };
  }).filter((t) => t.name !== '');
}

function readJson(file) {
  const j = JSON.parse(fs.readFileSync(file, 'utf8').replace(/^﻿/, ''));
  const list = Array.isArray(j) ? j : (j.tags || []);
  return list.map((t) => ({
    name: t.name,
    nodeId: t.nodeId,
    mapType: t.type || '',
    access: t.access || 'RO',
  }));
}

const ext = path.extname(file).toLowerCase();
let tags;
try {
  tags = ext === '.csv' ? readCsv(file) : readJson(file);
} catch (e) {
  console.error(`Не удалось прочитать карту ${file}: ${e.message}`);
  process.exit(2);
}
if (!tags.length) {
  console.error('В карте нет ни одного тега.');
  process.exit(1);
}

// --------------------------------------------------- сверка с сервером

// Ищем рядом с генератором. Генератор может лежать и в tools\, и в
// tools\opcua\, поэтому проверяем оба места, а не полагаемся на __dirname.
function opcuactlPath() {
  if (process.env.OPCUACTL) { return process.env.OPCUACTL; }
  const here = __dirname;
  const candidates = [
    path.join(here, 'opcuactl', 'opcuactl.exe'),
    path.join(here, '..', 'opcuactl', 'opcuactl.exe'),
    path.join(here, '..', '..', 'opcuactl', 'opcuactl.exe'),
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) { return path.resolve(c); }
  }
  return candidates[0];
}

let index = new Map();   // nodeId -> { dataType, value, status }
let serverTypes = null;

if (resolve) {
  const exe = opcuactlPath();
  if (!fs.existsSync(exe)) {
    console.error(`Не найден opcuactl: ${exe}`);
    console.error('Задайте путь переменной OPCUACTL или используйте --no-resolve.');
    process.exit(2);
  }
  let raw;
  try {
    raw = execFileSync(exe,
      ['get', 'vars', '-e', endpoint, '--node', 'i=85', '--recursive', '-f', 'json'],
      { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 });
  } catch (e) {
    console.error(`Ошибка обхода сервера ${endpoint}: ${e.message}`);
    process.exit(2);
  }
  const vars = JSON.parse(raw);
  for (const v of vars) {
    if (SKIP_SUFFIX.test(v.nodeId)) { continue; }
    index.set(v.nodeId, v);
  }
  serverTypes = vars.length;
  console.error(`[обход] ${endpoint}: переменных ${vars.length}, содержательных ${index.size}`);
}

// ------------------------------------------------------ сбор элементов

const used = new Set();
const elems = [];
const missing = [];
const mismatch = [];

function nodeIdOf(t) {
  if (t.nodeId) { return t.nodeId; }
  if (folder) { return `ns=2;s=${folder}.${t.name}`; }
  return null;
}

for (const t of tags) {
  const nodeId = nodeIdOf(t);
  if (!nodeId) {
    console.error('Не задан nodeId и не указан --path: нечем построить адрес.');
    process.exit(2);
  }
  if (SKIP_SUFFIX.test(nodeId)) { continue; }

  const onServer = index.get(nodeId);
  let type = null;

  if (onServer) {
    // Сервер - источник истины.
    type = onServer.dataType;
    if (t.mapType && KEEWARE[t.mapType] && KEEWARE[t.mapType] !== type) {
      mismatch.push(`${t.name}: в карте ${t.mapType} -> ${KEEWARE[t.mapType]}, сервер отдаёт ${type}`);
    }
  } else if (resolve) {
    missing.push(`${t.name}  (${nodeId})`);
    continue;
  } else {
    type = KEEWARE[t.mapType] || t.mapType;
    if (!T[type]) { type = null; }
  }

  if (!type || !(type in T)) {
    missing.push(`${t.name}  (${nodeId})  тип не опознан: ${t.mapType || '?'}`);
    continue;
  }
  if (!(type in ELEM)) {
    missing.push(`${t.name}  (${nodeId})  нет типа элемента для ${type}`);
    continue;
  }

  const accessLevel = onServer && onServer.accessLevel !== undefined
    ? Number(onServer.accessLevel) : null;
  let direction = DIR_RO;
  if (accessLevel === 3) { direction = DIR_RW; }
  else if (/rw/i.test(t.access || '')) { direction = DIR_RW; }

  const base = safeName(t.name, `Tag_${elems.length + 1}`);
  elems.push({
    name: uniqueName(used, base),
    mapName: t.name,
    nodeId,
    type,
    datatype: T[type],
    elemType: ELEM[type],
    direction,
    access: accessLevel === null ? t.access : `AccessLevel=${accessLevel}`,
  });
}

// ------------------------------------------------------------- отчёт

const errors = [];
if (missing.length && !allowMissing) { errors.push(`${missing.length} тегов не на сервере`); }

console.log('='.repeat(70));
console.log(`Карта : ${file}`);
console.log(`CTL   : ${outFile}`);
console.log(`Сервер: ${resolve ? endpoint : 'сверка отключена (--no-resolve)'}`);
console.log('='.repeat(70));

const byType = {};
for (const e of elems) { byType[e.type] = (byType[e.type] || 0) + 1; }
console.log(`Элементов к генерации: ${elems.length} из ${tags.length}`);
console.log('Типы:');
for (const [k, v] of Object.entries(byType).sort((a, b) => b[1] - a[1])) {
  console.log(`   ${k.padEnd(10)} ${String(v).padStart(3)}   код ${T[k]}, элемент ${ELEM[k]}`);
}
const dirs = [...new Set(elems.map((e) => e.direction))].sort();
console.log(`Направления: ${dirs.join(', ')}` +
  (dirs.length === 1 && dirs[0] === DIR_RO ? '  (только чтение)' : ''));

if (mismatch.length) {
  console.log(`РАСХОЖДЕНИЯ ТИПОВ карта/сервер: ${mismatch.length}`);
  mismatch.forEach((m) => console.log(`   ~ ${m}`));
}
if (missing.length) {
  console.log(`НЕТ НА СЕРВЕРЕ: ${missing.length}`);
  missing.forEach((m) => console.log(`   ! ${m}`));
  if (!allowMissing) {
    console.log('Это не ошибка карты как таковой: сервер может не отдавать такие');
    console.log('типы. Например Kepware не отдаёт LLong и QWord по OPC UA.');
    console.log('Чтобы пропустить их молча, добавь --allow-missing.');
  }
}
if (errors.length) {
  console.log('='.repeat(70));
  process.exit(1);
}
if (!elems.length) {
  console.log('Генерировать нечего.');
  process.exit(1);
}

// ------------------------------------------------------ генерация CTL

const dpPrefix = opt('dp', safeName(path.basename(file, ext), 'dpopc').toLowerCase());
const dpName = dpPrefix;
const dptName = opt('dpt', `${dpPrefix}_t`);

const L = [];
L.push('// СГЕНЕРИРОВАНО АВТОМАТИЧЕСКИ: tools/gen-opcua-dp.js');
L.push(`// Карта    : ${path.basename(file)}`);
L.push(`// Сервер  : ${endpoint || 'сверка отключена'}`);
L.push(`// Драйвер : ${driver}`);
L.push('//');
L.push('// Не правь руками: файл перезаписывается при следующей генерации.');
L.push('// Правь карту и запускай генератор заново.');
L.push('//');
L.push('// Карта элементов:');
L.push(`//   точка ${dpName}, тип ${dptName}`);
for (const e of elems) {
  L.push(`//     ${e.nodeId.padEnd(58)} ${String(e.datatype).padEnd(4)} ${e.type.padEnd(10)} ${e.elemType.padEnd(14)} dir ${e.direction}  ${e.name}`);
}
if (missing.length) {
  L.push('//');
  L.push('// Пропущены, сервер их не отдаёт:');
  missing.forEach((m) => L.push(`//   ${m}`));
}
L.push('');

L.push('int dpdPass = 0;');
L.push('int dpdFail = 0;');
L.push('int elemCount = 0;');
L.push('');
L.push(`const int DRV = ${driver};`);
L.push('');
L.push('// Коды преобразований OPC UA, полный список 19 значений.');
L.push('// Источник: scripts/libs/examples/opcuaImportExample.ctl, OPCUATransformation.');
L.push('int ADDR_DATATYPE_BOOLEAN = 751;');
L.push('int ADDR_DATATYPE_INT16   = 754;');
L.push('int ADDR_DATATYPE_UINT16  = 755;');
L.push('int ADDR_DATATYPE_INT32   = 756;');
L.push('int ADDR_DATATYPE_UINT32  = 757;');
L.push('int ADDR_DATATYPE_INT64   = 758;');
L.push('int ADDR_DATATYPE_UINT64  = 759;');
L.push('int ADDR_DATATYPE_FLOAT   = 760;');
L.push('int ADDR_DATATYPE_DOUBLE  = 761;');
L.push('int ADDR_DATATYPE_STRING  = 762;');
L.push('');
L.push('main()');
L.push('{');
L.push('  DebugN("=== OPC UA: точка по карте ===");');
L.push('');
L.push('  // Сервер и подписка находятся в проекте по ТИПУ. Имя в адресе');
L.push('  // пишется без ведущего подчёркивания: точка _opc_ua_con даёт');
L.push('  // в адресе opc_ua_con.');
L.push('  string serverName = findByType("_OPCUAServer");');
L.push('  string subName    = findByType("_OPCUASubscription");');
L.push('  DebugN("  сервер   = \'" + serverName + "\'");');
L.push('  DebugN("  подписка = \'" + subName + "\'");');
L.push('  if (serverName == "" ) { chk(FALSE, "найдена точка типа _OPCUAServer", "");        return; }');
L.push('  if (subName    == "" ) { chk(FALSE, "найдена точка типа _OPCUASubscription", ""); return; }');
L.push('');
L.push('  string prefix = serverName + "$" + subName + "$1$1$";');
L.push('  DebugN("  префикс  = ", prefix);');
L.push('');
L.push('  killDP("' + dpName + '", "' + dptName + '");');
if (keep) { L.push('  DebugN("  --keep: существующая точка не удаляется");'); }
L.push('');
L.push('  dyn_dyn_string names;');
L.push('  dyn_dyn_int    types;');
L.push(`  names[1] = makeDynString("${dptName}");`);
L.push('  types[1] = makeDynInt(DPEL_STRUCT);');
elems.forEach((e, i) => {
  L.push(`  names[${i + 2}] = makeDynString("", "${e.name}");`);
  L.push(`  types[${i + 2}] = makeDynInt(0, ${e.elemType});`);
});
L.push(`  chk(dpTypeCreate(names, types) == 0, "${dptName}: тип создан, элементов ${elems.length}", "");`);
L.push('');
L.push(`  chk(dpCreate("${dpName}", "${dptName}") == 0, "${dpName}: точка создана", "");`);
L.push('');
L.push('  DebugN("  -- адреса --");');
elems.forEach((e) => {
  L.push(`  cfg("${dpName}", "${e.name}", prefix + "${e.nodeId}", ${e.datatype}, ${e.direction});`);
});
L.push(`  elemCount += ${elems.length};`);
L.push('');

if (verify) {
  L.push('  // ------------------------- проверка данных -------------------------');
  L.push('  DebugN("=== ждём данные ===");');
  L.push('  for (int i = 1; i <= 40; i++) { if (allFresh()) { break; } delay(1); }');
  L.push('');
  L.push('  dyn_string names = allElems("' + dpName + '");');
  L.push('  int nAll = dynlen(names);');
  L.push('  dyn_string first = makeDynString();');
  L.push('  for (int i = 1; i <= nAll; i++)');
  L.push('  {');
  L.push('    dyn_anytype v;');
  L.push('    dpGet(names[i] + ":_online.._value", v);');
  L.push('    first[dynlen(first) + 1] = "" + v;');
  L.push('  }');
  L.push('');
  L.push('  DebugN("=== значения, первый срез ===");');
  L.push('  for (int i = 1; i <= nAll; i++)');
  L.push('  {');
  L.push('    dyn_anytype v; bool b; int q; time t;');
  L.push('    dpGet(names[i] + ":_online.._value", v);');
  L.push('    dpGet(names[i] + ":_online.._bad", b);');
  L.push('    dpGet(names[i] + ":_online.._quality_code", q);');
  L.push('    dpGet(names[i] + ":_online.._stime", t);');
  L.push('    DebugN("     ", names[i], ": v=", v, " q=", q, " bad=", b);');
  L.push('  }');
  L.push('');
  L.push('  DebugN("=== ждём 6 с, второй срез ===");');
  L.push('  delay(6);');
  L.push('  int good = 0, fresh = 0, live = 0;');
  L.push('  for (int i = 1; i <= nAll; i++)');
  L.push('  {');
  L.push('    dyn_anytype v; bool b; int q; time t;');
  L.push('    dpGet(names[i] + ":_online.._value", v);');
  L.push('    dpGet(names[i] + ":_online.._bad", b);');
  L.push('    dpGet(names[i] + ":_online.._quality_code", q);');
  L.push('    dpGet(names[i] + ":_online.._stime", t);');
  L.push('    if (q == 128 && !b) { good++; }');
  L.push('    else { DebugN("   НЕ GOOD: ", names[i], " q=", q, " bad=", b); }');
  L.push('    if (t != makeTime(1970, 1, 1, 3, 0, 0)) { fresh++; }');
  L.push('    else { DebugN("   НЕТ ДАННЫХ: ", names[i]); }');
  L.push('    if (("" + v) != first[i]) { live++; }');
  L.push('  }');
  L.push('  DebugN("=== итог ===");');
  L.push('  DebugN("  элементов всего  : ", nAll);');
  L.push('  DebugN("  quality = 128    : ", good);');
  L.push('  DebugN("  данные пришли    : ", fresh);');
  L.push('  DebugN("  значения меняются: ", live);');
  L.push('  chk(good == nAll, "все элементы GOOD", "" + good);');
  L.push('  chk(fresh == nAll, "данные у всех элементов", "" + fresh);');
  L.push('');
  L.push('  // Меняться обязаны не все: по карте есть константы и строки.');
  L.push('  DebugN("  изменилось " + live + " из " + nAll);');
}
L.push('');
L.push('  DebugN("");');
L.push('  DebugN("PASS=", dpdPass, "  FAIL=", dpdFail);');
L.push('  DebugN("=== конец ===");');
L.push('}');
L.push('');
L.push('// Привязка. Рецепт проверен на CTL 3.18, порядок атрибутов важен.');
L.push('// Без _distrib драйвер не считает точку своей и молчит без ошибок.');
L.push('void cfg(string dp, string el, string nodeId, int datatype, int direction)');
L.push('{');
L.push('  string dpe = dp + "." + el;');
L.push('  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,');
L.push('                    dpe + ":_distrib.._driver", DRV);');
L.push('  int rc = dpSetTimedWait(0,');
L.push('                    dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,');
L.push('                    dpe + ":_address.._reference", nodeId,');
L.push('                    dpe + ":_address.._active",    TRUE,');
L.push('                    dpe + ":_address.._drv_ident", "OPCUA",');
L.push('                    dpe + ":_address.._datatype",  datatype,');
L.push('                    dpe + ":_address.._direction", direction);');
L.push('  string got;');
L.push('  dpGet(dpe + ":_address.._reference", got);');
L.push('  chk((rc == 0) && (got == nodeId), dp + "." + el, "rc=" + rc + " got=\'" + got + "\'");');
L.push('}');
L.push('');
L.push('// dpNames() отбирает по ИМЕНИ, а не по типу, поэтому шаблон');
L.push('// "*_OPCUAServer" не годится. Перебираем всё и проверяем dpTypeName.');
L.push('string findByType(string want)');
L.push('{');
L.push('  dyn_string all = dpNames("**");');
L.push('  for (int i = 1; i <= dynlen(all); i++)');
L.push('  {');
L.push('    if (dpTypeName(all[i] + ".") != want) { continue; }');
L.push('    int pos = strpos(all[i], "_");');
L.push('    if (pos < 0) { return all[i]; }');
L.push('    return substr(all[i], pos + 1, 200);');
L.push('  }');
L.push('  return "";');
L.push('}');
L.push('');
L.push('void killDP(string dp, string dpt)');
L.push('{');
L.push('  if (dpExists(dp)) { dpDelete(dp); }');
L.push('  for (int i = 1; i <= 30; i++) { if (!dpExists(dp)) { break; } delay(1); }');
L.push('  for (int j = 1; j <= 30; j++)');
L.push('  {');
L.push('    dyn_dyn_string pn; dyn_dyn_int pt;');
L.push('    if (dpTypeGet(dpt, pn, pt) != 0) { break; }');
L.push('    dpTypeDelete(dpt); delay(1);');
L.push('  }');
L.push('}');
L.push('');
if (verify) {
  L.push('// Имена элементов берём из типа точки: функции dpGetAllDPEs в CTL нет.');
  L.push('dyn_string allElems(string dp)');
  L.push('{');
  L.push('  dyn_string res = makeDynString();');
  L.push('  string tpn = dpTypeName(dp + ".");');
  L.push('  dyn_dyn_string nm; dyn_dyn_int ty;');
  L.push('  if (dpTypeGet(tpn, nm, ty) != 0) { return res; }');
  L.push('  for (int k = 2; k <= dynlen(nm); k++)');
  L.push('  { res[dynlen(res) + 1] = dp + "." + nm[k][dynlen(nm[k])]; }');
  L.push('  return res;');
  L.push('}');
  L.push('');
  L.push('bool allFresh()');
  L.push('{');
  L.push('  dyn_string all = allElems("' + dpName + '");');
  L.push('  if (dynlen(all) == 0) { return false; }');
  L.push('  for (int i = 1; i <= dynlen(all); i++)');
  L.push('  {');
  L.push('    time t; dpGet(all[i] + ":_online.._stime", t);');
  L.push('    if (t == makeTime(1970, 1, 1, 3, 0, 0)) { return false; }');
  L.push('  }');
  L.push('  return true;');
  L.push('}');
  L.push('');
}
L.push('void chk(bool ok, string what, string extra)');
L.push('{');
L.push('  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }');
L.push('  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra); }');
L.push('}');
L.push('');

fs.mkdirSync(path.dirname(path.resolve(outFile)), { recursive: true });
fs.writeFileSync(outFile, L.join('\n'), 'utf8');
console.log(`Записан CTL: ${outFile}`);
console.log('='.repeat(70));
