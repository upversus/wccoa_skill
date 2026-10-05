// СГЕНЕРИРОВАНО АВТОМАТИЧЕСКИ: tools/gen-opcua-dp.js
// Карта    : accept.csv
// Сервер  : opc.tcp://192.168.0.107:49320
// Драйвер : 3
//
// Не правь руками: файл перезаписывается при следующей генерации.
// Правь карту и запускай генератор заново.
//
// Карта элементов:
//   точка ACCEPT, тип accept_t
//     ns=2;s=Data Type Examples.8 Bit Device.K Registers.Boolean1 751  Boolean    DPEL_BOOL      dir 7  K_Registers_Boolean1
//     ns=2;s=Data Type Examples.8 Bit Device.K Registers.Byte1   753  Byte       DPEL_UINT      dir 7  K_Registers_Byte1
//     ns=2;s=Data Type Examples.8 Bit Device.K Registers.Char1   752  SByte      DPEL_INT       dir 7  K_Registers_Char1
//     ns=2;s=Data Type Examples.8 Bit Device.K Registers.Short1  754  Int16      DPEL_INT       dir 7  K_Registers_Short1
//     ns=2;s=Data Type Examples.8 Bit Device.K Registers.Word1   755  UInt16     DPEL_UINT      dir 7  K_Registers_Word1
//     ns=2;s=Data Type Examples.8 Bit Device.K Registers.Long1   756  Int32      DPEL_INT       dir 7  K_Registers_Long1
//     ns=2;s=Data Type Examples.8 Bit Device.K Registers.DWord1  757  UInt32     DPEL_UINT      dir 7  K_Registers_DWord1
//     ns=2;s=Data Type Examples.8 Bit Device.K Registers.LLong1  758  Int64      DPEL_LONG      dir 7  K_Registers_LLong1
//     ns=2;s=Data Type Examples.8 Bit Device.K Registers.QWord1  759  UInt64     DPEL_ULONG     dir 7  K_Registers_QWord1
//     ns=2;s=Data Type Examples.8 Bit Device.K Registers.Float1  760  Float      DPEL_FLOAT     dir 7  K_Registers_Float1
//     ns=2;s=Data Type Examples.8 Bit Device.K Registers.Double1 761  Double     DPEL_FLOAT     dir 7  K_Registers_Double1
//     ns=2;s=Data Type Examples.8 Bit Device.S Registers.String1 762  String     DPEL_STRING    dir 7  S_Registers_String1

int dpdPass = 0;
int dpdFail = 0;
int elemCount = 0;

const int DRV = 3;

// Коды преобразований OPC UA, полный список 19 значений.
// Источник: scripts/libs/examples/opcuaImportExample.ctl, OPCUATransformation.
int ADDR_DATATYPE_BOOLEAN = 751;
int ADDR_DATATYPE_INT16   = 754;
int ADDR_DATATYPE_UINT16  = 755;
int ADDR_DATATYPE_INT32   = 756;
int ADDR_DATATYPE_UINT32  = 757;
int ADDR_DATATYPE_INT64   = 758;
int ADDR_DATATYPE_UINT64  = 759;
int ADDR_DATATYPE_FLOAT   = 760;
int ADDR_DATATYPE_DOUBLE  = 761;
int ADDR_DATATYPE_STRING  = 762;

