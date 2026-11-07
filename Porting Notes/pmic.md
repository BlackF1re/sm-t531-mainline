# PM8226 PMIC and board supplies

* PM8226 communicates over SPMI; RPM controls shared regulator votes. PON/RESIN
  and PS_HOLD participate in reset/shutdown. Native core/storage/display supply
  paths operate, but not every peripheral sequence is accepted.
* Rails/enables must follow the actual board DT and consumer ownership. L5
  display power is retained during current bring-up; separate TC358764 supply
  ownership is unresolved. Do not assign guessed regulators to untraced pins.
* An enabled rail, a requested voltage or a successful SCM call is not an
  independent voltage/power measurement. Keep active and sleep resource votes
  distinct; do not manipulate genpd reference counts to simulate sleep.

Evidence: [Android probe data](../docs/android-hardware-observation-20261022.json), [pinned board sources](../docs/hardware-source-manifest.json). `config/kernel.fragment`, `patches/linux/0134*`, `0135*`, `0138*`.
