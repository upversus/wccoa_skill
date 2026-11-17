// 02_alertSet.ctl - alertSet(): запись атрибута тревоги с текущим временем.
// Документация: docs/08-alerts.md#alertset
// Проверено: CTL 3.18, проект <проект стенда>.
// Скрипт самодостаточен: сам создаёт временную точку dptest_alert_08_02,
// взводит на ней тревогу, квитирует и удаляет точку.
//
// Жёсткое правило: alertSet() нельзя вызывать с нулевой датой — это ломает
// связность сегментов базы. Поэтому вызов защищён проверкой t != 0 && At != 0,
// и пример это показывает на намеренно пустом atime.
//
// Измеренные оговорки 3.18:
//   - _ack_state — атрибут тревоги, но верхнеуровневый _ack_state после
//     квитирования читается как -1; признак успеха — _act_state == 2;
//   - запись _comment через alertSet() не меняет _act_state.

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
  DebugN("=== alertSet() ===");
  DebugN("  сигнатура: int alertSet(time t, int count, string attr, anytype value)");

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

  string base = "dptest_alert_08_02";
  string dpe = alertDemoCreate(base);
  if (dpe == "")
  {
    dpdCheck("точка " + base + " создана и настроена", false);
    alertDemoDrop(base, base + ".b1");
    dpdSummary();
    exit(1);
  }
  // --- тревога -------------------------------------------------------------
  dpdCheck("CAME: _act_range != 0", alertDemoCame(dpe));
  int ar = 0;
  dpGet(dpe + ":_alert_hdl.._act_range", ar);
  dpdCheck("_act_range == 1", ar == 1);

  time t;
  atime At;
  bool ok = alertDemoAtime(dpe, t, At);
  dpdCheck("время тревоги и atime ненулевые", ok);

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

  // --- запись комментария --------------------------------------------------
  int ast = 0;
  dpGet(dpe + ":_alert_hdl.._act_state", ast);
  dpdCheck("до записи _comment: _act_state == 1", ast == 1);

  string comment = "обслуживание насоса";
  int rc = -1;
  if (t != 0 && At != 0)
  {
    rc = alertSet(t, getACount(At), dpe + ":_alert_hdl.._comment", comment);
  }
  DebugN("  alertSet(_comment) rc=", rc);
  dpdCheck("alertSet(_comment) rc=0", rc == 0);

  dyn_anytype v;
  rc = alertGet(t, getACount(At), dpe + ":_alert_hdl.._comment", v);
  DebugN("  alertGet(_comment) rc=", rc, " v=", v);
  dpdCheck("комментарий читается обратно", rc == 0 && (string)v[1] == comment);

  dpGet(dpe + ":_alert_hdl.._act_state", ast);
  dpdCheck("запись _comment не изменила _act_state (всё ещё 1)", ast == 1);

  // --- квитирование --------------------------------------------------------
  int rcAck = -1;
  if (t != 0 && At != 0)
  {
    rcAck = alertSet(t, getACount(At), dpe + ":_alert_hdl.._ack_state",
                     DPATTR_ACKTYPE_SINGLE);
  }
  DebugN("  alertSet(_ack_state) rc=", rcAck);
  dpdCheck("alertSet(_ack_state) rc=0", rcAck == 0);

  delay(0.5);
  dpGet(dpe + ":_alert_hdl.._act_state", ast);
  DebugN("  после квитирования: _act_state=", ast);
  dpdCheck("после квитирования _act_state == 2", ast == 2);

  // Верхнеуровневый _ack_state — агрегат по всем диапазонам, у одной тревоги
  // он не равен значению экземпляра (измерено: 2 до квитирования и -2 после).
  // Признак успеха берётся из _act_state, а не отсюда.
  int topAck = -99;
  dpGet(dpe + ":_alert_hdl.._ack_state", topAck);
  DebugN("  верхнеуровневый _ack_state=", topAck);
  dpdCheck("верхнеуровневый _ack_state не равен -1 (это не индикатор успеха)",
           topAck != -1);

  // --- защита от нулевой даты ---------------------------------------------
  atime Z;
  int calls = 0;
  if (Z != 0)
  {
    calls++;
    alertSet(t, getACount(Z), dpe + ":_alert_hdl.._comment", "не должно быть");
  }
  DebugN("  пустой atime: вызовов alertSet сделано ", calls);
  dpdCheck("пустой atime не проходит проверку и вызов не делается", calls == 0);
  dpdCheck("setACount на пустом atime делает его ненулевым (опасность)",
           setACount(Z, 1) == 0 && Z != 0);
  dpdCheck("но дата остаётся 1970", substr((string)Z, 0, 4) == "1970");

  // --- WENT и уборка -------------------------------------------------------
  alertDemoGone(dpe);
  dpGet(dpe + ":_alert_hdl.._act_range", ar);
  dpdCheck("WENT: _act_range == 0", ar == 0);

  alertDemoDrop(base, dpe);
  dpdCheck("точка " + base + " удалена", !dpExists(base));

  dpdSummary();
  exit(0);
}