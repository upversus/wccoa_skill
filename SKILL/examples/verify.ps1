<#
    verify.ps1 — прогон демонстрационных .ctl и разбор их сводок.

    Зачем этот скрипт: каждый пример сам себе печатает итог проверок, но итогов
    форматов оказалось четыре, и проверять результат приходилось глазами по
    выводу. Этот скрипт запускает примеры, разбирает сводку и печатает таблицу.

    Распознаваемые сводки:
        --- PASS= 3  FAIL= 0 ---              помощники dpdSummary() из _lib.ctl
        === ИТОГ: успешно 14, неудачно 0 ===  свой блок check()
        === ИТОГ: успешно 6 из 6 ===          без счётчика отказов
        (сводки нет)                          оценить нельзя

    Примеры:
      .\verify.ps1 -Script .\03-read\01_dpGet.ctl
      .\verify.ps1 -Section 03-read
      .\verify.ps1 -All

    Код возврата: 0 — все оценённые примеры прошли, 1 — есть сбои или примеры
    без сводки. Скрипты в папках exp\ и файлы, имя которых начинается с "_",
    не запускаются: это черновики и служебные файлы.
#>
[CmdletBinding()]
param(
    [string]$Script,
    [string]$Section,
    [switch]$All,
    # Как и в run-ctl.ps1, 'auto' - проект берётся из командной строки
    # запущенного рантайма. Явное имя нужно, только если поднято несколько
    # проектов одновременно.
    [string]$Project = 'auto',
    [int]$NumBase = 90,         # номер менеджера; ОДИН на все запуски
    [int]$WaitSeconds = 120,
    [switch]$ShowOutput,        # печатать полный вывод каждого скрипта
    [int]$SimPort = 0           # порт эмулятора Modbus; 0 — взять из map.json
)

