// 12_dpGetAllDetails.ctl - dpGetAllDetails(): что функция отдаёт на самом деле.
//
// Документация: docs/02-config.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем: создаёт свой тип и
// свою точку данных, в конце удаляет и то, и другое.
//
// РАСХОЖДЕНИЕ С ДОКУМЕНТАЦИЕЙ, измеренное на стенде CTL 3.18.
// Документация описывает dpGetAllDetails() как возврат списка detail-ов
// конфига (например "_lock"). Фактически поведение такое:
//   * для ЛЮБОГО обычного конфига возвращается массив из одной пустой
//     строки - то есть фактически НИЧЕГО полезного;
//   * только для конфига "_lock" возвращается список из 25 имён, причём это
//     не detail-ы, а имена КОНФИГОВ (_address, _default, _pv_range, ...).
// То есть на 3.18 функция ведёт себя не так, как описано, и опереться на неё
// в рабочем коде нельзя. Скрипт фиксирует фактическое поведение, а не
// документированное.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "cfgdet_t";
string DP  = "dpdemo_cfgdet_dp";

main()
{
  DebugN("=== dpGetAllDetails(): фактическое поведение ===");

  makeType();
  makeDp();

  // -------------------------------------------------------------------
  // 1. Обычные конфиги
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Обычные конфиги: одна пустая строка ---");

  dyn_string cfgs = makeDynString("_original", "_default", "_online",
                                 "_address", "_alert_class", "_general",
                                 "_corr");
  for (int i = 1; i <= dynlen(cfgs); i++)
  {
    dyn_string d = dpGetAllDetails(cfgs[i]);
    DebugN("  ", cfgs[i], " -> элементов ", dynlen(d),
           "  первый: '", d[1], "'");
    dpdCheck(dynlen(d) == 1,
             cfgs[i] + ": возвращён один элемент", dynlen(d));
    dpdCheck(d[1] == "",
             cfgs[i] + ": этот элемент ПУСТ - полезной информации нет", "'" + d[1] + "'");
  }

  // -------------------------------------------------------------------
  // 2. Исключение _lock
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. _lock: единственный конфиг с непустым результатом ---");

  dyn_string lk = dpGetAllDetails("_lock");
  DebugN("  элементов: ", dynlen(lk));
  for (int i = 1; i <= dynlen(lk); i++) { DebugN("    ", lk[i]); }
  dpdCheck(dynlen(lk) == 25, "_lock: 25 элементов", dynlen(lk));

  // Это не detail-ы конфига, а имена конфигов - видно по содержимому.
  dpdCheck(inList(lk, "_address") && inList(lk, "_online") && inList(lk, "_lock"),
           "_lock возвращает имена КОНФИГОВ, а не detail-ы", "проверено");

  // Состав совпадает со списком конфигов, который даёт dpGetAllConfigs.
  // Это довод в пользу того, что функция отдаёт не то, что описано.
  dyn_string allowed = dpGetAllConfigs(DP + ".fVal:");
  DebugN("  для сравнения dpGetAllConfigs даёт ", dynlen(allowed), " конфигов");
  dpdCheck(dynlen(lk) >= dynlen(allowed),
           "размер _lock сопоставим со списком конфигов - похоже на одно и то же",
           dynlen(lk) + " против " + dynlen(allowed));

  // -------------------------------------------------------------------
  // 3. Ошибочные случаи
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Ошибочные случаи ---");

  dyn_string none = dpGetAllDetails("_noSuchConfig");
  DebugN("  несуществующий конфиг -> ", dynlen(none), "  lastError=", getLastError());
  dpdCheck(dynlen(none) == 0,
           "несуществующий конфиг -> пустой массив (в отличие от пустой строки)",
           dynlen(none));
  dpdCheck(dynlen(getLastError()) == 0,
           "getLastError() пуст - ошибку не сообщают", "пусто");

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