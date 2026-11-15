# 15. InfluxDB проекта: прямые HTTP-запросы (только чтение)

> ⛔ **Раздел только для чтения.** Все запросы здесь — `GET /query` и `SHOW`.
> Запись в базу этим способом **категорически запрещена**: ни `POST /write`,
> ни line protocol, ни `INSERT`/`DROP`/`DELETE`. База — рабочее хранилище
> тревог и событий стенда, а не полигон.

WinCC OA 3.18 пишет архив тревог и событий NGA в InfluxDB. Раздел описывает
прямой доступ к этой базе по HTTP: как подключиться, что внутри, какие
запросы работают и где ловушки. Это не замена `dpGet()` и не архив значений —
см. раздел 6.

Проверено на стенде 2026-11-15: InfluxDB 1.8.3 OSS, база `kaskadhdb`.
Каждый запрос в разделе выполнен, ответы приведены фактические.

Полезно, когда нужно:

- выгрузить тревоги или события за период в отчёт, минуя WinCC OA;
- сверить, что NGA действительно записал тревогу в архив;
- посмотреть историю изменения значения точки, когда архива значений нет;
- построить график или сводку во внешнем инструменте (Python, PowerShell).

## 1. Подключение

| Параметр | Значение |
| --- | --- |
| Версия | InfluxDB 1.8.3 OSS, InfluxQL, HTTP API v1 (`/query`) |
| Адрес | `http://127.0.0.1:8086` |
| База | `kaskadhdb` — единственная в инстансе |
| Пользователь | `kaskad` (администратор, ALL PRIVILEGES на `kaskadhdb`) |
| Пароль | `kaskad#123` |
| Аутентификация | query-параметры `u`/`p` либо `Authorization: Basic` |
| HTTPS | выключен (`https-enabled = false` в конфиге проекта) |

Информация не секретная: это локальный стенд, база слушает только свою
машину, учётные данные лежат открытым текстом в `config/influxdb.conf`.

### Проверка доступности

```powershell
curl.exe -s -i http://127.0.0.1:8086/ping
```

```
HTTP/1.1 204 No Content
X-Influxdb-Version: 1.8.3
```

| Ответ | Что значит |
| --- | --- |
| `204` | сервер жив, аутентификация для `/ping` не требуется |
| `401 unauthorized` | неверные учётные данные или незакодированный `#` в пароле |
| `connection refused` | сервис не запущен (нет `influxd`/NGA) |

### `#` в пароле — главная причина `401`

Пароль содержит `#`, а `#` в URL начинает фрагмент: строка обрывается, до
сервера доходит пустой пароль. Поэтому в URL пароль **обязательно**
кодируется как `kaskad%23123`:

```text
http://127.0.0.1:8086/query?db=kaskadhdb&u=kaskad&p=kaskad%23123&q=SHOW%20MEASUREMENTS
```

**Измерено:** `p=kaskad#123` → `401 {"error":"authorization failed"}`;
`p=kaskad%23123` → `200`.

Basic-аутентификация тоже работает:

```powershell
curl.exe -s -i -u 'kaskad:kaskad#123' -G 'http://127.0.0.1:8086/query' `
  --data-urlencode 'db=kaskadhdb' `
  --data-urlencode 'q=SHOW MEASUREMENTS'
```

Здесь `#` безопасен: его кодирует сам `curl`.

## 2. Структура базы

```
kaskadhdb
├── retention policy autogen   default, duration 0s, shard 168h  — ПУСТАЯ
├── retention policy ALERT     duration 0s, shard 24h
│   └── measurement ALERT      тревоги (alert archive NGA)
└── retention policy EVENT     duration 0s, shard 24h
    └── measurement EVENT      события (event archive NGA)
```

`SHOW RETENTION POLICIES ON kaskadhdb` (измерено):

| name | duration | shardGroupDuration | default |
| --- | --- | --- | --- |
| `autogen` | `0s` | `168h0m0s` | `true` |
| `ALERT` | `0s` | `24h0m0s` | `false` |
| `EVENT` | `0s` | `24h0m0s` | `false` |

`duration 0s` — хранение бессрочное. Шарды режутся по суткам.

