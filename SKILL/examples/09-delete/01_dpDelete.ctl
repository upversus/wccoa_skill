// 01_dpDelete.ctl - удаление точки данных.
//
// Документация: docs/09-delete.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем:
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа;
//   3) удаляем и точку данных, и тип.
//
// dpDelete(dpname) удаляет точку данных. Возвращает 0 при успехе, -1 при
// ошибке. Функция БЕЗУСЛОВНАЯ: никакой проверки "а точно это тестовая точка?"
// в ней нет, поэтому удалять можно что угодно. Все примеры используют имена
// с префиксом dpdemo_ именно поэтому.
//
// ИЗМЕРЕНО: dpDelete() на CTL 3.18 СИНХРОННЫЙ. Точка данных исчезает
// к моменту возврата из функции - dpExists() сразу даёт FALSE. Документация
// объявляет функцию Blocking, и это подтверждается.
//
// Циклы ожидания ниже оставлены как страховка: на других объёмах или при
// удалении типа с множеством точек поведение может отличаться, и лишний
// цикл ожидания стоит дешевле, чем попытка работать с несуществующим объектом.
// Функция объявлена как Blocking, но фактически не блокирует.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "del_t";
string DP  = "dpdemo_del_dp";

main()
{
  DebugN("=== dpDelete(): удаление точки данных ===");

  // ---------------------------------------------------------------------
  // 1. Удаление несуществующей точки
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Несуществующая точка ---");

  int rcNo = dpDelete("noSuchDpAtAll");
  DebugN("  dpDelete несуществующей  rc=", rcNo, "  lastError=", getLastError());
  dpdCheck(rcNo == -1, "несуществующая точка -> rc = -1", rcNo);

  // ---------------------------------------------------------------------
  // 2. Создание и удаление
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Создание и удаление ---");

  makeType();
  makeDp();

  DebugN("  точка существует: ", dpExists(DP));

  int rc = dpDelete(DP);
  DebugN("  dpDelete rc=", rc, "  lastError=", getLastError());
  dpdCheck(rc == 0, "удаление вернуло rc=0", rc);

  // АСИНХРОННОСТЬ. Сразу после вызова точка может быть ещё видна.
  bool goneNow = !dpExists(DP);
  DebugN("  сразу после вызова dpExists = ", dpExists(DP), "   исчезла ли: ", goneNow);
  DebugN("  Если здесь FALSE - удаление асинхронно и нужен цикл ожидания.");

  // Ждём исчезновения
  int waited = 0;
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(DP)) { waited = i; break; }
    delay(1);
  }
  DebugN("  исчезла через ", waited, " с");
  dpdCheck(!dpExists(DP), "точка данных действительно исчезла", dpExists(DP));

  // ---------------------------------------------------------------------
  // 3. Повторное удаление уже удалённой точки
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Повторное удаление ---");

  int rcAgain = dpDelete(DP);
  DebugN("  dpDelete уже удалённой  rc=", rcAgain);
  dpdCheck(rcAgain == -1, "повторное удаление -> rc = -1", rcAgain);

  // ---------------------------------------------------------------------
  // 4. Удаление с префиксом системы
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Имя с префиксом системы ---");
  DebugN("  В распределённой установке имя должно содержать номер системы.");

  makeDp();
  int rcSys = dpDelete("System1:" + DP);
  DebugN("  dpDelete(\"System1:\" + DP)  rc=", rcSys);
  for (int i = 1; i <= 30; i++) { if (!dpExists(DP)) { break; } delay(1); }
  dpdCheck(!dpExists(DP), "удаление по имени с системой сработало", dpExists(DP));

  // ---------------------------------------------------------------------
  // 5. Удаление всех точек типа разом
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Все точки типа ---");

  dpCreate(DP + "_b", DPT);
  dpCreate(DP + "_c", DPT);
  DebugN("  создано две точки: ", DP, "_b, ", DP, "_c");
  dpdCheck(dynlen(dpNames("*", DPT)) == 2, "точек данных типа - две",
           dynlen(dpNames("*", DPT)));
  dyn_string all = dpNames("*", DPT);
  for (int i = 1; i <= dynlen(all); i++)
  {
    dpDelete(all[i]);
  }
  for (int i = 1; i <= 30; i++) { if (dynlen(dpNames("*", DPT)) == 0) { break; } delay(1); }
  DebugN("  осталось точек: ", dynlen(dpNames("*", DPT)));
  dpdCheck(dynlen(dpNames("*", DPT)) == 0, "все точки типа удалены",
           dynlen(dpNames("*", DPT)));

  // ---------------------------------------------------------------------
  // 6. Уборка типа
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("(6) уборка типа");
  dropType();
  dyn_dyn_string pn;
  dyn_dyn_int pt;
  dpdCheck(dpTypeGet(DPT, pn, pt) != 0, "тип удалён", DPT);

  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

void makeType()
{
  dropType();

  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString(DPT);          t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "fVal");    t[2] = makeDynInt(0, DPEL_FLOAT);
  n[3] = makeDynString("", "iVal");    t[3] = makeDynInt(0, DPEL_INT);
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
}

void makeDp()
{
  dpdCheck(dpCreate(DP, DPT) == 0, "точка данных создана", DP);
  dpSet(DP + ".fVal", 1.0);
}

void dropType()
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

void dpdCheck(bool ok, string what, dyn_anytype extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra, "  lastError=", getLastError()); }
}
