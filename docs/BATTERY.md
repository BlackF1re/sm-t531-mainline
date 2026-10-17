# SM-T531 battery and charge reporting

Checked 2026-10-17. Implementation is bring-up, not a validated fuel gauge.
The charging policy and SMB358 charge limits are separate and unchanged.

`VERIFIED_DEVICE`: the original kernel `cpuinfo` reports board `Revision:
0003`, while its DT model is `[MATISSE-3G-OPEN] Rev-02-MTP-v2`. The DT model
is not proof of `system_rev == 2`. Raw device evidence is private and excluded
from Git. The original ROM config enables both `MACH_MATISSE3G_OPEN` and
`SEC_MATISSEWIFI_COMMON`; that does not make this tablet a Wi-Fi-only board.

`VERIFIED_VENDOR_SOURCE`: Samsung's pinned [MSM8226 kernel](https://github.com/LineageOS/android_kernel_samsung_msm8226/tree/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256)
uses the PM8226 BMS, an external current sense resistor and a separate SMB358
charger. The fuel gauge is not an I2C MAX170xx, and PM8916 voltage-mode BMS is
different hardware. The board's `battery,fuelgauge_name = "bms"` and enabled
`pm8226_bms` are in [matisse3g-r02.dtsi](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/boot/dts/msm8226-sec-matisse3g-r02.dtsi).

`VERIFIED_DEVICE`: before patch 0118, only `smb358-usb` existed under
`/sys/class/power_supply`. UPower 1.90.9 detected external power, but its
DisplayDevice was `unknown`, `battery-missing-symbolic`, `percentage: 0%`.
That was missing telemetry, not a measured empty battery.

The read-only `tools/battery-diag` module checks the exact board and PM8226
BMS1 type/subtype before reading a bounded register allowlist. Root loaded it,
collected two snapshots 2 seconds apart, and unloaded it without writes.
`VERIFIED_DEVICE` observations:

| Register | Meaning | Observed value |
|---|---|---|
| `0x1208` | Battery presence | `0x83`, bit7 set |
| `0x3604/5` | User IADC type/subtype | `0x08/0x03` |
| `0x3804/5` | BMS IADC type/subtype | `0x08/0x05` |
| `0x3848` | BMS sense channel | `1`, external resistor |
| `0x4004/5` | BMS type/subtype | `0x0d/0x01`, BMS1 |
| `0x4040/42/43/46` | Mode/hold/clear/enable | `0x40/0/0/0x80` |
| `0x4090` | OCV for SOC, little endian | `0x9a1c` |
| `0x4098` | Signed average sense voltage code | `20` |
| `0x409e` | Average battery voltage code | `0x9a30` |
| `0x408a` | Signed36 main counter | Changing across samples |
| `0x40a8` | Signed36 shadow counter | Different accumulator, changing |

The direct VADC raw channels also work: VBAT `39467`, reference625 `31125`,
reference1250 `37508` in one sample. These are ADC codes, not millivolts.

Patch 0118 registers `pm8226-bms` as a Battery in the standard `power_supply`
class. It exports presence, status from its declared SMB358 supplier,
`voltage_now`, `voltage_ocv` and `temp`, plus standard battery design metadata.
VBAT is read from VADC and uses measured 625/1250 mV reference codes and the
1:3 prescaler. BMS OCV uses the same raw coding and reference calibration:
this follows `calib_vadc()`, `adjust_vbatt_reading()` and
`convert_vbatt_raw_to_uv()` in the exact vendor driver, rather than assuming
that a register code is already a voltage. A freezable 30-second notification
work item stops during system sleep; charger events notify immediately.
This first stage writes no BMS/charger configuration registers.

Patch 0119 fixes two bugs in upstream `qcom-spmi-iadc.c`: negative sample
subtraction wrapped in `u16`, and microvolts divided by micro-ohms omitted the
factor of one million required for microamps. The IIO ABI's 0.001 scale then
converts microamps to milliamps. It exposes the measured gain correction
`3291 / (gain_raw - offset_raw)` through read-only `calibscale` for BMS use.
The ordinary driver calibrates gain channel3 and offset channels6/5 at probe;
it does not reset or configure BMS1 or SMB358.

