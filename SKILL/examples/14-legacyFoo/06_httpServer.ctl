// 06_httpServer.ctl - HTTP-сервер в CTL: httpServer, httpConnect, httpDisconnect,
// данные запроса (httpGet*) и настройки (httpSet*).
// Документация: docs/14-legacyFoo.md (раздел 5).
// Проверено: CTL 3.18, проект <проект стенда>.
//
// Скрипт самодостаточен: поднимает сервер на 127.0.0.1, сам делает loopback-
// запросы через netGet/netPost и завершает менеджер через exit(0). Внешняя
// сеть не используется.
//
// Измеренные оговорки 3.18:
//   - сервер держит менеджер живым: без exit(0) процесс не завершается;
//   - занятый порт даёт rc = -1, но getLastError() пуст (ошибка только в журнале);
//   - Status из dyn_string становится обычным заголовком, статус остаётся 200;
//   - Status из dyn_mixed действительно меняет HTTP-статус;
//   - httpSetMethodHandler принимает DELETE/PUT/OPTIONS/TRACE/CONNECT,
//     но не PATCH/HEAD/GET/POST.

#uses "CtrlHTTP"

int dpdPass = 0;
int dpdFail = 0;

void dpdCheck(string what, bool ok)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "  lastError=", getLastError()); }
}

void dpdSummary()
{
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
}

// ------------------------------------------------------------------ состояние
int      cbCalls = 0;
string   cbMethod;
string   cbUri;
string   cbPort;
string   cbIp;
string   cbHeader;
mapping  cbQuery;
mapping  cbHeaders;
int      cbLang = -1;
int      cbLangId = -1;
int      cbContentRc = -99;
string   cbContent = "";

string echoCB(dyn_string names, dyn_string values, string user, string ip,
              dyn_string headerNames, dyn_string headerValues, int idx)
{
  cbCalls++;
  cbMethod  = httpGetMethod(idx);
  cbUri     = httpGetURI(idx);
  cbPort    = httpGetPort(idx);
  cbIp      = ip;
  cbQuery   = httpGetQuery(idx);
  cbHeaders = httpGetAllHeaders(idx);
  cbHeader  = httpGetHeader(idx, "user-agent");
  cbLang    = httpGetLanguage(idx);
  cbLangId  = (int)httpGetLanguageId(idx);
  cbContentRc = httpGetContent(idx, cbContent);
  return "echo-ok";
}

// POST application/x-www-form-urlencoded
int      formCalls = 0;
string   formName0;
string   formVal0;
string   formVal1;
string   formMethod;
mapping  formQuery;
int      formContentRc = -99;
string   formContent = "";

string formCB(dyn_string names, dyn_string values, string user, string ip,
              dyn_string headerNames, dyn_string headerValues, int idx)
{
  formCalls++;
  formMethod = httpGetMethod(idx);
  formQuery  = httpGetQuery(idx);
  if (dynlen(names) > 0) formName0 = names[1];
  if (dynlen(values) > 0) formVal0 = values[1];
  if (dynlen(values) > 1) formVal1 = values[2];
  formContentRc = httpGetContent(idx, formContent);
  return "form-ok";
}

// POST text/plain
int    textCalls = 0;
string textContent = "";

string textCB(string content, string user, string ip,
              dyn_string headerNames, dyn_string headerValues, int idx)
{
  textCalls++;
  textContent = content;
  return "text-ok";
}

// dyn_string: первый элемент - тело, остальные - заголовки
dyn_string richCB()
{
  dyn_string r;
  r[1] = "rich-body";
  r[2] = "X-Probe: yes";
  r[3] = "Status: 201 Created";
  return r;
}

// dyn_mixed: Status действительно меняет HTTP-статус
string mixedCB()
{
  dyn_mixed n;
  dynAppend(n, "mixed-body");
  dynAppend(n, "Status: 404 Not found");
  dynAppend(n, "X-Mixed: yes");
  return n;
}

// callback без аргументов
int    minCalls = 0;
string minUri = "";

string minCB()
{
  minCalls++;
  minUri = httpGetURI(0);
  return "min-ok";
}

// шаблон ресурса
int    patCalls = 0;
string patUri = "";

string patCB()
{
  patCalls++;
  patUri = httpGetURI(0);
  return "pat-ok";
}

// метод DELETE, перенаправленный через httpSetMethodHandler
string delCB(string clientIP, string url, int idx)
{
  return "deleted";
}

