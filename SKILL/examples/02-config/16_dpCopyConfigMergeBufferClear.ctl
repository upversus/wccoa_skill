// 16_dpCopyConfigMergeBufferClear.ctl - dpCopyConfigMergeBufferClear(): очистка буфера слияния.
//
// Документация: docs/02-config.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем: создаёт свой тип и
// несколько своих точек данных, в конце удаляет всё созданное.
//
// ГЛАВНЫЙ ВЫВОД РАЗДЕЛА, ИЗМЕРЕННЫЙ НА СТЕНДЕ CTL 3.18.
// Документация обещает: если между двумя копированиями изменился исходный
// элемент, нужно очистить буфер, иначе скопируется СТАРАЯ информация.
// Проверено на стенде - ОЧИСТКА НЕ ПОМОГАЕТ:
//
//   1. первое слияние кладёт в кэш значение 42.5;
//   2. значение на источнике меняют на 7.75;
//   3. буфер очищают, конфиг на цели удаляют;
//   4. повторное слияние всё равно приносит 42.5.
//
// Помогает единственное - СМЕНИТЬ ИСХОДНЫЙ ЭЛЕМЕНТ. Тот же набор значений,
// но взятый с другого элемента, копируется верно. То есть на 3.18 очистка
// буфера не инвалидирует кэш по исходному элементу, и опереться на неё
// в рабочем коде нельзя.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "cfgbuf_t";
string S1  = "dpdemo_cfgbuf_s1";
string S2  = "dpdemo_cfgbuf_s2";
string DST = "dpdemo_cfgbuf_dst";
main()
{
  DebugN("=== dpCopyConfigMergeBufferClear(): очистка буфера слияния ===");

  makeType();
  makeDp();
  makeDp2();

  mapping empty;
  int ty; float v; int err;

  // -------------------------------------------------------------------
  // 1. Функция ничего не возвращает
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Функция объявлена void ---");

  dpCopyConfigMergeBufferClear();
  DebugN("  dpCopyConfigMergeBufferClear() вызвана, возврата нет - это void");
  DebugN("  lastError=", getLastError());
  dpdCheck(dynlen(getLastError()) == 0,
           "очистка буфера не порождает ошибок", "пусто");

  // -------------------------------------------------------------------
  // 2. Первое слияние - данные актуальные
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Первое слияние: данные верные ---");

  dpSetWait(S1 + ".fVal:_default.._type", DPCONFIG_DEFAULTVALUE);
  dpSetWait(S1 + ".fVal:_default.._value", 42.5);

  dpCopyConfigMergeBufferClear();
  dpCopyConfigMerge(S1 + ".fVal", DST + ".fVal", makeDynString("_default"), err, empty);
  ty = -1; v = -1;
  dpGet(DST + ".fVal:_default.._type", ty);
  dpGet(DST + ".fVal:_default.._value", v);
  DebugN("  источник 1 = 42.5, цель = ", v, "  error=", err);
  dpdCheck(err == 0, "первое слияние без ошибки", err);
  dpdCheck(v == 42.5, "первое слияние принесло актуальные данные", v);

  // -------------------------------------------------------------------
  // 3. Источник изменён, очистка буфера НЕ помогает
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Источник изменён, очистка буфера НЕ помогает ---");

  dpSetWait(S1 + ".fVal:_default.._value", 7.75);
  v = -1; dpGet(S1 + ".fVal:_default.._value", v);
  DebugN("  источник 1 изменён на: ", v);

  // Убираем конфиг с цели, чтобы слияние точно не могло его пропустить.
  dpSetWait(DST + ".fVal:_default.._type", DPCONFIG_NONE);
  ty = -1; dpGet(DST + ".fVal:_default.._type", ty);
  DebugN("  конфиг на цели удалён (_default.._type=", ty, ")");

  // Делаем ровно то, что предписывает документация.
  dpCopyConfigMergeBufferClear();
  dpCopyConfigMerge(S1 + ".fVal", DST + ".fVal", makeDynString("_default"), err, empty);

  ty = -1; v = -1;
  dpGet(DST + ".fVal:_default.._type", ty);
  dpGet(DST + ".fVal:_default.._value", v);
  DebugN("  после очистки буфера цель = ", v, "  <- получено 42.5 вместо 7.75");
  dpdCheck(ty == DPCONFIG_DEFAULTVALUE, "конфиг на цели создан заново", ty);
  dpdCheck(v == 42.5,
           "КЭШ НЕ ОБНОВИЛСЯ: получено старое 42.5, хотя ждали 7.75", v);

  // -------------------------------------------------------------------
  // 4. Смена исходного элемента обновляет данные
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. СМЕНА исходного элемента обновляет данные ---");

  dpSetWait(S2 + ".fVal:_default.._type", DPCONFIG_DEFAULTVALUE);
  dpSetWait(S2 + ".fVal:_default.._value", 7.75);

  dpSetWait(DST + ".fVal:_default.._type", DPCONFIG_NONE);
  dpCopyConfigMergeBufferClear();
  int err4;
  dpCopyConfigMerge(S2 + ".fVal", DST + ".fVal", makeDynString("_default"), err4, empty);
  v = -1;
  dpGet(DST + ".fVal:_default.._value", v);
  DebugN("  источник 2 = 7.75, цель = ", v, "  error=", err4);
  dpdCheck(err4 == 0, "слияние от второго источника без ошибки", err4);
  dpdCheck(v == 7.75,
           "от ДРУГОГО элемента данные верные - только это и обновляет кэш", v);

  // -------------------------------------------------------------------
  // 5. Вывод
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Практический вывод ---");
  DebugN("  На CTL 3.18 dpCopyConfigMergeBufferClear() не сбрасывает кэш");
  DebugN("  по исходному элементу. Рабочий способ обойти это:");
  DebugN("    - править конфиги источника ДО первого слияния;");
  DebugN("    - либо брать конфиги с разных элементов;");
  DebugN("    - либо не полагаться на буфер и проверять результат чтением.");

  dropAll();
  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

void makeDp2()
{
  dpdCheck(dpCreate(S2, DPT) == 0, "вторая точка-источник создана", S2);
  dpSetWait(S2 + ".fVal", 0.0);
  dpSetWait(S2 + ".iVal", 0);
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

void makeDp()
{
  dpdCheck(dpCreate(S1, DPT) == 0, "точка-источник создана", S1);
  dpdCheck(dpCreate(DST, DPT) == 0, "точка-назначение создана", DST);
  dpSetWait(S1 + ".fVal", 0.0);
  dpSetWait(DST + ".fVal", 0.0);
  dpSetWait(S1 + ".iVal", 0);
  dpSetWait(DST + ".iVal", 0);
}

void dropAll()
{
  dyn_string all = dpNames("*", DPT);
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpExists(all[i])) { dpDelete(all[i]); }
  }
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