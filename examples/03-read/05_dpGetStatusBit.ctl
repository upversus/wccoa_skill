// 05_dpGetStatusBit.ctl - извлечение бита из 64-битного слова состояния.
//
// Документация: docs/03-read.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем:
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа с элементом bit32;
//   3) удаляем и точку данных, и тип.
//
// dpGetStatusBit(aStatus, aBitAttribute) возвращает значение одного бита
// 64-битного слова состояния: 0 или 1, а -1 при ошибке.
//
// ВНИМАНИЕ. Имя битового атрибута начинается с ДВОЕТОЧИЯ - это относительный
// адрес относительно элемента: ":_original.._userbit6". Без двоеточия
// работать не будет.
//
// Проверено: CTL 3.18, проект prg_12_3.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "sb_t";
string DP  = "sbDp";
string DPE = DP + ".b32";

main()
{
  DebugN("=== dpGetStatusBit(): бит из слова состояния ===");

  makeObjects();

  // ---------------------------------------------------------------------
  // 1. Читаем слово состояния
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Слово состояния элемента ---");

  bit32 status;
  int rcGet = dpGet(DPE + ":_original.._status", status);
  DebugN("  dpGet(_original.._status) rc=", rcGet);
  DebugN("  значение: ", status);

  dpdCheck(rcGet == 0, "слово состояния прочитано", rcGet);

  // ---------------------------------------------------------------------
  // 2. Извлекаем отдельные биты
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Извлечение битов ---");
  DebugN("  Имя атрибута - относительное, с двоеточием.");

  for (int bit = 0; bit <= 15; bit++)
  {
    string attr = ":_original.._userbit" + bit;
    int b = dpGetStatusBit(status, attr);
    if (b != 0)
    {
      DebugN("      ", attr, " -> ", b);
    }
    else
    {
      DebugN("      ", attr, " -> ", b, "   (ноль)");
    }
  }

  int b0 = dpGetStatusBit(status, ":_original.._userbit0");
  int b1 = dpGetStatusBit(status, ":_original.._userbit1");
  DebugN("  userbit0 = ", b0, "    userbit1 = ", b1);
  // АНОМАЛИЯ. Бит 0 возвращает -1 с сообщением "Couldn't convert to
  // DpIdentifier", тогда как биты 1 и выше отвечают нормально. Значит у
  // бита 0 нет отдельного атрибута _userbit0.
  dpdCheck(b0 == -1, "бит 0 возвращает -1 - отдельного атрибута нет", b0);
  dpdCheck(b1 == 0 || b1 == 1, "бит 1 вернул 0 или 1", b1);

  // ---------------------------------------------------------------------
  // 3. Бит выставляется и снимается
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Управление битом ---");

  // userbit - это атрибут, значит его можно записать через dpSetTimedWait.
  dpSetTimedWait(0, DPE + ":_original.._userbit3", TRUE);
  bit32 stSet;
  dpGet(DPE + ":_original.._status", stSet);
  int b3on = dpGetStatusBit(stSet, ":_original.._userbit3");
  DebugN("  после записи TRUE   -> ", b3on);

  dpSetTimedWait(0, DPE + ":_original.._userbit3", FALSE);
  bit32 stClr;
  dpGet(DPE + ":_original.._status", stClr);
  int b3off = dpGetStatusBit(stClr, ":_original.._userbit3");
  DebugN("  после записи FALSE  -> ", b3off);

  dpdCheck(b3on == 1, "бит выставился в 1", b3on);
  dpdCheck(b3off == 0, "бит снялся в 0", b3off);

  // ---------------------------------------------------------------------
  // 4. Конфиг _online даёт ту же картину
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Конфиг _online ---");

  bit32 stOn;
  int rcOn = dpGet(DPE + ":_online.._status", stOn);
  DebugN("  dpGet(_online.._status) rc=", rcOn, "  значение: ", stOn);
  dpdCheck(rcOn == 0, "слово состояния из _online прочитано", rcOn);

  int b3on2 = dpGetStatusBit(stOn, ":_online.._userbit3");
  DebugN("  _online userbit3 -> ", b3on2);
  dpdCheck(b3on2 == 0 || b3on2 == 1, "бит из _online прочитан", b3on2);

  // ---------------------------------------------------------------------
  // 5. Ошибочные случаи
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Ошибочные случаи ---");

  int e1 = dpGetStatusBit(status, ":_original.._userbit999");
  DebugN("  несуществующий бит        -> ", e1);
  dpdCheck(e1 == -1, "несуществующий бит -> -1", e1);

  int e2 = dpGetStatusBit(status, "no_such_attr");
  DebugN("  несуществующий атрибут    -> ", e2);
  dpdCheck(e2 == -1, "несуществующий атрибут -> -1", e2);

  int e3 = dpGetStatusBit(status, ":_nope.._userbit0");
  DebugN("  несуществующий конфиг     -> ", e3);
  dpdCheck(e3 == -1, "несуществующий конфиг -> -1", e3);

  int e4 = dpGetStatusBit(status, "_original.._userbit0");
  DebugN("  без ведущего двоеточия    -> ", e4);
  DebugN("    Ожидаем -1: адрес без двоеточия не является относительным.");
  dpdCheck(e4 == -1, "без ведущего двоеточия -> -1", e4);

  // ---------------------------------------------------------------------
  // 6. Уборка
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("(6) уборка");
  dropAll();
  dpdCheck(!dpExists(DP), "точка данных удалена", DP);
  dyn_dyn_string leftNames;
  dyn_dyn_int leftTypes;
  dpdCheck(dpTypeGet(DPT, leftNames, leftTypes) != 0, "тип удалён", DPT);

  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

void makeObjects()
{
  dropAll();

  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString(DPT);          t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "b32");     t[2] = makeDynInt(0, DPEL_BIT32);
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
  dpdCheck(dpCreate(DP, DPT) == 0, "точка данных создана", DP);
  delay(1);
  DebugN("  создана точка ", DP, " типа ", DPT, ", элемент b32 (bit32)");
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
