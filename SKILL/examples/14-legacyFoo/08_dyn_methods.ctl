// 08_dyn_methods.ctl - методы динамических массивов dyn_* (синтаксис arr.method()).
// Документация: docs/14-legacyFoo.md (раздел 7).
// Проверено: CTL 3.18, проект <проект стенда>.
// Скрипт самодостаточен: точки данных не создаёт, сеть не используется.
//
// ГЛАВНОЕ, ЧТО ИЗМЕРЕНО.
//   * Прямой индекс dyn_* - с 1: a[1] - первый элемент, a[0] даёт
//     SEVERE 79 "Index out of range" и останавливает скрипт.
//   * Методы работают с 0-based индексами, как vector:
//     at(0) - первый, insertAt(0, x) - в начало, removeAt(2) - третий.
//   * first(), last(), at(i) возвращают ссылку: a.first() = "Z" меняет массив.
//   * indexOf() возвращает 0-based позицию, -1 если элемента нет.
//   * indexListOf() возвращает vector<int> с 0-based позициями; если вхождений
//     нет - пустой vector (count = 0), а не -1, как у indexOf().
//   * lastIndexOf() в 3.18 НЕТ: вызов даёт WARNING 72
//     "Function not defined, dyn_T::lastIndexOf" и останавливает скрипт.
//     У vector<int> его тоже нет.
//   * unique() удаляет дубликаты и возвращает 0, а не новую длину.
//   * replaceAt() и removeAt() возвращают 0; take* возвращают извлечённое.
//   * Вызов метода у временного результата makeDyn*() (цепочкой) даёт
//     WARNING 73 (дважды) и WARNING 76, но скрипт продолжается.
//     Сначала присвойте массив переменной.
//   * Выход за границу at()/insertAt()/removeAt() - не rc, а исключение
//     SEVERE 176 + WARNING 79 "Index out of range"; скрипт останавливается.
//     Границы методов: insertAt допускает 0..len, removeAt/at - 0..len-1.
//     Эти случаи в гейт-скрипт не включены: они убивают поток.

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

