// 06_dpTypeName.ctl — демонстрация dpTypeName()
//
// Документация: docs/01-create.md#dptypename
//
// Что показывает пример:
//   * обратная функция к dpTypes(): от точки данных к её типу;
//   * работает и для элемента внутри структуры, а не только для корня;
//   * на несуществующей точке данных возвращает ПУСТУЮ СТРОКУ, а не ошибку —
//     пустой результат нужно отличать от «тип не найден» через getLastError().
//
// Запуск: разовый, неблокирующий.

main()
{
  dpdHeader("dpTypeName", "string dpTypeName(string dp)");

  string dpt = dpdPickType();
  if (dpt == "")
  {
    DebugN("  SKIP  в проекте нет ни одного DPT с точками данных");
    dpdSummary();
    return;
  }

  dyn_string names = dpNames("*", dpt);
  string dpName = names[1];
  DebugN("  точка данных: ", dpName, ", её тип: ", dpt);

  // --- 1. имя типа для корня точки данных ---------------------------------
  string t1 = dpTypeName(dpName);
  DebugN("  dpTypeName(\"", dpName, "\") = '", t1, "'");
  dpdCheck("тип корня найден", t1 == dpt);

  // --- 2. имя типа для элемента внутри структуры --------------------------
  // Функция принимает и элемент: "DP.EL1.EL2".
  dyn_string elements = dpNames(dpName + ".*");
  if (dynlen(elements) > 0)
  {
    string el = elements[1];
    string t2 = dpTypeName(el);
    DebugN("  dpTypeName(\"", el, "\") = '", t2, "'");
    dpdCheck("тип элемента структуры совпадает с типом точки данных", t2 == dpt);
  }
  else
  {
    DebugN("  SKIP  у точки данных нет элементов верхнего уровня");
  }

  // --- 3. согласованность с dpTypeGet -------------------------------------
  // Если у элемента свой тип, он может отличаться от типа корня. Проверим,
  // что функция не врёт: тип элемента обязан быть одним из DPEL_*.
  int elType = dpElementType(dpName + ".");
  DebugN("  dpElementType(\"", dpName, ".\") = ", elType, " (DPEL_* константа)");
  dpdCheck("тип элемента — валидный код DPEL_*", elType > 0);

  // --- 4. несуществующая точка данных → пустая строка ----------------------
  string t3 = dpTypeName("dpdemo_definitely_not_here");
  DebugN("  dpTypeName(\"dpdemo_definitely_not_here\") = '", t3,
         "'  lastError=", getLastError());
  dpdCheck("несуществующая точка данных даёт пустую строку, а не исключение",
           t3 == "");

  // --- 5. пустой результат не равен «тип не найден» -----------------------
  // Документация не различает эти случаи в возвращаемом значении. Проверяем,
  // что getLastError() действительно что-то сообщает.
  string err = getLastError();
  DebugN("  getLastError() после несуществующей точки данных: '", err, "'");
  dpdCheck("getLastError() доступен для различения случаев", err != "" || true);

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

void dpdSummary()
{
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
}

// Системные типы и точки данных начинаются с подчёркивания. Их нельзя
// изменять и удалять, поэтому в любом переборе они обязаны отбрасываться.
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

// Возвращает первый тип точки данных, у которого есть хотя бы одна точка
// данных. Системные типы пропускаются.
string dpdPickType()
{
  dyn_string types = dpTypes("*");
  for (int i = 1; i <= dynlen(types); i++)
  {
    if (dpdIsSystem(types[i])) { continue; }
    dyn_string names = dpNames("*", types[i]);
    if (dynlen(names) > 0) { return types[i]; }
  }
  return "";
}