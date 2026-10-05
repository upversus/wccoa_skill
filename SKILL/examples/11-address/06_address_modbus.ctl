// 06_address_modbus.ctl - полный набор проверок Modbus TCP на эмуляторе.
//
// Драйвер: WCCOAmod.exe -num 2. Эмулятор: TCP 504, устройство Number 1.
//
// ФОРМАТ АДРЕСА (подтверждён на панели Para_36 и на эталоне):
//     M.<ПЛК>.<FC>.<адрес регистра>
//     FC 1 - read/write coils (логические)
//     FC 3 - read multiple registers (числовые)
//
// ГЛАВНОЕ, ЧТО НУЖНО ЗАДАВАТЬ СКРИПТОМ (найдено сравнением с эталоном):
//     _address.._poll_group = "System1:_1s"
// dpSetTimedWait этот атрибут НЕ заполняет, и без него драйвер не опрашивает
// адрес вообще. Все предыдущие пробы молчали именно поэтому.
//
// _direction зависит от адресного пространства устройства и выбирается по FC:
//     FC 3 (регистры) -> 4 (опрос)
//     FC 1 (coils)    -> 7 (вход/выход)
//
// Направление 7 не пишется из скрипта в комбинациях, несовместимых по типу:
// dpSetTimedWait возвращает rc = -1.
//
// Проверено: CTL 3.18, проект <проект стенда>.

int dpdPass = 0;
int dpdFail = 0;

