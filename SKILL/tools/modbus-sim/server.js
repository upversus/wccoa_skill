// server.js - Modbus TCP сервер для стенда WinCC OA.
//
// Зачем он здесь: GUI-эмулятор mtcpServerEmulator не умеет перечитывать
// конфигурацию без перезапуска, а библиотеки node-modbus и jsmodbus
// с серверной частью не годятся - в npm это только клиенты:
//   * node-modbus тянет serialport ради RTU-клиента и нативной сборки;
//   * jsmodbus 5.0.0 содержит 27 .js файлов и ни одного createServer.
//
// Поэтому сервер написан здесь, без зависимостей.
//
// Возможности:
//   * Modbus TCP, порт из map.json;
//   * шесть устройств (unit id 1..6) на одном порту;
//   * FC1 чтение coils, FC2 discrete inputs, FC3 holding registers,
//     FC4 input registers;
//   * FC5 запись одного coil, FC6 одного регистра,
//     FC15 несколько coils, FC16 несколько регистров;
//   * адресное пространство каждого устройства непрерывно - дыры ломают
//     группировку запросов в драйвере WinCC OA;
//   * карта перечитывается при изменении map.json, перезапуск не нужен.
//
// Запуск:
//   node server.js
//
// Проверено: Node 22.22.2.

'use strict';

const net = require('net');
const fs = require('fs');
const path = require('path');

// Файл карты можно переопределить переменной окружения MODBUS_MAP - тогда
// рядом могут работать несколько экземпляров сервера на разных портах:
//   $env:MODBUS_MAP = 'D:\my_device.json'
//   node server.js
const MAP_FILE = process.env.MODBUS_MAP
  ? path.resolve(process.env.MODBUS_MAP)
  : path.join(__dirname, 'map.json');

// Правило «float32 или uint32?» живёт здесь, а не в этом файле: его же
// использует генератор CTL. Расхождение означало бы, что сервер кодирует
// значение не так, как его потом читает точка WinCC OA.
const regtype = require('./regtype.js');

// ---------------------------------------------------------------- карта

let map = null;
let devices = new Map();   // unit id -> устройство
let written = new Map();   // "unit:space:addr" -> значение, записанное снаружи

function loadMap(reason) {
  try {
    const raw = fs.readFileSync(MAP_FILE, 'utf8');
    const parsed = JSON.parse(stripJsonComments(raw));
    map = parsed;
    devices = new Map();
    for (const dev of parsed.devices) {
      devices.set(dev.id, dev);
    }
    console.log(
      `[карта] загружена (${reason}): ${parsed.devices.length} устройств, ` +
      `порт ${parsed.port}, порядок слов ${parsed.wordOrder}`
    );
    for (const dev of parsed.devices) {
        const cs = span(dev.coils), inp = span(dev.input);
        const ir = span(dev.ireg), hd = span(dev.holding);
        const fmt = (v) => (v ? `${v[0]}..${v[1]}` : "нет");
        console.log(
          `         slave ${dev.id} «${dev.name}»: ` +
          `coils ${fmt(cs)}, ` +
          `input ${fmt(inp)}, ` +
          `ireg ${fmt(ir)}, ` +
          `holding ${fmt(hd)}`
      );
    }
    checkContinuity();
    return true;
  } catch (e) {
    console.error('[карта] ОШИБКА чтения, работает прежняя карта:', e.message);
    return false;
  }
}

function stripJsonComments(text) {
  // Убирает строки-комментарии вида  // ...  в начале строки
  return text.replace(/^\s*\/\/.*$/gm, '');
}

// Реальный диапазон блока: первый адрес и последний ЗАНЯТЫЙ регистр.
// Раньше печатали "0..<последний addr>", из-за чего блок со сдвигом
// выглядел как покрывающий адреса, которых в карте нет.
function span(list) {
  if (!list || list.length === 0) return null;
  let lo = Infinity;
  let hi = -1;
  for (const reg of list) {
    const count = reg.count || 1;
    if (reg.addr < lo) lo = reg.addr;
    if (reg.addr + count - 1 > hi) hi = reg.addr + count - 1;
  }
  return [lo, hi];
}

// Проверка непрерывности: именно на этом наступали грабли.
function checkContinuity() {
  for (const dev of devices.values()) {
    const spaces = [
      ['coils', dev.coils],
      ['input', dev.input],
      ['holding', dev.holding],
      ['ireg', dev.ireg],
    ];
    for (const [space, list] of spaces) {
      if (!list) continue;
      const sorted = [...list].sort((a, b) => a.addr - b.addr);
      // null = первого адреса ещё не было. Начало блока ничем не
      // ограничено: устройство может отвечать только на 10..13.
      let expect = null;
      for (const reg of sorted) {
        if (expect !== null && reg.addr !== expect) {
          console.warn(
            `[карта] ВНИМАНИЕ slave ${dev.id} ${space}: `
              + (reg.addr < expect ? "перекрытие" : "разрыв")
              + ` перед адресом ${reg.addr}, ожидался ${expect}. Драйвер может не опрашивать блок.`
          );
        }
        expect = reg.addr + (reg.count || 1);
      }
    }
  }
}

