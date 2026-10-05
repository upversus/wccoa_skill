// 08_dpGetDpTypeRefs.ctl — демонстрация dpGetDpTypeRefs()
//
// Документация: docs/01-create.md#dpgetdptyprefs
//
// Что показывает пример:
//   * что такое ссылка на тип (DPEL_TYPEREF) и как она объявляется;
//   * как найти все ссылки ВНУТРИ типа точки данных;
//   * обратный поиск — в dpGetRefsToDpType(), см. 09_dpGetRefsToDpType.ctl.
//
// Пример полностью самодостаточный: сам создаёт базовый тип, тип со ссылкой и
// точку данных, затем удаляет всё за собой.
//
// Проверено: CTL 3.18, проект <проект стенда>.
//
// Запуск: разовый, blocking.

main()
{
  dpdHeader("dpGetDpTypeRefs", "dyn_dyn_string dpGetDpTypeRefs(string dpt)");

  string baseType = "dpdemo_base_float";
  string refType  = "dpdemo_with_ref";

  dpdCleanup(refType);
  dpdCleanup(baseType);

  // --- 1. базовый тип: корень-структура с одним элементом float -----------
  dyn_dyn_string bn;
  dyn_dyn_int bt;
  bn[1] = makeDynString(baseType);          // корень
  bt[1] = makeDynInt(DPEL_STRUCT);
  bn[2] = makeDynString("", "value");       // элемент 2: baseType.value
  bt[2] = makeDynInt(0, DPEL_FLOAT);

  int rcBase = dpTypeCreate(bn, bt);
  DebugN("  dpTypeCreate(\"", baseType, "\") rc=", rcBase, "  lastError=", getLastError());
  dpdCheckRc("базовый тип создан", rcBase);

  // --- 2. тип со ссылкой на базовый ----------------------------------------
  // Имя элемента-ссылки стоит на позиции глубины, а имя типа-ссылки — на
  // позиции ГЛУБЖЕ, и на позиции элемента в types стоит DPEL_TYPEREF.
  dyn_dyn_string rn;
  dyn_dyn_int rt;
  rn[1] = makeDynString(refType);
  rt[1] = makeDynInt(DPEL_STRUCT);
  rn[2] = makeDynString("", "regratio", baseType);
  //                        поз.1   поз.2       поз.3
  rt[2] = makeDynInt(0, DPEL_TYPEREF);
  //                 поз.1   поз.2

  int rcRef = dpTypeCreate(rn, rt);
  DebugN("  dpTypeCreate(\"", refType, "\") rc=", rcRef, "  lastError=", getLastError());
  dpdCheckRc("тип со ссылкой создан", rcRef);

  // Проверяем, что тип действительно создался (dpTypeCreate() может вернуть 0
  // и при фактическом отсутствии типа).
  dyn_dyn_string checkNames;
  dyn_dyn_int checkTypes;
  dpdCheck("тип со ссылкой существует (dpTypeGet() вернул 0)",
           dpTypeGet(refType, checkNames, checkTypes) == 0);

  // --- 3. точка данных по типу со ссылкой -----------------------------------
  string dpName = "dpdemo_ref_1";
  dpdDropDp(dpName);
  int rcDp = dpCreate(dpName, refType);
  DebugN("  dpCreate(", dpName, ") rc=", rcDp);
  dpdCheckRc("точка данных создана", rcDp);
  dpdCheck("точка данных существует", dpExists(dpName));

  // --- 4. ищем ссылки внутри типа со ссылкой -------------------------------
  dyn_dyn_string refs = dpGetDpTypeRefs(refType);
  DebugN("  dpGetDpTypeRefs(\"", refType, "\") вернул ", dynlen(refs), " строк(и)");
  for (int i = 1; i <= dynlen(refs); i++)
  {
    DebugN("    [", i, "] ", refs[i]);
  }
  dpdCheck("в типе со ссылкой найдена хотя бы одна ссылка", dynlen(refs) > 0);

  // --- 5. в базовом типе ссылок быть не должно -----------------------------
  dyn_dyn_string noRefs = dpGetDpTypeRefs(baseType);
  DebugN("  dpGetDpTypeRefs(\"", baseType, "\") вернул ", dynlen(noRefs), " строк(и)");
  dpdCheck("в базовом типе ссылок нет", dynlen(noRefs) == 0);

  // --- 6. несуществующий тип → пустой результат, а не исключение ----------
  dyn_dyn_string bad = dpGetDpTypeRefs("dpdemo_no_such_type");
  DebugN("  dpGetDpTypeRefs(\"dpdemo_no_such_type\") вернул ", dynlen(bad),
         " строк(и)  lastError=", getLastError());
  dpdCheck("несуществующий тип даёт пустой dyn_dyn_string", dynlen(bad) == 0);

  // --- teardown ------------------------------------------------------------
  dpdDropDp(dpName);
  dpdCleanup(refType);
  dpdCleanup(baseType);

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

// Удаляет точку данных типа dpt, затем сам тип. Порядок обязателен:
// dpTypeDelete() не работает, пока есть живые точки данных.
void dpdCleanup(string dpt)
{
  if (dpdIsSystem(dpt)) { return; }
  dyn_string names = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(names); i++)
  {
    if (dpdIsSystem(names[i])) { continue; }
    int rc = dpDelete(names[i]);
    DebugN("  teardown: dpDelete(", names[i], ") rc=", rc);
  }
  int rc = dpTypeDelete(dpt);
  DebugN("  teardown: dpTypeDelete(", dpt, ") rc=", rc);
}