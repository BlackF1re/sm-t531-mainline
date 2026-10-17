#!/usr/bin/env python3
"""Exercise the actual Phosh brightness GtkScale and restore its prior value.

Run as the local desktop user with its session D-Bus environment. This changes
physical brightness briefly; coordinate exclusive display ownership first.
--expect-manual checks the SM-T531's unchanged manual logarithmic mapping.
"""
import argparse
import json
import math
from pathlib import Path
import subprocess
import time
from gi.repository import Gio, GLib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--expect-manual', action='store_true')
parser.add_argument('--read-i2c', action='store_true', help='Read LP8556 BRT/CTRL/status via sudo; status reads clear latched faults')
args = parser.parse_args()
flags = Gio.DBusCallFlags.NONE
session = Gio.bus_get_sync(Gio.BusType.SESSION, None)
address = session.call_sync('org.a11y.Bus', '/org/a11y/bus', 'org.a11y.Bus',
                            'GetAddress', None, None, flags, 3000, None).unpack()[0]
access = Gio.DBusConnection.new_for_address_sync(
    address, Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT |
    Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION, None, None)


def call(name, path, interface, method, parameters=None):
    return access.call_sync(name, path, interface, method, parameters,
                            None, flags, 3000, None).unpack()


names = call('org.freedesktop.DBus', '/org/freedesktop/DBus',
             'org.freedesktop.DBus', 'ListNames')[0]
applications = []
for name in names:
    if not name.startswith(':'):
        continue
    pid = call('org.freedesktop.DBus', '/org/freedesktop/DBus',
               'org.freedesktop.DBus', 'GetConnectionUnixProcessID',
               GLib.Variant('(s)', (name,)))[0]
    if Path(f'/proc/{pid}/comm').read_text().strip() == 'phosh':
        applications.append((name, pid))
assert len(applications) == 1, f'Expected one Phosh: {applications}'
name, pid = applications[0]


def value_properties(path):
    return call(name, path, 'org.freedesktop.DBus.Properties', 'GetAll',
                GLib.Variant('(s)', ('org.a11y.atspi.Value',)))[0]


paths = ['/org/a11y/atspi/accessible/root']
seen = set()
sliders = []
while paths:
    path = paths.pop()
    if path in seen:
        continue
    seen.add(path)
    assert len(seen) < 1500, 'Unexpectedly large accessibility tree'
    role = call(name, path, 'org.a11y.atspi.Accessible', 'GetRoleName')[0]
    if role == 'slider':
        props = value_properties(path)
        if props['MinimumValue'] == 0.0 and props['MaximumValue'] == 1.0:
            sliders.append(path)
    children = call(name, path, 'org.a11y.atspi.Accessible', 'GetChildren')[0]
    paths.extend(child for child_name, child in children if child_name == name)
assert len(sliders) == 1, f'Ambiguous unit-range brightness slider: {sliders}'
path = sliders[0]
backlight = Path('/sys/class/backlight/lcd-backlight')
maximum = int((backlight / 'max_brightness').read_text())
assert maximum == 255 and int((backlight / 'bl_power').read_text()) == 0
original_value = value_properties(path)['CurrentValue']
original_raw = int((backlight / 'brightness').read_text())
result = {'timestamp_unix': time.time(), 'phosh_pid': pid,
          'widget': path, 'original_widget': original_value,
          'original_raw': original_raw, 'observations': [],
          'physical_optical_acceptance': 'UNKNOWN'}


def set_value(value):
    call(name, path, 'org.freedesktop.DBus.Properties', 'Set',
         GLib.Variant('(ssv)', ('org.a11y.atspi.Value', 'CurrentValue',
                               GLib.Variant('d', value))))
    time.sleep(0.7)


def read_i2c():
    code = """import ctypes,fcntl,os,json
class Msg(ctypes.Structure):
 _fields_=[('addr',ctypes.c_uint16),('flags',ctypes.c_uint16),('len',ctypes.c_uint16),('buf',ctypes.c_void_p)]
class Xfer(ctypes.Structure):
 _fields_=[('msgs',ctypes.POINTER(Msg)),('nmsgs',ctypes.c_uint32)]
f=os.open('/dev/i2c-0',os.O_RDWR)
result={}
for reg in [0,1,2]:
 a=ctypes.create_string_buffer(bytes([reg]),1);b=ctypes.create_string_buffer(1)
 msgs=(Msg*2)(Msg(0x2c,0,1,ctypes.addressof(a)),Msg(0x2c,1,1,ctypes.addressof(b)))
 fcntl.ioctl(f,0x707,Xfer(msgs,2));result['%02x'%reg]=b.raw[0]
os.close(f);print(json.dumps(result))
"""
    return json.loads(subprocess.check_output(['sudo', '-n', 'python3', '-c', code], text=True))


try:
    for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
        set_value(fraction)
        result['observations'].append({
            'slider': fraction, 'widget': value_properties(path)['CurrentValue'],
            'brightness': int((backlight / 'brightness').read_text()),
            'actual': int((backlight / 'actual_brightness').read_text()),
            'power': int((backlight / 'bl_power').read_text()),
            'expected_manual': round(2 * (255 / 2) ** fraction)})
        if args.read_i2c:
            result['observations'][-1]['registers'] = read_i2c()
finally:
    set_value(original_value)
    # Direct sysfs diagnostics may have left the GUI target out of sync. Preserve
    # both the GUI preference and exact original hardware request in that case.
    if int((backlight / 'brightness').read_text()) != original_raw:
        subprocess.run(['sudo', '-n', 'python3', '-c',
                        'from pathlib import Path; import sys; '
                        'Path("/sys/class/backlight/lcd-backlight/brightness").write_text(sys.argv[1])',
                        str(original_raw)], check=True)
        time.sleep(0.7)
    result['restored'] = {'widget': value_properties(path)['CurrentValue'],
                          'brightness': int((backlight / 'brightness').read_text()),
                          'actual': int((backlight / 'actual_brightness').read_text())}
    print(json.dumps(result, indent=2), flush=True)
assert result['restored']['brightness'] == result['restored']['actual'] == original_raw
if args.expect_manual:
    for sample in result['observations']:
        assert sample['brightness'] == sample['actual'] == sample['expected_manual'], sample
        assert math.isclose(sample['widget'], sample['slider']) and sample['power'] == 0
        if args.read_i2c:
            assert sample['registers']['00'] == sample['expected_manual']
            assert sample['registers']['01'] == 0x85
