<#
    run-ctl.ps1 — запуск демонстрационного .ctl-скрипта в живом проекте WinCC OA.

    Зачем этот скрипт: выяснено экспериментально на CTL 3.18, что
      * путь к скрипту ОБЯЗАН быть абсолютным — относительный даёт
        "PARAM, WARNING, 61, Cannot open file, <path>" и скрипт не стартует;
      * вывод DebugN() уходит в stdout, а НЕ в лог-файл проекта;
      * лог-файл WCCOActrl<num>.log создаётся не всегда (короткие скрипты
        успевают завершиться до его создания), поэтому читать нечего;
      * флаг -log +stderr перенаправляет служебные сообщения OA в stderr,
        где они видны при разборе ошибок;
      * значение -num обязано быть МЕНЬШЕ 255, иначе интерпретатор молча
        не стартует: "-num >= 255" и "exit(1) called!", причём ни в stdout,
        ни в отфильтрованный stderr это не попадает — вывод пустой.

    Пример:
      .\run-ctl.ps1 -Script .\01-create\01_dpCreate.ctl
      .\run-ctl.ps1 -Script .\01-create\01_dpCreate.ctl -Num 5 -WaitSeconds 60
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Script,
    # Имя проекта. По умолчанию 'auto': берётся из командной строки любого
    # запущенного процесса WinCC OA, где есть ключ -PROJ. Так скилл работает
    # с любым поднятым проектом без правки скрипта. Чтобы задать явно:
    #   -Project <проект стенда>
    # Если рантайм не запущен, 'auto' падает с внятной ошибкой.
    [string]$Project = 'auto',
    [string]$Credential = 'root:',
    [int]$Num = 0,          # номер менеджера, обязательно < 255
    [int]$WaitSeconds = 30,
    [switch]$LongRunning,
    [switch]$RawOut,         # отдать сырой stdout без печати (для verify.ps1)
    # Каталог стандартной установки WinCC OA, проверяется вторым после
    # переменной окружения. Если у вас другой путь - задайте WCCOA_CTRL_EXE
    # или переопределите этот ключ, править код не нужно.
    [string]$DefaultOaRoot = 'C:\Sybcom\Kaskad\3.18'
)

if ($Num -ge 255) {
    throw "Значение -Num должно быть меньше 255 (получено $Num). Интерпретатор при -num >= 255 завершается с кодом 1, не печатая ничего в stdout, и прогон выглядит как пустой."
}

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------
# Автоопределение проекта
# ---------------------------------------------------------------------
# Каждый процесс рантайма WinCC OA несёт в командной строке ключ -PROJ:
#   WCCOAmod.exe    -PROJ <проект стенда> -pmonIndex 11 -num 2
#   WCCOAopcua.exe  -PROJ <проект стенда> -pmonIndex 17 -num 3
#   WCCOActrl.exe   -PROJ <проект стенда> -pmonIndex 5 -f pvss_scripts.lst
#   WCCOAui.exe     -PROJ <проект стенда> -pmonIndex 8 -m gedi
# Отсюда же берутся номера драйверов (-num): для Modbus и OPC UA они нужны
# при работе с адресами и при dpCopyConfig(..., iDriverNumber).

function Get-WinCcoaRuntime {
    param([string]$Proj = '')
    $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
             Where-Object { $_.CommandLine -and $_.CommandLine -match '-PROJ\s+(\S+)' }
    foreach ($p in $procs) {
        if ($p.CommandLine -match '-PROJ\s+(\S+)') {
            $name = $matches[1]
            if ($Proj -and $name -ne $Proj) { continue }
            $driverNum = $null
            if ($p.CommandLine -match '-num\s+(\d+)') { $driverNum = [int]$matches[1] }
            [pscustomobject]@{
                Process  = $p.Name
                Project  = $name
                PmonIndex = if ($p.CommandLine -match '-pmonIndex\s+(\d+)') { [int]$matches[1] } else { $null }
                DriverNum = $driverNum
            }
        }
    }
}

