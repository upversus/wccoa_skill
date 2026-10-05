// probe_period.ctl - что значат параметры dpGetPeriod().
//
// Реальная сигнатура, сообщённая интерпретатором:
//   int dpGetPeriod(time t1, time t2, unsigned count, string dp1,
//                   dyn_type1 xa1, dyn_time ta1 [...])
//
// Настоящий пробник выясняет, что делает каждый параметр: границы окна,
// количество значений или что-то ещё. Меняем их по одному и смотрим,
// что происходит с возвращённым рядом.

string HIST_DP = "ExampleDP_Arg1";

main()
{
  DebugN("=== Смысл параметров dpGetPeriod ===");

  DebugN("");
  DebugN("--- 1. Разные окна при count = 20 ---");
  probe("окно 2 минуты,  14:20..14:22", makeTime(2026, 10, 4, 14, 20, 0), makeTime(2026, 10, 4, 14, 22, 0), 20);
  probe("окно 2 часа,    14:00..16:00", makeTime(2026, 10, 4, 14,  0, 0), makeTime(2026, 10, 4, 16,  0, 0), 20);
  probe("окно 5 минут,   20:00..20:05", makeTime(2026, 10, 4, 20,  0, 0), makeTime(2026, 10, 4, 20,  5, 0), 20);

  DebugN("");
  DebugN("--- 2. Разное количество при одном окне ---");
  probe("count = 3,  окно 14:20..14:30", makeTime(2026, 10, 4, 14, 20, 0), makeTime(2026, 10, 4, 14, 30, 0), 3);
  probe("count = 50, окно 14:20..14:30", makeTime(2026, 10, 4, 14, 20, 0), makeTime(2026, 10, 4, 14, 30, 0), 50);

  DebugN("");
  DebugN("--- 3. Совпадающие границы ---");
  probe("t1 == t2, 18:00", makeTime(2026, 10, 4, 18, 0, 0), makeTime(2026, 10, 4, 18, 0, 0), 10);
  probe("t2 < t1, 20:00..19:00", makeTime(2026, 10, 4, 20, 0, 0), makeTime(2026, 10, 4, 19, 0, 0), 10);

  DebugN("");
  DebugN("--- 4. Границы за пределами данных ---");
  probe("окно до данных, 2020", makeTime(2020, 1, 1, 0, 0, 0), makeTime(2020, 1, 1, 1, 0, 0), 10);
  probe("окно после данных, 2030", makeTime(2030, 1, 1, 0, 0, 0), makeTime(2030, 1, 1, 1, 0, 0), 10);

  DebugN("=== конец ===");
}

// Печатает первый и последний элемент возвращённого ряда.
void probe(string what, time t1, time t2, int count)
{
  dyn_float xa;
  dyn_time  ta;

  int rc = dpGetPeriod(t1, t2, count, HIST_DP + ".", xa, ta);

  DebugN("  ", what);
  DebugN("     rc=", rc, "  значений: ", dynlen(xa), "  меток: ", dynlen(ta));
  if (dynlen(xa) > 0)
  {
    DebugN("     первая: ", ta[1], "  = ", xa[1]);
    DebugN("     последняя: ", ta[dynlen(xa)], "  = ", xa[dynlen(xa)]);
  }
}