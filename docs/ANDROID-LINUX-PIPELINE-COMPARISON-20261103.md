# Сверка графики и suspend/resume Android и Linux, 2026-11-03

Сравниваются живой Android 6.0.1 Dirty Unicorns с downstream-ядром 3.4
и Linux `7.2.9-t531-unified2-dirty`. Android не является чистой заводской
прошивкой Samsung. Его бинарное ядро не сопоставлено побайтово с исследованным
Samsung/Lineage source commit `3fa1853ed5d6c3a8ef5a2fda9822705243bbc256`.
Проприетарный GLES compiler и точный Android GPU command stream пока не
исследованы: ниже подтверждённые звенья, а не полная реконструкция драйвера.

Linux восстановлен после Android; SHA-256 полного BOOT совпал с резервной
копией. Display manager активен. Тесты автономности не выполнялись.

## Графический тракт

| Звено | Android | Текущий Linux | Значение |
|---|---|---|---|
| GLES | Qualcomm Adreno 305, V@84.0 AU@ | Mesa 25.0.7 Freedreno FD305 / ir3 | Различаются compiler, command/state emission и управление ресурсами |
| Kernel submission | KGSL | DRM MSM / A3xx | Один GPU; разные submission, fence и PM implementations |
| Память | Общая DDR, GPU-local GMEM/OCMEM | Общая DDR, GMEM/OCMEM через msm и OCMEM | Отдельной дискретной VRAM нет; трафик текстур и промежуточных кадров важен |
| Изображения | gralloc / BufferQueue, fences | EGL/GBM, DMA-BUF, Wayland, fences | Формат, layout и число промежуточных кадров требуют сравнения по каждому ресурсу |
| Композиция | SurfaceFlinger + Qualcomm HWC | Plasma/QtQuick → KWin → unified MSM/KMS | Android в снятом домашнем экране отдаёт три слоя в MDP5; Linux имеет GPU-композицию |
| Вывод | MDSS/MDP5 → DSI → TC358764 → LVDS | MDP5 DRM → DSI → TC358764 → LVDS | Та же аппаратная цепь, разный драйвер и sequencing |

Android HWC в снятом состоянии: RGB888 wallpaper, RGBA8888 launcher,
RGBA8888 statusbar. Это наблюдение конкретного рабочего стола; нельзя
переносить его на все анимации. Прежняя Linux проблема межустройственного
PRIME import уже устранена unified DRM: около 6,2 мс → 0,015–0,030 мс.
Повторное объединение DRM не устранит оставшуюся стоимость рендеринга.

Пиковые GPU OPP bus votes уже совпадают с Android DT:

| GPU MHz | GFX→DDR, kB/s | GFX→OCMEM, kB/s |
|---:|---:|---:|
| 450 | 4256000 | 6400000 |
| 320 | 3200000 | 5120000 |
| 200 | 1600000 | 3200000 |
| 19 | 0 | 0 |

Linux дополнительно задаёт ненулевой average DDR vote. Совпадение peak
запросов не доказывает совпадение фактических частот или задержек шины.
Ранее аппаратно измерены GPU 450 MHz, AXI 266,67 MHz, DDR 533,33 MHz;
в новых тестах читались software rates до/после каждого случая.
Android pixel/byte rates в бодрствовании: 76,333/57,250 MHz; прежние
измерения Linux: 74,240/55,680 MHz. Синхронная повторная аппаратная
проверка Linux не проводилась. Разница требует отдельной сверки panel
porches/PLL и объясняет, почему события SurfaceFlinger нельзя автоматически
считать точным оптическим FPS. Она не объясняет offscreen-разрыв ниже.

## Новая проверка без композитора и развёртки

[Полные результаты](graphics-android-linux-comparison-20261103.json).
Одинаковые shader source, разрешение, RGBA8 private texture FBO, blending
ONE / ONE_MINUS_SRC_ALPHA, glClear, fullscreen draws, glFinish, 5 прогревов
и 40 измерений. Depth отсутствует. Android использует Java GLES JNI и EGL
pbuffer 1×1, Linux C и surfaceless EGL. Оба рисуют в отдельный FBO;
работающие оболочки остаются фоновыми потребителями GPU.

Linux A/B/A: `FD_MESA_DEBUG=inorder` → `inorder,ttile` → `inorder`.
Менялось только окружение тестового процесса; GUI не перезапускался.

| 1280×800, среднее мс | Android | Linux A | Linux texture tiling | Linux A повтор |
|---|---:|---:|---:|---:|
| 4 solid layers | 6,3684 | 14,3809 | 14,2890 | 14,3770 |
| 16 solid layers | 20,2741 | 41,3405 | 41,7686 | 42,0866 |
| 4 sampled layers | 8,1979 | 25,6056 | 15,0277 | 25,3895 |
| 16 sampled layers | 26,2982 | 82,2508 | 44,4195 | 82,8428 |

В Mesa A3xx `screen->tile_mode` устанавливается только при `FD_DBG(TTILE)`:
`src/gallium/drivers/freedreno/a3xx/fd3_screen.c:fd3_screen_init`.
В текущем GUI окружении `FD_MESA_DEBUG=inorder`, без `ttile`.
Tiling улучшил четырёхслойный texture test на 41,3%; возврат A восстановил
медленное время. Это причинное подтверждение вклада layout в данный тест,
но не проверенная оптимизация GUI и не доказательство одинакового layout
с закрытым Android driver. Разрешение tiling влияет на подходящие private
resources; импортированные linear DMA-BUF от этого автоматически tiled
не становятся. Проверялся один blue pixel с допуском 2, не весь кадр.

