Temporary recovery for the old SM-T531 DT (kernel #9 and earlier).

The old DT described WLAN DXE IRQs as rising-edge; driver startup changed
both to level-high. Unbinding left those mappings incompatible with the DT.
This helper resets only the two unbound WLAN mappings to the DT expectation.
It rejects another board, a bound device, and a DT already fixed to level-high.
It has no firmware access and must never be installed as a boot service.

Build with the matching kernel output:

```sh
make -C .work/linux O="$PWD/.work/out" ARCH=arm \
 CROSS_COMPILE=arm-linux-gnueabihf- M="$PWD/tools/wifi-irq-rearm" modules
```

`insmod t531_wifi_irq_rearm.ko` reports matching IRQs without changing them.
Only after unbinding WLAN, `insmod ... apply=1` performs the targeted reset;
unload the helper before rebinding the driver. Kernel #10/patch0124 removes
the need for this helper. Rebinding Wi-Fi drops its network connection, so
keep the working USB console and a timed rollback available.
