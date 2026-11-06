#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
project=$PWD
work=${WORK_DIR:-$project/../build/sm-t531}
out=${KERNEL_OUT:-$work/out}
artifacts=${ARTIFACTS_DIR:-$work/artifacts/current}
cross=${CROSS_COMPILE:-arm-linux-gnueabihf-}
profile=${1:-main}
case "$profile" in main) prefix=;; bootstrap) prefix=bootstrap-;; *) echo 'Usage: build-initramfs.sh [main|bootstrap]'; exit 1;; esac
export LC_ALL=C TZ=UTC SOURCE_DATE_EPOCH=1790985600
mkdir -p "$work" "$artifacts"
[ -x "$out/usr/gen_init_cpio" ] || { echo 'Run make build first to obtain gen_init_cpio'; exit 1; }
# Pinned static Debian armhf BusyBox; no host-architecture binary in initramfs.
url='https://deb.debian.org/debian/pool/main/b/busybox/busybox-static_1.37.0-6+b9_armhf.deb'
sha=8b35210e08d559ecc0ddb660dd96f6f9694f69eb27f1dc608f5eeda56d94509e
mkdir -p "$work/busybox"
if [ ! -f "$work/busybox.deb" ]; then curl -fL "$url" -o "$work/busybox.deb"; fi
echo "$sha  $work/busybox.deb" | sha256sum -c -
dpkg-deb -x "$work/busybox.deb" "$work/busybox"
if [ "$profile" = bootstrap ]; then
    "${cross}gcc" -static -Os -Wall -Wextra -Werror scripts/volume-wait.c -o "$work/volume-wait"
    kexec_sha=67b1ac503aade45a54db0bc79228a8830a35d5d4f83cee932cff3e7a81a4a9ec
    [ -f "$work/kexec-tools.tar.xz" ] || curl -fL \
        https://cdn.kernel.org/pub/linux/utils/kernel/kexec/kexec-tools-2.0.29.tar.xz \
        -o "$work/kexec-tools.tar.xz"
    echo "$kexec_sha  $work/kexec-tools.tar.xz" | sha256sum -c -
    [ -d "$work/kexec-tools-2.0.29" ] || tar -xf "$work/kexec-tools.tar.xz" -C "$work"
    (cd "$work/kexec-tools-2.0.29";
     ./configure --host="${cross%-}" --without-zlib --without-lzma --without-xen \
        CFLAGS=-Os LDFLAGS=-static;
     make -j"${JOBS:-8}")
fi
# gen_init_cpio writes device nodes without root privileges.
python3 - "$work" "$project" "$profile" > "$work/initramfs.list" <<'PYLIST'
import subprocess,sys
work,project,profile=sys.argv[1:]
for directory in ['bin','sbin','dev','proc','sys','run','tmp','newroot']:
    print(f'dir /{directory} 755 0 0')
print('nod /dev/console 600 0 0 c 5 1')
print('nod /dev/null 666 0 0 c 1 3')
print(f'file /init {project}/scripts/init 755 0 0')
print(f'file /init-usblog {project}/scripts/init-usblog 755 0 0')
print(f'file /bin/busybox {work}/busybox/usr/bin/busybox 755 0 0')
if profile == 'bootstrap':
    print(f'file /bin/kexec {work}/kexec-tools-2.0.29/build/sbin/kexec 755 0 0')
    print(f'file /kexec-sd.sh {project}/scripts/kexec-sd.sh 755 0 0')
    print(f'file /bootstrap-rescue {project}/scripts/bootstrap-rescue.sh 755 0 0')
    print(f'file /bin/volume-wait {work}/volume-wait 755 0 0')
    print(f'file /bin/bootstrap-command {project}/scripts/bootstrap-command.sh 755 0 0')
    for command in ['boot-sd','mount-sd','umount-sd','mount-internal-boot','save-logs']:
        print(f'slink /bin/{command} bootstrap-command 777 0 0')
apps=subprocess.check_output(['qemu-arm',work+'/busybox/usr/bin/busybox','--list'],text=True)
for app in sorted(apps.split()):
    if app not in ('busybox','kexec'): print(f'slink /bin/{app} busybox 777 0 0')
PYLIST
"$out/usr/gen_init_cpio" -t "$SOURCE_DATE_EPOCH" "$work/initramfs.list" | gzip -n -9 > "$artifacts/${prefix}initramfs.cpio.gz"
