// 05_address_manual_check.ctl — подготовка ДВУХ точек данных для ручной
// проверки пользователем.
//
// Документация: docs/11-address.md
//
// Что делает:
//   1. создаёт тип точки данных с тремя элементами — float, int, bool;
//   2. создаёт ДВЕ точки данных этого типа;
//   3. привязывает к их элементам подходящие узлы OPC UA;
//   4. проверяет, что конфиги записались и данные идут;
//   5. удаляет и точки данных, и тип.
//
// ПРОТОКОЛ ПРОВЕРКИ: пример самодостаточен и повторяем.
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа; если проверяем конфигурацию адреса —
//      навешиваем _address, прописывая адрес Modbus или OPC UA по тесту;
//   3) удаляем и точку данных, и тип.
//
// Предыдущая версия ничего не удаляла и проверяла создание типа только если
// его ещё не было. Из-за этого число проверок зависело от истории: 30 на первом
// прогоне и 29 на всех последующих, потому что проп��скала�� проверка
// "тип создан". Гейт с плавающим числом проверок непригоден. Теперь тип
// создаётся всегда, и уборка начинается до создания.
//
// Повторный запуск безопасен: точки данных удаляются и создаются заново,
// тип переиспользуется.
//
// Проверено: CTL 3.18, проект <проект стенда>.
//
// Запуск: разовый. Нужен живой Event Manager и OPC UA менеджер с номером 3.

