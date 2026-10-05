// exp_modbus_width.ctl - соответствие ширины регистра и типа преобразования.
//
// Установлено:
//   * M.1.3.0 с datatype 563 (UINT16, 1 регистр) - ДАННЫЕ, значение 2470;
//   * M.1.3.0 с datatype 566 (FLOAT, 2 регистра) - нет данных;
//   * direction 7 не пишется из скрипта (rc = -1), рабочая - 4.
//
// Если различие только в ширине, то одиночный UINT16 должен читаться на всех
// адресах 0..20, а FLOAT - только там, где в конфиге регистр имеет RegsCount 2.
//
// Проверено: CTL 3.18, проект prg_12_3.

main()
{
  DebugN("=== Одиночный регистр, UINT16 (563), адреса 0..20 ===");
  int driverNumber = 2;

  for (int a = 0; a <= 20; a++)
  {
    probe(driverNumber, a, 563);
  }

  DebugN("");
  DebugN("=== Два регистра, FLOAT (566) ===");
  probe(driverNumber, 2,  566);   // Reg_2, в конфиге RegsCount 2
  probe(driverNumber, 3,  566);   // второе слово Reg_2
  probe(driverNumber, 12, 566);   // MB_Float_A, RegsCount 2
  probe(driverNumber, 14, 566);   // MB_Float_B, RegsCount 2

  DebugN("");
  DebugN("=== Один регистр, BIT (567) в coil-пространстве ===");
  probe(driverNumber, 0,  567);   // Coil00
  probe(driverNumber, 4,  567);   // Reg_1
  probe(driverNumber, 5,  567);   // MB_Bool_A

  DebugN("=== конец ===");
}

void probe(int driverNumber, int addr, int datatype)
{
  string dpt    = "dpdemo_width";
  string dpName = "dpdemo_width_1";

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

  dpSetTimedWait(0,
                 "dpdemo_width_1.:_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                 "dpdemo_width_1.:_distrib.._driver", driverNumber);
  dpSetTimedWait(0,
                 "dpdemo_width_1.e:_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                 "dpdemo_width_1.e:_address.._reference", "M.1.3." + addr,
                 "dpdemo_width_1.e:_address.._active",    TRUE,
                 "dpdemo_width_1.e:_address.._drv_ident", "MODBUS",
                 "dpdemo_width_1.e:_address.._datatype",  datatype,
                 "dpdemo_width_1.e:_address.._direction", 4);

  delay(6);

  bool bad;
  time t;
  dyn_anytype v;
  dpGet("dpdemo_width_1.e:_online.._bad",   bad);
  dpGet("dpdemo_width_1.e:_online.._stime", t);
  dpGet("dpdemo_width_1.e:_online.._value", v);
  bool hasData = (t != makeTime(1970, 1, 1, 3, 0, 0));

  DebugN("  M.1.3.", addr, " dt=", datatype, "  ",
         (hasData && !bad) ? "ДАННЫЕ" : "нет   ",
         "   значение=", v);

  dpDelete(dpName);
  dpTypeDelete(dpt);
}