// 11_dpGetFormat.ctl - чтение строки формата элемента.
//
// Документация: docs/03-read.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем:
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа и задаём формат;
//   3) удаляем и точку данных, и тип.
//
// dpGetFormat(dp) возвращает строку формата элемента. При ошибке - пустая
// строка. Парная функция к dpSetFormat() из docs/02-config.md.
//
// Проверок соответствия формата типу значения нет: можно записать формат
// для float и применить к int, поведение не гарантировано.
//
// Проверено: CTL 3.18, проект prg_12_3.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "frm_t";
string DP  = "frmDp";

main()
{
  DebugN("=== dpGetFormat(): строка формата ===");

  makeObjects();

  // ---------------------------------------------------------------------
  // 1. Элемент без формата
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Элемент без формата ---");

  string none = dpGetFormat(DP + ".fVal");
  DebugN("  fVal без формата -> [", none, "]");
  dpdCheck(none == "", "без формата возвращается пустая строка", none);

  // ---------------------------------------------------------------------
  // 2. Задаём формат и читаем обратно
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Формат задан через dpSetFormat ---");

  int rc = dpSetFormat(DP + ".fVal", "%8.3f");
  DebugN("  dpSetFormat rc=", rc);

  string got = dpGetFormat(DP + ".fVal");
  DebugN("  dpGetFormat -> [", got, "]");
  dpdCheck(rc == 0, "dpSetFormat вернул rc=0", rc);
  dpdCheck(got == "%8.3f", "формат прочитан обратно без изменений", got);

  // ---------------------------------------------------------------------
  // 3. Форматы у разных элементов независимы
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Разные элементы ---");

  dpSetFormat(DP + ".iVal", "%d");
  dpSetFormat(DP + ".sVal", "%.1f mm");

  string gi = dpGetFormat(DP + ".iVal");
  string gs = dpGetFormat(DP + ".sVal");
  string gb = dpGetFormat(DP + ".bVal");
  DebugN("  iVal -> [", gi, "]");
  DebugN("  sVal -> [", gs, "]");
  DebugN("  bVal -> [", gb, "]   (формат не задавался)");

  dpdCheck(gi == "%d", "iVal - %d", gi);
  dpdCheck(gs == "%.1f mm", "sVal - %.1f mm", gs);
  dpdCheck(gb == "", "bVal без формата пуст", gb);

  // ---------------------------------------------------------------------
  // 4. Перезапись формата
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Перезапись ---");

  dpSetFormat(DP + ".fVal", "%.1f");
  string again = dpGetFormat(DP + ".fVal");
  DebugN("  после dpSetFormat(%.1f) -> [", again, "]");
  dpdCheck(again == "%.1f", "формат перезаписан", again);

  // ---------------------------------------------------------------------
  // 5. Формат и единица хранятся независимо
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Формат не зависит от единицы ---");

  dpSetUnit(DP + ".fVal", "Liter");
  string fmtWithUnit = dpGetFormat(DP + ".fVal");
  string unitNow     = dpGetUnit(DP + ".fVal");
  DebugN("  формат -> [", fmtWithUnit, "]   единица -> [", unitNow, "]");
  dpdCheck(fmtWithUnit == "%.1f", "формат не изменился от задания единицы", fmtWithUnit);
  dpdCheck(unitNow == "Liter", "единица прочитана", unitNow);

  // ---------------------------------------------------------------------
  // 6. Ошибочные случаи
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 6. Ошибочные случаи ---");

  string noDp = dpGetFormat("noSuchDp.fVal");
  DebugN("  несуществующая точка -> [", noDp, "]");
  dpdCheck(noDp == "", "несуществующая точка -> пустая строка", noDp);

  string noEl = dpGetFormat(DP + ".nosuch");
  DebugN("  несуществующий элемент -> [", noEl, "]");
  dpdCheck(noEl == "", "несуществующий элемент -> пустая строка", noEl);

  // ---------------------------------------------------------------------
  // 7. Уборка
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("(7) уборка");
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