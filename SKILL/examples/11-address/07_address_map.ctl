// 07_address_map.ctl - полная карта регистров по приложенному файлу.
//
// Шесть устройств, Slave ID 1..6. У каждого coils и holding-регистры.
// Формат адреса: M.<PLC>.<FC>.<регистр>, где PLC соответствует Slave ID.
//
//   coils   -> FC 1, направление 7 (вход/выход)
//   holding -> FC 3, направление 4 (опрос)
//   типы    -> 567 BIT, 566 FLOAT, 561 INT16 (знаковый)
//
// Группа опроса берётся по правилу: пользователь создаёт заранее, скрипт
// находит первую точку данных типа _PollGroup.
//
// Описания PLC (_Mod_Plc) создаёт пользователь, скрипт только проверяет их
// наличие. Нет описания - элемент работать не будет, это ожидаемо.
//
// Про логические элементы: проверяется только приход данных. Требования к
// смене значения нет - у coils на этом стенде значения могут не меняться.
//
// Внимание: CTL не поддерживает перегрузку функций, поэтому у всех
// вспомогательных функций разные имена. Списки элементов передаются явно,
// потому что dpNames() возвращает имена с префиксом системы, и из них
// нельзя собирать item-строки.
//
// Проверено: CTL 3.18, проект <проект стенда>.

int    DRIVER = 2;
string GROUP = "";
int    GLOBAL_OK = 0;
int    GLOBAL_BAD = 0;

