<#
    modbus-sim.ps1 - управление эмулятором Modbus TCP.

    Зачем отдельный скрипт: сервер нужно отсоединять от консоли, иначе
    вызов висит. Нужен остановленный порт, и нужен старый экземпляр, если
    он уже работает. Всё это каждый раз делалось руками.

    Действия:
        .\modbus-sim.ps1              запустить, если не запущен
        .\modbus-sim.ps1 restart      перезапустить
        .\modbus-sim.ps1 stop         остановить
        .\modbus-sim.ps1 status       показать состояние

    Параметры:
        -Port 504           порт, перекрывает значение из map.json
        -Map  <путь>        свой файл карты
        -VerboseLog         писать в журнал и запросы чтения (VERBOSE=1)

    Требуется Node.js. Зависимостей нет, установка не нужна.

    Проверено: Node 22.22.2, PowerShell 5.1, Windows.
#>
[CmdletBinding()]
param(
    [ValidateSet('start', 'stop', 'restart', 'status')]
    [string]$Action = 'start',
    [int]$Port = 0,
    [string]$Map = '',
    [switch]$VerboseLog
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($Map -eq '') { $Map = Join-Path $here 'map.json' }

$log = Join-Path $here 'server.log'
$err = Join-Path $here 'server.log.err'

# MODBUS_MAP - единственный способ указать серверу карту: параметров командной
# строки у server.js нет. Сохраняем прежнее значение, чтобы скрипт ничего
# не оставлял в вызвавшей сессии.
$mapEnvWas = [System.Environment]::GetEnvironmentVariable('MODBUS_MAP', 'Process')

# Ищем по командной строке только "server.js".
#
# Почему не по полному пути: сервер запускается с -WorkingDirectory, и в
# командной строке остаётся голое "server.js" - полного пути там нет. Первая
# версия искала путь к папке, из-за чего не узнавала собственный процесс и
# не могла его остановить.
#
# Ограничение признаём: скрипт остановит любой процесс node с аргументом
# server.js. Для одиночного стендового инструмента это приемлемо.
function Get-SimProcess {
    Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*server.js*' } |
        ForEach-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
}

function Get-PortOwner {
    param([int]$OnPort)
    Get-NetTCPConnection -LocalPort $OnPort -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1
}

function Test-PortBusy {
    param([int]$OnPort)
    return $null -ne (Get-PortOwner $OnPort)
}

function Stop-Sim {
    $procs = Get-SimProcess
    if (-not $procs) {
        Write-Host 'Остановлен: сервер и так не работает.'
        return
    }
    foreach ($p in $procs) {
        Write-Host "Остановлен: node PID $($p.Id)"
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 800
}

function Get-ConfiguredPort {
    if ($Port -gt 0) { return $Port }
    try {
        $raw = Get-Content -Raw -Encoding UTF8 $Map
        $raw = $raw -replace '(?m)^\s*//.*$', ''
        return [int](($raw | ConvertFrom-Json).port)
    }
    catch {
        Write-Warning "Не удалось прочитать порт из $Map : $($_.Exception.Message)"
        return 504
    }
}

function Start-Sim {
    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) {
        throw 'Node.js не найден в PATH. Установите Node.js, чтобы запустить сервер.'
    }

    $usePort = Get-ConfiguredPort

    if (Test-PortBusy $usePort) {
        $owner = Get-PortOwner $usePort
        $name = (Get-Process -Id $owner.OwningProcess -ErrorAction SilentlyContinue).ProcessName
        if ($name -ne 'node') {
            throw "Порт $usePort занят процессом '$name' (PID $($owner.OwningProcess)). Остановите его: остановите GUI-эмулятор Modbus."
        }
        throw "Порт $usePort уже держит этот сервер (PID $($owner.OwningProcess)). Выполните: .\modbus-sim.ps1 restart"
    }

    foreach ($f in @($log, $err)) { if (Test-Path $f) { Remove-Item $f -Force } }

    # Ключевой момент: окно скрываем и НЕ перенаправляем вывод в консоль.
    # С -NoNewWindow и перенаправлением процесс удерживает трубу, и вызов
    # не возвращает управление - консоль виснет.
    # Вот где карта реально попадает в сервер. Раньше её здесь не было:
    # -Map молча игнорировался, а в отчёте печаталась несогруженная карта.
    $env:MODBUS_MAP = (Resolve-Path -LiteralPath $Map).Path
    $env:VERBOSE = if ($VerboseLog) { '1' } else { '' }
    $p = Start-Process -FilePath $node.Source `
        -ArgumentList @($Here + '\server.js') `
        -WorkingDirectory $here `
        -WindowStyle Hidden `
        -PassThru `
        -RedirectStandardOutput $log `
        -RedirectStandardError $err

    # Процесс значение уже унаследовал - возвращаем своё, чтобы не утечь.
    $env:MODBUS_MAP = $mapEnvWas

    Write-Host "Запущен: node PID $($p.Id), порт $usePort, карта $Map"

    for ($i = 1; $i -le 20; $i++) {
        Start-Sleep -Milliseconds 500
        if (Test-PortBusy $usePort) {
            Write-Host "Готово: порт $usePort слушает (${i}с)"
            Show-Tail $log
            return
        }
        if ($p.HasExited) {
            Write-Host 'Сервер завершился сразу. Журнал:'
            Show-Tail $log
            if (Test-Path $err) { Get-Content $err }
            exit 1
        }
    }
    Write-Warning "Порт $usePort не поднялся за 10 с. Журнал:"
    Show-Tail $log
    exit 1
}

function Show-Tail($file) {
    if (-not (Test-Path $file)) { return }
    $lines = Get-Content $file -Encoding UTF8 -Tail 12
    if ($lines) {
        Write-Host '--- журнал сервера (последние строки) ---'
        $lines | ForEach-Object { "  $_" }
    }
}

function Show-Status {
    # Что открыл сервер на самом деле. Сервер пишет это в свой баннер, и
    # единственный честный источник - он: параметры этого скрипта могут
    # отличаться от того, с чем сервер реально запущен.
    $saidMap = ""
    $saidPort = 0
    if (Test-Path $log) {
        $txt = Get-Content $log -Encoding UTF8 -Raw
        if ($txt -match '\[сервер\] правь (.+?) - изменения') { $saidMap = $Matches[1].Trim() }
        if ($txt -match '\[сервер\] слушаю порт (\d+)') { $saidPort = [int]$Matches[1] }
    }

    $procs = Get-SimProcess
    if ($procs -and $saidMap -ne "") {
        Write-Host "Карта:    $saidMap   (из баннера сервера)"
        $usePort = if ($saidPort -gt 0) { $saidPort } else { Get-ConfiguredPort }
        Write-Host "Порт:     $usePort   (из баннера сервера)"
    }
    else {
        Write-Host "Карта:    $Map   (параметр скрипта, сервер не запущен)"
        $usePort = Get-ConfiguredPort
        Write-Host "Порт:     $usePort   (параметр скрипта, сервер не запущен)"
    }

    if ($procs) {
        foreach ($p in $procs) { Write-Host "Сервер:   node PID $($p.Id) работает" }
    }
    else {
        Write-Host 'Сервер:   НЕ РАБОТАЕТ'
    }
    if (Test-PortBusy $usePort) {
        $owner = Get-PortOwner $usePort
        $name = (Get-Process -Id $owner.OwningProcess -ErrorAction SilentlyContinue).ProcessName
        Write-Host "Порт ${usePort}: ЗАНЯТ процессом '$name' (PID $($owner.OwningProcess))"
    }
    else {
        Write-Host "Порт ${usePort}: свободен"
    }

    $gui = Get-Process mtcpServerEmulator -ErrorAction SilentlyContinue
    if ($gui) {
        Write-Host 'GUI-эмулятор mtcpServerEmulator: ЗАПУЩЕН - он конкурирует за порт'
    }

    if ($procs) { Show-Tail $log }
}

switch ($Action) {
    'start'   { Start-Sim }
    'stop'    { Stop-Sim }
    'restart' { Stop-Sim; Start-Sim }
    'status'  { Show-Status }
}