// inventory.ctl - полный перечень типов и точек данных в проекте.
//
// Нужен перед уборкой: удалять вслепую нельзя, часть объектов может
// принадлежать пользователю. Печатает всё, с меткой "СИСТЕМНАЯ" для
// системных объектов (имя начинается с подчёркивания), их не трогаем.

main()
{
  DebugN("=== Инвентаризация ===");

  DebugN("");
  DebugN("--- ВСЕ ТИПЫ ТОЧЕК ДАННЫХ ---");
  dyn_string types = dpTypes("*");
  DebugN("  всего типов: ", dynlen(types));
  for (int i = 1; i <= dynlen(types); i++)
  {
    string mark = (types[i][1] == "_") ? "  СИСТЕМНАЯ" : "";
    dyn_string members = dpNames("*", types[i]);
    DebugN("  [", types[i], "] точек данных: ", dynlen(members), mark);
  }

  DebugN("");
  DebugN("--- ТИПЫ НЕ-СИСТЕМНЫЕ, С ГРУППИРОВКОЙ ПО ИМЕНИ ---");
  dyn_string user;
  for (int i = 1; i <= dynlen(types); i++)
  {
    if (types[i][1] != "_") { user[dynlen(user) + 1] = types[i]; }
  }
  DebugN("  не-системных типов: ", dynlen(user));
  for (int i = 1; i <= dynlen(user); i++)
  {
    dyn_string members = dpNames("*", user[i]);
    DebugN("  ", user[i], "  ->  ", dynlen(members), " шт.");
    for (int j = 1; j <= dynlen(members); j++)
    {
      DebugN("        ", members[j]);
    }
  }

  DebugN("");
  DebugN("--- ТОЧКИ ДАННЫХ ВНЕ СИСТЕМНЫХ ТИПОВ ---");
  dyn_string loose;
  for (int i = 1; i <= dynlen(types); i++)
  {
    if (types[i][1] == "_") { continue; }
    dyn_string members = dpNames("*", types[i]);
    for (int j = 1; j <= dynlen(members); j++)
    {
      loose[dynlen(loose) + 1] = members[j];
    }
  }
  DebugN("  всего: ", dynlen(loose));
  for (int i = 1; i <= dynlen(loose); i++)
  {
    DebugN("      ", loose[i]);
  }

  DebugN("");
  DebugN("=== конец ===");
}