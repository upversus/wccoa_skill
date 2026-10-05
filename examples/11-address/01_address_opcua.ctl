// 01_address_opcua.ctl — создание периферийного адреса _address для OPC UA.
//
// Документация: docs/11-address.md
//
// Что показывает пример:
//   * правильный порядок: точка данных → _distrib (если driverNumber != 1) →
//     _address;
//   * конфиги пишутся ИСКЛЮЧИТЕЛЬНО через dpSetTimedWait(0, ...) — см. раздел 1
//     документации;
//   * сборка строки адреса OPC UA формата Server$Subscription$Art$Variante$Item;
//   * два слоя проверки: атрибуты конфига читаются обратно, затем проверяется,
//     что конфиг вообще существует (через _type).
//
// Проверено: CTL 3.18, проект prg_12_3, 2026-10-04 — создание и чтение конфига.
// Чтение значения из PLC в этом примере НЕ проверяется: для этого нужен
// запущенный OPC UA сервер и Node ID узлов — см. 02_address_opcua_read.ctl.
//
// Запуск (нужен живой Event Manager):
//   .\run-ctl.ps1 -Script .\11-address\01_address_opcua.ctl

main()
{
  dpdHeader("dpSetTimedWait", "конфигурация _address для OPC UA");

  // ---------------------------------------------------------------------
  // Параметры подключения. ЗАПОЛНЯЕТ ПОЛЬЗОВАТЕЛЬ.
  //
  // Номер драйвера угадывать нельзя: он зависит от того, как запущен менеджер
  // драйвера, и молча даст неверную привязку. Спрашивается у пользователя.
  // ---------------------------------------------------------------------
  int driverNumber = 1;              // ← спросить у пользователя

  // Имя точки данных _OPCUAServer БЕЗ ведущего "_"
  string serverName = "OPCUAServer";

  // Имя точки данных _OPCUASubscription БЕЗ ведущего "_"
  string subscriptionName = "MySubscription";

  // Node ID элемента на OPC UA сервере
  string itemId = "ns=2;s=MyNode";

  // ---------------------------------------------------------------------
  // 0. Готовим точку данных: тип с элементом float и сама точка данных
  // ---------------------------------------------------------------------
  string dpt = "dpdemo_dev";
  string dpe = "dpdemo_dev_1.Value";

  DebugN("  имя элемента точки данных: ", dpe);

  dpdDropAllDpOfType(dpt);
  {
    // Тип: корень-структура с одним элементом float.
    // Имя типа берётся из elements[1] — у dpTypeCreate() нет параметра с именем.
    dyn_dyn_string names;
    dyn_dyn_int types;
    names[1] = makeDynString(dpt);
    types[1] = makeDynInt(DPEL_STRUCT);
    names[2] = makeDynString("", "Value");
    types[2] = makeDynInt(0, DPEL_FLOAT);
    dpdCheckRc("тип точки данных создан", dpTypeCreate(names, types));
  }

  int rcCreate = dpCreate("dpdemo_dev_1", dpt);
  DebugN("  dpCreate() rc=", rcCreate, "  lastError=", getLastError());
  dpdCheckRc("точка данных создана", rcCreate);
  dpdCheck("точка данных существует", dpExists("dpdemo_dev_1"));

  // ---------------------------------------------------------------------
  // 1. Номер драйвера → конфиг _distrib (только если НЕ 1)
  // ---------------------------------------------------------------------
  if (driverNumber != 1)
  {
    int rcDist = dpSetTimedWait(0,
                        dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                        dpe + ":_distrib.._driver", driverNumber);
    DebugN("  dpSetTimedWait(_distrib) rc=", rcDist, "  driverNumber=", driverNumber);
    dpdCheckRc("_distrib создан с номером драйвера", rcDist);

    int drvBack;
    dpGet(dpe + ":_distrib.._driver", drvBack);
    DebugN("  прочитанный _distrib.._driver = ", drvBack);
    dpdCheck("номер драйвера записан верно", drvBack == driverNumber);
  }
  else
  {
    DebugN("  driverNumber == 1, конфиг _distrib не нужен");
  }

  // ---------------------------------------------------------------------
  // 2. Строка периферийного адреса
  //    Формат: Server$Subscription$Art$Variante$Item
  //    Два подряд "$" — пустые Art и Variante, драйвер определит их сам.
  // ---------------------------------------------------------------------
  string address = serverName + "$" + subscriptionName + "$$$" + itemId;
  DebugN("  адрес: ", address);

  // ---------------------------------------------------------------------
  // 3. Создание конфига _address одним вызовом dpSetTimedWait(0, ...)
  //
  //    DPCONFIG_PERIPH_ADDR_MAIN, а НЕ DPCONFIG_PERIPH_ADDR: такой константы
  //    в CTL 3.18 нет, скрипт с ней не компилируется
  //    (SEVERE, 73, Variable not defined).
  //
  //    _datatype и _direction задаются ЯВНО. Если их не писать, они читаются
  //    как 0, а для OPC UA в таблице преобразований 0 не значит ничего:
  //    DEFAULT для OPC UA — это 750, а не 0.
  // ---------------------------------------------------------------------
  int rcAddr = dpSetTimedWait(0,
                      dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                      dpe + ":_address.._reference", address,
                      dpe + ":_address.._active",    TRUE,
                      dpe + ":_address.._drv_ident", "OPCUA",
                      dpe + ":_address.._datatype",  ADDR_DATATYPE_FLOAT,
                      dpe + ":_address.._direction", DPATTR_ADDR_MODE_INPUT_POLL);
  DebugN("  dpSetTimedWait(_address) rc=", rcAddr, "  lastError=", getLastError());
  dpdCheckRc("конфиг _address создан и заполнен", rcAddr);

  // ---------------------------------------------------------------------
  // 4. Слой проверки 1 — читаем всё, что записали, обратно
  // ---------------------------------------------------------------------
  string gotRef;
  bool   gotActive;
  string gotIdent;
  int    gotType;
  int    gotDataType;
  int    gotDirection;

  int rc1 = dpGet(dpe + ":_address.._reference", gotRef);
  int rc2 = dpGet(dpe + ":_address.._active",    gotActive);
  int rc3 = dpGet(dpe + ":_address.._drv_ident", gotIdent);
  int rc4 = dpGet(dpe + ":_address.._datatype",  gotDataType);
  int rc5 = dpGet(dpe + ":_address.._direction", gotDirection);

  DebugN("  прочитано: reference='", gotRef, "'");
  DebugN("             active=",    gotActive);
  DebugN("             drv_ident='", gotIdent, "'");
  DebugN("             datatype=",  gotDataType);
  DebugN("             direction=", gotDirection);

  dpdCheck("dpGet(_reference) отработал без ошибки", rc1 == 0);
  dpdCheck("_reference записан верно", gotRef == address);
  dpdCheck("_active == TRUE", gotActive);
  dpdCheck("_drv_ident == 'OPCUA'", gotIdent == "OPCUA");
  dpdCheck("_datatype записан верно (FLOAT для OPC UA = 760)",
           gotDataType == ADDR_DATATYPE_FLOAT);
  dpdCheck("_direction записан верно (INPUT_POLL = 4)",
           gotDirection == DPATTR_ADDR_MODE_INPUT_POLL);

  // ---------------------------------------------------------------------
  // 5. Слой проверки 1 (продолжение) — конфиг вообще существует?
  //    У _address тип материализован, поэтому _type надёжен:
  //    0 — конфига нет, DPCONFIG_PERIPH_ADDR_MAIN — есть.
  //    Для _online это НЕ работает: там _type всегда 0. Не обобщайте.
  // ---------------------------------------------------------------------
  int cfgType;
  dpGet(dpe + ":_address.._type", cfgType);
  DebugN("  _address.._type = ", cfgType, " (DPCONFIG_PERIPH_ADDR_MAIN=",
         DPCONFIG_PERIPH_ADDR_MAIN, ")");
  dpdCheck("конфиг _address существует (_type != 0)", cfgType != 0);
  dpdCheck("_type == DPCONFIG_PERIPH_ADDR_MAIN", cfgType == DPCONFIG_PERIPH_ADDR_MAIN);

  // ---------------------------------------------------------------------
  // 6. Удаление адреса обратным вызовом
  // ---------------------------------------------------------------------
  int rcDel = dpSetTimedWait(0, dpe + ":_address.._type", DPCONFIG_NONE);
  DebugN("  удаление адреса: rc=", rcDel);
  dpdCheckRc("адрес удалён", rcDel);

  int cfgTypeAfter;
  dpGet(dpe + ":_address.._type", cfgTypeAfter);
  dpdCheck("после удаления _type == 0", cfgTypeAfter == 0);

  // ---------------------------------------------------------------------
  // teardown
  // ---------------------------------------------------------------------
  dpdDropAllDpOfType(dpt);
  int rcDelType = dpTypeDelete(dpt);
  DebugN("  teardown: dpTypeDelete(", dpt, ") rc=", rcDelType);
  dpdCheck("тип удалён", rcDelType == 0);

  dpdSummary();
}

// ===========================================================================
// Помощники — самодостаточный блок, идентичен examples/_lib.ctl
// ===========================================================================
int dpdPass = 0;
int dpdFail = 0;

// Коды типов преобразования для драйвера OPC UA из таблицы "_address.._datatype".
// В CTL это не именованные константы, поэтому значения зафиксированы здесь
// явно. Для Modbus набор другой — см. docs/11-address.md, раздел 7.
int ADDR_DATATYPE_BOOLEAN = 751;
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

// Системные точки данных и типы начинаются с подчёркивания. dpNames()
// возвращает имена с префиксом системы, поэтому префикс снимается ДО проверки.
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
    int rc = dpDelete(names[i]);
    DebugN("  teardown: dpDelete(", names[i], ") rc=", rc);
  }
}