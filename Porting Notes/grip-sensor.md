# Semtech SX9500 grip / SAR

* Confirmed SX9500 at I²C`0x28`: GPIO0/1 SDA/SCL, falling-edge IRQ GPIO66.
  Matisse uses PM8226L15=2.8V and LVS1; the vendor variable named L19 actually
  selects L15 for `CONFIG_SEC_MATISSE_PROJECT`. Main electrode CS0, reference CS1.
* Native `sx9500` IIO driver exports four `in_proximityN_raw` channels,
  sampling frequency, triggered buffer and threshold-event enables.
  `CONFIG_SX9500=m`; patches0149–0151 add supplies, power sequencing and board DT.
* Short live trial: four raw channels read successfully,336conversion IRQs;
  CS0 ranged2088–2992 during the requested handling test. No threshold events
  were recorded; grip/release thresholds and modem SAR policy remain unaccepted.
* The live overlay needed a temporary rail alias because existing L15 lacked
  a phandle. A diagnostic helper caused an Oops by passing NULL to the alias
  registration API; this helper is excluded from the patch series. Clean-boot
  acceptance of the normal DT/module is still pending; do not claim VERIFIED.
* GPIO66 is also named by the generic audio AUXPCM DOUT description; keep
  ownership exclusive. No reset GPIO is established; the chip uses soft reset.

Sources: pinned vendor `drivers/sensors/sx9500.c` and `sx9500_reg.h`, commit
`3fa1853ed5d6c3a8ef5a2fda9822705243bbc256`; upstream `drivers/iio/proximity/sx9500.c`.
