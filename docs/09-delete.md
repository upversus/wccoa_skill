# 09. Удаление и смена типа

---

## dpDelete()

**Синопсис**

```c
int dpDelete(string dpname);
```

**Назначение.** Удаляет точку данных.

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `dpname` | `string` | да | Имя удаляемой точки данных. **В распределённой системе имя должно содержать номер системы** | `"engine1"` |

**Возврат.** `0` — успех, `-1` — ошибка.

**Ошибки.** `getLastError()` — в том числе если точка данных не существует.

```c
main()
{
  string dpB = "engine1";
  int retV = dpDelete(dpB);
  DebugN(retV);
}
```

**Ожидание.** **Blocking** (Waiting Control function).

**Измерено на стенде.** `dpDelete()` **синхронный**: точка данных исчезает к
моменту возврата из функции, `dpExists()` сразу даёт `FALSE`. Документация
объявляет функцию Blocking, и это подтверждается.

Несуществующая точка и повторное удаление уже удалённой дают `rc = -1`.

**Скрипт.** `examples/09-delete/01_dpDelete.ctl` ✅ проверено, 11/11

**Типичные ошибки**

* Забыть префикс системы при удалении в распределённой установке.
* Удаление точки данных, на которую ещё висят подписки — сначала снимите их.
* Удалять точку данных, созданную не вами. Функция безусловна — никакой проверки
  «а точно это тестовая точка?» в ней нет.

> **Ошибка в документации 3.21.6.** В разделе Return Value написано
> «dpCreate() returns 0…» — очевидная описка, описывающая `dpDelete()`. Код возврата
> трактуется как `0` / `-1`.

---

## dpTypeDelete()

**Синопсис**

```c
int dpTypeDelete(string dpt);
```

**Назначение.** Удаляет тип точки данных.

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `dpt` | `string` | да | Имя типа точки данных | `"valve"` |

**Возврат.** `0` — успех, `-1` — ошибка.

**Предусловие.** **Все точки данных этого типа должны быть удалены**, иначе ошибка.

```c
main()
{
  int n = dpTypeDelete("valve");
  DebugN(n);
  if (n == 0) DebugN("Тип точки данных удалён");
}
```

**Ожидание.** **Blocking** (Waiting Control function).

**Измерено на стенде.** Тип с живыми точками данных удалить нельзя:
`dpTypeDelete()` возвращает `rc = -1`, тип остаётся на месте. После удаления
точек в правильном порядке тип удаляется сразу, без ожидания — функция
синхронная, как и объявлено.

**Скрипт.** `examples/09-delete/02_dpTypeDelete.ctl` ✅ проверено, 12/12

**Типичные ошибки**

* Попытка удалить тип при живых точках данных — ошибка. Сначала:
  `dpNames("*", "valve")` → `dpDelete()` для каждой → `dpTypeDelete()`.
* Перепутаны `dpDelete` и `dpTypeDelete` (оба возвращают `0`/`-1`, но делают
  разные вещи).

---

## dpTypeChange()

**Синопсис**

```c
int dpTypeChange(dyn_dyn_string names, dyn_dyn_int types
                 [, dyn_string elementNames]);
```

**Назначение.** Изменяет структуру существующего DPT: типы элементов и их имена.

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `names` | `dyn_dyn_string` | да | Имена элементов, та же разреженная структура, что и в `dpTypeCreate()` | `xxdepes` |
| `types` | `dyn_dyn_int` | да | Типы элементов, структура должна совпадать со структурой DPT | `xxdepei` |
| `elementNames` | `dyn_string` | нет | Переименование: пары «старый путь», «новое имя» | `makeDynString("valve.defaults.regratio","regratio_renamed")` |

**Возврат.** `0` — успех, `-1` — ошибка.

**Ошибки.** `getLastError()`; сообщение при неверных именах типов или отсутствии
аргументов.

### Пример: смена типа элемента `regratio` с float на int

