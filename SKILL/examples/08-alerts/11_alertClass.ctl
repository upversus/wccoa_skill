// 11_alertClass.ctl - классы тревог _AlertClass: штатные, свой класс, _ack_type.
// Документация: docs/08-alerts.md#классы-тревог-_alertclass
// Проверено: CTL 3.18, проект <проект стенда>.
// Скрипт самодостаточен: создаёт временный класс и две временные точки,
// убирает за собой.
//
// Измеренные оговорки 3.18:
//   - dpCreate(name, "_AlertClass") создаёт точку, но конфиг _alert_class не
//     инициализирован: _type = 0, _prior = -1. Запись _prior без _type даёт -1
//     (PARAM,WARNING,9 Config does not exist).
//   - Сначала пишется только _type = DPCONFIG_ALERT_CLASS (14). После этого
//     появляются значения по умолчанию: _prior = 1, _abbr = "", _ack_type = 0,
//     _archive = TRUE.
//   - _act_prior читается штатным dpGet() и показывает приоритет класса
//     (10 / 50 / 60), а _alert_hdl.._prior у диапазонной тревоги равен -1.
//   - _ack_state базового атрибута (:_alert_hdl.._ack_state) для диапазонной
//     тревоги принимается с rc = 0 и ничего не меняет. Квитирует только
//     атрибут с номером диапазона: :_alert_hdl.<N>._ack_state.

int dpdPass = 0;
int dpdFail = 0;

void dpdCheck(string what, bool ok)
{
  if (ok) { dpdPass++;  DebugN("  PASS  ", what); }
  else    { dpdFail++;  DebugN("  FAIL  ", what, "  lastError=", getLastError()); }
}

void dpdSummary()
{
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
}

// ===========================================================================
// Помощники
// ===========================================================================

// Ждёт нужный _act_state (тревога обрабатывается асинхронно).
void waitState(string dpe, int expect, string what)
{
  int ast = -1;
  for (int i = 1; i <= 50; i++)
  {
    dpGet(dpe + ":_alert_hdl.._act_state", ast);
    if (ast == expect) { break; }
    delay(0.1);
  }
  dpdCheck(what + ": _act_state == " + (string)expect, ast == expect);
}

void waitRange(string dpe, int expect, string what)
{
  int ar = -1;
  for (int i = 1; i <= 50; i++)
  {
    dpGet(dpe + ":_alert_hdl.._act_range", ar);
    if (ar == expect) { break; }
    delay(0.1);
  }
  dpdCheck(what + ": _act_range == " + (string)expect, ar == expect);
}

int actPrior(string dpe)
{
  int p = -1;
  dpGet(dpe + ":_alert_hdl.._act_prior", p);
  return p;
}

int alertCount(string dpe)
{
  dyn_atime al;
  dpGet(dpe + ":_alert_hdl.._alerts", al);
  return dynlen(al);
}

// Запись WENT отличается от CAME заполненным _gone_time.
bool isWentRecord(string dpe, int range, atime a)
{
  dyn_anytype gt;
  if (alertGet(a, getACount(a), dpe + ":_alert_hdl." + (string)range + "._gone_time", gt) != 0)
  {
    return false;
  }
  return dynlen(gt) == 1 && (time)gt[1] != 0;
}

// atime нужной стороны: came = TRUE ищет CAME, came = FALSE ищет WENT.
// Берутся только неквитированные записи: CAME — первая, WENT — последняя
// (запись WENT добавляется после CAME).
atime findSide(string dpe, int range, bool came)
{
  dyn_atime al;
  if (dpGet(dpe + ":_alert_hdl.._alerts", al) != 0)
  {
    return 0;
  }
  atime result = 0;
  for (int i = 1; i <= dynlen(al); i++)
  {
    dyn_anytype st;
    if (alertGet(al[i], getACount(al[i]),
                 dpe + ":_alert_hdl." + (string)range + "._ack_state", st) != 0)
    {
      continue;
    }
    if (dynlen(st) != 1 || (int)st[1] != 0) { continue; }   // уже квитирована
    bool isWent = isWentRecord(dpe, range, al[i]);
    if (isWent == came) { continue; }                        // нужна другая сторона
    if (came)
    {
      return al[i];
    }
    result = al[i];
  }
  return result;
}

