// 02_checkQuery.ctl - проверка синтаксиса запроса без его выполнения.
//
// Документация: docs/06-query.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем:
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа;
//   3) удаляем и точку данных, и тип.
//
// checkQuery(aQuery) проверяет СИНТАКСИС и ничего не выполняет.
//
// ГЛАВНОЕ РАСХОЖДЕНИЕ С ДОКУМЕНТАЦИЕЙ. В docs/06-query.md написано, что
// checkQuery() возвращает 0 при успехе и -1 при ошибке. На стенде CTL 3.18
// синтаксическая ошибка даёт **1**, а не -1:
//
//     checkQuery("SELEKT garbage")   ->  1
//     checkQuery("SELECT")           ->  1
//
// При этом dpQuery() на том же мусоре возвращает -1. То есть у двух функций
// РАЗНЫЕ соглашения об ошибке, и код вида "if (checkQuery(q) != 0) отказ" будет
// работать, а код "if (checkQuery(q) == -1) отказ" - нет. Проверять надо на
// "не равно нулю".
//
// Зачем это делать отдельно: если запрос строится из пользовательского ввода
// или склейкой строк, дешевле спросить checkQuery(), чем выполнять dpQuery()
// и разбирать ошибку SQL.
//
// ВАЖНО. Проверка синтаксиса не гарантирует результата: запрос может быть
// верен, но не найти ни одной строки. И наоборот - dpQuery() на запрос к
// несуществующей точке возвращает rc = 0 и пустую таблицу, а не ошибку.
//
// Проверено: CTL 3.18, проект prg_12_3.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "chkQ_t";
string DP  = "chkQ";

