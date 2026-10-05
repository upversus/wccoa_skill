// 14_dpCopyConfig.ctl - dpCopyConfig(): копирование конфигов между элементами.
//
// Документация: docs/02-config.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем: создаёт свой тип и
// ДВЕ свои точки данных этого типа (копировать конфиги можно только между
// элементами одного типа), в конце удаляет всё созданное.
//
// ВАЖНО. dpCopyConfig() возвращает void. Ошибка возвращается через
// параметр error, переданный по ссылке. Возврат функции игнорировать нельзя,
// но и проверять нечего - смотрим только error.
//
// ПРИЗНАК СУЩЕСТВОВАНИЯ КОНФИГА. У конфига _default нет атрибута _stime
// (всего четыре атрибута: _type, _value, _set_ibit, _set_pvrange), поэтому
// признаком служит _default.._type: 0 - конфига нет, DPCONFIG_DEFAULTVALUE - есть.

int dpdPass = 0;
int dpdFail = 0;

string DPT  = "cfgcp_t";
string SRC  = "dpdemo_cfgcp_src";
string DST  = "dpdemo_cfgcp_dst";

main()
{
  DebugN("=== dpCopyConfig(): копирование конфигов ===");

  makeType();
  makeDp();

  // Убеждаемся, что на цели конфига _default нет.
  int ty0;
  dpGet(DST + ".fVal:_default.._type", ty0);
  DebugN("  на цели _default.._type до копирования: ", ty0);
  dpdCheck(ty0 == 0, "на цели конфига _default нет", ty0);

  // -------------------------------------------------------------------
  // 1. Копирование конфига, который на источнике есть
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Копирование _default ---");

  int rcSrc = dpSet(SRC + ".fVal:_default.._type", DPCONFIG_DEFAULTVALUE);
  dpdCheck(rcSrc == 0, "на источнике _default создан", rcSrc);

  int tySrc;
  dpGet(SRC + ".fVal:_default.._type", tySrc);
  DebugN("  на источнике _default.._type = ", tySrc);
  dpdCheck(tySrc == DPCONFIG_DEFAULTVALUE, "источник: конфиг есть", tySrc);

  int err;
  dyn_string conf = makeDynString("_default");
  dpCopyConfig(SRC + ".fVal", DST + ".fVal", conf, err);
  DebugN("  dpCopyConfig error=", err, "  lastError=", getLastError());
  dpdCheck(err == 0, "dpCopyConfig без ошибки", err);

  int ty1;
  dpGet(DST + ".fVal:_default.._type", ty1);
  DebugN("  на цели _default.._type после копирования: ", ty1);
  dpdCheck(ty1 == DPCONFIG_DEFAULTVALUE, "конфиг действительно скопирован", ty1);

  // -------------------------------------------------------------------
  // 2. Несколько конфигов одним вызовом
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Несколько конфигов ---");

  dpSet(SRC + ".fVal:_default.._type", DPCONFIG_DEFAULTVALUE);
  dpSet(DST + ".fVal:_default.._type", DPCONFIG_NONE);
  dpSet(DST + ".iVal:_default.._type", DPCONFIG_NONE);

  int err2;
  dyn_string conf2 = makeDynString("_default", "_pv_range");
  dpCopyConfig(SRC + ".fVal", DST + ".fVal", conf2, err2);
  DebugN("  error=", err2);
  dpdCheck(err2 == 0, "два конфига одним вызовом без ошибки", err2);

  int ty2a; int ty2b;
  dpGet(DST + ".fVal:_default.._type", ty2a);
  dpGet(DST + ".iVal:_default.._type", ty2b);
  DebugN("  на цели: fVal _default.._type=", ty2a, "  iVal _default.._type=", ty2b);
  dpdCheck(ty2a == DPCONFIG_DEFAULTVALUE, "fVal: _default скопирован", ty2a);
  dpdCheck(ty2b == DPCONFIG_NONE, "iVal не тронут - источник не трогался", ty2b);

  // Копирование идёт по элементам: элемент iVal источника не задет.
  // Проверим, что элемент назначения тоже можно скопировать отдельно.
  int err2b;
  dpSet(DST + ".iVal:_default.._type", DPCONFIG_NONE);
  dpCopyConfig(SRC + ".fVal", DST + ".iVal", makeDynString("_default"), err2b);
  int ty2c;
  dpGet(DST + ".iVal:_default.._type", ty2c);
  DebugN("  копирование fVal -> iVal: error=", err2b, "  на iVal _default.._type=", ty2c);
  // ИЗМЕРЕНО: перенос конфига между РАЗНЫМИ элементами одного типа (fVal -> iVal)
  // не срабатывает: error = 0, а на цели конфига не появляется. То есть
  // функция копирует конфиг строго на тот же элемент-приёмник по позиции.
  dpdCheck(err2b == 0, "fVal -> iVal: error = 0", err2b);
  dpdCheck(ty2c == 0,
           "fVal -> iVal: конфиг НЕ перенесён - копируется только на тот же элемент",
           ty2c);

  // -------------------------------------------------------------------
  // 3. _original копировать нельзя
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Попытка скопировать _original ---");

  // ИЗМЕРЕНО: документация говорит "_original копировать нельзя", но
  // фактически dpCopyConfig() возвращает error = 0 и молчит. Запрет
  // НЕ проверяется - полагаться на error здесь нельзя.
  int err3;
  dpCopyConfig(SRC + ".fVal", DST + ".fVal", makeDynString("_original"), err3);
  DebugN("  error=", err3, "  lastError=", getLastError());
  dpdCheck(err3 == 0,
           "_original: error = 0 - запрет НЕ проверяется (расхождение с документацией)",
           err3);

  // -------------------------------------------------------------------
  // 4. Ошибочные случаи
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Ошибочные случаи ---");

  // Конфига нет на источнике.
  dpSet(SRC + ".fVal:_default.._type", DPCONFIG_NONE);
  dpSet(DST + ".fVal:_default.._type", DPCONFIG_NONE);
  int err4;
  dpCopyConfig(SRC + ".fVal", DST + ".fVal", makeDynString("_default"), err4);
  DebugN("  конфига нет на источнике: error=", err4);
  int ty4;
  dpGet(DST + ".fVal:_default.._type", ty4);
  DebugN("  на цели _default.._type = ", ty4);
  dpdCheck(ty4 == 0, "нечего копировать - на целе конфига не появилось", ty4);

  // Несуществующий источник.
  int err5;
  dpCopyConfig("noSuchDpAtAll.fVal", DST + ".fVal", makeDynString("_default"), err5);
  DebugN("  несуществующий источник: error=", err5, "  lastError=", getLastError());
  dpdCheck(err5 != 0, "несуществующий источник -> error != 0", err5);

  // Несуществующее назначение.
  int err6;
  dpCopyConfig(SRC + ".fVal", "noSuchDpAtAll.fVal", makeDynString("_default"), err6);
  DebugN("  несуществующее назначение: error=", err6, "  lastError=", getLastError());
  dpdCheck(err6 != 0, "несуществующее назначение -> error != 0", err6);

  // Элементы разных типов данных.
  int err7;
  dpCopyConfig(SRC + ".fVal", DST + ".iVal", makeDynString("_default"), err7);
  DebugN("  разные типы данных (float -> int): error=", err7, "  lastError=", getLastError());
  // ИЗМЕРЕНО: разные типы данных (float -> int) ТОЖЕ не дают ошибки,
  // хотя документация требует однотипность элементов. Проверки нет.
  dpdCheck(err7 == 0,
           "разные типы данных: error = 0 - проверки однотипности нет", err7);

  // ЛОВУШКА, ПРОВЕРЕННАЯ ОТДЕЛЬНО. Пустой список конфигов в dpCopyConfig()
  // приводит к НЕОБРАБОТАННОМУ исключению "Index out of range" (mp.ctl) и
  // скрипт обрывается, не печатая итогов. Вызов намеренно НЕ приведён в
  // этом скрипте: он убил бы проверку целиком. Если список может оказаться
  // пустым, проверяйте dynlen() ДО вызова.

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
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
}

void makeDp()
{
  dpdCheck(dpCreate(SRC, DPT) == 0, "точка-источник создана", SRC);
  dpdCheck(dpCreate(DST, DPT) == 0, "точка-назначение создана", DST);
  dpSet(SRC + ".fVal", 0.0);
  dpSet(DST + ".fVal", 0.0);
  dpSet(SRC + ".iVal", 0);
  dpSet(DST + ".iVal", 0);
}

void dropAll()
{
  if (dpExists(SRC)) { dpDelete(SRC); }
  if (dpExists(DST)) { dpDelete(DST); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(SRC) && !dpExists(DST)) { break; }
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