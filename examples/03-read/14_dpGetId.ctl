// 14_dpGetId.ctl - числовые идентификаторы элемента точки данных.
//
// Документация: docs/03-read.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем:
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа;
//   3) удаляем и точку данных, и тип.
//
// dpGetId(dpName, &dpId, &elId) возвращает true, если DPE существует.
// При false значения dpId и elId НЕ ОПРЕДЕЛЕНЫ - читать их нельзя.
//
// Требования к dpName: без подстановок, разрешается до двоеточия,
// БЕЗ имени системы.
//
// Проверено: CTL 3.18, проект prg_12_3.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "id_t";
string DP  = "idDp";

main()
{
  DebugN("=== dpGetId(): числовые идентификаторы элемента ===");

  makeObjects();

  // ---------------------------------------------------------------------
  // 1. Корень точки данных
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Корень точки данных ---");

  unsigned rootId;
  int rootEl;
  bool okRoot = dpGetId(DP + ".", rootId, rootEl);
  DebugN("  dpGetId(\"", DP, ".\") = ", okRoot, "  dpId=", rootId, "  elId=", rootEl);
  dpdCheck(okRoot, "корень точки данных существует", okRoot);

  // ---------------------------------------------------------------------
  // 2. Элементы типа
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Элементы типа ---");

  unsigned fId;
  int fEl;
  bool okF = dpGetId(DP + ".fVal", fId, fEl);
  DebugN("  fVal  = ", okF, "  dpId=", fId, "  elId=", fEl);

  unsigned iId;
  int iEl;
  bool okI = dpGetId(DP + ".iVal", iId, iEl);
  DebugN("  iVal  = ", okI, "  dpId=", iId, "  elId=", iEl);

  unsigned bId;
  int bEl;
  bool okB = dpGetId(DP + ".bVal", bId, bEl);
  DebugN("  bVal  = ", okB, "  dpId=", bId, "  elId=", bEl);

  dpdCheck(okF && okI && okB, "все элементы найдены", okF);

  // У элементов одной точки dpId совпадает, а elId различается
  dpdCheck(fId == iId && iId == bId, "dpId у элементов одной точки совпадает",
           fId + " / " + iId + " / " + bId);
  dpdCheck(fEl != iEl && iEl != bEl, "elId у элементов различается",
           fEl + " / " + iEl + " / " + bEl);

  // ---------------------------------------------------------------------
  // 3. Идентификаторы не меняются при повторном чтении
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Повторное чтение ---");

  unsigned fId2;
  int fEl2;
  bool okF2 = dpGetId(DP + ".fVal", fId2, fEl2);
  DebugN("  второй вызов: ", okF2, "  dpId=", fId2, "  elId=", fEl2);
  dpdCheck(okF2 && (fId2 == fId) && (fEl2 == fEl),
           "идентификаторы устойчивы между вызовами",
           "было " + fId + "/" + fEl + ", стало " + fId2 + "/" + fEl2);

  // ---------------------------------------------------------------------
  // 4. Ошибочные случаи
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Ошибочные случаи ---");
  DebugN("  ВНИМАНИЕ: при false идентификаторы не определены - не читаем их.");

  unsigned badId;
  int badEl;
  bool okNoDp = dpGetId("noSuchDp.", badId, badEl);
  DebugN("  несуществующая точка   = ", okNoDp);
  dpdCheck(!okNoDp, "несуществующая точка -> false", okNoDp);

  bool okNoEl = dpGetId(DP + ".nosuch", badId, badEl);
  DebugN("  несуществующий элемент = ", okNoEl);
  dpdCheck(!okNoEl, "несуществующий элемент -> false", okNoEl);

  bool okEmpty = dpGetId("", badId, badEl);
  DebugN("  пустая строка          = ", okEmpty);
  dpdCheck(!okEmpty, "пустая строка -> false", okEmpty);

  // ---------------------------------------------------------------------
  // 5. Круг: идентификаторы -> имя обратно
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Круг через dpGetName ---");

  string back = dpGetName(fId, fEl);
  DebugN("  dpGetName(", fId, ", ", fEl, ") -> [", back, "]");
  dpdCheck(back != "", "dpGetName вернул имя", back);

  // ---------------------------------------------------------------------
  // 6. Уборка
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("(6) уборка");
  dropAll();
  dpdCheck(!dpExists(DP), "точка данных удалена", DP);
  dyn_dyn_string leftNames;
  dyn_dyn_int leftTypes;
  dpdCheck(dpTypeGet(DPT, leftNames, leftTypes) != 0, "тип удалён", DPT);

  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

void makeObjects()
{
  dropAll();

  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString(DPT);          t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "fVal");    t[2] = makeDynInt(0, DPEL_FLOAT);
  n[3] = makeDynString("", "iVal");    t[3] = makeDynInt(0, DPEL_INT);
  n[4] = makeDynString("", "bVal");    t[4] = makeDynInt(0, DPEL_BOOL);
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
  dpdCheck(dpCreate(DP, DPT) == 0, "точка данных создана", DP);
  delay(1);
  DebugN("  создана точка ", DP, " типа ", DPT);
}

void dropAll()
{
  dyn_string all = dpNames("*", DPT);
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpExists(all[i])) { dpDelete(all[i]); }
  }
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    if (dynlen(dpNames("*", DPT)) == 0) { break; }
    delay(1);
  }
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    dyn_dyn_string pn;
    dyn_dyn_int pt;
    if (dpTypeGet(DPT, pn, pt) != 0) { break; }
    dpTypeDelete(DPT);
    delay(1);
  }
}

void dpdCheck(bool ok, string what, dyn_anytype extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra, "  lastError=", getLastError()); }
}