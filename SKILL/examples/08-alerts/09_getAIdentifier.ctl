// 09_getAIdentifier.ctl - getAIdentifier(): имя точки данных из atime.
// Документация: docs/08-alerts.md#getaidentifier
// Проверено: CTL 3.18, проект <проект стенда>.
// Скрипт самодостаточен: сам создаёт временную точку dptest_alert_08_09,
// собирает на ней atime и удаляет точку. Живая тревога не нужна.
//
// Формат имени. Функция возвращает DPE до detail. Для именованного элемента
// это "System1:<точка>.b1." (одна точка в конце), для имени без элементов
// ("System1:<точка>.") — две точки, потому что сам DPE уже оканчивается точкой.
// Это не оговорка версии, а нормальная запись DPE.

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

  dyn_dyn_string typeNames;
  dyn_dyn_int typeTypes;
  if (dpTypeGet("ExampleDP_DDE", typeNames, typeTypes) != 0)
  {
    DebugN("  SKIP  в проекте нет типа ExampleDP_DDE");
    dpdSummary();
    exit(0);
  }

  string base = "dptest_alert_08_09";
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
  string id = getAIdentifier(At);
  DebugN("  id='", id, "' count=", getACount(At));

  dpdCheck("именованный элемент: " + dpe + ".",
           id == dpe + ".");
  dpdCheck("номер тревоги в свежем atime — 0", getACount(At) == 0);

  // --- setAIdentifier меняет имя -----------------------------------------
  int rc = setAIdentifier(At, dpe);
  DebugN("  setAIdentifier(dp) rc=", rc, " id='", getAIdentifier(At), "'");
  dpdCheck("setAIdentifier(DPE) вернул 0", rc == 0);
  dpdCheck("имя после записи — " + dpe + ".",
           getAIdentifier(At) == dpe + ".");

  // --- полная строка атрибута сохраняется дословно -----------------------
  rc = setAIdentifier(At, dpe + ":_alert_hdl.._abbr");
  DebugN("  setAIdentifier(полный атрибут) rc=", rc, " id='", getAIdentifier(At), "'");
  dpdCheck("setAIdentifier(полная строка) вернул 0", rc == 0);
  dpdCheck("полная строка возвращается дословно",
           getAIdentifier(At) == dpe + ":_alert_hdl.._abbr");

  // --- имя без элементов --------------------------------------------------
  atime A2 = makeATime(t, 0, "System1:" + base + ".");
  DebugN("  без элементов: id='", getAIdentifier(A2), "'");
  dpdCheck("имя без элементов даёт две точки в конце",
           getAIdentifier(A2) == "System1:" + base + "..");

  // --- пустой atime -------------------------------------------------------
  atime Z;
  DebugN("  пустой atime: id='", getAIdentifier(Z), "'");
  dpdCheck("пустой atime даёт \".\"", getAIdentifier(Z) == ".");

  dpDelete(base);
  delay(1);
  dpdCheck("точка " + base + " удалена", !dpExists(base));

  dpdSummary();
  exit(0);
}
