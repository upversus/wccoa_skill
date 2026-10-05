// СГЕНЕРИРОВАНО АВТОМАТИЧЕСКИ: tools/gen-modbus-dp.js
// Карта   : G:\TEMP\wccoa_tools\tools\modbus-sim\devices\smart-temp-press.json
// Порядок слов: CDAB
// Драйвер : 2
//
// Не правьте этот файл руками: он перезаписывается при следующей
// генерации. Правьте карту и запускайте генератор заново.
//
// Карта элементов:
//
//   точка STP, тип stpt_, slave 1
//     дискретные входы FC 2:
//       M.1.2.0      567  BIT      Device_Ready
//       M.1.2.1      567  BIT      Heating_Active
//       M.1.2.2      567  BIT      Cooling_Active
//       M.1.2.3      567  BIT      Alarm_High_Temp
//       M.1.2.4      567  BIT      Alarm_Low_Temp
//       M.1.2.5      567  BIT      Alarm_High_Pressure
//       M.1.2.6      567  BIT      Alarm_Low_Pressure
//       M.1.2.7      567  BIT      Sensor_Fault
//     coils FC 1:
//       M.1.1.0      567  BIT      Enable_Heating
//       M.1.1.1      567  BIT      Enable_Cooling
//       M.1.1.2      567  BIT      Reset_Alarms
//       M.1.1.3      567  BIT      Start_Calibration
//       M.1.1.4      567  BIT      Relay_1
//       M.1.1.5      567  BIT      Relay_2
//     входные регистры FC 4:
//       M.1.4.0      561  INT16    Current_Temperature
//       M.1.4.1      563  UINT16   Current_Pressure
//       M.1.4.2      563  UINT16   Humidity
//       M.1.4.3      563  UINT16   Heater_Power
//       M.1.4.4      563  UINT16   Cooler_Power
//       M.1.4.5      563  UINT16   Device_Status_Word
//       M.1.4.6      564  UINT32   Total_Operating_Hours
//       M.1.4.8      566  FLOAT    Energy_Consumption
//     holding регистры FC 3:
//       M.1.3.0      561  INT16    Temperature_Setpoint
//       M.1.3.1      563  UINT16   Pressure_Setpoint
//       M.1.3.2      563  UINT16   Humidity_Setpoint
//       M.1.3.3      563  UINT16   PID_Kp
//       M.1.3.4      563  UINT16   PID_Ki
//       M.1.3.5      563  UINT16   PID_Kd
//       M.1.3.6      563  UINT16   Max_Heater_Power
//       M.1.3.7      563  UINT16   Max_Cooler_Power
//       M.1.3.8      561  INT16    Alarm_High_Temp_Threshold
//       M.1.3.9      561  INT16    Alarm_Low_Temp_Threshold
//       M.1.3.10     563  UINT16   Alarm_High_Pressure_Threshold
//       M.1.3.11     563  UINT16   Alarm_Low_Pressure_Threshold
//       M.1.3.12     563  UINT16   Device_Address
//       M.1.3.13     563  UINT16   Baud_Rate_Code
//       M.1.3.14     563  UINT16   Parity_Code
//       M.1.3.15     563  UINT16   Stop_Bits
//       M.1.3.16     564  UINT32   Serial_Number
//       M.1.3.18     566  FLOAT    Firmware_Version


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

  // ---- slave 1 «SmartTempPress» : 40 элементов ----
  killDP("STP", "stpt_");

  dyn_dyn_string names;
  dyn_dyn_int    types;
  names[1] = makeDynString("stpt_");
  types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "Device_Ready");
  types[2] = makeDynInt(0, DPEL_BOOL);
  names[3] = makeDynString("", "Heating_Active");
  types[3] = makeDynInt(0, DPEL_BOOL);
  names[4] = makeDynString("", "Cooling_Active");
  types[4] = makeDynInt(0, DPEL_BOOL);
  names[5] = makeDynString("", "Alarm_High_Temp");
  types[5] = makeDynInt(0, DPEL_BOOL);
  names[6] = makeDynString("", "Alarm_Low_Temp");
  types[6] = makeDynInt(0, DPEL_BOOL);
  names[7] = makeDynString("", "Alarm_High_Pressure");
  types[7] = makeDynInt(0, DPEL_BOOL);
  names[8] = makeDynString("", "Alarm_Low_Pressure");
  types[8] = makeDynInt(0, DPEL_BOOL);
  names[9] = makeDynString("", "Sensor_Fault");
  types[9] = makeDynInt(0, DPEL_BOOL);
  names[10] = makeDynString("", "Enable_Heating");
  types[10] = makeDynInt(0, DPEL_BOOL);
  names[11] = makeDynString("", "Enable_Cooling");
  types[11] = makeDynInt(0, DPEL_BOOL);
  names[12] = makeDynString("", "Reset_Alarms");
  types[12] = makeDynInt(0, DPEL_BOOL);
  names[13] = makeDynString("", "Start_Calibration");
  types[13] = makeDynInt(0, DPEL_BOOL);
  names[14] = makeDynString("", "Relay_1");
  types[14] = makeDynInt(0, DPEL_BOOL);
  names[15] = makeDynString("", "Relay_2");
  types[15] = makeDynInt(0, DPEL_BOOL);
  names[16] = makeDynString("", "Current_Temperature");
  types[16] = makeDynInt(0, DPEL_INT);
  names[17] = makeDynString("", "Current_Pressure");
  types[17] = makeDynInt(0, DPEL_INT);
  names[18] = makeDynString("", "Humidity");
  types[18] = makeDynInt(0, DPEL_INT);
  names[19] = makeDynString("", "Heater_Power");
  types[19] = makeDynInt(0, DPEL_INT);
  names[20] = makeDynString("", "Cooler_Power");
  types[20] = makeDynInt(0, DPEL_INT);
  names[21] = makeDynString("", "Device_Status_Word");
  types[21] = makeDynInt(0, DPEL_INT);
  names[22] = makeDynString("", "Total_Operating_Hours");
  types[22] = makeDynInt(0, DPEL_INT);
  names[23] = makeDynString("", "Energy_Consumption");
  types[23] = makeDynInt(0, DPEL_FLOAT);
  names[24] = makeDynString("", "Temperature_Setpoint");
  types[24] = makeDynInt(0, DPEL_INT);
  names[25] = makeDynString("", "Pressure_Setpoint");
  types[25] = makeDynInt(0, DPEL_INT);
  names[26] = makeDynString("", "Humidity_Setpoint");
  types[26] = makeDynInt(0, DPEL_INT);
  names[27] = makeDynString("", "PID_Kp");
  types[27] = makeDynInt(0, DPEL_INT);
  names[28] = makeDynString("", "PID_Ki");
  types[28] = makeDynInt(0, DPEL_INT);
  names[29] = makeDynString("", "PID_Kd");
  types[29] = makeDynInt(0, DPEL_INT);
  names[30] = makeDynString("", "Max_Heater_Power");
  types[30] = makeDynInt(0, DPEL_INT);
  names[31] = makeDynString("", "Max_Cooler_Power");
  types[31] = makeDynInt(0, DPEL_INT);
  names[32] = makeDynString("", "Alarm_High_Temp_Threshold");
  types[32] = makeDynInt(0, DPEL_INT);
  names[33] = makeDynString("", "Alarm_Low_Temp_Threshold");
  types[33] = makeDynInt(0, DPEL_INT);
  names[34] = makeDynString("", "Alarm_High_Pressure_Threshold");
  types[34] = makeDynInt(0, DPEL_INT);
  names[35] = makeDynString("", "Alarm_Low_Pressure_Threshold");
  types[35] = makeDynInt(0, DPEL_INT);
  names[36] = makeDynString("", "Device_Address");
  types[36] = makeDynInt(0, DPEL_INT);
  names[37] = makeDynString("", "Baud_Rate_Code");
  types[37] = makeDynInt(0, DPEL_INT);
  names[38] = makeDynString("", "Parity_Code");
  types[38] = makeDynInt(0, DPEL_INT);
  names[39] = makeDynString("", "Stop_Bits");
  types[39] = makeDynInt(0, DPEL_INT);
  names[40] = makeDynString("", "Serial_Number");
  types[40] = makeDynInt(0, DPEL_INT);
  names[41] = makeDynString("", "Firmware_Version");
  types[41] = makeDynInt(0, DPEL_FLOAT);
  int rcT = dpTypeCreate(names, types);
  chk(rcT == 0, "stpt_: тип создан, элементов 40", "rc=" + rcT);

  int rcC = dpCreate("STP", "stpt_");
  chk(rcC == 0, "STP: точка создана", "rc=" + rcC);

  DebugN("  -- адреса --");
  cfg("STP", "Device_Ready", "M.1.2.0", 567, 4, grp);
  cfg("STP", "Heating_Active", "M.1.2.1", 567, 4, grp);
  cfg("STP", "Cooling_Active", "M.1.2.2", 567, 4, grp);
  cfg("STP", "Alarm_High_Temp", "M.1.2.3", 567, 4, grp);
  cfg("STP", "Alarm_Low_Temp", "M.1.2.4", 567, 4, grp);
  cfg("STP", "Alarm_High_Pressure", "M.1.2.5", 567, 4, grp);
  cfg("STP", "Alarm_Low_Pressure", "M.1.2.6", 567, 4, grp);
  cfg("STP", "Sensor_Fault", "M.1.2.7", 567, 4, grp);
  cfg("STP", "Enable_Heating", "M.1.1.0", 567, 7, grp);
  cfg("STP", "Enable_Cooling", "M.1.1.1", 567, 7, grp);
  cfg("STP", "Reset_Alarms", "M.1.1.2", 567, 7, grp);
  cfg("STP", "Start_Calibration", "M.1.1.3", 567, 7, grp);
  cfg("STP", "Relay_1", "M.1.1.4", 567, 7, grp);
  cfg("STP", "Relay_2", "M.1.1.5", 567, 7, grp);
  cfg("STP", "Current_Temperature", "M.1.4.0", 561, 4, grp);
  cfg("STP", "Current_Pressure", "M.1.4.1", 563, 4, grp);
  cfg("STP", "Humidity", "M.1.4.2", 563, 4, grp);
  cfg("STP", "Heater_Power", "M.1.4.3", 563, 4, grp);
  cfg("STP", "Cooler_Power", "M.1.4.4", 563, 4, grp);
  cfg("STP", "Device_Status_Word", "M.1.4.5", 563, 4, grp);
  cfg("STP", "Total_Operating_Hours", "M.1.4.6", 564, 4, grp);
  cfg("STP", "Energy_Consumption", "M.1.4.8", 566, 4, grp);
  cfg("STP", "Temperature_Setpoint", "M.1.3.0", 561, 4, grp);
  cfg("STP", "Pressure_Setpoint", "M.1.3.1", 563, 4, grp);
  cfg("STP", "Humidity_Setpoint", "M.1.3.2", 563, 4, grp);
  cfg("STP", "PID_Kp", "M.1.3.3", 563, 4, grp);
  cfg("STP", "PID_Ki", "M.1.3.4", 563, 4, grp);
  cfg("STP", "PID_Kd", "M.1.3.5", 563, 4, grp);
  cfg("STP", "Max_Heater_Power", "M.1.3.6", 563, 4, grp);
  cfg("STP", "Max_Cooler_Power", "M.1.3.7", 563, 4, grp);
  cfg("STP", "Alarm_High_Temp_Threshold", "M.1.3.8", 561, 4, grp);
  cfg("STP", "Alarm_Low_Temp_Threshold", "M.1.3.9", 561, 4, grp);
  cfg("STP", "Alarm_High_Pressure_Threshold", "M.1.3.10", 563, 4, grp);
  cfg("STP", "Alarm_Low_Pressure_Threshold", "M.1.3.11", 563, 4, grp);
  cfg("STP", "Device_Address", "M.1.3.12", 563, 4, grp);
  cfg("STP", "Baud_Rate_Code", "M.1.3.13", 563, 4, grp);
  cfg("STP", "Parity_Code", "M.1.3.14", 563, 4, grp);
  cfg("STP", "Stop_Bits", "M.1.3.15", 563, 4, grp);
  cfg("STP", "Serial_Number", "M.1.3.16", 564, 4, grp);
  cfg("STP", "Firmware_Version", "M.1.3.18", 566, 4, grp);

  elemCount += 40;

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
  dps[dynlen(dps) + 1] = "STP";
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
