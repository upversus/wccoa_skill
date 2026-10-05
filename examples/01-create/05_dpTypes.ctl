// 05_dpTypes.ctl — демонстрация dpTypes()
//
// Документация: docs/01-create.md#dptypes
//
// Что показывает пример:
//   * dpTypes() без параметров — все типы проекта;
//   * ВАЖНО: параметр system нельзя ставить равным 0 — тогда возвращается
//     ПУСТОЙ результат (проверено на CTL 3.18, в проекте 262 типа).
//     Документация об этом молчит;
//   * includeEmpty = false требует настоящего номера системы;
//   * СИСТЕМНЫЕ типы (имя с префиксом "_") присутствуют в выдаче, и их нельзя
//     изменять или удалять — любой перебор обязан их отфильтровать.
//
// Проверено: CTL 3.18, проект prg_12_3, 2026-10-04.
//
// Запуск: разовый, неблокирующий.

main()
{
  dpdHeader("dpTypes", "dyn_string dpTypes(string pattern = \"*\", unsigned system, bool includeEmpty = true)");

  // --- 1. все типы --------------------------------------------------------
  dyn_string all = dpTypes();
  DebugN("  dpTypes() вернул ", dynlen(all), " типов");
  dpdCheck("выдача непустая", dynlen(all) > 0);

  // --- 2. подстановка по имени типа ---------------------------------------
  string firstUser = "";
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (!dpdIsSystem(all[i])) { firstUser = all[i]; break; }
  }

  if (firstUser != "")
  {
    DebugN("  первый пользовательский тип: ", firstUser);

    dyn_string exact = dpTypes(firstUser);
    DebugN("  dpTypes(\"", firstUser, "\") вернул ", dynlen(exact), " записей");
    dpdCheck("точное имя типа вернуло ровно этот тип",
             dynlen(exact) == 1 && exact[1] == firstUser);

    string prefix = substr(firstUser, 0, 1);
    dyn_string byPrefix = dpTypes(prefix + "*");
    DebugN("  dpTypes(\"", prefix, "*\") вернул ", dynlen(byPrefix), " типов");
    dpdCheck("подстановка по имени типа работает", dynlen(byPrefix) > 0);

    bool selfFound = false;
    for (int i = 1; i <= dynlen(byPrefix); i++)
    {
      if (byPrefix[i] == firstUser) { selfFound = true; }
    }
    dpdCheck("подстановка включает сам тип", selfFound);
  }
  else
  {
    DebugN("  SKIP  в проекте нет ни одного пользовательского типа точки данных");
  }

  // --- 3. подстановка, ничего не совпадающая ------------------------------
  // Префикс dpdemo_ не пересекается с системными именами.
  dyn_string none = dpTypes("dpdemo_no_such_prefix*");
  DebugN("  dpTypes(\"dpdemo_no_such_prefix*\") вернул ", dynlen(none), " типов");
  dpdCheck("несовпадающая подстановка даёт пустой результат", dynlen(none) == 0);

  // --- 4. ЛОВУШКА: system = 0 возвращает пусто ----------------------------
  // Документация молчит об этом. Не используйте 0 как «по умолчанию».
  dyn_string zeroSystem = dpTypes("*", 0, true);
  dyn_string sys1 = dpTypes("*", 1, true);
  DebugN("  dpTypes(\"*\", 0, TRUE) -> ", dynlen(zeroSystem), " типов");
  DebugN("  dpTypes(\"*\", 1, TRUE) -> ", dynlen(sys1), " типов");
  dpdCheck("system = 0 даёт пустой результат — это ловушка", dynlen(zeroSystem) == 0);
  dpdCheck("с настоящим номером системы результат непустой", dynlen(sys1) > 0);

  // --- 5. includeEmpty -----------------------------------------------------
  dyn_string notEmpty = dpTypes("*", 1, false);
  DebugN("  includeEmpty = TRUE : ", dynlen(sys1), " типов");
  DebugN("  includeEmpty = FALSE: ", dynlen(notEmpty), " типов");
  dpdCheck("includeEmpty = FALSE даёт меньше типов", dynlen(notEmpty) < dynlen(sys1));

  // --- 6. сколько среди типов системных ------------------------------------
  int systemCount = 0;
  int userCount = 0;
  dyn_string sample;
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpdIsSystem(all[i]))
    {
      systemCount++;
      if (dynlen(sample) < 6) { sample[dynlen(sample) + 1] = all[i]; }
    }
    else { userCount++; }
  }
  DebugN("  системных типов: ", systemCount, ", пользовательских: ", userCount);
  DebugN("  примеры системных: ", sample);
  dpdCheck("выдача разделена на системные и пользовательские типы",
           systemCount + userCount == dynlen(all));
  dpdCheck("системные типы действительно есть в проекте", systemCount > 0);

  dpdSummary();
}

// ===========================================================================
// Помощники
// ===========================================================================
int dpdPass = 0;
int dpdFail = 0;

void dpdHeader(string fn, string synopsis)
{
  DebugN("=== ", fn, " ===  ", synopsis);
}

void dpdCheck(string what, bool ok)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "  lastError=", getLastError()); }
}

void dpdSummary()
{
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
}

// dpNames() возвращает имена с префиксом системы ("System1:_mp_ANALOG1"),
// поэтому префикс системы нужно снять ДО проверки: системной является точка
// данных, если имя узла начинается с подчёркивания.
//
// В CTL 3.18 нет ни len(), ни indexOf(): есть strlen(), substr(), strpos().
// Проверено экспериментально.
bool dpdIsSystem(string name)
{
  if (name == "") { return false; }
  string bare = name;
  if (substr(name, 0, 6) == "System")
  {
    int colon = strpos(name, ":");
    if (colon > 0) { bare = substr(name, colon + 1); }
  }
  if (bare == "") { return false; }
  return substr(bare, 0, 1) == "_";
}