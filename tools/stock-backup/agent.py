#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Remote root agent. Sent over SSH; never installed or run automatically."""
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile

BLOCK = Path('/sys/class/block')
CHUNK = 1024 * 1024


def fail(message):
    raise RuntimeError(message)


def check_board():
    if os.geteuid() != 0:
        fail('Root access is required on the tablet')
    if b'samsung,matisse3g' not in Path('/proc/device-tree/compatible').read_bytes().split(b'\0'):
        fail('This is not samsung,matisse3g')
    cid = (BLOCK / 'mmcblk0/device/cid').read_text().strip().lower()
    if not re.fullmatch('[0-9a-f]{32}', cid):
        fail('Cannot establish eMMC identity')
    return cid


def device(name):
    if not re.fullmatch(r'mmcblk0(?:boot[01]|p(?:[1-9]|1[0-9]|2[0-6]))?', name):
        fail('Target is outside internal eMMC')
    path = Path('/dev') / name
    if path.is_symlink() or not stat.S_ISBLK(path.stat().st_mode):
        fail('Target is not a direct block device')
    size = int((BLOCK / name / 'size').read_text()) * 512
    return path, size


def offline():
    # Check all related partitions, including mounts under aliases and swap.
    names = ['mmcblk0'] + [p.name for p in BLOCK.glob('mmcblk0p*')]
    numbers = {(BLOCK / name / 'dev').read_text().strip() for name in names}
    for line in Path('/proc/self/mountinfo').read_text().splitlines():
        if line.split()[2] in numbers:
            fail('Internal eMMC has mounted filesystems; use Linux/rescue on SD or RAM')
    for name in names:
        if any((BLOCK / name / 'holders').iterdir()):
            fail('Internal eMMC has active device-mapper/RAID holders')
    for line in Path('/proc/swaps').read_text().splitlines()[1:]:
        source = line.split()[0]
        st = os.stat(source)
        number = f'{os.major(st.st_rdev)}:{os.minor(st.st_rdev)}'
        if number in numbers:
            fail('Internal eMMC is used as swap')


def inventory():
    cid = check_board()
    raw = json.loads(subprocess.check_output(
        ['lsblk', '-b', '-J', '-o', 'NAME,SIZE,START,PARTLABEL', '/dev/mmcblk0'], text=True
    ))['blockdevices'][0]
    if not raw.get('children') or not all(isinstance(p.get('partlabel'), str) for p in raw['children']):
        fail('Cannot enumerate named internal partitions; a verified layout is required')
    parts = [{'name':p['partlabel'].upper(), 'device':p['name'],
              'start_sector':int(p['start']), 'bytes':int(p['size'])}
             for p in raw.get('children', [])]
    areas = []
    for name in ('mmcblk0', 'mmcblk0boot0', 'mmcblk0boot1'):
        if (BLOCK / name).exists():
            _, size = device(name)
            areas.append({'name':name, 'bytes':size})
    ready, reason = True, ''
    try:
        offline()
    except RuntimeError as error:
        ready, reason = False, str(error)
    metadata = {}
    for name in ('name', 'serial', 'manfid', 'oemid', 'date', 'csd', 'fwrev', 'hwrev',
                 'life_time', 'pre_eol_info'):
        f = BLOCK / 'mmcblk0/device' / name
        if f.exists():
            metadata[name] = f.read_text().strip()
    # Runtime addresses are observations; factory identities remain in raw EFS/NV.
    addresses = {}
    for f in sorted(Path('/sys/class/net').glob('*/address')):
        addresses['network/' + f.parent.name] = f.read_text().strip()
    for f in sorted(Path('/sys/class/bluetooth').glob('hci*/address')):
        addresses['bluetooth/' + f.parent.name] = f.read_text().strip()
    return {'backend':'ssh', 'compatible':'samsung,matisse3g', 'model':'SM-T531',
            'identity':cid, 'identity_kind':'emmc-cid', 'kernel':os.uname().release,
            'partitions':parts, 'areas':areas, 'offline':ready, 'offline_reason':reason,
            'emmc_metadata':metadata, 'observed_addresses':addresses,
            'exclusions':['RPMB authenticated contents/key', 'OTP/eFuse/TrustZone secrets',
                          'volatile state and non-storage device firmware',
                          'eMMC EXT_CSD configuration is not included in raw images'],
            'consistency':'Unmounted storage read; not a firmware-wide atomic snapshot'}


