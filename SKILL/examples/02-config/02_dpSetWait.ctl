// 02_dpSetWait.ctl - dpSetWait(): блокирующая запись.
//
// Документация: docs/02-config.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем: создаёт свой тип и
// свою точку данных, в конце удаляет и то, и другое.
//
// dpSetWait() отличается от dpSet() только ожиданием: функция объявлена
// Blocking, то есть ждёт ответа Event Manager. Смысл в том, что сразу после
// возврата из функции значение должно быть видно чтением - без цикла ожидания.
//
// ВАЖНО. dpSetWait() ждёт ответа Event Manager, но НЕ ждёт выполнения
// колбэков, подписанных через dpConnect() на этот атрибут.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "cfgsw_t";
string DP  = "dpdemo_cfgsw_dp";

main()
{
  DebugN("=== dpSetWait(): блокирующая запись ===");

  makeType();
  makeDp();

  // -------------------------------------------------------------------
  // 1. Значение видно сразу после возврата
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Значение видно сразу после возврата ---");

  int rc = dpSetWait(DP + ".fVal:_original.._value", 40.0);
  DebugN("  dpSetWait rc=", rc, "  lastError=", getLastError());
  dpdCheck(rc == 0, "dpSetWait rc=0", rc);

  // Читаем СРАЗУ, без delay(). Это и есть проверка блокирующего поведения.
  float fv;
  int rcGet = dpGet(DP + ".fVal:_original.._value", fv);
  DebugN("  прочитано сразу после возврата: ", fv, "  (rc чтения=", rcGet, ")");
  dpdCheck(fv == 40.0, "значение видно БЕЗ цикла ожидания", fv);

  // -------------------------------------------------------------------
  // 2. Сравнение с неблокирующим dpSet()
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Для сравнения: неблокирующий dpSet() ---");
  DebugN("  Тот же эксперимент через dpSet(). На этом стенде разницы в");
  DebugN("  скорости не видно - Event Manager отвечает быстро. Функции");
  DebugN("  различаются гарантией ожидания, а не измеримой задержкой.");

  int rcNs = dpSet(DP + ".fVal:_original.._value", 41.0);
  float fvNs;
  dpGet(DP + ".fVal:_original.._value", fvNs);
  DebugN("  dpSet rc=", rcNs, "  прочитано сразу: ", fvNs);
  dpdCheck(fvNs == 41.0, "dpSet тоже виден сразу на этом стенде", fvNs);

  // -------------------------------------------------------------------
  // 3. Несколько пар в одном вызове
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Несколько пар ---");

  int rc3 = dpSetWait(DP + ".fVal:_original.._value", 1.5,
                      DP + ".iVal:_original.._value", 2,
                      DP + ".bVal:_original.._value", TRUE);
  DebugN("  rc=", rc3, "  lastError=", getLastError());
  dpdCheck(rc3 == 0, "три пары rc=0", rc3);

  float f3; int i3; bool b3;
  dpGet(DP + ".fVal:_original.._value", f3);
  dpGet(DP + ".iVal:_original.._value", i3);
  dpGet(DP + ".bVal:_original.._value", b3);
  dpdCheck((f3 == 1.5) && (i3 == 2) && (b3 == TRUE),
           "все три значения записаны", "f=" + f3 + " i=" + i3 + " b=" + b3);

  // -------------------------------------------------------------------
  // 4. Форма 2: массивы
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Форма 2 ---");

  dyn_string names = makeDynString(DP + ".fVal:_original.._value",
                                   DP + ".iVal:_original.._value");
  dyn_anytype vals = makeDynAnytype(3.5, 11);
  int rc4 = dpSetWait(names, vals);
  DebugN("  rc=", rc4, "  lastError=", getLastError());
  dpdCheck(rc4 == 0, "форма 2 rc=0", rc4);

  float f4; int i4;
  dpGet(DP + ".fVal:_original.._value", f4);
  dpGet(DP + ".iVal:_original.._value", i4);
  dpdCheck((f4 == 3.5) && (i4 == 11), "значения из массива записаны",
           "f=" + f4 + " i=" + i4);

  // -------------------------------------------------------------------
  // 5. Создание и удаление конфига
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Конфиг через DPCONFIG_DEFAULTVALUE / DPCONFIG_NONE ---");

  int rcC = dpSetWait(DP + ".fVal:_default.._type", DPCONFIG_DEFAULTVALUE);
  dpdCheck(rcC == 0, "создание конфига rc=0", rcC);

  // Признак - _type: у _default атрибута _stime нет вовсе.
  int ty;
  dpGet(DP + ".fVal:_default.._type", ty);
  DebugN("  _default.._type после создания: ", ty,
         "  (DPCONFIG_DEFAULTVALUE = ", DPCONFIG_DEFAULTVALUE, ")");
  dpdCheck(ty == DPCONFIG_DEFAULTVALUE, "конфиг появился", ty);

  int rcD = dpSetWait(DP + ".fVal:_default.._type", DPCONFIG_NONE);
  dpdCheck(rcD == 0, "удаление конфига rc=0", rcD);

  int ty2;
  dpGet(DP + ".fVal:_default.._type", ty2);
  dpdCheck(ty2 == 0, "конфиг удалён", ty2);

  // -------------------------------------------------------------------
  // 6. Ошибочные случаи
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 6. Ошибочные случаи ---");

  int rcNo = dpSetWait("noSuchDpAtAll.fVal:_original.._value", 1.0);
  DebugN("  несуществующая точка rc=", rcNo, "  lastError=", getLastError());
  dpdCheck(rcNo == -1, "несуществующая точка -> rc = -1", rcNo);

  // Повтор атрибута в одном вызове: принимается первое значение.
  int rcRep = dpSetWait(DP + ".fVal:_original.._value", 100.0,
                        DP + ".fVal:_original.._value", 200.0);
  float fRep;
  dpGet(DP + ".fVal:_original.._value", fRep);
  DebugN("  повтор атрибута rc=", rcRep, "  значение=", fRep);
  dpdCheck(rcRep == 0, "повтор атрибута rc=0", rcRep);
  dpdCheck(fRep == 100.0, "принято ПЕРВОЕ значение", fRep);

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
  n[4] = makeDynString("", "bVal");  t[4] = makeDynInt(0, DPEL_BOOL);
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
}

void makeDp()
{
  dpdCheck(dpCreate(DP, DPT) == 0, "точка данных создана", DP);
  dpSet(DP + ".fVal", 0.0);
  dpSet(DP + ".iVal", 0);
  dpSet(DP + ".bVal", FALSE);
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