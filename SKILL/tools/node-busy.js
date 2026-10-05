// node-busy.js - проверка, не занят ли узел другой точкой данных.
//
// Зачем это отдельный модуль. Одному узлу нельзя соотнести две точки,
// и рантайм это не предотвращает: для Modbus в журнал пишется
// "SEVERE 47 Duplicate peripheral address", а для OPC UA на стенде
// 2026-10-05 всё прошло тихо - вторая точка создалась, rc = 0,
// _reference совпал, в журнале ни строки. Поймать это можно только
// заранее.
//
// Проверку выполняет не генератор, а сгенерированный CTL: генератор на Node
// не видит проект WinCC OA и не может знать, что уже настроено. Поэтому здесь
// только текст функций на CTL, который вставляется в выводимый скрипт.

'use strict';

// Литерал строки для CTL.
//
// В CTL строки пишутся ТОЛЬКО в двойных кавычках. Одинарные дают
// "Syntax error" на строке с присваиванием - проверено на CTL 3.18
// минимальным скриптом из 8 строк.
function ctlLit(s) {
  return '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
}

// Список строк для вставки в сгенерированный CTL.
//
// refList - массив строковых адресов, которые собираемся занять (уже полные).
// Он вставляется ОДИН раз, до создания точек, и проверяет все узлы сразу.
function freePrologue(refList, prefixExpr) {
  // В _reference хранится ПОЛНЫЙ адрес вида
  // "opc_ua_con$subs$1$1$ns=2;s=...", поэтому сравнивать с сырым NodeId
  // бессмысленно - конфликт не найдётся. Для Modbus префикс пуст,
  // адрес полный сразу.
  const px = prefixExpr || "";
  const L = [];
L.push('  // ---- проверка занятости узлов, до создания точек ----');
  L.push('  // Один узел нельзя соотнести с двумя точками, и рантайм это не');
  L.push('  // предотвращает: для Modbus пишет SEVERE 47 Duplicate peripheral');
  L.push('  // address, для OPC UA может не написать ничего. Возврата ошибки нет');
  L.push('  // ни в том, ни в другом случае, поэтому проверяем ДО создания.');
  L.push('  dyn_string busyRefs = makeDynString();');
  refList.forEach((a) => {
    L.push('  busyRefs[dynlen(busyRefs) + 1] = ' + ctlLit(a) + ';');
  });
  L.push('  int freeAll = 0;');
  L.push('  string busyAddr = "";');
  L.push('  string busyOwner = "";');
  L.push('  for (int bi = 1; bi <= dynlen(busyRefs); bi++)');
  L.push('  {');
  L.push('    // В _reference лежит полный адрес, сравниваем с префиксом.');
  L.push('    string want = ' + px + ' + busyRefs[bi];');
  L.push('    string own = nodeOwner("", want);');
  L.push('    if (own == "") { freeAll++; continue; }');
  L.push('    if (busyOwner == "") { busyOwner = own; busyAddr = want; }');
  L.push('    DebugN("  узел занят: ", want, "   владелец: ", own);');
  L.push('  }');
  L.push('  if (freeAll != dynlen(busyRefs))');
  L.push('  {');
  L.push('    chk(FALSE, "все узлы свободны",');
  L.push('        "свободно " + freeAll + " из " + dynlen(busyRefs));');
  L.push('    DebugN("  ПРЕКРАЩАЮ до создания точек. Первый занятый:");');
  L.push('    DebugN("    " + busyAddr + "  держит " + busyOwner);');
  L.push('    DebugN("  Освободи узел или убери этот сигнал из карты.");');
  L.push('    return;');
  L.push('  }');
  L.push('  chk(TRUE, "все узлы свободны", "проверено " + dynlen(busyRefs));');
  L.push('  // ------------------------------------------------------------------');
  L.push('');
  return L.join('\n');
}

// Функция nodeOwner, дописываемая в конец сгенерированного CTL.
const helperCtl = [
  '// Имена элементов точки верхнего уровня. Рецепт dpTypeGet взят',
  '// из проверенного allElems() генераторов.',
  'dyn_string elemsOf(string dp)',
  '{',
  '  dyn_string res = makeDynString();',
  '  string tpn = dpTypeName(dp + ".");',
  '  if (tpn == "") { return res; }',
  '  dyn_dyn_string nm; dyn_dyn_int ty;',
  '  if (dpTypeGet(tpn, nm, ty) != 0) { return res; }',
  '  for (int k = 2; k <= dynlen(nm); k++)',
  '  { res[dynlen(res) + 1] = dp + "." + nm[k][dynlen(nm[k])]; }',
  '  return res;',
  '}',
  '',
  '// Кто уже использует этот узел. Возвращает имя точки-владельца',
  '// или пустую строку, если узел свободен. Пустая myDp означает',
  '// "проверить все точки": конфликт ловится и с самой создаваемой точкой.',
  'string nodeOwner(string myDp, string reference)',
  '{',
  '  dyn_string all = dpNames("**");',
  '  for (int i = 1; i <= dynlen(all); i++)',
  '  {',
  '    string dp = all[i];',
  '    if (myDp != "" && dp == myDp) { continue; }',
  '    // Конфиг _address стоит либо на корне точки, либо на её',
  '    // элементах - генераторы ставят его на элементы. Смотрим оба.',
  '    dyn_string probes = makeDynString(dp);',
  '    dyn_string els = elemsOf(dp);',
  '    for (int e = 1; e <= dynlen(els); e++)',
  '    { probes[dynlen(probes) + 1] = els[e]; }',
  '    for (int p = 1; p <= dynlen(probes); p++)',
  '    {',
  '      string cfg = probes[p] + ":_address.._reference";',
  '      // dpExists проверяет наличие конфига БЕЗ предупреждения,',
  '      // а dpGet по отсутствующему конфигу пишет в журнал',
  '      // "DP does not exist" - и OA начинает подавлять вывод.',
  '      if (dpExists(cfg) == FALSE) { continue; }',
  '      string got;',
  '      if (dpGet(cfg, got) != 0) { continue; }',
  '      if (got == reference) { return dp; }',
  '    }',
  '  }',
  '  return "";',
  '}',
].join('\n');

module.exports = { freePrologue, helperCtl };
