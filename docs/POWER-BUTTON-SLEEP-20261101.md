# Power button / aborted second sleep, 2026-11-01

Physical reproduction captured with passive input-event reads and 50 ms display
state polling. Each observed power press has one KEY_POWER down/up pair;
no extra power press was captured at the spontaneous screen-on transition.

The first attempt enters s2idle and resumes on the next physical key. The next
attempt returns -EBUSY before task freezing; systemd-sleep explicitly reports
"Failed to put system to sleep. System resumed again: Device or resource busy".
The display turns off at monotonic 2005.838 and on at 2006.669, with backlight
restored at 2006.774. No additional suspended time elapses in that attempt.
This is an aborted suspend, not proof of a completed sleep followed by an
uncommanded wakeup.

The asynchronous filesystem sync completes at 2007.030, after the failure at
2006.491. The kernel sync helper can return -EBUSY when wakeup becomes pending
while sync is running. GPIO38 card-detect IRQ78 has approximately three million
interrupts; the mmc1 wakeup source has hundreds of thousands of reported events.
An independent wakeup trace associates mmc1 activation with irq/78-f98a4900.
This anomaly was already recorded in GRAPHICS-BOTTLENECK.md, where temporarily
masking it did not improve graphics FPS. Its relevance to suspend is separate.

A bounded control / card-detect-only masked / restored sleep trial is pending.
The private test module verifies the IRQ hardware number and exact action name,
leaves SD data/power interrupts enabled, and automatically restores the IRQ.
No boot kernel, device tree or permanent power settings have been changed.

Raw scripts and captures: `.work/power-button-20261101/`.

The subsequent automated trial was interrupted after loss of connectivity and
owner reports of repeated screen-on / sleep. Its shell used systemctl suspend
without explicitly waiting for the complete PrepareForSleep(true/false) cycle,
so clearing the RTC alarm and advancing phases was not a valid synchronization
method. Its results must not be used as a clean A/B proof. The private script is
disabled locally. The owner restored stable operation after three further wakes. SSH recovery verified: the trial service is inactive, the module is absent, RTC wakealarm is empty, backlight is on, and IRQ78 increments again (3,043,472 then 3,065,488). Suspend statistics are success=6, fail=1. These later cycles do not constitute a synchronized A/B result.

## Permanent board fix

Patch 0130 removes SM-T531's `cd-gpios` and enables the existing `broken-cd`
polling fallback. SDHCI's broken-card-detection quirk disables native card-detect
interrupts and assumes presence while MMC periodically checks card liveness.
The socket remains removable; data/power IRQs and other wake sources are
unchanged. Other Matisse boards retain their original configuration.

The deployed trial changes only those two properties in the exact currently
used appended DT. All other DT properties and all 12,898,816 kernel-code bytes
are verified unchanged. The initramfs, kernel command line and modules are
unchanged. See `sd-cd-fix-package-20261101.json`. A complete verified snapshot
is `/var/lib/t531/graphics-baselines/20261101T161341Z`. The immutable golden
slot and bootstrap files remain intact; the previous production slot is saved
exactly under `/var/lib/t531/sd-cd-fix-20261101/previous-boot`.

The 48 MiB SD boot partition cannot hold three complete kernels alongside
rescue files. Slot switching selects golden first, verifies an exact rootfs
backup before retiring the unselected non-golden slot, then stages/selects the
requested image. The first-boot guard restores the previous production image
as next-boot selection before graphics. Runtime acceptance re-stages the fixed
image using the same verified procedure. The stage/guard/accept selection
sequence was checked on a host temporary filesystem; all three existing slot
unit tests also pass. The fixed DT image was accepted and is persistently selected. Golden and the rootfs backup of the previous production image remain available.

## Device validation after the DT-only boot

The fixed DT booted with the unchanged unified2 kernel. The first-boot guard
completed and restored the previous image as the next-boot selection. The CD
GPIO IRQ is no longer registered; the SD data IRQ remains active. The mmc1
wakeup source reports zero activations/events instead of the previous storm.
A 16 MiB random write, fsync and full readback match SHA-256 (2.608 s total).
KWin and plasmashell run; the unified probe reports hardware Adreno305, atomic
1280x800 at 59.999 Hz on one DRM device.

The first two RTC cycles suspend for 12.336 and 13.756 seconds with kernel
success=2, fail=0. A logging error after the first resume did not affect the
completed transition; the helper was corrected before subsequent trials. An
input-device number precondition also safely rejected a test after devices
were renumbered; the helper now discovers pm8941_pwrkey by name.

Subsequent key tests distinguish system resume from display wake. An RTC wake
can leave DPMS off, in which case the next short power key wakes the display
rather than requesting another suspend. Tests must establish display-on before
requesting sleep and verify display-on plus no further suspend after resume.
A timeout in the earlier helper represents a display-only wake with no kernel
suspend attempt; it is excluded from sleep-cycle results. These early diagnostic results are superseded by the final validation below.

