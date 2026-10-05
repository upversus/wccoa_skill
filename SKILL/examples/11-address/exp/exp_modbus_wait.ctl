// exp_modbus_wait.ctl - хватает ли времени, чтобы адрес встал в опрос.
//
// Установлено: из всех проверенных адресов работает ровно один - M.1.3.0,
// и это единственный адрес, который постоянно настроен в ExampleDP_Arg1.
// Все прочие проверки создавали точку данных, ждали 6 секунд и удаляли.
//
// Возможное объяснение: новый адрес не успевает попасть в группу опроса
// драйвера за 6 секунд, а ExampleDP_Arg1 опрашивается постоянно и потому
// работает всегда. Проверяем: та же точка данных, но ждём 30 секунд.
//
// Проверено: CTL 3.18, проект <проект стенда>.

main()
{
  DebugN("=== Хватает ли времени: 6 с против 30 с ===");

  int driverNumber = 2;
  string dpt    = "dpdemo_wait";
  string dpName = "dpdemo_wait_1";

  dyn_string old = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(old); i++) { dpDelete(old[i]); }
  dpTypeDelete(dpt);

  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);
  types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "e");
  types[2] = makeDynInt(0, DPEL_FLOAT);

  dpTypeCreate(names, types);
  dpCreate(dpName, dpt);

  // MB_Float_A: holding, 12-13, FLOAT
  dpSetTimedWait(0,
                 "dpdemo_wait_1.:_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                 "dpdemo_wait_1.:_distrib.._driver", driverNumber);
  dpSetTimedWait(0,
                 "dpdemo_wait_1.e:_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                 "dpdemo_wait_1.e:_address.._reference", "M.1.3.12",
                 "dpdemo_wait_1.e:_address.._active",    TRUE,
                 "dpdemo_wait_1.e:_address.._drv_ident", "MODBUS",
                 "dpdemo_wait_1.e:_address.._datatype",  566,
                 "dpdemo_wait_1.e:_address.._direction", 4);

  for (int sec = 1; sec <= 10; sec++)
  {
    delay(3);
    DebugN("  +", sec * 3, " с:  ", state());
  }

  DebugN("");
  DebugN("=== сравнение с эталоном на том же интервале ===");
  DebugN("  ExampleDP_Arg1: ", refState());

  DebugN("=== конец ===");
  DebugN("Точка данных оставлена: ", dpName);
}

string state()
{
  bool bad;
  time t;
  dyn_anytype v;
  dpGet("dpdemo_wait_1.e:_online.._bad",   bad);
  dpGet("dpdemo_wait_1.e:_online.._stime", t);
  dpGet("dpdemo_wait_1.e:_online.._value", v);
  if (t == makeTime(1970, 1, 1, 3, 0, 0)) { return "данных нет"; }
  if (bad) { return "данные есть, но _bad = TRUE, значение=" + v; }
  return "ДАННЫЕ, значение=" + v;
}

string refState()
{
  dyn_anytype v;
  dpGet("ExampleDP_Arg1.:_online.._value", v);
  return "значение=" + v;
}