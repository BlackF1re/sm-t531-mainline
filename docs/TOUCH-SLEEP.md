# maXTouch contact retained across sleep

Updated 2026-10-22 on SM-T531. The stale-contact failure was reproduced on
Linux `7.2.9-dirty #16` and fixed in `#17` by the separate
[maXTouch patch](../patches/linux/0124-input-atmel-mxt-release-contacts-across-sleep.patch).
Implementation state: **VERIFIED** for this touch sleep/wake regression.
The owner confirmed normal PIN unlock, touch, and Power behavior after testing.

## Device evidence

**VERIFIED_DEVICE:** after the reported sleep/wake incident, evdev held
`BTN_TOUCH=1`, slot 0 tracking ID 9, position `(35, 1820)` in the controller's
`0..4095` coordinate space. No input event arrived during a 12-second sample;
the contact remained identical in three subsequent queries. Power and volume
buttons were released. Rebinding only I2C device `4-004a` cleared all 16 slots.
The owner confirmed normal operation afterward.

A second, isolated test exercised the real bound driver's `suspend()` and
`resume()` callbacks through
[`tools/mxt-pm-probe`](../tools/mxt-pm-probe/README.md). A synthetic contact
was injected into the real evdev device while exclusively grabbed, hiding it
from Phoc. `BTN_TOUCH` was then released to model the input core's suspend
key cleanup. Slot 15 tracking ID 30000 survived the driver's sleep/wake pair
and another 0.5 seconds. Both callbacks returned zero. Explicit cleanup left
all 16 slots inactive, and the diagnostic module was unloaded. The system
itself did not suspend; this is a **driver callback regression test**, not
an end-to-end suspend acceptance test.

## Mechanism

**VERIFIED_UPSTREAM / pre-fix source:** `mxt_stop()` selects T7 deep sleep;
`mxt_suspend()` disables the IRQ afterward. Neither releases MT slots.
`input_dev_suspend()` releases key bits, including `BTN_TOUCH`, but leaves
the MT tracking IDs intact. `mxt_resume()` enables IRQ processing before
`mxt_start()` restores T7 run mode and requests calibration. T6 reset and
calibration status handling also leaves MT slots intact. Before patch0124,
the production series did not modify this touchscreen driver.

If scanning stops with a finger down, the controller need not send its lift
report. Linux consequently retains a contact whose physical lifetime has
ended. A final measurement or queued report can also be processed around the
stop/start boundary. The callback test confirms that this kernel preserves
such a stale contact; it does not distinguish which report was lost in the
original incident, whose raw pre-suspend messages were not recorded.

**HISTORICAL_SOURCE:** Nick Dyer's fix explicitly describes this maXTouch
behavior. The latest revision located in this investigation is Jiada Wang's
[v11 12/56, 2020-05-08](https://lkml.rescloud.iu.edu/2005.1/00068.html),
"Input: atmel_mxt_ts - release touch state during suspend". It combines IRQ
serialization, slot release, and draining old messages while reporting is
suppressed. Original source commit:
`26794433086dbc7dea18d2f6a1c8d61ab25bcfda`; GPL-2.0-or-later driver.
The production patch preserves Nick Dyer's authorship and adapts this fix to
the current PM callbacks without adopting the historical series wholesale. The
[current upstream driver](https://github.com/torvalds/linux/blob/master/drivers/input/touchscreen/atmel_mxt_ts.c)
was checked on 2026-10-22 and still lacks that combined fix.

## Installed correction and acceptance

Patch0124 quiesces the threaded IRQ before stopping scans and releases all
MT contacts plus pointer-emulation state. A sleep-transition flag suppresses
old input reports while preserving T6 completions required by T9 soft reset.
Resume wakes the controller and drains its old message queue, then restarts
scanning and synchronizes the IRQ before allowing input reports. Message
drain I2C errors are returned rather than mistaken for a short successful read.
The existing probe, input open/close and firmware-update IRQ ownership stays
in place. The T9 Chromebook reset branch was reviewed but not tested on that
different hardware.

**VERIFIED_DEVICE:** kernel `#17` passed 10 callback cycles, each starting
with synthetic contacts in slots 0, 7 and 15. Every cycle ended with all 16
tracking IDs -1 and `BTN_TOUCH=0`. It then passed 3 real system sleep/wake
cycles through logind, with the installed `MemorySleepMode=s2idle` policy and
10-second RTC wake alarms: suspend statistics were **3 success / 0 fail**.
Synthetic contacts were hidden from Phoc using EVIOCGRAB and were removed by
the actual driver PM callbacks. Phosh kept the same session, and SSH/Wi-Fi
returned. Test artifacts are summarized in
[touch-sleep-results.json](touch-sleep-results.json).

The owner subsequently confirmed on the physical device that the screen stays
off after pressing Power, and that PIN unlock and normal touch work after
waking. This is a short acceptance test, not an endurance result.

The unchanged configuration, DTB and MSM module were checksum-verified;
all 119 production patches match the built source, and checkpatch reports
zero errors, warnings and checks. Two trial boots of the same #17 image were
observed. The tested image is persisted on the SD boot partition; the internal
bootstrap is untouched and the verified #16 rollback remains at
`/var/lib/t531/kernel-trial-backup`. It can be restored with
`sudo /usr/local/libexec/t531-kernel-trial-restore --rollback`, then a reboot.

## Separate system-sleep limitation

An initial diagnostic used `rtcwake -m mem` directly, bypassing logind and the
installed sleep policy. This selected the kernel default `deep` instead of
the configured `s2idle`. One cycle cleared the contacts and returned; the next
was aborted in DRM preparation with `mdp5_pipe_release` WARN and `-EINVAL`.
That was a test-method error and is not a successful deep-suspend acceptance.
The device was rebooted into the same #17 image before the successful logind
tests. The exact direct-deep sequence was not compared against #16, so the
DRM failure's origin is not claimed as established. Native deep suspend
remains unverified; this touchscreen fix does not establish the correctness
of the complete graphics/power stack.

The volume overlay and immediate display reactivation are consistent with
the stale touch interfering with shell gestures, and disappeared after the
rebind according to the owner. Their separate event chains have not been
traced. This driver disables the touch IRQ and does not enable it as a system
wake source. Shell display reactivation and a kernel wake source must not be
conflated; the original wake source has not been isolated here.
