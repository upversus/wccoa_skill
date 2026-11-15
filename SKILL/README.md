# Скилл WinCC OA 3.18

Справочник проверенных функций точки данных, примеры CTL и инструменты.
Содержимое проверено запуском на живом проекте, а не взято из документации.

Это автономная папка: переносится целиком, пути внутри относительные,
внешние зависимости — только WinCC OA 3.18 и, для OPC UA, Node не нужен.

## Что внутри

| Папка | Содержание |
| --- | --- |
| `SKILL.md` | входная точка: правила, порядок работы, индекс задач |
| `docs/` | справочник по операциям CTL, с измеренными оговорками к документации (включая раздел 13 по клиентским HTTP-функциям `net*`, раздел 14 по JSON/mapping и раздел 15 по прямым запросам к InfluxDB — только чтение) |
| `examples/` | 87 примеров CTL по этапам; финальный гейт `-All` прогоняет 53, раздел `11-address` (17) — отдельно на подготовленном стенде, раздел `13-net` (4) — с запущенным тестовым HTTP-сервером, раздел `15-influx` (1) — с живой InfluxDB |
| `playbooks/` | четыре пошаговых сценария задач |
| `tools/` | эмулятор Modbus, генератор CTL, валидатор, `opcuactl` |

## Требования

| Что | Версия | Обязательно |
| --- | --- | --- |
| WinCC OA | 3.18 | да |
| PowerShell | 5.1 и новее | да |
| Node.js | 18 и новее | для Modbus, проверялся на 22.22 |
| OPC UA сервер | любой | только для задач OPC UA |

Путь к интерпретатору CTL ищется через переменную `WCCOA_CTRL_EXE`, а
если она не задана — в стандартной установке `C:\Sybcom\Kaskad\3.18`,
затем в типовых местах в `Program Files`:

```powershell
$env:WCCOA_CTRL_EXE = 'C:\Sybcom\Kaskad\3.18\bin\WCCOActrl.exe'
```

## Перенос

Папка самодостаточна. Чтобы перенести, достаточно скопировать каталог
целиком. Ничего править не нужно: внутри нет абсолютных путей, кроме
значения по умолчанию расположения WinCC OA в `examples/run-ctl.ps1`,
которое переопределяется переменной окружения.

Папка `.git` не нужна, Git не требуется. `examples/verify.ps1` и
`tools/modbus-sim` используют только PowerShell и Node.

## Проверка после переноса

Три команды, каждая сообщает о себе сама.

```powershell
# 1. инструмент OPC UA на месте
.\tools\opcuactl\opcuactl.exe version

# 2. эмулятор и валидатор работают
node .\tools\modbus-sim\validate-map.js .\tools\modbus-sim\devices\smart-temp-press.json --port 1502
# ожидается: "Ошибок нет", код возврата 0

# 3. генератор собирает точку
node .\tools\gen-modbus-dp.js .\tools\modbus-sim\devices\smart-temp-press.json `
     --out $env:TEMP\check.ctl --dp CHECK --dpt check_t --no-verify
