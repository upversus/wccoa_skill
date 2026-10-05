// exp_bool.ctl — ИССЛЕДОВАНИЕ, ВЫВОД КОТОРОГО ОКАЗАЛСЯ НЕВЕРНЫМ.
//
// ⚠ НЕ ДОВЕРЯЙТЕ ВЫВОДУ ЭТОГО СКРИПТА. Он проверял логический узел
// ОДНИМ мгновенным срезом значения и на этом основании заподозрил дефект
// драйвера. Узел User3 ПЕРЕКЛЮЧАЕТСЯ между true и false, поэтому срез
// попадал на false и выглядел как поломка. Настоящий вывод — в
// exp_bool2.ctl и в docs/11-address.md, раздел 10.1: логический тип
// работает, проверять нужно переход значения, а не срез.
//
// Скрипт оставлен как напоминание о типичной ошибке в тестах: проверка,
// зависящая от мгновенного значения изменяющегося источника, ненадёжна.
//
// Проверено: CTL 3.18, проект <проект стенда>.

main()
{
  DebugN("=== Поиск правильного варианта для Boolean ===");

  string server       = "kep";
  string subscription = "kep_sub";
  string itemId       = "ns=2;s=Simulation Examples.Functions.User3";
  int    driverNumber = 3;

  string dpt = "dpdemo_booltest";
  dpdDropAllDpOfType(dpt);

  // Тип с пятью однотипными элементами-заглушками. Их типы подставим позже
  // через dpTypeChange — нет, проще: создаём пять элементов разных типов,
  // каждый под свою гипотезу.
  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);              types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "vA_bool751");  types[2] = makeDynInt(0, DPEL_BOOL);   // A
  names[3] = makeDynString("", "vB_bool750");  types[3] = makeDynInt(0, DPEL_BOOL);   // B
  names[4] = makeDynString("", "vC_bool0");    types[4] = makeDynInt(0, DPEL_BOOL);   // C
  names[5] = makeDynString("", "vD_int751");   types[5] = makeDynInt(0, DPEL_INT);    // D
  names[6] = makeDynString("", "vE_bit32");    types[6] = makeDynInt(0, DPEL_BIT32);  // E

  DebugN("dpTypeCreate rc=", dpTypeCreate(names, types));

  string dpName = "dpdemo_booltest_1";
  DebugN("dpCreate rc=", dpCreate(dpName, dpt));

  // Гипотезы:
  //   A) тип DPE bool  + _datatype 751 (BOOLEAN)   — как в первом прогоне
  //   B) тип DPE bool  + _datatype 750 (DEFAULT)
  //   C) тип DPE bool  + _datatype не задан (0)
  //   D) тип DPE int   + _datatype 751 (BOOLEAN)
  //   E) тип DPE bit32 + _datatype 751 (BOOLEAN)
  dpdTry(dpName + ".vA_bool751", server, subscription, itemId, 751, driverNumber);
  dpdTry(dpName + ".vB_bool750", server, subscription, itemId, 750, driverNumber);
  dpdTry(dpName + ".vC_bool0",   server, subscription, itemId, 0,   driverNumber);
  dpdTry(dpName + ".vD_int751",  server, subscription, itemId, 751, driverNumber);
  dpdTry(dpName + ".vE_bit32",   server, subscription, itemId, 751, driverNumber);

  // Ждём данные
  delay(8);

  bool  a; bool b; bool c; int d; bit32 e;
  dpGet(dpName + ".vA_bool751:_online.._value", a);
  dpGet(dpName + ".vB_bool750:_online.._value", b);
  dpGet(dpName + ".vC_bool0:_online.._value",   c);
  dpGet(dpName + ".vD_int751:_online.._value",  d);
  dpGet(dpName + ".vE_bit32:_online.._value",   e);

  DebugN("--- РЕЗУЛЬТАТ (ожидаем TRUE / 1) ---");
  DebugN("  A) DPE bool  + datatype 751 (BOOLEAN) -> ", a);
  DebugN("  B) DPE bool  + datatype 750 (DEFAULT) -> ", b);
  DebugN("  C) DPE bool  + datatype не задан     -> ", c);
  DebugN("  D) DPE int   + datatype 751 (BOOLEAN) -> ", d);
  DebugN("  E) DPE bit32 + datatype 751 (BOOLEAN) -> ", e);

  // Те же элементы, но в конфиге _original — вдруг значение есть там,
  // а _online отдаёт 0 до первого обновления.
  bool aOrig;
  dpGet(dpName + ".vA_bool751:_original.._value", aOrig);
  DebugN("  A) то же в _original.._value           -> ", aOrig);

  // Статус качества: вдруг значение невалидно и поэтому не приходит.
  bool bad;
  bit32 status;
  dpGet(dpName + ".vA_bool751:_online.._bad",   bad);
  dpGet(dpName + ".vA_bool751:_online.._status", status);
  DebugN("  A) _online.._bad = ", bad, "  _online.._status = ", status);

  // ------------------------------------------------------------------
  // Решающий тест. Все пять вариантов выше дали ноль. Если драйвер
  // вообще доставляет значение узла, то запросив его НЕ как BOOLEAN,
  // мы должны получить 1. Если и тут ноль — узел не доставляется вовсе.
  //
  // Узел User3 — единственный рабочий boolean на сервере (остальные
  // boolean-узлы _Hints имеют DataType = Null и статус Bad).
  // ------------------------------------------------------------------
  DebugN("--- решающий тест: значение узла под другими типами ---");

  string dp2 = "dpdemo_booltest_2";
  DebugN("dpCreate rc=", dpCreate(dp2, dpt));

  dpdTry(dp2 + ".vA_bool751", server, subscription, itemId, 751, driverNumber); // BOOLEAN
  dpdTry(dp2 + ".vB_bool750", server, subscription, itemId, 750, driverNumber); // DEFAULT
  dpdTry(dp2 + ".vC_bool0",   server, subscription, itemId, 760, driverNumber); // FLOAT
  dpdTry(dp2 + ".vD_int751",  server, subscription, itemId, 761, driverNumber); // DOUBLE
  dpdTry(dp2 + ".vE_bit32",   server, subscription, itemId, 762, driverNumber); // STRING

  delay(8);

  bool  f2A; bool f2B; float f2C; double f2D; string f2E;
  dpGet(dp2 + ".vA_bool751:_online.._value", f2A);
  dpGet(dp2 + ".vB_bool750:_online.._value", f2B);
  dpGet(dp2 + ".vC_bool0:_online.._value",   f2C);   // запрошен FLOAT
  dpGet(dp2 + ".vD_int751:_online.._value",  f2D);   // запрошен DOUBLE
  dpGet(dp2 + ".vE_bit32:_online.._value",   f2E);   // запрошен STRING

  DebugN("  запрошен BOOLEAN (751) -> DPE bool  : ", f2A);
  DebugN("  запрошен DEFAULT (750) -> DPE bool  : ", f2B);
  DebugN("  запрошен FLOAT   (760) -> DPE bool  : ", f2C, "   <- если 1, значение доходит");
  DebugN("  запрошен DOUBLE  (761) -> DPE int   : ", f2D);
  DebugN("  запрошен STRING  (762) -> DPE bit32 : '", f2E, "'");

  // teardown
  dpdDropDp(dpName);
  dpdDropDp(dp2);
  dpdDropAllDpOfType(dpt);
  dpTypeDelete(dpt);
  DebugN("=== конец ===");
}

