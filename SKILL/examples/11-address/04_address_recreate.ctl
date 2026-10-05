// 04_address_recreate.ctl — создание точки данных с нуля и проверка получения
// данных по OPC UA.
//
// Документация: docs/11-address.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Пример самодостаточен и повторяем:
//
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа;
//      если проверяем конфигурацию адреса — навешиваем _address;
//   3) удаляем и точку данных, и тип.
//
// Никаких зависимостей от чужих объектов. Тип и точка создаются и удаляются
// самим скриптом.
//
// Предыдущая версия этого примера была одноразовой и не соответствовала
// протоколу: она требовала заранее существующих тип for_test_OPCUA и точки f1,
// удаляла f1 и не восстанавливала её. Из-за этого второй прогон давал 2/19.
// Побочный эффект: эталонная точка f1, на которую ссылается docs/11-address.md,
// была потеряна. Сейчас пример ничего чужого не трогает, а про f1 только
// сообщает.
//
// Заодно проверяется, влияет ли на приём значения режим направления:
// на ОДНОМ узле User3 создаются два логических элемента —
// b_node_spont в режиме IO_SPONT и b_node_poll в режиме INPUT_POLL.
//
// Проверено: CTL 3.18, проект <проект стенда>.
// Нужен живой Event Manager и запущенный OPC UA менеджер с номером 3.

int dpdPass = 0;
int dpdFail = 0;

string DPT   = "dpdemo_recreate_t";
string DP    = "dpdemo_recreated";

string server       = "kep";
string subscription = "kep_sub";
string art          = "1";
string variante     = "1";
int    driverNumber = 3;

// Те же узлы, что использовались на эталоне.
string nodeF = "ns=2;s=Simulation Examples.Functions.Ramp2";   // float
string nodeB = "ns=2;s=Simulation Examples.Functions.User3";    // boolean

// Коды типов преобразования для драйвера OPC UA из таблицы "_address.._datatype".
// В CTL это НЕ именованные константы, значения зафиксированы явно.
// Полная таблица, включая набор Modbus, — docs/11-address.md, раздел 7.
int ADDR_DATATYPE_BOOLEAN = 751;
int ADDR_DATATYPE_FLOAT   = 760;