GPU minimum временно 450 MHz, CPU minimum 1190400 kHz. Все 60 Linux
случаев завершились с pixel check без ошибок; minimum после тестов
восстановлены: 19 MHz GPU, 300 MHz CPU. Не менялись напряжения/максимумы.

Остаётся существенный разрыв и на solid layers, почти не зависящий от
texture tiling. По прежним исследованиям FP32 export увеличивает цену
synthetic draw, но full-stack FP16 A/B/A не улучшил GUI FPS. Следовательно,
точная причина оставшегося разрыва ещё не доказана. Следующий предмет
сравнения — shader machine code, GMEM binning/restore/store и state/draw
пакеты на совпадающей нагрузке; отдельно — лишняя GPU-композиция Linux.
Закрытый Android command stream пока не захвачен, нельзя объявлять его
GMEM policy или precision установленными фактами.

## CPU suspend/resume: порядок и различия

| Этап | Android downstream | Linux |
|---|---|---|
| Условия входа | Framework wakelocks, suspend devices; USB способен вернуть -EBUSY | systemd sleep, wakeup sources, device PM; временный default s2idle |
| Обычный idle | WFI, standalone PC, coordinated levels по CPU/L2 votes | В текущем ядре WFI и cpu-spc; полноценного согласованного cluster idle governor нет |
| Системный вход | Последнее ядро; lpm_system_prepare выбирает L2 level | suspend core отключает secondary CPUs; candidate qcom_spm_suspend_enter требует CPU0 alone |
| CPU clock | ramp_down_last_cpu → clk_disable; cortex_disable переключает safe parent/divider, 300 MHz GPLL0_AO/2 | cpufreq-dt generic suspend использует уже имеющийся opp-suspend 300 MHz; aux в DT обычный GPLL0_VOTE |
| Напряжение | AVS save/disable, SAW/CPR, RPM resource policy | OPP/SAW regulator и rpmpd; candidate меняет CPU CX на active-only |
| RPM | flush sleep requests и mask SMD receive IRQ | SMD RPM clients отправляют active/sleep votes при изменении ресурсов; прямого эквивалента downstream entry hook нет |
| MPM | absolute physical-counter deadline, wake mask/polarity, IPC, wake IRQ affinity | Candidate legacy qcom_mpm_prepare_suspend записывает wake table, timer=U64_MAX, barrier, mailbox; отдельный timer diagnostic не включён в production |
| Последний CPU | SPM sequence, boot vector, cpu_suspend, cache flush, SCM TERMINATE_PC | Candidate CPU/L2 SPM, cpu_pm/cluster_pm, cpu_suspend, flush_cache_all, qcom_scm_cpu_power_down |
| Возврат | secure warm entry → cpu_resume; SPM clock gating, CPU clock restore, RPM unmask, pending MPM replay | cpu_resume_arm; SPM standby, SAW voltage restore, cpu/cluster PM exit; MPM pending IRQ replay из handler |

Наличие different entry hook само по себе не означает отсутствие RPM
протокола: mainline SMD RPM реализует другую модель передачи запросов.
Нужна проверка фактических sleep votes, ACK и прерываний у последнего CPU.
Все 41 GPIO→MPM mapping совпали с Android. Отдельный OXILI_GX в живом Android
DT выключен; mainline combined OXILI_CX не является потерянным GPU domain.
APC/L2 — SAW/SCM, а не обычный GDSC. MDSS/Venus/VFE/JPEG/HSIC — локальные
GDSC; CX/MX — общие RPM-controlled rails с отдельными active/sleep votes.

Важно различать работающий `unified2` и source candidate `sleep1`:
расширенные режимы 0/1/2/3 и legacy MPM handshake находятся в кандидате.
В текущем ядре нет sysfs parameter `l2_sleep_mode`. Наличие нового кода
в `.work/linux` не доказывает его работу в загруженном ядре.
Наличие opp-suspend проверено и в живом DT; отсутствие CPU safe frequency
как причины утверждать нельзя. Реальный mux/PLL прямо у SCM entry ещё
требует безопасного измерения; full clk_summary читать нельзя.

## Что подтверждено коротким сном

Android без USB успешно прошёл один системный цикл с MPM deadline 8 с:
из master stats 8,13656 с, APSS shutdown counter 38→40. С USB получен
-EBUSY от f9a55000.usb. При обычном framework screen-off MediaScannerService
держал partial wakelock, поэтому screen-off не означал system suspend.

XO/VMIN counters не выросли даже в успешном Android цикле. В suspend log
остались mdss_ahb/axi/mdp/lut и обычные XO/GPLL0 запросы. Этот baseline
не подтверждает исправность полного XO shutdown. Причина удержания
тактов — ещё не установлена: возможную handoff reference нельзя выдавать
за доказанный дефект.

В Linux короткие циклы с удерживаемым DSI PHY ранее возвращались. Полное
освобождение PHY в эксперименте приводило к отсутствию подтверждённого
CPU resume и последующему reset; точная причина reset не установлена.
Различие локализует опасную границу к общему clock/rail/wakeup переходу,
но ещё не доказывает конкретный PLL, IRQ или voltage fault. Новых циклов
сна во время этой сверки не запускалось.

Практический выбор: WFI/SPC автоматически во время работы; s2idle —
текущий проверенный системный standby; shallow — отдельный L2 retention
путь для диагностики; deep RPM/APC collapse и освобождение общих clocks
пока требуют завершения проверки кандидата. XO shutdown и VMIN —
результаты согласования всех потребителей, а не независимые кнопки сна.
Hibernation не включена и не обеспечивает обычное телефонное пробуждение.
