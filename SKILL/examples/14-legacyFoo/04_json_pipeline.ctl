// 04_json_pipeline.ctl - конвейер mapping -> jsonEncode -> jsonDecode.
//
// Документация: docs/14-legacyFoo.md
// Проверено: CTL 3.18, проект <проект стенда>.
//
// Скрипт самодостаточен: точки данных не создаёт, сеть НЕ использует.
// Это «памятная» часть реального конвейера: в бою строка json уходит в
// netPost(), а тело ответа netGet() разбирается тем же jsonDecode().
// HTTP-функции — docs/13-http.md, примеры — examples/13-net/.

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
  DebugN("=== Конвейер JSON в памяти (без сети) ===");

  // ------------------------------------------------------ 1. сборка mapping
  DebugN("");
  DebugN("--- 1. Сборка mapping ---");
  mapping data = makeMapping("name", "test", "value", 42);
  data["timestamp"] = formatTime("%Y-%m-%dT%H:%M:%S", getCurrentTime());
  data["tags"] = makeDynString("a", "b");
  data["meta"] = makeMapping("source", "ctl");

  DebugN("  data=", data);
  dpdCheck("добавлен timestamp", mappingHasKey(data, "timestamp"));
  dpdCheck("timestamp не пуст", strlen(data["timestamp"]) > 0);
  dpdCheck("добавлен массив tags", dynlen(data["tags"]) == 2);
  dpdCheck("добавлен вложенный meta", mappingHasKey(data["meta"], "source"));

  // ------------------------------------------------------ 2. кодирование
  DebugN("");
  DebugN("--- 2. jsonEncode ---");
  string json = jsonEncode(data);
  DebugN("  json=", json);
  dpdCheck("JSON содержит name", strpos(json, "\"name\":\"test\"") >= 0);
  dpdCheck("JSON содержит value", strpos(json, "\"value\":42") >= 0);
  dpdCheck("JSON содержит timestamp", strpos(json, "\"timestamp\":") >= 0);
  dpdCheck("JSON содержит tags", strpos(json, "\"tags\":[\"a\",\"b\"]") >= 0);

  // ------------------------------------------------------ 3. разбор
  DebugN("");
  DebugN("--- 3. jsonDecode ---");
  anytype back = jsonDecode(json);
  DebugN("  back=", back);
  dpdCheck("getLastError пуст", dynlen(getLastError()) == 0);
  dpdCheck("name сохранился", back["name"] == "test");
  dpdCheck("value сохранился", back["value"] == 42);
  dpdCheck("timestamp сохранился", strlen(back["timestamp"]) > 0);
  dpdCheck("tags — массив длины 2", dynlen(back["tags"]) == 2);
  dpdCheck("tags[2] == b", back["tags"][2] == "b");
  dpdCheck("meta.source == ctl", back["meta"]["source"] == "ctl");

  // ------------------------------------------------------ 4. повторный roundtrip
  DebugN("");
  DebugN("--- 4. Повторный roundtrip ---");
  string json2 = jsonEncode(back);
  anytype again = jsonDecode(json2);
  dpdCheck("второй разбор без ошибки", dynlen(getLastError()) == 0);
  dpdCheck("value после второго круга", again["value"] == 42);
  dpdCheck("name после второго круга", again["name"] == "test");

  DebugN("");
  DebugN("--- Pretty-вывод для журнала ---");
  DebugN(jsonEncode(data, false));

  DebugN("");
  dpdSummary();
}
