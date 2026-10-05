// 11_nameCheck.ctl - nameCheck(): проверка и исправление имён.
//
// Документация: docs/01-create.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Функция ничего не создаёт и не удаляет - работает
// только со строками. Предустановленные точки проекта не затрагиваются.
//
// ВАЖНО, ЧТОБЫ НЕ ЗАБЫТЬ. Параметр dpName объявлен как ref (string &dpName),
// поэтому исправленное имя приходит в ПЕРЕМЕННУЮ. Если передать строковый
// литерал, результат проверки получить нельзя.
//
// Три режима nameType:
//     NAMETYPE_DP   (1, по умолчанию) - запрещены . : ; * ? [ ] { } $ @;
//     NAMETYPE_PROJ (2)                - запрещены \ / " ? < > * | : ; '
//     NAMETYPE_PATH (3)                - проверки нет вообще

int dpdPass = 0;
int dpdFail = 0;

main()
{
  DebugN("=== nameCheck(): проверка и исправление имён ===");
  DebugN("  NAMETYPE_DP   = ", NAMETYPE_DP);
  DebugN("  NAMETYPE_PROJ = ", NAMETYPE_PROJ);
  DebugN("  NAMETYPE_PATH = ", NAMETYPE_PATH);

  // -------------------------------------------------------------------
  // 1. Корректное имя
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Корректное имя ---");

  string okName = "dpdemo_GoodName_1";
  int rcOk = nameCheck(okName, NAMETYPE_DP);
  DebugN("  на входе:  '", okName, "'");
  DebugN("  rc=", rcOk, "  на выходе: '", okName, "'");
  dpdCheck(rcOk == 0, "корректное имя -> rc = 0", rcOk);
  dpdCheck(okName == "dpdemo_GoodName_1", "корректное имя не изменяется", okName);

  // -------------------------------------------------------------------
  // 2. Запрещённые символы в имени точки данных
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Запрещённые символы (имя точки данных) ---");

  dyn_string bad = makeDynString("dp.a", "dp:a", "dp;a", "dp*a",
                                 "dp?a", "dp[a", "dp]a", "dp{a",
                                 "dp}a", "dp$a", "dp@a");
  for (int i = 1; i <= dynlen(bad); i++)
  {
    string s = bad[i];
    int rc = nameCheck(s, NAMETYPE_DP);
    DebugN("  '", bad[i], "' -> rc=", rc, "  исправлено: '", s, "'");
    dpdCheck(rc == -1, "символ в '" + bad[i] + "' -> rc = -1", rc);
    dpdCheck(s != bad[i], "имя '" + bad[i] + "' было исправлено", "'" + s + "'");
  }

  // -------------------------------------------------------------------
  // 3. Символы, разрешённые в имени точки
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Разрешённые символы ---");

  string allow = "dp_demo-Name_1";
  int rcAllow = nameCheck(allow, NAMETYPE_DP);
  DebugN("  '", allow, "' -> rc=", rcAllow, "  на выходе: '", allow, "'");
  dpdCheck(rcAllow == 0, "дефис и подчёркивание разрешены", rcAllow);
  dpdCheck(allow == "dp_demo-Name_1", "разрешённое имя не изменяется", allow);

  // -------------------------------------------------------------------
  // 4. Режим имени проекта - другой набор запрещённых символов
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. NAMETYPE_PROJ: другой набор запрещённых символов ---");

  // Точка разрешена в имени проекта, но запрещена в имени точки.
  string projDp = "dp.demo";
  int rcProjDp = nameCheck(projDp, NAMETYPE_PROJ);
  DebugN("  'dp.demo' как имя ПРОЕКТА -> rc=", rcProjDp, "  на выходе: '", projDp, "'");
  dpdCheck(rcProjDp == 0, "точка разрешена в имени проекта", rcProjDp);

  string projBad = "dp?demo";
  int rcProjBad = nameCheck(projBad, NAMETYPE_PROJ);
  DebugN("  'dp?demo' как имя ПРОЕКТА -> rc=", rcProjBad, "  исправлено: '", projBad, "'");
  dpdCheck(rcProjBad == -1, "вопросительный знак запрещён в имени проекта", rcProjBad);

  // Обратная сторона: тот же вопросительный знак в имени точки.
  string dpBad2 = "dp?demo";
  int rcDpBad2 = nameCheck(dpBad2, NAMETYPE_DP);
  DebugN("  'dp?demo' как имя ТОЧКИ   -> rc=", rcDpBad2, "  исправлено: '", dpBad2, "'");
  dpdCheck(rcDpBad2 == -1, "и в имени точки он тоже запрещён", rcDpBad2);

  // -------------------------------------------------------------------
  // 5. Режим пути - проверки нет
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. NAMETYPE_PATH: расхождение с документацией ---");
  DebugN("  Документация говорит \"проверки нет\". Измерено: проверки");
  DebugN("  действительно нет (rc = 0), НО имя через ref-параметр");
  DebugN("  возвращается ПУСТЫМ. То есть проверки нет, но и результата нет.");

  string path = "some/path*with?bad:chars";
  DebugN("  на входе:  '", path, "'");
  int rcPath = nameCheck(path, NAMETYPE_PATH);
  DebugN("  rc=", rcPath, "  на выходе: '", path, "'");
  dpdCheck(rcPath == 0, "в режиме пути проверки нет, rc = 0", rcPath);
  dpdCheck(path == "", "имя в режиме пути возвращается ПУСТЫМ", "'" + path + "'");

  // -------------------------------------------------------------------
  // 6. Пустая строка
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 6. Пустая строка ---");

  string emptyName = "";
  int rcEmpty = nameCheck(emptyName, NAMETYPE_DP);
  DebugN("  '' -> rc=", rcEmpty, "  на выходе: '", emptyName, "'");
  dpdCheck(rcEmpty == -1, "пустое имя ОТВЕРГАЕТСЯ -> rc = -1", rcEmpty);
  dpdCheck(emptyName == "", "пустая строка остаётся пустой", emptyName);

  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

void dpdCheck(bool ok, string what, dyn_anytype extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra, "  lastError=", getLastError()); }
}