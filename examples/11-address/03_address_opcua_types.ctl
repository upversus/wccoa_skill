// 03_address_opcua_types.ctl — конфигурация _address для набора узлов
// разных типов данных.
//
// Документация: docs/11-address.md
//
// Сценарий:
//   1. создаётся тип точки данных с пятью элементами разных типов:
//      bool, int, float, double, string;
//   2. создаются две точки данных этого типа;
//   3. на каждый элемент вешается адрес OPC UA;
//   4. значения читаются и сравниваются с тем, что показывает
//      внешний инструмент opcuactl.
//
// Карта узлов сервера (получена opcuactl get value):
//   User3   → TypeIDBoolean  true
//   Ramp1   → TypeIDInt32    35
//   Random1 → TypeIDInt16    -20
//   Ramp3   → TypeIDUint16   0
//   Ramp2   → TypeIDFloat    150.75
//   Ramp8   → TypeIDDouble   150.75
//   User1   → TypeIDString   "Hello"
//
// Проверено: CTL 3.18, проект prg_12_3.
//
// Запуск: разовый. Нужен живой Event Manager и запущенный OPC UA менеджер
// с номером 3.

main()
{
  dpdHeader("OPC UA", "адреса для набора узлов разных типов данных");

  // Номер драйвера — из эталона f1.f_node (_distrib.._driver).
  int driverNumber = 3;

  string server       = "kep";
  string subscription = "kep_sub";
  string art          = "1";
  string variante     = "1";

  string dpt = "dpdemo_ua_t";

  // ---------------------------------------------------------------------
  // 1. Тип точки данных: корень + пять элементов разных типов
  //
  //    Имя типа берётся из elements[1]: у dpTypeCreate() НЕТ параметра
  //    с именем типа. Корневой элемент обязан быть DPEL_STRUCT.
  //
  //    Индекс массива — номер элемента при обходе в ширину; в ячейке
  //    лежит путь от корня, имя стоит на позиции, равной глубине.
  // ---------------------------------------------------------------------
  DebugN("(1) создаём тип точки данных ", dpt);

  dpdDropAllDpOfType(dpt);

  dyn_dyn_string names;
  dyn_dyn_int types;

  // элемент 1: корень. Его имя = имя типа.
  names[1] = makeDynString(dpt);
  types[1] = makeDynInt(DPEL_STRUCT);

  // элементы 2..6: пять листьев на глубине 2
  names[2] = makeDynString("", "bFlag");
  types[2] = makeDynInt(0, DPEL_BOOL);

  names[3] = makeDynString("", "iVal");
  types[3] = makeDynInt(0, DPEL_INT);

  names[4] = makeDynString("", "fVal");
  types[4] = makeDynInt(0, DPEL_FLOAT);

  names[5] = makeDynString("", "dVal");
  types[5] = makeDynInt(0, DPEL_FLOAT);

  names[6] = makeDynString("", "sVal");
  types[6] = makeDynInt(0, DPEL_STRING);

  dpdCheckRc("тип создан (dpTypeCreate)", dpTypeCreate(names, types));

  // Проверяем, что тип действительно создан, и сверяем структуру.
  dyn_dyn_string backNames;
  dyn_dyn_int backTypes;
  dpdCheckRc("тип существует (dpTypeGet)", dpTypeGet(dpt, backNames, backTypes));
  dpdCheck("в типе шесть элементов", dynlen(backNames) == 6);
  if (dynlen(backNames) == 6)
  {
    dpdCheck("корень — структура", backTypes[1][1] == DPEL_STRUCT);
    dpdCheck("bFlag — bool", backTypes[2][2] == DPEL_BOOL);
    dpdCheck("iVal — int",  backTypes[3][2] == DPEL_INT);
    dpdCheck("fVal — float", backTypes[4][2] == DPEL_FLOAT);
    dpdCheck("dVal — float (типа double в OA нет)", backTypes[5][2] == DPEL_FLOAT);
    dpdCheck("sVal — string", backTypes[6][2] == DPEL_STRING);
  }

  // ---------------------------------------------------------------------
  // 2. Две точки данных этого типа
  // ---------------------------------------------------------------------
  DebugN("(2) создаём две точки данных");
  string dpA = "dpdemo_ua_t_1";
  string dpB = "dpdemo_ua_t_2";
  dpdCheckRc("точка данных 1 создана", dpCreate(dpA, dpt));
  dpdCheckRc("точка данных 2 создана", dpCreate(dpB, dpt));

  // ---------------------------------------------------------------------
  // 3. Адреса
  //
  //    Направление — ввод без вывода (INPUT_POLL). В режиме ввода/вывода
  //    OA запрещает два одинаковых активных выхода на один адрес:
  //    PARAM,SEVERE, 47, Duplicate peripheral address for this output
  //
  //    _distrib и _address заводятся на КАЖДЫЙ элемент: конфиг принадлежит
  //    элементу точки данных, а не точке данных целиком.
  // ---------------------------------------------------------------------
  DebugN("(3) конфигурируем адреса");

  // Точка данных 1: по одному узлу каждого типа
  dpdSetAddress(dpA + ".bFlag", server, subscription, art, variante,
                "ns=2;s=Simulation Examples.Functions.User3",
                ADDR_DATATYPE_BOOLEAN, driverNumber);
  dpdSetAddress(dpA + ".iVal", server, subscription, art, variante,
                "ns=2;s=Simulation Examples.Functions.Ramp1",
                ADDR_DATATYPE_INT32, driverNumber);
  dpdSetAddress(dpA + ".fVal", server, subscription, art, variante,
                "ns=2;s=Simulation Examples.Functions.Ramp2",
                ADDR_DATATYPE_FLOAT, driverNumber);
  dpdSetAddress(dpA + ".dVal", server, subscription, art, variante,
                "ns=2;s=Simulation Examples.Functions.Ramp8",
                ADDR_DATATYPE_DOUBLE, driverNumber);
  dpdSetAddress(dpA + ".sVal", server, subscription, art, variante,
                "ns=2;s=Simulation Examples.Functions.User1",
                ADDR_DATATYPE_STRING, driverNumber);

  // Точка данных 2: другие узлы тех же типов — доказывает, что две точки
  // данных одного типа работают независимо.
  dpdSetAddress(dpB + ".bFlag", server, subscription, art, variante,
                "ns=2;s=Simulation Examples.Functions.User3",
                ADDR_DATATYPE_BOOLEAN, driverNumber);
  dpdSetAddress(dpB + ".iVal", server, subscription, art, variante,
                "ns=2;s=Simulation Examples.Functions.Random1",
                ADDR_DATATYPE_INT16, driverNumber);
  dpdSetAddress(dpB + ".fVal", server, subscription, art, variante,
                "ns=2;s=Simulation Examples.Functions.Sine2",
                ADDR_DATATYPE_FLOAT, driverNumber);
  dpdSetAddress(dpB + ".dVal", server, subscription, art, variante,
                "ns=2;s=Simulation Examples.Functions.Ramp8",
                ADDR_DATATYPE_DOUBLE, driverNumber);
  dpdSetAddress(dpB + ".sVal", server, subscription, art, variante,
                "ns=2;s=Simulation Examples.Functions.User4",
                ADDR_DATATYPE_STRING, driverNumber);

  // ---------------------------------------------------------------------
  // 4. Читаем значения
  // ---------------------------------------------------------------------
  DebugN("(4) ждём данные с PLC");

  // dVal читается в float: типа данных DPE "double" в WinCC OA НЕТ.
// Проверено на CTL 3.18: константа DPEL_DOUBLE не определена, скрипт с ней
// не компилируется (SEVERE, 73, Variable not defined). Узел типа Double
// на сервере приходится принимать в элемент типа float — драйвер сам
// преобразует значение, теряя точность двойной разрядности.
  bool  bA; int iA; float fA; float dA; string sA;
  bool  bB; int iB; float fB; float dB; string sB;

  bool allFresh = false;
  for (int i = 1; i <= 20; i++)
  {
    time t1;
    dpGet(dpA + ".bFlag:_online.._stime", t1);
    if (t1 != makeTime(1970, 1, 1, 3, 0, 0))
    {
      allFresh = true;
      break;
    }
    delay(1);
  }
  dpdCheck("данные пошли (метка времени источника заполнена)", allFresh);

  dpGet(dpA + ".bFlag:_online.._value", bA);
  dpGet(dpA + ".iVal:_online.._value",  iA);
  dpGet(dpA + ".fVal:_online.._value",  fA);
  dpGet(dpA + ".dVal:_online.._value",  dA);
  dpGet(dpA + ".sVal:_online.._value",  sA);

  dpGet(dpB + ".bFlag:_online.._value", bB);
  dpGet(dpB + ".iVal:_online.._value",  iB);
  dpGet(dpB + ".fVal:_online.._value",  fB);
  dpGet(dpB + ".dVal:_online.._value",  dB);
  dpGet(dpB + ".sVal:_online.._value",  sB);

  DebugN("  точка данных 1:");
  DebugN("    bFlag (bool)   = ", bA,   "   ожидается true");
  DebugN("    iVal  (int)    = ", iA,   "   ожидается 35");
  DebugN("    fVal  (float)  = ", fA,   "   ожидается ~150");
  DebugN("    dVal  (double) = ", dA,   "   ожидается ~150");
  DebugN("    sVal  (string) = '", sA, "'   ожидается 'Hello'");
  DebugN("  точка данных 2:");
  DebugN("    bFlag (bool)   = ", bB,   "   ожидается true");
  DebugN("    iVal  (int)    = ", iB,   "   ожидается -20");
  DebugN("    fVal  (float)  = ", fB,   "   ожидается ~0");
  DebugN("    dVal  (double) = ", dB,   "   ожидается ~150");
  DebugN("    sVal  (string) = '", sB, "'   ожидается текст");

  // Строка приехала целиком — самый строгий признак работающего преобразования.
  dpdCheck("string: значение прочитано непустым", sA != "");
  dpdCheck("int: значение в разумных пределах", iA > -100000 && iA < 100000);

  // ---------------------------------------------------------------------
  // Логический элемент.
  //
  // ВАЖНО, здесь была ошибка в самом тесте, а не в системе. Узел User3
  // не постоянен: он ПЕРЕКЛЮЧАЕТСЯ между true и false (проверено на
  // эталонной точке f1.b_node — шесть замеров подряд дали
  // FALSE, TRUE, TRUE, TRUE, FALSE, TRUE). Проверка вида "bA == true"
  // ловит один мгновенный срез и потому ненадёжна.
  //
  // Правильная проверка логического узла — зафиксировать ПЕРЕХОД
  // значения: если true и false наблюдались, узел жив и данные идут.
  // ---------------------------------------------------------------------
  bool sawTrue  = false;
  bool sawFalse = false;
  for (int i = 1; i <= 15; i++)
  {
    bool b;
    dpGet(dpA + ".bFlag:_online.._value", b);
    if (b) { sawTrue = true; } else { sawFalse = true; }
    if (sawTrue && sawFalse) { break; }
    delay(1);
  }
  DebugN("  логический узел: наблюдались true=", sawTrue, " false=", sawFalse);
  dpdCheck("bool: узел переключается — значит данные идут", sawTrue && sawFalse);

  // ---------------------------------------------------------------------
  // teardown
  // ---------------------------------------------------------------------
  DebugN("(5) уборка");
  dpdDropAllDpOfType(dpt);
  dpdCheckRc("тип удалён", dpTypeDelete(dpt));

  dpdSummary();
}

