// exp_inventory.ctl - инвентаризация созданных объектов. Только чтение.
//
// Задача: перед уборкой понять, что осталось в проекте от исследований,
// а что является рабочим примером. Ничего не удаляет.

main()
{
  DebugN("=== Инвентаризация точек данных и типов ===");

  // ---- рабочие примеры: их сохраняем ----
  DebugN("");
  DebugN("--- РАБОЧИЕ ПРИМЕРЫ (сохраняем) ---");
  show("mapPump");
  show("mapTemp");
  show("mapFlow");
  show("mapPress");
  show("mapLevel");
  show("mapValve");
  show("mapWrite");
  show("opcChk");
  show("metaDemo");

  // ---- объекты экспериментов: кандидаты на удаление ----
  DebugN("");
  DebugN("--- ОБЪЕКТЫ ЭКСПЕРИМЕНТОВ (кандидаты на удаление) ---");
  show("dpdemo_mb_a");
  show("dpdemo_mb_b");
  show("dpdemo_mbprobe_1");
  show("mapprobe");
  show("dpdemo_wait_1");
  show("dpdemo_line_1");
  show("dpdemo_width_1");
  show("dpdemo_fc_1");
  show("dpdemo_dir_1");
  show("dpdemo_seq_1");
  show("dpdemo_mbalive_1");
  show("dpdemo_opcua_check");
  show("dpdemo_recreate");
  show("opcFields");
  show("opcBrowse");
  show("opcB2");

  // ---- типы ----
  DebugN("");
  DebugN("--- ТИПЫ, созданные скриптами ---");
  dyn_string all = dpNames("*.**");
  for (int i = 1; i <= dynlen(all); i++)
  {
    // Корень типа виден как элемент с пустым именем после точки
    if (all[i] == "") { continue; }
  }

  // Типы перечисляем через имена DPT: если точка удалена, тип может остаться
  DebugN("--- проверка типов по именам ---");
  checkType("mapPumpT");
  checkType("mapTempT");
  checkType("mapFlowT");
  checkType("mapPressT");
  checkType("mapLevelT");
  checkType("mapValveT");
  checkType("mapWriteT");
  checkType("opcChk_t");
  checkType("metaDemo_t");
  checkType("dpdemo_mb");
  checkType("dpdemo_mbprobe_t");
  checkType("dpdemo_wait_t");
  checkType("dpdemo_line_t");
  checkType("dpdemo_width_t");
  checkType("dpdemo_fc_t");
  checkType("dpdemo_dir_t");
  checkType("dpdemo_seq_t");
  checkType("dpdemo_mbalive_t");
  checkType("dpdemo_opcua_check_t");
  checkType("dpdemo_opcua_check");
  checkType("mapprobe_t");
  checkType("opcFields_t");
  checkType("opcBrowse_t");
  checkType("opcB2_t");

  DebugN("");
  DebugN("=== конец. Скрипт ничего не изменял. ===");
}

void show(string dp)
{
  if (dpExists(dp))
  {
    string tn = dpTypeName(dp + ".");
    int n = 0;
    dyn_string els = dpNames(dp + ".*");
    n = dynlen(els);
    DebugN("  ЕСТЬ   ", dp, "   тип=", tn, "   элементов=", n);
  }
  else
  {
    DebugN("  нет    ", dp);
  }
}

void checkType(string dpt)
{
  dyn_dyn_string n;
  dyn_dyn_int t;
  int rc = dpTypeGet(dpt, n, t);
  if (rc == 0)
  {
    DebugN("  ЕСТЬ тип ", dpt, "   элементов=", dynlen(n));
  }
  else
  {
    DebugN("  нет  тип ", dpt);
  }
}