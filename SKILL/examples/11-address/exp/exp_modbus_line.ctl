// exp_modbus_line.ctl — граница, на которой перестаёт работать адресное
// пространство Modbus.
//
// Установлено:
//   * direction 7 из эталона через dpSetTimedWait не пишется (rc = -1),
//     рабочее направление — 4;
//   * после добавления Fill01 в конфиг адрес 0 заработал (значение 2470),
//     то есть гипотеза пользователя о том, что дыры в адресном пространстве
//     ломают группировку запросов, подтвердилась;
//   * holding-пространство в конфиге непрерывно 0..20, но адреса 11 и 12
//     после перезапуска драйвера молчат.
//
// Обходим 0..14 по одному, направление 4, и находим границу.
//
// Проверено: CTL 3.18, проект <проект стенда>.

main()
{
  DebugN("=== Граница адресного пространства Modbus ===");
  int driverNumber = 2;

  for (int a = 0; a <= 14; a++)
  {
    probe(driverNumber, a);
  }

  DebugN("=== конец ===");
}

void probe(int driverNumber, int addr)
{
  string dpt    = "dpdemo_line";
  string dpName = "dpdemo_line_1";

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

  int rc = dpSetTimedWait(0,
                 "dpdemo_line_1.:_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                 "dpdemo_line_1.:_distrib.._driver", driverNumber);
  rc = dpSetTimedWait(0,
                 "dpdemo_line_1.e:_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                 "dpdemo_line_1.e:_address.._reference", "M.1.3." + addr,
                 "dpdemo_line_1.e:_address.._active",    TRUE,
                 "dpdemo_line_1.e:_address.._drv_ident", "MODBUS",
                 "dpdemo_line_1.e:_address.._datatype",  566,
                 "dpdemo_line_1.e:_address.._direction", 4);

  delay(7);

  bool bad;
  time t;
  dyn_anytype v;
  dpGet("dpdemo_line_1.e:_online.._bad",   bad);
  dpGet("dpdemo_line_1.e:_online.._stime", t);
  dpGet("dpdemo_line_1.e:_online.._value", v);
  bool hasData = (t != makeTime(1970, 1, 1, 3, 0, 0));

  DebugN("  M.1.3.", addr, "  rc=", rc, "  ",
         (hasData && !bad) ? "ДАННЫЕ" : "нет   ",
         "   значение=", v);

  dpDelete(dpName);
  dpTypeDelete(dpt);
}