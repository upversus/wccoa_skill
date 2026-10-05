// 01_dpCreate.ctl — демонстрация dpCreate()
//
// Документация: docs/01-create.md#dpcreate
// Проверено: CTL 3.18, проект <проект стенда>
//
// Смысл примера — показать главную ловушку dpCreate(): функция может вернуть 0
// (успех) и при этом НЕ создать точку данных. Поэтому единственная надёжная
// проверка — пара dpCreate() + dpExists().
//
// Запуск: разово, обязательно при ЖИВОМ Event Manager (функция blocking).

main()
{
  dpdHeader("dpCreate", "int dpCreate(string dpname, string dptype [, int sysnum, unsigned dpNo])");

  string dpt = dpdPickType();
  if (dpt == "")
  {
    DebugN("  SKIP  в проекте нет ни одного DPT с точками данных — нечего создавать");
    dpdSummary();
    return;
  }
  DebugN("  используем тип точки данных: ", dpt);

  string dpName = "dpdemo_create_" + dpt;

  // --- teardown от предыдущего прогона ------------------------------------
  dpdDropDp(dpName);

  // --- 1. dpExists() на несуществующей точке -------------------------------
  bool before = dpExists(dpName);
  DebugN("  до создания: dpExists(", dpName, ") = ", before);
  dpdCheck("точки данных до создания нет", !before);

  // --- 2. создание --------------------------------------------------------
  int rc = dpCreate(dpName, dpt);
  DebugN("  dpCreate(", dpName, ", ", dpt, ") rc=", rc, "  lastError=", getLastError());
  dpdCheckRc("dpCreate() вернул 0", rc);

  // --- 3. ГЛАВНАЯ ПРОВЕРКА: точка действительно появилась? -----------------
  bool after = dpExists(dpName);
  DebugN("  после создания: dpExists(", dpName, ") = ", after);
  dpdCheck("точка данных создана (dpExists() == true)", after);

  // --- 4. повторный вызов на существующей точке — не ошибка ----------------
  // Документация: "If a datapoint with the specified name already exists, the
  // call of the function dpCreate() has no effect."
  int rc2 = dpCreate(dpName, dpt);
  DebugN("  повторный dpCreate() rc=", rc2, "  lastError=", getLastError());
  dpdCheck("повторный dpCreate() тоже вернул 0 (no-op, не ошибка)", rc2 == 0);

  // --- 5. тип созданной точки данных совпадает с запрошенным --------------
  string actualType = dpTypeName(dpName + ".");
  DebugN("  dpTypeName(", dpName, ".) = '", actualType, "'");
  dpdCheck("тип созданной точки данных == запрошенный", actualType == dpt);

  // --- teardown ------------------------------------------------------------
  dpdDropDp(dpName);
  dpdCheck("точка данных удалена", !dpExists(dpName));

  dpdSummary();
}

// ===========================================================================
// Помощники — самодостаточный блок, идентичен examples/_lib.ctl
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

void dpdDropDp(string dpName)
{
  if (dpExists(dpName))
  {
    int rc = dpDelete(dpName);
    DebugN("  teardown: dpDelete(", dpName, ") rc=", rc);
  }
}