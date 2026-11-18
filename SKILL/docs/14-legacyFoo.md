# 14. JSON, mapping, биты, HTTP-сервер, динамические вызовы и массивы — legacyFoo

Раздел назван `legacyFoo` по договорённости: сюда складываются функции CTL,
не относящиеся к точкам данных, и раздел будет пополняться. Сейчас в нём
шесть тем: JSON в памяти (`jsonEncode`, `jsonDecode`), ассоциативные массивы
`mapping`, работа с битами `bit32`/`bit64`, HTTP-сервер (`httpServer()` и
семейство `http*`), динамические вызовы (`callFunction()`, `checkScript()`,
`evalScript()`, `execScript()` с restricted-вариантами) и динамические
массивы `dyn_*` (методы и глобальные функции).

> ⛔ **JSON ≠ HTTP.** `jsonEncode()` и `jsonDecode()` работают только с памятью
> CTL-скрипта и **не делают сетевых запросов**. HTTP — это `netGet()`,
> `netPost()` и остальные `net*` из [13-http.md](13-http.md). Конвейер
> «собрать JSON → отправить → разобрать ответ» описан в разделе 11.

Источники (документация 3.21.6, проверка — CTL 3.18):

* [Mapping Functions](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/Control_Grundlagen/mapping_functions.html)
* [jsonEncode()](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/ControlE_R/jsonEncode.html)
* [jsonDecode()](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/ControlE_R/jsonDecode.html)
* [32/64 bit Functions](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/Control_Grundlagen/Control_Grundlagen-28.html)
* [httpServer()](https://www.winccoa.com/documentation/WinCCOA/latest/en_US/ControlE_R/httpServer.html)
* [httpConnect()](https://www.winccoa.com/documentation/WinCCOA/latest/en_US/ControlE_R/httpConnect.html)
* [HTTP Functions](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/Control_Grundlagen/http_functions.html)
* [callFunction()](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/ControlA_D/callFunction_2.html)
* [checkScript()](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/ControlA_D/checkScript_2.html)
* [evalScript()](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/ControlE_R/evalScript_3.html)
* [evalScriptRestricted()](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/ControlE_R/evalScriptRestricted.html)
* [execScript()](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/ControlE_R/execScript_3.html)
* [execScriptRestricted()](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/ControlE_R/execScriptRestricted.html)
* [Vector Methods](https://www.winccoa.com/documentation/WinCCOA/latest/en_US/Control_Grundlagen/vector_methods.html)
* [Vector / Dynamic Arrays — Functions](https://www.winccoa.com/documentation/WinCCOA/latest/en_US/Control_Grundlagen/vector_methods.html)

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

## 4. Биты `bit32`/`bit64`

CTL 3.18 поддерживает типы `bit32` и `bit64` для побитовых операций.
Младший бит — позиция **0**, позиции считаются от 0 до 31 (`bit32`) или 0 до 63 (`bit64`).

| Функция | Сигнатура | Назначение |
| --- | --- | --- |
| `getBit()` | `int (bit32|bit64 aBitVar, int position)` | вернуть значение бита: `0` или `1` |
| `setBit()` | `int (bit32|bit64 &aBitVar, int position, bool value)` | установить бит в `0`/`1` (`true`/`false`) |
| `checkPattern()` | `int (bit32|bit64 aBitVar, string pattern)` | сравнить переменную со шаблоном |
| `setPattern()` | `int (bit32|bit64 &aBitVar, string pattern)` | присвоить переменной шаблон |

`setBit`/`setPattern` передают переменную по ссылке (`&`) и меняют
её напрямую. Возвращают `0` при успехе, `-1` при ошибке (по документации).
`getBit` возвращает `0` или `1`, а при ошибке — `-1`.

```c
bit32 b = 13;              // 1101b: биты 0, 2, 3 = 1, бит 1 = 0
DebugN(getBit(b, 1));      // 0
setBit(b, 1, true);        // b станет 15 (1111b)
DebugN(checkPattern(b, "1111")); // 1
setPattern(b, "xx0x");     // бит 1 сброшен → b снова 13
```

Шаблон `pattern` — строка длиной 1–64 символа из `0`, `1` и прочих символов
(например `x`, которые игнорируются). **Измерено:** строка читается **справа
налево** — крайний правый символ соответствует биту 0.

### Измеренные оговорки 3.18

| Оговорка | Поведение 3.18 |
| --- | --- |
| `getBit()` за границей (позиция ≥ 32 для `bit32`) | возвращает `0`, а не `-1` как в документации |
| `setBit()` за границей | возвращает `0`, а не `-1` |
| позиция бита | с 0, младший бит |
| шаблон `checkPattern`/`setPattern` | читается справа налево, правый символ — бит 0 |
| символы, кроме `0`/`1`, в шаблоне | игнорируются, не считаются ошибкой |

## 5. HTTP-сервер: `httpServer()` и семейство `http*`

`httpServer()` поднимает HTTP-сервер внутри CTRL-менеджера. Это **серверная**
сторона: входящий запрос принимает функция, зарегистрированная через
`httpConnect()`. Клиентская сторона — `netGet()`, `netPost()` и остальные
`net*` из [13-http.md](13-http.md); ими же удобно проверять свой сервер
loopback-запросами.

> ⚠️ **Сервер живёт в менеджере.** Документация предупреждает: обмен с
> клиентом может блокировать систему, поэтому HTTP-сервер лучше запускать в
> отдельном CTRL-менеджере. На стенде loopback-запросы из того же скрипта
> работают (измерено), но предупреждение это не отменяет.

### `httpServer()`

```c
int httpServer([bool authRequired = true | string authMethod | dyn_string authMethods
                [, unsigned portNr = 80 [, unsigned securePortNr = 443]]]);
```

| Параметр | Смысл |
| --- | --- |
| `authRequired` / `authMethod` / `authMethods` | нужна ли аутентификация и какая: `"Basic"`, `"Basic realm=myRealm"`, `"Negotiate"`, `"NTLM"`. Задаётся только один из трёх вариантов |
| `portNr` | HTTP-порт, по умолчанию 80; `0` — HTTP не открывать, только HTTPS |
| `securePortNr` | HTTPS-порт, по умолчанию 443; `0` — HTTPS не использовать |

Возврат: `0` — сервер установлен, `-1` — ошибка. **Один сервер на менеджер.**

```c
#uses "CtrlHTTP"

int rc = httpServer(false, 18081, 0);   // без аутентификации, HTTP 18081, без HTTPS
if (rc != 0)
  DebugN("httpServer:", getLastError());
```

`#uses "CtrlHTTP"` подключает плагин `CtrlHTTP.dll`; примеры раздела используют
его, как и документация.

**Измерено в 3.18:**

| Что | Поведение |
| --- | --- |
| повторный `httpServer()` в том же менеджере | `-1`, `WARNING 54`, текст `httpServer already installed`; порт уже не важен |
| занятый порт | `-1`; `getLastError()` **пуст**, в журнале `SEVERE`: `The Port <N> could not be opened.` |
| повторная попытка на свободном порту после занятого | `0`, сервер поднимается |
| завершение менеджера | после `main()` процесс **не завершается**, пока сервер установлен; нужен `exit(0)` |
| порт по умолчанию 80 | может быть занят другим веб-сервером; на стенде берите высокий порт (под Linux порты < 1024 требуют root) |

Пример с fallback по портам — в `06_httpServer.ctl`.

### `httpConnect()` и `httpDisconnect()`

```c
int httpConnect(string|function_ptr callBackFunc, string resourceName
                [, string contentType = "text/html"]);
int httpDisconnect(string resourceName);
```

`httpConnect()` регистрирует CTRL-функцию как веб-ресурс. Ресурс можно задать
точным именем (`/echo`) или шаблоном (`/api/*`): сначала проверяется точное
совпадение, затем `patternMatch()`. `contentType` по умолчанию `text/html`.
`httpDisconnect()` снимает регистрацию.

**Измерено:** повторная регистрация того же ресурса — `-1`, `WARNING 76`
`Resource already connected`; несуществующий callback — `-1`, `WARNING 72`
`Function not defined`; повторный `httpDisconnect()` — `-1`, `WARNING 76`
`Resource not connected`. Шаблон `/api/*` вызывается для `/api/thing`.

**Измерено:** путь сравнивается с именем ресурса **буквально**, без нормализации.
`//api/dp`, `/api/dp/`, `/API/DP`, `/api/dp/extra` и `/api/../api/dp` не совпадают
с `/api/dp`: отвечает встроенный обработчик — `404`, `Content-Type: text/html`,
тело `<html>…The requested resource was not found…`, callback не вызывается.
Поэтому «двойной слэш» в адресе выглядит как отсутствующий ресурс, а не как
ошибка в параметрах; параметры запроса при этом вообще не разбираются.

Callback получает до семи аргументов:

```c
string cb(dyn_string names, dyn_string values, string user, string ip,
          dyn_string headerNames, dyn_string headerValues, int idx)
```

* `names` / `values` — параметры query-строки (`GET`) или поля формы
  (`POST application/x-www-form-urlencoded`);
* `user` — авторизованный пользователь или `""`; `ip` — адрес клиента
  (на стенде `::ffff:127.0.0.1`);
* `headerNames` / `headerValues` — заголовки запроса;
* `idx` — номер соединения, его передают в `httpGet*()`.

Все аргументы необязательны: `string cb()` тоже работает (**измерено**).
Для `POST` с типом `text/*` первым аргументом идёт `string content`, для
остальных типов — `blob content` (по документации).

### Данные запроса

Все функции принимают `idx` из callback и работают только внутри него.

| Функция | Возврат | Что даёт |
| --- | --- | --- |
| `httpGetMethod(idx)` | `string` | `GET`, `POST` и т. д. |
| `httpGetURI(idx)` | `string` | путь **без** query: для `/echo?a=1` вернёт `/echo` |
| `httpGetQuery(idx)` | `mapping` | query-параметры, значения-строки, уже декодированные |
| `httpGetHeader(idx, key)` | `string` | один заголовок; имя нечувствительно к регистру |
| `httpGetAllHeaders(idx)` | `mapping` | все заголовки запроса |
| `httpGetContent(idx, content)` | `int` | тело запроса: `0` при успехе, `-1` при ошибке |
| `httpGetPort(idx)` | `string` | порт, на который пришёл запрос |
| `httpGetLanguage(idx)` | `int` | язык клиента, `0..getNoOfLangs()-1` |
| `httpGetLanguageId(idx)` | `OaLanguage` | тот же выбор в виде enum |

**Измерено:** `httpGetQuery()` декодирует `%20` и `+` в пробел, а UTF-8
проценты — в символ (`%D0%B4` → `д`). У `POST` в `httpGetQuery()` попадает
только query из URL; поля формы приходят в `names`/`values`.
`httpGetContent()` на `GET` возвращает `0` и пустую строку; на `POST` с
`application/x-www-form-urlencoded` и `text/plain` — всё тело как есть
(`alpha=1&beta=two+words`, плюсы не декодируются). Для `POST` с `blob`
документация предупреждает, что `httpGetContent()` недоступен: тело уже
передано в callback; на стенде этот случай не проверялся.
`httpGetLanguage()` на стенде вернул `1`, `httpGetLanguageId()` — `10027`.

### Ответ клиенту

Callback может вернуть `string`, `dyn_string` или `dyn_mixed`:

| Возврат | Как трактуется |
| --- | --- |
| `string` | тело ответа; статус `200`, `Content-Type` из регистрации |
| `dyn_string` | `[1]` — тело, `[2..]` — заголовки ответа |
| `dyn_mixed` | `[1]` — тело (`string`, `blob` или `file`), остальные — заголовки; `"Status: 404 Not found"` меняет HTTP-статус |

```c
string cb() { return "<html>ok</html>"; }

dyn_string cb2()
{
  dyn_string r;
  r[1] = "body";
  r[2] = "X-Probe: yes";
  return r;
}

string cb3()
{
  dyn_mixed n;
  dynAppend(n, "not found");
  dynAppend(n, "Status: 404 Not found");
  return n;
}
```

**Измерено:** `Status: 201 Created` в `dyn_string` **не меняет** статус — код
остаётся `200`, а `Status` приходит обычным заголовком. В `dyn_mixed` тот же
`Status: 404 Not found` действительно даёт `404`. При `404` `netGet()` вернул
`rc = -1`, но тело и заголовки в `mapping` доступны. Сервер сам добавляет
`Cache-Control: no-cache, private, must-revalidate`, `X-XSS-Protection`,
`X-Frame-Options`, `X-Content-Type-Options`.

**Измерено:** ответ обработчика, назначенного через `httpSetMethodHandler()`,
приходит с `Content-Type: text/html` — типа для него не задать: `contentType`
есть только у `httpConnect()`. Тело при этом любое, включая JSON.

### Настройки и вспомогательные функции

| Функция | Сигнатура | Назначение | 3.18 |
| --- | --- | --- | --- |
| `httpSetMaxAge()` | `int (uint maxAge)` | время кеширования файлов клиентом, секунды | `0` |
| `httpSetMaxContentLength()` | `int (uint length)` | максимальный размер `POST`, по умолчанию 100 КБ | `0` |
| `httpSetMethodHandler()` | `int (string method, string callback)` | перенаправить HTTP-метод в callback `(string ip, string url, int idx)` | см. ниже |
| `httpMakeParamString()` | `string (dyn_string names, dyn_string values)` | собрать query-строку | `first=first%20value&second=second-value` |
| `httpParseDate()` | `int (string date)` | разобрать дату RFC-2616 | функция есть, не проверялась |
| `httpSetPermission()` | — | права на ресурс | функция есть, не проверялась |

`httpSetMethodHandler()` в 3.18 принимает **DELETE, PUT, OPTIONS, TRACE,
CONNECT** (`rc = 0`) и отвергает **PATCH, HEAD, GET, POST** и пустую строку
(`rc = -1`, `WARNING 76` `Callback function already set or method not
allowed`). Это расходится с документацией: там `CONNECT` назван запрещённым,
а `PATCH` — допустимым.

### Остальное семейство

Эти функции в 3.18 объявлены (`isFunctionDefined()` → `TRUE`), но на стенде не
проверялись: `httpSetPermission()`, `httpAccessLog()`,
`httpSaveFilesFromUpload()`, `httpSetSecondaryAuthSuccess()`,
`httpReadWebSocket()`, `httpWriteWebSocket()`, `httpCloseWebSocket()`,
`httpOnConnectionClose()`. Функции `httpSetUlcUserName()` в 3.18 **нет**
(`isFunctionDefined()` → `FALSE`).

Статические файлы сервер отдаёт из каталогов `/pictures/`, `/images/`,
`/colorDB/`, `/xml/`, `/nls/`, `/bin/`, `/data/`, `/log/`, `/panels/`,
`/scripts/` (последние два — в зашифрованном виде); если ресурс `/` не
зарегистрирован, ищется `<проект>/data/index.html`. По документации; на стенде
не проверялось.

### Измеренные оговорки 3.18

| Оговорка | Поведение 3.18 |
| --- | --- |
| второй `httpServer()` | `-1` + `WARNING 54` |
| занятый порт | `-1`, `getLastError()` пуст, причина только в журнале |
| завершение скрипта | с установленным сервером менеджер не выходит; нужен `exit(0)` |
| `httpGetURI()` | возвращает путь без query |
| `httpGetQuery()` у `POST` | только query из URL; поля формы — в `names`/`values` |
| `httpGetContent()` у `GET` | `rc = 0`, пустая строка |
| `Status` в `dyn_string` | остаётся заголовком, HTTP-код `200` |
| `Status` в `dyn_mixed` | меняет HTTP-код (проверено `404`) |
| `netGet()` при `404` | `rc = -1`, но тело и заголовки доступны |
| `httpSetMethodHandler()` | `DELETE`/`PUT`/`OPTIONS`/`TRACE`/`CONNECT` — да; `PATCH`/`HEAD`/`GET`/`POST` — нет |

## 6. Динамические вызовы: `callFunction()`, `checkScript()`, `evalScript()`, `execScript()`

Две независимые возможности, которые часто путают:

* **вызвать функцию по имени-строке** — `callFunction()`;
* **собрать текст скрипта и выполнить его** — `checkScript()`,
  `evalScript()`, `execScript()` и их restricted-варианты.

Первая работает с уже загруженными функциями, вторая компилирует новый скрипт
в рантайме. Общего у них только то, что имя/текст приходит из данных, а не из
кода, поэтому обе требуют проверки до вызова.

| Функция | Сигнатура | Назначение |
| --- | --- | --- |
| `callFunction()` | `anytype (string funcName[, <параметр> ...])` | вызвать функцию по имени |
| `checkScript()` | `bool (string scriptstr[, int &errorPos])` | проверить синтаксис текста |
| `evalScript()` | `int (anytype &retVal, string script[, dyn_string dollars[, <arg> ...]])` | выполнить текст, вернуть значение `main` |
| `evalScriptRestricted()` | то же | то же, но с белым списком функций |
| `execScript()` | `int (string script[, dyn_string dollars[, <arg> ...]])` | выполнить текст без возврата (`void main`) |
| `execScriptRestricted()` | то же | то же, но с белым списком функций |

### `callFunction()`

```c
anytype callFunction(string funcName[, <параметр1>[, <параметр2>]] ...);
```

`funcName` — **строка без скобок**, регистр важен. Параметры передаются как
в обычном вызове, возврат — то, что вернула вызванная функция.

```c
time t = callFunction("makeTime", 1999, 8, 13, 13, 40, 10, 50);
int ms = callFunction("hour", t);      // 13
int f  = callFunction("floor", 2.25);  // 2
int s  = callFunction("myAdd", 17, 8); // 25 — своя функция тоже вызывается
```

**Имя.** `"hour()"`, `"Hour"` и `"nosuchfunc"` не находятся: в журнале
`SEVERE 72, Function not defined` и `SEVERE 176, Uncaught exception in thread
started at main`, остаток `main()` не выполняется. Проверять имя заранее
можно через `isFunctionDefined()`:

| Проверка | 3.18 |
| --- | --- |
| `isFunctionDefined("hour")` | `TRUE` |
| `isFunctionDefined("hour()")` | `FALSE` — скобки не допускаются |
| `isFunctionDefined("Hour")` | `FALSE` — регистр важен |
| `isFunctionDefined("nosuchfunc_xyz")` | `FALSE` |

`TRUE` от `isFunctionDefined()` означает только «имя объявлено». Оно не
проверяет ни число/типы параметров, ни видимость, ни запрет restricted-режима
(`isFunctionDefined("dpGet")` в 3.18 тоже `TRUE`).

**Возврат.** Документация требует обязательно присваивать результат: иначе
скрипт закрывается без сообщения, и это же относится к вызову внутри
`DebugN()`. **Измерено в 3.18: не закрывается.** Работают оба варианта:

```c
callFunction("hour", t);                 // продолжает
DebugN(callFunction("hour", t));         // печатает 13 и продолжает
```

Полагаться на это не стоит: поведение расходится с документацией и может
измениться в другой версии. Присваивайте результат.

**Измеренные случаи 3.18.**

| Случай | Поведение |
| --- | --- |
| своя функция скрипта | вызывается |
| `private` функция **того же** скрипта | вызывается (документация обещает ошибку) |
| `synchronized` функция | вызывается напрямую, в том числе рекурсивно через `callFunction` |
| `void`-функция | выполняется, возврат — undefined `anytype` + `WARNING 73, … (forgotten return in callFunction?)` |
| неверный тип параметра | приводится: `callFunction("floor", "not a number")` → `0`, без ошибки |
| несуществующее имя / скобки / другой регистр | `SEVERE 72` + `SEVERE 176`, скрипт останавливается |

Про `synchronized` документация предупреждает: напрямую такие функции
вызывать нельзя, нужен mutex. На стенде прямой вызов и рекурсия отработали,
но переносимый вариант — как в документации:

```c
uint lock_someFunc;
int someFunc(int x) synchronized(lock_someFunc) { return x + 100; }

int r = callFunction("someFunc", 5);   // работает и по документации
```

Стек-трейс содержит только вызов `callFunction()`, а не вызванную функцию.
С функциями панелей и панельных ссылок `callFunction()` работать не будет:
вызов идёт в другом контексте. `private`-функция другого скрипта на стенде не
проверялась.

### `checkScript()`

```c
bool checkScript(string scriptstr[, int &errorPos]);   // 3.18
bool checkScript(string scriptstr[, int &errorPos | mapping &errorData]); // документация 3.21
```

Возврат: `TRUE` — синтаксис корректный, `FALSE` — есть ошибка.

**Вариант с `mapping &errorData` в 3.18 отсутствует.** Второй аргумент
принимается только как `int &errorPos`; передача `mapping` даёт
`WARNING 50, … cannot assign variable of type INTEGER_VAR`. Ориентируйтесь на
`errorPos`.

`errorPos` — **0-based смещение** символа, на котором парсер остановился:

| Скрипт | Результат | `errorPos` |
| --- | --- | --- |
| `main(){ DebugN(123); }` | `TRUE` | `0` |
| `main(){ DebugN(1; }` | `FALSE` | `16` — позиция `;` |
| `main( {` | `FALSE` | `6` |
| `int main(){ return ; }` | `FALSE` | `19` — позиция `;` |
| `int main(){ return 1 }` | `FALSE` | не измерялся |

**`TRUE` не означает «скрипт исполнится».** Измерено: `checkScript()` не
проверяет ни наличие `main`, ни существование функций, ни ограничения
restricted-режима. Все эти строки дают `TRUE`:

* `""` — пустая строка;
* `"int foo(){ return 1; }"` — нет `main`, `evalScript()` потом вернёт `-1`;
* `"main(){ int x; int x; }"` — повторное объявление переменной;
* `"int main(){ return nosuchfunc_xyz(); }"` — неизвестная функция;
* `"int main(){ int x; dpGet(\"System1:_1s\", x); }"` — `dpGet` запрещён в
  restricted-режиме, но синтаксис верный.

`getLastError()` после `checkScript()` на стенде пуст (`dyn_errClass 0 items`)
и для `TRUE`, и для `FALSE`. Диагностика — только `errorPos`.

```c
int pos = -1;
if (!checkScript(text, pos))
  DebugN("синтаксис, позиция", pos);
```

Практический порядок: `checkScript()` → проверка, что в тексте есть `main`
(например `strpos(text, "main")`) → `evalScript()`/`execScript()` → разбор
кода возврата и журнала.

### `evalScript()` и `evalScriptRestricted()`

```c
int evalScript(anytype &retVal, string script
               [, dyn_string dollars [, <тип> <arg> ...]]);
int evalScriptRestricted(anytype &retVal, string script
               [, dyn_string dollars [, <тип> <arg> ...]]);
```

`retVal` получает возврат `main`, `dollars` — подстановки `$имя:значение`,
остальные аргументы — параметры `main`. Возврат `0` при успехе и `-1` при
ошибке.

**Измерено: `-1` приходит только тогда, когда скрипт не удалось запустить.**

| Случай | `rc` | `retVal` | Журнал |
| --- | --- | --- | --- |
| успешный `int main()` | `0` | значение `main` | — |
| нет `main` | `-1` | не меняется | `SEVERE 72` |
| синтаксическая ошибка | `-1` | **не сбрасывается** (остаётся прежнее) | `WARNING 81` |
| тип возврата не совпал с переменной | `0` | `0` | — |
| неизвестная функция внутри | `0` | `0` | `SEVERE 72` + `SEVERE 176` |
| отсутствует `$`-параметр | `0` | `0` | `SEVERE 17/ctrl` + `SEVERE 176` |
| вызов функции вызывающего скрипта | `0` | `0` | `SEVERE 72` + `SEVERE 176` |

То есть ошибки времени выполнения **не меняют код возврата**. Проверять
`rc == 0` недостаточно: скрипт может молча не выполниться, а признак останется
только в журнале менеджера. Это главная ловушка обеих функций.

`retVal` при ошибке не обнуляется — в нём остаётся значение, которое было до
вызова. Если это важно, присваивайте начальное значение сами и проверяйте его
после вызова.

Функцию, объявленную в вызывающем скрипте, из `evalScript()` вызвать нельзя —
она не видна в новом скрипте. `$`-параметры задаются строками вида
`"$val1:12345"` и подставляются в текст до компиляции:

```c
int sum = 0;
int rc = evalScript(sum, "int main(int a, int b){ return a + b; }",
                    makeDynString(), 17, 8);   // rc=0, sum=25
```

Вложенный `evalScript()` (без restricted) работает: внутренний скрипт
возвращает значение, внешний его использует.

### `execScript()` и `execScriptRestricted()`

```c
int execScript(string script[, dyn_string dollars[, <тип> <arg> ...]]);
int execScriptRestricted(string script[, dyn_string dollars[, <тип> <arg> ...]]);
```

Предназначены для `void main` — без возврата. Возврат `0`/`-1`, ошибки и
`$`-параметры — как у `evalScript()`. **Измерено:** `int main()` с возвратом
тоже принимается и даёт `rc == 0` (так же сделано в примере документации);
значение при этом никуда не попадает — для возврата нужен `evalScript()`.

### Restricted-режим: что разрешено

`evalScriptRestricted()`/`execScriptRestricted()` запрещают два класса
функций (по документации):

* функции пользовательского интерфейса;
* функции из CTRL-extension.

Всё остальное — по белому списку из документации `execScriptRestricted()`:
математика, строки, `dyn_*`, `mapping`, `jsonEncode`/`jsonDecode`, время,
`checkScript`, `callFunction`, чтение свойств точек данных (`dpExists`,
`dpGetUnit`, `dpNames`, `dpGetAllAttributes` и т. п.), `DebugN`,
`getLastError`, `startThread`/`stopThread`, `setVariable`, `throw` и др.
Записи в точки данных (`dpSet`), подписок (`dpConnect`), запросов (`dpQuery`)
и сетевых вызовов (`netGet`, `netPost`, `http*`, кроме `httpParseDate`) в
списке нет.

**Измерено в 3.18:**

| Что | Результат |
| --- | --- |
| `strlen`, `checkScript`, `callFunction("strlen", …)` | разрешены, `rc == 0` |
| `dpGet`, `dpSet`, `netGet` напрямую | `WARNING 38, Function <имя> is not allowed in restricted mode` + `SEVERE 176` |
| `callFunction("netGet", …)` | **тоже блокируется**: `callFunction` не обходит белый список |
| `evalScriptRestricted()` внутри restricted | блокируется в 3.18 (`WARNING 38`); документация разрешает с 3.19 |
| `checkScript()` запрещённого скрипта | `TRUE` — ограничения не проверяются |
| `rc` при запрещённой функции | `0` (не `-1`), `retVal` сохраняет прежнее значение |

Отсюда практические правила:

1. `checkScript()` не является проверкой безопасности: он смотрит только
   синтаксис.
2. `rc == 0` в restricted-режиме не доказывает, что скрипт выполнился.
   Запрещённая функция видна только в журнале менеджера.
3. «Restricted» — не песочница. Белый список включает `startThread`,
   `setVariable`, `throw` и чтение конфигурации точек данных; не выполняйте
   в нём текст, пришедший от недоверенного источника.
4. Проверяйте новый динамический скрипт на тестовом менеджере и смотрите
   журнал, а не только `rc`.

### Измеренные оговорки 3.18 — динамические вызовы

| Оговорка | Поведение 3.18 |
| --- | --- |
| `callFunction` без присваивания возврата | продолжает (документация: закрывает скрипт) |
| `callFunction` внутри `DebugN` | продолжает |
| `private` функция того же скрипта | вызывается |
| `synchronized` функция | вызывается напрямую, рекурсия тоже |
| `void` через `callFunction` | undefined `anytype` + `WARNING 73` |
| неверный тип параметра | приводится, `floor("not a number")` → `0` |
| имя со скобками / другой регистр | `SEVERE 72` + `SEVERE 176`, скрипт останавливается |
| `checkScript(..., mapping &errorData)` | **нет** в 3.18, только `int &errorPos` |
| `errorPos` | 0-based смещение символа ошибки |
| `checkScript("")` | `TRUE` |
| `checkScript` без `main` / с неизвестной функцией | `TRUE` — проверяется только синтаксис |
| `evalScript`/`execScript`: нет `main` | `rc = -1` |
| `evalScript`/`execScript`: синтаксис | `rc = -1`, `retVal` не сбрасывается |
| `evalScript`/`execScript`: ошибка времени выполнения | `rc = 0`, `SEVERE` в журнале |
| тип возврата не совпал | `rc = 0`, значение `0` |
| вызов функции вызывающего скрипта | не видна: `rc = 0`, `SEVERE 72` |
| restricted: запрещённая функция | `rc = 0`, `WARNING 38`, `retVal` прежний |
| restricted: обход через `callFunction` | не работает |
| restricted: вложенный restricted | в 3.18 запрещён (с 3.19 разрешён) |

Пример: [`07_dynamic_calls.ctl`](../examples/14-legacyFoo/07_dynamic_calls.ctl) —
60 проверок, без точек данных и сети.

## 7. Динамические массивы: методы `dyn_*`

У динамических массивов два несовместимых способа работы, и путаница между
ними — главный источник ошибок:

| Способ | Индексация | Пример |
| --- | --- | --- |
| Прямой индекс `a[i]` | **с 1** | `a[1]` — первый элемент |
| Методы `a.method()` | **с 0**, как у `vector` | `a.at(0)` — первый элемент |
| Глобальные `dyn*(a, …)` | **с 1** | `dynContains(a, x)` → 1-based |

Это измерено на 3.18. Частое утверждение «индексация `dyn_*` начинается
с 1» верно только для прямого индекса и глобальных функций; методы `dyn_*`
нумеруют элементы с 0, как `vector`.

```c
dyn_string a = makeDynString("b", "a", "b");
DebugN(a[1]);        // "b"  - прямой индекс с 1
DebugN(a.at(0));     // "b"  - метод с 0
DebugN(a.at(1));     // "a"
string bad = a[0];   // SEVERE 79 Index out of range, скрипт останавливается
```

### Методы, измеренные в 3.18

| Метод | Что делает | Возврат |
| --- | --- | --- |
| `append(val)` | добавляет в конец | — |
| `insertAt(idx, val)` | вставляет перед `idx`; `0` — в начало, `len` — в конец | — |
| `replaceAt(idx, val)` | заменяет элемент `idx` | `0` |
| `removeAt(idx)` | удаляет элемент `idx` | `0` |
| `takeFirst()` | извлекает первый элемент | значение |
| `takeLast()` | извлекает последний элемент | значение |
| `takeAt(idx)` | извлекает элемент `idx` | значение |
| `first()`, `last()` | ссылка на первый/последний элемент | ссылка |
| `at(idx)` | ссылка на элемент `idx` | ссылка |
| `contains(val)` | есть ли значение | `TRUE`/`FALSE` |
| `indexOf(val)` | позиция первого вхождения | `0`-based индекс или `-1` |
| `indexListOf(val)` | позиции всех вхождений | `vector<int>`, `0`-based |
| `count()` | длина массива | `int` |
| `clear()` | очищает массив | — |
| `unique()` | удаляет дубликаты на месте | `0`, а не новая длина |

`first()`, `last()` и `at()` возвращают **ссылку**, поэтому присваивание
меняет сам массив:

```c
dyn_string a = makeDynString("b", "a", "b");
a.at(1) = "Q";       // a = ["b", "Q", "b"]
a.first() = "Z";     // a = ["Z", "Q", "b"]
```

`indexListOf()` возвращает `vector<int>`, а не `dyn_int`: у него `0`-based
индексы и метод `count()`. Если вхождений нет, возвращается **пустой
vector**, а не `-1`:

```c
dyn_string a = makeDynString("b", "a", "b");
anytype hit = a.indexListOf("b");    // vector<int> [0, 2]
anytype miss = a.indexListOf("zz");  // vector<int> 0 items, count() == 0
int p = a.indexOf("zz");             // -1
```

`unique()` регистрозависим (`"b"` и `"B"` — разные значения), сохраняет
порядок первых вхождений и возвращает `0`. Глобальная `dynUnique()`
возвращает новую длину — см. следующий подраздел.

### Границы: исключение, а не код возврата

У методов нет `rc` для ошибки индекса. Выход за границу даёт
`SEVERE 176` + `WARNING 79 "Index out of range"` и **останавливает поток**:

| Вызов | Допустимый диапазон | За границей |
| --- | --- | --- |
| `at(idx)` | `0 … len-1` | исключение |
| `insertAt(idx, val)` | `0 … len` | исключение |
| `removeAt(idx)` | `0 … len-1` | исключение |
| `takeAt(idx)` | `0 … len-1` | исключение |
| `first()`/`last()` | массив не пуст | исключение на пустом |

Поэтому проверяйте `count()` перед `at()`, `removeAt()` и `take*()`.
`insertAt(len, val)` — легальный способ дописать в конец; `insertAt(len+1, …)`
уже исключение.

### Что не работает в 3.18

* **`lastIndexOf()` отсутствует.** Вызов даёт `WARNING 72
  "Function not defined, dyn_T::lastIndexOf"` и останавливает скрипт. У
  `vector<int>` его тоже нет. Замена — `indexListOf()` и последний элемент
  результата.
* **Метод у временного результата.** `makeDynString(...).append("z")` и
  `makeDynString(...).indexListOf(...)` дают `WARNING 73` (иногда дважды) и
  `WARNING 76`, а возврат недостоверен (у `indexListOf` в этом случае
  измерено `-1`). Сначала присвойте массив переменной, потом вызывайте метод.
* **`dynlen(vector)`** возвращает `-1` и печатает `WARNING 77 "Expression is
  not an array"`. Для `vector` используйте `count()`.

### `vector` рядом

`vector<T>` индексируется с `0` и поддерживает тот же набор методов
(`append`, `at`, `count`, `indexOf`, …). Прямой индекс `v[0]` — первый
элемент, `dynlen(v)` не работает. Массивы `dyn_*` и `vector` не
взаимозаменяемы: приведение `(vector<int>)` в 3.18 запрещено синтаксически.

Пример: [`08_dyn_methods.ctl`](../examples/14-legacyFoo/08_dyn_methods.ctl) —
60 проверок, без точек данных и сети.

## 8. Глобальные функции `dyn*`

Классический синтаксис: массив передаётся первым аргументом, индексы —
**с 1**. Функции меняют массив на месте; многие возвращают новую длину.

### Создание и размер

| Функция | Измерено в 3.18 |
| --- | --- |
| `makeDynInt(...)`, `makeDynString(...)`, `makeDynFloat(...)`, `makeDynBool(...)`, `makeDynTime(...)`, `makeDynAnytype(...)` | создают массив с переданными значениями; `makeDynInt()` и `makeDynString()` без аргументов дают пустой массив (`dynlen = 0`) |
| `makeDynDynInt()`, `makeDynDynString()` | **не существуют** (`isFunctionDefined = FALSE`) |
| `dynlen(arr)` | длина |
| `dynClear(arr)` | очищает, `rc = 0` |

Двумерный `dyn_dyn_*` собирается присваиванием строк:

```c
dyn_dyn_int dd;
dd[1] = makeDynInt(3, 1, 5);
dd[2] = makeDynInt(4, 2, 6);
```

### Изменение

| Функция | Индексация | Возврат | Оговорка 3.18 |
| --- | --- | --- | --- |
| `dynAppend(arr, val)` | — | новая длина | `val` может быть массивом — дописываются все элементы |
| `dynAppendConst(arr, val)` | — | новая длина | **меняет `arr`**, вопреки описанию «не меняющая исходный массив» |
| `dynInsertAt(arr, val, pos)` | `pos` с 1 | новая длина | `pos = 0` или `pos > len` — добавление в конец |
| `dynRemove(arr, pos)` | `pos` с 1 | `0` | `pos = 0` — `rc = -1`, массив не меняется |

```c
dyn_string s = makeDynString("a", "b", "c");
dynInsertAt(s, "X", 1);   // ["X","a","b","c"]
dynInsertAt(s, "Y", 0);   // ["X","a","b","c","Y"]  - 0 значит "в конец"
dynRemove(s, 0);          // rc = -1, массив прежний
```

`dynAppendConst()` в 3.18 ведёт себя как `dynAppend()`: исходный массив
становится длиннее. Не рассчитывайте на копию: если нужен отдельный массив,
соберите его заново.

### Поиск, сортировка, уникальность

| Функция | Измерено |
| --- | --- |
| `dynContains(arr, val)` | 1-based индекс первого вхождения; `0` — нет |
| `dynPatternMatch(mask, arr)` | подмассив по маске; регистрозависимо; порядок сохраняется; нет совпадений — пустой массив |
| `dynSort(arr[, asc])` | сортирует на месте; по умолчанию и при `TRUE` — по возрастанию, при `FALSE` — по убыванию; возвращает длину |
| `dynSortAsc(arr)` | по возрастанию; возвращает длину |
| `dynUnique(arr)` | удаляет дубликаты на месте; возвращает **новую длину**; порядок первых вхождений; регистрозависимо |
| `dynSortDesc()` | **не существует** (`isFunctionDefined = FALSE`) |

Строки сортируются по кодам символов: `"A" < "a" < "b"`. Это не
лексикографический порядок с игнорированием регистра.

`dynUnique()` и метод `unique()` возвращают разное: глобальная функция —
новую длину, метод — `0`.

### Математика

`dynSum`, `dynAvg`, `dynMin`, `dynMax` принимают числовые массивы.

| Ситуация | Измерено |
| --- | --- |
| `dyn_int(4, 1, 7, 3)` | `sum = 15`, `avg = 3.75`, `min = 1`, `max = 7` |
| пустой массив | все четыре функции возвращают `-1` |
| `dynAvg()` для `dyn_int` | возвращает `float`, а не целое |

`-1` для пустого массива — не код ошибки, а обычное значение: отличить его
от настоящего результата `-1` нельзя. Проверяйте `dynlen()` до вызова.

### Двумерные массивы

| Функция | Измерено |
| --- | --- |
| `dynDynTurn(arr)` | транспонирует на месте; возвращает число строк результата |
| `dynDynSort(arr, col)` | сортирует строки по столбцу; `col` с 1; возвращает число строк |
| `dynDynSort(arr, 0)` | массив не меняется, ошибки нет — тихий отказ |

```c
dyn_dyn_int dd;
dd[1] = makeDynInt(9, 1);
dd[2] = makeDynInt(1, 9);
dynDynSort(dd, 1);   // по первому столбцу: [1,9], [9,1]
dynDynSort(dd, 2);   // по второму столбцу
dynDynSort(dd, 0);   // ничего не делает, rc = число строк
```

### Методы и глобальные функции: соответствие

| Задача | Метод (`0`-based) | Глобальная (`1`-based) |
| --- | --- | --- |
| длина | `count()` | `dynlen()` |
| добавить | `append()` | `dynAppend()` |
| вставить | `insertAt(idx, val)`, `idx` `0…len` | `dynInsertAt(arr, val, pos)`, `pos` `1…len`, `0` = в конец |
| удалить | `removeAt(idx)` | `dynRemove(arr, pos)`, `pos = 0` → `-1` |
| поиск | `indexOf()`, `contains()` | `dynContains()` |
| все вхождения | `indexListOf()` → `vector<int>` | — |
| дубликаты | `unique()` → `0` | `dynUnique()` → новая длина |
| сортировка | — | `dynSort()`, `dynSortAsc()` |
| сумма/среднее | — | `dynSum()`, `dynAvg()` |

Правило простое: внутри метода индекс `0` — первый элемент; в глобальной
функции `1` — первый элемент. `0` у `dynInsertAt` — это не «в начало», а
«в конец».

Пример: [`09_dyn_globals.ctl`](../examples/14-legacyFoo/09_dyn_globals.ctl) —
58 проверок, без точек данных и сети.

## 9. Смешанные ключи

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

## 10. Порядок и позиционный доступ

Порядок в `mapping` не гарантирован. `mappingKeys()`, `mappingGetKey()` и
`mappingGetValue()` используют один и тот же внутренний порядок, поэтому
`mappingGetKey(m, i)` и `mappingGetValue(m, i)` согласованы между собой, но
не обязаны совпадать с порядком вставки. Не полагайтесь на порядок в
протоколах и сравнениях — проверяйте ключи через `mappingHasKey()`.

## 11. Типовой конвейер JSON + `net*`

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

`netPost()`/`netGet()` описаны в [13-http.md](13-http.md). Примеры 01–05 сеть
не используют: они проверяют только сборку, кодирование, разбор и структуру.
`06_httpServer.ctl` поднимает HTTP-сервер и делает loopback-запросы на
`127.0.0.1`; внешняя сеть ему не нужна.

## 12. Измеренные оговорки CTL 3.18 — коротко

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
| HTTP-сервер и завершение | с установленным `httpServer()` менеджер не выходит без `exit(0)` |
| `Status` в `dyn_string` | остаётся заголовком; HTTP-код меняет только `dyn_mixed` |
| `httpSetMethodHandler()` | `DELETE`/`PUT`/`OPTIONS`/`TRACE`/`CONNECT` — да; `PATCH`/`HEAD`/`GET`/`POST` — нет |
| `callFunction` без присваивания / в `DebugN` | продолжает (документация: закрывает скрипт) |
| `callFunction`: `private` и `synchronized` | вызываются; рекурсия synchronized тоже |
| `callFunction`: `void` | undefined `anytype` + `WARNING 73` |
| `callFunction`: неверный тип | приводится, без ошибки |
| `callFunction`: имя со скобками / регистр | `SEVERE 72` + `SEVERE 176`, скрипт останавливается |
| `checkScript`: `mapping &errorData` | в 3.18 нет, только `int &errorPos` |
| `checkScript("")`, без `main`, неизвестная функция | `TRUE` — только синтаксис |
| `evalScript`/`execScript`: ошибка времени выполнения | `rc = 0`, `SEVERE` в журнале |
| `evalScript`/`execScript`: `retVal` при `-1` | не сбрасывается |
| restricted: запрещённая функция | `rc = 0`, `WARNING 38`, `retVal` прежний |
| restricted: `callFunction` как обход | не работает |
| restricted: вложенный restricted | в 3.18 запрещён (с 3.19 разрешён) |
| прямой индекс `dyn_*` | с 1; `a[0]` — `SEVERE 79`, поток стоит |
| методы `dyn_*` | индексы с 0, как у `vector` |
| `lastIndexOf()` (метод) | **нет** у `dyn_*` и `vector`; `WARNING 72` |
| `at`/`insertAt`/`removeAt` за границей | исключение `SEVERE 176` + `WARNING 79` |
| `insertAt(idx)` | допустим `0…len`; `len` — в конец |
| `indexListOf()` без совпадений | пустой `vector<int>`, не `-1` |
| `indexOf()` без совпадений | `-1` |
| `unique()` (метод) | возвращает `0`, массив меняется на месте |
| `dynUnique()` | возвращает новую длину |
| метод у временного результата | `WARNING 73`/`76`, возврат недостоверен |
| `dynlen(vector)` | `-1` + `WARNING 77` |
| `dynAppendConst()` | в 3.18 **меняет** исходный массив |
| `dynInsertAt(..., 0)` или `pos > len` | добавление в конец |
| `dynRemove(..., 0)` | `rc = -1`, массив не меняется |
| `dynSort(arr, FALSE)` | по убыванию; `TRUE`/по умолчанию — по возрастанию |
| `dynSortDesc()` | **нет** |
| `dynSum/Avg/Min/Max` пустого | `-1` |
| `dynAvg` для `dyn_int` | `float` |
| `dynDynSort(arr, 0)` | тихий отказ: массив не меняется |
| `makeDynDynInt/String()` | **нет**; `dyn_dyn_*` — присваиванием строк |

## 13. Примеры

| Файл | Что проверяет |
| --- | --- |
| [`01_jsonEncode.ctl`](../examples/14-legacyFoo/01_jsonEncode.ctl) | простые значения, `dyn_`, `mapping`, pretty, `atime`, нестроковый ключ, опции 3.18 |
| [`02_jsonDecode.ctl`](../examples/14-legacyFoo/02_jsonDecode.ctl) | объект, массив, вложенность, ошибки синтаксиса и BOM, скалярная оговорка, `atime` |
| [`03_mapping.ctl`](../examples/14-legacyFoo/03_mapping.ctl) | `makeMapping`, присваивание, `mappingHasKey`, `mappingKeys`, `mappinglen`, позиционный доступ, `mappingRemove`, `mappingClear`, смешанные ключи |
| [`04_json_pipeline.ctl`](../examples/14-legacyFoo/04_json_pipeline.ctl) | сборка `mapping` → `jsonEncode` → `jsonDecode` → проверка структуры без сети |
| [`05_bits.ctl`](../examples/14-legacyFoo/05_bits.ctl) | `getBit`, `setBit`, `checkPattern`, `setPattern` на `bit32`, границы позиций, шаблоны |
| [`06_httpServer.ctl`](../examples/14-legacyFoo/06_httpServer.ctl) | `httpServer`, `httpConnect`/`httpDisconnect`, `httpGet*`, `httpSet*`, шаблон ресурса, `GET`/`POST`, `dyn_string`/`dyn_mixed`, loopback |
| [`07_dynamic_calls.ctl`](../examples/14-legacyFoo/07_dynamic_calls.ctl) | `callFunction` (встроенная, своя, `private`, `synchronized`, `void`, приведение типов, `isFunctionDefined`), `checkScript`, `evalScript`/`execScript`, restricted-режим и его обход через `callFunction` |
| [`08_dyn_methods.ctl`](../examples/14-legacyFoo/08_dyn_methods.ctl) | методы `dyn_*`: 0-based индексы, ссылки `first`/`at`, `insertAt`/`replaceAt`/`removeAt`, `take*`, `contains`/`indexOf`/`indexListOf`, `count`, `unique`, пустой массив, `vector` |
| [`09_dyn_globals.ctl`](../examples/14-legacyFoo/09_dyn_globals.ctl) | глобальные `dyn*`: `makeDyn*`, `dynlen`/`dynClear`, `dynAppend`/`dynAppendConst`, `dynInsertAt`/`dynRemove`, `dynContains`, `dynPatternMatch`, `dynSort`/`dynSortAsc`, `dynUnique`, математика, `dynDynTurn`/`dynDynSort` |

Запуск раздела:

```powershell
.\examples\verify.ps1 -Section 14-legacyFoo
```
