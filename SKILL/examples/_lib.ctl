// _lib.ctl — общие помощники для демонстрационных скриптов точки данных.
//
// ЭТОТ ФАЙЛ НЕ ЗАПУСКАЕТСЯ САМ ПО СЕБЕ.
//
// Примеры в examples/** намеренно сделаны самодостаточными: каждый .ctl содержит
// свою копию блока помощников в конце файла. Причина — демо-скрипты потом
// превращаются в скилл, а куски кода в скилле должны работать без зависимостей.
// Этот файл — эталон этого блока и место для новых помощников.

#define DPD_PASSED "  PASS  "
#define DPD_FAILED "  FAIL  "

// ---------------------------------------------------------------------------
// Счётчики результатов
// ---------------------------------------------------------------------------
int dpdPass = 0;
int dpdFail = 0;

// ---------------------------------------------------------------------------
// Печать заголовка блока проверки
// ---------------------------------------------------------------------------
void dpdHeader(string fn, string synopsis)
{
  DebugN("=== ", fn, " ===  ", synopsis);
}

// ---------------------------------------------------------------------------
// Проверка с автоматической фиксацией результата.
//
// ВАЖНО: getLastError() возвращает ошибки ПОСЛЕДНЕГО вызова. Поэтому его нужно
// читать сразу же после проверяемой функции, иначе он покажет ошибку от
// чего-то другого. Здесь мы читаем его ДО вызова chk() — порядок в вызывающем
// коде должен быть таким же.
// ---------------------------------------------------------------------------
void dpdCheck(string what, bool ok)
{
  if (ok)
  {
    dpdPass++;
    DebugN(DPD_PASSED, what);
  }
  else
  {
    dpdFail++;
    DebugN(DPD_FAILED, what, "  lastError=", getLastError());
  }
}

// ---------------------------------------------------------------------------
// Проверка кода возврата вида 0 / -1
// ---------------------------------------------------------------------------
void dpdCheckRc(string what, int rc)
{
  if (rc == 0)
  {
    dpdPass++;
    DebugN(DPD_PASSED, what, "  rc=0");
  }
  else
  {
    dpdFail++;
    DebugN(DPD_FAILED, what, "  rc=", rc, "  lastError=", getLastError());
  }
}

// ---------------------------------------------------------------------------
// Итог блока проверки
// ---------------------------------------------------------------------------
void dpdSummary()
{
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
}

// ---------------------------------------------------------------------------
// Выбор существующего типа точки данных для примеров.
//
// dpCreate() требует готовый DPT. Чтобы примеры не зависели от того, какие типы
// есть в конкретном проекте, тип подбирается автоматически: берётся первый DPT,
// у которого есть хотя бы одна точка данных.
//
// Возвращает "" если подходящего типа нет.
// ---------------------------------------------------------------------------
string dpdPickType()
{
  dyn_string types = dpTypes("*");
  for (int i = 1; i <= dynlen(types); i++)
  {
    dyn_string names = dpNames("*", types[i]);
    if (dynlen(names) > 0)
    {
      return types[i];
    }
  }
  return "";
}

// ---------------------------------------------------------------------------
// Создание точки данных, если её ещё нет.
//
// dpCreate() может вернуть 0 и при этом НЕ создать точку данных (например, из-за
// совпадения имён). Поэтому единственная надёжная проверка — dpExists().
//
// Имя:  "dpdemo_" + <тип> + "_" + <что угодно> — заведомо уникальное.
bool dpdEnsureDp(string dpName, string dpt)
{
  if (dpExists(dpName))
  {
    return true;
  }
  int rc = dpCreate(dpName, dpt);
  if (rc != 0)
  {
    return false;
  }
  return dpExists(dpName);
}

// ---------------------------------------------------------------------------
// Удаление точки данных, если она есть. Используется в teardown.
// ---------------------------------------------------------------------------
void dpdDropDp(string dpName)
{
  if (dpExists(dpName))
  {
    int rc = dpDelete(dpName);
    DebugN("  teardown: dpDelete(", dpName, ") rc=", rc);
  }
}