$ErrorActionPreference = 'Stop'
try {
    chcp 65001 > $null
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
    Write-Warning "Не удалось переключить консоль на UTF-8: $($_.Exception.Message)"
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$runner = Join-Path $root 'run-ctl.ps1'
if (-not (Test-Path -LiteralPath $runner)) { throw "Не найден run-ctl.ps1 рядом с verify.ps1" }

# ---------------------------------------------------------------------------
# Разбор строки вывода DebugN.
# DebugN печатает JSON-массив: ["текст "][42][" хвост"]
# Внутри значения кавычки экранированы, поэтому их надо учесть в регекспе.
# ---------------------------------------------------------------------------
function ConvertFrom-DebugLine {
    param([string]$Line)
    if ($Line -notmatch '\[') { return $null }

    # ВАЖНО: DebugN печатает числа и логические значения БЕЗ кавычек,
    # а строки — в кавычках:  ["итог: "][14][" отказов "][0]
    # Разбор только вида ["..."] терял все числа, и сводка не находилась.
    $rx = '\[(?:"((?:[^"\\]|\\.)*)"|([^\]]*))\]'
    $sb = New-Object System.Text.StringBuilder
    $pos = 0

    foreach ($m in [regex]::Matches($Line, $rx)) {
        if ($m.Groups[1].Success) {
            [void]$sb.Append(($m.Groups[1].Value -replace '\\"', '"'))
        } else {
            [void]$sb.Append($m.Groups[2].Value)
        }
        $pos = $m.Index + $m.Length
    }

    # незакрытая скобка — начало многострочного значения dyn_anytype
    $tail = $Line.Substring($pos).TrimEnd(']')
    if ($tail) { [void]$sb.Append($tail) }

    if ($sb.Length -eq 0) { return $null }
    return $sb.ToString()
}

# ---------------------------------------------------------------------------
# Поиск сводки в выводе скрипта.
# Возвращает @{Pass; Fail; Kind; Raw} либо $null, если сводки нет.
# ---------------------------------------------------------------------------
function Get-Summary {
    param([string[]]$Lines)

    foreach ($l in $Lines) {
        # формат 1: --- PASS= 3  FAIL= 0 ---
        if ($l -match 'PASS=\s*(\d+)\s+FAIL=\s*(\d+)') {
            return @{ Pass = [int]$Matches[1]; Fail = [int]$Matches[2]; Kind = 'полная'; Raw = $l.Trim() }
        }
        # формат 2: === ИТОГ: успешно 14, неудачно 0 ===
        if ($l -match 'успешно\s+(\d+),\s*неудачно\s+(\d+)') {
            return @{ Pass = [int]$Matches[1]; Fail = [int]$Matches[2]; Kind = 'полная'; Raw = $l.Trim() }
        }
        # формат 3: === ИТОГ: успешно 6 из 6 ===   — счётчика отказов нет
        if ($l -match 'успешно\s+(\d+)\s+из\s+(\d+)') {
            return @{ Pass = [int]$Matches[1]; Fail = $null; Kind = 'без счётчика отказов'; Raw = $l.Trim() }
        }
    }
    return $null
}

# ---------------------------------------------------------------------------
# Отбор скриптов к прогону
# ---------------------------------------------------------------------------
$targets = @()

if ($Script) {
    $targets = @(Get-Item -LiteralPath $Script)
}
elseif ($Section) {
    $dir = Join-Path $root $Section
    if (-not (Test-Path -LiteralPath $dir)) { throw "Раздел не найден: $dir" }
    $targets = @(Get-ChildItem -LiteralPath $dir -Filter '*.ctl' -File | Sort-Object Name)
}
elseif ($All) {
    $targets = @(Get-ChildItem -LiteralPath $root -Filter '*.ctl' -File -Recurse |
                 Sort-Object FullName)
}
else {
    Write-Host 'Не указан ни -Script, ни -Section, ни -All.'
    Write-Host 'Примеры:'
    Write-Host '  .\verify.ps1 -Script .\03-read\01_dpGet.ctl'
    Write-Host '  .\verify.ps1 -Section 03-read'
    Write-Host '  .\verify.ps1 -All'
    return
}

# Отсев черновиков и служебных файлов
# Скрипты, у которых самопроверки нет по существу: утилиты уборки и черновые
# эксперименты. Отсутствие сводки у них - не дефект, поэтому в таблицу они не
# попадают и код возврата не роняют.
$exempt = @(
    '99_cleanup.ctl',
    '12_address_opcua_browse.ctl',
    '13_address_opcua_browse2.ctl',
    '14_read_temp.ctl',
    # Эксперимент, у которого отрицательный результат и есть ответ. Из трёх
    # вариантов строки адреса OPC UA работает один (NodeId с подпиской).
    # Browse Path и пустое поле подписки данных не дают - это зафиксировано
    # в docs/11-address.md. Сводить такой пример к "зелёному" нельзя.
    '11_address_opcua_fields.ctl',
    # Подписчики 05-subscribe: намеренно не завершаются сами. Проверяются
    # не разовым прогоном, а внешним триггером (см. шапку каждого скрипта),
    # поэтому сводки при одиночном запуске у них нет по существу.
    '01_dpConnect.ctl',
    '02_dpConnectUserData.ctl'
)

$before = $targets.Count
$targets = @($targets | Where-Object {
    $_.Name -notlike '_*' -and        # служебные: _lib.ctl и подобные
    $_.Name -notlike 'exp_*' -and    # черновики: exp_*.ctl
    $_.DirectoryName -notlike '*exp*' -and
    ($exempt -notcontains $_.Name)
})
if ($before -ne $targets.Count) {
    Write-Host "Пропущено служебных, черновиков и утилит без самопроверки: $($before - $targets.Count)"
}

if ($targets.Count -eq 0) {
    if ($before -gt 0) {
        Write-Host 'Все скрипты отфильтрованы: служебные и долгоживущие, сводки у них нет по существу.'
        return
    }
    throw 'К прогону нечего: файлов не найдено.'
}

# ---------------------------------------------------------------------------
# Предупреждения о предусловиях
# ---------------------------------------------------------------------------
# Порт эмулятора Modbus. Логика та же, что в modbus-sim.ps1: -SimPort
# важнее значения в map.json. Раньше здесь стояло жёсткое 504, поэтому
# запуск эмулятора на любом другом порту давал ложное «не запущен».
$simPort = $SimPort
if ($simPort -le 0) {
    $mapFile = Join-Path $PSScriptRoot '..\tools\modbus-sim\map.json'
    try {
        $rawMap = Get-Content -Raw -Encoding UTF8 $mapFile
        $rawMap = $rawMap -replace '(?m)^\s*//.*$', ''
        $simPort = [int](($rawMap | ConvertFrom-Json).port)
    }
    catch {
        Write-Warning "Не удалось прочитать порт из map.json: $($_.Exception.Message). Беру 504."
        $simPort = 504
    }
}

$modbusOn = @(Get-NetTCPConnection -LocalPort $simPort -State Listen -ErrorAction SilentlyContinue)
$needModbus = @($targets | Where-Object { $_.Name -match 'modbus' })

Write-Host ''
Write-Host '================================================================'
Write-Host " verify — примеров к прогону: $($targets.Count)"
if ($needModbus.Count -gt 0) {
    if ($modbusOn.Count -gt 0) {
        Write-Host " Эмулятор Modbus: порт $simPort слушает"
    } else {
        Write-Host " ВНИМАНИЕ: эмулятор Modbus не запущен (порт $simPort молчит)."
        Write-Host "   Примеры Modbus упадут: $($needModbus.Count). Запуск:"
        Write-Host '   tools\modbus-sim\modbus-sim.ps1 start'
    }
}
Write-Host '================================================================'

# ---------------------------------------------------------------------------
# Прогон
# ---------------------------------------------------------------------------
$rows = @()
$i = 0

foreach ($t in $targets) {
    $i++
    $rel = $t.FullName.Replace($root + '\', '')
    $num = $NumBase
    if ($num -ge 255) {
        Write-Warning "Номер $num больше 254, пропускаю $rel"
        $rows += [pscustomobject]@{ Скрипт = $rel; Прошло = 0; Отказов = $null; Статус = 'ПРОПУЩЕН'; Сводка = '-num >= 255' }
        continue
    }
    # Номер менеджера ОДИН на все запуски. Раньше был последовательный
    # (NumBase + номер скрипта), но это ничего не давало: run-ctl.ps1 дожидается
    # завершения каждого процесса, поэтому параллельных запусков не бывает и
    # гонки за номер не существует. Служебная точка _CtrlDebug_CTRL_ интерпретатор
    # не создаёт, а лишь предупреждает о её отсутствии, так что мусора тоже нет.

    $raw = & $runner -Script $t.FullName -Project $Project -Num $num -WaitSeconds $WaitSeconds -RawOut
    $lines = @()
    foreach ($rawLine in ($raw -split "`r?`n")) {
        $flat = ConvertFrom-DebugLine -Line $rawLine
        if ($null -ne $flat) { $lines += $flat }
    }

    $sum = Get-Summary -Lines $lines

    if ($ShowOutput) {
        Write-Host ''
        Write-Host "---------- $rel ----------"
        $lines | ForEach-Object { Write-Host $_ }
    }

    if ($null -eq $sum) {
        $rows += [pscustomobject]@{ Скрипт = $rel; Прошло = 0; Отказов = $null; Статус = 'НЕТ СВОДКИ'; Сводка = 'сводка не найдена' }
        Write-Host ("  {0,-46} {1}" -f $rel, 'НЕТ СВОДКИ')
        continue
    }

    $status =
        if ($sum.Fail -ne $null) {
            if ($sum.Fail -eq 0) { 'OK' } else { 'СБОЙ' }
        } else { 'НЕТ СЧЁТЧИКА' }

    $rows += [pscustomobject]@{
        Скрипт  = $rel
        Прошло  = $sum.Pass
        Отказов = $sum.Fail
        Статус  = $status
        Сводка  = $sum.Raw
    }

    Write-Host ("  {0,-46} {1,4}  {2,-16} {3}" -f `
        $rel, $sum.Pass, $status, $sum.Raw)
}

# ---------------------------------------------------------------------------
# Итог
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '================================================================'
Write-Host ' ИТОГ'
Write-Host '================================================================'
'{0,-46} {1,7} {2,8}  {3}' -f 'СКРИПТ', 'ПРОШЛО', 'ОТКАЗОВ', 'СТАТУС' | Write-Host
'-' * 86 | Write-Host

foreach ($r in $rows) {
    $f = if ($null -eq $r.Отказов) { '—' } else { $r.Отказов }
    '{0,-46} {1,7} {2,8}  {3}' -f $r.Скрипт, $r.Прошло, $f, $r.Статус | Write-Host
}

$ok      = @($rows | Where-Object { $_.Статус -eq 'OK' }).Count
$bad     = @($rows | Where-Object { $_.Статус -eq 'СБОЙ' }).Count
$nocount = @($rows | Where-Object { $_.Статус -eq 'НЕТ СЧЁТЧИКА' }).Count
$nosum   = @($rows | Where-Object { $_.Статус -eq 'НЕТ СВОДКИ' }).Count
$skipped = @($rows | Where-Object { $_.Статус -eq 'ПРОПУЩЕН' }).Count

Write-Host ''
Write-Host ("  прошли:            $ok")
Write-Host ("  со сбоями:         $bad")
Write-Host ("  без счётчика:      $nocount")
Write-Host ("  без сводки:        $nosum")
Write-Host ("  пропущено:         $skipped")
Write-Host ("  всего:             $($rows.Count)")

if ($bad -gt 0 -or $nosum -gt 0 -or $skipped -gt 0) {
    Write-Host ''
    Write-Host ' ПРОВЕРКА НЕ ПРОЙДЕНА'
    exit 1
}
if ($nocount -gt 0) {
    Write-Host ''
    Write-Host ' Пройдена, но сводка без счётчика отказов — оценка неполная.'
    exit 1
}
Write-Host ''
Write-Host ' ПРОВЕРКА ПРОЙДЕНА'
exit 0