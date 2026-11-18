# 05. Подписки на изменения: dpConnect и подписки по запросу

> ℹ️ **Раздел в объёме в части `dpConnect`, `dpConnectUserData`,
> `dpQueryConnectSingle`, `dpQueryConnectAll`, `dpQueryDisconnect`,
> `alertConnect` и `alertDisconnect`.** Шесть примеров написаны и проверены на
> стенде 3.18. `dpDisconnect()` и `dpDisconnectUserData()` на этом этапе
> **не реализуются**: их описание ниже
> остаётся справочным, а сценарий смены подписки описан словами.
>
> Ограничение, которое надо знать заранее: `maxConnectMessageSize` (см.
> [00-model.md, раздел 8](00-model.md#8-ограничения-о-которых-надо-знать-заранее)).

## Как проверить примеры

Подписчик **не завершается сам** — это правильное поведение: `dpConnect()`
регистрирует колбэк и возвращает управление, а скрипт продолжает жить и ждать
событий. Поэтому нужны два процесса: подписчик и триггер, который ставит
значения через `dpSet()` из другого процесса.

```powershell
# 1) подписчик остаётся висеть; run-ctl.ps1 печатает PID и путь к stdout
.\run-ctl.ps1 -Script .\05-subscribe\01_dpConnect.ctl -LongRunning -Num 200

# 2) во втором окне: четыре записи в подписанную точку
.\run-ctl.ps1 -Script .\05-subscribe\_trigger_dpConnect.ctl -Num 201

# 3) прочитать stdout подписчика и остановить его
Stop-Process -Id <PID> -Force
```

Ожидаемая сводка — `--- PASS= 11  FAIL= 0 ---` для `01_dpConnect.ctl` и
`--- PASS= 15  FAIL= 0 ---` для `02_dpConnectUserData.ctl`.

Примеры 03–06 устроены иначе: они **самодостаточны**, сами пишут значения,
дожидаются колбэков в `delay()` и завершаются со сводкой. Второй процесс им не
нужен:

```powershell
.\run-ctl.ps1 -Script .\05-subscribe\03_dpQueryConnectSingle.ctl -Num 200
.\run-ctl.ps1 -Script .\05-subscribe\04_dpQueryConnectAll.ctl      -Num 200
.\run-ctl.ps1 -Script .\05-subscribe\05_dpQueryDisconnect.ctl      -Num 200
.\run-ctl.ps1 -Script .\05-subscribe\06_alertConnect.ctl           -Num 200
```

Ожидаемые сводки: `--- PASS= 29  FAIL= 0 ---`, `--- PASS= 28  FAIL= 0 ---`,
`--- PASS= 19  FAIL= 0 ---`, `--- PASS= 65  FAIL= 0 ---`.

Примеры 01 и 02 делят одну точку `dpdemo_sub` и при старте пересоздают её,
поэтому запускать их **по одному**: если держать оба одновременно, второй
удалит точку, на которую подписан первый, и подписка умрёт молча. Примеры
03–06 используют свои точки `qsub_*`, `qall_*`, `qdis_*`, `qalert05_*` и с ними
не конфликтуют.

`-Num` — номер менеджера скрипта. `0` означает автовыбор номера Data
Manager'ом; у двух одновременно запущенных скриптов номера обязаны различаться.
У драйверов своё пространство номеров, поэтому совпадение номера скрипта с
номером драйвера конфликтом не является.

Оба примера используют `answer=FALSE`, поэтому вызовов ровно столько, сколько
записей сделал триггер. Обратное поведение — `answer=TRUE` — описано ниже:
колбэк вызывается принудительно уже при инициализации, с текущим значением DPE.

`dpConnect()` — неблокирующая подписка: регистрирует функцию и вызывает её при
каждом изменении. Это основной механизм реактивности в WinCC OA.

---

## dpConnect()

**Синопсис**

```c
int dpConnect([class object,] string|function_ptr work, [bool answer,]
              string dp1 [, string dp2 ...] | dyn_string dp_list);
```

**Назначение.** Вызывает колбэк каждый раз, когда изменяются значения/атрибуты
перечисленных точек данных.

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `object` | объект CTRL++ класса | нет | Экземпляр класса. **Только глобальный или скриптовый scope, не внутри функции** | `dpCon` |
| `work` | `string` / `function_ptr` | да | Имя колбэка или указатель на метод | `"add"` |
| `answer` | `bool` | нет | `TRUE` (по умолчанию) — колбэк вызывается **сразу** при регистрации. `FALSE` — только по изменению | `FALSE` (в примерах) |
| `dp1`, `dp2`, … | `string` | да | Атрибуты точек данных | `"Pipe_A.flow:_online.._value"` |
| `dp_list` | `dyn_string` | форма 2 | Список DPE. Тогда в колбэк приходят `dyn_string` и `dyn_<type>` | `makeDynString("A.","B.")` |

**Подстановка по умолчанию:** `_online.._value`.

**Возврат.** `0` — успех, `-1` — ошибка.

### Форма колбэка — жёсткое требование

```c
void work(string dpe1, <type1> var1 [, string dpe2, <type2> var2 ...]);
```

Кроме значения возвращается **идентификатор** атрибута строкой. Порядок пар
«идентификатор + значение» обязан совпадать с порядком регистрации.

> Если у колбэка есть параметры по умолчанию, в `dpConnect()` их тоже нужно
> передать. Иначе в LogViewer:
> `IMPL, WARNING, 54, Unexpected state, CtrlScript, dpVC, too less items in DpHLGroup, callback function myWork not started`

**Ошибки.** Через `getLastError()`. Писать в `PVSS_II.log` можно через
`throwError(err)`.

> `getLastError()` возвращает ошибки **последнего** вызова — читать его нужно
> **сразу** после `dpConnect()`:
>
> ```c
> i = dpConnect("add", "System1:ExampleDP_Arg1.", "System1:ExampleDP_Arg2.");
> err = getLastError();
> if (dynlen(err) > 0) DebugN("An error occurred:", err, throwError(err));
> else DebugN("Function executed:", i);
> ```

**Ожидание.** Неблокирующая по сути, но в документации помечена как
Datapoint function, Waiting Control function, Connection Functions.

### Ключевые правила поведения

* **Один вызов — одна система.** Точки разных систем в одной подписке не работают:
  `PARAM,SEVERE, 175, this request cannot address more than one system, ...`
* **Если конфиг, на который подписались, потом изменён через PARA — подписка
  перестаёт работать.** Конфиг надо перевыбрать в редакторе скрипта.
* **Не все атрибуты `_alert_hdl` одинаково доступны.** Через `dpConnect()`
  доступны `_prior`, `_act_state_color`, `_act_state_fore_color`,
  `_act_state_font_style`, `_text` и `panel`, а также `_act_state` и
  `_act_range` (измерено). Через `alertConnect()` приходят атрибуты экземпляра
  тревоги: `_text`, `_visible`, `_ack_state`, `_prior` и другие, но **не**
  `_act_state` и `_act_range`. Подробно — в
  [разделе alertConnect()](#alertconnect).
* **`_status` vs `_value`.** Атрибут `_status` вызывает колбэк **только при
  изменении** статуса. Атрибут `_value` — **на каждую** запись, независимо от того,
  изменилось значение или нет.
* **Порядок вызовов.** Если атрибут меняется во время работы колбэка, следующий
  вызов произойдёт **после** завершения предыдущего.
* **Время жизни.** Подписка действует до `dpDisconnect()`, остановки менеджера или
  закрытия панели в UI.
* **Выход из scope.** Когда переменная или объект выходит из scope, связанные
  колбэки тоже перестают выполняться. Если объект, создавший подписку,
  деконструирован — колбэк умирает.
* **Разрешение имён.** При одинаковых именах локальное определение в скрипте
  побеждает глобальные определения панели и менеджера.
* **Замыкание.** Если элемент создан через CTRL++ и ссылается на себя — подписка
  не сработает (`DPCONFIG_NOTSET`). Тот же дефект указывает на неверный тип
  (`FLOAT_VAR` вместо `DPEL_FLOAT`) или на отсутствие данных в БД.

### Очередь и потери событий

Если колбэк не успел завершиться, а событие произошло again — событие ставится в
очередь. Если частота событий выше частоты обработки, очередь и потребление памяти
CTRL-менеджера растут. При переполнении в LogViewer появляется:

```
Function has ... pending runs-> DISCARDING
```

Максимум очереди по умолчанию — **200**. При достижении система отбрасывает все
вызовы, кроме самого свежего, и обрабатывает только последнее значение. Очередь
может вырасти снова. Лимит настраивается конфиг-элементом `[general] ctrlMaxPendings`
(для UI и CTRL Manager).

> Если увидели `DISCARDING` — колбэк слишком тяжёлый. Переносите тяжёлую работу из
> колбэка в отдельный поток или ограничивайте частоту.

### Батчинг

Обычно при нескольких зарегистрированных элементах на каждое изменение приходит
**отдельный** вызов с **всеми** зарегистрированными значениями. Но:

* если несколько изменений отправлены **одним** `dpSet()`, придёт **один** общий вызов;
* то же для «родственных» атрибутов одного элемента (значение, время источника,
  качество).

### Правильная адресация

Обратите внимание на точки:

```c
ret = dpConnect("ReportEvent1", TRUE, "TestReport");                  // ret=0, но колбэк ПАДАЕТ
ret = dpConnect("ReportEvent1", TRUE, "TestReport.");                 // ret=0, колбэк РАБОТАЕТ
ret = dpConnect("ReportEvent1", TRUE, "TestReport:_online.._value");  // ret=-1, скрипт ПАДАЕТ
ret = dpConnect("ReportEvent1", TRUE, "TestReport.:_online.._value"); // ret=0, всё РАБОТАЕТ
```

Для узла структуры точка в конце обязательна.

### Диагностика: атрибуты `_connect`

| Атрибут | Что даёт |
| --- | --- |
| `._connect.._dpids` | Какие DPE входят в эту группу подписки |
| `._connect.._manids` | Какие менеджеры запрашивают этот DPE |
| `._connect.._mancount` | Сколько раз менеджер запрашивает этот DPE |

```c
dyn_dyn_string ds, as;
dyn_dyn_int dui, hui, di, fi;
dpGet("ExampleDP_Arg2.:_connect.._manids", dui,
      "ExampleDP_Arg2.:_connect.._dpids",  ds,
      "ExampleDP_Arg1.:_connect.._mancount", di,
      "testDp1.:_connect.._dpids", as,
      "testDp1.:_connect.._manids", hui,
      "testDp1.:_connect.._mancount", fi);
DebugN(ds, dui, di);
```

### Пример: C = A + B

```c
main()
{
  int i = dpConnect("add", "Pipe_A.flow", "Pipe_B.flow");
  DebugN("Function executed:", i);
}

add(string dp1, float a, string dp2, float b)
{
  dpSet("Pipe_C.flow", a + b);
}
```

### Пример: отображение значения с форматом и единицей

```c
main()
{
  dpConnect("displayValue", "Drive014.speed");
}

displayValue(string dpe, float speed)
{
  this.text = dpValToString(dpe, speed, true);
}
```

### Пример: символ привода с учётом качества и тревоги

```c
main()
{
  if (dpConnect("visualizeDrive",
                "Drive014.speed",
                "Drive014.speed:_online.._bad",
                "Drive014.fault:_alert_hdl.._act_state_color",
                "Drive014.manual") == -1)
    setValue("", "backCol", "_dpdoesnotexist");
}

visualizeDrive(string dpe1, float speed, string dpe2, bool invalid,
               string dpe3, string alertCol, string dpe4, bool manmode)
{
  string symbolCol;
  if (speed > 0)
    symbolCol = invalid ? "STD_device_on_invalid" : "STD_device_on";
  else
    symbolCol = invalid ? "STD_device_off_invalid" : "STD_device_off";

  setMultiValue("DriveSymbol", "backCol", symbolCol,
                "DriveSymbol", "foreCol", alertCol,
                "InvalidIndicator", "visible", invalid,
                "ManualIndicator",  "visible", manmode);
}
```

### Пример: журнал изменений уставки

```c
main()
{
  dpConnect("logSP",
            "Drive014.cmd.setpoint",
            "Drive014.cmd.setpoint:_online.._stime",
            "Drive014.cmd.setpoint:_online.._user",
            "Drive014.cmd.setpoint:_online.._manager",
            "Drive014.cmd.setpoint:_online.._invalid");
}

logSP(string dpe1, float setpoint,
      string dpe2, time stime,
      string dpe3, int uid,
      string dpe4, int manNum,
      string dpe5, bool invalid)
{
  string valStr, managerString;
  sprintf(valStr, "%5.2f", setpoint);
  convManIntToName(manNum, managerString);
  DebugN(formatTime("%c", stime, ",%03d") + " | " +
         "SP: " + valStr + " | " +
         getUserName(uid) + " " +
         "on " + managerString + " | " +
         (invalid ? "Invalid!" : ""));
}
```

Один `dpConnect()` на пять атрибутов — и `logSP` вызывается **один раз** на
изменение, а не пять раз. Вывод:

```
["04.11.2003 16:56:48,629 | SP: 1250.00 | root on UI -num 2 | "]
["04.11.2003 16:57:08,638 | SP: 1500.00 | John Q. Public on UI -num 1 | "]
["04.11.2003 16:57:58,479 | SP:  -5.00 | root on UI -num 2 | Invalid!"]
```

### Особенности указания идентификаторов

* Идентификатор можно задать абсолютным или **относительным** — `$dpe+".Messwert.value:..."`.
  Для переиспользуемых символов используйте `$`.
* Если на точке данных **нет** обработки тревог, подписка на
  `$dpe+".Messwert.value:_alert_hdl.._act_state_color"` **не вызывается**, но
  возврат будет `0` (успех). При переключении резервирования колбэк вызывается, но
  `_act_state_color` вернёт **пустую строку**. Значение для `Properties.Typ` будет
  `0`, а не из базы.
* В колбэке обычно **не нужно** вызывать `dpGet()` — регистрация и так передаёт
  значения. Описания, форматы и единицы достаются напрямую: это быстрый доступ к
  памяти, на скорость не влияет.
* Многоязычные текстовые элементы приходят **только на текущем языке**.

### CTRL++ классы как колбэки

Экземпляр класса передаётся первым аргументом, указатель на метод — вторым.

> **Экземпляр обязан быть объявлен в глобальном или файловом scope.** Объявленный
> внутри `main()` или другой функции экземпляр уничтожается при выходе из scope —
> и колбэк перестаёт работать, потому что объекта больше нет.

В панели экземпляр объявляется в **ScopeLib**; в скрипте CTRL-менеджера — на
уровне файла.

```c
// ScopeLib панели
class DpCon
{
  public void work(dyn_string dp, dyn_float value) { DebugTN(value); }
};
DpCon dpCon;              // глобальный scope

// Код кнопки
void main(mapping event)
{
  dyn_string dpList = makeDynString("ExampleDP_Arg1.", "ExampleDP_Arg2.");
  dpConnect(dpCon, dpCon.work, TRUE, dpList);
}
```

```c
// Скрипт CTRL-менеджера
class SensorMonitor
{
  public void onValueChanged(string dp, float value)
  { DebugTN("Sensor value changed:", dp, value); }
};
SensorMonitor monitor;    // файловый scope

void main()
{
  dpConnect(monitor, SensorMonitor::onValueChanged, "Sensor01.value.");
}
```

**Пример:** [examples/05-subscribe/01_dpConnect.ctl](../examples/05-subscribe/01_dpConnect.ctl)
— своя точка `dpdemo_sub`, `answer=FALSE`, сводка после четырёх записей
триггера из другого процесса.

---

## dpConnectUserData()

**Синопсис**

```c
int dpConnectUserData([class object,] string|function_ptr work, anytype userData,
                      [, bool answer = TRUE],
                      string dpe1 [, string dpe2 ...] | dyn_string dp_list);
```

**Назначение.** То же, что `dpConnect()`, но дополнительно передаёт в колбэк
**собственные данные**.

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `object` | объект CTRL++ | нет | Глобальный scope | `dpCon` |
| `work` | `string` / `function_ptr` | да | Колбэк | `"add"` |
| `userData` | `anytype` | да | Данные, передаваемые в колбэк **первым параметром** | `2` |
| `answer` | `bool` | нет | По умолчанию `TRUE` | `FALSE` (в примерах) |
| `dpe1`, … | `string` | да | Подписываемые атрибуты | `"Pipe_A.flow"` |

**Подстановка по умолчанию:** `_online.._value`.

**Формы колбэка**

```c
void workCB(anytype userData, string dp1, <type> v1, string dp2, <type> v2, ...);
// или для dp_list:
void workCB(anytype userData, dyn_string dps, dyn_anytype values);
```

```c
main()
{
  int userData = 0;
  dpConnectUserData("add", userData, "Pipe_A.flow", "Pipe_B.flow");
}

void add(int userData, string dp1, float a, string dp2, float b)
{
  if ((a + b) > userData)
    dpSet("Pipe_C.flow", a + b);
  else
    DebugN("Сумма <= 0. Значение на Pipe_C.flow не записано");
}
```

```c
main()
{
  float userData = 100;
  dpConnectUserData("displayValue", userData, "Drive014.speed");
}

void displayValue(float userData, string dpe, float speed)
{
  if (speed > userData) this.text = dpValToString(dpe, speed, true);
  else                  this.text(userData);
}
```

**Ошибки.** Те же, что у `dpConnect()` + правило «читать `getLastError()` сразу».

> Причины типичных «молчаливых» сбоев в `dpConnect()` и `dpConnectUserData()`:
> * нет обработки тревог на точке данных — тогда `dpConnect()` на
>   `._alert_hdl.._act_state_color` не вызывается, но вернёт `0`;
> * ошибка замкнутой ссылки (`DPCONFIG_NOTSET`);
> * неверный тип (`FLOAT_VAR` вместо `DPEL_FLOAT`);
> * отсутствие данных в БД.
>
> Все четыре случая дают **`0`**, а не ошибку. Проверяйте через `dpGet(...:_online.._value)`,
> а не по коду возврата.

**Пример:** [examples/05-subscribe/02_dpConnectUserData.ctl](../examples/05-subscribe/02_dpConnectUserData.ctl)
— тот же сценарий, `userData = 42` приходит первым параметром колбэка и
проверяется на каждом вызове.

---

## Подписка по SQL-запросу: когда нужна

`dpConnect()` требует перечислить DPE заранее. Если список большой или меняется
во время работы, его приходится собирать через `dpNames()` и переподписываться.
`dpQueryConnectSingle()` и `dpQueryConnectAll()` подписываются на **результат
SQL-запроса**: состав определяется условием `FROM ... WHERE ...`, а новые точки
подходящего типа Event Manager добавляет в подписку сам.

Типичные задачи:

* наблюдать все точки одного типа (`_DPT = "Valve_DPT"`) без списка имён;
* получать только те точки, которые сейчас подходят под условие
  (`'_online.._value' > 0`), и не тратить вызовы на остальные;
* реагировать на появление новых объектов, созданных инженером во время работы.

Подписка на запрос — не замена `dpConnect()`: у неё другая единица доставки
(таблица) и другие правила уведомления. Ниже — только измеренное на стенде.

---

## dpQueryConnectSingle()

**Синопсис**

```c
int dpQueryConnectSingle([class object,] string|function_ptr work,
                         bool wantsanswer, anytype userData, string query
                         [, int blockingTime]);
```

**Назначение.** Подписка на SQL-`SELECT`. На каждое изменение Event Manager
вызывает колбэк и передаёт **только изменившиеся строки** (плюс строку
заголовка).

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `object` | объект CTRL++ | нет | Экземпляр класса, только глобальный/файловый scope | — |
| `work` | `string` / `function_ptr` | да | Имя колбэка | `"onSingle"` |
| `wantsanswer` | `bool` | да | `TRUE` — вызвать сразу с текущим срезом; `FALSE` — только по изменению | `TRUE` |
| `userData` | `anytype` | да | Данные, приходящие первым параметром колбэка | `"S1"` |
| `query` | `string` | да | SQL `SELECT` | см. ниже |
| `blockingTime` | `int` | нет | Накопление вызовов, мс; `0` — не накапливать | `0` |

**Форма колбэка**

```c
void work(anytype userData, dyn_dyn_anytype tab);
```

**Возврат.** `0` — сообщение о регистрации отправлено, `-1` — ошибка аргументов
(например, колбэк не найден). **`0` не означает, что запрос корректен**: ошибка
SQL приходит позже через `getLastError()`.

### Структура таблицы

| Элемент | Содержимое |
| --- | --- |
| `tab[1][1]` | пусто |
| `tab[1][2]`, `tab[1][3]`, … | имена запрошенных атрибутов: `":_online.._value"`, `":_online.._stime"`, … |
| `tab[n][1]`, `n ≥ 2` | полное имя DPE: `"System1:qsub_a.value"` |
| `tab[n][2]`, `tab[n][3]`, … | значения в порядке `SELECT` |

```c
for (int r = 2; r <= dynlen(tab); r++)
{
  string dpe = (string)tab[r][1];
  float  val = (float)tab[r][2];
  time   ts  = (time)tab[r][3];
  DebugN(dpe, val, ts);
}
```

Строка заголовка есть **всегда**. Поэтому `dynlen(tab) == 1` означает «данных
нет», а не «таблица пустая»: при `wantsanswer = TRUE` и пустой выборке колбэк
приходит один раз с одной строкой заголовка.

Проверено отдельно (`strlen`): `tab[1][1]` — действительно пустая строка,
`strlen = 0`, а имя в `tab[n][1]` — чистое `"System1:dp.element"` без
аннотаций. `DebugN(tab)` печатает рядом `(Type: … Sys: … Dp: … El: …)` — это
представление `anytype`, а не содержимое строки; сравнивать имена можно
напрямую.

### Что измерено

| Действие | Результат |
| --- | --- |
| `wantsanswer = TRUE` | один вызов сразу при регистрации, в таблице весь текущий срез |
| `wantsanswer = FALSE` | до первого изменения вызовов нет |
| изменение одной точки | один вызов, одна строка данных |
| один `dpSet()` на две точки | один вызов, две строки данных |
| две записи в разное время | два отдельных вызова; промежуточные значения **не теряются** |
| создание новой точки подходящего типа | вызов уже на создании; в строке значение по умолчанию |
| удаление точки | отдельного вызова нет; со следующего изменения её нет в таблице |
| вход значения в `WHERE` | вызов есть |
| уход значения из `WHERE` | **вызова нет**; последняя полученная таблица остаётся устаревшей |
| `blockingTime = 2000`, две записи с интервалом 1 с | один вызов с двумя строками |

Уход из `WHERE` — главная ловушка `Single`. Если по колбэкам считать «сколько
сейчас активных аварий», счётчик не уменьшится: событие «стало неактивно» не
придёт. Для полного среза нужен `All` (см. ниже) или отдельная логика
обнаружения ухода.

### Рабочий запрос

```c
string query =
  "SELECT '_online.._value', '_online.._stime' " +
  "FROM 'qsub_*' " +
  "WHERE _DPT = \"qsub_t\"";

int rc = dpQueryConnectSingle("onSingle", TRUE, "S1", query);
dyn_errClass err = getLastError();   // читать сразу
if (rc != 0 || dynlen(err) > 0)
  DebugN("регистрация не удалась:", rc, err);
```

`FROM` — шаблон имени в **одинарных** кавычках, тип в `_DPT` — в **двойных**
(внутри строки CTL они экранируются). Атрибуты в `WHERE` — в одинарных кавычках.

### Подписка на тревоги

`_alert_hdl.._act_state` — обычный конфиг-атрибут, поэтому его можно запросить
подпиской и отфильтровать точки по классу тревоги ещё в `WHERE`:

```c
string q =
  "SELECT '_alert_hdl.._act_state' FROM 'Pump*' " +
  "WHERE '_alert_hdl.._class' = \"System1:alert.\"";
dpQueryConnectSingle("onAlert", FALSE, "A", q);
```

Измерено: в выборку попадают только DPE с настроенной тревогой этого класса;
CAME даёт `_act_state = 1`, WENT — `3` (у `dpConnect()` те же значения). Так
одна подписка заменяет `alertConnect()` с ручной фильтрацией в колбэке и не
требует перечислять точки. Подробнее — в разделе
[`alertConnect()` или `dpQueryConnectSingle()`](#alertconnect-или-dpqueryconnectsingle).

**Пример:** [examples/05-subscribe/03_dpQueryConnectSingle.ctl](../examples/05-subscribe/03_dpQueryConnectSingle.ctl)
— 29 проверок: снимок при регистрации, одна и две изменившиеся строки, новая
точка, удаление, `WHERE`, `dpQueryDisconnect()`.

---

## dpQueryConnectAll()

**Синопсис**

```c
int dpQueryConnectAll([class object,] string|function_ptr work,
                      bool wantsanswer, anytype userData, string query
                      [, int blockingTime]);
```

**Назначение.** Подписка на тот же SQL-`SELECT`, но на каждое изменение
приходит **вся текущая выборка**, включая строки, которые не менялись.

**Отличие от `Single`**

| | `Single` | `All` |
| --- | --- | --- |
| Что в таблице | только изменившиеся строки | вся выборка |
| Изменилась одна точка из десяти | 1 строка данных | 10 строк данных |
| Уход из `WHERE` | вызова нет | вызов есть; ушедшей строки в таблице нет |
| Пустая выборка после ухода | — | таблица из одной строки заголовка |
| `blockingTime`, две записи | один вызов, две строки | один вызов, **два полных снимка подряд** |

Последняя строка — измеренная особенность: при `blockingTime = 1500` и двух
записях в одну точку в таблице оказываются заголовок и две строки с **одним и
тем же** именем DPE (значения 1 и 2). Это не дубликат ошибки, а два снимка,
склеенные в один вызов. Код, который рисует таблицу, должен либо не задавать
`blockingTime`, либо уметь брать последнюю строку для каждого DPE.

**Пример:** [examples/05-subscribe/04_dpQueryConnectAll.ctl](../examples/05-subscribe/04_dpQueryConnectAll.ctl)
— 28 проверок: полная таблица, неизменившиеся строки, новая и удалённая точка,
уход из `WHERE`, склейка снимков при `blockingTime`.

---

## Что можно выбрать и где фильтровать

Измерено на CTL 3.18 для `dpQueryConnect*` (для `dpQuery()` ограничения те же):

| Атрибут в `SELECT` | Результат |
| --- | --- |
| `_online.._value` | работает |
| `_original.._value` | работает |
| `_online.._stime` | работает, приходит `time` |
| `_online.._status` | работает, приходит строка битов |
| `_alert_hdl.._act_state` | работает, приходит `int` |
| `_alert_hdl.._ack_state` | возвращает `-?-` всегда, в том числе после квитирования |
| `_common.._description` | ошибка `PARAM,SEVERE, 81 ... error on fetching header description`; колбэка нет |

Поэтому «боевой» запрос с описанием и признаком квитирования, собранный из
документации, на 3.18 **не работает**. Рабочий вариант:

```c
string query =
  "SELECT '_online.._value', '_online.._stime', '_alert_hdl.._act_state' " +
  "FROM 'PumpStation1_*.alarm' " +
  "WHERE _DPT = \"Valve_DPT\" AND '_online.._value' == 1 " +
  "SORT BY 2 DESC";
```

Здесь:

* `== 1`, а не `== TRUE`: сравнение BOOL с `TRUE` в connect-запросе не даёт
  ни одного вызова и не сообщает об ошибке;
* `SORT BY 2 DESC` сортирует по **второму столбцу `SELECT`** (`_stime`);
  нумерация начинается с 1 и считает только выбранные атрибуты. Без указания
  направления сортировка идёт по возрастанию (измерено на `_stime`: `ASC` —
  старые сверху, `DESC` — новые сверху);
* `_alert_hdl.._act_state` показывает, активна ли тревога, но не признак
  квитирования. Квитирование читается отдельно через `alertGet()` по каждой
  строке;
* описание (`_common.._description`) в запрос не входит — его надо получать
  через `dpGetDescription()` или `dpGet()` по имени DPE.

Неверный номер столбца в `SORT BY` (`SORT BY 3` при двух столбцах) даёт
`rc = 0`, **ни одного колбэка** и ошибку только в журнале/`getLastError()`:
`PARAM,SEVERE, 81 ... ORDER BY requested for invalid column`.

---

## dpQueryDisconnect()

**Синопсис**

```c
int dpQueryDisconnect([class object,] string|function_ptr work, anytype userData);
```

Снимает подписку, созданную `dpQueryConnectSingle()` или
`dpQueryConnectAll()`. Ключ подписки — пара **колбэк + `userData`**, а не текст
запроса.

| Действие | Результат |
| --- | --- |
| тот же колбэк и тот же `userData` | `rc = 0`, вызовы прекращаются |
| тот же колбэк, другой `userData` | `rc = -1`, `CTRL, WARNING, 76, Invalid argument in function` |
| один колбэк зарегистрирован дважды с разным `userData` | снятие одной регистрации не трогает вторую |
| повторная регистрация после снятия | работает, `rc = 0` |

Как и `dpDisconnect()`, вызывается **только в том же скрипте**, где была
регистрация.

**Пример:** [examples/05-subscribe/05_dpQueryDisconnect.ctl](../examples/05-subscribe/05_dpQueryDisconnect.ctl)
— 19 проверок: две регистрации одного колбэка, снятие одной, неверный
`userData`, повторная подписка, ошибки запроса и колбэка.

---

## Что выбрать

| Задача | Инструмент |
| --- | --- |
| Фиксированный небольшой список DPE, нужны все изменения по порядку | `dpConnect()` |
| То же + свой контекст в колбэке | `dpConnectUserData()` |
| Большой или меняющийся список, нужны только изменившиеся строки | `dpQueryConnectSingle()` |
| Нужен полный текущий срез (счётчики, таблица на экране) | `dpQueryConnectAll()` |
| Нужно отфильтровать точки до доставки в скрипт | `WHERE` в любом из `dpQueryConnect*()` |

`Single` не «теряет промежуточные значения» сам по себе: две записи в разное
время дают два вызова. Склейка появляется только при явно заданном
`blockingTime`. `All` не «гарантирует отсутствие потерь»: при `blockingTime`
он присылает несколько снимков в одной таблице.

### Из документации, на стенде не проверялось

Эти ограничения взяты из документации 3.21.6 и не измерялись. Проверенное
поведение — только в таблицах выше.

* `blockingTime` ограничен `32767` мс (на стенде `40000` приняли с `rc = 0`,
  но фактическую задержку не измеряли).
* Если `FROM` затрагивает более **80 %** всех DPE, регистрируется обычная
  подписка «на всё»; в колбэке остаются только строки, подошедшие под SQL.
* В подписке запрещены `SELECT ALL`, `TIMERANGE` и `SELECT ALERT` — из-за
  производительности Event Manager. **Проверено на 3.18:** `SELECT ALERT`
  принимается (`rc = 0`) и присылает события тревог; см.
  [«`alertConnect()` или `dpQueryConnectSingle()`»](#alertconnect-или-dpqueryconnectsingle).
  Фактическую нагрузку на Event Manager на стенде не измеряли, поэтому для
  больших проектов ограничение из документации остаётся ориентиром.
* `FIRST` / `LAST` в запросе подписки не учитываются.
* Подписка работает только по конфигам, управляемым Event Manager: нельзя
  `_archive`, `_address`, `_cmd_conv`, `_msg_conv`, `_smooth`.
* Элемент типа `struct` через `dpQueryConnectSingle()` не запрашивается; может
  прийти предупреждение `IMPL, WARNING, 54 ... no config`.

---

## Тихие отказы подписок по запросу

| Действие | Код | Что произошло |
| --- | --- | --- |
| синтаксическая ошибка в запросе | `rc = 0` | колбэка нет; `PARAM,SEVERE, 81 ... syntax error - check query` в `getLastError()` |
| неверный столбец `SORT BY` | `rc = 0` | колбэка нет; ошибка только в журнале/`getLastError()` |
| `_common.._description` в `SELECT` | `rc = 0` | колбэка нет; `... error on fetching header description` |
| `'_online.._value' == TRUE` | `rc = 0` | ни одного вызова, ошибки нет |
| несуществующий колбэк | `rc = -1` | `CTRL, WARNING, 72, Function not defined` |
| неверный `userData` в `dpQueryDisconnect()` | `rc = -1` | `CTRL, WARNING, 76, Invalid argument in function` |
| уход значения из `WHERE` у `Single` | — | вызова нет, ошибки нет |

---

## dpDisconnect()

**Синопсис**

```c
int dpDisconnect([class object,] string|function_ptr work,
                 string dp1 [, string dp2...|dyn_string dp_list]);
```

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `object` | объект CTRL++ | нет | Тот же объект, что при регистрации | `dpCon` |
| `work` | `string` / `function_ptr` | да | Тот же колбэк | `"add"` |
| `dp1`, … | `string` | да | Те же атрибуты | `"A.:_original.._value"` |

**Подстановка по умолчанию:** `_online.._value`.

**Возврат.** `0` — успех, `-1` — ошибка (нет такой точки данных или функции).

> **`dpDisconnect()` может быть вызван только в том же скрипте, где был
> `dpConnect()`.** Из другого скрипта или панели не сработает.

```c
main()
{
  dpConnect("startCalc", "D.:_original.._value");
}

startCalc(string dp1, int d)
{
  if (d == 1)
    dpConnect("add", "A.:_original.._value", "B.:_original.._value");
  else
    dpDisconnect("add", "A.:_original.._value", "B.:_original.._value");
}

add(string dp1, int a, string dp2, int b)
{
  dpSet("C.:_original.._value", a + b);
}
```

**На этом этапе не реализуется.** Сценарий смены подписки: сначала
`dpDisconnect()`, затем `dpConnect()` на другие точки — в том же скрипте.

---

## dpDisconnectUserData()

**Синопсис**

```c
int dpDisconnectUserData([class object,] string|function_ptr work, anytype userData,
                         [, string dp1[, string dpe2 ...] | dyn_string dp_list);
```

Снимает подписку, созданную `dpConnectUserData()`. `userData` должен быть **тот же
самый**, что и при регистрации, иначе подписка не снимется. Использование
неинициализированной переменной в `userData` вызовет ошибку.

```c
main()
{
  anytype userData = getUserName();
  dpConnectUserData("startCalc", userData, "D.:_original.._value");
}

startCalc(anytype userData, string dp1, int d)
{
  if (d == 1)
    dpConnectUserData("add", userData, "A.:_original.._value", "B.:_original.._value");
  else
    dpDisconnectUserData("add", userData, "A.:_original.._value", "B.:_original.._value");
}
```

**На этом этапе не реализуется.** Сценарий смены подписки: сначала
`dpDisconnectUserData()` с тем же `userData`, затем `dpConnectUserData()` на
другие точки — в том же скрипте.

---

## alertConnect()

**Синопсис**

```c
int alertConnect([class object,] string|function_ptr work, [bool answer,]
                 string alert1 [, string alert2 ...] | dyn_string alert_list);
```

**Назначение.** Регистрирует `work` для вызова при появлении, изменении и уходе
экземпляров тревог. Это не «`dpConnect()` для тревог»: `dpConnect()` следит за
атрибутами перечисленных точек, а `alertConnect()` — за атрибутом тревоги
**во всех точках системы** (измерено, см. ниже).

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание |
| --- | --- | --- | --- |
| `object` | объект CTRL++ | нет | Экземпляр класса, если `work` — его метод. Только файловый или глобальный scope |
| `work` | `string` / `function_ptr` | да | Имя функции или указатель на метод (`obj.method`) |
| `answer` | `bool` | нет | `TRUE` (по умолчанию) — сразу вызвать с текущими тревогами; `FALSE` — только новые события |
| `alert1`, `alert2`, … | `string` | да | Атрибуты `_alert_hdl`, например `"Pump1.err:_alert_hdl.._text"` |
| `alert_list` | `dyn_string` | форма 2 | Список атрибутов; в колбэк приходят `dyn_string` и `dyn_anytype` |

**Возврат.** `0` — успех, `-1` — ошибка; причина в `getLastError()`.

### Область подписки — вся система

Измерено на 3.18. Подписка, оформленная как
`alertConnect("cb", FALSE, "dptest_a.b1:_alert_hdl.._text")`, вызвала колбэк на
CAME **другой** точки `dptest_b.b1`, к которой никакого `alertConnect()` не
было. То же с глобальной формой без DPE (`":_alert_hdl.._text"`): при
`answer=TRUE` колбэк получил текущие тревоги всех точек проекта
(`ExampleDP_Arg1`, `ExampleDP_AlertHdl1`, служебные точки лицензии).

Документация 3.21 это подтверждает: «In contrast to `dpConnect()`,
`alertConnect()` does not connect with alert handling attributes of individual
datapoint elements, but rather with the appropriate attributes of all datapoint
elements».

Практические следствия:

* DPE в строке атрибута нужен только для проверки существования — фильтром он
  не является. Отбирать события приходится в колбэке по имени пришедшего
  атрибута (`strpos(name, "Pump")`).
* В колбэк приходит **полный** адрес `System1:Pump1.err:_alert_hdl.._text`, а
  не то, что было в строке подписки.
* `answer=TRUE` по умолчанию — это не «одно текущее значение», а вызов по
  каждой активной тревоге системы. На стенде это было пять вызовов подряд.

### Форма колбэка

```c
void work(time t, int count, string alert1, <type1> var1
          [, string alert2, <type2> var2 ...]);
```

| Параметр | Смысл |
| --- | --- |
| `t` | время тревоги |
| `count` | счётчик тревог с общим временем; на одиночной тревоге измерен `0` |
| `alert1`, `var1`, … | пары «полное имя атрибута — значение», по одной на каждый атрибут подписки |

Для формы с `dyn_string` колбэк принимает `(time t, int count, dyn_string a,
dyn_anytype v)`: одно событие — один вызов, в массивах сразу все имена и
значения.

```c
// две строки в подписке -> шесть аргументов в колбэке
void cbTwo(time t, int count, string n1, anytype v1, string n2, anytype v2)
{
  DebugN(t, count, n1, v1, n2, v2);
}
alertConnect("cbTwo", FALSE,
             "Pump1.err:_alert_hdl.._text",
             "Pump1.err:_alert_hdl.._visible");
// -> System1:Pump1.err:_alert_hdl.._text    ALARM
// -> System1:Pump1.err:_alert_hdl.._visible TRUE
```

`_text` — многоязычная строка (`langString`). Если объявить параметр как
`string`, придёт текст на текущем языке; если как `anytype` — структура
`LANG:… "ALARM"`.

### Какие атрибуты дают события

Подписка на любой существующий атрибут `_alert_hdl` возвращает `0`. События
приходят не по всем:

| Атрибуты | Поведение |
| --- | --- |
| `_text`, `_visible`, `_value`, `_prior`, `_ack_oblig`, `_comment`, `_add_values`, `_ack_state`, `_direction`, `_abbr`, `_class` | приходят на CAME, WENT и квитирование |
| `_act_state`, `_act_range`, `_alerts` | принимаются (`0`), но событий не дают: это атрибуты **элемента**, а не экземпляра тревоги |
| `_active`, `_text0`, `_text1`, `_type`, `_orig_hdl` | принимаются (`0`), но изменение конфигурации события не вызывает (измерено на `_text1`) |
| несуществующий атрибут (`_time`, `_nope`) | `-1`, `WARNING 71 "DP does not exist"` |

Отсюда главная практическая поправка: распространённый пример с
`_alert_hdl.._act_state` в `alertConnect()` **не работает** — вызов вернёт `0`,
но колбэк не сработает ни разу. Состояние тревоги отслеживают через
`_ack_state`, `_text`, `_visible`, а `_act_state` читают через `dpGet()` или
`dpConnect()`.

### `answer`

* `TRUE` (по умолчанию) — сразу после регистрации колбэк вызывается с
  текущими значениями **всех** активных тревог системы.
* `FALSE` — только новые события. Это то, что нужно в большинстве случаев.

### `alertDisconnect()`

```c
int alertDisconnect([class object,] string|function_ptr work,
                    string alert1 [, string alert2 ...] | dyn_string alert_list);
```

Снимает подписку по паре «`work` + те же атрибуты». Возврат `0`/`-1`.

* **Параметра `answer` у `alertDisconnect()` нет.** Лишний `bool` на месте
  третьего аргумента воспринимается как имя атрибута: `-1`. Причина попадает
  в журнал (`WARNING 71 "DP does not exist"`), а `getLastError()` в замере
  остался **пустым** — проверять надо по коду возврата. Это отличается от
  `dpConnect()`/`dpDisconnect()`, где `answer` есть у обеих функций.
* Повторная отписка уже снятой пары даёт `-1` с **пустым** `getLastError()`.
* Отписка несуществующего колбэка даёт `-1` и `WARNING 72 "Function not
  defined"`.
* Пока жива хотя бы одна подписка, менеджер CTRL не завершается — как у
  `dpConnect()`. В конце скрипта нужен явный `alertDisconnect()`.

### Повторная подписка дублирует колбэк

`alertConnect()` с теми же `work` и атрибутом не заменяет прежнюю подписку, а
добавляет ещё одну: одно событие даёт два вызова. Одна `alertDisconnect()`
снимает ровно одну. Если подписка оформлена в функции, которую вызывают
несколько раз, колбэк будет множиться.

### Объектная форма

```c
class Watcher
{
  public int n;
  public void onText(time t, int count, string a, anytype v) { n++; }
};
Watcher w;                                   // файловый scope обязателен

alertConnect(w, w.onText, FALSE, "Pump1.err:_alert_hdl.._text");
alertDisconnect(w, w.onText, "Pump1.err:_alert_hdl.._text");
```

* Нужен **указатель на метод** (`w.onText`). Имя метода строкой
  (`alertConnect(w, "onText", …)`) даёт `-1` и `WARNING 72 "Function not
  defined"`.
* Для глобальной функции наоборот: строка `"cb"` работает, а `function_ptr` из
  имени функции в CTL 3.18 не собрать (`&cb` — синтаксическая ошибка,
  приведение запрещено).
* Экземпляр обязан быть в файловом или глобальном scope.

### `alertConnect()` или `dpQueryConnectSingle()`

`alertConnect()` не умеет фильтровать: он отдаёт поток событий по атрибуту от
всех точек, а отбор остаётся колбэку. Документация 3.21 прямо рекомендует для
шаблонов и фильтров использовать `dpQueryConnectSingle()`: «If you want to use
a DPE pattern or filter, for performance reasons use a `dpQueryConnectSingle()`
method with a suitable filter».

**Правило.** Нужен конкретный набор точек по шаблону (все тревоги класса
`System1:alert.`, приоритет выше заданного, маска имён) — берут
`dpQueryConnectSingle()`. Нужен поток событий тревог без отбора (журналирование,
пересчёт сводки) — берут `alertConnect()`. Сотни `alertConnect()` на отдельные
DPE не нужны: одна подписка на запрос дешевле и фильтрует на стороне Event
Manager.

Измерено на 3.18 (блок 9 примера
[06_alertConnect.ctl](../examples/05-subscribe/06_alertConnect.ctl)): запрос

```c
string query =
  "SELECT '_alert_hdl.._act_state' FROM 'qfilter*' " +
  "WHERE '_alert_hdl.._class' = \"System1:alert.\"";
dpQueryConnectSingle("onAlert", FALSE, "A", query);
```

* в выборку попала только точка с настроенной тревогой этого класса, точка без
  `_alert_hdl` не попала;
* CAME на ней дал вызов с `_alert_hdl.._act_state = 1`, WENT — `3`;
* класс тревоги — обычный конфиг-атрибут, поэтому он работает и в `SELECT`,
  и в `WHERE`; `_alert_hdl.._prior` читается (`dpGet` дал `60` для
  `System1:alert.`), но **записать** его нельзя: `dpSetTimedWait` вернул `-1`
  (приоритет задаётся классом).

Форма `SELECT ALERT` в подписке на 3.18 тоже **работает**, хотя документация
3.21.6 относит её к запрещённым (см. таблицу ограничений выше):

```c
string qa = "SELECT ALERT '_alert_hdl.._text', '_alert_hdl.._value' " +
            "FROM 'qfilter*' WHERE '_alert_hdl.._class' = \"System1:alert.\"";
// rc = 0, на CAME: [DPE, время, langString "ALARM", TRUE]
```

Колонки идут в порядке `SELECT`, но первая колонка — DPE, затем служебное время
тревоги, затем запрошенные атрибуты; строка заголовка, как и у обычного
`SELECT`, приходит первой. Проверяйте `SELECT ALERT` на своём патче перед
использованием: поведение может отличаться между версиями.

Плата за `dpQueryConnectSingle()` — пакетная доставка: результат приходит
целиком на изменение выборки, с задержкой `blockingTime`, а не мгновенным
событием на каждое изменение. Ещё одна ловушка — уход из `WHERE`: у `Single`
вызова не будет (см. таблицы выше), поэтому «сколько тревог активно сейчас» по
такой подписке не посчитать.

### Пример

[examples/05-subscribe/06_alertConnect.ctl](../examples/05-subscribe/06_alertConnect.ctl)
— две временные точки, 65 проверок: область подписки, `answer`, пары
«имя-значение», `dyn_string`, квитирование, дубликаты, объектная форма,
молчащие атрибуты и сравнение с подпиской на запрос по классу тревоги.

---

## Связи

```
dpConnect() ─┬─▶ ответ сразу (answer = TRUE)
             └─▶ по каждому изменению
dpConnectUserData() ─▶ то же + свои данные (userData)
dpDisconnect() / dpDisconnectUserData() ─▶ снять подписку (только в том же скрипте)

dpQueryConnectSingle() ─▶ SQL-запрос, в колбэк только изменившиеся строки
dpQueryConnectAll()    ─▶ SQL-запрос, в колбэк вся текущая выборка
dpQueryDisconnect()    ─▶ снять подписку по паре "колбэк + userData"

alertConnect()    ─▶ события тревог ВСЕХ точек (фильтр только в колбэке)
alertDisconnect() ─▶ снять подписку (параметра answer нет)

dpWaitForValue() ─▶ разовая блокирующая подписка ([04-write.md](04-write.md#dpWaitForValue))
```

Разовые SQL-запросы (`dpQuery`, `checkQuery`) — в [06-query.md](06-query.md).
Подписки на запросы теперь относятся к этому разделу, а не к 06.

Ограничение размера сообщений подписки — `maxConnectMessageSize`:
см. [00-model.md](00-model.md#8-ограничения-о-которых-надо-знать-заранее).