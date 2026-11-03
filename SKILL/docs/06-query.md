# 06. SQL-запросы и подписки по условию

> ## Объём этапа
>
> **Реализованы и проверены на стенде (2 функции):**
> `dpQuery` — `examples/06-query/01_dpQuery.ctl`, 19/19;
> `checkQuery` — `examples/06-query/02_checkQuery.ctl`, 14/14.
>
> **Вне объёма (8 функций):** `dpQueryConnectAll`, `dpQueryConnectSingle`,
> `dpQueryDisconnect`, `dpGetAllAliases`, `dpAliases`, `dpGetAllDescriptions`,
> `dpGetAllComments`, `getAllDpAliases`. Подписки на запросы исключены
> отдельно; этап `05-subscribe` при этом реализован в части `dpConnect` и
> `dpConnectUserData`. Справочные описания остаются ниже.
>
> Функции поиска и фильтрации — `dpNames()`, `dpTypeName()`, `dpGetAlias()`,
> `dpAliasToName()`, `dpGetAllDescriptions()` — разобраны на других этапах
> ([01-create.md](01-create.md), [03-read.md](03-read.md)) и в объём работ входят.

`dpQuery()` — разовый SQL-запрос. `dpQueryConnectAll()` / `dpQueryConnectSingle()` —
подписка на всё, что подходит под условие запроса.

---

## dpQuery()

**Синопсис**

```c
int dpQuery(string query, dyn_dyn_anytype &tab);
```

**Назначение.** Выполняет SQL-`SELECT` и возвращает двумерную таблицу.

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `query` | `string` | да | SQL-оператор `SELECT` | `"SELECT '_online.._value' FROM 'ExampleDP_Arg*' WHERE _DPT= \"ExampleDP_Float\""` |
| `tab` | `dyn_dyn_anytype` | да, **ref** | Двумерная таблица результата | `tab` |

**Возврат.** `0` — успех, `-1` — ошибка.

### Структура результата

| | |
| --- | --- |
| `tab[1][1]` | **не используется** |
| `tab[1][2]` | заголовки столбцов |
| `tab[n][1]`, `n>1` | имя строки (полный идентификатор DPE) |
| `tab[n][2]`, `n>1` | значение |

Цикл обхода начинается с `2`:

```c
for (int z = 2; z <= dynlen(tab); z++) setValue(list1, "appendItem", tab[z][2]);
```

**Что можно запрашивать.** Все атрибуты конфигов, которые хранит **Event Manager**:
`_original`, `_online`, `_alert_hdl` и т.п.

```sql
SELECT '_online.._value' FROM '*'
```

**Что запрашивать нельзя.** Конфиги других менеджеров — например
`_alert_hdl.._active` вернёт пустую строку типа `anytype`.

> **Ограничение конфигов.** Подписки (connect-функции) работают только по конфигам,
> управляемым Event Manager. Нельзя подписываться на: `_archive`, `_address`,
> `_cmd_conv`, `_msg_conv`, `_smooth`.

**Особые случаи**

* В проектах с архивированием RAIMA для `TIMERANGE` допустимы времена только **до 2038 года**. Ограничение не действует для SQLite.
* `SELECT ALL` в проектах SQLite-NGA корректно возвращает ошибку — он не поддерживается.
* `_status64` можно использовать в `SELECT` с агрегатами для NGA, **без** указания
  агрегатной функции. Берётся из последнего значения в окне агрегации:
  ```sql
  SELECT '_original.._stime', 'AVG(_original.._value)', '_original.._status64'
  FROM 'MyDpe.' TIMERANGE ... SORT BY 0 GROUP BY SECS(500)
  ```

**В `WHERE` можно фильтровать по `_DP=` и `_DPT=`:**

```sql
WHERE _DP  = "..."   -- конкретная точка данных
WHERE _DPT = "..."   -- конкретный тип
```

