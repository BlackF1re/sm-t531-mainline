#!/usr/bin/env python3
"""Temporary FM receive-only protocol diagnostic; never a production service.

Override only the otherwise unbound APPS_FM endpoint. Firmware responses are
control-path evidence, not proof of RF reception. No calibration is saved or
invented. No WCNSS restart, transmitter command or undocumented register write.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import select
import signal
import struct
import subprocess
import time


def interrupted(_signum, _frame):
    raise InterruptedError("Probe interrupted; restoring channel ownership")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--antenna", type=int, choices=(0, 1), default=0)
    parser.add_argument("--khz", type=int, nargs="+", default=[104600])
    args = parser.parse_args()
    compatible = Path("/proc/device-tree/compatible").read_bytes().split(b"\0")
    if os.geteuid() or b"samsung,matisse3g" not in compatible:
        parser.error("Requires root on SM-T531 / matisse3g")
    if any(not 87500 <= f <= 108000 or f % 50 for f in args.khz):
        parser.error("Frequencies must be 87500..108000 kHz in 50-kHz steps")
    with open("/run/lock/t531-fm-probe.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        probe(args)


def probe(args):
    base = Path("/sys/bus/rpmsg")
    channels = [p for p in (base / "devices").glob("*")
                if (p / "name").exists()
                and (p / "name").read_text().strip() == "APPS_FM"]
    if len(channels) != 1:
        raise RuntimeError("Expected exactly one APPS_FM channel")
    channel = channels[0]
    if (channel / "driver").exists() or (
        channel / "driver_override"
    ).read_text().strip() not in ("", "(null)"):
        raise RuntimeError("APPS_FM is already owned; refusing to take it")
    subprocess.run(["modprobe", "rpmsg_char"], check=True)
    fd = None
    bound = False
    for signum in (signal.SIGTERM, signal.SIGINT):
        signal.signal(signum, interrupted)

    def log(record):
        print(json.dumps(record), flush=True)

    def command(opcode, payload=b"", timeout=3):
        packet = struct.pack("<HB", opcode, len(payload)) + payload
        log({"tx": packet.hex()})
        if os.write(fd, packet) != len(packet):
            raise OSError("Short RPMSG write")
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if not select.select([fd], [], [], max(0, end - time.monotonic()))[0]:
                break
            data = os.read(fd, 4096)
            log({"rx": data.hex()})
            if len(data) < 2 or data[1] != len(data) - 2:
                raise ValueError("Malformed FM packet")
            result = None
            if (len(data) >= 6 and data[0] == 15
                    and struct.unpack_from("<H", data, 3)[0] == opcode):
                result = data[5:]
            elif (len(data) == 6 and data[0] == 16
                  and struct.unpack_from("<H", data, 4)[0] == opcode):
                result = bytes([data[2]])
            if result is not None:
                if opcode != 0x4c0a and (not result or result[0]):
                    raise OSError(f"FM command {opcode:#x}: {result.hex()}")
                return result
        raise TimeoutError(hex(opcode))

    try:
        (channel / "driver_override").write_text("rpmsg_chrdev\n")
        (base / "drivers/rpmsg_chrdev/bind").write_text(channel.name)
        bound = True
        endpoints = []
        for _ in range(30):
            endpoints = list(channel.glob("rpmsg/rpmsg*"))
            if endpoints:
                break
            time.sleep(0.1)
        if len(endpoints) != 1:
            raise RuntimeError("Cannot identify the FM-only character endpoint")
        fd = os.open("/dev/" + endpoints[0].name, os.O_RDWR | os.O_NONBLOCK)
        log({"enable": command(0x4c01, timeout=5).hex()})
        command(0x4c05, b"\x03\x01")  # Hard mute; no audio path required.
        command(0x4c06, b"\x00\x01\x01\x01")
        command(0x4c04, struct.pack("<BBBBII", 1, 2, 1, 0, 87500, 108000))
        command(0x4c07, bytes([args.antenna]))
        command(0x4c16, b"\x07")
        command(0x4c12, struct.pack("<IIB", 0xffffffff, 1, 0))
        for frequency in args.khz:
            command(0x5401, struct.pack("<I", frequency))
            time.sleep(2)
            station = command(0x4c0a)
            if len(station) != 12:
                raise ValueError("Unexpected station response length")
            log({"khz": struct.unpack_from("<I", station, 1)[0],
                 "service": station[5], "rssi": station[6],
                 "stereo": station[7], "rds_sync": station[8]})
    finally:
        for signum in (signal.SIGTERM, signal.SIGINT):
            signal.signal(signum, signal.SIG_IGN)
        if fd is not None:
            try:
                log({"disable": command(0x4c02).hex()})
            except Exception as error:
                log({"disable_error": repr(error), "power_off_verified": False})
            finally:
                os.close(fd)
        try:
            if bound:
                (base / "drivers/rpmsg_chrdev/unbind").write_text(channel.name)
        finally:
            (channel / "driver_override").write_text("\n")
        log({"override_cleared": True})


if __name__ == "__main__":
    main()
