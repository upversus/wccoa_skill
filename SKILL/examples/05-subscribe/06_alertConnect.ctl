// 06_alertConnect.ctl - alertConnect(): подписка на события тревог.
//
// Документация: docs/05-subscribe.md#alertconnect
// Проверено: CTL 3.18, проект <проект стенда>
//
// ПРОТОКОЛ ПРОВЕРКИ. Пример самодостаточный: создаёт временные точки, сам
// взводит и квитирует тревоги, ждёт колбэки в delay() и печатает сводку.
// Второй процесс не нужен.
//
//   .\run-ctl.ps1 -Script .\05-subscribe\06_alertConnect.ctl -Num 200
//
// ЧТО ЗДЕСЬ ГЛАВНОЕ.
//   * alertConnect() подписывается не на точку, а на АТРИБУТ всех точек
//     системы: DPE в строке атрибута нужен только для проверки, фильтра он
//     не создаёт. Событие с чужой точки приходит в тот же колбэк.
//   * answer=TRUE (по умолчанию) даёт немедленный вызов с текущими тревогами
//     ВСЕЙ системы, answer=FALSE - только новые события.
//   * Колбэк: (time t, int count, string alert1, <type1> v1 [, string
//     alert2, <type2> v2 ...]). Для dyn_string - (time, count, dyn_string,
//     dyn_anytype).
//   * answer - параметр только alertConnect(); у alertDisconnect() его нет.
//     Лишний bool воспринимается как имя атрибута: rc=-1.
//   * Повторный alertConnect() с теми же work+атрибут НЕ заменяет подписку,
//     а добавляет вторую: колбэк вызывается дважды. Одна отписка снимает одну.
//   * `_alert_hdl.._act_state` и `_act_range` - атрибуты элемента, а не
//     экземпляра тревоги: подписка возвращает 0, но не срабатывает никогда.
//     Состояние тревоги смотрят через `_ack_state`, `_text`, `_visible`.
//   * Объектная форма требует указатель на метод (obj.method), имя метода
//     строкой даёт rc=-1 "Function not defined".
//   * Если нужен отбор по шаблону/классу/приоритету, alertConnect() - не лучший
//     инструмент: подписка на запрос с WHERE по '_alert_hdl.._class' фильтрует
//     на стороне Event Manager (блок 9).
//   * Как и dpConnect(), живая подписка не даёт менеджеру завершиться,
//     поэтому в конце всё отписывается.
//
// Между блоками точка пересоздаётся: так в ней не накапливаются старые
// тревоги и ответы answer=TRUE остаются предсказуемыми.

string DPA = "qalert05_a";
string DPB = "qalert05_b";

int dpdPass = 0;
int dpdFail = 0;

// --- счётчики и последние значения -------------------------------------
int nText = 0;  string lastTextName = ""; string lastTextValue = ""; int lastTextCount = -1;
int nTwo  = 0;  string twoN1 = ""; string twoV1 = "";
                string twoN2 = ""; string twoV2 = "";
int nAck  = 0;  int lastAck = -1;
int nAns  = 0;  int nAnsA = 0; string lastAnsName = "";
int nDup  = 0;
int nDyn  = 0;  int dynN = 0; int dynV = 0;
                string dynName1 = ""; string dynName2 = ""; string dynVal1 = "";
int nSilent = 0;
int nQuery = 0;      int lastQueryState = -1;
int nAlertQ = 0;     string lastAlertQText = "";

class Watcher
{
  public int n;
  public void onText(time t, int count, string a, anytype v)
  {
    if (strpos(a, "qalert05") < 0) { return; }
    n++;
    DebugN("  OBJ#", n, " count=", count, " a=", a, " v=", v);
  }
  public int hits() { return n; }
};

Watcher w;   // файловый scope обязателен

