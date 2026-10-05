// 09_address_opcua_from_system.ctl - OPC UA, поля адреса берутся из системных
// точек данных. Без строковых параметров и без шаблонов.
//
// Задача: не задавать Сервер и Подписку вручную, а вывести их из проекта.
//
// Откуда берутся значения (проверено чтением):
//     точка данных _kep      тип _OPCUAServer        -> Сервер   "kep"
//     точка данных _kep_sub  тип _OPCUASubscription  -> Подписка "kep_sub"
// В Para они показываются без подчёркивания, в _reference подставляется имя
// без подчёркивания.
//
// Формат _reference для OPC UA:
//     <Сервер>$<Подписка>$<вариант>$<элемент>$<NodeId>
//
// Поля "вариант" и "элемент" в проекте равны 1 и 1. Их источник не
// установлен, поэтому они заданы константами VARIANT_ID и ELEMENT_ID.
//
// Индексы строковых функций CTL с нуля (проверено опытно):
//     strpos("System1:_kep", "_")     -> 8
//     substr("System1:_kep", 9, 200)  -> "kep"
// В CTL НЕ существуют: strstr, copy, left, right, replace, mid, strFind.
//
// dpNames() отбирает по ИМЕНИ, а не по типу: шаблон "*_OPCUAServer" даёт ноль.
// Перебор ведётся по dpNames("_**") с проверкой dpTypeName().
//
// Проверено: CTL 3.18, проект prg_12_3.

string SERVER_NAME = "";
string SUB_NAME    = "";
int    VARIANT_ID  = 1;
int    ELEMENT_ID  = 1;

main()
{
  DebugN("=== OPC UA: адрес собирается из системных точек ===");

  int driverNumber = 3;   // WCCOAopcua.exe -num 3
  string dpt    = "opcChk_t";
  string dpName = "opcChk";

  // ---------------------------------------------------- 1. удаление
  DebugN("");
  DebugN("--- 1. удаление прежних объектов ---");
  // dpDelete и dpTypeDelete асинхронные: если не дождаться, следующий
  // dpTypeCreate вернёт rc = -1 с "DP already exists".
  removeDp(dpName);
  removeDpt(dpt);
  DebugN("  точка удалена: ", (!dpExists(dpName)));
  typeGone(dpt);

  // ------------------------- 2. Сервер и Подписка из системных точек
  DebugN("");
  DebugN("--- 2. Сервер и Подписка из системных точек ---");
  SERVER_NAME = findByType("_OPCUAServer");
  SUB_NAME    = findByType("_OPCUASubscription");

  if (SERVER_NAME == "") { DebugN("  ОШИБКА: нет точки типа _OPCUAServer"); return; }
  if (SUB_NAME    == "") { DebugN("  ОШИБКА: нет точки типа _OPCUASubscription"); return; }

  DebugN("  Сервер   = '", SERVER_NAME, "'");
  DebugN("  Подписка = '", SUB_NAME, "'");

  // сверка: производное имя соответствует точке, у которой оно снято.
  // Имя точки начинается с подчёркивания, поэтому в проверке подчёркивание
  // добавляется обратно: "kep" -> "_kep".
  DebugN("  проверка сервера:   точка '_", SERVER_NAME, "' есть: ",
         dpExists("_" + SERVER_NAME), "  тип: ", dpTypeName("_" + SERVER_NAME + "."));
  DebugN("  проверка подписки: точка '_", SUB_NAME, "' есть: ",
         dpExists("_" + SUB_NAME), "  тип: ", dpTypeName("_" + SUB_NAME + "."));

  // ------------------------------------------------------- 3. тип
  DebugN("");
  DebugN("--- 3. создание типа и точки данных ---");

  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);          types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "bUser3"); types[2] = makeDynInt(0, DPEL_BOOL);
  names[3] = makeDynString("", "fSine2"); types[3] = makeDynInt(0, DPEL_FLOAT);
  names[4] = makeDynString("", "iRamp4"); types[4] = makeDynInt(0, DPEL_INT);

  // dpTypeDelete асинхронен: сразу после удаления dpExists показывает
  // отсутствие типа, но dpTypeCreate ещё некоторое время отвечает
  // "DP already exists". Поэтому создаём с повторами до успеха.
  int rcT = -1;
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    rcT = dpTypeCreate(names, types);
    if (rcT == 0) { break; }
    delay(1);
  }
  DebugN("  dpTypeCreate rc=", rcT, (rcT != 0) ? "  ОШИБКА" : "");
  int rcD = dpCreate(dpName, dpt);
  DebugN("  dpCreate     rc=", rcD, (rcD != 0) ? "  ОШИБКА" : "");
  DebugN("  имя типа: ", dpTypeName(dpName + "."));

  // ------------------------------------------------------ 4. адреса
  DebugN("");
  DebugN("--- 4. адреса ---");

  string prefix = SERVER_NAME + "$" + SUB_NAME + "$" + VARIANT_ID + "$" + ELEMENT_ID + "$";

  setAddr(dpName + ".bUser3", prefix + "ns=2;s=Simulation Examples.Functions.User3", 751);
  setAddr(dpName + ".fSine2", prefix + "ns=2;s=Simulation Examples.Functions.Sine2", 760);
  setAddr(dpName + ".iRamp4", prefix + "ns=2;s=Simulation Examples.Functions.Ramp4", 756);

  // ---------------------------------------------------- 5. данные
  DebugN("");
  DebugN("--- 5. приход данных ---");
  DebugN("  ждём 25 с...");
  delay(25);

  int ok = 0;
  ok += check(dpName + ".bUser3", "bool  User3");
  ok += check(dpName + ".fSine2", "float Sine2");
  ok += check(dpName + ".iRamp4", "int   Ramp4");

  DebugN("");
  DebugN("  второй срез через 6 с:");
  delay(6);
  ok += check(dpName + ".bUser3", "bool  User3");
  ok += check(dpName + ".fSine2", "float Sine2");
  ok += check(dpName + ".iRamp4", "int   Ramp4");

  DebugN("");
  DebugN("=== ИТОГ: успешно ", ok, ", неудачно ", (6 - ok), " ===");
  DebugN("");
  DebugN("--- собранная строка адреса ---");
  DebugN("  префикс: ", prefix);
  DebugN("  пример:  ", prefix + "ns=2;s=Simulation Examples.Functions.User3");
  DebugN("--- объекты оставлены в проекте ---");
}

