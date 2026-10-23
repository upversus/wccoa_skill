// selftest-coils.js - проверки чтения катушек по FC1.
//
// Самое важное здесь - источник данных. FC1 обязан читать секцию `coils`,
// а не `holding`. Раньше ветки `coils` в spaceOf() не было, и чтение
// катушек молча уходило в holding: клиент получал чужие значения с тех же
// адресов. Ошибка была почти незаметна, потому что на демо-карте катушки и
// holding описаны по одним адресам, а после записи значение берётся из
// `written` и читается правильно.
//
// Запуск:  node selftest-coils.js
// Код возврата: 0 - все ожидания совпали, 1 - есть провалы.
'use strict';

const net = require('net');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const SERVER = path.join(__dirname, 'server.js');

let pass = 0;
let fail = 0;

function eq(name, got, want) {
  const a = JSON.stringify(got);
  const b = JSON.stringify(want);
  if (a === b) {
    pass += 1;
    console.log(`  PASS  ${name}   ${a}`);
  } else {
    fail += 1;
    console.log(`  FAIL  ${name}   получено ${a}, ожидалось ${b}`);
  }
}

function freePort() {
  return new Promise((resolve, reject) => {
    const s = net.createServer();
    s.on('error', reject);
    s.listen(0, '127.0.0.1', () => {
      const p = s.address().port;
      s.close(() => resolve(p));
    });
  });
}

// ------------------------------------------------------------------ клиент

function request(port, fc, start, qty, bits) {
  return new Promise((resolve, reject) => {
    let pdu;
    if (fc === 5) {
      pdu = Buffer.alloc(5);
      pdu.writeUInt8(5, 0);
      pdu.writeUInt16BE(start, 1);
      pdu.writeUInt16BE(bits ? 0xff00 : 0x0000, 3);
    } else if (fc === 15) {
      const n = Math.ceil(bits.length / 8);
      pdu = Buffer.alloc(6 + n);
      pdu.writeUInt8(15, 0);
      pdu.writeUInt16BE(start, 1);
      pdu.writeUInt16BE(bits.length, 3);
      pdu.writeUInt8(n, 5);
      bits.forEach((b, i) => { if (b) pdu[6 + (i >> 3)] |= 1 << (i % 8); });
    } else {
      pdu = Buffer.alloc(5);
      pdu.writeUInt8(fc, 0);
      pdu.writeUInt16BE(start, 1);
      pdu.writeUInt16BE(qty, 3);
    }

    const head = Buffer.alloc(7);
    head.writeUInt16BE(1, 0);
    head.writeUInt16BE(0, 2);
    head.writeUInt16BE(pdu.length + 1, 4);
    head.writeUInt8(1, 6);

    const sock = net.connect(port, '127.0.0.1');
    let buf = Buffer.alloc(0);
    const timer = setTimeout(() => { sock.destroy(); reject(new Error('таймаут ответа')); }, 5000);

    sock.on('error', err => { clearTimeout(timer); reject(err); });
    sock.on('connect', () => sock.write(Buffer.concat([head, pdu])));
    sock.on('data', d => {
      buf = Buffer.concat([buf, d]);
      if (buf.length < 7) return;
      const len = buf.readUInt16BE(4);
      if (buf.length < 6 + len) return;

      clearTimeout(timer);
      sock.end();

      const rfc = buf.readUInt8(7);
      if (rfc & 0x80) {
        reject(new Error(`исключение fc=${rfc & 0x7f} код=${buf.readUInt8(8)}`));
        return;
      }
      if (fc === 1 || fc === 2) {
        const nbytes = buf.readUInt8(8);
        const data = buf.subarray(9, 9 + nbytes);
        const out = [];
        for (let i = 0; i < qty; i++) out.push((data[i >> 3] >> (i % 8)) & 1);
        resolve(out);
      } else if (fc === 3 || fc === 4) {
        const out = [];
        for (let i = 0; i < qty; i++) out.push(buf.readUInt16BE(9 + i * 2));
        resolve(out);
      } else {
        resolve([]);
      }
    });
  });
}

// ------------------------------------------------------------------ сервер

async function startServer(map) {
  const port = await freePort();
  map.port = port;

  const file = path.join(os.tmpdir(),
    'mbsim-coils-' + Math.random().toString(16).slice(2) + '.json');
  fs.writeFileSync(file, JSON.stringify(map, null, 2), 'utf8');

  const child = spawn(process.execPath, [SERVER], {
    env: { ...process.env, MODBUS_MAP: file },
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  let out = '';
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => { child.kill(); reject(new Error('сервер не поднялся: ' + out)); }, 5000);
    const done = () => { clearTimeout(timer); resolve(); };
    child.stdout.on('data', d => { out += d; if (out.includes('слушаю порт')) done(); });
    child.stderr.on('data', d => { out += d; });
    child.on('exit', code => { clearTimeout(timer); reject(new Error('сервер вышел ' + code + ': ' + out)); });
  });

  return {
    port,
    stop() {
      child.kill();
      try { fs.unlinkSync(file); } catch { /* файла может уже не быть */ }
    },
  };
}