main()
{
  dpdHeader("OPC UA", "точка данных с нуля: свой тип, свой адрес, уборка");

  // =====================================================================
  // 0. Убираем возможные остатки прошлого прогона
  // =====================================================================
  DebugN("(0) уборка остатков прошлого прогона");
  dpdDropAll();

  // Про эталон f1 только сообщаем — ничего в нём не меняем.
  if (dpExists("f1"))
  {
    DebugN("    эталонная точка f1 на месте, пример её не трогает");
  }
  else
  {
    DebugN("    эталонной точки f1 нет. Пример от неё не зависит.");
    DebugN("    Структура f1 сохранена в docs/11-address.md, раздел 6.2.");
  }

  // =====================================================================
  // 1. Создаём тип точки данных
  // =====================================================================
  DebugN("(1) создаём тип ", DPT);

  dyn_dyn_string names;
  dyn_dyn_int    types;
  names[1] = makeDynString(DPT);                    types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "f_node");           types[2] = makeDynInt(0, DPEL_FLOAT);
  names[3] = makeDynString("", "b_node_spont");     types[3] = makeDynInt(0, DPEL_BOOL);
  names[4] = makeDynString("", "b_node_poll");      types[4] = makeDynInt(0, DPEL_BOOL);

  int rcType = dpTypeCreate(names, types);
  DebugN("    dpTypeCreate rc=", rcType, "  lastError=", getLastError());
  dpdCheckRc("тип создан", rcType);

  dyn_dyn_string chkNames;
  dyn_dyn_int    chkTypes;
  dpdCheckRc("тип читается через dpTypeGet", dpTypeGet(DPT, chkNames, chkTypes));
  DebugN("    элементов в типе: ", dynlen(chkNames));

  // =====================================================================
  // 2. Создаём точку данных
  // =====================================================================
  DebugN("(2) создаём точку данных ", DP);
  int rcCreate = dpCreate(DP, DPT);
  DebugN("    dpCreate rc=", rcCreate, "  lastError=", getLastError());
  dpdCheckRc("точка данных создана", rcCreate);
  dpdCheck("точка данных существует", dpExists(DP));
  dpdCheck("тип точки данных совпадает", dpTypeName(DP + ".") == DPT);

  dyn_string elems = dpNames(DP + ".*");
  DebugN("    элементов верхнего уровня: ", dynlen(elems));
  for (int i = 1; i <= dynlen(elems); i++)
  {
    DebugN("      ", elems[i]);
  }
  dpdCheck("все три элемента на месте", dynlen(elems) == 3);

  // =====================================================================
  // 3. Навешиваем конфигурацию _address
  // =====================================================================
  DebugN("(3) навешиваем конфигурацию _address");

  dpdSetAddress(DP + ".f_node", server, subscription, art, variante,
                nodeF, ADDR_DATATYPE_FLOAT, DPATTR_ADDR_MODE_IO_SPONT,
                driverNumber);

  // Один и тот же узел User3, два режима направления.
  dpdSetAddress(DP + ".b_node_spont", server, subscription, art, variante,
                nodeB, ADDR_DATATYPE_BOOLEAN, DPATTR_ADDR_MODE_IO_SPONT,
                driverNumber);

  dpdSetAddress(DP + ".b_node_poll", server, subscription, art, variante,
                nodeB, ADDR_DATATYPE_BOOLEAN, DPATTR_ADDR_MODE_INPUT_POLL,
                driverNumber);

  // =====================================================================
  // 4. Ждём данные с PLC
  // =====================================================================
  DebugN("(4) ждём данные с PLC, до 25 секунд");

  // --- float
  bool floatOk = false;
  time floatT;
  for (int i = 1; i <= 25; i++)
  {
    dpGet(DP + ".f_node:_online.._stime", floatT);
    if (floatT != makeTime(1970, 1, 1, 3, 0, 0)) { floatOk = true; break; }
    delay(1);
  }
  dpdCheck("float: значения пошли", floatOk);

  // --- логический узел: фиксируем переключение, а не мгновенный срез
  bool sawTrue = false;
  bool sawFalse = false;
  bool spontGotData = false;
  for (int i = 1; i <= 25; i++)
  {
    bool  b;
    time  t;
    dpGet(DP + ".b_node_spont:_online.._value", b);
    dpGet(DP + ".b_node_spont:_online.._stime", t);
    if (t != makeTime(1970, 1, 1, 3, 0, 0)) { spontGotData = true; }
    if (b) { sawTrue = true; } else { sawFalse = true; }
    if (sawTrue && sawFalse && spontGotData) { break; }
    delay(1);
  }
  DebugN("    IO_SPONT:      данные=", spontGotData,
         "  наблюдались true=", sawTrue, "  false=", sawFalse);
  dpdCheck("bool IO_SPONT: значения пошли", spontGotData);
  dpdCheck("bool IO_SPONT: узел переключается — оба состояния видны",
           sawTrue && sawFalse);

  // --- тот же узел в режиме INPUT_POLL: влияет ли режим на приём
  bool pollGotData = false;
  for (int i = 1; i <= 15; i++)
  {
    time t;
    dpGet(DP + ".b_node_poll:_online.._stime", t);
    if (t != makeTime(1970, 1, 1, 3, 0, 0)) { pollGotData = true; break; }
    delay(1);
  }
  DebugN("    INPUT_POLL:    данные=", pollGotData);

  float fVal;
  bool  bSpont;
  bool  bPoll;
  dpGet(DP + ".f_node:_online.._value",         fVal);
  dpGet(DP + ".b_node_spont:_online.._value",   bSpont);
  dpGet(DP + ".b_node_poll:_online.._value",    bPoll);
  DebugN("    значения: f_node=", fVal,
         "  b_node_spont=", bSpont, "  b_node_poll=", bPoll);

  // =====================================================================
  // 5. Уборка: точка данных, затем тип
  // =====================================================================
  DebugN("(5) уборка");
  dpdDropAll();
  dpdCheck("точка данных удалена", !dpExists(DP));
  dyn_dyn_string gNames;
  dyn_dyn_int    gTypes;
  dpdCheck("тип удалён", dpTypeGet(DPT, gNames, gTypes) != 0);

  DebugN("");
  dpdSummary();
  DebugN("--- пример повторяем: тип и точка создаются заново на каждом прогоне ---");
}

