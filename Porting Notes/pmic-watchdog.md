# PM8226 PON watchdog

* A `pm8916_wdt`-based candidate could feed and read back registers, but actual
  expiry failed to reset the tablet; the candidate was rolled back.
* PM8226 secure clock/reset semantics remain unresolved. The candidate is not
  production policy and must not be counted as accepted hard-hang recovery.
* Real expiry, reset reason and a recoverable boot are required acceptance;
  register access alone does not meet it. Preserve physical recovery access.
