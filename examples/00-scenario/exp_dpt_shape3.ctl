// exp_dpt_shape3.ctl — третий эксперимент.
//
// Два вопроса, на которые не даёт ответ документация:
//
// (1) dpTypes(): второй параметр — номер системы. Что означает 0?
//     Наблюдение: dpTypes("*") возвращает ПУСТО, при этом
//     dpTypes("*") возвращает типы. Возможно 0 = «система 0», которой нет.
//
// (2) dpTypeCreate(): в каком порядке перечислять элементы вложенной структуры?
//     Вариант H — «как читаешь сверху вниз» (родитель, потом его дети, потом
//     следующий ребёнок корня, то есть в глубину).
//     Вариант I — в ширину: сначала все дети корня, потом дети первого ребёнка.
//     Вариант J — как I, но все пути дополнены пустыми до общей ширины 4.
//
// Проверено: CTL 3.18, проект prg_12_3.

main()
{
  DebugN("=== Эксперимент 3 ===");

  probeDpTypes();

  // Структура: valve / setpoint(limits(upper,lower)) / state / tag
  DebugN("--- H: порядок в глубину ---");
  {
    dropType("dpdemo_h");
    dyn_dyn_string n;
    dyn_dyn_int t;
    n[1] = makeDynString("valve");            t[1] = makeDynInt(DPEL_STRUCT);
    n[2] = makeDynString("", "setpoint");      t[2] = makeDynInt(0, DPEL_STRUCT);
    n[3] = makeDynString("", "", "limits");    t[3] = makeDynInt(0, 0, DPEL_STRUCT);
    n[4] = makeDynString("", "", "", "upper"); t[4] = makeDynInt(0, 0, 0, DPEL_FLOAT);
    n[5] = makeDynString("", "", "", "lower"); t[5] = makeDynInt(0, 0, 0, DPEL_FLOAT);
    n[6] = makeDynString("", "state");         t[6] = makeDynInt(0, DPEL_BOOL);
    n[7] = makeDynString("", "tag");           t[7] = makeDynInt(0, DPEL_STRING);
    DebugN("  dpTypeCreate rc=", dpTypeCreate(n, t));
    report("dpdemo_h");
    dropType("dpdemo_h");
  }

  DebugN("--- I: порядок в ширину ---");
  {
    dropType("dpdemo_i");
    dyn_dyn_string n;
    dyn_dyn_int t;
    n[1] = makeDynString("valve");            t[1] = makeDynInt(DPEL_STRUCT);
    n[2] = makeDynString("", "setpoint");      t[2] = makeDynInt(0, DPEL_STRUCT);
    n[3] = makeDynString("", "state");         t[3] = makeDynInt(0, DPEL_BOOL);
    n[4] = makeDynString("", "tag");           t[4] = makeDynInt(0, DPEL_STRING);
    n[5] = makeDynString("", "", "limits");    t[5] = makeDynInt(0, 0, DPEL_STRUCT);
    n[6] = makeDynString("", "", "", "upper"); t[6] = makeDynInt(0, 0, 0, DPEL_FLOAT);
    n[7] = makeDynString("", "", "", "lower"); t[7] = makeDynInt(0, 0, 0, DPEL_FLOAT);
    DebugN("  dpTypeCreate rc=", dpTypeCreate(n, t));
    report("dpdemo_i");
    dropType("dpdemo_i");
  }

  DebugN("--- J: в ширину + дополнение пустыми до ширины 4 ---");
  {
    dropType("dpdemo_j");
    dyn_dyn_string n;
    dyn_dyn_int t;
    n[1] = makeDynString("valve", "", "", "");           t[1] = makeDynInt(DPEL_STRUCT, 0, 0, 0);
    n[2] = makeDynString("", "setpoint", "", "");        t[2] = makeDynInt(0, DPEL_STRUCT, 0, 0);
    n[3] = makeDynString("", "state", "", "");           t[3] = makeDynInt(0, DPEL_BOOL, 0, 0);
    n[4] = makeDynString("", "tag", "", "");             t[4] = makeDynInt(0, DPEL_STRING, 0, 0);
    n[5] = makeDynString("", "", "limits", "");          t[5] = makeDynInt(0, 0, DPEL_STRUCT, 0);
    n[6] = makeDynString("", "", "", "upper");           t[6] = makeDynInt(0, 0, 0, DPEL_FLOAT);
    n[7] = makeDynString("", "", "", "lower");           t[7] = makeDynInt(0, 0, 0, DPEL_FLOAT);
    DebugN("  dpTypeCreate rc=", dpTypeCreate(n, t));
    report("dpdemo_j");
    dropType("dpdemo_j");
  }

  DebugN("=== конец эксперимента 3 ===");
}

// (1) Как ведёт себя dpTypes() при разном втором параметре.
void probeDpTypes()
{
  DebugN("--- dpTypes() ---");
  DebugN("  dpTypes()                     -> ", dynlen(dpTypes()));
  DebugN("  dpTypes(\"*\")                  -> ", dynlen(dpTypes("*")));
  DebugN("  dpTypes(\"*\", 0, true)         -> ", dynlen(dpTypes("*")));
  DebugN("  dpTypes(\"*\", 0, false)        -> ", dynlen(dpTypes("*")));
  DebugN("  dpTypes(\"*\", 1, true)         -> ", dynlen(dpTypes("*", 1, true)));
  DebugN("  dpTypes(\"*\", 1, false)        -> ", dynlen(dpTypes("*", 1, false)));
  DebugN("  myManNum() = ", myManNum());

  // И отдельно — что вообще есть в проекте.
  dyn_string all = dpTypes();
  DebugN("  первые типы проекта:");
  for (int i = 1; i <= dynlen(all) && i <= 10; i++)
  {
    DebugN("    ", all[i]);
  }

  // dpNames() без второго параметра.
  dyn_string names = dpNames();
  DebugN("  dpNames() вернул ", dynlen(names), " точек данных; первые:");
  for (int i = 1; i <= dynlen(names) && i <= 10; i++)
  {
    DebugN("    ", names[i]);
  }
}

// Печатает, создался ли тип и какие у него элементы.
void report(string dpt)
{
  dyn_dyn_string n;
  dyn_dyn_int t;
  int rc = dpTypeGet(dpt, n, t);
  DebugN("  dpTypeGet rc=", rc, " элементов=", dynlen(n));
  string dpName = dpt + "_dp";
  if (dpExists(dpName)) { dpDelete(dpName); }
  int rcDp = dpCreate(dpName, dpt);
  DebugN("  dpCreate rc=", rcDp, " dpExists=", dpExists(dpName));
  if (dpExists(dpName))
  {
    dyn_string leaves = dpNames(dpName + ".**");
    DebugN("  элементы точки данных (", dynlen(leaves), "):");
    for (int i = 1; i <= dynlen(leaves); i++)
    {
      DebugN("    ", leaves[i], "  тип=", dpElementType(leaves[i]));
    }
    dpDelete(dpName);
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