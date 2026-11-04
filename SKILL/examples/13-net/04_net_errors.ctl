// 04_net_errors.ctl - тестирование ошибок net*: сеть, невалидный URL.
//
// Документация: docs/13-http.md
//
// ПРОТОКОЛ ПРОВЕРКИ.
//   Часть проверок не требует сервера (connection refused, невалидный URL).
//   Для части (500, 400) нужен запущенный tools/net-test-server/:
//       python tools/net-test-server/net_test_server.py
//   Затем: .\examples\run-ctl.ps1 -Script .\examples\13-net\04_net_errors.ctl -WaitSeconds 20

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

  DebugN("=== net*: обработка ошибок ===");

  // ------------------------------------------- 1. Connection refused (сервер не запущен)
  DebugN("");
  DebugN("--- 1. GET на несуществующий порт (connection refused) ---");
  rc = netGet("http://127.0.0.1:9/", r);
  DebugN("  rc=", rc);
  DebugN("  error=", r["error"]);
  DebugN("  errorString=", r["errorString"]);
  dpdCheck("netGet refused rc=-1", rc == -1);
  dpdCheck("errorString не пуст", strlen(r["errorString"]) > 0);

  // ------------------------------------------- 2. Невалидный URL
  DebugN("");
  DebugN("--- 2. GET с невалидным URL ---");
  rc = netGet("not-a-url", r);
  DebugN("  rc=", rc);
  DebugN("  error=", r["error"]);
  DebugN("  errorString=", r["errorString"]);
  dpdCheck("netGet invalid url rc=-1", rc == -1);

  // ------------------------------------------- 3. HTTP 500 (если сервер работает)
  DebugN("");
  DebugN("--- 3. GET /error -> HTTP 500 (требует сервер) ---");
  rc = netGet(BASE + "/error", r);
  DebugN("  rc=", rc, "  status=", r["httpStatusCode"], r["httpStatusText"]);
  DebugN("  content=", r["content"]);
  dpdCheck("netGet 500 rc=-1", rc == -1);
  dpdCheckEq("httpStatusCode = 500", r["httpStatusCode"], 500);

  // ------------------------------------------- 4. HTTP 400
  DebugN("");
  DebugN("--- 4. GET /bad -> HTTP 400 ---");
  rc = netGet(BASE + "/bad", r);
  DebugN("  rc=", rc, "  status=", r["httpStatusCode"], r["httpStatusText"]);
  dpdCheck("netGet 400 rc=-1", rc == -1);
  dpdCheckEq("httpStatusCode = 400", r["httpStatusCode"], 400);

  DebugN("");
  DebugN("=== ИТОГ: успешно ", dpdPass, ", неудачно ", dpdFail, " ===");
  dpdSummary();
}
