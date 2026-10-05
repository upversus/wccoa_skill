// exp_modbus_sweep.ctl — какие адреса эмулятор вообще отдаёт.
//
// Установлено: адрес M.1.3.2 (Reg_2, vType 4, DataFormat 4, RegsCount 2)
// работает, новые адреса 20/22/28 из t1_mb.xml — нет, причём их описание
// почти не отличается от рабочего. Значит либо конфиг не подхватился,
// либо эмулятор отдаёт ограниченный диапазон адресов.
//
// Разворачиваем одинаковые элементы (FLOAT 566) по разным адресам и смотрим,
// какие из них приходят. Все элементы заливает один и тот же конфиг.
//
// Проверено: CTL 3.18, проект <проект стенда>.

main()
{
  DebugN("=== Сканирование адресов Modbus ===");

  int driverNumber = 2;
  string dpt    = "dpdemo_mbsweep";
  string dpName = "dpdemo_mbsweep_1";

  dyn_string old = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(old); i++) { dpDelete(old[i]); }
  dpTypeDelete(dpt);

  // Проверяем адреса: 0 (Reg из исходного конфига), 2 (Reg_2, рабочий),
  // 4 (Reg_1, рабочий как BIT) и далее пустые 6,8,10,12,14,16,18,20,22
  // CTL не принимает ни инициализацию массива списком, ни пустое объявление
  // "dyn_int x[]", поэтому адрес вычисляется арифметически по номеру элемента.
  int addrCount = 12;

  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);
  types[1] = makeDynInt(DPEL_STRUCT);
  for (int i = 1; i <= addrCount; i++)
  {
    names[i + 1] = makeDynString("", "a" + (i - 1) * 2);
    types[i + 1] = makeDynInt(0, DPEL_FLOAT);
  }

  DebugN("dpTypeCreate rc=", dpTypeCreate(names, types));
  DebugN("dpCreate rc=", dpCreate(dpName, dpt));

  for (int i = 1; i <= addrCount; i++)
  {
    dpdSet(dpName + ".a" + (i - 1) * 2, "M.1.3." + (i - 1) * 2, 566, driverNumber);
  }

  DebugN("  ждём 20 с ...");
  delay(20);

  DebugN("--- результат по адресам (FLOAT 566, FC 3) ---");
  int alive = 0;
  for (int i = 1; i <= addrCount; i++)
  {
    string el = dpName + ".a" + (i - 1) * 2;
    bool bad;
    time t;
    float v;
    dpGet(el + ":_online.._bad",   bad);
    dpGet(el + ":_online.._stime", t);
    dpGet(el + ":_online.._value", v);
    bool hasData = (t != makeTime(1970, 1, 1, 3, 0, 0));
    if (hasData) { alive++; }
    DebugN("  M.1.3.", (i - 1) * 2, "  данные=", hasData, "  bad=", bad, "  значение=", v);
  }
  DebugN("  отвечают адресов: ", alive, " из ", addrCount);

  DebugN("=== конец ===");

  dyn_string left = dpNames("*", dpt);
  for (int i = 1; i <= dynlen(left); i++) { dpDelete(left[i]); }
  dpTypeDelete(dpt);
}

void dpdSet(string dpe, string address, int datatype, int driverNumber)
{
  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", driverNumber);
  dpSetTimedWait(0,
                    dpe + ":_address.._type",      DPCONFIG_PERIPH_ADDR_MAIN,
                    dpe + ":_address.._reference", address,
                    dpe + ":_address.._active",    TRUE,
                    dpe + ":_address.._drv_ident", "MODBUS",
                    dpe + ":_address.._datatype",  datatype,
                    dpe + ":_address.._direction", DPATTR_ADDR_MODE_INPUT_POLL);
}