const constBool = v => ({ type: 'const', value: v });
const constInt = v => ({ type: 'const', value: v });

// Карта устройства целиком, чтобы можно было задавать секции по необходимости.
function mapWith(sections) {
  const dev = { id: 1, name: 'Fixture' };
  Object.assign(dev, sections);
  return { wordOrder: 'CDAB', devices: [dev] };
}

(async () => {
  // 1. Главная регрессия: катушки и holding дают РАЗНУЮ картину.
  //    Если FC1 снова начнёт читать holding, ожидание развалится.
  console.log('--- FC1 обязан читать coils, а не holding ---');
  {
    const srv = await startServer(mapWith({
      coils: [
        { addr: 0, name: 'C0', gen: constBool(true) },
        { addr: 1, name: 'C1', gen: constBool(false) },
      ],
      holding: [
        { addr: 0, count: 1, name: 'H0', gen: constInt(0) },
        { addr: 1, count: 1, name: 'H1', gen: constInt(5) },
      ],
    }));
    try {
      eq('coils [TRUE,FALSE] при holding [0,5]',
        await request(srv.port, 1, 0, 2), [1, 0]);
    } finally { srv.stop(); }
  }

  // 2. Катушки без секции holding: раньше findReg возвращал null
  //    и все катушки читались как FALSE.
  console.log('--- катушки без holding ---');
  {
    const srv = await startServer(mapWith({
      coils: [
        { addr: 0, name: 'C0', gen: constBool(true) },
        { addr: 1, name: 'C1', gen: constBool(false) },
      ],
    }));
    try {
      eq('FC1 без секции holding', await request(srv.port, 1, 0, 2), [1, 0]);
    } finally { srv.stop(); }
  }

  // 3. Карта без катушек - осознанный откат на прежнее поведение.
  //    Если это когда-нибудь поменяют, тест обязан упасть и заставить
  //    принять решение, а не проглотить смену поведения.
  console.log('--- карта без coils: прежний откат на holding ---');
  {
    const srv = await startServer(mapWith({
      holding: [
        { addr: 0, count: 1, name: 'H0', gen: constInt(0) },
        { addr: 1, count: 1, name: 'H1', gen: constInt(7) },
      ],
    }));
    try {
      eq('FC1 без coils отдаёт holding', await request(srv.port, 1, 0, 2), [0, 1]);
    } finally { srv.stop(); }
  }

  // 4. Запись обязана быть видна при чтении - и одной катушкой, и пачкой.
  console.log('--- запись видна при чтении ---');
  {
    const srv = await startServer(mapWith({
      coils: [
        { addr: 0, name: 'C0', gen: constBool(false) },
        { addr: 1, name: 'C1', gen: constBool(false) },
        { addr: 2, name: 'C2', gen: constBool(false) },
      ],
      holding: [{ addr: 0, count: 1, name: 'H0', gen: constInt(9) }],
    }));
    try {
      await request(srv.port, 5, 1, 1, true);
      eq('FC5 записал катушку 1', await request(srv.port, 1, 0, 3), [0, 1, 0]);

      await request(srv.port, 15, 0, 3, [1, 0, 1]);
      eq('FC15 записал 0..2', await request(srv.port, 1, 0, 3), [1, 0, 1]);
    } finally { srv.stop(); }
  }

  // 5. Остальные пространства не должны поехать от правки FC1.
  console.log('--- FC2/FC3/FC4 читают свои секции ---');
  {
    const srv = await startServer(mapWith({
      coils: [{ addr: 0, name: 'C0', gen: constBool(false) }],
      input: [{ addr: 0, name: 'I0', gen: constBool(false) }],
      ireg: [{ addr: 0, count: 1, name: 'IR0', gen: constInt(111) }],
      holding: [{ addr: 0, count: 1, name: 'H0', gen: constInt(222) }],
    }));
    try {
      eq('FC2 input', await request(srv.port, 2, 0, 1), [0]);
      eq('FC3 holding', await request(srv.port, 3, 0, 1), [222]);
      eq('FC4 ireg', await request(srv.port, 4, 0, 1), [111]);
      eq('FC1 coils', await request(srv.port, 1, 0, 1), [0]);
    } finally { srv.stop(); }
  }

  console.log('');
  console.log(`ИТОГО: PASS=${pass} FAIL=${fail}`);
  process.exit(fail > 0 ? 1 : 0);
})().catch(err => {
  console.log('  ОШИБКА: ' + err.message);
  process.exit(1);
});