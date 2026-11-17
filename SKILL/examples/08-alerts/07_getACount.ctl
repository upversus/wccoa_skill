// 07_getACount.ctl - getACount(): порядковый номер тревоги внутри atime.
// Документация: docs/08-alerts.md#getacount
// Проверено: CTL 3.18, проект <проект стенда>.
// Скрипт самодостаточен: сам создаёт временную точку dptest_alert_08_07,
// взводит на ней живую тревогу, квитирует и удаляет точку.
//
// Номер тревоги — часть адреса. atime с неверным номером не находит тревогу
// (alertGet вернёт rc=0 и пустой dyn_anytype), поэтому номер нельзя угадывать:
// правильный atime со счётчиком отдаёт _alert_hdl.._alerts.
//
// Жёсткое правило: вызов alertSet*() только при t != 0 && At != 0.

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
  DebugN("=== getACount() ===");
  DebugN("  сигнатура: uint getACount(atime AlertTime)");

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

  string base = "dptest_alert_08_07";
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

  // --- живая тревога: номер из _alerts ищет её -----------------------------
  int realCount = (int)getACount(At);
  DebugN("  живая тревога: t='", t, "' count=", realCount);

  dyn_anytype v;
  int rcGet = alertGet(At, realCount, dpe + ":_alert_hdl.._direction", v);
  DebugN("  alertGet с реальным счётчиком rc=", rcGet, " v=", v);
  dpdCheck("alertGet с реальным счётчиком находит тревогу",
           rcGet == 0 && dynlen(v) == 1 && (bool)v[1]);

  // --- неверный номер: тревога не находится --------------------------------
  int wrongCount = (realCount == 0) ? 1 : 0;
  atime Wrong = At;
  int rcSetWrong = setACount(Wrong, wrongCount);

  dpdCheck("setACount(Wrong, " + wrongCount + ") вернул 0", rcSetWrong == 0);
  dpdCheck("у Wrong номер " + wrongCount, (int)getACount(Wrong) == wrongCount);
  dpdCheck("номер исходного At не изменился", (int)getACount(At) == realCount);

  dyn_anytype w;
  int rcWrong = alertGet(Wrong, (int)getACount(Wrong),
                         dpe + ":_alert_hdl.._direction", w);
  DebugN("  alertGet с чужим счётчиком rc=", rcWrong, " len=", dynlen(w));
  dpdCheck("с неверным счётчиком тревога не находится",
           rcWrong == 0 && dynlen(w) == 0);

  rcGet = alertGet(At, realCount, dpe + ":_alert_hdl.._direction", v);
  dpdCheck("исходный At продолжает работать",
           rcGet == 0 && dynlen(v) == 1 && (bool)v[1]);

  // --- setACount меняет копию, а не исходный atime -------------------------
  atime Copy = At;
  int rcSetCopy = setACount(Copy, 7);
  dpdCheck("setACount(Copy, 7) вернул 0", rcSetCopy == 0);
  dpdCheck("у копии номер стал 7", (int)getACount(Copy) == 7);
  dpdCheck("At после правки копии по-прежнему " + realCount,
           (int)getACount(At) == realCount);

  // --- пустой atime: номер 0, но setACount даёт дату 1970 ------------------
  atime Z;
  dpdCheck("пустой atime равен нулю", Z == 0);
  dpdCheck("getACount(пустой atime) — 0", getACount(Z) == 0);

  int rcZ = setACount(Z, 5);
  DebugN("  setACount(пустой, 5) rc=", rcZ, " Z='", (string)Z,
         "' count=", getACount(Z));
  dpdCheck("setACount на пустом atime вернул 0", rcZ == 0);
  dpdCheck("после setACount пустой atime стал ненулевым", Z != 0);
  dpdCheck("но его дата — 1970 (в alertSet нельзя)",
           substr((string)Z, 0, 4) == "1970");

  // --- квитирование и уборка ----------------------------------------------
  int rcAck = -1;
  if (t != 0 && At != 0)
  {
    rcAck = alertSet(t, getACount(At), dpe + ":_alert_hdl.._ack_state",
                     DPATTR_ACKTYPE_SINGLE);
  }
  delay(0.5);
  int ast = 0;
  dpGet(dpe + ":_alert_hdl.._act_state", ast);
  dpdCheck("квитирование CAME: rc=0 и _act_state == 2", rcAck == 0 && ast == 2);

  alertDemoGone(dpe);
  int ar = 0;
  dpGet(dpe + ":_alert_hdl.._act_range", ar);
  dpdCheck("WENT: _act_range == 0", ar == 0);

  alertDemoDrop(base, dpe);
  dpdCheck("точка " + base + " удалена", !dpExists(base));

  dpdSummary();
  exit(0);
}
