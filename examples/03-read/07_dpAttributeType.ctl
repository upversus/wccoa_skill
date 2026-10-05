// 07_dpAttributeType.ctl - тип данных АТРИБУТА конфига.
//
// Документация: docs/03-read.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем:
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа и наполняем её;
//   3) удаляем и точку данных, и тип.
//
// dpAttributeType(dp) возвращает тип АТРИБУТА, а не элемента. Набор
// констант ДРУГОЙ: FLOAT_VAR / INT_VAR / …, а не DPEL_*. Не путать с
// dpElementType(), который отвечает про тип элемента.
//
// Формат адреса: элемент, конфиг, атрибут - "dp.elem:_cfg.._attr".
//
// Код возврата - составной битовый:
//     (базовый тип << 16) | флаги
// На стенде младшие 16 бит всегда нулевые, поэтому базовый тип читается
// просто делением на 65536.
//
// Проверено: CTL 3.18, проект prg_12_3.

int dpdPass = 0;
int dpdFail = 0;

// Тип атрибута _status. Именованной константы в CTL нет, значение измерено.
int ATTR_TYPE_STATUS = 589824;   // 9 << 16

string DPT = "attr_t";
string DP  = "attr";

main()
{
  DebugN("=== dpAttributeType(): тип атрибута ===");

  // ---------------------------------------------------------------------
  // 0. Значения констант
  // ---------------------------------------------------------------------
  // Обратите внимание: это НЕ те же значения, что у DPEL_*.
  DebugN("");
  DebugN("--- 0. Константы типов атрибутов ---");
  DebugN("  FLOAT_VAR  = ", FLOAT_VAR,   "   (", FLOAT_VAR / 65536, " << 16)");
  DebugN("  INT_VAR    = ", INT_VAR,     "   (", INT_VAR / 65536, " << 16)");
  DebugN("  BOOL_VAR   = ", BOOL_VAR,    "   (", BOOL_VAR / 65536, " << 16)");
  DebugN("  STRING_VAR = ", STRING_VAR,  "   (", STRING_VAR / 65536, " << 16)");
  DebugN("  TIME_VAR   = ", TIME_VAR,    "   (", TIME_VAR / 65536, " << 16)");

  dpdCheck(FLOAT_VAR == 458752, "FLOAT_VAR == 458752", FLOAT_VAR);
  dpdCheck(INT_VAR == 327680, "INT_VAR == 327680", INT_VAR);
  dpdCheck(BOOL_VAR == 262144, "BOOL_VAR == 262144", BOOL_VAR);
  dpdCheck(STRING_VAR == 524288, "STRING_VAR == 524288", STRING_VAR);
  dpdCheck(TIME_VAR == 196608, "TIME_VAR == 196608", TIME_VAR);

  // Все значения кратны 65536 - старшие биты, младшие нулевые.
  dpdCheck((FLOAT_VAR % 65536) == 0, "младшие 16 бит FLOAT_VAR нулевые", FLOAT_VAR % 65536);

  makeObjects();

  // ---------------------------------------------------------------------
  // 1. Тип атрибута _value зависит от типа элемента
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. _value: тип элемента определяет тип атрибута ---");

  checkElem("_value", "fVal", FLOAT_VAR);
  checkElem("_value", "iVal", INT_VAR);
  checkElem("_value", "bVal", BOOL_VAR);
  checkElem("_value", "sVal", STRING_VAR);
  checkElem("_value", "tVal", TIME_VAR);

  // ---------------------------------------------------------------------
  // 2. Остальные атрибуты от типа элемента не зависят
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. _stime, _bad, _status ---");
  DebugN("  Эти атрибуты имеют один тип для любого элемента.");

  dyn_string elems = makeDynString("fVal", "iVal", "bVal", "sVal", "tVal");
  for (int i = 1; i <= dynlen(elems); i++)
  {
    checkElem("_stime",   elems[i], TIME_VAR);
    checkElem("_bad",     elems[i], BOOL_VAR);
    // У _status нет именованной константы: код 589824 = 9 << 16.
    // Поэтому сверяем с числом, а не с *_VAR.
    int st = dpAttributeType(DP + "." + elems[i] + ":_online.._status");
    dpdCheck(st == ATTR_TYPE_STATUS, elems[i] + ":_status -> 589824 (9 << 16)", st);
  }

  // ---------------------------------------------------------------------
  // 3. Конфиг на тип атрибута не влияет
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. _original и _online дают одинаковый тип ---");

  for (int i = 1; i <= dynlen(elems); i++)
  {
    int orig = dpAttributeType(DP + "." + elems[i] + ":_original.._value");
    int onl  = dpAttributeType(DP + "." + elems[i] + ":_online.._value");
    dpdCheck(orig == onl, elems[i] + ": _original == _online", orig + " / " + onl);
  }

  // ---------------------------------------------------------------------
  // 4. Ошибочные случаи - все дают -1
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Ошибочные случаи ---");

  checkBad("несуществующий элемент",  DP + ".nosuch:_online.._value");
  checkBad("несуществующий конфиг",   DP + ".fVal:_nope.._value");
  checkBad("несуществующий атрибут",  DP + ".fVal:_online.._nope");
  checkBad("пустая строка",           "");
  checkBad("имя элемента без точки",  DP + "fVal:_online.._value");
  // У корня типа struct значения нет, поэтому и типа атрибута нет.
  checkBad("корень типа struct",      DP + ".:" + "_online.._value");

  // ---------------------------------------------------------------------
  // 5. Уборка
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("(5) уборка");
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
// Проверка типа одного атрибута у одного элемента
// ===========================================================================
void checkElem(string attr, string elem, int expected)
{
  int got = dpAttributeType(DP + "." + elem + ":_online.." + attr);
  dpdCheck(got == expected, elem + ":_" + attr + " -> " + attrTypeName(expected),
           "получено " + got);
}

void checkBad(string what, string path)
{
  int got = dpAttributeType(path);
  dpdCheck(got == -1, what + " -> -1", "получено " + got);
}

string attrTypeName(int code)
{
  if (code == FLOAT_VAR)  { return "FLOAT_VAR"; }
  if (code == INT_VAR)    { return "INT_VAR"; }
  if (code == BOOL_VAR)   { return "BOOL_VAR"; }
  if (code == STRING_VAR) { return "STRING_VAR"; }
  if (code == TIME_VAR)   { return "TIME_VAR"; }
  if (code == ATTR_TYPE_STATUS) { return "STATUS (589824)"; }
  if (code == -1)         { return "ошибка"; }
  return "код " + code + " (не измерен)";
}

// ===========================================================================
// Создание своих объектов
// ===========================================================================
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
  n[6] = makeDynString("", "tVal");    t[6] = makeDynInt(0, DPEL_TIME);
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
  dpdCheck(dpCreate(DP, DPT) == 0, "точка данных создана", DP);

  dpSet(DP + ".fVal", 42.5);
  dpSet(DP + ".iVal", -17);
  dpSet(DP + ".bVal", TRUE);
  dpSet(DP + ".sVal", "строка");
  dpSet(DP + ".tVal", makeTime(2026, 10, 4, 12, 0, 0));
  delay(1);
  DebugN("  создана точка ", DP, " типа ", DPT);
  DebugN("  элементы: fVal(float) iVal(int) bVal(bool) sVal(string) tVal(time)");
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

// ПОРЯДОК АРГУМЕНТОВ: (ok, what, extra). Обоснование - в 06-query/01_dpQuery.ctl:
// при объявлении (string what, bool ok) вызовы склеиваются без ошибки, булево
// выражение превращается в строку, и все проверки проходят насквозь.
void dpdCheck(bool ok, string what, dyn_anytype extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra, "  lastError=", getLastError()); }
}