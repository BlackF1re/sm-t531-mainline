#!/usr/bin/env python3
"""Bounded read-only A305B busy-counter sampling with bracketed timestamps."""
import argparse
import json
import mmap
import os
import struct
import time
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('seconds', type=int, choices=range(1, 26))
a = p.parse_args()
if os.geteuid() or b'samsung,matisse3g' not in Path('/proc/device-tree/compatible').read_bytes().split(b'\0'):
    raise SystemExit('Requires root on SM-T531')
active = Path('/sys/bus/platform/devices/fdb00000.gpu/power/runtime_status')
if active.read_text().strip() != 'active':
    raise SystemExit('GPU must already be powered; this tool does not change power state')

def word(regs, offset):
    return struct.unpack_from('<I', regs, offset * 4)[0]

def counter(regs):
    for _ in range(3):
        high = word(regs, 0xed)
        low = word(regs, 0xec)
        if high == word(regs, 0xed):
            return high << 32 | low
    raise RuntimeError('Inconsistent counter read')

with open('/dev/mem', 'rb', buffering=0) as memory, mmap.mmap(
        memory.fileno(), 4096, access=mmap.ACCESS_READ, offset=0xfdb00000) as regs:
    end = time.monotonic() + a.seconds
    previous = None
    while time.monotonic() < end:
        before = time.monotonic()
        value = counter(regs)
        after = time.monotonic()
        stamp = (before + after) / 2
        if previous is not None:
            old_stamp, old_value, old_before, old_after = previous
            if value < old_value:
                raise SystemExit('Counter reset: reject recording')
            print(json.dumps(dict(time=stamp, seconds=stamp-old_stamp,
                gpu_busy_cycles=value-old_value, read_started=before,
                read_finished=after, previous_read_started=old_before,
                previous_read_finished=old_after)))
        previous = stamp, value, before, after
        time.sleep(0.001)
if active.read_text().strip() != 'active':
    raise SystemExit('GPU power changed: reject recording')
