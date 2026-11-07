"""Public synthetic vectors only; no factory calibration is read by tests."""
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('grip', ROOT / 'scripts/configure-grip.py')
grip = importlib.util.module_from_spec(spec)
spec.loader.exec_module(grip)


def vector(useful=1024, offset=3000, legacy=False):
    n = useful * 50000
    adc = (abs(n) // (8 * 65536)) * (-1 if n < 0 else 1)
    baseline = 2 * ((offset >> 6) * 3600 + (offset & 63) * 225) + adc
    return baseline, struct.pack('<3i', baseline - (300000 if legacy else 0), useful, offset)


class GripCalibration(unittest.TestCase):
    def test_current_and_legacy_formats(self):
        for legacy in (False, True):
            for useful in (-32768, -1, 0, 1, 32767):
                baseline, blob = vector(useful=useful, legacy=legacy)
                self.assertEqual(grip.decode_calibration(blob), baseline)

    def test_missing_malformed_or_inconsistent_data(self):
        for blob in (b'', b'\0' * 12, b'\0' * 13,
                     struct.pack('<3i', 400000, 32768, 3000),
                     struct.pack('<3i', 400000, 0, 3880),
                     struct.pack('<3i', 400000, 0, 1)):
            with self.assertRaises(ValueError):
                grip.decode_calibration(blob)

    def test_rule_is_idempotent_and_private(self):
        baseline, blob = vector()
        rule = grip.rule_for(grip.decode_calibration(blob))
        self.assertIn(f'ATTR{{in_capacitance0_calibbias}}="{-baseline}"', rule)
        self.assertNotIn('RUN', rule)
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / 'calibration.rules'
            grip.atomic_write(p, rule)
            grip.atomic_write(p, rule)
            self.assertEqual(p.read_text(), rule)
            self.assertEqual(p.stat().st_mode & 0o777, 0o600)
