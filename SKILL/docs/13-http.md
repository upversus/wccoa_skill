# 13. Клиентские HTTP-функции net*

> Проверено на CTL 3.18, проект `<проект стенда>`. Все пять функций компилируются
> и отрабатывают на живом стенде (измерено на локальном HTTP-сервере 127.0.0.1:18080).

Функции `netGet()`, `netPost()`, `netPut()`, `netDelete()` и `netHead()` — **клиентские**
HTTP-функции WinCC OA. Они выполняют HTTP-запрос из CTRL-скрипта и ждут ответа сервера.

**Не путать с серверной стороной:** `httpServer()` / `httpConnect()` принимают запросы
со стороны, а `net*` — отправляют их. Для FTP используйте `ftpDownload()` /
`ftpUpload()` — через `net*` FTP не является основным сценарием.

## Общие свойства группы net*

| Свойство | Значение |
| --- | --- |
| Блокирование | **да** — Waiting Control function, скрипт ждёт ответа сервера |
| Встроенный таймаут CTRL | **нет** — зависший/недоступный сервер зависнет скрипт надолго |
| Доступно в | UI и CTRL |
| Код возврата | `0` — HTTP-транзакция доведена до сервера, `-1` — ошибка (сеть, SSL, неверный URL) |

`rc == 0` **не гарантирует HTTP `2xx`**. Например, при `followRedirection = false`
сервер может вернуть `302` при `rc == 0`; при `4xx`/`5xx` `rc == -1`, но при
результате в `mapping` поля `httpStatusCode`/`httpStatusText` всё равно заполнены —
 их нужно читать даже при `rc == -1`.

## netGet()

**Синопсис:**
```c
int netGet(string url, mapping|string|blob &result [, mapping options]);
```

**Назначение.** Выполняет HTTP `GET` и сохраняет ответ сервера в `result`.

**Параметры:**
* `url` — обязательный URL со схемой `http`, `https` или `file`.
* `&result` — обязательный выходной параметр: `mapping`, `string` или `blob`.
* `options` — необязательный `mapping`: заголовки (`headers`), SSL
  (`ignoreSslErrors`), редиректы (`followRedirection`), `target` (файл для тела
  ответа).

**Возврат.** `0` — запрос wykonан, `-1` — ошибка.

Если `result` — `mapping`, доступны ключи:
* `headers` — заголовки ответа (mapping),
* `content` — тело ответа (string),
* `url` — фактический URL после редиректов,
* `httpStatusCode` / `httpStatusText` — код и текст HTTP-статуса,
* `target` — абсолютный путь файла, если указан в `options`,
* `sslErrors` — если SSL-ошибки проигнорированы.

При ошибке сети additionally появляются ключи `error` (ключ ошибки, например
`ConnectionRefusedError`) и `errorString` (описание).

**Типичные ошибки:**
* проверять только `rc != 0` и не смотреть `httpStatusCode` — `rc == 0` не значит `2xx`;
* ожидать заголовки и статус при передаче `string`/`blob` — там только тело;
* забывать, что функция блокирующая.

**Пример:**
```c
mapping result;
int rc = netGet("https://httpbin.org/get", result);
DebugN(rc, result["httpStatusCode"], result["httpStatusText"], result["content"]);
```

## netPost()

**Синопсис:**
```c
int netPost(string url, mapping|string|blob data [, mapping|string|blob &result]);
```

**Назначение.** Выполняет HTTP `POST` и передаёт данные на сервер.

**Параметры:**
* `url` — обязательный URL.
* `data` — обязательные отправляемые данные: `mapping`, `string` или `blob`.
* `&result` — необязательный выходной параметр для ответа сервера.

Если `data` — `mapping`, используются ключи:
* `content` — тело запроса,
* `headers` — дополнительные заголовки, включая `Content-Type`,
* `target` — путь к файлу/каталогу, куда сохранить **ответ** сервера (функция
  **не читает** файл по `target`, а пишет туда ответ),
* `ignoreSslErrors` — `""` (игнорировать все SSL-ошибки) или `dyn_string` со
  списком игнорируемых ошибок,
* `followRedirection` — `false` отключает автоматические редиректы.

**Возврат.** `0` — запрос wykonан, `-1` — ошибка (SSL, ошибка записи в `target` и т.п.).

**Типичные ошибки:**
* не указывать `Content-Type`, когда сервер его требует;
* ожидать гарантированную доставку;
* путать `target` в `data` с файлом, который отправляете;
* забывать про блокирующее поведение.

**Пример:**
```c
mapping data, result;
data["content"] = "{\"name\":\"test\"}";
data["headers"] = makeMapping("Content-Type", "application/json", "X-Probe", "client-ok");
int rc = netPost("https://httpbin.org/post", data, result);
DebugN(rc, result["httpStatusCode"], result["content"]);
```

## netPut()

**Синопсис:**
```c
int netPut(string url, mapping|string|blob data [, mapping|string|blob &result]);
```

**Назначение.** Выполняет HTTP `PUT` — загрузку или замену ресурса на сервере.
По сигнатуре и поведению идентична `netPost()`; отличие только в HTTP-методе.

**Параметры:** те же, что у `netPost()` — `url`, `data`, необязательный `&result`;
ключи `data` (`content`, `headers`, `target`, `ignoreSslErrors`,
`followRedirection`) описаны в разделе `netPost()`.

**Возврат.** `0` — запрос wykonан, `-1` — ошибка.

