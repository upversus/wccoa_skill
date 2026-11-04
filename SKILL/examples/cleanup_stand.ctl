// cleanup_stand.ctl - уборка объектов, оставленных прикладными примерами.
//
// ПРОТОКОЛ УБОРКИ. Удаляется ТОЛЬКО явный белый список типов, созданных
// примерами из этого репозитория. Системные объекты (имя начинается с "_")
// и объекты проекта не трогаются вовсе - здесь их нет даже в списке.
//
// Порядок обязателен: сначала точки данных, потом типы. dpTypeDelete() не
// проходит, пока у типа остались точки.
//
// Что было удалено и почему - см. RESUME.md, раздел "Уборка стенда".
//
// ГРУППЫ. Функции groupCreate() и groupDelete() живут в библиотеке
// dpGroups.ctl, а не в базовой библиотеке DLL. Поэтому в начале файла стоит
// #uses, без него вызовы не компилируются.

#uses "dpGroups.ctl"

// Типы, созданные примерами. Пустой тип тоже попадает в список.
dyn_string MY_TYPES = makeDynString(
    "mapFlowT",       // 11-address, карта Modbus
    "mapLevelT",
    "mapPressT",
    "mapPumpT",
    "mapTempT",
    "mapValveT",
    "mapWriteT",
    "mbtest",         // ранняя проба Modbus, точка mb_test_1
    "metaDemo_t",     // 02-config, метаданные
    "opcB2_t",        // 11-address, Browse Path
    "opcBrowse_t",
    "opcChk_t",
    "opcFields_t",    // 11-address, поля Kind и Variant
    "pit_parse",      // точка word_to_bit
    "period_probe_t", // 03-read, своя точка без архива в dpGetPeriod
    "probe_coil_t",   // подбор направления для coil
    "sub_t",          // 05-subscribe, подписка dpConnect
    "double",         // точка doubl2, проверка "типа double нет"
    "valve",          // 00-scenario, проба формы типа
    "fValue");        // 00-scenario, проба формы типа

int dpdPass = 0;
int dpdFail = 0;