Patch 0120 takes a mutex-protected snapshot of BMS OCV, main counter and
average sense voltage. It holds only `0x4042` bit0, waits 100 microseconds (more than two sleep
clock cycles) and restores the previous bit on every exit, including failures.
It never clears counters, rewrites OCV or changes charging. The main counter
tracks charge since the last accepted OCV; the shadow accumulator is not
interchangeable. Signed36 wrap is accumulated in software between snapshots.
Voltage references and measured IADC gain correct the conversion. Samsung's
unchanged 31-by-5 OCV table is converted into `simple-battery` properties in a
separate GPL-2.0-only DTS include retaining Samsung's copyright. Capacity
starts from measured OCV and subtracts measured discharge coulombs; charge
and current use microamp-hours and microamps in `power_supply`. Positive
current means charging. No fixed percentage or supplier-online-to-100% rule
is used.

The register/conversion source is [qpnp-bms.c](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/drivers/power/qpnp-bms.c);
ADC calibration is documented by [qpnp-adc-current.c](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/drivers/hwmon/qpnp-adc-current.c).
Both are Qualcomm GPL-2.0-only. Battery characterization is Samsung's
[6800mAh profile](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/mach-msm/bms-batterydata-samsung-6800mah.c),
also GPL-2.0-only. The source was retrieved on 2026-10-17. Its nominal capacity
and 123 mOhm resistance characterize this board's cell family, not cell ageing.

`HISTORICAL_SOURCE`: Craig Tatlor's [2018 v7 proposal and maintainer review](https://lkml.indiana.edu/hypermail/linux/kernel/1809.2/00131.html)
cover PM8941 BMS. The series is absent from the pinned Linux 7.2.9 tree;
a 2026-10-17 search found no later authoritative revision. It is research,
not an applied upstream series. Its raw-OCV conversion, shadow-counter use,
clear-register offset and calibration cannot be reused blindly for PM8226.

Known model and validation limits:

- The exact pinned `MACH_MATISSE3G_OPEN` branch selects 13.5 mOhm for board
  revision<=2 and 12.2 mOhm for revision>2. Revision3 justifies 12.2 mOhm here.
  The historical installed ROM log instead implies 12.5 mOhm from its
  `vsense_uv/current_ua` pairs. This is a 2.4% current/coulomb calibration
  discrepancy; independent current measurement remains required.
- `charge_full_design = 6800000` is nominal design data. The algorithm does
  not learn remaining full capacity of an old cell. Samsung also provides
  temperature-dependent FCC/resistance tables; only the standard OCV tables
  are currently used. The standard helper selects the nearest temperature
  table. Full-cycle SOC accuracy and runtime estimates remain unverified.
- PMIC temperature compensation and voltage trim compensation used by the
  Android driver are not fully implemented by the upstream ADC drivers.
  Do not call current or voltage precision externally calibrated.
- A warm boot or replaced battery can leave stale initial OCV. First stage
  exposes hardware OCV; the model needs cold-boot/rest/recharge validation.
  No persisted Android SOC or fabricated replacement OCV is used.
- Restore of a hold bit can itself fail on an SPMI bus error. The driver
  propagates that failure; hardware error recovery still needs testing.
- A changing charge reading and UPower recognition prove export, not gauge
  accuracy, battery health, safe termination/recharge or suspend charging.

Acceptance sequence: boot with the new DT and drivers; collect `uevent`,
`upower -d`, thermistor and ADC data; verify held-register state returns to 0;
confirm readings change with load; unplug power and verify discharging/current
sign and decreasing charge; recharge and verify sign/status and charge increase;
validate cold boot and repeated suspend/resume. Record a controlled discharge
and recharge against an external current/voltage reference before marking the
model `VERIFIED`. Physical cable changes are coordinated by the lead agent.

`tools/check-battery-model.py` extracts the actual driver conversion, snapshot,
model and IADC functions plus upstream battery-table helpers into a standalone
harness with mocked I/O. It compares every one of the 155 table points against
the pinned vendor source, checks signed current at negative/positive/extreme
ADC codes against a dimensional reference, and checks CC36 near both limits
against arbitrary-precision rational conversion. It exercises both wrap
boundaries in the actual model function, charge/discharge direction, invalid
voltage references and injected snapshot I/O failures including hold restore.
On 2026-10-17 it passed host UBSan/signed-overflow checks and an ARMv7 static
binary under qemu-arm. These are software checks, not physical gauge accuracy.

```sh
./tools/check-battery-model.py
```

