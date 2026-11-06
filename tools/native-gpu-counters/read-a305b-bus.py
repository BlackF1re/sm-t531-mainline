#!/usr/bin/env python3
"""Read-only sampler for the bounded native-gpu-counters diagnostic."""
import json
import mmap
import os
import sys
from pathlib import Path
import struct
import time

if os.geteuid() or b'samsung,matisse3g' not in Path('/proc/device-tree/compatible').read_bytes().split(b'\0'):
    raise SystemExit('Requires root on SM-T531')
if not Path('/sys/module/t531_gpu_counters').exists():
    raise SystemExit('Requires bounded t531_gpu_counters module')
if Path('/sys/bus/platform/devices/fdb00000.gpu/power/runtime_status').read_text().strip() != 'active':
    raise SystemExit('GPU must be powered')


def word(regs, offset):
    return struct.unpack_from('<I', regs, offset * 4)[0]


def counter(regs, offset):
    for _ in range(3):
        high = word(regs, offset + 1)
        low = word(regs, offset)
        if high == word(regs, offset + 1):
            return (high << 32) | low
    raise RuntimeError('Counter could not be read consistently')


duration = int(sys.argv[1]) if len(sys.argv) > 1 else 15
if not 1 <= duration <= 25:
    raise SystemExit('Duration must be1..25seconds')

shader = Path('/sys/module/t531_gpu_counters/parameters/shader').read_text().strip() == 'Y'
extra = [
    ('pc_working', 0x96, 0xc48, 0x0c),
    ('pc_stall_vfd', 0x98, 0xc49, 0x09),
    ('pc_stall_tse', 0x9a, 0xc4a, 0x0a),
    ('pc_stall_vbif', 0x9c, 0xc4b, 0x0b),
    ('rb_active', 0xe2, 0xcc6, 0x00),
    ('rb_stall_marb', 0xe4, 0xcc7, 0x05),
    ('sp_alu_active', 0xd2, 0xec4, 0x1d),
    ('sp_stall_tp', 0xd4, 0xec5, 0x20),
    ('sp_stall_uche', 0xd6, 0xec6, 0x21),
    ('sp_stall_rb', 0xd8, 0xec7, 0x22),
    ('sp_active_any', 0xda, 0xec8, 0x23),
    ('sp_fs_full_instructions', 0xdc, 0xec9, 0x0e),
    ('sp_fs_half_instructions', 0xde, 0xeca, 0x0f),
    ('sp_fs_tex_instructions', 0xe0, 0xecb, 0x0b),
    ('tp_l1_requests', 0xc6, 0xf04, 0x01),
    ('tp_l1_misses', 0xc8, 0xf05, 0x02),
    ('tp_latency', 0xca, 0xf06, 0x1a),
    ('tp_latency_transactions', 0xcc, 0xf07, 0x1b),
    ('tp_active_any', 0xce, 0xf08, 0x17),
    ('tp_stall_arb', 0xd0, 0xf09, 0x19),
    ('uche_vbif_latency', 0xba, 0xe84, 0x12),
    ('uche_vbif_transactions', 0xbc, 0xe85, 0x13),
    ('uche_active', 0xbe, 0xe86, 0x14),
    ('uche_tp_read_beats', 0xc0, 0xe87, 0x00),
] if shader else []

with open('/dev/mem', 'rb', buffering=0) as memory, \
        mmap.mmap(memory.fileno(), 4096, access=mmap.ACCESS_READ, offset=0xfdb00000) as rbbm, \
        mmap.mmap(memory.fileno(), 4096, access=mmap.ACCESS_READ, offset=0xfdb0c000) as vbif, \
        mmap.mmap(memory.fileno(), 4096, access=mmap.ACCESS_READ, offset=0xfdb03000) as selectors:
    start = time.monotonic()
    previous = None
    while time.monotonic() - start < duration:
        if word(vbif, 0x70) & 0x1f != 5 or word(vbif, 0x72) & 0x7f != 85:
            raise SystemExit('Counter configuration changed; rejecting sample')
        values = dict(axi_beats=counter(vbif, 0x73), ram_wait_cycles=counter(vbif, 0x77),
                      gpu_busy_cycles=counter(rbbm, 0xec))
        for name, offset, select_reg, selection in extra:
            if word(selectors, select_reg - 0xc00) != selection:
                raise SystemExit('Shader counter selector changed; rejecting sample')
            values[name] = counter(rbbm, offset)
        stamp = time.monotonic()
        if previous is not None:
            before, old = previous
            delta = {key: value-old[key] for key, value in values.items()}
            if any(v < 0 for v in delta.values()):
                raise SystemExit('Counter reset during measurement')
            print(json.dumps(dict(time=stamp, seconds=stamp-before, **delta)), flush=True)
        previous = stamp, values
        time.sleep(0.01)