Имена политик совпадают с именами измерений. Из-за этого **работает только
трёхчастное имя** `"rp"."measurement"`; запрос без RP ищет измерение в
политике по умолчанию `autogen` и молча возвращает пустоту (ловушка 1).

Полный состав измерений и схема:

```sql
SHOW DATABASES
SHOW RETENTION POLICIES ON kaskadhdb
SHOW MEASUREMENTS ON kaskadhdb
SHOW SHARDS
```

### 2.1. `ALERT` — тревоги

Живёт в RP `ALERT`. Одна строка — одна запись тревоги.

**Теги (5):** `name`, `variabletype`, `_dpid_dp`, `_dpid_el`, `detail`.

`name` — DPE, `variabletype` — тип точки, `_dpid_dp` / `_dpid_el` —
внутренние идентификаторы точки и элемента, `detail` — номер detail-а.

**Поля (33)**, `SHOW FIELD KEYS FROM "ALERT"."ALERT"`:

| Тип | Поля |
| --- | --- |
| string | `_abbr_0`, `_abbr_1`, `_alert_color`, `_alert_font_style`, `_alert_fore_color`, `_alert_id`, `_class`, `_comment`, `_dest_text_0`, `_dest_text_1`, `_panel`, `_text_0`, `_text_1` |
| integer | `_ack_state`, `_ack_type`, `_ack_user`, `_dest`, `_partn_idx`, `_prior`, `_state`, `_value_status64`, `alarmvalue_type`, `count` |
| float | `_ack_time`, `_partner`, `_system_time`, `alarmvalue_float` |
| boolean | `_ackable`, `_direction`, `_inact_ack`, `_single_ack`, `_visible`, `alarmvalue_bool` |

Поля `valuetype` в `ALERT` **нет** — тип значения лежит в `alarmvalue_type`.

`SELECT *` даёт 39 колонок: `time` + 33 поля + 5 тегов (включая `name` и
`variabletype`).

`count` — поле с именем агрегатной функции. В кавычках и без кавычек
работает одинаково (**измерено**), но кавычки однозначны:

```sql
SELECT "count", "alarmvalue_type" FROM "ALERT"."ALERT" LIMIT 3
```

**Содержимое (снимок 2026-11-15):** 19 строк,
`2026-10-23T13:17:04.645Z` — `2026-11-11T12:39:13.037Z`. Тревоги тоже
пополняются: при повторной проверке в тот же день строк уже 20.

| `variabletype` | Строк |
| --- | --- |
| `ExampleDP_Bit` | 10 |
| `_LicenseSrv` | 6 |
| `ExampleDP_Float` | 3 |

Всего три `name`:

```text
System1:ExampleDP_AlertHdl1.
System1:ExampleDP_Arg1.
System1:_LicenseSrv_server1.States.isLicenseValid
```

### 2.2. `EVENT` — события

Живёт в RP `EVENT`. Одна строка — одно изменение значения.

**Теги (2):** `name`, `variabletype`.

**Поля (9):**

| Поле | Тип | Смысл |
| --- | --- | --- |
| `original_value_float` | float | значение для числовых типов |
| `original_value_int` | integer | значение для целых |
| `original_value_string` | string | значение для строковых |
| `valuetype` | integer | тип значения: 2 — int, 3 — float, 4 — string |
| `_manager` | integer | номер менеджера, сделавшего запись |
| `_status64` | integer | статус значения, 64-битная маска |
| `_user` | integer | пользователь |
| `_comment` | string | комментарий |
| `_unit` | string | единица измерения |

`SELECT *` даёт 12 колонок: `time` + 9 полей + 2 тега.

**Содержимое:** на снимке 08:28 UTC — 1760 строк,
`2026-10-23T13:09:33.589Z` — `2026-11-15T08:23:47.181Z`; при прогоне
примера в 11:58 — уже 1782. База пополняется в реальном времени.

| `variabletype` | Строк (снимок) |
| --- | --- |
| `_ReduManager` | 1570 |
| `ExampleDP_Float` | 119 |
| `_Ui` | 71 |

Всего 7 `name`:

```text
System1:_ReduManager.MaxMyErrorStatus
System1:_ReduManager.MyErrorStatus
System1:_ReduManager.MyErrorStatusRemote
System1:_ReduManager.ErrorChangeReason
System1:_Ui_1.UserName
System1:_Ui_2.UserName
System1:ExampleDP_Arg1.
```