main()
{
  DebugN("=== alertConnect(): подписка на события тревог ===");
  teardown();

  string A = makeDp(DPA);
  string B = makeDp(DPB);
  if (A == "" || B == "")
  {
    dpdCheck(false, "временные точки созданы", "");
    dpdSummary();
    return;
  }
  dpdCheck(A != "" && B != "", "временные точки созданы", "");

  // =====================================================================
  // 1. answer=FALSE и область подписки
  // =====================================================================
  int rc1 = alertConnect("cbText", FALSE, A + ":_alert_hdl.._text");
  dpdCheck(rc1 == 0, "alertConnect(answer=FALSE) вернул 0", rc1);
  delay(1);
  dpdCheck(nText == 0, "answer=FALSE: сразу после подписки вызовов нет", nText);

  came(B);
  dpdCheck(nText == 1, "событие на ДРУГОЙ точке пришло в тот же колбэк", nText);
  dpdCheck(strpos(lastTextName, DPB) >= 0, "в имени атрибута - DPE B", lastTextName);
  dpdCheck(lastTextValue == "ALARM", "значение _text - ALARM", lastTextValue);
  dpdCheck(lastTextCount == 0, "count одиночной тревоги равен 0", lastTextCount);

  went(B);
  dpdCheck(nText == 2, "_text приходит и на уход тревоги", nText);

  dpdCheck(alertDisconnect("cbText", A + ":_alert_hdl.._text") == 0,
           "отписка вернула 0", "");

  int nAfterOff = nText;
  went(B);
  came(B);
  went(B);
  delay(1);
  dpdCheck(nText == nAfterOff, "после отписки вызовов нет", nText - nAfterOff);
  dropDp(DPB);          // B больше не нужна

  // =====================================================================
  // 2. Две строки-атрибута: пары имя/значение в одном колбэке
  // =====================================================================
  A = makeDp(DPA);      // чистая точка, без старых тревог
  int rc2 = alertConnect("cbTwo", FALSE,
             A + ":_alert_hdl.._text",
             A + ":_alert_hdl.._visible");
  dpdCheck(rc2 == 0, "подписка на два атрибута вернула 0", rc2);
  dpdCheck(nTwo == 0, "answer=FALSE и на два атрибута: сразу вызовов нет", nTwo);

  came(A);
  dpdCheck(nTwo == 1, "CAME даёт ОДИН вызов на оба атрибута", nTwo);
  dpdCheck(strpos(twoN1, "_text") >= 0 && strpos(twoN2, "_visible") >= 0,
           "имена атрибутов пришли по порядку", twoN1 + " | " + twoN2);
  dpdCheck(twoV1 == "ALARM", "первое значение - текст тревоги", twoV1);
  dpdCheck(twoV2 == "TRUE", "второе значение - _visible=TRUE", twoV2);

  went(A);
  dpdCheck(nTwo == 2, "WENT - ещё один вызов", nTwo);
  dpdCheck(twoV2 == "TRUE",
           "у неквитированной ушедшей тревоги _visible остаётся TRUE", twoV2);

  dpdCheck(alertDisconnect("cbTwo",
             A + ":_alert_hdl.._text",
             A + ":_alert_hdl.._visible") == 0, "отписка двух атрибутов вернула 0", "");

  // =====================================================================
  // 3. _ack_state: квитирование
  // =====================================================================
  A = makeDp(DPA);      // чистая точка: квитируется ровно одна тревога
  int rc3 = alertConnect("cbAck", FALSE, A + ":_alert_hdl.._ack_state");
  dpdCheck(rc3 == 0, "подписка на _ack_state вернула 0", rc3);

  came(A);
  dpdCheck(nAck == 1, "CAME даёт событие _ack_state", nAck);
  dpdCheck(lastAck == 0, "до квитирования _ack_state = 0", lastAck);

  bool acked = ackOne(A);
  int nAckAfterAck = nAck;
  dpdCheck(acked, "квитирование выполнено", "");
  dpdCheck(nAckAfterAck == 2, "квитирование даёт событие _ack_state", nAckAfterAck);
  dpdCheck(lastAck > 0, "после квитирования _ack_state > 0", lastAck);

  went(A);
  dpdCheck(nAck >= 3, "уход квитированной тревоги - ещё событие", nAck);
  dpdCheck(lastAck == 0, "после ухода _ack_state снова 0", lastAck);

  dpdCheck(alertDisconnect("cbAck", A + ":_alert_hdl.._ack_state") == 0,
           "отписка от _ack_state вернула 0", "");

  // =====================================================================
  // 4. answer=TRUE: немедленный вызов с текущей тревогой
  // =====================================================================
  A = makeDp(DPA);
  came(A);
  int rc4 = alertConnect("cbAns", TRUE, A + ":_alert_hdl.._text");
  dpdCheck(rc4 == 0, "alertConnect(answer=TRUE) вернул 0", rc4);
  delay(2);
  dpdCheck(nAnsA >= 1, "answer=TRUE: вызов сразу, без нового события", nAnsA);

  dpdCheck(alertDisconnect("cbAns", A + ":_alert_hdl.._text") == 0,
           "отписка answer=TRUE вернула 0", "");

  // =====================================================================
  // 5. Повторная подписка дублирует колбэк
  // =====================================================================
  A = makeDp(DPA);
  int rc5a = alertConnect("cbDup", FALSE, A + ":_alert_hdl.._text");
  int rc5b = alertConnect("cbDup", FALSE, A + ":_alert_hdl.._text");
  dpdCheck(rc5a == 0 && rc5b == 0, "две одинаковые подписки вернули 0", rc5a * 10 + rc5b);

  came(A);
  dpdCheck(nDup == 2, "CAME при двух подписках даёт ДВА вызова", nDup);

  dpdCheck(alertDisconnect("cbDup", A + ":_alert_hdl.._text") == 0,
           "одна отписка вернула 0", "");
  went(A);
  dpdCheck(nDup == 3, "после одной отписки остаётся один вызов", nDup - 2);

  dpdCheck(alertDisconnect("cbDup", A + ":_alert_hdl.._text") == 0,
           "вторая отписка вернула 0", "");
  int nBefore = nDup;
  came(A);
  went(A);
  dpdCheck(nDup == nBefore, "после двух отписок вызовов нет", nDup - nBefore);

  // =====================================================================
  // 6. dyn_string: массивы имён и значений
  // =====================================================================
  A = makeDp(DPA);
  dyn_string list = makeDynString(A + ":_alert_hdl.._text",
                                  A + ":_alert_hdl.._visible");
  int rc6 = alertConnect("cbDyn", FALSE, list);
  dpdCheck(rc6 == 0, "подписка через dyn_string вернула 0", rc6);

  came(A);
  dpdCheck(nDyn == 1, "dyn_string: один вызов на событие", nDyn);
  dpdCheck(dynN == 2 && dynV == 2, "в колбэке два имени и два значения", dynN * 10 + dynV);
  dpdCheck(strpos(dynName1, "_text") >= 0 && strpos(dynName2, "_visible") >= 0,
           "имена в dyn_string по порядку", dynName1 + " | " + dynName2);
  dpdCheck(dynVal1 == "ALARM", "первое значение - ALARM", dynVal1);

  dpdCheck(alertDisconnect("cbDyn", list) == 0, "отписка dyn_string вернула 0", "");

  // =====================================================================
  // 7. Объектная форма: указатель на метод, а не имя строкой
  // =====================================================================
  A = makeDp(DPA);
  string attrA = A + ":_alert_hdl.._text";
  int rc7 = alertConnect(w, w.onText, FALSE, attrA);
  dpdCheck(rc7 == 0, "объект + указатель на метод: rc=0", rc7);

  came(A);
  dpdCheck(w.hits() == 1, "метод класса получил событие", w.hits());

  dpdCheck(alertDisconnect(w, w.onText, attrA) == 0,
           "отписка объектной формы вернула 0", "");
  int hitsBefore = w.hits();
  went(A);
  dpdCheck(w.hits() == hitsBefore, "после отписки метод не вызывается", w.hits() - hitsBefore);

  int rc7b = alertConnect(w, "onText", FALSE, attrA);
  dyn_errClass err7 = getLastError();
  dpdCheck(rc7b == -1, "имя метода строкой даёт rc=-1", rc7b);
  dpdCheck(dynlen(err7) > 0, "ошибка имени метода в getLastError()", err7);

  // =====================================================================
  // 8. Ловушки: атрибуты, которые принимаются, но молчат
  // =====================================================================
  A = makeDp(DPA);
  int rc8a = alertConnect("cbSilent", FALSE, A + ":_alert_hdl.._act_state");
  int rc8b = alertConnect("cbSilent", FALSE, A + ":_original.._value");
  dpdCheck(rc8a == 0 && rc8b == 0, "_act_state и _original.._value приняты", rc8a * 10 + rc8b);

  came(A);
  went(A);
  delay(1);
  dpdCheck(nSilent == 0, "по ним не приходит ни одного события", nSilent);
  alertDisconnect("cbSilent", A + ":_alert_hdl.._act_state");
  alertDisconnect("cbSilent", A + ":_original.._value");

  int rc9 = alertConnect("cbText", FALSE, A + ":_alert_hdl.._nope");
  dyn_errClass err9 = getLastError();
  dpdCheck(rc9 == -1, "несуществующий атрибут даёт rc=-1", rc9);
  dpdCheck(dynlen(err9) > 0, "ошибка атрибута в getLastError()", err9);

  int rc10 = alertConnect("no_such_callback_xyz", FALSE, A + ":_alert_hdl.._text");
  dyn_errClass err10 = getLastError();
  dpdCheck(rc10 == -1, "несуществующий колбэк даёт rc=-1", rc10);
  dpdCheck(dynlen(err10) > 0, "ошибка колбэка в getLastError()", err10);

  // У alertDisconnect() нет параметра answer: лишний bool - это имя атрибута.
  // Причина видна в журнале (WARNING 71), getLastError() может остаться пустым.
  int rc11 = alertDisconnect("cbAck", FALSE, A + ":_alert_hdl.._text");
  dpdCheck(rc11 == -1, "лишний bool в alertDisconnect() даёт rc=-1", rc11);

  // =====================================================================
  // 9. Альтернатива для фильтра: dpQueryConnectSingle()
  // =====================================================================
  teardown();
  A = makeDp(DPA);              // точка с тревогой класса System1:alert.
  string B2 = makePlainDp(DPB); // та же DPT, но тревога не настроена

  string q = "SELECT '_alert_hdl.._act_state' FROM '" + DPA + "*' " +
             "WHERE '_alert_hdl.._class' = \"System1:alert.\"";
  int rcQ = dpQueryConnectSingle("cbQuery", FALSE, "s1", q);
  dpdCheck(rcQ == 0, "подписка на запрос с фильтром по классу: rc=0", rcQ);

  came(A);
  dpdCheck(nQuery == 1 && lastQueryState == 1,
           "CAME: в выборку попало _act_state=1", nQuery * 100 + lastQueryState);

  came(B2);
  dpdCheck(nQuery == 1, "точка без настроенной тревоги в выборку не попала", nQuery - 1);

  went(A);
  dpdCheck(nQuery == 2 && lastQueryState == 3,
           "WENT даёт _act_state=3", nQuery * 100 + lastQueryState);
  dpdCheck(dpQueryDisconnect("cbQuery", "s1") == 0, "отписка от запроса вернула 0", "");

  // SELECT ALERT: документация 3.21.6 относит форму к запрещённым в подписке,
  // на 3.18 она принимается и присылает тексты тревог.
  string qa = "SELECT ALERT '_alert_hdl.._text' FROM '" + DPA + "*'";
  int rcQA = dpQueryConnectSingle("cbAlertQuery", FALSE, "s2", qa);
  dpdCheck(rcQA == 0, "SELECT ALERT в подписке принят (rc=0)", rcQA);
  came(A);
  dpdCheck(nAlertQ == 1, "SELECT ALERT прислал событие тревоги", nAlertQ);
  dpdCheck(lastAlertQText == "ALARM", "в строке SELECT ALERT - текст тревоги", lastAlertQText);
  dpQueryDisconnect("cbAlertQuery", "s2");

  // =====================================================================
  // Уборка
  // =====================================================================
  teardown();
  dpdCheck(!dpExists(DPA) && !dpExists(DPB), "временные точки удалены", "");
  dpdSummary();
}