// ===========================================================================
// Удаление точки данных и типа с ожиданием: dpDelete и dpTypeDelete
// асинхронны, поэтому повторяем, пока объект не исчезнет.
// ===========================================================================
void dpdDropAll()
{
  // --- точки данных этого типа
  dyn_string dps = dpNames(DP);
  for (int i = 1; i <= dynlen(dps); i++)
  {
    if (dpExists(dps[i]))
    {
      int rc = dpDelete(dps[i]);
      DebugN("    dpDelete(", dps[i], ") rc=", rc);
    }
  }
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    if (!dpExists(DP)) { break; }
    delay(1);
  }

  // --- тип: сносим все точки этого типа, иначе dpTypeDelete не пройдёт
  dyn_string all = dpNames("*", DPT);
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpExists(all[i]))
    {
      int rc = dpDelete(all[i]);
      DebugN("    dpDelete(", all[i], ") rc=", rc);
    }
  }
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    dyn_string still = dpNames("*", DPT);
    if (dynlen(still) == 0) { break; }
    delay(1);
  }

  for (int attempt = 1; attempt <= 30; attempt++)
  {
    dyn_dyn_string pn;
    dyn_dyn_int    pt;
    if (dpTypeGet(DPT, pn, pt) != 0) { break; }   // типа нет
    dpTypeDelete(DPT);
    delay(1);
  }
}

// ===========================================================================
// Конфигурирование адреса на одном элементе
// ===========================================================================
void dpdSetAddress(string dpe, string srv, string sub,
                   string a, string v, string itemId,
                   int datatype, int direction, int driverNo)
{
  string address = srv + "$" + sub + "$" + a + "$" + v + "$" + itemId;

  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", driverNo);

  int rc = dpSetTimedWait(0,
                    dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                    dpe + ":_address.._reference", address,
                    dpe + ":_address.._active",    TRUE,
                    dpe + ":_address.._drv_ident", "OPCUA",
                    dpe + ":_address.._datatype",  datatype,
                    dpe + ":_address.._direction", direction);

  string refGot;
  int    dtGot;
  int    dirGot;
  dpGet(dpe + ":_address.._reference", refGot);
  dpGet(dpe + ":_address.._datatype",  dtGot);
  dpGet(dpe + ":_address.._direction", dirGot);

  DebugN("    ", dpe, " rc=", rc, " ref='", refGot,
         "' datatype=", dtGot, " direction=", dirGot);

  dpdCheck("  " + dpe + ": конфиг записан", rc == 0);
  dpdCheck("  " + dpe + ": _reference совпадает", refGot == address);
  dpdCheck("  " + dpe + ": _datatype совпадает", dtGot == datatype);
  dpdCheck("  " + dpe + ": _direction совпадает", dirGot == direction);
}

// ===========================================================================
// Помощники проверки — копия блока из _lib.ctl, чтобы пример был без зависимостей
// ===========================================================================
void dpdHeader(string fn, string synopsis)
{
  DebugN("=== ", fn, " ===  ", synopsis);
}

void dpdCheck(string what, bool ok)
{
  if (ok)
  {
    dpdPass++;
    DebugN("  PASS  ", what);
  }
  else
  {
    dpdFail++;
    DebugN("  FAIL  ", what, "  lastError=", getLastError());
  }
}

void dpdCheckRc(string what, int rc)
{
  if (rc == 0)
  {
    dpdPass++;
    DebugN("  PASS  ", what, "  rc=0");
  }
  else
  {
    dpdFail++;
    DebugN("  FAIL  ", what, "  rc=", rc, "  lastError=", getLastError());
  }
}

void dpdSummary()
{
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
}