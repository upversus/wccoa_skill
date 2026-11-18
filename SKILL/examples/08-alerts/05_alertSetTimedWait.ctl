// 05_alertSetTimedWait.ctl - alertSetTimedWait(): блокирующая запись атрибута тревоги с меткой времени.
// Документация: docs/08-alerts.md#alertsettimedwait
// Проверено: CTL 3.18, проект <проект стенда>.
// Скрипт самодостаточен: сам создаёт временную точку dptest_alert_08_05,
// взводит на ней тревогу, квитирует и удаляет точку.
//
// Метка acktime — это не время поиска тревоги, а значение, которое пишется в
// атрибут (_ack_time). Тревога по-прежнему адресуется парой (t, count).
//
// Жёсткое правило: вызов только при t != 0 && At != 0.

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

string alertDemoCreate(string base)
{
  string dpe = base + ".b1";
  if (dpExists(base))
  {
    dpSet(dpe + ":_alert_hdl.._active", FALSE);
    delay(1);
    dpDelete(base);
  }

  if (dpCreate(base, "ExampleDP_DDE") != 0 || !dpExists(base))
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

  if (dpSetTimedWait(0, dpe + ":_alert_hdl.._active", TRUE) != 0)
  {
    return "";
  }
  return dpe;
}

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

void alertDemoGone(string dpe)
{
  dpSetWait(dpe + ":_original.._value", FALSE);
  delay(0.5);
}

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
  DebugN("=== alertSetTimedWait() ===");
  DebugN("  сигнатура: int alertSetTimedWait(time acktime, time t, int count, string attr, anytype value)");

  int ackType = -1;
  if (dpGet("System1:alert.:_alert_class.._ack_type", ackType) != 0 || ackType != 3)
  {
    DebugN("  SKIP  нет класса System1:alert. с _ack_type=3 — квитирование не проверить");
    dpdSummary();
    exit(0);
  }
  dyn_dyn_string typeNames;
  dyn_dyn_int typeTypes;
  if (dpTypeGet("ExampleDP_DDE", typeNames, typeTypes) != 0)
  {
    DebugN("  SKIP  в проекте нет типа ExampleDP_DDE");
    dpdSummary();
    exit(0);
  }

  string base = "dptest_alert_08_05";
  string dpe = alertDemoCreate(base);
  if (dpe == "")
  {
    dpdCheck("точка " + base + " создана и настроена", false);
    alertDemoDrop(base, base + ".b1");
    dpdSummary();
    exit(1);
  }
  dpdCheck("CAME: _act_range != 0", alertDemoCame(dpe));

  time t;
  atime At;
  dpdCheck("время тревоги и atime ненулевые", alertDemoAtime(dpe, t, At));

  int ast = 0;
  dpGet(dpe + ":_alert_hdl.._act_state", ast);
  dpdCheck("до квитирования _act_state == 1", ast == 1);

  // --- метка квитирования --------------------------------------------------
  time acktime = getCurrentTime();
  dpdCheck("acktime ненулевой", acktime != 0);
  dpdCheck("время тревоги t ненулевое", t != 0);

  int rcAck = -1;
  if (t != 0 && At != 0 && acktime != 0)
  {
    rcAck = alertSetTimedWait(acktime, t, getACount(At),
                          dpe + ":_alert_hdl.._ack_state",
                          DPATTR_ACKTYPE_SINGLE);
  }
  DebugN("  alertSetTimedWait(_ack_state, SINGLE) rc=", rcAck, " acktime=", acktime);
  dpdCheck("alertSetTimedWait rc=0", rcAck == 0);

  delay(0.5);
  dpGet(dpe + ":_alert_hdl.._act_state", ast);
  dpdCheck("после квитирования _act_state == 2", ast == 2);

  dyn_anytype v;
  int rcGet = alertGet(t, getACount(At), dpe + ":_alert_hdl.._ack_time", v);
  DebugN("  alertGet(_ack_time) rc=", rcGet, " v=", v);
  dpdCheck("_ack_time равен переданному acktime",
           rcGet == 0 && dynlen(v) == 1 && (time)v[1] == acktime);

  rcGet = alertGet(t, getACount(At), dpe + ":_alert_hdl.._ack_state", v);
  DebugN("  alertGet(_ack_state) rc=", rcGet, " v=", v);
  dpdCheck("alertGet(_ack_state) == 2 (single)",
           rcGet == 0 && dynlen(v) == 1 && (int)v[1] == 2);

  // --- запись комментария с меткой ----------------------------------------
  time ctime = getCurrentTime();
  int rcComment = -1;
  if (t != 0 && At != 0 && ctime != 0)
  {
    rcComment = alertSetTimedWait(ctime, t, getACount(At),
                              dpe + ":_alert_hdl.._comment", "timed");
  }
  delay(0.5);
  rcGet = alertGet(t, getACount(At), dpe + ":_alert_hdl.._comment", v);
  DebugN("  alertSetTimedWait(_comment) rc=", rcComment, " readback=", v);
  dpdCheck("комментарий записан через alertSetTimedWait",
           rcComment == 0 && rcGet == 0 && dynlen(v) == 1 && (string)v[1] == "timed");

  // --- защита от нулевой даты ---------------------------------------------
  atime Z;
  int calls = 0;
  if (Z != 0)
  {
    calls++;
    alertSetTimedWait(acktime, t, getACount(Z), dpe + ":_alert_hdl.._comment", "нельзя");
  }
  dpdCheck("пустой atime не проходит проверку и вызов не делается", calls == 0);

  // --- WENT и уборка -------------------------------------------------------
  alertDemoGone(dpe);
  int ar = 0;
  dpGet(dpe + ":_alert_hdl.._act_range", ar);
  dpdCheck("WENT: _act_range == 0", ar == 0);

  alertDemoDrop(base, dpe);
  dpdCheck("точка " + base + " удалена", !dpExists(base));

  dpdSummary();
  exit(0);
}
