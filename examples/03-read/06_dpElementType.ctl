// 06_dpElementType.ctl - код типа данных элемента точки.
//
// dpElementType() возвращает целое - код типа данных элемента,
// -1 при ошибке. Ничего не меняет, только читает.
//
// Скрипт проверяет:
//
//   * код типа для каждого элемента собственной точки, созданной dpTypeCreate;
//   * соответствие констант DPEL_* их числовым значениям из таблицы
//     документации - если документация ошиблась, это будет видно;
//   * код типа корневого элемента (структура);
//   * поведение на несуществующем элементе и на пустой строке.
//
// Важно: код типа элемента НЕ зависит от того, настроен ли конфиг
// _address, и не связан с dpAttributeType(), который отвечает на другой
// вопрос - какая характеристика атрибута хранится (см. 07_dpAttributeType.ctl).
//
// Проверено: CTL 3.18, проект prg_12_3.
// Объекты создаются и удаляются самим скриптом.

int OK = 0;
int BAD = 0;

string DPT = "rdEl_t";
string DP  = "rdEl";

main()
{
  DebugN("=== dpElementType(): код типа данных элемента ===");

  makeObjects();

  // ------------------------------------------------- 1. коды типов
  DebugN("");
  DebugN("--- 1. Код типа каждого элемента ---");

  string  names;
  int     types;
  int     expected;
  int     i;

  string ename = "";
  int    etype = 0;
  int    eexp  = 0;

  // Имена элементов в порядке создания, начиная с корня
  for (i = 1; i <= nelem(); i++)
  {
    ename = elemName(i);
    etype = elemType(i);
    eexp  = elemExpected(i);

    int got = dpElementType(DP + "." + ename);
    DebugN("  ", (ename == "") ? "<корень>" : ename,
            "   код=", got, "   ожидался ", eexp, "   ",
            typeName(got));
    check(got == eexp, "код типа совпал", (ename == "") ? "<корень>" : ename);
  }

  DebugN("");
  DebugN("  Всего проверено элементов: ", nelem());

  // ---------------------------------------- 2. значения констант
  DebugN("");
  DebugN("--- 2. Числовые значения констант DPEL_* ---");
  DebugN("  Сверяются с таблицей docs/03-read.md. Расхождение - ошибка документации.");

  DebugN("     DPEL_STRUCT          = ", DPEL_STRUCT,          "   в документации 1");
  DebugN("     DPEL_BOOL            = ", DPEL_BOOL,            "   в документации 23");
  DebugN("     DPEL_CHAR            = ", DPEL_CHAR,            "   в документации 19");
  DebugN("     DPEL_INT             = ", DPEL_INT,             "   в документации 21");
  DebugN("     DPEL_UINT            = ", DPEL_UINT,            "   в документации 20");
  DebugN("     DPEL_FLOAT           = ", DPEL_FLOAT,           "   в документации 22");
  DebugN("     DPEL_STRING          = ", DPEL_STRING,          "   в документации 25");
  DebugN("     DPEL_TIME            = ", DPEL_TIME,            "   в документации 26");
  DebugN("     DPEL_DPID            = ", DPEL_DPID,            "   в документации 27");
  DebugN("     DPEL_LANGSTRING      = ", DPEL_LANGSTRING,      "   в документации 42");
  DebugN("     DPEL_BIT32           = ", DPEL_BIT32,           "   в документации 24");
  DebugN("     DPEL_BIT64           = ", DPEL_BIT64,           "   в документации 50");
  DebugN("     DPEL_LONG            = ", DPEL_LONG,            "   в документации 54");
  DebugN("     DPEL_ULONG           = ", DPEL_ULONG,           "   в документации 58");
  DebugN("     DPEL_BLOB            = ", DPEL_BLOB,            "   в документации 46");
  DebugN("     DPEL_DYN_INT         = ", DPEL_DYN_INT,         "   в документации 5");
  DebugN("     DPEL_DYN_FLOAT       = ", DPEL_DYN_FLOAT,       "   в документации 6");
  DebugN("     DPEL_DYN_STRING      = ", DPEL_DYN_STRING,      "   в документации 9");
  DebugN("     DPEL_DYN_BOOL        = ", DPEL_DYN_BOOL,        "   в документации 7");
  DebugN("     DPEL_DYN_TIME        = ", DPEL_DYN_TIME,        "   в документации 10");
  DebugN("     DPEL_TYPEREF         = ", DPEL_TYPEREF,         "   в документации 41");
  DebugN("     DPEL_DYN_DPID        = ", DPEL_DYN_DPID,        "   в документации 29");

  check(DPEL_STRUCT    == 1,  "DPEL_STRUCT == 1",      DPEL_STRUCT);
  check(DPEL_BOOL      == 23, "DPEL_BOOL == 23",       DPEL_BOOL);
  check(DPEL_INT       == 21, "DPEL_INT == 21",        DPEL_INT);
  check(DPEL_FLOAT     == 22, "DPEL_FLOAT == 22",      DPEL_FLOAT);
  check(DPEL_STRING    == 25, "DPEL_STRING == 25",     DPEL_STRING);
  check(DPEL_DYN_INT   == 5,  "DPEL_DYN_INT == 5",     DPEL_DYN_INT);
  check(DPEL_DYN_FLOAT == 6,  "DPEL_DYN_FLOAT == 6",   DPEL_DYN_FLOAT);
  check(DPEL_DYN_STRING== 9,  "DPEL_DYN_STRING == 9",  DPEL_DYN_STRING);

  // --------------------------------------------- 3. ошибочные случаи
  DebugN("");
  DebugN("--- 3. Ошибочные случаи ---");

  int rcNo = dpElementType(DP + ".nosuchelem");
  DebugN("  несуществующий элемент   код=", rcNo);
  check(rcNo == -1, "несуществующий элемент даёт -1", rcNo);

  int rcEmpty = dpElementType("");
  DebugN("  пустая строка            код=", rcEmpty);
  check(rcEmpty == -1, "пустая строка даёт -1", rcEmpty);

  int rcNoDp = dpElementType("nosuchdp.x");
  DebugN("  несуществующая точка     код=", rcNoDp);
  check(rcNoDp == -1, "несуществующая точка даёт -1", rcNoDp);

  DebugN("");
  DebugN("=== ИТОГ: успешно ", OK, ", неудачно ", BAD, " ===");

  cleanObjects();
  DebugN("--- объекты удалены скриптом ---");
  DebugN("=== конец ===");
}