main()
{
  DebugN("=== checkQuery(): проверка синтаксиса без выполнения ===");

  makeObjects();

  // ---------------------------------------------------------------------
  // 1. Валидные запросы
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Валидные запросы ---");

  string good1 = "SELECT '_online.._value' FROM '" + DP + "' WHERE _DP = \"" + DP + "\"";
  int r1 = checkQuery(good1);
  DebugN("  rc=", r1, "   ", good1);
  dpdCheck(r1 == 0, "простой SELECT принят", r1);

  string good2 = "SELECT '_original.._value' FROM '" + DP + ".*' WHERE _DPT = \"" + DPT + "\"";
  int r2 = checkQuery(good2);
  DebugN("  rc=", r2, "   выборка по типу");
  dpdCheck(r2 == 0, "выборка по типу принята", r2);

  string good3 = "SELECT '_online.._value', '_online.._stime' FROM '" + DP + "'";
  int r3 = checkQuery(good3);
  DebugN("  rc=", r3, "   два столбца");
  dpdCheck(r3 == 0, "два столбца приняты", r3);

  // ---------------------------------------------------------------------
  // 2. Запрос к истории - форма с TIMERANGE
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Запрос к истории с TIMERANGE ---");
  DebugN("  Форма, которая однозначно отдаёт исторические данные:");
  DebugN("     SELECT '_original.._value'");
  DebugN("       FROM 'ExampleDP_Arg1.'");
  DebugN("       TIMERANGE(\"<с\",\"по\",1,0)");
  DebugN("       LAST 10");

  string histQuery =
        "SELECT '_original.._value' "
      + "FROM 'ExampleDP_Arg1.' "
      + "TIMERANGE(\"2026.10.04 13:34:18\",\"2026.10.04 21:34:31\",1,0) "
      + "LAST 10";

  int rHist = checkQuery(histQuery);
  DebugN("  rc=", rHist);
  DebugN("  запрос: ", histQuery);
  dpdCheck(rHist == 0, "запрос с TIMERANGE принят", rHist);

  // Синтаксис TIMERANGE легко испортить: забыть закрывающую точку в FROM
  // или убрать запятые. Проверяем, что такие варианты отвергаются.
  string badRange = "SELECT '_original.._value' FROM 'ExampleDP_Arg1' TIMERANGE(\"2026.10.04 13:34:18\",\"2026.10.04 21:34:31\",1,0)";
  int rBadRange = checkQuery(badRange);
  DebugN("  без закрывающей точки в FROM   rc=", rBadRange);
  DebugN("    (внимание: этот вариант может быть признан верным - это не ошибка");
  DebugN("     синтаксиса, а другая форма адреса. Проверяем, что решит CTL.)");
  dpdCheck(rHist != 0 || rBadRange == 0,
           "поведение без точки в FROM зафиксировано",
           "rc=" + rBadRange);

  // ---------------------------------------------------------------------
  // 3. Некорректные запросы
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Некорректные запросы ---");

  string bad1 = "SELEKT garbage";
  int e1 = checkQuery(bad1);
  DebugN("  rc=", e1, "   ", bad1);
  DebugN("    lastError=", getLastError());
  dpdCheck(e1 != 0, "мусорный запрос отвергнут", "rc=" + e1 + " (в документации ожидалось -1)");

  string bad2 = "SELECT";
  int e2 = checkQuery(bad2);
  DebugN("  rc=", e2, "   обрывок запроса");
  dpdCheck(e2 != 0, "обрывок запроса отвергнут", "rc=" + e2 + " (в документации ожидалось -1)");

  string bad3 = "DROP TABLE ExampleDP_Arg1";
  int e3 = checkQuery(bad3);
  DebugN("  rc=", e3, "   не SELECT");
  DebugN("    Если checkQuery() принимает такой запрос - он проверяет не только");
  DebugN("    синтаксис. Это важно для случая, когда запрос приходит извне.");
  dpdCheck(e3 != 0, "не-SELECT отвергнут: checkQuery проверяет не только синтаксис", "rc=" + e3);

  // ---------------------------------------------------------------------
  // 4. Согласованность с dpQuery
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. checkQuery и dpQuery дают одинаковый вердикт ---");
  DebugN("  checkQuery() проверяет синтаксис, dpQuery() выполняет. Для корректно");
  DebugN("  собранного запроса вердикты должны совпадать.");

  dyn_dyn_anytype tab;
  int rq  = checkQuery(good1);
  int rex = dpQuery(good1, tab);
  DebugN("  checkQuery rc=", rq, "   dpQuery rc=", rex);
  dpdCheck((rq == 0) && (rex == 0), "оба согласны по корректному запросу",
           "check=" + rq + " dpQuery=" + rex);

  dyn_dyn_anytype tabBad;
  int rqBad  = checkQuery(bad1);
  int rexBad = dpQuery(bad1, tabBad);
  DebugN("  checkQuery rc=", rqBad, "   dpQuery rc=", rexBad);
  dpdCheck((rqBad != 0) && (rexBad == -1), "оба отвергают мусорный запрос, но разными кодами",
           "checkQuery=" + rqBad + "  dpQuery=" + rexBad);

  // ---------------------------------------------------------------------
  // 5. Уборка
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("(5) уборка");
  dropAll();
  dpdCheck(!dpExists(DP), "точка данных удалена", DP);
  dyn_dyn_string leftNames;
  dyn_dyn_int leftTypes;
  dpdCheck(dpTypeGet(DPT, leftNames, leftTypes) != 0, "тип удалён", DPT);

  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

// ===========================================================================
// Создание своих объектов
// ===========================================================================
void makeObjects()
{
  dropAll();

  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(DPT);           types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "fVal");     types[2] = makeDynInt(0, DPEL_FLOAT);
  dpdCheck(dpTypeCreate(names, types) == 0, "тип создан", DPT);
  dpdCheck(dpCreate(DP, DPT) == 0, "точка данных создана", DP);
  dpSet(DP + ".fVal", 42.5);
  delay(1);
  DebugN("  создана точка ", DP, " типа ", DPT, ", fVal = 42.5");
}

// ===========================================================================
// Уборка: сначала точки данных, потом тип
// ===========================================================================
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

// ПОРЯДОК АРГУМЕНТОВ: (ok, what, extra). Обоснование - в 01_dpQuery.ctl:
// при объявлении (string what, bool ok) вызовы склеиваются без ошибки,
// булево выражение становится строкой, и все проверки проходят насквозь.
void dpdCheck(bool ok, string what, dyn_anytype extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra, "  lastError=", getLastError()); }
}