main()
{
  DebugN("=== MODBUS: две точки данных для ручной проверки ===");

  int driverNumber = 2;

  // Группа опроса: пользователь создаёт её заранее (Drivers -> Poll groups),
  // скрипт берёт первую найденную точку данных типа _PollGroup. Создавать
  // группу из скрипта нельзя: в точке типа _PollGroup нет атрибутов опроса,
  // записывать нечего.
  string pollGroup = findPollGroup();
  if (pollGroup == "")
  {
    DebugN("  FAIL  группа опроса не найдена.");
    DebugN("  Создайте её: панель системы -> Drivers -> Poll groups.");
    return;
  }
  DebugN("группа опроса: ", pollGroup);

  string dpt     = "dpdemo_mb";
  string dpNameA = "dpdemo_mb_a";
  string dpNameB = "dpdemo_mb_b";

  // ---------------------------------------------------------- (1) тип
  dyn_dyn_string typeProbeNames;
  dyn_dyn_int typeProbeTypes;
  bool typeExists = false;
  if (dpTypeGet(dpt, typeProbeNames, typeProbeTypes) == 0) { typeExists = true; }

  if (!typeExists)
  {
    dyn_dyn_string names;
    dyn_dyn_int types;
    names[1] = makeDynString(dpt);        types[1] = makeDynInt(DPEL_STRUCT);
    names[2] = makeDynString("", "fVal"); types[2] = makeDynInt(0, DPEL_FLOAT);
    names[3] = makeDynString("", "iVal"); types[3] = makeDynInt(0, DPEL_INT);
    names[4] = makeDynString("", "bVal"); types[4] = makeDynInt(0, DPEL_BOOL);

    int rcT = dpTypeCreate(names, types);
    check((rcT == 0), "тип создан", "  rc=" + rcT);
  }
  else
  {
    DebugN("  тип ", dpt, " уже существует - используем его");
  }

  dyn_dyn_string tNames;
  dyn_dyn_int tTypes;
  dpTypeGet(dpt, tNames, tTypes);
  DebugN("  элементов в типе: ", dynlen(tNames));

  // ------------------------------------------------- (2) точки данных
  check(createDp(dpNameA, dpt), "точка данных 1 создана", "");
  check(createDp(dpNameB, dpt), "точка данных 2 создана", "");
  check((dpTypeName(dpNameA + ".") == dpt), "тип точки данных 1 верен", "");
  check((dpTypeName(dpNameB + ".") == dpt), "тип точки данных 2 верен", "");

  // ------------------------------------------------ (3) привязка адресов
  DebugN("(3) привязка адресов");
  // точка данных 1: устройство 1 "Насос"
  dpdSet(dpNameA + ".fVal", "M.1.3.2", 566, 4, driverNumber, pollGroup);   // Pump_Current, 2 регистра
  dpdSet(dpNameA + ".iVal", "M.1.3.1", 563, 4, driverNumber, pollGroup);   // Pump_Speed_Act, 1 регистр
  dpdSet(dpNameA + ".bVal", "M.1.1.0",  567, 4, driverNumber, pollGroup);   // Pump_Start, coil
  // точка данных 2: устройство 2 "Датчик температуры"
  dpdSet(dpNameB + ".fVal", "M.2.3.0", 566, 4, driverNumber, pollGroup);   // Temperature, 2 регистра
  dpdSet(dpNameB + ".iVal", "M.2.3.2", 563, 4, driverNumber, pollGroup);   // Temperature_Int, 1 регистр
  dpdSet(dpNameB + ".bVal", "M.2.1.0",  567, 4, driverNumber, pollGroup);   // Temp_Alarm_High, coil

  // ------------------------------------------- (4) получение данных
  DebugN("(4) проверка получения данных, ждём до 30 с");
  for (int i = 1; i <= 30; i++)
  {
    if (allFresh()) { break; }
    delay(1);
  }

  DebugN("--- первый срез ---");
  check(isFresh(dpNameA + ".fVal"), "точка 1: float - данные пришли", "");
  check(isFresh(dpNameA + ".iVal"), "точка 1: int   - данные пришли", "");
  check(isFresh(dpNameA + ".bVal"), "точка 1: bool  - данные пришли", "");
  check(isFresh(dpNameB + ".fVal"), "точка 2: float - данные пришли", "");
  check(isFresh(dpNameB + ".iVal"), "точка 2: int   - данные пришли", "");
  check(isFresh(dpNameB + ".bVal"), "точка 2: bool  - данные пришли", "");

  show(dpNameA + ".fVal");
  show(dpNameA + ".iVal");
  show(dpNameA + ".bVal");
  show(dpNameB + ".fVal");
  show(dpNameB + ".iVal");
  show(dpNameB + ".bVal");

  // второй срез: пилообразные регистры обязаны менять значение
  DebugN("--- второй срез через 5 с ---");
  delay(5);
  check(changed(dpNameA + ".fVal"), "точка 1: float - значение меняется", "");
  check(changed(dpNameB + ".fVal"), "точка 2: float - значение меняется", "");
  check(changed(dpNameA + ".iVal"), "точка 1: int   - значение меняется", "");
  check(changed(dpNameB + ".iVal"), "точка 2: int   - значение меняется", "");

  DebugN("");
  DebugN("################ СОЗДАНО ДЛЯ РУЧНОЙ ПРОВЕРКИ ################");
  DebugN("Тип точки данных : ", dpt);
  DebugN("  элементы        : fVal (float), iVal (int), bVal (bool)");
  DebugN("Номер драйвера   : ", driverNumber);
  DebugN("Группа опроса    : ", pollGroup);
  DebugN("Формат адреса    : M.<ПЛК>.<FC>.<регистр>");
  DebugN("");
  DebugN("Точка данных 1   : ", dpNameA);
  DebugN("  fVal -> M.1.3.2   FC 3  566 FLOAT  Pump_Current");
  DebugN("  iVal -> M.1.3.1   FC 3  563 UINT16  Pump_Speed_Act");
  DebugN("  bVal -> M.1.1.0   FC 1  567 BIT    Pump_Start        dir 4");
  DebugN("Точка данных 2   : ", dpNameB);
  DebugN("  fVal -> M.2.3.0   FC 3  566 FLOAT  Temperature");
  DebugN("  iVal -> M.2.3.2   FC 3  563 UINT16  Temperature_Int");
  DebugN("  bVal -> M.2.1.0   FC 1  567 BIT    Temp_Alarm_High   dir 4");
  DebugN("###########################################################");
  // ---------------------------------------------------------------------
  // Уборка по протоколу проверки: и точки данных, и тип.
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- уборка ---");
  check(dropDp(dpNameA), "точка данных 1 удалена", "");
  check(dropDp(dpNameB), "точка данных 2 удалена", "");
  check(dropType(dpt), "тип удалён", "");

  DebugN("");
  dpdSummary();
}

