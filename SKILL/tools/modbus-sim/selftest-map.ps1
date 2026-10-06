<#
    selftest-map.ps1 - проверка validate-map.js на разрывах в блоке регистров.

    Что тут ловится. Блок регистров не обязан начинаться с нуля: устройство
    вполне может отвечать только на holding 10..13. Такой блок непрерывен и
    валиден. Разрыв - это дыра ВНУТРИ блока, из-за которой драйвер может
    опрашивать регистры по одному вместо блоком.

    Пять фикстур, у каждой ожидаемый код возврата:
      leading-zero     0..1          без сдвига, как раньше      -> 0
      leading-offset  10..13         блок со сдвигом, сплошной  -> 0
      count-block      0, 2 (count=2) два 32-битных подряд       -> 0
      hole-inside     10, 12         дыра внутри блока           -> 1
      overlap          0 (count=4), 2 перекрытие                -> 1

    Запуск:  .\selftest-map.ps1
    Код возврата: 0 - все ожидания совпали, 1 - есть расхождения.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
chcp 65001 > $null
$OutputEncoding = [System.Text.Encoding]::UTF8

$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
$v = Join-Path $here 'validate-map.js'

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

$tmp = Join-Path $env:TEMP ('wccoa-maptest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp | Out-Null

# У каждой фикстуры свой свободный порт: валидатор проверяет и занятость.
$port = 1604

$TEMPLATE = @'
{
  "port": __PORT__,
  "wordOrder": "__WORDORDER__",
  "devices": [
    { "id": 1, "name": "Fixture", "__SPACE__": [
__REGS__
    ] }
  ]
}
'@

function Reg($addr, $count, $signed, $name, $gen, $writable) {
    $s = if ($signed) { 'true' } else { 'false' }
    $g = ($gen | ConvertTo-Json -Compress)
    $w = if ($writable -eq $null -or $writable -eq '') { '' } else { ', "writable": ' + $writable }
    return '      { "addr": ' + $addr + ', "count": ' + $count + ', "signed": ' + $s + ', "name": "' + $name + '", "gen": ' + $g + $w + ' }'
}

$ramp = @{ type = 'ramp'; min = 0; max = 100; periodMs = 10000 }
$c1 = @{ type = 'const'; value = 1 }
$c2 = @{ type = 'const'; value = 2 }
$c3 = @{ type = 'const'; value = 3 }
$c4 = @{ type = 'const'; value = 4 }

$cases = @(
    @{ Name = 'leading-zero'; Expect = 0; Space = 'holding'; Regs = @(
            (Reg 0 1 $false 'A' $c1), (Reg 1 1 $false 'B' $c2)) },
    @{ Name = 'leading-offset'; Expect = 0; Space = 'holding'; Regs = @(
            (Reg 10 1 $false 'A' $c1), (Reg 11 1 $false 'B' $c2),
            (Reg 12 1 $false 'C' $c3), (Reg 13 1 $false 'D' $c4)) },
    @{ Name = 'count-block'; Expect = 0; Space = 'ireg'; Regs = @(
            (Reg 0 2 $true 'W0' $ramp), (Reg 2 2 $true 'W1' $ramp)) },
    @{ Name = 'hole-inside'; Expect = 1; Space = 'holding'; Regs = @(
            (Reg 10 1 $false 'A' $c1), (Reg 12 1 $false 'B' $c2)) },
    @{ Name = 'overlap'; Expect = 1; Space = 'ireg'; Regs = @(
            (Reg 0 4 $true 'W0' $ramp), (Reg 2 1 $true 'W1' $c1)) },
    @{ Name = 'writable-holding'; Expect = 0; Space = 'holding'; Regs = @((Reg 0 1 $false 'A' $c1 'true')) },
    @{ Name = 'writable-readonly-space'; Expect = 1; Space = 'input'; Regs = @((Reg 0 1 $false 'A' $c1 'true')) },
    @{ Name = 'writable-not-bool'; Expect = 1; Space = 'holding'; Regs = @((Reg 0 1 $false 'A' $c1 '"yes"')) },
    @{ Name = 'wordorder-abcd'; Expect = 1; Space = 'holding'; WordOrder = 'ABCD'; Regs = @((Reg 0 2 $true 'W0' $ramp)) }
)

try {
    foreach ($c in $cases) {
        while ((Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)) {
            $port += 1
        }
        $wo = if ($c.WordOrder) { $c.WordOrder } else { 'CDAB' }
        $json = $TEMPLATE.Replace('__PORT__', [string]$port).Replace('__SPACE__', $c.Space).Replace('__WORDORDER__', $wo)
        $json = $json.Replace('__REGS__', ($c.Regs -join ",`n"))

        $file = Join-Path $tmp ($c.Name + '.json')
        Set-Content -LiteralPath $file -Value $json -Encoding ASCII

        $out = & node $v $file 2>&1 | Out-String
        $rc = $LASTEXITCODE
        if ($rc -eq $c.Expect) {
            Ok $c.Name ('ожидался код ' + $c.Expect + ', получен ' + $rc)
        } else {
            $why = (($out -split "`r?`n") | Where-Object { $_.Trim() } |
                Select-Object -First 4) -join ' / '
            No $c.Name ('ожидался код ' + $c.Expect + ', получен ' + $rc + ' :: ' + $why)
        }
    }
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host ('ИТОГО: PASS=' + $pass + ' FAIL=' + $fail)
if ($fail -gt 0) { exit 1 }
exit 0