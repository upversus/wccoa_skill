// 02_dpExists.ctl — демонстрация dpExists()
//
// Документация: docs/01-create.md#dpexists
//
// Главная идея: dpExists() возвращает true, если разрешилась ХОТЯ БЫ ОДНА часть
// идентификатора. Поэтому для несуществующей точки данных с урезанным именем
// он всё равно вернёт true. Чтобы проверять именно DP, нужен dpSubStr(..., DPSUB_DP).
//
// Запуск: разово, блокировки нет — работает и без живого Event Manager,
// но полезно запускать при работающей системе.

main()
{
  dpdHeader("dpExists", "bool dpExists(string dpname)");

  // --- 1. полностью несуществующая точка данных ----------------------------
  bool a = dpExists("dpdemo_definitely_not_here");
  DebugN("  dpExists(\"dpdemo_definitely_not_here\") = ", a);
  dpdCheck("несуществующее имя даёт false", !a);

  // --- 2. урезанное имя НЕ разрешается, если точка данных не существует -----
  // Проверено на CTL 3.18: dpExists("несуществующаяDP:_original.._value")
  // возвращает FALSE. Документация утверждает, что функция возвращает true,
  // если разрешилась ХОТЯ БЫ ОДНА часть идентификатора, — на практике
  // несуществующий префикс точки данных делает весь идентификатор
  // неразрешимым.
  bool b = dpExists("dpdemo_definitely_not_here:_original.._value");
  DebugN("  dpExists(\"несуществующаяDP:_original.._value\") = ", b);
  dpdCheck("урезанное имя не разрешается, хотя часть после ':' корректна", !b);

  // --- 3. но пустой идентификатор разрешается всегда ------------------------
  // dpExists(":") == true — функция бесполезна как guard «есть ли вообще база».
  DebugN("  dpExists(\":\") = ", dpExists(":"));
  dpdCheck("dpExists(\":\") == true — бесполезен как guard", dpExists(":"));

  // --- 4. правильный guard: сначала вырезать только имя DP ------------------
  // dpSubStr(..., DPSUB_DP) — строгая проверка того, что речь именно о точке
  // данных, а не о каком-то частично разрешимом идентификаторе.
  string ident = "dpdemo_definitely_not_here:_original.._value";
  string onlyDp = dpSubStr(ident, DPSUB_DP);
  bool c = dpExists(onlyDp);
  DebugN("  dpSubStr(ident, DPSUB_DP) = '", onlyDp, "' → dpExists = ", c);
  dpdCheck("строгий guard через dpSubStr() даёт false", !c);

  // --- 5. рабочий guard на реально существующей точке ----------------------
  string dpt = dpdPickType();
  if (dpt == "")
  {
    DebugN("  SKIP  нет DPT с точками данных");
  }
  else
  {
    dyn_string names = dpNames("*", dpt);
    string existing = names[1];
    DebugN("  существующая точка данных: ", existing);

    bool d = dpExists(existing);
    dpdCheck("существующая точка данных даёт true", d);

    string existingOnlyDp = dpSubStr(existing, DPSUB_DP);
    dpdCheck("dpSubStr(..., DPSUB_DP) не ломает существующую точку",
             dpExists(existingOnlyDp));

    // элемент верхнего уровня — с точкой
    bool e = dpExists(existing + ".");
    DebugN("  dpExists(\"", existing, ".\") = ", e);
    dpdCheck("элемент верхнего уровня (с точкой) существует", e);
  }

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