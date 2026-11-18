// 03_dpQueryConnectSingle.ctl - dpQueryConnectSingle(): подписка по SQL-запросу,
// колбэк получает только изменившиеся строки.
//
// Документация: docs/05-subscribe.md#dpqueryconnectsingle
// Проверено: CTL 3.18, проект <проект стенда>
//
// ПРОТОКОЛ ПРОВЕРКИ. Пример самодостаточный: подписывается, сам пишет значения,
// ждёт колбэки в delay() и печатает сводку. Второй процесс не нужен.
//
//   .\run-ctl.ps1 -Script .\05-subscribe\03_dpQueryConnectSingle.ctl -Num 200
//
// Ожидаемая сводка: --- PASS= 29  FAIL= 0 ---
//
// ЧТО ЗДЕСЬ ГЛАВНОЕ.
//   * dpQueryConnectSingle() подписывается не на список DPE, а на SQL-запрос.
//     Новые точки подходящего типа подхватываются без переподписки.
//   * answer=TRUE даёт один вызов сразу при регистрации - с текущим срезом.
//     answer=FALSE не даёт ни одного вызова до первого изменения.
//   * В колбэк приходит таблица: строка 1 - заголовок, данные с строки 2.
//     В Single попадают ТОЛЬКО изменившиеся строки, а не вся выборка.
//   * Один dpSet() на несколько точек даёт ОДИН вызов с несколькими строками.
//   * Уход значения из WHERE у Single НЕ уведомляется: вызова не будет.
//   * dpQueryDisconnect() снимает подписку; после неё вызовов нет.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "qsub_t";
string A = "qsub_a";
string B = "qsub_b";
string C = "qsub_c";

int nSingle = 0;
int nFilter = 0;
dyn_dyn_anytype lastSingle;
dyn_dyn_anytype lastFilter;

main()
{
  DebugN("=== dpQueryConnectSingle(): подписка по SQL-запросу ===");
  teardown();

  makeType();
  makeDp(A);
  makeDp(B);
  delay(1);

  string q = "SELECT '_online.._value', '_online.._stime' FROM 'qsub_*' " +
             "WHERE _DPT = \"qsub_t\"";
  int rc = dpQueryConnectSingle("onSingle", TRUE, "S1", q);
  dpdCheck(rc == 0, "при регистрации rc=0", rc);

  delay(2);
  dpdCheck(nSingle == 1, "answer=TRUE дал один вызов сразу", nSingle);
  dpdCheck(dynlen(lastSingle) == 3, "в снимке заголовок и две точки", dynlen(lastSingle));
  dpdCheck(headerValue(lastSingle, 2) == ":_online.._value" &&
           headerValue(lastSingle, 3) == ":_online.._stime",
           "строка 1 - заголовки столбцов", lastSingle[1]);
  dpdCheck((string)lastSingle[1][1] == "",
           "tab[1][1] пуст, имя точки только в данных", lastSingle[1][1]);

  // -------------------------------------------------------------------
  // 1. Одна изменившаяся точка - одна строка данных
  // -------------------------------------------------------------------
  dpSetWait(A + ".value:_original.._value", 10.0);
  delay(2);
  dpdCheck(nSingle == 2, "изменение A дало второй вызов", nSingle);
  dpdCheck(dataRows(lastSingle) == 1, "в Single только изменившаяся строка",
           dataRows(lastSingle));
  dpdCheck(rowValue(lastSingle, A + ".value") == 10.0,
           "значение A в колбэке", rowValue(lastSingle, A + ".value"));

  // -------------------------------------------------------------------
  // 2. Один dpSet на две точки - один вызов с двумя строками
  // -------------------------------------------------------------------
  dpSetWait(A + ".value:_original.._value", 20.0,
            B + ".value:_original.._value", 30.0);
  delay(2);
  dpdCheck(nSingle == 3, "один dpSet дал один вызов", nSingle);
  dpdCheck(dataRows(lastSingle) == 2, "в вызове две изменившиеся строки",
           dataRows(lastSingle));
  dpdCheck(rowValue(lastSingle, A + ".value") == 20.0 &&
           rowValue(lastSingle, B + ".value") == 30.0,
           "оба новых значения на месте", lastSingle);

  // -------------------------------------------------------------------
  // 3. Новая точка того же типа подхватывается без переподписки
  // -------------------------------------------------------------------
  int rcC = dpCreate(C, DPT);
  dpdCheck(rcC == 0, "новая точка C создана после подписки", rcC);
  delay(1);
  dpSetWait(C + ".value:_original.._value", 40.0);
  delay(2);
  dpdCheck(rowValue(lastSingle, C + ".value") == 40.0,
           "новая точка C пришла в подписку", lastSingle);
  dpdCheck(dataRows(lastSingle) == 1,
           "Single прислал только новую строку C", dataRows(lastSingle));

  // -------------------------------------------------------------------
  // 4. Удаление точки: отдельного вызова нет, из следующего снимка она ушла
  // -------------------------------------------------------------------
  int beforeDel = nSingle;
  int rcDel = dpDelete(B);
  dpdCheck(rcDel == 0, "точка B удалена", rcDel);
  delay(1);
  dpdCheck(nSingle == beforeDel, "удаление само по себе колбэк не вызывает",
           nSingle - beforeDel);

  dpSetWait(A + ".value:_original.._value", 50.0);
  delay(2);
  dpdCheck(!hasRow(lastSingle, B + ".value"),
           "удалённой B в следующем снимке нет", lastSingle);
  dpdCheck(rowValue(lastSingle, A + ".value") == 50.0,
           "A=50 после удаления B", rowValue(lastSingle, A + ".value"));

  // -------------------------------------------------------------------
  // 5. WHERE: вход в фильтр уведомляется, уход - нет
  // -------------------------------------------------------------------
  string qf = "SELECT '_online.._value' FROM 'qsub_*' WHERE _DPT = \"qsub_t\" " +
              "AND '_online.._value' > 10";
  int rcF = dpQueryConnectSingle("onFilter", TRUE, "F1", qf);
  dpdCheck(rcF == 0, "подписка с WHERE зарегистрирована", rcF);
  delay(2);
  dpdCheck(nFilter == 1, "снимок по фильтру получен", nFilter);

  dpSetWait(A + ".value:_original.._value", 5.0);
  delay(2);
  dpdCheck(nFilter == 1, "уход из WHERE у Single не уведомляется", nFilter);

  dpSetWait(A + ".value:_original.._value", 60.0);
  delay(2);
  dpdCheck(nFilter == 2, "вход в WHERE уведомлён", nFilter);
  dpdCheck(rowValue(lastFilter, A + ".value") == 60.0,
           "значение вошедшей точки", rowValue(lastFilter, A + ".value"));

  // -------------------------------------------------------------------
  // 6. dpQueryDisconnect() останавливает подписку
  // -------------------------------------------------------------------
  int rcD = dpQueryDisconnect("onSingle", "S1");
  dpdCheck(rcD == 0, "dpQueryDisconnect вернул 0", rcD);
  int before = nSingle;
  dpSetWait(A + ".value:_original.._value", 70.0);
  delay(2);
  dpdCheck(nSingle == before, "после disconnect вызовов нет", nSingle - before);

  dpQueryDisconnect("onFilter", "F1");
  delay(1);
  dpdCheck(cleanup(), "временные точки и тип удалены", "");

  dpdSummary();
}

