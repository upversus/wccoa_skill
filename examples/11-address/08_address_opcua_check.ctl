// 08_address_opcua_check.ctl - тип с bool, float, int на узлах OPC UA.
//
// Сервер: opc.tcp://192.168.0.107:49320 (Kepware KEPServerEX 6)
// Драйвер OPC UA в проекте prg_12_3: WCCOAopcua.exe -num 3
// Формат адреса: <Art>$<Переменная>$<вариант>$<NodeId>
//
// Подобранные узлы (типы проверены opcuactl get value --format json):
//     bool  User3   TypeIDBoolean  -> _datatype 751
//     float Sine2   TypeIDFloat    -> _datatype 760
//     int   Ramp4   TypeIDInt32    -> _datatype 756
//
// Почему именно эти:
//     User3 - единственный логический узел в наборе Functions;
//     Sine2 - синусоида, форма кривой сразу подтверждает корректность float;
//     Ramp4 - знаковый Int32 со значением -1000, в отличие от Ramp1 (35),
//             на нём видно, что знак не теряется.
//
// Группа опроса для OPC UA не выставляется: примеры 01-03 прошли без неё.
// Для Modbus атрибут обязателен, см. docs/11-address.md раздел 8.1.
//
// Проверено: CTL 3.18, проект prg_12_3.

main()
{
  DebugN("=== OPC UA: тип с bool, float, int ===");

  int driverNumber = 3;   // WCCOAopcua.exe -num 3
  string dpt    = "opcChk_t";
  string dpName = "opcChk";

  // ---- тип ----
  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);            types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "bUser3");   types[2] = makeDynInt(0, DPEL_BOOL);
  names[3] = makeDynString("", "fSine2");   types[3] = makeDynInt(0, DPEL_FLOAT);
  names[4] = makeDynString("", "iRamp4");   types[4] = makeDynInt(0, DPEL_INT);

  if (dpExists(dpName)) { dpDelete(dpName); }
  if (dpExists(dpt))    { dpTypeDelete(dpt); }
  delay(2);

  int rcT = dpTypeCreate(names, types);
  DebugN("  тип ", dpt, ": rc=", rcT, rcT != 0 ? "  ОШИБКА" : "");
  int rcD = dpCreate(dpName, dpt);
  DebugN("  точка ", dpName, ": rc=", rcD, rcD != 0 ? "  ОШИБКА" : "");
  DebugN("  имя типа: ", dpTypeName(dpName + "."));

  // ---- адреса ----
  DebugN("");
  setAddr(dpName + ".bUser3", "kep$kep_sub$1$1$ns=2;s=Simulation Examples.Functions.User3", 751);
  setAddr(dpName + ".fSine2", "kep$kep_sub$1$1$ns=2;s=Simulation Examples.Functions.Sine2", 760);
  setAddr(dpName + ".iRamp4", "kep$kep_sub$1$1$ns=2;s=Simulation Examples.Functions.Ramp4", 756);

  // ---- приход данных ----
  DebugN("");
  DebugN("Ждём 25 с на данные...");
  delay(25);

  DebugN("--- срез 1 ---");
  int ok = 0;
  ok += check(dpName + ".bUser3", "bool  User3");
  ok += check(dpName + ".fSine2", "float Sine2");
  ok += check(dpName + ".iRamp4", "int   Ramp4");

  DebugN("");
  DebugN("--- срез 2 через 6 с, значения должны измениться ---");
  delay(6);
  ok += check(dpName + ".bUser3", "bool  User3");
  ok += check(dpName + ".fSine2", "float Sine2");
  ok += check(dpName + ".iRamp4", "int   Ramp4");

  DebugN("");
  DebugN("=== ИТОГ: успешно ", ok, ", неудачно ", (6 - ok), " ===");

  DebugN("");
  DebugN("################ ДЛЯ РУЧНОЙ ПРОВЕРКИ ################");
  DebugN("Тип точки данных : ", dpt);
  DebugN("Точка данных     : ", dpName);
  DebugN("Драйвер OPC UA   : ", driverNumber);
  DebugN("Сервер           : opc.tcp://192.168.0.107:49320");
  DebugN("  bUser3 -> kep$kep_sub$1$1$ns=2;s=Simulation Examples.Functions.User3  dt 751");
  DebugN("  fSine2 -> kep$kep_sub$1$1$ns=2;s=Simulation Examples.Functions.Sine2  dt 760");
  DebugN("  iRamp4 -> kep$kep_sub$1$1$ns=2;s=Simulation Examples.Functions.Ramp4  dt 756");
  DebugN("###################################################");
  DebugN("--- Объекты оставлены в проекте ---");
}

void setAddr(string dpe, string address, int datatype)
{
  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", 3);
  int rc = dpSetTimedWait(0,
                    dpe + ":_address.._type",       DPCONFIG_PERIPH_ADDR_MAIN,
                    dpe + ":_address.._reference",  address,
                    dpe + ":_address.._active",     TRUE,
                    dpe + ":_address.._drv_ident",  "OPCUA",
                    dpe + ":_address.._datatype",   datatype,
                    dpe + ":_address.._direction",  DPATTR_ADDR_MODE_INPUT_POLL);

  string got;
  int gotType;
  dpGet(dpe + ":_address.._reference", got);
  dpGet(dpe + ":_address.._datatype",  gotType);
  DebugN("  ", (rc == 0 && got == address) ? "ok  " : "ОШИБКА",
         " ", dpe, " -> ", got, "  dt=", gotType, "  rc=", rc);
}

int check(string dpe, string what)
{
  bool bad;
  time t;
  dyn_anytype v;
  dpGet(dpe + ":_online.._bad",   bad);
  dpGet(dpe + ":_online.._stime", t);
  dpGet(dpe + ":_online.._value", v);
  bool hasData = (t != makeTime(1970, 1, 1, 3, 0, 0));
  DebugN("  ", (hasData && !bad) ? "данные" : "НЕТ   ", "  ", what,
         "  = ", v, "   stime=", t);
  if (hasData && !bad) { return 1; }
  return 0;
}