// =====================================================================
// Колбэки
// =====================================================================

void cbText(time t, int count, string a, anytype v)
{
  if (strpos(a, "qalert05") < 0) { return; }
  nText++;
  lastTextName = a;
  lastTextValue = (string)v;
  lastTextCount = count;
  DebugN("  TEXT#", nText, " count=", count, " ", a, " = ", v);
}

void cbTwo(time t, int count, string n1, anytype v1, string n2, anytype v2)
{
  if (strpos(n1, "qalert05") < 0) { return; }
  nTwo++;
  twoN1 = n1; twoV1 = (string)v1;
  twoN2 = n2; twoV2 = (string)v2;
  DebugN("  TWO#", nTwo, " ", n1, "=", v1, " ", n2, "=", v2);
}

void cbAck(time t, int count, string a, anytype v)
{
  if (strpos(a, "qalert05") < 0) { return; }
  nAck++;
  lastAck = (int)v;
  DebugN("  ACK#", nAck, " count=", count, " ", a, " = ", v);
}

void cbAns(time t, int count, string a, anytype v)
{
  if (strpos(a, "qalert05") < 0) { return; }
  nAns++;
  lastAnsName = a;
  if (strpos(a, DPA) >= 0) { nAnsA++; }
  DebugN("  ANS#", nAns, " count=", count, " ", a, " = ", v);
}

