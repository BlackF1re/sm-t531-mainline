#!/usr/bin/env python3
"""Validate Samsung SX9500 calibration and install a standard IIO udev rule."""
import argparse
from pathlib import Path
import os
import shutil
import struct
import subprocess
import tempfile

RULE = Path('/etc/udev/rules.d/70-t531-grip-calibration.rules')


def decode_calibration(blob):
    if len(blob) != 12:
        raise ValueError('Expected three little-endian signed 32-bit values')
    baseline, useful, offset = struct.unpack('<3i', blob)
    if baseline == 0 or not -32768 <= useful <= 32767 or not 0 < offset < 3880:
        raise ValueError('Missing or invalid Samsung calibration')
    # Old Samsung files store capacitance minus 300000; the vendor reader
    # explicitly recognizes this representation when baseline <= 100000.
    if baseline <= 100000:
        baseline += 300000
    numerator = useful * 50000
    adc = (abs(numerator) // (8 * 65536)) * (-1 if numerator < 0 else 1)
    reference = 2 * ((offset >> 6) * 3600 + (offset & 63) * 225) + adc
    if baseline <= 0 or abs(baseline - reference) > 500:
        raise ValueError('Calibration does not match the Samsung small-range model')
    return baseline


def rule_for(baseline):
    return ('# SX9500 board calibration; private, do not commit.\n'
            'ACTION=="add", SUBSYSTEM=="iio", ATTR{name}=="sx9500", '
            f'ATTR{{in_capacitance0_calibbias}}="{-baseline}"\n')


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=path.parent,
                                         prefix='.' + path.name, delete=False) as stream:
            temp = Path(stream.name)
            os.fchmod(stream.fileno(), 0o600)
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
    finally:
        if temp is not None:
            temp.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('calibration', type=Path, help='Private Android grip_cal_data')
    action = parser.add_mutually_exclusive_group()
    action.add_argument('--output', type=Path, help='Write a private udev rule, without installing')
    action.add_argument('--install', action='store_true', help='Install and apply on SM-T531 as root')
    args = parser.parse_args()
    try:
        baseline = decode_calibration(args.calibration.read_bytes())
        rule = rule_for(baseline)
        if args.output:
            atomic_write(args.output, rule)
        if args.install:
            if os.geteuid() or b'samsung,matisse3g' not in Path(
                    '/proc/device-tree/compatible').read_bytes().split(b'\0'):
                raise ValueError('Installation requires root on SM-T531')
            targets = [p / 'in_capacitance0_calibbias'
                       for p in Path('/sys/bus/iio/devices').glob('iio:device*')
                       if (p / 'name').read_text().strip() == 'sx9500']
            if len(targets) != 1 or not targets[0].is_file():
                raise ValueError('One SX9500 with the calibrated-capacitance interface is required')
            previous_bias = targets[0].read_text()
            previous_rule = RULE.read_text() if RULE.exists() else None
            try:
                targets[0].write_text(str(-baseline))
                if int(targets[0].read_text()) != -baseline:
                    raise ValueError('Calibration readback mismatch')
                if previous_rule is not None and previous_rule != rule:
                    shutil.copy2(RULE, RULE.with_suffix('.rules.previous'))
                atomic_write(RULE, rule)
                subprocess.run(['udevadm', 'control', '--reload'], check=True)
            except (OSError, ValueError, subprocess.CalledProcessError):
                targets[0].write_text(previous_bias)
                if previous_rule is None:
                    RULE.unlink(missing_ok=True)
                else:
                    atomic_write(RULE, previous_rule)
                raise
        print('Calibration valid' + ('; installed and read back' if args.install else ''))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, str(error) + '\n')


if __name__ == '__main__':
    main()
