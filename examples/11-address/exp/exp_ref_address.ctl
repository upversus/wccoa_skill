// exp_ref_address.ctl — считывание эталонной конфигурации _address,
// созданной вручную в ParaMod.
//
// Цель: увидеть реальные значения, которые OA пишет при штатной настройке
// адреса, и сверить их с допущениями из docs/11-address.md:
//   * формат строки _reference;
//   * коды _datatype и _direction;
//   * имя драйвера в _drv_ident;
//   * наличие и содержимое _distrib.
//
// Эталон: тип точки данных for_test_OPCUA, точка данных f1, элемент f_node.
//
// Запуск: разовый, неблокирующий.

main()
{
  DebugN("=== Эталон конфигурации _address ===");

  string dpe = "f1.f_node";

  // --- 1. сама точка данных и её тип ---------------------------------------
  DebugN("dpExists(\"", dpe, "\") = ", dpExists(dpe));
  DebugN("dpTypeName(\"f1.\") = '", dpTypeName("f1."), "'");
  DebugN("dpElementType(\"", dpe, "\") = ", dpElementType(dpe));

  // --- 2. структура типа ----------------------------------------------------
  dyn_dyn_string tn;
  dyn_dyn_int tt;
  int rcT = dpTypeGet("for_test_OPCUA", tn, tt);
  DebugN("dpTypeGet(\"for_test_OPCUA\") rc=", rcT, " элементов=", dynlen(tn));
  if (rcT == 0)
  {
    for (int i = 1; i <= dynlen(tn); i++)
    {
      string nl = "";
      for (int j = 1; j <= dynlen(tn[i]); j++) { nl = nl + " '" + tn[i][j] + "'"; }
      string tl = "";
      if (i <= dynlen(tt))
      {
        for (int j = 1; j <= dynlen(tt[i]); j++) { tl = tl + " " + tt[i][j]; }
      }
      DebugN("   n[", i, "]=", nl, "  t[", i, "]=", tl);
    }
  }

  // --- 3. состав всех конфигов элемента ------------------------------------
  // dpGetAllConfigs покажет, какие конфиги вообще созданы на этом элементе.
  dyn_string cfgs = dpGetAllConfigs(dpe + ":");
  DebugN("dpGetAllConfigs(\"", dpe, ":\") вернул ", dynlen(cfgs), ":");
  for (int i = 1; i <= dynlen(cfgs); i++)
  {
    DebugN("   ", cfgs[i]);
  }

  // --- 4. все атрибуты конфига _address ------------------------------------
  // Читаем по списку из документации, а не по фиксированному набору:
  // так не пропустим атрибуты, добавленные в этой версии.
  DebugN("--- атрибуты _address ---");
  dyn_string attrs = dpGetAllAttributes("_address");
  DebugN("dpGetAllAttributes(\"_address\") вернул ", dynlen(attrs), ":");
  for (int i = 1; i <= dynlen(attrs); i++)
  {
    DebugN("   атрибут: ", attrs[i]);
  }

  // --- 5. значения ключевых атрибутов --------------------------------------
  DebugN("--- значения ---");

  string sVal;
  bool bVal;
  int iVal;
  int rc;

  rc = dpGet(dpe + ":_address.._type", iVal);
  DebugN("_address.._type      rc=", rc, "  значение=", iVal);

  rc = dpGet(dpe + ":_address.._reference", sVal);
  DebugN("_address.._reference rc=", rc, "  значение='", sVal, "'");

  rc = dpGet(dpe + ":_address.._drv_ident", sVal);
  DebugN("_address.._drv_ident rc=", rc, "  значение='", sVal, "'");

  rc = dpGet(dpe + ":_address.._connection", sVal);
  DebugN("_address.._connection rc=", rc, "  значение='", sVal, "'");

  rc = dpGet(dpe + ":_address.._datatype", iVal);
  DebugN("_address.._datatype  rc=", rc, "  значение=", iVal);

  rc = dpGet(dpe + ":_address.._direction", iVal);
  DebugN("_address.._direction rc=", rc, "  значение=", iVal);

  rc = dpGet(dpe + ":_address.._mode", iVal);
  DebugN("_address.._mode      rc=", rc, "  значение=", iVal);

  rc = dpGet(dpe + ":_address.._subindex", iVal);
  DebugN("_address.._subindex  rc=", rc, "  значение=", iVal);

  rc = dpGet(dpe + ":_address.._offset", iVal);
  DebugN("_address.._offset    rc=", rc, "  значение=", iVal);

  rc = dpGet(dpe + ":_address.._active", bVal);
  DebugN("_address.._active    rc=", rc, "  значение=", bVal);

  rc = dpGet(dpe + ":_address.._internal", bVal);
  DebugN("_address.._internal  rc=", rc, "  значение=", bVal);

  rc = dpGet(dpe + ":_address.._lowlevel", bVal);
  DebugN("_address.._lowlevel  rc=", rc, "  значение=", bVal);

  // --- 6. конфиг _distrib ----------------------------------------------------
  DebugN("--- _distrib ---");
  rc = dpGet(dpe + ":_distrib.._type", iVal);
  DebugN("_distrib.._type   rc=", rc, "  значение=", iVal);
  rc = dpGet(dpe + ":_distrib.._driver", iVal);
  DebugN("_distrib.._driver rc=", rc, "  значение=", iVal);

  // --- 7. значение, которое реально приходит с PLC --------------------------
  DebugN("--- значение ---");
  float onLine;
  rc = dpGet(dpe + ":_online.._value", onLine);
  DebugN("_online.._value   rc=", rc, "  значение=", onLine);

  float origVal;
  rc = dpGet(dpe + ":_original.._value", origVal);
  DebugN("_original.._value rc=", rc, "  значение=", origVal);

  // Метка времени источника покажет, свежее ли значение.
  time stime;
  rc = dpGet(dpe + ":_online.._stime", stime);
  DebugN("_online.._stime   rc=", rc, "  значение=", formatTime("%c", stime, ""));

  // --- 8. прямое чтение из PLC (только OPC UA) ------------------------------
  DebugN("--- прямое чтение из PLC ---");
  float direct;
  rc = dpDirectRead(5000, dpe + ":_original.._value", direct);
  DebugN("dpDirectRead(5000, ", dpe, ":_original.._value) rc=", rc,
         "  значение=", direct, "  lastError=", getLastError());

  DebugN("=== конец ===");
}