main()
{
  DebugN("=== Карта регистров: 6 устройств ===");

  GROUP = findPollGroup();
  DebugN("группа опроса: ", (GROUP == "") ? "<НЕ НАЙДЕНА>" : GROUP);
  if (GROUP == "") { return; }

  checkPlcDefinitions();

  // ------------- Устройство 1: Насос, Slave ID 1 -------------
  dyn_dyn_string n1; dyn_dyn_int t1;
  n1[1]  = makeDynString("mapPumpT");                             t1[1]  = makeDynInt(DPEL_STRUCT);
  n1[2]  = makeDynString("", "Pump_Start");     t1[2]  = makeDynInt(0, DPEL_BOOL);
  n1[3]  = makeDynString("", "Pump_Stop");      t1[3]  = makeDynInt(0, DPEL_BOOL);
  n1[4]  = makeDynString("", "Pump_Run");       t1[4]  = makeDynInt(0, DPEL_BOOL);
  n1[5]  = makeDynString("", "Pump_Fault");     t1[5]  = makeDynInt(0, DPEL_BOOL);
  n1[6]  = makeDynString("", "Pump_Speed_Set"); t1[6]  = makeDynInt(0, DPEL_INT);
  n1[7]  = makeDynString("", "Pump_Speed_Act"); t1[7]  = makeDynInt(0, DPEL_INT);
  n1[8]  = makeDynString("", "Pump_Current");   t1[8]  = makeDynInt(0, DPEL_FLOAT);
  n1[9]  = makeDynString("", "Pump_Pressure");  t1[9]  = makeDynInt(0, DPEL_FLOAT);
  n1[10] = makeDynString("", "Pump_Flow");      t1[10] = makeDynInt(0, DPEL_FLOAT);
  n1[11] = makeDynString("", "Pump_Runtime");   t1[11] = makeDynInt(0, DPEL_INT);
  mkDevice("mapPumpT", "mapPump", n1, t1);

  dyn_string e1 = makeDynString("Pump_Start", "Pump_Stop", "Pump_Run", "Pump_Fault",
                                "Pump_Speed_Set", "Pump_Speed_Act", "Pump_Current",
                                "Pump_Pressure", "Pump_Flow", "Pump_Runtime");
  setAddr("mapPump", "Pump_Start",      1, 1, 0, 567, 7);
  setAddr("mapPump", "Pump_Stop",       1, 1, 1, 567, 7);
  setAddr("mapPump", "Pump_Run",        1, 1, 2, 567, 7);
  setAddr("mapPump", "Pump_Fault",      1, 1, 3, 567, 7);
  setAddr("mapPump", "Pump_Speed_Set",  1, 3, 0, 561, 4);
  setAddr("mapPump", "Pump_Speed_Act",  1, 3, 1, 561, 4);
  setAddr("mapPump", "Pump_Current",    1, 3, 2, 566, 4);
  setAddr("mapPump", "Pump_Pressure",   1, 3, 4, 566, 4);
  setAddr("mapPump", "Pump_Flow",       1, 3, 6, 566, 4);
  setAddr("mapPump", "Pump_Runtime",    1, 3, 8, 561, 4);

  // ------------- Устройство 2: Датчик температуры, Slave ID 2 -------------
  dyn_dyn_string n2; dyn_dyn_int t2;
  n2[1] = makeDynString("mapTempT");                             t2[1] = makeDynInt(DPEL_STRUCT);
  n2[2] = makeDynString("", "Temp_Alarm_High");   t2[2] = makeDynInt(0, DPEL_BOOL);
  n2[3] = makeDynString("", "Temp_Alarm_Low");    t2[3] = makeDynInt(0, DPEL_BOOL);
  n2[4] = makeDynString("", "Temp_Sensor_Fault"); t2[4] = makeDynInt(0, DPEL_BOOL);
  n2[5] = makeDynString("", "Temperature");       t2[5] = makeDynInt(0, DPEL_FLOAT);
  n2[6] = makeDynString("", "Temperature_Int");   t2[6] = makeDynInt(0, DPEL_INT);
  n2[7] = makeDynString("", "Temp_Setpoint");     t2[7] = makeDynInt(0, DPEL_INT);
  mkDevice("mapTempT", "mapTemp", n2, t2);

  dyn_string e2 = makeDynString("Temp_Alarm_High", "Temp_Alarm_Low", "Temp_Sensor_Fault",
                                "Temperature", "Temperature_Int", "Temp_Setpoint");
  setAddr("mapTemp", "Temp_Alarm_High",   2, 1, 0, 567, 7);
  setAddr("mapTemp", "Temp_Alarm_Low",    2, 1, 1, 567, 7);
  setAddr("mapTemp", "Temp_Sensor_Fault", 2, 1, 2, 567, 7);
  setAddr("mapTemp", "Temperature",       2, 3, 0, 566, 4);
  setAddr("mapTemp", "Temperature_Int",   2, 3, 2, 561, 4);
  setAddr("mapTemp", "Temp_Setpoint",     2, 3, 3, 561, 4);

  // ------------------ Устройство 3: Расходомер, Slave ID 3 ------------------
  dyn_dyn_string n3; dyn_dyn_int t3;
  n3[1] = makeDynString("mapFlowT");                             t3[1] = makeDynInt(DPEL_STRUCT);
  n3[2] = makeDynString("", "Flow_Alarm");        t3[2] = makeDynInt(0, DPEL_BOOL);
  n3[3] = makeDynString("", "Flow_Sensor_Fault"); t3[3] = makeDynInt(0, DPEL_BOOL);
  n3[4] = makeDynString("", "Flow_Instant");      t3[4] = makeDynInt(0, DPEL_FLOAT);
  n3[5] = makeDynString("", "Flow_Total");        t3[5] = makeDynInt(0, DPEL_FLOAT);
  n3[6] = makeDynString("", "Flow_Int");          t3[6] = makeDynInt(0, DPEL_INT);
  n3[7] = makeDynString("", "Flow_Setpoint");     t3[7] = makeDynInt(0, DPEL_INT);
  mkDevice("mapFlowT", "mapFlow", n3, t3);

  dyn_string e3 = makeDynString("Flow_Alarm", "Flow_Sensor_Fault", "Flow_Instant",
                                "Flow_Total", "Flow_Int", "Flow_Setpoint");
  setAddr("mapFlow", "Flow_Alarm",        3, 1, 0, 567, 7);
  setAddr("mapFlow", "Flow_Sensor_Fault", 3, 1, 1, 567, 7);
  setAddr("mapFlow", "Flow_Instant",      3, 3, 0, 566, 4);
  setAddr("mapFlow", "Flow_Total",        3, 3, 2, 566, 4);
  setAddr("mapFlow", "Flow_Int",          3, 3, 4, 561, 4);
  setAddr("mapFlow", "Flow_Setpoint",     3, 3, 5, 561, 4);

  // ---------------- Устройство 4: Датчик давления, Slave ID 4 ----------------
  dyn_dyn_string n4; dyn_dyn_int t4;
  n4[1] = makeDynString("mapPressT");                             t4[1] = makeDynInt(DPEL_STRUCT);
  n4[2] = makeDynString("", "Pressure_Alarm_High");   t4[2] = makeDynInt(0, DPEL_BOOL);
  n4[3] = makeDynString("", "Pressure_Alarm_Low");    t4[3] = makeDynInt(0, DPEL_BOOL);
  n4[4] = makeDynString("", "Pressure_Sensor_Fault"); t4[4] = makeDynInt(0, DPEL_BOOL);
  n4[5] = makeDynString("", "Pressure");              t4[5] = makeDynInt(0, DPEL_FLOAT);
  n4[6] = makeDynString("", "Pressure_Int");          t4[6] = makeDynInt(0, DPEL_INT);
  n4[7] = makeDynString("", "Pressure_Setpoint");     t4[7] = makeDynInt(0, DPEL_INT);
  mkDevice("mapPressT", "mapPress", n4, t4);

  dyn_string e4 = makeDynString("Pressure_Alarm_High", "Pressure_Alarm_Low",
                                "Pressure_Sensor_Fault", "Pressure", "Pressure_Int",
                                "Pressure_Setpoint");
  setAddr("mapPress", "Pressure_Alarm_High",   4, 1, 0, 567, 7);
  setAddr("mapPress", "Pressure_Alarm_Low",    4, 1, 1, 567, 7);
  setAddr("mapPress", "Pressure_Sensor_Fault", 4, 1, 2, 567, 7);
  setAddr("mapPress", "Pressure",              4, 3, 0, 566, 4);
  setAddr("mapPress", "Pressure_Int",          4, 3, 2, 561, 4);
  setAddr("mapPress", "Pressure_Setpoint",     4, 3, 3, 561, 4);

  // ------------------- Устройство 5: Уровнемер, Slave ID 5 -------------------
  dyn_dyn_string n5; dyn_dyn_int t5;
  n5[1] = makeDynString("mapLevelT");                             t5[1] = makeDynInt(DPEL_STRUCT);
  n5[2] = makeDynString("", "Level_Alarm_High");   t5[2] = makeDynInt(0, DPEL_BOOL);
  n5[3] = makeDynString("", "Level_Alarm_Low");    t5[3] = makeDynInt(0, DPEL_BOOL);
  n5[4] = makeDynString("", "Level_Sensor_Fault"); t5[4] = makeDynInt(0, DPEL_BOOL);
  n5[5] = makeDynString("", "Level");              t5[5] = makeDynInt(0, DPEL_FLOAT);
  n5[6] = makeDynString("", "Level_Int");          t5[6] = makeDynInt(0, DPEL_INT);
  n5[7] = makeDynString("", "Level_Setpoint");     t5[7] = makeDynInt(0, DPEL_INT);
  mkDevice("mapLevelT", "mapLevel", n5, t5);

  dyn_string e5 = makeDynString("Level_Alarm_High", "Level_Alarm_Low",
                                "Level_Sensor_Fault", "Level", "Level_Int",
                                "Level_Setpoint");
  setAddr("mapLevel", "Level_Alarm_High",   5, 1, 0, 567, 7);
  setAddr("mapLevel", "Level_Alarm_Low",    5, 1, 1, 567, 7);
  setAddr("mapLevel", "Level_Sensor_Fault", 5, 1, 2, 567, 7);
  setAddr("mapLevel", "Level",              5, 3, 0, 566, 4);
  setAddr("mapLevel", "Level_Int",          5, 3, 2, 561, 4);
  setAddr("mapLevel", "Level_Setpoint",     5, 3, 3, 561, 4);

  // ------------- Устройство 6: Клапан / Задвижка, Slave ID 6 -------------
  dyn_dyn_string n6; dyn_dyn_int t6;
  n6[1] = makeDynString("mapValveT");                             t6[1] = makeDynInt(DPEL_STRUCT);
  n6[2] = makeDynString("", "Valve_Open");     t6[2] = makeDynInt(0, DPEL_BOOL);
  n6[3] = makeDynString("", "Valve_Close");    t6[3] = makeDynInt(0, DPEL_BOOL);
  n6[4] = makeDynString("", "Valve_Opened");   t6[4] = makeDynInt(0, DPEL_BOOL);
  n6[5] = makeDynString("", "Valve_Closed");   t6[5] = makeDynInt(0, DPEL_BOOL);
  n6[6] = makeDynString("", "Valve_Fault");    t6[6] = makeDynInt(0, DPEL_BOOL);
  n6[7] = makeDynString("", "Valve_Position"); t6[7] = makeDynInt(0, DPEL_FLOAT);
  n6[8] = makeDynString("", "Valve_Setpoint"); t6[8] = makeDynInt(0, DPEL_INT);
  mkDevice("mapValveT", "mapValve", n6, t6);

  dyn_string e6 = makeDynString("Valve_Open", "Valve_Close", "Valve_Opened",
                                "Valve_Closed", "Valve_Fault", "Valve_Position",
                                "Valve_Setpoint");
  setAddr("mapValve", "Valve_Open",     6, 1, 0, 567, 7);
  setAddr("mapValve", "Valve_Close",    6, 1, 1, 567, 7);
  setAddr("mapValve", "Valve_Opened",   6, 1, 2, 567, 7);
  setAddr("mapValve", "Valve_Closed",   6, 1, 3, 567, 7);
  setAddr("mapValve", "Valve_Fault",    6, 1, 4, 567, 7);
  setAddr("mapValve", "Valve_Position", 6, 3, 0, 566, 4);
  setAddr("mapValve", "Valve_Setpoint", 6, 3, 2, 561, 4);

  DebugN("");
  DebugN("Ждём 40 с на опрос...");
  delay(40);

  DebugN("");
  DebugN("=== Результат по элементам ===");
  report("mapPump",  e1, "Насос", 1);
  report("mapTemp",  e2, "Датчик температуры", 2);
  report("mapFlow",  e3, "Расходомер", 3);
  report("mapPress", e4, "Датчик давления", 4);
  report("mapLevel", e5, "Уровнемер", 5);
  report("mapValve", e6, "Клапан", 6);

  DebugN("");
  DebugN("=== ИТОГ: успешно ", GLOBAL_OK, ", неудачно ", GLOBAL_BAD, " ===");
  DebugN("--- Объекты оставлены в проекте ---");
}