# ожидается: "Всего элементов: 40", код возврата 0
```

Полная проверка на живом проекте:

```powershell
.\examples\verify.ps1 -All
```

Гейт прогоняет 53 скрипта (разделы 00–09, `14-legacyFoo` и сценарий). Раздел
`11-address` исключён намеренно: ему нужен подготовленный стенд — эмулятор
Modbus, настроенный OPC UA, карта адресов. Раздел `13-net` исключён, пока не
запущен HTTP-тестовый сервер, а `15-influx` — пока не поднята InfluxDB стенда
(база `kaskadhdb` на `127.0.0.1:8086`). Гейт всегда сообщает в выводе, сколько
скриптов исключено и почему. Когда окружение готово, добавьте
`-IncludeAddress`, для `13-net` — `-IncludeNet`, для `15-influx` —
`-IncludeInflux`. Прогон занимает несколько минут и создаёт временные точки,
которые за собой убирает.

Полный прогон: 53/53, код возврата 0. Раздел `14-legacyFoo` даёт 6 примеров и
160 проверок; раздел `13-net` при `-IncludeNet` — ещё 4 примера и 38 проверок;
раздел `15-influx` при `-IncludeInflux` — 1 пример и 24 проверки. С
`-IncludeInflux` гейт прогоняет 54 скрипта.

## Лицензии и сторонние компоненты

Скилл распространяется под **MIT** — текст в файле `LICENSE` в корне.
Можно копировать, менять и использовать, в том числе в коммерческих
проектах; при распространении нужно сохранить уведомление об авторстве.

| Компонент | Лицензия | Что сделать при публикации |
| --- | --- | --- |
| содержимое `docs/`, `examples/`, `playbooks/` | **MIT**, файл `LICENSE` в корне | ничего, лицензия уже приложена |
| `tools/gen-modbus-dp.js`, `tools/modbus-sim/*` | **MIT**, файл `LICENSE` в корне | ничего, лицензия уже приложена |
| `tools/opcuactl/opcuactl.exe` | **MIT**, `github.com/otfabric/opcuactl` | текст лицензии уже лежит рядом, в `tools/opcuactl/LICENSE` |

Двоичный файл `opcuactl.exe` — 8,1 МБ, windows/amd64, версия 0.2.0.
Подробности в `tools/opcuactl/PROVENANCE.md`.

Если публикуешь без OPC UA, `tools/opcuactl/` можно удалить, остальное
работать не перестанет.

## Честно о границах

- Проверено на CTL 3.18 с драйверами Modbus и OPC UA. На другой версии
  расхождения с документацией могут быть другими.
- Для OPC UA нет генератора адресов и эмулятора: обход сервера и чтение
  данных проверены на Kepware KEPServerEX, а разбор карты в адреса — нет.
- `docs/04-write.md` и `docs/08-alerts.md` без
  примеров скриптов.
- Проверка на одном поколении стенда, не на нескольких независимых.

Подробный список — в `SKILL.md`, раздел «Известные дыры».

## Реализованные функции CTL

Все функции ниже проверены запуском на живом проекте. Устаревшие,
нереализованные и исключённые функции не в списке.

### 01-create — создание, проверка, имена
`dpCreate()`, `dpExists()`, `dpTypeCreate()`, `dpTypeGet()`, `dpTypes()`,
`dpTypeName()`, `dpTypeRefName()`, `dpGetDpTypeRefs()`, `dpGetRefsToDpType()`,
`dpNames()`, `nameCheck()`

### 02-config — конфиги, атрибуты, оформление
`dpSet()`, `dpSetWait()`, `dpSetTimed()`, `dpSetTimedWait()`, `dpSetAlias()`,
`dpGetAlias()`, `dpSetUnit()`, `dpSetFormat()`, `dpSetDescription()`,
`dpGetDescription()`, `dpGetAllAttributes()`, `dpGetAllDetails()`,
`dpGetAllConfigs()`, `dpCopyConfig()`, `dpCopyConfigMerge()`,
`dpCopyConfigMergeBufferClear()`

### 03-read — чтение
`dpGet()`, `dpGetPeriod()`, `dpGetMaxAge()`, `dpGetStatusBit()`, `dpGetUnit()`,
`dpGetFormat()`, `dpElementType()`, `dpAttributeType()`, `dpSubStr()`,
`dpValToString()`, `dpAliasToName()`, `dpGetId()`, `dpGetName()`

### 05-subscribe — подписки
`dpConnect()`, `dpConnectUserData()`

### 06-query — SQL-запросы
`dpQuery()`, `checkQuery()`

### 07-copy — клонирование
`dpCopy()`, `dpCopyBufferClear()`

### 09-delete — удаление и смена типа
`dpDelete()`, `dpTypeDelete()`, `dpTypeChange()`

### 13-http — клиентские HTTP-функции net*
`netGet()`, `netPost()`, `netPut()`, `netDelete()`, `netHead()`

### 14-legacyFoo — JSON, mapping, биты, HTTP-сервер
`jsonEncode()`, `jsonDecode()`, `makeMapping()`, `mappingHasKey()`,
`mappingKeys()`, `mappinglen()`, `mappingGetKey()`, `mappingGetValue()`,
`mappingRemove()`, `mappingClear()`, `getBit()`, `setBit()`, `checkPattern()`,
`setPattern()`, `httpServer()`, `httpConnect()`, `httpDisconnect()`,
`httpGetMethod()`, `httpGetURI()`, `httpGetQuery()`, `httpGetHeader()`,
`httpGetAllHeaders()`, `httpGetContent()`, `httpGetPort()`, `httpGetLanguage()`,
`httpGetLanguageId()`, `httpSetMaxAge()`, `httpSetMaxContentLength()`,
`httpSetMethodHandler()`, `httpMakeParamString()`

### 15-influx — прямые запросы к InfluxDB проекта (только чтение)
`netGet()`, `httpMakeParamString()`, `jsonDecode()` — только `GET /query`,
база `kaskadhdb`. Запись в базу запрещена.

## Откуда взялось

WinCC OA 3.18, драйвер Modbus 2, эмулятор на TCP 504. Стенд тестовый,
его имя в скилле не упоминается намеренно: так примеры не привязаны
к одной машине.
