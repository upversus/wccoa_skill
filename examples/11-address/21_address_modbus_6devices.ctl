// СГЕНЕРИРОВАНО АВТОМАТИЧЕСКИ: tools/gen-modbus-dp.js
// Карта   : G:\TEMP\wccoa_tools\tools\modbus-sim\map.json
// Порядок слов: CDAB
// Драйвер : 2
//
// Не правьте этот файл руками: он перезаписывается при следующей
// генерации. Правьте карту и запускайте генератор заново.
//
// Карта элементов:
//
//   точка slave1, тип slave1_t, slave 1
//     coils FC 1:
//       M.1.1.0      567  BIT      Pump_Start
//       M.1.1.1      567  BIT      Pump_Stop
//       M.1.1.2      567  BIT      Pump_Run
//       M.1.1.3      567  BIT      Pump_Fault
//     holding регистры FC 3:
//       M.1.3.0      563  UINT16   Pump_Speed_Set
//       M.1.3.1      563  UINT16   Pump_Speed_Act
//       M.1.3.2      566  FLOAT    Pump_Current
//       M.1.3.4      566  FLOAT    Pump_Pressure
//       M.1.3.6      566  FLOAT    Pump_Flow
//       M.1.3.8      563  UINT16   Pump_Runtime
//
//   точка slave2, тип slave2_t, slave 2
//     coils FC 1:
//       M.2.1.0      567  BIT      Temp_Alarm_High
//       M.2.1.1      567  BIT      Temp_Alarm_Low
//       M.2.1.2      567  BIT      Temp_Sensor_Fault
//     holding регистры FC 3:
//       M.2.3.0      566  FLOAT    Temperature
//       M.2.3.2      563  UINT16   Temperature_Int
//       M.2.3.3      563  UINT16   Temp_Setpoint
//
//   точка slave3, тип slave3_t, slave 3
//     coils FC 1:
//       M.3.1.0      567  BIT      Flow_Alarm
//       M.3.1.1      567  BIT      Flow_Sensor_Fault
//     holding регистры FC 3:
//       M.3.3.0      566  FLOAT    Flow_Instant
//       M.3.3.2      564  UINT32   Flow_Total
//       M.3.3.4      563  UINT16   Flow_Int
//       M.3.3.5      563  UINT16   Flow_Setpoint
//
//   точка slave4, тип slave4_t, slave 4
//     coils FC 1:
//       M.4.1.0      567  BIT      Pressure_Alarm_High
//       M.4.1.1      567  BIT      Pressure_Alarm_Low
//       M.4.1.2      567  BIT      Pressure_Sensor_Fault
//     holding регистры FC 3:
//       M.4.3.0      566  FLOAT    Pressure
//       M.4.3.2      563  UINT16   Pressure_Int
//       M.4.3.3      563  UINT16   Pressure_Setpoint
//
//   точка slave5, тип slave5_t, slave 5
//     coils FC 1:
//       M.5.1.0      567  BIT      Level_Alarm_High
//       M.5.1.1      567  BIT      Level_Alarm_Low
//       M.5.1.2      567  BIT      Level_Sensor_Fault
//     holding регистры FC 3:
//       M.5.3.0      566  FLOAT    Level
//       M.5.3.2      563  UINT16   Level_Int
//       M.5.3.3      563  UINT16   Level_Setpoint
//
//   точка slave6, тип slave6_t, slave 6
//     coils FC 1:
//       M.6.1.0      567  BIT      Valve_Open
//       M.6.1.1      567  BIT      Valve_Close
//       M.6.1.2      567  BIT      Valve_Opened
//       M.6.1.3      567  BIT      Valve_Closed
//       M.6.1.4      567  BIT      Valve_Fault
//       M.6.1.5      567  BIT      Valve_Cmd_Test
//     holding регистры FC 3:
//       M.6.3.0      566  FLOAT    Valve_Position
//       M.6.3.2      563  UINT16   Valve_Setpoint
//       M.6.3.3      563  UINT16   Valve_Reg_Test


// Сгенерировано: делаем точку, привязываем адреса, проверяем данные.
int dpdPass = 0;
int dpdFail = 0;
int elemCount = 0;

const int DRV = 2;