if ($Project -eq 'auto') {
    $rt = @(Get-WinCcoaRuntime)
    if ($rt.Count -eq 0) {
        throw ("Автоопределение проекта не удалось: не найдено ни одного процесса WinCC OA " +
               "с ключом -PROJ. Похоже, рантайм не запущен. Укажите проект явно: -Project <имя>")
    }
    $names = @($rt | Select-Object -ExpandProperty Project -Unique)
    if ($names.Count -gt 1) {
        # Несколько проектов поднято - берём тот, у которого больше процессов.
        $Project = ($rt | Group-Object Project | Sort-Object Count -Descending |
                    Select-Object -First 1).Name
        Write-Warning ("Запущено несколько проектов: {0}. Использую '{1}'. " +
                       "Уточните через -Project, если нужен другой.") -f ($names -join ', '), $Project
    }
    else {
        $Project = $names[0]
    }
}

# Номера драйверов - в переменные окружения, чтобы их могли читать вызывающие.
$rt = @(Get-WinCcoaRuntime -Proj $Project)
$drvModbus  = ($rt | Where-Object { $_.Process -match 'WCCOAmod\.exe$'   } | Select-Object -First 1).DriverNum
$drvOpcUa   = ($rt | Where-Object { $_.Process -match 'WCCOAopcua\.exe$' } | Select-Object -First 1).DriverNum
$env:WCCOA_PROJECT     = $Project
if ($drvModbus) { $env:WCCOA_DRV_MODBUS = "$drvModbus" }
if ($drvOpcUa)  { $env:WCCOA_DRV_OPCUA  = "$drvOpcUa" }

# Вывод DebugN() приходит в UTF-8. Без переключения консоли кириллица
# превращается в мусор, а проверять результат по мусору невозможно.
try {
    chcp 65001 > $null
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
    Write-Warning "Не удалось переключить консоль на UTF-8: $($_.Exception.Message)"
}

# Где взять WCCOActrl.exe.
#
# Порядок: переменная WCCOA_CTRL_EXE, затем стандартная установка
# C:\Sybcom\Kaskad\3.18, затем типовые места установки в Program Files.
# Переменная важнее всего: если WinCC OA стоит не по этому пути, её
# достаточно задать один раз, и скрипт работает без правок кода.
$exe = $null

if ($env:WCCOA_CTRL_EXE) { $exe = $env:WCCOA_CTRL_EXE }
else {
    $candidates = New-Object System.Collections.Generic.List[string]
    $candidates.Add((Join-Path $DefaultOaRoot 'bin\WCCOActrl.exe'))
    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramW6432)
    foreach ($r in $roots) {
        if (-not $r) { continue }
        $oaRoot = Join-Path $r 'WinCC OA'
        if (-not (Test-Path -LiteralPath $oaRoot)) { continue }
        foreach ($v in (Get-ChildItem $oaRoot -Directory -ErrorAction SilentlyContinue)) {
            $candidates.Add((Join-Path $v.FullName 'bin\WCCOActrl.exe'))
        }
    }
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { $exe = $c; break }
    }
}

if (-not $exe -or -not (Test-Path -LiteralPath $exe)) {
    $hint = 'Интерпретатор WCCOActrl.exe не найден. Проверены: переменная WCCOA_CTRL_EXE, '
    $hint += 'каталог ' + $DefaultOaRoot + ' и типовые места установки в Program Files.' + [char]10
    $hint += 'Укажите его одним из способов:' + [char]10
    $hint += ' 1) переменная окружения:  $env:WCCOA_CTRL_EXE = ' + [char]39 + '<путь>\bin\WCCOActrl.exe' + [char]39 + [char]10
    $hint += ' 2) ключ запуска:  -DefaultOaRoot <каталог установки>' + [char]10
    $hint += ' 3) проверьте путь: где лежит WCCOActrl.exe - там и должна указывать переменная.' + [char]10
    throw $hint
}
# Абсолютный путь — обязательное условие, см. шапку скрипта.
$scriptPath = (Resolve-Path -LiteralPath $Script).Path
$workDir = Split-Path -Parent $scriptPath

