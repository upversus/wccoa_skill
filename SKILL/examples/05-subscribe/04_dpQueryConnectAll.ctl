// 04_dpQueryConnectAll.ctl - dpQueryConnectAll(): на каждое изменение приходит
// вся текущая выборка, а не только изменившиеся строки.
//
// Документация: docs/05-subscribe.md#dpqueryconnectall
// Проверено: CTL 3.18, проект <проект стенда>
//
// ПРОТОКОЛ ПРОВЕРКИ. Пример самодостаточный: подписывается, сам пишет значения,
// ждёт колбэки в delay() и печатает сводку.
//
//   .\run-ctl.ps1 -Script .\05-subscribe\04_dpQueryConnectAll.ctl -Num 200
//
// Ожидаемая сводка: --- PASS= 28  FAIL= 0 ---
//
// ЧТО ЗДЕСЬ ГЛАВНОЕ.
//   * All присылает ВСЮ выборку при каждом изменении: и изменившиеся строки,
//     и неизменившиеся. Поэтому по одному колбэку можно нарисовать полный срез.
//   * Уход значения из WHERE у All уведомляется: приходит таблица без этой
//     строки (в пределе - только заголовок).
//   * blockingTime склеивает несколько изменений в один вызов. Для All это
//     означает, что в одной таблице окажутся несколько полных снимков подряд,
//     с повторяющимися именами точек. Это не ошибка, а измеренное поведение.
//   * Для сравнения с Single см. 03_dpQueryConnectSingle.ctl.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "qall_t";
string A = "qall_a";
string B = "qall_b";
string C = "qall_c";

int nAll = 0;
int nFilter = 0;
int nBlock = 0;
dyn_dyn_anytype lastAll;
dyn_dyn_anytype lastFilter;
dyn_dyn_anytype lastBlock;

