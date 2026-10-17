# SM-T531 LP8556 brightness range investigation

Root cause identified in Phosh, 2026-10-17. Reported physical symptom: approximately the lower
half of the Phosh slider appears unchanged at minimum brightness, and the
upper end appears dimmer than expected. Full physical range acceptance is
outstanding. No slider-range workaround or LED-current increase is justified
by the evidence below.

## Hardware and Samsung configuration

VERIFIED_VENDOR_SOURCE: Samsung/Lineage kernel commit
`3fa1853ed5d6c3a8ef5a2fda9822705243bbc256`, GPL-2.0:

* [LP8556 configuration](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/drivers/video/msm/mdss/LP8556-backlight.c)
  selects the TC358764 Matisse configuration: register01=80 (external PWM),
  A5=24 (four phase/channel outputs), A0=44, A1=6c. The Matisse ATT-specific
  A7=cb override does not apply to Matisse3G.
* [Panel brightness constants](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/drivers/video/msm/mdss/mdss_samsung_dsi_panel_msm8x26.h)
  and [panel conversion](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/drivers/video/msm/mdss/mdss_tc358764_dsi2lvds.c)
  map Android brightness20→PWM1,30→3,143→45,255→105 for this variant.
* [GP0 PWM programming](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/drivers/video/msm/mdss/mdss_msm_gpio_pwm.c)
  uses M=1,N=127,D=2*level. Thus the final 105 is a PWM count, not an
  LP8556 brightness-register ceiling. Copying 105 into register max_brightness
  would confuse distinct units. The nominal vendor maximum duty is105/127.

The local common DTS retains A0=44,A1=6c,A5=24. Board patch0036 changes the
input source to register-only control01=85 and removes the unused GP0 PWM.
Driver patch0033 gates BL_CTL at zero; patch0037 reads back actual BRT/BL_CTL.

