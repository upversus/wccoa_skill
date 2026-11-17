// 08_setACount.ctl - setACount(): запись порядкового номера тревоги в atime.
// Документация: docs/08-alerts.md#setacount
// Проверено: CTL 3.18, проект <проект стенда>.
// Скрипт самодостаточен: работает с atime в памяти, точка данных не создаётся.
//
// ВАЖНО. setACount() на пустом atime возвращает 0 и делает atime ненулевым,
// но с датой 1970 года. Такой atime нельзя передавать в alertSet*(): проверка
// только "At != 0" его пропустит. Перед записью атрибута тревоги нужны обе
// проверки: t != 0 и At != 0.

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
  DebugN("=== setACount() ===");
  DebugN("  сигнатура: int setACount(atime &AlertTime, uint AlertNo)");

  time t = getCurrentTime();
  atime At = makeATime(t, 0, "System1:ExampleDP_DDE.b1");

  dpdCheck("atime собран из ненулевого времени", At != 0);
  dpdCheck("начальный номер тревоги — 0", getACount(At) == 0);

  int rc = setACount(At, 7);
  DebugN("  setACount(At, 7) rc=", rc, " count=", getACount(At));
  dpdCheck("setACount(At, 7) вернул 0", rc == 0);
  dpdCheck("номер стал 7", getACount(At) == 7);

  rc = setACount(At, 0);
  DebugN("  setACount(At, 0) rc=", rc, " count=", getACount(At));
  dpdCheck("setACount(At, 0) вернул 0 и сбросил номер", rc == 0 && getACount(At) == 0);

  rc = setACount(At, 300);
  DebugN("  setACount(At, 300) rc=", rc, " count=", getACount(At));
  dpdCheck("номер 300 записан", rc == 0 && getACount(At) == 300);

  // --- пустой atime: измеренная ловушка ----------------------------------
  atime Z;
  dpdCheck("пустой atime равен нулю", Z == 0);
  dpdCheck("getACount(пустой atime) — 0", getACount(Z) == 0);

  rc = setACount(Z, 5);
  DebugN("  setACount(пустой, 5) rc=", rc, " Z='", (string)Z, "' count=", getACount(Z));
  dpdCheck("setACount на пустом atime вернул 0", rc == 0);
  dpdCheck("после setACount пустой atime стал ненулевым", Z != 0);
  dpdCheck("но его дата — 1970 (в alertSet нельзя)", substr((string)Z, 0, 4) == "1970");

  dpdSummary();
  exit(0);
}
