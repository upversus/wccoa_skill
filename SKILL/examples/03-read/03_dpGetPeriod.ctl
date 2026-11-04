// 03_dpGetPeriod.ctl - ряд значений из архива за интервал.
//
// Документация: docs/03-read.md#dpgetperiod
// Проверено: CTL 3.18, проект <проект стенда>
//
// ПРОТОКОЛ ПРОВЕРКИ. Пример работает с предустановленной демонстрационной
// точкой ExampleDP_Arg1, у которой включён конфиг _archive и ведётся история.
//
// ВАЖНО, ЧЕМ ЭТО ОТЛИЧАЕТСЯ ОТ ОСТАЛЬНЫХ ПРИМЕРОВ:
//   * скрипт ПИШЕТ в точку проекта - пять своих значений через dpSet();
//   * исходное значение в конце восстанавливается;
//   * записи в истории остаются навсегда: убрать их из архива нельзя.
//   * точка может быть эталоном Modbus и опрашиваться драйвером. Тогда в
//     окне будут и его значения: проверки требуют, чтобы наши пять нашлись,
//     а не чтобы окно было свободно от чужих записей.
// Свою точку с историей здесь не создать: конфиг _archive принадлежит
// архивному менеджеру, и простым dpSet его не включить (проверено: dpSet
// возвращает 0, а значения не архивируются).
//
// ЧТО ПРОВЕРЯЕТСЯ.
//   1. Наличие архива: dpGet("...:_archive.._archive", anytype) -> TRUE.
//      Без архива функция вернёт rc=0 и НОЛЬ значений - rc=0 значит
//      "ошибки нет", а не "данные есть". Это проверено на своей точке
//      без _archive (см. блок 8).
//   2. Записанные значения действительно читаются за окно [tStart, tEnd].
//   3. count добавляет значения ДО t1 и ПОСЛЕ t2, а не ограничивает общее
//      число. Проверяется на узком окне в два значения.
//   4. Ряд отсортирован по времени источника, длины xa и ta равны.
//
// dpGetPeriod(t1, t2, count, dp1, xa1, ta1):
//   * берёт ВСЕ значения атрибута за интервал [t1, t2];
//   * плюс до count значений ДО t1 и до count ПОСЛЕ t2.
//
// Время локальное. Массивы переинициализируются при каждом вызове.
// dyn_anytype использовать нельзя - нужен конкретный dyn_*.
//
// Ожидаемая сводка: --- PASS= 33  FAIL= 0 ---

int dpdPass = 0;
int dpdFail = 0;

string HIST_DP = "ExampleDP_Arg1";

// Пять значений, которые пишем в точку. Дробные .5 представимы точно,
// поэтому их можно сравнивать без допуска - но сравниваем через closeEnough(),
// чтобы пример не зависел от этого свойства.
dyn_float TEST_VALUES = makeDynFloat(111.5, 222.5, 333.5, 444.5, 555.5);

// Своя точка без архива - для проверки обязательного условия.
string NOARCH_DPT = "period_probe_t";
string NOARCH_DP  = "dpdemo_period_probe";

