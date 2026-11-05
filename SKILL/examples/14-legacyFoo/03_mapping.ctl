// 03_mapping.ctl - mapping: создание, доступ, перебор, удаление.
//
// Документация: docs/14-legacyFoo.md
// Проверено: CTL 3.18, проект <проект стенда>.
//
// Скрипт самодостаточен: точки данных не создаёт, сеть не использует.
// В CTL 3.18 нет mappingAdd() и mappingDel(); добавление — m[key] = value,
// удаление — mappingRemove().

int dpdPass = 0;
int dpdFail = 0;

void dpdCheck(string what, bool ok)
{
  if (ok) { dpdPass++;  DebugN("  PASS  ", what); }
  else    { dpdFail++;  DebugN("  FAIL  ", what, "  lastError=", getLastError()); }
}

void dpdSummary()
{
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
}

main()
{
  DebugN("=== mapping: ассоциативный массив ===");

  // ------------------------------------------------------ 1. makeMapping
  DebugN("");
  DebugN("--- 1. makeMapping и mappinglen ---");
  mapping m = makeMapping("one", 1, "two", 2, "three", 3);
  DebugN("  len=", mappinglen(m), "  keys=", mappingKeys(m));
  dpdCheck("makeMapping создал 3 записи", mappinglen(m) == 3);
  dpdCheck("ключ one есть", mappingHasKey(m, "one"));
  dpdCheck("ключа missing нет", !mappingHasKey(m, "missing"));

  // ------------------------------------------------------ 2. добавление и перезапись
  DebugN("");
  DebugN("--- 2. Добавление и перезапись: m[key] = value ---");
  m["four"] = 4;
  dpdCheck("добавлен four, длина 4", mappinglen(m) == 4 && m["four"] == 4);
  m["one"] = 100;
  dpdCheck("one перезаписан, длина не изменилась", mappinglen(m) == 4 && m["one"] == 100);

  // ------------------------------------------------------ 3. типо-строгий hasKey
  DebugN("");
  DebugN("--- 3. mappingHasKey типо-строгий: 1 != \"1\" ---");
  mapping ts = makeMapping("1", "string-key");
  dpdCheck("ключ \"1\" найден", mappingHasKey(ts, "1"));
  dpdCheck("ключ 1 не найден", !mappingHasKey(ts, 1));

  // ------------------------------------------------------ 4. mappingKeys
  DebugN("");
  DebugN("--- 4. mappingKeys: все ключи, порядок не гарантирован ---");
  mapping km = makeMapping("a", 1, "b", 2);
  dyn_anytype keys = mappingKeys(km);
  bool gotA = false;
  bool gotB = false;
  for (int i = 1; i <= dynlen(keys); i++)
  {
    if (keys[i] == "a") gotA = true;
    if (keys[i] == "b") gotB = true;
  }
  DebugN("  keys=", keys, "  dynlen=", dynlen(keys));
  dpdCheck("mappingKeys вернул 2 ключа", dynlen(keys) == 2);
  dpdCheck("среди ключей есть a и b", gotA && gotB);
  dpdCheck("mappingKeys пустого = 0", dynlen(mappingKeys(makeMapping())) == 0);

  // ------------------------------------------------------ 5. позиционный доступ
  DebugN("");
  DebugN("--- 5. mappingGetKey / mappingGetValue (индексация с 1) ---");
  mapping pos = makeMapping("a", 10, "b", 20);
  int posOk = 0;
  for (int i = 1; i <= mappinglen(pos); i++)
  {
    anytype k = mappingGetKey(pos, i);
    anytype v = mappingGetValue(pos, i);
    DebugN("  idx=", i, " key=", k, " value=", v);
    if (mappingHasKey(pos, k) && pos[k] == v) posOk++;
  }
  dpdCheck("позиционный доступ согласован", posOk == mappinglen(pos));

  // Оговорка 3.18: за границей обе функции возвращают -1 и пишут WARNING 76.
  anytype kOut = mappingGetKey(pos, mappinglen(pos) + 1);
  anytype vOut = mappingGetValue(pos, mappinglen(pos) + 1);
  DebugN("  за границей: key=", kOut, " value=", vOut);
  dpdCheck("mappingGetKey за границей = -1", kOut == -1);
  dpdCheck("mappingGetValue за границей = -1", vOut == -1);

  // ------------------------------------------------------ 6. mappingRemove
  DebugN("");
  DebugN("--- 6. mappingRemove: существующий и отсутствующий ключ ---");
  int before = mappinglen(pos);
  int rcMissing = mappingRemove(pos, "zzz");
  DebugN("  missing: rc=", rcMissing, " len=", mappinglen(pos));
  dpdCheck("отсутствующий ключ: rc=0 (оговорка 3.18)", rcMissing == 0);
  dpdCheck("длина при отсутствующем ключе не изменилась", mappinglen(pos) == before);

  int rcRem = mappingRemove(pos, "a");
  DebugN("  existing: rc=", rcRem, " len=", mappinglen(pos));
  dpdCheck("удаление существующего: rc=0", rcRem == 0);
  dpdCheck("длина уменьшилась на 1", mappinglen(pos) == before - 1);
  dpdCheck("ключ a больше не найден", !mappingHasKey(pos, "a"));

  // ------------------------------------------------------ 7. mappingClear
  DebugN("");
  DebugN("--- 7. mappingClear ---");
  int rcClear = mappingClear(pos);
  DebugN("  rc=", rcClear, " len=", mappinglen(pos));
  dpdCheck("clear вернул 0", rcClear == 0);
  dpdCheck("после clear длина 0", mappinglen(pos) == 0);
  dpdCheck("clear пустого тоже 0", mappingClear(pos) == 0);

  // ------------------------------------------------------ 8. смешанные ключи
  DebugN("");
  DebugN("--- 8. Смешанные типы ключей ---");
  mapping mix;
  mix["s"] = "str";
  mix[1] = "one";
  mix[2.5] = "float";
  DebugN("  len=", mappinglen(mix), "  keys=", mappingKeys(mix));
  dpdCheck("смешанные ключи: длина 3", mappinglen(mix) == 3);
  dpdCheck("строковый ключ", mix["s"] == "str");
  dpdCheck("int-ключ", mix[1] == "one");
  dpdCheck("float-ключ", mix[2.5] == "float");

  DebugN("");
  dpdSummary();
}
