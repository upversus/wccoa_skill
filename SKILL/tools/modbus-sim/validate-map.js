// validate-map.js - проверка карты адресов перед запуском эмулятора.
//
// Зачем он нужен. Карту адресного пространства пишет не человек, а скилл -
// по референсу пользователя, который приходит обычным текстом. Опечатка в
// адресе или пропуск блока дают сервер, который молча отдаёт нули: значения
// формально приходят, но ничего не меняется. Отличить такое от исправной
// работы без проверки невозможно.
//
// Поэтому карта проверяется МЕХАНИЧЕСКИ, до старта сервера.
//
// Использование:
//   node validate-map.js <файл map.json> [--port 502]
//
// Код возврата: 0 - всё в порядке, 1 - есть ошибки, 2 - файл не прочитан.

'use strict';

const fs = require('fs');
const net = require('net');

const GEN_TYPES = new Set([
  'const', 'toggle', 'sine', 'sineInt', 'ramp', 'rand',
]);

// Что обязательно для каждого типа генератора.
const GEN_PARAMS = {
  const:   ['value'],
  toggle:  ['periodMs'],
  sine:    ['min', 'max', 'periodMs'],
  sineInt: ['min', 'max', 'periodMs'],
  ramp:    ['min', 'max', 'periodMs'],
  rand:    ['min', 'max'],
};

const SPACES = {
  coils:   { fc: 1, label: 'Coils (дискретные выходы)' },
  input:   { fc: 2, label: 'Discrete Inputs (дискретные входы)' },
  holding: { fc: 3, label: 'Holding Registers (регистры хранения)' },
  ireg:    { fc: 4, label: 'Input Registers (регистры ввода)' },
};

const errors = [];
const warnings = [];
const line = '='.repeat(70);

function fail(msg) { errors.push(msg); }
function warn(msg) { warnings.push(msg); }

// ------------------------------------------------------------- аргументы

const args = process.argv.slice(2);
const file = args.find(a => !a.startsWith('--'));
const portArgIdx = args.indexOf('--port');
const portOverride = portArgIdx >= 0 ? Number(args[portArgIdx + 1]) : null;

if (!file) {
  console.error('Укажите файл карты: node validate-map.js <map.json> [--port N]');
  process.exit(2);
}

// ------------------------------------------------------------- чтение

let raw;
try {
  raw = fs.readFileSync(file, 'utf8');
} catch (e) {
  console.error(`Не удалось прочитать файл ${file}: ${e.message}`);
  process.exit(2);
}

// jsonc -> json: убираем строки-комментарии, как это делает server.js
const text = raw.replace(/^\s*\/\/.*$/gm, '');
let map;
try {
  map = JSON.parse(text);
} catch (e) {
  console.error(`НЕВАЛИДНЫЙ JSON в ${file}:\n  ${e.message}`);
  process.exit(1);
}

// ------------------------------------------------------------- верхний уровень

if (!map.port || typeof map.port !== 'number') {
  fail('Не задан port (число).');
}
// Драйвер читает только CDAB, и настроить иначе средствами, которые
// документирует скилл, нельзя. Карта с ABCD проходит проверку молча, а
// 32-битные значения собираются задом наперёд: замерено 814415872 вместо
// 12847, плюс bad = 1 и заглушка 2147483647.
if (map.wordOrder === 'ABCD') {
  fail(`wordOrder = "ABCD" на этом драйвере читается задом наперёд: ` +
       `32-битные значения соберутся перевёрнутыми. Драйвер WinCC OA 3.18 ` +
       `читает только CDAB - поставьте "wordOrder": "CDAB".`);
}
else if (map.wordOrder && map.wordOrder !== 'CDAB') {
  fail(`Неизвестный wordOrder "${map.wordOrder}" - ожидается CDAB.`);
}

if (!Array.isArray(map.devices) || map.devices.length === 0) {
  fail('Нет ни одного устройства в devices.');
  report();
}