main()
{
  DebugN("=== точка данных по карте ===");
  string grp = findPollGroup();
  DebugN("группа опроса: '" + grp + "'");
  if (grp == "")
  {
    DebugN("  FAIL группа опроса не найдена.");
    DebugN("  Создайте её: панель системы -> Drivers -> Poll groups.");
    dpdFail++;
    return;
  }

  // ---- slave 1 «Насос» : 10 элементов ----
  killDP("slave1", "slave1_t");

  dyn_dyn_string names;
  dyn_dyn_int    types;
  names[1] = makeDynString("slave1_t");
  types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "Pump_Start");
  types[2] = makeDynInt(0, DPEL_BOOL);
  names[3] = makeDynString("", "Pump_Stop");
  types[3] = makeDynInt(0, DPEL_BOOL);
  names[4] = makeDynString("", "Pump_Run");
  types[4] = makeDynInt(0, DPEL_BOOL);
  names[5] = makeDynString("", "Pump_Fault");
  types[5] = makeDynInt(0, DPEL_BOOL);
  names[6] = makeDynString("", "Pump_Speed_Set");
  types[6] = makeDynInt(0, DPEL_INT);
  names[7] = makeDynString("", "Pump_Speed_Act");
  types[7] = makeDynInt(0, DPEL_INT);
  names[8] = makeDynString("", "Pump_Current");
  types[8] = makeDynInt(0, DPEL_FLOAT);
  names[9] = makeDynString("", "Pump_Pressure");
  types[9] = makeDynInt(0, DPEL_FLOAT);
  names[10] = makeDynString("", "Pump_Flow");
  types[10] = makeDynInt(0, DPEL_FLOAT);
  names[11] = makeDynString("", "Pump_Runtime");
  types[11] = makeDynInt(0, DPEL_INT);
  int rcT = dpTypeCreate(names, types);
  chk(rcT == 0, "slave1_t: тип создан, элементов 10", "rc=" + rcT);

  int rcC = dpCreate("slave1", "slave1_t");
  chk(rcC == 0, "slave1: точка создана", "rc=" + rcC);

  DebugN("  -- адреса --");
  cfg("slave1", "Pump_Start", "M.1.1.0", 567, 7, grp);
  cfg("slave1", "Pump_Stop", "M.1.1.1", 567, 7, grp);
  cfg("slave1", "Pump_Run", "M.1.1.2", 567, 7, grp);
  cfg("slave1", "Pump_Fault", "M.1.1.3", 567, 7, grp);
  cfg("slave1", "Pump_Speed_Set", "M.1.3.0", 563, 4, grp);
  cfg("slave1", "Pump_Speed_Act", "M.1.3.1", 563, 4, grp);
  cfg("slave1", "Pump_Current", "M.1.3.2", 566, 4, grp);
  cfg("slave1", "Pump_Pressure", "M.1.3.4", 566, 4, grp);
  cfg("slave1", "Pump_Flow", "M.1.3.6", 566, 4, grp);
  cfg("slave1", "Pump_Runtime", "M.1.3.8", 563, 4, grp);

  elemCount += 10;

  // ---- slave 2 «Датчик температуры» : 6 элементов ----
  killDP("slave2", "slave2_t");

  dyn_dyn_string names;
  dyn_dyn_int    types;
  names[1] = makeDynString("slave2_t");
  types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "Temp_Alarm_High");
  types[2] = makeDynInt(0, DPEL_BOOL);
  names[3] = makeDynString("", "Temp_Alarm_Low");
  types[3] = makeDynInt(0, DPEL_BOOL);
  names[4] = makeDynString("", "Temp_Sensor_Fault");
  types[4] = makeDynInt(0, DPEL_BOOL);
  names[5] = makeDynString("", "Temperature");
  types[5] = makeDynInt(0, DPEL_FLOAT);
  names[6] = makeDynString("", "Temperature_Int");
  types[6] = makeDynInt(0, DPEL_INT);
  names[7] = makeDynString("", "Temp_Setpoint");
  types[7] = makeDynInt(0, DPEL_INT);
  int rcT = dpTypeCreate(names, types);
  chk(rcT == 0, "slave2_t: тип создан, элементов 6", "rc=" + rcT);

  int rcC = dpCreate("slave2", "slave2_t");
  chk(rcC == 0, "slave2: точка создана", "rc=" + rcC);

  DebugN("  -- адреса --");
  cfg("slave2", "Temp_Alarm_High", "M.2.1.0", 567, 7, grp);
  cfg("slave2", "Temp_Alarm_Low", "M.2.1.1", 567, 7, grp);
  cfg("slave2", "Temp_Sensor_Fault", "M.2.1.2", 567, 7, grp);
  cfg("slave2", "Temperature", "M.2.3.0", 566, 4, grp);
  cfg("slave2", "Temperature_Int", "M.2.3.2", 563, 4, grp);
  cfg("slave2", "Temp_Setpoint", "M.2.3.3", 563, 4, grp);

  elemCount += 6;

  // ---- slave 3 «Расходомер» : 6 элементов ----
  killDP("slave3", "slave3_t");

  dyn_dyn_string names;
  dyn_dyn_int    types;
  names[1] = makeDynString("slave3_t");
  types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "Flow_Alarm");
  types[2] = makeDynInt(0, DPEL_BOOL);
  names[3] = makeDynString("", "Flow_Sensor_Fault");
  types[3] = makeDynInt(0, DPEL_BOOL);
  names[4] = makeDynString("", "Flow_Instant");
  types[4] = makeDynInt(0, DPEL_FLOAT);
  names[5] = makeDynString("", "Flow_Total");
  types[5] = makeDynInt(0, DPEL_INT);
  names[6] = makeDynString("", "Flow_Int");
  types[6] = makeDynInt(0, DPEL_INT);
  names[7] = makeDynString("", "Flow_Setpoint");
  types[7] = makeDynInt(0, DPEL_INT);
  int rcT = dpTypeCreate(names, types);
  chk(rcT == 0, "slave3_t: тип создан, элементов 6", "rc=" + rcT);

  int rcC = dpCreate("slave3", "slave3_t");
  chk(rcC == 0, "slave3: точка создана", "rc=" + rcC);

  DebugN("  -- адреса --");
  cfg("slave3", "Flow_Alarm", "M.3.1.0", 567, 7, grp);
  cfg("slave3", "Flow_Sensor_Fault", "M.3.1.1", 567, 7, grp);
  cfg("slave3", "Flow_Instant", "M.3.3.0", 566, 4, grp);
  cfg("slave3", "Flow_Total", "M.3.3.2", 564, 4, grp);
  cfg("slave3", "Flow_Int", "M.3.3.4", 563, 4, grp);
  cfg("slave3", "Flow_Setpoint", "M.3.3.5", 563, 4, grp);

  elemCount += 6;

  // ---- slave 4 «Датчик давления» : 6 элементов ----
  killDP("slave4", "slave4_t");

  dyn_dyn_string names;
  dyn_dyn_int    types;
  names[1] = makeDynString("slave4_t");
  types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "Pressure_Alarm_High");
  types[2] = makeDynInt(0, DPEL_BOOL);
  names[3] = makeDynString("", "Pressure_Alarm_Low");
  types[3] = makeDynInt(0, DPEL_BOOL);
  names[4] = makeDynString("", "Pressure_Sensor_Fault");
  types[4] = makeDynInt(0, DPEL_BOOL);
  names[5] = makeDynString("", "Pressure");
  types[5] = makeDynInt(0, DPEL_FLOAT);
  names[6] = makeDynString("", "Pressure_Int");
  types[6] = makeDynInt(0, DPEL_INT);
  names[7] = makeDynString("", "Pressure_Setpoint");
  types[7] = makeDynInt(0, DPEL_INT);
  int rcT = dpTypeCreate(names, types);
  chk(rcT == 0, "slave4_t: тип создан, элементов 6", "rc=" + rcT);

  int rcC = dpCreate("slave4", "slave4_t");
  chk(rcC == 0, "slave4: точка создана", "rc=" + rcC);

  DebugN("  -- адреса --");
  cfg("slave4", "Pressure_Alarm_High", "M.4.1.0", 567, 7, grp);
  cfg("slave4", "Pressure_Alarm_Low", "M.4.1.1", 567, 7, grp);
  cfg("slave4", "Pressure_Sensor_Fault", "M.4.1.2", 567, 7, grp);
  cfg("slave4", "Pressure", "M.4.3.0", 566, 4, grp);
  cfg("slave4", "Pressure_Int", "M.4.3.2", 563, 4, grp);
  cfg("slave4", "Pressure_Setpoint", "M.4.3.3", 563, 4, grp);

  elemCount += 6;

  // ---- slave 5 «Уровнемер» : 6 элементов ----
  killDP("slave5", "slave5_t");

  dyn_dyn_string names;
  dyn_dyn_int    types;
  names[1] = makeDynString("slave5_t");
  types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "Level_Alarm_High");
  types[2] = makeDynInt(0, DPEL_BOOL);
  names[3] = makeDynString("", "Level_Alarm_Low");
  types[3] = makeDynInt(0, DPEL_BOOL);
  names[4] = makeDynString("", "Level_Sensor_Fault");
  types[4] = makeDynInt(0, DPEL_BOOL);
  names[5] = makeDynString("", "Level");
  types[5] = makeDynInt(0, DPEL_FLOAT);
  names[6] = makeDynString("", "Level_Int");
  types[6] = makeDynInt(0, DPEL_INT);
  names[7] = makeDynString("", "Level_Setpoint");
  types[7] = makeDynInt(0, DPEL_INT);
  int rcT = dpTypeCreate(names, types);
  chk(rcT == 0, "slave5_t: тип создан, элементов 6", "rc=" + rcT);

  int rcC = dpCreate("slave5", "slave5_t");
  chk(rcC == 0, "slave5: точка создана", "rc=" + rcC);

  DebugN("  -- адреса --");
  cfg("slave5", "Level_Alarm_High", "M.5.1.0", 567, 7, grp);
  cfg("slave5", "Level_Alarm_Low", "M.5.1.1", 567, 7, grp);
  cfg("slave5", "Level_Sensor_Fault", "M.5.1.2", 567, 7, grp);
  cfg("slave5", "Level", "M.5.3.0", 566, 4, grp);
  cfg("slave5", "Level_Int", "M.5.3.2", 563, 4, grp);
  cfg("slave5", "Level_Setpoint", "M.5.3.3", 563, 4, grp);

  elemCount += 6;

  // ---- slave 6 «Клапан» : 9 элементов ----
  killDP("slave6", "slave6_t");

  dyn_dyn_string names;
  dyn_dyn_int    types;
  names[1] = makeDynString("slave6_t");
  types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "Valve_Open");
  types[2] = makeDynInt(0, DPEL_BOOL);
  names[3] = makeDynString("", "Valve_Close");
  types[3] = makeDynInt(0, DPEL_BOOL);
  names[4] = makeDynString("", "Valve_Opened");
  types[4] = makeDynInt(0, DPEL_BOOL);
  names[5] = makeDynString("", "Valve_Closed");
  types[5] = makeDynInt(0, DPEL_BOOL);
  names[6] = makeDynString("", "Valve_Fault");
  types[6] = makeDynInt(0, DPEL_BOOL);
  names[7] = makeDynString("", "Valve_Cmd_Test");
  types[7] = makeDynInt(0, DPEL_BOOL);
  names[8] = makeDynString("", "Valve_Position");
  types[8] = makeDynInt(0, DPEL_FLOAT);
  names[9] = makeDynString("", "Valve_Setpoint");
  types[9] = makeDynInt(0, DPEL_INT);
  names[10] = makeDynString("", "Valve_Reg_Test");
  types[10] = makeDynInt(0, DPEL_INT);
  int rcT = dpTypeCreate(names, types);
  chk(rcT == 0, "slave6_t: тип создан, элементов 9", "rc=" + rcT);

  int rcC = dpCreate("slave6", "slave6_t");
  chk(rcC == 0, "slave6: точка создана", "rc=" + rcC);

  DebugN("  -- адреса --");
  cfg("slave6", "Valve_Open", "M.6.1.0", 567, 7, grp);
  cfg("slave6", "Valve_Close", "M.6.1.1", 567, 7, grp);
  cfg("slave6", "Valve_Opened", "M.6.1.2", 567, 7, grp);
  cfg("slave6", "Valve_Closed", "M.6.1.3", 567, 7, grp);
  cfg("slave6", "Valve_Fault", "M.6.1.4", 567, 7, grp);
  cfg("slave6", "Valve_Cmd_Test", "M.6.1.5", 567, 7, grp);
  cfg("slave6", "Valve_Position", "M.6.3.0", 566, 4, grp);
  cfg("slave6", "Valve_Setpoint", "M.6.3.2", 563, 4, grp);
  cfg("slave6", "Valve_Reg_Test", "M.6.3.3", 563, 4, grp);

  elemCount += 9;

  // ------------------------- проверка данных -------------------------
  DebugN("=== ждём данные ===");
  for (int i = 1; i <= 30; i++) { if (allFresh()) { break; } delay(1); }

  // Один общий срез, потом одна пауза, потом второй срез. Проверять
  // каждый элемент в отдельном цикле со своей паузой нельзя: при
  // 40 элементах и паузе 6 с проверка растягивается на четыре минуты.
  dyn_string names = allElems();
  int nAll = dynlen(names);
  dyn_string first = makeDynString();
  for (int i = 1; i <= nAll; i++)
  {
    dyn_anytype v;
    dpGet(names[i] + ":_online.._value", v);
    first[dynlen(first) + 1] = "" + v;
  }

  DebugN("=== значения, первый срез ===");
  for (int i = 1; i <= nAll; i++)
  {
    dyn_anytype v; bool b; int q; time t;
    dpGet(names[i] + ":_online.._value", v);
    dpGet(names[i] + ":_online.._bad", b);
    dpGet(names[i] + ":_online.._quality_code", q);
    dpGet(names[i] + ":_online.._stime", t);
    DebugN("     ", names[i], ": v=", v, " q=", q, " bad=", b);
  }

  DebugN("=== ждём 6 с, второй срез ===");
  delay(6);
  int good = 0, fresh = 0, live = 0;
  for (int i = 1; i <= nAll; i++)
  {
    dyn_anytype v; bool b; int q; time t;
    dpGet(names[i] + ":_online.._value", v);
    dpGet(names[i] + ":_online.._bad", b);
    dpGet(names[i] + ":_online.._quality_code", q);
    dpGet(names[i] + ":_online.._stime", t);
    if (q == 128 && !b) { good++; }
    else { DebugN("   НЕ GOOD: ", names[i], " q=", q, " bad=", b); }
    if (t != makeTime(1970, 1, 1, 3, 0, 0)) { fresh++; }
    else { DebugN("   НЕТ ДАННЫХ: ", names[i]); }
    if (("" + v) != first[i]) { live++; }
  }
  DebugN("=== итог ===");
  DebugN("  элементов всего  : ", nAll);
  DebugN("  quality = 128    : ", good);
  DebugN("  данные пришли    : ", fresh);
  DebugN("  значения меняются: ", live);
  chk(good == nAll, "все элементы GOOD", "" + good);
  chk(fresh == nAll, "данные у всех элементов", "" + fresh);
  chk(live > 0, "хотя бы часть значений меняется", "" + live);

  DebugN("");
  DebugN("PASS=", dpdPass, "  FAIL=", dpdFail);
  DebugN("=== конец ===");
}