// ------------------------------------------------------- пространства Modbus
//
// В спецификации Modbus четыре независимых пространства:
//   FC1 coils            00001..  дискретные выходы
//   FC2 discrete inputs  10001..  дискретные входы
//   FC3 holding          40001..  регистры хранения
//   FC4 input            30001..  регистры ввода
//
// Раньше сервер отдавал по FC2 те же coils, а по FC4 те же holding, что
// для большинства устройств совпадает, но для устройства с заполненными
// входами это неверно. Теперь у каждого пространства своя секция карты
// (`input`, `ireg`), а при её отсутствии - откат на прежнее поведение.
//
// У FC1 была та же ошибка, только хуже: ветки `coils` не было вовсе, и
// чтение катушек уходило в holding, отдавая чужие значения с тех же адресов.
// Заметно это было лишь до первой записи: записанная катушка лежит в
// `written` и читается верно, а остальные продолжали врать. Защита -
// selftest-coils.js.

function spaceOf(dev, space) {
  if (!dev) return null;
  if (space === 'input' && dev.input)  return 'input';
  if (space === 'ireg'  && dev.ireg)   return 'ireg';
  if (space === 'coils' && dev.coils)  return 'coils';
  if (space === 'input') return 'coils';
  return 'holding';
}

function spaceReg(dev, space, addr) {
  return findReg(dev, spaceOf(dev, space), addr);
}

// ------------------------------------------------------------ генераторы

function generate(gen) {
  const t = Date.now();
  switch (gen.type) {
    case 'const':
      return gen.value;
    case 'toggle':
      return Math.floor(t / gen.periodMs) % 2 === 1;
    case 'sine': {
      const span = gen.max - gen.min;
      const phase = (t % gen.periodMs) / gen.periodMs * 2 * Math.PI;
      return gen.min + span / 2 * (1 + Math.sin(phase));
    }
    case 'sineInt': {
      const span = gen.max - gen.min;
      const phase = (t % gen.periodMs) / gen.periodMs * 2 * Math.PI;
      return Math.round(gen.min + span / 2 * (1 + Math.sin(phase)));
    }
    case 'ramp': {
      const phase = (t % gen.periodMs) / gen.periodMs;
      return gen.min + (gen.max - gen.min) * phase;
    }
    case 'rand':
      return Math.round(gen.min + Math.random() * (gen.max - gen.min));
    default:
      return 0;
  }
}

// --------------------------------------------------------- доступ к данным

function findReg(dev, space, addr) {
  if (!dev || !dev[space]) return null;
  for (const reg of dev[space]) {
    if (reg.addr <= addr && addr < reg.addr + (reg.count || 1)) {
      return reg;
    }
  }
  return null;
}

// Значение регистра с учётом записанного извне.
function regValue(dev, space, addr) {
  const key = `${dev.id}:${space}:${addr}`;
  if (written.has(key)) return written.get(key);

  const real = spaceOf(dev, space);
  const reg = findReg(dev, real, addr);
  if (!reg) return 0;

  const offset = addr - reg.addr;
  const count = reg.count || 1;

  if (count === 1) {
    const v = generate(reg.gen);
    return reg.gen.type === 'toggle' ? (v ? 1 : 0) : Math.round(v);
  }

  const v = generate(reg.gen);
  const words = encodeWords(v, count, reg.signed === true, regtype.isFloat(reg));
  return words[offset];
}

// Кодирование числа в 16-битные регистры с учётом порядка слов и знаковости.
function encodeWords(value, count, signed, isFloat) {
  if (count === 1) {
    if (signed) return [toInt16(value) & 0xffff];
    return [Math.round(value) & 0xffff];
  }
  if (count === 2) {
    if (isFloat) {
      const buf = Buffer.alloc(4);
      buf.writeFloatBE(value, 0);
      const hi = buf.readUInt16BE(0);
      const lo = buf.readUInt16BE(2);
      return map.wordOrder === 'CDAB' ? [lo, hi] : [hi, lo];
    }
    // целое 32-битное: старшее слово по порядку карты
    let v = Math.trunc(value);
    if (v < 0) { v = 0x100000000 + v; }
    const hi = (v >>> 16) & 0xffff;
    const lo = v & 0xffff;
    return map.wordOrder === 'CDAB' ? [lo, hi] : [hi, lo];
  }
  if (count === 4) {
    // uint32 из 64-битного числа - для счётчиков часов и т.п.
    let v = Math.trunc(value);
    if (v < 0) { v = 0x100000000 + v; }
    const w = [(v >>> 24) & 0xffff, (v >>> 16) & 0xffff, (v >>> 8) & 0xffff, v & 0xffff];
    if (map.wordOrder === 'CDAB') return [w[1], w[0], w[3], w[2]];
    return w;
  }
  return [Math.round(value) & 0xffff];
}

