from pathlib import Path
import ctypes,fcntl,json,os,platform,time
class Msg(ctypes.Structure):
    _fields_=[('addr',ctypes.c_uint16),('flags',ctypes.c_uint16),('len',ctypes.c_uint16),('buf',ctypes.c_void_p)]
class Xfer(ctypes.Structure):
    _fields_=[('msgs',ctypes.POINTER(Msg)),('nmsgs',ctypes.c_uint32)]
f=os.open('/dev/i2c-0',os.O_RDWR)
def rd(reg):
    a=ctypes.create_string_buffer(bytes([reg]),1); b=ctypes.create_string_buffer(1)
    msgs=(Msg*2)(Msg(0x2c,0,1,ctypes.addressof(a)),Msg(0x2c,1,1,ctypes.addressof(b)))
    fcntl.ioctl(f,0x707,Xfer(msgs,2)); return b.raw[0]
b=Path('/sys/class/backlight/lcd-backlight')
def get(n): return int((b/n).read_text())
orig=get('brightness')
assert get('bl_power')==0, 'Display must already be enabled'
assert get('max_brightness')==255
result={'device':Path('/proc/device-tree/model').read_bytes().rstrip(b'\0').decode(),'kernel':platform.release(),'timestamp_unix':time.time(),'original_brightness':orig,'status_read_clears_latched_faults':True,'observations':[],'physical_acceptance':'UNKNOWN'}
try:
    for level in [2,4,8,16,23,32,64,96,128,160,192,224,255,192,128,64,23,2]:
        (b/'brightness').write_text(str(level))
        time.sleep(0.6)
        sample={'requested':level,'sysfs':get('brightness'),'actual':get('actual_brightness'),'bl_power':get('bl_power'),'registers':{'%02x'%r:rd(r) for r in [0,1,2,0xa0,0xa1,0xa2,0xa3,0xa4,0xa5]}}
        result['observations'].append(sample)
        print(json.dumps(sample),flush=True)
        assert sample['sysfs']==sample['actual']==sample['registers']['00']==level, 'Brightness changed or failed to reach hardware'
        assert sample['bl_power']==0 and sample['registers']['01']==0x85, 'Backlight unexpectedly off'
finally:
    (b/'brightness').write_text(str(orig)); time.sleep(0.6)
    result['restored']={'brightness':get('brightness'),'actual':get('actual_brightness'),'BRT':rd(0),'CTRL':rd(1),'power':get('bl_power')}
    print(json.dumps({'result':result}),flush=True)
    os.close(f)