main()
{
  DebugN("=== dpGetPeriod(): ряд значений за интервал ===");
  DebugN("  точка: ", HIST_DP, " (пишем 5 значений, исходное восстановим)");

  // ---------------------------------------------------------------------
  // 1. Точка и её архив
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Конфиг _archive ---");

  dpdCheck(dpExists(HIST_DP), "точка существует", HIST_DP);

  anytype av;
  int rcA = dpGet(HIST_DP + ".:_archive.._archive", av);
  DebugN("  anytype ", HIST_DP, ".:_archive.._archive  rc=", rcA, "  val=", av);
  dpdCheck(rcA == 0, "_archive.._archive читается через dpGet", rcA);
  // TRUE - история ведётся; FALSE (в anytype приходит 0) - нет.
  dpdCheck(av == true, "_archive включён: история ведётся", av);

  // То же самое в bool - рабочий вариант, если anytype неудобен.
  bool bArch = false;
  int rcB = dpGet(HIST_DP + ".:_archive.._archive", bArch);
  DebugN("  bool    ", HIST_DP, ".:_archive.._archive  rc=", rcB, "  val=", bArch);
  dpdCheck(rcB == 0 && bArch == true, "то же в bool", bArch);

  // ---------------------------------------------------------------------
  // 2. Исходное значение - его восстановим в конце
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Исходное значение ---");

  float fOrig = 0.0;
  int rcOrig = dpGet(HIST_DP + ".:_original.._value", fOrig);
  DebugN("  ", HIST_DP, ".:_original.._value  rc=", rcOrig, "  = ", fOrig);
  dpdCheck(rcOrig == 0, "исходное значение прочитано", fOrig);

  // ---------------------------------------------------------------------
  // 3. Пишем пять значений
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Пишем 5 значений с шагом 1 с ---");

  time tStart = getCurrentTime();
  int written = 0;
  for (int i = 1; i <= dynlen(TEST_VALUES); i++)
  {
    int rcw = dpSet(HIST_DP + ".:_original.._value", TEST_VALUES[i]);
    if (rcw == 0) { written++; }
    DebugN("  dpSet ", TEST_VALUES[i], "  rc=", rcw);
    delay(1);
  }
  dpdCheck(written == dynlen(TEST_VALUES),
           "записаны все значения", written + " из " + dynlen(TEST_VALUES));

  // Архивирование асинхронное: без паузы запрос может не увидеть последние
  // записи. tEnd берём ПОСЛЕ паузы, иначе метка времени записи может оказаться
  // чуть позже границы окна.
  DebugN("  ждём архивирования: 5 с");
  delay(5);
  time tEnd = getCurrentTime();

  // ---------------------------------------------------------------------
  // 4. Ряд за окно записей
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. dpGetPeriod за окно записей ---");
  DebugN("  окно ", tStart, " .. ", tEnd, "   count = 0");

  dyn_float xa;
  dyn_time  ta;
  int rc = dpGetPeriod(tStart, tEnd, 0, HIST_DP + ".", xa, ta);

  DebugN("  rc=", rc, "  значений: ", dynlen(xa), "  меток: ", dynlen(ta));
  dpdCheck(rc == 0, "dpGetPeriod вернул rc=0", rc);
  dpdCheck(dynlen(xa) == dynlen(ta), "длины xa и ta равны",
           dynlen(xa) + " / " + dynlen(ta));
  // Именно "не меньше", а не "ровно": ExampleDP_Arg1 на многих стендах -
  // эталон Modbus, и драйвер может писать в неё параллельно. Тогда в окне
  // окажутся ещё и его значения; наши от этого не пропадают.
  dpdCheck(dynlen(xa) >= dynlen(TEST_VALUES),
           "в окне не меньше пяти значений", dynlen(xa));

  // Все пять значений должны найтись в ряду.
  int found = 0;
  for (int i = 1; i <= dynlen(TEST_VALUES); i++)
  {
    for (int j = 1; j <= dynlen(xa); j++)
    {
      if (closeEnough(xa[j], TEST_VALUES[i])) { found++; break; }
    }
  }
  dpdCheck(found == dynlen(TEST_VALUES), "все записанные значения вернулись", found);

  // И все метки - внутри окна.
  int inside = 0;
  for (int i = 1; i <= dynlen(ta); i++)
  {
    if (ta[i] >= tStart && ta[i] <= tEnd) { inside++; }
  }
  dpdCheck(inside == dynlen(ta), "все метки внутри окна", inside);

  // ---------------------------------------------------------------------
  // 5. Порядок по времени
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Значения отсортированы по времени ---");

  int unsorted = 0;
  for (int i = 2; i <= dynlen(ta); i++)
  {
    if (ta[i] < ta[i - 1]) { unsorted++; }
  }
  DebugN("  пар, нарушающих порядок: ", unsorted);
  dpdCheck(unsorted == 0, "ряд отсортирован по времени источника", unsorted);

  if (dynlen(xa) > 0)
  {
    DebugN("  первая:    ", ta[1], "  = ", xa[1]);
    DebugN("  последняя: ", ta[dynlen(xa)], "  = ", xa[dynlen(xa)]);
  }

  // ---------------------------------------------------------------------
  // 6. count добавляет соседей, а не ограничивает выборку
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 6. count: узкое окно в два значения ---");

  time tw1 = 0;
  time tw2 = 0;
  for (int i = 1; i <= dynlen(xa); i++)
  {
    if (tw1 == 0 && closeEnough(xa[i], TEST_VALUES[2])) { tw1 = ta[i]; }
    if (tw2 == 0 && closeEnough(xa[i], TEST_VALUES[3])) { tw2 = ta[i]; }
  }
  DebugN("  окно между 2-м и 3-м значением: ", tw1, " .. ", tw2);

  dyn_float xc0;
  dyn_time  tc0;
  int rcC0 = dpGetPeriod(tw1, tw2, 0, HIST_DP + ".", xc0, tc0);
  DebugN("  count = 0  -> значений: ", dynlen(xc0));
  dpdCheck(rcC0 == 0, "вызов с count = 0 отработал", rcC0);
  dpdCheck(dynlen(xc0) >= 2, "в узком окне оба наших значения", dynlen(xc0));

  dyn_float xc2;
  dyn_time  tc2;
  int rcC2 = dpGetPeriod(tw1, tw2, 2, HIST_DP + ".", xc2, tc2);
  DebugN("  count = 2  -> значений: ", dynlen(xc2));
  dpdCheck(rcC2 == 0, "вызов с count = 2 отработал", rcC2);

  int inWin = 0;
  int outWin = 0;
  for (int i = 1; i <= dynlen(tc2); i++)
  {
    if (tc2[i] >= tw1 && tc2[i] <= tw2) { inWin++; } else { outWin++; }
  }
  DebugN("  внутри окна: ", inWin, "   вне окна: ", outWin);
  dpdCheck(inWin >= 2, "наши значения остались внутри окна", inWin);
  dpdCheck(outWin > 0, "count добавил значения вне окна", outWin);
  dpdCheck(dynlen(xc2) > dynlen(xc0), "count расширяет выборку",
           dynlen(xc0) + " -> " + dynlen(xc2));
  // До 2 значений слева + до 2 справа, плюс 2 внутри окна.
  dpdCheck(dynlen(xc2) <= dynlen(xc0) + 4, "count добавляет не больше 2 + 2",
           dynlen(xc2));

  // ---------------------------------------------------------------------
  // 7. Ошибочные случаи
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 7. Ошибочные случаи ---");

  dyn_float xAddr;
  dyn_time  tAddr;
  int rcAddr = dpGetPeriod(tStart, tEnd, 1, HIST_DP + ".:" + "_address.._value",
                           xAddr, tAddr);
  DebugN("  _address.._value  rc=", rcAddr);
  dpdCheck(rcAddr == -1, "_address отвергнут", rcAddr);

  dyn_float xBad;
  dyn_time  tBad;
  int rcBad = dpGetPeriod(tStart, tEnd, 5, "noSuchDp.", xBad, tBad);
  DebugN("  несуществующая точка  rc=", rcBad, "  значений: ", dynlen(xBad));
  dpdCheck(rcBad == -1, "несуществующая точка -> rc = -1", rcBad);

  time past = makeTime(1990, 1, 1, 0, 0, 0);
  dyn_float xFar;
  dyn_time  tFar;
  int rcFar = dpGetPeriod(past, past, 0, HIST_DP + ".", xFar, tFar);
  DebugN("  окно до данных  rc=", rcFar, "  значений: ", dynlen(xFar));
  dpdCheck(rcFar == 0, "окно до данных: ошибки нет", rcFar);
  dpdCheck(dynlen(xFar) == 0, "окно до данных: значений нет", dynlen(xFar));

  // ---------------------------------------------------------------------
  // 8. Обязательное условие: точка БЕЗ _archive
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 8. Своя точка без _archive: значений не будет ---");

  makeNoArchDp();

  bool bNo = true;
  int rcNo = dpGet(NOARCH_DP + ".:_archive.._archive", bNo);
  DebugN("  ", NOARCH_DP, ".:_archive.._archive  rc=", rcNo, "  val=", bNo);
  dpdCheck(rcNo == 0 && bNo == false, "у новой точки архива нет", bNo);

  time nStart = getCurrentTime();
  int rcNoWrite = dpSet(NOARCH_DP + ".value:_original.._value", 7.5);
  DebugN("  dpSet 7.5  rc=", rcNoWrite);
  dpdCheck(rcNoWrite == 0, "запись в точку без архива проходит", rcNoWrite);

  delay(3);
  time nEnd = getCurrentTime();

  dyn_float xn;
  dyn_time  tn;
  int rcN = dpGetPeriod(nStart, nEnd, 0, NOARCH_DP + ".", xn, tn);
  DebugN("  dpGetPeriod  rc=", rcN, "  значений: ", dynlen(xn));
  dpdCheck(rcN == 0, "без архива ошибки нет - rc=0", rcN);
  dpdCheck(dynlen(xn) == 0, "без архива значений 0 - вот и обязательное условие",
           dynlen(xn));

  dropNoArchDp();

  // ---------------------------------------------------------------------
  // 9. Возврат исходного значения
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 9. Возврат исходного значения ---");

  int rcRestore = dpSet(HIST_DP + ".:_original.._value", fOrig);
  DebugN("  dpSet ", fOrig, "  rc=", rcRestore);
  delay(1);

  float fBack = 0.0;
  int rcBack = dpGet(HIST_DP + ".:_original.._value", fBack);
  DebugN("  обратно прочитано: rc=", rcBack, "  = ", fBack);
  dpdCheck(rcRestore == 0, "исходное значение записано обратно", rcRestore);
  dpdCheck(rcBack == 0 && closeEnough(fBack, fOrig),
           "значение точки восстановлено", fBack);

  dpdSummary();
  DebugN("  Записи в истории остались: удалить их из архива нельзя.");
  DebugN("=== конец ===");
}

