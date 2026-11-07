# PM8226 IADC

* User-IADC type/subtype0x3604/5=08/03; BMS-IADC0x3804/5=08/05. Gain channel3,
  offset6/5; BMS external-sense selection1. These current channels are separate
  from VADC voltage sampling.
* Patch0119 fixes negative-sample subtraction wrapping in u16 and missing
  ×1,000,000 in µV/µΩ→µA. Read-only calibscale3291/(gain_raw−offset_raw)
  corrects the measured gain; the ordinary IIO0.001scale expresses mA.
* BMS uses averaged/cached current while user-IADC reads direct conversions.
  Timing and magnitude disagreement remain externally uncalibrated; do not
  infer polarity only from a channel label or equate USB input and cell current.

Evidence: `patches/linux/0119-iio-qcom-spmi-iadc-signed-current-calibration.patch`,
[load response](../docs/battery-results.json), `tools/check-battery-model.py`.
