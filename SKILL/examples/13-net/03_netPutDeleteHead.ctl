// 03_netPutDeleteHead.ctl - тестирование netPut(), netDelete(), netHead().
//
// Документация: docs/13-http.md
//
// ПРОТОКОЛ ПРОВЕРКИ.
//   Требуется запущенный HTTP-тестовый сервер tools/net-test-server/ на
//   http://127.0.0.1:18080:
//       python tools/net-test-server/net_test_server.py
//   Затем: .\examples\run-ctl.ps1 -Script .\examples\13-net\03_netPutDeleteHead.ctl -WaitSeconds 20

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
  mapping r, data;

  DebugN("=== netPut / netDelete / netHead ===");
  DebugN("Сервер: ", BASE);

  // ------------------------------------------------------------ netPut
  DebugN("");
  DebugN("--- netPut: замена ресурса ---");
  data = makeMapping();
  data["content"] = "{\"name\":\"updated\",\"value\":99}";
  data["headers"] = makeMapping("Content-Type", "application/json");
  rc = netPut(BASE + "/put", data, r);
  DebugN("  rc=", rc, "  status=", r["httpStatusCode"], r["httpStatusText"]);
  DebugN("  content=", r["content"]);
  dpdCheckRc("netPut rc=0", rc);
  dpdCheckEq("httpStatusCode = 200", r["httpStatusCode"], 200);

  // ------------------------------------------------------------ netDelete
  DebugN("");
  DebugN("--- netDelete: удаление ресурса (204 No Content) ---");
  rc = netDelete(BASE + "/delete", r);
  DebugN("  rc=", rc, "  status=", r["httpStatusCode"], r["httpStatusText"]);
  DebugN("  content=", r["content"]);
  dpdCheckRc("netDelete rc=0", rc);
  dpdCheckEq("httpStatusCode = 204", r["httpStatusCode"], 204);
  dpdCheck("content пуст (204 без тела)", strlen(r["content"]) == 0);

  // ------------------------------------------------------------ netHead (mapping)
  DebugN("");
  DebugN("--- netHead: только заголовки, результат в mapping ---");
  rc = netHead(BASE + "/head", r);
  DebugN("  rc=", rc, "  status=", r["httpStatusCode"]);
  DebugN("  headers=", r["headers"]);
  DebugN("  content=", r["content"], "  (должно быть пусто)");
  dpdCheckRc("netHead rc=0", rc);
  dpdCheckEq("httpStatusCode = 200", r["httpStatusCode"], 200);
  dpdCheck("headers не пусты", mappingHasKey(r, "headers"));
  dpdCheck("content пуст (HEAD без тела)", strlen(r["content"]) == 0);

  // ------------------------------------------------------------ netHead (string)
  DebugN("");
  DebugN("--- netHead: результат в string (тело пустое — неинформативно) ---");
  string s;
  rc = netHead(BASE + "/head", s);
  DebugN("  rc=", rc, "  len=", strlen(s), "  body='", s, "'");
  dpdCheckRc("netHead string rc=0", rc);
  dpdCheck("string пуст (HEAD без тела)", strlen(s) == 0);

  DebugN("");
  DebugN("=== ИТОГ: успешно ", dpdPass, ", неудачно ", dpdFail, " ===");
  dpdSummary();
}
