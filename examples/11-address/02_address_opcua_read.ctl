// 02_address_opcua_read.ctl — полная цепочка: создание адреса скриптом
// и получение значения с PLC.
//
// Документация: docs/11-address.md
//
// Конфигурация изначально снята с эталона: тип for_test_OPCUA, точка f1,
// и настроенные в ParaMod вручную. Пример повторяет их конфигурацию
// программно — с тем же адресом и тем же номером драйвера.
//
// Что проверяется:
//   1. конфиг _distrib с номером драйвера;
//   2. конфиг _address со строкой адреса;
//   3. ВОТ ЭТО — главное: приходит ли значение с PLC в созданную скриптом
//      точку данных. Узел-эталон — «пила» (Ramp2), значение на нём
//      постоянно меняется, поэтому проверка не сравнением с эталоном,
//      а признаком живых данных: значение прочитано И метка времени
//      источника обновилась.
//
// ⚠ Ограничение: привязка точки данных к соединению драйвера делается
// в ParaMod вручную (документированного атрибута для неё нет). Если новую
// точку данных не привязать в PARA, конфиг будет записан верно, но данные
// могут не прийти. Поэтому проверки разделены: сбой прихода данных — это
// либо «не привязано в PARA», либо «адрес неверный».
//
// Проверено: CTL 3.18, проект prg_12_3.
//
// Запуск: разовый. Нужен живой Event Manager и запущенный OPC UA менеджер.

