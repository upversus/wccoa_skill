// exp_opcua_types.ctl - ЧТЕНИЕ типов _OPCUAServer и _OPCUASubscription.
//
// Только чтение.
//
// dpNames() отбирает по ИМЕНИ, а не по типу: шаблон "*_OPCUAServer" дал ноль,
// хотя точка _kep типа _OPCUAServer существует. Перебор поэтому делается по
// dpNames("_**") с проверкой dpTypeName().
//
// У этих типов, как и у _Mod_Plc, dpGetAllConfigs возвращает 0 - значит
// сведения лежат в структуре типа. Читаем её через dpTypeGet.

main()
{
  DebugN("=== 1. Перебор системных точек по типу ===");
  DebugN("--- тип _OPCUAServer ---");
  findByType("_OPCUAServer");
  DebugN("--- тип _OPCUASubscription ---");
  findByType("_OPCUASubscription");

  DebugN("");
  DebugN("=== 2. Структура типа _OPCUAServer ===");
  dumpType("_OPCUAServer");

  DebugN("");
  DebugN("=== 3. Структура типа _OPCUASubscription ===");
  dumpType("_OPCUASubscription");

  DebugN("=== конец. Скрипт ничего не изменял. ===");
}

void findByType(string wanted)
{
  dyn_string all = dpNames("_**");
  int found = 0;
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpTypeName(all[i] + ".") == wanted)
    {
      found++;
      DebugN("   ", all[i]);
    }
  }
  DebugN("   всего: ", found);
}

void dumpType(string typeName)
{
  dyn_dyn_string names;
  dyn_dyn_int types;
  int rc = dpTypeGet(typeName, names, types);
  DebugN("   dpTypeGet rc=", rc, "  элементов: ", dynlen(names));
  for (int i = 1; i <= dynlen(names); i++)
  {
    string path = "";
    for (int j = 1; j <= dynlen(names[i]); j++)
    {
      if (names[i][j] != "") { path = path + "." + names[i][j]; }
    }
    string tl = "";
    if (i <= dynlen(types))
    {
      for (int j = 1; j <= dynlen(types[i]); j++) { tl = tl + " " + types[i][j]; }
    }
    DebugN("      [", i, "] ", path, "   типы:", tl);
  }
}