function toInt16(value) {
  let v = Math.trunc(value);
  if (v > 32767) v = 32767;
  if (v < -32768) v = -32768;
  return v;
}

function coilValue(dev, space, addr) {
  const key = `${dev.id}:${space}:${addr}`;
  if (written.has(key)) return written.get(key) ? 1 : 0;
  const reg = findReg(dev, spaceOf(dev, space), addr);
  if (!reg) return 0;
  return generate(reg.gen) ? 1 : 0;
}

// ------------------------------------------------------------- протокол

const EX_ILLEGAL_FUNCTION = 0x01;
const EX_ILLEGAL_ADDRESS  = 0x02;
const EX_ILLEGAL_VALUE    = 0x03;

function exception(unit, fc, code) {
  const body = Buffer.from([fc | 0x80, code]);
  return frame(unit, body);
}

function frame(unit, pdu) {
  const head = Buffer.alloc(7);
  head.writeUInt16BE(0, 0);          // transaction id - заполняется при отправке
  head.writeUInt16BE(0, 2);          // protocol id
  head.writeUInt16BE(pdu.length + 1, 4);
  head.writeUInt8(unit, 6);
  return Buffer.concat([head, pdu]);
}

function handleRequest(unit, pdu) {
  const fc = pdu.readUInt8(0);
  const data = pdu.subarray(1);

  switch (fc) {
    case 1:   // Read Coils
    case 2: { // Read Discrete Inputs
      const addr = data.readUInt16BE(0);
      const qty = data.readUInt16BE(2);
      if (qty < 1 || qty > 2000) return exception(unit, fc, EX_ILLEGAL_VALUE);
      const dev = devices.get(unit);
      if (!dev) return exception(unit, fc, EX_ILLEGAL_ADDRESS);
      const space = (fc === 2) ? 'input' : 'coils';
      const bytes = Buffer.alloc(Math.ceil(qty / 8));
      for (let i = 0; i < qty; i++) {
        const bit = coilValue(dev, space, addr + i);
        if (bit) bytes[i >> 3] |= 1 << (i % 8);
      }
      const body = Buffer.concat([Buffer.from([fc, bytes.length]), bytes]);
      log('read', unit, `FC${fc} ${space} ${addr}..${addr + qty - 1}`);
      return frame(unit, body);
    }

    case 3:   // Read Holding Registers
    case 4: { // Read Input Registers
      const addr = data.readUInt16BE(0);
      const qty = data.readUInt16BE(2);
      if (qty < 1 || qty > 125) return exception(unit, fc, EX_ILLEGAL_VALUE);
      const dev = devices.get(unit);
      if (!dev) return exception(unit, fc, EX_ILLEGAL_ADDRESS);
      const space = (fc === 4) ? 'ireg' : 'holding';
      const bytes = Buffer.alloc(qty * 2);
      for (let i = 0; i < qty; i++) {
        bytes.writeUInt16BE(regValue(dev, space, addr + i) & 0xffff, i * 2);
      }
      const body = Buffer.concat([Buffer.from([fc, bytes.length]), bytes]);
      log('read', unit, `FC${fc} ${space} ${addr}..${addr + qty - 1}`);
      return frame(unit, body);
    }

    case 5: { // Write Single Coil
      const addr = data.readUInt16BE(0);
      const val = data.readUInt16BE(2);
      if (val !== 0x0000 && val !== 0xff00) return exception(unit, fc, EX_ILLEGAL_VALUE);
      const dev = devices.get(unit);
      if (!dev) return exception(unit, fc, EX_ILLEGAL_ADDRESS);
      written.set(`${unit}:coils:${addr}`, val === 0xff00);
      const reg = findReg(dev, 'coils', addr);
      log('write', unit, `FC5 coil ${addr} = ${val === 0xff00}` +
         (reg ? ` (${reg.name})` : ' (не описан в карте)'));
      return frame(unit, Buffer.from([fc]));
    }

    case 6: { // Write Single Register
      const addr = data.readUInt16BE(0);
      const val = data.readUInt16BE(2);
      const dev = devices.get(unit);
      if (!dev) return exception(unit, fc, EX_ILLEGAL_ADDRESS);
      written.set(`${unit}:holding:${addr}`, val);
      const reg = findReg(dev, 'holding', addr);
      log('write', unit, `FC6 holding ${addr} = ${val}` +
         (reg ? ` (${reg.name})` : ' (не описан в карте)'));
      return frame(unit, Buffer.from([fc]));
    }

    case 15: { // Write Multiple Coils
      const addr = data.readUInt16BE(0);
      const qty = data.readUInt16BE(2);
      const byteCount = data.readUInt8(4);
      const dev = devices.get(unit);
      if (!dev) return exception(unit, fc, EX_ILLEGAL_ADDRESS);
      for (let i = 0; i < qty; i++) {
        const byte = data.readUInt8(5 + (i >> 3));
        const bit = (byte >> (i % 8)) & 1;
        written.set(`${unit}:coils:${addr + i}`, bit === 1);
      }
      log('write', unit, `FC15 coils ${addr}..${addr + qty - 1} (${byteCount} байт)`);
      const body = Buffer.alloc(5);
      body.writeUInt8(fc, 0);
      body.writeUInt16BE(addr, 1);
      body.writeUInt16BE(qty, 3);
      return frame(unit, body);
    }

    case 16: { // Write Multiple Registers
      const addr = data.readUInt16BE(0);
      const qty = data.readUInt16BE(2);
      const byteCount = data.readUInt8(4);
      const dev = devices.get(unit);
      if (!dev) return exception(unit, fc, EX_ILLEGAL_ADDRESS);
      for (let i = 0; i < qty; i++) {
        const val = data.readUInt16BE(5 + i * 2);
        written.set(`${unit}:holding:${addr + i}`, val);
      }
      const reg = findReg(dev, 'holding', addr);
      log('write', unit, `FC16 holding ${addr}..${addr + qty - 1}` +
         (reg ? ` (${reg.name})` : ' (не описан в карте)'));
      const body = Buffer.alloc(5);
      body.writeUInt8(fc, 0);
      body.writeUInt16BE(addr, 1);
      body.writeUInt16BE(qty, 3);
      return frame(unit, body);
    }

    default:
      log('ошибка', unit, `неподдерживаемый FC ${fc}`);
      return exception(unit, fc, EX_ILLEGAL_FUNCTION);
  }
}

