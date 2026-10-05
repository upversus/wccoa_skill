// probe_checkquery.ctl - что именно возвращает checkQuery() на заведомо
// правильном запросе с TIMERANGE.
//
// Запрос гарантированно синтаксически правильный, поэтому ожидается 0.
// Дополнительно печатается dpQuery() на том же тексте для сравнения:
// у функций разные соглашения об ошибке, и это надо видеть в одном прогоне.

main()
{
  DebugN("=== checkQuery на эталонном запросе ===");

  string q =
        "SELECT '_original.._value' "
      + "FROM 'ExampleDP_Arg1.' "
      + "TIMERANGE(\"2026.10.04 13:34:18\",\"2026.10.04 21:34:31\",1,0) "
      + "LAST 10";

  DebugN("  запрос:");
  DebugN("  ", q);
  DebugN("");

  // Проверка синтаксиса. Должно быть 0.
  int r = checkQuery(q);
  DebugN("  checkQuery()   = ", r);
  DebugN("  getLastError() = ", getLastError());
  DebugN("");

  // Для сравнения: тот же запрос через dpQuery().
  dyn_dyn_anytype tab;
  int rq = dpQuery(q, tab);
  DebugN("  dpQuery()      = ", rq, "   строк в таблице: ", dynlen(tab));
  DebugN("  getLastError() = ", getLastError());
  DebugN("");

  // Разбор первых строк результата.
  DebugN("  строк данных (минус заголовок): ", dynlen(tab) - 1);
  for (int z = 2; z <= dynlen(tab) && z <= 4; z++)
  {
    DebugN("    ", tab[z][2]);
  }
  if (dynlen(tab) > 1)
  {
    DebugN("    ...");
    DebugN("    ", tab[dynlen(tab)][2]);
  }

  DebugN("");
  DebugN("  ВЕРДИКТ:");
  DebugN("    checkQuery == 0  -> ", (r == 0) ? "ДА, синтаксис признан верным" : "НЕТ");
  DebugN("    dpQuery    == 0  -> ", (rq == 0) ? "ДА, запрос выполнен" : "НЕТ");
  DebugN("=== конец ===");
}