// Квитирует сторону по номеру диапазона.
// Возврат: rc alertSet; -2 — сторона не найдена; -3 — нулевая дата.
int ackSide(string dpe, int range, bool came)
{
  atime a = findSide(dpe, range, came);
  if (a == 0)
  {
    return -2;
  }
  time t = (time)a;                 // время тревоги; нулевая дата недопустима
  if (t == 0)
  {
    return -3;
  }
  return alertSet(t, getACount(a), dpe + ":_alert_hdl." + (string)range + "._ack_state",
                  DPATTR_ACKTYPE_SINGLE);
}

// Точка с тремя диапазонами: 1 — норма, 2 — середина, 3 — авария.
int configure3(string dpe, string midClass)
{
  dpSetWait(dpe + ":_alert_hdl.._active", FALSE);
  int rc = dpSetWait(
    dpe + ":_alert_hdl.._type",     DPCONFIG_ALERT_NONBINARYSIGNAL,
    dpe + ":_alert_hdl.._orig_hdl", TRUE,
    dpe + ":_alert_hdl.1._type",    DPDETAIL_RANGETYPE_MINMAX,
    dpe + ":_alert_hdl.1._l_limit", 0,
    dpe + ":_alert_hdl.1._u_limit", 20,
    dpe + ":_alert_hdl.1._l_incl",  TRUE,
    dpe + ":_alert_hdl.1._u_incl",  FALSE,
    dpe + ":_alert_hdl.1._class",   "",
    dpe + ":_alert_hdl.1._text",    "OK",
    dpe + ":_alert_hdl.2._type",    DPDETAIL_RANGETYPE_MINMAX,
    dpe + ":_alert_hdl.2._l_limit", 20,
    dpe + ":_alert_hdl.2._u_limit", 30,
    dpe + ":_alert_hdl.2._l_incl",  TRUE,
    dpe + ":_alert_hdl.2._u_incl",  FALSE,
    dpe + ":_alert_hdl.2._class",   midClass,
    dpe + ":_alert_hdl.2._text",    "MID",
    dpe + ":_alert_hdl.3._type",    DPDETAIL_RANGETYPE_MINMAX,
    dpe + ":_alert_hdl.3._l_limit", 30,
    dpe + ":_alert_hdl.3._u_limit", maxINT(),
    dpe + ":_alert_hdl.3._l_incl",  TRUE,
    dpe + ":_alert_hdl.3._u_incl",  TRUE,
    dpe + ":_alert_hdl.3._class",   "System1:alert.",
    dpe + ":_alert_hdl.3._text",    "ALARM");
  if (rc != 0) { return rc; }
  return dpSetWait(dpe + ":_alert_hdl.._active", TRUE);
}

// Точка с двумя диапазонами: 1 — норма, 2 — авария с указанным классом.
int configure2(string dpe, string cls)
{
  dpSetWait(dpe + ":_alert_hdl.._active", FALSE);
  int rc = dpSetWait(
    dpe + ":_alert_hdl.._type",     DPCONFIG_ALERT_NONBINARYSIGNAL,
    dpe + ":_alert_hdl.._orig_hdl", TRUE,
    dpe + ":_alert_hdl.1._type",    DPDETAIL_RANGETYPE_MINMAX,
    dpe + ":_alert_hdl.1._l_limit", 0,
    dpe + ":_alert_hdl.1._u_limit", 20,
    dpe + ":_alert_hdl.1._l_incl",  TRUE,
    dpe + ":_alert_hdl.1._u_incl",  FALSE,
    dpe + ":_alert_hdl.1._class",   "",
    dpe + ":_alert_hdl.1._text",    "OK",
    dpe + ":_alert_hdl.2._type",    DPDETAIL_RANGETYPE_MINMAX,
    dpe + ":_alert_hdl.2._l_limit", 20,
    dpe + ":_alert_hdl.2._u_limit", maxINT(),
    dpe + ":_alert_hdl.2._l_incl",  TRUE,
    dpe + ":_alert_hdl.2._u_incl",  TRUE,
    dpe + ":_alert_hdl.2._class",   cls,
    dpe + ":_alert_hdl.2._text",    "ALARM");
  if (rc != 0) { return rc; }
  return dpSetWait(dpe + ":_alert_hdl.._active", TRUE);
}

