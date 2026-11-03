// 02_dpConnectUserData.ctl - dpConnectUserData(): подписка с передачей
// пользовательских данных в колбэк.
//
// Документация: docs/05-subscribe.md#dpconnectuserdata
// Проверено: CTL 3.18, проект <проект стенда>
//
// ПРОТОКОЛ ПРОВЕРКИ. Нужны ДВА процесса: подписчик живёт и ждёт события,
// значения ставит отдельный служебный скрипт _trigger_dpConnect.ctl (тот же,
// что и для 01_dpConnect.ctl).
//
//   1) подписчик (остаётся висеть):
//        .\run-ctl.ps1 -Script .\05-subscribe\02_dpConnectUserData.ctl -LongRunning -Num 200
//   2) триггер (второе окно):
//        .\run-ctl.ps1 -Script .\05-subscribe\_trigger_dpConnect.ctl -Num 201
//   3) прочитать stdout подписчика (путь печатает run-ctl.ps1) и остановить его:
//        Stop-Process -Id <PID> -Force
//
// ВАЖНО: этот пример и 01_dpConnect.ctl делят одну точку dpdemo_sub, и каждый
// при старте пересоздаёт её. Держать оба запущенными одновременно нельзя:
// второй удалит точку, на которую подписан первый, и подписка умрёт МОЛЧА -
// сводки просто не будет, без единой ошибки. Запускайте по одному.
//
// Ожидаемая сводка: --- PASS= 15  FAIL= 0 ---
//
// ЧТО ЗДЕСЬ ГЛАВНОЕ.
//   * dpConnectUserData() отличается от dpConnect() только тем, что первым
//     параметром колбэка приходит userData - произвольное значение, заданное
//     при регистрации. Это способ передать в колбэк контекст, не заводя
//     глобальных переменных: у каждого колбэка может быть своё значение.
//   * Сигнатура колбэка становится (anytype userData, string dp, <значения>),
//     то есть userData всегда ПЕРВЫЙ параметр.
//   * userData объявлен как anytype, поэтому тип значения не важен: здесь int.
//     Сравнение anytype с int работает (проверено на стенде).
//   * answer=FALSE - вызовов ровно столько, сколько записей. С answer=TRUE
//     колбэк вызывается принудительно уже при инициализации, и в userData
//     приходит то же самое значение.
//
// СКРИПТ НЕ ЗАВЕРШАЕТСЯ САМ - это правильное поведение подписчика.

int dpdPass = 0;
int dpdFail = 0;

string DPT = "sub_t";
string DP  = "dpdemo_sub";

// Контекст, который передаётся в колбэк. Может быть любого типа: int, string,
// struct и т.д. В колбэке приходит как anytype.
int userData = 42;

// Заглушка: сюда колбэк кладёт пришедшее значение.
float val_fNewValue = 0.0;

int nChanges = 0;          // сколько записей триггера уже обработано

// Четыре значения, которые ставит _trigger_dpConnect.ctl.
float E1 = 22.3;
float E2 = 47.5;
float E3 = -5.25;
float E4 = 100.0;

main()
{
  DebugN("=== dpConnectUserData(): подписка с пользовательскими данными ===");
  DebugN("  подписчик не завершится сам; значения ставит _trigger_dpConnect.ctl");

  makeType();
  makeDp();

  // -------------------------------------------------------------------
  // 1. Регистрация подписки с userData
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. dpConnectUserData() ---");

  int rc = dpConnectUserData("onValue", userData, FALSE, DP + ".value:_online.._value");
  dpdCheck(rc == 0, "dpConnectUserData вернул 0", rc);
  DebugN("  lastError после регистрации: ", getLastError());

  DebugN("  дальше скрипт ждёт событий; сводка появится после 4-й записи триггера");
}

// ---------------------------------------------------------------------------
// Колбэк. userData - ВСЕГДА первый параметр, дальше идут адреса подписки.
// ---------------------------------------------------------------------------
void onValue(anytype userData, string dp, float fNewValue)
{
  if (nChanges >= 4)
  {
    // Пятый вызов - уже отклонение. Сводка к этому моменту напечатана, поэтому
    // печатаем её заново: иначе отказ не попадёт в число FAIL.
    dpdCheck(FALSE, "лишний вызов колбэка", fNewValue);
    dpdSummary();
    return;
  }

  // Проверяем контекст на каждом вызове: так видно, что userData не теряется
  // между событиями.
  dpdCheck(userData == 42, "userData дошёл без изменений", userData);

  dpdCheck(strpos(dp, DP + ".value") >= 0, "имя DPE содержит точку подписки", dp);
  dpdCheck(closeEnough(fNewValue, expectedAt(nChanges + 1)),
           "значение совпало с записанным триггером", fNewValue);

  nChanges++;
  val_fNewValue = fNewValue;

  if (nChanges == 4)
  {
    DebugN("  значение в заглушке val_fNewValue = ", val_fNewValue);
    dpdSummary();
    DebugN("  сводка напечатана; подписка продолжает работать, скрипт жив");
  }
}

float expectedAt(int i)
{
  if (i == 1) { return E1; }
  if (i == 2) { return E2; }
  if (i == 3) { return E3; }
  return E4;
}

bool closeEnough(float a, float b)
{
  float d = a - b;
  if (d < 0) { d = -d; }
  return d < 0.001;
}

// ---------------------------------------------------------------------------
// Та же точка, что и в 01_dpConnect.ctl: примеры делят один тип и одну точку,
// чтобы триггер был один. Точка пересоздаётся - так у неё значение 0.0 и нет
// зависимости от прошлого прогона.
// ---------------------------------------------------------------------------
void makeType()
{
  dyn_dyn_string pn;
  dyn_dyn_int pt;
  if (dpTypeGet(DPT, pn, pt) == 0)
  {
    dpdCheck(TRUE, "тип уже существует", DPT);
    return;
  }

  dyn_dyn_string n;
  dyn_dyn_int t;
  n[1] = makeDynString(DPT);          t[1] = makeDynInt(DPEL_STRUCT);
  n[2] = makeDynString("", "value");  t[2] = makeDynInt(0, DPEL_FLOAT);
  dpdCheck(dpTypeCreate(n, t) == 0, "тип создан", DPT);
}

void makeDp()
{
  if (dpExists(DP))
  {
    int rcDel = dpDelete(DP);
    DebugN("  teardown: dpDelete(", DP, ") rc=", rcDel);
  }
  dpdCheck(dpCreate(DP, DPT) == 0, "точка данных создана", DP);
}

// ---------------------------------------------------------------------------
// Самодостаточный блок проверки - копия из examples/_lib.ctl: демо-скрипты
// не подключают библиотек, чтобы куски кода работали в скилле без зависимостей.
// ---------------------------------------------------------------------------
void dpdCheck(bool ok, string what, dyn_anytype extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra, "  lastError=", getLastError()); }
}

void dpdSummary()
{
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
}
