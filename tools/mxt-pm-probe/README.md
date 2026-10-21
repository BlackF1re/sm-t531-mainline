# SM-T531 maXTouch PM diagnostic

This one-shot module calls the bound `4-004a` maXTouch driver's system-sleep
callbacks with the rest of the system awake. It does not install hooks, change
firmware, enter global suspend, or replace the production driver. Loading it
briefly stops/restarts touch scanning and adds the usual out-of-tree kernel
taint. It is diagnostic code, not a production sleep implementation.

Build against the exact running kernel output:

```sh
make -C .work/linux O="$PWD/.work/out" ARCH=arm \
    CROSS_COMPILE=arm-linux-gnueabihf- M="$PWD/tools/mxt-pm-probe" modules
```

The test in [TOUCH-SLEEP.md](../../docs/TOUCH-SLEEP.md) exclusively grabbed
the touch evdev node, asserted slot 15 tracking ID 30000 using evdev writes,
cleared `BTN_TOUCH` to model input-core suspend, loaded this module, and read
`EVIOCGMTSLOTS(ABS_MT_TRACKING_ID)` after 0.5 seconds. The tracking ID remained
30000. A `finally` block released that slot and `BTN_TOUCH`, restored slot 0,
unloaded the module, and dropped the grab. All slots were then verified -1.

Run this only with no real contacts active, with guaranteed cleanup of any
synthetic contact. The module alone does not inject or release contacts.
Do not mistake this targeted callback test for full system suspend testing.

`check.py MODULE --cycles 10` automates the regression with three synthetic
contacts and cleanup on failure. Run it as root on the tablet with the module
built for the running kernel. It refuses to start if a real contact is active.
Use a temporary sleep inhibitor for callback tests so automatic idle suspend
does not interfere. It prints JSON evidence and unloads the module each cycle.

`check.py MODULE --cycles 3 --system-sleep` exercises full system sleep through
logind. It arms a 10-second RTC alarm, calls `systemctl suspend`, and waits for
the kernel success counter to advance and logind preparation to finish. It
checks the failure counter as well. Run it as a transient system service with
output saved to a file, so Wi-Fi disconnection cannot kill the test. This mode
does not load MODULE. Existing RTC alarms are protected; the test alarm is
cleared afterward. Do not use direct `rtcwake -m mem` to bypass the configured
systemd sleep policy and compositor preparation.