main()
{
  dpdHeader("OPC UA", "две точки данных, проверка адресов, уборка");

  // ---------------------------------------------------------------------
  // Параметры подключения. Номер драйвера — из _distrib.._driver эталона.
  // ---------------------------------------------------------------------
  int    driverNumber = 3;
  string server       = "kep";
  string subscription = "kep_sub";
  string art          = "1";
  string variante     = "1";

  // ---------------------------------------------------------------------
  // Объекты, которые остаются после прогона
  // ---------------------------------------------------------------------
  dyn_dyn_string typeProbeNames;   // переменные для проверки существования типа
  dyn_dyn_int typeProbeTypes;     // (параметры dpTypeGet объявлены как ссылки)
  string dpt  = "dpdemo_ua3";         // тип точки данных
  string dpA  = "dpdemo_ua3_a";       // точка данных 1
  string dpB  = "dpdemo_ua3_b";       // точка данных 2

  // ---------------------------------------------------------------------
  // 1. Тип точки данных: корень + fVal(float) + iVal(int) + bVal(bool)
  //
  //    Имя типа берётся из elements[1] — у dpTypeCreate() НЕТ параметра
  //    с именем. Корневой элемент обязан быть DPEL_STRUCT.
  //    Индекс массива — номер элемента при обходе в ширину, в ячейке
  //    лежит путь от корня, имя стоит на позиции, равной глубине.
  // ---------------------------------------------------------------------
  DebugN("(1) тип точки данных ", dpt);

  // Параметры dpTypeGet() объявлены как ссылки (&), поэтому результат функции
  // передать в них нельзя — нужен отдельный вызов с настоящими переменными.
  // Идемпотентность: сперва убираем остатки прошлого прогона. Тогда тип заведомо
  // не существует, dpTypeCreate() вызывается всегда, и число проверок не
  // зависит от того, что осталось на стенде от предыдущих запусков.
  dpdDropAll(dpt);

  DebugN("(1) создаём тип точки данных ", dpt);

  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);            types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "fVal");      types[2] = makeDynInt(0, DPEL_FLOAT);
  names[3] = makeDynString("", "iVal");      types[3] = makeDynInt(0, DPEL_INT);
  names[4] = makeDynString("", "bVal");      types[4] = makeDynInt(0, DPEL_BOOL);
  dpdCheckRc("тип создан", dpTypeCreate(names, types));

  dyn_dyn_string backNames;
  dyn_dyn_int backTypes;
  dpdCheckRc("тип читается (dpTypeGet)", dpTypeGet(dpt, backNames, backTypes));
  DebugN("    элементов в типе: ", dynlen(backNames));
  dpdCheck("в типе ровно 4 элемента", dynlen(backNames) == 4);
  if (dynlen(backNames) == 4)
  {
    dpdCheck("fVal — float", backTypes[2][2] == DPEL_FLOAT);
    dpdCheck("iVal — int",   backTypes[3][2] == DPEL_INT);
    dpdCheck("bVal — bool",  backTypes[4][2] == DPEL_BOOL);
  }

  // ---------------------------------------------------------------------
  // 2. Две точки данных этого типа
  // ---------------------------------------------------------------------
  DebugN("(2) точки данных ", dpA, " и ", dpB);

  dpdRecreateDp(dpA, dpt);
  dpdRecreateDp(dpB, dpt);

  dpdCheck("точка данных 1 создана", dpExists(dpA));
  dpdCheck("точка данных 2 создана", dpExists(dpB));
  dpdCheck("тип точки данных 1 верен", dpTypeName(dpA + ".") == dpt);
  dpdCheck("тип точки данных 2 верен", dpTypeName(dpB + ".") == dpt);

  // ---------------------------------------------------------------------
  // 3. Привязка узлов
  //
  //    Режим ввода без выхода (INPUT_POLL) — он не создаёт выходов, а
  //    значит не конфликтует с уже настроенными адресами. Приём данных
  //    от направления не зависит — проверено и IO_SPONT, и INPUT_POLL.
  //
  //    Типы узлов сверены инструментом opcuactl get value.
  // ---------------------------------------------------------------------
  DebugN("(3) привязка узлов");

  // Точка данных 1
  dpdSetAddress(dpA + ".fVal", server, subscription, art, variante,
                "ns=2;s=Simulation Examples.Functions.Ramp2",
                ADDR_DATATYPE_FLOAT, driverNumber);
  dpdSetAddress(dpA + ".iVal", server, subscription, art, variante,
                "ns=2;s=Simulation Examples.Functions.Ramp1",
                ADDR_DATATYPE_INT32, driverNumber);
  dpdSetAddress(dpA + ".bVal", server, subscription, art, variante,
                "ns=2;s=Simulation Examples.Functions.User3",
                ADDR_DATATYPE_BOOLEAN, driverNumber);

  // Точка данных 2 — другие узлы. Логический узел на сервере только один,
  // поэтому он общий: это заодно проверяет, что один узел может читаться
  // в две точки данных.
  dpdSetAddress(dpB + ".fVal", server, subscription, art, variante,
                "ns=2;s=Simulation Examples.Functions.Ramp8",
                ADDR_DATATYPE_DOUBLE, driverNumber);
  dpdSetAddress(dpB + ".iVal", server, subscription, art, variante,
                "ns=2;s=Simulation Examples.Functions.Random1",
                ADDR_DATATYPE_INT16, driverNumber);
  dpdSetAddress(dpB + ".bVal", server, subscription, art, variante,
                "ns=2;s=Simulation Examples.Functions.User3",
                ADDR_DATATYPE_BOOLEAN, driverNumber);

  // ---------------------------------------------------------------------
  // 4. Проверка получения данных
  // ---------------------------------------------------------------------
  DebugN("(4) проверка получения данных");

  // float
  bool floatOk = false;
  for (int i = 1; i <= 20; i++)
  {
    time t;
    dpGet(dpA + ".fVal:_online.._stime", t);
    if (t != makeTime(1970, 1, 1, 3, 0, 0)) { floatOk = true; break; }
    delay(1);
  }
  dpdCheck("точка данных 1: float — данные пошли", floatOk);

  // int
  bool intOk = false;
  for (int i = 1; i <= 20; i++)
  {
    time t;
    dpGet(dpA + ".iVal:_online.._stime", t);
    if (t != makeTime(1970, 1, 1, 3, 0, 0)) { intOk = true; break; }
    delay(1);
  }
  dpdCheck("точка данных 1: int — данные пошли", intOk);

  // bool — узел переключается, поэтому фиксируем переход, а не срез
  bool sawTrue = false;
  bool sawFalse = false;
  for (int i = 1; i <= 25; i++)
  {
    bool b;
    dpGet(dpA + ".bVal:_online.._value", b);
    if (b) { sawTrue = true; } else { sawFalse = true; }
    if (sawTrue && sawFalse) { break; }
    delay(1);
  }
  dpdCheck("точка данных 1: bool — узел переключается", sawTrue && sawFalse);

  // ---------------------------------------------------------------------
  // 5. Сводка проверенного, затем уборка
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- что было проверено ---");
  DebugN("Тип точки данных : ", dpt);
  DebugN("  элементы        : fVal (float), iVal (int), bVal (bool)");
  DebugN("Точка данных 1   : ", dpA);
  DebugN("  fVal -> ", nodeOf(dpA + ".fVal"));
  DebugN("  iVal -> ", nodeOf(dpA + ".iVal"));
  DebugN("  bVal -> ", nodeOf(dpA + ".bVal"));
  DebugN("Точка данных 2   : ", dpB);
  DebugN("  fVal -> ", nodeOf(dpB + ".fVal"));
  DebugN("  iVal -> ", nodeOf(dpB + ".iVal"));
  DebugN("  bVal -> ", nodeOf(dpB + ".bVal"));
  DebugN("Номер драйвера   : ", driverNumber);
  DebugN("Режим             : ", DPATTR_ADDR_MODE_INPUT_POLL, " (ввод без выхода)");

  // ---------------------------------------------------------------------
  // 5. Уборка по протоколу: и точки данных, и тип
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("(5) уборка");
  dpdDropAll(dpt);
  dpdCheck("точка данных 1 удалена", !dpExists(dpA));
  dpdCheck("точка данных 2 удалена", !dpExists(dpB));
  dyn_dyn_string leftNames;
  dyn_dyn_int leftTypes;
  dpdCheck("тип удалён", dpTypeGet(dpt, leftNames, leftTypes) != 0);

  DebugN("");
  dpdSummary();
}

