// 12_address_opcua_browse.ctl - подбор правильного Browse Path.
//
// Вариант 2 в поле Variant работает: драйвер вызывает
// translateBrowsePathToNodeId и сообщает BadNoMatch на неверный путь.
// Значит проверяем форму пути, а не схему.
//
// Узел имеет NodeId ns=2;s=Simulation Examples.Functions.User3 - это один
// элемент с точками внутри имени, поэтому путь может состоять из одного
// сегмента. Проверяем четыре кандидата плюс контрольный вариант с NodeId.
//
// Проверено: CTL 3.18, проект prg_12_3.

main()
{
  DebugN("=== Подбор Browse Path (Variant 2) ===");

  int driverNumber = 3;
  string dpt = "opcBrowse_t";
  string dp  = "opcBrowse";

  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);                       types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "ctl");   types[2] = makeDynInt(0, DPEL_BOOL);  // контроль, NodeId
  names[3] = makeDynString("", "one");   types[3] = makeDynInt(0, DPEL_BOOL);
  names[4] = makeDynString("", "oneNs1");types[4] = makeDynInt(0, DPEL_BOOL);
  names[5] = makeDynString("", "three"); types[5] = makeDynInt(0, DPEL_BOOL);
  names[6] = makeDynString("", "absNs");  types[6] = makeDynInt(0, DPEL_BOOL);

  cleanUp(dp, dpt);
  DebugN("  тип rc=", dpTypeCreate(names, types), ", точка rc=", dpCreate(dp, dpt));
  DebugN("");

  DebugN("--- кандидаты ---");
  // контрольный вариант: Variant 1, NodeId
  setAddr(dp + ".ctl",   "kep$kep_sub$1$1$ns=2;s=Simulation Examples.Functions.User3");
  // один сегмент с точками внутри имени, ns=2
  setAddr(dp + ".one",   "kep$kep_sub$1$2$/2:Simulation Examples.Functions.User3");
  // один сегмент, ns=1
  setAddr(dp + ".oneNs1","kep$kep_sub$1$2$/1:Simulation Examples.Functions.User3");
  // три сегмента, как пробовали раньше
  setAddr(dp + ".three", "kep$kep_sub$1$2$/2:Simulation Examples/2:Functions/2:User3");
  // без ведущего слэша
  setAddr(dp + ".absNs", "kep$kep_sub$1$2$2:Simulation Examples.Functions.User3");

  DebugN("");
  DebugN("ждём 30 с...");
  delay(30);

  DebugN("");
  DebugN("--- результат ---");
  check(dp + ".ctl",    "контроль NodeId          ");
  check(dp + ".one",    "один сегмент ns=2, слэш ");
  check(dp + ".oneNs1", "один сегмент ns=1, слэш ");
  check(dp + ".three",  "три сегмента ns=2        ");
  check(dp + ".absNs",  "без ведущего слэша      ");

  DebugN("");
  DebugN("=== конец ===");
}

void check(string dpe, string what)
{
  bool bad;
  time t;
  dyn_anytype v;
  dpGet(dpe + ":_online.._bad",   bad);
  dpGet(dpe + ":_online.._stime", t);
  dpGet(dpe + ":_online.._value", v);
  bool hasData = (t != makeTime(1970, 1, 1, 3, 0, 0));
  DebugN("  ", (hasData && !bad) ? "данные" : "НЕТ   ", "  ", what, "  = ", v);
}

void setAddr(string dpe, string address)
{
  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", 3);
  dpSetTimedWait(0,
                    dpe + ":_address.._type",       DPCONFIG_PERIPH_ADDR_MAIN,
                    dpe + ":_address.._reference",  address,
                    dpe + ":_address.._active",     TRUE,
                    dpe + ":_address.._drv_ident",  "OPCUA",
                    dpe + ":_address.._datatype",   751,
                    dpe + ":_address.._direction",  DPATTR_ADDR_MODE_INPUT_SPONT);
  string got;
  dpGet(dpe + ":_address.._reference", got);
  DebugN("  ", got);
}

void cleanUp(string dp, string dpt)
{
  if (dpExists(dp)) { dpDelete(dp); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(dp)) { break; }
    delay(1);
  }
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    dyn_dyn_string pn;
    dyn_dyn_int pt;
    if (dpTypeGet(dpt, pn, pt) != 0) { break; }
    dpTypeDelete(dpt);
    delay(1);
  }
}