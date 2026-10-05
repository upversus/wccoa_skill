// exp_modplc.ctl - ЧТЕНИЕ структуры внутренних точек _Mod_Plc.
//
// Только чтение. Ничего не изменяется.
//
// Причина текущего сбоя найдена по логу драйвера:
//   PARAM,WARNING, 54, No host/unit address defined for PLC number: 6
// Драйвер Modbus требует, чтобы каждый номер PLC был описан во внутренней
// точке данных типа _Mod_Plc с адресом хоста и unit. Раньше устройство было
// одно (Number 1), и описание, видимо, уже существовало.
//
// Задача: выяснить форму и содержимое существующих описаний.

main()
{
  DebugN("=== 1. Есть ли тип _Mod_Plc ===");
  DebugN("dpExists(\"_Mod_Plc\") = ", dpExists("_Mod_Plc"));

  DebugN("");
  DebugN("=== 2. Все точки данных этого типа ===");
  dyn_string all = dpNames("_Mod_Plc*");
  DebugN("найдено по шаблону _Mod_Plc*: ", dynlen(all));
  for (int i = 1; i <= dynlen(all); i++)
  {
    DebugN("   ", all[i], "   тип=", dpTypeName(all[i] + "."));
  }

  DebugN("");
  DebugN("=== 3. Ищем по типу среди всех системных точек ===");
  dyn_string sys = dpNames("_**");
  int found = 0;
  for (int i = 1; i <= dynlen(sys); i++)
  {
    if (dpTypeName(sys[i] + ".") == "_Mod_Plc")
    {
      found++;
      DebugN("   ", sys[i]);
      dump(sys[i]);
    }
  }
  DebugN("   всего точек типа _Mod_Plc: ", found);

  DebugN("=== конец. Скрипт ничего не изменял. ===");
}

void dump(string dp)
{
  dyn_string cfgs = dpGetAllConfigs(dp + ":");
  DebugN("--- конфиги ", dp, " (", dynlen(cfgs), ") ---");
  for (int c = 1; c <= dynlen(cfgs); c++)
  {
    dyn_string attrs = dpGetAllAttributes(cfgs[c]);
    for (int i = 1; i <= dynlen(attrs); i++)
    {
      string v = readAny(dp + ":" + cfgs[c] + ".." + attrs[i]);
      if ((v == "") || (v == "0") || (v == "FALSE")) { continue; }
      DebugN("      ", cfgs[c], "..", attrs[i], " = '", v, "'");
    }
  }
}

string readAny(string item)
{
  dyn_anytype v;
  int rc = dpGet(item, v);
  if (rc != 0) { return "<rc=" + rc + ">"; }
  return "" + v;
}