// 05_bits.ctl - работа с битами bit32/bit64: getBit, setBit, checkPattern, setPattern.
// Документация: docs/14-legacyFoo.md (раздел 4).
// Проверено: CTL 3.18, проект <проект стенда>.
// Скрипт самодостаточен: точки данных не создаёт, сеть не используется.
//
// Измеренные оговорки 3.18:
//   - getBit / setBit за границей позиции возвращают 0 (документация обещает -1).
//   - шаблон checkPattern/setPattern читается справа налево: правый символ — бит 0.

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
  DebugN("=== Работа с битами (bit32/bit64) ===");

  // ------------------------------------------------------ 1. getBit
  DebugN("");
  DebugN("--- 1. getBit: значение бита (позиция 0 = младший) ---");
  bit32 b = 13;              // 1101b: биты 0, 2, 3 = 1; бит 1 = 0
  DebugN("  b = 13 (1101b)");
  dpdCheck("getBit(b,0)==1", getBit(b, 0) == 1);
  dpdCheck("getBit(b,1)==0", getBit(b, 1) == 0);
  dpdCheck("getBit(b,2)==1", getBit(b, 2) == 1);
  dpdCheck("getBit(b,3)==1", getBit(b, 3) == 1);
  dpdCheck("getBit(b,4)==0", getBit(b, 4) == 0);
  dpdCheck("getBit(b,31)==0", getBit(b, 31) == 0);

  // ------------------------------------------------------ 2. getBit за границей
  DebugN("");
  DebugN("--- 2. getBit за границей: измерено — 0, не -1 ---");
  int gbOob = getBit(b, 32);
  DebugN("  getBit(b,32) = ", gbOob);
  dpdCheck("getBit за границей = 0 (оговорка 3.18)", gbOob == 0);

  // ------------------------------------------------------ 3. checkPattern
  DebugN("");
  DebugN("--- 3. checkPattern: совпадение с шаблоном (справа налево) ---");
  dpdCheck("checkPattern(b,\"1101\")==1", checkPattern(b, "1101") == 1);
  dpdCheck("checkPattern(b,\"0011\")==0", checkPattern(b, "0011") == 0);
  dpdCheck("checkPattern(b,\"xx01\")==1", checkPattern(b, "xx01") == 1);
  dpdCheck("checkPattern(b,\"xx1x\")==0", checkPattern(b, "xx1x") == 0);
  dpdCheck("checkPattern(b,\"\")==0", checkPattern(b, "") == 0);

  // ------------------------------------------------------ 4. setBit
  DebugN("");
  DebugN("--- 4. setBit: установить бит ---");
  int rc1 = setBit(b, 1, true);
  DebugN("  setBit(b,1,true) rc=", rc1, " b=", b);
  dpdCheck("setBit rc==0", rc1 == 0);
  dpdCheck("бит 1 стал 1 (b=15)", b == 15);
  dpdCheck("остальные биты не изменились", getBit(b, 0) == 1 && getBit(b, 2) == 1 && getBit(b, 3) == 1);

  int rc2 = setBit(b, 0, false);
  DebugN("  setBit(b,0,false) rc=", rc2, " b=", b);
  dpdCheck("setBit rc==0", rc2 == 0);
  dpdCheck("бит 0 стал 0 (b=14)", b == 14);
  dpdCheck("бит 1 остался 1", getBit(b, 1) == 1);

  int rcOob = setBit(b, 32, true);
  DebugN("  setBit(b,32,true) = ", rcOob);
  dpdCheck("setBit за границей = 0 (оговорка 3.18)", rcOob == 0);

  // ------------------------------------------------------ 5. setPattern
  DebugN("");
  DebugN("--- 5. setPattern: назначить шаблон ---");
  bit32 c;
  int rc3 = setPattern(c, "1111");
  DebugN("  setPattern(c,\"1111\") rc=", rc3, " c=", c);
  dpdCheck("setPattern rc==0", rc3 == 0);
  dpdCheck("c == 15 (1111b)", c == 15);
  dpdCheck("checkPattern(c,\"1111\")==1", checkPattern(c, "1111") == 1);

  int rc4 = setPattern(c, "xx0x");
  DebugN("  setPattern(c,\"xx0x\") rc=", rc4, " c=", c);
  dpdCheck("x не меняет биты, c=13 (1101b)", c == 13);
  dpdCheck("бит 1 (справа налево) сброшен", getBit(c, 1) == 0);

  dpdSummary();
}
