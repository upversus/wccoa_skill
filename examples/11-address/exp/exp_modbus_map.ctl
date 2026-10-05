// exp_modbus_map.ctl — карта адресов, которые отдаёт эмулятор.
//
// Установлено:
//   * конфиг t1_mb.xml загружен — в логе эмулятора от 13:06 видно три
//     моста на Kepware User3 (Reg_1, MB_Bool_A, MB_Bool_B);
//   * при этом M.1.3.20/22/28 не отвечают, хотя описаны в конфиге;
//   * coarsely: отвечают 2, 4, 6; не отвечают 0, 8, 10...22.
//
// Значит либо адреса в конфиге и адреса на проводе расходятся, либо сервис
// отдаёт ограниченный блок. Сканируем 0..40 подряд, все элементы одинаковые
// (FLOAT 566, FC 3), и смотрим фактическую карту.
//
// Проверено: CTL 3.18, проект prg_12_3.

main()
{
  DebugN("=== Карта адресов Modbus, 0..40 ===");

  int driverNumber = 2;
  string dpt    = "dpdemo_mbmap";
  string dpName = "dpdemo_mbmap_1";

  dyn_string old = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(old); i++) { dpDelete(old[i]); }
  dpTypeDelete(dpt);

  int addrCount = 41;      // адреса 0..40

  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);
  types[1] = makeDynInt(DPEL_STRUCT);
  for (int i = 1; i <= addrCount; i++)
  {
    names[i + 1] = makeDynString("", "a" + (i - 1));
    types[i + 1] = makeDynInt(0, DPEL_FLOAT);
  }

  DebugN("dpTypeCreate rc=", dpTypeCreate(names, types));
  DebugN("dpCreate rc=", dpCreate(dpName, dpt));

  for (int i = 1; i <= addrCount; i++)
  {
    dpdSet(dpName + ".a" + (i - 1), "M.1.3." + (i - 1), 566, driverNumber);
  }

  DebugN("  ждём 25 с ...");
  delay(25);

  DebugN("--- карта: X = отвечает, . = ошибка ---");
  for (int i = 1; i <= addrCount; i++)
  {
    string el = dpName + ".a" + (i - 1);
    bool bad;
    time t;
    float v;
    dpGet(el + ":_online.._bad",   bad);
    dpGet(el + ":_online.._stime", t);
    dpGet(el + ":_online.._value", v);
    bool hasData = (t != makeTime(1970, 1, 1, 3, 0, 0));
    DebugN("  адрес ", i - 1, ": ", (hasData && !bad) ? "X" : ".", "   значение=", v);
  }

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