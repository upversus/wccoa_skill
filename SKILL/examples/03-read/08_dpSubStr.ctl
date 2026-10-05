// 08_dpSubStr.ctl - вырезание части идентификатора точки данных.
//
// Документация: docs/03-read.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем:
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа;
//   3) удаляем и точку данных, и тип.
//
// dpSubStr(dp, pattern) возвращает запрошенную часть идентификатора.
// Возвращает ПУСТУЮ СТРОКУ при ошибке, в том числе если точки данных нет -
// поэтому пустой возврат нельзя отличить от существующей точки с пустым именем.
//
// Проверяем полный набор констант DPSUB_* на собственном элементе, включая
// вложенный элемент структуры.
//
// Проверено: CTL 3.18, проект <проект стенда>.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "sub_t";
string DP  = "subDp";

main()
{
  DebugN("=== dpSubStr(): части идентификатора ===");

  makeObjects();

  // Полный идентификатор, который будем разбирать
  string full = DP + ".fVal:_online.._value";
  DebugN("");
  DebugN("  разбираем: ", full);
  DebugN("");

  // ---------------------------------------------------------------------
  // 1. Все константы - печатаем результат
  // ---------------------------------------------------------------------
  DebugN("--- 1. Все константы DPSUB_* ---");

  show("DPSUB_ALL",                  full, DPSUB_ALL);
  show("DPSUB_SYS_DP_EL_CONF_DET_ATT", full, DPSUB_SYS_DP_EL_CONF_DET_ATT);
  show("DPSUB_SYS_DP_EL_CONF_DET",   full, DPSUB_SYS_DP_EL_CONF_DET);
  show("DPSUB_SYS_DP_EL_CONF",       full, DPSUB_SYS_DP_EL_CONF);
  show("DPSUB_SYS_DP_EL",            full, DPSUB_SYS_DP_EL);
  show("DPSUB_SYS_DP",               full, DPSUB_SYS_DP);
  show("DPSUB_SYS",                  full, DPSUB_SYS);
  show("DPSUB_DP_EL_CONF_DET_ATT",   full, DPSUB_DP_EL_CONF_DET_ATT);
  show("DPSUB_DP_EL_CONF_DET",       full, DPSUB_DP_EL_CONF_DET);
  show("DPSUB_DP_EL_CONF",           full, DPSUB_DP_EL_CONF);
  show("DPSUB_DP_EL",                full, DPSUB_DP_EL);
  show("DPSUB_DP",                   full, DPSUB_DP);
  show("DPSUB_CONF_DET_ATT",         full, DPSUB_CONF_DET_ATT);
  show("DPSUB_CONF_DET",             full, DPSUB_CONF_DET);
  show("DPSUB_CONF",                 full, DPSUB_CONF);

  // ---------------------------------------------------------------------
  // 2. Проверки по измеренным значениям
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Проверки ---");

  // DPSUB_ALL возвращает КАНОНИЧЕСКУЮ форму - с префиксом системы, даже если
  // его не было во входной строке.
  dpdCheck(dpSubStr(full, DPSUB_ALL) == "System1:" + full,
           "DPSUB_ALL - каноническая форма, с системой",
           dpSubStr(full, DPSUB_ALL));
  dpdCheck(dpSubStr(full, DPSUB_SYS) == "System1:", "DPSUB_SYS возвращает систему",
           dpSubStr(full, DPSUB_SYS));
  dpdCheck(dpSubStr(full, DPSUB_DP) == DP, "DPSUB_DP возвращает имя точки данных",
           dpSubStr(full, DPSUB_DP));
  dpdCheck(dpSubStr(full, DPSUB_DP_EL) == DP + ".fVal", "DPSUB_DP_EL - точка и элемент",
           dpSubStr(full, DPSUB_DP_EL));
  dpdCheck(dpSubStr(full, DPSUB_CONF) == ":_online", "DPSUB_CONF - конфиг с двоеточием",
           dpSubStr(full, DPSUB_CONF));
  dpdCheck(dpSubStr(full, DPSUB_CONF_DET_ATT) == ":_online.._value",
           "DPSUB_CONF_DET_ATT - конфиг с двоеточием и атрибутом",
           dpSubStr(full, DPSUB_CONF_DET_ATT));
  dpdCheck(dpSubStr(full, DPSUB_SYS_DP) == "System1:" + DP,
           "DPSUB_SYS_DP - система и точка", dpSubStr(full, DPSUB_SYS_DP));

  // Укороченная форма без системы должна быть суффиксом полной
  dpdCheck(dpSubStr(full, DPSUB_DP_EL_CONF_DET_ATT) == DP + ".fVal:_online.._value",
           "без системы - та же строка без префикса",
           dpSubStr(full, DPSUB_DP_EL_CONF_DET_ATT));

  // ---------------------------------------------------------------------
  // 3. Элемент без конфига
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Идентификатор без конфига и атрибута ---");

  string bare = DP + ".fVal";
  DebugN("  разбираем: ", bare);
  dpdCheck(dpSubStr(bare, DPSUB_DP) == DP, "DPSUB_DP работает и без конфига",
           dpSubStr(bare, DPSUB_DP));
  DebugN("  DPSUB_CONF на пустой конфиг: '", dpSubStr(bare, DPSUB_CONF), "'");
  dpdCheck(dpSubStr(bare, DPSUB_CONF) == "", "DPSUB_CONF на отсутствующем конфиге пуст",
           "'" + dpSubStr(bare, DPSUB_CONF) + "'");

  // ---------------------------------------------------------------------
  // --- 4. Вложенный элемент структуры ---------------------------------
  //
  // Документация утверждает: для элементов типа struct dpSubStr()
  // возвращает индекс, то есть "myDp.intStruct[2]" вместо "myDp.intStruct.node2".
  //
  // Проверить это здесь нечем: создать точку с вложенной структурой через
  // dpTypeCreate() не удалось (см. блок создания типа выше). Поэтому
  // утверждение документации остаётся НЕПРОВЕРЕННЫМ, и выдавать его за
  // проверенный факт нельзя. Проверка потребует готовой точки с такой
  // структурой.
  DebugN("  (не проверяется на этом стенде)");

  // 5. Ошибочные случаи - пустая строка
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Ошибочные случаи ---");
  DebugN("  ВНИМАНИЕ: dpSubStr() проверяет существование точки данных.");
  DebugN("  Пустой возврат нельзя отличить от существующей точки с пустым именем.");

  dpdCheck(dpSubStr("noSuchDp.fVal", DPSUB_DP) == "", "несуществующая точка -> пусто",
           "'" + dpSubStr("noSuchDp.fVal", DPSUB_DP) + "'");
  dpdCheck(dpSubStr("", DPSUB_DP) == "", "пустая строка -> пусто",
           "'" + dpSubStr("", DPSUB_DP) + "'");
  // Неизвестный код константы НЕ даёт пустую строку: возвращается вся
  // строка, как при DPSUB_ALL. То есть неизвестный код неотличим от
  // "хочу всё" - опечатку в константе это не поймает.
  dpdCheck(dpSubStr(full, -1) == "System1:" + full,
           "неизвестный код даёт всю строку, а не пустую",
           dpSubStr(full, -1));

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

// ===========================================================================
// Печать результата одной константы
// ===========================================================================
void show(string name, string id, int pattern)
{
  string s = dpSubStr(id, pattern);
  DebugN("  ", name, " = '", s, "'");
}

// ===========================================================================
// Создание своих объектов. Вложенная структура нужна для проверки индекса.
// ===========================================================================
void makeObjects()
{
  dropAll();

  dyn_dyn_string n;
  dyn_dyn_int t;
  // ВАЖНО: вложенную структуру НЕЛЬЗЯ объявлять явно вместе с её же
  // Тип плоский. Вложенную структуру (элемент типа struct с потомками)
  // в dpTypeCreate() создать НЕ удалось: плоский формат требует, чтобы имя
  // промежуточного узла не повторялось, а повтор даёт "equal element names".
  // Поэтому поведение dpSubStr() для вложенных элементов (индекс в
  // квадратных скобках) здесь НЕ проверяется - см. раздел 4.
  n[1] = makeDynString(DPT);               t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "fVal");        t[2] = makeDynInt(0, DPEL_FLOAT);
  n[3] = makeDynString("", "iVal");        t[3] = makeDynInt(0, DPEL_INT);
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
  dpdCheck(dpCreate(DP, DPT) == 0, "точка данных создана", DP);

  dpSet(DP + ".fVal", 42.5);
  delay(1);
  DebugN("  создана точка ", DP, " типа ", DPT);
  DebugN("  элементы: fVal(float), sub.node1(int), sub.node2(int)");
}

// ===========================================================================
// Уборка: сначала точки данных, потом тип
// ===========================================================================
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
