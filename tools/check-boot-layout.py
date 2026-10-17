#!/usr/bin/env python3
"""Reject ARM appended-DTB images whose decompressor workspace can hit scanout.

The SM-T531 firmware scans RAM at 0x03200000. ARM's compressed/head.S can
relocate its compressed image and appended DTB above the decompressed kernel.
Checking zImage size alone misses this collision. Use a conservative bound,
including BSS and 256 KiB for alignment, stack and decompressor workspace.
"""
import json
import pathlib
import re
import sys

symbols, config, zimage, dtb = map(pathlib.Path, sys.argv[1:])
cfg = config.read_text()
match = re.search(r"^CONFIG_PAGE_OFFSET=(0x[0-9a-fA-F]+)$", cfg, re.M)
if not match:
    raise SystemExit("Cannot determine ARM kernel virtual-to-physical offset")
offset = int(match[1], 16)
values = {}
for line in symbols.read_text().splitlines():
    fields = line.split()
    if len(fields) == 3 and fields[2] in ("_text", "_end"):
        values[fields[2]] = int(fields[0], 16) - offset
if set(values) != {"_text", "_end"}:
    raise SystemExit("Missing kernel boundary symbols")
framebuffer_start = 0x03200000
peak = values["_end"] + zimage.stat().st_size + dtb.stat().st_size + 0x40000
report = {"kernel_begin": hex(values["_text"]), "kernel_end": hex(values["_end"]),
          "conservative_workspace_end": hex(peak),
          "firmware_framebuffer_start": hex(framebuffer_start)}
print(json.dumps(report, indent=2))
if values["_text"] < 0 or peak >= framebuffer_start:
    raise SystemExit("Unsafe ARM decompressor/appended DTB placement near framebuffer")
