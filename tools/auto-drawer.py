#!/usr/bin/env python3
import json
import os
import struct
import sys
import time
from pathlib import Path

touchscreens = [p.parent.parent for p in Path("/sys/class/input").glob("event*/device/name")
                if "maXTouch" in p.read_text().strip()]
if len(touchscreens) != 1:
    raise SystemExit("Expected exactly one maXTouch touchscreen")
DEVICE = "/dev/input/" + touchscreens[0].name
CYCLES = 10
STEPS = 24
STEP_TIME = 0.005
SETTLE_TIME = 0.750

LOG = Path(sys.argv[1])

EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
SYN_REPORT, BTN_TOUCH = 0, 330
ABS_X, ABS_Y = 0, 1
ABS_MT_SLOT = 47
ABS_MT_POSITION_X = 53
ABS_MT_POSITION_Y = 54
ABS_MT_TRACKING_ID = 57

name = (Path("/sys/class/input") / Path(DEVICE).name / "device/name").read_text().strip()
if "maXTouch" not in name:
    raise SystemExit("Unexpected touchscreen")

event = struct.Struct("@llHHi")
if event.size != 16:
    raise SystemExit("Unexpected input_event layout")

fd = os.open(DEVICE, os.O_WRONLY | os.O_NONBLOCK)
marks = []

def send(*values):
    data = b"".join(event.pack(0, 0, *value) for value in values)
    written = os.write(fd, data)
    if written != len(data):
        raise RuntimeError("Incomplete input write")

def swipe(cycle, phase, y0, y1, tracking_id):
    x = 2047
    start = time.monotonic()

    marks.append({
        "cycle": cycle,
        "phase": phase,
        "event": "press",
        "time": start
    })

    active = True

    try:
        send(
            (EV_ABS, ABS_MT_SLOT, 0),
            (EV_ABS, ABS_MT_TRACKING_ID, tracking_id),
            (EV_ABS, ABS_MT_POSITION_X, x),
            (EV_ABS, ABS_MT_POSITION_Y, y0),
            (EV_ABS, ABS_X, x),
            (EV_ABS, ABS_Y, y0),
            (EV_KEY, BTN_TOUCH, 1),
            (EV_SYN, SYN_REPORT, 0),
        )

        for i in range(1, STEPS + 1):
            target = start + i * STEP_TIME
            time.sleep(max(0, target - time.monotonic()))

            y = y0 + (y1 - y0) * i // STEPS

            send(
                (EV_ABS, ABS_MT_POSITION_X, x),
                (EV_ABS, ABS_MT_POSITION_Y, y),
                (EV_ABS, ABS_X, x),
                (EV_ABS, ABS_Y, y),
                (EV_SYN, SYN_REPORT, 0),
            )

    finally:
        if active:
            send(
                (EV_ABS, ABS_MT_SLOT, 0),
                (EV_ABS, ABS_MT_TRACKING_ID, -1),
                (EV_KEY, BTN_TOUCH, 0),
                (EV_SYN, SYN_REPORT, 0),
            )
            marks.append({
                "cycle": cycle,
                "phase": phase,
                "event": "release",
                "time": time.monotonic()
            })

try:
    for cycle in range(1, CYCLES + 1):
        swipe(cycle, "open", 81, 1638, cycle * 2 + 2000)
        time.sleep(SETTLE_TIME)

        swipe(cycle, "close", 3071, 983, cycle * 2 + 2001)
        time.sleep(SETTLE_TIME)

finally:
    os.close(fd)
    LOG.write_text(json.dumps({
        "cycles": CYCLES,
        "steps": STEPS,
        "step_time_seconds": STEP_TIME,
        "settle_seconds": SETTLE_TIME,
        "marks": marks
    }, indent=2) + "\n")

print(f"Completed {CYCLES} cycles; {len(marks)} timestamps")
print(f"Gesture log: {LOG}")