## 3. Как выполнить запрос

### 3.1. Браузер

Достаточно открыть URL — ответ придёт JSON-ом:

```text
http://127.0.0.1:8086/query?db=kaskadhdb&u=kaskad&p=kaskad%23123&q=SHOW%20MEASUREMENTS
```

```text
http://127.0.0.1:8086/query?db=kaskadhdb&u=kaskad&p=kaskad%23123&q=SELECT%20*%20FROM%20%22EVENT%22.%22EVENT%22%20LIMIT%203
```

Таблиц API v1 не отдаёт: `&pretty=true` только форматирует JSON. Для
табличного вывода — 3.3 или 3.4. Пробелы и кавычки в `q` кодируются вручную
(`%20`, `%22`), поэтому длинные запросы удобнее слать из скрипта.

### 3.2. curl

```powershell
# Список измерений
curl.exe -s -G 'http://127.0.0.1:8086/query' `
  --data-urlencode 'db=kaskadhdb' `
  --data-urlencode 'u=kaskad' `
  --data-urlencode 'p=kaskad#123' `
  --data-urlencode 'q=SHOW MEASUREMENTS'

# Последние 3 события
curl.exe -s -G 'http://127.0.0.1:8086/query' `
  --data-urlencode 'db=kaskadhdb' `
  --data-urlencode 'u=kaskad' `
  --data-urlencode 'p=kaskad#123' `
  --data-urlencode 'q=SELECT * FROM "EVENT"."EVENT" ORDER BY time DESC LIMIT 3'
```

`--data-urlencode` кодирует `#`, кавычки и пробелы — руками ничего
экранировать не нужно.

### 3.3. PowerShell

```powershell
$q = @{
    db = 'kaskadhdb'
    u  = 'kaskad'
    p  = 'kaskad#123'
    q  = 'SELECT "original_value_float" FROM "EVENT"."EVENT" WHERE "name" = ''System1:ExampleDP_Arg1.'' LIMIT 3'
}
$s = (Invoke-RestMethod -Uri 'http://127.0.0.1:8086/query' -Body $q).results.series[0]
$s.columns -join ' | '
$s.values | ForEach-Object { $_ -join ' | ' }
```

Фактический вывод:

```text
time | original_value_float
04.11.2026 6:52:57 | 11,1
04.11.2026 6:52:58 | 22,2
04.11.2026 6:52:59 | 33,3
```

`#` в хэш-таблице безопасен — кодирование делает `Invoke-RestMethod`.
Время он сам разбирает в `DateTime` и печатает по локали, поэтому в выводе
не `2026-11-04T06:52:57Z`, а `04.11.2026 6:52:57` (ловушка 9).

### 3.4. Python

```python
import json, urllib.parse, urllib.request

params = urllib.parse.urlencode({
    "db": "kaskadhdb", "u": "kaskad", "p": "kaskad#123",
    "q": 'SELECT * FROM "EVENT"."EVENT" LIMIT 2',
})
with urllib.request.urlopen("http://127.0.0.1:8086/query?" + params, timeout=10) as r:
    data = json.load(r)
print(list(data["results"][0]["series"][0].keys()))
print(data["results"][0]["series"][0]["columns"][:4])
```

Фактический вывод:

```text
['name', 'columns', 'values']
['time', '_comment', '_manager', '_status64']
```

`requests` работает так же: `requests.get(url, params={...})`.

### 3.5. CTL

Из CTL запрос собирается тремя функциями: `httpMakeParamString()` кодирует
параметры, `netGet()` делает GET, `jsonDecode()` разбирает ответ.
`httpMakeParamString()` требует `#uses "CtrlHTTP"`.

```c
#uses "CtrlHTTP"

dyn_string n = makeDynString("db", "u", "p", "q");
dyn_string v = makeDynString("kaskadhdb", "kaskad", "kaskad#123",
                             "SELECT * FROM \"EVENT\".\"EVENT\" ORDER BY time DESC LIMIT 3");
string url = "http://127.0.0.1:8086/query?" + httpMakeParamString(n, v);

mapping res;
int rc = netGet(url, res);                       // 0 = HTTP 2xx, -1 = ошибка
mapping doc;
if (mappingHasKey(res, "content"))
  doc = jsonDecode((string)res["content"]);

dyn_mixed results = doc["results"];              // массивы 1-базовые
mapping   r0      = results[1];
dyn_mixed series  = r0["series"];
mapping   s0      = series[1];
dyn_mixed rows    = s0["values"];
DebugN(rows[1][1], rows[1][7]);                  // time, name первой строки
```

