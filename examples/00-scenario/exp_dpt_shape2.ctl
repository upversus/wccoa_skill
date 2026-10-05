// exp_dpt_shape2.ctl — второй эксперимент: как индексируются массивы
// dpTypeCreate().
//
// Установлено первым экспериментом (exp_dpt_shape.ctl, CTL 3.18):
//   * у DPT есть корневой элемент уровня 1 с типом DPEL_STRUCT;
//   * если в names[2] перечислить несколько имён ("", "fValue", "bFlag", "iCount"),
//     OA создаст ОДИН элемент — читается только позиция 2;
//   * следовательно, гипотеза «индекс массива = уровень, позиция = сосед» НЕВЕРНА.
//
// Проверяем гипотезу: индекс массива = порядковый номер элемента при обходе
// в ширину, а в ячейке лежит путь от корня, имя стоит на своей глубине.
//
// Варианты:
//   E) индекс = номер элемента, путь дополнен пустыми до максимальной глубины:
//        n[1]=("root","")     t[1]=(1,0)
//        n[2]=("","fValue")   t[2]=(0,22)
//        n[3]=("","bFlag")    t[3]=(0,23)
//        n[4]=("","iCount")   t[4]=(0,21)
//   F) то же, но без дополняющих пустых:
//        n[1]=("root")        t[1]=(1)
//        n[2]=("","fValue")   t[2]=(0,22)   и т.д.
//   G) контрольный: ровно один дочерний элемент
//
// Проверка результата ведётся НЕ только через dpTypeGet(), но и через
// dpNames() на реально созданной точке данных — это независимый источник истины.

main()
{
  DebugN("=== Эксперимент 2: индексация массивов dpTypeCreate() ===");

  runVariant("E", "dpdemo_e2_e");
  runVariant("F", "dpdemo_e2_f");
  runVariant("G", "dpdemo_e2_g");

  DebugN("=== конец эксперимента 2 ===");
}

// Создаёт тип, создаёт по нему точку данных и печатает, что реально получилось.
void runVariant(string tag, string dpt)
{
  dropType(dpt);

  dyn_dyn_string n;
  dyn_dyn_int t;

  if (tag == "E")
  {
    n[1] = makeDynString(dpt, "");        t[1] = makeDynInt(DPEL_STRUCT, 0);
    n[2] = makeDynString("", "fValue");    t[2] = makeDynInt(0, DPEL_FLOAT);
    n[3] = makeDynString("", "bFlag");     t[3] = makeDynInt(0, DPEL_BOOL);
    n[4] = makeDynString("", "iCount");    t[4] = makeDynInt(0, DPEL_INT);
  }
  else if (tag == "F")
  {
    n[1] = makeDynString(dpt);            t[1] = makeDynInt(DPEL_STRUCT);
    n[2] = makeDynString("", "fValue");    t[2] = makeDynInt(0, DPEL_FLOAT);
    n[3] = makeDynString("", "bFlag");     t[3] = makeDynInt(0, DPEL_BOOL);
    n[4] = makeDynString("", "iCount");    t[4] = makeDynInt(0, DPEL_INT);
  }
  else if (tag == "G")
  {
    n[1] = makeDynString(dpt);            t[1] = makeDynInt(DPEL_STRUCT);
    n[2] = makeDynString("", "fValue");    t[2] = makeDynInt(0, DPEL_FLOAT);
  }

  int rc = dpTypeCreate(n, t);
  DebugN("--- Вариант ", tag, " (", dpt, "): dpTypeCreate rc=", rc);

  dumpType(dpt);

  // Независимая проверка: создаём точку данных и спрашиваем её элементы.
  string dpName = dpt + "_dp";
  int rcDp = dpCreate(dpName, dpt);
  DebugN("    dpCreate rc=", rcDp, "  dpExists=", dpExists(dpName));
  if (dpExists(dpName))
  {
    dyn_string leaves = dpNames(dpName + ".**");
    DebugN("    элементы точки данных (", dynlen(leaves), " шт.):");
    for (int i = 1; i <= dynlen(leaves); i++)
    {
      string leaf = leaves[i];
      // dpNames возвращает "DP.EL1.EL2" — печатаем тип последнего элемента
      DebugN("      ", leaf, "  тип=", dpElementType(leaf));
    }
  }

  dropType(dpt);
}

void dumpType(string dpt)
{
  dyn_dyn_string n;
  dyn_dyn_int t;
  int rc = dpTypeGet(dpt, n, t);
  DebugN("    dpTypeGet rc=", rc, " элементов в массиве=", dynlen(n));
  if (rc != 0)
  {
    return;
  }
  for (int i = 1; i <= dynlen(n); i++)
  {
    string namesLine = "";
    for (int j = 1; j <= dynlen(n[i]); j++)
    {
      namesLine = namesLine + " [" + j + "='" + n[i][j] + "']";
    }
    string typesLine = "";
    if (i <= dynlen(t))
    {
      for (int j = 1; j <= dynlen(t[i]); j++)
      {
        typesLine = typesLine + " " + t[i][j];
      }
    }
    DebugN("    n[", i, "]=", namesLine, "  t[", i, "]=", typesLine);
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