const seenIds = new Set();
for (const dev of map.devices) {
  if (typeof dev.id !== 'number') {
    fail('Устройство без числового id.');
  } else if (seenIds.has(dev.id)) {
    fail(`Дублирующийся unit id ${dev.id}.`);
  } else {
    seenIds.add(dev.id);
  }
  if (!dev.name) warn(`Устройство ${dev.id} без имени.`);
  checkSpace(dev, 'coils');
  checkSpace(dev, 'input');
  checkSpace(dev, 'holding');
  checkSpace(dev, 'ireg');
}

report();

// ------------------------------------------------------------- проверки

function checkSpace(dev, space) {
  const list = dev[space];
  if (!list) return;
  const meta = SPACES[space];

  if (!Array.isArray(list) || list.length === 0) {
    warn(`slave ${dev.id} ${space}: пустой список.`);
    return;
  }

  const seen = new Map();
  // null = адреса ещё не было: первый регистр блока может начинаться с любого
  let expected = null;
  let dynamic = 0;
  let constOnly = 0;

  for (const reg of list) {
    if (typeof reg.addr !== 'number' || reg.addr < 0) {
      fail(`slave ${dev.id} ${space}: неверный адрес у "${reg.name || '?'}"`);
      continue;
    }
    if (seen.has(reg.addr)) {
      fail(`slave ${dev.id} ${space}: адрес ${reg.addr} описан дважды ` +
           `("${seen.get(reg.addr).name}" и "${reg.name}")`);
    }
    seen.set(reg.addr, reg);

    // Непрерывность. Дыра внутри блока заставит драйвер опрашивать по одному.
    // А начало блока ничем не ограничено: устройство вполне может отвечать
    // только на 10..13, и такой блок разрывом не является.
    if (expected !== null && reg.addr < expected) {
      fail(`slave ${dev.id} ${space} (FC${meta.fc}): перекрытие - адрес ` +
           `${reg.addr} ("${reg.name}") уже занят предыдущим регистром, ` +
           `свободным был ${expected}.`);
    }
    else if (expected !== null && reg.addr > expected) {
      fail(`slave ${dev.id} ${space} (FC${meta.fc}): разрыв - ожидался адрес ` +
           `${expected}, а следующий ${reg.addr} ("${reg.name}"). ` +
           `Драйвер может не опрашивать блок.`);
    }

    const count = reg.count || 1;
    if (count !== 1 && count !== 2 && count !== 4) {
      fail(`slave ${dev.id} ${space} "${reg.name}": count=${count}, ` +
           `допустимо 1, 2 (32 бита) или 4 (64 бита).`);
    }
    if (reg.signed !== undefined && typeof reg.signed !== 'boolean') {
      fail(`slave ${dev.id} ${space} "${reg.name}": signed должно быть true/false.`);


      }
      else if (reg.writable && space !== 'holding') {
        fail(`slave ${dev.id} ${space} "${reg.name}": writable на ` +
             `${space} не имеет смысла - запись есть только у holding ` +
             `(FC6/16). Укажите нужный блок как holding.`);
      }
    // Флаг writable помечает параметр, который должен достучать до
    // устройства. Тип строгий: строка или число молча превратились бы в
    // подсказку, которой генератор не воспользуется.
    if (reg.writable !== undefined) {
      if (typeof reg.writable !== 'boolean') {
        fail(`slave ${dev.id} ${space} "${reg.name}": writable должно быть ` +
             `true или false.`);
    }
    }
    if (count === 2 && reg.signed === undefined) {
      warn(`slave ${dev.id} ${space} "${reg.name}": count=2, signed не указан. ` +
           `Трактовка берётся из генератора: "sine" и дробный "const" -> float32, ` +
           `"ramp" и целый "const" -> uint32. Если нужно наоборот - укажите явно.`);
    }

    if (!reg.gen || typeof reg.gen !== 'object') {
      fail(`slave ${dev.id} ${space} "${reg.name}": нет gen.`);
    } else {
      const t = reg.gen.type;
      if (!GEN_TYPES.has(t)) {
        fail(`slave ${dev.id} ${space} "${reg.name}": неизвестный gen.type "${t}". ` +
             `Допустимо: ${[...GEN_TYPES].join(', ')}.`);
      } else {
        for (const p of GEN_PARAMS[t] || []) {
          if (reg.gen[p] === undefined) {
            fail(`slave ${dev.id} ${space} "${reg.name}": gen.type=${t} требует "${p}".`);
          }
        }
        if (t === 'const') constOnly++; else dynamic++;
      }
    }
    expected = reg.addr + count;
  }

  // Главная проверка для диагностики: если всё константы, «данные приходят,
  // но не меняются» - и это не отличить от молчащего адреса.
  if (constOnly === list.length && list.length > 0) {
    warn(`slave ${dev.id} ${space}: ВСЕ значения константы. ` +
         `Значения не будут меняться - нельзя отличить исправную работу ` +
         `от неверного адреса. Хотя бы часть сигналов должна быть динамической.`);
  }
  return dynamic;
}

