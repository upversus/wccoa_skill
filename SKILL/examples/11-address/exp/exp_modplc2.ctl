// exp_modplc2.ctl - ЧТЕНИЕ структуры _Mod_Plc с правильным именем.
//
// Только чтение.
//
// Предыдущая попытка читала конфиги по имени с префиксом системы
// ("System1:_Mod_Plc_1:") и получала "DP does not exist". Для доступа к
// конфигам имя должно быть без префикса, как умеет dpNames().
//
// Задача: узнать форму описания PLC, чтобы оценить, что нужно для
// обслуживания Slave ID 3..6.

main()
{
  DebugN("=== 1. Имена без префикса системы ===");
  DebugN("dpExists(\"_Mod_Plc_1\")   = ", dpExists("_Mod_Plc_1"));
  DebugN("dpExists(\"_Mod_Plc_2\")   = ", dpExists("_Mod_Plc_2"));
  DebugN("dpExists(\"_Mod_Plc_1_2\") = ", dpExists("_Mod_Plc_1_2"));
  DebugN("dpExists(\"_Mod_Plc_2_2\") = ", dpExists("_Mod_Plc_2_2"));

  DebugN("");
  DebugN("=== 2. Конфиги _Mod_Plc_1 ===");
  dump("_Mod_Plc_1");

  DebugN("");
  DebugN("=== 3. Конфиги остальных ===");
  dump("_Mod_Plc_1_2");
  dump("_Mod_Plc_2");
  dump("_Mod_Plc_2_2");

  DebugN("");
  DebugN("=== 4. Что вообще есть по именам _Mod_* ===");
  dyn_string all = dpNames("_Mod_*");
  for (int i = 1; i <= dynlen(all); i++)
  {
    DebugN("   ", all[i]);
  }

  DebugN("=== конец. Скрипт ничего не изменял. ===");
}

void dump(string dp)
{
  dyn_string cfgs = dpGetAllConfigs(dp + ":");
  DebugN("--- ", dp, ": конфигов ", dynlen(cfgs), " ---");
  for (int c = 1; c <= dynlen(cfgs); c++)
  {
    DebugN("    конфиг ", cfgs[c]);
    dyn_string attrs = dpGetAllAttributes(cfgs[c]);
    for (int i = 1; i <= dynlen(attrs); i++)
    {
      DebugN("        ", attrs[i], " = '",
             readAny(dp + ":" + cfgs[c] + ".." + attrs[i]), "'");
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