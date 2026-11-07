#!/usr/bin/env python3
"""Check actual kernel battery C functions with mocked I/O, host UBSan and ARM."""
from fractions import Fraction
from pathlib import Path
import argparse
import os
import re
import subprocess

project = Path(__file__).resolve().parents[1]
sources = Path(os.environ.get('SOURCES_DIR', project.parent / 'sources'))
linux = Path(os.environ.get('KERNEL_SRC', sources / 'linux-mainline'))
work = Path(os.environ.get('WORK_DIR', project.parent / 'build/sm-t531'))

parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('--linux', type=Path, default=linux)
parser.add_argument('--vendor', type=Path, required=True, help='Samsung 6800mAh batterydata C source (not bundled)')
parser.add_argument('--out', type=Path, default=work / 'battery-validation')
a = parser.parse_args()
a.out.mkdir(parents=True, exist_ok=True)

def block(text, start):
    begin = text.index(start)
    opening = text.index('{', begin)
    depth = 1
    end = opening + 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[begin:end]

bms = (a.linux / 'drivers/power/supply/qcom_pm8226_bms.c').read_text()
iadc = (a.linux / 'drivers/iio/adc/qcom-spmi-iadc.c').read_text()
core = (a.linux / 'drivers/power/supply/power_supply_core.c').read_text()
profile = (a.linux / 'arch/arm/boot/dts/qcom/qcom-msm8226-samsung-matisse-battery.dtsi').read_text()
vendor = a.vendor.read_text().split('static struct pc_temp_ocv_lut pc_temp_ocv = {', 1)[1].split('\n};', 1)[0]
temps = [int(v) for v in re.search(r'\.temp\s*=\s*\{([^}]+)', vendor)[1].split(',')]
pcs = [int(v) for v in re.search(r'\.percent\s*=\s*\{([^}]+)', vendor)[1].split(',')]
rows = [[int(v) for v in row.split(',')] for row in re.findall(r'\{([\d, ]+)\}', vendor.split('.ocv', 1)[1])]
assert len(temps) == 5 and len(rows) == len(pcs) == 31
profile_temps = [int(v) for v in re.findall(r'-?\d+', re.search(r'ocv-capacity-celsius\s*=\s*<([^>]+)>', profile)[1])]
assert profile_temps == temps
c_tables = ''
for i, temp in enumerate(temps):
    values = [(int(uv), int(pc)) for uv, pc in re.findall(r'<(\d+) (\d+)>', re.search(rf'ocv-capacity-table-{i}\s*=([^;]+);', profile)[1])]
    expected = [(row[i] * 1000, pc) for row, pc in zip(rows, pcs)]
    assert values == expected, f'Samsung table {i} changed'
    assert all(values[j][0] > values[j + 1][0] for j in range(30))
    c_tables += 'static const struct power_supply_battery_ocv_table table%d[] = {%s};\n' % (i, ','.join('{%d,%d}' % v for v in values))
print('PASS: all 155 Samsung OCV/capacity pairs and five temperatures preserved', flush=True)

# Use arbitrary-precision dimensional arithmetic as a separate reference.
cc_cases = [-(1 << 35), -(1 << 35) + 1, -10000000, -1, 0, 1, 10000000, (1 << 35) - 2, (1 << 35) - 1]
reference = [int(Fraction(raw * 542535 * 3291 * 56 * 1000000, 100000 * 3281 * 32764 * 3600 * 12200)) for raw in cc_cases]
cc_vectors = ','.join('{%dLL,%dLL}' % v for v in zip(cc_cases, reference))

