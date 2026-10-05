// exp_opcua_pairs.ctl - ЧТЕНИЕ: какие Сервер/Подписка используются в проекте.
//
// Только чтение.
//
// Установлено:
//   * отдельных атрибутов для Сервера и Подписки нет - это первые два поля
//     строки _reference;
//   * системных точек со списком серверов нет, _SysMgm_* через CTL не читается.
//
// Проверяем, можно ли собрать перечень из уже настроенных точек проекта.
//
// Замечание: разбор строки по символу '$' НЕ делается. Строковые функции CTL
// неизвестны (substr, strpos, charAt - не подтверждены, из них часть просто
// не существует). Поэтому печатаем _reference целиком: пары видны глазами.
//
// Также проверяем, принимает ли dpGet имя с префиксом системы, который
// возвращает dpNames. Если принимает - отпадает необходимость его срезать.

main()
{
  DebugN("=== 1. Все элементы данных проекта ===");
  dyn_string all = dpNames("*.*");
  DebugN("  всего элементов: ", dynlen(all));

  DebugN("");
  DebugN("=== 2. Читается ли имя с префиксом системы ===");
  if (dynlen(all) > 0)
  {
    string s;
    int rcPref = dpGet(all[1] + ":_address.._drv_ident", s);
    DebugN("  ", all[1]);
    DebugN("     dpGet с префиксом: rc=", rcPref, "  значение='", s, "'");
  }

  DebugN("");
  DebugN("=== 3. Элементы с драйвером OPC UA: их _reference ===");

  int ua = 0;
  for (int i = 1; i <= dynlen(all); i++)
  {
    string ident;
    int rc = dpGet(all[i] + ":_address.._drv_ident", ident);
    if (rc != 0) { continue; }
    if (ident != "OPCUA") { continue; }

    string ref;
    dpGet(all[i] + ":_address.._reference", ref);
    int dt;
    dpGet(all[i] + ":_address.._datatype", dt);

    ua++;
    DebugN("  ", all[i]);
    DebugN("      _reference = ", ref);
    DebugN("      _datatype  = ", dt);
  }
  DebugN("  всего элементов с драйвером OPC UA: ", ua);

  DebugN("");
  DebugN("=== 4. Тот же перебор по корневым элементам (шаблон *.) ===");
  dyn_string roots = dpNames("*.");
  int uaRoot = 0;
  for (int i = 1; i <= dynlen(roots); i++)
  {
    string ident;
    int rc = dpGet(roots[i] + ":_address.._drv_ident", ident);
    if (rc == 0 && ident == "OPCUA")
    {
      string ref;
      dpGet(roots[i] + ":_address.._reference", ref);
      uaRoot++;
      DebugN("  ", roots[i], "   ->   ", ref);
    }
  }
  DebugN("  корневых элементов с OPC UA: ", uaRoot);

  DebugN("=== конец. Скрипт ничего не изменял. ===");
}