Структура та же, что у [`dpTypeCreate()`](01-create.md#dptypecreate), только вместо
`DPEL_FLOAT` в нужной позиции стоит `DPEL_INT`:

```c
main()
{
  int n;
  dyn_dyn_string xxdepes;
  dyn_dyn_int xxdepei;

  xxdepes[1]  = makeDynString("valve","","","");
  xxdepes[2]  = makeDynString("","defaults","","");
  xxdepes[3]  = makeDynString("","","regratio","");
  xxdepes[4]  = makeDynString("","returns","","");
  xxdepes[5]  = makeDynString("","","faults","");
  xxdepes[6]  = makeDynString("","","","id");
  xxdepes[7]  = makeDynString("","","","text");
  xxdepes[8]  = makeDynString("","","states","");
  xxdepes[9]  = makeDynString("","","","endpos_open");
  xxdepes[10] = makeDynString("","","","motor_running");
  xxdepes[11] = makeDynString("","","","endpos_closed");
  xxdepes[12] = makeDynString("","","regratio","");

  xxdepei[1]  = makeDynInt(DPEL_STRUCT);
  xxdepei[2]  = makeDynInt(0,DPEL_STRUCT);
  xxdepei[3]  = makeDynInt(0,0,DPEL_INT);        // ← было DPEL_FLOAT, стало DPEL_INT
  xxdepei[4]  = makeDynInt(0,DPEL_STRUCT);
  xxdepei[5]  = makeDynInt(0,0,DPEL_STRUCT);
  xxdepei[6]  = makeDynInt(0,0,0,DPEL_BIT32);
  xxdepei[7]  = makeDynInt(0,0,0,DPEL_STRING);
  xxdepei[8]  = makeDynInt(0,0,DPEL_STRUCT);
  xxdepei[9]  = makeDynInt(0,0,0,DPEL_BOOL);
  xxdepei[10] = makeDynInt(0,0,0,DPEL_BOOL);
  xxdepei[11] = makeDynInt(0,0,0,DPEL_BOOL);
  xxdepei[12] = makeDynInt(0,0,DPEL_INT);

  n = dpTypeChange(xxdepes, xxdepei);
  DebugN("Тип точки данных изменён, результат: ", n);
}
```

### Пример: переименование элементов

Задаётся **полный путь** элемента, который переименовывается:

```c
main()
{
  dyn_dyn_string names;
  dyn_dyn_int types;
  dyn_string elementNames;

  names[1][1] = "valve";
  elementNames = makeDynString("valve.defaults.regratio", "regratio_renamed",
                               "valve.defaults",           "defaults_renamed");
  dpTypeChange(names, types, elementNames);
}
```

**Ожидание.** **Blocking** (Waiting Control function).

### Две ловушки, найденные на стенде

**1. Путь для переименования начинается с имени ТИПА, а не точки данных.**

В примере документации `makeDynString("valve.defaults.regratio", …)` — это
путь от типа `valve`. Если подставить имя точки данных, переименование **молча
ничего не делает**, при этом `dpTypeChange()` возвращает `rc = 0`.

**2. Код возврата недостоверен.**

Недопустимый тип элемента (например `999`) приводит к внутренней ошибке
`changeType unmoeglich` и `Unknown Element Type` в журнале, но
`dpTypeChange()` возвращает **`rc = 0`**. Структура при этом не меняется.

Значит проверять результат только по `rc` **нельзя** — после вызова нужно
сверять структуру, например через `dpTypeGet()` или `dpElementType()`.

Пустая структура `names`/`types` отвергается корректно: `rc = -1`.

**Проверено:** `examples/09-delete/03_dpTypeChange.ctl`, 18/18.

**Скрипт.** `examples/09-delete/03_dpTypeChange.ctl` ✅ проверено, 18/18

**Типичные ошибки**

* `types` не совпадает по структуре с текущим DPT — DPE «поедут».
* Переименование без полного пути — элемент не найден.
* Смена типа на несовместимый (`float` → `bool`) обрушивает значения существующих
  точек данных. **Перед `dpTypeChange()` делайте `dpCopy()` или выгружайте значения.**

---

## Связи

```
dpDelete()      ──▶ удалить точку данных (blocking)
dpTypeDelete()  ──▶ удалить тип; сначала удалите все точки этого типа
dpTypeChange()  ──▶ изменить структуру типа (blocking)

dpCopy()        ──▶ сделать бэкап перед сменой типа ([07-copy.md](07-copy.md))
dpCopyOriginal()──▶ скопировать значения перед сменой ([04-write.md](04-write.md#dpcopyoriginal))
```

Создание — [01-create.md](01-create.md).