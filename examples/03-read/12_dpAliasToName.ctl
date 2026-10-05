// 12_dpAliasToName.ctl - имя элемента по алиасу.
//
// Документация: docs/03-read.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем:
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа и задаём алиас элементу;
//   3) удаляем и точку данных, и тип.
//
// dpAliasToName(alias) - обратная операция к dpGetAlias() из docs/02-config.md.
// Возвращает элемент точки данных по алиасу либо пустую строку.
//
// Алиасы ищутся по ВСЕМ точкам проекта, поэтому для проверки берём
// заведомо уникальное имя вида "dpdemo_<случай>_<что-то>", как это делает
// dpdEnsureDp() в docs/_lib.ctl. Тогда результат не зависит от состояния
// проекта и не может случайно совпасть с чужим алиасом.
//
// Проверено: CTL 3.18, проект prg_12_3.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "alias_t";
string DP  = "dpdemo_alias_dp";
string ALIAS  = "dpdemo_alias_Al1as_9x";
string ALIAS2 = "dpdemo_alias_Al2as_9x";
string ALIAS3 = "dpdemo_alias_Al3as_9x";

main()
{
  DebugN("=== dpAliasToName(): имя элемента по алиасу ===");

  makeObjects();

  // ---------------------------------------------------------------------
  // 1. Алиаса нет - возвращается пустая строка
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Несуществующий алиас ---");

  string none = dpAliasToName("dpdemo_no_such_alias_at_all");
  DebugN("  несуществующий алиас -> [", none, "]");
  dpdCheck(none == "", "несуществующий алиас -> пустая строка", none);

  // ---------------------------------------------------------------------
  // 2. Задаём алиас и ищем его обратно
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Алиас задан через dpSetAlias ---");

  int rc = dpSetAlias(DP + ".fVal", ALIAS);
  DebugN("  dpSetAlias rc=", rc);

  string back = dpAliasToName(ALIAS);
  DebugN("  dpAliasToName(ALIAS) -> [", back, "]");

  // Возвращается элемент; вид может быть с префиксом системы или без него -
  // сравниваем по существу, а не по точному тексту.
  dpdCheck(rc == 0, "dpSetAlias вернул rc=0", rc);
  // ВАЖНО. dpAliasToName() возвращает имя С ПРЕФИКСОМ СИСТЕМЫ:
  // "System1:dpdemo_alias_dp.fVal", а не "dpdemo_alias_dp.fVal".
  // Присваивать результат в имя элемента напрямую нельзя - лишний префикс.
  dpdCheck(back == "System1:" + DP + ".fVal", "найден элемент с префиксом системы", back);

  // Обратная операция: алиас элемента
  string aliasBack = dpGetAlias(DP + ".fVal");
  DebugN("  dpGetAlias(элемент) -> [", aliasBack, "]");
  dpdCheck(aliasBack == ALIAS, "dpGetAlias вернул заданный алиас", aliasBack);

  // ---------------------------------------------------------------------
  // 3. Алиасы разных элементов не путаются
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Несколько алиасов ---");

  dpSetAlias(DP + ".iVal", ALIAS2);
  dpSetAlias(DP + ".sVal", ALIAS3);

  string b2 = dpAliasToName(ALIAS2);
  string b3 = dpAliasToName(ALIAS3);
  DebugN("  ALIAS2 -> [", b2, "]");
  DebugN("  ALIAS3 -> [", b3, "]");
  dpdCheck(b2 == "System1:" + DP + ".iVal", "ALIAS2 ведёт на iVal", b2);
  dpdCheck(b3 == "System1:" + DP + ".sVal", "ALIAS3 ведёт на sVal", b3);

  // ---------------------------------------------------------------------
  // 4. Элемент без алиаса
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Элемент без алиаса ---");

  string noAlias = dpGetAlias(DP + ".bVal");
  DebugN("  dpGetAlias(bVal) -> [", noAlias, "]");
  dpdCheck(noAlias == "", "элемент без алиаса даёт пустую строку", noAlias);

  // ---------------------------------------------------------------------
  // 5. Ошибочные случаи
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Ошибочные случаи ---");

  dpdCheck(dpAliasToName("") == "", "пустая строка -> пустой результат",
           dpAliasToName(""));
  dpdCheck(dpAliasToName("no_such_dp.fVal") == "",
           "имя элемента вместо алиаса -> пустой результат",
           dpAliasToName("no_such_dp.fVal"));

  // ---------------------------------------------------------------------
  // 6. Уборка
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("(6) уборка");
  dropAll();
  dpdCheck(!dpExists(DP), "точка данных удалена", DP);
  dyn_dyn_string leftNames;
  dyn_dyn_int leftTypes;
  dpdCheck(dpTypeGet(DPT, leftNames, leftTypes) != 0, "тип удалён", DPT);

  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

void makeObjects()
{
  dropAll();

  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString(DPT);          t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "fVal");    t[2] = makeDynInt(0, DPEL_FLOAT);
  n[3] = makeDynString("", "iVal");    t[3] = makeDynInt(0, DPEL_INT);
  n[4] = makeDynString("", "bVal");    t[4] = makeDynInt(0, DPEL_BOOL);
  n[5] = makeDynString("", "sVal");    t[5] = makeDynInt(0, DPEL_STRING);
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
  dpdCheck(dpCreate(DP, DPT) == 0, "точка данных создана", DP);
  delay(1);
  DebugN("  создана точка ", DP, " типа ", DPT);
  DebugN("  алиасы: ", ALIAS, ", ", ALIAS2, ", ", ALIAS3);
}

void dropAll()
{
  dyn_string all = dpNames("*", DPT);
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpExists(all[i])) { dpDelete(all[i]); }
  }
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    if (dynlen(dpNames("*", DPT)) == 0) { break; }
    delay(1);
  }
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    dyn_dyn_string pn;
    dyn_dyn_int pt;
    if (dpTypeGet(DPT, pn, pt) != 0) { break; }
    dpTypeDelete(DPT);
    delay(1);
  }
}

void dpdCheck(bool ok, string what, dyn_anytype extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra, "  lastError=", getLastError()); }
}
