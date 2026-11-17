// 01_alertGet.ctl - alertGet(): чтение атрибутов тревоги на её момент времени.
// Документация: docs/08-alerts.md#alertget
// Проверено: CTL 3.18, проект <проект стенда>.
// Скрипт самодостаточен: сам создаёт временную точку dptest_alert_08_01,
// взводит на ней тревогу, квитирует и удаляет точку.
//
// Измеренные оговорки 3.18:
//   - после квитирования _act_state равен 2, а верхнеуровневый _ack_state
//     читается как -1 — признак успеха берётся из _act_state;
//   - alertGet() возвращает dyn_anytype и для одного атрибута (1 значение),
//     и для dyn_string (по значению на атрибут).

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
// Помощники тревог — эталон examples/_lib.ctl
// ===========================================================================

// Создаёт временную точку base типа ExampleDP_DDE и настраивает _alert_hdl
// на элементе b1. Возвращает DPE или "" при ошибке.
string alertDemoCreate(string base)
{
  string dpe = base + ".b1";
  if (dpExists(base))
  {
    dpSet(dpe + ":_alert_hdl.._active", FALSE);
    delay(1);
    dpDelete(base);
  }

  int rc = dpCreate(base, "ExampleDP_DDE");
  if (rc != 0 || !dpExists(base))
  {
    return "";
  }

  dpSetWait(dpe + ":_original.._value", FALSE);
  int rcCfg = dpSetTimedWait(0,
      dpe + ":_alert_hdl.._active",   FALSE,
      dpe + ":_alert_hdl.._type",     DPCONFIG_ALERT_BINARYSIGNAL,
      dpe + ":_alert_hdl.._class",    "System1:alert.",
      dpe + ":_alert_hdl.._text0",    "OK",
      dpe + ":_alert_hdl.._text1",    "ALARM",
      dpe + ":_alert_hdl.._orig_hdl", TRUE);
  if (rcCfg != 0)
  {
    return "";
  }

  int rcOn = dpSetTimedWait(0, dpe + ":_alert_hdl.._active", TRUE);
  if (rcOn != 0)
  {
    return "";
  }
  return dpe;
}

// Записывает «плохое» значение и ждёт появления тревоги (до 10 с).
bool alertDemoCame(string dpe)
{
  if (dpSetWait(dpe + ":_original.._value", TRUE) != 0)
  {
    return false;
  }
  int ar = 0;
  for (int i = 1; i <= 50; i++)
  {
    dpGet(dpe + ":_alert_hdl.._act_range", ar);
    if (ar != 0)
    {
      return true;
    }
    delay(0.2);
  }
  return false;
}

// Читает время начала тревоги и строит atime. TRUE только если и время,
// и atime ненулевые — это условие допуска к alertSet*().
bool alertDemoAtime(string dpe, time &t, atime &At)
{
  t = 0;
  At = 0;
  if (dpGet(dpe + ":_original.._stime", t) != 0 || t == 0)
  {
    return false;
  }

  // makeATime(t, 0, dpe) здесь не годится: у реальной тревоги счётчик может
  // быть не 0 (например, 1), и alertSet()/alertGet() молча не находят её.
  // Точный atime со счётчиком отдаёт _alert_hdl.._alerts.
  dyn_atime al;
  if (dpGet(dpe + ":_alert_hdl.._alerts", al) != 0)
  {
    return false;
  }
  for (int i = 1; i <= dynlen(al); i++)
  {
    dyn_anytype d;
    if (alertGet(al[i], getACount(al[i]), dpe + ":_alert_hdl.._direction", d) != 0)
    {
      continue;
    }
    if (dynlen(d) == 1 && (bool)d[1])
    {
      At = al[i];
    }
  }
  return At != 0;
}

// Возвращает «хорошее» значение: тревога уходит.
void alertDemoGone(string dpe)
{
  dpSetWait(dpe + ":_original.._value", FALSE);
  delay(0.5);
}

