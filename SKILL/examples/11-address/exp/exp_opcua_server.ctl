// exp_opcua_server.ctl - ЧТЕНИЕ: содержимое точек _OPCUAServer и
//                         _OPCUASubscription, и перебор их всех.
//
// Только чтение. Точки системные (имя с подчёркиванием) - не изменяем.
//
// Найдено:
//     _kep      тип _OPCUAServer       - сервер OPC UA
//     _kep_sub  тип _OPCUASubscription - подписка OPC UA
//
// В Para они отображаются без подчёркивания: "kep" и "kep_sub".

main()
{
  DebugN("=== 1. Перебор всех серверов и подписок в проекте ===");
  showAll("*_OPCUAServer");
  showAll("*_OPCUASubscription");

  DebugN("");
  DebugN("=== 2. Конфиги сервера _kep ===");
  dump("_kep");

  DebugN("");
  DebugN("=== 3. Конфиги подписки _kep_sub ===");
  dump("_kep_sub");

  DebugN("=== конец. Скрипт ничего не изменял. ===");
}

void showAll(string pattern)
{
  dyn_string r = dpNames(pattern);
  DebugN("   шаблон ", pattern, " -> ", dynlen(r), " шт.");
  for (int i = 1; i <= dynlen(r); i++)
  {
    DebugN("      ", r[i], "   тип=", dpTypeName(r[i] + "."));
  }
}

void dump(string dp)
{
  dyn_string cfgs = dpGetAllConfigs(dp + ":");
  DebugN("   ", dp, ": конфигов ", dynlen(cfgs));
  for (int c = 1; c <= dynlen(cfgs); c++)
  {
    dyn_string at = dpGetAllAttributes(cfgs[c]);
    DebugN("   --- ", cfgs[c], " (", dynlen(at), ") ---");
    for (int i = 1; i <= dynlen(at); i++)
    {
      string v = readAny(dp + ":" + cfgs[c] + ".." + at[i]);
      DebugN("        ", at[i], " = '", v, "'");
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