```c
dyn_dyn_anytype tab;
dpQuery("SELECT '_online.._value' FROM 'ExampleDP_Arg*' WHERE _DPT= \"ExampleDP_Float\"", tab);
shape list1 = getShape("SELECTION_LIST1");
for (int z = 2; z <= dynlen(tab); z++) setValue(list1, "appendItem", tab[z][2]);
```

**Ошибки.** `getLastError()`. Превышение лимита результата → сообщение об ошибке,
читается через `getLastError()`.

### Что показано на стенде

| Случай | `dpQuery` | Результат |
| --- | --- | --- |
| Корректный `SELECT` | `0` | таблица: строка заголовков + данные |
| `SELEKT garbage` | `-1` | ошибка, таблица пуста |
| Запрос к несуществующей точке | **`0`** | **пустой результат, а не ошибка** |

Ошибку даёт только невалидный синтаксис. Отсутствие данных — не ошибка:
`rc` будет `0`, а таблица состоять только из строки заголовков.

### Как выглядит результат на самом деле

Документация говорит `tab[1][1]` «не используется». Фактически там не пусто,
а строка служебного идентификатора:

```
tab[1][1] = " (Type: 0 Sys: 0 Dp: 0 El: 0 : 0..0)"
tab[1][2] = ":_online.._value (Type: 0 Sys: 0 Dp: 0 El: 0 : _online.._value)"
tab[2][1] = "System1:qryDp.fVal (Type: 622 Sys: 1 Dp: 1168 El: 2 : 0..0)"
tab[2][2] = 42.5
```

То есть в **имени строки** приходит аннотация `(Type: … Sys: … Dp: … El: …)`.
Если разбирать результат по строкам, аннотацию надо отбрасывать — простое
сравнение с именем точки не сработает.

### Запрос к истории: TIMERANGE

Форма, которая однозначно отдаёт исторические данные:

```sql
SELECT '_original.._value'
  FROM 'ExampleDP_Arg1.'
  TIMERANGE("2026.10.04 13:34:18","2026.10.04 21:34:31",1,0)
  LAST 10
```

Существенные детали синтаксиса:

* в `FROM` имя точки **с закрывающей точкой** — `'ExampleDP_Arg1.'`, тогда
  берётся корень точки, а не именованный элемент;
* `TIMERANGE` принимает две строки-времени в двойных кавычках и два числа;
* `LAST 10` ограничивает число строк.

Проверено на стенде: вернулось 10 значений. Пропуск закрывающей точки в
`FROM` CTL считает допустимым и тоже даёт `0`.

**Скрипт.** `examples/06-query/01_dpQuery.ctl`

---

## checkQuery()

**Синопсис**

```c
int checkQuery(string aQuery);
```

Проверяет синтаксис запроса **без выполнения**.

| Возврат | Смысл |
| --- | --- |
| `0` | синтаксис верен |
| **`1`** | синтаксическая ошибка |

> ⚠️ **Документация была неверна.** Здесь раньше было указано `-1` при ошибке.
> На CTL 3.18 `checkQuery()` возвращает **`1`**, а не `-1`:
>
> | Запрос | `checkQuery` | `dpQuery` |
> | --- | --- | --- |
> | `SELECT '_online.._value' FROM 'chkQ'` | `0` | `0` |
> | `SELEKT garbage` | **`1`** | **`-1`** |
> | `SELECT` (обрывок) | **`1`** | `-1` |
> | `DROP TABLE …` (не `SELECT`) | **`1`** | — |
>
> У функций **разные соглашения об ошибке**. Поэтому проверять надо на
> «не равно нулю»: `if (checkQuery(q) != 0) отказ;`
> Проверка `== -1` не сработает.

```c
string start = "2017.09.01 11:25:00.000";
string stop  = "2017.09.01 11:38:00.000";
string q = "SELECT '_online.._value' FROM 'ExampleDP_Arg1' "
         + "WHERE _DPT = \"ExampleDP_Float\" "
         + "TIMERANGE(\"" + start + "\",\"" + stop + "\", 1, 0) SORT BY 1 DESC";

DebugN("checkQuery:", checkQuery(q));   // 0 = OK
dpQuery(q, tab);
```