Готовый пример с проверками — `examples/15-influx/01_netGet_influx.ctl`
(24 проверки: кодирование пароля, форма ответа, пустой результат, 400 и 401).
Запуск:

```powershell
.\examples\run-ctl.ps1 -Script .\examples\15-influx\01_netGet_influx.ctl
```

**Измерено:** `netGet()` на `200` даёт `rc = 0`, на `400` и `401` — `rc = -1`,
но `httpStatusCode` и JSON-тело в `mapping` заполнены. Если сервер не
ответил вовсе, ключа `httpStatusCode` в `mapping` нет — проверяйте через
`mappingHasKey()`.

## 4. Полезные запросы

Все выполнены на стенде; ответы сокращены. Числа — снимок 2026-11-15,
база пополняется в реальном времени, поэтому `count(*)` со временем растёт.

```sql
-- схема
SHOW MEASUREMENTS ON kaskadhdb
SHOW TAG KEYS FROM "ALERT"."ALERT"
SHOW FIELD KEYS FROM "ALERT"."ALERT"
SHOW FIELD KEYS FROM "EVENT"."EVENT"
SHOW TAG VALUES FROM "EVENT"."EVENT" WITH KEY = "name"

-- последние события
SELECT * FROM "EVENT"."EVENT" ORDER BY time DESC LIMIT 50

-- тревоги за 30 дней
SELECT * FROM "ALERT"."ALERT" WHERE time >= now() - 30d

-- значения одной точки за 7 дней
SELECT "original_value_float" FROM "EVENT"."EVENT"
WHERE "name" = 'System1:ExampleDP_Arg1.' AND time >= now() - 7d

-- только пользовательские события, без системных менеджеров
SELECT * FROM "EVENT"."EVENT" WHERE "variabletype" !~ /^_/

-- почасовое среднее: агрегат обязателен
SELECT mean("original_value_float") FROM "EVENT"."EVENT"
WHERE "name" = 'System1:ExampleDP_Arg1.'
GROUP BY time(1h)

-- счётчик строк по каждому полю
SELECT count(*) FROM "EVENT"."EVENT"
```

Фактические ответы:

```text
SELECT "original_value_float" ... LIMIT 3
["2026-11-15T07:58:18.764Z",555.5]
["2026-11-15T07:58:13.677Z",2345.5]
["2026-11-15T07:58:12.664Z",1234.5]

SELECT count(*) FROM "EVENT"."EVENT"
columns: time, count__comment, count__manager, count__status64, count__unit,
         count__user, count_original_value_float, count_original_value_int,
         count_original_value_string, count_valuetype
values:  1970-01-01T00:00:00Z, 1760, 1760, 1760, 1760, 1760, 119, 785, 856, 1760
```

`count(*)` полезен, когда непонятно, какое поле заполняется: на снимке видно
`original_value_float` — 119, `original_value_int` — 785,
`original_value_string` — 856.

`GROUP BY time(12h)` возвращает и пустые корзины со значением `null`:
в CTL такое значение приходит как `-?-`, в JSON — как `null`. Это не ошибка.

## 5. Ловушки

1. **Запрос без retention policy возвращает пустоту.**
   `SELECT * FROM "ALERT"` ищет измерение в RP по умолчанию `autogen`,
   а он пуст: ответ `{"results":[{"statement_id":0}]}` — без ошибки, ноль
   строк. Нужно `FROM "ALERT"."ALERT"` / `FROM "EVENT"."EVENT"`.

2. **Пустой ответ ≠ ошибка.** На запрос без данных InfluxDB отдаёт `200` и
   `results` **без** ключа `series`. Код обязан проверять наличие `series`
   до индексации. В CTL: `mappingHasKey(r0, "series")`.

3. **Пароль в URL.** `kaskad#123` → `kaskad%23123`. Иначе `401`.

