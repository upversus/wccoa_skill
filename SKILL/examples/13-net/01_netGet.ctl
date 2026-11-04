// 01_netGet.ctl - тестирование клиентской HTTP-функции netGet().
//
// Документация: docs/13-http.md
//
// ПРОТОКОЛ ПРОВЕРКИ.
//   Требуется запущенный HTTP-тестовый сервер tools/net-test-server/ на
//   http://127.0.0.1:18080. Запуск:
//       python tools/net-test-server/net_test_server.py
//   Затем: .\examples\run-ctl.ps1 -Script .\examples\13-net\01_netGet.ctl -WaitSeconds 20
//
// Скрипт самодостаточен: создаёт свои счётчики проверок, не использует
// предустановленные точки данных проекта. net* функции не работают с точками
// данных — они только делают HTTP-запросы.

int dpdPass = 0;
int dpdFail = 0;

string BASE = "http://127.0.0.1:18080";

void dpdCheck(string what, bool ok)
{
  if (ok) { dpdPass++;  DebugN("  PASS  ", what); }
  else    { dpdFail++;  DebugN("  FAIL  ", what, "  lastError=", getLastError()); }
}

void dpdCheckRc(string what, int rc)
{
  if (rc == 0) { dpdPass++;  DebugN("  PASS  ", what, "  rc=0"); }
  else         { dpdFail++;  DebugN("  FAIL  ", what, "  rc=", rc, "  lastError=", getLastError()); }
}

void dpdCheckEq(string what, dyn_anytype a, dyn_anytype b)
{
  if (a == b) { dpdPass++;  DebugN("  PASS  ", what, "  ", a); }
  else        { dpdFail++;  DebugN("  FAIL  ", what, "  ожидалось=", b, "  получено=", a); }
}

void dpdSummary()
{
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
}

main()
{
  int rc;
  mapping r;

  DebugN("=== netGet(): клиентский HTTP GET ===");
  DebugN("Сервер: ", BASE, "  (нужен tools/net-test-server/net_test_server.py)");

  // ----------------------------------------------------------- 1. GET 200, mapping
  DebugN("");
  DebugN("--- 1. GET 200, результат в mapping ---");
  r = makeMapping();
  rc = netGet(BASE + "/get", r);
  DebugN("  rc=", rc, "  status=", r["httpStatusCode"], r["httpStatusText"]);
  DebugN("  url=", r["url"]);
  DebugN("  headers=", r["headers"]);
  DebugN("  content=", r["content"]);
  dpdCheckRc("netGet /get rc=0", rc);
  dpdCheckEq("httpStatusCode = 200", r["httpStatusCode"], 200);
  dpdCheckEq("httpStatusText = OK", r["httpStatusText"], "OK");
  dpdCheck("content не пуст", strlen(r["content"]) > 0);

  // ----------------------------------------------------------- 2. GET 404, mapping
  DebugN("");
  DebugN("--- 2. GET 404, результат в mapping (rc=-1, но статус есть) ---");
  rc = netGet(BASE + "/missing", r);
  DebugN("  rc=", rc, "  status=", r["httpStatusCode"], r["httpStatusText"]);
  DebugN("  content=", r["content"]);
  dpdCheck("netGet /missing rc=-1 (ошибка HTTP)", rc == -1);
  dpdCheckEq("httpStatusCode = 404", r["httpStatusCode"], 404);

  // ----------------------------------------------------------- 3. GET 200, string
  DebugN("");
  DebugN("--- 3. GET 200, результат в string (только тело) ---");
  string s;
  rc = netGet(BASE + "/get", s);
  DebugN("  rc=", rc, "  len=", strlen(s), "  body=", s);
  dpdCheckRc("netGet string rc=0", rc);
  dpdCheck("string содержит тело", strlen(s) > 0);

  // ----------------------------------------------------------- 4. GET 200, blob
  DebugN("");
  DebugN("--- 4. GET 200, результат в blob ---");
  blob b;
  rc = netGet(BASE + "/get", b);
  DebugN("  rc=", rc);
  dpdCheckRc("netGet blob rc=0", rc);

  // ----------------------------------------------------------- 5. Redirect off (302)
  DebugN("");
  DebugN("--- 5. GET с followRedirection=false: 302 не folgt ---");
  mapping opts;
  opts["followRedirection"] = false;
  rc = netGet(BASE + "/redirect", r, opts);
  DebugN("  rc=", rc, "  status=", r["httpStatusCode"], "  url=", r["url"]);
  dpdCheckRc("netGet redirect-off rc=0", rc);
  dpdCheckEq("httpStatusCode = 302", r["httpStatusCode"], 302);

  // ----------------------------------------------------------- 6. Redirect on (folge до 200)
  DebugN("");
  DebugN("--- 6. GET с followRedirection=true: редирект folgt до 200 ---");
  opts["followRedirection"] = true;
  rc = netGet(BASE + "/redirect", r, opts);
  DebugN("  rc=", rc, "  status=", r["httpStatusCode"], "  url=", r["url"]);
  dpdCheckRc("netGet redirect-on rc=0", rc);
  dpdCheckEq("httpStatusCode = 200 после редиректа", r["httpStatusCode"], 200);

  // ----------------------------------------------------------- 7. target-файл
  DebugN("");
  DebugN("--- 7. GET с target=файл (тело сохраняется в файл) ---");
  string tmpFile = "C:/Users/User/AppData/Local/Temp/opencode/netget_target.txt";
  opts["target"] = tmpFile;
  rc = netGet(BASE + "/get", r, opts);
  DebugN("  rc=", rc, "  target=", r["target"]);
  DebugN("  content в mapping=", r["content"]);
  dpdCheckRc("netGet target rc=0", rc);
  dpdCheckEq("target записан в result", r["target"], tmpFile);

  DebugN("");
  DebugN("=== ИТОГ: успешно ", dpdPass, ", неудачно ", dpdFail, " ===");
  dpdSummary();
}
