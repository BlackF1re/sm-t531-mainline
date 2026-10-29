import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('slots', Path(__file__).resolve().parents[1] / 'tools/graphics-ab/slots.py')
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)

def image(path, tag):
    path.mkdir(exist_ok=True)
    for name in ('zImage', 'initramfs.cpio.gz'):
        (path / name).write_bytes((tag + name).encode())
    (path / 'kexec.cmdline').write_text('root=LABEL=T531_ROOT ' + tag)
    (path / 'kernel.sha256').write_text(''.join(hashlib.sha256((path / f).read_bytes()).hexdigest() + '  ' + f + '\n' for f in ('zImage', 'initramfs.cpio.gz')))

class Slots(unittest.TestCase):
    def test_interrupted_conversion_and_atomic_selection(self):
        for stop in range(1, 6):
            with tempfile.TemporaryDirectory() as d:
                root = Path(d) / 'boot'; image(root, 'golden')
                original = {f: (root/f).read_bytes() for f in s.FILES}
                calls = 0
                def checkpoint():
                    nonlocal calls
                    calls += 1
                    self.assertEqual(original, {f: (root/f).read_bytes() for f in s.FILES})
                    if calls == stop:
                        raise InterruptedError()
                with self.assertRaises(InterruptedError):
                    s.initialize(root, 'golden', checkpoint)
                s.verify(root)
                s.initialize(root, 'golden')
                candidate = Path(d)/'candidate'; image(candidate, 'candidate')
                s.stage(root, candidate, 'trial')
                s.select(root, 'trial'); s.verify(root)
                self.assertEqual((root/'zImage').read_bytes(), (candidate/'zImage').read_bytes())
                s.select(root, 'golden')
                self.assertEqual(original, {f: (root/f).read_bytes() for f in s.FILES})

    def test_corruption_rejected_without_switch(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)/'boot'; image(root, 'golden'); s.initialize(root, 'golden')
            candidate=Path(d)/'candidate'; image(candidate, 'candidate'); s.stage(root,candidate,'trial')
            (root/'graphics-slots/trial/zImage').write_bytes(b'bad')
            with self.assertRaises(ValueError): s.select(root,'trial')
            self.assertEqual('graphics-slots/golden', (root/'graphics-current').readlink().as_posix())
            with self.assertRaises(ValueError): s.stage(root,candidate,'../bad')

class Retirement(unittest.TestCase):
    def test_only_verified_unselected_candidates_can_be_retired(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)/'boot'; image(root,'golden'); s.initialize(root,'golden')
            candidate=Path(d)/'candidate'; image(candidate,'candidate'); s.stage(root,candidate,'trial')
            with self.assertRaises(ValueError): s.retire(root,'golden',root)
            s.select(root,'trial')
            with self.assertRaises(ValueError): s.retire(root,'trial',candidate)
            s.select(root,'golden')
            wrong=Path(d)/'wrong'; image(wrong,'wrong')
            with self.assertRaises(ValueError): s.retire(root,'trial',wrong)
            self.assertTrue((root/'graphics-slots/trial').is_dir())
            s.retire(root,'trial',candidate)
            self.assertFalse((root/'graphics-slots/trial').exists())
            s.verify(root)

if __name__ == '__main__': unittest.main()
