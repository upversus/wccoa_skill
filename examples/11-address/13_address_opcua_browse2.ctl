// 13_address_opcua_browse2.ctl - разбор Browse Path на одном элементе.
//
// В журнале драйвера путь /2:Simulation Examples/2:Functions/2:User3 получил
// статус Good, но в предыдущем прогоне данные не пришли. Возможных причин
// две: элемент проверялся слишком рано, либо подписка уже была активна и
// новый элемент в неё не попал.
//
// Проверяем один элемент, ждём 60 с, смотрим и значение, и признак bad.
//
// Проверено: CTL 3.18, проект prg_12_3.

main()
{
  DebugN("=== Browse Path: один элемент, ожидание 60 с ===");

  int driverNumber = 3;
  string dpt = "opcB2_t";
  string dp  = "opcB2";

  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);        types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "e");    types[2] = makeDynInt(0, DPEL_BOOL);

  cleanUp(dp, dpt);
  DebugN("  тип rc=", dpTypeCreate(names, types), ", точка rc=", dpCreate(dp, dpt));

  // Путь, получивший Good в журнале
  setAddr(dp + ".e", "kep$kep_sub$1$2$/2:Simulation Examples/2:Functions/2:User3");

  DebugN("");
  for (int i = 1; i <= 10; i++)
  {
    delay(6);
    DebugN("  +", i * 6, " с: ", state(dp + ".e"));
    if (hasData(dp + ".e")) { break; }
  }

  DebugN("");
  DebugN("=== итог ===");
  DebugN("  ", hasData(dp + ".e") ? "ДАННЫЕ ПРИШЛИ" : "данных нет");

  DebugN("");
  DebugN("=== конец ===");
}

string state(string dpe)
{
  bool bad;
  time t;
  dyn_anytype v;
  dpGet(dpe + ":_online.._bad",   bad);
  dpGet(dpe + ":_online.._stime", t);
  dpGet(dpe + ":_online.._value", v);
  if (t == makeTime(1970, 1, 1, 3, 0, 0)) { return "данных нет"; }
  if (bad) { return "bad = TRUE, значение = " + v; }
  return "ДАННЫЕ = " + v;
}

bool hasData(string dpe)
{
  bool bad;
  time t;
  dpGet(dpe + ":_online.._bad",   bad);
  dpGet(dpe + ":_online.._stime", t);
  return (t != makeTime(1970, 1, 1, 3, 0, 0)) && (!bad);
}

void setAddr(string dpe, string address)
{
  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", 3);
  int rc = dpSetTimedWait(0,
                    dpe + ":_address.._type",       DPCONFIG_PERIPH_ADDR_MAIN,
                    dpe + ":_address.._reference",  address,
                    dpe + ":_address.._active",     TRUE,
                    dpe + ":_address.._drv_ident",  "OPCUA",
                    dpe + ":_address.._datatype",   751,
                    dpe + ":_address.._direction",  DPATTR_ADDR_MODE_INPUT_SPONT);
  string got;
  dpGet(dpe + ":_address.._reference", got);
  DebugN("  адрес записан rc=", rc, ": ", got);
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