$outFile = Join-Path $env:TEMP ('dpdemo_out_{0}.txt' -f [Guid]::NewGuid().ToString('N'))
$errFile = Join-Path $env:TEMP ('dpdemo_err_{0}.txt' -f [Guid]::NewGuid().ToString('N'))

$argList = @('-user', $Credential, '-num', "$Num", '-proj', $Project,
             '-log', '+stderr', $scriptPath)

if (-not $RawOut) { Write-Host "Запуск: $exe $($argList -join ' ')" }
if (-not $RawOut) { Write-Host "Папка скрипта: $workDir" }
if (-not $RawOut) {
    $drvTxt = @()
    if ($drvModbus) { $drvTxt += "Modbus=$drvModbus" }
    if ($drvOpcUa)  { $drvTxt += "OPCUA=$drvOpcUa" }
    if ($drvTxt.Count -gt 0) {
        Write-Host ("Проект определён автоматически: {0}   драйверы: {1}" -f $Project, ($drvTxt -join '  '))
    } else {
        Write-Host "Проект определён автоматически: $Project"
    }
}

$p = Start-Process -FilePath $exe -ArgumentList $argList -WorkingDirectory $workDir `
        -PassThru -NoNewWindow `
        -RedirectStandardOutput $outFile -RedirectStandardError $errFile

if ($LongRunning) {
    Write-Host "Режим: долгий. Скрипт работает, пока его не остановят (PID $($p.Id))."
    Write-Host "stdout (DebugN): $outFile"
    Write-Host "stderr (служебное): $errFile"
    return
}

if (-not $p.WaitForExit($WaitSeconds * 1000)) {
    if (-not $RawOut) { Write-Warning "Скрипт не завершился за $WaitSeconds с — вероятно, завис на blocking-функции. Останавливаю PID $($p.Id)." }
    Stop-Process -Id $p.Id -Force
} else {
    if (-not $RawOut) { Write-Host "Скрипт завершился, код выхода: $($p.ExitCode)" }
}

# --- вывод DebugN --------------------------------------------------------
# Читаем именно в UTF8: DebugN пишет UTF-8, и чтение в кодировке по умолчанию
# превращает кириллицу в мусор.
$out = if (Test-Path $outFile) { Get-Content -LiteralPath $outFile -Raw -Encoding UTF8 } else { '' }
if ($RawOut) {
    Remove-Item -LiteralPath $outFile, $errFile -Force -ErrorAction SilentlyContinue
    return $out
}
if ($out) {
    Write-Host ''
    Write-Host '========== ВЫВОД СКРИПТА =========='
    # Разбор JSON-массива DebugN в читаемые строки: ["PASS  текст"][n]
    foreach ($line in ($out -split "`r?`n")) {
        if ($line.Trim()) { Write-Host $line }
    }
    Write-Host '====================================='
}

# --- служебные сообщения OA: только ошибки и предупреждения --------------
$err = if (Test-Path $errFile) { Get-Content -LiteralPath $errFile -Raw -Encoding UTF8 } else { '' }
if ($err) {
    $problems = $err -split "`r?`n" |
                Where-Object { $_ -match 'WARNING|SEVERE|SEVERE|Cannot open' }
    if ($problems) {
        Write-Host ''
        Write-Host '===== СООБЩЕНИЯ OA (WARNING / SEVERE) ====='
        $problems | ForEach-Object { Write-Host $_ }
        Write-Host '==========================================='
    }
}

Remove-Item -LiteralPath $outFile, $errFile -Force -ErrorAction SilentlyContinue