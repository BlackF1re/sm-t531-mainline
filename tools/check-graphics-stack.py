#!/usr/bin/env python3
"""Read-only qualification of the single installed SM-T531 graphics stack."""
import hashlib
import json
import os
from pathlib import Path
import subprocess

assert os.geteuid() == 0, 'Run as root'
assert b'samsung,matisse3g' in Path('/proc/device-tree/compatible').read_bytes().split(b'\0')
lock = json.loads(Path('/etc/t531/graphics-stack.lock.json').read_text())

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def mapped(name):
    pids = subprocess.check_output(['pgrep', '-u', '1000', '-x', name], text=True).split()
    assert len(pids) == 1, (name, pids)
    files = set()
    for line in Path('/proc', pids[0], 'maps').read_text().splitlines():
        fields = line.split(maxsplit=5)
        if len(fields) == 6 and fields[5].startswith('/'):
            if any(part in fields[5] for part in ('libgallium', 'libQt6Gui', 'libmobileshellplugin')):
                assert not fields[5].endswith(' (deleted)'), fields[5]
                files.add(fields[5])
    return files

assert Path('/proc/sys/kernel/osrelease').read_text().strip() == lock['kernel']
module = Path('/lib/modules', lock['kernel'], 'kernel/drivers/gpu/drm/msm/msm.ko')
assert sha(module) == lock['msm_sha256']
assert Path('/sys/module/msm/notes/.note.gnu.build-id').read_bytes()[16:36].hex() == lock['msm_build_id']
assert Path('/sys/module/msm/parameters/separate_gpu_kms').read_text().strip() == 'N'
assert 'clk_ignore_unused' not in Path('/proc/cmdline').read_text().split()
symbols = {line.split()[2] for line in Path('/proc/kallsyms').read_text().splitlines() if len(line.split()) >= 3}
for function in ('ocmem_suspend_late', 'ocmem_resume_early', 'qcom_mpm_disable_wake_irq',
                 'ci_hdrc_msm_suspend', 'qcom_usb_hs_phy_suspend_late', 'msm8226_noc_suspend_late'):
    assert function in symbols, function
shell, kwin = mapped('plasmashell'), mapped('kwin_wayland')
qt = f"/opt/t531-graphics/qt-{lock['qt_gui_sha256'][:16]}/libQt6Gui.so.{lock['qt_gui_version']}"
plugin = '/usr/lib/arm-linux-gnueabihf/qt6/qml/org/kde/plasma/private/mobileshell/libmobileshellplugin.so'
assert qt in shell and sha(qt) == lock['qt_gui_sha256']
assert plugin in shell and sha(plugin) == lock['mobileshell_sha256']
assert any(path.startswith('/opt/t531-graphics/' + lock['mesa_bundle'] + '/libgallium') for path in shell)
assert any(path.startswith('/usr/lib/arm-linux-gnueabihf/libgallium-' + lock['kwin_mesa_package']) for path in kwin)
mesa = Path('/opt/t531-graphics', lock['mesa_bundle'])
subprocess.run(['sha256sum', '--quiet', '-c', 'libraries.sha256'], cwd=mesa, check=True)
assert subprocess.check_output(['dpkg-query', '-W', '-f=${Version}', 'plasma-mobile'], text=True) == lock['plasma_mobile_package']
for name, expected in (('plasmashell', lock['shell_fd_mesa_debug']), ('kwin_wayland', lock['kwin_fd_mesa_debug'])):
    pid = subprocess.check_output(['pgrep', '-u', '1000', '-x', name], text=True).strip()
    env = dict(item.split(b'=', 1) for item in Path('/proc', pid, 'environ').read_bytes().split(b'\0') if b'=' in item)
    assert env.get(b'FD_MESA_DEBUG', b'').decode() == expected
    assert not any(key.startswith((b'FD3_DIAG_', b'IR3_SHADER_DEBUG')) for key in env)
assert Path('/proc/device-tree/soc/mmc@f98a4900/broken-cd').exists()
assert not Path('/proc/device-tree/soc/mmc@f98a4900/cd-gpios').exists()
bms_wake = Path('/sys/class/power_supply/pm8226-bms/power/wakeup')
assert not bms_wake.exists() or bms_wake.read_text().strip() == 'disabled'
actions = set()
for p in Path('/proc').glob('[0-9]*'):
    try:
        if 'powerdevil' not in (p/'cmdline').read_bytes().decode(errors='replace'):
            continue
        if (p/'status').read_text().split('Uid:')[1].split()[0] != '1000':
            continue
        actions.update(line.split(maxsplit=5)[5] for line in (p/'maps').read_text().splitlines()
                       if 'powerdevil_suspendsessionaction.so' in line)
    except (OSError, IndexError):
        continue
assert actions and all(b'Not suspending because a suspend is in progress' in Path(p).read_bytes()
                       for p in actions), 'PowerDevil transition guard missing'
for unit in ('t531-kernel-trial-restore.service', 't531-sd-cd-fix-guard.service',
             't531-sleep-stack-guard.service'):
    assert subprocess.run(['systemctl', 'is-enabled', '--quiet', unit],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0, unit
probe = json.loads(subprocess.check_output(['/usr/local/libexec/t531-drm-probe', '--require-unified'], text=True))
health = subprocess.check_output(['journalctl', '-b', '--no-pager', '-o', 'cat', '-k'], text=True)
for error in ('hangcheck detected gpu lockup', 'hangcheck recover!', 'PM: failed to resume',
              'Failed to restore graphics allocation', 'Failed to release graphics lock for sleep', 'BUG:', 'WARNING:'):
    assert error not in health, error
print(json.dumps({'qualified': True, 'kernel': lock['kernel'], 'unified_drm': probe,
                  'qt_depth_discard': True, 'shell_cache': True, 'mesa_checksums': True,
                  'kernel_resume_callbacks': True, 'powerdevil_transition_guard': True,
                  'card_detect_polling': True, 'no_bms_software_wakeup': True,
                  'legacy_trial_guards_disabled': True, 'no_logged_kernel_gpu_resume_fault': True}, indent=2))
