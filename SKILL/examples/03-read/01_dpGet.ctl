// 01_dpGet.ctl - чтение значений и атрибутов конфигов.
//
// Проверяет dpGet() на собственных объектах, ничего не завися от других
// примеров:
//
//   * чтение значений разных типов: float, int, bool, string;
//   * чтение нескольких пар в одном вызове;
//   * чтение списка элементов через dyn_string + dyn_anytype;
//   * проверка существования конфига по его атрибуту _type;
//   * атрибуты конфига _online;
//   * различие _original и _online - важная ловушка;
//   * подстановка конфига по умолчанию;
//   * несколько атрибутов конфига _alert_hdl.
//
// Свойства dpGet():
//   * возвращает 0 при успехе и -1 при сбое;
//   * проверяет существование ЭЛЕМЕНТА, но не конфига;
//   * по умолчанию читает _online.._value;
//   * ОДИН вызов - ОДНА система: точки разных систем в одном dpGet()
//     не работают, даёт "PARAM,SEVERE, 175";
//   * если первый аргумент - массив, переменная обязана быть dyn_anytype;
//   * при росте числа пар производительность падает квадратично;
//   * только чтение, побочных эффектов нет.
//
// Три ловушки, найденные на стенде:
//
//   1. Путь к конфигу КОРНЕВОГО элемента требует точки: "dp.:_online.._type".
//      Без точки получается "dp._online.._type" и dpGet отвечает
//      "DP does not exist". Пример из документации - "ExampleDP_Arg1.:_default.._type".
//
//   2. У корневого элемента типа struct конфига _online НЕТ: корень не несёт
//      значения. Проверять конфиг нужно на ЭЛЕМЕНТЕ со значением.
//
//   3. ГЛАВНОЕ. Признак существования конфига через _type НЕ УНИВЕРСАЛЕН.
//      Для _address тип материализован, и _type честно даёт 16.
//      Для _online _type равен 0 ДАЖЕ ПРИ НАСТРОЕННОМ конфиГЕ, который
//      отдаёт значения. Общий признак - читать атрибут данных конфига
//      (_stime или _value) и смотреть rc. См. пункт 4.
//
// Проверено: CTL 3.18, проект <проект стенда>.
// Объекты создаются и удаляются самим скриптом.

int OK = 0;
int BAD = 0;

string DPT = "rdGet_t";
string DP  = "rdGet";

