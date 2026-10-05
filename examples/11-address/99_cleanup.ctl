// 99_cleanup.ctl - перечень созданых для проверки объектов и их удаление.
//
// Порядок работы: сначала печатается ПОЛНЫЙ перечень с элементами и адресами,
// чтобы можно было проверить, и только затем удаление. Ничего не удаляется
// молча.
//
// Удаляются только объекты, созданные скриптами в ходе проверки стенда.
// Объекты, созданные вручную, не трогаются - они перечислены в разделе
// "НЕ ТРОГАЕМ" исключительно для сравнения.
//
// Потерять ничего нельзя: каждый объект создаётся заново своим примером,
// все скрипты идемпотентны и пересоздают точки данных с нуля.
//
// Проверено: CTL 3.18, проект prg_12_3.

main()
{
  DebugN("=== ПЕРЕЧЕНЬ ОБЪЕКТОВ, СОЗДАННЫХ ДЛЯ ПРОВЕРКИ ===");
  DebugN("");

  listAll("mapPump",  "mapPumpT");
  listAll("mapTemp",  "mapTempT");
  listAll("mapFlow",  "mapFlowT");
  listAll("mapPress", "mapPressT");
  listAll("mapLevel", "mapLevelT");
  listAll("mapValve", "mapValveT");
  listAll("mapWrite", "mapWriteT");
  listAll("opcChk",   "opcChk_t");
  listAll("metaDemo", "metaDemo_t");

  DebugN("");
  DebugN("--- НЕ ТРОГАЕМ: объекты, созданные вручную ---");
  peek("ExampleDP_Arg1", "эталон Modbus, настраивался в Para");
  peek("for_test_OPCUA",  "тип, созданный вручную");
  peek("pit_parse",       "точка, созданная вручную");

  DebugN("");
  DebugN("=== ПЕРЕЧЕНЬ НАПЕЧАТАН. УДАЛЕНИЕ ===");

  drop("mapPump",  "mapPumpT");
  drop("mapTemp",  "mapTempT");
  drop("mapFlow",  "mapFlowT");
  drop("mapPress", "mapPressT");
  drop("mapLevel", "mapLevelT");
  drop("mapValve", "mapValveT");
  drop("mapWrite", "mapWriteT");
  drop("opcChk",   "opcChk_t");
  drop("metaDemo", "metaDemo_t");

  DebugN("");
  DebugN("=== КОНТРОЛЬ ПОСЛЕ УДАЛЕНИЯ ===");
  DebugN("");
  DebugN("--- удалённые объекты должны отсутствовать ---");
  gone("mapPump",  "mapPumpT");
  gone("mapTemp",  "mapTempT");
  gone("mapFlow",  "mapFlowT");
  gone("mapPress", "mapPressT");
  gone("mapLevel", "mapLevelT");
  gone("mapValve", "mapValveT");
  gone("mapWrite", "mapWriteT");
  gone("opcChk",   "opcChk_t");
  gone("metaDemo", "metaDemo_t");

  DebugN("");
  DebugN("--- ручные объекты должны сохраниться ---");
  peek("ExampleDP_Arg1", "эталон Modbus");
  peek("for_test_OPCUA",  "тип, созданный вручную");
  peek("pit_parse",       "точка, созданная вручную");

  DebugN("");
  DebugN("=== конец ===");
}

// ---------------------------------------------------------------- печать

void listAll(string dp, string dpt)
{
  if (!dpExists(dp))
  {
    DebugN("  ОТСУТСТВУЕТ  ", dp, "   (тип ", dpt, ")");
    return;
  }
  string tn = dpTypeName(dp + ".");
  dyn_string els = dpNames(dp + ".*");
  DebugN("  ", dp, "   тип ", tn, "   элементов ", dynlen(els));
  for (int i = 1; i <= dynlen(els); i++)
  {
    // Имена из dpNames идут УЖЕ с префиксом системы:
    // "System1:mapPump.Pump_Current". Склеивать с префиксом имя точки данных
    // нельзя - получится "mapPump.System1:mapPump.Pump_Current" и dpGet
    // ответит "DP does not exist". dpGet принимает имя с префиксом и так.
    string e = els[i];
    string ref;
    string drv;
    int dt;
    dpGet(e + ":_address.._reference", ref);
    dpGet(e + ":_address.._drv_ident", drv);
    dpGet(e + ":_address.._datatype",  dt);
    DebugN("        ", e, "  ", drv, "  ", ref, "  dt=", dt);
  }
}

void peek(string dp, string comment)
{
  bool e = dpExists(dp);
  string tn = "";
  if (e) { tn = dpTypeName(dp + "."); }
  DebugN("  ", (e ? "СОХРАНЁН" : "ОТСУТСТВУЕТ"), "  ", dp, "   тип ", tn, "   ", comment);
}

// ------------------------------------------------------------ удаление

void drop(string dp, string dpt)
{
  if (dpExists(dp))
  {
    dpDelete(dp);
    for (int i = 1; i <= 30; i++)
    {
      if (!dpExists(dp)) { break; }
      delay(1);
    }
  }
  DebugN("  точка ", dp, ": удалена = ", (!dpExists(dp)));
  dropType(dpt);
}

// Тип удаляется в цикле: dpTypeDelete асинхронен, а dpExists для имени типа
// всегда возвращает FALSE и признаком существования не годится.
void dropType(string dpt)
{
  int guard = 0;
  while (guard < 30)
  {
    dyn_dyn_string pn;
    dyn_dyn_int pt;
    if (dpTypeGet(dpt, pn, pt) != 0)
    {
      DebugN("  тип   ", dpt, ": удалён");
      return;
    }
    dpTypeDelete(dpt);
    guard++;
    delay(1);
  }
  DebugN("  тип   ", dpt, ": НЕ УДАЛЁН за 30 попыток");
}

void gone(string dp, string dpt)
{
  bool dpGone = !dpExists(dp);
  dyn_dyn_string pn;
  dyn_dyn_int pt;
  bool tGone = (dpTypeGet(dpt, pn, pt) != 0);
  DebugN("  ", ((dpGone && tGone) ? "УДАЛЁН" : "ОСТАЛСЯ"), "  ", dp, "   тип ", dpt);
}