// ---------------------------------------------------------------------------
// Точка без конфига _archive. Нужна, чтобы проверить утверждение
// "конфиг _archive обязателен": без него dpGetPeriod вернёт 0 значений.
// ---------------------------------------------------------------------------
void makeNoArchDp()
{
  dyn_dyn_string probeNames;
  dyn_dyn_int    probeTypes;
  if (dpTypeGet(NOARCH_DPT, probeNames, probeTypes) != 0)
  {
    dyn_dyn_string n;
    dyn_dyn_int t;
    n[1] = makeDynString(NOARCH_DPT);          t[1] = makeDynInt(DPEL_STRUCT);
    n[2] = makeDynString("", "value");         t[2] = makeDynInt(0, DPEL_FLOAT);
    dpdCheck(dpTypeCreate(n, t) == 0, "тип без архива создан", NOARCH_DPT);
  }
  if (dpExists(NOARCH_DP)) { dpDelete(NOARCH_DP); }
  dpdCheck(dpCreate(NOARCH_DP, NOARCH_DPT) == 0, "точка без архива создана",
           NOARCH_DP);
}

void dropNoArchDp()
{
  if (dpExists(NOARCH_DP))
  {
    dpdCheck(dpDelete(NOARCH_DP) == 0, "точка без архива удалена", NOARCH_DP);
  }
  dpdCheck(dpTypeDelete(NOARCH_DPT) == 0, "тип без архива удалён", NOARCH_DPT);
}

// Сравнение float только с допуском: значение в FLOAT может лечь приблизительно.
bool closeEnough(float a, float b)
{
  float d = a - b;
  if (d < 0) { d = -d; }
  return d < 0.001;
}

// ---------------------------------------------------------------------------
// Самодостаточный блок проверки - копия из examples/_lib.ctl: демо-скрипты
// не подключают библиотек, чтобы куски кода работали в скилле без зависимостей.
// ---------------------------------------------------------------------------
void dpdCheck(bool ok, string what, dyn_anytype extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra, "  lastError=", getLastError()); }
}

void dpdSummary()
{
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
}
