// 01_netGet_influx.ctl - прямые HTTP-запросы к InfluxDB проекта из CTL.
//
// Документация: docs/15-influx.md
//
// ⛔ ТОЛЬКО ЧТЕНИЕ. Скрипт делает исключительно GET /query. Запись в базу
//    (POST /write, line protocol, INSERT/DROP/DELETE) запрещена и здесь не
//    выполняется ни при каких условиях.
//
// ПРОТОКОЛ ПРОВЕРКИ.
//   Нужна живая InfluxDB стенда: InfluxDB 1.8.3 OSS на 127.0.0.1:8086,
//   база kaskadhdb, пользователь kaskad. Если базы нет, проверки упадут -
//   это ожидаемо, раздел в гейт по умолчанию не входит.
//   Запуск:
//       .\examples\run-ctl.ps1 -Script .\examples\15-influx\01_netGet_influx.ctl
//   Раздел: .\examples\verify.ps1 -Section 15-influx
//
// Почему URL собирается через httpMakeParamString(): в пароле есть '#',
// незакодированный символ обрывает query-строку и сервер отвечает 401.
// Хелпер кодирует и '#', и кавычки, и пробелы в тексте запроса.

#uses "CtrlHTTP"

int dpdPass = 0;
int dpdFail = 0;

int    PORT = 8086;
string DB   = "kaskadhdb";
string USER = "kaskad";
string PASS = "kaskad#123";

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

void dpdSummary()
{
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
}

// Собирает URL /query: db, u, p плюс одна пара из аргументов.
string influxUrl(dyn_string extraNames, dyn_string extraValues)
{
  dyn_string names  = makeDynString("db", "u", "p");
  dyn_string values = makeDynString(DB, USER, PASS);
  int i;
  for (i = 1; i <= dynlen(extraNames) && i <= dynlen(extraValues); i++)
  {
    dynAppend(names, extraNames[i]);
    dynAppend(values, extraValues[i]);
  }
  return "http://127.0.0.1:" + PORT + "/query?" + httpMakeParamString(names, values);
}

// Код ответа или 0, если netGet не дошёл до сервера.
int statusOf(mapping res)
{
  if (mappingHasKey(res, "httpStatusCode")) return (int)res["httpStatusCode"];
  return 0;
}

// GET запроса и разбор JSON. Возвращает rc из netGet.
int influxQuery(string url, mapping &res, mapping &doc)
{
  int rc = netGet(url, res);
  string body = "";
  if (mappingHasKey(res, "content")) body = (string)res["content"];
  if (strlen(body) > 0) doc = jsonDecode(body);
  return rc;
}

// Первая серия ответа. has = false, если ключа series нет (пустой результат).
mapping firstSeries(mapping doc, bool &has)
{
  mapping none;
  has = false;
  if (!mappingHasKey(doc, "results")) return none;
  dyn_mixed results = doc["results"];
  if (dynlen(results) < 1) return none;
  mapping r0 = results[1];
  if (!mappingHasKey(r0, "series")) return none;
  dyn_mixed series = r0["series"];
  if (dynlen(series) < 1) return none;
  has = true;
  return (mapping)series[1];
}

