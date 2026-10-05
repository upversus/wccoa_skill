// probe_coil.ctl - почему конфиг coil не записывается.
//
// 06_address_modbus.ctl на элементах bVal получает rc = -1 от dpSetTimedWait:
//     dpe + ":_address.._reference", "M.1.1.0",
//     dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
//     dpe + ":_address.._datatype",  567,
//     dpe + ":_direction",          7
//
// В шапке самого 06_address_modbus.ctl сказано: "Направление 7 не пишется из
// скрипта в комбинациях, несовместимых по типу: dpSetTimedWait возвращает
// rc = -1". Значит надо подобрать рабочую комбинацию, а не угадывать.
//
// Перебираем coil-адреса из карты map.json в сочетании с разными _direction.

string DPT = "probe_coil_t";
string DP  = "probe_coil";
string PG  = "System1:_pool1s";

main()
{
  DebugN("=== Подбор рабочей комбинации для coil ===");

  makeObjects();

  dyn_string coils = makeDynString(
      "M.1.1.0",   // Pump_Start
      "M.1.1.1",   // Pump_Stop
      "M.1.1.2",   // Pump_Run
      "M.1.1.3",   // Pump_Fault
      "M.1.1.5",   // вне карты
      "M.2.1.0");  // Temp_Alarm_High

  DebugN("");
  DebugN("--- _datatype 567 (BIT), перебор _direction ---");
  for (int d = 0; d <= 7; d++)
  {
    dyn_string good;
    for (int c = 1; c <= dynlen(coils); c++)
    {
      if (tryCoil(coils[c], 567, d)) { good = appendStr(good, coils[c] + " "); }
      delay(2);
    }
    DebugN("  direction=", d, "  принято: ", (good == "") ? "НИЧЕГО" : good);
  }

  DebugN("");
  DebugN("--- обратная проверка: holding-адрес с direction 7 ---");
  dyn_string holds = makeDynString("M.1.3.1", "M.1.3.2");
  for (int d = 0; d <= 7; d++)
  {
    dyn_string good;
    for (int c = 1; c <= dynlen(holds); c++)
    {
      if (tryCoil(holds[c], 566, d)) { good = appendStr(good, holds[c] + " "); }
      delay(2);
    }
    DebugN("  direction=", d, "  принято: ", (good == "") ? "НИЧЕГО" : good);
  }

  cleanObjects();
  DebugN("=== конец ===");
}

// Пытается записать конфиг и возвращает true, если rc == 0 и _reference читается.
bool tryCoil(string address, int datatype, int direction)
{
  string dpe = DP + ".bVal";

  // Перед каждой попыткой ПОЛНОСТЬЮ сбрасываем конфиг адреса и ждём.
  // Без сброса попытки идут подряд, dpSetTimedWait возвращается до
  // применения предыдущей записи, и результат получается случайным.
  dpSetTimedWait(0, dpe + ":_address.._type", DPCONFIG_NONE);
  for (int s = 1; s <= 5; s++)
  {
    string gone;
    int rcGone = dpGet(dpe + ":_address.._reference", gone);
    if (rcGone == -1) { break; }
    delay(1);
  }

  int rc = dpSetTimedWait(0,
        dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
        dpe + ":_distrib.._driver", 2,
        dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
        dpe + ":_address.._reference", address,
        dpe + ":_address.._active",    TRUE,
        dpe + ":_address.._drv_ident", "MODBUS",
        dpe + ":_address.._datatype",  datatype,
        dpe + ":_address.._direction", direction,
        dpe + ":_address.._poll_group", PG);
  if (rc != 0) { return false; }
  string ref;
  dpGet(dpe + ":_address.._reference", ref);
  return ref == address;
}

string appendStr(string acc, string s)
{
  if (acc == "") { return s; }
  return acc + s;
}

void makeObjects()
{
  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString(DPT);        t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "bVal"); t[2] = makeDynInt(0, DPEL_BOOL);
  dpTypeCreate(n, t);
  dpCreate(DP, DPT);
  DebugN("  создан ", DP, " типа ", DPT);
}

void cleanObjects()
{
  if (dpExists(DP)) { dpDelete(DP); }
  for (int i = 1; i <= 30; i++) { if (!dpExists(DP)) { break; } delay(1); }
  for (int k = 1; k <= 30; k++)
  {
    dyn_dyn_string pn;
    dyn_dyn_int pt;
    if (dpTypeGet(DPT, pn, pt) != 0) { break; }
    dpTypeDelete(DPT);
    delay(1);
  }
}