main()
{
  DebugN("=== HTTP-сервер: httpServer и семейство http* ===");

  // ------------------------------------------------------ 1. запуск
  DebugN("");
  DebugN("--- 1. httpServer: высокий порт со свободным fallback ---");
  int port = 0;
  int i;
  for (i = 18081; i <= 18089; i++)
  {
    if (httpServer(false, i, 0) == 0) { port = i; i = 18090; }
  }
  DebugN("  порт=", port);
  dpdCheck("httpServer поднялся (rc==0)", port != 0);
  if (port == 0) { dpdSummary(); exit(0); }

  int rcSecond = httpServer(false, port + 100, 0);
  DebugN("  повторный httpServer rc=", rcSecond);
  dpdCheck("второй httpServer rc==-1", rcSecond == -1);

  // ------------------------------------------------------ 2. регистрация
  DebugN("");
  DebugN("--- 2. httpConnect / httpDisconnect ---");
  int rcConn = httpConnect("echoCB", "/echo");
  DebugN("  httpConnect(\"/echo\") rc=", rcConn);
  dpdCheck("httpConnect rc==0", rcConn == 0);
  dpdCheck("повторный httpConnect rc==-1", httpConnect("echoCB", "/echo") == -1);

  dpdCheck("httpConnect formCB", httpConnect("formCB", "/form") == 0);
  dpdCheck("httpConnect textCB", httpConnect("textCB", "/text") == 0);
  dpdCheck("httpConnect richCB", httpConnect("richCB", "/rich") == 0);
  dpdCheck("httpConnect mixedCB", httpConnect("mixedCB", "/mixed") == 0);
  dpdCheck("httpConnect minCB", httpConnect("minCB", "/min") == 0);
  dpdCheck("httpConnect по шаблону /api/*", httpConnect("patCB", "/api/*") == 0);

  int rcNoCb = httpConnect("noSuchCallback", "/nope");
  DebugN("  httpConnect с несуществующим callback rc=", rcNoCb);
  dpdCheck("несуществующий callback: rc==-1", rcNoCb == -1);

  // ------------------------------------------------------ 3. GET
  DebugN("");
  DebugN("--- 3. GET: данные запроса ---");
  string res;
  int rcGet = netGet("http://127.0.0.1:" + port + "/echo?a=hello%20world&b=two+words", res);
  DebugN("  netGet rc=", rcGet, " res=\"", res, "\"");
  DebugN("  method=\"", cbMethod, "\" uri=\"", cbUri, "\" port=\"", cbPort, "\"");
  DebugN("  query=", cbQuery);
  DebugN("  ip=\"", cbIp, "\" ua=\"", cbHeader, "\" lang=", cbLang, " langId=", cbLangId);
  DebugN("  httpGetContent rc=", cbContentRc, " content=\"", cbContent, "\"");

  dpdCheck("netGet rc==0", rcGet == 0);
  dpdCheck("ответ callback = echo-ok", res == "echo-ok");
  dpdCheck("httpGetMethod = GET", cbMethod == "GET");
  dpdCheck("httpGetURI без query = /echo", cbUri == "/echo");
  dpdCheck("query a = hello world", (string)cbQuery["a"] == "hello world");
  dpdCheck("query b = two words", (string)cbQuery["b"] == "two words");
  dpdCheck("httpGetHeader нечувствителен к регистру", strlen(cbHeader) > 0);
  dpdCheck("httpGetAllHeaders содержит User-Agent", mappingHasKey(cbHeaders, "User-Agent"));
  dpdCheck("httpGetPort = выбранный порт", (int)cbPort == port);
  dpdCheck("httpGetLanguage >= 0", cbLang >= 0);
  dpdCheck("httpGetLanguageId >= 0", cbLangId >= 0);
  dpdCheck("httpGetContent на GET: rc==0 и пусто", cbContentRc == 0 && strlen(cbContent) == 0);

  // ------------------------------------------------------ 4. шаблон ресурса
  DebugN("");
  DebugN("--- 4. шаблон ресурса /api/* ---");
  string patOut;
  int rcPat = netGet("http://127.0.0.1:" + port + "/api/thing", patOut);
  DebugN("  netGet rc=", rcPat, " content=\"", patOut, "\" uri=\"", patUri, "\"");
  dpdCheck("шаблон вызвал callback", rcPat == 0 && patCalls == 1 && patOut == "pat-ok");
  dpdCheck("httpGetURI = /api/thing", patUri == "/api/thing");

  // ------------------------------------------------------ 5. POST form
  DebugN("");
  DebugN("--- 5. POST application/x-www-form-urlencoded ---");
  mapping formData, formOut;
  formData["content"] = "alpha=1&beta=two+words";
  formData["headers"] = makeMapping("Content-Type", "application/x-www-form-urlencoded");
  int rcForm = netPost("http://127.0.0.1:" + port + "/form?pre=1", formData, formOut);
  DebugN("  netPost rc=", rcForm, " status=", formOut["httpStatusCode"]);
  DebugN("  names[1]=\"", formName0, "\" values[1]=\"", formVal0, "\" values[2]=\"", formVal1, "\"");
  DebugN("  query=", formQuery, " contentRc=", formContentRc, " content=\"", formContent, "\"");
  dpdCheck("netPost rc==0", rcForm == 0);
  dpdCheck("form callback вызван", formCalls == 1);
  dpdCheck("httpGetMethod = POST", formMethod == "POST");
  dpdCheck("form names[1] = alpha", formName0 == "alpha");
  dpdCheck("form values[1] = 1, values[2] = two words", formVal0 == "1" && formVal1 == "two words");
  dpdCheck("httpGetQuery у POST = URL query", (string)formQuery["pre"] == "1");
  dpdCheck("httpGetContent вернул тело формы", formContentRc == 0 && formContent == "alpha=1&beta=two+words");

  // ------------------------------------------------------ 6. POST text
  DebugN("");
  DebugN("--- 6. POST text/plain ---");
  mapping textData, textOut;
  textData["content"] = "hello text body";
  textData["headers"] = makeMapping("Content-Type", "text/plain");
  int rcText = netPost("http://127.0.0.1:" + port + "/text", textData, textOut);
  DebugN("  netPost rc=", rcText, " content=\"", textContent, "\"");
  dpdCheck("netPost rc==0", rcText == 0);
  dpdCheck("text callback получил тело", textCalls == 1 && textContent == "hello text body");

  // ------------------------------------------------------ 7. return types
  DebugN("");
  DebugN("--- 7. dyn_string и dyn_mixed в ответе ---");
  mapping richOut;
  int rcRich = netGet("http://127.0.0.1:" + port + "/rich", richOut);
  mapping richHdr;
  if (mappingHasKey(richOut, "headers")) richHdr = richOut["headers"];
  DebugN("  /rich status=", richOut["httpStatusCode"], " content=\"", richOut["content"], "\"");
  DebugN("  /rich headers=", richHdr);
  dpdCheck("/rich content = rich-body", richOut["content"] == "rich-body");
  dpdCheck("/rich X-Probe = yes", mappingHasKey(richHdr, "X-Probe") && (string)richHdr["X-Probe"] == "yes");
  dpdCheck("/rich Status из dyn_string не меняет код (200)", (int)richOut["httpStatusCode"] == 200);

  mapping mixedOut;
  int rcMixed = netGet("http://127.0.0.1:" + port + "/mixed", mixedOut);
  mapping mixedHdr;
  if (mappingHasKey(mixedOut, "headers")) mixedHdr = mixedOut["headers"];
  DebugN("  /mixed rc=", rcMixed, " status=", mixedOut["httpStatusCode"], " content=\"", mixedOut["content"], "\"");
  dpdCheck("/mixed Status из dyn_mixed даёт 404", (int)mixedOut["httpStatusCode"] == 404);
  dpdCheck("/mixed rc==-1, но тело доступно", rcMixed == -1 && mixedOut["content"] == "mixed-body");
  dpdCheck("/mixed X-Mixed = yes", mappingHasKey(mixedHdr, "X-Mixed"));

  // ------------------------------------------------------ 8. callback без аргументов
  DebugN("");
  DebugN("--- 8. callback без аргументов ---");
  string minOut;
  int rcMin = netGet("http://127.0.0.1:" + port + "/min", minOut);
  DebugN("  netGet rc=", rcMin, " content=\"", minOut, "\" calls=", minCalls, " uri=\"", minUri, "\"");
  dpdCheck("callback без аргументов вызван", rcMin == 0 && minCalls == 1 && minOut == "min-ok");

  // ------------------------------------------------------ 9. настройки
  DebugN("");
  DebugN("--- 9. httpSet* и httpMakeParamString ---");
  dpdCheck("httpSetMaxAge rc==0", httpSetMaxAge(3600) == 0);
  dpdCheck("httpSetMaxContentLength rc==0", httpSetMaxContentLength(200000) == 0);
  int rcDel = httpSetMethodHandler("DELETE", "delCB");
  int rcGetMh = httpSetMethodHandler("GET", "delCB");
  DebugN("  httpSetMethodHandler DELETE rc=", rcDel, " GET rc=", rcGetMh);
  dpdCheck("httpSetMethodHandler DELETE rc==0", rcDel == 0);
  dpdCheck("httpSetMethodHandler GET rc==-1 (чёрный список)", rcGetMh == -1);

  dyn_string pn = makeDynString("first", "second");
  dyn_string pv = makeDynString("first value", "second-value");
  string qs = httpMakeParamString(pn, pv);
  DebugN("  httpMakeParamString = \"", qs, "\"");
  dpdCheck("httpMakeParamString кодирует пробел", qs == "first=first%20value&second=second-value");

  // ------------------------------------------------------ 10. отключение
  DebugN("");
  DebugN("--- 10. httpDisconnect ---");
  int rcDis = httpDisconnect("/echo");
  DebugN("  httpDisconnect(\"/echo\") rc=", rcDis);
  dpdCheck("httpDisconnect rc==0", rcDis == 0);
  dpdCheck("повторный httpDisconnect rc==-1", httpDisconnect("/echo") == -1);

  dpdSummary();
  exit(0);
}
