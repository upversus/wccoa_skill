// 13_dpGetAllConfigs.ctl - dpGetAllConfigs(): какие конфиги допустимы.
//
// Документация: docs/02-config.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем: создаёт свой тип и
// свою точку данных, в конце удаляет и то, и другое.
//
// Функция имеет две формы: по элементу и по типу данных. Возвращает список
// конфигов, ДОПУСТИМЫХ для этого элемента - то есть возможных, а не созданных.
//
// ДВЕ ЛОВУШКИ, измеренные на стенде CTL 3.18:
//   1. Имя элемента передаётся БЕЗ завершающей точки: "DP.fVal:" -> 21 конфиг,
//      а документированная форма "DP.fVal.:" -> 0 конфигов и НИКАКОЙ ошибки.
//   2. Недопустимый тип данных (999) не отвергается: возвращается список из
//      10 конфигов, getLastError() пуст. Отличить мусор от настоящего ответа
//      по коду невозможно - только осмысленностью самого списка.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "cfgglob_t";
string DP  = "dpdemo_cfgglob_dp";

main()
{
  DebugN("=== dpGetAllConfigs(): допустимые конфиги ===");

  makeType();
  makeDp();

  // -------------------------------------------------------------------
  // 1. Форма по элементу: форма имени
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Форма имени элемента ---");

  dyn_string forms = makeDynString(DP + ".fVal:", DP + ".fVal.:",
                                  DP + ".fVal", DP + ".fVal.",
                                  "System1:" + DP + ".fVal:");
  for (int i = 1; i <= dynlen(forms); i++)
  {
    dyn_string c = dpGetAllConfigs(forms[i]);
    DebugN("  '", forms[i], "' -> ", dynlen(c), " конфигов");
  }

  // Рабочие формы: без завершающей точки, двоеточие необязательно.
  dpdCheck(dynlen(dpGetAllConfigs(DP + ".fVal:")) == 21,
           "форма 'DP.fVal:' -> 21 конфиг", 21);
  dpdCheck(dynlen(dpGetAllConfigs(DP + ".fVal")) == 21,
           "форма 'DP.fVal' (без двоеточия) -> 21 конфиг", 21);
  dpdCheck(dynlen(dpGetAllConfigs("System1:" + DP + ".fVal:")) == 21,
           "с префиксом системы -> 21 конфиг", 21);

  // Ловушка 1: завершающая точка даёт ноль и НЕ сообщает об ошибке.
  int withDot = dynlen(dpGetAllConfigs(DP + ".fVal.:"));
  DebugN("  документированная форма 'DP.fVal.:' -> ", withDot,
         " конфигов, lastError=", getLastError());
  dpdCheck(withDot == 0,
           "завершающая точка даёт НОЛЬ конфигов - форма из документации нерабочая",
           withDot);
  dpdCheck(dynlen(getLastError()) == 0,
           "при нулевом результате ошибка НЕ сообщается", "пусто");

  // -------------------------------------------------------------------
  // 2. Корень точки данных против элемента
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Корень точки и разные типы элементов ---");

  int root = dynlen(dpGetAllConfigs(DP + ".:"));
  DebugN("  корень точки (структура) -> ", root, " конфигов");
  dpdCheck(root == 11, "корень структуры -> 11 конфигов", root);
  dpdCheck(root < 21, "у корня набора меньше, чем у простого элемента",
           root + " против 21");

  // -------------------------------------------------------------------
  // 3. Форма по типу данных
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Форма по типу данных ---");

  dyn_int types = makeDynInt(DPEL_FLOAT, DPEL_INT, DPEL_BOOL,
                             DPEL_STRUCT, DPEL_STRING);
  for (int i = 1; i <= dynlen(types); i++)
  {
    dyn_string c = dpGetAllConfigs(types[i]);
    DebugN("  тип ", types[i], " -> ", dynlen(c), " конфигов");
  }

  dpdCheck(dynlen(dpGetAllConfigs(DPEL_FLOAT)) == 21, "float -> 21 конфиг", 21);
  dpdCheck(dynlen(dpGetAllConfigs(DPEL_INT)) == 21,   "int -> 21 конфиг", 21);
  dpdCheck(dynlen(dpGetAllConfigs(DPEL_BOOL)) == 20,  "bool -> 20 конфигов", 20);
  dpdCheck(dynlen(dpGetAllConfigs(DPEL_STRUCT)) == 11,"структура -> 11 конфигов", 11);
  dpdCheck(dynlen(dpGetAllConfigs(DPEL_STRING)) == 19,"string -> 19 конфигов", 19);

  dpdCheck(dynlen(dpGetAllConfigs(DPEL_BOOL)) != dynlen(dpGetAllConfigs(DPEL_FLOAT)),
           "bool и float дают разные наборы - функция различает типы",
           "20 против 21");

  // -------------------------------------------------------------------
  // 4. Совпадают ли формы «элемент» и «тип»
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Форма по элементу совпадает с формой по типу ---");

  dyn_string byEl = dpGetAllConfigs(DP + ".fVal:");
  dyn_string byTy = dpGetAllConfigs(DPEL_FLOAT);
  bool same = (dynlen(byEl) == dynlen(byTy));
  if (same)
  {
    for (int i = 1; i <= dynlen(byEl); i++)
    {
      if (byEl[i] != byTy[i]) { same = FALSE; }
    }
  }
  DebugN("  элемент: ", dynlen(byEl), "  тип: ", dynlen(byTy),
         "  совпадают: ", same);
  dpdCheck(same, "для float элемент и тип дают одинаковый список", "совпадают");

  // -------------------------------------------------------------------
  // 5. Ловушка 2: недопустимый тип данных
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Недопустимый тип данных 999 ---");

  dyn_string junk = dpGetAllConfigs(999);
  DebugN("  тип 999 -> ", dynlen(junk), " конфигов, lastError=", getLastError());
  for (int i = 1; i <= dynlen(junk); i++) { DebugN("    ", junk[i]); }
  dpdCheck(dynlen(junk) > 0,
           "недопустимый тип НЕ отвергается - возвращается правдоподобный список",
           dynlen(junk));
  dpdCheck(dynlen(getLastError()) == 0,
           "и getLastError() пуст - отличить от нормального ответа нечем",
           "пусто");

  // -------------------------------------------------------------------
  // 6. Несуществующий элемент
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 6. Несуществующий элемент ---");

  int noEl = dynlen(dpGetAllConfigs(DP + ".noSuchEl:"));
  DebugN("  -> ", noEl, " конфигов, lastError=", getLastError());
  dpdCheck(noEl == 0, "несуществующий элемент -> ноль конфигов", noEl);

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
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
}

void makeDp()
{
  dpdCheck(dpCreate(DP, DPT) == 0, "точка данных создана", DP);
  dpSet(DP + ".fVal", 0.0);
}

void dropAll()
{
  if (dpExists(DP)) { dpDelete(DP); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(DP)) { break; }
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