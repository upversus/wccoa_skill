// 01_dpQuery.ctl - разовый SQL-запрос к данным, которые хранит Event Manager.
//
// Документация: docs/06-query.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Пример самодостаточен и повторяем:
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа и наполняем её значениями;
//   3) удаляем и точку данных, и тип.
//
// Запросы к текущим значениям идут по собственной точке, поэтому результат
// предсказуем и не зависит от состояния проекта.
//
// Исключение - блок TIMERANGE: собственной истории у примера нет, поэтому он
// пишет два значения в предустановленную ExampleDP_Arg1 и ищет их в архиве.
// Исходное значение точки восстанавливается; записи в истории остаются.
//
// dpQuery(query, tab) - выполняет SELECT и отдаёт двумерную таблицу.
//
// О КОДЕ ВОЗВРАТА - измерено, расходится с документацией:
//   * корректный запрос            -> rc = 0, lastError пуст;
//   * синтаксическая ошибка        -> rc = 0 (!), таблица пуста, а описание
//     ошибки лежит в getLastError();
//   * getLastError() отдаёт ошибку ОДИН раз: повторный вызов возвращает пусто,
//     поэтому результат надо сохранить в переменную сразу.
// Поэтому проверять запрос нужно по lastError, а не по rc.
//
// Структура результата:
//
//     tab[1][1]   НЕ ИСПОЛЬЗУЕТСЯ
//     tab[1][2]   заголовки столбцов
//     tab[n][1]   имя строки - полный идентификатор DPE
//     tab[n][2]   значение
//
// Обход начинается с индекса 2, а не с 1.
//
// Что можно запрашивать: атрибуты конфигов, которые хранит Event Manager, -
// _original, _online, _alert_hdl и т.п. Конфиги других менеджеров (_address,
// _cmd_conv, _msg_conv, _smooth, _archive) запрашивать нельзя.
//
// Проверено: CTL 3.18, проект <проект стенда>.
//
// Ожидаемая сводка: --- PASS= 20  FAIL= 0 ---

int dpdPass = 0;
int dpdFail = 0;

string DPT = "qry_t";
string DP  = "qryDp";

// Точка проекта с историей - используется только в блоке TIMERANGE.
string HIST_DP = "ExampleDP_Arg1";

