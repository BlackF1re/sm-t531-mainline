# APSS watchdog

* Native `qcom_wdt` probed, feeding/stopping worked. Actual expiry did not
  reliably reset/recover Linux and the observed counter rate depended on load.
* Reset routing/clock behavior and subsequent recoverable boot remain blocked.
  No production hardware-watchdog recovery guarantee is established.
* Probe/feed logs are insufficient acceptance. An expiry test can require
  physical recovery; do not rely on a userspace rollback timer after a kernel
  wedge or repeat reset tests without an approved recovery plan.
