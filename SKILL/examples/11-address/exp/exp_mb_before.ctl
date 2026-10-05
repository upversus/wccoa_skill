// exp_mb_before.ctl - ДИАГНОСТИКА ДО ИСПРАВЛЕНИЯ. Только чтение.
//
// Ситуация: пользователь удалил группу опроса _1s и создал новую с другим
// именем. Конфигурация _address в уже созданных точках данных не исправлена,
// поэтому ссылка _poll_group должна оказаться висячей.
//
// Задача снять доказательство "до": что именно сломано.

main()
{
  DebugN("=== 1. Какие группы опроса есть в проекте ===");

  dyn_string all = dpNames("_**");
  int found = 0;
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpTypeName(all[i] + ".") == "_PollGroup")
    {
      found++;
      DebugN("   ", all[i]);
    }
  }
  DebugN("   всего найдено: ", found);

  DebugN("");
  DebugN("   старая группа _1s существует: ", dpExists("_1s"));

  DebugN("");
  DebugN("=== 2. Что записано в _poll_group у уже созданных точек ===");
  show("dpdemo_mb_a.fVal");
  show("dpdemo_mb_a.iVal");
  show("dpdemo_mb_a.bVal");
  show("dpdemo_mb_b.fVal");
  show("dpdemo_mb_b.iVal");
  show("dpdemo_mb_b.bVal");
  show("ExampleDP_Arg1.");

  DebugN("");
  DebugN("=== 3. Идёт ли опрос сейчас ===");
  data("dpdemo_mb_a.fVal");
  data("dpdemo_mb_a.iVal");
  data("dpdemo_mb_a.bVal");
  data("dpdemo_mb_b.fVal");
  data("dpdemo_mb_b.iVal");
  data("dpdemo_mb_b.bVal");
  data("ExampleDP_Arg1.");

  DebugN("=== конец. Скрипт ничего не изменял. ===");
}

void show(string dpe)
{
  string group;
  int rc = dpGet(dpe + ":_address.._poll_group", group);
  DebugN("  ", dpe, "  группа='", group, "'  rc=", rc);
}

void data(string dpe)
{
  bool bad;
  time t;
  dyn_anytype v;
  dpGet(dpe + ":_online.._bad",   bad);
  dpGet(dpe + ":_online.._stime", t);
  dpGet(dpe + ":_online.._value", v);
  bool hasData = (t != makeTime(1970, 1, 1, 3, 0, 0));
  DebugN("  ", dpe, "  ", (hasData && !bad) ? "ДАННЫЕ" : "НЕТ   ",
         "  bad=", bad, "  значение=", v, "  stime=", t);
}