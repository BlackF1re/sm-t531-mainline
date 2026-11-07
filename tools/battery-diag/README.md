# Read-only PM8226 battery diagnostic

This SM-T531-only module takes two bounded snapshots, two seconds apart,
using the existing SPMI PMIC regmap. It refuses an unexpected board or BMS
peripheral type and performs no register writes. Multi-byte samples are
unlocked and can tear; compare repeated snapshots before interpreting them.

Build against the exact running kernel's configured output and symbols:

```sh
make -C .work/out M="$PWD/tools/battery-diag" \
    ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- modules
```

The lead engineer coordinates device mutations and loads the resulting
`t531_battery_diag.ko`, collects `dmesg` lines matching `t531-battery`, then
unloads it. Do not load it while another driver is modifying those peripheral
registers. The PM8226 register allowlist and source commit are in the C file.
See [battery evidence](../../Porting%20Notes/battery.md) for interpretation and limits.