main()
{
  DebugN("=== OPC UA: точка по карте ===");

  // Сервер и подписка находятся в проекте по ТИПУ. Имя в адресе
  // пишется без ведущего подчёркивания: точка _opc_ua_con даёт
  // в адресе opc_ua_con.
  string serverName = findByType("_OPCUAServer");
  string subName    = findByType("_OPCUASubscription");
  DebugN("  сервер   = '" + serverName + "'");
  DebugN("  подписка = '" + subName + "'");
  if (serverName == "" ) { chk(FALSE, "найдена точка типа _OPCUAServer", "");        return; }
  if (subName    == "" ) { chk(FALSE, "найдена точка типа _OPCUASubscription", ""); return; }

  string prefix = serverName + "$" + subName + "$1$1$";
  DebugN("  префикс  = ", prefix);

  killDP("ACCEPT", "accept_t");

  dyn_dyn_string names;
  dyn_dyn_int    types;
  names[1] = makeDynString("accept_t");
  types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "K_Registers_Boolean1");
  types[2] = makeDynInt(0, DPEL_BOOL);
  names[3] = makeDynString("", "K_Registers_Byte1");
  types[3] = makeDynInt(0, DPEL_UINT);
  names[4] = makeDynString("", "K_Registers_Char1");
  types[4] = makeDynInt(0, DPEL_INT);
  names[5] = makeDynString("", "K_Registers_Short1");
  types[5] = makeDynInt(0, DPEL_INT);
  names[6] = makeDynString("", "K_Registers_Word1");
  types[6] = makeDynInt(0, DPEL_UINT);
  names[7] = makeDynString("", "K_Registers_Long1");
  types[7] = makeDynInt(0, DPEL_INT);
  names[8] = makeDynString("", "K_Registers_DWord1");
  types[8] = makeDynInt(0, DPEL_UINT);
  names[9] = makeDynString("", "K_Registers_LLong1");
  types[9] = makeDynInt(0, DPEL_LONG);
  names[10] = makeDynString("", "K_Registers_QWord1");
  types[10] = makeDynInt(0, DPEL_ULONG);
  names[11] = makeDynString("", "K_Registers_Float1");
  types[11] = makeDynInt(0, DPEL_FLOAT);
  names[12] = makeDynString("", "K_Registers_Double1");
  types[12] = makeDynInt(0, DPEL_FLOAT);
  names[13] = makeDynString("", "S_Registers_String1");
  types[13] = makeDynInt(0, DPEL_STRING);
  chk(dpTypeCreate(names, types) == 0, "accept_t: тип создан, элементов 12", "");

  chk(dpCreate("ACCEPT", "accept_t") == 0, "ACCEPT: точка создана", "");

  DebugN("  -- адреса --");
  cfg("ACCEPT", "K_Registers_Boolean1", prefix + "ns=2;s=Data Type Examples.8 Bit Device.K Registers.Boolean1", 751, 7);
  cfg("ACCEPT", "K_Registers_Byte1", prefix + "ns=2;s=Data Type Examples.8 Bit Device.K Registers.Byte1", 753, 7);
  cfg("ACCEPT", "K_Registers_Char1", prefix + "ns=2;s=Data Type Examples.8 Bit Device.K Registers.Char1", 752, 7);
  cfg("ACCEPT", "K_Registers_Short1", prefix + "ns=2;s=Data Type Examples.8 Bit Device.K Registers.Short1", 754, 7);
  cfg("ACCEPT", "K_Registers_Word1", prefix + "ns=2;s=Data Type Examples.8 Bit Device.K Registers.Word1", 755, 7);
  cfg("ACCEPT", "K_Registers_Long1", prefix + "ns=2;s=Data Type Examples.8 Bit Device.K Registers.Long1", 756, 7);
  cfg("ACCEPT", "K_Registers_DWord1", prefix + "ns=2;s=Data Type Examples.8 Bit Device.K Registers.DWord1", 757, 7);
  cfg("ACCEPT", "K_Registers_LLong1", prefix + "ns=2;s=Data Type Examples.8 Bit Device.K Registers.LLong1", 758, 7);
  cfg("ACCEPT", "K_Registers_QWord1", prefix + "ns=2;s=Data Type Examples.8 Bit Device.K Registers.QWord1", 759, 7);
  cfg("ACCEPT", "K_Registers_Float1", prefix + "ns=2;s=Data Type Examples.8 Bit Device.K Registers.Float1", 760, 7);
  cfg("ACCEPT", "K_Registers_Double1", prefix + "ns=2;s=Data Type Examples.8 Bit Device.K Registers.Double1", 761, 7);
  cfg("ACCEPT", "S_Registers_String1", prefix + "ns=2;s=Data Type Examples.8 Bit Device.S Registers.String1", 762, 7);
  elemCount += 12;

  // ------------------------- проверка данных -------------------------
  DebugN("=== ждём данные ===");
  for (int i = 1; i <= 40; i++) { if (allFresh()) { break; } delay(1); }

  dyn_string names = allElems("ACCEPT");
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

  // Меняться обязаны не все: по карте есть константы и строки.
  DebugN("  изменилось " + live + " из " + nAll);

  DebugN("");
  DebugN("PASS=", dpdPass, "  FAIL=", dpdFail);
  DebugN("=== конец ===");
}

// Привязка. Рецепт проверен на CTL 3.18, порядок атрибутов важен.
// Без _distrib драйвер не считает точку своей и молчит без ошибок.
void cfg(string dp, string el, string nodeId, int datatype, int direction)
{
  string dpe = dp + "." + el;
  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", DRV);
  int rc = dpSetTimedWait(0,
                    dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                    dpe + ":_address.._reference", nodeId,
                    dpe + ":_address.._active",    TRUE,
                    dpe + ":_address.._drv_ident", "OPCUA",
                    dpe + ":_address.._datatype",  datatype,
                    dpe + ":_address.._direction", direction);
  string got;
  dpGet(dpe + ":_address.._reference", got);
  chk((rc == 0) && (got == nodeId), dp + "." + el, "rc=" + rc + " got='" + got + "'");
}

// dpNames() отбирает по ИМЕНИ, а не по типу, поэтому шаблон
// "*_OPCUAServer" не годится. Перебираем всё и проверяем dpTypeName.
string findByType(string want)
{
  dyn_string all = dpNames("**");
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpTypeName(all[i] + ".") != want) { continue; }
    int pos = strpos(all[i], "_");
    if (pos < 0) { return all[i]; }
    return substr(all[i], pos + 1, 200);
  }
  return "";
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
dyn_string allElems(string dp)
{
  dyn_string res = makeDynString();
  string tpn = dpTypeName(dp + ".");
  dyn_dyn_string nm; dyn_dyn_int ty;
  if (dpTypeGet(tpn, nm, ty) != 0) { return res; }
  for (int k = 2; k <= dynlen(nm); k++)
  { res[dynlen(res) + 1] = dp + "." + nm[k][dynlen(nm[k])]; }
  return res;
}

bool allFresh()
{
  dyn_string all = allElems("ACCEPT");
  if (dynlen(all) == 0) { return false; }
  for (int i = 1; i <= dynlen(all); i++)
  {
    time t; dpGet(all[i] + ":_online.._stime", t);
    if (t == makeTime(1970, 1, 1, 3, 0, 0)) { return false; }
  }
  return true;
}

void chk(bool ok, string what, string extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra); }
}
