// 11_dpGetAllAttributes.ctl - dpGetAllAttributes(): состав конфига.
//
// Документация: docs/02-config.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем: создаёт свой тип и
// свою точку данных, в конце удаляет и то, и другое.
//
// dpGetAllAttributes(config) возвращает состав КОНФИГА - список его атрибутов.
// Практическая ценность: это самый надёжный способ узнать состав конфига на
// конкретной версии OA, вместо того чтобы гадать по документации.
//
// ГЛАВНЫЙ ВЫВОД, ИЗМЕРЕННЫЙ НА СТЕНДЕ. Состав разных конфигов различается
// ОЧЕНЬ СИЛЬНО, и _stime есть далеко не везде:
//     _original - 77 атрибутов, среди них есть _stime;
//     _default  -  4 атрибута, _stime среди НИХ НЕТ;
//     _corr     -  4 атрибута: _type, _value, _stime, _status64.
// Поэтому "_stime != 0" как универсальный признак существования конфига
// НЕ работает: чтение _default.._stime даёт rc = -1.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "cfgattr_t";
string DP  = "dpdemo_cfgattrs_dp";

main()
{
  DebugN("=== dpGetAllAttributes(): состав конфига ===");

  makeType();
  makeDp();

  // -------------------------------------------------------------------
  // 1. _original - самый большой конфиг
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. _original ---");

  dyn_string orig = dpGetAllAttributes("_original");
  DebugN("  атрибутов: ", dynlen(orig));
  for (int i = 1; i <= dynlen(orig); i++) { DebugN("    ", orig[i]); }
  dpdCheck(dynlen(orig) == 77, "_original: 77 атрибутов на CTL 3.18", dynlen(orig));

  // Ключевые атрибуты, на которые опираются другие разделы документации.
  dpdCheck(inList(orig, "_value"),  "_original содержит _value",  "_value");
  dpdCheck(inList(orig, "_stime"),  "_original содержит _stime",  "_stime");
  dpdCheck(inList(orig, "_active"), "_original содержит _active", "_active");
  dpdCheck(inList(orig, "_bad"),    "_original содержит _bad",    "_bad");

  // -------------------------------------------------------------------
  // 2. _default - всего четыре атрибута, _stime среди них нет
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. _default ---");

  dyn_string def = dpGetAllAttributes("_default");
  DebugN("  атрибутов: ", dynlen(def));
  for (int i = 1; i <= dynlen(def); i++) { DebugN("    ", def[i]); }
  dpdCheck(dynlen(def) == 4, "_default: 4 атрибута на CTL 3.18", dynlen(def));
  dpdCheck(inList(def, "_type") && inList(def, "_value") &&
           inList(def, "_set_ibit") && inList(def, "_set_pvrange"),
           "_default: ровно _type, _value, _set_ibit, _set_pvrange", "проверено");

  // ГЛАВНОЕ РАСХОЖДЕНИЕ С ПРАКТИКОЙ. _stime у _default отсутствует.
  dpdCheck(!inList(def, "_stime"),
           "у _default НЕТ атрибута _stime - читать его бессмысленно", "нет");

  int stBad;
  int rcSt = dpGet(DP + ".fVal:_default.._stime", stBad);
  DebugN("  чтение _default.._stime rc=", rcSt, "  lastError=", getLastError());
  dpdCheck(rcSt == -1, "чтение _default.._stime даёт rc=-1", rcSt);

  // -------------------------------------------------------------------
  // 3. _corr - четыре атрибута, и _stime здесь ЕСТЬ
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. _corr ---");

  dyn_string corr = dpGetAllAttributes("_corr");
  DebugN("  атрибутов: ", dynlen(corr));
  for (int i = 1; i <= dynlen(corr); i++) { DebugN("    ", corr[i]); }
  dpdCheck(dynlen(corr) == 4, "_corr: 4 атрибута", dynlen(corr));
  dpdCheck(inList(corr, "_stime"),
           "_corr содержит _stime - в отличие от _default", "_stime");
  dpdCheck(inList(corr, "_value"),
           "_corr содержит _value", "_value");

  // -------------------------------------------------------------------
  // 4. Составы разных конфигов различаются
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Сравнение составов ---");

  DebugN("  _original: ", dynlen(orig), "   _default: ", dynlen(def),
         "   _corr: ", dynlen(corr));
  dpdCheck(dynlen(orig) > dynlen(def),
           "_original заметно больше _default",
           dynlen(orig) + " против " + dynlen(def));
  dpdCheck(dynlen(def) == dynlen(corr),
           "_default и _corr одинаковой длины, но состав разный",
           dynlen(def) + " / " + dynlen(corr));

  bool anyShared = false;
  for (int i = 1; i <= dynlen(def); i++)
  {
    if (inList(corr, def[i])) { anyShared = TRUE; DebugN("    общий: ", def[i]); }
  }
  dpdCheck(anyShared, "_default и _corr имеют общие атрибуты", "проверено");

  // -------------------------------------------------------------------
  // 5. Ошибочные случаи
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Ошибочные случаи ---");

  dyn_string none = dpGetAllAttributes("_noSuchConfig");
  DebugN("  несуществующий конфиг -> ", dynlen(none), "  lastError=", getLastError());
  dpdCheck(dynlen(none) == 0, "несуществующий конфиг -> пустой массив", dynlen(none));

  // Ошибка НЕ сигнализируется ни в rc, ни в getLastError() - признак только
  // сам факт пустого массива.
  dpdCheck(dynlen(getLastError()) == 0,
           "при этом getLastError() ПУСТ - ошибку не сообщают", "пусто");

  dropAll();
  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

bool inList(dyn_string lst, string what)
{
  for (int i = 1; i <= dynlen(lst); i++)
  {
    if (lst[i] == what) { return TRUE; }
  }
  return FALSE;
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