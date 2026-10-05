// exp_dpt_depth.ctl — где проходит граница сложности структуры DPT.
//
// Из эксперимента 3 известно:
//   * dpTypeCreate() с корнем и двумя дочерними элементами глубины 2 — работает;
//   * любой вариант с глубиной 3 и более — возвращает -1
//     ("DM: DP already exists"), независимо от порядка и дополнения пустыми.
//   → Нужно найти точную причину: глубина, наличие вложенной структуры
//     или конкретное имя элемента.
//
// Каждый шаг проверяется на СВОЕМ типе, чтобы результаты не смешивались.

main()
{
  DebugN("=== Граница сложности DPT ===");

  // L1: только корень
  t1("L1 только корень");

  // L2: корень + один лист глубины 2
  t2("L2 корень + 1 лист");

  // L3: корень + два листа глубины 2 (заведомо рабочий вариант)
  t3("L3 корень + 2 листа");

  // L4: корень + дочерняя структура глубины 2 (без её детей)
  t4("L4 корень + дочерняя структура без детей");

  // L5: корень + дочерняя структура глубины 2 + один лист глубины 3
  t5("L5 вложенность до глубины 3");

  // L6: корень + лист глубины 2 + лист глубины 3 в другом поддереве
  t6("L6 два поддерева, один до глубины 3");

  // L7: то же, что L3, но с именем элемента "limits" вместо "upper"
  t7("L7 проверка имени 'limits'");

  DebugN("=== конец ===");
}

void t1(string what)
{
  string dpt = "dpdemo_d1";
  dropType(dpt);
  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString("root");
  t[1] = makeDynInt(DPEL_STRUCT);
  report(what, dpt, n, t);
  dropType(dpt);
}

void t2(string what)
{
  string dpt = "dpdemo_d2";
  dropType(dpt);
  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString("root");             t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "a");            t[2] = makeDynInt(0, DPEL_FLOAT);
  report(what, dpt, n, t);
  dropType(dpt);
}

void t3(string what)
{
  string dpt = "dpdemo_d3";
  dropType(dpt);
  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString("root");             t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "a");            t[2] = makeDynInt(0, DPEL_FLOAT);
  n[3] = makeDynString("", "b");            t[3] = makeDynInt(0, DPEL_BOOL);
  report(what, dpt, n, t);
  dropType(dpt);
}

void t4(string what)
{
  string dpt = "dpdemo_d4";
  dropType(dpt);
  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString("root");             t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "sub");          t[2] = makeDynInt(0, DPEL_STRUCT);
  report(what, dpt, n, t);
  dropType(dpt);
}

void t5(string what)
{
  string dpt = "dpdemo_d5";
  dropType(dpt);
  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString("root");             t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "sub");          t[2] = makeDynInt(0, DPEL_STRUCT);
  n[3] = makeDynString("", "", "a");        t[3] = makeDynInt(0, 0, DPEL_FLOAT);
  report(what, dpt, n, t);
  dropType(dpt);
}

void t6(string what)
{
  string dpt = "dpdemo_d6";
  dropType(dpt);
  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString("root");             t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "a");            t[2] = makeDynInt(0, DPEL_FLOAT);
  n[3] = makeDynString("", "sub");          t[3] = makeDynInt(0, DPEL_STRUCT);
  n[4] = makeDynString("", "", "b");        t[4] = makeDynInt(0, 0, DPEL_FLOAT);
  report(what, dpt, n, t);
  dropType(dpt);
}

void t7(string what)
{
  string dpt = "dpdemo_d7";
  dropType(dpt);
  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString("root");             t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "limits");       t[2] = makeDynInt(0, DPEL_STRUCT);
  n[3] = makeDynString("", "other");        t[3] = makeDynInt(0, DPEL_FLOAT);
  report(what, dpt, n, t);
  dropType(dpt);
}

void report(string what, string dpt, dyn_dyn_string &n, dyn_dyn_int &t)
{
  int rc = dpTypeCreate(n, t);
  DebugN("--- ", what, " (", dpt, "): dpTypeCreate rc=", rc,
         "  lastError=", getLastError());

  dyn_dyn_string back;
  dyn_dyn_int backT;
  int rcGet = dpTypeGet(dpt, back, backT);
  DebugN("      dpTypeGet rc=", rcGet, " элементов=", dynlen(back));

  if (rcGet == 0)
  {
    string dpName = dpt + "_dp";
    if (dpExists(dpName)) { dpDelete(dpName); }
    int rcDp = dpCreate(dpName, dpt);
    if (dpExists(dpName))
    {
      dyn_string leaves = dpNames(dpName + ".**");
      DebugN("      ОК: ", dynlen(leaves), " узлов:");
      for (int i = 1; i <= dynlen(leaves); i++)
      {
        DebugN("        ", leaves[i], "  тип=", dpElementType(leaves[i]));
      }
      dpDelete(dpName);
    }
    else
    {
      DebugN("      dpCreate rc=", rcDp, " — точка данных НЕ создана");
    }
  }
}

void dropType(string dpt)
{
  dyn_string names = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(names); i++)
  {
    dpDelete(names[i]);
  }
  dpTypeDelete(dpt);
}