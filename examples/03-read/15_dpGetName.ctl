// 15_dpGetName.ctl - имя элемента по числовым идентификаторам.
//
// Документация: docs/03-read.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем:
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа;
//   3) удаляем и точку данных, и тип.
//
// dpGetName(dpId, elId [, sysnum = ownSystem]) - обратная операция к
// dpGetId(). Возвращает имя элемента или пустую строку.
//
// ВАЖНО, что замечено на стенде: возвращаемое имя содержит ПРЕФИКС СИСТЕМЫ,
// "System1:idDp.fVal". То есть результат нельзя напрямую склеивать с точкой
// как "имя"+"."+элемент - получится лишнее имя системы.
//
// Проверено: CTL 3.18, проект prg_12_3.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "name_t";
string DP  = "nameDp";

main()
{
  DebugN("=== dpGetName(): имя элемента по идентификаторам ===");

  makeObjects();

  // ---------------------------------------------------------------------
  // 1. Круг: имя -> идентификаторы -> имя
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Полный круг ---");

  unsigned fId;
  int fEl;
  bool ok = dpGetId(DP + ".fVal", fId, fEl);
  DebugN("  dpGetId(\"", DP, ".fVal\") = ", ok, "  dpId=", fId, "  elId=", fEl);

  string back = dpGetName(fId, fEl);
  DebugN("  dpGetName(", fId, ", ", fEl, ") -> [", back, "]");

  dpdCheck(ok, "dpGetId нашёл элемент", ok);
  dpdCheck(back == "System1:" + DP + ".fVal",
           "круг замкнулся, имя с префиксом системы", back);

  // ---------------------------------------------------------------------
  // 2. Все элементы точки разрешаются обратно
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Все элементы ---");

  dyn_string elems = makeDynString("", "fVal", "iVal", "bVal");
  for (int i = 2; i <= dynlen(elems); i++)
  {
    unsigned eId;
    int eEl;
    dpGetId(DP + "." + elems[i], eId, eEl);
    string nm = dpGetName(eId, eEl);
    DebugN("  ", elems[i], "  (", eId, ", ", eEl, ") -> [", nm, "]");
    dpdCheck(nm == "System1:" + DP + "." + elems[i],
             "элемент " + elems[i] + " разрешается обратно", nm);
  }

  // ---------------------------------------------------------------------
  // 3. Корень точки
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Корень точки (elId = 1) ---");

  unsigned rId;
  int rEl;
  dpGetId(DP + ".", rId, rEl);
  string rootName = dpGetName(rId, rEl);
  DebugN("  корень (", rId, ", ", rEl, ") -> [", rootName, "]");
  dpdCheck(rootName != "", "корень разрешается", rootName);
  dpdCheck(rEl == 1, "у корня elId = 1", rEl);

  // ---------------------------------------------------------------------
  // 4. Явный номер системы
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Третий параметр sysnum ---");
  DebugN("  По умолчанию берётся система вызова. Проверим явное значение.");

  string withSys = dpGetName(fId, fEl, 1);
  DebugN("  dpGetName(dpId, elId, 1) -> [", withSys, "]");
  dpdCheck(withSys == back, "явный sysnum = 1 даёт тот же результат", withSys);

  string badSys = dpGetName(fId, fEl, 99);
  DebugN("  dpGetName(dpId, elId, 99) -> [", badSys, "]");
  dpdCheck(badSys == "", "несуществующая система -> пустая строка", badSys);

  // ---------------------------------------------------------------------
  // 5. Ошибочные случаи
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Ошибочные случаи ---");

  string noEl = dpGetName(fId, 999);
  DebugN("  несуществующий elId -> [", noEl, "]");
  dpdCheck(noEl == "", "несуществующий elId -> пустая строка", noEl);

  string noDp = dpGetName(999999, 1);
  DebugN("  несуществующий dpId -> [", noDp, "]");
  dpdCheck(noDp == "", "несуществующий dpId -> пустая строка", noDp);

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
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
  dpdCheck(dpCreate(DP, DPT) == 0, "точка данных создана", DP);
  delay(1);
  DebugN("  создана точка ", DP, " типа ", DPT);
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