# 08. Атрибуты тревог

Раздел закрывает 10 функций работы с атрибутами тревог. Для каждой есть
самодостаточный пример в `examples/08-alerts/`: он сам создаёт временную точку
данных, взводит на ней тревогу, выполняет проверки, квитирует её и удаляет точку.
Демо-точка `System1:ExampleDP_AlertHdl1.` не используется и не изменяется.

Запуск одного примера и всего раздела:

```powershell
cd SKILL\examples
.\verify.ps1 -Script .\08-alerts\01_alertGet.ctl
.\verify.ps1 -Section 08-alerts
```

Тревога (`alert`) идентифицируется **не только** точкой данных, но и **временем
возникновения** и **порядковым номером**. Поэтому у всех функций этого этапа первые
параметры — время `t` и номер `count`.

Полный перечень атрибутов конфига `_alert_hdl` — в
[03-read.md](03-read.md#читаемые-атрибуты-_alert_hdl).

---

## Настройка `_alert_hdl` для примеров

У всех примеров раздела одна и та же подготовка: тип `ExampleDP_DDE`, именованный
bool-элемент `b1`, бинарная тревога по значению `TRUE`.

```c
string base = "dptest_alert_08_01";   // имя точки — без точки на конце
string dpe  = base + ".b1";           // рабочий DPE — с элементом
dpCreate(base, "ExampleDP_DDE");
dpSetWait(dpe + ":_original.._value", FALSE);

// 1. Снять обработку, чтобы менять настройки на «спокойной» точке.
dpSetTimedWait(0, dpe + ":_alert_hdl.._active", FALSE);

// 2. Настроить и включить обработку.
dpSetTimedWait(0,
  dpe + ":_alert_hdl.._type",     DPCONFIG_ALERT_BINARYSIGNAL,   // 12
  dpe + ":_alert_hdl.._class",    "System1:alert.",
  dpe + ":_alert_hdl.._text0",    "OK",
  dpe + ":_alert_hdl.._text1",    "ALARM",
  dpe + ":_alert_hdl.._orig_hdl", TRUE);
dpSetTimedWait(0, dpe + ":_alert_hdl.._active", TRUE);

// 3. Взвести тревогу «плохим» значением.
dpSetWait(dpe + ":_original.._value", TRUE);   // CAME: _act_range = 1
```

Порядок обязателен: **сначала `_active=FALSE`, потом настройка, потом
`_active=TRUE`**. Если менять `_class`, `_type` или тексты на включённом
обработчике, часть изменений не применяется к уже существующему экземпляру
тревоги. Снять неквитированную тревогу можно двумя способами: квитировать её либо
выключить `_active` — второй способ и используется в уборке.

Класс фиксирован: `System1:alert.` (`_ack_type = 3`,
`ACKNOWLEDGEMENT_PAIR`; `_archive = TRUE`, `_archive_time = 31536000` — год).
Создать собственный класс тревоги скриптом на стенде не удалось: точка
`_AlertClass` создаётся, но конфиг `_alert_class` не появляется, а запись
`_ack_type` даёт `PARAM,WARNING,9`. Если класса `System1:alert.` в проекте нет,
примеры печатают `SKIP` и не считают это ни `PASS`, ни `FAIL`.

> ### ⛔ Жёсткое правило: нулевая дата
>
> Ни один `alertSet*()` не вызывается, пока не проверены **оба** условия:
> `t != 0` **и** `At != 0`. Тревога с нулевой датой ломает связность сегментов
> базы, и починить это задним числом нельзя. Проверки только `At != 0`
> недостаточно: `setACount()` умеет сделать пустой `atime` ненулевым (см. ниже).
>
> ```c
> if (t != 0 && At != 0)
>   alertSet(t, getACount(At), dpe + ":_alert_hdl.._comment", "текст");
> ```
>
> В уборке то же условие: если оно не выполнено, квитирование не делается, а
> точка гасится через `_alert_hdl.._active = FALSE`.

Готовые помощники (`alertDemoCreate`, `alertDemoCame`, `alertDemoAtime`,
`alertDemoGone`, `alertDemoDrop`) лежат в `examples/_lib.ctl` и дословно
скопированы в каждый пример.

---

## Ключевая идея: `atime`

Тип `atime` — это структура «время тревоги»: время + порядковый номер + имя точки
данных. Собирается `makeATime()`, разбирается `getACount()`, `getAIdentifier()`,
`setACount()`, `setAIdentifier()`.

```c
int makeATime(time t, int count, string dpe);   // собрать
int getACount(atime At);                        // номер
string getAIdentifier(atime At);                // имя точки
```

**Для живой тревоги `atime` берётся не из `makeATime()`, а из
`_alert_hdl.._alerts`.** Это `dyn_atime` со всеми текущими экземплярами тревог
точки, у каждого — свой точный счётчик:

```c
time t;
dpGet(dpe + ":_original.._stime", t);            // время текущей стороны тревоги
dyn_atime al;
dpGet(dpe + ":_alert_hdl.._alerts", al);          // точные atime

atime At = 0;
for (int i = 1; i <= dynlen(al); i++)             // ищем CAME
{
  dyn_anytype dir;
  if (alertGet(al[i], getACount(al[i]), dpe + ":_alert_hdl.._direction", dir) == 0
      && dynlen(dir) == 1 && (bool)dir[1])
  {
    At = al[i];
  }
}
```

Почему это важно. `makeATime(t, 0, dpe)` всегда ставит номер `0`, а у реальной
тревоги номер может быть `1` и больше (например, если на точке уже была тревога).
`alertSet()` и `alertGet()` с несуществующей парой «время + номер» возвращают
`rc = 0` и **молча ничего не делают** — ни ошибки, ни признака в результате. На
стенде это выглядело как «запись иногда не срабатывает»: время совпадало до
миллисекунды, а номер — нет.

---

## alertGet()

**Синопсис**

```c
int alertGet(time t, int count, string dp, anytype &value
             [, time t2, int count2, string dp2, anytype &value2, ...]);
int alertGet(time t, int count, dyn_string dps, dyn_anytype &values);
```

**Назначение.** Читает атрибуты **экземпляра тревоги**, адресованного парой
«время + номер». Это единственный штатный способ прочитать атрибуты, у которых в
таблице конфига пустая колонка `dpGet` (например, `_ack_state`, `_ack_oblig`).

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `t1` | `time` | да | Время возникновения тревоги | `t` |
| `count1` | `int` | да | Порядковый номер | `getACount(At)` |
| `dp1` | `string` | да | DPE с атрибутом тревоги | `dpe + ":_alert_hdl.._act_state"` |
| `value1` | `anytype` | да, **ref** | Возвращённое значение | `v` |
| `dps` | `dyn_string` | форма 2 | Список DPE | `attrs` |
| `values` | `dyn_anytype` | форма 2 | Значения | `vals` |

**Возврат.** `0` — успех, `-1` — ошибка.

> **Ограничение на `dyn`-форму.** Все записи `dps` должны указывать на **одну и ту же
> тревогу** и могут отличаться только атрибутом. То есть
> `SYSTEM:DATAPOINT.ELEMENT:CONFIG.DATATYPE` должны быть равны.

**Исторические тревоги.** Те тревоги, которые настроены как «не удаляемые», тоже
запрашиваются этой функцией.

> **Для всех не-логических тревог используйте `alertGetPeriod()`**, а не `alertGet()`.

```c
dyn_anytype v;
int rc = alertGet(t, getACount(At), dpe + ":_alert_hdl.._act_state", v);
if (rc == 0 && dynlen(v) == 1)
  DebugN("_act_state =", (int)v[1]);

// dyn-форма: три атрибута одной тревоги
dyn_string attrs = makeDynString(
    dpe + ":_alert_hdl.._act_state",
    dpe + ":_alert_hdl.._ack_oblig",
    dpe + ":_alert_hdl.._value");
dyn_anytype vals;
rc = alertGet(t, getACount(At), attrs, vals);   // rc=0, dynlen(vals)==3
```

**Скрипт.** `examples/08-alerts/01_alertGet.ctl` ✅ проверено, 22/22

**Типичные ошибки**

* Читать `_ack_state`/`_ack_oblig` через `dpGet()`. `dpGet` по `_ack_state`
  **не записывает переменную вовсе** (она остаётся прежней), а по `_ack_oblig`
  отдаёт конфиг `FALSE` вместо значения экземпляра `TRUE`. Трактовать такие
  значения нельзя — нужен `alertGet()`.
* Брать `atime` из `makeATime(t, 0, dpe)` для живой тревоги (см. «Ключевая идея»).
* Обращаться к `v[1]` без проверки `dynlen(v) == 1`: для несуществующего
  атрибута или тревоги функция возвращает `rc = 0` и **пустой** `dyn_anytype`.

---

## alertSet()

**Синопсис**

```c
int alertSet(time t1, int count1, string dp1, anytype value1
             [, time t2, ... ]);
```

**Назначение.** Пишет атрибут **конкретного экземпляра тревоги**. Работает как
`dpSet()`, но адресует не значение точки данных, а запись тревоги.

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `t1` | `time` | да | Время возникновения тревоги | `t` |
| `count1` | `int` | да | Порядковый номер | `getACount(At)` |
| `dp1` | `string` | да | DPE с атрибутом тревоги | `dpe + ":_alert_hdl.._ack_state"` |
| `value1` | `anytype` | да | Значение | `DPATTR_ACKTYPE_SINGLE` |

**Возврат.** `0` — успех, `-1` — ошибка.

**Ошибки.** Ошибки CTRL-менеджера — сразу через `getLastError()`. Ошибки от Event
Manager видны через `getLastError()` **только** при использовании waiting-функций
(см. `alertSetWait()`). Для NGA `rc = 0` не доказывает, что запись дошла, —
результат проверяется чтением через `alertGet()`.

### Пример: комментарий и квитирование

```c
if (t != 0 && At != 0)
{
  alertSet(t, getACount(At), dpe + ":_alert_hdl.._comment", "alertSet demo");
  alertSet(t, getACount(At), dpe + ":_alert_hdl.._ack_state",
           DPATTR_ACKTYPE_SINGLE);
}
delay(0.5);

int ast = 0;
dpGet(dpe + ":_alert_hdl.._act_state", ast);   // 2 — CAME квитирована
```

**Измерено на стенде.** После `alertSet(_ack_state, DPATTR_ACKTYPE_SINGLE)`
функция вернула `rc = 0`, `_act_state` стал `2` (CAME acknowledged), а
`alertGet(_ack_state)` вернул `2` (single acknowledgement). Комментарий,
записанный `alertSet`, читается обратно тем же адресом.

**Скрипт.** `examples/08-alerts/02_alertSet.ctl` ✅ проверено, 16/16

**Типичные ошибки**

* Считать `rc = 0` доказательством записи. При неверном `atime` (например,
  `count` не совпал) запись не выполняется, но `rc` остаётся `0`. Проверяйте
  результат через `alertGet()`.
* Писать `_ack_state` в атрибут конфига (`:_alert_hdl.._ack_state` — это
  экземпляр; номер диапазона для бинарной тревоги не нужен).
* Вызывать без защиты `t != 0 && At != 0`.

---

## alertSetWait()

**Синопсис**

```c
int alertSetWait(time t1, int count1, string dp1, anytype value1
                 [, time t2, ... ]);
```

`alertSet()`, но **блокирующая** — ждёт ответ Event Manager.

> **Ограничение с NextGen Archiver (NGA).** Функция **не проверяет**, что тревога
> действительно записана в базу, и поэтому **всегда возвращает `0`**. Проверять
> запись нужно отдельно (`alertGet()`).

```c
int rc = -1;
if (t != 0 && At != 0)
  rc = alertSetWait(t, getACount(At), dpe + ":_alert_hdl.._comment", "wait");

dyn_anytype v;
int rcGet = alertGet(t, getACount(At), dpe + ":_alert_hdl.._comment", v);
// успех: rcGet == 0 && dynlen(v) == 1 && (string)v[1] == "wait"
```

**Скрипт.** `examples/08-alerts/03_alertSetWait.ctl` ✅ проверено, 9/9

**Типичные ошибки**

* Проверять только `rc`: с NGA он всегда `0`. Результат — чтением.

---

## alertSetTimed()

**Синопсис**

```c
int alertSetTimed(time alerttime, time t1, int count1, string dp1, anytype value1
                  [, time t2, ... ] );
```

**Назначение.** `alertSet()` + **ручная установка временной метки**. Первый
параметр — не время поиска тревоги, а значение, которое записывается в атрибут.
Тревога по-прежнему адресуется парой `(t1, count1)`.

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `alerttime` | `time` | да | Метка, которая будет записана | `acktime` |
| `t1` | `time` | да | Время возникновения тревоги | `t` |
| `count1` | `int` | да | Порядковый номер | `getACount(At)` |
| `dp1` | `string` | да | DPE с атрибутом тревоги | `dpe + ":_alert_hdl.._ack_time"` |
| `value1` | `anytype` | да | Значение | `DPATTR_ACKTYPE_SINGLE` |

**Возврат.** `0` — успех, `-1` — ошибка.

```c
time acktime = getCurrentTime();
if (t != 0 && At != 0)
  alertSetTimed(acktime, t, getACount(At),
                dpe + ":_alert_hdl.._ack_state", DPATTR_ACKTYPE_SINGLE);
```

**Измерено на стенде.** `alertSetTimed` записал переданный `acktime` в
`_ack_time` — `alertGet` вернул ровно это значение (до наносекунд). Поэтому
`alertSetTimed` пригоден именно для подстановки своей метки, а не для «записи
задним числом»: время самой тревоги (`t`, `count`) не меняется.

**Скрипт.** `examples/08-alerts/04_alertSetTimed.ctl` ✅ проверено, 13/13

**Типичные ошибки**

* Передать `alerttime = 0`. Метка попадёт в запись как нулевая дата.
* Думать, что первый параметр ищет тревогу. Ищет пара `(t1, count1)`.

---

## alertSetTimedWait()

**Синопсис**

```c
int alertSetTimedWait(time alerttime, time t1, int count1, string dp1, anytype value1
                      [, time t2, ... ] );
```

`alertSetTimed()`, но **блокирующая**. Пример идентичен `alertSetTimed()`, вызов
заменяется на `alertSetTimedWait()`.

**Скрипт.** `examples/08-alerts/05_alertSetTimedWait.ctl` ✅ проверено, 13/13

**Типичные ошибки**

* Те же, что у `alertSetTimed()`, плюс ограничение NGA из `alertSetWait()`:
  проверяйте запись через `alertGet()`.

---

## isAlertAttribute()

**Синопсис**

```c
bool isAlertAttribute(string attr);
```

Проверяет, является ли атрибут **атрибутом тревоги** — то есть запрашивается ли он
через `alertGetPeriod()` / `alertConnect()` / `SELECT ALERT` либо записывается ли
через `alertSet()`.

**Возврат.** `TRUE` — да, `FALSE` — нет.

> **Известное исключение.** Из-за особого поведения виртуальных атрибутов
> `isAlertAttribute()` возвращает `FALSE` для атрибута `_event`, хотя его
> **обязаны** писать через `alertSet()`.

```c
main()
{
  string dpe = "System1:ExampleDP_DDE.b1";
  DebugN(isAlertAttribute(dpe + ":_alert_hdl.._ack_state"));        // TRUE
  DebugN(isAlertAttribute(dpe + ":_alert_hdl.._alert_fore_color")); // TRUE
  DebugN(isAlertAttribute(dpe + ":_alert_hdl.._event"));            // FALSE (исключение)
  DebugN(isAlertAttribute(dpe + ":_archive.._archive"));            // FALSE
  DebugN(isAlertAttribute(dpe + ":_original.._value"));             // FALSE
}
```

**Практическая польза.** Позволяет проверить атрибут **до** того, как строить вызов
`alertSet()` — иначе получите ошибку в рантайме.

**Измерено на стенде.** Голые имена без DPE (`"_ack_state"`, `"_value"`) тоже дают
`TRUE` — проверка по одному имени не различает конфиг и значение. Указывайте DPE
целиком.

**Скрипт.** `examples/08-alerts/06_isAlertAttribute.ctl` ✅ проверено, 9/9

---

## getACount()

**Синопсис**

```c
int getACount(atime AlertTime);
```

Возвращает порядковый номер тревоги, записанный в `atime`. Нумерация **с нуля**.
Номер — часть адреса: `(время, номер)` вместе указывают на экземпляр тревоги.

**Возврат.** Номер тревоги, `-1` при ошибке. При ошибке список классов ошибок **не
заполняется**.

Актуально, когда в один момент по одному элементу данных возникло несколько тревог
(например, при `dpQuery("SELECT ALERT ...")`).

```c
int count = getACount(At);                    // точный номер из _alert_hdl.._alerts
if (alertGet(t, count, dpe + ":_alert_hdl.._direction", v) == 0 && dynlen(v) == 1)
  DebugN("CAME direction:", (bool)v[1]);

// неверный номер тревогу не находит: rc=0, dyn_anytype пуст
atime Wrong = At;
setACount(Wrong, (count == 0) ? 1 : 0);
alertGet(t, getACount(Wrong), dpe + ":_alert_hdl.._direction", v);   // dynlen(v) == 0
```

**Измерено на стенде.** На свежей точке номер первой тревоги — `0`; если на точке
уже была тревога, `_alerts` отдаёт `atime` с номером `1`. `atime` ведёт себя как
значение: `setACount` на копии не меняет исходный `At`.

**Скрипт.** `examples/08-alerts/07_getACount.ctl` ✅ проверено, 19/19

**Типичные ошибки**

* Считать, что номер всегда `0`. Он может быть любым; берите его из
  `_alert_hdl.._alerts`.
* Проверять «нашлась ли тревога» по `rc`. Неверный номер даёт `rc = 0` и пустой
  `dyn_anytype`.

---

## setACount()

**Синопсис**

```c
int setACount(atime &AlertTime, uint AlertNo);
```

Записывает номер тревоги **внутрь** структуры `atime`.

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `AlertTime` | `atime` | да, **ref** | Время тревоги | `At` |
| `AlertNo` | `uint` | да | Номер тревоги | `7` |

**Возврат.** `0` — успех, `-1` — ошибка (нет/неверные аргументы).

```c
atime At = makeATime(makeTime(1999, 8, 23, 10, 52, 46), 0,
                     "System1:ExampleDP_DDE.b1");
setACount(At, 2);
DebugN(getACount(At));   // 2
```

> **Неточность примера в документации.** Функция объявлена как принимающая
> `atime &`, но пример передаёт `time`. Для единообразия с остальным кодом
> (`makeATime()`) корректно работать с переменной типа `atime`.

**Измерено на стенде.** `setACount` на **пустом** `atime` вернул `rc = 0` и сделал
его ненулевым, но с датой 1970 года:

```c
atime Z;                       // Z == 0
setACount(Z, 5);               // rc=0
(string)Z;                     // "1970.01.01 03:00:00.000"
```

Такой `atime` проходит проверку `At != 0` и **не должен** попадать в
`alertSet*()`. Отсюда требование проверять ещё и `t != 0`.

**Скрипт.** `examples/08-alerts/08_setACount.ctl` ✅ проверено, 11/11

**Типичные ошибки**

* Передать пустой `atime` и потом удивляться дате 1970 года.
* Забыть, что номер — часть адреса: после записи «чужого» номера тревога больше
  не находится.

---

## getAIdentifier()

**Синопсис**

```c
string getAIdentifier(atime AlertTime);
```

Возвращает имя, записанное в `atime`. Для именованного элемента это DPE с
элементом и завершающей точкой:

```c
atime At = makeATime(getCurrentTime(), 0, "System1:ExampleDP_DDE.b1");
getAIdentifier(At);   // "System1:ExampleDP_DDE.b1."
```

**Возврат.** Имя точки данных или **пустая строка** при ошибке. При ошибке список
классов ошибок **не заполняется**.

```c
dyn_atime al;
dpGet(dpe + ":_alert_hdl.._alerts", al);
for (int i = 1; i <= dynlen(al); i++)
  DebugN("DPE:" + getAIdentifier(al[i]), "AlertID:" + getACount(al[i]));
```

**Измерено на стенде.** Две точки на конце (`System1:ExampleDP_AlertHdl1..`)
получаются только у точки данных без элементов, где DPE уже оканчивается точкой.
Это не ошибка 3.18, а следствие формата имени; в примерах используется именованный
элемент `b1`.

**Скрипт.** `examples/08-alerts/09_getAIdentifier.ctl` ✅ проверено, 8/8

---

## setAIdentifier()

**Синопсис**

```c
int setAIdentifier(atime &alertTime, string dpid);
```

Записывает имя точки данных в структуру времени тревоги.

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `alertTime` | `atime` | да, **ref** | Время тревоги | `At` |
| `dpid` | `string` | да | Имя точки данных | `"System1:ExampleDP_DDE.b1"` |

**Возврат.** `0` — успех, `-1` — ошибка.

```c
atime At = makeATime(getCurrentTime(), 0, "System1:ExampleDP_DDE.b1");
setACount(At, 17);
setAIdentifier(At, "System1:ExampleDP_DDE.b1");   // rc=0
DebugN(getAIdentifier(At));                        // "System1:ExampleDP_DDE.b1."
```

**Измерено на стенде.** Существующий DPE принимается (`rc = 0`, завершающая точка
добавляется). Полная строка атрибута сохраняется дословно. Несуществующее имя —
`rc = -1` с `DP does not exist`. На **пустом** `atime` — `rc = 0`, имя
записывается, но время остаётся нулевым: пригодным для `alertSet*()` такой
`atime` не становится (в отличие от `setACount`).

**Скрипт.** `examples/08-alerts/10_setAIdentifier.ctl` ✅ проверено, 10/10

**Типичные ошибки**

* Передать несуществующий DPE — `rc = -1`.
* Проверять только `rc` на пустом `atime`: имя запишется, но адрес тревоги
  останется нулевым.

---

## Измерено на стенде (CTL 3.18)

| Что проверялось | Результат |
| --- | --- |
| Точный `atime` живой тревоги | `dpGet(dpe + ":_alert_hdl.._alerts", dyn_atime)`; счётчик может быть `0` или `1` |
| `makeATime(t, 0, dpe)` для живой тревоги | может дать счётчик `0` при реальном `1` → `alertSet`/`alertGet` молча ничего не делают (`rc=0`) |
| `_ack_state`, `_ack_oblig` | атрибуты экземпляра тревоги; только `alertGet`/`alertConnect`/`SELECT ALERT`, у обоих в таблице конфига пустая колонка `dpGet` |
| `dpGet` по `_ack_state` | переменная **не меняется** (значение не записывается) |
| `dpGet` по `_ack_oblig` | отдаёт конфиг `FALSE`, а экземпляр — `TRUE` |
| `_ack_type = 3` (`System1:alert.`) | `ACKNOWLEDGEMENT_PAIR`: квитируется пара |
| CAME квитирована → WENT | у WENT `_ack_oblig = FALSE`, `_act_state` сразу `0` |
| CAME **не** квитирована → WENT | `_act_state = 3`, у WENT `_ack_oblig = TRUE`; квитирование этой стороны даёт `_act_state = 0` |
| `_original.._stime` после WENT | меняется на время WENT — время CAME читать **до** WENT |
| `getATime()` | в 3.18 отсутствует: `Function not defined` |
| `alertGet` по несуществующей тревоге/атрибуту | `rc = 0` и пустой `dyn_anytype`; перед `v[1]` нужна проверка `dynlen(v) == 1` |
| `alertSetTimed(acktime, ...)` | пишет `acktime` в `_ack_time`; `alertGet` возвращает ровно переданное значение |
| `setACount` на пустом `atime` | `rc = 0`, `atime` становится ненулевым с датой 1970 года |
| `setAIdentifier` на пустом `atime` | `rc = 0`, имя пишется, время остаётся `0` |
| `isAlertAttribute` | `TRUE` для `_ack_state`, `_alert_fore_color`; `FALSE` для `_archive`, `_original.._value`, `_event`; голые имена тоже `TRUE` |
| Класс `System1:alert.` | `_ack_type=3`, `_archive=TRUE`, `_archive_time=31536000` (год) |

**След на стенде.** Все примеры квитируют тревоги перед удалением точки (или
гасят `_active`), поэтому живых точек и неквитированных тревог не остаётся. Класс
архивирует тревоги на год, поэтому в архиве NGA после полного прогона остаются
квитированные тестовые тревоги — до 6 за прогон (по одной на алертный пример).
Это осознанная цена проверки на живом стенде. Страховочная уборка — раздел `1b` в
`examples/cleanup_stand.ctl`.

---

## Связи

```
dpGet(dpe + ":_alert_hdl.._act_range")   ──▶ какой диапазон тревоги активен
dpGet(dpe + ":_original.._stime")        ──▶ время текущей стороны тревоги
dpGet(dpe + ":_alert_hdl.._alerts")      ──▶ точные atime экземпляров тревог
alertGet(a, getACount(a), attr)          ──▶ прочитать атрибут экземпляра
alertSet() / alertSetWait()              ──▶ записать атрибут тревоги
alertSetTimed() / alertSetTimedWait()    ──▶ то же с ручной меткой времени
isAlertAttribute()                       ──▶ проверить атрибут до вызова

getAIdentifier() / setAIdentifier()      ──▶ имя точки данных в atime
setACount() / getACount()                ──▶ номер тревоги в atime
```

Чтение атрибутов `_alert_hdl` обычным `dpGet()` — [03-read.md](03-read.md#читаемые-атрибуты-_alert_hdl).

---

Подписка на тревоги — [05-subscribe.md](05-subscribe.md).

Архив тревог NGA лежит в InfluxDB; прочитать его напрямую по HTTP (только
чтение) — [15-influx.md](15-influx.md).
