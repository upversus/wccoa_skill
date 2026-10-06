<#
    selftest.ps1 - проверка, что modbus-sim.ps1 запускает сервер ТОТ картой,
    которую запросили, не врёт в отчёте и не пишет в каталог скилла.

    Четыре группы утверждений:
      1. сервер загрузил карту из -Map, а не дефолтную map.json;
      2. число устройств в баннере соответствует этой карте;
      3. строка "Карта:" в status совпадает с тем, что сервер реально открыл;
      4. журналы сервера лежат во временном каталоге, а не рядом с
         modbus-sim.ps1 - иначе скилл нельзя положить в read-only каталог.

    Запуск:  .\selftest.ps1
    Код возврата: 0 - всё прошло, 1 - есть провалы.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
chcp 65001 > $null
$OutputEncoding = [System.Text.Encoding]::UTF8

$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sim = Join-Path $here 'modbus-sim.ps1'

# Каталог журналов по контракту: вне скилла.
$logDir = Join-Path $env:TEMP 'wccoa-mbsim'
$logNew = Join-Path $logDir 'server.log'
$logOld = Join-Path $here 'server.log'

function Find-Log {
    if (Test-Path $logNew) { return $logNew }
    if (Test-Path $logOld) { return $logOld }
    return $logNew
}

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

# Порт для теста: поднимаемся, пока не найдём свободный.
$port = 1504
while ((Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)) {
    $port += 1
}

$tmp = Join-Path $env:TEMP ('wccoa-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp | Out-Null
$map = Join-Path $tmp 'selftest-map.json'

# Два устройства - дефолтная карта содержит шесть, поэтому баннер различим.
$json = @'
{
  "//": "карта для selftest.ps1: два устройства, порт выставляется здесь",
  "port": __PORT__,
  "wordOrder": "CDAB",
  "devices": [
    { "id": 1, "name": "SelftestA",
      "ireg": [ { "addr": 0, "count": 1, "signed": true, "name": "V0",
                  "gen": { "type": "ramp", "min": 0, "max": 100, "periodMs": 10000 } } ] },
    { "id": 2, "name": "SelftestB",
      "ireg": [ { "addr": 0, "count": 1, "signed": true, "name": "V0",
                  "gen": { "type": "ramp", "min": 0, "max": 100, "periodMs": 10000 } } ] }
  ]
}
'@
Set-Content -LiteralPath $map -Value ($json -replace '__PORT__', $port) -Encoding ASCII
Write-Host ('Порт теста: ' + $port)
Write-Host ('Карта теста: ' + $map)

try {
    Write-Host ''
    Write-Host '--- запуск эмулятора с -Map ---'
    $out = & $sim -Action start -Map $map 2>&1 | Out-String
    Write-Host $out.Trim()

    $log = Find-Log
    $banner = if (Test-Path $log) { Get-Content -LiteralPath $log -Encoding UTF8 | Out-String } else { '' }

    # 1. Сервер должен открыть именно запрошенную карту.
    if ($banner -match [regex]::Escape($map)) {
        Ok 'сервер открыл карту из -Map' $map
    } elseif ($banner -match 'map\.json') {
        $hit = ($banner -split "`n" | Select-String 'правь' | Select-Object -First 1)
        No 'сервер открыл карту из -Map' ('вместо неё загружена map.json; в логе: ' + $hit)
    } else {
        No 'сервер открыл карту из -Map' 'в баннере нет ни карты, ни map.json'
    }

    # 2. Число устройств должно совпасть с картой.
    if ($banner -match 'устройств\s+2') {
        Ok 'в баннере два устройства' 'как в тестовой карте'
    } else {
        $m = ($banner -split "`n" | Select-String 'устройств' | Select-Object -First 1)
        No 'в баннере два устройства' ('вместо них сервер видит другое; ' + $m)
    }

    # 3. Отчёт status не должен называть не ту карту.
    $statusOut = Join-Path $tmp 'status.txt'
    & $sim -Action status *> $statusOut
    $st = Get-Content -LiteralPath $statusOut -Encoding UTF8 -Raw
    $said = ''
    if ($st -match '(?m)^Карта:\s+(.+?)\s{2,}') { $said = $Matches[1].Trim() }
    $opened = ''
    if ($banner -match '\[сервер\] правь (.+?) - изменения') { $opened = $Matches[1].Trim() }
    if ($said -and $opened -and ($said.Trim() -eq $opened.Trim())) {
        Ok 'status называет ту же карту, что открыл сервер' $said
    } else {
        No 'status называет ту же карту, что открыл сервер' ("status говорит '$said', сервер открыл '$opened'")
    }

    # 4. Журналы не должны появляться в каталоге скилла.
    $inSkill = @()
    foreach ($n in @('server.log', 'server.log.err')) {
        if (Test-Path (Join-Path $here $n)) { $inSkill += $n }
    }
    if ($inSkill.Count -eq 0) {
        Ok 'в каталоге скилла нет журналов' ('журнал здесь: ' + $log)
    } else {
        No 'в каталоге скилла нет журналов' ('найдено рядом с ps1: ' + ($inSkill -join ', '))
    }
}
finally {
    & $sim -Action stop 2>&1 | Out-Null
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host ('ИТОГО: PASS=' + $pass + ' FAIL=' + $fail)
if ($fail -gt 0) { exit 1 }
exit 0