// 02_netPost.ctl - тестирование клиентской HTTP-функции netPost().
//
// Документация: docs/13-http.md
//
// ПРОТОКОЛ ПРОВЕРКИ.
//   Требуется запущенный HTTP-тестовый сервер tools/net-test-server/ на
//   http://127.0.0.1:18080:
//       python tools/net-test-server/net_test_server.py
//   Затем: .\examples\run-ctl.ps1 -Script .\examples\13-net\02_netPost.ctl -WaitSeconds 20

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
  mapping data, r;

  DebugN("=== netPost(): клиентский HTTP POST ===");
  DebugN("Сервер: ", BASE);

  // -------------------------------------------------- 1. POST JSON, mapping data, mapping result
  DebugN("");
  DebugN("--- 1. POST JSON: data=mapping, result=mapping ---");
  data = makeMapping();
  data["content"] = "{\"name\":\"test\",\"value\":42}";
  data["headers"] = makeMapping("Content-Type", "application/json", "X-Probe", "client-ok");
  rc = netPost(BASE + "/post", data, r);
  DebugN("  rc=", rc, "  status=", r["httpStatusCode"], r["httpStatusText"]);
  DebugN("  content=", r["content"]);
  dpdCheckRc("netPost JSON rc=0", rc);
  dpdCheckEq("httpStatusCode = 201", r["httpStatusCode"], 201);
  dpdCheck("ответ содержит эхо тела", strlen(r["content"]) > 0);

  // -------------------------------------------------- 2. POST string data
  DebugN("");
  DebugN("--- 2. POST string data (result не запрашиваем) ---");
  rc = netPost(BASE + "/post", "{\"name\":\"plain\"}");
  DebugN("  rc=", rc);
  dpdCheckRc("netPost string data rc=0", rc);

  // -------------------------------------------------- 3. POST с Content-Type через headers
  DebugN("");
  DebugN("--- 3. POST без Content-Type: сервер получит пустой contentType ---");
  data = makeMapping();
  data["content"] = "{\"x\":1}";
  // headers без Content-Type
  data["headers"] = makeMapping("X-Probe", "no-ctype");
  rc = netPost(BASE + "/post", data, r);
  DebugN("  rc=", rc, "  status=", r["httpStatusCode"]);
  DebugN("  content=", r["content"]);
  dpdCheckRc("netPost без Content-Type rc=0", rc);

  DebugN("");
  DebugN("=== ИТОГ: успешно ", dpdPass, ", неудачно ", dpdFail, " ===");
  dpdSummary();
}
