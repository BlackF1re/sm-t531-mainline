#!/usr/bin/env python3
"""Read only the Samsung-documented CPU/MMSS QoS registers on SM-T531."""
import json
import mmap
import os
from pathlib import Path
import struct

if os.geteuid() or Path('/proc/device-tree/compatible').read_bytes().split(b'\0')[0] != b'samsung,matisse3g':
    raise SystemExit('Requires root on SM-T531')
result = {}
with open('/dev/mem', 'rb', buffering=0) as memory:
    # These are always-on fabric configuration registers, not GPU/DSI PLLs.
    with mmap.mmap(memory.fileno(), 4096, access=mmap.ACCESS_READ, offset=0xfc47b000) as regs:
        result['mmss_noc'] = {
            name: {key: struct.unpack_from('<I', regs, port * 0x80 + offset)[0]
                   for key, offset in [('priority', 8), ('mode', 12), ('bandwidth', 16), ('saturation', 20)]}
            for name, port in [('mdp', 1), ('gpu', 2)]
        }
    result['bimc'] = {}
    for name, port in [('cpu', 0), ('mmss', 2)]:
        with mmap.mmap(memory.fileno(), 4096, access=mmap.ACCESS_READ,
                       offset=0xfc388000 + port * 0x4000) as regs:
            result['bimc'][name] = {
                key: struct.unpack_from('<I', regs, offset)[0]
                for key, offset in [('mode', 0x210), ('priority_override', 0x230),
                                    ('read_override', 0x240), ('write_override', 0x250),
                                    ('bke_enable', 0x300), ('bke_grant_period', 0x304),
                                    ('bke_grant_count', 0x308),
                                    ('health0', 0x340), ('health1', 0x344),
                                    ('health2', 0x348), ('health3', 0x34c)]
            }
print(json.dumps(result, indent=2))