void dpdDropDp(string dpName)
{
  if (dpExists(dpName)) { dpDelete(dpName); }
}

// Конфигурирует адрес и сразу читает записанный _datatype обратно.
void dpdTry(string dpe, string server, string subscription, string itemId,
            int datatype, int driverNumber)
{
  string address = server + "$" + subscription + "$1$1$" + itemId;

  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", driverNumber);

  if (datatype == 0)
  {
    // _datatype намеренно не задаём
    dpSetTimedWait(0, dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                      dpe + ":_address.._reference", address,
                      dpe + ":_address.._active",    TRUE,
                      dpe + ":_address.._drv_ident", "OPCUA",
                      dpe + ":_address.._direction", DPATTR_ADDR_MODE_INPUT_POLL);
  }
  else
  {
    dpSetTimedWait(0, dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                      dpe + ":_address.._reference", address,
                      dpe + ":_address.._active",    TRUE,
                      dpe + ":_address.._drv_ident", "OPCUA",
                      dpe + ":_address.._datatype",  datatype,
                      dpe + ":_address.._direction", DPATTR_ADDR_MODE_INPUT_POLL);
  }

  int got;
  dpGet(dpe + ":_address.._datatype", got);
  DebugN("  ", dpe, ": запрошен datatype=", datatype, ", в конфиге=", got);
}

void dpdDropAllDpOfType(string dpt)
{
  dyn_string names = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(names); i++)
  {
    dpDelete(names[i]);
  }
}