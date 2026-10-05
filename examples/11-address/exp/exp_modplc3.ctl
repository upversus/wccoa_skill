// exp_modplc3.ctl - ЧТЕНИЕ атрибутов точки _Mod_Plc.
//
// Только чтение.
//
// Установлено: у типа _Mod_Plc нет ни одного конфига (dpGetAllConfigs вернул 0),
// поэтому описание PLC хранится в атрибутах самой точки данных, а не в конфиге
// _address или каком-либо другом.

main()
{
  DebugN("=== Атрибуты точки данных без указания конфига ===");
  dump("_Mod_Plc_1");
  dump("_Mod_Plc_1_2");
  dump("_Mod_Plc_2");
  dump("_Mod_Plc_2_2");

  DebugN("");
  DebugN("=== Тип _Mod_Plc: какие атрибуты он объявляет ===");
  dyn_dyn_string tNames;
  dyn_dyn_int tTypes;
  int rc = dpTypeGet("_Mod_Plc", tNames, tTypes);
  DebugN("dpTypeGet rc=", rc, "  элементов в типе: ", dynlen(tNames));
  for (int i = 1; i <= dynlen(tNames); i++)
  {
    string line = "   ";
    for (int j = 1; j <= dynlen(tNames[i]); j++)
    {
      line = line + " '" + tNames[i][j] + "'";
    }
    DebugN(line, "   типы:");
    if (i <= dynlen(tTypes))
    {
      for (int j = 1; j <= dynlen(tTypes[i]); j++) { DebugN("      ", tTypes[i][j]); }
    }
  }

  DebugN("=== конец. Скрипт ничего не изменял. ===");
}

void dump(string dp)
{
  dyn_string attrs = dpGetAllAttributes(dp);
  DebugN("--- ", dp, ": атрибутов ", dynlen(attrs), " ---");
  for (int i = 1; i <= dynlen(attrs); i++)
  {
    DebugN("    ", attrs[i], " = '", readAny(dp + ":" + attrs[i]), "'");
  }
}

string readAny(string item)
{
  dyn_anytype v;
  int rc = dpGet(item, v);
  if (rc != 0) { return "<rc=" + rc + ">"; }
  return "" + v;
}