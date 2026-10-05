// 12_groupCreate.ctl - groupCreate(): создание группы точек данных.
//
// Документация: docs/01-create.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Группы создаются и удаляются внутри скрипта: имя группы
// делается уникальным, а в конце всё удаляется. Предустановленные точки
// проекта и чужие группы не затрагиваются.
//
// ВАЖНО ПРО ИМПОРТ. groupCreate() - НЕ функция базовой библиотеки DLL, а
// обычная функция на CTL из библиотеки dpGroups.ctl. Без директивы
//     #uses "dpGroups.ctl"
// вызов не компилируется:
//     SEVERE, 72, Function not defined, <файл>, Line: N, groupCreate
// Это НЕ означает, что функции нет в версии. Тот же приём использует
// штатный distSyncMan.ctl: #uses "dist.ctl" / "distsync.ctl" / "dpGroups.ctl".
//
// ВАЖНО ПРО iError. Функция объявлена void, код ошибки приходит только через
// iError (ref). Но сам код iError при УСПХЕ НЕ ПРИСВАИВАЕТ - он меняется
// только в ветках ошибки. Поэтому переменную нужно обнулять ДО вызова,
// иначе можно получить "успех" с мусором в iError.
//
// Проверено: CTL 3.18, проект <проект стенда>.

#uses "dpGroups.ctl"

int dpdPass = 0;
int dpdFail = 0;

string GRP     = "dpdemo_grp_a";
string GRP_PRIV = "dpdemo_grp_b";