main()
{
  DebugN("=== dpGet(): чтение значений и атрибутов ===");

  makeObjects();

  // ------------------------------------------- 1. значения разных типов
  DebugN("");
  DebugN("--- 1. Чтение значений по типам ---");

  float  fv;
  int    iv;
  bool   bv;
  string sv;

  check(dpGet(DP + ".fVal", fv) == 0, "float прочитан",  fv);
  check(dpGet(DP + ".iVal", iv) == 0, "int   прочитан",  iv);
  check(dpGet(DP + ".bVal", bv) == 0, "bool  прочитан",  bv);
  check(dpGet(DP + ".sVal", sv) == 0, "string прочитан", sv);

  // ---------------------------------------- 2. несколько пар за один раз
  DebugN("");
  DebugN("--- 2. Несколько пар в одном вызове ---");
  DebugN("  Один вызов - одна система. Точки разных систем в одном dpGet()");
  DebugN("  дают PARAM,SEVERE, 175. Рост числа пар падает квадратично.");

  float  f2;
  int    i2;
  bool   b2;
  string s2;
  int rcMulti = dpGet(DP + ".fVal", f2,
                      DP + ".iVal", i2,
                      DP + ".bVal", b2,
                      DP + ".sVal", s2);
  check(rcMulti == 0, "четыре пары одним вызовом",
        f2 + " / " + i2 + " / " + b2 + " / " + s2);

  // ------------------------------- 3. список элементов одним вызовом
  DebugN("");
  DebugN("--- 3. Список элементов: dyn_string + dyn_anytype ---");
  DebugN("  Если первый аргумент - массив, переменная обязана быть dyn_anytype.");

  dyn_string items = makeDynString(DP + ".fVal", DP + ".iVal", DP + ".bVal", DP + ".sVal");
  dyn_anytype bulk;
  int rcBulk = dpGet(items, bulk);
  DebugN("  rc=", rcBulk, "  элементов прочитано: ", dynlen(bulk));
  for (int i = 1; i <= dynlen(bulk); i++)
  {
    DebugN("     ", i, ") ", bulk[i]);
  }
  check((rcBulk == 0) && (dynlen(bulk) == 4),
        "прочитаны все четыре элемента списком", dynlen(bulk));

  // ------------------------- 4. существование конфига по атрибуту _type
  DebugN("");
  DebugN("--- 4. Проверка существования конфига ---");
  DebugN("  dpGet() проверяет элемент, но НЕ конфиг.");
  DebugN("");
  DebugN("  ВНИМАНИЕ. Документация предлагает признак _type: 0 - конфига нет,");
  DebugN("  ненулевое значение - есть. Проверяем.");
  DebugN("");
  DebugN("  У _address тип материализован, поэтому признак честно работает.");
  DebugN("  У _online - нет: _type равен 0 ДАЖЕ ПРИ НАСТРОЕННОМ конфиГЕ,");
  DebugN("  который при этом отдаёт значения. Значит как общий признак _type");
  DebugN("  не годится, и обобщать правило нельзя.");
  DebugN("");
  DebugN("  Что _type различает на самом деле - известно ли имя конфига системе:");
  DebugN("     _alert_class  rc=0   - имя конфига системе известно, но не настроено");
  DebugN("     _nonsense_cfg rc=-1  - имя не существует вовсе");
  DebugN("  То есть _type отвечает на вопрос \"известно ли имя\", а не настроен ли конфиг.");
  DebugN("");
  DebugN("  РАБОТАЮЩИЙ признак - читать атрибут данных конфига и смотреть rc:");

  int  typeOnly;
  time stimeOnline;
  int rcTypeOnly = dpGet(DP + ".fVal:_online.._type",   typeOnly);
  int rcStime    = dpGet(DP + ".fVal:_online.._stime",  stimeOnline);
  DebugN("     fVal:_online.._type    rc=", rcTypeOnly, "  значение=", typeOnly, "   <- бесполезно");
  DebugN("     fVal:_online.._stime   rc=", rcStime,   "  значение=", stimeOnline, "   <- признак есть");
  check(rcStime == 0, "существующий конфиг _online найден по _stime", rcStime);

  int  absentType;
  time absentStime;
  int rcAbsentType  = dpGet(DP + ".fVal:_alert_class.._type",  absentType);
  int rcAbsentStime = dpGet(DP + ".fVal:_alert_class.._stime", absentStime);
  DebugN("     fVal:_alert_class.._type    rc=", rcAbsentType,  "  имя известно системе");
  DebugN("     fVal:_alert_class.._stime   rc=", rcAbsentStime, "   <- признака нет");
  check(rcAbsentStime == -1, "отсутствующий конфиг _alert_class отвергнут по _stime", rcAbsentStime);

  // --------------------------------------------- 5. атрибуты конфига
  DebugN("");
  DebugN("--- 5. Атрибуты конфига _online ---");

  time  stime;
  bool  isBad;
  int   status;
  float onlineVal;

  dpGet(DP + ".fVal:_online.._stime",    stime);
  dpGet(DP + ".fVal:_online.._bad",      isBad);
  dpGet(DP + ".fVal:_online.._status",   status);
  dpGet(DP + ".fVal:_online.._value",    onlineVal);
  DebugN("  _stime=", stime, "  _bad=", isBad, "  _status=", status);
  DebugN("  _value=", onlineVal);
  check(stime != makeTime(1970, 1, 1, 3, 0, 0), "_stime заполнен", stime);
  check(!isBad, "_bad = FALSE", isBad);
  check(status != 0, "_status ненулевой", status);

  // ------------------------------- 6. ловушка _original против _online
  DebugN("");
  DebugN("--- 6. Ловушка: dpSet пишет в _original, dpGet читает _online ---");
  DebugN("  Поэтому подставленные значения расходятся, и конфиг надо указывать явно.");

  float written;
  dpSet(DP + ".fVal", 123.5);
  dpGet(DP + ".fVal:_original.._value", written);
  float defaultRead = readPlain(DP + ".fVal");
  DebugN("  после dpSet('", DP, ".fVal', 123.5):");
  DebugN("     dpGet('_original.._value') = ", written);
  DebugN("     dpGet('dp.') по умолчанию   = ", defaultRead);
  check(written == 123.5, "записанное значение лежит в _original", written);

  // --------------------------- 7. подстановка конфига по умолчанию
  DebugN("");
  DebugN("--- 7. Подстановка по умолчанию ---");
  DebugN("  Без указания конфига dpGet() читает _online.._value.");

  float withDefault = readPlain(DP + ".fVal");
  float explicitOn  = 0.0;
  dpGet(DP + ".fVal:_online.._value", explicitOn);
  DebugN("  без конфига = ", withDefault, "   с конфигом = ", explicitOn);
  check(withDefault == explicitOn,
        "подстановка даёт то же, что и явный _online", withDefault);

  // ------------------------------------------- 8. атрибуты _alert_hdl
  DebugN("");
  DebugN("--- 8. Конфиг _alert_hdl ---");
  DebugN("  Самый богатый конфиг по числу атрибутов. На новой точке обработка");
  DebugN("  тревог не настроена, поэтому ожидаем пустые значения.");

  int   ahType;
  int   ahRanges;
  bool  ahActive;
  int rcAh = dpGet(DP + ".fVal:_alert_hdl.._type", ahType);
  dpGet(DP + ".fVal:_alert_hdl.._num_ranges", ahRanges);
  dpGet(DP + ".fVal:_alert_hdl.._active",     ahActive);
  DebugN("  rc=", rcAh, "  _type=", ahType, "  _num_ranges=", ahRanges, "  _active=", ahActive);
  check(rcAh == 0, "атрибуты _alert_hdl читаются без сбоя", rcAh);

  DebugN("");
  DebugN("=== ИТОГ: успешно ", OK, ", неудачно ", BAD, " ===");

  cleanObjects();
  DebugN("--- объекты удалены скриптом ---");
  DebugN("=== конец ===");
}