// ============================================================ helpers

string findPollGroup()
{
  dyn_string all = dpNames("_**");
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpTypeName(all[i] + ".") == "_PollGroup") { return all[i]; }
  }
  return "";
}

// Описания PLC создаёт пользователь. Скрипт только сообщает, чего нет.
void checkPlcDefinitions()
{
  DebugN("");
  DebugN("=== Описания PLC (_Mod_Plc) ===");
  dyn_string all = dpNames("_Mod_Plc*");
  DebugN("  всего найдено: ", dynlen(all));
  for (int i = 1; i <= dynlen(all); i++) { DebugN("    ", all[i]); }

  for (int num = 1; num <= 6; num++)
  {
    bool found = false;
    for (int i = 1; i <= dynlen(all); i++)
    {
      if (all[i] == "System1:_Mod_Plc_" + num) { found = true; }
    }
    if (!found)
    {
      DebugN("  >>> Slave ID ", num, ": описания PLC _Mod_Plc_", num, " НЕТ");
    }
  }
  DebugN("  (описания PLC создаёт пользователь, скрипт их не создаёт)");
}

// Создаёт тип и точку данных, предварительно удаляя прежние объекты.
//
// Существование типа проверяется ТОЛЬКО через dpTypeGet. Имя типа не является
// именем точки данных, поэтому dpExists для него всегда возвращает FALSE и
// такая проверка ничего не значит: тип считается удалённым, пока он на месте,
// и dpTypeCreate затем отвечает "DP already exists".
//
// dpTypeDelete асинхронен, поэтому удаление повторяется, пока тип не исчезнет.
// Создание типа тоже повторяется - на удалённом, но ещё не освобождённом
// типе первый вызов неизбежно получает отказ.
void mkDevice(string dpt, string dp, dyn_dyn_string n, dyn_dyn_int t)
{
  // точка данных
  if (dpExists(dp)) { dpDelete(dp); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(dp)) { break; }
    delay(1);
  }
  if (dpExists(dp)) { DebugN("  ВНИМАНИЕ: точка ", dp, " не удалилась"); }

  // тип точки данных
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    dyn_dyn_string probeNames;
    dyn_dyn_int probeTypes;
    if (dpTypeGet(dpt, probeNames, probeTypes) != 0) { break; }   // типа нет
    dpTypeDelete(dpt);
    delay(1);
  }

  int rcT = -1;
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    rcT = dpTypeCreate(n, t);
    if (rcT == 0) { break; }
    delay(1);
  }

  int rcD = dpCreate(dp, dpt);
  DebugN("  ", dp, ": тип ", (rcT == 0) ? "создан" : "ОШИБКА rc=" + rcT,
         ", точка ", (rcD == 0) ? "создана" : "ОШИБКА rc=" + rcD);
}