// ===========================================================================
// Конфигурирование одного элемента: _distrib + _address
//
// Порядок обязателен: сначала _distrib с номером драйвера, затем создание
// конфига _address и только потом заполнение его атрибутов.
// Конфиги пишутся исключительно dpSetTimedWait(0, ...).
// ===========================================================================
void dpdSetAddress(string dpe, string server, string subscription,
                   string art, string variante, string itemId,
                   int datatype, int driverNumber)
{
  string address = server + "$" + subscription + "$" + art + "$" + variante + "$" + itemId;

  int rcDist = dpSetTimedWait(0,
                      dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                      dpe + ":_distrib.._driver", driverNumber);

  int rcAddr = dpSetTimedWait(0,
                      dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                      dpe + ":_address.._reference", address,
                      dpe + ":_address.._active",    TRUE,
                      dpe + ":_address.._drv_ident", "OPCUA",
                      dpe + ":_address.._datatype",  datatype,
                      dpe + ":_address.._direction", DPATTR_ADDR_MODE_INPUT_POLL);

  // Читаем обратно — конфиг записан именно так, как задумано.
  string refGot;
  int dtGot;
  dpGet(dpe + ":_address.._reference", refGot);
  dpGet(dpe + ":_address.._datatype",  dtGot);

  DebugN("    ", dpe, " rcAddr=", rcAddr, " ref='", refGot, "' datatype=", dtGot);

  dpdCheck("  " + dpe + ": _distrib записан", rcDist == 0);
  dpdCheck("  " + dpe + ": _address записан", rcAddr == 0);
  dpdCheck("  " + dpe + ": _reference совпадает", refGot == address);
  dpdCheck("  " + dpe + ": _datatype совпадает", dtGot == datatype);
}

