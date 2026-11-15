# 14. JSON, mapping, биты и HTTP-сервер — legacyFoo

Раздел назван `legacyFoo` по договорённости: сюда складываются функции CTL,
не относящиеся к точкам данных, и раздел будет пополняться. Сейчас в нём
четыре темы: JSON в памяти (`jsonEncode`, `jsonDecode`), ассоциативные массивы
`mapping`, работа с битами `bit32`/`bit64` и HTTP-сервер (`httpServer()` и
семейство `http*`).

> ⛔ **JSON ≠ HTTP.** `jsonEncode()` и `jsonDecode()` работают только с памятью
> CTL-скрипта и **не делают сетевых запросов**. HTTP — это `netGet()`,
> `netPost()` и остальные `net*` из [13-http.md](13-http.md). Конвейер
> «собрать JSON → отправить → разобрать ответ» описан в разделе 8.

Источники (документация 3.21.6, проверка — CTL 3.18):

* [Mapping Functions](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/Control_Grundlagen/mapping_functions.html)
* [jsonEncode()](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/ControlE_R/jsonEncode.html)
* [jsonDecode()](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/ControlE_R/jsonDecode.html)
* [32/64 bit Functions](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/Control_Grundlagen/Control_Grundlagen-28.html)
* [httpServer()](https://www.winccoa.com/documentation/WinCCOA/latest/en_US/ControlE_R/httpServer.html)
* [httpConnect()](https://www.winccoa.com/documentation/WinCCOA/latest/en_US/ControlE_R/httpConnect.html)
* [HTTP Functions](https://www.winccoa.com/documentation/WinCCOA/latest/de_AT/Control_Grundlagen/http_functions.html)

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

## 6. Смешанные ключи

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

## 7. Порядок и позиционный доступ

Порядок в `mapping` не гарантирован. `mappingKeys()`, `mappingGetKey()` и
`mappingGetValue()` используют один и тот же внутренний порядок, поэтому
`mappingGetKey(m, i)` и `mappingGetValue(m, i)` согласованы между собой, но
не обязаны совпадать с порядком вставки. Не полагайтесь на порядок в
протоколах и сравнениях — проверяйте ключи через `mappingHasKey()`.

## 8. Типовой конвейер JSON + `net*`

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

## 9. Измеренные оговорки CTL 3.18 — коротко

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

## 10. Примеры

| Файл | Что проверяет |
| --- | --- |
| [`01_jsonEncode.ctl`](../examples/14-legacyFoo/01_jsonEncode.ctl) | простые значения, `dyn_`, `mapping`, pretty, `atime`, нестроковый ключ, опции 3.18 |
| [`02_jsonDecode.ctl`](../examples/14-legacyFoo/02_jsonDecode.ctl) | объект, массив, вложенность, ошибки синтаксиса и BOM, скалярная оговорка, `atime` |
| [`03_mapping.ctl`](../examples/14-legacyFoo/03_mapping.ctl) | `makeMapping`, присваивание, `mappingHasKey`, `mappingKeys`, `mappinglen`, позиционный доступ, `mappingRemove`, `mappingClear`, смешанные ключи |
| [`04_json_pipeline.ctl`](../examples/14-legacyFoo/04_json_pipeline.ctl) | сборка `mapping` → `jsonEncode` → `jsonDecode` → проверка структуры без сети |
| [`05_bits.ctl`](../examples/14-legacyFoo/05_bits.ctl) | `getBit`, `setBit`, `checkPattern`, `setPattern` на `bit32`, границы позиций, шаблоны |
| [`06_httpServer.ctl`](../examples/14-legacyFoo/06_httpServer.ctl) | `httpServer`, `httpConnect`/`httpDisconnect`, `httpGet*`, `httpSet*`, шаблон ресурса, `GET`/`POST`, `dyn_string`/`dyn_mixed`, loopback |

Запуск раздела:

```powershell
.\examples\verify.ps1 -Section 14-legacyFoo
```
