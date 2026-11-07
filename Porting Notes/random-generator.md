# Qualcomm PRNG

* Device-probed PRNG at `0xf9bff000`. The driver explicitly reports TRNG support
  not detected; `rng_available` was empty.
* The pinned upstream `qcom-rng.c` distinguishes `qcom,prng` with
  `hwrng_support=false`. Do not expose this as a proven physical entropy source
  or infer successful randomness delivery merely from a bound driver.

Evidence: [device observation](../docs/hardware-observation-20261022.json),
Linux v7.2.9 `drivers/crypto/qcom-rng.c` (base `5fce161649b4`).
