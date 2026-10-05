// exp_opcua_sysmgm.ctl - ЧТЕНИЕ точки _SysMgm_DriverOpc.
//
// Только чтение.
//
// Найдена единственная точка, связанная с OPC UA: _SysMgm_DriverOpc,
// тип _SysMgm. Панель Para показывает Сервер и Подписку выпадающими
// списками, значит где-то должен храниться перечень допустимых значений.
// Проверяем эту точку.
//
// Также проверяем, что панель показывает "Спонтанный" при _direction = 4.

main()
{
  DebugN("=== 1. Конфиги _SysMgm_DriverOpc ===");
  dyn_string cfgs = dpGetAllConfigs("_SysMgm_DriverOpc:");
  DebugN("  конфигов: ", dynlen(cfgs));
  for (int c = 1; c <= dynlen(cfgs); c++)
  {
    DebugN("  --- ", cfgs[c], " ---");
    dyn_string at = dpGetAllAttributes(cfgs[c]);
    for (int i = 1; i <= dynlen(at); i++)
    {
      string v = readAny("_SysMgm_DriverOpc:" + cfgs[c] + ".." + at[i]);
      DebugN("       ", at[i], " = '", v, "'");
    }
  }

  DebugN("");
  DebugN("=== 2. Атрибуты самой точки (без конфига) ===");
  dyn_string own = dpGetAllAttributes("_SysMgm_DriverOpc");
  DebugN("  атрибутов: ", dynlen(own));
  for (int i = 1; i <= dynlen(own); i++)
  {
    DebugN("     ", own[i], " = '", readAny("_SysMgm_DriverOpc:" + own[i]), "'");
  }

  DebugN("");
  DebugN("=== 3. Все точки типа _SysMgm ===");
  dyn_string all = dpNames("**");
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpTypeName(all[i] + ".") == "_SysMgm")
    {
      DebugN("   ", all[i]);
    }
  }

  DebugN("");
  DebugN("=== 4. Проверка направления: панель против значения ===");
  DebugN("   _direction на bUser3 = '", readAny("opcChk.bUser3:_address.._direction"), "'");
  DebugN("   _mode      на bUser3 = '", readAny("opcChk.bUser3:_address.._mode"), "'");
  DebugN("   На снимке панели Para_12 выбран режим приема: Спонтанный");

  DebugN("=== конец. Скрипт ничего не изменял. ===");
}

string readAny(string item)
{
  dyn_anytype v;
  int rc = dpGet(item, v);
  if (rc != 0) { return "<rc=" + rc + ">"; }
  return "" + v;
}