> Вызывайте `checkQuery()` перед `dpQuery()`, если запрос строится из пользовательского
> ввода или склейкой строк. Это дешевле, чем разбирать ошибку SQL.

**Скрипт.** `examples/06-query/02_checkQuery.ctl`

---

## dpQueryConnectAll()

**Синопсис**

```c
int dpQueryConnectAll([class object,] string|function_ptr work, bool wantsanswer,
                      anytype userData, string query [, int blockingTime]);
```

**Назначение.** Подписка на все элементы, подходящие под SQL-условие. При изменении
Event Manager передаёт **все** подписанные элементы, даже если изменилось одно.

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `object` | объект CTRL++ | нет | Экземпляр класса | — |
| `work` | `string` / `function_ptr` | да | Колбэк. **Должен уметь обработать всю таблицу** | `"leaf"` |
| `wantsanswer` | `bool` | да | `TRUE` — вызвать сразу при регистрации | `TRUE` |
| `userData` | `anytype` | да | Данные в колбэк | `getUserName()` |
| `query` | `string` | да | SQL `SELECT` | `"SELECT '_original.._value' FROM 'Motor1' WHERE _LEAF"` |
| `blockingTime` | `int` | нет | Задержка вызова в мс, **≤ 32767**. `0` — не блокировать. Не задан — из `[different sections] queryHLBlockedTime` | `0` |

**Форма колбэка**

```c
void workfunc(anytype userData, dyn_dyn_anytype result);
```

**Возврат.** `0`, `-1` при ошибке. **Возврат означает лишь, что сообщение CONNECT
отправлено**, а не что запрос выполнился. Ошибка попадает в поток после выполнения —
читать `getLastError()`.

**Особенности поведения**

* При изменении значения передаются **все** запрошенные значения, а не только
  изменившееся. Ограничения вида `FIRST` / `LAST` в SQL-строке **не учитываются**.
* `blockingTime` — не «блокировка», а накопление: колбэк вызывается не сразу, а через
  указанное время, и открытые запросы передаются **одним** вызовом.
* **Если в пределах `blockingTime` менялись разные точки в разное время (например,
  три разные точки в три разных момента), таблица вернётся три раза.**
* Создание и удаление необязательных конфигов вызывает колбэк **только** если у этих
  конфигов доступен атрибут `_type`.
* Если `FROM` затрагивает более **80 %** всех DPE — регистрируется обычная подписка
  «на всё». Внутри колбэка будут использоваться только элементы, возвращённые SQL.
* **Запрещено:** `SELECT ALL`, `TIMERANGE` (обрабатывается в Event Manager) и
  `SELECT ALERT ...` — из-за производительности.
* Ошибки: отсутствующие аргументы (в т.ч. у work-функции), неопределённая функция,
  некорректные аргументы, неинициализированный `userData`.

```c
main()
{
  string query = "SELECT '_original.._value' FROM 'Motor1' WHERE _LEAF";
  anytype userData = getUserName();
  dpQueryConnectAll("leaf", TRUE, userData, query);
}

void leaf(anytype userData, dyn_dyn_anytype tab)
{
  // tab содержит ВСЮ таблицу, включая неизменившиеся значения
  for (int z = 2; z <= dynlen(tab); z++) { /* ... */ }
}
```

**Скрипт не создан — вне объёма.**

**Типичные ошибки**

* Обработка только «первой строки» — придёт вся таблица.
* Ожидание вызова только на изменившиеся элементы — `All` отдаёт всё.
* `SELECT ALERT` — убьёт производительность Event Manager.

---

## dpQueryConnectSingle()

**Синопсис**

```c
int dpQueryConnectSingle([class object,] string|function_ptr work, bool wantsanswer,
                         anytype userData, string query [, int blockingTime]);
```

