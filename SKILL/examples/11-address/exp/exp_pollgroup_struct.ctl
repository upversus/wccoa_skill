// exp_pollgroup_struct.ctl - ЧТЕНИЕ структуры системной точки _PollGroup.
//
// ВНИМАНИЕ: ничего не изменяется. Только чтение. Точка _1s - системная.
//
// Задача: выяснить, где хранятся параметры опроса, без которых создать
// новую группу невозможно. Никаких предположений - только что вернули чтения.
//
// Проверено: CTL 3.18, проект <проект стенда>.

main()
{
  DebugN("=== Атрибуты небольших конфигов _1s ===");

  dump("_distrib");
  dump("_logger");

  DebugN("");
  DebugN("=== Все атрибуты конфига _general ===");
  dump("_general");

  DebugN("");
  DebugN("=== Прямые попытки прочитать вероятные имена ===");
  tryRead("_general..poll_time");
  tryRead("_general..polltime");
  tryRead("_general..pollTime");
  tryRead("_general..PollTime");
  tryRead("_general..interval");
  tryRead("_general..mode");
  tryRead("_general..active");
  tryRead("_general..sync_time");
  tryRead("_logger..poll_time");
  tryRead("_logger..mode");
  tryRead("_logger..active");
  tryRead("_logger..interval");
  tryRead("_distrib..poll_time");
  tryRead("_distrib..mode");

  DebugN("");
  DebugN("=== конец. Скрипт ничего не изменял. ===");
}

void dump(string cfg)
{
  dyn_string attrs = dpGetAllAttributes(cfg);
  DebugN("--- ", cfg, ": атрибутов ", dynlen(attrs), " ---");
  for (int i = 1; i <= dynlen(attrs); i++)
  {
    DebugN("   ", attrs[i], " = '", readAny("_1s.:" + cfg + ".." + attrs[i]), "'");
  }
}

void tryRead(string tail)
{
  DebugN("  ", tail, " -> '", readAny("_1s.:" + tail), "'");
}

string readAny(string item)
{
  dyn_anytype v;
  int rc = dpGet(item, v);
  if (rc != 0) { return "<rc=" + rc + ">"; }
  return "" + v;
}