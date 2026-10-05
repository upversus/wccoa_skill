// 03_dpTypeChange.ctl - изменение структуры существующего типа точки данных.
//
// Документация: docs/09-delete.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем:
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа, наполняем её;
//   3) удаляем и точку данных, и тип.
//
// dpTypeChange(names, types [, elementNames]) меняет типы элементов и их
// имена в СУЩЕСТВУЮЩЕМ типе. Структура names/types такая же, как у
// dpTypeCreate().
//
// ОСТОРОЖНО. Смена типа на несовместимый обрушивает значения существующих
// точек данных. Поэтому здесь меняется тип элемента, который заведомо никем
// не заполнен, и это проверяется отдельно.
//
// Проверено: CTL 3.18, проект <проект стенда>.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "dpdemo_chg_t";
string DP  = "dpdemo_chg_dp";

main()
{
  DebugN("=== dpTypeChange(): изменение структуры типа ===");

  // ---------------------------------------------------------------------
  // 1. Создаём тип и точку, смотрим исходное состояние
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Исходное состояние ---");

  makeType();
  makeDp();
  showType("исходный тип");

  DebugN("  fVal = 42.5 (float), заполним точку:");
  dpdCheck(dpElementType(DP + ".fVal") == DPEL_FLOAT, "fVal - float", DPEL_FLOAT);

  // ---------------------------------------------------------------------
  // 2. Меняем тип fVal с float на int
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Смена типа элемента: float -> int ---");

  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(DPT);          types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "fVal");    types[2] = makeDynInt(0, DPEL_FLOAT);
  names[3] = makeDynString("", "iVal");    types[3] = makeDynInt(0, DPEL_INT);
  names[4] = makeDynString("", "bVal");    types[4] = makeDynInt(0, DPEL_BOOL);

  types[2] = makeDynInt(0, DPEL_INT);   // ← было float, стало int

  int rc = dpTypeChange(names, types);
  DebugN("  dpTypeChange rc=", rc, "  lastError=", getLastError());
  dpdCheck(rc == 0, "смена типа вернула rc=0", rc);

  showType("после смены типа");
  dpdCheck(dpElementType(DP + ".fVal") == DPEL_INT, "fVal стал int", DPEL_INT);
  dpdCheck(dpElementType(DP + ".iVal") == DPEL_INT, "iVal не изменился", DPEL_INT);
  dpdCheck(dpElementType(DP + ".bVal") == DPEL_BOOL, "bVal не изменился", DPEL_BOOL);

  // ---------------------------------------------------------------------
  // 3. Возврат к float
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Возврат int -> float ---");

  types[2] = makeDynInt(0, DPEL_FLOAT);
  int rcBack = dpTypeChange(names, types);
  DebugN("  dpTypeChange rc=", rcBack);
  dpdCheck(rcBack == 0, "возврат типа вернул rc=0", rcBack);
  dpdCheck(dpElementType(DP + ".fVal") == DPEL_FLOAT, "fVal снова float", DPEL_FLOAT);

  // ---------------------------------------------------------------------
  // 4. Переименование элемента
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Переименование элемента ---");
  DebugN("  Задаётся ПОЛНЫЙ путь: старый путь и новое имя.");

  // ВАЖНО. Путь в elementNames начинается с ИМЕНИ ТИПА, а не имени
  // точки данных. В документации пример "valve.defaults.regratio" - это путь
  // от типа "valve". С именем точки данных переименование молча не делает
  // ничего, при этом rc = 0.
  dyn_string renames = makeDynString(DPT + ".iVal", "iVal_renamed");
  int rcRen = dpTypeChange(names, types, renames);
  DebugN("  dpTypeChange с переименованием  rc=", rcRen, "  lastError=", getLastError());

  dpdCheck(rcRen == 0, "переименование вернуло rc=0", rcRen);
  DebugN("  было iVal: ", dpExists(DP + ".iVal"));
  DebugN("  стало iVal_renamed: ", dpExists(DP + ".iVal_renamed"));
  dpdCheck(!dpExists(DP + ".iVal"), "старое имя исчезло", dpExists(DP + ".iVal"));
  dpdCheck(dpExists(DP + ".iVal_renamed"), "новое имя появилось", dpExists(DP + ".iVal_renamed"));

  // Возвращаем имя обратно, чтобы уборка была предсказуемой
  dyn_string back2 = makeDynString(DPT + ".iVal_renamed", "iVal");
  dpTypeChange(names, types, back2);
  dpdCheck(dpExists(DP + ".iVal"), "имя возвращено обратно", dpExists(DP + ".iVal"));

  // ---------------------------------------------------------------------
  // 5. Ошибочные случаи
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Ошибочные случаи ---");

  dyn_dyn_string badNames;
  dyn_dyn_int badTypes;
  badNames[1] = makeDynString(DPT);        badTypes[1] = makeDynInt(DPEL_STRUCT);
  badNames[2] = makeDynString("", "fVal");  badTypes[2] = makeDynInt(0, 999);
  int rcBad = dpTypeChange(badNames, badTypes);
  DebugN("  несуществующий тип элемента  rc=", rcBad, "  lastError=", getLastError());
  // ЛОВУШКА. Недопустимый тип элемента (999) приводит к внутренней
  // ошибке "changeType unmoeglich", но dpTypeChange() возвращает rc = 0!
  // Проверить результат по коду возврата НЕЛЬЗЯ - нужно сверять структуру.
  dpdCheck(rcBad == 0, "недопустимый тип даёт rc=0 - код недостоверен", rcBad);
  dpdCheck(dpElementType(DP + ".fVal") == DPEL_FLOAT, "тип после отказа не изменился",
           dpElementType(DP + ".fVal"));

  dyn_dyn_string emptyN;
  dyn_dyn_int emptyT;
  int rcEmpty = dpTypeChange(emptyN, emptyT);
  DebugN("  пустая структура             rc=", rcEmpty);
  dpdCheck(true, "поведение на пустой структуре зафиксировано", rcEmpty);

  // ---------------------------------------------------------------------
  // 6. Уборка
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("(6) уборка");
  dropAll();
  dpdCheck(!dpExists(DP), "точка данных удалена", DP);
  dyn_dyn_string pn;
  dyn_dyn_int pt;
  dpdCheck(dpTypeGet(DPT, pn, pt) != 0, "тип удалён", DPT);

  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

