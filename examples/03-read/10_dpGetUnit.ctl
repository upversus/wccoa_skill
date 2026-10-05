// 10_dpGetUnit.ctl - чтение единицы измерения элемента.
//
// Документация: docs/03-read.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем:
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа и задаём единицу;
//   3) удаляем и точку данных, и тип.
//
// dpGetUnit(dp) возвращает единицу измерения элемента. При ошибке - пустая
// строка. Парная функция к dpSetUnit() из docs/02-config.md.
//
// ВАЖНО: единица - это langString, многоязычный текст. Функция возвращает
// строку активного языка.
//
// Проверено: CTL 3.18, проект prg_12_3.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "unit_t";
string DP  = "unitDp";

main()
{
  DebugN("=== dpGetUnit(): единица измерения ===");

  makeObjects();

  // ---------------------------------------------------------------------
  // 1. Элемент без единицы
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Элемент без единицы ---");

  string none = dpGetUnit(DP + ".fVal");
  DebugN("  fVal без единицы -> [", none, "]");
  dpdCheck(none == "", "без единицы возвращается пустая строка", none);

  // ---------------------------------------------------------------------
  // 2. Задаём единицу и читаем обратно
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Единица задана через dpSetUnit ---");

  int rc = dpSetUnit(DP + ".fVal", "Liter");
  DebugN("  dpSetUnit rc=", rc);

  string got = dpGetUnit(DP + ".fVal");
  DebugN("  dpGetUnit -> [", got, "]");
  dpdCheck(rc == 0, "dpSetUnit вернул rc=0", rc);
  dpdCheck(got == "Liter", "единица прочитана обратно", got);

  // ---------------------------------------------------------------------
  // 3. Единицы у разных элементов не зависят друг от друга
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Разные элементы ---");

  dpSetUnit(DP + ".iVal", "Grad");
  dpSetUnit(DP + ".sVal", "Text");

  string gi = dpGetUnit(DP + ".iVal");
  string gs = dpGetUnit(DP + ".sVal");
  string gb = dpGetUnit(DP + ".bVal");
  DebugN("  iVal -> [", gi, "]");
  DebugN("  sVal -> [", gs, "]");
  DebugN("  bVal -> [", gb, "]   (единица не задавалась)");

  dpdCheck(gi == "Grad", "iVal - Grad", gi);
  dpdCheck(gs == "Text", "sVal - Text", gs);
  dpdCheck(gb == "", "bVal без единицы пуст", gb);

  // ---------------------------------------------------------------------
  // 4. Перезапись единицы
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Перезапись ---");

  dpSetUnit(DP + ".fVal", "Bar");
  string again = dpGetUnit(DP + ".fVal");
  DebugN("  после повторного dpSetUnit(Bar) -> [", again, "]");
  dpdCheck(again == "Bar", "единица перезаписана", again);

  // ---------------------------------------------------------------------
  // 5. Ошибочные случаи
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Ошибочные случаи ---");

  string noDp = dpGetUnit("noSuchDp.fVal");
  DebugN("  несуществующая точка -> [", noDp, "]");
  dpdCheck(noDp == "", "несуществующая точка -> пустая строка", noDp);

  string noEl = dpGetUnit(DP + ".nosuch");
  DebugN("  несуществующий элемент -> [", noEl, "]");
  dpdCheck(noEl == "", "несуществующий элемент -> пустая строка", noEl);

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
  n[5] = makeDynString("", "sVal");    t[5] = makeDynInt(0, DPEL_STRING);
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