## Second independent sleep defect: uninitialized A3xx ring

After CD events were eliminated, another transition failed later, in the GPU
suspend callback: `adreno_idle` reports hardware RPTR/software WPTR 0/528 and
`adreno_system_suspend` returns -EBUSY. This differs from the original abort
during filesystem sync. Kernel statistics at that point were success=6, fail=1;
therefore the DT fix alone must not be described as complete sleep acceptance.

`msm_gpu_pm_resume()` sets needs_hw_init but defers CP initialization to the
next submit. A second suspend without a submit can therefore compare reset
hardware pointers against the previous software cursor. Patch 0131 reconciles
cur/next with hardware WPTR only when needs_hw_init is true. It validates the
pointer range and retains ring-drain, RBBM busy and VBIF halt checks, fences,
sequence numbers and submission tracking. Using hardware WPTR covers retained
state as well as reset-to-zero state.

The MSM module builds against the exact unified2 configuration (byte-identical
to the recorded kernel.config) and matching version magic. All undefined
symbols are checked using symbol tables from the actual dependency builds;
no unresolved-symbol or version checks are disabled. Only msm.ko is installed.
The previous module and checksum are saved under the repair state directory.
Installed candidate SHA-256:
`5b33a0884837ff51ee1a5bbbe3368666f0053c047fdf67cbe75d1f39f2d89b15`.
The subsequent reboot loaded the candidate module: its in-memory GNU build-note SHA-256 matches the built module (`268fba25f5e904f2029e88106617040fbf39179665db46f3cb3b5a5ac6d5b131`).


## Remaining software wake source and final policy

With the fixed DT and loaded MSM module, two more RTC cycles succeeded. A
subsequent key-triggered attempt still aborted during filesystem sync. The
only wake source with a new wakeup_count in that boot was `pm8226-bms` (one);
mmc1 remained zero. This identifies BMS polling as the remaining suspect,
although the failed transition itself did not record wake-source tracepoints.
A separate successful key cycle traced periodic `pm8226-bms` activation from
kworker; source inspection shows the freezable periodic poll unconditionally
calls power_supply_changed(), which holds a wakeup source by default.

Patch 0132 sets power_supply_config.no_wakeup_source for this poll-only BMS.
It has no IRQ and cannot detect a hardware wake condition. The modified
object compiles with the production kernel configuration. This BMS is built
into the running kernel; therefore the equivalent device wakeup policy is
applied live and persistently through
`/etc/udev/rules.d/80-t531-bms-poll-no-wakeup.rules`, supplied in scripts/.
The BMS continues reporting measurements; charger, RTC and power-key wake
sources retain their existing policy.

The temporary GPU `power/control=on` diagnostic service drop-in was backed up
and removed; the GPU now uses normal runtime PM (`auto`). The final validation
uses the ordinary production graphics libraries and the loaded patched MSM
module. Automated tests are bounded, wait for the actual kernel result and
service completion, and clear the RTC alarm afterward.


## Final installed validation

With SD polling, patched MSM and BMS software wake disabled, three consecutive
cycles pass (12.979, 13.439 and 13.798 seconds actually suspended). The first
two use logind; the third injects one short power key through the existing
input device and the ordinary desktop power handler. After the RTC wake leaves
DPMS off, one power key restores the display and the 15-second observation
period detects no further suspend. Kernel counters change success 3→6 and
fail remains 1: that earlier failure predates the final BMS policy, and is
retained rather than hidden/reset. This is three final successful cycles,
not six error-free cycles across the whole investigation.

The final trace contains four runtime resume→suspend intervals with no GPU
submissions between them. All complete without the previous idle timeout.
The two forced-on system cycles did contain submissions after resume, so
that specific no-submit system-suspend sequence was not directly covered.
An offscreen GPU readback after the final series passes all seven cases,
21,045 pixels per case, maximum channel error 1. The unified probe remains
Adreno305, one DRM device, atomic 1280×800 at 59.999 Hz. Existing MDP SMP
allocation messages occur both before and after this work and are not a
claim of complete graphics-pipeline acceptance.

No sleep-test units remain running; RTC wakealarm is empty; the display is on.
GPU runtime policy is auto, mmc1 wakeup events remain zero. udevadm test matches
the persisted BMS rule. Results: sd-cd-sleep-results-20261101.json. The brief
repeated sleep/wake activity reported during this session coincided with the
explicit RTC test series; it was stopped and the alarm cleared before further
bounded checks.

Rollback: `/usr/local/libexec/t531-sd-cd-slot restore` restores the previous
SD boot selection. The previous MSM module is saved as
`/var/lib/t531/sd-cd-fix-20261101/msm-before-0131.ko`; restoring it requires
depmod and a reboot. The BMS policy is the named udev rule and device
power/wakeup attribute. The immutable golden boot slot remains intact.
