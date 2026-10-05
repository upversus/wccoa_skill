// exp_modbus_probe.ctl — проверка формата адреса Modbus при записи из скрипта.
//
// Эталон ExampleDP_Arg1 использует _reference = "M.1.3.2", то есть
//   M            — драйвер MODBUS
//   1            — номер PLC (в эмуляторе <Number>1</Number>)
//   3            — функциональный код 3 = read multiple registers
//   2            — адрес регистра (в эмуляторе Reg_2 с <Addr>2</Addr>)
//
// Регистры эмулятора (файл t1.xml):
//   Addr 0, RegsCount 1 — 16-битное значение
//   Addr 2, RegsCount 2 — 32-битное значение (float)
//   Addr 4, mSpace 2    — логическое значение, мостом с Kepware User3
//
// Перебираются варианты для логического элемента: функциональный код
// 1 (read coils) и 2 (read input discrete) — какой из них соответствует
// регистру Addr 4, выясняется экспериментально.
//
// Проверено: CTL 3.18, проект prg_12_3.

main()
{
  DebugN("=== Проверка формата адреса MODBUS ===");

  int driverNumber = 2;   // WCCOAmod.exe -num 2

  string dpt = "dpdemo_mbprobe";
  dyn_dyn_string probeNames;
  dyn_dyn_int probeTypes;

  // Убираем возможные остатки
  dyn_string old = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(old); i++) { dpDelete(old[i]); }
  dpTypeDelete(dpt);

  // Тип: корень + четыре элемента-кандидата
  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);        types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "f566"); types[2] = makeDynInt(0, DPEL_FLOAT); // FC3 reg2
  names[3] = makeDynString("", "i561"); types[3] = makeDynInt(0, DPEL_INT);   // FC3 reg0
  names[4] = makeDynString("", "b567"); types[4] = makeDynInt(0, DPEL_BOOL);  // FC2 reg4
  names[5] = makeDynString("", "b568"); types[5] = makeDynInt(0, DPEL_BOOL);  // FC1 reg4

  DebugN("dpTypeCreate rc=", dpTypeCreate(names, types));

  string dpName = "dpdemo_mbprobe_1";
  DebugN("dpCreate rc=", dpCreate(dpName, dpt));

  // --- выдаём адреса ---
  // элемент 2: float, регистр 2, функциональный код 3, тип 566 (FLOAT)
  dpdSet(dpName + ".f566", "M.1.3.2", 566, driverNumber);
  // элемент 3: int, регистр 0, функциональный код 3, тип 561 (INT16)
  dpdSet(dpName + ".i561", "M.1.3.0", 561, driverNumber);
  // элемент 4: bool через функциональный код 2 (read input discrete), тип 567 (BIT)
  dpdSet(dpName + ".b567", "M.1.3.4", 567, driverNumber);
  // элемент 5: bool через функциональный код 3, тип 568 (BOOLEAN_AS_BYTE)
  dpdSet(dpName + ".b568", "M.1.3.4", 568, driverNumber);

  // --- читаем ---
  DebugN("--- ждём данные до 20 с ---");
  bool gotF = false, gotI = false, gotB4 = false, gotB5 = false;
  for (int i = 1; i <= 20; i++)
  {
    time t;
    dpGet(dpName + ".f566:_online.._stime", t);
    if (t != makeTime(1970, 1, 1, 3, 0, 0)) { gotF = true; }
    dpGet(dpName + ".i561:_online.._stime", t);
    if (t != makeTime(1970, 1, 1, 3, 0, 0)) { gotI = true; }
    dpGet(dpName + ".b567:_online.._stime", t);
    if (t != makeTime(1970, 1, 1, 3, 0, 0)) { gotB4 = true; }
    dpGet(dpName + ".b568:_online.._stime", t);
    if (t != makeTime(1970, 1, 1, 3, 0, 0)) { gotB5 = true; }
    if (gotF && gotI && gotB4 && gotB5) { break; }
    delay(1);
  }

  float fV;
  int iV;
  bool b4;
  bool b5;
  dpGet(dpName + ".f566:_online.._value", fV);
  dpGet(dpName + ".i561:_online.._value", iV);
  dpGet(dpName + ".b567:_online.._value", b4);
  dpGet(dpName + ".b568:_online.._value", b5);

  DebugN("--- РЕЗУЛЬТАТ ---");
  DebugN("  M.1.3.2  datatype 566 (FLOAT)      -> данные=", gotF, "  значение=", fV);
  DebugN("  M.1.3.0  datatype 561 (INT16)      -> данные=", gotI, "  значение=", iV);
  DebugN("  M.1.3.4  datatype 567 (BIT)        -> данные=", gotB4, "  значение=", b4);
  DebugN("  M.1.3.4  datatype 568 (BOOL_AS_BYTE)-> данные=", gotB5, "  значение=", b5);

  // Качество: у элементов без данных статус должен показывать ошибку
  for (int k = 2; k <= 5; k++)
  {
    string el = "";
    if (k == 2) { el = "f566"; }
    if (k == 3) { el = "i561"; }
    if (k == 4) { el = "b567"; }
    if (k == 5) { el = "b568"; }
    bool bad;
    dpGet(dpName + "." + el + ":_online.._bad", bad);
    DebugN("  ", el, ": _online.._bad = ", bad);
  }

  // --- уборка ---
  dyn_string left = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(left); i++) { dpDelete(left[i]); }
  dpTypeDelete(dpt);
  DebugN("=== конец ===");
}

void dpdSet(string dpe, string address, int datatype, int driverNumber)
{
  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", driverNumber);

  int rc = dpSetTimedWait(0,
                    dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                    dpe + ":_address.._reference", address,
                    dpe + ":_address.._active",    TRUE,
                    dpe + ":_address.._drv_ident", "MODBUS",
                    dpe + ":_address.._datatype",  datatype,
                    dpe + ":_address.._direction", DPATTR_ADDR_MODE_INPUT_POLL);

  string refGot;
  dpGet(dpe + ":_address.._reference", refGot);
  DebugN("  ", dpe, " rc=", rc, " reference='", refGot, "'");
}