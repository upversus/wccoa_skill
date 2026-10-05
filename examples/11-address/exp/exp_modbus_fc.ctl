// exp_modbus_fc.ctl - проверка кодов функций и направления.
//
// Из снимка панели Para_36 (пользователь прислал) видно устройство настройки
// адреса Modbus:
//     Ссылка        M.1.1.6
//     N драйвера    2
//     ПЛК           1
//     FC/SFC        read/write coils
//     Адрес регистра 6
//     Преобразование boolean
//     Направление   Вх./Вых.
//     Режим приема  Опрос
//
// Отсюда формат: M.<ПЛК>.<FC>.<адрес регистра>. И сразу видно главное: для
// логического элемента нужен FC 1 (coils), а не FC 3 (регистры). Все прежние
// попытки обойтись M.1.3.N с типом boolean были заведомо нерабочими, о чём
// драйвер и сообщал: "Transformation/FC incompatibility for: M.1.3.4".
//
// _direction в GUI несёт и направление, и режим приема:
//     Вх./Вых. -> 7 (именно такое значение у эталона ExampleDP_Arg1)
//     Опрос    -> 4
// Ставится по FC: для coils - 7, для регистров - 4.
//
// Проверяем: holding одним регистром на 0..20, float на местах с RegsCount 2,
// coils через FC 1 в обоих направлениях.
//
// Проверено: CTL 3.18, проект prg_12_3.

main()
{
  int driverNumber = 2;

  DebugN("=== holding, FC 3, направление 4, UINT16 (563), один регистр ===");
  for (int a = 0; a <= 20; a++)
  {
    probe(driverNumber, "M.1.3." + a, 563, 4);
  }

  DebugN("");
  DebugN("=== holding, FC 3, направление 4, FLOAT (566), два регистра ===");
  probe(driverNumber, "M.1.3.2",  566, 4);
  probe(driverNumber, "M.1.3.12", 566, 4);
  probe(driverNumber, "M.1.3.14", 566, 4);
  probe(driverNumber, "M.1.3.16", 566, 4);

  DebugN("");
  DebugN("=== coils, FC 1, направление 7 (Вх./Вых.), BIT (567) ===");
  probe(driverNumber, "M.1.1.0", 567, 7);
  probe(driverNumber, "M.1.1.4", 567, 7);
  probe(driverNumber, "M.1.1.5", 567, 7);
  probe(driverNumber, "M.1.1.6", 567, 7);

  DebugN("");
  DebugN("=== то же, но направление 4 - для сравнения ===");
  probe(driverNumber, "M.1.1.6", 567, 4);

  DebugN("");
  DebugN("=== coils через FC 2 (read input discrete), направление 4 ===");
  probe(driverNumber, "M.1.2.6", 567, 4);

  DebugN("=== конец ===");
}

void probe(int driverNumber, string address, int datatype, int direction)
{
  string dpt    = "dpdemo_fc";
  string dpName = "dpdemo_fc_1";

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
                 "dpdemo_fc_1.:_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                 "dpdemo_fc_1.:_distrib.._driver", driverNumber);
  int rc = dpSetTimedWait(0,
                 "dpdemo_fc_1.e:_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                 "dpdemo_fc_1.e:_address.._reference", address,
                 "dpdemo_fc_1.e:_address.._active",    TRUE,
                 "dpdemo_fc_1.e:_address.._drv_ident", "MODBUS",
                 "dpdemo_fc_1.e:_address.._datatype",  datatype,
                 "dpdemo_fc_1.e:_address.._direction", direction);

  delay(6);

  bool bad;
  time t;
  dyn_anytype v;
  dpGet("dpdemo_fc_1.e:_online.._bad",   bad);
  dpGet("dpdemo_fc_1.e:_online.._stime", t);
  dpGet("dpdemo_fc_1.e:_online.._value", v);
  bool hasData = (t != makeTime(1970, 1, 1, 3, 0, 0));

  DebugN("  ", address, " dt=", datatype, " dir=", direction, "  rc=", rc, "  ",
         (hasData && !bad) ? "ДАННЫЕ" : "нет   ",
         "   значение=", v);

  dpDelete(dpName);
  dpTypeDelete(dpt);
}