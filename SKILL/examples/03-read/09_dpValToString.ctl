// 09_dpValToString.ctl - форматирование значения по строке формата.
//
// Документация: docs/03-read.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем:
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа и настраиваем формат с единицей;
//   3) удаляем и точку данных, и тип.
//
// dpValToString(dp, val[, unit]) возвращает значение, отформатированное по
// строке формата элемента. Третий параметр - дописать ли единицу измерения.
// Максимальная длина результата - 1024 символа.
//
// ГЛАВНОЕ, что показано на стенде: значение сначала приводится к ТИПУ
// ЭЛЕМЕНТА, и только потом форматируется. Переданное значение как есть не
// выводится. Поэтому в int-элемент нельзя передать 1.23 и получить "1.23".
//
// Проверок соответствия формата типу значения НЕТ (см. docs/02-config.md,
// dpSetFormat).
//
// Проверено: CTL 3.18, проект <проект стенда>.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "fmt_t";
string DP  = "fmtDp";

main()
{
  DebugN("=== dpValToString(): значение по строке формата ===");

  makeObjects();

  // ---------------------------------------------------------------------
  // 1. Элемент со строкой формата и единицей
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Формат '%6.2f' и единица 'Liter' ---");

  // Строка формата и единица задаются БЕЗ завершающей точки в имени элемента.
  int rcF = dpSetFormat(DP + ".fVal", "%6.2f");
  int rcU = dpSetUnit(DP + ".fVal", "Liter");
  DebugN("  dpSetFormat rc=", rcF, "   dpSetUnit rc=", rcU);

  string f1 = dpValToString(DP + ".fVal", 1.23, FALSE);
  string f2 = dpValToString(DP + ".fVal", 1.23, TRUE);
  DebugN("  без единицы: '", f1, "'");
  DebugN("  с единицей: '", f2, "'");

  // "%6.2f" - ширина 6 символов, два знака после точки
  dpdCheck(f1 == "  1.23", "формат %6.2f без единицы", f1);
  dpdCheck(f2 == "  1.23 Liter", "формат %6.2f с единицей", f2);

  // ---------------------------------------------------------------------
  // 2. Разные значения
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Разные значения через тот же формат ---");

  DebugN("  1.5    -> ", q(dpValToString(DP + ".fVal", 1.5,   TRUE)));
  DebugN("  1234.5 -> ", q(dpValToString(DP + ".fVal", 1234.5, TRUE)));
  DebugN("  0.0    -> ", q(dpValToString(DP + ".fVal", 0.0,   TRUE)));
  DebugN("  -2.5   -> ", q(dpValToString(DP + ".fVal", -2.5,  TRUE)));

  // 1234.5 не помещается в ширину 6 - проверяем, что не обрезается
  string wide = dpValToString(DP + ".fVal", 1234.5, TRUE);
  dpdCheck(wide == "1234.50 Liter", "широкое значение не обрезано", wide);

  // ---------------------------------------------------------------------
  // 3. Значение приводится к типу элемента
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Значение приводится к типу элемента ---");
  DebugN("  ВАЖНО: сначала приведение к типу элемента, потом формат.");
  DebugN("  Переданное значение как есть НЕ выводится.");

  // Элемент iVal имеет тип int, передаём 1.23 - ожидаем приведение, а не "1.23"
  string noFmt = dpValToString(DP + ".iVal", 1.23, FALSE);
  DebugN("  iVal (int) без формата, передано 1.23 -> ", q(noFmt));
  dpdCheck(noFmt == "1", "int-элемент: 1.23 приведено к типу элемента", noFmt);

  // ---------------------------------------------------------------------
  // 4. Формат есть, единицы нет
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Формат есть, единицы нет ---");

  dpSetFormat(DP + ".iVal", "%.3f");
  string noUnit = dpValToString(DP + ".iVal", 1.23, TRUE);
  DebugN("  запрошена единица, её нет -> ", q(noUnit));
  DebugN("  Расхождение с разделом 3 (там было 1, здесь 0.000) - поведение");
  DebugN("  непоследовательное, поэтому фиксируем как измеренное, а не как правило.");
  dpdCheck(noUnit == "0.000", "int-элемент с форматом - фактически 0.000", noUnit);

  // ---------------------------------------------------------------------
  // 5. Типы значений
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Разные типы значений ---");

  string si = dpValToString(DP + ".iVal", 42,     FALSE);
  string sb = dpValToString(DP + ".bVal", TRUE,   FALSE);
  string ss = dpValToString(DP + ".sVal", "текст", TRUE);
  DebugN("  int    -> ", q(si));
  DebugN("  bool   -> ", q(sb));
  DebugN("  string -> ", q(ss));

  dpdCheck(si != "", "int форматируется", si);
  dpdCheck(sb == "TRUE", "bool без формата", sb);
  dpdCheck(ss == "текст", "string без формата", ss);

  // ---------------------------------------------------------------------
  // 6. Ошибочные случаи
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 6. Ошибочные случаи ---");
  DebugN("  Несуществующая точка даёт ПУСТУЮ СТРОКУ, а не само значение.");
  DebugN("  Значит пустой возврат - признак ошибки, а не «формата нет».");

  string badDp = dpValToString("noSuchDp.fVal", 1.23, FALSE);
  DebugN("  несуществующая точка -> ", q(badDp));
  dpdCheck(badDp == "", "несуществующая точка -> пустая строка", badDp);

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

// Оборачивает значение в кавычки для наглядности в выводе.
string q(string s)
{
  return "[" + s + "]";
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
  dpSet(DP + ".fVal", 1.23);
  dpSet(DP + ".iVal", 1);
  dpSet(DP + ".bVal", TRUE);
  dpSet(DP + ".sVal", "текст");
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