preamble = r'''
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <errno.h>
typedef uint8_t u8; typedef uint16_t u16; typedef uint32_t u32; typedef uint64_t u64;
typedef int16_t s16; typedef int32_t s32; typedef int64_t s64;
typedef uint8_t __u8; typedef uint64_t __u64; typedef int64_t __s64;
#undef __always_inline
#define __always_inline inline
#define BIT(n) (1U << (n))
#define HZ 100
#define PM8226_BMS_HOLD 0x42
#define PM8226_BMS_HOLD_DATA BIT(0)
#define PM8226_BMS_CC 0x8a
#define PM8226_BMS_OCV 0x90
#define PM8226_BMS_VSENSE 0x98
#define IADC_REF_GAIN_MICRO_VOLTS 17857
#define IADC_IDEAL_RAW_GAIN 3291
#define IIO_CHAN_INFO_RAW 0
#define IIO_CHAN_INFO_SCALE 1
#define IIO_CHAN_INFO_CALIBSCALE 2
#define IIO_VAL_INT 1
#define IIO_VAL_INT_PLUS_MICRO 2
#define IIO_VAL_FRACTIONAL 3
#define POWER_SUPPLY_OCV_TEMP_MAX 20
#define DIV_ROUND_CLOSEST(x,d) (((x) + ((x) < 0 ? -(d)/2 : (d)/2)) / (d))
#define DIV_ROUND_CLOSEST_ULL(x,d) (((x) + (d)/2) / (d))
#define clamp_t(t,x,l,h) ((t)(x) < (t)(l) ? (t)(l) : ((t)(x) > (t)(h) ? (t)(h) : (t)(x)))
#define time_before(x,y) ((long)((x)-(y)) < 0)
#define dev_dbg(...) ((void)0)
struct mutex { int unused; }; struct delayed_work { int unused; };
struct completion { int unused; };
static void mutex_lock(struct mutex *m) { (void)m; }
static void mutex_unlock(struct mutex *m) { (void)m; }
static void usleep_range(int low, int high) { assert(low >= 62 && high >= low); }
static s64 div_s64(s64 n, int32_t d) { assert(d); return n/d; }
static unsigned long jiffies = 1000;
struct iio_channel { int raw, processed; };
static int iio_read_channel_raw(struct iio_channel *c, int *v) { *v = c->raw; return IIO_VAL_INT; }
static int iio_read_channel_processed(struct iio_channel *c, int *v) { *v = c->processed; return IIO_VAL_INT; }
struct regmap { u8 regs[256]; int calls, fail; };
static bool io_fail(struct regmap *m) { return ++m->calls == m->fail; }
static int regmap_read(struct regmap *m, unsigned int r, unsigned int *v) {
 if (io_fail(m)) return -EIO; *v = m->regs[r & 255]; return 0;
}
static int regmap_update_bits(struct regmap *m, unsigned int r, unsigned int mask, unsigned int v) {
 if (io_fail(m)) return -EIO; m->regs[r & 255] = (m->regs[r & 255] & ~mask) | (v & mask); return 0;
}
static int regmap_bulk_read(struct regmap *m, unsigned int r, void *p, size_t n) {
 if (io_fail(m)) return -EIO; memcpy(p, m->regs + (r & 255), n); return 0;
}
struct power_supply_battery_ocv_table { int ocv, capacity; };
struct power_supply_battery_info {
 int charge_full_design_uah;
 int ocv_temp[20];
 const struct power_supply_battery_ocv_table *ocv_table[20];
 int ocv_table_size[20];
};
struct power_supply { struct power_supply_battery_info *battery_info; };
struct iio_chan_spec { int channel; };
struct iio_dev { void *priv; };
static void *iio_priv(struct iio_dev *d) { return d->priv; }
static u16 test_adc_raw;
'''
parts = [preamble]
parts += [block(bms, 'struct pm8226_bms_sample {') + ';', block(bms, 'struct pm8226_bms {') + ';']
parts += [block(iadc, 'struct iadc_chip {') + ';']
parts += ['static int iadc_do_conversion(struct iadc_chip *p, int c, u16 *v) { (void)p; (void)c; *v = test_adc_raw; return 0; }']
parts += [block((a.linux / 'include/linux/bitops.h').read_text(), 'static __always_inline __s64 sign_extend64(')]
parts += [block((a.linux / 'include/linux/fixp-arith.h').read_text(), 'static inline int fixp_linear_interpolate(')]
parts += [block(core, 'int power_supply_ocv2cap_simple(')]
parts += [block(core, 'const struct power_supply_battery_ocv_table *\npower_supply_find_ocv2cap_table(')]
parts += [block(core, 'int power_supply_batinfo_ocv2cap(')]
parts += [block(bms, 'static int pm8226_bms_raw_to_uv('), block(bms, 'static s64 pm8226_bms_cc_to_uah(')]
parts += [block(bms, 'static int pm8226_bms_snapshot('), block(bms, 'static int pm8226_bms_sample(')]
parts += [block(iadc, 'static int iadc_read_raw('), c_tables]
parts += ['static const s64 cc_vectors[][2] = {' + cc_vectors + '};']
parts += [r'''
static void set_sample(struct regmap *m, u16 ocv, s64 cc, s16 vsense) {
 m->regs[0x90] = ocv; m->regs[0x91] = ocv >> 8;
 for (int i = 0; i < 5; i++) m->regs[0x8a+i] = (u64)cc >> (8*i);
 m->regs[0x98] = vsense; m->regs[0x99] = (u16)vsense >> 8;
 m->calls = m->fail = 0;
}
int main(void) {
 struct regmap map = {0};
 struct iio_channel ref625 = {.raw=31125}, ref1250 = {.raw=37508}, therm = {.processed=25000};
 struct pm8226_bms b = {.regmap=&map, .base=0x4000, .ref625=&ref625, .ref1250=&ref1250,
  .temperature=&therm, .rsense_uohm=12200, .gain_num=3291, .gain_den=3281};
 struct power_supply_battery_info info = {.charge_full_design_uah=6800000};
 const struct power_supply_battery_ocv_table *tables[] = {table0,table1,table2,table3,table4};
 int temperatures[] = {-20,0,25,40,60};
 for (int i=0;i<5;i++) {
  info.ocv_table[i]=tables[i]; info.ocv_table_size[i]=31; info.ocv_temp[i]=temperatures[i];
  for (int j=0;j<31;j++) assert(power_supply_batinfo_ocv2cap(&info,tables[i][j].ocv,temperatures[i])==tables[i][j].capacity);
 }
 for (unsigned int i=0;i<sizeof(cc_vectors)/sizeof(cc_vectors[0]);i++)
  assert(llabs(pm8226_bms_cc_to_uah(&b,cc_vectors[i][0])-cc_vectors[i][1])<=1);
 int uv; assert(!pm8226_bms_raw_to_uv(&b,39467,&uv)); assert(uv>=4325000 && uv<=4325500);
 ref1250.raw=ref625.raw; assert(pm8226_bms_raw_to_uv(&b,39467,&uv)==-ERANGE); ref1250.raw=37508;
 struct iadc_chip adc = {.gain=27788,.offset={24507,24507},.rsense={10000,12200}};
 struct iio_dev indio = {.priv=&adc}; struct iio_chan_spec ch = {.channel=1}; int value,value2;
 int raw_vectors[] = {0,24506,24507,24508,65535};
 for (unsigned int i=0;i<sizeof(raw_vectors)/sizeof(raw_vectors[0]);i++) {
  test_adc_raw=raw_vectors[i]; assert(iadc_read_raw(&indio,&ch,&value,&value2,IIO_CHAN_INFO_RAW)==IIO_VAL_INT);
  long long numerator=(long long)(test_adc_raw-24507)*17857*1000000;
  long long expected=numerator/((long long)3281*12200);
  assert(llabs((long long)value-expected)<=83);
  assert((value<0)==(test_adc_raw<24507)); assert((value>0)==(test_adc_raw>24507));
 }
 assert(iadc_read_raw(&indio,&ch,&value,&value2,IIO_CHAN_INFO_CALIBSCALE)==IIO_VAL_FRACTIONAL);
 assert(value==3291 && value2==3281);
 /* Exercise the actual snapshot function's read failures and prior hold state. */
 for (int hold=0;hold<=1;hold++) for (int fail=0;fail<=6;fail++) {
  u16 ocv; s64 cc; s16 vsense; set_sample(&map,0x9a1c,-123456,-20);
  map.regs[0x42]=0xa0|hold; map.fail=fail;
  int ret=pm8226_bms_snapshot(&b,&ocv,&cc,&vsense);
  assert(ret==(fail ? -EIO : 0));
  if (fail!=6) assert(map.regs[0x42]==(0xa0|hold));
  if (!fail) assert(ocv==0x9a1c && cc==-123456 && vsense==-20);
 }
 struct power_supply psy = {.battery_info=&info}; struct pm8226_bms_sample sample;
 /* Real model: discharge decreases remaining charge and reports negative current. */
 set_sample(&map,0x9a1c,0,100); map.regs[0x42]=0;
 assert(!pm8226_bms_sample(&b,&psy,&sample)); int before=sample.charge_uah; assert(sample.current_ua<0);
 jiffies+=1000; set_sample(&map,0x9a1c,10000000,100);
 assert(!pm8226_bms_sample(&b,&psy,&sample)); assert(sample.charge_uah<before);
 jiffies+=1000; set_sample(&map,0x9a1c,0,-100);
 assert(!pm8226_bms_sample(&b,&psy,&sample)); assert(sample.charge_uah==before && sample.current_ua>0);
 /* Actual sample-function expressions cross each signed36 boundary. */
 b.last_cc_raw=(1LL<<35)-2; b.accumulated_cc=1000;
 jiffies+=1000; set_sample(&map,0x9a1c,-(1LL<<35)+3,0);
 assert(!pm8226_bms_sample(&b,&psy,&sample)); assert(b.accumulated_cc==1005);
 b.last_cc_raw=-(1LL<<35)+3; b.accumulated_cc=1000;
 jiffies+=1000; set_sample(&map,0x9a1c,(1LL<<35)-2,0);
 assert(!pm8226_bms_sample(&b,&psy,&sample)); assert(b.accumulated_cc==995);
 /* A failed real snapshot must not commit counter history. */
 jiffies+=1000; set_sample(&map,0x9a1c,99,0); map.fail=4;
 assert(pm8226_bms_sample(&b,&psy,&sample)==-EIO && b.accumulated_cc==995 && !map.regs[0x42]);
 puts("PASS: actual C table helpers, voltage references, signed IADC, CC36 limits/wrap, charge direction and hold restoration");
 return 0;
}
''']
source = a.out / 'actual-battery-functions.c'
source.write_text('\n\n'.join(parts))
host = a.out / 'check-host'
subprocess.run(['cc', '-std=gnu11', '-O1', '-g', '-fsanitize=undefined,signed-integer-overflow', '-fno-sanitize-recover=all', str(source), '-o', str(host)], check=True)
subprocess.run([str(host)], check=True)
arm = a.out / 'check-arm'
subprocess.run(['arm-linux-gnueabihf-gcc', '-std=gnu11', '-O2', '-static', str(source), '-o', str(arm)], check=True)
subprocess.run(['qemu-arm', str(arm)], check=True)
print('PASS: host UBSan and ARMv7 executions completed', flush=True)