**Назначение.** Подписка по SQL-условию, но Event Manager отдаёт **каждое изменение
отдельно** — в сообщении обычно один элемент.

**Отличие от `dpQueryConnectAll()`**

| | `All` | `Single` |
| --- | --- | --- |
| Что приходит в колбэк | Вся таблица | Только изменившееся |
| Несколько изменений одним `dpSet()` | Одна передача | Тоже одна передача |
| `blockingTime` | Копится и передаётся трижды, если точки менялись в разное время | Копится в один вызов |

```c
main()
{
  string query = "SELECT '_online.._value' FROM 'ExampleDP*' WHERE _LEAF";
  dpQueryConnectSingle("doIt", FALSE, "User Data", query);
}

void doIt(string userData, dyn_dyn_anytype ddaTab)
{
  for (int i = 2; i <= dynlen(ddaTab); i++)
  {
    string DPE = ddaTab[i][1];   // полный идентификатор DPE
    float fNewValue = ddaTab[i][2];
    DebugN(DPE, fNewValue);
  }
}
```

Вывод:

```
WCCOAui1:["System1:ExampleDP_Arg2."][100]
WCCOAui1:["System1:ExampleDP_Result."][104]
WCCOAui1:["System1:ExampleDP_Arg1."][16]
```

**Фильтр по типу точки данных:**

```c
dpQueryConnectSingle("doIt", FALSE, "ud",
                     "SELECT '_online.._value' FROM '*' WHERE _DPT = \"ExampleDP_Float\"");
```

**Ограничение на структуры.** Элемент типа `struct` через `dpQueryConnectSingle()`
**не запрашивается**; может прийти предупреждение:

```
WCCILevent (0), <TIMESTAMP>, IMPL, WARNING, 54, Unexpected state, DP: <DP-ID>:_original.._stime,
  EvDpManager::getDpValueAttribut: no config
```

В структуре точки данных последний элемент должен быть **конкретным** типом
(`int`, `string`, `float`, …), иначе он не будет виден подписке.

**Структуры после обновления запроса.** При обновлении запроса конфига `_original`
(например, созданы новые точки данных) в результате появятся и `struct`-элементы.
Обычно структуры отфильтровываются на этапе создания запроса (пустые строки), но
после обновления новые точки добавляются в таблицу вместе со структурами.

**Скрипт не создан — вне объёма.**

---

## dpQueryDisconnect()

**Синопсис**

```c
int dpQueryDisconnect([class object,] string|function_ptr work, anytype userData);
```

Снимает подписку, созданную `dpQueryConnectAll()` или `dpQueryConnectSingle()`.

> Как и `dpDisconnect()`, вызывается **только в том же скрипте**, где была
> регистрация.

```c
main()
{
  string wf = "examplFunc";
  anytype userData = getUserName();
  dyn_dyn_anytype tab;
  int blockTime = 0;
  string query = "SELECT '_online.._value' FROM '*' WHERE _LEAF AND '_online.._userbit7' == 1";

  int queryAll = dpQueryConnectAll(wf, TRUE, userData, query, blockTime);
  DebugN("Registration successful?? ", queryAll);   // 0 = успех

  int dq = dpQueryDisconnect(wf, userData);
  DebugN("Unregister successful? ", dq);           // 0 = успех
}

void examplFunc(anytype userData, dyn_dyn_anytype tab)
{
  for (int z = 1; z <= dynlen(tab); z++) DebugN(tab[z]);
}
```

**Скрипт не создан — вне объёма.**

---

## dpGetAllAliases()

**Синопсис**

```c
int dpGetAllAliases(dyn_string &dps, dyn_string &aliases
                    [, string aliasFilter [, string dpeFilter]]);
```

Заменяет `getAllDpAliases()` в версиях > 2.11.1.

**Параметры**