main()
{
  int rc;
  mapping res;
  mapping doc;
  mapping s;
  bool has = false;
  string body = "";

  DebugN("=== InfluxDB: прямые HTTP-запросы из CTL (только чтение) ===");
  DebugN("База: ", DB, "  адрес: 127.0.0.1:", PORT, "  пользователь: ", USER);

  // -------------------------------------------------- 1. кодирование пароля
  DebugN("");
  DebugN("--- 1. httpMakeParamString кодирует пароль с '#' ---");
  dyn_string n = makeDynString("db", "u", "p");
  dyn_string v = makeDynString(DB, USER, PASS);
  string qs = httpMakeParamString(n, v);
  DebugN("  query = ", qs);
  dpdCheck("пароль закодирован как kaskad%23123", strpos(qs, "kaskad%23123") >= 0);
  dpdCheck("в query нет незакодированного '#'", strpos(qs, "#") < 0);

  // -------------------------------------------------- 2. последние 3 события
  DebugN("");
  DebugN("--- 2. GET /query: последние 3 события EVENT ---");
  string url3 = influxUrl(makeDynString("q"),
    makeDynString("SELECT * FROM \"EVENT\".\"EVENT\" ORDER BY time DESC LIMIT 3"));
  rc = influxQuery(url3, res, doc);
  DebugN("  rc=", rc, "  status=", statusOf(res));
  dpdCheckRc("netGet /query rc=0", rc);
  dpdCheck("httpStatusCode = 200", statusOf(res) == 200);

  // -------------------------------------------------- 3. форма ответа
  DebugN("");
  DebugN("--- 3. ответ - JSON с results ---");
  dpdCheck("в ответе есть results", mappingHasKey(doc, "results"));
  dyn_mixed results = doc["results"];
  dpdCheck("results длиной 1", dynlen(results) == 1);

  // -------------------------------------------------- 4. серия EVENT
  DebugN("");
  DebugN("--- 4. серия EVENT ---");
  s = firstSeries(doc, has);
  dpdCheck("ключ series есть", has);
  dpdCheck("name = EVENT", has && (string)s["name"] == "EVENT");
  dyn_mixed cols = s["columns"];
  dpdCheck("колонок 12", has && dynlen(cols) == 12);
  dpdCheck("первая колонка time", has && (string)cols[1] == "time");

  // -------------------------------------------------- 5. строки
  DebugN("");
  DebugN("--- 5. строки ответа ---");
  dyn_mixed rows = s["values"];
  dpdCheck("строк 3", has && dynlen(rows) == 3);
  dyn_mixed row1;
  if (has && dynlen(rows) > 0) row1 = rows[1];
  dpdCheck("в строке 12 значений", dynlen(row1) == 12);
  string t1 = (string)row1[1];
  dpdCheck("время в UTC (кончается на Z)", strlen(t1) > 0 && substr(t1, strlen(t1) - 1, 1) == "Z");

  // -------------------------------------------------- 6. count по полю
  DebugN("");
  DebugN("--- 6. count(valuetype) по EVENT ---");
  rc = influxQuery(influxUrl(makeDynString("q"),
    makeDynString("SELECT count(\"valuetype\") FROM \"EVENT\".\"EVENT\"")), res, doc);
  s = firstSeries(doc, has);
  dyn_mixed cntRow;
  if (has && dynlen(s["values"]) > 0) cntRow = ((dyn_mixed)s["values"])[1];
  int cnt = 0;
  if (dynlen(cntRow) > 1) cnt = (int)cntRow[2];
  DebugN("  rc=", rc, "  count=", cnt);
  dpdCheckRc("count rc=0", rc);
  dpdCheck("count > 0 (база пополняется)", cnt > 0);

  // -------------------------------------------------- 7. пустой результат
  DebugN("");
  DebugN("--- 7. пустой результат: нет ключа series ---");
  rc = influxQuery(influxUrl(makeDynString("q"),
    makeDynString("SELECT \"original_value_float\" FROM \"EVENT\".\"EVENT\" WHERE time > now() + 1h")),
    res, doc);
  s = firstSeries(doc, has);
  DebugN("  rc=", rc, "  status=", statusOf(res), "  series=", has);
  dpdCheckRc("пустой ответ rc=0", rc);
  dpdCheck("httpStatusCode = 200", statusOf(res) == 200);
  dpdCheck("series отсутствует", !has);

  // -------------------------------------------------- 8. неверный пароль
  DebugN("");
  DebugN("--- 8. неверный пароль -> 401 ---");
  mapping res401;
  mapping doc401;
  string urlBad = "http://127.0.0.1:" + PORT + "/query?"
                + httpMakeParamString(makeDynString("db", "u", "p", "q"),
                    makeDynString(DB, USER, "wrong", "SHOW MEASUREMENTS"));
  rc = influxQuery(urlBad, res401, doc401);
  body = "";
  if (mappingHasKey(res401, "content")) body = (string)res401["content"];
  DebugN("  rc=", rc, "  status=", statusOf(res401), "  body=", body);
  dpdCheck("rc=-1 при 401", rc == -1);
  dpdCheck("httpStatusCode = 401", statusOf(res401) == 401);
  dpdCheck("тело содержит authorization failed", strpos(body, "authorization failed") >= 0);

  // -------------------------------------------------- 9. ошибка в запросе
  DebugN("");
  DebugN("--- 9. синтаксическая ошибка -> 400 ---");
  mapping res400;
  mapping doc400;
  rc = influxQuery(influxUrl(makeDynString("q"), makeDynString("SELECT * FROM")),
                   res400, doc400);
  body = "";
  if (mappingHasKey(res400, "content")) body = (string)res400["content"];
  DebugN("  rc=", rc, "  status=", statusOf(res400), "  body=", body);
  dpdCheck("rc=-1 при 400", rc == -1);
  dpdCheck("httpStatusCode = 400", statusOf(res400) == 400);
  dpdCheck("тело содержит error parsing query", strpos(body, "error parsing query") >= 0);

  // -------------------------------------------------- итог
  DebugN("");
  DebugN("=== ИТОГ: успешно ", dpdPass, ", неудачно ", dpdFail, " ===");
  dpdSummary();
}
