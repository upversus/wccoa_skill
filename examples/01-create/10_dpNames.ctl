// 10_dpNames.ctl - dpNames(): поиск точек данных и элементов по шаблону.
//
// Документация: docs/01-create.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт создаёт свой тип с несколькими элементами и две
// свои точки данных, проверяет формы шаблонов и в конце всё удаляет.
// Проверки не зависят от предустановленных точек проекта: везде, где нужен
// точный состав, используются собственные объекты.
//
// ВАЖНО. Уровни задаются ЯВНО: dpNames("*") и dpNames("*.*") - это разные
// запросы с разными результатами. Фильтр по типу требует ТОЧНОГО имени типа,
// подстановки не работают.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "dpdemo_nm_t";
string DP1 = "dpdemo_nm_a";
string DP2 = "dpdemo_nm_b";

main()
{
  DebugN("=== dpNames(): поиск по шаблону ===");

  makeType();
  makeDp();

  // -------------------------------------------------------------------
  // 1. Поиск по имени типа
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Фильтр по типу (ТОЧНОЕ имя) ---");

  dyn_string byType = dpNames("*", DPT);
  DebugN("  dpNames(\"*\", \"" + DPT + "\") -> ", dynlen(byType), " шт.");
  for (int i = 1; i <= dynlen(byType); i++) { DebugN("    ", byType[i]); }
  dpdCheck(dynlen(byType) == 2, "наши точки данных найдены по типу", dynlen(byType));
  // ИЗМЕРЕНО: dpNames() возвращает имена С ПРЕФИКСОМ СИСТЕМЫ.
  // Искать надо "System1:" + имя, а не голое имя.
  dpdCheck(inList(byType, "System1:" + DP1) && inList(byType, "System1:" + DP2),
           "обе точки в списке, имена с префиксом System1:", "проверено");

  // Подстановка в имени типа не работает - это важно.
  dyn_string wildcard = dpNames("*", "dpdemo_nm_*");
  DebugN("  dpNames(\"*\", \"dpdemo_nm_*\") -> ", dynlen(wildcard),
         " шт. <- подстановка в имени типа НЕ работает");
  dpdCheck(dynlen(wildcard) == 0,
           "имя типа требует ТОЧНОГО совпадения, \"dpdemo_nm_*\" даёт пусто",
           dynlen(wildcard));

  // -------------------------------------------------------------------
  // 2. Поиск по имени точки данных
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Поиск по имени точки ---");

  dyn_string byName = dpNames(DP1 + "*");
  DebugN("  dpNames(\"" + DP1 + "*\") -> ", dynlen(byName), " шт.");
  for (int i = 1; i <= dynlen(byName); i++) { DebugN("    ", byName[i]); }
  dpdCheck(dynlen(byName) == 1, "по префиксу точка найдена", dynlen(byName));
  dpdCheck(byName[1] == "System1:" + DP1,
           "в результате есть префикс системы", byName[1]);

  dyn_string exact = dpNames(DP1);
  dpdCheck(dynlen(exact) >= 1, "точное имя точки найдено", dynlen(exact));

  // -------------------------------------------------------------------
  // 3. Элементы: уровни задаются явно
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Элементы: \"*.\" против \"**\" ---");

  dyn_string oneLevel = dpNames(DP1 + ".*");
  dyn_string deep = dpNames(DP1 + ".**");
  DebugN("  dpNames(\"" + DP1 + ".*\")  -> ", dynlen(oneLevel), " шт.");
  for (int i = 1; i <= dynlen(oneLevel); i++) { DebugN("    ", oneLevel[i]); }
  DebugN("  dpNames(\"" + DP1 + ".**\") -> ", dynlen(deep), " шт.");

  dpdCheck(dynlen(oneLevel) == 4, "у точки четыре элемента первого уровня", dynlen(oneLevel));
  dpdCheck(dynlen(deep) >= dynlen(oneLevel),
           "\".**\" даёт не меньше, чем \".*\"", dynlen(deep));
  dpdCheck(inList(oneLevel, "System1:" + DP1 + ".fVal"),
           "имена элементов приходят с префиксом системы", "с системой");
  dpdCheck(!inList(oneLevel, DP1 + ".fVal"),
           "без префикса системы элемент не находится", "без системы не найден");

  // -------------------------------------------------------------------
  // 4. Поиск по конфигам
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Поиск по конфигам через \":\" ---");

  // ИЗМЕРЕНО: запрос по конфигам в dpNames() ТОЛЬКО ГЛОБАЛЬНЫЙ. Имя точки
  // данных в шаблон подставлять нельзя - получается ноль без всякой ошибки:
  //     dpNames("DP.:_original.*")   -> 0
  //     dpNames("System1:DP.:_original.*") -> 0
  // Рабочая форма - без имени точки, как в примерах документации:
  dyn_string details = dpNames(":_original.*");
  DebugN("  dpNames(\":_original.*\")  -> ", dynlen(details), " шт. <- detail-ы, по проекту");
  dpdCheck(dynlen(details) == 1, "detail-ы конфига _original: один", dynlen(details));

  dyn_string attrs = dpNames(":_original..*");
  DebugN("  dpNames(\":_original..*\") -> ", dynlen(attrs), " шт. <- атрибуты, по проекту");
  dpdCheck(dynlen(attrs) == 77,
           "набор атрибутов _original по проекту - 77", dynlen(attrs));

  // Тот же набор атрибутов, что отдаёт dpGetAllAttributes, но в РАЗНОМ виде.
  // ИЗМЕРЕНО:
  //     dpNames(":_original..*")        -> "System1::_original.._active"
  //     dpGetAllAttributes("_original") -> "_active"
  // Количество совпадает (77 = 77), но сравнивать строки напрямую бессмысленно.
  //
  // Части идентификатора разбираются функцией dpSubStr() - это правильный
  // инструмент для работы с путями точки данных, и он уже проверен
  // в 03-read/08_dpSubStr.ctl. Строковые функции CTL 3.18 тут ни при чём.
  DebugN("  пример из dpNames:             ", attrs[1]);
  dyn_string viaFunc = dpGetAllAttributes("_original");
  DebugN("  пример из dpGetAllAttributes: ", viaFunc[1]);
  DebugN("  dpSubStr(..., DPSUB_SYS)         = '", dpSubStr(attrs[1], DPSUB_SYS), "'");
  DebugN("  dpSubStr(..., DPSUB_CONF_DET_ATT) = '",
         dpSubStr(attrs[1], DPSUB_CONF_DET_ATT), "'");
  DebugN("");

  // dpNames отдаёт путь целиком, dpGetAllAttributes - голое имя атрибута.
  // Поэтому собираем полную форму от bare-имени и ищем её среди
  // результатов dpNames. Ни одной строковой операции не требуется.
  string pre = "System1::_original..";
  bool sameSet = (dynlen(viaFunc) == dynlen(attrs));
  int notFound = 0;
  if (sameSet)
  {
    for (int i = 1; i <= dynlen(viaFunc); i++)
    {
      string want = pre + viaFunc[i];
      if (!inList(attrs, want)) { sameSet = FALSE; notFound++; }
    }
  }
  dpdCheck(sameSet,
           "составы совпадают: каждый атрибут dpGetAllAttributes есть в dpNames",
           "несовпавших: " + notFound);

  // И структура пути подтверждена разбором через dpSubStr.
  dpdCheck(dpSubStr(attrs[1], DPSUB_SYS) == "System1:",
           "dpSubStr выделяет систему из пути", dpSubStr(attrs[1], DPSUB_SYS));
  dpdCheck(dpSubStr(attrs[1], DPSUB_CONF_DET_ATT) == ":_original.._active",
           "dpSubStr выделяет конфиг, detail и атрибут",
           dpSubStr(attrs[1], DPSUB_CONF_DET_ATT));

  // -------------------------------------------------------------------
  // 5. Поиск по алиасу
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Поиск по алиасу ---");

  langString al = "dpdemo_alias_f";
  dpSetAlias(DP1 + ".fVal", al);
  dyn_string byAlias = dpNames("@" + al);
  DebugN("  dpNames(\"@" + al + "\") -> ", dynlen(byAlias), " шт.");
  for (int i = 1; i <= dynlen(byAlias); i++) { DebugN("    ", byAlias[i]); }
  dpdCheck(dynlen(byAlias) == 1, "поиск по алиасу нашёл ровно одну точку", dynlen(byAlias));
  dpdCheck(inList(byAlias, "System1:" + DP1 + ".fVal"),
           "найдено полное имя с префиксом системы", "проверено");

  // -------------------------------------------------------------------
  // 6. Регистр
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 6. Регистр ---");

  dyn_string upper = dpNames(DP1);
  dyn_string upperIgnore = dpNames(DP1, "", TRUE);
  DebugN("  dpNames(\"" + DP1 + "\")         -> ", dynlen(upper), " шт.");
  DebugN("  dpNames(\"" + DP1 + "\", \"\", TRUE) -> ", dynlen(upperIgnore), " шт.");
  dpdCheck(dynlen(upper) == 1, "точное имя даёт одну точку", dynlen(upper));
  dpdCheck(dynlen(upperIgnore) >= dynlen(upper),
           "с игнорированием регистра результат не меньше", dynlen(upperIgnore));

  // -------------------------------------------------------------------
  // 7. Ошибочные случаи
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 7. Ничего не найдено ---");

  dyn_string nothing = dpNames("noSuchDpPattern*");
  DebugN("  dpNames(\"noSuchDpPattern*\") -> ", dynlen(nothing), " шт. lastError=", getLastError());
  dpdCheck(dynlen(nothing) == 0, "несуществующий шаблон -> пустой массив", dynlen(nothing));
  dpdCheck(dynlen(getLastError()) == 0,
           "ошибка НЕ сообщается - признак только пустой массив", "пусто");

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
  n[4] = makeDynString("", "bVal");  t[4] = makeDynInt(0, DPEL_BOOL);
  n[5] = makeDynString("", "sVal");  t[5] = makeDynInt(0, DPEL_STRING);
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
}

void makeDp()
{
  dpdCheck(dpCreate(DP1, DPT) == 0, "точка 1 создана", DP1);
  dpdCheck(dpCreate(DP2, DPT) == 0, "точка 2 создана", DP2);
  dpSet(DP1 + ".fVal", 1.0);
  dpSet(DP1 + ".iVal", 2);
  dpSet(DP1 + ".bVal", TRUE);
  dpSet(DP1 + ".sVal", "текст");
}

void dropAll()
{
  // Имена своих точек известны точно, поэтому перечисляем их явно.
  // (patMatch() в CTL 3.18 нет - такая попытка компиляции падает.)
  if (dpExists(DP1)) { dpDelete(DP1); }
  if (dpExists(DP2)) { dpDelete(DP2); }
  for (int a = 1; a <= 30; a++)
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
void dpdCheck(bool ok, string what, dyn_anytype extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra, "  lastError=", getLastError()); }
}

bool inList(dyn_string lst, string what)
{
  for (int i = 1; i <= dynlen(lst); i++)
  {
    if (lst[i] == what) { return TRUE; }
  }
  return FALSE;
}