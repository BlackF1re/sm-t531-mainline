#!/usr/bin/env python3
"""Insert a private per-device Bluetooth identity into a staged SM-T531 DTB."""
import re
import subprocess
import sys
from pathlib import Path


def main():
    dtb, source = map(Path, sys.argv[1:])
    value = source.read_text().strip()
    if not re.fullmatch(r"(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}", value):
        raise SystemExit("Invalid factory Bluetooth address file")
    address = bytes.fromhex(value.replace(":", ""))
    if address[0] & 1 or address in (bytes(6), bytes([255]) * 6):
        raise SystemExit("Bluetooth address must be a nonzero unicast address")
    # bluetooth-controller.yaml specifies least-significant byte first.
    subprocess.run([
        "fdtput", "-t", "bx", str(dtb),
        "/soc/remoteproc@fb204000/smd-edge/wcnss/bluetooth",
        "local-bd-address", *(f"{b:02x}" for b in reversed(address))], check=True)


if __name__ == "__main__":
    main()
