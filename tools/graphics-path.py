#!/usr/bin/env python3
"""Identify the active compositor's open KMS and GPU devices."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess


def inspect_path(pid=None, require_unlocked=False):
    if os.geteuid():
        raise SystemExit("Run as root to inspect compositor descriptors and DRM names")
    if b"samsung,matisse3g" not in Path("/proc/device-tree/compatible").read_bytes().split(b"\0"):
        raise SystemExit("Restricted to SM-T531")
    if pid is None:
        found = subprocess.run(["pgrep", "-u", "t531", "-x", "kwin_wayland|phoc"],
                               text=True, capture_output=True).stdout.strip()
        if not found.isdecimal():
            raise SystemExit("Expected exactly one session compositor")
        pid = int(found)
    devices = set()
    for fd in Path(f"/proc/{pid}/fd").iterdir():
        try:
            target = os.readlink(fd)
        except FileNotFoundError:
            continue
        if re.fullmatch(r"/dev/dri/(card\d+|renderD\d+)", target):
            devices.add(target)
    cards = sorted(d for d in devices if re.fullmatch(r"/dev/dri/card\d+", d))
    if len(cards) != 1:
        raise SystemExit("Ambiguous/missing compositor KMS device: " + repr(cards))
    card = Path(cards[0])
    minor = os.minor(card.stat().st_rdev)
    name = Path(f"/sys/kernel/debug/dri/{minor}/name").read_text().strip()
    if name.startswith("msm "):
        capability = json.loads(subprocess.check_output(
            ["/usr/local/libexec/t531-drm-probe", "--require-unified"], text=True))
        if Path(capability["card"]) != card:
            raise SystemExit("Compositor is not using the verified unified KMS device")
        presentation = "native-kms"
    elif name.startswith("msm-kms dev=fd900100.display-controller "):
        presentation = "native-kms"
        expected = Path("/dev/dri/by-path/platform-fd900100.display-controller-card")
        gpu = Path("/dev/dri/by-path/platform-fdb00000.gpu-render")
        if expected.resolve(strict=True) != card or str(gpu.resolve(strict=True)) not in devices:
            raise SystemExit("Native scanout or Adreno render descriptor does not match board topology")
    elif name.startswith("simpledrm "):
        presentation = "simpledrm"
    else:
        raise SystemExit("Unsupported active KMS driver: " + name)
    result = {"presentation_path": presentation, "compositor_pid": pid,
            "compositor_name": Path(f"/proc/{pid}/comm").read_text().strip(),
            "kms_device": str(card), "kms_driver": name,
            "render_devices": sorted(d for d in devices if "/renderD" in d)}
    if require_unlocked:
        sessions = []
        listing = subprocess.check_output(["loginctl", "list-sessions", "--no-legend"], text=True)
        for line in listing.splitlines():
            fields = line.split()
            if len(fields) < 4 or fields[2:4] != ["t531", "seat0"]:
                continue
            sid = fields[0]
            kind = subprocess.check_output(["loginctl", "show-session", sid,
                                            "-p", "Type", "--value"], text=True).strip()
            if kind == "wayland":
                sessions.append(sid)
        if len(sessions) != 1:
            raise SystemExit("INVALID: expected one local Wayland session")
        locked = subprocess.check_output(["loginctl", "show-session", sessions[0],
                                          "-p", "LockedHint", "--value"], text=True).strip()
        if locked != "no":
            raise SystemExit("INVALID: unlock the desktop before profiling")
        result.update(session_id=sessions[0], session_locked=False)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expect", choices=("native-kms", "simpledrm"))
    parser.add_argument("--compare", type=Path, help="Reject any device/compositor change since this JSON snapshot")
    parser.add_argument("--require-unlocked", action="store_true", help="Reject lock-screen workloads")
    args = parser.parse_args()
    result = inspect_path(require_unlocked=args.require_unlocked)
    if args.expect and result["presentation_path"] != args.expect:
        raise SystemExit("INVALID: expected " + args.expect + ", actually " + result["presentation_path"])
    if args.compare and result != json.loads(args.compare.read_text()):
        raise SystemExit("INVALID: compositor or DRM path changed during recording")
    print(json.dumps(result, indent=2))
