// exp_modplc4.ctl - ЧТЕНИЕ значений описания PLC.
//
// Только чтение.
//
// Тип _Mod_Plc содержит элементы:
//   PlcNumber, UnitAddress, HostsAndPorts, TransactionTimeout, Coding,
//   DrvNumber, Active, Offset, ConfigFlags и служебные счётчики кадров.
//
// dpGetAllConfigs вернул 0 конфигов, а dpGetAllAttributes без конфига -
// 0 атрибутов: значит элементы лежат на самой точке данных и путь к ним
// не через конфиг. Форма пути перебирается ниже.

main()
{
  DebugN("=== 1. Перебор форм пути к PlcNumber ===");
  tryRead("_Mod_Plc_1.:PlcNumber");
  tryRead("_Mod_Plc_1..PlcNumber");
  tryRead("_Mod_Plc_1.:.PlcNumber");
  tryRead("System1:_Mod_Plc_1.:PlcNumber");

  DebugN("");
  DebugN("=== 2. Если путь найден - читаем остальные поля ===");
  tryRead("_Mod_Plc_1.:UnitAddress");
  tryRead("_Mod_Plc_1.:HostsAndPorts");
  tryRead("_Mod_Plc_1.:TransactionTimeout");
  tryRead("_Mod_Plc_1.:Coding");
  tryRead("_Mod_Plc_1.:DrvNumber");
  tryRead("_Mod_Plc_1.:Active");
  tryRead("_Mod_Plc_1.:Offset");
  tryRead("_Mod_Plc_1.:ConfigFlags");
  tryRead("_Mod_Plc_1.:ConnState");
  tryRead("_Mod_Plc_1.:Error");

  DebugN("");
  DebugN("=== 3. Для сравнения - второе устройство ===");
  tryRead("_Mod_Plc_2.:PlcNumber");
  tryRead("_Mod_Plc_2.:UnitAddress");
  tryRead("_Mod_Plc_2.:HostsAndPorts");
  tryRead("_Mod_Plc_2.:DrvNumber");
  tryRead("_Mod_Plc_2.:Active");

  DebugN("=== конец. Скрипт ничего не изменял. ===");
}

void tryRead(string item)
{
  dyn_anytype v;
  int rc = dpGet(item, v);
  if (rc != 0)
  {
    DebugN("  ", item, " -> rc=", rc);
    return;
  }
  DebugN("  ", item, " -> '", v, "'");
}