// ===========================================================================
// Удаление точки данных и типа с ожиданием: dpDelete и dpTypeDelete
// асинхронны, поэтому повторяем, пока объект не исчезнет.
// ===========================================================================
void dpdDropAll(string dpt)
{
  dyn_string all = dpNames("*", dpt);
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
    if (dynlen(dpNames("*", dpt)) == 0) { break; }
    delay(1);
  }

  for (int attempt = 1; attempt <= 30; attempt++)
  {
    dyn_dyn_string pn;
    dyn_dyn_int pt;
    if (dpTypeGet(dpt, pn, pt) != 0) { break; }   // типа нет
    dpTypeDelete(dpt);
    delay(1);
  }
}

// ===========================================================================
// Пересоздание точки данных: удалить, если есть, и создать заново
// ===========================================================================
void dpdRecreateDp(string dpName, string dpt)
{
  if (dpExists(dpName))
  {
    int rc = dpDelete(dpName);
    DebugN("    удалена существующая ", dpName, " rc=", rc);
  }
  int rc = dpCreate(dpName, dpt);
  DebugN("    создана ", dpName, " rc=", rc);
}

// Возвращает записанный адрес элемента — для сводки.
string nodeOf(string dpe)
{
  string ref;
  dpGet(dpe + ":_address.._reference", ref);
  return ref;
}

// ===========================================================================
// Конфигурирование адреса на одном элементе
// ===========================================================================
void dpdSetAddress(string dpe, string server, string subscription,
                   string art, string variante, string itemId,
                   int datatype, int driverNumber)
{
  string address = server + "$" + subscription + "$" + art + "$" + variante + "$" + itemId;

  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", driverNumber);

  int rc = dpSetTimedWait(0,
                    dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                    dpe + ":_address.._reference", address,
                    dpe + ":_address.._active",    TRUE,
                    dpe + ":_address.._drv_ident", "OPCUA",
                    dpe + ":_address.._datatype",  datatype,
                    dpe + ":_address.._direction", DPATTR_ADDR_MODE_INPUT_POLL);

  string refGot;
  int dtGot;
  dpGet(dpe + ":_address.._reference", refGot);
  dpGet(dpe + ":_address.._datatype",  dtGot);

  DebugN("    ", dpe, " rc=", rc, " datatype=", dtGot);

  dpdCheck("  " + dpe + ": конфиг записан", rc == 0);
  dpdCheck("  " + dpe + ": _reference совпадает", refGot == address);
  dpdCheck("  " + dpe + ": _datatype совпадает", dtGot == datatype);
}

// ===========================================================================
// Помощники
// ===========================================================================
int dpdPass = 0;
int dpdFail = 0;

int ADDR_DATATYPE_BOOLEAN = 751;
int ADDR_DATATYPE_INT16   = 754;
int ADDR_DATATYPE_INT32   = 756;
int ADDR_DATATYPE_FLOAT   = 760;
int ADDR_DATATYPE_DOUBLE  = 761;

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