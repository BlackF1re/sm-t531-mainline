#!/usr/bin/python3
# SPDX-License-Identifier: MIT
"""Read-only SM-T531 low-power inventory; no register writes."""
import json,pathlib,os,struct,time,gzip,mmap
P=pathlib.Path
def read(p):
 try:return P(p).read_text().strip()
 except OSError:return None
def fields(p,names):return {n:read(str(p)+'/'+n) for n in names}
def snapshot():
 assert b'samsung,matisse3g\0' in P('/proc/device-tree/compatible').read_bytes()
 r={'monotonic':time.monotonic(),'boottime':time.clock_gettime(time.CLOCK_BOOTTIME),'power':fields('/sys/power',['state','mem_sleep','disk','suspend_stats/success','suspend_stats/fail']),'cpuidle':{},'rpm_stats':{},'runtime':{},'battery':fields('/sys/class/power_supply/pm8226-bms',['status','current_now','voltage_now','charge_now','capacity']),'charger_online':read('/sys/class/power_supply/smb358-usb/online')}
 for p in P('/sys/devices/system/cpu').glob('cpu[0-9]*/cpuidle/state*'):r['cpuidle'][str(p)]=fields(p,['name','desc','disable','usage','time','rejected','latency','residency'])
 for p in P('/sys/kernel/debug/qcom_stats').glob('*'):r['rpm_stats'][p.name]=read(p)
 for p in P('/sys/bus/platform/devices').glob('*'):
  if any(t in p.name for t in ['gpu','display','iommu','remoteproc','mmc','usb','phy']):r['runtime'][p.name]=fields(p/'power',['control','runtime_status','wakeup','runtime_active_time','runtime_suspended_time'])
 for n,p in {'genpd':'/sys/kernel/debug/pm_genpd/pm_genpd_summary','wakeup_sources':'/sys/kernel/debug/wakeup_sources','interrupts':'/proc/interrupts','regulators':'/sys/kernel/debug/regulator/regulator_summary'}.items():r[n]=read(p)
 # Stock master-stats-v2 documented APSS SRAM window; read only, bounded.
 try:
  fd=os.open('/dev/mem',os.O_RDONLY|os.O_SYNC)
  try:
   with mmap.mmap(fd,4096,flags=mmap.MAP_SHARED,prot=mmap.PROT_READ,offset=0xfc428000) as page:
    raw=page[0x150:0x150+52]
  finally:os.close(fd)
  vals=struct.unpack('<IIQQQQIII',raw)
  r['apss_master_stats']=dict(zip(['active_cores','num_shutdowns','shutdown_req','wakeup_ind','bringup_req','bringup_ack','wakeup_reason','last_sleep_transition','last_wake_transition'],vals))
 except (OSError,struct.error) as e:r['apss_master_stats_error']=str(e)
 try:
  config=gzip.decompress(P('/proc/config.gz').read_bytes()).decode()
  keys=('CONFIG_SUSPEND','CONFIG_HIBERNATION','CONFIG_PM_AUTOSLEEP','CONFIG_PM_WAKELOCKS','CONFIG_QCOM_MPM','CONFIG_QCOM_STATS','CONFIG_QCOM_RPM_MASTER_STATS','CONFIG_CPU_IDLE','CONFIG_QCOM_SPM','CONFIG_PM_DEBUG')
  r['kernel_config']={k:next((l for l in config.splitlines() if l.startswith(k+'=') or l=='# '+k+' is not set'),None) for k in keys}
 except OSError as e:r['kernel_config_error']=str(e)
 r['display_bridge_firmware_power']=read('/sys/module/tc358764/parameters/firmware_power')
 r['rtc_alarm']=read('/sys/class/rtc/rtc0/wakealarm')
 return r
if __name__=='__main__':print(json.dumps(snapshot(),indent=2))
