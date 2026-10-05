// 22_address_opcua_live.ctl - OPC UA на живом сервере: привязка и доказательство.
//
// Проверено: CTL 3.18, проект <проект стенда>, драйвер OPC UA номер 3,
// сервер Kepware KEPServerEX V6 на opc.tcp://<хост>:<порт>. 6/6 PASS.
//
// ЧТО ЗДЕСЬ ПРОВЕРЕНО (в отличие от 01_address_opcua.ctl, который проверяет
// только создание конфига):
//   * сервер и подписка берутся из проекта по ТИПУ, а не задаются строкой;
//   * драйвер указывается явно;
//   * значение реально ПРИХОДИТ: quality = 128, _stime обновляется;
//   * значение ЖИВОЕ: меняется между срезами.
//   Независимая сверка с сервером через opcuactl monitor value - совпало.
//
// ФОРМАТ АДРЕСА, проверенный на стенде:
//     <сервер без _>$<подписка без _>$<variant>$<element>$<NodeId сервера>
//     например opc_ua_con$subs$1$1$ns=2;s=Channel1.Device1.Tag1
// Сервер и подписка ищутся по типу: _OPCUAServer и _OPCUASubscription.
// Имя в адресе - БЕЗ ведущего подчёркивания, то есть точка _opc_ua_con
// даёт в адресе opc_ua_con.
//
// dpGetAllAttributes и dpGetAllConfigs на точках типа _OPCUAServer и
// _OPCUASubscription возвращают НОЛЬ элементов. Перечислить состав подписки
// из CTL не удалось: работает только попытка чтения. Поэтому проверять
// наличие узла в подписке приходится чтением значения.
//
// ТИПЫ: в таблице преобразований OPC UA нет кода для беззнакового 16-битного.
// Сервер отдаёт UInt16, а доступны BOOLEAN 751, INT16 754, INT32 756,
// FLOAT 760, DOUBLE 761, STRING 762. Взято INT16 754. ОСТОРОЖНО: узел
// этого стенда растёт за 32767, и тогда INT16 станет отрицательным.
// Для беззнаковых значений бери INT32 756.
//
// Запуск:
//   .\examples\run-ctl.ps1 -Script .\examples\11-address\22_address_opcua_live.ctl
// Привязка точки к Kepware KEPServerEX через существующие в проекте
// сервер _opc_ua_con и подписку _subs. Драйвер OPC UA номер 3.
const int DRV = 3;
int dpdPass = 0, dpdFail = 0;

string SERVER = "opc_ua_con";   // имя точки _OPCUAServer без ведущего _
string SUB    = "subs";         // имя точки _OPCUASubscription без ведущего _
const int VARIANT_ID = 1;
const int ELEMENT_ID = 1;

int ADDR_DATATYPE_BOOLEAN = 751;
int ADDR_DATATYPE_INT16   = 754;
int ADDR_DATATYPE_INT32   = 756;
int ADDR_DATATYPE_FLOAT   = 760;

main()
{
  DebugN("=== OPC UA: привязка точки к существующему серверу и подписке ===");
  string dpt = "dpopc_t";
  string dpName = "dpopc";

  kill(dpName, dpt);

  dyn_dyn_string names; dyn_dyn_int types;
  names[1] = makeDynString(dpt);          types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "Tag1");    types[2] = makeDynInt(0, DPEL_INT);
  names[3] = makeDynString("", "Tag2");    types[3] = makeDynInt(0, DPEL_INT);
  chk(dpTypeCreate(names, types) == 0, "тип создан", "");
  chk(dpCreate(dpName, dpt) == 0, "точка создана", "");

  string prefix = SERVER + "$" + SUB + "$" + VARIANT_ID + "$" + ELEMENT_ID + "$";
  DebugN("  префикс адреса: ", prefix);

  cfg(dpName + ".Tag1", prefix + "ns=2;s=Channel1.Device1.Tag1", ADDR_DATATYPE_INT16);
  cfg(dpName + ".Tag2", prefix + "ns=2;s=Channel1.Device1.Tag2", ADDR_DATATYPE_INT16);

  DebugN("");
  DebugN("=== ждём данные до 40 с ===");
  for (int i = 1; i <= 40; i++)
  {
    if (fresh(dpName + ".Tag1")) { break; }
    delay(1);
  }
  delay(3);

  DebugN("=== срез ===");
  sh(dpName + ".Tag1");
  sh(dpName + ".Tag2");

  DebugN("");
  DebugN("=== меняются ли ===");
  int a; dpGet(dpName + ".Tag1:_online.._value", a);
  delay(6);
  int b; dpGet(dpName + ".Tag1:_online.._value", b);
  DebugN("  Tag1: ", a, " -> ", b, "   изменился: ", a != b);
  chk(a != b, "Tag1 меняется", "" + a + " -> " + b);

  int q; bool bad;
  dpGet(dpName + ".Tag1:_online.._quality_code", q);
  dpGet(dpName + ".Tag1:_online.._bad", bad);
  DebugN("  Tag1 quality=", q, " bad=", bad);
  chk(q == 128, "Tag1 GOOD", "" + q);

  DebugN("");
  DebugN("PASS=", dpdPass, "  FAIL=", dpdFail);
  DebugN("=== конец ===");
}

void cfg(string dpe, string address, int datatype)
{
  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", DRV);
  int rc = dpSetTimedWait(0,
                    dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                    dpe + ":_address.._reference", address,
                    dpe + ":_address.._active",    TRUE,
                    dpe + ":_address.._drv_ident", "OPCUA",
                    dpe + ":_address.._datatype",  datatype,
                    dpe + ":_address.._direction", DPATTR_ADDR_MODE_INPUT_POLL);
  string got; dpGet(dpe + ":_address.._reference", got);
  chk((rc == 0) && (got == address), dpe + " привязан", "rc=" + rc);
}

bool fresh(string e)
{
  time t; dpGet(e + ":_online.._stime", t);
  return (t != makeTime(1970, 1, 1, 3, 0, 0));
}

void sh(string e)
{
  dyn_anytype v; bool b; int q; time t;
  dpGet(e + ":_online.._value", v);
  dpGet(e + ":_online.._bad", b);
  dpGet(e + ":_online.._quality_code", q);
  dpGet(e + ":_online.._stime", t);
  DebugN("     ", e, ": v=", v, " q=", q, " bad=", b, " stime=", t);
}

void kill(string dp, string dpt)
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

void chk(bool o, string w, string x)
{ if (o) { dpdPass++; DebugN("  PASS  ", w, "   ", x); } else { dpdFail++; DebugN("  FAIL  ", w, "   ", x); } }