// exp_opcua_nodes.ctl - ЧТЕНИЕ: где именно лежат Сервер и Подписка.
//
// Только чтение.
//
// Пользователь прислал снимок дерева Para: сервер и подписка являются
// точками данных. На снимке видны имена:
//     V = OPCUAServer
//     V = kep
//     V = OpcUaSubscription
//       kep_sub
//
// Раньше эти точки не нашлись, потому что поиск шёл по шаблонам с
// подчёркиванием. Проверяем имя без подчёркивания, с подчёркиванием
// и другие варианты написания.
//
// Строковые функции в CTL не используются: отбор по шаблонам dpNames.

main()
{
  DebugN("=== 1. Поиск по шаблонам ===");
  show("OpcUAServer*");
  show("_OpcUAServer*");
  show("OpcUa*");
  show("_OpcUa*");
  show("OpcUA*");
  show("_OpcUA*");
  show("kep*");
  show("_kep*");

  DebugN("");
  DebugN("=== 2. Проверка существования поимённо ===");
  exists("OpcUAServer");
  exists("_OpcUAServer");
  exists("OpcUAServer.kep");
  exists("kep");
  exists("_kep");
  exists("kep.");
  exists("OpcUaSubscription");
  exists("_OpcUaSubscription");
  exists("OpcUaSubscription.kep_sub");
  exists("kep_sub");
  exists("_kep_sub");
  exists("kep.kep_sub");
  exists("kep_sub.");

  DebugN("=== конец. Скрипт ничего не изменял. ===");
}

void show(string pattern)
{
  dyn_string r = dpNames(pattern);
  if (dynlen(r) == 0)
  {
    DebugN("   ", pattern, " -> ничего");
    return;
  }
  DebugN("   ", pattern, " -> ", dynlen(r), " шт.");
  for (int i = 1; i <= dynlen(r); i++)
  {
    DebugN("      ", r[i], "   тип=", dpTypeName(r[i] + "."));
  }
}

void exists(string name)
{
  bool e = dpExists(name);
  string tn = "";
  if (e) { tn = dpTypeName(name + "."); }
  DebugN("   dpExists('", name, "') = ", e, "   тип=", tn);
}