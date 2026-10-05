// probe_type.ctl - проверка правила "конфиг есть, если _type != 0".
//
// Документация утверждает: dpGet() не проверяет конфиг, признак конфига -
// его атрибут _type, где 0 - конфига нет. Скрипт 01_dpGet.ctl на этом
// споткнулся: у заведомо существующего конфига _online значение _type = 0.
//
// Проверяем на трёх случаях:
//   A. нативная точка, созданная dpCreate - конфиг _online точно есть;
//   B. та же точка, заведомо отсутствующий конфиг _alert_class;
//   C. элемент реальной точки OPC UA, где _type ранее читался как 2.
//
// Ищем признак, который реально различает "есть" и "нет".

string DPT = "probe_t";
string DP  = "probe";

main()
{
  DebugN("=== Проверка признака существования конфига ===");

  // --- создаём нативную точку
  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString(DPT);        t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "fVal"); t[2] = makeDynInt(0, DPEL_FLOAT);
  dpTypeCreate(n, t);
  dpCreate(DP, DPT);
  dpSet(DP + ".fVal", 42.5);

  // --- A. конфиг _online у нативной точки
  DebugN("");
  DebugN("--- A. Нативная точка, конфиг _online (заведомо есть) ---");
  probe(DP + ".fVal:_online",       "существует");
  probe(DP + ".fVal:_alert_class",  "ОТСУТСТВУЕТ");
  probe(DP + ".fVal:_nonsense_cfg", "ОТСУТСТВУЕТ");

  // --- B. контрольный случай: заведомо существующий элемент
  DebugN("");
  DebugN("--- B. Контроль: элемент fVal и несуществующий элемент ---");
  DebugN("  rc при чтении _value:");
  float ev;
  DebugN("     fVal:_online.._value      rc=", dpGet(DP + ".fVal:_online.._value", ev));
  DebugN("     nosuch.._value            rc=", dpGet(DP + ".nosuch.._value", ev));
  DebugN("     fVal:_alert_class.._value rc=", dpGet(DP + ".fVal:_alert_class.._value", ev));

  // --- вывод
  DebugN("");
  DebugN("--- Итог ---");
  DebugN("  Сравни _type и rc для существующего и отсутствующего конфигов.");
  DebugN("  Признак годится только тот, где эти случаи различаются.");

  dpDelete(DP);
  for (int i = 1; i <= 30; i++) { if (!dpExists(DP)) { break; } delay(1); }
  for (int k = 1; k <= 30; k++)
  {
    dyn_dyn_string pn;
    dyn_dyn_int pt;
    if (dpTypeGet(DPT, pn, pt) != 0) { break; }
    dpTypeDelete(DPT);
    delay(1);
  }
  DebugN("=== конец ===");
}

// Печатает _type и rc для каждого атрибута конфига cfg.
void probe(string cfg, string note)
{
  DebugN("  ", cfg, "   (", note, ")");

  int t;
  int rcT = dpGet(cfg + ".._type", t);
  DebugN("     _type          rc=", rcT, "  значение=", t);

  time st;
  int rcS = dpGet(cfg + ".._stime", st);
  DebugN("     _stime         rc=", rcS);

  float v;
  int rcV = dpGet(cfg + ".._value", v);
  DebugN("     _value         rc=", rcV, "  значение=", v);

  int num;
  int rcN = dpGet(cfg + ".._num_ranges", num);
  DebugN("     _num_ranges    rc=", rcN, "  значение=", num);
}