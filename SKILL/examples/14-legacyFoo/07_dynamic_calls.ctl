// 07_dynamic_calls.ctl - динамические вызовы: callFunction, checkScript,
// evalScript/evalScriptRestricted, execScript/execScriptRestricted.
// Документация: docs/14-legacyFoo.md (раздел 6).
// Проверено: CTL 3.18, проект <проект стенда>.
// Скрипт самодостаточен: точки данных не создаёт, сеть не используется.
//
// Измеренные оговорки 3.18:
//   - callFunction: private и synchronized функции того же скрипта вызываются,
//     возврат можно не присваивать (документация предупреждает о закрытии
//     скрипта); void-функция даёт undefined anytype + WARNING 73.
//   - checkScript: второй аргумент только int &errorPos, mapping &errorData
//     в 3.18 нет; TRUE ещё не значит "скрипт исполнится".
//   - evalScript/execScript: rc=-1 только для синтаксиса и отсутствия main;
//     ошибки времени выполнения дают rc=0 и SEVERE в журнале.
//   - restricted: запрещённая функция даёт rc=0 и WARNING 38 в журнале,
//     retVal сохраняет прежнее значение; callFunction запрет не обходит.

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

// ---------------------------------------------------------------- функции,
// которые вызываются по имени через callFunction()
int dynAdd(int a, int b)
{
  return a + b;
}

private int dynPrivate(int x)
{
  return x * 2;
}

uint dynLock;
int dynSync(int x) synchronized(dynLock)
{
  return x + 100;
}

int dynVoidSide = 0;
void dynVoid(int x)
{
  dynVoidSide = x;
}