main()
{
  DebugN("=== groupCreate(): создание группы точек данных ===");
  DebugN("  библиотека dpGroups.ctl подключена, функция доступна");

  // Чистим возможные остатки прошлого прогона.
  int pre;
  groupDelete(GRP, pre);
  groupDelete(GRP_PRIV, pre);

  // -------------------------------------------------------------------
  // 1. Создание публичной группы
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Публичная группа ---");

  string newGroup = "";
  int err = 0;              // ОБНУЛЯЕМ САМИ: функция iError при успехе не пишет
  groupCreate(GRP, FALSE, newGroup, FALSE, err);
  DebugN("  groupCreate(\"" + GRP + "\", bPrivate=FALSE)");
  DebugN("    iError = ", err, "   newGroup = '", newGroup, "'");
  DebugN("    текст ошибки: '", groupGetErrorText(err), "'");
  dpdCheck(err == 0, "группа создана, iError = 0", err);
  dpdCheck(newGroup != "", "имя точки данных группы получено", "'" + newGroup + "'");

  // Синтаксис имени: _DpGroup<NNNNN>_Public
  // substr() в CTL: первый аргумент - смещение от 0, второй - длина.
  //   "_DpGroup00021_Public"
  //    0123456789...
  bool shaped = (substr(newGroup, 0, 8) == "_DpGroup") &&
                (substr(newGroup, 8, 5) != "");
  DebugN("  префикс _DpGroup: ", shaped, "   номер: '",
         substr(newGroup, 8, 5), "'");
  dpdCheck(shaped, "имя группы начинается с _DpGroup и содержит номер", "'" + newGroup + "'");
  dpdCheck(substr(newGroup, 14, 6) == "Public",
           "публичная группа помечена словом Public", substr(newGroup, 14, 6));

  // Точка данных группы действительно создана и имеет тип _DpGroup.
  DebugN("  dpExists = ", dpExists(newGroup));
  dpdCheck(dpExists(newGroup), "точка данных группы существует", dpExists(newGroup));
  // dpNames() возвращает имена С ПРЕФИКСОМ СИСТЕМЫ - проверено в 10_dpNames.ctl.
  dyn_string ofType = dpNames("*", "_DpGroup");
  dpdCheck(dynContains(ofType, "System1:" + newGroup),
           "точка в списке точек типа _DpGroup", newGroup);

  // Атрибут Level выставлен согласно параметру main.
  int level;
  dpGet(newGroup + ".Level:_original.._value", level);
  DebugN("  Level = ", level, " (main=FALSE -> ожидаем 0)");
  dpdCheck(level == 0, "Level = 0 при main = FALSE", level);

  // Имя группы лежит в описании точки данных.
  string backName = groupDpNameToName(newGroup);
  DebugN("  groupDpNameToName(\"" + newGroup + "\") = '", backName, "'");
  dpdCheck(backName == GRP, "имя группы читается обратно без потерь", "'" + backName + "'");

  // Обратное преобразование.
  // ИЗМЕРЕНО: groupNameToDpName() возвращает имя С ПРЕФИКСОМ СИСТЕМЫ.
  string dpBack = groupNameToDpName(GRP);
  DebugN("  groupNameToDpName(\"" + GRP + "\") = '", dpBack, "'");
  dpdCheck(dpBack == "System1:" + newGroup,
           "имя группы преобразуется в имя точки данных (с префиксом системы)",
           "'" + dpBack + "'");

  // -------------------------------------------------------------------
  // 2. Повторное создание той же группы
  // -------------------------------------------------------------------
  // РАСХОЖДЕНИЕ С ДОКУМЕНТАЦИЕЙ, НАЙДЕННОЕ ПО ТЕКСТУ dpGroups.ctl.
  // Документация обещает -9 (группа уже существует). Измерен��: дубликат
  // СОЗДАЁТСЯ, iError = 0.
  //
  // Причина в самой библиотеке: проверка дубликата сравнивает переменную str
  // с именем группы (строка 110), но несколькими строками ниже (строка 119)
  // та же переменная str переиспользуется под номер группы:
  //     string lastGroup = dpSubStr(dpGroups[i], DPSUB_DP);
  //     str = substr(lastGroup, 8, 5);      // <- str теперь номер
  // То есть к моменту проверки следующей группы str уже не то имя, и
  // сравнение никогда не срабатывает. Проверить это поведение можно только
  // из CTL - по документации оно выглядит как защита.
  DebugN("");
  DebugN("--- 2. Повторное создание той же группы ---");

  string again = "";
  int err2 = 0;
  groupCreate(GRP, FALSE, again, FALSE, err2);
  DebugN("    iError = ", err2, "   newGroup = '", again, "'");
  DebugN("  Документация обещает -9, но измерен другой результат.");
  dpdCheck(err2 == 0,
           "дубликат создан БЕЗ ошибки - код -9 не срабатывает (дефект dpGroups.ctl)",
           err2);
  dpdCheck(again != "" && again != newGroup,
           "создана отдельная группа с новым номером", "'" + again + "'");
  // Убираем обе группы по именам их точек данных: обе подписаны одним
  // именем, поэтому groupDelete(имя) удалил бы только одну из них.
  if (again  != "") { dropGp(again); }
  if (newGroup != "") { dropGp(newGroup); }
  dpdCheck(!dpExists(again) && !dpExists(newGroup),
           "обе группы с одинаковым именем удалены", "обе");

  // -------------------------------------------------------------------
  // 3. Пустое имя группы
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Пустое имя группы ---");

  string emptyGp = "";
  int err3 = 0;
  groupCreate("", FALSE, emptyGp, FALSE, err3);
  DebugN("    iError = ", err3, "   newGroup = '", emptyGp, "'");
  DebugN("  Документация обещает -10 (пустое имя).");
  dpdCheck(err3 == -10, "пустое имя -> iError = -10", err3);

  // Пустое имя из одних пробелов - тоже отвергается (код проверяет trim).
  string spaces = "   ";
  string spGp = "";
  int err3b = 0;
  groupCreate(spaces, FALSE, spGp, FALSE, err3b);
  DebugN("    имя из пробелов: iError = ", err3b);
  dpdCheck(err3b == -10, "имя из одних пробелов -> iError = -10", err3b);

  // -------------------------------------------------------------------
  // 4. Приватная группа и main = TRUE
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Приватная группа, main = TRUE ---");

  string privGp = "";
  int err4 = 0;
  groupCreate(GRP_PRIV, TRUE, privGp, TRUE, err4);
  DebugN("    iError = ", err4, "   newGroup = '", privGp, "'");
  dpdCheck(err4 == 0, "приватная группа создана", err4);
  dpdCheck(privGp != "", "имя приватной группы получено", "'" + privGp + "'");

  // У приватной группы в имени НЕ "Public", а имя пользователя.
  string tail = substr(privGp, 14, 40);
  DebugN("  хвост имени приватной группы: '", tail, "'");
  DebugN("  пользователь: '", getUserName(), "'");
  dpdCheck(tail == getUserName(),
           "приватная группа оканчивается ИМЕНЕМ ПОЛЬЗОВАТЕЛЯ", "'" + tail + "'");

  int level2;
  dpGet(privGp + ".Level:_original.._value", level2);
  DebugN("  Level = ", level2, " (main=TRUE -> ожидаем 1)");
  dpdCheck(level2 == 1, "Level = 1 при main = TRUE", level2);

  // -------------------------------------------------------------------
  // 5. Ловушка: iError не присваивается при успехе
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Ловушка: iError не обнуляется функцией ---");
  DebugN("  Код функции присваивает iError ТОЛЬКО в ветках ошибки.");
  DebugN("  Поэтому перед вызовом переменную нужно обнулять самим.");

  int dirty = 12345;
  string tmpGp = "";
  groupCreate(GRP_PRIV + "_c", FALSE, tmpGp, FALSE, dirty);
  DebugN("  перед вызовом iError = 12345, после успешного вызова: ", dirty);
  dpdCheck(dirty == 12345,
           "после УСПЕШНОГО вызова iError не изменился - функция его не пишет",
           dirty);
  DebugN("  Значит проверять (err == 0) без обнуления бессмысленно.");
  DebugN("  Удаляем оставшуюся группу.");
  groupDelete(GRP_PRIV + "_c", dirty);

  // -------------------------------------------------------------------
  // 6. Уборка
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 6. Уборка ---");

  int e1 = 0; groupDelete(GRP, e1);
  int e2 = 0; groupDelete(GRP_PRIV, e2);
  DebugN("  удаление приватной группы: ", e2);
  DebugN("  удаление группы " + GRP + ": ", e1,
         "  <- -2 ожидаем: обе группы с этим именем удалены в разделе 2");
  dpdCheck(e2 == 0, "приватная группа удалена", e2);
  dpdCheck(e1 == -2,
           "повторное удаление уже удалённой группы -> iError = -2", e1);

  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

void dropGp(string dp)
{
  if (dpExists(dp)) { dpDelete(dp); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(dp)) { break; }
    delay(1);
  }
}

void dpdCheck(bool ok, string what, dyn_anytype extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra, "  lastError=", getLastError()); }
}