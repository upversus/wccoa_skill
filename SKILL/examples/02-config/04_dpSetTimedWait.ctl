// 04_dpSetTimedWait.ctl - dpSetTimedWait(): блокирующая запись со временем.
//
// Документация: docs/02-config.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем: создаёт свой тип и
// свою точку данных, в конце удаляет и то, и другое.
//
// dpSetTimedWait() отличается от dpSetTimed() только ожиданием: объявлена
// Blocking и ждёт ответа Event Manager. Набор ограничений по атрибутам и
// поведение кода возврата - ровно те же, что у dpSetTimed(), см. подробности
// в 03_dpSetTimed.ctl и в docs/02-config.md.
//
// ГЛАВНОЕ ОГРАНИЧЕНИЕ (наследуется от dpSetTimed): rc = 0 не значит, что
// запись выполнена. Все проверки здесь читают значение обратно.
int dpdPass = 0;
int dpdFail = 0;

string DPT = "cfgtmw_t";
string DP  = "dpdemo_cfgtmw_dp";
main()
{
  DebugN("=== dpSetTimedWait(): блокирующая запись со временем ===");

  makeType();
  makeDp();

  // -------------------------------------------------------------------
  // 1. Запись, которая действительно работает: _original.._active
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. _original.._active: рабочая запись ---");

  time t1 = makeTime(2026, 10, 5, 10, 0, 0);
  int rc1 = dpSetTimedWait(t1, DP + ".fVal:_original.._active", TRUE);
  DebugN("  dpSetTimedWait(t, _original.._active, TRUE) rc=", rc1,
         "  lastError=", getLastError());
  dpdCheck(rc1 == 0, "_active: rc=0", rc1);

  bool act;
  int rcAct = dpGet(DP + ".fVal:_original.._active", act);
  DebugN("  прочитано: ", act, "  (rc=", rcAct, ")");
  dpdCheck((rcAct == 0) && (act == TRUE), "_active записано", act);

  // -------------------------------------------------------------------
  // 2. ГЛАВНОЕ ОГРАНИЧЕНИЕ. Код возврата не сигнализирует ни о чём
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Код возврата не является признаком успеха ---");
  DebugN("  АСИММЕТРИЯ С dpSetTimed(), измеренная на стенде:");
  DebugN("    dpSetTimed()     -> rc = 0 на запрещённый атрибут, отказ НЕ виден;");
  DebugN("    dpSetTimedWait() -> rc = -1 на тот же атрибут, отказ ВИДЕН.");
  DebugN("  Причина в том, что блокирующая версия дожидается ответа");
  DebugN("  Event Manager, и в ответе приходит сам отказ. Неблокирующая");
  DebugN("  ответа не ждёт и отбрасывает его молча.");
  DebugN("  ПРАКТИЧЕСКИЙ ВЫВОД: если нужен контроль ошибок записи -");
  DebugN("  использовать dpSetTimedWait().");

  // 2a. Запрещённый атрибут _bad - rc=0, значение не изменилось.
  bool badBefore; dpGet(DP + ".fVal:_original.._bad", badBefore);
  int rcBad = dpSetTimedWait(t1, DP + ".fVal:_original.._bad", TRUE);
  bool badAfter; dpGet(DP + ".fVal:_original.._bad", badAfter);
  DebugN("  _bad: rc=", rcBad, "  было=", badBefore, " стало=", badAfter,
         "  lastError=", getLastError());
  dpdCheck(rcBad == -1, "_bad: rc=-1, отказ ВИДЕН (в отличие от dpSetTimed)", rcBad);
  dpdCheck(badAfter == badBefore, "_bad не изменился (запись проигнорирована)", badAfter);

  // 2b. Системный атрибут _quality_code - то же самое.
  int qBefore; dpGet(DP + ".fVal:_original.._quality_code", qBefore);
  int rcQ = dpSetTimedWait(t1, DP + ".fVal:_original.._quality_code", 99);
  int qAfter; dpGet(DP + ".fVal:_original.._quality_code", qAfter);
  DebugN("  _quality_code: rc=", rcQ, "  было=", qBefore, " стало=", qAfter);
  dpdCheck(rcQ == -1, "_quality_code: rc=-1, отказ виден", rcQ);
  dpdCheck(qAfter == qBefore, "_quality_code не изменился", qAfter);

  // -------------------------------------------------------------------
  // 3. _corr.._value - расхождение с документацией
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. _corr.._value: документация обещает, стенд не выполняет ---");

  // У _corr ровно четыре атрибута: _type, _value, _stime, _status64.
  // _value там float - того же типа, что _original.._value, так что дело
  // не в типе значения.
  DebugN("  состав _corr: ", dynlen(dpGetAllAttributes("_corr")), " атрибута");

  int rcCorr = dpSetTimedWait(t1, DP + ".fVal:_corr.._value", 40.0);
  float corrVal; int rcCorrGet = dpGet(DP + ".fVal:_corr.._value", corrVal);
  int corrStime; dpGet(DP + ".fVal:_corr.._stime", corrStime);
  DebugN("  dpSetTimedWait(_corr.._value, 40.0) rc=", rcCorr,
         "  прочитано=", corrVal, " (rc=", rcCorrGet, ")  _corr.._stime=", corrStime);
  dpdCheck(rcCorr == 0, "_corr.._value: rc=0", rcCorr);
  dpdCheck(corrVal != 40.0,
           "_corr.._value НЕ записалась даже с rc=0 - документация описывает нерабочий вызов",
           corrVal);

  // -------------------------------------------------------------------
  // 4. _exp_default - тоже игнорируется
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. _exp_default: rc=0, но записи нет ---");

  int rcEd = dpSetTimedWait(t1, DP + ".fVal:_original.._exp_default", 4.0);
  float ed; dpGet(DP + ".fVal:_original.._exp_default", ed);
  DebugN("  _exp_default: rc=", rcEd, "  прочитано=", ed);
  dpdCheck(rcEd == -1, "_exp_default: rc=-1, отказ виден", rcEd);
  dpdCheck(ed != 4.0, "_exp_default не изменился", ed);

  // -------------------------------------------------------------------
  // 5. Время 0
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Время источника 0 ---");
  DebugN("  Документация допускает dpSetTimedWait(0, ...) для конфигов тревог.");

  // ИЗМЕРЕНО: время 0 не игнорируется, а принимается, и запись выполняется.
  dpSetTimedWait(t1, DP + ".fVal:_original.._active", TRUE);
  bool actBefore0; dpGet(DP + ".fVal:_original.._active", actBefore0);
  int rcZero = dpSetTimedWait(0, DP + ".fVal:_original.._active", FALSE);
  bool actAfter0; dpGet(DP + ".fVal:_original.._active", actAfter0);
  DebugN("  было: ", actBefore0, "  dpSetTimedWait(0, _active, FALSE) rc=", rcZero,
         "  стало: ", actAfter0);
  dpdCheck(rcZero == 0, "время 0: rc=0", rcZero);
  dpdCheck((actBefore0 == TRUE) && (actAfter0 == FALSE),
           "время 0 принимается, запись выполняется",
           "было " + actBefore0 + " стало " + actAfter0);

  // -------------------------------------------------------------------
  // 6. Предусловие про 1970 год недостижимо
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 6. Предусловие «не раньше 1970» недостижимо через makeTime ---");

  time tOld = makeTime(1969, 12, 31, 23, 0, 0);
  DebugN("  makeTime(1969,12,31,23,0,0) вернул ", tOld);
  DebugN("  То есть CTL сам подставляет 1970-й год, и проверить отказ");
  DebugN("  на времени до 1970 средствами CTL нельзя.");
  dpdCheck(year(tOld) >= 1970, "makeTime не даёт время до 1970 года", year(tOld));

  int rcOld = dpSetTimedWait(tOld, DP + ".fVal:_original.._active", FALSE);
  bool actOld; dpGet(DP + ".fVal:_original.._active", actOld);
  DebugN("  dpSetTimedWait(1969) rc=", rcOld, "  _active=", actOld);
  dpdCheck(rcOld == -1, "подставленный 1970: rc=-1, отказ виден", rcOld);

  // -------------------------------------------------------------------
  // 7. Несколько пар и форма 2
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 7. Несколько пар и форма 2 ---");

  int rcMany = dpSetTimedWait(t1, DP + ".fVal:_original.._active", TRUE,
                          DP + ".iVal:_original.._active", TRUE);
  DebugN("  две пары rc=", rcMany, "  lastError=", getLastError());
  dpdCheck(rcMany == 0, "две пары: rc=0", rcMany);
  bool aF; bool aI;
  dpGet(DP + ".fVal:_original.._active", aF);
  dpGet(DP + ".iVal:_original.._active", aI);
  dpdCheck((aF == TRUE) && (aI == TRUE), "оба _active записаны",
           "fVal=" + aF + " iVal=" + aI);

  dyn_string names = makeDynString(DP + ".fVal:_original.._active",
                                   DP + ".iVal:_original.._active");
  dyn_anytype vals = makeDynBool(FALSE, FALSE);
  int rcArr = dpSetTimedWait(t1, names, vals);
  DebugN("  форма 2 rc=", rcArr, "  lastError=", getLastError());
  dpdCheck(rcArr == 0, "форма 2: rc=0", rcArr);
  dpGet(DP + ".fVal:_original.._active", aF);
  dpGet(DP + ".iVal:_original.._active", aI);
  dpdCheck((aF == FALSE) && (aI == FALSE), "форма 2 действительно записала оба",
           "fVal=" + aF + " iVal=" + aI);

  // -------------------------------------------------------------------
  // 8. _per_active из документации
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 8. _per_active: атрибута нет на CTL 3.18 ---");

  int paVal; int rcPa = dpGet(DP + ".fVal:_original.._per_active", paVal);
  DebugN("  чтение _original.._per_active rc=", rcPa, "  lastError=", getLastError());
  dpdCheck(rcPa == -1,
           "_per_active отсутствует - документация перечисляет несуществующий атрибут",
           rcPa);

  dropAll();
  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}
void makeType()
{
  dropAll();
  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString(DPT);        t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "fVal");  t[2] = makeDynInt(0, DPEL_FLOAT);
  n[3] = makeDynString("", "iVal");  t[3] = makeDynInt(0, DPEL_INT);
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
}

void makeDp()
{
  dpdCheck(dpCreate(DP, DPT) == 0, "точка данных создана", DP);
  dpSet(DP + ".fVal", 0.0);
  dpSet(DP + ".iVal", 0);
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