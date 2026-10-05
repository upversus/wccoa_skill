// exp_bool2.ctl — проверка логического элемента f1.b_node.
//
// Задача: выяснить, был ли предыдущий провал (User3 читался как FALSE)
// особенностью узла или особенностью драйвера на логическом типе.
//
// Пользователь создал f1.b_node как рабочий пример логического узла.
//
// Проверяется: полный конфиг _address элемента и фактическое значение.
//
// Проверено: CTL 3.18, проект <проект стенда>.

main()
{
  DebugN("=== Логический элемент f1.b_node ===");

  string dpe = "f1.b_node";

  DebugN("dpExists = ", dpExists(dpe));
  DebugN("dpTypeName(\"f1.\") = '", dpTypeName("f1."), "'");
  DebugN("dpElementType(\"", dpe, "\") = ", dpElementType(dpe),
         "  (23 = DPEL_BOOL)");

  // --- конфиг _address ---
  string sVal;
  bool bVal;
  int iVal;

  dpGet(dpe + ":_address.._type",      iVal); DebugN("_address.._type      = ", iVal);
  dpGet(dpe + ":_address.._reference", sVal); DebugN("_address.._reference = '", sVal, "'");
  dpGet(dpe + ":_address.._drv_ident", sVal); DebugN("_address.._drv_ident = '", sVal, "'");
  dpGet(dpe + ":_address.._connection",sVal); DebugN("_address.._connection= '", sVal, "'");
  dpGet(dpe + ":_address.._datatype",  iVal); DebugN("_address.._datatype  = ", iVal);
  dpGet(dpe + ":_address.._direction", iVal); DebugN("_address.._direction = ", iVal);
  dpGet(dpe + ":_address.._mode",      iVal); DebugN("_address.._mode      = ", iVal);
  dpGet(dpe + ":_address.._subindex",  iVal); DebugN("_address.._subindex  = ", iVal);
  dpGet(dpe + ":_address.._offset",    iVal); DebugN("_address.._offset    = ", iVal);
  dpGet(dpe + ":_address.._active",    bVal); DebugN("_address.._active    = ", bVal);
  dpGet(dpe + ":_address.._internal",  bVal); DebugN("_address.._internal  = ", bVal);
  dpGet(dpe + ":_address.._lowlevel",  bVal); DebugN("_address.._lowlevel  = ", bVal);
  dpGet(dpe + ":_distrib.._type",      iVal); DebugN("_distrib.._type      = ", iVal);
  dpGet(dpe + ":_distrib.._driver",    iVal); DebugN("_distrib.._driver    = ", iVal);

  // --- значение ---
  // Читаем несколько раз: если это логическое значение, оно может
  // переключаться, и одного снимка мало.
  DebugN("--- значение, 6 замеров с интервалом 1 с ---");
  for (int i = 1; i <= 6; i++)
  {
    bool vOnline;
    bool vOrig;
    bool bad;
    time stime;
    dpGet(dpe + ":_online.._value",  vOnline);
    dpGet(dpe + ":_original.._value", vOrig);
    dpGet(dpe + ":_online.._bad",    bad);
    dpGet(dpe + ":_online.._stime", stime);
    DebugN("  ", i, ": _online=", vOnline, "  _original=", vOrig,
           "  bad=", bad, "  stime=", formatTime("%c", stime, ""));
    delay(1);
  }

  DebugN("=== конец ===");
}