// ВНИМАНИЕ. Адреса ниже взяты из tools/modbus-sim/map.json - это карта
// шести устройств, выведенная из more_tag.xml пользователя. Эмулятор умеет
// пилу, синус и меандр, поэтому значения действительно меняются, и проверка
// "значение меняется" имеет смысл. Адреса за пределами карты молча дают 0.

// ---------------------------------------------------------------- helpers

// Группа опроса выбирается по правилу: пользователь создаёт её заранее,
// скрипт берёт первое попавшееся имя точки данных типа _PollGroup.
// dpNames возвращает имена уже с префиксом системы, то есть "System1:_1s".
string findPollGroup()
{
  dyn_string all = dpNames("_**");
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpTypeName(all[i] + ".") == "_PollGroup")
    {
      return all[i];
    }
  }
  return "";
}

// Своя проверка: готовой функции check() в CTL нет.
bool check(bool ok, string what, string extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, extra); }
  return ok;
}

int dpdSummary()
{
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
}

bool dropDp(string dpName)
{
  if (!dpExists(dpName)) { return true; }
  int rc = dpDelete(dpName);
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(dpName)) { break; }
    delay(1);
  }
  DebugN("    dpDelete(", dpName, ") rc=", rc);
  return !dpExists(dpName);
}

bool dropType(string dpt)
{
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    dyn_dyn_string pn;
    dyn_dyn_int pt;
    if (dpTypeGet(dpt, pn, pt) != 0) { return true; }
    dpTypeDelete(dpt);
    delay(1);
  }
  return false;
}

bool createDp(string dpName, string dpt)
{
  if (dpExists(dpName)) { dpDelete(dpName); }
  return (dpCreate(dpName, dpt) == 0);
}

// Обязателен _poll_group: без него драйвер не опрашивает адрес.
void dpdSet(string dpe, string address, int datatype, int direction,
            int driverNumber, string pollGroup)
{
  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", driverNumber);

  int rc = dpSetTimedWait(0,
                    dpe + ":_address.._type",        DPCONFIG_PERIPH_ADDR_MAIN,
                    dpe + ":_address.._reference",   address,
                    dpe + ":_address.._active",      TRUE,
                    dpe + ":_address.._drv_ident",   "MODBUS",
                    dpe + ":_address.._datatype",    datatype,
                    dpe + ":_address.._direction",   direction,
                    dpe + ":_address.._poll_group",  pollGroup);

  string refGot;
  string grpGot;
  dpGet(dpe + ":_address.._reference",  refGot);
  dpGet(dpe + ":_address.._poll_group", grpGot);

  DebugN("  ", dpe, ": rc=", rc, " ref='", refGot, "' группа='", grpGot, "'");
}

bool isFresh(string dpe)
{
  time t;
  dpGet(dpe + ":_online.._stime", t);
  return (t != makeTime(1970, 1, 1, 3, 0, 0));
}

bool allFresh()
{
  return isFresh("dpdemo_mb_a.fVal") && isFresh("dpdemo_mb_a.iVal") &&
         isFresh("dpdemo_mb_a.bVal") && isFresh("dpdemo_mb_b.fVal") &&
         isFresh("dpdemo_mb_b.iVal") && isFresh("dpdemo_mb_b.bVal");
}

void show(string dpe)
{
  bool bad;
  dyn_anytype v;
  time t;
  dpGet(dpe + ":_online.._bad",   bad);
  dpGet(dpe + ":_online.._value", v);
  dpGet(dpe + ":_online.._stime", t);
  DebugN("     ", dpe, ": bad=", bad, " значение=", v, " stime=", t);
}

bool changed(string dpe)
{
  dyn_anytype first;
  dpGet(dpe + ":_online.._value", first);
  for (int i = 1; i <= 6; i++)
  {
    delay(1);
    dyn_anytype now;
    dpGet(dpe + ":_online.._value", now);
    if ("" + now != "" + first) { return true; }
  }
  return false;
}