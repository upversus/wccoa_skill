# 14. JSON и mapping — legacyFoo

Раздел назван `legacyFoo` по договорённости: сюда складываются функции CTL,
не относящиеся к точкам данных, и раздел будет пополняться. Сейчас в нём две
темы: JSON в памяти (`jsonEncode`, `jsonDecode`) и ассоциативные массивы
`mapping`.

> ⛔ **JSON ≠ HTTP.** `jsonEncode()` и `jsonDecode()` работают только с памятью
> CTL-скрипта и **не делают сетевых запросов**. HTTP — это `netGet()`,
> `netPost()` и остальные `net*` из [13-http.md](13-http.md). Конвейер
> «собрать JSON → отправить → разобрать ответ» описан в разделе 6.

Источники (документация 3.21.6, проверка — CTL 3.18):

* [Mapping Functions](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/Control_Grundlagen/mapping_functions.html)
* [jsonEncode()](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/ControlE_R/jsonEncode.html)
* [jsonDecode()](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/ControlE_R/jsonDecode.html)

Проверено запуском: CTL 3.18, проект `<проект стенда>`. Всё, что помечено
**«измерено»**, проверено на стенде и может расходиться с документацией.

## 1. `jsonEncode()`

```c
string jsonEncode(anytype any [, bool compactFormat = true] [, mapping options])
```

| Параметр | Смысл |
| --- | --- |
| `any` | значение: простой тип, `dyn_`, `mapping`, `vector`, класс или структура |
| `compactFormat` | `true` (по умолчанию) — одна строка; `false` — с отступами и переносами |
| `options` | `compactFormat`, `timeAsMilliSeconds`, `langIdx`, `keepNanInf` |

Что во что кодируется:

| Вход | JSON |
| --- | --- |
| простой тип (`int`, `float`, `bool`, `string`) | массив из одного элемента: `42` → `[42]` |
| `dyn_` | массив: `makeDynInt(1,2,3)` → `[1,2,3]` |
| `mapping` | объект, **только со строковыми ключами** |
| `atime` | объект `{"time":"…","dpid":"…","count":…}`, время — ISO-8601 UTC |
| `errClass` | объект `{"prio":…,"type":…,"id":…,"text":…}` |
| `langString` | объект с одной записью на язык |
| `nullptr` | `null` |

```c
mapping m = makeMapping("name", "test", "value", 42);
string compact = jsonEncode(m);        // {"value":42,"name":"test"}
string pretty  = jsonEncode(m, false); // с переносами и отступами
```

**Ограничения.**

* Ключи `mapping` обязаны быть строками. Нестроковые ключи не кодируются:
  `jsonEncode(makeMapping(1, "one"))` возвращает `{}` — **измерено**, без
  ошибки в `getLastError()`.
* Порядок ключей в JSON не гарантирован и не совпадает с порядком вставки.
* Целые за пределами IEEE 754 (`±2^53`) теряют точность.
* `NaN`/`Inf` по умолчанию заменяются на `null`; `keepNanInf = true` сохраняет
  их как нестандартные значения. На стенде не измерялось: деление на ноль в
  CTL прерывает поток.

### Опции в CTL 3.18 — измерено

| Что проверялось | Результат 3.18 |
| --- | --- |
| `jsonEncode(m, false)` | работает, вывод с переносами |
| `jsonEncode(m, true, makeMapping("compactFormat", false))` | **опции игнорируются**, вывод компактный |
| `jsonEncode(m, makeMapping("keepNanInf", true))` (2-й аргумент) | mapping приводится к `bool`, в журнале `WARNING 50`; опция не работает |
| `timeAsMilliSeconds` (2-м и 3-м аргументом) | **не работает**: `atime` всё равно кодируется объектом с ISO-строкой |
| `langIdx` | не проверялось |

Вывод: в 3.18 надёжен только второй параметр `compactFormat`. Остальные опции
из документации 3.21.6 на этом стенде не действуют — проверяйте на своей
версии, прежде чем полагаться на них.

## 2. `jsonDecode()`

```c
<anytype> jsonDecode(string json)
```

Раскодирует JSON-строку: объект → `mapping`, массив → `dyn_`, число/строку →
соответствующий простой тип (по документации).

```c
anytype d = jsonDecode("{\"name\":\"test\",\"value\":42}");
if (dynlen(getLastError()) == 0 && mappingHasKey(d, "name"))
  DebugN("name =", d["name"], " value =", d["value"]);
```

**Диагностика ошибок.** `jsonDecode()` **не возвращает `-1`**, как `net*`:
при ошибке результат пустой/некорректный. Признак ошибки — `getLastError()`:

```c
anytype bad = jsonDecode("{bad json");
if (dynlen(getLastError()) > 0)
  DebugN("ошибка разбора:", getLastError());
```

