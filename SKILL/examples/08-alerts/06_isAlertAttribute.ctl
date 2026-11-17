// 06_isAlertAttribute.ctl - isAlertAttribute(): является ли атрибут атрибутом тревоги.
// Документация: docs/08-alerts.md#isalertattribute
// Проверено: CTL 3.18, проект <проект стенда>.
// Скрипт самодостаточен: точки данных не создаёт, живая тревога не нужна.
//
// Измеренные оговорки 3.18:
//   - _event возвращает FALSE, хотя писать его можно только через alertSet();
//   - голое имя без DPE ("_ack_state", "_value") тоже даёт TRUE: функция
//     проверяет имя атрибута, а не конкретный конфиг точки данных.

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
  DebugN("=== isAlertAttribute() ===");
  DebugN("  сигнатура: bool isAlertAttribute(string attr)");

  string dp = "System1:ExampleDP_AlertHdl1.";

  // --- атрибуты экземпляра тревоги ---------------------------------------
  dpdCheck("_alert_hdl.._ack_state — TRUE",
           isAlertAttribute(dp + ":_alert_hdl.._ack_state"));
  dpdCheck("_alert_hdl.._alert_fore_color — TRUE",
           isAlertAttribute(dp + ":_alert_hdl.._alert_fore_color"));
  dpdCheck("_alert_hdl.._ack_time — TRUE",
           isAlertAttribute(dp + ":_alert_hdl.._ack_time"));

  // --- не атрибуты тревоги ------------------------------------------------
  dpdCheck("_archive.._archive — FALSE",
           !isAlertAttribute(dp + ":_archive.._archive"));
  dpdCheck("_original.._value — FALSE",
           !isAlertAttribute(dp + ":_original.._value"));

  // --- измеренное исключение ---------------------------------------------
  dpdCheck("_alert_hdl.._event — FALSE (исключение 3.18)",
           !isAlertAttribute(dp + ":_alert_hdl.._event"));

  // --- голое имя: конфиг не различается ----------------------------------
  dpdCheck("голое \"_ack_state\" — TRUE",
           isAlertAttribute("_ack_state"));
  dpdCheck("голое \"_value\" — TRUE (омоним конфига)",
           isAlertAttribute("_value"));
  dpdCheck("несуществующий атрибут — FALSE",
           !isAlertAttribute("_no_such_alert_attr_xyz"));

  dpdSummary();
  exit(0);
}
