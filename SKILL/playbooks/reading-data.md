# Чтение данных из точки

Самое частое. Главное здесь — не забыть про качестве: значение без признака
достоверности бесполезно, а признак обычно лежит рядом и читается отдельно.

## Минимальный замер

```ctl
main()
{
  string e = "ExampleDP_Arg1.";          // одиночная точка: точка в конце
  // string e = "STP.Current_Temperature"; // элемент структуры: точки НЕТ

  dyn_anytype v; bool bad; int q; time t;
  int rc = dpGet(e + ":_online.._value", v);
  dpGet(e + ":_online.._bad", bad);
  dpGet(e + ":_online.._quality_code", q);
  dpGet(e + ":_online.._stime", t);
  DebugN("rc=", rc, " v=", v, " q=", q, " bad=", bad, " stime=", t);
}
```

| Что | О чём говорит |
| --- | --- |
| `_online.._value` | значение, каким его видит система |
| `_online.._bad` | `TRUE` — значение недостоверно |
| `_online.._quality_code` | `128` — GOOD, иначе код причина |
| `_online.._stime` | время последнего обновления |
| `rc` | `0` успех, `-1` точки нет |

## Точка в конце пути — только у корня

Это правило стоит отдельного упоминания, потому что нарушается постоянно.

```ctl
dpGet("STP.CurTemp:_online.._value", v);     // элемент структуры — БЕЗ точки
dpGet("ExampleDP_Arg1.:_online.._value", v); // корень одиночной точки — С точкой
```

С точкой на элементе получаешь `DP does not exist` и `rc = -1`, причём
переменная остаётся нулевой, и это легко принять за «данные не пришли».

## Проверить, что значение живое

Один срез ничего не доказывает. Два с интервалом — доказывают.

```ctl
bool changed(string e)
{
  dyn_anytype a;
  dpGet(e + ":_online.._value", a);
  for (int i = 1; i <= 6; i++)
  {
    delay(1);
    dyn_anytype b;
    dpGet(e + ":_online.._value", b);
    if (("" + b) != ("" + a)) { return true; }
  }
  return false;
}
```

Осторожно с ценой: такая проверка на 40 элементах в цикле тянет четыре
минуты. Правильно — снять все значения разом, сделать одну паузу, снять
снова и сравнить.

Если по референсу сигнал константа, изменение не проверить нельзя. Спроси
пользователя и скажи прямо, что проверить нечем.

## Дождаться данных

```ctl
bool fresh(string e)
{
  time t;
  dpGet(e + ":_online.._stime", t);
  return (t != makeTime(1970, 1, 1, 3, 0, 0));
}

for (int i = 1; i <= 30; i++)
{
  if (fresh("STP.Current_Temperature")) { break; }
  delay(1);
}
```

Нулевое время — значит точка не обновлялась ни разу.

## Тип значения

`_online.._value` читается в `dyn_anytype`. Печатать его можно, но
`dpValToString` на `IntegerVar` и `FloatVar` из `dyn_anytype` **не
работает** и молча отдаёт ноль вместе с предупреждением в журнале.

Практичнее читать в типизированную переменную:

```ctl
float f;  dpGet(e + ":_online.._value", f);   // f = 3.5026953
int   i;  dpGet(e + ":_online.._value", i);   // i = 254
bool  b;  dpGet(e + ":_online.._value", b);   // b = TRUE
```

## Имена элементов точки

Через тип, не через несуществующую функцию:

```ctl
string tpn = dpTypeName("STP.");
dyn_dyn_string nm; dyn_dyn_int ty;
dpTypeGet(tpn, nm, ty);
for (int k = 2; k <= dynlen(nm); k++)      // строка 1 — сам тип
{ DebugN("STP." + nm[k][dynlen(nm[k])]); }
```

Функции `dpGetAllDPEs` не существует. Существуют `dpGetAllAttributes`,
`dpGetAllDetails`, `dpGetAllConfigs`.

## Метаданные

```ctl
int    utype;  dpGet(e + ":_online.._utype", utype);    // тип значения
string unit;   dpGet(e + ":_online.._unit", unit);      // единица измерения
string fmt;    dpGet(e + ":_online.._format", fmt);     // формат
string alias;  string name;
dpAliasToName(e + ":_online.._value", alias, name);
```

Алиасы ищутся `dpNames("@алиас")`. Имя элемента для сеттеров
`dpSetUnit`, `dpSetFormat`, `dpSetDescription`, `dpSetAlias` передаётся
**без завершающей точки**; с точкой сеттеры дают `rc = -1`.

## Есть ли значение вообще

`dpExists` отвечает на вопрос про точку целиком, а не про элемент. Для
элемента признак — `rc` из `dpGet` и время `_stime`.

## Прямой доступ в PLC

Если нужно значение, минуя точку данных, минуя драйвер и систему, — это
`docs/04-write.md` и функции `dpGetPlc`/`dpSetPlc`. Пользуйся только когда
точка данных по какой-то причине не подходит: значение мимо системы не
участвует в архиве, апи и тревогах.

## Примеры

| Что | Файл |
| --- | --- |
| базовое чтение | `examples/03-read/01_dpGet.ctl` |
| разрез структуры по элементам | `examples/03-read/08_dpSubStr.ctl` |
| алиас и имя | `examples/03-read/12_dpAliasToName.ctl` |
| период и возраст значения | `examples/03-read/03_dpGetPeriod.ctl`, `04_dpGetMaxAge.ctl` |
| биты состояния | `examples/03-read/05_dpGetStatusBit.ctl` |
| чтение с Modbus по готовой точке | `examples/11-address/14_read_temp.ctl` |
