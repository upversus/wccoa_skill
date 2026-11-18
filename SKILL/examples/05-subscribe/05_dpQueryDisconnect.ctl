// 05_dpQueryDisconnect.ctl - dpQueryDisconnect(): снятие подписки на запрос.
//
// Документация: docs/05-subscribe.md#dpquerydisconnect
// Проверено: CTL 3.18, проект <проект стенда>
//
// ПРОТОКОЛ ПРОВЕРКИ. Пример самодостаточный: подписывается, сам пишет значения,
// ждёт колбэки в delay() и печатает сводку.
//
//   .\run-ctl.ps1 -Script .\05-subscribe\05_dpQueryDisconnect.ctl -Num 200
//
// Ожидаемая сводка: --- PASS= 19  FAIL= 0 ---
//
// ЧТО ЗДЕСЬ ГЛАВНОЕ.
//   * dpQueryDisconnect() снимает подписку по паре "колбэк + userData".
//     Один и тот же колбэк может быть зарегистрирован несколько раз с разным
//     userData; снятие одной регистрации не трогает остальные.
//   * Неверный userData - это ошибка: rc=-1 и запись в getLastError().
//   * После снятия подписки колбэк больше не вызывается.
//   * Ошибочный SQL-запрос при регистрации даёт rc=0, а не -1: ошибку надо
//     читать из getLastError() сразу после вызова.
//   * Несуществующий колбэк - это rc=-1 и "Function not defined".

int dpdPass = 0;
int dpdFail = 0;

string DPT = "qdis_t";
string A = "qdis_a";

int nShared = 0;
string lastUd = "";

main()
{
  DebugN("=== dpQueryDisconnect(): снятие подписки на запрос ===");
  teardown();

  makeType();
  makeDp(A);
  delay(1);

  string q = "SELECT '_online.._value' FROM 'qdis_*' WHERE _DPT = \"qdis_t\"";

  // -------------------------------------------------------------------
  // 1. Две регистрации одного колбэка с разным userData
  // -------------------------------------------------------------------
  int rc1 = dpQueryConnectSingle("onShared", FALSE, "U1", q);
  int rc2 = dpQueryConnectSingle("onShared", FALSE, "U2", q);
  dpdCheck(rc1 == 0 && rc2 == 0, "две регистрации вернули 0", rc1 * 100 + rc2);

  dpSetWait(A + ".value:_original.._value", 1.0);
  delay(2);
  dpdCheck(nShared == 2, "оба подписчика получили вызов", nShared);

  // -------------------------------------------------------------------
  // 2. Снимаем только U1 - U2 продолжает работать
  // -------------------------------------------------------------------
  int rcD1 = dpQueryDisconnect("onShared", "U1");
  dpdCheck(rcD1 == 0, "dpQueryDisconnect(U1) вернул 0", rcD1);

  int before = nShared;
  dpSetWait(A + ".value:_original.._value", 2.0);
  delay(2);
  dpdCheck(nShared == before + 1, "после снятия U1 остался один вызов",
           nShared - before);
  dpdCheck(lastUd == "U2", "вызов пришёл от оставшейся регистрации", lastUd);

  // -------------------------------------------------------------------
  // 3. Неверный userData - ошибка, подписка не снимается
  // -------------------------------------------------------------------
  int rcBad = dpQueryDisconnect("onShared", "BAD");
  dyn_errClass errBad = getLastError();
  dpdCheck(rcBad == -1, "неверный userData даёт rc=-1", rcBad);
  dpdCheck(dynlen(errBad) > 0, "ошибка неверного userData в getLastError()",
           errBad);

  // -------------------------------------------------------------------
  // 4. Снимаем U2 - вызовов больше нет
  // -------------------------------------------------------------------
  int rcD2 = dpQueryDisconnect("onShared", "U2");
  dpdCheck(rcD2 == 0, "dpQueryDisconnect(U2) вернул 0", rcD2);
  before = nShared;
  dpSetWait(A + ".value:_original.._value", 3.0);
  delay(2);
  dpdCheck(nShared == before, "после снятия обеих подписок вызовов нет",
           nShared - before);

  // -------------------------------------------------------------------
  // 5. Ошибки регистрации: запрос и колбэк
  // -------------------------------------------------------------------
  int rcQ = dpQueryConnectSingle("onShared", FALSE, "Q1", "SELEKT garbage");
  dyn_errClass errQ = getLastError();
  dpdCheck(rcQ == 0, "ошибочный запрос даёт rc=0", rcQ);
  dpdCheck(dynlen(errQ) > 0, "ошибка запроса в getLastError()", errQ);
  dpQueryDisconnect("onShared", "Q1");

  int rcM = dpQueryConnectSingle("noSuchCallback", FALSE, "M1", q);
  dyn_errClass errM = getLastError();
  dpdCheck(rcM == -1, "несуществующий колбэк даёт rc=-1", rcM);
  dpdCheck(dynlen(errM) > 0, "ошибка колбэка в getLastError()", errM);

  // -------------------------------------------------------------------
  // 6. После снятия можно подписаться снова
  // -------------------------------------------------------------------
  int rc3 = dpQueryConnectSingle("onShared", FALSE, "U3", q);
  dpdCheck(rc3 == 0, "повторная регистрация вернула 0", rc3);
  before = nShared;
  dpSetWait(A + ".value:_original.._value", 4.0);
  delay(2);
  dpdCheck(nShared == before + 1, "новая подписка получает вызов",
           nShared - before);
  dpdCheck(lastUd == "U3", "userData новой подписки", lastUd);

  dpQueryDisconnect("onShared", "U3");
  delay(1);
  dpdCheck(cleanup(), "временная точка и тип удалены", "");

  dpdSummary();
}

void onShared(string ud, dyn_dyn_anytype tab)
{
  nShared++;
  lastUd = ud;
  DebugN("  CB Shared #", nShared, " ud=", ud, " rows=", dynlen(tab));
}

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
  if (dpExists(A)) { dpDelete(A); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(A)) { break; }
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
