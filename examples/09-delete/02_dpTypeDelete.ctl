// 02_dpTypeDelete.ctl - удаление типа точки данных.
//
// Документация: docs/09-delete.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем:
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа;
//   3) удаляем и точку данных, и тип.
//
// dpTypeDelete(dpt) удаляет тип точки данных. Возвращает 0 при успехе, -1 при
// ошибке.
//
// ПРЕДУСЛОВИЕ: все точки данных этого типа должны быть удалены, иначе ошибка.
// Именно поэтому порядок обязателен:
//
//   1) dpTypeCreate()
//   2) dpCreate()
//   3) dpDelete() для каждой точки типа
//   4) dpTypeDelete()
//
// Функция безусловна - удалить можно любой тип, поэтому все примеры работают
// с именами, начинающимися с dpdemo_.
//
// ИЗМЕРЕНО: dpTypeDelete() на CTL 3.18 синхронный - тип исчезает к моменту
// возврата. Цикл ожидания оставлен как страховка.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "dpdemo_delt_t";
string DPNAME = "dpdemo_delt_dp";

main()
{
  DebugN("=== dpTypeDelete(): удаление типа точки данных ===");

  // ---------------------------------------------------------------------
  // 1. Удаление несуществующего типа
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Несуществующий тип ---");

  int rcNo = dpTypeDelete("noSuchTypeAtAll");
  DebugN("  dpTypeDelete несуществующего  rc=", rcNo, "  lastError=", getLastError());
  dpdCheck(rcNo == -1, "несуществующий тип -> rc = -1", rcNo);

  // ---------------------------------------------------------------------
  // 2. Тип без точек данных удаляется сразу
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Тип без точек данных ---");

  makeType();
  DebugN("  тип создан, точек данных: ", dynlen(dpNames("*", DPT)));

  int rc = dpTypeDelete(DPT);
  DebugN("  dpTypeDelete rc=", rc, "  lastError=", getLastError());

  dyn_dyn_string pn;
  dyn_dyn_int pt;
  bool gone = dpTypeGet(DPT, pn, pt) != 0;

  dpdCheck(rc == 0, "удаление пустого типа вернуло rc=0", rc);
  dpdCheck(gone, "тип действительно исчез сразу, без ожидания", gone);

  // ---------------------------------------------------------------------
  // 3. Тип с живыми точками удалить НЕЛЬЗЯ
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Тип с живыми точками ---");
  DebugN("  Это главное предупреждение документации: сначала точки, потом тип.");

  makeType();
  dpCreate(DPNAME + "_1", DPT);
  dpCreate(DPNAME + "_2", DPT);
  DebugN("  создано точек данных типа: ", dynlen(dpNames("*", DPT)));

  int rcBusy = dpTypeDelete(DPT);
  DebugN("  dpTypeDelete при живых точках  rc=", rcBusy, "  lastError=", getLastError());
  bool stillThere = dpTypeGet(DPT, pn, pt) == 0;
  DebugN("  тип сохранился: ", stillThere);

  dpdCheck(rcBusy == -1, "тип с живыми точками удалить нельзя", rcBusy);
  dpdCheck(stillThere, "тип остался на месте после отказа", stillThere);

  // ---------------------------------------------------------------------
  // 4. Правильный порядок: сначала точки, потом тип
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Правильный порядок удаления ---");

  dyn_string all = dpNames("*", DPT);
  DebugN("  удаляю точки: ", dynlen(all));
  for (int i = 1; i <= dynlen(all); i++)
  {
    int rcDp = dpDelete(all[i]);
    DebugN("    dpDelete(", all[i], ") rc=", rcDp);
  }
  for (int i = 1; i <= 30; i++) { if (dynlen(dpNames("*", DPT)) == 0) { break; } delay(1); }
  DebugN("  осталось точек: ", dynlen(dpNames("*", DPT)));
  dpdCheck(dynlen(dpNames("*", DPT)) == 0, "все точки удалены", dynlen(dpNames("*", DPT)));

  int rcNow = dpTypeDelete(DPT);
  DebugN("  dpTypeDelete rc=", rcNow);
  dpdCheck(rcNow == 0, "после удаления точек тип удалился", rcNow);
  dpdCheck(dpTypeGet(DPT, pn, pt) != 0, "тип исчез", DPT);

  // ---------------------------------------------------------------------
  // 5. Повторное удаление
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Повторное удаление ---");

  int rcAgain = dpTypeDelete(DPT);
  DebugN("  dpTypeDelete уже удалённого  rc=", rcAgain);
  dpdCheck(rcAgain == -1, "повторное удаление -> rc = -1", rcAgain);

  // ---------------------------------------------------------------------
  // Уборка на случай, если что-то осталось
  // ---------------------------------------------------------------------
  dropAll();
  dpdCheck(dpTypeGet(DPT, pn, pt) != 0, "после финальной уборки тип удалён", DPT);

  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}


void makeType()
{
  dropAll();

  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString(DPT);          t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "fVal");    t[2] = makeDynInt(0, DPEL_FLOAT);
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
}

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

void dpdCheck(bool ok, string what, dyn_anytype extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra, "  lastError=", getLastError()); }
}