// ============================================================ helpers

// Удаляет точку данных и ждёт, пока она исчезнет.
void removeDp(string dp)
{
  if (dpExists(dp)) { dpDelete(dp); }
  for (int i = 1; i <= 20; i++)
  {
    if (!dpExists(dp)) { return; }
    delay(1);
  }
  DebugN("  ВНИМАНИЕ: точка ", dp, " не удалилась за 20 с");
}

// Удаляет тип точки данных.
//
// Существование типа проверяется НЕ через dpExists: имя типа не является
// именем точки данных, поэтому dpExists для него всегда FALSE и проверка
// ничего не значит. Правильная проверка - dpTypeGet, он возвращает != 0,
// когда типа нет.
//
// dpTypeDelete тоже асинхронный, поэтому удаление повторяется, пока тип
// действительно не исчезнет.
void removeDpt(string dpt)
{
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    dyn_dyn_string probeNames;
    dyn_dyn_int probeTypes;
    if (dpTypeGet(dpt, probeNames, probeTypes) != 0) { return; }   // типа нет
    dpTypeDelete(dpt);
    delay(1);
  }
  DebugN("  ВНИМАНИЕ: тип ", dpt, " не удалился за 30 попыток");
}

// Ищет первую точку данных заданного типа и возвращает её имя без
// подчёркивания и без префикса системы, то есть ровно то, что подставляется
// в строку адреса.
string findByType(string wanted)
{
  dyn_string all = dpNames("_**");
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpTypeName(all[i] + ".") != wanted) { continue; }

    // Например "System1:_kep" -> strpos даёт 8 -> substr с 9 даёт "kep"
    string full = all[i];
    int pos = strpos(full, "_");
    if (pos < 0) { return full; }
    return substr(full, pos + 1, 200);
  }
  return "";
}

// Сообщает, исчез ли тип точки данных. Проверка через dpTypeGet, а не
// через dpExists: имя типа не является именем точки данных.
void typeGone(string dpt)
{
  dyn_dyn_string n;
  dyn_dyn_int t;
  bool gone = (dpTypeGet(dpt, n, t) != 0);
  DebugN("  тип удалён:    ", gone);
}
void setAddr(string dpe, string address, int datatype)
{
  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", 3);
  int rc = dpSetTimedWait(0,
                    dpe + ":_address.._type",       DPCONFIG_PERIPH_ADDR_MAIN,
                    dpe + ":_address.._reference",  address,
                    dpe + ":_address.._active",     TRUE,
                    dpe + ":_address.._drv_ident",  "OPCUA",
                    dpe + ":_address.._datatype",   datatype,
                    dpe + ":_address.._direction",  DPATTR_ADDR_MODE_INPUT_POLL);

  string got;
  dpGet(dpe + ":_address.._reference", got);
  DebugN("  ", (rc == 0 && got == address) ? "ok  " : "ОШИБКА", " ", dpe, " -> ", got);
}

int check(string dpe, string what)
{
  bool bad;
  time t;
  dyn_anytype v;
  dpGet(dpe + ":_online.._bad",   bad);
  dpGet(dpe + ":_online.._stime", t);
  dpGet(dpe + ":_online.._value", v);
  bool hasData = (t != makeTime(1970, 1, 1, 3, 0, 0));
  DebugN("    ", (hasData && !bad) ? "данные" : "НЕТ   ", "  ", what, "  = ", v);
  if (hasData && !bad) { return 1; }
  return 0;
}