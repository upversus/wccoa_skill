// regtype.js - единственное место, где решается, что означает запись карты.
//
// Зачем вынесено отдельно. Правило «count=2 и signed=false - это float или
// uint?» должно быть ОДНИМ для сервера и для генератора CTL. Когда эти два
// места решали по-разному, эмулятор отдавал Total_Operating_Hours как float32,
// а точка читала его как uint32: значение приходило как bad=1 с заглушкой
// 2147483647. Расхождение в одну строку стоило целой ветки диагностики.
//
// Используется из:
//   server.js                 - как кодировать регистр в 16-битные слова
//   tools/gen-modbus-dp.js    - какой _datatype и тип элемента ставить в WinCC OA

'use strict';

// Коды _datatype в WinCC OA. Проверено на стенде, CTL 3.18.
const DATATYPE = {
  INT16:  561,
  INT32:  562,
  UINT16: 563,
  UINT32: 564,
  FLOAT:  566,
  BIT:    567,
};

// Типы элемента точки данных в WinCC OA.
const DPEL = {
  INT:   'DPEL_INT',
  FLOAT: 'DPEL_FLOAT',
  BOOL:  'DPEL_BOOL',
};

// Направление _address.._direction.
const DIRECTION = {
  POLL: 4,   // только чтение
  IO:   7,   // вход/выход, запись доходит до устройства
};

// Коды функций Modbus по пространствам.
const SPACE_FC = { coils: 1, input: 2, holding: 3, ireg: 4 };

// Сколько регистров занимает запись.
function words(reg) {
  return reg.count || 1;
}

// Двухрегистровая запись неоднозначна: и float32, и uint32 имеют count=2 и
// signed=false. Распределяем по генератору, он однозначно указывает намерение.
function isFloat(reg) {
  const g = reg.gen || {};
  if (g.type === 'sine') { return true; }
  if (g.type === 'const') {
    return typeof g.value === 'number' && !Number.isInteger(g.value);
  }
  if (g.type === 'ramp' || g.type === 'sineInt') { return false; }
  return false;
}

// Полная классификация записи карты.
function classify(reg, space) {
  const w = words(reg);
  const bitSpace = (space === 'coils' || space === 'input');

  // Направление: POLL = только чтение, IO = запись доходит до устройства.
  // Записываемым может быть только holding: у него есть FC3/06/16.
  // У катушек своя ветка выше, у input/ireg записи нет вовсе, поэтому
  // флаг writable там игнорируется - это отвергает валидатор.
  //
  // По умолчанию holding остаётся только для чтения: так безопаснее,
  // и раньше это было единственным поведением. Явно помечайте записываемые
  // параметры через "writable": true, иначе запись в уставку молча ничего
  // не делает.
  const dir = (space === 'holding' && reg.writable === true)
    ? DIRECTION.IO
    : DIRECTION.POLL;

  if (bitSpace) {
    return {
      words: 1,
      isFloat: false,
      datatype: DATATYPE.BIT,
      dpeType: DPEL.BOOL,
      direction: space === 'coils' ? DIRECTION.IO : DIRECTION.POLL,
      label: 'BIT',
    };
  }

  if (w === 1) {
    return reg.signed === true
      ? { words: 1, isFloat: false, datatype: DATATYPE.INT16,
          dpeType: DPEL.INT, direction: dir, label: 'INT16' }
      : { words: 1, isFloat: false, datatype: DATATYPE.UINT16,
          dpeType: DPEL.INT, direction: dir, label: 'UINT16' };
  }

  if (w === 2) {
    if (isFloat(reg)) {
      return { words: 2, isFloat: true, datatype: DATATYPE.FLOAT,
               dpeType: DPEL.FLOAT, direction: dir, label: 'FLOAT' };
    }
    return reg.signed === true
      ? { words: 2, isFloat: false, datatype: DATATYPE.INT32,
          dpeType: DPEL.INT, direction: dir, label: 'INT32' }
      : { words: 2, isFloat: false, datatype: DATATYPE.UINT32,
          dpeType: DPEL.INT, direction: dir, label: 'UINT32' };
  }

  if (w === 4) {
    return { words: 4, isFloat: false, datatype: DATATYPE.UINT32,
             dpeType: DPEL.INT, direction: dir, label: 'UINT32 (64 бита эмулируются в 4 слова)' };
  }

  return null;
}

// Имя элемента точки: только буквы, цифры и подчёркивание, первым символом -
// буква или подчёркивание. Точки и пробелы WinCC OA в именах не принимает.
function safeName(raw, fallback) {
  let s = String(raw == null ? '' : raw)
    .replace(/[^A-Za-z0-9_]/g, '_')
    .replace(/_+/g, '_')
    .replace(/^([0-9])/, '_$1');
  if (s === '' || s === '_') { s = fallback; }
  return s;
}

// Имя элемента с учётом коллизий: одно и то же имя в разных пространствах
// нельзя положить в одну точку дважды.
function uniqueName(used, base) {
  let name = base;
  let n = 2;
  while (used.has(name)) { name = `${base}_${n}`; n += 1; }
  used.add(name);
  return name;
}

module.exports = {
  DATATYPE, DPEL, DIRECTION, SPACE_FC,
  words, isFloat, classify, safeName, uniqueName,
};