`getLastError()` читается один раз после вызова: следующий вызов вернёт уже
другое состояние. Рабочая проверка — `dynlen(getLastError()) == 0`;
сравнение `getLastError() == 0` на стенде тоже работает.

**Измеренные ограничения 3.18.**

| Случай | Результат |
| --- | --- |
| JSON-объект | `mapping`, `getLastError()` пуст |
| JSON-массив | `dyn_anytype`, `getLastError()` пуст |
| верхнеуровневый скаляр `42`, `"abc"`, `true`, `null` | **ошибка** (`getLastError()` не пуст), значение не декодируется |
| BOM в начале строки | ошибка `Invalid value` |
| `atime` после `jsonEncode()` | декодируется в `mapping` с полями `time`/`dpid`/`count`, **не в `atime`** |

Скаляр всё же декодируется, если завернуть его в массив или объект:
`jsonDecode("[42]")[1] == 42`. Для `atime` обратное преобразование делайте
вручную или не полагайтесь на автоматическое.

BOM появляется при чтении файла через `fileToString()`; используйте
кодировку без BOM, иначе `jsonDecode()` упадёт.

## 3. `mapping`: ассоциативный массив

`mapping` — пары «ключ → значение» в памяти. Ключи могут быть разных типов,
включая смешанные `int` и `string` в одном `mapping` (**измерено**). Порядок
элементов не гарантирован.

| Функция / приём | Сигнатура | Назначение |
| --- | --- | --- |
| `makeMapping()` | `mapping (key1, value1 [, key2, value2, …])` | создать `mapping` с парами |
| `m[key] = value` | — | **добавить или перезаписать** пару |
| `mappingHasKey()` | `bool (mapping m, key)` | есть ли ключ (тип ключа важен) |
| `mappingKeys()` | `dyn_anytype (mapping m)` | все ключи в произвольном порядке |
| `mappinglen()` | `int (mapping m)` | число записей |
| `mappingGetKey()` | `anytype (mapping m, int idx)` | ключ на позиции `idx`, с 1 |
| `mappingGetValue()` | `anytype (mapping m, int idx)` | значение на позиции `idx`, с 1 |
| `mappingRemove()` | `int (mapping &m, key)` | удалить запись по ключу |
| `mappingClear()` | `int (mapping &m)` | удалить все записи |

> ⛔ **`mappingAdd()` и `mappingDel()` в CTL 3.18 отсутствуют.** Их нет и в
> официальном списке Mapping Functions (3.21.6). Вызов даёт
> `SEVERE, 72, Function not defined`. Добавление — только присваиванием
> `m[key] = value`, удаление — `mappingRemove()`. Не ищите эти имена в старых
> примерах: их там быть не должно.

### `makeMapping()`

```c
mapping m = makeMapping("one", 1, "two", 2, "three", 3);
DebugN(mappinglen(m)); // 3
```

### Добавление и перезапись — `m[key] = value`

```c
mapping m = makeMapping("name", "test");
m["value"] = 42;        // добавить
m["name"]  = "demo";    // перезаписать, длина не меняется
```

Это единственный переносимый способ «добавить»: `mappingAdd()` в 3.18 нет.
Присваивание сразу перезаписывает существующий ключ — отдельная проверка
`mappingHasKey()` нужна, только если перезапись нежелательна.

### `mappingHasKey()`

```c
mapping m = makeMapping("name", "test");
if (mappingHasKey(m, "name"))
  DebugN(m["name"]);
```

Проверяет только ключи, не значения. Сравнение **типо-строгое**: ключ `1` и
ключ `"1"` — разные (**измерено**).

### `mappingKeys()`

```c
mapping m = makeMapping("a", 1, "b", 2, 3, "c");
dyn_anytype keys = mappingKeys(m);
for (int i = 1; i <= dynlen(keys); i++)
  DebugN("key:", keys[i]);
```

Возвращает `dyn_anytype`, потому что ключи могут быть разных типов. Порядок
не гарантирован.

### `mappinglen()`

```c
DebugN(mappinglen(makeMapping("x", 1, "y", 2))); // 2
```

Для проверки конкретного ключа используйте `mappingHasKey()`, а не длину.

### `mappingGetKey()` и `mappingGetValue()`

```c
mapping m = makeMapping("one", 10, "two", 20);
for (int i = 1; i <= mappinglen(m); i++)
  DebugN(mappingGetKey(m, i), " => ", mappingGetValue(m, i));
```

Индексация с **1**, порядок — внутренний, не порядок вставки. Поэтому
`mappingGetValue(m, 1)` — это значение первого элемента во внутреннем
порядке, а не значение по ключу `1`.

**Измерено:** за границей диапазона обе функции возвращают `-1` и пишут в
журнал `WARNING 76, Invalid argument in function`. Исключения нет.

### `mappingRemove()`

