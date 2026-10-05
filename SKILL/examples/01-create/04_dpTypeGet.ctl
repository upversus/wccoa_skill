// 04_dpTypeGet.ctl — демонстрация dpTypeGet()
//
// Документация: docs/01-create.md#dptypeget
//
// Что показывает пример:
//   * структура типа точки данных читается в те же форматы, которые принимает
//     dpTypeCreate() — то есть её можно скопировать 1:1;
//   * необязательный параметр includeSubTypes;
//   * поведение на несуществующем типе.
//
// Запуск: разовый, неблокирующий.

main()
{
  dpdHeader("dpTypeGet", "int dpTypeGet(string name, dyn_dyn_string &elements, dyn_dyn_int &types[, bool includeSubTypes = FALSE])");

  string dpt = dpdPickType();
  if (dpt == "")
  {
    DebugN("  SKIP  в проекте нет ни одного DPT с точками данных");
    dpdSummary();
    return;
  }
  DebugN("  разбираем тип точки данных: ", dpt);

  // --- 1. чтение структуры --------------------------------------------------
  dyn_dyn_string names;
  dyn_dyn_int types;
  int rc = dpTypeGet(dpt, names, types);

  DebugN("  dpTypeGet() rc=", rc, "  lastError=", getLastError());
  dpdCheckRc("dpTypeGet() вернул 0", rc);

  DebugN("  уровней в names: ", dynlen(names), ", в types: ", dynlen(types));
  dpdCheck("names непустой", dynlen(names) > 0);
  dpdCheck("длины names и types совпадают", dynlen(names) == dynlen(types));

  // --- 2. содержимое первого уровня ----------------------------------------
  // names[1] — уровень 1. Элементы этого массива — элементы верхнего уровня DPT.
  dyn_string topLevel = names[1];
  DebugN("  элементы верхнего уровня: ", topLevel);
  dpdCheck("верхний уровень структуры непустой", dynlen(topLevel) > 0);

  // --- 3. типы элементов верхнего уровня -----------------------------------
  // types[1] — типы уровня 1. Последний ненулевой элемент каждой строки —
  // собственно тип последнего элемента ветки.
  dyn_int topTypes = types[1];
  DebugN("  типы верхнего уровня: ", topTypes);
  dpdCheck("типы верхнего уровня непустые", dynlen(topTypes) > 0);

  // --- 4. согласованность: столько же имён, сколько типов -----------------
  dpdCheck("число имён верхнего уровня == числу типов",
           dynlen(topLevel) == dynlen(topTypes));

  // --- 5. структуру можно скормить обратно в dpTypeCreate() ----------------
  // Это и есть главная ценность: names/types — тот же формат, что на входе.
  DebugN("  names можно передать обратно в dpTypeCreate() без преобразований");

  // --- 6. includeSubTypes --------------------------------------------------
  dyn_dyn_string namesSub;
  dyn_dyn_int typesSub;
  int rcSub = dpTypeGet(dpt, namesSub, typesSub, true);
  DebugN("  dpTypeGet(..., TRUE) rc=", rcSub, "  уровней: ", dynlen(namesSub));
  dpdCheckRc("includeSubTypes = TRUE отработал без ошибки", rcSub);
  dpdCheck("includeSubTypes не даёт меньше уровней, чем FALSE",
           dynlen(namesSub) >= dynlen(names));

  // --- 7. несуществующий тип ------------------------------------------------
  dyn_dyn_string namesBad;
  dyn_dyn_int typesBad;
  int rcBad = dpTypeGet("dpdemo_no_such_type", namesBad, typesBad);
  DebugN("  dpTypeGet(\"dpdemo_no_such_type\") rc=", rcBad,
         "  lastError=", getLastError());
  dpdCheck("несуществующий тип даёт rc = -1", rcBad == -1);

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