| Имя | Тип CTRL | Обяз. | Описание | Значение для примера |
| --- | --- | --- | --- | --- |
| `dps` | `dyn_string` | да, **ref** | Точки данных | — |
| `aliases` | `dyn_string` | да, **ref** | Их алиасы | — |
| `aliasFilter` | `string` | нет | Шаблон алиасов | `"Engine*"` |
| `dpeFilter` | `string` | нет | Шаблон DPE. `""` и `"*"` = все DPE | `"*.para"` |

**Возврат.** Число найденных алиасов, `-1` при ошибке.

**Системы в `dpeFilter`:** `"Sys23:*.**"` — алиасы конкретной системы,
`"*:*.**"` — всех систем, `"Sys{1,2,3,45}:Ex*"` — список систем.

```c
dyn_string dps, ali;
int i = dpGetAllAliases(dps, ali);
DebugN(i, dps, ali);
```

**Скрипт не создан — вне объёма.**

---

## dpAliases()

**Синопсис**

```c
dyn_string dpAliases(string filter [, string dpeFilter]);
```

Возвращает только список алиасов по фильтру. Пустая строка — подходящих нет.

```c
DebugN(dpAliases("*", "*"));   // все существующие алиасы
```

**Скрипт не создан — вне объёма.**

---

## dpGetAllDescriptions()

**Синопсис**

```c
int dpGetAllDescriptions(dyn_string &dps, dyn_string &descriptions
                         [, string descriptionFilter [, string dpeFilter [, int mode]]]);
```

Заменяет `dpGetAllComments()`. Возвращает точки данных вместе с их описаниями,
прошедшими фильтры.

**Возврат.** Число найденных описаний, `-1` при ошибке. Если фильтр `"valve1"` нашёл
три описания (три точки данных) — вернётся `3`.

**Режимы `mode`** — те же, что у [`dpGetDescription()`](02-config.md#dpgetdescription),
для массовой выборки:

| Режим | Поведение |
| --- | --- |
| `-2` | Только описание на DPE, иначе ошибка (внутренний) |
| `-1` | Описание DPE, иначе имя элемента; для корневого — имя точки данных (внутренний) |
| `0` | Описание DPE, иначе имя DPE вида `System1:DP.EL1.EL2` |
| `1` | **По умолчанию.** Описание DPE, иначе `root DP + " " + master DP`. Если мастер-DP или описание нет — имя DPE как в режиме 0 |
| `2` | Как `1`, но порядок обратный: `master DPE + " " + root DP` |
| `3` | Описание собирается по всей ветке от корня: `root DP + " " + master DPE1 + … + master DPE`. Нет описания на мастере — берётся имя элемента (как `-1`) |

```c
int number;
dyn_string dps, comment;
number = dpGetAllDescriptions(dps, comment, "*");
DebugN(number, dps, comment);
```

**Скрипт не создан — вне объёма.**

---

## dpGetAllComments() — устарела

```c
int dpGetAllComments(dyn_string &dpe, dyn_string &comments
                     [, string commentFilter [, string dpeFilter [, int mode]]]);
```

Предшественник `dpGetAllDescriptions()`. Заменена на неё.

---

## getAllDpAliases() — устарела

```c
int getAllDpAliases(dyn_string &dps, dyn_string &aliases);
```

Переименована в `dpGetAllAliases()` начиная с 2.11.1.

---

## Связи

```
dpQuery()               ──▶ разовый SQL-SELECT
checkQuery()            ──▶ проверка синтаксиса до выполнения
dpQueryConnectAll()     ──▶ подписка, в колбэк приходит ВСЯ таблица
dpQueryConnectSingle()  ──▶ подписка, в колбэк приходит ТОЛЬКО изменившееся
dpQueryDisconnect()     ──▶ снять подписку (только в том же скрипте)

dpGetAllAliases() / dpAliases()          ──▶ алиасы
dpGetAllDescriptions()                   ──▶ описания
dpGetAlias() / dpAliasToName()           ──▶ точечно ([02](02-config.md), [03](03-read.md))
```

Обычная подписка без SQL — [05-subscribe.md](05-subscribe.md).