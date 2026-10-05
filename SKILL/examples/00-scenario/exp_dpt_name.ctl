// exp_dpt_name.ctl — проверка гипотезы: имя типа точки данных берётся
// из ПЕРВОГО элемента arrays, переданных в dpTypeCreate().
//
// Наблюдение, породившее гипотезу:
//   * exp_dpt_depth.ctl объявлял тип "dpdemo_d1", но передавал
//     n[1] = makeDynString("root"). dpTypeCreate() вернул 0,
//     а dpTypeGet("dpdemo_d1") вернул -1.
//   * Все следующие варианты с тем же n[1] = "root" вернули -1
//     с сообщением "DM: DP already exists".
//   * exp_dpt_shape2.ctl работал, потому что там n[1] содержал
//     ИМЯ ТИПА, а не отдельное слово.
//
// Вывод, который проверяем: dpTypeCreate() не имеет параметра с именем типа,
// и имя типа — это elements[1]. Корневой узел структуры называется тем же
// именем, что и сам тип.
//
// Проверено: CTL 3.18, проект <проект стенда>.

main()
{
  DebugN("=== Проверка: откуда dpTypeCreate() берёт имя типа ===");

  // 1. Гипотеза: имя типа = elements[1].
  string dpt = "dpdemo_nametest";
  dropType(dpt);
  DebugN("Объявляем тип с именем '", dpt, "' в elements[1]");

  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString(dpt);
  t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "value");
  t[2] = makeDynInt(0, DPEL_FLOAT);

  int rc = dpTypeCreate(n, t);
  DebugN("  dpTypeCreate rc=", rc, "  lastError=", getLastError());

  // 2. Тип с таким именем должен появиться.
  dyn_string found = dpTypes(dpt);
  DebugN("  dpTypes(\"", dpt, "\") вернул ", dynlen(found), " записей");
  DebugN("  ИТОГ: имя типа берётся из elements[1]: ", (rc == 0 && dynlen(found) == 1));

  // 3. Структура созданного типа: корневой узел назван так же, как тип.
  dyn_dyn_string back;
  dyn_dyn_int backT;
  int rcGet = dpTypeGet(dpt, back, backT);
  DebugN("  dpTypeGet rc=", rcGet, " элементов=", dynlen(back));
  if (rcGet == 0)
  {
    DebugN("    корень: '", back[1][1], "' тип=", backT[1][1], " (DPEL_STRUCT=",
           DPEL_STRUCT, ")");
    DebugN("    ИТОГ: корень назван именем типа: ", back[1][1] == dpt);
  }

  // 4. Контрольный отрицательный случай: если в elements[1] положить
  //    другое слово, тип создастся под ЭТИМ именем, а не под запрошенным.
  string dpt2 = "dpdemo_wrongname";
  dropType("notdpdemo_name");
  DebugN("Объявляем тип '", dpt2, "', но в elements[1] кладём 'notdpdemo_name'");

  dyn_dyn_string n2;
  dyn_dyn_int t2;
  n2[1] = makeDynString("notdpdemo_name");
  t2[1] = makeDynInt(DPEL_STRUCT);
  n2[2] = makeDynString("", "value");
  t2[2] = makeDynInt(0, DPEL_FLOAT);

  int rc2 = dpTypeCreate(n2, t2);
  DebugN("  dpTypeCreate rc=", rc2);
  DebugN("  dpTypes(\"", dpt2, "\")            -> ", dynlen(dpTypes(dpt2)), " записей");
  DebugN("  dpTypes(\"notdpdemo_name\")        -> ", dynlen(dpTypes("notdpdemo_name")), " записей");
  DebugN("  ИТОГ: создан тип с именем из elements[1], а не с запрошенным: ",
         (dynlen(dpTypes(dpt2)) == 0 && dynlen(dpTypes("notdpdemo_name")) == 1));

  // --- teardown ------------------------------------------------------------
  dropType(dpt);
  dropType("notdpdemo_name");
  dropType("root");
  DebugN("=== конец ===");
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