VERIFIED_UPSTREAM: TI [LP8556 datasheet SNVS871M](https://www.ti.com/lit/ds/symlink/lp8556.pdf)
(revision June2020, sections8.3.2 and8.6): register00 is8-bit linear
brightness; Device Control BRT_MODE=10 selects register brightness alone.
The maximum-current configuration is independent of BRT. A1=6c,A0=44
selects30mA*0xc44/4095≈23.0mA per active sink with ISET_EN=0. CFG5=24
selects four output phases. These are existing Samsung values, not proposed
increases. No evidence permits a higher sink current.

## Read-only device observations

VERIFIED_DEVICE: on kernel7.2.9-dirty/#5, one backlight exists:
`/sys/class/backlight/lcd-backlight`, max255,typeplatform,scaleunknown,
control mode register based. Initial requested/actual brightness was9/255;
bl_power0. Live DT has dev-ctrl85 and ROM valuesA0=44,A1=6c,A5=24.
A read-only I2C combined register-address/read transaction during the
independently coordinated display-power test returned:

```
00=20 01=85 02=38 04=00 16=3f 98=9a 9e=21
A0=44 A1=6c A2=28 A3=02 A4=72 A5=24 A6=40 A7=f7
A8=24 A9=c0 AA=0f AB=00 AC=00 AD=00 AE=0e AF=02
```

BRT20hex corresponds to the coordinator setting32decimal; the initial9
and later32 are separate observations, not a register/sysfs mismatch.
Status02=38 has VREF_OK,VBOOST_OK and a latched OVP event. Datasheet section
8.6.1.3 says reading02 clears OVP/OCP/TSD/UVLO history; the read is therefore
recorded explicitly. A latched event alone does not establish a persistent
fault, its timing, or a brightness cap. Repeat status after a controlled
sweep is needed. No brightness, GPIO, clock, PWM or power mutation was
performed by this investigation at this point.

SensorProxy reports HasAmbientLight=false,LightLevel=0lux; no IIO light
sensor is exposed. The GNOME ambient-enabled preference is true and the
saved auto-brightness-offset is0.5. Initially we inferred that the absent
sensor would prevent effective auto brightness. The actual GTK slider test
below disproves that inference: Phosh still enables automatic brightness
after an unblank claims the nonexistent sensor. Night-light-enabled isfalse.

## Phosh transfer function

VERIFIED_UPSTREAM: the pinned [Phosh0.58.0 release](https://sources.phosh.mobi/releases/phosh/phosh-0.58.0.tar.xz) source already
retained in `.work/phosh/phosh-0.58.0` (`src/backlight.c`,
`src/backlight-sysfs.c`, `src/brightness-manager.c`) treats both unknown and
linear backlight scales as linear hardware, then applies a perceptual
logarithmic mapping in userspace. Its minimum ismax(1,255/100)=2; the
manual-slider fractionp maps to `round(2*(255/2)^p)`:

| Manual slider | Expected LP8556 BRT | Fraction of full-scale BRT |
| --- | --- | --- |
| 0% | 2 | 0.8% |
| 25% | 7 | 2.7% |
| 50% | 23 | 9.0% |
| 75% | 76 | 29.8% |
| 100% | 255 | 100% |

This is the expected manual transfer function. It does not match the
observed live slider values below; automatic-offset mode is the actual
cause of the compressed range. Changing the kernel scale to non-linear would falsely
advertise the hardware and merely bypass that userspace curve. Changing the
LP8556 current or remapping the GUI slider without physical evidence would
mask the reported problem.

## Controlled hardware register sweep

VERIFIED_DEVICE,2026-10-17: after the coordinator completed display-power
cycles on the persistent0116 image, an exclusive18-step direct sysfs sweep
covered2,4,8,16,23,32,64,96,128,160,192,224,255,192,128,64,23,2. Each step
settled for600ms, then read requested brightness, actual brightness, power,
I2C BRT,BL_CTL,status andA0-A5. Every requested level matched both sysfs
readbacks and the actual LP8556 BRT register; CTRL stayed85,power0 and all
six configuration registers stayed unchanged. This includes the full255
endpoint, so no numerical kernel clamp was observed.

First status38 records a historical OVP event after the preceding DPMS
cycles; all subsequent17 status reads were30 (VREF_OK,VBOOST_OK,no fault),
including maximum brightness. The original requested37 was restored and
verified as37 in sysfs,actual and BRT,withCTRL85,power0. Kernel build is
`#5 SMP Sat Oct 17 01:02:17 +07 2026`; Phosh package is0.58.0-1~t5312.
Full machine-readable evidence is in [backlight-range-results.json](backlight-range-results.json).
The executed diagnostic script is retained in
[tools/test-backlight-range.py](../tools/test-backlight-range.py).

Register-path testPASS is not physical brightness acceptance.

## Actual GTK slider reproduces the defect

VERIFIED_DEVICE: after unlocking the existing session, the active Phosh
GTK brightness GtkScale was located through its AT-SPI accessible ancestry:
Phosh panel → brightness row → GtkScale,adjacent to Brightness Settings.
Its range is0..1,increment0.01. Setting its actual CurrentValue through
AT-SPI exercises the same GtkAdjustment value-changed handler used by touch;
no direct backlight write was used for this endpoint test.

| GTK slider | Requested/actual LP8556 brightness before fix |
| --- | --- |
| 0% | 2 |
| 25% | 2 |
| 50% | 3 |
| 75% | 11 |
| 100% | 37 |

This exactly matches automatic brightness at zero lux: Phosh's bucket
algorithm selects relative base0.1, and the slider adds an offsetp-0.5.
Thus the first40% clamps to minimum; its maximum is relative0.6 and maps
to37/255. This accounts for both reported symptoms without a hardware clamp.

A first restore attempt assumed manual mode and set the logarithmic
fraction for37,which produced5 because auto-offset mode was active. The
restore was immediately corrected through the original GtkScale value1.0;
requested and actual brightness37 were verified again, and the original
saved auto offset0.5 was restored. Both attempts remain in the evidence.

VERIFIED_UPSTREAM: `src/ambient.c:maybe_claim` does not test HasAmbientLight,
and `on_shell_state_changed` calls it on unblank. A successful ClaimLight
reply enables auto brightness solely from the claim counter and preference.
HasAmbientLight=false hides the auto toggle while the effective offset mode
can remain enabled. A successful claim is a subscription result, not proof
of populated hardware. This is confirmed by the installed iio-sensor-proxy
3.7-3 and its upstream [3.7 source](https://gitlab.freedesktop.org/hadess/iio-sensor-proxy/-/blob/3.7/src/iio-sensor-proxy.c#L497):
`handle_generic_method_call` records the client and explicitly returns
success when no driver for the requested sensor type exists. The retrieved
source is GPL-3.0 and its SHA256 is
`cd6564675eb4f60cf4602e49f36d2fdd4fc80d6cf8ab2234636eee02ce4f9c32`.
This is expected SensorProxy behavior, not an ALS hardware-driver failure. This is a Phosh availability/state defect.

Patch [0002](../patches/phosh/0002-ambient-require-available-light-sensor.patch)
requires an actual available sensor and an unblanked display, disables auto
mode immediately when availability disappears, releases the subscription,
and reconciles changes after serialized asynchronous claim/release replies.
It preserves the legitimate manual logarithmic curve and valid ALS behavior.
Kernel patch0117 is not required. The post-install GTK endpoint and unblank
checks below pass on the existing graphics kernel.

The Linux [backlight scale ABI](https://kernel.googlesource.com/pub/scm/linux/kernel/git/torvalds/linux/+/master/Documentation/ABI/testing/sysfs-class-backlight)
explicitly directs controls to apply logarithmic mapping to linear hardware.
GSD's udev backlight backend uses arithmetic percentages instead; that
policy difference is not evidence that Phosh's manual curve is defective.

## Regression tests and packaging

The new focused `test-ambient` target compiles the actual ambient state
machine with delayed successful D-Bus replies. Four cases pass in the ARM
build root: no sensor/no claim, normal sensor lifecycle, disappearance while
a claim is pending, and reappearance while a release is pending. The same
no-sensor test against the original implementation aborts on duplicate
invalid ClaimLight calls. The patched implementation passes again after the
negative control. The test needs GNOME settings-daemon-common schemas in the
build root; this dependency is included in the build script.

Reproduction commands (in `.work/phosh/rootfs`):

```
cd /build-phosh
meson configure obj-arm-linux-gnueabihf -Dtests=true
ninja -C obj-arm-linux-gnueabihf tests/test-ambient
meson test -C obj-arm-linux-gnueabihf --no-rebuild --print-errorlogs ambient
```

The production packaging build uses `-Dtests=false` after this focused test.
`build-phosh.sh` and `install-phosh.sh` select version0.58.0-1~t5313.
The actual GTK endpoint check is automated in
[tools/test-phosh-brightness.py](../tools/test-phosh-brightness.py), run as
the desktop user with its session bus environment and `--expect-manual`.
It changes physical brightness briefly, requires coordinated exclusive
display ownership, and restores the original GUI value and raw brightness.

## Device verification after package installation

VERIFIED_DEVICE: the coordinator installed the four rebuilt t5313 packages
without package removals. `dpkg --audit` and `apt-get check` passed. The old
t5312 packages are retained in a private on-device rollback directory.
Phosh was restarted while retaining kernel#5/MSM0116 so the software fix
was tested independently of the subsequent battery-kernel work.

The actual GTK brightness slider was discovered again through AT-SPI and
exercised at0/25/50/75/100%. Requested sysfs brightness, actual_brightness,
and direct LP8556 BRT readbacks all matched2/7/23/76/255 respectively;
CTRL remained85. Maximum now reaches register255. The first status read38
was a latched prior OVP event; subsequent reads, including maximum, were30
with no fault bits. No LED-current, ROM, PWM or kernel-scale change occurred.
The existing manual logarithmic curve is preserved.

The script captured GUI value1.0/raw255 after unlock and restored that value
at completion. We then explicitly restored the pre-test level37 through the
actual GTK control. A coordinated normal Phosh DPMS cycle verified:

| State | Requested | Actual | bl_power |
| --- | --- | --- | --- |
| Before | 37 | 37 | 0 |
| Off | 37 | 0 | 4 |
| On | 37 | 37 | 0 |

A seven-second system D-Bus monitor spanning this cycle recorded zero
ClaimLight method calls while the ambient-enabled preference remainedtrue
and HasAmbientLight remainedfalse. Thus unblank no longer activates the
absent-sensor automatic-offset mode. Final requested/actual brightness37
and power0 were restored before handing the display back to the coordinator.

`tools/test-phosh-brightness.py --expect-manual --read-i2c` reproduces the
five endpoint checks using the desktop user's session D-Bus environment.
The optional I2C reads use passwordless sudo and explicitly clear latched
LP8556 status history. Both GUI and DPMS results are recorded in
[backlight-range-results.json](backlight-range-results.json).

The software regression and full register range are verified. Physical
optical brightness/comfort acceptance is still UNKNOWN: no lux meter or
owner observation of this specific post-fix sweep was recorded. A later
kernel boot should repeat the same GUI test before combining acceptance
with unrelated kernel changes.


VERIFIED_DEVICE after the persistent kernel0118–0121 boot: the serialized
GUI/register test again returns2/7/23/76/255 and restores its initial255.
An earlier overlapping DPMS/brightness run is invalid for manual brightness
acceptance; it correctly observed actual0 while display power was off.
The successful repeat runs after the power-cycle process has completed.
