# net-test-server — HTTP-сервер для тестирования net* функций WinCC OA CTL

Эмулирует HTTP-сервер для проверки клиентских функций `netGet()`, `netPost()`,
`netPut()`, `netDelete()`, `netHead()` из CTL-скриптов (раздел 13 скилла).

## Запуск

```powershell
python tools/net-test-server/net_test_server.py
# по умолчанию: http://127.0.0.1:18080

python tools/net-test-server/net_test_server.py --port 18080 --bind 127.0.0.1
```

## Эндпоинты

| Метод | Путь | Ответ | Назначение |
| --- | --- | --- | --- |
| `GET` | `/get` | `200`, JSON + заголовки | базовый GET с полным ответом |
| `GET` | `/missing` | `404`, текст | проверка `rc=-1` + `httpStatusCode=404` |
| `GET` | `/error` | `500`, текст | проверка серверной ошибки |
| `GET` | `/bad` | `400`, текст | проверка `400 Bad Request` |
| `GET` | `/redirect` | `302` → `/get` | проверка `followRedirection` |
| `GET` | `/target` | `200`, JSON | проверка сохранения в `target`-файл |
| `GET` | `/hang` | соединение без ответа | проверка блокирующего поведения |
| `POST` | `/post` | `201`, JSON + эхо тела | проверка POST с данными |
| `PUT` | `/put` | `200`, JSON + эхо тела | проверка PUT |
| `DELETE` | `/delete` | `204`, без тела | проверка DELETE |
| `HEAD` | `/head` | `200`, только заголовки | проверка HEAD (тело пустое) |

Все запросы логируются в stdout с уникальным id и меткой времени.

## Примеры CTL

Примеры лежат в `examples/13-net/`:

- `01_netGet.ctl` — `netGet`: 200/404, `mapping`/`string`/`blob`, редирект, `target`
- `02_netPost.ctl` — `netPost`: JSON-данные, `Content-Type`
- `03_netPutDeleteHead.ctl` — `netPut`, `netDelete`, `netHead`
- `04_net_errors.ctl` — ошибки: `connection refused`, невалидный URL, 500, 400

Запуск примера:

```powershell
# 1. Запустить сервер (в одном окне)
python tools/net-test-server/net_test_server.py

# 2. Запустить пример CTL (в другом окне)
.\examples\run-ctl.ps1 -Script .\examples\13-net\01_netGet.ctl -WaitSeconds 20
```

## Проверка через гейт

Раздел `13-net` по умолчанию **исключён** из `.\verify.ps1 -All` (требует
сети и запущенного сервера, как `11-address`). Включить:

```powershell
.\verify.ps1 -All -IncludeNet
```

Перед этим нужно запустить `net_test_server.py`.

## Требования

- Python 3 (только стандартная библиотека, без внешних зависимостей)
- Порт 18080 (или другой через `--port`) должен быть свободен