// ------------------------------------------------------------------
// Привязка адреса. Рецепт проверен на CTL 3.18; порядок атрибутов важен.
// Без _distrib драйвер не считает точку своей и молчит без ошибок.
void cfg(string dp, string el, string addr, int datatype, int direction, string grp)
{
  string dpe = dp + "." + el;
  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", DRV);
  int rc = dpSetTimedWait(0,
                    dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                    dpe + ":_address.._reference", addr,
                    dpe + ":_address.._active",    TRUE,
                    dpe + ":_address.._drv_ident", "MODBUS",
                    dpe + ":_address.._datatype",  datatype,
                    dpe + ":_address.._direction", direction,
                    dpe + ":_address.._poll_group", grp);
  string got;
  dpGet(dpe + ":_address.._reference", got);
  chk((rc == 0) && (got == addr), dp + "." + el + " " + addr, "rc=" + rc + " got='" + got + "'");
}

void killDP(string dp, string dpt)
{
  if (dpExists(dp)) { dpDelete(dp); }
  for (int i = 1; i <= 30; i++) { if (!dpExists(dp)) { break; } delay(1); }
  for (int j = 1; j <= 30; j++)
  {
    dyn_dyn_string pn; dyn_dyn_int pt;
    if (dpTypeGet(dpt, pn, pt) != 0) { break; }
    dpTypeDelete(dpt); delay(1);
  }
}

