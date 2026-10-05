// exp_map_probe.ctl - разведка перед построением карты.
//
// Стенд новый: шесть устройств (Slave ID 1..6), у каждого coils и holding.
// Три неизвестные, которые нельзя угадать:
//
//   1. Как задаётся Slave ID - второе поле адреса M.<SlaveID>.<FC>.<регистр>?
//      Раньше устройство было одно, с Number 1, и проверить было нечем.
//   2. Работает ли 561 (INT16, знаковый) - в карте int16 знаковый, а раньше
//      проверен был только 563 (UINT16).
//   3. Читаются ли coils через FC 1 с направлением 7 - раньше coils работали
//      случайно, на старой конфигурации.
//
// Проверено: CTL 3.18, проект <проект стенда>.

main()
{
  int driverNumber = 2;
  string pollGroup = findPollGroup();
  DebugN("группа опроса: ", pollGroup);
  if (pollGroup == "") { return; }

  string dpt = "mapprobe_t";
  string dpName = "mapprobe";

  dyn_string old = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(old); i++) { dpDelete(old[i]); }
  if (dpExists(dpName)) { dpDelete(dpName); }
  dpTypeDelete(dpt);

  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);           types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "dev1_hr0_s16");  types[2] = makeDynInt(0, DPEL_INT);
  names[3] = makeDynString("", "dev1_hr0_u16");  types[3] = makeDynInt(0, DPEL_INT);
  names[4] = makeDynString("", "dev2_hr0_f");    types[4] = makeDynInt(0, DPEL_FLOAT);
  names[5] = makeDynString("", "dev1_coil0");    types[5] = makeDynInt(0, DPEL_BOOL);
  names[6] = makeDynString("", "dev3_hr0_f");    types[6] = makeDynInt(0, DPEL_FLOAT);
  names[7] = makeDynString("", "dev6_coil0");    types[7] = makeDynInt(0, DPEL_BOOL);

  DebugN("dpTypeCreate rc=", dpTypeCreate(names, types));
  DebugN("dpCreate rc=", dpCreate(dpName, dpt));

  // 1 и 2: Slave ID 1, holding 0, знаковый и беззнаковый int16
  set(dpName + ".dev1_hr0_s16", "M.1.3.0", 561, 4, driverNumber, pollGroup);
  set(dpName + ".dev1_hr0_u16", "M.1.3.0", 563, 4, driverNumber, pollGroup);
  // 3: Slave ID 1, coil 0
  set(dpName + ".dev1_coil0", "M.1.1.0", 567, 7, driverNumber, pollGroup);
  // 1: Slave ID 2, holding 0-1, float
  set(dpName + ".dev2_hr0_f", "M.2.3.0", 566, 4, driverNumber, pollGroup);
  // 1: Slave ID 3, holding 0-1, float
  set(dpName + ".dev3_hr0_f", "M.3.3.0", 566, 4, driverNumber, pollGroup);
  // 1 и 3: Slave ID 6, coil 0
  set(dpName + ".dev6_coil0", "M.6.1.0", 567, 7, driverNumber, pollGroup);

  DebugN("");
  DebugN("ждём 25 с ...");
  delay(25);

  DebugN("--- результат ---");
  show(dpName + ".dev1_hr0_s16", "Slave 1, hr 0, 561 INT16");
  show(dpName + ".dev1_hr0_u16", "Slave 1, hr 0, 563 UINT16");
  show(dpName + ".dev2_hr0_f",   "Slave 2, hr 0-1, 566 FLOAT");
  show(dpName + ".dev3_hr0_f",   "Slave 3, hr 0-1, 566 FLOAT");
  show(dpName + ".dev1_coil0",   "Slave 1, coil 0, 567 BIT");
  show(dpName + ".dev6_coil0",   "Slave 6, coil 0, 567 BIT");

  DebugN("=== конец ===");
}

void set(string dpe, string address, int datatype, int direction,
         int driverNumber, string pollGroup)
{
  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", driverNumber);
  dpSetTimedWait(0,
                    dpe + ":_address.._type",       DPCONFIG_PERIPH_ADDR_MAIN,
                    dpe + ":_address.._reference",  address,
                    dpe + ":_address.._active",     TRUE,
                    dpe + ":_address.._drv_ident",  "MODBUS",
                    dpe + ":_address.._datatype",   datatype,
                    dpe + ":_address.._direction",  direction,
                    dpe + ":_address.._poll_group", pollGroup);
}

void show(string dpe, string what)
{
  bool bad;
  time t;
  dyn_anytype v;
  dpGet(dpe + ":_online.._bad",   bad);
  dpGet(dpe + ":_online.._stime", t);
  dpGet(dpe + ":_online.._value", v);
  bool hasData = (t != makeTime(1970, 1, 1, 3, 0, 0));
  DebugN("  ", (hasData && !bad) ? "ДАННЫЕ" : "нет   ", "  ", what, "   значение=", v);
}

string findPollGroup()
{
  dyn_string all = dpNames("_**");
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpTypeName(all[i] + ".") == "_PollGroup") { return all[i]; }
  }
  return "";
}