void cbDup(time t, int count, string a, anytype v)
{
  if (strpos(a, "qalert05") < 0) { return; }
  nDup++;
  DebugN("  DUP#", nDup, " ", a, " = ", v);
}

void cbDyn(time t, int count, dyn_string a, dyn_anytype v)
{
  if (dynlen(a) < 1 || strpos(a[1], "qalert05") < 0) { return; }
  nDyn++;
  dynN = dynlen(a);
  dynV = dynlen(v);
  dynName1 = a[1];
  dynName2 = a[2];
  dynVal1 = (string)v[1];
  DebugN("  DYN#", nDyn, " names=", dynN, " values=", dynV);
  for (int i = 1; i <= dynlen(a); i++) { DebugN("     ", a[i], " = ", v[i]); }
}

void cbSilent(time t, int count, string a, anytype v)
{
  if (strpos(a, "qalert05") < 0) { return; }
  nSilent++;
  DebugN("  SILENT#", nSilent, " ", a, " = ", v);
}

// Подписка на запрос: строки приходят таблицей, первая строка - заголовок.
void cbQuery(anytype userData, dyn_dyn_anytype tab)
{
  for (int r = 2; r <= dynlen(tab); r++)
  {
    if (strpos((string)tab[r][1], "qalert05") < 0) { continue; }
    nQuery++;
    lastQueryState = (int)tab[r][2];
    DebugN("  QUERY#", nQuery, " ", tab[r][1], " act_state=", lastQueryState);
  }
}

