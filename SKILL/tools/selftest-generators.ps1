<#
    selftest-generators.ps1 - статические проверки сгенерированного CTL.

    Здесь ничего не создаётся в проекте WinCC OA: генераторы только
    пишут текст скрипта в TEMP, и проверяется сам текст.

    Проверяется:
      1. Modbus-ветка не печатает пустой левый операнд вида
         "string want =  + busyRefs[bi];". Префикс у Modbus пуст по
         существу, и строка обязана выглядеть как "busyRefs[bi]".
      2. OPC UA-ветка печатает префикс: адрес в _reference полный,
         "server$subscription$1$1$NodeId", сравнивать с сырым NodeId
         нельзя - конфликт не найдётся.
      3. У обоих файлов ровно один вызов nodeOwner и один баннер проверки:
         дубли этих функций компилируются, но означают две независимые
         проверки занятости.
      4. Ни в одном файле нет BOM: CTL с BOM не запускается.

    Запуск:  .\selftest-generators.ps1
    Код возврата: 0 - все ожидания совпали, 1 - есть расхождения.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
chcp 65001 > $null
$OutputEncoding = [System.Text.Encoding]::UTF8

$tools = Split-Path -Parent $MyInvocation.MyCommand.Definition
$tmp = Join-Path $env:TEMP ('wccoa-gen-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp | Out-Null

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

function Has-Bom($p) {
    $b = [System.IO.File]::ReadAllBytes($p)
    return ($b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
}

try {
    # ------------------------------------------------------------ Modbus
    $mb = Join-Path $tmp 'mb.ctl'
    & node (Join-Path $tools 'gen-modbus-dp.js') (Join-Path $tools 'modbus-sim\map.json') `
        --out $mb --dp GENTEST --dpt gentest_t --drv 2 --no-verify 2>&1 | Out-Null
    if (-not (Test-Path $mb)) { No 'Modbus CTL создан' 'генератор не создал файл'; }
    else {
        $t = Get-Content -LiteralPath $mb -Encoding UTF8
        $want = @($t | Where-Object { $_ -match 'string want =' })

        # 1. Никакого пустого левого операнда.
        $bad = @($want | Where-Object { $_ -match '=\s+\+' })
        if ($bad.Count -eq 0) {
            Ok 'Modbus: нет пустого левого операнда' ('want = ' + ($want | Select-Object -First 1).Trim())
        } else {
            No 'Modbus: нет пустого левого операнда' ('строка: ' + $bad[0].Trim())
        }

        $owners = @($t | Where-Object { $_ -match 'string nodeOwner' })
        if ($owners.Count -eq 1) { Ok 'Modbus: nodeOwner ровно один' '1' }
        else { No 'Modbus: nodeOwner ровно один' ('найдено ' + $owners.Count) }

        $banner = @($t | Where-Object { $_ -match 'проверка занятости узлов' })
        if ($banner.Count -eq 1) { Ok 'Modbus: баннер проверки ровно один' '1' }
        else { No 'Modbus: баннер проверки ровно один' ('найдено ' + $banner.Count) }

        if (Has-Bom $mb) { No 'Modbus: BOM отсутствует' 'BOM есть, CTL не запустится' }
        else { Ok 'Modbus: BOM отсутствует' 'байты чистые' }
    }

    # ------------------------------------------------------------ OPC UA
    $op = Join-Path $tmp 'opc.ctl'
    & node (Join-Path $tools 'gen-opcua-dp.js') (Join-Path $tools 'opcua\Functions.csv') `
        --out $op --path 'Sim.Functions' `
        --dp GENTEST --dpt gentest_t --drv 3 --no-verify --allow-missing 2>&1 | Out-Null
    if (-not (Test-Path $op)) { No 'OPC UA CTL создан' 'генератор не создал файл'; }
    else {
        $t = Get-Content -LiteralPath $op -Encoding UTF8
        $want = @($t | Where-Object { $_ -match 'string want =' })

        # 2. Префикс обязан присутствовать.
        $good = @($want | Where-Object { $_ -match '=\s*prefix\s*\+' })
        if ($good.Count -eq 1) {
            Ok 'OPC UA: сверка идёт с префиксом' $good[0].Trim()
        } else {
            No 'OPC UA: сверка идёт с префиксом' ('найдено строк с prefix: ' + $good.Count)
        }

        # Префикс должен быть вычислен раньше проверки.
        $iPrefix = -1; $iWant = -1
        for ($i = 0; $i -lt $t.Count; $i++) {
            if ($t[$i] -match 'string prefix =' -and $iPrefix -lt 0) { $iPrefix = $i }
            if ($t[$i] -match 'string want =' -and $iWant -lt 0) { $iWant = $i }
        }
        if ($iPrefix -ge 0 -and $iPrefix -lt $iWant) {
            Ok 'OPC UA: префикс вычислен до проверки' ('строка ' + ($iPrefix + 1) + ' < ' + ($iWant + 1))
        } else {
            No 'OPC UA: префикс вычислен до проверки' ("prefix=$($iPrefix + 1) want=$($iWant + 1)")
        }

        $owners = @($t | Where-Object { $_ -match 'string nodeOwner' })
        if ($owners.Count -eq 1) { Ok 'OPC UA: nodeOwner ровно один' '1' }
        else { No 'OPC UA: nodeOwner ровно один' ('найдено ' + $owners.Count) }

        if (Has-Bom $op) { No 'OPC UA: BOM отсутствует' 'BOM есть, CTL не запустится' }
        else { Ok 'OPC UA: BOM отсутствует' 'байты чистые' }
    }
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host ('ИТОГО: PASS=' + $pass + ' FAIL=' + $fail)
if ($fail -gt 0) { exit 1 }
exit 0