void setv(string dpe, int v)
{
  dpSetWait(dpe + ":_original.._value", v);
  delay(0.5);
}

// Создаёт временную точку с типом struct + int value.
bool makePoint(string base, string dpt, dyn_dyn_string &typeNames, dyn_dyn_int &typeTypes)
{
  if (dpExists(base))
  {
    dpSet(base + ".value:_alert_hdl.._active", FALSE);
    delay(0.5);
    dpDelete(base);
  }
  if (dpTypeGet(dpt, typeNames, typeTypes) == 0)
  {
    dpTypeDelete(dpt);
    delay(0.5);
  }
  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString(dpt);           t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "value");   t[2] = makeDynInt(0, DPEL_INT);
  if (dpTypeCreate(n, t) != 0) { return false; }
  if (dpCreate(base, dpt) != 0 || !dpExists(base)) { return false; }
  dpSetWait(base + ".value:_original.._value", 10);
  return true;
}

// ===========================================================================
// Пример
// ===========================================================================
main()
{
  DebugN("=== классы тревог _AlertClass ===");

  dyn_dyn_string typeNames;
  dyn_dyn_int typeTypes;
  if (dpTypeGet("_AlertClass", typeNames, typeTypes) != 0)
  {
    DebugN("  SKIP  в проекте нет типа _AlertClass");
    dpdSummary();
    exit(0);
  }

  int infoAck = -1, alertAck = -1, infoPrior = -1, alertPrior = -1;
  if (dpGet("System1:information.:_alert_class.._ack_type", infoAck) != 0 ||
      dpGet("System1:alert.:_alert_class.._ack_type", alertAck) != 0)
  {
    DebugN("  SKIP  нет штатных классов System1:information. / System1:alert.");
    dpdSummary();
    exit(0);
  }
  dpGet("System1:information.:_alert_class.._prior", infoPrior);
  dpGet("System1:alert.:_alert_class.._prior", alertPrior);

  // --- 1. Штатные классы ---------------------------------------------------
  dyn_string classes = dpNames("*", "_AlertClass");
  DebugN("  классов _AlertClass в проекте: ", dynlen(classes), " ", classes);
  dpdCheck("dpNames(*, _AlertClass) находит штатные классы", dynlen(classes) >= 7);
  dpdCheck("System1:information. — без квитирования (_ack_type=1)", infoAck == 1);
  dpdCheck("System1:alert. — квитирование пары (_ack_type=3)", alertAck == 3);
  dpdCheck("приоритет information = 10", infoPrior == 10);
  dpdCheck("приоритет alert = 60", alertPrior == 60);

  // --- 2. Свой класс -------------------------------------------------------
  string clsBase = "dptest_alertclass_08_11";
  if (dpExists(clsBase))
  {
    dpDelete(clsBase);
    delay(0.5);
  }
  int rc = dpCreate(clsBase, "_AlertClass");
  DebugN("  dpCreate(", clsBase, ", _AlertClass) rc=", rc);
  dpdCheck("свой класс создан", rc == 0 && dpExists(clsBase));

  int ct = -1;
  dpGet(clsBase + ".:_alert_class.._type", ct);
  dpdCheck("после dpCreate конфиг не инициализирован (_type=0)", ct == 0);

  int rcNoType = dpSetWait(clsBase + ".:_alert_class.._prior", 50);
  DebugN("  запись _prior без _type: rc=", rcNoType, " err=", getLastError());
  dpdCheck("без _type запись _prior отклоняется (rc=-1)", rcNoType == -1);

  rc = dpSetWait(clsBase + ".:_alert_class.._type", DPCONFIG_ALERT_CLASS);
  DebugN("  запись _type=DPCONFIG_ALERT_CLASS rc=", rc);
  dpdCheck("_type=14 принимается", rc == 0);

  int ct2 = -1, cp = -1, ca = -1; string cab = "?"; bool car = FALSE;
  dpGet(clsBase + ".:_alert_class.._type", ct2);
  dpGet(clsBase + ".:_alert_class.._prior", cp);
  dpGet(clsBase + ".:_alert_class.._abbr", cab);
  dpGet(clsBase + ".:_alert_class.._ack_type", ca);
  dpGet(clsBase + ".:_alert_class.._archive", car);
  DebugN("  значения по умолчанию: _prior=", cp, " _abbr=", cab,
         " _ack_type=", ca, " _archive=", car);
  dpdCheck("после _type=14: _prior=1", cp == 1);
  dpdCheck("после _type=14: _abbr пустой", cab == "");
  dpdCheck("после _type=14: _ack_type=0 (Acknowledge deletes)", ca == 0);
  dpdCheck("после _type=14: _archive=TRUE", car == TRUE);

  // _archive=FALSE взят намеренно: на стенде он не мешает ни записям в _alerts,
  // ни квитированию. Проверки точки B ниже это и подтверждают.
  rc = dpSetWait(clsBase + ".:_alert_class.._prior", 50,
                 clsBase + ".:_alert_class.._abbr", "X",
                 clsBase + ".:_alert_class.._ack_type", DPATTR_ACK_APP_AND_DISAPP,
                 clsBase + ".:_alert_class.._archive", FALSE);
  dpdCheck("настройка своего класса rc=0", rc == 0);

  int cp2 = -1, ca2 = -1; string cab2 = "?"; bool car2 = TRUE;
  dpGet(clsBase + ".:_alert_class.._prior", cp2);
  dpGet(clsBase + ".:_alert_class.._abbr", cab2);
  dpGet(clsBase + ".:_alert_class.._ack_type", ca2);
  dpGet(clsBase + ".:_alert_class.._archive", car2);
  dpdCheck("свой класс: _prior=50", cp2 == 50);
  dpdCheck("свой класс: _abbr=X", cab2 == "X");
  dpdCheck("свой класс: _ack_type=4", ca2 == DPATTR_ACK_APP_AND_DISAPP);
  dpdCheck("свой класс: _archive=FALSE", car2 == FALSE);

  // --- 3. Точка A: штатные классы (information и alert) --------------------
  string baseA = "dptest_alert_08_11a";
  string dpeA  = baseA + ".value";
  string dptA  = "dptest_alert_08_11a_t";
  dpdCheck("точка A создана", makePoint(baseA, dptA, typeNames, typeTypes));

  rc = configure3(dpeA, "System1:information.");
  DebugN("  конфиг A с information: rc=", rc, " err=", getLastError());
  dpdCheck("A: диапазоны 0..20 / 20..30 / 30..max настроены", rc == 0);
  string stored = "?";
  dpGet(dpeA + ":_alert_hdl.2._class", stored);
  dpdCheck("A: класс диапазона 2 сохранён как System1:information.",
           stored == "System1:information.");

  setv(dpeA, 25);
  waitRange(dpeA, 2, "A: значение 25");
  waitState(dpeA, 2, "A: information не требует квитирования");
  dpdCheck("A: приоритет диапазона 2 = 10 (из класса)", actPrior(dpeA) == 10);

  setv(dpeA, 10);
  waitRange(dpeA, 1, "A: возврат в норму");
  waitState(dpeA, 0, "A: возврат в норму");

  setv(dpeA, 35);
  waitRange(dpeA, 3, "A: значение 35");
  waitState(dpeA, 1, "A: alert — CAME без квитирования");
  dpdCheck("A: приоритет диапазона 3 = 60 (из класса)", actPrior(dpeA) == 60);
  dpdCheck("A: у alert есть запись тревоги", alertCount(dpeA) >= 1);

  // Базовый атрибут для диапазонной тревоги — молчаливый no-op.
  atime cameA = findSide(dpeA, 3, TRUE);
  int rcBase = -1;
  if (cameA != 0 && (time)cameA != 0)
  {
    rcBase = alertSet((time)cameA, getACount(cameA), dpeA + ":_alert_hdl.._ack_state",
                      DPATTR_ACKTYPE_SINGLE);
  }
  DebugN("  квитирование по базовому атрибуту: rc=", rcBase);
  dpdCheck("A: базовый _ack_state принят (rc=0), но это no-op", rcBase == 0);
  waitState(dpeA, 1, "A: после базового атрибута состояние не изменилось");

  int rcAck = ackSide(dpeA, 3, TRUE);
  DebugN("  квитирование по _alert_hdl.3._ack_state: rc=", rcAck);
  dpdCheck("A: квитирование CAME по диапазону 3 rc=0", rcAck == 0);
  waitState(dpeA, 2, "A: CAME квитирована");

  setv(dpeA, 10);
  waitState(dpeA, 0, "A: после квитирования WENT даёт норму");

  // --- 4. Точка B: свой класс, _ack_type=4 ---------------------------------
  string baseB = "dptest_alert_08_11b";
  string dpeB  = baseB + ".value";
  string dptB  = "dptest_alert_08_11b_t";
  dpdCheck("точка B создана", makePoint(baseB, dptB, typeNames, typeTypes));

  rc = configure2(dpeB, clsBase + ".");
  DebugN("  конфиг B со своим классом: rc=", rc, " err=", getLastError());
  dpdCheck("B: класс точки принимается в диапазоне (имя с точкой)", rc == 0);
  dpGet(dpeB + ":_alert_hdl.2._class", stored);
  dpdCheck("B: класс сохранён с системным префиксом", stored == "System1:" + clsBase + ".");

  setv(dpeB, 25);
  waitRange(dpeB, 2, "B: значение 25");
  waitState(dpeB, 1, "B: свой класс — CAME без квитирования");
  dpdCheck("B: приоритет диапазона 2 = 50 (из своего класса)", actPrior(dpeB) == 50);
  dpdCheck("B: у своего класса есть запись тревоги", alertCount(dpeB) >= 1);

  rcAck = ackSide(dpeB, 2, TRUE);
  dpdCheck("B: квитирование CAME по диапазону 2 rc=0", rcAck == 0);
  waitState(dpeB, 2, "B: CAME квитирована");

  setv(dpeB, 10);
  waitState(dpeB, 3, "B: ack_type=4 — WENT ждёт отдельного квитирования");

  rcAck = ackSide(dpeB, 2, FALSE);
  dpdCheck("B: квитирование WENT по диапазону 2 rc=0", rcAck == 0);
  waitState(dpeB, 0, "B: WENT квитирован, норма");

  // --- 5. Уборка -----------------------------------------------------------
  dpSet(dpeA + ":_alert_hdl.._active", FALSE);
  dpSet(dpeB + ":_alert_hdl.._active", FALSE);
  delay(0.5);
  if (dpExists(baseA)) { dpDelete(baseA); }
  if (dpExists(baseB)) { dpDelete(baseB); }
  delay(0.5);
  dpdCheck("точки " + baseA + " и " + baseB + " удалены",
           !dpExists(baseA) && !dpExists(baseB));

  if (dpExists(clsBase))
  {
    dpSet(clsBase + ".:_alert_class.._type", DPCONFIG_NONE);
    delay(0.5);
    dpDelete(clsBase);
  }
  dpdCheck("свой класс " + clsBase + " удалён", !dpExists(clsBase));

  if (dpTypeGet(dptA, typeNames, typeTypes) == 0) { dpTypeDelete(dptA); }
  if (dpTypeGet(dptB, typeNames, typeTypes) == 0) { dpTypeDelete(dptB); }
  dpdCheck("типы точек удалены",
           dpTypeGet(dptA, typeNames, typeTypes) != 0 &&
           dpTypeGet(dptB, typeNames, typeTypes) != 0);

  dpdSummary();
  exit(0);
}