// ---------------------------------------------------------------- helpers

// Чтение с подставленным конфигом - отдельная функция, чтобы не смешивать
// её с проверкой возвращаемого значения.
float readPlain(string dpe)
{
  float v;
  dpGet(dpe, v);
  return v;
}

void check(bool ok, string what, dyn_anytype extra)
{
  if (ok) { OK++;  DebugN("  PASS  ", what, "   ", extra); }
  else    { BAD++; DebugN("  FAIL  ", what, "   ", extra); }
}

void makeObjects()
{
  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(DPT);            types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "fVal");     types[2] = makeDynInt(0, DPEL_FLOAT);
  names[3] = makeDynString("", "iVal");     types[3] = makeDynInt(0, DPEL_INT);
  names[4] = makeDynString("", "bVal");     types[4] = makeDynInt(0, DPEL_BOOL);
  names[5] = makeDynString("", "sVal");     types[5] = makeDynInt(0, DPEL_STRING);

  cleanObjects();
  int rcT = dpTypeCreate(names, types);
  int rcD = dpCreate(DP, DPT);
  DebugN("  тип ", DPT, " rc=", rcT, ", точка ", DP, " rc=", rcD);
  DebugN("  элементы: fVal (float), iVal (int), bVal (bool), sVal (string)");

  // Наполняем значения, чтобы было что читать
  dpSet(DP + ".fVal", 42.5);
  dpSet(DP + ".iVal", -17);
  dpSet(DP + ".bVal", TRUE);
  dpSet(DP + ".sVal", "строка");
}

void cleanObjects()
{
  if (dpExists(DP)) { dpDelete(DP); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(DP)) { break; }
    delay(1);
  }
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    dyn_dyn_string pn;
    dyn_dyn_int pt;
    if (dpTypeGet(DPT, pn, pt) != 0) { break; }   // типа нет
    dpTypeDelete(DPT);
    delay(1);
  }
}