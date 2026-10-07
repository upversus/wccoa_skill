// exp_modbus_alive.ctl — жив ли эмулятор после загрузки нового конфига.
//
// Результат прогона 253: НИ ОДИН из шести адресов не дал данных, включая
// ранее рабочие. Значит либо сломалось соединение с эмулятором, либо новые
// регистры не отдаются. Разделяем эти две причины: сравниваем заведомо
// рабочий адрес из эталона с новыми.
//
// Заодно проверяем, продолжает ли обновляться вручную настроенная точка
// ExampleDP_Arg1 (адрес M.1.3.2) — если и она молчит, эмулятор или драйвер.
//
// Известный из лога факт: драйвер ходит на адрес из HostsAndPorts, а не на
// localhost — поэтому адрес в проекте должен совпадать с адресом эмулятора.

main()
{
  DebugN("=== Проверка живости эмулятора Modbus ===");

  int driverNumber = 2;
  string dpt    = "dpdemo_mbalive";
  string dpName = "dpdemo_mbalive_1";

  dyn_string old = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(old); i++) { dpDelete(old[i]); }
  dpTypeDelete(dpt);

  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);        types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "old");  types[2] = makeDynInt(0, DPEL_FLOAT);  // M.1.3.2 рабочий
  names[3] = makeDynString("", "bit");  types[3] = makeDynInt(0, DPEL_BOOL);   // M.1.3.4 рабочий
  names[4] = makeDynString("", "new1"); types[4] = makeDynInt(0, DPEL_FLOAT);  // M.1.3.22 новый
  names[5] = makeDynString("", "new2"); types[5] = makeDynInt(0, DPEL_INT);    // M.1.3.20 новый
  names[6] = makeDynString("", "new3"); types[6] = makeDynInt(0, DPEL_BOOL);   // M.1.3.28 новый

  DebugN("dpTypeCreate rc=", dpTypeCreate(names, types));
  DebugN("dpCreate rc=", dpCreate(dpName, dpt));

  dpdSet(dpName + ".old",  "M.1.3.2",  566, driverNumber);
  dpdSet(dpName + ".bit",  "M.1.3.4",  567, driverNumber);
  dpdSet(dpName + ".new1", "M.1.3.22", 566, driverNumber);
  dpdSet(dpName + ".new2", "M.1.3.20", 561, driverNumber);
  dpdSet(dpName + ".new3", "M.1.3.28", 567, driverNumber);

  delay(15);

  DebugN("--- рабочие адреса (из эталона ExampleDP_Arg1) ---");
  dpdReport(dpName + ".old", "M.1.3.2  FLOAT 566");
  dpdReport(dpName + ".bit", "M.1.3.4  BIT   567");

  DebugN("--- новые адреса из t1_mb.xml ---");
  dpdReport(dpName + ".new1", "M.1.3.22 FLOAT 566  MB_Float_A");
  dpdReport(dpName + ".new2", "M.1.3.20 INT16 561  MB_Int16_A");
  dpdReport(dpName + ".new3", "M.1.3.28 BIT   567  MB_Bool_A");

  DebugN("--- вручную настроенная точка ---");
  bool fresh1 = false, fresh2 = false;
  float v1, v2;
  time t1;
  dpGet("ExampleDP_Arg1.:_online.._stime", t1);
  dpGet("ExampleDP_Arg1.:_online.._value", v1);
  DebugN("  первый срез  stime=", t1, "  значение=", v1);
  delay(6);
  dpGet("ExampleDP_Arg1.:_online.._stime", t1);
  dpGet("ExampleDP_Arg1.:_online.._value", v2);
  DebugN("  второй срез  stime=", t1, "  значение=", v2);
  fresh1 = (t1 != makeTime(1970, 1, 1, 3, 0, 0));
  DebugN("  ExampleDP_Arg1 обновляется: ", fresh1, "   изменилось: ", (v1 != v2));

  DebugN("=== конец ===");

  dyn_string left = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(left); i++) { dpDelete(left[i]); }
  dpTypeDelete(dpt);
}

void dpdSet(string dpe, string address, int datatype, int driverNumber)
{
  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", driverNumber);
  dpSetTimedWait(0,
                    dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                    dpe + ":_address.._reference", address,
                    dpe + ":_address.._active",    TRUE,
                    dpe + ":_address.._drv_ident", "MODBUS",
                    dpe + ":_address.._datatype",  datatype,
                    dpe + ":_address.._direction", DPATTR_ADDR_MODE_INPUT_POLL);
}

void dpdReport(string dpe, string what)
{
  bool bad;
  time t;
  dyn_anytype v;
  dpGet(dpe + ":_online.._bad",   bad);
  dpGet(dpe + ":_online.._stime", t);
  dpGet(dpe + ":_online.._value", v);
  DebugN("  ", what, "  данные=", (t != makeTime(1970, 1, 1, 3, 0, 0)), "  bad=", bad, "  значение=", v);
}