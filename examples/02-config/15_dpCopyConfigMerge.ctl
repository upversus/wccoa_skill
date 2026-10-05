// Документация: docs/02-config.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем: создаёт свой тип и
// ДВЕ свои точки данных этого типа, в конце удаляет всё созданное.
//
// Ошибка возвращается через параметр error (ref), а не возвратом функции:
// dpCopyConfigMerge() объявлена void.
//
// ИМЕНА ЭЛЕМЕНТОВ - БЕЗ завершающей точки.
//
// ПРИЗНАК СУЩЕСТВОВАНИЯ КОНФИГА. У _default нет атрибута _stime (всего четыре
// атрибута), поэтому признак - _default.._type: 0 = нет, 3 = есть.

// 15_dpCopyConfigMerge.ctl - dpCopyConfigMerge(): слияние конфигов с исключениями.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "cfgmg_t";
string SRC = "dpdemo_cfgmg_src";
string DST = "dpdemo_cfgmg_dst";
main()
{
  DebugN("=== dpCopyConfigMerge(): слияние конфигов ===");

  makeType();
  makeDp();

  // Готовим источник: конфиг _default есть, значение известно.
  dpSetWait(SRC + ".fVal:_default.._type", DPCONFIG_DEFAULTVALUE);
  dpSetWait(SRC + ".fVal:_default.._value", 42.5);
  int tySrc; dpGet(SRC + ".fVal:_default.._type", tySrc);
  float vSrc;  dpGet(SRC + ".fVal:_default.._value", vSrc);
  DebugN("  источник: _default.._type=", tySrc, "  _default.._value=", vSrc);

  int ty; float v; int err;
  mapping empty;

  // -------------------------------------------------------------------
  // 1. Явный список конфигов
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Явный список конфигов ---");

  dpCopyConfigMergeBufferClear();
  dpCopyConfigMerge(SRC + ".fVal", DST + ".fVal", makeDynString("_default"), err, empty);
  DebugN("  error=", err, "  lastError=", getLastError());
  dpdCheck(err == 0, "слияние без ошибки", err);

  ty = -1; v = -1;
  dpGet(DST + ".fVal:_default.._type", ty);
  dpGet(DST + ".fVal:_default.._value", v);
  DebugN("  цель: _default.._type=", ty, "  _default.._value=", v);
  dpdCheck(ty == DPCONFIG_DEFAULTVALUE, "конфиг создан на цели", ty);
  dpdCheck(v == 42.5, "значение атрибута перенесено", v);

  // -------------------------------------------------------------------
  // 2. Пустой список = копировать ВСЁ
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Пустой список означает «все конфиги» ---");

  // Убираем конфиг с цели и пересоздаём точку, чтобы слияние шло с нуля.
  dropDpOnly();
  makeDp();
  dpSetWait(SRC + ".fVal:_default.._type", DPCONFIG_DEFAULTVALUE);
  dpSetWait(SRC + ".fVal:_default.._value", 42.5);

  dyn_string noList;
  dpCopyConfigMergeBufferClear();
  int err2;
  dpCopyConfigMerge(SRC + ".fVal", DST + ".fVal", noList, err2, empty);
  DebugN("  error=", err2, "  lastError=", getLastError());
  dpdCheck(err2 == 0, "слияние всех конфигов без ошибки (и без падения)", err2);

  ty = -1; v = -1;
  dpGet(DST + ".fVal:_default.._type", ty);
  dpGet(DST + ".fVal:_default.._value", v);
  DebugN("  цель: _default.._type=", ty, "  _default.._value=", v);
  dpdCheck(ty == DPCONFIG_DEFAULTVALUE,
           "пустой список действительно копирует все конфиги", ty);

  // -------------------------------------------------------------------
  // 3. forceAttributes - атрибуты, которые НЕ копировать
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. forceAttributes: что именно не переносится ---");
  DebugN("  ВНИМАНИЕ: название вводит в заблуждение. Это список");
  DebugN("  атрибутов, которые нужно ИСКЛЮЧИТЬ из копирования.");
  DebugN("  Ключ - имя атрибута в схеме <config>..<attribute>.");

  dropDpOnly();
  makeDp();
  dpSetWait(SRC + ".fVal:_default.._type", DPCONFIG_DEFAULTVALUE);
  dpSetWait(SRC + ".fVal:_default.._value", 42.5);

  mapping fa;
  fa["_default.._value"] = 0.0;
  int err3;
  dpCopyConfigMergeBufferClear();
  dpCopyConfigMerge(SRC + ".fVal", DST + ".fVal", makeDynString("_default"), err3, fa);
  DebugN("  error=", err3);
  dpdCheck(err3 == 0, "слияние с исключением без ошибки", err3);

  ty = -1; v = -1;
  dpGet(DST + ".fVal:_default.._type", ty);
  dpGet(DST + ".fVal:_default.._value", v);
  DebugN("  цель: _default.._type=", ty, "  _default.._value=", v, "  <- ожидаем 0 вместо 42.5");
  dpdCheck(ty == DPCONFIG_DEFAULTVALUE,
           "конфиг создан, хотя атрибут был исключён", ty);
  dpdCheck(v != 42.5,
           "исключённый атрибут _value НЕ перенесён", v);

  // -------------------------------------------------------------------
  // 4. Ловушка кэша: повторное слияние от того же источника
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. ЛОВУШКА: изменённый источник отдаёт СТАРЫЕ данные ---");
  DebugN("  Первый вызов dpCopyConfigMerge() запомнил источник. После этого");
  DebugN("  изменение исходного элемента НЕ подхватывается, даже если");
  DebugN("  конфиг на цели удалить и буфер очистить. Подробно разобрано");
  DebugN("  в 16_dpCopyConfigMergeBufferClear.ctl.");

  dropDpOnly();
  makeDp();
  dpSetWait(SRC + ".fVal:_default.._type", DPCONFIG_DEFAULTVALUE);
  dpSetWait(SRC + ".fVal:_default.._value", 42.5);
  dpCopyConfigMergeBufferClear();
  dpCopyConfigMerge(SRC + ".fVal", DST + ".fVal", makeDynString("_default"), err, empty);
  v = -1; dpGet(DST + ".fVal:_default.._value", v);
  DebugN("  первое слияние: цель = ", v);
  dpdCheck(v == 42.5, "первое слияние корректно", v);

  // Меняем источник и повторяем в точности по документации: чистим буфер.
  dpSetWait(SRC + ".fVal:_default.._value", 7.75);
  v = -1; dpGet(SRC + ".fVal:_default.._value", v);
  DebugN("  источник изменён на: ", v);
  dpSetWait(DST + ".fVal:_default.._value", 0.0);
  dpCopyConfigMergeBufferClear();
  int err4;
  dpCopyConfigMerge(SRC + ".fVal", DST + ".fVal", makeDynString("_default"), err4, empty);
  v = -1; dpGet(DST + ".fVal:_default.._value", v);
  DebugN("  после очистки буфера цель = ", v, "  <- осталось 42.5, а не 7.75");
  dpdCheck(err4 == 0, "повторное слияние: error = 0 (ошибки нет!)", err4);
  dpdCheck(v == 42.5,
           "цель получила СТАРЫЕ 42.5 - очистка буфера не помогла", v);

  // -------------------------------------------------------------------
  // 5. Ошибочные случаи
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Ошибочные случаи ---");

  int err5;
  dpCopyConfigMergeBufferClear();
  dpCopyConfigMerge("noSuchDpAtAll.fVal", DST + ".fVal", makeDynString("_default"), err5, empty);
  DebugN("  несуществующий источник: error=", err5, "  lastError=", getLastError());
  dpdCheck(err5 == -1, "несуществующий источник -> error = -1", err5);

  int err6;
  dpCopyConfigMergeBufferClear();
  dpCopyConfigMerge(SRC + ".fVal", "noSuchDpAtAll.fVal", makeDynString("_default"), err6, empty);
  DebugN("  несуществующее назначение: error=", err6, "  lastError=", getLastError());
  dpdCheck(err6 != 0, "несуществующее назначение -> error != 0", err6);

  dropAll();
  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

void dropDpOnly()
{
  if (dpExists(DST)) { dpDelete(DST); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(DST)) { break; }
    delay(1);
  }
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
  dpdCheck(dpCreate(SRC, DPT) == 0, "точка-источник создана", SRC);
  dpdCheck(dpCreate(DST, DPT) == 0, "точка-назначение создана", DST);
  dpSetWait(SRC + ".fVal", 0.0);
  dpSetWait(DST + ".fVal", 0.0);
  dpSetWait(SRC + ".iVal", 0);
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