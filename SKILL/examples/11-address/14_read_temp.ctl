// 01_read_temp.ctl - чтение одного значения для проверки живой перезагрузки карты.
//
// Используется как инструмент: запустить, изменить map.json, запустить снова.
// Если значение изменилось до нового диапазона - карта подхватилась без
// перезапуска сервера.
//
// Проверено: CTL 3.18, проект <проект стенда>.

main()
{
  DebugN("Температура, °C : ", readOne("mapTemp.Temperature"));
  DebugN("Температура ×10: ", readOne("mapTemp.Temperature_Int"));
}

float readOne(string dpe)
{
  float v;
  dpGet(dpe + ":_online.._value", v);
  return v;
}