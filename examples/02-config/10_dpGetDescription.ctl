// 10_dpGetDescription.ctl - dpGetDescription(): описание элемента и режимы mode.
//
// Документация: docs/02-config.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем: создаёт свой тип и
// свою точку данных, в конце удаляет и то, и другое.
//
// Описание - свойство ЭЛЕМЕНТА (DPE), а не точки данных. Имя элемента
// передаётся БЕЗ завершающей точки (установлено на стенде).
//
// ГЛАВНОЕ. Пустой результат НЕ означает "нет описания": при mode >= 0
// подставляется имя элемента или точки данных. Проверить наличие описания
// можно только сравнением с mode = -2, который не подставляет ничего.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "cfgdesc_t";
string DP  = "dpdemo_cfgdesc_dp";

main()
{
  DebugN("=== dpGetDescription(): описания и режимы mode ===");

  makeType();
  makeDp();

  // -------------------------------------------------------------------
  // 1. Описание элемента
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Описание элемента ---");

  langString dFlow = "Расход";
  int rcSet = dpSetDescription(DP + ".fVal", dFlow);
  DebugN("  dpSetDescription(fVal) rc=", rcSet, "  lastError=", getLastError());
  dpdCheck(rcSet == 0, "описание задано", rcSet);

  langString got = dpGetDescription(DP + ".fVal");
  DebugN("  dpGetDescription(fVal) = '", got, "'");
  dpdCheck(got == "Расход", "описание прочитано", got);

  // -------------------------------------------------------------------
  // 2. Режимы mode
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Режимы mode для элемента С описанием ---");

  dyn_int modes = makeDynInt(-2, -1, 0, 1, 2, 3);
  for (int i = 1; i <= dynlen(modes); i++)
  {
    langString r = dpGetDescription(DP + ".fVal", modes[i]);
    DebugN("  mode=", modes[i], " -> '", r, "'");
  }

  // -------------------------------------------------------------------
  // 3. Режимы для элемента БЕЗ описания - там идёт подстановка имени
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Элемент без описания: подстановка имени ---");

  dyn_int modes2 = makeDynInt(-2, -1, 0, 1, 2, 3);
  for (int i = 1; i <= dynlen(modes2); i++)
  {
    langString r = dpGetDescription(DP + ".iVal", modes2[i]);
    DebugN("  mode=", modes2[i], " -> '", r, "'");
  }

  // mode = -2 ничего не подставляет, поэтому именно он отвечает на вопрос
  // "есть ли описание на самом деле".
  langString noDesc = dpGetDescription(DP + ".iVal", -2);
  DebugN("  mode=-2 для элемента без описания: '", noDesc, "'  <- пусто, описания нет");
  dpdCheck(noDesc == "", "mode=-2 честно показывает отсутствие описания", noDesc);

  langString hasDesc = dpGetDescription(DP + ".fVal", -2);
  DebugN("  mode=-2 для элемента с описанием: '", hasDesc, "'");
  dpdCheck(hasDesc == "Расход", "mode=-2 возвращает описание, если оно есть", hasDesc);

  // -------------------------------------------------------------------
  // 4. Корень точки данных
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Корень точки данных ---");

  // ИЗМЕРЕНО: описание корню точки данных задать НЕЛЬЗЯ.
  // dpSetDescription(имяТочки) возвращает rc = -1, а в журнале приходит
  //   SEVERE, ElementTable, findNameLocation, Problem with Typecontainer.
  // Причина ровно та, о которой говорит документация: описание - свойство
  // ЭЛЕМЕНТА (DPE), а корень структуры таким элементом не является.
  // Документация обходит этот момент молча.
  langString dRoot = "Корень точки";
  int rcRoot = dpSetDescription(DP, dRoot);
  DebugN("  dpSetDescription(\"", DP, "\") rc=", rcRoot, "  lastError=", getLastError());
  dpdCheck(rcRoot == -1, "описание корню задать НЕЛЬЗЯ -> rc = -1", rcRoot);

  dyn_int modes3 = makeDynInt(-2, -1, 0, 1, 2, 3);
  for (int i = 1; i <= dynlen(modes3); i++)
  {
    langString r = dpGetDescription(DP, modes3[i]);
    DebugN("  корень, mode=", modes3[i], " -> '", r, "'  (имя подставляется)");
  }

  langString rootStrict = dpGetDescription(DP, -2);
  dpdCheck(rootStrict == "", "у корня своего описания нет (mode=-2)", rootStrict);

  // -------------------------------------------------------------------
  // 5. Удаление описания
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Удаление описания пустой строкой ---");

  int rcDel = dpSetDescription(DP + ".iVal", "");
  dpdCheck(rcDel == 0, "описание удалено", rcDel);

  langString afterDel = dpGetDescription(DP + ".iVal", -2);
  DebugN("  после удаления, mode=-2: '", afterDel, "'");
  dpdCheck(afterDel == "", "mode=-2: описания действительно нет", afterDel);

  langString afterDel1 = dpGetDescription(DP + ".iVal", 1);
  DebugN("  после удаления, mode=1:  '", afterDel1, "'  <- имя подставлено");
  dpdCheck(afterDel1 != "", "mode=1 всё равно что-то возвращает (подстановка)", afterDel1);

  // -------------------------------------------------------------------
  // 6. Ошибочные случаи
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 6. Ошибочные случаи ---");

  langString bad = dpGetDescription(DP + ".noSuchEl");
  DebugN("  несуществующий элемент: '", bad, "'  lastError=", getLastError());
  dpdCheck(bad == "", "несуществующий элемент -> пусто", bad);

  langString badDp = dpGetDescription("noSuchDpAtAll");
  DebugN("  несуществующая точка:  '", badDp, "'  lastError=", getLastError());
  dpdCheck(badDp == "", "несуществующая точка -> пусто", badDp);

  // С завершающей точкой имя элемента не работает - задокументировано выше.
  langString withDot = dpGetDescription(DP + ".fVal.");
  DebugN("  имя с завершающей точкой: '", withDot, "'");
  dpdCheck(withDot == "", "завершающая точка в имени элемента ломает вызов", withDot);

  dropAll();
  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

void makeType()
{
  dropAll();
  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString(DPT);        t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "fVal");  t[2] = makeDynInt(0, DPEL_FLOAT);
  n[3] = makeDynString("", "iVal");  t[3] = makeDynInt(0, DPEL_INT);
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
}

void makeDp()
{
  dpdCheck(dpCreate(DP, DPT) == 0, "точка данных создана", DP);
  dpSet(DP + ".fVal", 0.0);
  dpSet(DP + ".iVal", 0);
}

void dropAll()
{
  if (dpExists(DP)) { dpDelete(DP); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(DP)) { break; }
    delay(1);
  }
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    dyn_dyn_string pn;
    dyn_dyn_int pt;
    if (dpTypeGet(DPT, pn, pt) != 0) { break; }
    dpTypeDelete(DPT);
    delay(1);
  }
}

void dpdCheck(bool ok, string what, dyn_anytype extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra, "  lastError=", getLastError()); }
}