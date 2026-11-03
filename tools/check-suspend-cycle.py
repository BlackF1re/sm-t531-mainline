#!/usr/bin/python3
# SPDX-License-Identifier: MIT
"""One complete sleep/resume cycle; never enqueue the next cycle."""
import json,pathlib,subprocess,time,sys,struct,os
if len(sys.argv) not in (2,3) or (len(sys.argv)==3 and sys.argv[2] not in ('logind','power-key')):
 raise SystemExit('Usage: check-suspend-cycle.py NEW_OUTPUT_DIRECTORY [logind|power-key]')
assert 'samsung,matisse3g' in pathlib.Path('/proc/device-tree/compatible').read_bytes().decode().split('\0')
out=pathlib.Path(sys.argv[1]);out.mkdir(mode=0o700)
alarm=pathlib.Path('/sys/class/rtc/rtc0/wakealarm')
def clocks():return {'monotonic':time.monotonic(),'boottime':time.clock_gettime(time.CLOCK_BOOTTIME)}
def stats():
 return {k:int(v) for line in pathlib.Path('/sys/kernel/debug/suspend_stats').read_text().splitlines() if ':' in line for k,v in [line.split(':',1)] if v.strip().lstrip('-').isdigit()}
def emit(**v):print(json.dumps({'clocks':clocks(),**v}),flush=True)
mode=sys.argv[2] if len(sys.argv)>2 else 'logind'
rtc_seconds=int(os.environ.get('T531_RTC_SECONDS','30'))
assert 5 <= rtc_seconds <= 60
key_path=None
if mode=='power-key':
 devices=[p for p in pathlib.Path('/sys/class/input').glob('event*/device/name') if p.read_text().strip()=='pm8941_pwrkey']
 assert len(devices)==1, 'Expected one pm8941_pwrkey input device'
 key_path=pathlib.Path('/dev/input')/devices[0].parent.parent.name
def send_power_key():
 with key_path.open('wb',buffering=0) as key:
  def event(typ,code,value):key.write(struct.pack('@llHHi',0,0,typ,code,value))
  event(1,116,1);event(0,0,0);time.sleep(.15);event(1,116,0);event(0,0,0)
def display_on():
 return pathlib.Path('/sys/class/backlight/lcd-backlight/bl_power').read_text().strip()=='0'
def graphics_pids():
 return {name: subprocess.check_output(['pgrep','-u','1000','-x',name],text=True).split()
         for name in ('kwin_wayland','plasmashell')}
def check_rendering(phase):
 # A live compositor and advancing scanout can still display empty buffers.
 # Supply an executable pixel-readback check for the installed Mesa stack.
 checker=os.environ.get('T531_GPU_PIXEL_CHECK')
 if checker:
  with (out/('gpu-pixels-'+phase+'.log')).open('w') as log:
   subprocess.run([checker],stdout=log,stderr=subprocess.STDOUT,
                  check=True,timeout=40)
def graphics_health(since):
 health={}
 for label,extra in (('kernel',['-k']),('graphics',['_COMM=kwin_wayland','_COMM=plasmashell'])):
  text=subprocess.check_output(['journalctl','-b','--since','@'+str(int(since)),
                                '--no-pager','-o','cat',*extra],text=True)
  health[label]=[line for line in text.splitlines() if any(word in line for word in (
   'hangcheck detected gpu lockup','hangcheck recover!',
   'timeout waiting to drain ringbuffer','GL_CONTEXT_LOST','Context is lost.',
   'Unable to handle kernel','BUG:','WARNING:',
   'PM: failed to resume','Failed to restore graphics allocation',
   'Failed to release graphics lock for sleep'))]
 return health
realtime_started=time.time()
graphics_before=graphics_pids()
baseline_health=graphics_health(0)
(out/'graphics-health-before.json').write_text(json.dumps(baseline_health,indent=2)+'\n')
assert not any(baseline_health.values()), 'Boot already contains GPU/context/kernel faults'
check_rendering('before')
before=stats();started=clocks();(out/'before.json').write_text(json.dumps(dict(stats=before,clocks=started)))
assert pathlib.Path('/sys/class/rtc/rtc0/device/power/wakeup').read_text().strip()=='enabled'
alarm.write_text('0');alarm.write_text('+'+str(rtc_seconds))
assert alarm.read_text().strip()
(out/'armed-alarm.txt').write_text(alarm.read_text())
emit(event='armed',stats=before,mode=mode)
if mode=='power-key':
 # RTC resume can intentionally leave DPMS off. First establish an awake
 # display so this key tests sleep, rather than merely waking the screen.
 if not display_on():
  send_power_key();time.sleep(3)
  assert display_on() and stats()['success']==before['success']
  alarm.write_text('0');alarm.write_text('+'+str(rtc_seconds))
  started=clocks()
 send_power_key()
else:
 subprocess.run(['systemctl','suspend'],check=True)
# systemctl suspend is asynchronous. Wait for both kernel outcome and
# systemd-suspend completion before touching the RTC alarm or returning.
while True:
 current=stats()
 state=subprocess.check_output(['systemctl','show','systemd-suspend.service','-p','ActiveState','--value'],text=True).strip()
 completed=current['success']+current['fail']>before['success']+before['fail']
 if completed and state in ('inactive','failed'):break
 if time.clock_gettime(time.CLOCK_BOOTTIME)-started['boottime']>rtc_seconds+50:
  emit(event='timeout',stats=current,service=state)
  # Preserve a still armed alarm if a transition remains pending.
  raise SystemExit(1)
 time.sleep(.25)
# Preserve the backup alarm until the awake interval is verified.
finished=clocks()
residency=(finished['boottime']-started['boottime'])-(finished['monotonic']-started['monotonic'])
result={'before':before,'after':current,'suspended_seconds':residency,'service':state,'clocks':finished}
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');emit(event='completed',**result)
assert current['success']==before['success']+1 and current['fail']==before['fail']
assert all(current[k]==v for k,v in before.items() if k.startswith('failed_')), 'Suspend/resume phase error counter increased'
# A power-key wake is different from a background RTC wake: verify the
# screen can be woken without initiating another system suspend.
if mode=='power-key':
 time.sleep(3)
 result['display_on_after_rtc']=display_on()
 if not display_on():send_power_key();time.sleep(3)
 assert display_on()
 result['display_on_after_power_wake']=True
 (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
# Leave enough awake time for network recovery and to catch a re-suspend.
time.sleep(15)
assert stats()['success']==current['success'] and stats()['fail']==current['fail']
alarm.write_text('0')
check_rendering('after')
# Returning CPU/scanout counters alone does not prove a surviving GUI.
graphics_after=graphics_pids()
assert graphics_after==graphics_before, 'Graphical processes restarted during sleep check'
health=graphics_health(realtime_started)
(out/'graphics-health.json').write_text(json.dumps(health,indent=2)+'\n')
assert not any(health.values()), 'GPU/context/kernel fault during suspend check'
assert residency>3, f'Early wake: only {residency:.3f}s suspended'
(out/'SUCCESS').touch()
