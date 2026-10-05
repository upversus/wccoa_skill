// exp_modbus_ref.ctl — считывание эталонной конфигурации Modbus
// с точки данных ExampleDP_Arg1.
//
// Задача: узнать формат строки _reference для драйвера MODBUS и набор
// атрибутов, которые реально заполняются. Формат документирован отдельно
// (см. docs/11-address.md, раздел 5.2), но на стенде не проверен.
//
// Эталон: ExampleDP_Arg1 — настроена вручную и получает данные.
//
// Проверено: CTL 3.18, проект prg_12_3.

main()
{
  DebugN("=== Эталон конфигурации MODBUS: ExampleDP_Arg1 ===");

  string dpName = "ExampleDP_Arg1";

  DebugN("dpExists(\"", dpName, "\") = ", dpExists(dpName));
  string type = dpTypeName(dpName + ".");
  DebugN("dpTypeName = '", type, "'");

  // --- структура типа ---
  dyn_dyn_string tn;
  dyn_dyn_int tt;
  int rcT = dpTypeGet(type, tn, tt);
  DebugN("dpTypeGet rc=", rcT, " элементов=", dynlen(tn));
  if (rcT == 0)
  {
    for (int i = 1; i <= dynlen(tn); i++)
    {
      string nl = "";
      for (int j = 1; j <= dynlen(tn[i]); j++) { nl = nl + " '" + tn[i][j] + "'"; }
      string tl = "";
      if (i <= dynlen(tt))
      {
        for (int j = 1; j <= dynlen(tt[i]); j++) { tl = tl + " " + tt[i][j]; }
      }
      DebugN("   n[", i, "]=", nl, "  t[", i, "]=", tl);
    }
  }

  // --- элементы ---
  dyn_string elems = dpNames(dpName + ".**");
  DebugN("--- элементы (", dynlen(elems), ") ---");
  for (int i = 1; i <= dynlen(elems); i++)
  {
    DebugN("   ", elems[i], "  тип=", dpElementType(elems[i]));
  }

  // --- конфиг _address на каждом элементе, где он есть ---
  DebugN("--- конфиг _address по элементам ---");
  for (int i = 1; i <= dynlen(elems); i++)
  {
    string dpe = elems[i];

    int cfgType;
    int rcT2 = dpGet(dpe + ":_address.._type", cfgType);
    if (rcT2 != 0 || cfgType == 0)
    {
      DebugN("   ", dpe, ": конфига _address нет");
      continue;
    }

    DebugN("   ", dpe, ":");
    DebugN("      _type       = ", cfgType);

    string sVal;
    int iVal;
    bool bVal;

    dpGet(dpe + ":_address.._reference",  sVal); DebugN("      _reference  = '", sVal, "'");
    dpGet(dpe + ":_address.._drv_ident",  sVal); DebugN("      _drv_ident  = '", sVal, "'");
    dpGet(dpe + ":_address.._connection", sVal); DebugN("      _connection = '", sVal, "'");
    dpGet(dpe + ":_address.._datatype",   iVal); DebugN("      _datatype   = ", iVal);
    dpGet(dpe + ":_address.._direction",  iVal); DebugN("      _direction  = ", iVal);
    dpGet(dpe + ":_address.._mode",      iVal); DebugN("      _mode       = ", iVal);
    dpGet(dpe + ":_address.._subindex",   iVal); DebugN("      _subindex   = ", iVal);
    dpGet(dpe + ":_address.._offset",     iVal); DebugN("      _offset     = ", iVal);
    dpGet(dpe + ":_address.._active",     bVal); DebugN("      _active     = ", bVal);
    dpGet(dpe + ":_address.._internal",   bVal); DebugN("      _internal   = ", bVal);
    dpGet(dpe + ":_address.._lowlevel",   bVal); DebugN("      _lowlevel   = ", bVal);

    // конфиг драйвера
    int distType;
    int distDrv;
    dpGet(dpe + ":_distrib.._type",   distType);
    dpGet(dpe + ":_distrib.._driver", distDrv);
    DebugN("      _distrib.._type = ", distType, "  _distrib.._driver = ", distDrv);

    // значение
    dyn_anytype v;
    dpGet(dpe + ":_online.._value", v);
    time stime;
    dpGet(dpe + ":_online.._stime", stime);
    DebugN("      значение = ", v, "  stime = ", formatTime("%c", stime, ""));
  }

  DebugN("=== конец ===");
}