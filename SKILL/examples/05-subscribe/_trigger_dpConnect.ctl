// _trigger_dpConnect.ctl - служебный скрипт к примеру 01_dpConnect.ctl.
//
// НЕ ПРИМЕР. Имя начинается с "_", поэтому verify.ps1 его не прогоняет, а
// docs/99-reference.md не считает в общем числе примеров.
//
// Зачем: подписка проверяется только внешним событием. Этот скрипт ставит
// четыре значения в точку, на которую подписан 01_dpConnect.ctl, и завершается.
//
// Запуск (второе окно, пока подписчик жив):
//   .\run-ctl.ps1 -Script .\05-subscribe\_trigger_dpConnect.ctl -Num 201
//
// ВАЖНО: пишем в _original.._value. dpSet() в _online.._value вернёт rc=0,
// но значение не изменится, и подписка промолчит.

string DP = "dpdemo_sub";

main()
{
  DebugN("=== триггер подписки: четыре записи ===");

  int rc;

  rc = dpSet(DP + ".value:_original.._value", 22.3);
  DebugN("  записано 22.3   rc=", rc);
  delay(1);

  rc = dpSet(DP + ".value:_original.._value", 47.5);
  DebugN("  записано 47.5   rc=", rc);
  delay(1);

  rc = dpSet(DP + ".value:_original.._value", -5.25);
  DebugN("  записано -5.25  rc=", rc);
  delay(1);

  rc = dpSet(DP + ".value:_original.._value", 100.0);
  DebugN("  записано 100.0  rc=", rc);

  // Пауза в конце: dpSet() не блокирующий, и без неё последняя запись может
  // не уйти до завершения процесса.
  delay(1);
}