```c
mapping m = makeMapping("a", 1, "b", 2);
int rc = mappingRemove(m, "a");
DebugN("rc=", rc, " len=", mappinglen(m)); // rc=0, len=1
```

Передаётся по ссылке (`&m`), меняет исходный `mapping`. **Измерено:** в 3.18
`rc = 0` и при успешном удалении, и при отсутствующем ключе, поэтому `rc` не
признак наличия. Проверяйте `mappinglen()` до и после.

### `mappingClear()`

```c
mapping m = makeMapping("x", 1, "y", 2);
mappingClear(m);                 // rc=0
DebugN(mappinglen(m));           // 0
```

Передаётся по ссылке. Для пустого `mapping` тоже возвращает `0` (**измерено**).

## 4. Смешанные ключи

```c
mapping m;
m["s"]   = "str";
m[1]     = "one";
m[2.5]   = "float";
DebugN(mappinglen(m));   // 3
DebugN(m["s"], m[1], m[2.5]);
```

Ключи разных типов допустимы, но `mappingKeys()` вернёт `dyn_mixed`, а
`jsonEncode()` такой `mapping` закодирует как `{}` — JSON требует строковых
ключей.

## 5. Порядок и позиционный доступ

Порядок в `mapping` не гарантирован. `mappingKeys()`, `mappingGetKey()` и
`mappingGetValue()` используют один и тот же внутренний порядок, поэтому
`mappingGetKey(m, i)` и `mappingGetValue(m, i)` согласованы между собой, но
не обязаны совпадать с порядком вставки. Не полагайтесь на порядок в
протоколах и сравнениях — проверяйте ключи через `mappingHasKey()`.

## 6. Типовой конвейер JSON + `net*`

```c
mapping data = makeMapping("name", "test", "value", 42);
if (!mappingHasKey(data, "timestamp"))
  data["timestamp"] = formatTime("%Y-%m-%dT%H:%M:%S", getCurrentTime());

string json = jsonEncode(data, true);

mapping result;
int rc = netPost("https://example.invalid/post", json, result);
if (rc == 0)
{
  anytype resp = jsonDecode(result["content"]);
  if (dynlen(getLastError()) == 0 && mappingHasKey(resp, "json"))
    DebugN("echo:", resp["json"]);
}
```

`netPost()`/`netGet()` описаны в [13-http.md](13-http.md). Примеры раздела 14
сеть не используют: они проверяют только сборку, кодирование, разбор и
проверку структуры.

## 7. Измеренные оговорки CTL 3.18 — коротко

| Оговорка | Поведение 3.18 |
| --- | --- |
| `mappingAdd()`, `mappingDel()` | **нет**, `Function not defined` |
| добавление | `m[key] = value` |
| `mappingRemove()` отсутствующий ключ | `rc = 0`, длина не меняется |
| `mappingClear()` пустой `mapping` | `rc = 0` |
| `mappingGetKey/Value()` за границей | `-1` + `WARNING 76` |
| порядок `mapping` | не гарантирован, не порядок вставки |
| `mappingHasKey()` | типо-строгий: `1` ≠ `"1"` |
| `jsonEncode(скаляр)` | массив из одного элемента: `[42]` |
| `jsonEncode(mapping)` с нестроковым ключом | `{}`, без ошибки |
| `jsonEncode(atime)` | объект `time`/`dpid`/`count`, ISO-8601 UTC |
| `jsonEncode` опции (3-й аргумент) | игнорируются |
| `jsonDecode()` верхнеуровневый скаляр | ошибка; заворачивайте в `[]`/`{}` |
| `jsonDecode()` BOM | ошибка `Invalid value` |
| `jsonDecode(atime-объекта)` | `mapping`, не `atime` |
| ошибка `jsonDecode()` | не `-1`; проверяйте `dynlen(getLastError())` |

## 8. Примеры

| Файл | Что проверяет |
| --- | --- |
| [`01_jsonEncode.ctl`](../examples/14-legacyFoo/01_jsonEncode.ctl) | простые значения, `dyn_`, `mapping`, pretty, `atime`, нестроковый ключ, опции 3.18 |
| [`02_jsonDecode.ctl`](../examples/14-legacyFoo/02_jsonDecode.ctl) | объект, массив, вложенность, ошибки синтаксиса и BOM, скалярная оговорка, `atime` |
| [`03_mapping.ctl`](../examples/14-legacyFoo/03_mapping.ctl) | `makeMapping`, присваивание, `mappingHasKey`, `mappingKeys`, `mappinglen`, позиционный доступ, `mappingRemove`, `mappingClear`, смешанные ключи |
| [`04_json_pipeline.ctl`](../examples/14-legacyFoo/04_json_pipeline.ctl) | сборка `mapping` → `jsonEncode` → `jsonDecode` → проверка структуры без сети |

Запуск раздела:

```powershell
.\examples\verify.ps1 -Section 14-legacyFoo
```
