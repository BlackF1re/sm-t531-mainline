#!/usr/bin/env python3
"""Fetch the explicit Debian dependency set, verifying archives and metadata."""
import argparse
import email.parser
import hashlib
import json
from pathlib import Path
import subprocess
import urllib.request

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("destination", type=Path)
args = parser.parse_args()
manifest = Path(__file__).resolve().parent.parent / "config/phosh-runtime.lock.json"
entries = json.loads(manifest.read_text())["packages"]
args.destination.mkdir(parents=True, exist_ok=True)
for entry in entries:
    name = entry["filename"]
    if Path(name).name != name or not name.endswith(".deb"):
        raise SystemExit("Invalid package filename")
    dest = args.destination / name
    if not dest.exists():
        part = dest.with_suffix(".deb.part")
        with urllib.request.urlopen(entry["url"], timeout=60) as response, part.open("wb") as output:
            while chunk := response.read(1024 * 1024):
                output.write(chunk)
        if hashlib.sha256(part.read_bytes()).hexdigest() != entry["sha256"]:
            part.unlink()
            raise SystemExit("Checksum mismatch: " + name)
        part.replace(dest)
    if hashlib.sha256(dest.read_bytes()).hexdigest() != entry["sha256"]:
        raise SystemExit("Checksum mismatch: " + name)
    control = email.parser.Parser().parsestr(
        subprocess.check_output(["dpkg-deb", "-f", str(dest)], text=True))
    for field in ("Package", "Version", "Architecture"):
        if control[field] != entry[field.lower()]:
            raise SystemExit("Unexpected " + field + " in " + name)
    print("Verified " + name, flush=True)
