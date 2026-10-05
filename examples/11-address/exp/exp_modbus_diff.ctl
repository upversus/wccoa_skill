// exp_modbus_diff.ctl - полное сравнение атрибутов эталона и точки, созданной
// скриптом.
//
// Эталон ExampleDP_Arg1 настроен через панель Para_36 и работает.
// Точка dpdemo_wait_1 создана скриптом и не работает.
// На снимке панели виден параметр "Группа опроса: 1s", который скриптом не
// выставлялся ни разу - возможно, без него драйвер не опрашивает адрес.
//
// Печатаем все атрибуты обоих конфигов _address и помечаем различия.
//
// Проверено: CTL 3.18, проект prg_12_3.

main()
{
  DebugN("=== Сравнение атрибутов _address ===");

  DebugN("");
  DebugN("--- ЭТАЛОН: ExampleDP_Arg1. ---");
  dyn_string refAttrs = dpGetAllAttributes("_address");
  for (int i = 1; i <= dynlen(refAttrs); i++)
  {
    DebugN("  ", refAttrs[i], " = ", getAny("ExampleDP_Arg1.:_address.." + refAttrs[i]));
  }

  DebugN("");
  DebugN("--- СКРИПТ: dpdemo_wait_1.e ---");
  dyn_string myAttrs = dpGetAllAttributes("_address");
  for (int i = 1; i <= dynlen(myAttrs); i++)
  {
    DebugN("  ", myAttrs[i], " = ", getAny("dpdemo_wait_1.e:_address.." + myAttrs[i]));
  }

  DebugN("");
  DebugN("=== Список конфигов точки данных (эталон) ===");
  dyn_string refCfgs = dpGetAllConfigs("ExampleDP_Arg1.:");
  for (int i = 1; i <= dynlen(refCfgs); i++)
  {
    DebugN("  ", refCfgs[i]);
  }

  DebugN("");
  DebugN("=== Список конфигов точки данных (скрипт) ---");
  dyn_string myCfgs = dpGetAllConfigs("dpdemo_wait_1.e:");
  for (int i = 1; i <= dynlen(myCfgs); i++)
  {
    DebugN("  ", myCfgs[i]);
  }

  DebugN("=== конец ===");
}

string getAny(string item)
{
  int rc;
  dyn_anytype v;
  rc = dpGet(item, v);
  if (rc != 0) { return "<нет значения, rc=" + rc + ">"; }
  return "" + v;
}