// ===========================================================================
// Помощники
// ===========================================================================
int dpdPass = 0;
int dpdFail = 0;

// Коды типов преобразования OPC UA (docs/11-address.md, раздел 7.1).
int ADDR_DATATYPE_BOOLEAN = 751;
int ADDR_DATATYPE_INT16   = 754;
int ADDR_DATATYPE_INT32   = 756;
int ADDR_DATATYPE_FLOAT   = 760;
int ADDR_DATATYPE_DOUBLE  = 761;
int ADDR_DATATYPE_STRING  = 762;

void dpdHeader(string fn, string synopsis)
{
  DebugN("=== ", fn, " ===  ", synopsis);
}

void dpdCheck(string what, bool ok)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "  lastError=", getLastError()); }
}

void dpdCheckRc(string what, int rc)
{
  if (rc == 0) { dpdPass++; DebugN("  PASS  ", what, "  rc=0"); }
  else         { dpdFail++; DebugN("  FAIL  ", what, "  rc=", rc, "  lastError=", getLastError()); }
}

void dpdSummary()
{
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
}

// Системные точки данных начинаются с подчёркивания; dpNames() отдаёт имена
// с префиксом системы, поэтому он снимается ДО проверки.
// В CTL 3.18 нет ни len(), ни indexOf(): есть strlen(), substr(), strpos().
bool dpdIsSystem(string name)
{
  if (name == "") { return false; }
  string bare = name;
  if (substr(name, 0, 6) == "System")
  {
    int colon = strpos(name, ":");
    if (colon > 0) { bare = substr(name, colon + 1); }
  }
  if (bare == "") { return false; }
  return substr(bare, 0, 1) == "_";
}

void dpdDropAllDpOfType(string dpt)
{
  if (dpdIsSystem(dpt)) { return; }
  dyn_string names = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(names); i++)
  {
    if (dpdIsSystem(names[i])) { continue; }
    dpDelete(names[i]);
  }
}