// Имена элементов берём из типа точки: функции dpGetAllDPEs в CTL нет.
dyn_string allElems()
{
  dyn_string res = makeDynString();
  dyn_string dps = makeDynString();
  dps[dynlen(dps) + 1] = "slave1";
  dps[dynlen(dps) + 1] = "slave2";
  dps[dynlen(dps) + 1] = "slave3";
  dps[dynlen(dps) + 1] = "slave4";
  dps[dynlen(dps) + 1] = "slave5";
  dps[dynlen(dps) + 1] = "slave6";
  for (int d = 1; d <= dynlen(dps); d++)
  {
    string tpn = dpTypeName(dps[d] + ".");
    dyn_dyn_string nm; dyn_dyn_int ty;
    if (dpTypeGet(tpn, nm, ty) != 0) { continue; }
    for (int k = 2; k <= dynlen(nm); k++)
    { res[dynlen(res) + 1] = dps[d] + "." + nm[k][dynlen(nm[k])]; }
  }
  return res;
}

bool allFresh()
{
  dyn_string all = allElems();
  if (dynlen(all) == 0) { return false; }
  for (int i = 1; i <= dynlen(all); i++)
  {
    time t; dpGet(all[i] + ":_online.._stime", t);
    if (t == makeTime(1970, 1, 1, 3, 0, 0)) { return false; }
  }
  return true;
}

// Группа опроса: берём первую точку типа _PollGroup, имя уже с системным
// префиксом, то есть "System1:_1s".
string findPollGroup()
{
  dyn_string all = dpNames("_**");
  for (int i = 1; i <= dynlen(all); i++)
  { if (dpTypeName(all[i] + ".") == "_PollGroup") { return all[i]; } }
  return "";
}

void chk(bool ok, string what, string extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra); }
}
