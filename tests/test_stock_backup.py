"""Backup fault tests: synthetic images and subprocess mocks, no device writes."""
from contextlib import redirect_stdout
from copy import deepcopy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools/stock-backup' / filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


b = module('stock_backup', 'backup.py')
a = module('stock_agent', 'agent.py')
CID = 'a' * 32  # Synthetic fixture; never a real device identity.


def inventory():
    return dict(backend='ssh', compatible=b.PROFILE['compatible'], model='SM-T531',
                identity=CID, identity_kind='emmc-cid', offline=True,
                partitions=deepcopy(b.PROFILE['partitions']),
                areas=[dict(name='mmcblk0', bytes=b.PROFILE['user_area_bytes']),
                       dict(name='mmcblk0boot0', bytes=4194304),
                       dict(name='mmcblk0boot1', bytes=4194304)])


class FakeSSH:
    def __init__(self):
        self.data = b'\x5a' * 1024
        self.writes = []

    def inspect(self):
        return inventory()

    def read(self, spec, dest, progress):
        assert spec['name'] == 'FSC'
        dest.write(self.data)
        progress(len(self.data))
        return hashlib.sha256(self.data).hexdigest()

    def hash(self, spec):
        return hashlib.sha256(self.data).hexdigest()

    def write(self, *args):
        self.writes.append(args)


