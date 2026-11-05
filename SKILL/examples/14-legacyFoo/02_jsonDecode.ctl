// 02_jsonDecode.ctl - jsonDecode(): разбор JSON и диагностика ошибок.
//
// Документация: docs/14-legacyFoo.md
// Проверено: CTL 3.18, проект <проект стенда>.
//
// Скрипт самодостаточен: точки данных не создаёт, сеть не использует.
// jsonDecode() не возвращает -1; ошибка проверяется через getLastError().

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
  DebugN("=== jsonDecode(): разбор JSON ===");

  // ------------------------------------------------------ 1. объект -> mapping
  DebugN("");
  DebugN("--- 1. JSON-объект -> mapping ---");
  anytype o = jsonDecode("{\"name\":\"test\",\"value\":42,\"ok\":true}");
  DebugN("  decoded: ", o);
  dpdCheck("getLastError пуст", dynlen(getLastError()) == 0);
  dpdCheck("ключ name есть", mappingHasKey(o, "name"));
  dpdCheck("name == test", o["name"] == "test");
  dpdCheck("value == 42", o["value"] == 42);
  dpdCheck("ok == true", o["ok"] == true);

  // ------------------------------------------------------ 2. массив -> dyn_
  DebugN("");
  DebugN("--- 2. JSON-массив -> dyn_anytype ---");
  anytype a = jsonDecode("[10,20,30]");
  DebugN("  decoded: ", a);
  dpdCheck("getLastError пуст", dynlen(getLastError()) == 0);
  dpdCheck("длина массива 3", dynlen(a) == 3);
  dpdCheck("a[1] == 10", a[1] == 10);
  dpdCheck("a[3] == 30", a[3] == 30);

  // ------------------------------------------------------ 3. вложенность
  DebugN("");
  DebugN("--- 3. Вложенные объект и массив ---");
  anytype n = jsonDecode("{\"list\":[1,2],\"nested\":{\"a\":7}}");
  DebugN("  decoded: ", n);
  dpdCheck("getLastError пуст", dynlen(getLastError()) == 0);
  dpdCheck("n[\"list\"] — массив длины 2", dynlen(n["list"]) == 2);
  dpdCheck("n[\"list\"][2] == 2", n["list"][2] == 2);
  dpdCheck("вложенный ключ nested.a есть", mappingHasKey(n["nested"], "a"));
  dpdCheck("n[\"nested\"][\"a\"] == 7", n["nested"]["a"] == 7);

  // ------------------------------------------------------ 4. roundtrip
  DebugN("");
  DebugN("--- 4. Roundtrip: mapping -> JSON -> mapping ---");
  mapping src = makeMapping("name", "test", "value", 42);
  string js = jsonEncode(src);
  mapping back = jsonDecode(js);
  DebugN("  json : ", js);
  DebugN("  back : ", back);
  dpdCheck("getLastError пуст", dynlen(getLastError()) == 0);
  dpdCheck("name сохранился", back["name"] == "test");
  dpdCheck("value сохранился", back["value"] == 42);
  dpdCheck("длина mapping 2", mappinglen(back) == 2);

  // ------------------------------------------------------ 5. ошибка синтаксиса
  DebugN("");
  DebugN("--- 5. Синтаксическая ошибка: результат пуст, ошибка в getLastError ---");
  anytype bad = jsonDecode("{bad json");
  int badLen = dynlen(getLastError());
  DebugN("  bad=", bad, "  lastError.len=", badLen);
  dpdCheck("getLastError не пуст", badLen > 0);

  // ------------------------------------------------------ 6. BOM
  DebugN("");
  DebugN("--- 6. BOM в начале строки -> ошибка (измерено) ---");
  anytype bom = jsonDecode("\xEF\xBB\xBF{\"a\":1}");
  int bomLen = dynlen(getLastError());
  DebugN("  bom=", bom, "  lastError.len=", bomLen);
  dpdCheck("BOM вызывает ошибку", bomLen > 0);

  // ------------------------------------------------------ 7. скаляр верхнего уровня
  DebugN("");
  DebugN("--- 7. Оговорка 3.18: верхнеуровневый скаляр не декодируется ---");
  anytype sn = jsonDecode("42");
  int snLen = dynlen(getLastError());
  DebugN("  jsonDecode(\"42\")=", sn, "  lastError.len=", snLen);
  dpdCheck("скаляр 42 даёт ошибку (оговорка 3.18)", snLen > 0);
  anytype sa = jsonDecode("[42]");
  dpdCheck("в массиве число декодируется", dynlen(getLastError()) == 0 && sa[1] == 42);

  // ------------------------------------------------------ 8. atime
  DebugN("");
  DebugN("--- 8. atime после jsonEncode декодируется в mapping (измерено) ---");
  atime t = makeTime(2020, 6, 15, 12, 0, 0);
  anytype tb = jsonDecode(jsonEncode(makeMapping("t", t)));
  DebugN("  decoded: ", tb);
  dpdCheck("getLastError пуст", dynlen(getLastError()) == 0);
  dpdCheck("t стал mapping с ключом time", mappingHasKey(tb["t"], "time"));
  dpdCheck("time — строка ISO-8601", strpos(tb["t"]["time"], "2020-06-15T") >= 0);

  DebugN("");
  dpdSummary();
}