// ---------------------------------------------------------------------------
// Колбэки. userData - всегда первый параметр, таблица - второй.
// ---------------------------------------------------------------------------
void onSingle(string ud, dyn_dyn_anytype tab)
{
  nSingle++;
  lastSingle = tab;
  DebugN("  CB Single #", nSingle, " ud=", ud, " rows=", dynlen(tab));
}

void onFilter(string ud, dyn_dyn_anytype tab)
{
  nFilter++;
  lastFilter = tab;
  DebugN("  CB Filter #", nFilter, " ud=", ud, " rows=", dynlen(tab));
}

// ---------------------------------------------------------------------------
// Разбор таблицы. Строка 1 - заголовок, данные начинаются со строки 2.
// ---------------------------------------------------------------------------
int dataRows(dyn_dyn_anytype tab)
{
  if (dynlen(tab) < 2) { return 0; }
  return dynlen(tab) - 1;
}

string headerValue(dyn_dyn_anytype tab, int col)
{
  if (dynlen(tab) < 1 || dynlen(tab[1]) < col) { return ""; }
  return (string)tab[1][col];
}

float rowValue(dyn_dyn_anytype tab, string suffix)
{
  for (int r = 2; r <= dynlen(tab); r++)
  {
    if (strpos((string)tab[r][1], suffix) >= 0) { return (float)tab[r][2]; }
  }
  return -999.0;
}

bool hasRow(dyn_dyn_anytype tab, string suffix)
{
  for (int r = 2; r <= dynlen(tab); r++)
  {
    if (strpos((string)tab[r][1], suffix) >= 0) { return TRUE; }
  }
  return FALSE;
}

// ---------------------------------------------------------------------------
// Своя точка данных и тип: пример не зависит от демо-точек проекта.
// ---------------------------------------------------------------------------
void makeType()
{
  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString(DPT);          t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "value");  t[2] = makeDynInt(0, DPEL_FLOAT);
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
}

void makeDp(string dp)
{
  dpdCheck(dpCreate(dp, DPT) == 0, "точка создана", dp);
  dpSetWait(dp + ".value:_original.._value", 0.0);
}

bool cleanup()
{
  if (dpExists(C)) { dpDelete(C); }
  if (dpExists(B)) { dpDelete(B); }
  if (dpExists(A)) { dpDelete(A); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(A) && !dpExists(B) && !dpExists(C)) { break; }
    delay(1);
  }
  dyn_dyn_string pn;
  dyn_dyn_int pt;
  if (dpTypeGet(DPT, pn, pt) == 0) { dpTypeDelete(DPT); }
  for (int i = 1; i <= 30; i++)
  {
    if (dpTypeGet(DPT, pn, pt) != 0) { return TRUE; }
    delay(1);
  }
  return FALSE;
}

void teardown()
{
  if (dpExists(C)) { dpDelete(C); }
  if (dpExists(B)) { dpDelete(B); }
  if (dpExists(A)) { dpDelete(A); }
  delay(1);
  dyn_dyn_string pn;
  dyn_dyn_int pt;
  if (dpTypeGet(DPT, pn, pt) == 0)
  {
    dpTypeDelete(DPT);
    delay(1);
  }
}

void dpdCheck(bool ok, string what, dyn_anytype extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra, "  lastError=", getLastError()); }
}

void dpdSummary()
{
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
}