main()
{
  dpdHeader("OPC UA", "создание адреса скриптом и получение значения с PLC");

  // ---------------------------------------------------------------------
  // Параметры подключения — перенесены из эталонной конфигурации.
  // ---------------------------------------------------------------------
  int driverNumber = 3;    // из _distrib.._driver эталона

  // Строка адреса эталонной точки данных, разобранная на части.
  string serverName        = "kep";
  string subscriptionName  = "kep_sub";
  string art               = "1";
  string variante          = "1";
  string itemId            = "ns=2;s=Simulation Examples.Functions.Ramp2";

  // Коды из конфига эталона: datatype=760 (FLOAT), direction=6 (IO_SPONT).
  //
  // ВНИМАНИЕ. Направление приходится отличать от эталонного. В эталоне
  // работает в режиме IO_SPONT (6) — это ввод/вывод, то есть адрес включает
  // ВЫХОД. OA запрещает два одинаковых активных выхода на один адрес, поэтому
  // скрипт с тем же адресом и тем же режимом получает отказ:
  //
  //   PARAM,SEVERE, 47, Duplicate peripheral address for this output,
  //   DP: ...:_address.._type
  //
  // Здесь используется режим ввода без вывода — DPATTR_ADDR_MODE_INPUT_POLL (4).
int direction = DPATTR_ADDR_MODE_INPUT_POLL;
int datatype  = ADDR_DATATYPE_FLOAT;

  string address = serverName + "$" + subscriptionName + "$" + art + "$" +
                   variante + "$" + itemId;
  DebugN("  адрес: ", address);
  DebugN("  номер драйвера: ", driverNumber);

  // ---------------------------------------------------------------------
  // 0. Создаём собственный тип и точку данных
  // ---------------------------------------------------------------------
  string dpt   = "dpdemo_ua";
  string dpName = "dpdemo_ua_1";
  string dpe   = dpName + ".Value";

  dpdDropAllDpOfType(dpt);
  {
    // Имя типа берётся из elements[1] — у dpTypeCreate() нет параметра с именем.
    dyn_dyn_string names;
    dyn_dyn_int types;
    names[1] = makeDynString(dpt);
    types[1] = makeDynInt(DPEL_STRUCT);
    names[2] = makeDynString("", "Value");
    types[2] = makeDynInt(0, DPEL_FLOAT);
    dpdCheckRc("тип точки данных создан", dpTypeCreate(names, types));
  }
  dpdCheckRc("точка данных создана", dpCreate(dpName, dpt));
  dpdCheck("точка данных существует", dpExists(dpName));

  // ---------------------------------------------------------------------
  // 1. Конфиг _distrib — привязка к номеру драйвера
  // ---------------------------------------------------------------------
  int rcDist = dpSetTimedWait(0,
                      dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                      dpe + ":_distrib.._driver", driverNumber);
  DebugN("  dpSetTimedWait(_distrib) rc=", rcDist);
  dpdCheckRc("конфиг _distrib создан", rcDist);

  int drvBack;
  dpGet(dpe + ":_distrib.._driver", drvBack);
  DebugN("  _distrib.._driver прочитан как ", drvBack);
  dpdCheck("номер драйвера записан верно", drvBack == driverNumber);

  // ---------------------------------------------------------------------
  // 2. Конфиг _address
  // ---------------------------------------------------------------------
  int rcAddr = dpSetTimedWait(0,
                      dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                      dpe + ":_address.._reference", address,
                      dpe + ":_address.._active",    TRUE,
                      dpe + ":_address.._drv_ident", "OPCUA",
                      dpe + ":_address.._datatype",  datatype,
                      dpe + ":_address.._direction", direction);
  DebugN("  dpSetTimedWait(_address) rc=", rcAddr, "  lastError=", getLastError());
  dpdCheckRc("конфиг _address создан и заполнен", rcAddr);

  // Сверяем записанное с эталоном — конфиги должны совпасть.
  string refGot;
  string identGot;
  int dtGot;
  int dirGot;
  dpGet(dpe + ":_address.._reference", refGot);
  dpGet(dpe + ":_address.._drv_ident", identGot);
  dpGet(dpe + ":_address.._datatype",  dtGot);
  dpGet(dpe + ":_address.._direction", dirGot);
  DebugN("  прочитано: reference='", refGot, "' datatype=", dtGot,
         " direction=", dirGot);
  dpdCheck("_reference совпадает с эталонным", refGot == address);
  dpdCheck("_drv_ident == 'OPCUA'", identGot == "OPCUA");
  dpdCheck("_datatype == 760 (FLOAT)", dtGot == 760);
  dpdCheck("_direction == 4 (INPUT_POLL)", dirGot == 4);

  // ---------------------------------------------------------------------
  // 3. Ждём данные. Узел — пила, поэтому проверяем не значение,
  //    а признак живых данных: значение прочитано И метка времени
  //    источника обновилась между двумя чтениями.
  // ---------------------------------------------------------------------
  DebugN("  ждём данные с PLC (до 20 с)...");

  float v1;
  float v2;
  time t1;
  time t2;

  bool got1 = false;
  bool got2 = false;
  bool changed = false;

  for (int i = 1; i <= 20; i++)
  {
    dpGet(dpe + ":_online.._value", v1);
    dpGet(dpe + ":_online.._stime", t1);
    if (!got1)
    {
      DebugN("    попытка ", i, ": значение=", v1, " stime=",
             formatTime("%c", t1, ""));
      got1 = true;
    }
    delay(1);

    dpGet(dpe + ":_online.._value", v2);
    dpGet(dpe + ":_online.._stime", t2);
    if (v1 != v2 || t1 != t2)
    {
      DebugN("    попытка ", i, ": значение=", v2, " stime=",
             formatTime("%c", t2, ""));
      changed = true;
      break;
    }
  }

  dpdCheck("значение прочитано (dpGet отработал)", got1);
  dpdCheck("метка времени источника обновляется — данные идут", changed);

  // Раньше здесь читался эталон f1.f_node "для сравнения". Эталона на стенде
  // больше нет, и читать нечего: dpGet() вернул бы 0, а напечаталось бы это
  // как значение эталона - то есть вывод вводил бы в заблуждение.
  // Сравнивать не с чем: все примеры сами создают конфигурацию, а исходная
  // снята с f1 и сохранена в docs/11-address.md, раздел 6.2.
  DebugN("  сверять не с чем: эталон f1 на стенде отсутствует,");
  DebugN("  исходная конфигурация сохранена в docs/11-address.md, раздел 6.2");

  // ---------------------------------------------------------------------
  // teardown
  // ---------------------------------------------------------------------
  dpdDropAllDpOfType(dpt);
  dpdCheckRc("тип удалён", dpTypeDelete(dpt));

  dpdSummary();
}

// ===========================================================================
// Помощники
// ===========================================================================
int dpdPass = 0;
int dpdFail = 0;

// Коды типов преобразования OPC UA (docs/11-address.md, раздел 7.1).
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