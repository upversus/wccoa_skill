// full_cycle.ctl — полный цикл жизни точки данных на одном скрипте.
//
// Сценарий проверки:
//   1) создать тип точки данных, элементы которого float, bool, int;
//   2) создать точку данных этого типа;
//   3) задать значения через dpSet();
//   4) прочитать и проверить значения через dpGet();
//   5) удалить точку данных;
//   6) удалить тип точки данных.
//
// Проверено: CTL 3.18, проект prg_12_3, 2026-10-04 — 15 PASS, 0 FAIL.
//
// Два неочевидных момента, найденных экспериментально (см. docs/01-create.md):
//   * у типа точки данных обязателен корневой элемент с типом DPEL_STRUCT;
//   * индекс в dyn_dyn_string/dyn_dyn_int — это НЕ уровень вложенности,
//     а номер элемента при обходе в ширину; в ячейке лежит путь от корня.
//
// Запуск (нужен живой Event Manager — dpCreate() и dpDelete() blocking):
//   .\run-ctl.ps1 -Script .\00-scenario\full_cycle.ctl

main()
{
  DebugN("=== Полный цикл точки данных ===");

  string dpt = "dpdemo_triple";
  string dpName = "dpdemo_triple_1";

  // Значения, которые задаём и потом проверяем.
  float wantFloat = 42.5;
  bool  wantBool  = true;
  int   wantInt   = -7;

  // ------------------------------------------------------------------ (1)
  DebugN("(1) создаём тип точки данных ", dpt);

  // Убираем возможные остатки предыдущего прогона.
  cleanupDpAndType(dpt);

  // Индекс массива = номер элемента при обходе в ширину.
  // В ячейке — путь от корня: имя стоит на позиции, равной глубине,
  // выше — пустые строки. В types на этих позициях стоят 0.
  dyn_dyn_string names;
  dyn_dyn_int types;

  // элемент 1: корень структуры
  names[1] = makeDynString(dpt);
  types[1] = makeDynInt(DPEL_STRUCT);

  // элемент 2: fValue, глубина 2
  names[2] = makeDynString("", "fValue");
  types[2] = makeDynInt(0, DPEL_FLOAT);

  // элемент 3: bFlag, глубина 2
  names[3] = makeDynString("", "bFlag");
  types[3] = makeDynInt(0, DPEL_BOOL);

  // элемент 4: iCount, глубина 2
  names[4] = makeDynString("", "iCount");
  types[4] = makeDynInt(0, DPEL_INT);

  int rcType = dpTypeCreate(names, types);
  DebugN("    dpTypeCreate() rc=", rcType, " lastError=", getLastError());
  check("dpTypeCreate() вернул 0", rcType == 0);

  // dpTypeCreate() может вернуть 0 и не создать тип (например, без корневой
  // структуры). Поэтому единственная надёжная проверка — dpTypeGet().
  dyn_dyn_string backNames;
  dyn_dyn_int backTypes;
  int rcGet = dpTypeGet(dpt, backNames, backTypes);
  DebugN("    dpTypeGet() rc=", rcGet, " элементов в структуре=", dynlen(backNames));
  check("тип действительно создан (dpTypeGet() вернул 0)", rcGet == 0);
  check("в структуре четыре элемента", dynlen(backNames) == 4);

  if (rcGet == 0 && dynlen(backNames) == 4)
  {
    check("корень типа — структура", backTypes[1][1] == DPEL_STRUCT);
    check("порядок и набор имён сохранены",
          backNames[2][2] == "fValue" && backNames[3][2] == "bFlag" && backNames[4][2] == "iCount");
    check("типы элементов сохранены",
          backTypes[2][2] == DPEL_FLOAT && backTypes[3][2] == DPEL_BOOL && backTypes[4][2] == DPEL_INT);
  }

  // ------------------------------------------------------------------ (2)
  DebugN("(2) создаём точку данных ", dpName, " типа ", dpt);

  int rcCreate = dpCreate(dpName, dpt);
  DebugN("    dpCreate() rc=", rcCreate, " lastError=", getLastError());
  check("dpCreate() вернул 0", rcCreate == 0);

  // ГЛАВНАЯ проверка создания: dpCreate() может вернуть 0 и не создать точку.
  // Надёжен только dpExists().
  bool exists = dpExists(dpName);
  DebugN("    dpExists() = ", exists);
  check("точка данных действительно создана", exists);
  check("тип созданной точки данных совпадает с заданным",
        dpTypeName(dpName + ".") == dpt);

  // Проверяем, что элементы реально появились, и какие у них типы.
  // dpNames() — независимый от dpTypeGet() источник истины.
  //
  // ВАЖНО: dpNames("dp.**") возвращает 4 элемента, а не 3 — в выдачу входит
  // и корень структуры "dp." (имя заканчивается точкой). Листья — те, где
  // имени НЕ предшествует точка в конце пути.
  dyn_string all = dpNames(dpName + ".**");
  DebugN("    dpNames(\"", dpName, ".**\") вернул ", dynlen(all), ":");
  for (int i = 1; i <= dynlen(all); i++)
  {
    DebugN("      ", all[i], "  тип=", dpElementType(all[i]));
  }
  dyn_string leaves = dpNames(dpName + ".*");
  DebugN("    без корня (dpNames(\"", dpName, ".*\")): ", dynlen(leaves));
  check("в точке данных три листа", dynlen(leaves) == 3);
  check("корневой элемент тоже входит в \"**\"", dynlen(all) == 4);

  // ------------------------------------------------------------------ (3)
  DebugN("(3) задаём значения через dpSet()");

  // Явно указываем конфиг и атрибут. Без этого dpSet() пишет в _original.._value
  // по умолчанию, а dpGet() читает _online.._value — и значения «разъезжаются».
  int rcSetF = dpSet(dpName + ".fValue:_original.._value", wantFloat);
  DebugN("    dpSet(fValue) rc=", rcSetF, " lastError=", getLastError());
  check("dpSet() для float вернул 0", rcSetF == 0);

  int rcSetB = dpSet(dpName + ".bFlag:_original.._value", wantBool);
  DebugN("    dpSet(bFlag) rc=", rcSetB);
  check("dpSet() для bool вернул 0", rcSetB == 0);

  int rcSetI = dpSet(dpName + ".iCount:_original.._value", wantInt);
  DebugN("    dpSet(iCount) rc=", rcSetI);
  check("dpSet() для int вернул 0", rcSetI == 0);

  // ------------------------------------------------------------------ (4)
  DebugN("(4) читаем и проверяем значения через dpGet()");

  float gotFloat;
  bool  gotBool;
  int   gotInt;

  int rcReadF = dpGet(dpName + ".fValue:_original.._value", gotFloat);
  DebugN("    dpGet(fValue) rc=", rcReadF, " значение=", gotFloat);
  check("dpGet() для float вернул 0", rcReadF == 0);
  check("float прочитан верно", gotFloat == wantFloat);

  int rcReadB = dpGet(dpName + ".bFlag:_original.._value", gotBool);
  DebugN("    dpGet(bFlag) rc=", rcReadB, " значение=", gotBool);
  check("dpGet() для bool вернул 0", rcReadB == 0);
  check("bool прочитан верно", gotBool == wantBool);

  int rcReadI = dpGet(dpName + ".iCount:_original.._value", gotInt);
  DebugN("    dpGet(iCount) rc=", rcReadI, " значение=", gotInt);
  check("dpGet() для int вернул 0", rcReadI == 0);
  check("int прочитан верно", gotInt == wantInt);

  // Типы элементов точки данных, а не только DPT.
  DebugN("    типы элементов: fValue=", dpElementType(dpName + ".fValue"),
         " bFlag=", dpElementType(dpName + ".bFlag"),
         " iCount=", dpElementType(dpName + ".iCount"));
  check("тип элемента fValue == DPEL_FLOAT",
        dpElementType(dpName + ".fValue") == DPEL_FLOAT);
  check("тип элемента bFlag == DPEL_BOOL",
        dpElementType(dpName + ".bFlag") == DPEL_BOOL);
  check("тип элемента iCount == DPEL_INT",
        dpElementType(dpName + ".iCount") == DPEL_INT);

  // ------------------------------------------------------------------ (5)
  DebugN("(5) удаляем точку данных");

  int rcDel = dpDelete(dpName);
  DebugN("    dpDelete() rc=", rcDel, " lastError=", getLastError());
  check("dpDelete() вернул 0", rcDel == 0);
  check("точка данных больше не существует", !dpExists(dpName));

  // ------------------------------------------------------------------ (6)
  DebugN("(6) удаляем тип точки данных");

  // Тип удаляется, только когда живых точек данных нет — порядок обязателен.
  int rcDelType = dpTypeDelete(dpt);
  DebugN("    dpTypeDelete() rc=", rcDelType, " lastError=", getLastError());
  check("dpTypeDelete() вернул 0", rcDelType == 0);

  dyn_string left = dpTypes(dpt);
  DebugN("    dpTypes(\"", dpt, "\") вернул ", dynlen(left), " записей");
  check("тип больше не выводится в dpTypes()", dynlen(left) == 0);

  DebugN("=== ИТОГ: PASS=", pass, " FAIL=", fail, " ===");
}

// ===========================================================================
// Вспомогательные функции
// ===========================================================================
int pass = 0;
int fail = 0;

void check(string what, bool ok)
{
  if (ok)
  {
    pass++;
    DebugN("  PASS  ", what);
  }
  else
  {
    fail++;
    DebugN("  FAIL  ", what, "  lastError=", getLastError());
  }
}

// Имя системной точки данных или типа начинается с подчёркивания.
// Такое нельзя ни создавать, ни удалять, ни изменять.
bool isSystemName(string name)
{
  if (name == "") { return false; }
  return substr(name, 0, 1) == "_";
}

// Удаляет все точки данных типа dpt, затем сам тип. Порядок обязателен.
void cleanupDpAndType(string dpt)
{
  if (isSystemName(dpt))
  {
    DebugN("  ОТКАЗ: ", dpt, " — системное имя, не трогаю");
    return;
  }
  dyn_string names = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(names); i++)
  {
    if (isSystemName(names[i]))
    {
      continue;
    }
    dpDelete(names[i]);
  }
  dpTypeDelete(dpt);
}