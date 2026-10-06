// selftest-regtype.js - проверки классификации записи карты.
//
// Самое важное здесь - направление. Регистры хранения обязаны уметь быть
// записываемыми: без этого запись в уставку молча ничего не делает, при
// этом rc = 0, референс верный и данные идут.
//
// Запуск:  node selftest-regtype.js
// Код возврата: 0 - все ожидания совпали, 1 - есть провалы.
'use strict';

const { classify, DIRECTION } = require('./regtype.js');

let pass = 0;
let fail = 0;

function eq(name, got, want) {
  if (got === want) {
    pass += 1;
    console.log(`  PASS  ${name}   ${got}`);
  } else {
    fail += 1;
    console.log(`  FAIL  ${name}   получено ${got}, ожидалось ${want}`);
  }
}

console.log('--- направление по умолчанию ---');
eq('holding без флага -> только чтение',
  classify({ addr: 0, signed: false }, 'holding').direction, DIRECTION.POLL);
eq('ireg без флага -> только чтение',
  classify({ addr: 0, signed: true }, 'ireg').direction, DIRECTION.POLL);

console.log('--- направление по флагу writable ---');
eq('holding writable:true -> запись',
  classify({ addr: 0, signed: false, writable: true }, 'holding').direction,
  DIRECTION.IO);
eq('holding writable:false -> только чтение',
  classify({ addr: 0, signed: false, writable: false }, 'holding').direction,
  DIRECTION.POLL);

console.log('--- катушки не должны ломаться ---');
eq('coils всегда -> запись',
  classify({ addr: 0 }, 'coils').direction, DIRECTION.IO);
eq('coils writable:true -> то же',
  classify({ addr: 0, writable: true }, 'coils').direction, DIRECTION.IO);

console.log('--- флаг на пространстве только для чтения игнорируется ---');
// Валидатор такое отвергает отдельной проверкой; здесь классификатор
// обязан остаться в POLL, иначе получится read-only адрес с правом записи.
eq('input writable:true -> всё равно чтение',
  classify({ addr: 0, writable: true }, 'input').direction, DIRECTION.POLL);
eq('ireg writable:true -> всё равно чтение',
  classify({ addr: 0, signed: true, writable: true }, 'ireg').direction,
  DIRECTION.POLL);

console.log('--- типы не должны поехать от нового флага ---');
eq('writable не меняет datatype UINT16',
  classify({ addr: 0, signed: false, writable: true }, 'holding').datatype,
  classify({ addr: 0, signed: false }, 'holding').datatype);
eq('writable не меняет dpeType FLOAT',
  classify({ addr: 0, count: 2, writable: true }, 'holding').dpeType,
  classify({ addr: 0, count: 2 }, 'holding').dpeType);

console.log('');
console.log(`ИТОГО: PASS=${pass} FAIL=${fail}`);
process.exit(fail > 0 ? 1 : 0);