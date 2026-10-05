// 11_address_opcua_fields.ctl - проверка полей Kind и Variant в _reference.
//
// Схема из документации драйвера OPC UA:
//     Server$Subscription$Kind$Variant$[numeric range]Item
//
//   поле 1 Server       имя точки типа _OPCUAServer без подчёркивания
//   поле 2 Subscription имя точки типа _OPCUASubscription без подчёркивания
//   поле 3 Kind         данные / события / тревоги. В панели НЕ настраивается,
//                       выводится из типа подписки. В проекте 1.
//   поле 4 Variant      1 = NodeId, 2 = Browse Path
//   поле 5 Item         сам NodeId или Browse Path
//
// Пример из документации: UASERVER1$Subscription1$1$1$ns=2;s=System.Pumpe1
//
// Если подписка не используется (режим опроса), адрес имеет вид
// Server$$Variant$Item - поле Subscription пустое, Kind отсутствует.
//
// Проверяем три формы на живом сервере:
//     A  обычная, с подпиской и NodeId       (должна работать)
//     B  Variant = 2, Browse Path             (проверяем)
//     C  без подписки, режим опроса           (проверяем)
//
// Проверено: CTL 3.18, проект <проект стенда>.


// Счётчики самопроверки. Должны быть в глобальной области: helpers ниже
// обращаются к ним, а локальные переменные main() им не видны.
int dpdPass = 0;
int dpdFail = 0;

main()
{
  DebugN("=== Поля Kind и Variant в строке адреса OPC UA ===");

  int driverNumber = 3;
  string dpt = "opcFields_t";
  string dp  = "opcFields";

  // ---- свои объекты ----
  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);          types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "aNodeId"); types[2] = makeDynInt(0, DPEL_BOOL);
  names[3] = makeDynString("", "bBrowse");  types[3] = makeDynInt(0, DPEL_BOOL);
  names[4] = makeDynString("", "cPoll");    types[4] = makeDynInt(0, DPEL_BOOL);

  cleanUp(dp, dpt);
  int rcT = dpTypeCreate(names, types);
  int rcD = dpCreate(dp, dpt);
  DebugN("  тип rc=", rcT, ", точка rc=", rcD);
  DebugN("");

  // A: обычная форма - подписка, Kind 1, Variant 1 (NodeId)
  DebugN("--- A: kep$kep_sub$1$1$<NodeId> ---");
  setAddr(dp + ".aNodeId", "kep$kep_sub$1$1$ns=2;s=Simulation Examples.Functions.User3",
          751, DPATTR_ADDR_MODE_INPUT_SPONT);

  // B: Variant 2 - Browse Path вместо NodeId
  DebugN("--- B: kep$kep_sub$1$2$<BrowsePath> ---");
  setAddr(dp + ".bBrowse", "kep$kep_sub$1$2$/2:Simulation Examples/2:Functions/2:User3",
          751, DPATTR_ADDR_MODE_INPUT_SPONT);

  // C: без подписки, режим опроса - поле Kind отсутствует
  DebugN("--- C: kep$$1$<NodeId> ---");
  setAddr(dp + ".cPoll", "kep$$1$ns=2;s=Simulation Examples.Functions.User3",
          751, DPATTR_ADDR_MODE_INPUT_POLL);

  // ---- данные ----
  DebugN("");
  DebugN("ждём 25 с...");
  delay(25);

  DebugN("");
  DebugN("--- результат ---");
  check(dp + ".aNodeId", "A  подписка + NodeId  ");
  check(dp + ".bBrowse", "B  подписка + Browse   ");
  check(dp + ".cPoll",   "C  опрос, без подписки ");

  DebugN("");
  dpdSummary();
  DebugN("=== конец ===");
}

// ============================================================ helpers

void check(string dpe, string what)
{
  bool bad;
  time t;
  dyn_anytype v;
  dpGet(dpe + ":_online.._bad",   bad);
  dpGet(dpe + ":_online.._stime", t);
  dpGet(dpe + ":_online.._value", v);
  bool hasData = (t != makeTime(1970, 1, 1, 3, 0, 0));

  if (hasData && !bad) { dpdPass++; } else { dpdFail++; }
  DebugN("  ", (hasData && !bad) ? "данные" : "НЕТ   ", "  ", what,
         "  = ", v);
}

// Сводка нужна verify.ps1: без неё пример не оценивается.
void dpdSummary()
{
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
}

void setAddr(string dpe, string address, int datatype, int direction)
{
  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", 3);
  int rc = dpSetTimedWait(0,
                    dpe + ":_address.._type",       DPCONFIG_PERIPH_ADDR_MAIN,
                    dpe + ":_address.._reference",  address,
                    dpe + ":_address.._active",     TRUE,
                    dpe + ":_address.._drv_ident",  "OPCUA",
                    dpe + ":_address.._datatype",   datatype,
                    dpe + ":_address.._direction",  direction);

  string got;
  dpGet(dpe + ":_address.._reference", got);
  DebugN("  ", (rc == 0 && got == address) ? "записан" : "ОШИБКА", " -> ", got);
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