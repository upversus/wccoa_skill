// 01_jsonEncode.ctl - jsonEncode(): кодирование значений в JSON.
//
// Документация: docs/14-legacyFoo.md
// Проверено: CTL 3.18, проект <проект стенда>.
//
// Скрипт самодостаточен: точки данных не создаёт, сеть не использует.
// jsonEncode() работает только с памятью CTL-скрипта.

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
  DebugN("=== jsonEncode(): кодирование в JSON ===");

  // ------------------------------------------------------ 1. простые значения
  DebugN("");
  DebugN("--- 1. Простой тип -> массив из одного элемента ---");
  string sInt = jsonEncode(42);
  string sFloat = jsonEncode(1.5);
  string sBool = jsonEncode(true);
  string sStr = jsonEncode("abc");
  DebugN("  int    : ", sInt);
  DebugN("  float  : ", sFloat);
  DebugN("  bool   : ", sBool);
  DebugN("  string : ", sStr);
  dpdCheck("int 42 -> [42]", sInt == "[42]");
  dpdCheck("float 1.5 -> [1.5]", sFloat == "[1.5]");
  dpdCheck("bool true -> [true]", sBool == "[true]");
  dpdCheck("string abc -> [\"abc\"]", sStr == "[\"abc\"]");

  // ------------------------------------------------------ 2. dyn_ -> массив
  DebugN("");
  DebugN("--- 2. dyn_ -> JSON-массив ---");
  string dInt = jsonEncode(makeDynInt(1, 2, 3));
  string dStr = jsonEncode(makeDynString("a", "b"));
  DebugN("  dyn_int    : ", dInt);
  DebugN("  dyn_string : ", dStr);
  dpdCheck("dyn_int -> [1,2,3]", dInt == "[1,2,3]");
  dpdCheck("dyn_string -> [\"a\",\"b\"]", dStr == "[\"a\",\"b\"]");

  // ------------------------------------------------------ 3. mapping -> объект
  DebugN("");
  DebugN("--- 3. mapping -> JSON-объект (порядок ключей не гарантирован) ---");
  mapping m = makeMapping("name", "test", "value", 42, "ok", true);
  string compact = jsonEncode(m);
  DebugN("  compact: ", compact);
  dpdCheck("начинается с { и заканчивается }",
           strpos(compact, "{") == 0 && strpos(compact, "}") == strlen(compact) - 1);
  dpdCheck("содержит name=test", strpos(compact, "\"name\":\"test\"") >= 0);
  dpdCheck("содержит value=42", strpos(compact, "\"value\":42") >= 0);
  dpdCheck("содержит ok=true", strpos(compact, "\"ok\":true") >= 0);
  dpdCheck("compact без переводов строк", strpos(compact, "\n") < 0);

  // ------------------------------------------------------ 4. compactFormat=false
  DebugN("");
  DebugN("--- 4. compactFormat=false -> отступы и переносы ---");
  string pretty = jsonEncode(m, false);
  DebugN("  pretty: ", pretty);
  dpdCheck("pretty содержит перевод строки", strpos(pretty, "\n") >= 0);
  dpdCheck("pretty содержит отступ 4 пробела", strpos(pretty, "    \"") >= 0);

  // ------------------------------------------------------ 5. atime -> объект
  DebugN("");
  DebugN("--- 5. atime -> объект time/dpid/count, время ISO-8601 UTC ---");
  atime t = makeTime(2020, 6, 15, 12, 0, 0);
  string tj = jsonEncode(makeMapping("t", t));
  DebugN("  ", tj);
  dpdCheck("atime закодирован объектом", strpos(tj, "{\"t\":{") >= 0);
  dpdCheck("есть поле time", strpos(tj, "\"time\":\"2020-06-15T") >= 0);
  dpdCheck("время оканчивается на .000Z", strpos(tj, ".000Z\"") >= 0);
  dpdCheck("есть поле count", strpos(tj, "\"count\":0") >= 0);
  dpdCheck("есть поле dpid", strpos(tj, "\"dpid\":") >= 0);

  // ------------------------------------------------------ 6. нестроковый ключ
  DebugN("");
  DebugN("--- 6. Нестроковый ключ mapping -> {} (измерено) ---");
  string intKey = jsonEncode(makeMapping(1, "one"));
  DebugN("  mapping с ключом int: ", intKey);
  dpdCheck("нестроковый ключ отбрасывается: {}", intKey == "{}");

  // ------------------------------------------------------ 7. опции 3.18
  DebugN("");
  DebugN("--- 7. Оговорка 3.18: options в 3-м аргументе игнорируются ---");
  string viaOpts = jsonEncode(m, true, makeMapping("compactFormat", false));
  DebugN("  результат: ", viaOpts);
  dpdCheck("compactFormat в options не сработал (вывод компактный)",
           strpos(viaOpts, "\n") < 0);

  DebugN("");
  dpdSummary();
}
