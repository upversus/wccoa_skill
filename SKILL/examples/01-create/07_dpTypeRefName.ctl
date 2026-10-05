// 07_dpTypeRefName.ctl - dpTypeRefName(): имя типа, на который ссылается элемент.
//
// Документация: docs/01-create.md
//
// ПРОТОКОЛ ПРОВЕРКИ. Скрипт самодостаточен и повторяем: создаёт два своих типа
// (базовый и ссылающийся), свою точку данных, в конце удаляет всё.
//
// Ссылка на тип объявляется элементом с типом DPEL_TYPEREF и вторым именем -
// именем типа-адресата:
//     rn[2] = makeDynString("", "regratio", baseType);
//     rt[2] = makeDynInt(0, DPEL_TYPEREF);
//
// В документации 3.21.6 Availability у dpTypeRefName() указано UI, то есть
// функция помечена как недоступная в отладчике CTL. Это проверяется здесь
// фактически: если бы функция была недоступна, скрипт не скомпилировался бы.

int dpdPass = 0;
int dpdFail = 0;

string BASE = "dpdemo_trn_base";
string REF  = "dpdemo_trn_ref";
string DP   = "dpdemo_trn_dp";

main()
{
  DebugN("=== dpTypeRefName(): имя типа-ссылки ===");

  makeTypes();
  makeDp();

  // -------------------------------------------------------------------
  // 1. Элемент-ссылка
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 1. Элемент, являющийся ссылкой на тип ---");

  string got = dpTypeRefName(DP + ".regratio");
  DebugN("  dpTypeRefName(\"" + DP + ".regratio\") = '" + got + "'");
  DebugN("  ожидалось: ", BASE);
  dpdCheck(got == BASE, "у ссылочного элемента возвращается имя типа-адресата", got);

  // -------------------------------------------------------------------
  // 2. Обычный элемент - не ссылка
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 2. Обычный элемент: не ссылка ---");

  string plain = dpTypeRefName(DP + ".value");
  DebugN("  dpTypeRefName(\"" + DP + ".value\") = '" + plain + "'  <- пусто");
  dpdCheck(plain == "", "у обычного элемента пустая строка", "'" + plain + "'");

  // -------------------------------------------------------------------
  // 3. Корень точки данных
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 3. Корень точки данных ---");

  string root = dpTypeRefName(DP);
  DebugN("  dpTypeRefName(\"" + DP + "\") = '" + root + "'");
  dpdCheck(root == "", "у корня точки данных пустая строка", "'" + root + "'");

  // -------------------------------------------------------------------
  // 4. Ошибочные случаи
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 4. Ошибочные случаи ---");

  string noDp = dpTypeRefName("noSuchDpAtAll");
  DebugN("  несуществующая точка: '" + noDp + "'  lastError=", getLastError());
  dpdCheck(noDp == "", "несуществующая точка -> пустая строка", "'" + noDp + "'");

  string noEl = dpTypeRefName(DP + ".noSuchEl");
  DebugN("  несуществующий элемент: '" + noEl + "'  lastError=", getLastError());
  dpdCheck(noEl == "", "несуществующий элемент -> пустая строка", "'" + noEl + "'");

  // -------------------------------------------------------------------
  // 5. Согласуется ли с dpGetDpTypeRefs
  // -------------------------------------------------------------------
  DebugN("");
  DebugN("--- 5. Согласование с dpGetDpTypeRefs ---");

  // ИЗМЕРЕНО: dpGetDpTypeRefs() возвращает dyn_dyn_string, где refs[1] -
  // это сам список ссылок, а не отдельная ссылка. То есть первая позиция -
  // список имён типов, вторая позиция - список имён элементов.
  dyn_dyn_string refs = dpGetDpTypeRefs(REF);
  DebugN("  dpGetDpTypeRefs(\"" + REF + "\") вернул ", dynlen(refs), " строк(и)");
  for (int i = 1; i <= dynlen(refs); i++)
  {
    DebugN("    позиция ", i, ": dyn_string из ", dynlen(refs[i]), " имён");
    for (int j = 1; j <= dynlen(refs[i]); j++) { DebugN("        ", refs[i][j]); }
  }
  bool mentioned = FALSE;
  for (int i = 1; i <= dynlen(refs); i++)
  {
    for (int j = 1; j <= dynlen(refs[i]); j++)
    {
      if (refs[i][j] == BASE) { mentioned = TRUE; }
    }
  }
  dpdCheck(mentioned, "dpGetDpTypeRefs называет тот же тип-адресат", "совпадает");
  dpdCheck(got == BASE && mentioned,
           "dpTypeRefName и dpGetDpTypeRefs согласованы между собой", "согласованы");

  dropAll();
  DebugN("");
  DebugN("--- PASS=", dpdPass, "  FAIL=", dpdFail, " ---");
  DebugN("=== конец ===");
}

void makeTypes()
{
  dropAll();

  dyn_dyn_string bn;
  dyn_dyn_int bt;
  bn[1] = makeDynString(BASE);        bt[1] = makeDynInt(DPEL_STRUCT);
  bn[2] = makeDynString("", "value");  bt[2] = makeDynInt(0, DPEL_FLOAT);
  dpdCheck(dpTypeCreate(bn, bt) == 0, "базовый тип создан", BASE);

  // Ссылающийся тип: элемент с типом DPEL_TYPEREF, второе имя - тип-адресат.
  dyn_dyn_string rn;
  dyn_dyn_int rt;
  rn[1] = makeDynString(REF);                 rt[1] = makeDynInt(DPEL_STRUCT);
  rn[2] = makeDynString("", "regratio", BASE); rt[2] = makeDynInt(0, DPEL_TYPEREF);
  dpdCheck(dpTypeCreate(rn, rt) == 0, "ссылающийся тип создан", REF);
}

void makeDp()
{
  dpdCheck(dpCreate(DP, REF) == 0, "точка данных создана", DP);
}

void dropAll()
{
  if (dpExists(DP)) { dpDelete(DP); }
  for (int i = 1; i <= 30; i++)
  {
    if (!dpExists(DP)) { break; }
    delay(1);
  }
  for (int attempt = 1; attempt <= 30; attempt++)
  {
    for (int which = 1; which <= 2; which++)
    {
      string tn = (which == 1) ? REF : BASE;
      dyn_dyn_string pn;
      dyn_dyn_int pt;
      if (dpTypeGet(tn, pn, pt) != 0) { continue; }
      dpTypeDelete(tn);
      delay(1);
    }
    dyn_dyn_string p1; dyn_dyn_int t1;
    dyn_dyn_string p2; dyn_dyn_int t2;
    if (dpTypeGet(REF, p1, t1) != 0 && dpTypeGet(BASE, p2, t2) != 0) { break; }
  }
}
void dpdCheck(bool ok, string what, dyn_anytype extra)
{
  if (ok) { dpdPass++; DebugN("  PASS  ", what, "   ", extra); }
  else    { dpdFail++; DebugN("  FAIL  ", what, "   ", extra, "  lastError=", getLastError()); }
}

bool inList(dyn_string lst, string what)
{
  for (int i = 1; i <= dynlen(lst); i++)
  {
    if (lst[i] == what) { return TRUE; }
  }
  return FALSE;
}