def bounds(name, offset, size):
    path, capacity = device(name)
    if offset < 0 or size <= 0 or offset + size > capacity:
        fail('Range is outside the device')
    return path


def read_range(name, offset, size, output=True):
    check_board()
    offline()
    path = bounds(name, offset, size)
    digest = hashlib.sha256()
    with path.open('rb', buffering=0) as source:
        source.seek(offset)
        remaining = size
        while remaining:
            data = source.read(min(CHUNK, remaining))
            if not data:
                fail('Short block-device read')
            digest.update(data)
            if output:
                sys.stdout.buffer.write(data)
            remaining -= len(data)
    offline()
    return digest.hexdigest()


def write_image(name, size, expected_hash, expected_cid):
    # The host requires an explicit execution flag and typed identity first.
    if check_board() != expected_cid:
        fail('eMMC identity changed')
    offline()
    target = bounds(name, 0, size)
    if device(name)[1] != size or name.startswith('mmcblk0boot'):
        fail('Only exact complete user-area or partition writes are supported')
    if not re.fullmatch('[0-9a-f]{64}', expected_hash):
        fail('Invalid expected SHA256')
    # Stage and hash BEFORE touching eMMC. A lost SSH upload cannot start a write.
    os.umask(0o077)
    with tempfile.TemporaryDirectory(prefix='t531-restore-', dir='/var/tmp') as tmp:
        free = os.statvfs(tmp).f_bavail * os.statvfs(tmp).f_frsize
        if free < size + 64 * CHUNK:
            fail('Insufficient SD/RAM space to stage and verify restoration')
        image = Path(tmp) / 'image.raw'
        digest = hashlib.sha256()
        with image.open('xb') as dest:
            remaining = size
            while remaining:
                data = sys.stdin.buffer.read(min(CHUNK, remaining))
                if not data:
                    fail('Upload interrupted; no eMMC write performed')
                dest.write(data)
                digest.update(data)
                remaining -= len(data)
            if sys.stdin.buffer.read(1):
                fail('Upload exceeds exact target size')
            dest.flush()
            os.fsync(dest.fileno())
        if digest.hexdigest() != expected_hash:
            fail('Uploaded image checksum mismatch; no eMMC write performed')
        if check_board() != expected_cid:
            fail('eMMC identity changed before write')
        offline()
        with image.open('rb') as source, target.open('r+b', buffering=0) as dest:
            while data := source.read(CHUNK):
                view = memoryview(data)
                while view:
                    count = dest.write(view)
                    if not count:
                        fail('Short block-device write')
                    view = view[count:]
            os.fsync(dest.fileno())
        actual = read_range(name, 0, size, output=False)
        if actual != expected_hash:
            fail('RESTORE READBACK MISMATCH; do not reboot')
    return actual


def main():
    action, *args = sys.argv[1:]
    if action == 'inspect' and not args:
        print(json.dumps(inventory()))
    elif action in ('read', 'hash') and len(args) == 3:
        digest = read_range(args[0], int(args[1]), int(args[2]), output=action == 'read')
        print(json.dumps({'sha256':digest}), file=sys.stderr if action == 'read' else sys.stdout)
    elif action == 'write' and len(args) == 4:
        print(json.dumps({'sha256':write_image(args[0], int(args[1]), args[2], args[3])}))
    else:
        fail('Unsupported agent action')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print(f'Backup agent: {error}', file=sys.stderr)
        sys.exit(1)
