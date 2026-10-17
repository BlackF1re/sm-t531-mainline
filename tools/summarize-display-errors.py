#!/usr/bin/env python3
"""Report logged MDP5 underruns in the recording window (rate-limited)."""
import argparse
import json
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("start_uptime", type=Path)
parser.add_argument("kernel_log", type=Path)
args = parser.parse_args()
start = float(args.start_uptime.read_text())
underruns = []
for line in args.kernel_log.read_text().splitlines():
    stamp = re.match(r"\[\s*([0-9.]+)\]", line)
    if not stamp or float(stamp[1]) < start:
        continue
    error = re.search(r"mdp5_irq_error_handler.*errors: ([0-9a-fA-F]+)", line)
    if error and int(error[1], 16) & 0x55000000:
        underruns.append({"uptime": float(stamp[1]), "irq_status": error[1]})
print(json.dumps({
    "logged_mdp5_underruns": len(underruns),
    "events": underruns,
    "display_integrity": "FAILED_UNDERRUN" if underruns else "NO_LOGGED_UNDERRUN",
    "limitation": "Kernel logging is rate-limited; counts are lower bounds and zero is not physical acceptance.",
}, indent=2))