main()
{
  DebugN("=== dpQueryConnectAll(): вся выборка на каждое изменение ===");
  teardown();

  makeType();
  makeDp(A);
  makeDp(B);
  delay(1);

  string q = "SELECT '_online.._value' FROM 'qall_*' WHERE _DPT = \"qall_t\"";
  int rc = dpQueryConnectAll("onAll", TRUE, "A1", q);
  dpdCheck(rc == 0, "при регистрации rc=0", rc);

  delay(2);
  dpdCheck(nAll == 1, "answer=TRUE дал один вызов сразу", nAll);
  dpdCheck(dynlen(lastAll) == 3, "в снимке заголовок и две точки", dynlen(lastAll));

  // -------------------------------------------------------------------
  // 1. Изменилась одна точка - в таблице всё равно обе
  // -------------------------------------------------------------------
  dpSetWait(A + ".value:_original.._value", 10.0);
  delay(2);
  dpdCheck(nAll == 2, "изменение A дало второй вызов", nAll);
  dpdCheck(dynlen(lastAll) == 3, "All прислал всю выборку, а не одну строку",
           dynlen(lastAll));
  dpdCheck(hasRow(lastAll, B + ".value"),
           "неизменившаяся B тоже в таблице", lastAll);

  // -------------------------------------------------------------------
  // 2. Один dpSet на две точки - один вызов
  // -------------------------------------------------------------------
  dpSetWait(A + ".value:_original.._value", 20.0,
            B + ".value:_original.._value", 30.0);
  delay(2);
  dpdCheck(nAll == 3, "один dpSet дал один вызов", nAll);
  dpdCheck(rowValue(lastAll, A + ".value") == 20.0 &&
           rowValue(lastAll, B + ".value") == 30.0,
           "оба значения в одном снимке", lastAll);

  // -------------------------------------------------------------------
  // 3. Новая точка подхватывается и попадает в полную таблицу
  // -------------------------------------------------------------------
  int rcC = dpCreate(C, DPT);
  dpdCheck(rcC == 0, "новая точка C создана после подписки", rcC);
  delay(1);
  dpSetWait(C + ".value:_original.._value", 40.0);
  delay(2);
  dpdCheck(dynlen(lastAll) == 4, "в таблице A, B и C", dynlen(lastAll));
  dpdCheck(rowValue(lastAll, C + ".value") == 40.0,
           "значение C в полной таблице", rowValue(lastAll, C + ".value"));

  // -------------------------------------------------------------------
  // 4. Удалённая точка исчезает из следующей полной таблицы
  // -------------------------------------------------------------------
  int rcDel = dpDelete(B);
  dpdCheck(rcDel == 0, "точка B удалена", rcDel);
  delay(1);
  dpSetWait(A + ".value:_original.._value", 50.0);
  delay(2);
  dpdCheck(!hasRow(lastAll, B + ".value"),
           "удалённой B в таблице нет", lastAll);
  dpdCheck(dynlen(lastAll) == 3, "остались заголовок, A и C", dynlen(lastAll));

  // -------------------------------------------------------------------
  // 5. WHERE: All уведомляет и вход, и уход
  // -------------------------------------------------------------------
  string qf = "SELECT '_online.._value' FROM 'qall_*' WHERE _DPT = \"qall_t\" " +
              "AND '_online.._value' > 10";
  int rcF = dpQueryConnectAll("onFilter", TRUE, "F1", qf);
  dpdCheck(rcF == 0, "подписка All с WHERE зарегистрирована", rcF);
  delay(2);
  dpdCheck(nFilter == 1, "снимок по фильтру получен", nFilter);

  dpSetWait(A + ".value:_original.._value", 5.0);
  delay(2);
  dpdCheck(nFilter == 2, "All уведомил уход из WHERE", nFilter);
  dpdCheck(!hasRow(lastFilter, A + ".value"),
           "ушедшей A в таблице нет", lastFilter);

  dpSetWait(A + ".value:_original.._value", 60.0);
  delay(2);
  dpdCheck(nFilter == 3, "All уведомил вход в WHERE", nFilter);
  dpdCheck(rowValue(lastFilter, A + ".value") == 60.0,
           "вошедшая A в таблице", rowValue(lastFilter, A + ".value"));

  // -------------------------------------------------------------------
  // 6. blockingTime: несколько изменений в одном вызове
  // -------------------------------------------------------------------
  string qb = "SELECT '_online.._value' FROM 'qall_a.*' WHERE _DPT = \"qall_t\"";
  int rcB = dpQueryConnectAll("onBlock", FALSE, "B1", qb, 1500);
  dpdCheck(rcB == 0, "подписка с blockingTime=1500 зарегистрирована", rcB);
  delay(1);

  dpSetWait(A + ".value:_original.._value", 1.0);
  delay(0.5);
  dpSetWait(A + ".value:_original.._value", 2.0);
  delay(4);
  dpdCheck(nBlock == 1, "два изменения склеены в один вызов", nBlock);
  dpdCheck(dynlen(lastBlock) == 3,
           "в таблице заголовок и два снимка подряд", dynlen(lastBlock));
  dpdCheck(dynlen(lastBlock) >= 3 &&
           strpos((string)lastBlock[2][1], A) >= 0 &&
           strpos((string)lastBlock[3][1], A) >= 0,
           "в двух строках одна и та же точка", lastBlock);

  dpQueryDisconnect("onAll", "A1");
  dpQueryDisconnect("onFilter", "F1");
  dpQueryDisconnect("onBlock", "B1");
  delay(1);
  dpdCheck(cleanup(), "временные точки и тип удалены", "");

  dpdSummary();
}

// ---------------------------------------------------------------------------
// Колбэки.
// ---------------------------------------------------------------------------
void onAll(string ud, dyn_dyn_anytype tab)
{
  nAll++;
  lastAll = tab;
  DebugN("  CB All #", nAll, " ud=", ud, " rows=", dynlen(tab));
}

void onFilter(string ud, dyn_dyn_anytype tab)
{
  nFilter++;
  lastFilter = tab;
  DebugN("  CB Filter #", nFilter, " ud=", ud, " rows=", dynlen(tab));
}

void onBlock(string ud, dyn_dyn_anytype tab)
{
  nBlock++;
  lastBlock = tab;
  DebugN("  CB Block #", nBlock, " ud=", ud, " rows=", dynlen(tab));
}

// ---------------------------------------------------------------------------
// Разбор таблицы.
// ---------------------------------------------------------------------------
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
// Своя точка данных и тип.
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
