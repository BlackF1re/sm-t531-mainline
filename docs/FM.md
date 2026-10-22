# FM receiver bring-up

Updated 2026-10-22. **FM reception is not working or accepted.** The native
receiver candidate registers `/dev/radio0` and passed 49/49 `v4l2-compliance`
1.30.1 API checks. With wired headphones connected, all 29 owner-supplied
Tomsk frequencies returned zero signal, no stereo/RDS lock and no RDS bytes.
Successful tuning commands and API compliance do not prove reception.
[Measurements](fm-results.json) retain that distinction.

## Is FM actually connected on SM-T531?

The leading hypothesis is now **an unwired FM function**, not merely a missing
Linux driver. Samsung's SM-T531 service manual, Rev.1.0 (April 2014), provides
model-specific evidence:

* [Product functions, page 5](https://www.manualslib.com/manual/2076923/Samsung-Sm-T531.html?page=5)
  lists Wi-Fi/Bluetooth/GNSS but does not advertise FM.
* [Board block diagram, page 29 / sheet 8-1](https://www.manualslib.com/manual/2076923/Samsung-Sm-T531.html?page=29)
  identifies MATISSE3G SM-T531 rev0.3 and a WCN3660A Wi-Fi/Bluetooth block;
  no FM route is identified in the extracted text.
* [Radio schematic, page 45 / sheet 8-17](https://www.manualslib.com/manual/2076923/Samsung-Sm-T531.html?page=45)
  names the chip's FM pins: FM_DATA (41), FM_SSBI (48), FM_HS_RX (61) and
  FM_TXRX (68). Unlike neighboring Bluetooth signals, these appear only as
  pin labels without corresponding external net names in the text extraction.

Retrieved 2026-10-22. These are Samsung-authored documents hosted by a third
party; copyrighted scans are not redistributed. **Only the textual rendering
was accessible.** Wires and no-connect crosses have not been visually inspected,
and the physical board has not been traced. Missing text labels alone do not
prove an open circuit. Thus disconnected FM is a **HYPOTHESIS**, not a verified
absence or a claim that WCN3660 silicon lacks FM.

The same zero-signal behavior in native Linux and preserved Android supports
that hypothesis, but Android was a downstream ROM rather than factory Samsung.
Before further driver work, inspect the graphical schematic at those four pins
and, if necessary, establish continuity/population on the actual board revision.
Keep FM outside production until a usable board-level receiver is established.

## Implementation and deployment

The [candidate patch](../patches/candidates/fm/0001-media-radio-qcom-smd-candidate.patch)
implements a V4L2 receiver on the actual `APPS_FM` RPMSG service advertised by
this tablet's existing WCNSS firmware. It has standard tuner/frequency ioctls,
mute, 50/75 µs deemphasis, RDS reception control, block reads/poll and a bounded
hardware-seek implementation. No Android HAL, private userspace ABI or persistent
helper is required by this design. The endpoint is acquired on first open and
released on last close. Command waits are bounded; removal wakes waiters and
releases the endpoint before freeing callback storage.

It remains **outside the production patch series and kernel fragments**. Trials
use an external module in RAM; no candidate module is installed under
`/lib/modules`, and no FM autoload/service/driver override is retained. Kernel
#19, the SD boot artifacts and the internal BOOT are the existing baseline.
Do not promote this candidate because a radio node appeared.

## Device evidence and blockers

| Check | Result | What it establishes |
| --- | --- | --- |
| `APPS_FM` presence | One real WCNSS RPMSG channel | Firmware exposes an FM control service. |
| Enable/configuration/tune | Firmware accepts commands; fresh initialization generates tune-status events | Control transport and command framing work. |
| Native `/dev/radio0` | `v4l2-ctl` queries controls/tuner and sets/reads 104.6 MHz | Standard Linux application interface works in the candidate. |
| `v4l2-compliance` 1.30.1 | 49 passed, 0 failed, 0 warnings | Tested API behavior only. It does not validate received RF, seek results, RDS or suspend. |
| 29 supplied stations, two-second dwell | All signal values zero; no stereo/RDS lock or bytes; no tuning errors | Real RF acceptance failed under the tested conditions. |
| Antenna selections 0 and 1 | Six stations each; all zero | Selecting either firmware antenna path did not fix reception. The board's physical routing is still unknown. |
| Measured process calibration | Firmware returns calibration and accepts applying it; reception unchanged | Calibration control is responsive; does not establish complete RF calibration. No calibration file was written. |
| Hold Iris bootstrap rails and XO | Same configured voltages; no improvement; temporary votes released | Extra host resource votes alone did not restore reception. This is not a physical voltage measurement. |
| Receiver disable | No command-complete within three seconds | Proven RF power-off is a release blocker; closing the endpoint is not proof. |
| Preserved Android comparison | 12 successful tune/tuner checks: six frequencies × two antenna selections, RSSI/stereo zero | Failed reception is reproducible with the preserved vendor driver; native V4L2 is not the sole explanation. |
| Android FM DSP capture | PCM 0/1, two channels/48 kHz/16-bit, 684,032 frames; six RF checks still zero | DSP PCM path ran; not audible FM acceptance. Mixer route restored Off. |
| Android process calibration | Read and applied the actual 23-byte result; six RF checks still zero | Vendor calibration API sequence did not restore reception. No calibration file saved. |

The zero readings do **not** prove that FM is physically absent, nor that the
remaining bug is only an antenna. Exact FM input wiring/population, firmware
power/calibration state and receiver shutdown must be established. A combo chip's
FM capability and generic downstream Iris driver are insufficient board evidence.
No guessed FM GPIO, RF register write or voltage change has been added to DT.

A first candidate test exposed a control-handler mutex being reused as the
outer ioctl mutex. That diagnostic version was removed by reboot. The current
candidate uses separate control-handler locking and passed the checks above.
A later temporary loss of SSH/ACM was sleep: the owner woke the screen with one
Power press. Measurement runs use a bounded sleep inhibitor, not a permanent
power-policy change.

## Android comparison and recovery

The owner authorized a temporary Android BOOT trial. The preserved Dirty
Unicorns Android 6.0.1 image runs kernel
`3.4.0-cyanogenmod-g6be37d8-00011-gcee6fdf-dirty`; it is not a pristine Samsung
factory release and its exact source is not claimed to match the research
mirror. WCNSS reports the same 1.5.1.2 / CRM 12035159 / 48 MHz XO firmware.
The first enable attempt timed out; a subsequent invocation completed, as did
configuration/tuning/disable ioctls. Neither antenna selection found signal at
87.7, 91.1, 95.7, 102.1, 104.6 or 106.6 MHz.

A temporary `MultiMedia2 Mixer INTERNAL_FM_TX` -> PCM card0/device1 capture
used the existing Android DSP and captured 684,032 frames. Both antenna settings
still gave zero RSSI/stereo at 87.7, 95.7 and 104.6 MHz; the mixer route was
restored Off. The RAM capture tool used AOSP
[TinyALSA android-6.0.1_r1](https://android.googlesource.com/platform/external/tinyalsa/+/android-6.0.1_r1/),
BSD-licensed research code. This does not port or accept native audio. Another
test ran Iris process calibration, retrieved its actual 23 bytes using the old
ARM time32 buffer ABI, and reapplied them through the vendor extended control
before reception: the same six observations stayed zero. No guessed calibration
or saved calibration file was used.

Android's reported regulator settings, L16 **3,000,000 µV** and L24
**1,300,000 µV**, match the native configuration; these are not multimeter
readings. The reference transport source synthesizes a disable response on SMD
close. Android's successful disable ioctl is not proof of a firmware
command-complete packet or physical receiver power-off.

Fresh fastboot reads verified the 524,288-byte protected lk2nd prefix and
9,961,472-byte virtual boot payload against the frozen baseline. Only virtual
`boot` was flashed. After testing, the original payload was restored at offset
524,288 and all **10,485,760 bytes of physical BOOT compared equal** to the fresh
backup. Before/after SHA256:
`f2e67d637182e79193912952f45341ceac4e621aeb7cefab4a8e55a6663192fc`.
No other partition was flashed; normal Android startup mounted its ordinary
filesystems. Native #19, SSH/ACM and Phoc/Phosh returned; trial FM modules and
Android RAM helpers are absent from the restored native system.

These results do not distinguish an unconnected FM input from a firmware/common
initialization issue. Next acceptance needs exact board RF input/population
evidence or a positive controlled RF reference. Another V4L2 frontend rewrite
would not settle that hardware question.

## Reproduce the checks

With the candidate manually built and loaded, use ordinary tools:

```sh
sudo systemd-inhibit --what=sleep --mode=block --why='FM validation' \
    timeout 60 v4l2-compliance -r /dev/radio0
sudo v4l2-ctl -d /dev/radio0 --all --set-freq=104.6 --get-freq --get-tuner
```

Build [the standard-ioctl reception probe](../tools/fm-diag/v4l2-reception.c)
with the project's ARM toolchain and run it under a bounded sleep inhibitor:

```sh
arm-linux-gnueabihf-gcc -O2 -Wall -Wextra -Werror \
    tools/fm-diag/v4l2-reception.c -o v4l2-reception
# On the tablet, with wired headphones inserted:
sudo systemd-inhibit --what=sleep --mode=block --why='FM reception' \
    timeout 120 ./v4l2-reception /dev/radio0
```

It keeps one descriptor open, tries the owner's 29 frequencies, records standard
signal/subchannel/RDS observations, and returns 1 when no candidate signal is
found, 2 on an I/O failure. A positive signal still needs real RDS identification
or another physical station-identification test. Audio routing is outside this
task; it has not been accepted by these tests.

The lower-level [protocol probe](../tools/fm-diag/protocol-probe.py) is restricted
to SM-T531 and an otherwise unowned `APPS_FM` channel. It temporarily uses stock
`rpmsg_char`, attempts receiver disable in cleanup, unbinds and clears the
override. SIGTERM/SIGINT run cleanup. Do not run it alongside the V4L2 candidate,
other FM applications, or with an existing owner. It performs receive/control
operations only; no transmitter commands, firmware restart or calibration writes.

## Research provenance

* [Qualcomm/Samsung radio-iris](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/drivers/media/radio/radio-iris.c)
  and its transport/headers, commit `3fa1853ed5d6c3a8ef5a2fda9822705243bbc256`,
  GPL-2.0: command/event layout, kHz frequencies, calibration sequence and
  eight-byte raw RDS groups. Source evidence; not physical reception acceptance.
* [Qualcomm RPMSG FM transport conversion](https://android.googlesource.com/kernel/msm/+/8bbaf739b6e8c1b095cc6e10c0a850fe2976d8e7%5E%21/),
  2021: establishes the later vendor transport direction; not imported wholesale.
* [Qualcomm FM userspace](https://github.com/LineageOS/android_hardware_qcom_fm/tree/3253b05eba14f36a90058da25627013e354d4f76),
  pinned commit: initialization/calibration research only. The production design
  does not depend on Android properties, `fm_dl` or the JNI/private ioctl ABI.
* [Stock firmware provenance](FIRMWARE.md): current executable segments and NV
  match this tablet's partitions. No replacement firmware was installed for FM.

Evidence states: **VERIFIED_DEVICE** for the bounded observations above;
**VERIFIED_VENDOR_SOURCE** for protocol/source facts and the service-manual
pin labels; **UNKNOWN** for usable board FM population/routing; **HYPOTHESIS**
for unwired FM pins as the cause of no RF.
Implementation state: **BLOCKED**, with an API-tested diagnostic candidate.