// Две попытки записи: при предыдущем прогоне M.1.1.0 и M.6.1.0 не
// подтвердились чтением с первого раза без внятной причины в логе драйвера.
void setAddr(string dp, string elem, int slave, int fc, int reg,
             int datatype, int direction)
{
  string dpe = dp + "." + elem;
  string address = "M." + slave + "." + fc + "." + reg;
  int rc = -1;

  for (int attempt = 1; attempt <= 2; attempt++)
  {
    dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                      dpe + ":_distrib.._driver", DRIVER);
    rc = dpSetTimedWait(0,
                      dpe + ":_address.._type",       DPCONFIG_PERIPH_ADDR_MAIN,
                      dpe + ":_address.._reference",  address,
                      dpe + ":_address.._active",     TRUE,
                      dpe + ":_address.._drv_ident",  "MODBUS",
                      dpe + ":_address.._datatype",   datatype,
                      dpe + ":_address.._direction",  direction,
                      dpe + ":_address.._poll_group", GROUP);

    string probe;
    dpGet(dpe + ":_address.._reference", probe);
    if (probe == address) { break; }
    delay(1);
  }

  string gotRef, gotGrp;
  int gotType;
  dpGet(dpe + ":_address.._reference",  gotRef);
  dpGet(dpe + ":_address.._datatype",   gotType);
  dpGet(dpe + ":_address.._poll_group", gotGrp);

  bool ok = (rc == 0) && (gotRef == address) && (gotType == datatype) && (gotGrp == GROUP);
  DebugN("      ", (ok ? "ok  " : "ОШИБКА"), " ", dpe, " -> ", gotRef,
         " dt=", gotType, " группа=", gotGrp);
}

void report(string dp, dyn_string elems, string device, int slave)
{
  DebugN("");
  DebugN("--- ", device, " (Slave ID ", slave, ") ---");
  int ok = 0, bad = 0;

  for (int i = 1; i <= dynlen(elems); i++)
  {
    string bare = dp + "." + elems[i];

    string ref;
    dpGet(bare + ":_address.._reference", ref);

    bool isBad;
    time t;
    dyn_anytype v;
    dpGet(bare + ":_online.._bad",   isBad);
    dpGet(bare + ":_online.._stime", t);
    dpGet(bare + ":_online.._value", v);

    bool hasData = (t != makeTime(1970, 1, 1, 3, 0, 0));
    if (hasData && !isBad) { ok++; GLOBAL_OK++; } else { bad++; GLOBAL_BAD++; }

    DebugN("    ", (hasData && !isBad) ? "данные" : "НЕТ   ",
           "  ", bare, "  ", ref, "  = ", v);
  }
  DebugN("    успешно ", ok, ", неудачно ", bad);
}