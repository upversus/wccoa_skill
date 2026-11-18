// 09_dyn_globals.ctl - глобальные функции dyn*: создание, длина, изменение,
// поиск, сортировка, математика, двумерные массивы.
// Документация: docs/14-legacyFoo.md (раздел 8).
// Проверено: CTL 3.18, проект <проект стенда>.
// Скрипт самодостаточен: точки данных не создаёт, сеть не используется.
//
// ГЛАВНОЕ, ЧТО ИЗМЕРЕНО (расхождения с документацией 3.21 отмечены).
//   * Глобальные dyn*-функции нумеруют элементы с 1, в отличие от методов.
//   * makeDynDynInt() и makeDynDynString() в 3.18 НЕ существуют
//     (isFunctionDefined = FALSE): dyn_dyn_* собирается присваиванием строк.
//     dynAppendConst() В 3.18 МЕНЯЕТ исходный массив (вопреки описанию
//     «не меняющая исходный массив») и возвращает новую длину - как dynAppend().
//   * dynInsertAt(arr, val, pos): pos 1..len вставляет перед позицией,
//     pos = 0 или pos > len добавляет в конец; возвращает новую длину.
//   * dynRemove(arr, pos): pos 1-based; pos = 0 - rc = -1 и массив не меняется.
//   * dynContains() возвращает 1-based индекс, 0 если элемента нет.
//   * dynSort() по умолчанию по возрастанию, второй аргумент FALSE -
//     по убыванию, TRUE - по возрастанию; возвращает длину.
//     Строки сортируются по кодам: "A" < "a" < "b".
//   * dynUnique() удаляет дубликаты на месте и возвращает НОВУЮ длину
//     (метод unique() возвращает 0).
//   * dynSum/dynAvg/dynMin/dynMax для пустого массива возвращают -1.
//     dynAvg() для dyn_int возвращает float (15/4 = 3.75).
//   * dynPatternMatch() учитывает регистр, порядок сохраняет, при отсутствии
//     совпадений возвращает пустой dyn_string.
//   * dynDynTurn() транспонирует на месте и возвращает число строк.
//   * dynDynSort(arr, col): col 1-based, сортирует на месте, возвращает число
//     строк; col = 0 не меняет массив и не сообщает об ошибке.

int dpdPass = 0;
int dpdFail = 0;

void dpdCheck(string what, bool ok)
{
  if (ok) { dpdPass++;  DebugN("  PASS  ", what); }
  else    { dpdFail++;  DebugN("  FAIL  ", what, "  lastError=", getLastError()); }
}

void dpdSummary()
{
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
}

string joinS(dyn_string a)
{
  string s = "";
  for (int i = 1; i <= dynlen(a); i++) { if (i > 1) { s += ","; } s += a[i]; }
  return s;
}

string joinI(dyn_int a)
{
  string s = "";
  for (int i = 1; i <= dynlen(a); i++) { if (i > 1) { s += ","; } s += (string)a[i]; }
  return s;
}