main()
{
  DebugN("=== Уборка стенда ===");
  DebugN("");
  DebugN("Типов в белом списке: ", dynlen(MY_TYPES));

  // Сколько объектов было до уборки - нужно для отчёта "до/после".
  int typesBefore = 0;
  int dpsBefore   = 0;
  for (int i = 1; i <= dynlen(MY_TYPES); i++)
  {
    dyn_string members = dpNames("*", MY_TYPES[i]);
    if (dynlen(members) > 0) { typesBefore++; }
    dpsBefore += dynlen(members);
  }
  DebugN("Из них существовало: типов ", typesBefore, ", точек данных ", dpsBefore);

  // ---------------------------------------------------------------------
  // 1. Точки данных
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("(1) удаляю точки данных");

  for (int i = 1; i <= dynlen(MY_TYPES); i++)
  {
    string t = MY_TYPES[i];
    dyn_string members = dpNames("*", t);
    for (int j = 1; j <= dynlen(members); j++)
    {
      // Имя из dpNames() приходит с префиксом системы, dpExists() его понимает.
      if (dpExists(members[j]))
      {
        int rc = dpDelete(members[j]);
        DebugN("    dpDelete(", members[j], ") rc=", rc);
      }
    }
  }

  // Ждём, пока все удалится: dpDelete асинхронен.
  for (int attempt = 1; attempt <= 40; attempt++)
  {
    int left = 0;
    for (int i = 1; i <= dynlen(MY_TYPES); i++)
    {
      left += dynlen(dpNames("*", MY_TYPES[i]));
    }
    if (left == 0) { break; }
    delay(1);
  }

  for (int i = 1; i <= dynlen(MY_TYPES); i++)
  {
    dyn_string members = dpNames("*", MY_TYPES[i]);
    dpdCheck("точек у типа " + MY_TYPES[i] + " не осталось", dynlen(members) == 0);
  }

  // ---------------------------------------------------------------------
  // 2. Типы
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("(2) удаляю типы");

  for (int i = 1; i <= dynlen(MY_TYPES); i++)
  {
    string t = MY_TYPES[i];
    dyn_dyn_string pn;
    dyn_dyn_int pt;
    if (dpTypeGet(t, pn, pt) != 0) { continue; }   // типа уже нет

    int rc = dpTypeDelete(t);
    DebugN("    dpTypeDelete(", t, ") rc=", rc);
    delay(1);
  }

  // dpTypeDelete тоже асинхронен - повторяем, пока тип виден.
  for (int attempt = 1; attempt <= 40; attempt++)
  {
    int left = 0;
    for (int i = 1; i <= dynlen(MY_TYPES); i++)
    {
      dyn_dyn_string pn;
      dyn_dyn_int pt;
      if (dpTypeGet(MY_TYPES[i], pn, pt) == 0) { left++; }
    }
    if (left == 0) { break; }
    delay(1);
  }

  for (int i = 1; i <= dynlen(MY_TYPES); i++)
  {
    dyn_dyn_string pn;
    dyn_dyn_int pt;
    dpdCheck("тип " + MY_TYPES[i] + " удалён", dpTypeGet(MY_TYPES[i], pn, pt) != 0);
  }

  // ---------------------------------------------------------------------
  // 3. Группы точек данных
  // ---------------------------------------------------------------------
  // Группы лежат в точках данных типа _DpGroup. Штатно они удаляются
  // функцией groupDelete() из библиотеки dpGroups.ctl - именно поэтому
  // группу нельзя снести обычным dpDelete(): удалится точка, а связь
  // с именем группы в UI останется.
  //
  // Берём только группы с нашим префиксом dpdemo_, чтобы не задеть
  // чужие и предустановленные.
  DebugN("");
  DebugN("(3) удаляю группы точек данных");

  dyn_string allGroups = dpNames("*", "_DpGroup");
  DebugN("  всего точек типа _DpGroup в проекте: ", dynlen(allGroups),
         " (большая часть - системные, их не трогаем)");

  int removed = 0;
  int mine    = 0;
  for (int i = 1; i <= dynlen(allGroups); i++)
  {
    string gdp = allGroups[i];
    // Имя группы лежит в описании точки данных.
    string gname = groupDpNameToName(gdp);
    if (!strMatch(gname, "dpdemo_*")) { continue; }   // не наша - не трогаем
    mine++;
    int ge = 0;
    groupDelete(gname, ge);
    DebugN("    groupDelete(\"", gname, "\") iError=", ge);
    if (ge == 0) { removed++; }
  }
  DebugN("  наших групп найдено: ", mine, "   удалено: ", removed);

  // Проверяем только свои группы. Запрос вида dpNames("*:dpdemo_*", "_DpGroup")
  // непригоден: шаблоны по конфигам в dpNames работают лишь глобально, без
  // имени точки (проверено в 01-create/10_dpNames.ctl), поэтому фильтруем
  // перебором.
  int left = 0;
  dyn_string after = dpNames("*", "_DpGroup");
  for (int i = 1; i <= dynlen(after); i++)
  {
    if (strMatch(groupDpNameToName(after[i]), "dpdemo_*")) { left++; }
  }
  dpdCheck("наших групп не осталось", left == 0);

  // ---------------------------------------------------------------------
  // 4. Контроль: осталось ли что-то с тем же почерком
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("(4) контроль");
  DebugN("  Всего типов в проекте теперь: ", dynlen(dpTypes("*")));

  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

bool strMatch(string s, string pattern)
{
  // Простой матч "префикс*". Функций patMatch()/length() в CTL 3.18 нет,
  // поэтому сравнение делаем вручную. Длину строки берём через dynlen()
  // от makeDynString - на голой string dynlen() ругается "not an array".
  int star = strpos(pattern, "*");
  if (star == -1) { return s == pattern; }
  string prefix = substr(pattern, 0, star);
  int pl = dynlen(makeDynString(prefix));
  if (pl > dynlen(makeDynString(s))) { return FALSE; }
  return substr(s, 0, pl) == prefix;
}

void dpdCheck(string what, bool ok)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what); }
  else    { dpdFail++; DebugN("  FAIL  ", what); }
}