// 01_dpSet.ctl - dpSet(): запись значений, создание и удаление конфигов.
//
// Документация: docs/02-config.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем: создаёт свой тип и
// свою точку данных, в конце удаляет и то, и другое. Предустановленные точки
// проекта не затрагиваются.
//
// dpSet() - основная пишущая функция. Если атрибут не указан, по умолчанию
// пишется _original.._value.
//
// ИМЕНА ЭЛЕМЕНТОВ передаются БЕЗ завершающей точки - это установлено на стенде
// и относится ко всем сеттерам и геттерам.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "cfgs_t";
string DP  = "dpdemo_cfgs_dp";

main()
{
  DebugN("=== dpSet(): запись значений и конфигов ===");

  makeType();
  makeDp();

  // -------------------------------------------------------------------
  // 1. Запись без указания атрибута
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Атрибут не указан -> _original.._value ---");

  int rc1 = dpSet(DP + ".fVal", 40.0);
  DebugN("  dpSet(\"" + DP + ".fVal\", 40.0)  rc=", rc1, "  lastError=", getLastError());
  dpdCheck(rc1 == 0, "запись без атрибута rc=0", rc1);

  float fv;
  dpGet(DP + ".fVal:_original.._value", fv);
  DebugN("  _original.._value = ", fv);
  dpdCheck(fv == 40.0, "значение дошло до _original.._value", fv);

  // -------------------------------------------------------------------
  // 2. Явный атрибут
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Явный атрибут ---");

  int rc2 = dpSet(DP + ".iVal:_original.._value", 7);
  dpdCheck(rc2 == 0, "явный атрибут rc=0", rc2);
  int iv;
  dpGet(DP + ".iVal:_original.._value", iv);
  dpdCheck(iv == 7, "int записан", iv);

  // -------------------------------------------------------------------
  // 3. Несколько пар в одном вызове
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Несколько пар в одном вызове ---");

  int rc3 = dpSet(DP + ".fVal:_original.._value", 1.5,
                  DP + ".iVal:_original.._value", 2,
                  DP + ".bVal:_original.._value", TRUE);
  DebugN("  rc=", rc3, "  lastError=", getLastError());
  dpdCheck(rc3 == 0, "три пары одним вызовом rc=0", rc3);

  float f3; int i3; bool b3;
  dpGet(DP + ".fVal:_original.._value", f3);
  dpGet(DP + ".iVal:_original.._value", i3);
  dpGet(DP + ".bVal:_original.._value", b3);
  DebugN("  прочитано: fVal=", f3, " iVal=", i3, " bVal=", b3);
  dpdCheck((f3 == 1.5) && (i3 == 2) && (b3 == TRUE),
           "все три значения записаны", "f=" + f3 + " i=" + i3 + " b=" + b3);

  // -------------------------------------------------------------------
  // 4. Форма 2: dyn_string + dyn_anytype
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Форма 2: массивы ---");

  dyn_string names = makeDynString(DP + ".fVal:_original.._value",
                                   DP + ".iVal:_original.._value");
  dyn_anytype vals = makeDynAnytype(3.5, 11);
  int rc4 = dpSet(names, vals);
  DebugN("  dpSet(массив из 2) rc=", rc4, "  lastError=", getLastError());
  dpdCheck(rc4 == 0, "форма 2 rc=0", rc4);

  float f4; int i4;
  dpGet(DP + ".fVal:_original.._value", f4);
  dpGet(DP + ".iVal:_original.._value", i4);
  dpdCheck((f4 == 3.5) && (i4 == 11), "значения из массива записаны",
           "f=" + f4 + " i=" + i4);

  // -------------------------------------------------------------------
  // 5. Создание конфига через _type
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Создание конфига DPCONFIG_DEFAULTVALUE ---");

  // ПРИЗНАК СУЩЕСТВОВАНИЯ КОНФИГА. У _default НЕТ атрибута _stime: всего
  // четыре атрибута - _type, _value, _set_ibit, _set_pvrange. Чтение
  // _default.._stime даёт rc = -1 и не годится как признак.
  // Зато _type у _default НАДЁЖЕН: он хранит константу DPCONFIG_*.
  // Это не противоречит тому, что _type ненадёжен для _online - там он
  // бывает 0 при настроенном конфиге.
  int tyBefore;
  int rcTyB = dpGet(DP + ".fVal:_default.._type", tyBefore);
  DebugN("  до создания: _default.._type rc=", rcTyB, " значение=", tyBefore,
         "  (0 = конфига нет)");

  int rc5 = dpSet(DP + ".fVal:_default.._type", DPCONFIG_DEFAULTVALUE);
  DebugN("  dpSet(_default.._type, DPCONFIG_DEFAULTVALUE) rc=", rc5,
         "  lastError=", getLastError());
  dpdCheck(rc5 == 0, "создание конфига rc=0", rc5);

  int tyAfter;
  dpGet(DP + ".fVal:_default.._type", tyAfter);
  DebugN("  после создания: _default.._type = ", tyAfter,
         "  (DPCONFIG_DEFAULTVALUE = ", DPCONFIG_DEFAULTVALUE, ")");
  dpdCheck(tyAfter == DPCONFIG_DEFAULTVALUE,
           "_type подтверждает создание конфига", tyAfter);

  // -------------------------------------------------------------------
  // 6. Удаление конфига через DPCONFIG_NONE
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 6. Удаление конфига DPCONFIG_NONE ---");

  int rc6 = dpSet(DP + ".fVal:_default.._type", DPCONFIG_NONE);
  DebugN("  dpSet(_default.._type, DPCONFIG_NONE) rc=", rc6,
         "  lastError=", getLastError());
  dpdCheck(rc6 == 0, "удаление конфига rc=0", rc6);

  int tyGone;
  dpGet(DP + ".fVal:_default.._type", tyGone);
  DebugN("  после удаления: _default.._type = ", tyGone);
  dpdCheck(tyGone == 0, "_type подтверждает удаление конфига", tyGone);

  // -------------------------------------------------------------------
  // 7. Ошибочные случаи
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 7. Ошибочные случаи ---");

  int rcNoDp = dpSet("noSuchDpAtAll.fVal", 1.0);
  DebugN("  несуществующая точка rc=", rcNoDp, "  lastError=", getLastError());
  dpdCheck(rcNoDp == -1, "несуществующая точка -> rc = -1", rcNoDp);

  // Повтор одного атрибута в одном вызове: принимается первое значение,
  // остальные отбрасываются, возврат 0.
  int rcRep = dpSet(DP + ".fVal:_original.._value", 100.0,
                    DP + ".fVal:_original.._value", 200.0);
  float fRep;
  dpGet(DP + ".fVal:_original.._value", fRep);
  DebugN("  повтор атрибута rc=", rcRep, "  значение=", fRep);
  dpdCheck(rcRep == 0, "повтор атрибута rc=0", rcRep);
  dpdCheck(fRep == 100.0, "принято ПЕРВОЕ значение, не последнее", fRep);

  // Несовпадение длин массивов.
  dyn_string n2 = makeDynString(DP + ".fVal:_original.._value",
                                DP + ".iVal:_original.._value");
  dyn_anytype v1 = makeDynAnytype(5.0);
  int rcLen = dpSet(n2, v1);
  DebugN("  2 имени / 1 значение rc=", rcLen, "  lastError=", getLastError());
  dpdCheck(rcLen == -1, "несовпадение длин массивов -> rc = -1", rcLen);

  // -------------------------------------------------------------------
  // 8. Несоответствие типа значения
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 8. Несоответствие типа значения ---");

  // float в атрибут int: значение молча преобразуется, исключения НЕТ.
  int rcType = dpSet(DP + ".iVal:_original.._value", 3.9);
  int iConv;
  dpGet(DP + ".iVal:_original.._value", iConv);
  DebugN("  float 3.9 в int-атрибут: rc=", rcType, "  стало ", iConv);
  dpdCheck(rcType == 0, "несоответствие типа НЕ даёт ошибки", rcType);
  DebugN("  Значение преобразовалось: 3.9 -> ", iConv, " (округление вниз)");

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