// exp_mb_fixpoll.ctl - ИСПРАВЛЕНИЕ висячей ссылки _poll_group.
//
// Ситуация: группа опроса _1s удалена, создана новая _pool2s. В конфигах
// _address уже созданных точек осталась ссылка на внутренний идентификатор
// удалённой точки: (Type: 0 Sys: 1 Dp: 670 El: 0 : ..).
//
// Исправление: перепривязать _poll_group на действующую группу опроса.
// Группу не создаём - это обязанность пользователя.
//
// Важная оговорка: по состоянию на момент диагностики опрос продолжал идти
// несмотря на битую ссылку. Драйвер держит разрешённую конфигурацию сам.
// То есть исправление убирает битую ссылку из проекта, но появление данных
// после него ожидать нельзя - они и так шли.
//
// Проверено: CTL 3.18, проект <проект стенда>.

main()
{
  string pollGroup = findPollGroup();
  if (pollGroup == "")
  {
    DebugN("  FAIL  группа опроса не найдена.");
    DebugN("  Создайте её: панель системы -> Drivers -> Poll groups.");
    return;
  }
  DebugN("Новая группа опроса: ", pollGroup);

  DebugN("");
  DebugN("=== Перепривязка ===");

  // Точки данных, созданные скриптом
  fix("dpdemo_mb_a.fVal");
  fix("dpdemo_mb_a.iVal");
  fix("dpdemo_mb_a.bVal");
  fix("dpdemo_mb_b.fVal");
  fix("dpdemo_mb_b.iVal");
  fix("dpdemo_mb_b.bVal");
  // Эталон, настроенный вручную - по указанию пользователя
  fix("ExampleDP_Arg1.");

  DebugN("");
  DebugN("=== Контрольная проверка ===");
  delay(8);

  check("dpdemo_mb_a.fVal");
  check("dpdemo_mb_a.iVal");
  check("dpdemo_mb_a.bVal");
  check("dpdemo_mb_b.fVal");
  check("dpdemo_mb_b.iVal");
  check("dpdemo_mb_b.bVal");
  check("ExampleDP_Arg1.");

  DebugN("=== конец ===");
}

void fix(string dpe)
{
  string before;
  int rcB = dpGet(dpe + ":_address.._poll_group", before);

  int rc = dpSetTimedWait(0, dpe + ":_address.._poll_group", findPollGroup());

  string after;
  int rcA = dpGet(dpe + ":_address.._poll_group", after);

  DebugN("  ", dpe);
  DebugN("      было : '", before, "'  rc=", rcB);
  DebugN("      стало: '", after, "'  rc=", rcA, "  запись rc=", rc);
}

void check(string dpe)
{
  string group;
  int rc = dpGet(dpe + ":_address.._poll_group", group);

  bool bad;
  time t;
  dyn_anytype v;
  dpGet(dpe + ":_online.._bad",   bad);
  dpGet(dpe + ":_online.._stime", t);
  dpGet(dpe + ":_online.._value", v);
  bool hasData = (t != makeTime(1970, 1, 1, 3, 0, 0));

  bool groupOk = (group == findPollGroup());
  bool dataOk  = (hasData && !bad);

  DebugN("  ", (groupOk && dataOk) ? "PASS" : "FAIL", "  ", dpe,
         "  группа='", group, "'  данные=", dataOk, "  значение=", v);
}

// Группа опроса: пользователь создаёт заранее, скрипт берёт первую
// найденную точку данных типа _PollGroup.
string findPollGroup()
{
  dyn_string all = dpNames("_**");
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpTypeName(all[i] + ".") == "_PollGroup")
    {
      return all[i];
    }
  }
  return "";
}