Device trial of kernel #7 through patch 0120 on 2026-10-17: `VERIFIED_DEVICE`
standard export and UPower recognition. `pm8226-bms` reported battery present,
Li-ion, live voltage 4.23–4.31V, retained OCV 4.363V, temperature 25.4–25.7C,
changing signed current and charge near 6.797Ah. UPower created a rechargeable
Battery and DisplayDevice, showed 100%, and transitioned from discharging to
charging while external power remained online. The 100% comes from the hardware
OCV/profile plus counted charge, not a fixed or supplier-online value. This
proves export and observed update, not full-cycle percentage accuracy. Retained
OCV was about 23 mV above the programmed 4.34 V limit: stale OCV is one possibility,
and absent PMIC voltage trim compensation another; neither is established.

The trial also exposed an upstream core metadata bug: battery-info stores
limits in whole Celsius but `power_supply_battery_info_get_prop()` returned
those directly for the deci-Celsius ABI, producing `temp_max=60` and
`temp_min=-5`. Patch 0121 changes only the six getter conversions to multiply
by 10, preserving all internal battery-info units and charger policy. The
existing `has_prop` guard rejects undefined `INT_MIN` minima and `INT_MAX`
maxima before multiplication. The current [upstream core at 58161ead29e5](https://github.com/torvalds/linux/blob/58161ead29e50d70a317ea26b472e0c7508e69da/drivers/power/supply/power_supply_core.c)
still contained the bug when checked 2026-10-17. The [standard ABI uses tenths
of Celsius](https://docs.kernel.org/power/power_supply_class.html#units).
`tools/check-battery-temperature.py` compiles the actual getter and has_prop
guard, verifies all six conversions and rejects all six undefined sentinels
without changing fields or overflowing. Host UBSan and ARM/qemu checks pass.

```sh
./tools/check-battery-temperature.py
```

`VERIFIED_DEVICE`: a read-only 1 Hz sampler observed a root-controlled FD305
pixel workload between monotonic 220.4988 and 231.7052 s. It completed all 12
cases with no graphics fault. The battery response was coherent:

| Interval | Mean BMS current | Mean live voltage | Counted charge |
|---|---|---|---|
| Before load, 28 samples | +18.5mA | 4.344V | 6797411→6797572uAh |
| GPU active, 11 samples | −33.7mA | 4.306V | 6797568→6797435uAh |
| After load, 19 samples | +18.0mA | 4.349V | 6797435→6797694uAh |

All 11 samples during the load had negative battery current; charge decreased
by 133 uAh and increased again after load. The separate user IADC averaged
−50.0mA during load. Its raw sign on this board follows charge-positive in
this observation; do not assume raw IADC polarity from a label. BMS current
has a 2-second cache and hardware averaging, while user IADC reads are direct
conversions. Magnitude and latency disagreement remain to be calibrated.
No charger settings or cable state changed for this test. Results are in
ignored `battery-0120-synchronized-current.tsv` and
`battery-0120-current-step-summary.json`. This verifies changing system
interfaces and load response, not coulomb-counter precision or full-cycle SOC.


## Installed device result

VERIFIED_DEVICE: the complete0118–0121 set is installed on SD in kernel
`#8 SMP Sat Oct17 15:07:43 +07 2026`. Container SHA256 is
`9d76269c14fb76cc9e171044532c417df3d78f43301a3fc57c1aba3ea00e7d92`.
A subsequent ordinary boot runs that kernel with native Phoc/Phosh and the
unchanged0116 MSM module. UPower now enumerates battery_pm8226_bms and its
DisplayDevice as a real present battery instead of missing/0%.

The persistent-boot sample exports voltage4275387uV, current-34836uA,
charge6796259uAh, capacity100% and temperature256 (25.6C). These are one
changing sample, not fixed outputs. Nominal charge_full_design is6800000uAh;
no learned full capacity or measured cell health is claimed. Temperature
limits are correctly exported as-50/600 and alert maximum450 in deci-Celsius.
Kernel logs contain no new graphics fault, and a normal display-power cycle
reports no logged underrun. Optical image/touch acceptance remains separate.

The old SD kernel and MSM pair, plus modules.builtin, modules.builtin.modinfo
and modules.order, are checksummed in /var/lib/t531/kernel-trial-backup.
The explicit trial helper --rollback restores those files before the next
reboot and regenerates module dependencies. Its automatic trial service is
disabled after promotion. Internal boot/lk2nd and charger policy are unchanged.
