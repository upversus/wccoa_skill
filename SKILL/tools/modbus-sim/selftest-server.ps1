<#
    selftest-server.ps1 - проверка server.js и modbus-sim.ps1 на разрывах
    и на видимость предупреждений.

    Три вещи, которые тут проверяются:

      1. Блок, начинающийся не с нуля, НЕ должен считаться разрывом.
         Раньше и валидатор, и сервер требовали адрес 0 первым, а обычное
         устройство, отвечающее только на holding 10..13, объявлялось
         повреждённым.
      2. Настоящая дыра внутри блока обязана по-прежнему ругаться.
      3. Предупреждения сервера уходят в stderr, то есть в server.log.err,
         а Show-Tail читал только stdout. Из-за этого единственная
         диагностика эмулятора была не видна в обычном запуске.

    Запуск:  .\selftest-server.ps1
    Код возврата: 0 - все ожидания совпали, 1 - есть расхождения.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
chcp 65001 > $null
$OutputEncoding = [System.Text.Encoding]::UTF8

$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sim = Join-Path $here 'modbus-sim.ps1'
$log = Join-Path $here 'server.log'
$err = Join-Path $here 'server.log.err'

$pass = 0
$fail = 0
function Ok($what, $detail) {
    $script:pass += 1
    Write-Host ('  PASS  ' + $what + '   ' + $detail) -ForegroundColor Green
}
function No($what, $detail) {
    $script:fail += 1
    Write-Host ('  FAIL  ' + $what + '   ' + $detail) -ForegroundColor Red
}

$tmp = Join-Path $env:TEMP ('wccoa-srvtest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp | Out-Null

$TEMPLATE = @'
{
  "port": __PORT__,
  "wordOrder": "CDAB",
  "devices": [
    { "id": 1, "name": "Fixture", "holding": [
__REGS__
    ] }
  ]
}
'@

function Reg($addr, $name, $value) {
    return '      { "addr": ' + $addr + ', "count": 1, "signed": false, "name": "' + $name + '", "gen": { "type": "const", "value": ' + $value + ' } }'
}

$port = 1704
function Free-Port {
    while ((Get-NetTCPConnection -LocalPort $script:port -State Listen -ErrorAction SilentlyContinue)) {
        $script:port += 1
    }
    return $script:port
}

function Start-With($regs) {
    $p = Free-Port
    $json = $TEMPLATE.Replace('__PORT__', [string]$p).Replace('__REGS__', ($regs -join ",`n"))
    $file = Join-Path $tmp ('m-' + $p + '.json')
    Set-Content -LiteralPath $file -Value $json -Encoding ASCII
    & $sim -Action start -Map $file 2>&1 | Out-Null
    $errText = ''
    if (Test-Path $err) { $errText = (Get-Content -LiteralPath $err -Encoding UTF8 -Raw) }
    return $errText
}

try {
    # 1. Непрерывный блок со сдвигом 10..12 - разрыва быть не должно.
    $t = Start-With @((Reg 10 'A' 1), (Reg 11 'B' 2), (Reg 12 'C' 3))
    if ($t -match 'разрыв') {
        No 'блок 10..12 не считается разрывом' 'сервер написал предупреждение'
    } else {
        Ok 'блок 10..12 не считается разрывом' 'предупреждения нет'
    }
    & $sim -Action stop 2>&1 | Out-Null

    # 2. Настоящая дыра 10, 12 - обязана быть найдена.
    $t2 = Start-With @((Reg 10 'A' 1), (Reg 12 'B' 2))
    if ($t2 -match 'разрыв') {
        Ok 'дыра 10, 12 найдена' 'предупреждение есть'
    } else {
        No 'дыра 10, 12 найдена' 'сервер промолчал'
    }

    # 3. Это же предупреждение должно быть видно в status, а не лежать
    #    в файле, на который никто не смотрит.
    $statusOut = Join-Path $tmp 'status.txt'
    & $sim -Action status *> $statusOut
    $st = Get-Content -LiteralPath $statusOut -Encoding UTF8 -Raw
    if ($st -match 'разрыв') {
        Ok 'status показывает предупреждение из server.log.err' 'строка найдена в выводе'
    } else {
        No 'status показывает предупреждение из server.log.err' 'в выводе status её нет'
    }
    & $sim -Action stop 2>&1 | Out-Null
}
finally {
    & $sim -Action stop 2>&1 | Out-Null
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host ('ИТОГО: PASS=' + $pass + ' FAIL=' + $fail)
if ($fail -gt 0) { exit 1 }
exit 0