function report() {
  console.log(line);
  console.log(`Проверка карты: ${file}`);
  console.log(line);
  if (map.port) console.log(`Порт: ${map.port}${portOverride ? ` (в аргументе --port ${portOverride})` : ''}`);
  if (map.wordOrder) console.log(`Порядок слов: ${map.wordOrder}`);
  console.log(`Устройств: ${map.devices ? map.devices.length : 0}`);

  if (map.devices) {
    for (const dev of map.devices) {
      console.log('');
      console.log(`  slave ${dev.id} «${dev.name || '?'}»`);
      for (const [space, meta] of Object.entries(SPACES)) {
        const list = dev[space];
        if (!list) continue;
        let last = -1;
        for (const r of list) { last = Math.max(last, r.addr + (r.count || 1) - 1); }
        const wide = list.filter(r => (r.count || 1) > 1).length;
        const dyn = list.filter(r => r.gen && r.gen.type !== 'const').length;
        console.log(
          `      ${meta.label.padEnd(42)} адреса 0..${last}, ` +
          `${list.length} записей, 32/64-битных: ${wide}, динамических: ${dyn}`
        );
      }
    }
  }

  // Занятость порта проверяется отдельно и асинхронно, см. checkPortFree().
  console.log('');
  console.log(line);
  if (warnings.length) {
    console.log(`ПРЕДУПРЕЖДЕНИЙ: ${warnings.length}`);
    for (const w of warnings) console.log(`  ~ ${w}`);
    console.log(line);
  }
  if (errors.length) {
    console.log(`ОШИБОК: ${errors.length}`);
    for (const e of errors) console.log(`  ! ${e}`);
    console.log(line);
    console.log('КАРТА НЕ ПРИГОДНА. Исправьте и проверьте снова.');
    process.exit(1);
  }
  console.log('Ошибок нет. Карта пригодна для запуска сервера.');
  if (warnings.length) {
    console.log('Предупреждения не блокируют запуск, но прочитайте их.');
  }

  if (map.port && !portOverride) checkPortFree(map.port);
}

// Порт занят - самая частая причина, по которой сервер не поднимается.
// Проверяем честно: пытаемся занять порт самим.
function checkPortFree(port) {
  const srv = net.createServer();
  srv.once('error', (e) => {
    console.log('');
    console.log(`Порт ${port} УЖЕ ЗАНЯТ (${e.code}).`);
    console.log('Сервер с этой картой не поднимется (EADDRINUSE). Остановите прежний.');
    console.log(line);
    // Без этого процесс завершался кодом 0, и вызывающая сторона считала
    // занятый порт успешной проверкой карты.
    process.exit(1);
  });
  srv.once('listening', () => {
    console.log('');
    console.log(`Порт ${port} свободен.`);
    srv.close(() => process.exit(0));
  });
  srv.listen(port, '0.0.0.0');
}