// Убирает точку. Если тревога ещё висит и не квитирована — квитирует её
// (только при валидном atime), затем снимает _active и удаляет точку.
void alertDemoDrop(string base, string dpe)
{
  // Квитируется та сторона пары, у которой _ack_oblig == TRUE: для пары это
  // либо ещё висящая CAME, либо уже ушедшая WENT. У текущей стороны время
  // совпадает с _original.._stime, поэтому оно и передаётся в alertSet().
  dyn_atime al;
  if (dpGet(dpe + ":_alert_hdl.._alerts", al) == 0)
  {
    time t = 0;
    dpGet(dpe + ":_original.._stime", t);
    atime target = 0;
    for (int i = 1; i <= dynlen(al); i++)
    {
      dyn_anytype ob;
      if (alertGet(al[i], getACount(al[i]), dpe + ":_alert_hdl.._ack_oblig", ob) != 0)
      {
        continue;
      }
      if (dynlen(ob) == 1 && (bool)ob[1])
      {
        target = al[i];
      }
    }
    if (target != 0 && t != 0)
    {
      alertSet(t, getACount(target), dpe + ":_alert_hdl.._ack_state",
               DPATTR_ACKTYPE_SINGLE);
    }
  }
  dpSetWait(dpe + ":_alert_hdl.._active", FALSE);
  delay(1);
  if (dpExists(base))
  {
    dpDelete(base);
  }
}

