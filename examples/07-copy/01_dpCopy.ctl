// 01_dpCopy.ctl - dpCopy(): копирование точки данных вместе с конфигурацией.
//
// Документация: docs/07-copy.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт создаёт свой тип и свою исходную точку данных,
// копирует её в несколько целевых точек и в конце удаляет всё созданное.
// Предустановленные точки проекта не затрагиваются.
//
// ВАЖНО. dpCopy() возвращает void. Ошибка приходит ТОЛЬКО через параметр error
// (ref). Возврата у функции нет - проверять нечего.
//
// ИМЕНА ЭЛЕМЕНТОВ - БЕЗ завершающей точки.
// ПРИЗНАК СУЩЕСТВОВАНИЯ КОНФИГА - _default.._type: 0 = нет, 3 = DPCONFIG_DEFAULTVALUE.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "cp_t";
string SRC = "dpdemo_cp_src";
string DST = "dpdemo_cp_dst";

main()
{
  DebugN("=== dpCopy(): копирование точки данных ===");

  makeType();
  makeSrc();

  langString dSrc = "Исходная точка";
  dpSetDescription(SRC + ".fVal", dSrc);
  DebugN("  на источнике: _default создан, описание задано");

  // -------------------------------------------------------------------
  // 1. Успешное копирование
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Копирование ---");

  int err;
  dpCopy(SRC, DST, err);
  DebugN("  dpCopy(\"" + SRC + "\", \"" + DST + "\")  error=", err,
         "  lastError=", getLastError());
  dpdCheck(err == 0, "копирование без ошибки", err);
  dpdCheck(dpExists(DST), "целевая точка данных создана", dpExists(DST));

  dyn_string ours = dpNames("*", DPT);
  dpdCheck(inList(ours, "System1:" + DST),
           "у копии тот же тип точки данных", "тип совпал");

  // -------------------------------------------------------------------
  // 2. Что именно перенесено
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Что перенесено ---");

  int tySrc; int tyDst;
  dpGet(SRC + ".fVal:_default.._type", tySrc);
  dpGet(DST + ".fVal:_default.._type", tyDst);
  DebugN("  _default.._type: источник=", tySrc, "  копия=", tyDst);
  dpdCheck(tySrc == DPCONFIG_DEFAULTVALUE, "на источнике конфиг есть", tySrc);
  dpdCheck(tyDst == DPCONFIG_DEFAULTVALUE, "конфиг ПЕРЕНЕСЁН на копию", tyDst);

  string dDst = dpGetDescription(DST + ".fVal");
  DebugN("  описание на копии: '", dDst, "'");
  dpdCheck(dDst == "Исходная точка", "описание элемента перенесено", "'" + dDst + "'");

  float vSrc; float vDst;
  dpGet(SRC + ".fVal:_original.._value", vSrc);
  dpGet(DST + ".fVal:_original.._value", vDst);
  DebugN("  _original.._value: источник=", vSrc, "  копия=", vDst);

  // -------------------------------------------------------------------
  // 3. Копирование в уже существующую точку
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Копирование в уже существующую точку ---");

  int err3;
  dpCopy(SRC, DST, err3);
  DebugN("  error=", err3, "  lastError=", getLastError());
  DebugN("  Документация обещает -9 (целевая точка уже существует).");
  if (err3 == 0)
  {
    DebugN("  ФАКТ: повторное копирование отработало без ошибки.");
    dpdCheck(err3 == 0,
             "повторное копирование: ошибки НЕТ (расхождение с документацией)", err3);
  }
  else
  {
    dpdCheck(err3 == -9, "повторное копирование -> error = -9", err3);
  }

  // -------------------------------------------------------------------
  // 4. Копирование в себя
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Копирование в себя ---");

  int err4;
  dpCopy(SRC, SRC, err4);
  DebugN("  dpCopy(src, src)  error=", err4, "  lastError=", getLastError());
  DebugN("  Документация обещает -12 (источник и цель совпадают).");
  dpdCheck(err4 != 0, "копирование в себя отвергается", err4);
  if (err4 != 0)
  {
    dpdCheck(err4 == -12, "точное значение кода -12", err4);
  }

  // -------------------------------------------------------------------
  // 5. Ошибочные случаи
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Ошибочные случаи ---");

  int err5;
  dpCopy("noSuchDpAtAll", DST + "_x", err5);
  DebugN("  несуществующий источник: error=", err5, "  lastError=", getLastError());
  dpdCheck(err5 == -1, "несуществующий источник -> error = -1", err5);

  int err6;
  dpCopy(SRC, DST + "_y", err6, 2);
  DebugN("  с номером драйвера iDriverNumber=2: error=", err6);
  dpdCheck(err6 == 0, "явный номер драйвера принимается", err6);
  dpdCheck(dpExists(DST + "_y"), "точка создана и с номером драйвера", dpExists(DST + "_y"));
  if (dpExists(DST + "_y"))
  {
    dpDelete(DST + "_y");
    for (int z = 1; z <= 30; z++) { if (!dpExists(DST + "_y")) { break; } delay(1); }
  }

  // -------------------------------------------------------------------
  // 6. Уборка
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 6. Уборка ---");

  dropAll();
  dpdCheck(!dpExists(DST), "копия удалена", dpExists(DST));
  dpdCheck(!dpExists(SRC), "источник удалён", dpExists(SRC));

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

void makeSrc()
{
  dpdCheck(dpCreate(SRC, DPT) == 0, "исходная точка создана", SRC);
  dpSetWait(SRC + ".fVal:_default.._type", DPCONFIG_DEFAULTVALUE);
  dpSetWait(SRC + ".fVal", 42.5);
  dpSetWait(SRC + ".iVal", 7);
}

void dropAll()
{
  if (dpExists(DST)) { dpDelete(DST); }
  if (dpExists(SRC)) { dpDelete(SRC); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(DST) && !dpExists(SRC)) { break; }
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