#!/usr/bin/env python3
"""Exercise the actual Plasma Mobile drawer; emit settled-state evidence."""
import json
import subprocess
import time

for cycle in range(4):
    for action, expected in (("openActionDrawer", "true"), ("closeActionDrawer", "false")):
        start = time.monotonic()
        subprocess.run(["qdbus6", "org.kde.plasmashell", "/Mobile", action], check=True)
        time.sleep(1.5)
        observed = subprocess.check_output(
            ["qdbus6", "org.kde.plasmashell", "/Mobile", "isActionDrawerOpen"], text=True).strip()
        print(json.dumps({"cycle": cycle, "action": action, "start": start,
                          "settled": time.monotonic(), "expected": expected,
                          "observed": observed}), flush=True)
        if observed != expected:
            raise SystemExit("Drawer did not reach the requested state")