4. **Значения тегов — точные строки.** `name` у DPE включает точку на конце:
   `'System1:ExampleDP_Arg1.'`. Без точки — ноль строк, тоже без ошибки.
   Список значений: `SHOW TAG VALUES FROM "EVENT"."EVENT" WITH KEY = "name"`.

5. **Время в UTC.** InfluxDB всегда отдаёт `Z`. МСК = UTC+3; `now() - 7d`
   считается по UTC, разницы не даёт.

6. **`LIKE` не работает.** Только регулярные выражения: `=~ /^System1:/`,
   `!~ /^_/`. На `LIKE` приходит
   `error parsing query: found LIKE, expected ;`, а не пустой ответ.

7. **Теги нельзя агрегировать как поля.** `count("name")` не ошибка, а пустой
   ответ: `name` — тег. Считать по полю: `count("valuetype")`.

8. **`GROUP BY time()` требует агрегат** в списке выборки, иначе
   `GROUP BY requires at least one aggregate function`.

9. **PowerShell меняет время.** `Invoke-RestMethod` и `ConvertFrom-Json`
   разбирают ISO-строки в `DateTime`, поэтому `time` печатается по локали.
   Для отчёта читайте ответ через `curl` или разбирайте текст вручную:
   у `ConvertFrom-Json` в PowerShell 7.5+ есть ключ `-DateKind String`,
   а у `Invoke-RestMethod` такого ключа нет (проверено на 7.7).

10. **`count("valuetype")` по `ALERT` — пусто.** Поля `valuetype` в `ALERT`
    нет; пустой ответ выглядит как «нет данных». Считать надо по
    `count("alarmvalue_type")` или `count("count")`.

11. **64-битные значения.** `_status64` и `_value_status64` выходят за
    `2^53`: `-9007199254737846015`. CTL и PowerShell 7 держат их как 64-битные
    целые, а `JSON.parse` в Node/JS теряет младшие разряды:
    `-9007199254737846000` (**измерено**). Если значение уходит в браузер или
    JS — передавайте его строкой или не читайте вовсе.

12. **`count` — имя поля.** В `ALERT` есть поле `count`. В списке выборки
    работает и без кавычек, но с кавычками однозначно:
    `SELECT "count" FROM "ALERT"."ALERT"`.

## 6. Чего в базе нет

Отдельного измерения архива значений (value archive) нет — ни `WINCCOA`,
ни `_value`, ничего подобного. В базе только `ALERT` и `EVENT`, то есть
архивирование тревог и событий NGA, а RP `autogen` пуста.

Практическое следствие: строки в `EVENT` появляются только при изменении
значения. Если точка за период не менялась, запрос «значения за неделю»
вернёт пусто — это нормальный результат, а не ошибка запроса. Непрерывной
истории значений здесь не будет, пока архив значений NGA не настроен писать
в эту базу.

## 7. Где это настраивается

InfluxDB поднимает NGA, а не отдельная служба:

| Что | Где |
| --- | --- |
| Конфиг InfluxDB | `<проект>/config/influxdb.conf` |
| Аутентификация | `[http] auth-enabled = true` |
| HTTP-порт | `[http] bind-address`, по умолчанию `:8086` |
| Данные | `[data] dir = <проект>/db/prgcl_sd/influx`, WAL рядом |
| Метаданные | `[meta] dir = <проект>/db/prgcl_sd/influx/meta` |
| Писатель | процесс `WCCOAnextgenarch.exe` с ключом `-PROJ <проект>` |
| HTTPS | `https-enabled = false`; сертификаты `nga_influx.crt`/`.key` |

На стенде: `P_12_3_mb/config/influxdb.conf`, данные в
`C:/Sybcom/prg/P_12_3_mb/db/prgcl_sd/influx`.

На другом стенде порядок такой:

1. `SHOW DATABASES` — найти имя базы (у NGA обычно `<проект>hdb`).
2. `SHOW RETENTION POLICIES ON <база>` — проверить, что данные не в `autogen`.
3. `SHOW MEASUREMENTS ON <база>` — уточнить имена измерений: они могут
   отличаться от `ALERT`/`EVENT`.
4. Порт и `auth-enabled` — в `<проект>/config/influxdb.conf`.

Учётные данные NGA создаёт при инициализации базы; если пароль неизвестен,
его задаёт администратор стенда, а не скилл.
