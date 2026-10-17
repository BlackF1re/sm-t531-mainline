#!/usr/bin/env python3
"""Compile the real battery-info getter and check standard temperature units."""
import argparse
from pathlib import Path
import re
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--source', type=Path, default=Path('.work/linux/drivers/power/supply/power_supply_core.c'))
p.add_argument('--out', type=Path, default=Path('.work/battery-temperature-validation'))
a = p.parse_args()
a.out.mkdir(parents=True, exist_ok=True)
s = a.source.read_text()
start = s.index('int power_supply_battery_info_get_prop(')
end = s.index('\nEXPORT_SYMBOL_GPL(power_supply_battery_info_get_prop)', start)
func = s[start:end]
fields = sorted(set(re.findall(r'info->(\w+)', func)))
props = sorted(set(re.findall(r'POWER_SUPPLY_PROP_\w+', func)))
pre = '#include <assert.h>\n#include <errno.h>\n#include <stdio.h>\n#include <limits.h>\n#include <stdbool.h>\n#define POWER_SUPPLY_TECHNOLOGY_UNKNOWN 0\n'
pre += 'enum power_supply_property {' + ','.join(props) + '};\n'
pre += 'union power_supply_propval { int intval; };\n'
pre += 'struct power_supply_battery_info { ' + ''.join('int ' + f + ';' for f in fields) + ' };\n'
guard_start = s.index('bool power_supply_battery_info_has_prop(')
guard_end = s.index('\nEXPORT_SYMBOL_GPL(power_supply_battery_info_has_prop)', guard_start)
pre += s[guard_start:guard_end] + '\n'
main = 'int main(void) { struct power_supply_battery_info i = {0}; union power_supply_propval v;\n'
for prop, field, value in [
    ('TEMP_AMBIENT_ALERT_MIN', 'temp_ambient_alert_min', -20),
    ('TEMP_AMBIENT_ALERT_MAX', 'temp_ambient_alert_max', 60),
    ('TEMP_ALERT_MIN', 'temp_alert_min', 0),
    ('TEMP_ALERT_MAX', 'temp_alert_max', 45),
    ('TEMP_MIN', 'temp_min', -5),
    ('TEMP_MAX', 'temp_max', 60),
]:
    main += f'i.{field}={value}; assert(!power_supply_battery_info_get_prop(&i, POWER_SUPPLY_PROP_{prop}, &v)); assert(v.intval=={value * 10}); assert(i.{field}=={value});\n'
    sentinel = 'INT_MIN' if field.endswith('min') else 'INT_MAX'
    main += f'i.{field}={sentinel}; v.intval=12345; assert(!power_supply_battery_info_has_prop(&i, POWER_SUPPLY_PROP_{prop})); assert(power_supply_battery_info_get_prop(&i, POWER_SUPPLY_PROP_{prop}, &v)==-EINVAL); assert(v.intval==12345 && i.{field}=={sentinel});\n'
main += 'puts("PASS: actual battery-info getter exports all six limits in deci-Celsius and preserves Celsius/undefined sentinels"); return 0; }\n'
source = a.out / 'getter.c'
source.write_text(pre + func + main)
exe = a.out / 'getter-host'
subprocess.run(['cc', '-fsanitize=undefined', '-fno-sanitize-recover=all', str(source), '-o', str(exe)], check=True)
subprocess.run([str(exe)], check=True)
arm = a.out / 'getter-arm'
subprocess.run(['arm-linux-gnueabihf-gcc', '-static', str(source), '-o', str(arm)], check=True)
subprocess.run(['qemu-arm', str(arm)], check=True)
