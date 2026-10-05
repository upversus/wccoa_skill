// exp_modbus_int.ctl — почему регистр 0 не читается.
//
// Результат первого прогона:
//   M.1.3.2  datatype 566 (FLOAT)       -> данные пришли, значение 77.37
//   M.1.3.4  datatype 567 (BIT)         -> данные пришли
//   M.1.3.0  datatype 561 (INT16)       -> НЕ пришли, _online.._bad = TRUE
//   M.1.3.4  datatype 568 (BOOL_AS_BYTE)-> НЕ пришли, _online.._bad = TRUE
//
// В эмуляторе (t1.xml) регистр Addr 0 описан как RegsCount 1, vType 18,
// а рабочий Reg_2 — RegsCount 2, vType 4, DataFormat 4. Похоже, дело в
// описании регистра, а не в адресе. Перебираем типы преобразования для
// того же адреса и соседние адреса.
//
// Проверено: CTL 3.18, проект <проект стенда>.

main()
{
  DebugN("=== Разбор регистра Modbus Addr 0 ===");

  int driverNumber = 2;
  string dpt = "dpdemo_mbint";
  string dpName = "dpdemo_mbint_1";

  dyn_string old = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(old); i++) { dpDelete(old[i]); }
  dpTypeDelete(dpt);

  // Пять элементов-кандидатов: один и тот же адрес, разные типы
  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);       types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "d561"); types[2] = makeDynInt(0, DPEL_INT);    // INT16
  names[3] = makeDynString("", "d563"); types[3] = makeDynInt(0, DPEL_INT);    // UINT16
  names[4] = makeDynString("", "d564"); types[4] = makeDynInt(0, DPEL_INT);    // UINT32
  names[5] = makeDynString("", "d566"); types[5] = makeDynInt(0, DPEL_FLOAT);  // FLOAT
  names[6] = makeDynString("", "d569"); types[6] = makeDynInt(0, DPEL_STRING); // STRING

  DebugN("dpTypeCreate rc=", dpTypeCreate(names, types));
  DebugN("dpCreate rc=", dpCreate(dpName, dpt));

  dpdSet(dpName + ".d561", "M.1.3.0", 561, driverNumber);
  dpdSet(dpName + ".d563", "M.1.3.0", 563, driverNumber);
  dpdSet(dpName + ".d564", "M.1.3.0", 564, driverNumber);
  dpdSet(dpName + ".d566", "M.1.3.0", 566, driverNumber);
  dpdSet(dpName + ".d569", "M.1.3.0", 569, driverNumber);

  delay(10);

  DebugN("--- адрес M.1.3.0, разные типы преобразования ---");
  dpdReport(dpName + ".d561", "INT16 (561)");
  dpdReport(dpName + ".d563", "UINT16 (563)");
  dpdReport(dpName + ".d564", "UINT32 (564)");
  dpdReport(dpName + ".d566", "FLOAT (566)");
  dpdReport(dpName + ".d569", "STRING (569)");

  // Для сравнения — заведомо рабочий адрес
  DebugN("--- для сравнения: рабочий адрес M.1.3.2 ---");
  dpdReport(dpName + ".d566", "FLOAT (566) на M.1.3.0 — см. выше");

  dyn_string left = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(left); i++) { dpDelete(left[i]); }
  dpTypeDelete(dpt);
  DebugN("=== конец ===");
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
  bool fresh = (t != makeTime(1970, 1, 1, 3, 0, 0));
  DebugN("  ", what, "  данные=", fresh, "  bad=", bad, "  значение=", v);
}