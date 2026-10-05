// probe_attrtype.ctl - значения dpAttributeType() и констант *_VAR.
//
// dpAttributeType() отвечает на вопрос о типе АТРИБУТА, а не элемента.
// Набор констант другой: FLOAT_VAR / INT_VAR, а не DPEL_*.
//
// Сначала нужно узнать, что именно возвращается, и сопоставить с константами,
// поэтому этот пробник только печатает числа и ничего не утверждает.

string DPT = "attr_t";
string DP  = "attr";

main()
{
  DebugN("=== dpAttributeType: разведка ===");

  DebugN("");
  DebugN("--- значения известных констант ---");
  DebugN("  FLOAT_VAR = ", FLOAT_VAR);
  DebugN("  INT_VAR   = ", INT_VAR);

  makeObjects();

  DebugN("");
  DebugN("--- тип атрибута по элементам и конфигам ---");

  dyn_string elems = makeDynString("fVal", "iVal", "bVal", "sVal", "tVal");
  dyn_string attrs = makeDynString("_value", "_stime", "_bad", "_status");

  for (int e = 1; e <= dynlen(elems); e++)
  {
    for (int a = 1; a <= dynlen(attrs); a++)
    {
      string p1 = DP + "." + elems[e] + ":_original.." + attrs[a];
      string p2 = DP + "." + elems[e] + ":_online.." + attrs[a];
      int r1 = dpAttributeType(p1);
      int r2 = dpAttributeType(p2);
      DebugN("  ", elems[e], "  ", attrs[a],
             "   _original=", r1, "   _online=", r2);
    }
  }

  DebugN("");
  DebugN("--- корневой элемент ---");
  DebugN("  корень :_online.._value   = ", dpAttributeType(DP + ".:" + "_online.._value"));
  DebugN("  корень :_original.._value = ", dpAttributeType(DP + ".:" + "_original.._value"));

  DebugN("");
  DebugN("--- ошибочные случаи ---");
  DebugN("  несуществующий элемент  = ", dpAttributeType(DP + ".nosuch:_online.._value"));
  DebugN("  несуществующий конфиг   = ", dpAttributeType(DP + ".fVal:_nope.._value"));
  DebugN("  несуществующий атрибут  = ", dpAttributeType(DP + ".fVal:_online.._nope"));
  DebugN("  пустая строка           = ", dpAttributeType(""));
  DebugN("  элемент без точки       = ", dpAttributeType(DP + "fVal:_online.._value"));

  cleanObjects();
  DebugN("=== конец ===");
}

void makeObjects()
{
  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString(DPT);          t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "fVal");    t[2] = makeDynInt(0, DPEL_FLOAT);
  n[3] = makeDynString("", "iVal");    t[3] = makeDynInt(0, DPEL_INT);
  n[4] = makeDynString("", "bVal");    t[4] = makeDynInt(0, DPEL_BOOL);
  n[5] = makeDynString("", "sVal");    t[5] = makeDynInt(0, DPEL_STRING);
  n[6] = makeDynString("", "tVal");    t[6] = makeDynInt(0, DPEL_TIME);
  dpTypeCreate(n, t);
  dpCreate(DP, DPT);
  dpSet(DP + ".fVal", 42.5);
  dpSet(DP + ".iVal", -17);
  dpSet(DP + ".bVal", TRUE);
  dpSet(DP + ".sVal", "строка");
  delay(1);
  DebugN("  создана точка ", DP, " типа ", DPT);
}

void cleanObjects()
{
  if (dpExists(DP)) { dpDelete(DP); }
  for (int i = 1; i <= 30; i++) { if (!dpExists(DP)) { break; } delay(1); }
  for (int k = 1; k <= 30; k++)
  {
    dyn_dyn_string pn;
    dyn_dyn_int pt;
    if (dpTypeGet(DPT, pn, pt) != 0) { break; }
    dpTypeDelete(DPT);
    delay(1);
  }
}