// 09_getAIdentifier.ctl - getAIdentifier(): имя точки данных из atime.
// Документация: docs/08-alerts.md#getaidentifier
// Проверено: CTL 3.18, проект <проект стенда>.
// Скрипт самодостаточен: работает с atime в памяти, живая тревога не нужна.
//
// Формат имени. Функция возвращает DPE до detail. Для именованного элемента
// это "System1:ExampleDP_DDE.b1." (одна точка в конце), для точки без элементов
// ("System1:ExampleDP_AlertHdl1.") — две точки, потому что сам DPE уже
// оканчивается точкой. Это не оговорка версии, а нормальная запись DPE.

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
  DebugN("=== getAIdentifier() ===");
  DebugN("  сигнатура: string getAIdentifier(atime AlertTime)");

  time t = getCurrentTime();
  atime At = makeATime(t, 0, "System1:ExampleDP_DDE.b1");
  string id = getAIdentifier(At);
  DebugN("  id='", id, "' count=", getACount(At));

  dpdCheck("именованный элемент: System1:ExampleDP_DDE.b1.",
           id == "System1:ExampleDP_DDE.b1.");
  dpdCheck("номер тревоги в свежем atime — 0", getACount(At) == 0);

  // --- setAIdentifier меняет имя -----------------------------------------
  int rc = setAIdentifier(At, "System1:ExampleDP_DDE.b1");
  DebugN("  setAIdentifier(dp) rc=", rc, " id='", getAIdentifier(At), "'");
  dpdCheck("setAIdentifier(DPE) вернул 0", rc == 0);
  dpdCheck("имя после записи — System1:ExampleDP_DDE.b1.",
           getAIdentifier(At) == "System1:ExampleDP_DDE.b1.");

  // --- полная строка атрибута сохраняется дословно -----------------------
  rc = setAIdentifier(At, "System1:ExampleDP_DDE.b1:_alert_hdl.._abbr");
  DebugN("  setAIdentifier(полный атрибут) rc=", rc, " id='", getAIdentifier(At), "'");
  dpdCheck("setAIdentifier(полная строка) вернул 0", rc == 0);
  dpdCheck("полная строка возвращается дословно",
           getAIdentifier(At) == "System1:ExampleDP_DDE.b1:_alert_hdl.._abbr");

  // --- точка без элементов ------------------------------------------------
  atime A2 = makeATime(t, 0, "System1:ExampleDP_AlertHdl1.");
  DebugN("  элементлесс: id='", getAIdentifier(A2), "'");
  dpdCheck("точка без элементов даёт две точки в конце",
           getAIdentifier(A2) == "System1:ExampleDP_AlertHdl1..");

  // --- пустой atime -------------------------------------------------------
  atime Z;
  DebugN("  пустой atime: id='", getAIdentifier(Z), "'");
  dpdCheck("пустой atime даёт \".\"", getAIdentifier(Z) == ".");

  dpdSummary();
  exit(0);
}
