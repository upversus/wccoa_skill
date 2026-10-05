// exp_dpt_shape.ctl — эксперимент: как правильно объявить плоский тип
// с тремя элементами (float, bool, int), чтобы dpTypeGet() вернул все три.
//
// Проверено на CTL 3.18, проект <проект стенда>, 2026-10-04.
//
// Варианты:
//   A) names[2] = makeDynString("", "fValue", "bFlag", "iCount")
//      types[2] = makeDynInt(0, DPEL_FLOAT, DPEL_BOOL, DPEL_INT)
//   B) без ведущей пустой строки:
//      names[2] = makeDynString("fValue", "bFlag", "iCount")
//      types[2] = makeDynInt(DPEL_FLOAT, DPEL_BOOL, DPEL_INT)
//   C) с дополняющими пустыми строками до фиксированной ширины 4:
//      names[2] = makeDynString("", "fValue", "bFlag", "iCount", "")
//      types[2] = makeDynInt(0, DPEL_FLOAT, DPEL_BOOL, DPEL_INT)
//
// Каждый вариант применяется к СВОЕМУ типу, чтобы результаты не смешались.

main()
{
  DebugN("=== Эксперимент: форма записи плоского DPT ===");

  // --- вариант A ----------------------------------------------------------
  dropType("dpdemo_exp_a");
  {
    dyn_dyn_string n;
    dyn_dyn_int t;
    n[1] = makeDynString("dpdemo_exp_a");
    t[1] = makeDynInt(DPEL_STRUCT);
    n[2] = makeDynString("", "fValue", "bFlag", "iCount");
    t[2] = makeDynInt(0, DPEL_FLOAT, DPEL_BOOL, DPEL_INT);
    DebugN("A) dpTypeCreate rc=", dpTypeCreate(n, t));
    dump("dpdemo_exp_a");
  }

  // --- вариант B ----------------------------------------------------------
  dropType("dpdemo_exp_b");
  {
    dyn_dyn_string n;
    dyn_dyn_int t;
    n[1] = makeDynString("dpdemo_exp_b");
    t[1] = makeDynInt(DPEL_STRUCT);
    n[2] = makeDynString("fValue", "bFlag", "iCount");
    t[2] = makeDynInt(DPEL_FLOAT, DPEL_BOOL, DPEL_INT);
    DebugN("B) dpTypeCreate rc=", dpTypeCreate(n, t));
    dump("dpdemo_exp_b");
  }

  // --- вариант C ----------------------------------------------------------
  dropType("dpdemo_exp_c");
  {
    dyn_dyn_string n;
    dyn_dyn_int t;
    n[1] = makeDynString("dpdemo_exp_c", "", "", "");
    t[1] = makeDynInt(DPEL_STRUCT, 0, 0, 0);
    n[2] = makeDynString("", "fValue", "bFlag", "iCount", "");
    t[2] = makeDynInt(0, DPEL_FLOAT, DPEL_BOOL, DPEL_INT);
    DebugN("C) dpTypeCreate rc=", dpTypeCreate(n, t));
    dump("dpdemo_exp_c");
  }

  // --- вариант D: по одному makeDyn* на элемент, нарастающим уровнем -------
  // Каждый следующий элемент объявляется отдельным вызовом на том же уровне.
  dropType("dpdemo_exp_d");
  {
    dyn_dyn_string n;
    dyn_dyn_int t;
    n[1] = makeDynString("dpdemo_exp_d");
    t[1] = makeDynInt(DPEL_STRUCT);
    n[2] = makeDynString("", "fValue");
    t[2] = makeDynInt(0, DPEL_FLOAT);
    n[2][3] = "bFlag";
    t[2][3] = DPEL_BOOL;
    n[2][4] = "iCount";
    t[2][4] = DPEL_INT;
    DebugN("D) dpTypeCreate rc=", dpTypeCreate(n, t));
    dump("dpdemo_exp_d");
  }

  // --- уборка -------------------------------------------------------------
  dropType("dpdemo_exp_a");
  dropType("dpdemo_exp_b");
  dropType("dpdemo_exp_c");
  dropType("dpdemo_exp_d");
  DebugN("=== конец эксперимента ===");
}

// Печатает структуру типа по уровням.
void dump(string dpt)
{
  dyn_dyn_string n;
  dyn_dyn_int t;
  int rc = dpTypeGet(dpt, n, t);
  DebugN("   dpTypeGet rc=", rc, " уровней=", dynlen(n));
  if (rc != 0)
  {
    return;
  }
  for (int lvl = 1; lvl <= dynlen(n); lvl++)
  {
    string namesLine = "";
    for (int i = 1; i <= dynlen(n[lvl]); i++)
    {
      namesLine = namesLine + " '" + n[lvl][i] + "'";
    }
    string typesLine = "";
    if (lvl <= dynlen(t))
    {
      for (int i = 1; i <= dynlen(t[lvl]); i++)
      {
        typesLine = typesLine + " " + t[lvl][i];
      }
    }
    DebugN("     уровень ", lvl, ": имена=", namesLine, " | типы=", typesLine);
  }
}

// Удаляет все точки данных типа и сам тип.
void dropType(string dpt)
{
  dyn_string names = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(names); i++)
  {
    dpDelete(names[i]);
  }
  dpTypeDelete(dpt);
}