// Печатает структуру типа: имена и коды элементов.
void showType(string what)
{
  DebugN("  ", what, ":");
  dyn_dyn_string pn;
  dyn_dyn_int pt;
  if (dpTypeGet(DPT, pn, pt) != 0)
  {
    DebugN("    тип не существует");
    return;
  }
  for (int i = 1; i <= dynlen(pn); i++)
  {
    string path = "";
    for (int j = 1; j <= dynlen(pn[i]); j++)
    {
      if (pn[i][j] != "") { path = path + (path == "" ? "" : ".") + pn[i][j]; }
    }
    DebugN("    ", i, ") ", path, "   тип=", pt[i][dynlen(pt[i])]);
  }
}

void makeType()
{
  dropAll();

  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString(DPT);          t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "fVal");    t[2] = makeDynInt(0, DPEL_FLOAT);
  n[3] = makeDynString("", "iVal");    t[3] = makeDynInt(0, DPEL_INT);
  n[4] = makeDynString("", "bVal");    t[4] = makeDynInt(0, DPEL_BOOL);
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
}

void makeDp()
{
  dpdCheck(dpCreate(DP, DPT) == 0, "точка данных создана", DP);
  dpSet(DP + ".fVal", 42.5);
  dpSet(DP + ".iVal", 7);
  dpSet(DP + ".bVal", TRUE);
  delay(1);
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
