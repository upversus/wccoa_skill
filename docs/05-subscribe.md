# 05. Подписки на изменения: dpConnect и колбэки

> ## ⛔ Раздел вне объёма
>
> **Скриптов нет и не планируется.** По решению владельца стенда подписки
> исключены из объёма работ. Материал ниже остаётся как справочная заметка:
> семантика `dpConnect` в CTL 3.18 здесь описана верно и может пригодиться,
> но обещать примеры, которых не будет, нельзя.
>
> Все ссылки вида `examples/05-subscribe/NN_*.ctl` удалены. Число скриптов
> в сводке [99-reference.md](99-reference.md) уменьшено на 4.


> ## ⛔ ВНЕ ТЕКУЩЕГО ОБЪЁМА РАБОТ
>
> Этап 05 **не реализуется сейчас**. Функции `dpConnect`, `dpConnectUserData`,
> `dpDisconnect`, `dpDisconnectUserData` признаны избыточными для функционала
> планируемого скила.
>
> Материал ниже сохранён как справочный: к этапу можно вернуться позже, и тогда
> примеры и проверки будут опираться на уже разобранную модель из
> [00-model.md](00-model.md). **Демонстрационные скрипты для этого этапа не
> написаны** — при появлении в объёме работ они пишутся с нуля и сразу
> проверяются.
>
> Ограничение, которое почти наверняка понадобится при возврате:
> `maxConnectMessageSize` (см. [00-model.md, раздел 8](00-model.md#8-ограничения-о которых-надо-знать-заранее)).

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
| `answer` | `bool` | нет | `TRUE` (по умолчанию) — колбэк вызывается **сразу** при регистрации. `FALSE` — только по изменению | `TRUE` |
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
* **Не все атрибуты `_alert_hdl` доступны.** Через `dpConnect()` доступны только
  `_prior`, `_act_state_color`, `_act_state_fore_color`, `_act_state_font_style`,
  `_text` и `panel`. Остальные — через `alertConnect()`.
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

**Скрипт не создан — раздел вне объёма.**

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
| `answer` | `bool` | нет | По умолчанию `TRUE` | `TRUE` |
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

**Скрипт не создан — раздел вне объёма.**

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

**Скрипт не создан — раздел вне объёма.**

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

**Скрипт не создан — раздел вне объёма.**

---

## Связи

```
dpConnect() ─┬─▶ ответ сразу (answer = TRUE)
             └─▶ по каждому изменению
dpConnectUserData() ─▶ то же + свои данные (userData)
dpDisconnect() / dpDisconnectUserData() ─▶ снять подписку (только в том же скрипте)

dpQueryConnectAll() / dpQueryConnectSingle() ─▶ подписка по SQL-условию ([06-query.md])
dpWaitForValue() ─▶ разовая блокирующая подписка ([04-write.md](04-write.md#dpWaitForValue))
```

Ограничение размера сообщений подписки — `maxConnectMessageSize`:
см. [00-model.md](00-model.md#8-ограничения-о которых-надо-знать-заранее).