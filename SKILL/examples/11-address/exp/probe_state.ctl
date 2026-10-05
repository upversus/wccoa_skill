// probe_state.ctl - что осталось на стенде после прогона всех примеров.
//
// Проверяет предусловия, на которые опираются существующие примеры:
//   f1               - эталонная точка, на которую ссылается 11-address.md
//                      (f1.f_node снят как образец конфигурации);
//   for_test_OPCUA   - пользовательский тип, который 04_address_recreate.ctl
//                      НЕ создаёт и НЕ удаляет, а просто требует наличия.
//
// 04_address_recreate.ctl удаляет f1 в начале и не восстанавливает её,
// поэтому второй прогон даёт 2/19. Этот скрипт проверяет, что осталось после него.

main()
{
  DebugN("=== Состояние стенда ===");

  DebugN("");
  DebugN("--- эталонная точка f1 ---");
  DebugN("  dpExists(\"f1\")            = ", dpExists("f1"));
  DebugN("  dpTypeName(\"f1.\")         = '", dpTypeName("f1."), "'");
  dyn_string fe = dpNames("f1.*");
  DebugN("  элементов в f1             = ", dynlen(fe));
  for (int i = 1; i <= dynlen(fe); i++)
  {
    DebugN("      ", fe[i]);
  }

  DebugN("");
  DebugN("--- тип for_test_OPCUA ---");
  dyn_dyn_string pn;
  dyn_dyn_int pt;
  int rcT = dpTypeGet("for_test_OPCUA", pn, pt);
  DebugN("  dpTypeGet rc=             = ", rcT);
  if (rcT == 0)
  {
    DebugN("  элементов в типе          = ", dynlen(pn));
    for (int i = 1; i <= dynlen(pn); i++)
    {
      DebugN("      ", pn[i]);
    }
  }

  DebugN("");
  DebugN("--- остатки прошлых прогонов ---");
  dyn_string leftovers = dpNames("dpdemo_*");
  DebugN("  точек dpdemo_*             = ", dynlen(leftovers));
  for (int i = 1; i <= dynlen(leftovers); i++)
  {
    DebugN("      ", leftovers[i]);
  }

  dyn_string strayTypes = dpTypes("dpdemo_*");
  DebugN("  типов dpdemo_*             = ", dynlen(strayTypes));
  for (int i = 1; i <= dynlen(strayTypes); i++)
  {
    DebugN("      ", strayTypes[i]);
  }

  DebugN("");
  DebugN("=== конец ===");
}