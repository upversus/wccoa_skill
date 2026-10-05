// 09_dpGetRefsToDpType.ctl — демонстрация dpGetRefsToDpType()
//
// Документация: docs/01-create.md#dpgetrefstodptype
//
// Что показывает пример: ОБРАТНЫЙ поиск — какие типы и точки данных ссылаются
// на указанный тип. Парная функция к dpGetDpTypeRefs()
// (см. 08_dpGetDpTypeRefs.ctl), который ищет ссылки ВНУТРИ типа.
//
// Пример самодостаточный: создаёт базовый тип, тип со ссылкой и точку данных,
// проверяет, что обратный поиск находит именно то, что ожидалось, и убирает
// за собой.
//
// Проверено: CTL 3.18, проект <проект стенда>.
//
// Запуск: разовый, неблокирующий (dpNames внутри — blocking).

main()
{
  dpdHeader("dpGetRefsToDpType", "dyn_dyn_string dpGetRefsToDpType(string reference)");

  string baseType = "dpdemo_base_float";
  string refType  = "dpdemo_with_ref";

  dpdCleanup(refType);
  dpdCleanup(baseType);

  // --- 1. базовый тип: корень-структура с элементом float ------------------
  dyn_dyn_string bn;
  dyn_dyn_int bt;
  bn[1] = makeDynString(baseType);
  bt[1] = makeDynInt(DPEL_STRUCT);
  bn[2] = makeDynString("", "value");
  bt[2] = makeDynInt(0, DPEL_FLOAT);

  dpdCheckRc("базовый тип создан", dpTypeCreate(bn, bt));

  // --- 2. тип со ссылкой на базовый ----------------------------------------
  dyn_dyn_string rn;
  dyn_dyn_int rt;
  rn[1] = makeDynString(refType);
  rt[1] = makeDynInt(DPEL_STRUCT);
  rn[2] = makeDynString("", "regratio", baseType);
  rt[2] = makeDynInt(0, DPEL_TYPEREF);

  dpdCheckRc("тип со ссылкой создан", dpTypeCreate(rn, rt));

  // --- 3. точка данных по типу со ссылкой ----------------------------------
  string dpName = "dpdemo_ref_1";
  dpdDropDp(dpName);
  dpdCheckRc("точка данных создана", dpCreate(dpName, refType));
  dpdCheck("точка данных существует", dpExists(dpName));

  // --- 4. обратный поиск: кто ссылается на базовый тип ---------------------
  dyn_dyn_string refs = dpGetRefsToDpType(baseType);
  DebugN("  dpGetRefsToDpType(\"", baseType, "\") вернул ", dynlen(refs), " строк(и)");
  for (int i = 1; i <= dynlen(refs); i++)
  {
    DebugN("    [", i, "] ", refs[i]);
  }
  dpdCheck("найден хотя бы один ссылающийся объект", dynlen(refs) > 0);

  // --- 5. среди найденного должен быть тип со ссылкой ---------------------
  // Функция возвращает и DPT, и DP — ищем тип со ссылкой по точному имени.
  bool typeFound = false;
  for (int i = 1; i <= dynlen(refs); i++)
  {
    if (refs[i][1] == refType) { typeFound = true; }
  }
  DebugN("  тип ", refType, " найден среди ссылок: ", typeFound);
  dpdCheck("ссылающийся тип найден", typeFound);

  // --- 6. на сам тип со ссылкой никто не ссылается ------------------------
  dyn_dyn_string selfRefs = dpGetRefsToDpType(refType);
  DebugN("  dpGetRefsToDpType(\"", refType, "\") вернул ", dynlen(selfRefs), " строк(и)");
  dpdCheck("обратный поиск не находит «сам у себя»", dynlen(selfRefs) == 0);

  // --- 7. несуществующее имя → пустой результат ---------------------------
  dyn_dyn_string bad = dpGetRefsToDpType("dpdemo_no_such_type");
  DebugN("  dpGetRefsToDpType(\"dpdemo_no_such_type\") вернул ", dynlen(bad),
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