void cbAlertQuery(anytype userData, dyn_dyn_anytype tab)
{
  // SELECT ALERT: [DPE, время тревоги, запрошенные атрибуты...]
  for (int r = 2; r <= dynlen(tab); r++)
  {
    if (strpos((string)tab[r][1], "qalert05") < 0) { continue; }
    nAlertQ++;
    lastAlertQText = (string)tab[r][3];
    DebugN("  ALERTQ#", nAlertQ, " ", tab[r]);
  }
}

// =====================================================================
// Помощники тревог - эталон examples/_lib.ctl
// =====================================================================

string makeDp(string base)
{
  string dpe = base + ".b1";
  if (dpExists(base))
  {
    dpSet(dpe + ":_alert_hdl.._active", FALSE);
    delay(1);
    dpDelete(base);
    delay(1);
  }
  if (dpCreate(base, "ExampleDP_DDE") != 0 || !dpExists(base)) { return ""; }

  dpSetWait(dpe + ":_original.._value", FALSE);
  if (dpSetTimedWait(0,
      dpe + ":_alert_hdl.._active",   FALSE,
      dpe + ":_alert_hdl.._type",     DPCONFIG_ALERT_BINARYSIGNAL,
      dpe + ":_alert_hdl.._class",    "System1:alert.",
      dpe + ":_alert_hdl.._text0",    "OK",
      dpe + ":_alert_hdl.._text1",    "ALARM",
      dpe + ":_alert_hdl.._orig_hdl", TRUE) != 0) { return ""; }
  if (dpSetTimedWait(0, dpe + ":_alert_hdl.._active", TRUE) != 0) { return ""; }
  delay(0.5);
  return dpe;
}

// Точка без настроенной тревоги: та же DPT, но _alert_hdl не активирован.
string makePlainDp(string base)
{
  string dpe = base + ".b1";
  if (dpExists(base))
  {
    dpSet(dpe + ":_alert_hdl.._active", FALSE);
    delay(1);
    dpDelete(base);
    delay(1);
  }
  if (dpCreate(base, "ExampleDP_DDE") != 0 || !dpExists(base)) { return ""; }
  dpSetWait(dpe + ":_original.._value", FALSE);
  delay(0.5);
  return dpe;
}

void came(string dpe)
{
  dpSetWait(dpe + ":_original.._value", TRUE);
  delay(1);
}

void went(string dpe)
{
  dpSetWait(dpe + ":_original.._value", FALSE);
  delay(1);
}

void dropDp(string base)
{
  if (!dpExists(base)) { return; }
  dpSet(base + ".b1:_alert_hdl.._active", FALSE);
  delay(0.5);
  dpDelete(base);
  delay(0.5);
}

// Квитирует единственную тревогу на свежей точке (эталон 08-alerts).
bool ackOne(string dpe)
{
  dyn_atime al;
  if (dpGet(dpe + ":_alert_hdl.._alerts", al) != 0) { return false; }
  time t = 0;
  dpGet(dpe + ":_original.._stime", t);
  atime target = 0;
  for (int i = 1; i <= dynlen(al); i++)
  {
    dyn_anytype ob;
    if (alertGet(al[i], getACount(al[i]), dpe + ":_alert_hdl.._ack_oblig", ob) != 0) { continue; }
    if (dynlen(ob) == 1 && (bool)ob[1]) { target = al[i]; }
  }
  if (target == 0 || t == 0) { return false; }
  int rc = alertSet(t, getACount(target), dpe + ":_alert_hdl.._ack_state",
                    DPATTR_ACKTYPE_SINGLE);
  delay(1);
  return rc == 0;
}

void teardown()
{
  dyn_string bases = makeDynString(DPA, DPB);
  for (int i = 1; i <= dynlen(bases); i++) { dropDp(bases[i]); }
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
