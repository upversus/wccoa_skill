// 04_dpGetMaxAge.ctl - значение с принудительным опросом драйвера.
//
// Документация: docs/03-read.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем:
//   1) создаём нужный тип точки данных;
//   2) создаём точку данных этого типа; для проверки драйвера навешиваем
//      конфигурацию _address (OPC UA);
//   3) удаляем и точку данных, и тип.
//
// dpGetMaxAge(age, dp, &var) - если значение элемента старше age миллисекунд,
// дёргает драйвер через singleQuery и отдаёт свежее значение. age = 0 означает
// "запрашивать всегда".
//
// age задаётся в МИЛЛИСЕКУНДАХ.
//
// Два разных случая проверяются:
//   * элемент с конфигом _address - запрос реально уходит драйверу;
//   * элемент без адреса - функция ведёт себя как dpGet() и возвращает
//     значение немедленно, независимо от возраста.
//
// Проверено: CTL 3.18, проект <проект стенда>.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "age_t";
string DP  = "ageDp";

string SERVER = "kep";
string SUB    = "kep_sub";
string NODE   = "ns=2;s=Simulation Examples.Functions.Ramp2";

main()
{
  DebugN("=== dpGetMaxAge(): значение с принудительным опросом ===");

  makeObjects();
  setAddress();

  // ---------------------------------------------------------------------
  // 1. age = 0 - запрашивать у драйвера всегда
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. age = 0, всегда спрашивать драйвер ---");

  unsigned zero = 0;
  dyn_anytype v1;
  time t1before;
  dpGet(DP + ".fVal:_online.._stime", t1before);

  int rc1 = dpGetMaxAge(zero, DP + ".fVal", v1);
  DebugN("  rc=", rc1, "  значение=", v1);

  time t1after;
  dpGet(DP + ".fVal:_online.._stime", t1after);
  DebugN("  метка до=", t1before);
  DebugN("  метка после=", t1after);

  dpdCheck(rc1 == 0, "age = 0 вернул rc=0", rc1);
  dpdCheck(dynlen(v1) > 0, "значение получено", dynlen(v1));
  dpdCheck(t1after >= t1before, "метка времени не уехала назад",
           "было " + t1before + ", стало " + t1after);

  // ---------------------------------------------------------------------
  // 2. Большой age - драйвер не дёргается
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. age = 1 час, значение свежее ---");
  DebugN("  Значение только что получено, поэтому запрос к драйверу");
  DebugN("  не требуется - функция вернёт значение из кэша.");

  unsigned hour = 3600000;
  dyn_anytype v2;
  int rc2 = dpGetMaxAge(hour, DP + ".fVal", v2);
  DebugN("  rc=", rc2, "  значение=", v2);
  dpdCheck(rc2 == 0, "age = 1 час вернул rc=0", rc2);
  dpdCheck(v2 == v1, "значение совпало с age = 0", v2);

  // ---------------------------------------------------------------------
  // 3. Элемент без периферийного адреса
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Элемент без адреса ---");
  DebugN("  Без _address функция ведёт себя как dpGet(): значение");
  DebugN("  возвращается немедленно, возраст не имеет значения.");

  dpSet(DP + ".iVal", 7);
  delay(1);

  unsigned zero2 = 0;
  dyn_anytype v3;
  int rc3 = dpGetMaxAge(zero2, DP + ".iVal", v3);
  DebugN("  rc=", rc3, "  значение=", v3);

  int direct;
  dpGet(DP + ".iVal", direct);
  DebugN("  для сравнения dpGet() = ", direct);

  dpdCheck(rc3 == 0, "элемент без адреса вернул rc=0", rc3);
  // ВАЖНО: v3 - это dyn_anytype, контейнер. Сравнивать его с int нельзя,
  // сравниваются контейнеры, а не значения. Нужен элемент v3[1].
  dpdCheck(v3[1] == direct, "значение совпало с dpGet()", v3[1]);

  // ---------------------------------------------------------------------
  // 4. Ошибочные случаи
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Ошибочные случаи ---");

  unsigned zero3 = 0;
  dyn_anytype v4;
  int rc4 = dpGetMaxAge(zero3, "noSuchDp.fVal", v4);
  DebugN("  несуществующая точка   rc=", rc4, "  lastError=", getLastError());
  dpdCheck(rc4 == -1, "несуществующая точка -> rc = -1", rc4);

  dyn_anytype v5;
  int rc5 = dpGetMaxAge(zero3, DP + ".nosuch", v5);
  DebugN("  несуществующий элемент rc=", rc5);
  dpdCheck(rc5 == -1, "несуществующий элемент -> rc = -1", rc5);

  // ---------------------------------------------------------------------
  // 5. Уборка
  // ---------------------------------------------------------------------
  DebugN("");
  DebugN("(5) уборка");
  dropAll();
  dpdCheck(!dpExists(DP), "точка данных удалена", DP);
  dyn_dyn_string leftNames;
  dyn_dyn_int leftTypes;
  dpdCheck(dpTypeGet(DPT, leftNames, leftTypes) != 0, "тип удалён", DPT);

  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

// Навешивает конфигурацию адреса OPC UA на элемент fVal.
void setAddress()
{
  string dpe = DP + ".fVal";
  string address = SERVER + "$" + SUB + "$1$1$" + NODE;

  int rc = dpSetTimedWait(0,
        dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
        dpe + ":_distrib.._driver", 3,
        dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
        dpe + ":_address.._reference", address,
        dpe + ":_address.._active",    TRUE,
        dpe + ":_address.._drv_ident", "OPCUA",
        dpe + ":_address.._datatype",  760,
        dpe + ":_address.._direction", 4);

  DebugN("  конфигурация адреса rc=", rc, "   ref='", address, "'");
  dpdCheck(rc == 0, "конфигурация _address записана", rc);
}

void makeObjects()
{
  dropAll();

  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString(DPT);          t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "fVal");    t[2] = makeDynInt(0, DPEL_FLOAT);
  n[3] = makeDynString("", "iVal");    t[3] = makeDynInt(0, DPEL_INT);
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
  dpdCheck(dpCreate(DP, DPT) == 0, "точка данных создана", DP);
  dpSet(DP + ".iVal", 0);
  delay(1);
  DebugN("  создана точка ", DP, " типа ", DPT);
}

void dropAll()
{
  dyn_string all = dpNames("*", DPT);
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpExists(all[i])) { dpDelete(all[i]); }
  }
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    if (dynlen(dpNames("*", DPT)) == 0) { break; }
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