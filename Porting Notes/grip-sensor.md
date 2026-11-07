# Semtech SX9500 grip / SAR

* Работает через штатный IIO: чтение raw, компенсация фона, калибровка,
  буфер и пороговые события; реакция на хват и отпускание проверена.
* I²C `0x28`, GPIO0/1 SDA/SCL, IRQ GPIO66 (спад); VDD=L15 2.8V,
  SVDD=LVS1. Основной электрод CS0, опорный CS1; GPIO66 не делить с AUXPCM.
* `CONFIG_SX9500=m`, драйвер `sx9500`, патчи0149–0152: DT, питание
  VDD→SVDD, знаковые отсчёты, калиброванная ёмкость и управление порогами.
  Ожидание преобразования ограничено 900мс с учётом смены частоты.
* `in_proximityN_raw` — signed USEFUL; `_input` — `(USEFUL−AVG)>>4`.
  `in_capacitanceN_input` — ёмкость/ΔC в нФ по модели Samsung;
  `_calibbias` — поправка, `_scale`=0.000000100 нФ/код. Пороги и гистерезис
  общие, включение событий раздельное; raw доступен в triggered buffer.
* EFS `/grip_cal_data`: 12байт, LE signed32 baseline/USEFUL/OFFSET;
  legacy baseline≤100000 нормализуется добавлением300000.
  `t531-configure-grip --install FILE` сохраняет baseline CS0 в приватное
  udev-правило; rootfs принимает `GRIP_CALIBRATION_FILE`. OFFSET не восстанавливается.
* При сильном хвате x8 возможно насыщение32767; ёмкость тогда неточна.
  Suspend/resume не проверен; управление SAR модема не реализовано.
* Аппаратная схема и модель: Samsung `drivers/sensors/sx9500{,_reg.h}`,
  commit `3fa1853ed5d6c3a8ef5a2fda9822705243bbc256`.