// ------------------------------------------------------------ транспорт

const server = net.createServer(sock => {
  let buf = Buffer.alloc(0);
  console.log(`[клиент] подключился ${sock.remoteAddress}:${sock.remotePort}`);

  sock.on('data', chunk => {
    buf = Buffer.concat([buf, chunk]);
    while (buf.length >= 7) {
      const len = buf.readUInt16BE(4);
      const total = 6 + len;
      if (buf.length < total) break;

      const transactionId = buf.readUInt16BE(0);
      const unit = buf.readUInt8(6);
      const pdu = buf.subarray(7, total);

      let response;
      try {
        response = handleRequest(unit, pdu);
      } catch (e) {
        console.error('[клиент] ошибка обработки:', e.message);
        response = exception(unit, pdu.readUInt8(0), EX_ILLEGAL_FUNCTION);
      }
      response.writeUInt16BE(transactionId, 0);
      sock.write(response);

      buf = buf.subarray(total);
    }
  });

  sock.on('close', () => console.log('[клиент] отключился'));
  sock.on('error', e => console.error('[клиент] ошибка:', e.message));
});

server.on('error', e => {
  if (e.code === 'EADDRINUSE') {
    console.error(
      '[сервер] порт ' + (map ? map.port : '?') + ' занят. ' +
      'Остановите GUI-эмулятор mtcpServerEmulator.'
    );
  } else {
    console.error('[сервер] ошибка:', e.message);
  }
  process.exit(1);
});

// ---------------------------------------------------------------- старт

if (loadMap('старт')) {
  server.listen(map.port, '0.0.0.0', () => {
    console.log(`[сервер] слушаю порт ${map.port}, устройств ${devices.size}`);
    console.log(`[сервер] правь ${MAP_FILE} - изменения подхватятся сами`);
  });
}

// Следим за картой: перезапуск сервера не требуется.
fs.watch(MAP_FILE, { persistent: true }, (evt, name) => {
  if (evt === 'change') {
    setTimeout(() => loadMap('файл изменён'), 150);
  }
});

let quiet = 0;
function log(kind, unit, text) {
  // Чтение идёт постоянно, поэтому оно не логируется unless VERBOSE
  if (kind === 'read' && !process.env.VERBOSE) return;
  console.log(`[${new Date().toLocaleTimeString()}] ${kind.padEnd(6)} slave ${unit}: ${text}`);
}