main()
{
  DebugN("=== Динамические вызовы CTL ===");

  // ================================================== 1. callFunction
  DebugN("");
  DebugN("--- 1. callFunction: вызов функции по имени-строке ---");
  time t = callFunction("makeTime", 1999, 8, 13, 13, 40, 10, 50);
  int f = callFunction("floor", 2.25);
  DebugN("  floor(2.25) = ", f);
  dpdCheck("callFunction(\"floor\", 2.25) == 2", f == 2);

  int h = callFunction("hour", t);
  DebugN("  hour(t) = ", h);
  dpdCheck("callFunction(\"hour\", t) == 13", h == 13);

  int s = callFunction("dynAdd", 17, 8);
  DebugN("  dynAdd(17, 8) = ", s);
  dpdCheck("пользовательская функция = 25", s == 25);

  int p = callFunction("dynPrivate", 21);
  DebugN("  dynPrivate(21) = ", p);
  dpdCheck("private функция того же скрипта вызывается (42)", p == 42);

  int y = callFunction("dynSync", 5);
  DebugN("  dynSync(5) = ", y);
  dpdCheck("synchronized функция вызывается напрямую (105)", y == 105);

  dynVoidSide = 0;
  anytype v = callFunction("dynVoid", 7);
  DebugN("  dynVoid(7): side=", dynVoidSide, " type=", getTypeName(v));
  dpdCheck("void-функция выполнилась, side == 7", dynVoidSide == 7);
  dpdCheck("возврат void — anytype (оговорка 3.18)", getTypeName(v) == "anytype");

  int g = callFunction("floor", "not a number");
  DebugN("  floor(\"not a number\") = ", g);
  dpdCheck("неверный тип приводится, ошибки нет (0)", g == 0);

  dpdCheck("isFunctionDefined(\"hour\") == TRUE", isFunctionDefined("hour") == true);
  dpdCheck("isFunctionDefined(\"hour()\") == FALSE", isFunctionDefined("hour()") == false);
  dpdCheck("isFunctionDefined(\"Hour\") == FALSE (регистр)", isFunctionDefined("Hour") == false);
  dpdCheck("isFunctionDefined(\"nosuchfunc_xyz\") == FALSE", isFunctionDefined("nosuchfunc_xyz") == false);

  bool bareReached = false;
  callFunction("hour", t);          // возврат не присвоен — в 3.18 продолжает
  bareReached = true;
  dpdCheck("голый callFunction не закрывает скрипт (оговорка 3.18)", bareReached);

  bool debugReached = false;
  DebugN("  DebugN(callFunction(\"hour\")) = ", callFunction("hour", t));
  debugReached = true;
  dpdCheck("callFunction внутри DebugN не закрывает скрипт", debugReached);

  // ================================================== 2. checkScript
  DebugN("");
  DebugN("--- 2. checkScript: проверка синтаксиса перед запуском ---");
  int pos = -1;
  bool ok1 = checkScript("main(){ DebugN(123); }", pos);
  dpdCheck("корректный скрипт — TRUE", ok1);
  dpdCheck("errorPos корректного скрипта == 0", pos == 0);

  string bad1 = "main(){ DebugN(1; }";
  pos = -1;
  bool ok2 = checkScript(bad1, pos);
  DebugN("  bad1 pos = ", pos);
  dpdCheck("битый скрипт — FALSE", ok2 == false);
  dpdCheck("errorPos == 16 (0-based позиция ';')", pos == 16);

  pos = -1;
  bool ok3 = checkScript("main( {", pos);
  DebugN("  bad2 pos = ", pos);
  dpdCheck("вторая ошибка — FALSE", ok3 == false);
  dpdCheck("errorPos == 6", pos == 6);

  pos = -1;
  bool ok4 = checkScript("int main(){ return ; }", pos);
  DebugN("  bad3 pos = ", pos);
  dpdCheck("третья ошибка — FALSE", ok4 == false);
  dpdCheck("errorPos == 19", pos == 19);

  dpdCheck("пустая строка — TRUE (оговорка 3.18)",
           checkScript("") == true);
  dpdCheck("скрипт без main — TRUE: проверяется только синтаксис",
           checkScript("int foo(){ return 1; }") == true);
  dpdCheck("повторная переменная — TRUE (оговорка 3.18)",
           checkScript("main(){ int x; int x; }") == true);
  dpdCheck("неизвестная функция — TRUE: имя не проверяется",
           checkScript("int main(){ return nosuchfunc_xyz(); }") == true);
  dpdCheck("запрещённая в restricted функция — TRUE",
           checkScript("int main(){ int x; dpGet(\"System1:_1s\", x); }") == true);
  dpdCheck("пропущенная ';' — FALSE",
           checkScript("int main(){ return 1 }") == false);

  // ================================================== 3. evalScript/execScript
  DebugN("");
  DebugN("--- 3. evalScript/execScript: выполнение текста скрипта ---");
  anytype ret;
  int rc = evalScript(ret, "int main(){ return 42; }");
  DebugN("  rc=", rc, " ret=", ret);
  dpdCheck("evalScript: rc == 0", rc == 0);
  dpdCheck("evalScript: возврат 42", ret == 42);

  int sum = 0;
  rc = evalScript(sum, "int main(int a, int b){ return a + b; }",
                  makeDynString(), 17, 8);
  DebugN("  args rc=", rc, " sum=", sum);
  dpdCheck("evalScript: аргументы main дают 25", rc == 0 && sum == 25);

  int dol = 0;
  rc = evalScript(dol, "int main(){ return $val1; }",
                  makeDynString("$val1:12345"));
  DebugN("  $val1 rc=", rc, " dol=", dol);
  dpdCheck("evalScript: $val1 == 12345", rc == 0 && dol == 12345);

  int noMain = 0;
  rc = evalScript(noMain, "int foo(){ return 1; }");
  DebugN("  нет main rc=", rc);
  dpdCheck("evalScript: нет main → rc == -1", rc == -1);

  int keep = 777;
  rc = evalScript(keep, "int main(){ return ; }");
  DebugN("  синтаксис rc=", rc, " keep=", keep);
  dpdCheck("evalScript: синтаксис → rc == -1", rc == -1);
  dpdCheck("evalScript: retVal при ошибке не сбрасывается", keep == 777);

  int tm = 5;
  rc = evalScript(tm, "string main(){ return \"abc\"; }");
  DebugN("  тип rc=", rc, " tm=", tm);
  dpdCheck("evalScript: несовпадение типа — rc == 0", rc == 0);
  dpdCheck("evalScript: несовпадение типа — молча 0", tm == 0);

  int cf = 0;
  rc = evalScript(cf, "int main(){ return dynAdd(1, 2); }");
  DebugN("  функция вызывающего rc=", rc, " cf=", cf);
  dpdCheck("evalScript: функцию вызывающего скрипта вызвать нельзя — rc == 0",
           rc == 0);
  dpdCheck("evalScript: её результат не получен — 0", cf == 0);

  int uf = 0;
  rc = evalScript(uf, "int main(){ return nosuchfunc_xyz(); }");
  DebugN("  неизвестная функция rc=", rc);
  dpdCheck("evalScript: неизвестная функция — rc == 0 (SEVERE в журнале)",
           rc == 0);

  int md = 0;
  rc = evalScript(md, "int main(){ return $noval; }");
  DebugN("  нет $ параметра rc=", rc);
  dpdCheck("evalScript: отсутствующий $ — rc == 0 (SEVERE в журнале)",
           rc == 0);

  int ne = 0;
  rc = evalScript(ne,
      "int main(){ anytype r; int c = evalScript(r, \"int main(){ return 5; }\");"
      + " return c * 100 + r; }");
  DebugN("  вложенный eval rc=", rc, " ne=", ne);
  dpdCheck("evalScript: вложенный вызов работает", rc == 0 && ne == 5);

  rc = execScript("int main(int a, int b){ return a + b; }", makeDynString(), 2, 3);
  DebugN("  execScript int main rc=", rc);
  dpdCheck("execScript: int main с возвратом работает — rc == 0", rc == 0);

  rc = execScript("int main(){ DebugN(\"  execScript выполнился\"); }");
  DebugN("  execScript void rc=", rc);
  dpdCheck("execScript: void main — rc == 0", rc == 0);

  rc = execScript("int main(){ DebugN(\"  $val1=\", $val1); }",
                  makeDynString("$val1:777"));
  dpdCheck("execScript: $ параметр — rc == 0", rc == 0);

  rc = execScript("int foo(){ return 1; }");
  DebugN("  execScript нет main rc=", rc);
  dpdCheck("execScript: нет main → rc == -1", rc == -1);

  rc = execScript("int main(){ return ; }");
  DebugN("  execScript синтаксис rc=", rc);
  dpdCheck("execScript: синтаксис → rc == -1", rc == -1);

  // ================================================== 4. restricted
  DebugN("");
  DebugN("--- 4. restricted: разрешённое и запрещённое ---");
  int ar = 0;
  rc = evalScriptRestricted(ar, "int main(){ return strlen(\"abc\"); }");
  DebugN("  strlen rc=", rc, " ar=", ar);
  dpdCheck("restricted: strlen разрешён — rc == 0", rc == 0);
  dpdCheck("restricted: результат 3", ar == 3);

  int ac = 0;
  rc = evalScriptRestricted(ac,
      "int main(){ if (checkScript(\"main(){}\")) { return 1; } return 0; }");
  dpdCheck("restricted: checkScript разрешён", rc == 0 && ac == 1);

  int nr = 0;
  rc = evalScriptRestricted(nr,
      "int main(){ anytype r; int c = evalScriptRestricted(r, \"int main(){ return 3; }\");"
      + " return c * 10 + r; }");
  DebugN("  вложенный restricted rc=", rc, " nr=", nr);
  dpdCheck("restricted: вложенный restricted — rc == 0", rc == 0);
  dpdCheck("restricted: вложенный запрещён в 3.18 (0, WARNING 38)", nr == 0);

  int fr = 999;
  rc = evalScriptRestricted(fr,
      "int main(){ int x; dpGet(\"System1:_1s\", x); return 1; }");
  DebugN("  dpGet rc=", rc, " fr=", fr);
  dpdCheck("restricted: dpGet запрещён — rc == 0 (WARNING 38)", rc == 0);
  dpdCheck("restricted: retVal сохраняет прежнее значение (999)", fr == 999);

  int ng = 0;
  rc = evalScriptRestricted(ng,
      "int main(){ mapping m = netGet(\"http://127.0.0.1:1/\"); return 1; }");
  DebugN("  netGet rc=", rc);
  dpdCheck("restricted: netGet запрещён — rc == 0", rc == 0);

  int br = 0;
  rc = evalScriptRestricted(br,
      "int main(){ mapping m = callFunction(\"netGet\", \"http://127.0.0.1:1/\"); return 1; }");
  DebugN("  netGet через callFunction rc=", rc);
  dpdCheck("restricted: callFunction не обходит запрет — rc == 0", rc == 0);

  int cr = 0;
  rc = evalScriptRestricted(cr,
      "int main(){ return callFunction(\"strlen\", \"abcd\"); }");
  DebugN("  callFunction(strlen) rc=", rc, " cr=", cr);
  dpdCheck("restricted: callFunction к разрешённой функции работает", rc == 0 && cr == 4);

  rc = execScriptRestricted("int main(){ DebugN(\"  execScriptRestricted выполнился\"); }");
  DebugN("  execScriptRestricted rc=", rc);
  dpdCheck("execScriptRestricted: разрешённое — rc == 0", rc == 0);

  rc = execScriptRestricted("int main(){ dpSet(\"System1:no_such_dp_probe.elt\", 1); }");
  DebugN("  execScriptRestricted dpSet rc=", rc);
  dpdCheck("execScriptRestricted: dpSet запрещён — rc == 0", rc == 0);

  rc = execScriptRestricted("int main(){ return ; }");
  DebugN("  execScriptRestricted синтаксис rc=", rc);
  dpdCheck("execScriptRestricted: синтаксис → rc == -1", rc == -1);

  dpdSummary();
  exit(0);
}
