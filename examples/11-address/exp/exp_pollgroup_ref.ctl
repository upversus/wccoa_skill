// exp_pollgroup_ref.ctl - читающий скрипт: как хранится ссылка на группу опроса.
//
// ВНИМАНИЕ: скрипт ничего не изменяет. Только dpExists и dpGet.
// _1s - системная точка данных (имя начинается с подчёркивания), её нельзя
// удалять и нельзя изменять. Здесь она только читается.
//
// Вопрос: где и в каком виде устанавливается ссылка на точку данных группы
// опроса и как она записана на рабочих точках.
//
// Проверено: CTL 3.18, проект prg_12_3.

main()
{
  DebugN("=== 1. Точка данных группы опроса ===");
  DebugN("dpExists(\"_1s\")             = ", dpExists("_1s"));
  DebugN("dpExists(\"System1:_1s\")     = ", dpExists("System1:_1s"));
  DebugN("dpTypeName(\"_1s.\")          = ", dpTypeName("_1s."));

  DebugN("");
  DebugN("=== 2. В каком виде хранится атрибут _poll_group ===");
  DebugN("Документация объявляет _poll_group типом dpid, то есть числовым");
  DebugN("идентификатором точки данных. Проверяем чтением.");

  int idAsInt;
  int rcInt = dpGet("ExampleDP_Arg1.:_address.._poll_group", idAsInt);
  DebugN("  чтение в int    : rc=", rcInt, "  значение=", idAsInt);

  string idAsString;
  int rcStr = dpGet("ExampleDP_Arg1.:_address.._poll_group", idAsString);
  DebugN("  чтение в string : rc=", rcStr, "  значение='", idAsString, "'");

  DebugN("  Вывод: в int НЕ assign-ится (тип DPIDENTIFIER_VAR),");
  DebugN("         в string читается как полное имя с системой.");

  DebugN("");
  DebugN("=== 3. Как записано на рабочих точках ===");
  showDp("ExampleDP_Arg1.",    "эталон, настроен вручную, работает");
  showDp("ExampleDP_AlertHd1.", "из снимка панели Para_36");
  showDp("ExampleDP_Float.",    "плавающее значение");
  showDp("dpdemo_mb_a.fVal",    "создана скриптом, работает");
  showDp("dpdemo_mb_a.bVal",    "создана скриптом, работает");

  DebugN("");
  DebugN("=== 4. Конфиги точки данных группы опроса _1s ===");
  dyn_string cfgs = dpGetAllConfigs("_1s.:");
  DebugN("конфиги (", dynlen(cfgs), "):");
  for (int i = 1; i <= dynlen(cfgs); i++)
  {
    DebugN("   ", cfgs[i]);
  }

  DebugN("");
  DebugN("=== 5. Все группы опроса в проекте ===");
  dyn_string all = dpNames("_**");
  int pollFound = 0;
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpTypeName(all[i] + ".") == "_PollGroup")
    {
      pollFound++;
      DebugN("   ", all[i]);
    }
  }
  DebugN("   всего найдено: ", pollFound);

  DebugN("=== конец. Скрипт ничего не изменял. ===");
}

void showDp(string dpe, string comment)
{
  string group;
  int rc;
  rc = dpGet(dpe + ":_address.._poll_group", group);

  string ref;
  dpGet(dpe + ":_address.._reference", ref);

  string ident;
  dpGet(dpe + ":_address.._drv_ident", ident);

  int dir;
  dpGet(dpe + ":_address.._direction", dir);

  DebugN("  ", dpe, "   ", comment);
  DebugN("      группа опроса = '", group, "'  (rc=", rc, ")");
  DebugN("      адрес         = '", ref, "'");
  DebugN("      драйвер       = '", ident, "'   направление = ", dir);
}

string readAny(string item)
{
  dyn_anytype v;
  int rc = dpGet(item, v);
  if (rc != 0) { return "<rc=" + rc + ">"; }
  return "" + v;
}