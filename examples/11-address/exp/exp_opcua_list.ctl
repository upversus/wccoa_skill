// exp_opcua_list.ctl - ЧТЕНИЕ: откуда панель берёт Сервер и Подписку.
//
// Только чтение. Системные точки не изменяются.
//
// На снимке панели Para_12:
//     Сервер:       kep        (выпадающий список)
//     Подписка:     kep_sub    (выпадающий список + кнопка обзора)
//     Вариант:      ID узла
//     Элем.:        ns=2;s=Simulation Examples.Functions.User3
//     Драйвер:      3
//     Направление:  Вход
//     Режим приема: Спонтанный
//
// Вопросы:
//   1. Есть ли отдельные атрибуты для сервера и подписки, или они только
//      внутри строки _reference?
//   2. Откуда панель берёт список допустимых значений?
//   3. Почему панель показывает "Спонтанный", если ставился INPUT_POLL?
//
// Замечание: строковые функции в CTL неизвестны, поэтому отбор имён сделан
// шаблонами dpNames, а не поиском подстроки.

main()
{
  DebugN("=== 1. Все атрибуты _address на элементе bUser3 ===");
  dyn_string attrs = dpGetAllAttributes("_address");
  for (int i = 1; i <= dynlen(attrs); i++)
  {
    DebugN("   ", attrs[i], " = '",
           readAny("opcChk.bUser3:_address.." + attrs[i]), "'");
  }

  DebugN("");
  DebugN("=== 2. Конфиги _distrib и _connect на элементе ===");
  showCfg("opcChk.bUser3:", "_distrib");
  showCfg("opcChk.bUser3:", "_connect");
  showCfg("opcChk.bUser3:", "_original");

  DebugN("");
  DebugN("=== 3. Поиск системных точек OPC UA по шаблонам имён ===");
  show("_*Opc*");
  show("*Opc*");
  show("_UA*");
  show("_Ua*");
  show("_Sub*");
  show("_OpcUa*");
  show("_UaServer*");

  DebugN("");
  DebugN("=== 4. Типы точек данных с OPC или UA в названии ===");
  showType("_OpcUa*");
  showType("_UA*");

  DebugN("=== конец. Скрипт ничего не изменял. ===");
}

void showCfg(string dpe, string cfg)
{
  dyn_string at = dpGetAllAttributes(cfg);
  DebugN("   конфиг ", cfg, " (", dynlen(at), " атрибутов)");
  for (int i = 1; i <= dynlen(at); i++)
  {
    DebugN("      ", at[i], " = '", readAny(dpe + cfg + ".." + at[i]), "'");
  }
}

void show(string pattern)
{
  dyn_string r = dpNames(pattern);
  if (dynlen(r) == 0) { return; }
  DebugN("   шаблон ", pattern, " -> ", dynlen(r), " шт.");
  for (int i = 1; i <= dynlen(r); i++)
  {
    DebugN("      ", r[i], "   тип=", dpTypeName(r[i] + "."));
  }
}

void showType(string pattern)
{
  dyn_string r = dpNames(pattern);
  for (int i = 1; i <= dynlen(r); i++)
  {
    DebugN("   ", r[i], "   тип=", dpTypeName(r[i] + "."));
  }
}

string readAny(string item)
{
  dyn_anytype v;
  int rc = dpGet(item, v);
  if (rc != 0) { return "<rc=" + rc + ">"; }
  return "" + v;
}