main()
{
  DebugN("=== Методы dyn_* (0-based, как vector) ===");

  // ------------------------------------------------------ 1. Индексация
  DebugN("");
  DebugN("--- 1. Прямой индекс 1-based, методы 0-based ---");
  dyn_string a = makeDynString("b", "a", "b");
  dpdCheck("dynlen=3", dynlen(a) == 3);
  dpdCheck("a[1] - первый элемент", a[1] == "b");
  dpdCheck("a[2] - второй элемент", a[2] == "a");
  dpdCheck("at(0) - первый элемент", (string)a.at(0) == "b");
  dpdCheck("at(1) - второй элемент", (string)a.at(1) == "a");
  dpdCheck("at(2) - третий элемент", (string)a.at(2) == "b");
  dpdCheck("first()", (string)a.first() == "b");
  dpdCheck("last()", (string)a.last() == "b");

  // ------------------------------------------------------ 2. Ссылка
  DebugN("");
  DebugN("--- 2. first()/at() возвращают ссылку ---");
  a.at(1) = "Q";
  dpdCheck("a.at(1)=\"Q\" меняет второй элемент", a[2] == "Q");
  a.first() = "Z";
  dpdCheck("a.first()=\"Z\" меняет первый элемент", a[1] == "Z");

  // ------------------------------------------------------ 3. Добавление
  DebugN("");
  DebugN("--- 3. append / insertAt / replaceAt ---");
  dyn_string b = makeDynString("a", "b");
  b.append("c");
  dpdCheck("append: len=3", dynlen(b) == 3);
  dpdCheck("append: элемент в конце", b[3] == "c");

  dyn_string i0 = makeDynString("a", "b", "c");
  i0.insertAt(0, "X");
  dpdCheck("insertAt(0) вставляет в начало (0-based)", i0[1] == "X" && i0[2] == "a");
  dpdCheck("insertAt(0): len=4", dynlen(i0) == 4);

  dyn_string i1 = makeDynString("a", "b", "c");
  i1.insertAt(1, "X");
  dpdCheck("insertAt(1) перед вторым", i1[2] == "X" && i1[3] == "b");

  dyn_string i3 = makeDynString("a", "b", "c");
  i3.insertAt(3, "X");
  dpdCheck("insertAt(len) добавляет в конец", i3[4] == "X" && dynlen(i3) == 4);

  dyn_string rp = makeDynString("a", "b", "c");
  int rcRp = rp.replaceAt(0, "X");
  dpdCheck("replaceAt(0) заменяет первый", rp[1] == "X" && dynlen(rp) == 3);
  dpdCheck("replaceAt возвращает 0", rcRp == 0);
  rp.replaceAt(2, "Y");
  dpdCheck("replaceAt(2) заменяет третий", rp[3] == "Y");

  // ------------------------------------------------------ 4. Удаление
  DebugN("");
  DebugN("--- 4. removeAt / take* / clear ---");
  dyn_string r0 = makeDynString("a", "b", "c");
  int rcR0 = r0.removeAt(0);
  dpdCheck("removeAt(0) удаляет первый", dynlen(r0) == 2 && r0[1] == "b");
  dpdCheck("removeAt возвращает 0", rcR0 == 0);
  dyn_string r2 = makeDynString("a", "b", "c");
  r2.removeAt(2);
  dpdCheck("removeAt(2) удаляет третий", dynlen(r2) == 2 && r2[2] == "b");

  dyn_string t1 = makeDynString("x", "y", "z");
  string v1 = (string)t1.takeFirst();
  dpdCheck("takeFirst возвращает первый", v1 == "x");
  dpdCheck("takeFirst удаляет его", dynlen(t1) == 2 && t1[1] == "y");

  dyn_string t2 = makeDynString("x", "y", "z");
  string v2 = (string)t2.takeLast();
  dpdCheck("takeLast возвращает последний", v2 == "z");
  dpdCheck("takeLast удаляет его", dynlen(t2) == 2 && t2[2] == "y");

  dyn_string t3 = makeDynString("x", "y", "z");
  string v3 = (string)t3.takeAt(1);
  dpdCheck("takeAt(1) возвращает второй (0-based)", v3 == "y");
  dpdCheck("takeAt(1) удаляет его", dynlen(t3) == 2 && t3[1] == "x" && t3[2] == "z");

  dyn_string t0 = makeDynString("x", "y", "z");
  dpdCheck("takeAt(0) возвращает первый", (string)t0.takeAt(0) == "x");
  dpdCheck("takeAt(0) оставляет y,z", t0[1] == "y" && t0[2] == "z");

  dyn_string t4 = makeDynString("x", "y", "z");
  dpdCheck("takeAt(2) возвращает третий", (string)t4.takeAt(2) == "z");
  dpdCheck("takeAt(2) оставляет x,y", t4[1] == "x" && t4[2] == "y");

  dyn_string c = makeDynString("a", "b");
  c.clear();
  dpdCheck("clear: len=0", dynlen(c) == 0);

  // ------------------------------------------------------ 5. Поиск
  DebugN("");
  DebugN("--- 5. contains / indexOf / indexListOf / count ---");
  dyn_string s = makeDynString("b", "a", "b");
  dpdCheck("contains(a)=TRUE", s.contains("a") == TRUE);
  dpdCheck("contains(zz)=FALSE", s.contains("zz") == FALSE);
  dpdCheck("indexOf(a)=1 (0-based)", s.indexOf("a") == 1);
  dpdCheck("indexOf(zz)=-1", s.indexOf("zz") == -1);
  dpdCheck("count=3", s.count() == 3);
  dpdCheck("count() == dynlen()", s.count() == dynlen(s));

  anytype il = s.indexListOf("b");
  DebugN("  indexListOf(b) = ", il);
  dpdCheck("indexListOf: два вхождения", il.count() == 2);
  dpdCheck("indexListOf: позиции 0 и 2 (0-based)", il[0] == 0 && il[1] == 2);
  anytype im = s.indexListOf("zz");
  dpdCheck("indexListOf(zz): пустой vector, а не -1", im.count() == 0);

  // ------------------------------------------------------ 6. unique
  DebugN("");
  DebugN("--- 6. unique: дубликаты и регистр ---");
  dyn_string u = makeDynString("b", "a", "b", "c", "a");
  anytype ur = u.unique();
  DebugN("  unique() вернул ", ur, ", массив ", u);
  dpdCheck("unique: len=3", dynlen(u) == 3);
  dpdCheck("unique: порядок первых вхождений", u[1] == "b" && u[2] == "a" && u[3] == "c");
  dpdCheck("unique возвращает 0, а не новую длину", (int)ur == 0);

  dyn_string uc = makeDynString("b", "B", "b", "a");
  uc.unique();
  dpdCheck("unique регистрозависим: b и B разные", dynlen(uc) == 3);

  // ------------------------------------------------------ 7. dyn_int
  DebugN("");
  DebugN("--- 7. Те же методы у dyn_int ---");
  dyn_int di = makeDynInt(5, 1, 5);
  dpdCheck("dyn_int contains(5)=TRUE", di.contains(5) == TRUE);
  dpdCheck("dyn_int indexOf(5)=0", di.indexOf(5) == 0);
  dpdCheck("dyn_int count=3", di.count() == 3);
  di.unique();
  dpdCheck("dyn_int unique: len=2", dynlen(di) == 2 && di[1] == 5 && di[2] == 1);

  // ------------------------------------------------------ 8. Пустой массив
  DebugN("");
  DebugN("--- 8. Пустой массив ---");
  dyn_string e;
  dpdCheck("count() пустого = 0", e.count() == 0);
  dpdCheck("contains() пустого = FALSE", e.contains("x") == FALSE);
  dpdCheck("indexOf() пустого = -1", e.indexOf("x") == -1);
  anytype em = e.indexListOf("x");
  dpdCheck("indexListOf() пустого - пустой vector", em.count() == 0);
  anytype eu = e.unique();
  dpdCheck("unique() пустого возвращает 0", (int)eu == 0);
  e.clear();
  dpdCheck("clear() пустого безопасен", dynlen(e) == 0);

  // ------------------------------------------------------ 9. vector
  DebugN("");
  DebugN("--- 9. vector: 0-based, dynlen не работает ---");
  vector<int> v;
  v.append(10);
  v.append(20);
  dpdCheck("v[0] - первый элемент", v[0] == 10);
  dpdCheck("v[1] - второй элемент", v[1] == 20);
  dpdCheck("count() вектора = 2", v.count() == 2);
  dpdCheck("dynlen(vector) = -1 (WARNING 77)", dynlen(v) == -1);

  dpdSummary();
}
