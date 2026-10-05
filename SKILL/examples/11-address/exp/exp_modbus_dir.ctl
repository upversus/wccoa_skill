// exp_modbus_dir.ctl — в чём разница с рабочим эталоном ExampleDP_Arg1.
//
// Эталон сейчас настроен пользователем и работает. Его конфиг:
//     _reference = 'M.1.3.0'
//     _drv_ident = 'MODBUS'
//     _datatype  = 563
//     _direction = 7
//     _distrib.._driver = 2
//
// Во всех моих тестах ставилось _direction = 4 (как для OPC UA). Раньше это
// давало данные, но после перезапуска драйвера перестало. В изоляции меняем
// ровно один параметр за раз, начиная с точной копии эталона.
//
// Проверено: CTL 3.18, проект <проект стенда>.

main()
{
  DebugN("=== Поиск отличия от рабочего эталона ===");

  int driverNumber = 2;

  // A — точная копия эталона: должен работать
  probe(driverNumber, "M.1.3.0",  563, 7, "A  копия эталона           dir=7 dt=563");

  // B — меняем только направление
  probe(driverNumber, "M.1.3.0",  563, 4, "B  только направление       dir=4 dt=563");

  // C — направление эталона, но float
  probe(driverNumber, "M.1.3.0",  566, 7, "C  только тип 566 FLOAT    dir=7 dt=566");

  // D — на новый регистр, направление эталона
  probe(driverNumber, "M.1.3.12", 566, 7, "D  MB_Float_A, dir=7       dir=7 dt=566");
  probe(driverNumber, "M.1.3.11", 561, 7, "E  MB_Int16_A, dir=7       dir=7 dt=561");
  probe(driverNumber, "M.1.3.5",  567, 7, "F  MB_Bool_A,  dir=7       dir=7 dt=567");

  DebugN("=== конец ===");
}

void probe(int driverNumber, string address, int datatype, int direction, string what)
{
  string dpt    = "dpdemo_dir";
  string dpName = "dpdemo_dir_1";

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

  dpSetTimedWait(0, "dpdemo_dir_1.:_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                 "dpdemo_dir_1.:_distrib.._driver", driverNumber);
  int rc = dpSetTimedWait(0,
                 "dpdemo_dir_1.e:_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                 "dpdemo_dir_1.e:_address.._reference", address,
                 "dpdemo_dir_1.e:_address.._active",    TRUE,
                 "dpdemo_dir_1.e:_address.._drv_ident", "MODBUS",
                 "dpdemo_dir_1.e:_address.._datatype",  datatype,
                 "dpdemo_dir_1.e:_address.._direction", direction);

  delay(8);

  bool bad;
  time t;
  dyn_anytype v;
  dpGet("dpdemo_dir_1.e:_online.._bad",   bad);
  dpGet("dpdemo_dir_1.e:_online.._stime", t);
  dpGet("dpdemo_dir_1.e:_online.._value", v);
  bool hasData = (t != makeTime(1970, 1, 1, 3, 0, 0));

  DebugN("  ", what, "  rc=", rc, "  ->  ",
         (hasData && !bad) ? "данные ЕСТЬ" : "НЕТ ДАННЫХ",
         "   значение=", v);

  dpDelete(dpName);
  dpTypeDelete(dpt);
}