class StockBackup(unittest.TestCase):
    def capture(self, directory, remote):
        args = SimpleNamespace(output=directory, partitions='FSC', resume=False,
                               provenance='Synthetic test only', backend='ssh')
        with patch.object(b, 'backend', return_value=remote), redirect_stdout(io.StringIO()):
            b.backup(args)
        return b.load_manifest(directory)

    def test_live_geometry_includes_half_kib_userdata_remainder(self):
        # /proc/partitions rounds KiB: blindly multiplying it loses 512 bytes.
        last = b.PROFILE['partitions'][-1]
        self.assertEqual(last['bytes'] % 1024, 512)
        self.assertEqual(last['start_sector'] * 512 + last['bytes'] + 33 * 512,
                         b.PROFILE['user_area_bytes'])

    def test_wrong_board_geometry_and_identity_rejected(self):
        saved = inventory()
        live = deepcopy(saved)
        live['identity'] = 'b' * 32
        with self.assertRaisesRegex(RuntimeError, 'Different tablet'):
            b.validate_same(saved, live)
        live = deepcopy(saved)
        live['partitions'][0]['bytes'] -= 512
        with self.assertRaisesRegex(RuntimeError, 'geometry'):
            b.validate_inventory(live)

    def test_path_escape_and_symlink_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            with self.assertRaises(RuntimeError):
                b.asset_path(root, '../outside.raw')
            (root / 'image').symlink_to('/etc/passwd')
            with self.assertRaises(RuntimeError):
                b.asset_path(root, 'image')

    def test_capture_integrity_and_corruption(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            manifest = self.capture(root, FakeSSH())
            with redirect_stdout(io.StringIO()):
                b.verify(root, manifest)
            (root / manifest['assets'][0]['file']).write_bytes(b'X' * 1024)
            with self.assertRaisesRegex(RuntimeError, 'checksum'):
                b.verify(root, manifest)

    def test_missing_selected_asset_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            manifest = self.capture(root, FakeSSH())
            manifest['selection'].append(b.specs(inventory(), 'BOOT')[0])
            with self.assertRaisesRegex(RuntimeError, 'selection'):
                b.verify(root, manifest)

    def test_resume_rejects_changed_source(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            remote = FakeSSH()
            self.capture(root, remote)
            remote.data = b'Y' * 1024
            args = SimpleNamespace(output=root, partitions='FSC', resume=True, backend='ssh')
            with patch.object(b, 'backend', return_value=remote), redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(RuntimeError, 'changed'):
                    b.backup(args)

    def test_restore_plan_and_critical_gate_do_not_write(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            remote = FakeSSH()
            self.capture(root, remote)
            args = SimpleNamespace(directory=root, partitions='FSC', execute=False,
                                   critical=False, confirm=None)
            with patch.object(b, 'backend', return_value=remote), redirect_stdout(io.StringIO()):
                b.restore(args)
                self.assertEqual(remote.writes, [])
                args.execute = True
                with self.assertRaisesRegex(RuntimeError, 'critical'):
                    b.restore(args)
                self.assertEqual(remote.writes, [])

    def test_restore_confirmation_and_completed_journal(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            remote = FakeSSH()
            self.capture(root, remote)
            args = SimpleNamespace(directory=root, partitions='FSC', execute=True,
                                   critical=True, confirm='WRONG')
            with patch.object(b, 'backend', return_value=remote), redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(RuntimeError, 'Confirmation'):
                    b.restore(args)
                self.assertEqual(remote.writes, [])
                args.confirm = 'RESTORE-' + b.fingerprint(inventory())
                b.restore(args)
                self.assertEqual(len(remote.writes), 1)
                journal = json.loads((root / 'restore-last.json').read_text())
                self.assertEqual(journal['status'], 'verified')

    def test_lk2nd_boot_reassembly_and_transport_hash(self):
        lk = b.LK2nd.__new__(b.LK2nd)
        lk.maximum = 4
        pieces = {'lk2nd':b'LK2!', 'boot':b'PAYLOAD!'}
        state = {}

        def command(*args, **kwargs):
            if args[:2] == ('oem', 'read-partition'):
                name, offset, size = args[2].split(':')
                state['data'] = pieces[name][int(offset):int(offset)+int(size)]
            elif args[:2] == ('oem', 'hash'):
                return '(bootloader) ' + hashlib.sha256(state['data']).hexdigest()
            elif args[0] == 'get_staged':
                Path(args[1]).write_bytes(state['data'])
            else:
                self.fail('Unexpected or writing fastboot command')
            return ''

        lk.run = command
        dest = io.BytesIO()
        with patch.dict(b.PROFILE, lk2nd_boot_prefix_bytes=4):
            digest = lk.read(dict(name='BOOT', bytes=12), dest)
        self.assertEqual(dest.getvalue(), b'LK2!PAYLOAD!')
        self.assertEqual(digest, hashlib.sha256(dest.getvalue()).hexdigest())

    def test_failed_upload_never_touches_target(self):
        with tempfile.TemporaryDirectory() as d:
            target = Path(d) / 'synthetic-device'
            target.write_bytes(b'original')
            data = b'restored'
            for uploaded, expected in [(data[:3], hashlib.sha256(data).hexdigest()),
                                       (data, '0' * 64)]:
                with patch.object(a, 'check_board', return_value=CID), \
                     patch.object(a, 'offline'), \
                     patch.object(a, 'device', return_value=(target, len(data))), \
                     patch.object(a.sys, 'stdin', SimpleNamespace(buffer=io.BytesIO(uploaded))):
                    with self.assertRaises(RuntimeError):
                        a.write_image('mmcblk0p19', len(data), expected, CID)
                self.assertEqual(target.read_bytes(), b'original')

    def test_agent_stages_and_reads_back_synthetic_file(self):
        with tempfile.TemporaryDirectory() as d:
            target = Path(d) / 'synthetic-device'
            target.write_bytes(b'original')
            data = b'restored'
            digest = hashlib.sha256(data).hexdigest()
            with patch.object(a, 'check_board', return_value=CID), \
                 patch.object(a, 'offline'), \
                 patch.object(a, 'device', return_value=(target, len(data))), \
                 patch.object(a.sys, 'stdin', SimpleNamespace(buffer=io.BytesIO(data))):
                self.assertEqual(a.write_image('mmcblk0p19', len(data), digest, CID), digest)
            self.assertEqual(target.read_bytes(), data)

    def test_malformed_manifest_is_a_controlled_error(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / 'manifest.json').write_text('[]')
            with self.assertRaisesRegex(RuntimeError, 'format'):
                b.load_manifest(root)

    def test_lk2nd_bad_chunk_cannot_be_accepted(self):
        lk = b.LK2nd.__new__(b.LK2nd)
        lk.maximum = 4

        def command(*args, **kwargs):
            if args[:2] == ('oem', 'hash'):
                return '(bootloader) ' + '0' * 64
            if args[0] == 'get_staged':
                Path(args[1]).write_bytes(b'DATA')
            self.assertNotIn('flash', args)
            return ''

        lk.run = command
        with self.assertRaisesRegex(RuntimeError, 'hash mismatch'):
            lk.read(dict(name='FSC', bytes=4), io.BytesIO())