main()
{
  DebugN("=== Глобальные функции dyn* (1-based) ===");

  // ------------------------------------------------------ 1. makeDyn*
  DebugN("");
  DebugN("--- 1. makeDyn*: создание ---");
  dyn_int mi = makeDynInt(1, 2, 3);
  dyn_string ms = makeDynString("a", "b");
  dyn_float mf = makeDynFloat(1.5, 2.5);
  dyn_bool mb = makeDynBool(TRUE, FALSE);
  dpdCheck("makeDynInt: len=3", dynlen(mi) == 3 && mi[1] == 1 && mi[3] == 3);
  dpdCheck("makeDynString: len=2", dynlen(ms) == 2 && ms[2] == "b");
  dpdCheck("makeDynFloat: len=2", dynlen(mf) == 2 && mf[1] == 1.5);
  dpdCheck("makeDynBool: len=2", dynlen(mb) == 2 && mb[1] == TRUE && mb[2] == FALSE);
  dpdCheck("makeDynInt() без аргументов: len=0", dynlen(makeDynInt()) == 0);
  dpdCheck("makeDynDynInt не существует (3.18)", isFunctionDefined("makeDynDynInt") == FALSE);
  dpdCheck("makeDynDynString не существует (3.18)", isFunctionDefined("makeDynDynString") == FALSE);

  // ------------------------------------------------------ 2. dynlen / dynClear
  DebugN("");
  DebugN("--- 2. dynlen / dynClear ---");
  dpdCheck("dynlen(mi)=3", dynlen(mi) == 3);
  dyn_int cl = makeDynInt(1, 2);
  int rcCl = dynClear(cl);
  dpdCheck("dynClear: len=0", dynlen(cl) == 0);
  dpdCheck("dynClear возвращает 0", rcCl == 0);

  // ------------------------------------------------------ 3. dynAppend
  DebugN("");
  DebugN("--- 3. dynAppend / dynAppendConst ---");
  dyn_int ap = makeDynInt(1, 2);
  int rcAp = dynAppend(ap, 3);
  dpdCheck("dynAppend(scalar): len=3", dynlen(ap) == 3 && ap[3] == 3);
  dpdCheck("dynAppend возвращает новую длину", rcAp == 3);

  dyn_int ap2 = makeDynInt(1, 2);
  dynAppend(ap2, makeDynInt(3, 4));
  dpdCheck("dynAppend(массив) дописывает все элементы", dynlen(ap2) == 4 && ap2[3] == 3 && ap2[4] == 4);

  dyn_int acs = makeDynInt(1, 2);
  int rcAcs = dynAppendConst(acs, 3);
  DebugN("  dynAppendConst: src=", joinI(acs), " rc=", rcAcs);
  dpdCheck("dynAppendConst в 3.18 МЕНЯЕТ src (оговорка)", dynlen(acs) == 3 && acs[3] == 3);
  dpdCheck("dynAppendConst возвращает новую длину", rcAcs == 3);

  // ------------------------------------------------------ 4. dynInsertAt
  DebugN("");
  DebugN("--- 4. dynInsertAt: 1-based, 0 = в конец ---");
  dyn_string i1 = makeDynString("a", "b", "c");
  int rcI1 = dynInsertAt(i1, "X", 1);
  dpdCheck("pos=1 вставляет в начало", joinS(i1) == "X,a,b,c");
  dpdCheck("dynInsertAt возвращает новую длину", rcI1 == 4);

  dyn_string i2 = makeDynString("a", "b", "c");
  dynInsertAt(i2, "X", 2);
  dpdCheck("pos=2 вставляет перед вторым", joinS(i2) == "a,X,b,c");

  dyn_string i3 = makeDynString("a", "b", "c");
  dynInsertAt(i3, "X", 3);
  dpdCheck("pos=3 вставляет перед третьим", joinS(i3) == "a,b,X,c");

  dyn_string i0 = makeDynString("a", "b", "c");
  dynInsertAt(i0, "X", 0);
  dpdCheck("pos=0 добавляет в конец (оговорка)", joinS(i0) == "a,b,c,X");

  dyn_string i4 = makeDynString("a", "b", "c");
  dynInsertAt(i4, "X", 4);
  dpdCheck("pos > len добавляет в конец", joinS(i4) == "a,b,c,X");

  // ------------------------------------------------------ 5. dynRemove
  DebugN("");
  DebugN("--- 5. dynRemove: 1-based, 0 = отказ ---");
  dyn_string r1 = makeDynString("a", "b", "c");
  int rcR1 = dynRemove(r1, 1);
  dpdCheck("pos=1 удаляет первый", joinS(r1) == "b,c");
  dpdCheck("dynRemove возвращает 0", rcR1 == 0);

  dyn_string r2 = makeDynString("a", "b", "c");
  dynRemove(r2, 2);
  dpdCheck("pos=2 удаляет второй", joinS(r2) == "a,c");

  dyn_string r3 = makeDynString("a", "b", "c");
  dynRemove(r3, 3);
  dpdCheck("pos=3 удаляет третий", joinS(r3) == "a,b");

  dyn_string r0 = makeDynString("a", "b", "c");
  int rcR0 = dynRemove(r0, 0);
  dpdCheck("pos=0: массив не меняется", joinS(r0) == "a,b,c");
  dpdCheck("pos=0: rc=-1", rcR0 == -1);

  // ------------------------------------------------------ 6. dynContains
  DebugN("");
  DebugN("--- 6. dynContains: 1-based индекс или 0 ---");
  dyn_int g = makeDynInt(5, 1, 3, 3);
  dpdCheck("dynContains(1)=2", dynContains(g, 1) == 2);
  dpdCheck("dynContains(3)=3 (первое вхождение)", dynContains(g, 3) == 3);
  dpdCheck("dynContains(9)=0", dynContains(g, 9) == 0);
  dyn_string gs = makeDynString("a", "b", "c");
  dpdCheck("dynContains работает и для строк", dynContains(gs, "b") == 2 && dynContains(gs, "zz") == 0);

  // ------------------------------------------------------ 7. dynPatternMatch
  DebugN("");
  DebugN("--- 7. dynPatternMatch: маска, регистр ---");
  dyn_string names = makeDynString("Pump_1", "pump_2", "Valve_2", "Pump_3");
  dpdCheck("Pump* -> Pump_1,Pump_3", joinS(dynPatternMatch("Pump*", names)) == "Pump_1,Pump_3");
  dpdCheck("pump* -> pump_2 (регистрозависимо)", joinS(dynPatternMatch("pump*", names)) == "pump_2");
  dpdCheck("*_2 -> pump_2,Valve_2 (порядок сохранён)", joinS(dynPatternMatch("*_2", names)) == "pump_2,Valve_2");
  dpdCheck("нет совпадений -> пустой массив", dynlen(dynPatternMatch("ZZZ*", names)) == 0);

  // ------------------------------------------------------ 8. dynSort
  DebugN("");
  DebugN("--- 8. dynSort / dynSortAsc ---");
  dyn_int so = makeDynInt(3, 1, 2);
  int rcSo = dynSort(so);
  dpdCheck("по умолчанию по возрастанию", joinI(so) == "1,2,3");
  dpdCheck("dynSort возвращает длину", rcSo == 3);

  dyn_int sd = makeDynInt(3, 1, 2);
  dynSort(sd, FALSE);
  dpdCheck("asc=FALSE - по убыванию", joinI(sd) == "3,2,1");

  dyn_int sa = makeDynInt(3, 1, 2);
  dynSort(sa, TRUE);
  dpdCheck("asc=TRUE - по возрастанию", joinI(sa) == "1,2,3");

  dyn_int sasc = makeDynInt(3, 1, 2);
  dynSortAsc(sasc);
  dpdCheck("dynSortAsc - по возрастанию", joinI(sasc) == "1,2,3");

  dyn_string ss = makeDynString("b", "A", "a");
  dynSort(ss);
  dpdCheck("строки по кодам: A,a,b", joinS(ss) == "A,a,b");

  // ------------------------------------------------------ 9. dynUnique
  DebugN("");
  DebugN("--- 9. dynUnique: дубликаты и возврат ---");
  dyn_int un = makeDynInt(3, 1, 3, 2, 1);
  int rcUn = dynUnique(un);
  dpdCheck("дубликаты удалены, порядок первых вхождений", joinI(un) == "3,1,2");
  dpdCheck("dynUnique возвращает новую длину", rcUn == 3 && dynlen(un) == 3);

  // ------------------------------------------------------ 10. Математика
  DebugN("");
  DebugN("--- 10. dynSum / dynAvg / dynMin / dynMax ---");
  dyn_int mm = makeDynInt(4, 1, 7, 3);
  dpdCheck("dynSum=15", dynSum(mm) == 15);
  dpdCheck("dynAvg=3.75 (float для dyn_int)", dynAvg(mm) == 3.75);
  dpdCheck("dynMin=1", dynMin(mm) == 1);
  dpdCheck("dynMax=7", dynMax(mm) == 7);

  dyn_int empty;
  dpdCheck("пустой dynSum=-1", dynSum(empty) == -1);
  dpdCheck("пустой dynAvg=-1", dynAvg(empty) == -1);
  dpdCheck("пустой dynMin=-1", dynMin(empty) == -1);
  dpdCheck("пустой dynMax=-1", dynMax(empty) == -1);

  // ------------------------------------------------------ 11. dyn_dyn_*
  DebugN("");
  DebugN("--- 11. dyn_dyn_*: turn и sort ---");
  dyn_dyn_int dd;
  dd[1] = makeDynInt(3, 1, 5);
  dd[2] = makeDynInt(4, 2, 6);
  int rcTurn = dynDynTurn(dd);
  dpdCheck("turn: строк стало 3", dynlen(dd) == 3 && rcTurn == 3);
  dpdCheck("turn: 1-я строка [3,4]", joinI(dd[1]) == "3,4");
  dpdCheck("turn: 3-я строка [5,6]", joinI(dd[3]) == "5,6");

  dyn_dyn_int ds;
  ds[1] = makeDynInt(9, 1);
  ds[2] = makeDynInt(1, 9);
  int rcSort = dynDynSort(ds, 1);
  dpdCheck("sort col=1: по первому столбцу", joinI(ds[1]) == "1,9" && joinI(ds[2]) == "9,1");
  dpdCheck("dynDynSort возвращает число строк", rcSort == 2);

  dyn_dyn_int ds2;
  ds2[1] = makeDynInt(9, 1);
  ds2[2] = makeDynInt(1, 9);
  dynDynSort(ds2, 2);
  dpdCheck("sort col=2: по второму столбцу", joinI(ds2[1]) == "9,1" && joinI(ds2[2]) == "1,9");

  dyn_dyn_int ds0;
  ds0[1] = makeDynInt(9, 1);
  ds0[2] = makeDynInt(1, 9);
  dynDynSort(ds0, 0);
  dpdCheck("col=0: массив не меняется, ошибки нет", joinI(ds0[1]) == "9,1" && joinI(ds0[2]) == "1,9");

  dpdSummary();
}
