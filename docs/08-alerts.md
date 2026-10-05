# 08. Атрибуты тревог

> ## ⛔ Раздел вне объёма работ
>
> **Демонстрационные скрипты не создаются (10 штук):** 01_....ctl …
> 10_....ctl. Исключено по решению владельца стенда.
>
> Причина практическая: на стенде не настроены аварийные границы, классы и
> обработчики. Без них функции этого этапа проверять не на чем, а писать
> примеры вслепую — значит выпустить код, который выглядит рабочим и не
> является. Материал ниже остаётся как справочная заметка.
>
> Атрибуты конфига `_alert_hdl` разобраны на других этапах: полный перечень — в
> [03-read.md](03-read.md#читаемые-атрибуты-_alert_hdl).

---


Тревога (`alert`) идентифицируется **не только** точкой данных, но и **временем
возникновения** и **порядковым номером**. Поэтому у всех функций этого этапа первые
параметры — время `t` и номер `count`.

Полный перечень атрибутов конфига `_alert_hdl` — в
[03-read.md](03-read.md#читаемые-атрибуты-_alert_hdl).

---

---

## Ключевая идея: `atime`

Тип `atime` — это структура «время тревоги»: время + порядковый номер + имя точки
данных. Создаётся через `makeATime()` и разбирается функциями `getACount()`,
`getAIdentifier()`, `setACount()`, `setAIdentifier()`.

Типичный цикл работы с тревогой:

```c
// 1. узнать время тревоги
dpGet(dpe + ":_online.._stime", t);
// 2. собрать atime
atime At = makeATime(t, 0, dpe);
// 3. узнать порядковый номер
int cnt = getACount(At);
// 4. записать атрибут тревоги
alertSet(t, cnt, dpe + ":_alert_hdl." + range + "._ack_state", DPATTR_ACKTYPE_SINGLE);
```

---

## alertGet()

**Синопсис**

```c
int alertGet(time t, int count, string dp, anytype &value
             [, time t2, int count2, string dp2, anytype &value2, ...]);
int alertGet(time t, int count, dyn_string dps, dyn_anytype &values);
```

**Назначение.** Читает атрибуты **последней** тревоги точки данных. Исторические
тревоги не запрашиваются.

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `t1` | `time` | да | Время возникновения | `a` (переменная `atime`) |
| `count1` | `int` | да | Порядковый номер | `getACount(a)` |
| `dp1` | `string` | да | Точка данных | `"ExampleDP_AlertHdl1.:_alert_hdl.._value"` |
| `value1` | `anytype` | да, **ref** | Возвращённое значение | `ok` |
| `dps` | `dyn_string` | форма 2 | Имена точек данных | — |
| `values` | `dyn_anytype` | форма 2 | Значения | — |

**Возврат.** `0` — успех, `-1` — ошибка.

> **Ограничение на `dyn`-форму.** Все записи `dps` должны указывать на **одну и ту же
> тревогу** и могут отличаться только атрибутом. То есть
> `SYSTEM:DATAPOINT.ELEMENT:CONFIG.DATATYPE` должны быть равны.

**Исторические тревоги.** Те тревоги, которые настроены как «не удаляемые», тоже
запрашиваются этой функцией.

> **Для всех не-логических тревог используйте `alertGetPeriod()`**, а не `alertGet()`.

```c
main()
{
  bool ok;
  atime a;
  ok = TRUE;
  dpGet("ExampleDP_AlertHdl1.:_alert_hdl.._ok_range", ok);
  alertGet(a, getACount(a), "ExampleDP_AlertHdl1.:_alert_hdl.._value", ok);
  DebugN("alertGet: atime = " + (string)a + ", value = " + ok);
}
```

**Скрипт не создан — раздел вне объёма.**

---

## alertSet()

**Синопсис**

```c
int alertSet(time t1, int count1, string dp1, anytype value1
             [, time t2, ... ]);
```

**Назначение.** Пишет атрибут **конкретной тревоги**. Работает как `dpSet()`, но
адресует не значение точки данных, а запись тревоги.

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `t1` | `time` | да | Время возникновения. **Должно быть приведено к типу `atime`** | `t` |
| `count1` | `int` | да | Порядковый номер | `getACount(At)` |
| `dp1` | `string` | да | Точка данных | `dpe + ":_alert_hdl." + range + "._ack_state"` |
| `value1` | `anytype` | да | Значение | `DPATTR_ACKTYPE_SINGLE` |

**Возврат.** `0` — успех, `-1` — ошибка.

**Ошибки.** Ошибки CTRL-менеджера — сразу через `getLastError()`. Ошибки от Event
Manager видны через `getLastError()` **только** при использовании waiting-функций
(см. `alertSetWait()`).

### Практический пример: квитирование тревоги

```c
AcknowledgeDpe(string dpe)
{
  int range;
  time t;
  atime At;

  // получить диапазон тревоги
  dpGet(dpe + ":_alert_hdl.._act_range", range);

  // получить время тревоги
  dpGet(dpe + ":_online.._stime", t);

  // привести время к типу atime
  At = makeATime(t, 0, dpe);

  // убедиться, что квитирование нужно
  if (range != 0)
    alertSet(t, getACount(At),
             dpe + ":_alert_hdl." + range + "._ack_state",
             DPATTR_ACKTYPE_SINGLE);
}
```

### Пример: принудительная фильтрация

```c
main()
{
  int retVal;
  time t = makeTime(2011, 01, 19, 14, 44, 03, 986);
  bool r;
  retVal = alertSet(t, 0,
             "System1:_mp_PUMP1.alert.controlFuse:_alert_hdl.._force_filtered", 1);
  dpGet("System1:_mp_PUMP1.alert.controlFuse:_alert_hdl.._force_filtered", r);
  DebugN("Функция успешна:", retVal, "ForceFiltered:", r);
}
```

**Скрипт не создан — раздел вне объёма.**

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
> запись нужно отдельно (`dpGet()`).

```c
main()
{
  alertSetWait(zeit, count, "Zahl_1.:_alert_hdl.._ack_state", 25);
}
```

**Скрипт не создан — раздел вне объёма.**

---

## alertSetTimed()

**Синопсис**

```c
int alertSetTimed(time alerttime, time t1, int count1, string dp1, anytype value1
                  [, time t2, ... ] );
```

**Назначение.** `alertSet()` + **ручная установка временной метки**.

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `alerttime` | `time` | да | Время, которое будет записано как timestamp | `acktime` |
| `t1` | `time` | да | Время возникновения тревоги | `alerttime` |
| `count1` | `int` | да | Порядковый номер | `getACount(At)` |
| `dp1` | `string` | да | Точка данных | `dpe + ":_alert_hdl." + range + "._ack_state"` |
| `value1` | `anytype` | да | Значение | `DPATTR_ACKTYPE_SINGLE` |

**Возврат.** `0` — успех, `-1` — ошибка.

```c
main()
{
  string dpe = "System1:ExampleDP_Arg1.";
  int range;
  time alerttime;
  time acktime;
  atime At;

  dpGet(dpe + ":_alert_hdl.._act_range", range);   // диапазон тревоги
  dpGet(dpe + ":_online.._stime", alerttime);       // время тревоги

  acktime = makeTime(2012, 12, 22, 12, 12, 12);    // время для метки
  At = makeATime(alerttime, 0, dpe);                // atime

  if (range != 0)
    alertSetTimed(acktime, alerttime, getACount(At),
                  dpe + ":_alert_hdl." + range + "._ack_state",
                  DPATTR_ACKTYPE_SINGLE);
}
```

**Скрипт не создан — раздел вне объёма.**

---

## alertSetTimedWait()

**Синопсис**

```c
int alertSetTimedWait(time alerttime, time t1, int count1, string dp1, anytype value1
                      [, time t2, ... ] );
```

`alertSetTimed()`, но **блокирующая**.

Пример идентичен `alertSetTimed()`, вызов заменяется на `alertSetTimedWait()`.

**Скрипт не создан — раздел вне объёма.**

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
  DebugN(isAlertAttribute("System1:ExampleDP_AlertHdl1.:_alert_hdl.._alert_fore_color")); // 1
  DebugN(isAlertAttribute("System1:ExampleDP_AlertHdl1.:_alert_hdl.._ack_state"));          // 1
  DebugN(isAlertAttribute("System1:ExampleDP_AlertHdl1.:_archive.._archive"));              // 0
  DebugN(isAlertAttribute("System1:ExampleDP_AlertHdl1.:_original.._value"));               // 0
}
```

**Скрипт не создан — раздел вне объёма.**

**Практическая польза.** Позволяет проверить атрибут **до** того, как строить вызов
`alertSet()` — иначе получите ошибку в рантайме.

---

## getACount()

**Синопсис**

```c
int getACount(atime AlertTime);
```

Возвращает внутренний порядковый номер тревоги в момент `AlertTime`. Нумерация **с
нуля**.

**Возврат.** Номер тревоги, `-1` при ошибке. При ошибке список классов ошибок **не
заполняется**.

Актуально, когда в один момент по одному элементу данных возникло несколько тревог
(например, при `dpQuery("SELECT ALERT ...")`).

```c
AcknowledgeDpe(string dpe)
{
  int range;
  time t;
  atime At;
  dpGet(dpe + ":_alert_hdl.._act_range", range);
  dpGet(dpe + ":_online..stime", t);
  At = makeATime(t, 0, dpe);
  if (range != 0)
    alertSet(t, getACount(At),
             dpe + ":_alert_hdl." + range + "._ack_state", DPATTR_ACKTYPE_SINGLE);
}
```

**Скрипт не создан — раздел вне объёма.**

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
| `AlertNo` | `uint` | да | Номер тревоги | `2` |

**Возврат.** `0` — успех, `-1` — ошибка (нет/неверные аргументы).

```c
main()
{
  time t;
  t = makeTime(1999, 8, 23, 10, 52, 46);
  setACount(t, 2);
  DebugN(getACount(t));   // 2
}
```

> **Неточность примера в документации.** Функция объявлена как принимающая
> `atime &`, но пример передаёт `time`. Для единообразия с остальным кодом
> (`makeATime()`) корректно работать с переменной типа `atime`:
>
> ```c
> atime At = makeATime(makeTime(1999, 8, 23, 10, 52, 46), 0, "ExampleDP_AlertHdl1.");
> setACount(At, 2);
> DebugN(getACount(At));   // 2
> ```

**Скрипт не создан — раздел вне объёма.**

---

## getAIdentifier()

**Синопсис**

```c
string getAIdentifier(atime AlertTime);
```

Возвращает имя точки данных, записанное в `atime`. Имя возвращается **до уровня
detail** — до атрибута его нужно дописать самостоятельно.

**Возврат.** Имя точки данных или **пустая строка** при ошибке. При ошибке список
классов ошибок **не заполняется**.

```c
main()
{
  dyn_atime dat_summed_alerts;   // список ожидающих тревог (DPE + время тревоги)
  dpGet("ExampleDP_SumAlert.:_alert_hdl.._summed_alerts", dat_summed_alerts);

  if (dynlen(dat_summed_alerts) == 0)
  {
    DebugN("Нет ожидающих тревог");
  }
  else
  {
    for (int i = 1; i <= dynlen(dat_summed_alerts); i++)
      DebugN("DPE:" + getAIdentifier(dat_summed_alerts[i]),
             "AlertID:" + getACount(dat_summed_alerts[i]));
  }
}
```

**Скрипт не создан — раздел вне объёма.**

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
| `alertTime` | `atime` | да, **ref** | Время тревоги | `at` |
| `dpid` | `string` | да | Имя точки данных | `"ExampleDP_AlertHdl1.:_alert_hdl.._abbr"` |

**Возврат.** `0` — успех, `-1` — ошибка.

```c
main()
{
  atime at;
  DebugN(at, getAIdentifier(at));
  setACount(at, 17);
  setAIdentifier(at, "ExampleDP_AlertHdl1.:_alert_hdl.._abbr");
  DebugN(at, getAIdentifier(at));
}
```

**Скрипт не создан — раздел вне объёма.**

---

## Связи

```
dpGet("dpe:_alert_hdl.._act_range")   ──▶ какой диапазон тревоги активен
dpGet("dpe:_online.._stime")          ──▶ время тревоги
makeATime(t, 0, dpe)                  ──▶ собрать atime
getACount(At)                         ──▶ порядковый номер
alertSet() / alertSetWait()           ──▶ записать атрибут тревоги
alertSetTimed() / alertSetTimedWait() ──▶ то же с ручной меткой времени
alertGet()                            ──▶ прочитать атрибут последней тревоги
isAlertAttribute()                    ──▶ проверить атрибут до вызова

getAIdentifier() / setAIdentifier()   ──▶ имя точки данных в atime
setACount() / getACount()             ──▶ номер тревоги в atime
```

Чтение атрибутов `_alert_hdl` обычным `dpGet()` — [03-read.md](03-read.md#читаемые-атрибуты-_alert_hdl).

---
Подписка на тревоги — [05-subscribe.md](05-subscribe.md).
