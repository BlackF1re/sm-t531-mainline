#!/usr/bin/env python3
"""Test stale-contact cleanup through the real SM-T531 touch PM callbacks."""
import argparse
import fcntl
import glob
import json
import os
import struct
import subprocess
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("module", type=Path)
    parser.add_argument("--cycles", type=int, default=3)
    parser.add_argument("--system-sleep", action="store_true",
                        help="use logind system suspend with an RTC wake alarm")
    args = parser.parse_args()
    assert os.geteuid() == 0 and struct.calcsize("P") == 4
    assert 1 <= args.cycles <= 20
    assert b"samsung,matisse3g" in Path("/proc/device-tree/compatible").read_bytes()
    assert not Path("/sys/module/t531_mxt_pm_probe").exists()
    matches = [p for p in glob.glob("/dev/input/event*")
               if Path("/sys/class/input", Path(p).name, "device/name").read_text()
               .strip() == "Atmel maXTouch Touchscreen"]
    assert len(matches) == 1
    fd = os.open(matches[0], os.O_RDWR | os.O_NONBLOCK)

    def slots():
        buf = bytearray(struct.pack("=i", 57) + bytes(64))
        fcntl.ioctl(fd, 0x8044450a, buf)  # EVIOCGMTSLOTS, 16 slots
        return list(struct.unpack("=17i", buf)[1:])

    def touch_down():
        buf = bytearray(96)
        fcntl.ioctl(fd, 0x80604518, buf)  # EVIOCGKEY
        return bool(buf[330 // 8] & (1 << (330 % 8)))

    def emit(events):
        # The tablet uses ARM32 input_event, including 32-bit timeval fields.
        os.write(fd, b"".join(struct.pack("=iiHHi", 0, 0, t, c, v)
                              for t, c, v in events + [(0, 0, 0)]))

    records = []
    grabbed = False
    injected = False
    selected = (0, 7, 15)
    try:
        fcntl.ioctl(fd, 0x40044590, 1)  # EVIOCGRAB: hide test input from GUI
        grabbed = True
        assert slots() == [-1] * 16 and not touch_down(), "Real touch in progress"
        for cycle in range(args.cycles):
            injected = True
            for slot in selected:
                emit([(3, 47, slot), (3, 57, 30000 + cycle * 16 + slot),
                      (3, 53, 2048), (3, 54, 2048), (1, 330, 1)])
            before = slots()
            # input_dev_suspend() releases keys, but not MT tracking IDs.
            emit([(1, 330, 0)])
            if args.system_sleep:
                alarm = Path("/sys/class/rtc/rtc0/wakealarm")
                assert not alarm.read_text().strip(), "An RTC alarm is already armed"
            else:
                subprocess.run(["insmod", str(args.module.resolve())], check=True)
            try:
                if args.system_sleep:
                    stats = Path("/sys/power/suspend_stats")
                    successes = int((stats / "success").read_text())
                    failures = int((stats / "fail").read_text())
                    subprocess.run(["rtcwake", "-m", "no", "-s", "10"],
                                   check=True, stdout=subprocess.PIPE)
                    # Notify the compositor and NetworkManager through logind.
                    subprocess.run(["systemctl", "suspend"], check=True)
                    deadline = time.monotonic() + 35
                    while True:
                        assert int((stats / "fail").read_text()) == failures, \
                            "System suspend was aborted"
                        if int((stats / "success").read_text()) > successes:
                            preparing = subprocess.check_output([
                                "busctl", "get-property", "org.freedesktop.login1",
                                "/org/freedesktop/login1", "org.freedesktop.login1.Manager",
                                "PreparingForSleep"], text=True).strip()
                            if preparing == "b false":
                                break
                        assert time.monotonic() < deadline, "Suspend did not complete"
                        time.sleep(0.2)
                    time.sleep(1)
                time.sleep(0.2)
                after = slots()
                down = touch_down()
                records.append({"cycle": cycle + 1, "before": before,
                                "after": after, "BTN_TOUCH_after": down})
                assert after == [-1] * 16 and not down, "Stale contact survived PM"
            finally:
                if args.system_sleep:
                    alarm.write_text("0\n")
                else:
                    subprocess.run(["rmmod", "t531_mxt_pm_probe"], check=True)
    finally:
        if grabbed:
            # Also runs if the assertion fails on an unpatched kernel.
            if injected:
                for slot in selected:
                    emit([(3, 47, slot), (3, 57, -1)])
                emit([(1, 330, 0), (3, 47, 0)])
            final = slots()
            fcntl.ioctl(fd, 0x40044590, 0)
        else:
            final = None
        os.close(fd)
        print(json.dumps({"cycles": records, "final_slots": final,
                          "system_sleep": args.system_sleep,
                          "module_unloaded": not Path(
                              "/sys/module/t531_mxt_pm_probe").exists()}, indent=2))


if __name__ == "__main__":
    main()
