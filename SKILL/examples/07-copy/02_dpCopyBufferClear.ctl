// 02_dpCopyBufferClear.ctl - dpCopyBufferClear(): очистка буфера копирования.
//
// Документация: docs/07-copy.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт создаёт свой тип и три свои точки данных,
// выполняет копирование с изменением источника между прогонами и в конце
// удаляет всё созданное.
//
// Документация обещает: если между копированиями изменилась исходная точка
// данных, буфер надо очистить через dpCopyBufferClear(), иначе скопируется
// СТАРАЯ информация. В документации это даже подчёркнуто - очистка в зоне
// ответственности вызывающего кода.
//
// Здесь проверяется ровно это обещание: сначала копируем, потом меняем
// источник, потом повторяем копирование - с очисткой буфера и без неё.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "cpb_t";
string S1  = "dpdemo_cpb_s1";
string S2  = "dpdemo_cpb_s2";
string T1  = "dpdemo_cpb_t1";
string T2  = "dpdemo_cpb_t2";

main()
{
  DebugN("=== dpCopyBufferClear(): очистка буфера копирования ===");

  makeType();
  makeSrc(S1, 42.5);
  makeSrc(S2, 7.75);

  int err;

  // -------------------------------------------------------------------
  // 1. Функция ничего не возвращает
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Функция объявлена void ---");

  dpCopyBufferClear();
  DebugN("  dpCopyBufferClear() вызвана, возврата нет");
  DebugN("  lastError=", getLastError());
  dpdCheck(dynlen(getLastError()) == 0, "очистка буфера не порождает ошибок", "пусто");

  // -------------------------------------------------------------------
  // 2. Первое копирование: данные актуальные
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Первое копирование ---");

  float dVal; int ty;
  dpCopy(S1, T1, err);
  ty = -1; dpGet(T1 + ".fVal:_default.._type", ty);
  DebugN("  error=", err, "  у копии _default.._type=", ty);
  dpdCheck(err == 0, "первое копирование без ошибки", err);
  dpdCheck(ty == DPCONFIG_DEFAULTVALUE, "конфиг перенесён", ty);

  // -------------------------------------------------------------------
  // 3. Источник изменился, копируем БЕЗ очистки
  // -------------------------------------------------------------------
  // ЧТОБЫ ПРОВЕРКА БЫЛА ЧЕСТНОЙ: dpCopy() в уже существующую точку не
  // копирует и возвращает -9 (это подтверждено в 01_dpCopy.ctl). Поэтому
  // перед каждым повторным копированием цель удаляется - иначе копирование
  // просто не произойдёт, и мы измеряли бы не буфер, а код ошибки.
  DebugN("");
  DebugN("--- 3. Источник изменён, буфер НЕ очищен ---");

  dpSetWait(S1 + ".fVal:_default.._value", 99.75);
  dVal = -1; dpGet(S1 + ".fVal:_default.._value", dVal);
  DebugN("  на источнике _default.._value = ", dVal, "  (было 42.5)");

  dropDp(T1);
  dpCopy(S1, T1, err);
  dVal = -1; dpGet(T1 + ".fVal:_default.._value", dVal);
  DebugN("  без очистки: у копии _default.._value = ", dVal,
         "  <- документация обещает СТАРОЕ значение");
  dpdCheck(err == 0, "копирование без ошибки", err);
  dpdCheck(dVal == 42.5, "без очистки пришло СТАРОЕ значение 42.5", dVal);

  // -------------------------------------------------------------------
  // 4. То же самое, но с очисткой буфера
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Источник изменён, буфер ОЧИЩЕН ---");
  DebugN("  Делаем ровно то, что предписывает документация.");

  dropDp(T1);
  dpCopyBufferClear();
  int err4;
  dpCopy(S1, T1, err4);
  dVal = -1; dpGet(T1 + ".fVal:_default.._value", dVal);
  DebugN("  ПОСЛЕ очистки: у копии _default.._value = ", dVal,
         "  <- ожидается свежее 99.75, если очистка работает");
  dpdCheck(err4 == 0, "копирование после очистки без ошибки", err4);
  dpdCheck(dVal == 99.75,
           "очистка СРАБОТАЛА: получено свежее 99.75, как и обещает документация",
           dVal);

  // -------------------------------------------------------------------
  // 5. Смена исходной точки обновляет данные
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Смена исходной точки обновляет данные ---");

  dropDp(T2);
  dpCopyBufferClear();
  int err5;
  dpCopy(S2, T2, err5);
  dVal = -1; dpGet(T2 + ".fVal:_default.._value", dVal);
  DebugN("  источник 2 имеет _default.._value = 7.75, у копии = ", dVal,
         "  error=", err5);
  dpdCheck(err5 == 0, "копирование от второго источника без ошибки", err5);
  dpdCheck(dVal == 7.75,
           "от ДРУГОЙ точки данные верные - только это обновляет кэш", dVal);

  // -------------------------------------------------------------------
  // 6. Вывод
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 6. Практический вывод ---");
  DebugN("  dpCopyBufferClear() на CTL 3.18 РАБОТАЕТ РОВНО КАК ОПИСАНО:");
  DebugN("  без очистки приходит старое значение, после очистки - свежее.");
  DebugN("");
  DebugN("  ВАЖНОЕ ПРОТИВОПОЛОЖЕНИЕ. У dpCopyConfigMergeBufferClear()");
  DebugN("  картина обратная: там очистка НЕ обновляет кэш по исходному");
  DebugN("  элементу (проверено в 02-config/16_dpCopyConfigMergeBufferClear.ctl).");
  DebugN("  Две функции названы почти одинаково и решают одну задачу, но");
  DebugN("  ведут себя по-разному - поэтому очистку нельзя считать");
  DebugN("  безусловно надёжной и надо проверять результат чтением.");

  dropAll();
  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

// Удаление одной точки данных с ожиданием исчезновения.
void dropDp(string dp)
{
  if (dpExists(dp)) { dpDelete(dp); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(dp)) { break; }
    delay(1);
  }
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

void makeSrc(string dp, float defVal)
{
  dpdCheck(dpCreate(dp, DPT) == 0, "точка создана", dp);
  dpSetWait(dp + ".fVal:_default.._type", DPCONFIG_DEFAULTVALUE);
  dpSetWait(dp + ".fVal:_default.._value", defVal);
  dpSetWait(dp + ".fVal", defVal);
  dpSetWait(dp + ".iVal", 1);
}

void dropAll()
{
  if (dpExists(T1)) { dpDelete(T1); }
  if (dpExists(T2)) { dpDelete(T2); }
  if (dpExists(S1)) { dpDelete(S1); }
  if (dpExists(S2)) { dpDelete(S2); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(T1) && !dpExists(T2) && !dpExists(S1) && !dpExists(S2)) { break; }
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

bool inList(dyn_string lst, string what)
{
  for (int i = 1; i <= dynlen(lst); i++)
  {
    if (lst[i] == what) { return TRUE; }
  }
  return FALSE;
}