// ---------------------------------------------------------------------------
// Помощники тревог (раздел 08).
//
// Каждый пример раздела 08 — самодостаточен и содержит свою копию этого блока
// в конце файла. Здесь они лежат как эталон: новое поведение правится здесь,
// затем копируется в примеры.
//
// Точка: тип ExampleDP_DDE, элемент b1. dpCreate() получает имя БЕЗ точки.
// ---------------------------------------------------------------------------
#define ALERT_DEMO_CLASS "System1:alert."
#define ALERT_DEMO_TYPE  "ExampleDP_DDE"
#define ALERT_DEMO_CONN  ".b1:_alert_hdl.."

// Создаёт временную точку base и настраивает _alert_hdl на элементе b1.
// Возвращает DPE (base + ".b1") или "" при ошибке. Точка создаётся с
// активным _alert_hdl, значение _original сброшено в FALSE.
string alertDemoCreate(string base)
{
  string dpe = base + ".b1";
  if (dpExists(base))
  {
    dpSet(dpe + ":_alert_hdl.._active", FALSE);
    delay(1);
    dpDelete(base);
  }

  if (dpCreate(base, ALERT_DEMO_TYPE) != 0 || !dpExists(base))
  {
    return "";
  }

  dpSetWait(dpe + ":_original.._value", FALSE);
  int rcCfg = dpSetTimedWait(0,
      dpe + ":_alert_hdl.._active",   FALSE,
      dpe + ":_alert_hdl.._type",     DPCONFIG_ALERT_BINARYSIGNAL,
      dpe + ":_alert_hdl.._class",    ALERT_DEMO_CLASS,
      dpe + ":_alert_hdl.._text0",    "OK",
      dpe + ":_alert_hdl.._text1",    "ALARM",
      dpe + ":_alert_hdl.._orig_hdl", TRUE);
  if (rcCfg != 0)
  {
    return "";
  }

  if (dpSetTimedWait(0, dpe + ":_alert_hdl.._active", TRUE) != 0)
  {
    return "";
  }
  return dpe;
}

// Записывает «плохое» значение и ждёт появления тревоги (до 10 с).
bool alertDemoCame(string dpe)
{
  if (dpSetWait(dpe + ":_original.._value", TRUE) != 0)
  {
    return false;
  }
  int ar = 0;
  for (int i = 1; i <= 50; i++)
  {
    dpGet(dpe + ":_alert_hdl.._act_range", ar);
    if (ar != 0)
    {
      return true;
    }
    delay(0.2);
  }
  return false;
}

// Читает время начала тревоги и строит atime. TRUE только если и время,
// и atime ненулевые — это условие допуска к alertSet*().
bool alertDemoAtime(string dpe, time &t, atime &At)
{
  t = 0;
  At = 0;
  if (dpGet(dpe + ":_original.._stime", t) != 0)
  {
    return false;
  }
  if (t == 0)
  {
    return false;
  }
  At = makeATime(t, 0, dpe);
  return At != 0;
}

// Возвращает «хорошее» значение: тревога уходит.
void alertDemoGone(string dpe)
{
  dpSetWait(dpe + ":_original.._value", FALSE);
  delay(0.5);
}

// Убирает точку. Если тревога висит и не квитирована — квитирует её
// (только при валидном atime), затем снимает _active и удаляет точку.
void alertDemoDrop(string base, string dpe)
{
  int ar = 0;
  int ast = 0;
  dpGet(dpe + ":_alert_hdl.._act_range", ar);
  dpGet(dpe + ":_alert_hdl.._act_state", ast);
  if (ar != 0 && (ast == 1 || ast == 3))
  {
    time t;
    atime At;
    if (alertDemoAtime(dpe, t, At))
    {
      alertSet(t, getACount(At), dpe + ":_alert_hdl.._ack_state",
               DPATTR_ACKTYPE_SINGLE);
    }
  }
  dpSetWait(dpe + ":_alert_hdl.._active", FALSE);
  delay(1);
  if (dpExists(base))
  {
    dpDelete(base);
  }
}