**Типичные ошибки:** те же, что у `netPost()`; дополнительно `netPut()` не
гарантирует, что сервер действительно создал или заменил ресурс — смотрите
`httpStatusCode` в `result`.

Используйте `netPut()`, когда REST-сервер требует идемпотентного `PUT` по известному
URL, и `netPost()`, когда нужна обычная отправка данных без семантики `PUT`.

## netDelete()

**Синопсис:**
```c
int netDelete(string url, mapping|string|blob &result [, mapping options]);
```

**Назначение.** Выполняет HTTP `DELETE` — просит сервер удалить ресурс, идентифицируемый URL.

**Параметры:**
* `url` — обязательный URL ресурса.
* `&result` — обязательный выходной параметр для ответа сервера.
* `options` — необязательный `mapping` с заголовками, SSL-настройками,
  управлением редиректами и `target`.

**Возврат.** `0` — запрос wykonан, `-1` — ошибка.

Если `result` — `mapping`, доступны `headers`, `content`, `url`,
`httpStatusCode`, `httpStatusText`; при ошибке `-1` — также `errorString` и `error`
с ключом ошибки (например, `RedirectionLoop`).

**Типичные ошибки:**
* считать `0` доказательством удаления — сервер мог вернуть `403`/`404`;
* передавать `options` как `string`, хотя параметр — `mapping`.

## netHead()

**Синопсис:**
```c
int netHead(string url, mapping &result [, mapping options]);
```

**Назначение.** Выполняет HTTP `HEAD` — получает только заголовки без тела ответа.
Полезна для проверки существования ресурса, `Content-Length`, `Content-Type`,
`Last-Modified` и прочих метаданных.

**Параметры:**
* `url` — обязательный URL.
* `&result` — обязательный выходной `mapping` (`string`/`blob` компилируются, но
  возвращают пустое тело — для `HEAD` неинформативно; используйте `mapping`).
* `options` — необязательный `mapping` с `target`, `headers`,
  `ignoreSslErrors`, `followRedirection`.

**Возврат.** `0` — запрос wykonан, `-1` — ошибка. В `result` гарантированно есть
ключ `headers` с заголовками ответа. Если указан `target` как файл, файл создаётся,
но остаётся пустым — тела у `HEAD`-ответа нет.

**Типичные ошибки:**
* использовать `netHead()` для скачивания данных;
* передавать `string` в `&result`, тогда как требуется `mapping`.

## Общие замечания

1. **Блокировка.** Все `net*` — `Waiting Control functions`. Нет встроенного
   таймаута CTRL, поэтому недоступный сервер зависнет скрипт. Ограничивайте время
   ожидания снаружи (например, оберткойrun-ctl с `-WaitSeconds` или внешним
   watchdog).
2. **`rc == 0` ≠ HTTP `2xx`.** Всегда проверяйте `result["httpStatusCode"]` и
   `result["httpStatusText"]`, когда `result` — `mapping`.
3. **`mapping` против `string`/`blob`.** При `string`/`blob` сохраняется только
   тело, заголовки и статус теряются. Для диагностики и разбора ответа всегда
   используйте `mapping`.
4. **SSL.** Управляется ключом `ignoreSslErrors` в `options` (для `netGet`/
   `netDelete`/`netHead`) или в `data` (для `netPost`/`netPut`).
5. **`target`.** Путь, куда сохранить **ответ** сервера. `net*()` не читают файл по
   `target`.
6. **Смежные функции.** Серверная сторона — `httpServer()` / `httpConnect()`; FTP —
   `ftpDownload()` / `ftpUpload()`.

## Проверено на стенде CTL 3.18

| Поведение | Результат |
| --- | --- |
| `netGet` 200, `mapping` | `rc=0`, `httpStatusCode=200`, `headers`+`content` заполнены |
| `netGet` 404, `mapping` | `rc=-1`, но `httpStatusCode=404` и `content` доступны |
| `netGet` 200, `string` | `rc=0`, только тело, заголовки/статус потеряны |
| `netGet` 200, `blob` | `rc=0` |
| `netPost` JSON, 201 | `rc=0`, `httpStatusCode=201` |
| `netPut` JSON, 200 | `rc=0` |
| `netDelete`, 204 | `rc=0`, `content=""` |
| `netHead`, `mapping` | `rc=0`, `headers` заполнены, `content=""` |
| `netHead`, `string` | `rc=0`, тело пустое (HEAD без тела) |
| `followRedirection=false`, 302 | `rc=0`, `httpStatusCode=302`, `url` не меняется |
| `followRedirection=true`, 302 | `rc=0`, следует редиректу до 200 |
| `target` (файл) | файл создан, записано тело ответа |
| ошибка сети (connection refused) | `rc=-1`, `error="ConnectionRefusedError"`, `errorString="Connection refused"` |
| `ignoreSslErrors=""` | описано в документации, ключ передаётся в `options`/`data` |

Проверка ключей в `mapping` делайте через `mappingHasKey(m, "ключ")` — метод
`.hasKey()` в CTL 3.18 не существует.

## См. также

Сборка и разбор JSON в памяти CTL (`jsonEncode`, `jsonDecode`, `mapping`) —
[14-legacyFoo.md](14-legacyFoo.md). Типовой конвейер: `mapping` → `jsonEncode`
→ `netPost` → `netGet` → `jsonDecode` → `mappingHasKey`.