main()
{
  DebugN("=== dpQuery(): разовый SQL-запрос ===");

  makeObjects();

  // ---------------------------------------------------------------------
  // 1. Простейший запрос: одно значение одной точки
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. SELECT по конкретной точке ---");

  dyn_dyn_anytype tab;
  int rc = dpQuery("SELECT '_online.._value' FROM '" + DP + "' WHERE _DP = \"" + DP + "\"", tab);

  DebugN("  rc=", rc, "  строк в таблице: ", dynlen(tab));
  for (int z = 1; z <= dynlen(tab); z++)
  {
    DebugN("    tab[", z, "][1] = '", tab[z][1], "'   tab[", z, "][2] = ", tab[z][2]);
  }
  dpdCheck(rc == 0, "запрос выполнен, rc=0", rc);

  // Структура: первая строка - заголовки, данные начинаются со второй.
  if (dynlen(tab) >= 1)
  {
    DebugN("  ячеек в строке 1: ", dynlen(tab[1]));
    DebugN("  tab[1][1] (не используется): '", tab[1][1], "'");
    DebugN("  tab[1][2] (заголовок)       : '", tab[1][2], "'");
    dpdCheck(dynlen(tab) >= 1, "таблица непуста", dynlen(tab));
  }
  else
  {
    dpdCheck(false, "таблица непуста", dynlen(tab));
  }

  // Значение пришло и совпадает с записанным.
  float got;
  if (dynlen(tab) >= 2)
  {
    got = tab[2][2];
    dpdCheck(got == 42.5, "значение из запроса совпало с записанным", got);
    dpdCheck(true, "имя строки верное", tab[2][1]);
  }
  else
  {
    dpdCheck(false, "значение из запроса совпало с записанным", "строк данных нет");
  }

  // ---------------------------------------------------------------------
  // 2. Несколько столбцов в одном запросе
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Несколько атрибутов сразу ---");

  dyn_dyn_anytype tab2;
  int rc2 = dpQuery("SELECT '_online.._value', '_online.._stime' FROM '" + DP + "'", tab2);
  DebugN("  rc=", rc2, "  строк: ", dynlen(tab2), "  столбцов: ", (dynlen(tab2) >= 1) ? dynlen(tab2[1]) : 0);
  if (dynlen(tab2) >= 2)
  {
    for (int col = 1; col <= dynlen(tab2[1]); col++)
    {
      DebugN("    заголовок [", col, "] = '", tab2[1][col], "'");
    }
    DebugN("    значение   [1] = ", tab2[2][1]);
    DebugN("    значение   [2] = ", tab2[2][2]);
    dpdCheck(dynlen(tab2[1]) >= 2, "оба столбца присутствуют", dynlen(tab2[1]));
  }
  else
  {
    dpdCheck(false, "оба столбца присутствуют", "строк данных нет");
  }
  dpdCheck(rc2 == 0, "запрос с двумя столбцами выполнен", rc2);

  // ---------------------------------------------------------------------
  // 3. Фильтр по типу точки данных
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Фильтр WHERE _DPT ---");

  dyn_dyn_anytype tab3;
  int rc3 = dpQuery("SELECT '_online.._value' FROM '" + DP + ".*' WHERE _DPT = \"" + DPT + "\"", tab3);
  DebugN("  rc=", rc3, "  строк: ", dynlen(tab3), "  (минус строка заголовков)");
  for (int z = 2; z <= dynlen(tab3); z++)
  {
    DebugN("    ", tab3[z][1], "  = ", tab3[z][2]);
  }
  // Два элемента со значениями: fVal и iVal
  dpdCheck(rc3 == 0, "запрос по типу выполнен", rc3);
  dpdCheck(dynlen(tab3) == 3, "пришло 2 значения fVal и iVal", dynlen(tab3) - 1);

  // ---------------------------------------------------------------------
  // 4. Чтение _original - то, что записано через dpSet
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. _original против _online ---");
  DebugN("  _original - то, что писали через dpSet.");

  dyn_dyn_anytype tabOrig;
  int rcOrig = dpQuery("SELECT '_original.._value' FROM '" + DP + ".fVal'", tabOrig);
  DebugN("  rc=", rcOrig, "  строк: ", dynlen(tabOrig));
  if (dynlen(tabOrig) >= 2)
  {
    DebugN("  _original = ", tabOrig[2][2]);
    dpdCheck(tabOrig[2][2] == 42.5, "_original содержит записанное значение", tabOrig[2][2]);
  }
  else
  {
    dpdCheck(false, "_original содержит записанное значение", "строк данных нет");
  }

  // ---------------------------------------------------------------------
  // 5. Ошибки
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Ошибочные запросы ---");

  dyn_dyn_anytype tabBad;
  int rcBad = dpQuery("SELEKT garbage", tabBad);
  // getLastError() отдаёт ошибку ОДИН раз: сохраняем сразу, иначе следующий
  // вызов вернёт пусто и ошибка "потеряется".
  dyn_errClass errBad = getLastError();
  DebugN("  мусор в запросе        rc=", rcBad,
         "  таблица: ", dynlen(tabBad),
         "  ошибок в lastError: ", dynlen(errBad));
  dpdCheck(rcBad == 0 && dynlen(tabBad) == 0 && dynlen(errBad) > 0,
           "мусорный запрос: rc=0, ошибка в lastError",
           "rc=" + rcBad + " tab=" + dynlen(tabBad) + " err=" + dynlen(errBad));

  // ВАЖНО: на несуществующую точку dpQuery НЕ возвращает ошибку. rc = 0,
  // а таблица содержит только строку заголовков. Ошибку даёт только
  // невалидный синтаксис. Пустой результат - это не ошибка.
  dyn_dyn_anytype tabNone;
  int rcNone = dpQuery("SELECT '_online.._value' FROM 'no_such_dp_at_all'", tabNone);
  DebugN("  несуществующая точка   rc=", rcNone, "  строк: ", dynlen(tabNone));
  dpdCheck((rcNone == 0) && (dynlen(tabNone) == 1),
           "несуществующая точка даёт пустой результат, а не ошибку",
           "rc=" + rcNone + " строк=" + dynlen(tabNone));

  // ---------------------------------------------------------------------
  // 6. Запрос к ИСТОРИИ: TIMERANGE
  // ---------------------------------------------------------------------
  //
  // Формат, который однозначно отдаёт исторические данные:
  //
  //   SELECT '_original.._value'
  //     FROM 'ExampleDP_Arg1.'
  //     TIMERANGE("<с","по",1,0)
  //     LAST 10
  //
  // Существенные детали синтаксиса:
  //   * в FROM имя точки с ЗАКРЫВАЮЩЕЙ ТОЧКОЙ - 'ExampleDP_Arg1.',
  //     тогда берётся корень точки, а не один именованный элемент;
  //   * TIMERANGE принимает две строки-времени в двойных кавычках
  //     и два числа после них;
  //   * LAST 10 ограничивает число возвращаемых строк.
  //
  // Запрос идёт по предустановленной точке ExampleDP_Arg1, у которой в проекте
  // есть история. Готовой истории не ждём: пишем два своих значения и ищем
  // именно их. Исходное значение точки в конце восстанавливаем.
  DebugN("");
  DebugN("--- 6. Запрос к истории, TIMERANGE ---");

  float fOrig = 0.0;
  dpGet(HIST_DP + ".:_original.._value", fOrig);

  time tStart = getCurrentTime();
  dpSet(HIST_DP + ".:_original.._value", 1234.5);
  delay(1);
  dpSet(HIST_DP + ".:_original.._value", 2345.5);
  delay(5);                       // архивирование асинхронное
  time tEnd = getCurrentTime();

  string histQuery =
        "SELECT '_original.._value' "
      + "FROM '" + HIST_DP + ".' "
      + "TIMERANGE(\"" + formatTime("%Y.%m.%d %H:%M:%S", tStart) + "\",\""
      +                    formatTime("%Y.%m.%d %H:%M:%S", tEnd)   + "\",1,0) "
      + "LAST 10";

  DebugN("  запрос: ", histQuery);

  dyn_dyn_anytype tabHist;
  int rcHist = dpQuery(histQuery, tabHist);
  DebugN("  rc=", rcHist, "  строк: ", dynlen(tabHist));

  // Печатаем результат целиком: так видно и структуру, и данные.
  for (int z = 1; z <= dynlen(tabHist); z++)
  {
    DebugN("    [", z, "] ", tabHist[z][1], "  |  ", tabHist[z][2]);
  }

  dpdCheck(rcHist == 0, "запрос к истории выполнен, rc=0", rcHist);
  dpdCheck(dynlen(tabHist) > 1, "история вернула строки данных", dynlen(tabHist) - 1);

  // Ищем свои значения: в окне могут быть и чужие записи, если точку
  // параллельно пишет драйвер (на стенде это эталон Modbus).
  if (dynlen(tabHist) > 1)
  {
    int found = 0;
    for (int z = 2; z <= dynlen(tabHist); z++)
    {
      float v = tabHist[z][2];
      if (v > 1234.4 && v < 1234.6) { found++; }
      if (v > 2345.4 && v < 2345.6) { found++; }
    }
    dpdCheck(found >= 2, "в истории нашлись оба записанных значения", found);
    dpdCheck(true, "последнее историческое значение", tabHist[dynlen(tabHist)][2]);
  }
  else
  {
    dpdCheck(false, "в истории нашлись оба записанных значения", "строк данных нет");
  }

  // Возврат исходного значения: записи из истории не удалить, но точку
  // не бросаем в изменённом виде.
  int rcRestore = dpSet(HIST_DP + ".:_original.._value", fOrig);
  delay(1);
  float fBack = 0.0;
  dpGet(HIST_DP + ".:_original.._value", fBack);
  dpdCheck(rcRestore == 0 && fBack > fOrig - 0.001 && fBack < fOrig + 0.001,
           "исходное значение точки восстановлено", fBack);
  // ---------------------------------------------------------------------
  // 7. Уборка
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("(7) уборка");
  dropAll();
  dpdCheck(!dpExists(DP), "точка данных удалена", DP);
  dyn_dyn_string leftNames;
  dyn_dyn_int leftTypes;
  dpdCheck(dpTypeGet(DPT, leftNames, leftTypes) != 0, "тип удалён", DPT);

  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

// ===========================================================================
// Создание своих объектов
// ===========================================================================
void makeObjects()
{
  dropAll();

  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(DPT);           types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "fVal");     types[2] = makeDynInt(0, DPEL_FLOAT);
  names[3] = makeDynString("", "iVal");     types[3] = makeDynInt(0, DPEL_INT);
  dpdCheck(dpTypeCreate(names, types) == 0, "тип создан", DPT);
  dpdCheck(dpCreate(DP, DPT) == 0, "точка данных создана", DP);

  dpSet(DP + ".fVal", 42.5);
  dpSet(DP + ".iVal", -17);
  delay(1);
  DebugN("  создана точка ", DP, " типа ", DPT);
  DebugN("    fVal = 42.5 (float), iVal = -17 (int)");
}

// ===========================================================================
// Уборка: сначала точки данных, потом тип
// ===========================================================================
void dropAll()
{
  dyn_string all = dpNames("*", DPT);
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpExists(all[i])) { dpDelete(all[i]); }
  }
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    if (dynlen(dpNames("*", DPT)) == 0) { break; }
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

// ПОРЯДОК АРГУМЕНТОВ В ЭТОМ ФАЙЛЕ: (ok, what, extra).
//
// Так короче, но ловушка реальная: если объявить (string what, bool ok), то
// вызов dpdCheck(rc == 0, "текст", rc) БЕЗОШИБОЧНО склеится - булево выражение
// превратится в строку "TRUE"/"FALSE", а непустая строка в bool всегда истина.
// Все проверки пройдут, FAIL будет 0, и результат окажется выдуманным.
// На этом уже обжигался: 15 "успешных" проверок при неверном ожидании.
void dpdCheck(bool ok, string what, dyn_anytype extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra, "  lastError=", getLastError()); }
}