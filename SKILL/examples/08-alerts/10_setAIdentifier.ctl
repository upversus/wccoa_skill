// 10_setAIdentifier.ctl - setAIdentifier(): запись имени точки данных в atime.
// Документация: docs/08-alerts.md#setaidentifier
// Проверено: CTL 3.18, проект <проект стенда>.
// Скрипт самодостаточен: сам создаёт временную точку dptest_alert_08_10,
// собирает на ней atime и удаляет точку. Живая тревога не нужна.
//
// Функция проверяет, что имя существует, но не проверяет, что это атрибут
// тревоги: полная строка вида "DPE:_alert_hdl.._attr" сохраняется дословно.
// Несуществующее имя даёт rc=-1.
//
// Пустой atime не отвергается: имя записывается, rc=0, но время остаётся
// нулевым. То есть setAIdentifier не делает atime пригодным для alertSet*().

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

main()
{
  DebugN("=== setAIdentifier() ===");
  DebugN("  сигнатура: int setAIdentifier(atime &AlertTime, string Identifier)");

  dyn_dyn_string typeNames;
  dyn_dyn_int typeTypes;
  if (dpTypeGet("ExampleDP_DDE", typeNames, typeTypes) != 0)
  {
    DebugN("  SKIP  в проекте нет типа ExampleDP_DDE");
    dpdSummary();
    exit(0);
  }

  string base = "dptest_alert_08_10";
  if (dpExists(base))
  {
    dpDelete(base);
    delay(1);
  }
  if (dpCreate(base, "ExampleDP_DDE") != 0 || !dpExists(base))
  {
    dpdCheck("точка " + base + " создана", false);
    dpdSummary();
    exit(1);
  }

  string dpe = "System1:" + base + ".b1";
  time t = getCurrentTime();
  atime At = makeATime(t, 0, dpe);
  dpdCheck("atime собран из ненулевого времени", At != 0);

  // --- существующий DPE ---------------------------------------------------
  int rc = setAIdentifier(At, dpe);
  string id = getAIdentifier(At);
  DebugN("  setAIdentifier(DPE) rc=", rc, " id='", id, "'");
  dpdCheck("setAIdentifier(существующий DPE) вернул 0", rc == 0);
  dpdCheck("имя читается обратно как " + dpe + ".",
           id == dpe + ".");

  // --- полная строка атрибута ---------------------------------------------
  string full = dpe + ":_alert_hdl.._abbr";
  rc = setAIdentifier(At, full);
  id = getAIdentifier(At);
  DebugN("  setAIdentifier(полный атрибут) rc=", rc, " id='", id, "'");
  dpdCheck("setAIdentifier(полная строка) вернул 0", rc == 0);
  dpdCheck("полная строка сохраняется дословно", id == full);

  // --- несуществующая точка -----------------------------------------------
  rc = setAIdentifier(At, "System1:no_such_dp_08.fVal");
  DebugN("  setAIdentifier(несуществующая точка) rc=", rc,
         " id='", getAIdentifier(At), "'  lastError=", getLastError());
  dpdCheck("несуществующая точка — rc=-1", rc == -1);
  dpdCheck("после ошибки имя не изменилось", getAIdentifier(At) == full);

  // --- пустой atime -------------------------------------------------------
  atime Z;
  dpdCheck("пустой atime равен нулю", Z == 0);
  rc = setAIdentifier(Z, dpe);
  DebugN("  setAIdentifier(пустой atime) rc=", rc,
         " id='", getAIdentifier(Z), "' time='", (string)Z, "'",
         " zero=", (Z == 0), "  lastError=", getLastError());
  dpdCheck("пустой atime — rc=0 (имя пишется без проверки времени)", rc == 0);
  dpdCheck("время при этом осталось нулевым (в отличие от setACount)", Z == 0);

  dpDelete(base);
  delay(1);
  dpdCheck("точка " + base + " удалена", !dpExists(base));

  dpdSummary();
  exit(0);
}