// ===========================================================================
// Пример
// ===========================================================================
main()
{
  DebugN("=== alertGet() ===");
  DebugN("  сигнатура: int alertGet(time t, int count, string attr, dyn_anytype &value)");

  int ackType = -1;
  if (dpGet("System1:alert.:_alert_class.._ack_type", ackType) != 0 || ackType != 3)
  {
    DebugN("  SKIP  нет класса System1:alert. с _ack_type=3 — квитирование не проверить");
    dpdSummary();
    exit(0);
  }
  if (dynlen(dpNames("*", "ExampleDP_DDE")) == 0)
  {
    DebugN("  SKIP  в проекте нет типа ExampleDP_DDE");
    dpdSummary();
    exit(0);
  }

  string base = "dptest_alert_08_01";
  string dpe = alertDemoCreate(base);
  if (dpe == "")
  {
    dpdCheck("точка " + base + " создана и настроена", false);
    alertDemoDrop(base, base + ".b1");
    dpdSummary();
    exit(1);
  }
  dpdCheck("точка " + base + " создана", dpExists(base));

  // --- настройка _alert_hdl ------------------------------------------------
  int typ = 0;
  bool active = FALSE;
  bool orig = FALSE;
  string cls = "";
  dpGet(dpe + ":_alert_hdl.._type", typ);
  dpGet(dpe + ":_alert_hdl.._active", active);
  dpGet(dpe + ":_alert_hdl.._orig_hdl", orig);
  dpGet(dpe + ":_alert_hdl.._class", cls);
  dpdCheck("_alert_hdl.._type == 12 (binary)", typ == 12);
  dpdCheck("_alert_hdl.._active == TRUE", active);
  dpdCheck("_alert_hdl.._orig_hdl == TRUE", orig);
  dpdCheck("_alert_hdl.._class == System1:alert.", cls == "System1:alert.");

  // --- тревога -------------------------------------------------------------
  dpdCheck("CAME: _act_range != 0", alertDemoCame(dpe));
  int ar = 0;
  int ast = 0;
  int ackp = 0;
  bool acko = FALSE;
  dpGet(dpe + ":_alert_hdl.._act_range", ar);
  dpGet(dpe + ":_alert_hdl.._act_state", ast);
  dpGet(dpe + ":_alert_hdl.._ack_possible", ackp);
  dpGet(dpe + ":_alert_hdl.._ack_oblig", acko);
  dpdCheck("_act_range == 1", ar == 1);
  dpdCheck("_act_state == 1 (не квитирована)", ast == 1);
  dpdCheck("_ack_possible == 1", ackp == 1);
  // Прямое чтение даёт конфиг (_ack_oblig в _alert_hdl = FALSE), а значение
  // самого экземпляра тревоги читается через alertGet() и равно TRUE.
  dpdCheck("_alert_hdl.._ack_oblig (конфиг) == FALSE", !acko);

  time t;
  atime At;
  dpdCheck("время тревоги и atime ненулевые", alertDemoAtime(dpe, t, At));

  // atime берётся из _alert_hdl.._alerts: только так счётчик совпадает с
  // реальной тревогой (makeATime с нулём может указать в пустоту).
  dyn_atime al;
  dpGet(dpe + ":_alert_hdl.._alerts", al);
  bool found = FALSE;
  for (int i = 1; i <= dynlen(al); i++)
  {
    if (al[i] == At)
    {
      found = TRUE;
    }
  }
  dpdCheck("atime CAME взят из _alert_hdl.._alerts", found);

  // --- alertGet по одному атрибуту ----------------------------------------
  dyn_anytype v;
  int rc = alertGet(t, getACount(At), dpe + ":_alert_hdl.._act_state", v);
  DebugN("  alertGet(_act_state) rc=", rc, " v=", v);
  dpdCheck("alertGet(_act_state) rc=0 и значение 1", rc == 0 && (int)v[1] == 1);

  rc = alertGet(t, getACount(At), dpe + ":_alert_hdl.._ack_oblig", v);
  DebugN("  alertGet(_ack_oblig) rc=", rc, " v=", v);
  dpdCheck("alertGet(_ack_oblig) rc=0 и TRUE", rc == 0 && (bool)v[1]);

  rc = alertGet(t, getACount(At), dpe + ":_alert_hdl.._value", v);
  DebugN("  alertGet(_value) rc=", rc, " v=", v);
  dpdCheck("alertGet(_value) rc=0 и TRUE", rc == 0 && (bool)v[1]);

  // --- dyn-форма -----------------------------------------------------------
  dyn_string attrs = makeDynString(
      dpe + ":_alert_hdl.._act_state",
      dpe + ":_alert_hdl.._ack_oblig",
      dpe + ":_alert_hdl.._value");
  dyn_anytype vals;
  rc = alertGet(t, getACount(At), attrs, vals);
  DebugN("  alertGet(dyn) rc=", rc, " vals=", vals);
  dpdCheck("dyn-форма: rc=0 и три значения", rc == 0 && dynlen(vals) == 3);
  dpdCheck("dyn-форма: _act_state == 1", (int)vals[1] == 1);

  // --- квитирование --------------------------------------------------------
  int rcComment = -1;
  if (t != 0 && At != 0)
  {
    rcComment = alertSet(t, getACount(At), dpe + ":_alert_hdl.._comment",
                         "alertGet demo");
  }
  dpdCheck("alertSet(_comment) rc=0", rcComment == 0);

  int rcAck = -1;
  if (t != 0 && At != 0)
  {
    rcAck = alertSet(t, getACount(At), dpe + ":_alert_hdl.._ack_state",
                     DPATTR_ACKTYPE_SINGLE);
  }
  dpdCheck("alertSet(_ack_state) rc=0", rcAck == 0);
  delay(0.5);
  dpGet(dpe + ":_alert_hdl.._act_state", ast);
  DebugN("  после квитирования: _act_state=", ast);
  dpdCheck("после квитирования _act_state == 2", ast == 2);

  // --- WENT и уборка -------------------------------------------------------
  alertDemoGone(dpe);
  dpGet(dpe + ":_alert_hdl.._act_range", ar);
  dpdCheck("WENT: _act_range == 0", ar == 0);

  alertDemoDrop(base, dpe);
  dpdCheck("точка " + base + " удалена", !dpExists(base));

  dpdSummary();
  exit(0);
}
