// probe_archive.ctl - пригодна ли предустановленная точка для архивных функций.
//
// dpGetAsynch() читает значение на момент времени из АРХИВА, а dpGetPeriod()
// отдаёт ряд значений за период. Обе работают только для архивированных точек.
//
// Нужно выяснить, есть ли в проекте точка, на которой это можно проверить
// без подготовки. Кандидат - предустановленная ExampleDP_Arg1: у неё в
// проекте есть история (её читает запрос с TIMERANGE).
//
// Проверяем наличие конфига _archive и пробуем обе функции.
// Ничего не изменяем и не удаляем: только читаем.

string HIST_DP = "ExampleDP_Arg1";

main()
{
  DebugN("=== Пригодность точки для архивных функций ===");

  // ---------------------------------------------------------------------
  // 1. Есть ли конфиг _archive
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Конфиг _archive ---");
  DebugN("  Существование конфига проверяем чтением атрибута данных:");

  time  archStime;
  int   rcStime = dpGet(HIST_DP + ".:" + "_archive.._stime", archStime);
  DebugN("  ", HIST_DP, ".:_archive.._stime  rc=", rcStime);

  bool  archActive;
  int   rcAct = dpGet(HIST_DP + ".:" + "_archive.._active", archActive);
  DebugN("  ", HIST_DP, ".:_archive.._active  rc=", rcAct, "  значение=", archActive);

  if (rcStime == 0)
  {
    DebugN("  Конфиг _archive настроен - архивные функции можно пробовать.");
  }
  else
  {
    DebugN("  Конфиг _archive НЕ настроен. Пробуем функции всё равно -");
    DebugN("  покажем, что именно они отвечают без архива.");
  }

  // ---------------------------------------------------------------------
  // 2. То же для _online - есть ли вообще значение
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Текущее значение ---");

  float cur;
  int   rcCur = dpGet(HIST_DP + ".:_online.._value", cur);
  DebugN("  ", HIST_DP, ".:_online.._value  rc=", rcCur, "  значение=", cur);

  // ---------------------------------------------------------------------
  // 3. Самый ранний момент в базе - надёжная граница окна
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Границы истории ---");
  DebugN("  Надёжный способ найти самое раннее значение: dpGet('dp.:_start.._original')");

  time startOrig;
  int rcStart = dpGet(HIST_DP + ".:" + "_start.._original", startOrig);
  DebugN("  ", HIST_DP, ".:_start.._original  rc=", rcStart, "  = ", startOrig);

  time startOnline;
  int rcStart2 = dpGet(HIST_DP + ".:" + "_start.._online", startOnline);
  DebugN("  ", HIST_DP, ".:_start.._online    rc=", rcStart2, "  = ", startOnline);

  time endOnline;
  int rcEnd = dpGet(HIST_DP + ".:" + "_end.._online", endOnline);
  DebugN("  ", HIST_DP, ".:_end.._online      rc=", rcEnd, "  = ", endOnline);

  // ---------------------------------------------------------------------
  // 4. dpGetAschutz - значение на момент времени
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. dpGetAsynch: значение на момент времени ---");

  // Берём момент из найденного окна истории.
  time probe = makeTime(2026, 10, 4, 18, 0, 0);
  DebugN("  спрашиваем значение на ", probe);

  float asynch;
  int rcAs = dpGetAsynch(HIST_DP + ".:" + "_online.._value", probe, asynch);
  DebugN("  dpGetAsynch rc=", rcAs, "  значение=", asynch);

  time asynchStime;
  int rcAsT = dpGetAsynch(HIST_DP + ".:" + "_online.._stime", probe, asynchStime);
  DebugN("  dpGetAsynch(_stime) rc=", rcAsT, "  = ", asynchStime);

  // Конфиги, которые читать нельзя - проверяем, что они и не читаются
  DebugN("  (ниже пробуем запрещённые конфиги - ожидаем отказ)");
  float fromAddr;
  int rcAddr = dpGetAsynch(HIST_DP + ".:" + "_address.._value", probe, fromAddr);
  DebugN("  _address.._value rc=", rcAddr, "   <- должен быть отказ");

  // ---------------------------------------------------------------------
  // 5. dpGetPeriod - ряд значений за период
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. dpGetPeriod: ряд значений за период ---");

  dyn_float xa;
  dyn_time  ta;
  time from = makeTime(2026, 10, 4, 18, 0, 0);
  time to   = makeTime(2026, 10, 4, 18, 30, 0);
  DebugN("  окно: ", from, " .. ", to);

  // ВНИМАНИЕ. Сигнатура в документации была указана неверно. Реальная,
  // которую сообщает сам интерпретатор:
  //   int dpGetPeriod(time t1, time t2, unsigned count, string dp1,
  //                   dyn_type1 xa1, dyn_time ta1 [...])
  // То есть сначала границы и количество, потом точка данных и массивы.
  int rcPer = dpGetPeriod(from, to, 100, HIST_DP + ".", xa, ta);
  DebugN("  dpGetPeriod rc=", rcPer);
  DebugN("  значений: ", dynlen(xa), "   меток времени: ", dynlen(ta));

  for (int i = 1; i <= dynlen(xa) && i <= 5; i++)
  {
    DebugN("    [", i, "] ", ta[i], "  = ", xa[i]);
  }
  if (dynlen(xa) > 5)
  {
    DebugN("    ...");
    DebugN("    [", dynlen(xa), "] ", ta[dynlen(xa)], "  = ", xa[dynlen(xa)]);
  }

  DebugN("");
  DebugN("=== ВЕРДИКТ ===");
  DebugN("  _archive настроен:            ", (rcStime == 0) ? "ДА" : "НЕТ");
  DebugN("  dpGetAsynch вернул значение:  ", (rcAs == 0) ? "ДА" : "НЕТ");
  DebugN("  dpGetPeriod вернул значения:  ", (dynlen(xa) > 0) ? "ДА" : "НЕТ");
  DebugN("=== конец ===");
}