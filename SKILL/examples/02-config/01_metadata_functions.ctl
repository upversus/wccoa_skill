// 01_metadata_functions.ctl - алиас, единица, формат, описание.
//
// Проверяет пять функций на собственных объектах, не завися от примеров
// настройки адреса:
//     dpSetAlias()  /  dpGetAlias()
//     dpSetUnit()   /  dpGetUnit()
//     dpSetFormat() /  dpGetFormat()
//     dpSetDescription()  /  dpGetDescription()
//
// ВАЖНО, установлено опытом: и сеттеры, и геттеры принимают имя элемента
// БЕЗ завершающей точки. Документация требует точку у геттеров
// (dpGetAlias("Pump12.")), и это неверно - с точкой возвращается пусто,
// а dpGetDescription с точкой даёт "DP does not exist".
//
//     dpSetAlias("opcChk.iRamp4", "MB_Ramp4")   rc = 0
//     dpGetAlias("opcChk.iRamp4")               -> "MB_Ramp4"
//     dpGetAlias("opcChk.iRamp4.")              -> ""
//
// Остальные выводы с натуры:
//   * все восемь функций в CTL 3.18 существуют;
//   * с завершающей точкой сеттеры возвращают rc = -1;
//   * алиасы ищутся через dpNames("@алиас");
//   * getLastError() после успешной установки пуст.
//
// Проверено: CTL 3.18, проект <проект стенда>.
// Оставляет: тип metaDemo_t, точку данных metaDemo.

int OK_COUNT = 0;
int BAD_COUNT = 0;

main()
{
  DebugN("=== Алиас, единица, формат, описание ===");

  string dpt = "metaDemo_t";
  string dp  = "metaDemo";

  // ---- собственные объекты ----
  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);           types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "fVal");    types[2] = makeDynInt(0, DPEL_FLOAT);
  names[3] = makeDynString("", "iVal");    types[3] = makeDynInt(0, DPEL_INT);
  names[4] = makeDynString("", "bVal");    types[4] = makeDynInt(0, DPEL_BOOL);

  cleanUp(dp, dpt);
  int rcT = dpTypeCreate(names, types);
  int rcD = dpCreate(dp, dpt);
  DebugN("  тип ", dpt, " rc=", rcT, ", точка ", dp, " rc=", rcD);
  DebugN("  элементы: fVal (float), iVal (int), bVal (bool)");
  DebugN("");

  // ---------------------------------------------------------- dpSetAlias
  DebugN("--- dpSetAlias ---");
  checkSet(dpSetAlias(dp + ".fVal", "Meta_Flow"),    "алиас fVal -> Meta_Flow");
  checkSet(dpSetAlias(dp + ".iVal", "Meta_Level"),   "алиас iVal -> Meta_Level");
  checkSet(dpSetAlias(dp + ".bVal", "Meta_Flag"),    "алиас bVal -> Meta_Flag");

  DebugN("--- dpGetAlias ---");
  checkAlias(dp + ".fVal", "Meta_Flow");
  checkAlias(dp + ".iVal", "Meta_Level");
  checkAlias(dp + ".bVal", "Meta_Flag");

  DebugN("");
  DebugN("--- поиск по алиасу через dpNames ---");
  dyn_string found = dpNames("@Meta_Level");
  DebugN("  dpNames('@Meta_Level') -> ", dynlen(found), " шт.");
  for (int i = 1; i <= dynlen(found); i++) { DebugN("     ", found[i]); }
  if (dynlen(found) == 1) { pass("алиас находится через dpNames"); }
  else                    { fail("dpNames по алиасу вернул ", dynlen(found)); }

  // ----------------------------------------------------------- dpSetUnit
  DebugN("");
  DebugN("--- dpSetUnit ---");
  langString unitFlow = "m3/h";
  langString unitLvl  = "%";
  langString unitFlag = "";
  checkSet(dpSetUnit(dp + ".fVal", unitFlow), "единица fVal -> m3/h");
  checkSet(dpSetUnit(dp + ".iVal", unitLvl),  "единица iVal -> %");
  checkSet(dpSetUnit(dp + ".bVal", unitFlag), "единица bVal -> пусто");

  DebugN("--- dpGetUnit ---");
  checkUnit(dp + ".fVal", "m3/h");
  checkUnit(dp + ".iVal", "%");

  // --------------------------------------------------------- dpSetFormat
  DebugN("");
  DebugN("--- dpSetFormat ---");
  langString fmtFlow = "%8.3f";
  langString fmtLvl  = "%3d";
  langString fmtFlag = "";
  checkSet(dpSetFormat(dp + ".fVal", fmtFlow), "формат fVal -> %8.3f");
  checkSet(dpSetFormat(dp + ".iVal", fmtLvl),  "формат iVal -> %3d");
  checkSet(dpSetFormat(dp + ".bVal", fmtFlag), "формат bVal -> пусто");

  DebugN("--- dpGetFormat ---");
  checkFormat(dp + ".fVal", "%8.3f");
  checkFormat(dp + ".iVal", "%3d");

  // --------------------------------------------------- dpSetDescription
  DebugN("");
  DebugN("--- dpSetDescription ---");
  langString dFlow = "Расход";
  langString dLvl  = "Уровень";
  langString dFlag = "Признак";
  checkSet(dpSetDescription(dp + ".fVal", dFlow), "описание fVal -> Расход");
  checkSet(dpSetDescription(dp + ".iVal", dLvl),  "описание iVal -> Уровень");
  checkSet(dpSetDescription(dp + ".bVal", dFlag), "описание bVal -> Признак");

  DebugN("--- dpGetDescription ---");
  checkDesc(dp + ".fVal", "Расход");
  checkDesc(dp + ".iVal", "Уровень");
  checkDesc(dp + ".bVal", "Признак");

  DebugN("");
  DebugN("--- форма с завершающей точкой (документация требует её) ---");
  string aDot = dpGetAlias(dp + ".fVal.");
  DebugN("  dpGetAlias('", dp, ".fVal.') = '", aDot, "'  <- пусто, точка не нужна");

  DebugN("");
  DebugN("=== ИТОГ: успешно ", OK_COUNT, ", неудачно ", BAD_COUNT, " ===");
  DebugN("--- объекты оставлены в проекте ---");
}

