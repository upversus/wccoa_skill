// 10_setAIdentifier.ctl - setAIdentifier(): запись имени точки данных в atime.
// Документация: docs/08-alerts.md#setaidentifier
// Проверено: CTL 3.18, проект <проект стенда>.
// Скрипт самодостаточен: работает с atime в памяти, живая тревога не нужна.
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

  time t = getCurrentTime();
  atime At = makeATime(t, 0, "System1:ExampleDP_DDE.b1");
  dpdCheck("atime собран из ненулевого времени", At != 0);

  // --- существующий DPE ---------------------------------------------------
  int rc = setAIdentifier(At, "System1:ExampleDP_DDE.b1");
  string id = getAIdentifier(At);
  DebugN("  setAIdentifier(DPE) rc=", rc, " id='", id, "'");
  dpdCheck("setAIdentifier(существующий DPE) вернул 0", rc == 0);
  dpdCheck("имя читается обратно как System1:ExampleDP_DDE.b1.",
           id == "System1:ExampleDP_DDE.b1.");

  // --- полная строка атрибута ---------------------------------------------
  string full = "System1:ExampleDP_DDE.b1:_alert_hdl.._abbr";
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
  rc = setAIdentifier(Z, "System1:ExampleDP_DDE.b1");
  DebugN("  setAIdentifier(пустой atime) rc=", rc,
         " id='", getAIdentifier(Z), "' time='", (string)Z, "'",
         " zero=", (Z == 0), "  lastError=", getLastError());
  dpdCheck("пустой atime — rc=0 (имя пишется без проверки времени)", rc == 0);
  dpdCheck("время при этом осталось нулевым (в отличие от setACount)", Z == 0);

  dpdSummary();
  exit(0);
}
