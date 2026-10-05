// 03_dpTypeCreate.ctl — демонстрация dpTypeCreate()
//
// Документация: docs/01-create.md#dptypecreate
//
// Что показывает пример:
//   * корневой элемент с типом DPEL_STRUCT обязателен;
//   * индекс в dyn_dyn_string/dyn_dyn_int — номер элемента при обходе в ширину,
//     а в ячейке лежит путь от корня (имя на позиции, равной глубине);
//   * вложенная структура в три уровня;
//   * проверка результата через dpTypeGet() и через dpNames() на реальной
//     точке данных.
//
// Проверено: CTL 3.18, проект prg_12_3.
//
// Запуск: разовый, blocking — нужен живой Event Manager.

main()
{
  dpdHeader("dpTypeCreate", "int dpTypeCreate(dyn_dyn_string elements, dyn_dyn_int types)");

  string dpt = "dpdemo_valve";

  dpdDropAllDpOfType(dpt);

  // Структура, которую создаём:
  //   valve
  //     setpoint        (структура)
  //       limits        (структура)
  //         upper       (float)
  //         lower       (float)
  //     state           (bool)
  //     tag             (string)
  // ВАЖНО: у dpTypeCreate() НЕТ параметра с именем типа. Имя типа берётся
  // из ПЕРВОГО элемента arrays, и корневой узел структуры называется тем же
  // именем. Если положить в names[1] другое слово, тип создастся под этим
  // другим именем (проверено на CTL 3.18, см. exp_dpt_name.ctl).
  dyn_dyn_string names;
  dyn_dyn_int types;

  // элемент 1: корень. Его имя = имя типа.
  names[1] = makeDynString(dpt);
  types[1] = makeDynInt(DPEL_STRUCT);

  // элемент 2: valve.setpoint — глубина 2
  names[2] = makeDynString("", "setpoint");
  types[2] = makeDynInt(0, DPEL_STRUCT);

  // элемент 3: valve.setpoint.limits — глубина 3
  names[3] = makeDynString("", "", "limits");
  types[3] = makeDynInt(0, 0, DPEL_STRUCT);

  // элемент 4: valve.setpoint.limits.upper — глубина 4
  names[4] = makeDynString("", "", "", "upper");
  types[4] = makeDynInt(0, 0, 0, DPEL_FLOAT);

  // элемент 5: valve.setpoint.limits.lower — глубина 4
  names[5] = makeDynString("", "", "", "lower");
  types[5] = makeDynInt(0, 0, 0, DPEL_FLOAT);

  // элемент 6: valve.state — глубина 2
  names[6] = makeDynString("", "state");
  types[6] = makeDynInt(0, DPEL_BOOL);

  // элемент 7: valve.tag — глубина 2
  names[7] = makeDynString("", "tag");
  types[7] = makeDynInt(0, DPEL_STRING);

  int rc = dpTypeCreate(names, types);
  DebugN("  dpTypeCreate() rc=", rc, "  lastError=", getLastError());
  dpdCheckRc("dpTypeCreate() вернул 0", rc);

  // dpTypeCreate() может вернуть 0 и не создать тип — проверяем через dpTypeGet().
  dyn_dyn_string backNames;
  dyn_dyn_int backTypes;
  int rcGet = dpTypeGet(dpt, backNames, backTypes);
  DebugN("  dpTypeGet() rc=", rcGet, "  элементов в структуре=", dynlen(backNames));
  dpdCheckRc("тип действительно создан (dpTypeGet() вернул 0)", rcGet);
  dpdCheck("в структуре семь элементов", dynlen(backNames) == 7);

  if (rcGet == 0 && dynlen(backNames) == 7)
  {
    // Пути читаются ровно те, что задавались: имя на позиции своей глубины.
    dpdCheck("путь элемента 4 = valve.setpoint.limits.upper",
             backNames[4][1] == "" && backNames[4][2] == "" &&
             backNames[4][3] == "" && backNames[4][4] == "upper");
    dpdCheck("тип элемента 4 == DPEL_FLOAT", backTypes[4][4] == DPEL_FLOAT);
    dpdCheck("тип элемента 6 == DPEL_BOOL", backTypes[6][2] == DPEL_BOOL);
    dpdCheck("тип элемента 7 == DPEL_STRING", backTypes[7][2] == DPEL_STRING);
  }

  // --- независимая проверка: создаём точку данных и смотрим её элементы ----
  string dpName = "dpdemo_valve_1";
  dpdDropDp(dpName);
  int rcCreate = dpCreate(dpName, dpt);
  DebugN("  dpCreate(", dpName, ", ", dpt, ") rc=", rcCreate);
  dpdCheckRc("dpCreate() по только что созданному типу", rcCreate);
  dpdCheck("точка данных создана", dpExists(dpName));

  // dpNames("dp.**") включает корень структуры "dp." — отсчитываем листья.
  dyn_string leaves = dpNames(dpName + ".**");
  DebugN("  dpNames(\"", dpName, ".**\") вернул ", dynlen(leaves), ":");
  for (int i = 1; i <= dynlen(leaves); i++)
  {
    DebugN("    ", leaves[i], "  тип=", dpElementType(leaves[i]));
  }
dpdCheck("структура содержит 7 узлов (корень + 6 элементов)",
           dynlen(leaves) == 7);

  // Документация рекомендует: последним элементом структуры делать простой тип
  // (bool/int/float), а не структуру — иначе чтение значений по ветке ведёт себя
  // непредсказуемо.
  //
  // dpNames("dp.**") возвращает ВСЕ узлы, включая промежуточные структуры, и
  // сортирует их по алфавиту — поэтому «последний узел» ничего не значит.
  // Полезная проверка: пустой структуры (структура без единого ребёнка)
  // в структуре быть не должно.
  //
  // ВАЖНО, две особенности CTL, найденные при отладке этого примера:
  //   * makeDynString(dyn_string, string) СКЛЕИВАЕТ аргументы, а не добавляет
  //     элемент. Чтобы дописать элемент в dyn_string, нужно присвоить по
  //     индексу: arr[dynlen(arr) + 1] = value;
  //   * корневой узел приходит из dpNames как "System1:dp." — с точкой на конце,
  //     и его нельзя считать листом. Признак корня — последний символ ".".
  int emptyStructs = 0;
  dyn_string leafList;
  for (int i = 1; i <= dynlen(leaves); i++)
  {
    string node = leaves[i];

    // Корень структуры: имя заканчивается точкой. У него есть дети, но
    // dpNames("System1:dp..*") из-за двойной точки ничего не находит.
    if (substr(node, strlen(node) - 1, 1) == ".") { continue; }

    if (dynlen(dpNames(node + ".*")) == 0)
    {
      leafList[dynlen(leafList) + 1] = node;
      if (dpElementType(node) == DPEL_STRUCT) { emptyStructs++; }
    }
  }
  DebugN("  листья (", dynlen(leafList), " шт.): ", leafList);
  DebugN("  пустых структур среди них: ", emptyStructs);
  dpdCheck("нет пустых структур — все листья простых типов", emptyStructs == 0);
  dpdCheck("листьев ровно четыре (upper, lower, state, tag)", dynlen(leafList) == 4);

  // --- teardown ------------------------------------------------------------
  dpdDropDp(dpName);
  dpdDropAllDpOfType(dpt);
  int rcDel = dpTypeDelete(dpt);
  DebugN("  teardown: dpTypeDelete(", dpt, ") rc=", rcDel);
  dpdCheckRc("тип удалён", rcDel);

  dpdSummary();
}

// ===========================================================================
// Помощники
// ===========================================================================
int dpdPass = 0;
int dpdFail = 0;

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

// Системные точки данных начинаются с подчёркивания — их не трогаем.
// dpNames() возвращает имена с префиксом системы ("System1:_mp_ANALOG1"),
// поэтому префикс системы нужно снять ДО проверки: системной является точка
// данных, если имя узла начинается с подчёркивания.
//
// В CTL 3.18 нет ни len(), ни indexOf(): есть strlen(), substr(), strpos().
// Проверено экспериментально.
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

void dpdDropDp(string dpName)
{
  if (dpdIsSystem(dpName)) { return; }
  if (dpExists(dpName))
  {
    int rc = dpDelete(dpName);
    DebugN("  teardown: dpDelete(", dpName, ") rc=", rc);
  }
}

// Удаляет все точки данных указанного типа. Нужно перед dpTypeDelete(),
// иначе тип удалить нельзя.
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