// ============================================================ helpers

void pass(string what)
{
  OK_COUNT++;
  DebugN("  PASS  ", what);
}

void fail(string what, string extra)
{
  BAD_COUNT++;
  DebugN("  FAIL  ", what, " ", extra);
}

void checkSet(int rc, string what)
{
  if (rc == 0) { pass(what); } else { fail(what, " rc=" + rc); }
}

void checkAlias(string dpe, string expected)
{
  string got = dpGetAlias(dpe);
  if (got == expected) { pass("прочитано '", expected, "'"); }
  else                 { fail("ожидалось '", expected, "' получено '" + got + "'"); }
}

void checkUnit(string dpe, string expected)
{
  langString got = dpGetUnit(dpe);
  if (got == expected) { pass("прочитано '", expected, "'"); }
  else                 { fail("ожидалось '", expected, "'"); }
}

void checkFormat(string dpe, string expected)
{
  langString got = dpGetFormat(dpe);
  if (got == expected) { pass("прочитано '", expected, "'"); }
  else                 { fail("ожидалось '", expected, "'"); }
}

void checkDesc(string dpe, string expected)
{
  langString got = dpGetDescription(dpe);
  if (got == expected) { pass("прочитано '", expected, "'"); }
  else                 { fail("ожидалось '", expected, "'"); }
}

// Удаление с ожиданием: dpDelete асинхронен.
void cleanUp(string dp, string dpt)
{
  if (dpExists(dp)) { dpDelete(dp); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(dp)) { break; }
    delay(1);
  }
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    dyn_dyn_string pn;
    dyn_dyn_int pt;
    if (dpTypeGet(dpt, pn, pt) != 0) { break; }   // типа нет
    dpTypeDelete(dpt);
    delay(1);
  }
}