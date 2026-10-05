// exp_modbus_seq.ctl — проверка адресов строго по одному.
//
// Зачем по одному: сканер на 41 одновременный адрес обслуживал только младшие
// (1..6), и карта адресов получилась ложной. Одновременных адресов должно быть
// мало. Здесь каждый адрес создаётся, проверяется и удаляется по очереди.
//
// Состояние конфига t1_mb.xml: загружен, адресное пространство непрерывно
// (holding 0..20, coil 0..6). Эмулятор подтвердил загрузку семью тегами User3.
//
// Проверено: CTL 3.18, проект <проект стенда>.

main()
{
  DebugN("=== Эталон ExampleDP_Arg1 ===");
  dpdShow("ExampleDP_Arg1.");

  DebugN("");
  DebugN("=== Последовательная проверка адресов ===");

  int driverNumber = 2;

  probe(driverNumber, "M.1.3.0",  566, "Reg          FLOAT  адрес 0");
  probe(driverNumber, "M.1.3.2",  566, "Reg_2        FLOAT");
  probe(driverNumber, "M.1.3.4",  567, "Reg_1        BIT    coil");
  probe(driverNumber, "M.1.3.5",  567, "MB_Bool_A    BIT    coil");
  probe(driverNumber, "M.1.3.6",  567, "MB_Bool_B    BIT    coil");
  probe(driverNumber, "M.1.3.11", 561, "MB_Int16_A   INT16");
  probe(driverNumber, "M.1.3.12", 566, "MB_Float_A   FLOAT");
  probe(driverNumber, "M.1.3.14", 566, "MB_Float_B   FLOAT");
  probe(driverNumber, "M.1.3.20", 561, "MB_Int16_B   INT16");

  DebugN("=== конец ===");
}

// Создаёт одноэлементный тип и точку данных, проверяет, удаляет.
void probe(int driverNumber, string address, int datatype, string what)
{
  string dpt    = "dpdemo_seq";
  string dpName = "dpdemo_seq_1";

  dyn_string old = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(old); i++) { dpDelete(old[i]); }
  dpTypeDelete(dpt);

  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);
  types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "e");
  types[2] = makeDynInt(0, DPEL_FLOAT);   // элемент float вмещает любой тип

  dpTypeCreate(names, types);
  dpCreate(dpName, dpt);

  dpSetTimedWait(0, "dpdemo_seq_1.:_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                 "dpdemo_seq_1.:_distrib.._driver", driverNumber);
  dpSetTimedWait(0,
                 "dpdemo_seq_1.e:_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                 "dpdemo_seq_1.e:_address.._reference", address,
                 "dpdemo_seq_1.e:_address.._active",    TRUE,
                 "dpdemo_seq_1.e:_address.._drv_ident", "MODBUS",
                 "dpdemo_seq_1.e:_address.._datatype",  datatype,
                 "dpdemo_seq_1.e:_address.._direction", DPATTR_ADDR_MODE_INPUT_POLL);

  delay(8);

  bool bad;
  time t;
  dyn_anytype v;
  dpGet("dpdemo_seq_1.e:_online.._bad",   bad);
  dpGet("dpdemo_seq_1.e:_online.._stime", t);
  dpGet("dpdemo_seq_1.e:_online.._value", v);
  bool hasData = (t != makeTime(1970, 1, 1, 3, 0, 0));

  DebugN("  ", address, "  ", what, "  ->  ",
         (hasData && !bad) ? "данные ЕСТЬ" : "НЕТ ДАННЫХ",
         "   значение=", v);

  dpDelete(dpName);
  dpTypeDelete(dpt);
}

void dpdShow(string dpe)
{
  string sVal;
  int iVal;

  dpGet(dpe + ":_address.._reference", sVal); DebugN("  _reference = '", sVal, "'");
  dpGet(dpe + ":_address.._drv_ident", sVal); DebugN("  _drv_ident = '", sVal, "'");
  dpGet(dpe + ":_address.._datatype",  iVal); DebugN("  _datatype  = ", iVal);
  dpGet(dpe + ":_address.._direction", iVal); DebugN("  _direction = ", iVal);
  dpGet(dpe + ":_distrib.._driver",    iVal); DebugN("  _distrib.._driver = ", iVal);

  dyn_anytype v;
  time t;
  dpGet(dpe + ":_online.._value", v);
  dpGet(dpe + ":_online.._stime", t);
  DebugN("  значение   = ", v, "   stime = ", t);
}