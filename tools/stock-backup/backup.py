#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""SM-T531 private backup/restore CLI. Python standard library only."""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import select
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
PROFILE = json.loads((ROOT / 'hardware/partitions.json').read_text())
AGENT = Path(__file__).with_name('agent.py').read_text()
MIB = 1024 * 1024
CRITICAL = {'EMMC_USER', 'SBL1', 'DBI', 'DDR', 'ABOOT', 'RPM', 'TZ', 'BOOT',
            'RECOVERY', 'EFS', 'MODEMST1', 'MODEMST2', 'FSG', 'FSC', 'PERSIST',
            'PERSDATA', 'MODEM', 'APNHLOS', 'SSD', 'BACKUP', 'PARAM', 'FOTA'}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def atomic_json(path, value):
    fd, name = tempfile.mkstemp(prefix='.' + path.name + '-', dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as output:
            json.dump(value, output, indent=2)
            output.write('\n')
            output.flush()
            os.fsync(output.fileno())
        temporary.replace(path)
        fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    finally:
        temporary.unlink(missing_ok=True)


def private_dir(path):
    path = path.expanduser().absolute()
    require(not path.is_symlink(), 'Backup directory must not be a symlink')
    path = path.resolve()
    if path.is_relative_to(ROOT):
        require(path.is_relative_to(ROOT / 'backup_stock'),
                'Inside the repository, private output must be under backup_stock/')
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.chmod(0o700)
    return path


@contextmanager
def lock(path):
    with (path / '.lock').open('a') as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise RuntimeError('Another operation is using this backup session') from error
        yield


def asset_path(root, name):
    require(isinstance(name, str) and name, 'Invalid asset path')
    relative = Path(name)
    require(not relative.is_absolute() and '..' not in relative.parts,
            'Unsafe manifest path')
    path = root / relative
    require(path.resolve().is_relative_to(root.resolve()), 'Asset escapes backup directory')
    require(not any(p.is_symlink() for p in [path, *path.parents] if p != root.parent),
            'Symlinks are not accepted in backup assets')
    return path


def hash_range(path, offset=0, size=None):
    digest = hashlib.sha256()
    size = path.stat().st_size - offset if size is None else size
    require(offset >= 0 and size >= 0, 'Invalid image range')
    with path.open('rb') as source:
        source.seek(offset)
        remaining = size
        while remaining:
            data = source.read(min(MIB, remaining))
            require(data, 'Short local image')
            digest.update(data)
            remaining -= len(data)
    return digest.hexdigest()


def validate_inventory(info):
    require(isinstance(info, dict), 'Invalid device inventory')
    require(info.get('compatible') == PROFILE['compatible'], 'Wrong board')
    expected = PROFILE['partitions']
    actual = info.get('partitions')
    require(actual == expected, 'Partition geometry differs from the verified SM-T531 profile')
    require(info.get('backend') in {'ssh', 'lk2nd'}, 'Unknown backup backend')
    require(info.get('identity_kind') in {'emmc-cid', 'fastboot-serial'}, 'Unknown identity type')
    require(isinstance(info.get('identity'), str), 'Invalid device identity')
    require(info['identity'].strip('0'), 'Zero device identity')
    require(info['identity_kind'] == {'ssh':'emmc-cid', 'lk2nd':'fastboot-serial'}[info['backend']],
            'Identity type does not match the acquisition backend')
    require(re.fullmatch('[0-9a-f]{32}', info.get('identity', '')) is not None
            if info.get('identity_kind') == 'emmc-cid'
            else bool(re.fullmatch('[A-Za-z0-9_.-]{4,128}', info.get('identity', ''))),
            'Missing reliable device identity')
    if info['backend'] == 'ssh':
        require(isinstance(info.get('areas'), list) and
                all(isinstance(a, dict) and 'name' in a for a in info['areas']), 'Invalid eMMC area list')
        require(sorted(info['areas'], key=lambda p: str(p['name'])) == [
            {'name':'mmcblk0', 'bytes':PROFILE['user_area_bytes']},
            {'name':'mmcblk0boot0', 'bytes':PROFILE['boot_area_bytes']},
            {'name':'mmcblk0boot1', 'bytes':PROFILE['boot_area_bytes']}],
            'Unexpected eMMC capacity or inaccessible boot areas')
    return info


def fingerprint(info):
    return hashlib.sha256((info['identity_kind'] + ':' + info['identity']).encode()).hexdigest()[:12]


def validate_same(saved, live):
    validate_inventory(saved)
    validate_inventory(live)
    require(saved['identity_kind'] == live['identity_kind'] and saved['identity'] == live['identity'],
            'Different tablet/eMMC: restoration across devices is prohibited')


def specs(info, selection=None):
    entries = [{'name':p['name'], 'device':p['device'], 'offset':0, 'bytes':p['bytes']}
               for p in PROFILE['partitions']]
    if info['backend'] == 'ssh':
        areas = [{'name':{'mmcblk0':'EMMC_USER', 'mmcblk0boot0':'EMMC_BOOT0',
                          'mmcblk0boot1':'EMMC_BOOT1'}[a['name']],
                  'device':a['name'], 'offset':0, 'bytes':a['bytes']} for a in info['areas']]
        if selection is None:
            require({a['name'] for a in areas} == {'EMMC_USER', 'EMMC_BOOT0', 'EMMC_BOOT1'},
                    'Both eMMC boot areas are required for the default full capture')
            return areas
        entries += areas
    if selection is None:
        return entries
    selected = selection.split(',')
    require(len(set(selected)) == len(selected), 'Duplicate partition selection')
    available = {p['name']:p for p in entries}
    require(all(p in available for p in selected), 'Unknown partition/area; use uppercase names')
    return [available[p] for p in selected]


class Progress:
    def __init__(self, name, total):
        self.name, self.total = name, total
        self.start, self.last = time.monotonic(), 0
        size = f'{total / MIB:.2f} MiB' if total >= MIB else f'{total / 1024:.2f} KiB'
        print(f'  {name:<14} {size:>13}', flush=True)

    def __call__(self, done):
        now = time.monotonic()
        if sys.stdout.isatty() and now - self.last >= 0.5:
            rate = done / max(now - self.start, 0.01)
            eta = (self.total - done) / max(rate, 1)
            print(f'\r    {done / self.total:6.1%}  {rate / MIB:6.1f} MiB/s  ETA {eta:5.0f}s', end='', flush=True)
            self.last = now

    def finish(self):
        if sys.stdout.isatty():
            print('\r' + ' ' * 68 + '\r', end='')
        print('    SHA256 verified', flush=True)


class NullSink:
    def write(self, data):
        return len(data)


class SSH:
    def __init__(self, args):
        require(args.host and not args.host.startswith('-') and
                re.fullmatch(r'[A-Za-z0-9_.@:\[\]-]+', args.host), 'Supply --host root@ADDRESS')
        self.base = ['ssh', '-T', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
                     '-o', 'ConnectTimeout=8', '-o', 'ServerAliveInterval=10',
                     '-o', 'ServerAliveCountMax=3']
        if args.known_hosts:
            self.base += ['-o', 'UserKnownHostsFile=' + str(args.known_hosts.resolve())]
        self.base += [args.host]

    def command(self, *args):
        return self.base + [shlex.join(['python3', '-c', AGENT, *map(str, args)])]

    def inspect(self):
        result = subprocess.run(self.command('inspect'), capture_output=True, text=True, timeout=35)
        require(result.returncode == 0, 'SSH inspection failed: ' + result.stderr.strip())
        return validate_inventory(json.loads(result.stdout))

    def read(self, spec, dest, progress=lambda done: None):
        command = self.command('read', spec['device'], spec['offset'], spec['bytes'])
        digest, done = hashlib.sha256(), 0
        with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as process:
            try:
                while done < spec['bytes']:
                    require(select.select([process.stdout], [], [], 45)[0], 'SSH transfer stalled')
                    data = os.read(process.stdout.fileno(), min(MIB, spec['bytes'] - done))
                    require(data, 'SSH transfer ended early')
                    dest.write(data)
                    digest.update(data)
                    done += len(data)
                    progress(done)
                extra, error = process.communicate(timeout=45)
                require(process.returncode == 0 and not extra,
                        'Remote read failed: ' + error.decode(errors='replace').strip())
                require(json.loads(error)['sha256'] == digest.hexdigest(), 'Transport checksum mismatch')
            except BaseException:
                process.kill()
                process.wait()
                raise
        return digest.hexdigest()

    def hash(self, spec):
        result = subprocess.run(self.command('hash', spec['device'], spec['offset'], spec['bytes']),
                                capture_output=True, text=True, timeout=None)
        require(result.returncode == 0, 'Remote checksum failed: ' + result.stderr.strip())
        return json.loads(result.stdout)['sha256']

    def write(self, spec, source, offset, digest, info):
        command = self.command('write', spec['device'], spec['bytes'], digest, info['identity'])
        progress = Progress('upload ' + spec['name'], spec['bytes'])
        # Remote stages and verifies the entire upload before opening the target for writing.
        with tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as error:
            with subprocess.Popen(command, stdin=subprocess.PIPE, stdout=output, stderr=error) as proc:
                try:
                    with source.open('rb') as stream:
                        stream.seek(offset)
                        remaining = spec['bytes']
                        while remaining:
                            data = stream.read(min(MIB, remaining))
                            require(data, 'Local restoration image ended early')
                            proc.stdin.write(data)
                            remaining -= len(data)
                            progress(spec['bytes'] - remaining)
                    proc.stdin.close()
                    proc.wait()
                    error.seek(0)
                    require(proc.returncode == 0, 'Remote restore failed: ' + error.read().decode(errors='replace').strip())
                    output.seek(0)
                    require(json.load(output)['sha256'] == digest, 'Restore readback mismatch')
                except BaseException:
                    proc.kill()
                    proc.wait()
                    raise
        progress.finish()


class LK2nd:
    def __init__(self, args):
        result = subprocess.run(['fastboot', 'devices'], capture_output=True, text=True, timeout=10)
        devices = [line.split()[0] for line in result.stdout.splitlines() if line.strip()]
        serial = args.serial
        require(serial in devices if serial else len(devices) == 1,
                'Connect exactly one fastboot device, or supply --serial')
        self.serial = serial or devices[0]
        self.base = ['fastboot', '-s', self.serial]
        self.maximum = 16 * MIB

    def run(self, *args, timeout=180):
        result = subprocess.run(self.base + list(map(str, args)), capture_output=True, text=True, timeout=timeout)
        require(result.returncode == 0, 'Fastboot failed: ' + (result.stderr + result.stdout).strip())
        return result.stdout + result.stderr

    def var(self, name):
        output = self.run('getvar', name, timeout=15)
        for line in output.splitlines():
            line = re.sub(r'^\(bootloader\)\s*', '', line).strip()
            if line.startswith(name + ':'):
                return line[len(name) + 1:].strip()
        raise RuntimeError('Fastboot did not return ' + name)

    def inspect(self):
        require(self.var('lk2nd:compatible') == PROFILE['compatible'], 'Not the SM-T531 lk2nd device')
        self.maximum = min(int(self.var('max-fetch-size'), 0), 16 * MIB)
        require(self.maximum >= 512, 'Invalid max-fetch-size')
        self.maximum -= self.maximum % 512
        for part in PROFILE['partitions']:
            size = int(self.var('partition-size:' + part['name'].lower()), 0)
            expected = part['bytes'] - (PROFILE['lk2nd_boot_prefix_bytes'] if part['name'] == 'BOOT' else 0)
            require(size == expected, 'Unexpected physical/virtual partition size: ' + part['name'])
        require(int(self.var('partition-size:lk2nd'), 0) == PROFILE['lk2nd_boot_prefix_bytes'],
                'Cannot establish the protected lk2nd prefix')
        identity = self.var('serialno')
        return validate_inventory({'backend':'lk2nd', 'compatible':PROFILE['compatible'],
            'model':'SM-T531', 'identity':identity, 'identity_kind':'fastboot-serial',
            'partitions':PROFILE['partitions'], 'offline':True, 'areas':[],
            'exclusions':['eMMC gaps and partition tables/PIT', 'eMMC boot0/boot1',
                          'RPMB, OTP/eFuse/TrustZone secrets', 'eMMC configuration'],
            'consistency':'Stationary lk2nd partition reads; not a complete physical eMMC capture'})

    def read(self, spec, dest, progress=lambda done: None):
        digest, done = hashlib.sha256(), 0
        prefix = PROFILE['lk2nd_boot_prefix_bytes']
        ranges = [('lk2nd', 0, prefix), ('boot', 0, spec['bytes'] - prefix)] if spec['name'] == 'BOOT' else [(spec['name'].lower(), 0, spec['bytes'])]
        with tempfile.TemporaryDirectory(prefix='t531-fetch-') as temporary:
            chunk_file = Path(temporary) / 'chunk.raw'
            for partition, offset, size in ranges:
                for start in range(offset, offset + size, self.maximum):
                    count = min(self.maximum, offset + size - start)
                    self.run('oem', 'read-partition', f'{partition}:{start}:{count}')
                    remote = self.run('oem', 'hash', 'sha256')
                    hashes = re.findall(r'(?<![0-9a-f])[0-9a-f]{64}(?![0-9a-f])', remote.lower())
                    require(len(hashes) == 1, 'Cannot verify staged data SHA256')
                    self.run('get_staged', str(chunk_file))
                    require(chunk_file.stat().st_size == count, 'Short fastboot chunk')
                    data = chunk_file.read_bytes()
                    require(hashlib.sha256(data).hexdigest() == hashes[0], 'Fastboot chunk hash mismatch')
                    dest.write(data)
                    digest.update(data)
                    done += count
                    progress(done)
                    chunk_file.unlink()
        require(done == spec['bytes'], 'Incorrect partition byte count')
        return digest.hexdigest()

    def hash(self, spec):
        return self.read(spec, NullSink())

    def write(self, spec, source, offset, digest, info):
        require(spec['name'] not in {'EMMC_USER', 'EMMC_BOOT0', 'EMMC_BOOT1'},
                'Raw eMMC restoration requires SSH rescue mode')
        with tempfile.TemporaryDirectory(prefix='t531-flash-') as tmp:
            image = Path(tmp) / 'image.raw'
            with source.open('rb') as src, image.open('wb') as dst:
                src.seek(offset)
                remaining = spec['bytes']
                while remaining:
                    data = src.read(min(MIB, remaining))
                    require(data, 'Short restoration source')
                    dst.write(data)
                    remaining -= len(data)
            require(hash_range(image) == digest, 'Restoration source changed')
            if spec['name'] == 'BOOT':
                # fastboot flash boot addresses the payload, never the lk2nd prefix.
                prefix = PROFILE['lk2nd_boot_prefix_bytes']
                local_prefix = hash_range(image, 0, prefix)
                with tempfile.TemporaryFile() as current:
                    # Read only the prefix through the ordinary chunk protocol.
                    original = dict(spec, name='LK2ND_PREFIX', bytes=prefix)
                    original['name'] = 'LK2ND'  # Not a flash target; read uses its lower-case alias.
                    actual = self.read(original, current)
                require(actual == local_prefix, 'BOOT prefix differs; full BOOT restoration needs SSH rescue')
                payload = Path(tmp) / 'payload.raw'
                with image.open('rb') as src, payload.open('wb') as dst:
                    src.seek(prefix)
                    shutil.copyfileobj(src, dst, MIB)
                image = payload
            validate_same(info, self.inspect())
            self.run('-S', '16M', 'flash', spec['name'].lower(), str(image), timeout=3600)
            require(self.hash(spec) == digest, 'RESTORE READBACK MISMATCH; do not reboot')


def backend(args):
    return SSH(args) if args.backend == 'ssh' else LK2nd(args)


def load_manifest(root):
    manifest = json.loads(asset_path(root, 'manifest.json').read_text())
    require(isinstance(manifest, dict) and manifest.get('format') == 1, 'Unsupported backup format')
    require(isinstance(manifest.get('assets'), list) and isinstance(manifest.get('selection'), list),
            'Invalid backup manifest lists')
    for entry in manifest['assets']:
        require(isinstance(entry, dict) and isinstance(entry.get('spec'), dict) and
                isinstance(entry.get('name'), str) and isinstance(entry.get('file'), str) and
                isinstance(entry.get('sha256'), str) and
                re.fullmatch('[0-9a-f]{64}', entry['sha256']), 'Invalid backup asset record')
    validate_inventory(manifest['device'])
    return manifest


def verify(root, manifest):
    require(manifest.get('status') == 'complete', 'Backup is incomplete; use backup --resume')
    assets = manifest['assets']
    require(assets and len({a['name'] for a in assets}) == len(assets), 'Missing/duplicate backup assets')
    available = {p['name']:p for p in specs(manifest['device'], ','.join(a['name'] for a in assets))}
    require(manifest['selection'] == list(available.values()), 'Incomplete or inconsistent backup selection')
    for entry in assets:
        require(entry['spec'] == available[entry['name']], 'Manifest geometry/target mismatch')
        path = asset_path(root, entry['file'])
        require(path.stat().st_size == entry['spec']['bytes'], 'Wrong image size: ' + entry['name'])
        require(hash_range(path) == entry['sha256'], 'Bad checksum: ' + entry['name'])
    print(f"Verified {len(assets)} images; coverage: {manifest['coverage']}")


def backup(args):
    remote = backend(args)
    info = remote.inspect()
    require(info['offline'], info.get('offline_reason', 'Internal storage must be offline'))
    selected = specs(info, args.partitions)
    root = private_dir(args.output)
    with lock(root):
        path = root / 'manifest.json'
        if path.exists():
            require(args.resume, 'Backup already exists; use a new directory or --resume')
            manifest = load_manifest(root)
            validate_same(manifest['device'], info)
            require(manifest['selection'] == selected, 'Resume selection differs from the original backup')
        else:
            require(not args.resume, 'Nothing to resume')
            manifest = {'format':1, 'created_utc':datetime.now(timezone.utc).isoformat(),
                        'status':'incomplete', 'origin':'current-device-state',
                        'provenance':args.provenance, 'device':info, 'selection':selected,
                        'coverage':('user-area-and-emmc-boot-areas' if args.partitions is None and args.backend == 'ssh'
                                    else 'selected-partitions' if args.partitions else 'all-lk2nd-exposed-partitions'),
                        'assets':[]}
            atomic_json(path, manifest)
        total = sum(e['bytes'] for e in selected)
        require(shutil.disk_usage(root).free > total - sum(e['spec']['bytes'] for e in manifest['assets']) + 64*MIB,
                'Not enough local free space for this selection')
        (root / 'images').mkdir(mode=0o700, exist_ok=True)
        print(f"Backup · SM-T531 · device {fingerprint(info)}\nDirectory: {root}\nCurrent state; not automatically factory stock.")
        for spec in selected:
            entry = next((a for a in manifest['assets'] if a['name'] == spec['name']), None)
            if entry:
                source = asset_path(root, entry['file'])
                print('  Rechecking ' + spec['name'] + ' locally and on the device…', flush=True)
                require(hash_range(source) == entry['sha256'] == remote.hash(spec),
                        'Completed image/source changed; resume would mix snapshots')
                print('  ' + spec['name'] + ' already verified against the device')
                continue
            final = asset_path(root, 'images/' + spec['name'] + '.raw')
            partial = asset_path(root, 'images/' + spec['name'] + '.raw.partial')
            progress = Progress(spec['name'], spec['bytes'])
            with partial.open('wb') as dest:
                digest = remote.read(spec, dest, progress)
                dest.flush()
                os.fsync(dest.fileno())
            require(hash_range(partial) == digest, 'Local readback checksum mismatch')
            partial.replace(final)
            directory_fd = os.open(final.parent, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
            manifest['assets'].append({'name':spec['name'], 'spec':spec,
                                       'file':str(final.relative_to(root)), 'sha256':digest})
            atomic_json(path, manifest)
            progress.finish()
        validate_same(info, remote.inspect())
        manifest['status'] = 'complete'
        atomic_json(path, manifest)
        verify(root, manifest)
        print('Backup complete. Exclusions are recorded in manifest.json.')


def restore_source(root, manifest, spec):
    direct = next((a for a in manifest['assets'] if a['name'] == spec['name']), None)
    if direct:
        return asset_path(root, direct['file']), 0, direct['sha256']
    raw = next((a for a in manifest['assets'] if a['name'] == 'EMMC_USER'), None)
    require(raw and spec['name'] in {p['name'] for p in PROFILE['partitions']},
            'Selected partition is not present in this backup')
    part = next(p for p in PROFILE['partitions'] if p['name'] == spec['name'])
    source = asset_path(root, raw['file'])
    offset = part['start_sector'] * PROFILE['sector_bytes']
    return source, offset, hash_range(source, offset, spec['bytes'])


def restore(args):
    root = args.directory.resolve()
    with lock(root):
        manifest = load_manifest(root)
        verify(root, manifest)
        remote = backend(args)
        info = remote.inspect()
        validate_same(manifest['device'], info)
        require(info['offline'], 'Internal storage must be offline')
        selected = specs(info, args.partitions)
        require(not any(s['name'].startswith('EMMC_BOOT') for s in selected),
                'eMMC boot-area writes are deliberately unsupported')
        require('EMMC_USER' not in {s['name'] for s in selected} or len(selected) == 1,
                'Whole user-area restoration cannot be mixed with partition writes')
        plan = [(s, *restore_source(root, manifest, s)) for s in selected]
        print(f'Restore plan · same device {fingerprint(info)}')
        for spec, _, _, digest in plan:
            print(f"  {spec['name']:<14} {spec['bytes'] / MIB:9.2f} MiB  SHA256 {digest[:12]}…")
        if not args.execute:
            print('PLAN ONLY. No device writes. Add --execute for an explicit restoration.')
            return
        require(args.critical or not any(s['name'] in CRITICAL for s in selected),
                'This selection affects boot/radio/factory state; add --critical only after reviewing the plan')
        token = 'RESTORE-' + fingerprint(info)
        if args.confirm:
            require(args.confirm == token, 'Confirmation does not match this device')
        else:
            require(sys.stdin.isatty(), 'Use --confirm ' + token + ' for non-interactive restoration')
            require(input('Type ' + token + ' to write: ').strip() == token, 'Cancelled')
        journal = {'started_utc':datetime.now(timezone.utc).isoformat(),
                   'selection':[s['name'] for s in selected], 'completed':[], 'status':'incomplete'}
        atomic_json(root / 'restore-last.json', journal)
        for spec, source, offset, digest in plan:
            validate_same(info, remote.inspect())
            remote.write(spec, source, offset, digest, info)
            journal['completed'].append(spec['name'])
            atomic_json(root / 'restore-last.json', journal)
        journal['status'] = 'verified'
        atomic_json(root / 'restore-last.json', journal)
        print('Restoration read back and verified. No automatic reboot.')


def arguments(argv=None):
    parser = argparse.ArgumentParser(prog="backup-stock", description=__doc__, epilog='No implicit reboot, flash, erase, unlock, or partition-table modification.')
    subs = parser.add_subparsers(dest='action', required=True)
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument('--backend', choices=('ssh', 'lk2nd'), default='ssh')
    common.add_argument('--host', help='Root SSH destination; normal host-key verification is enforced')
    known = ROOT.parent / 'private/known_hosts'
    common.add_argument('--known-hosts', type=Path, default=known if known.is_file() else None)
    common.add_argument('--serial', help='Explicit fastboot serial when more than one device is connected')
    subs.add_parser('inspect', parents=[common], help='Read-only device/transport preflight')
    cap = subs.add_parser('backup', parents=[common], help='Capture current storage with checksums')
    cap.add_argument('--output', type=Path, default=ROOT / 'backup_stock' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
    cap.add_argument('--partitions', help='Comma-separated uppercase names; default captures all accessible storage')
    cap.add_argument('--resume', action='store_true', help='Resume completed images only after comparing them to the device again')
    cap.add_argument('--provenance', default='Current modified device; factory-stock origin not established')
    check = subs.add_parser('verify', help='Offline local integrity check')
    check.add_argument('directory', type=Path)
    recover = subs.add_parser('restore', parents=[common], help='Plan first; writing requires --execute and device confirmation')
    recover.add_argument('directory', type=Path)
    recover.add_argument('--partitions', required=True, help='Explicit names, or EMMC_USER over SSH for complete user-area restoration')
    recover.add_argument('--execute', action='store_true')
    recover.add_argument('--critical', action='store_true', help='Acknowledge boot/radio/NV/full-device risk')
    recover.add_argument('--confirm', help='Typed RESTORE-devicefingerprint token, not a bypass of identity checks')
    return parser.parse_args(argv)


def main(argv=None):
    os.umask(0o077)
    args = arguments(argv)
    if args.action == 'inspect':
        info = backend(args).inspect()
        print(f"SM-T531 · {info['backend']} · device {fingerprint(info)}\n"
              f"{len(info['partitions'])} verified partitions · storage offline: {info['offline']}")
        if not info['offline']:
            print(info['offline_reason'])
        print('Excluded: ' + '; '.join(info['exclusions']))
    elif args.action == 'backup':
        backup(args)
    elif args.action == 'verify':
        root = args.directory.resolve()
        with lock(root):
            verify(root, load_manifest(root))
    elif args.action == 'restore':
        restore(args)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print('\nInterrupted. An unfinished backup is not complete; use --resume to recheck it.', file=sys.stderr)
        sys.exit(130)
    except subprocess.TimeoutExpired:
        print('Error: transport timed out; the operation was not confirmed complete.', file=sys.stderr)
        sys.exit(1)
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