// ---------------------------------------------------------------- helpers

int nelem()
{
  return 19;   // корень плюс 18 элементов
}

string elemName(int i)
{
  dyn_string n = makeDynString("", "bVal", "cVal", "iVal", "uVal", "fVal",
                               "sVal", "tVal", "idVal", "lsVal",
                               "b32Val", "lVal", "ulVal", "blobVal",
                               "diVal", "dfVal", "dsVal", "dbVal", "dtVal");
  return n[i];
}

int elemType(int i)
{
  dyn_int t = makeDynInt(DPEL_STRUCT, DPEL_BOOL, DPEL_CHAR, DPEL_INT, DPEL_UINT,
                      DPEL_FLOAT, DPEL_STRING, DPEL_TIME, DPEL_DPID, DPEL_LANGSTRING,
                      DPEL_BIT32, DPEL_LONG, DPEL_ULONG, DPEL_BLOB,
                      DPEL_DYN_INT, DPEL_DYN_FLOAT, DPEL_DYN_STRING,
                      DPEL_DYN_BOOL, DPEL_DYN_TIME);
  return t[i];
}

int elemExpected(int i)
{
  return elemType(i);   // ожидаем ровно то, чем создавали
}

string typeName(int code)
{
  if (code == -1)         { return "ошибка / нет элемента"; }
  if (code == DPEL_STRUCT){ return "структура"; }
  if (code == DPEL_BOOL)  { return "bit"; }
  if (code == DPEL_CHAR)  { return "символ"; }
  if (code == DPEL_INT)   { return "целое"; }
  if (code == DPEL_UINT)  { return "беззнаковое целое"; }
  if (code == DPEL_FLOAT) { return "float"; }
  if (code == DPEL_STRING){ return "текст"; }
  if (code == DPEL_TIME)  { return "время"; }
  if (code == DPEL_DPID)  { return "идентификатор точки данных"; }
  if (code == DPEL_LANGSTRING)   { return "многоязычный текст"; }
  if (code == DPEL_BIT32) { return "битовое поле 32"; }
  if (code == DPEL_LONG)  { return "целое 64 бита"; }
  if (code == DPEL_ULONG) { return "положительное целое 64 бита"; }
  if (code == DPEL_BLOB)  { return "blob"; }
  if (code == DPEL_DYN_INT)    { return "динамический массив целых"; }
  if (code == DPEL_DYN_FLOAT)  { return "динамический массив float"; }
  if (code == DPEL_DYN_STRING) { return "динамический массив текста"; }
  if (code == DPEL_DYN_BOOL)   { return "динамический битовый массив"; }
  if (code == DPEL_DYN_TIME)   { return "динамический массив времени"; }
  return "код вне взятой таблицы";
}

void check(bool ok, string what, dyn_anytype extra)
{
  if (ok) { OK++;  DebugN("  PASS  ", what, "   ", extra); }
  else    { BAD++; DebugN("  FAIL  ", what, "   ", extra); }
}

void makeObjects()
{
  dyn_dyn_string names;
  dyn_dyn_int types;

  int n = nelem();
  names[1] = makeDynString(DPT);   types[1] = makeDynInt(elemType(1));
  for (int i = 2; i <= n; i++)
  {
    names[i] = makeDynString("", elemName(i));
    types[i] = makeDynInt(0, elemType(i));
  }

  cleanObjects();
  int rcT = dpTypeCreate(names, types);
  int rcD = dpCreate(DP, DPT);
  DebugN("  тип ", DPT, " rc=", rcT, ", точка ", DP, " rc=", rcD);
  DebugN("  элементов в типе: ", n);
}

void cleanObjects()
{
  if (dpExists(DP)) { dpDelete(DP); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(DP)) { break; }
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