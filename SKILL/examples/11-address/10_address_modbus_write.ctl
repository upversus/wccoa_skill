// 10_address_modbus_write.ctl - запись по Modbus TCP.
//
// Проверяет запись в двух адресах, добавленных специально для этого:
//     M.6.1.5  coil 5    slave 6  Valve_Cmd_Test   FC 1
//     M.6.3.3  holding 3  slave 6  Valve_Reg_Test   FC 3
// Эталонная карта в 07_address_map.ctl не затрагивается.
//
// Направления подобраны так, чтобы запись была возможна, а чтение по
// окончательному значению доказывало, что значение дошло до устройства:
//     coilCmd  DPATTR_ADDR_MODE_IO_POLL (7)   вход/выход
//     regSet   DPATTR_ADDR_MODE_IO_POLL (7)   вход/выход
//
// Направление DPATTR_ADDR_MODE_OUTPUT_SINGLE (5) не подошло: при нём драйвер
// держит значение локально и на устройство не отправляет - в журнале сервера
// запроса записи не появляется вовсе.
//
// Фактические коды функций отличаются от ожидаемых: драйвер ГРУППИРУЕТ
// записи и для одного элемента шлёт FC15 (write multiple coils), а не FC5.
// Поэтому в заголовках ниже коды указаны по факту, а не по ожиданию.
//
// Ключевая проверка: после записи coilCmd = TRUE значение держится и НЕ
// переключается. Устройство отдаёт записанное значение вместо генератора,
// поэтому постоянство и есть доказательство, что запись дошла.
//
// Для регистра подтверждение идёт по журналу сервера: он печатает каждый
// принятый запрос записи с адресом, значением и именем регистра.
//
// Проверено: CTL 3.18, проект <проект стенда>, сервер tools/modbus-sim.

int OK = 0;
int BAD = 0;

main()
{
  DebugN("=== Запись по Modbus ===");

  int driverNumber = 2;
  string dpt = "mapWriteT";
  string dp  = "mapWrite";

  // ---- свои объекты, эталон не трогаем ----
  dyn_dyn_string names;
  dyn_dyn_int types;
  names[1] = makeDynString(dpt);              types[1] = makeDynInt(DPEL_STRUCT);
  names[2] = makeDynString("", "coilCmd");     types[2] = makeDynInt(0, DPEL_BOOL);
  names[3] = makeDynString("", "regSet");      types[3] = makeDynInt(0, DPEL_INT);

  cleanUp(dp, dpt);
  int rcT = dpTypeCreate(names, types);
  int rcD = dpCreate(dp, dpt);
  DebugN("  тип ", dpt, " rc=", rcT, ", точка ", dp, " rc=", rcD);
  DebugN("  группа опроса: ", findPollGroup());

  // ---- адреса ----
  DebugN("");
  setAddr(dp + ".coilCmd", "M.6.1.5", 567, DPATTR_ADDR_MODE_IO_POLL);
  setAddr(dp + ".regSet",  "M.6.3.3", 563, DPATTR_ADDR_MODE_IO_POLL);

  delay(12);
  DebugN("");
  DebugN("--- состояние до записи ---");
  DebugN("  coilCmd = ", readBool(dp + ".coilCmd"));
  DebugN("  regSet  = ", readInt(dp + ".regSet"));

  // ------------------------------------------- запись 1: одиночный coil
  DebugN("");
  DebugN("--- запись 1: coilCmd = TRUE (ожидаем FC5, придёт FC15) ---");
  int rcW1 = dpSetTimedWait(0, dp + ".coilCmd", TRUE);
  DebugN("  dpSetTimedWait rc=", rcW1);
  check(rcW1 == 0, "запись coilCmd вернула 0");

  delay(12);
  bool afterWrite = readBool(dp + ".coilCmd");
  DebugN("  прочитано после записи: ", afterWrite);
  check(afterWrite == TRUE, "coilCmd читается как TRUE");

  // Ключевая проверка: значение держится и не переключается
  DebugN("  ждём 14 с и смотрим, держится ли значение...");
  bool stable = TRUE;
  for (int i = 1; i <= 7; i++)
  {
    delay(2);
    bool now = readBool(dp + ".coilCmd");
    if (now != afterWrite)
    {
      DebugN("    на отсчёте ", i * 2, " с значение сменилось на ", now);
      stable = FALSE;
    }
  }
  DebugN("  держится: ", stable);
  check(stable, "coilCmd держит TRUE - значение дошло до устройства");

  // --------------------------------------- запись 2: одиночный регистр
  DebugN("");
  DebugN("--- запись 2: regSet = 1234 (ожидаем FC6, придёт FC16) ---");
  int rcW2 = dpSetTimedWait(0, dp + ".regSet", 1234);
  DebugN("  dpSetTimedWait rc=", rcW2);
  check(rcW2 == 0, "запись regSet вернула 0");

  delay(6);
  int back = readInt(dp + ".regSet");
  DebugN("  прочитано обратно: ", back);
  check(back == 1234, "regSet читается как 1234");

  DebugN("");
  DebugN("=== ИТОГ: успешно ", OK, ", неудачно ", BAD, " ===");
  DebugN("");
  DebugN("Подтверждение записи в регистр смотри в журнале сервера:");
  DebugN("  tools/modbus-sim/server.log, строки с меткой [write]");
  DebugN("--- объекты оставлены в проекте ---");
}

// ============================================================ helpers

void pass(string what)      { OK++;  DebugN("  PASS  ", what); }
void fail(string what)      { BAD++; DebugN("  FAIL  ", what); }
void check(bool ok, string what)
{
  if (ok) { pass(what); } else { fail(what); }
}

void setAddr(string dpe, string address, int datatype, int direction)
{
  string pollGroup = findPollGroup();
  dpSetTimedWait(0, dpe + ":_distrib.._type",   DPCONFIG_DISTRIBUTION_INFO,
                    dpe + ":_distrib.._driver", 2);
  int rc = dpSetTimedWait(0,
                    dpe + ":_address.._type",       DPCONFIG_PERIPH_ADDR_MAIN,
                    dpe + ":_address.._reference",  address,
                    dpe + ":_address.._active",     TRUE,
                    dpe + ":_address.._drv_ident",  "MODBUS",
                    dpe + ":_address.._datatype",   datatype,
                    dpe + ":_address.._direction",  direction,
                    dpe + ":_address.._poll_group", pollGroup);

  string got;
  dpGet(dpe + ":_address.._reference", got);
  DebugN("  ", (rc == 0 && got == address) ? "ok  " : "ОШИБКА", " ", dpe,
         " -> ", got, " направление=", direction);
}

bool readBool(string dpe)
{
  bool v;
  dpGet(dpe + ":_online.._value", v);
  return v;
}

int readInt(string dpe)
{
  int v;
  dpGet(dpe + ":_online.._value", v);
  return v;
}

string findPollGroup()
{
  dyn_string all = dpNames("_**");
  for (int i = 1; i <= dynlen(all); i++)
  {
    if (dpTypeName(all[i] + ".") == "_PollGroup") { return all[i]; }
  }
  return "";
}

void cleanUp(string dp, string dpt)
{
  if (dpExists(dp)) { dpDelete(dp); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(dp)) { break; }
    delay(1);
  }
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    dyn_dyn_string pn;
    dyn_dyn_int pt;
    if (dpTypeGet(dpt, pn, pt) != 0) { break; }
    dpTypeDelete(dpt);
    delay(1);
  }
}