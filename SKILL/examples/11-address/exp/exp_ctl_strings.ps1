<#
    exp_ctl_strings.ps1 — определение строковых функций CTL опытным путём.

    Зачем: неизвестное имя функции валит компиляцию с
        SEVERE, 72, Function not defined
    поэтому проверить пакетно нельзя - каждый кандидат проверяется
    отдельным прогоном интерпретатора.

    Результат на CTL 3.18:
        ЕСТЬ   substr(s, from, len), strpos(s, sub), strtok(s, sub)
        НЕТ    strstr, copy, left, right, strReplace, replace, mid, strFind

    Индексы у строковых функций С НУЛЯ:
        strpos("System1:_kep", "_")    -> 8
        substr("System1:_kep", 9, 4)  -> "kep"

    Проверено: CTL 3.18, проект <проект стенда>.
#>
chcp 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$dir = $PSScriptRoot
# Путь к интерпретатору задаётся переменной окружения: жёсткий путь
# одного стенда здесь не нужен и ломал бы скрипт на любой другой машине.
if (-not $env:WCCOA_CTRL_EXE) {
    throw 'Задайте $env:WCCOA_CTRL_EXE полным путём к WCCOActrl.exe.'
}
$exe = $env:WCCOA_CTRL_EXE

# Значение -num обязано быть меньше 255, иначе интерпретатор завершается
# с кодом 1, не печатая ничего.
$start = 120

$cands = [ordered]@{
    'substr'     = 'string r = substr(s, 9, 4);'
    'strpos'     = 'int r = strpos(s, "_");'
    'strstr'     = 'string r = strstr(s, "_");'
    'copy'       = 'string r = copy(s, 9, 4);'
    'left'       = 'string r = left(s, 8);'
    'right'      = 'string r = right(s, 4);'
    'strReplace' = 'string r = strReplace(s, "System1:", "");'
    'replace'    = 'string r = replace(s, "System1:", "");'
    'strtok'     = 'string r = strtok(s, "_");'
    'mid'        = 'string r = mid(s, 9, 4);'
    'strFind'    = 'int r = strFind(s, "_");'
}

$num = $start
foreach ($k in $cands.Keys) {
    $num++
    $body = 'main(){ string s = "System1:_kep"; ' + $cands[$k] + ' DebugN("OK", r); }'
    $f = Join-Path $dir "$k.ctl"
    [System.IO.File]::WriteAllText($f, $body, (New-Object System.Text.UTF8Encoding($false)))

    $o = Join-Path $dir "$k.out"
    $e = Join-Path $dir "$k.err"

    $p = Start-Process -FilePath $exe `
            -ArgumentList @('-user', 'root:', '-num', "$num", '-proj', '<проект стенда>',
                            '-log', '+stderr', $f) `
            -WorkingDirectory $dir -PassThru -NoNewWindow `
            -RedirectStandardOutput $o -RedirectStandardError $e
    $p.WaitForExit(25000) | Out-Null

    $err = if (Test-Path $e) { Get-Content $e -Raw } else { '' }
    $out = if (Test-Path $o) { Get-Content $o -Raw } else { '' }

    if ($err -match 'Function not defined') {
        "{0,-12} НЕТ" -f $k
    }
    elseif ($err -match 'SEVERE') {
        "{0,-12} ОШИБКА: {1}" -f $k, (($err -split "`n" | Where-Object { $_ -match 'SEVERE' } | Select-Object -First 1).Trim())
    }
    else {
        "{0,-12} ЕСТЬ -> {1}" -f $k, ($out.Trim() -replace "`r?`n", ' ')
    }

    Remove-Item -LiteralPath $f, $o, $e -Force -ErrorAction SilentlyContinue
}