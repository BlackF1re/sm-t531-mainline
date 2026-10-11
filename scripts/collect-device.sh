#!/usr/bin/env bash
set -euo pipefail
umask 077
serial=${ADB_SERIAL:-192.168.2.156:5555}
destination=${DEVICE_DATA_DIR:-/home/paul/t531/private/device}
repo=$(realpath "$(dirname "$0")/..")
mkdir -p "$destination"
destination=$(realpath "$destination")
case "$destination/" in "$repo/"*) echo 'Private data must be outside the repository'; exit 1;; esac
adb devices -l
case "$serial" in *:*) adb connect "$serial";; esac
adb -s "$serial" get-state >/dev/null
adb -s "$serial" shell id
adb -s "$serial" shell "su -c 'id'" | tr -d '\r' | rg -q 'uid=0'
model=$(adb -s "$serial" shell getprop ro.product.model | tr -d '\r')
[ "$model" = SM-T531 ] || { echo "Unexpected model; refusing collection: $model"; exit 1; }
[ ! -e "$destination/collection-complete" ] || { echo 'Existing collection: choose a new external destination'; exit 1; }
date -u +%FT%TZ > "$destination/collection-started"
remote() { adb -s "$serial" exec-out "su -c '$1'"; }
remote getprop > "$destination/getprop.txt"
for name in cpuinfo version cmdline meminfo iomem interrupts modules partitions mounts; do
    remote "cat /proc/$name" > "$destination/proc-$name.txt"
done
remote 'uname -a' > "$destination/uname.txt"
remote dmesg > "$destination/dmesg.txt"
remote 'cat /proc/bus/input/devices' > "$destination/input-devices.txt"
remote 'cat /proc/asound/cards' > "$destination/asound.txt" || true
remote 'cat /proc/config.gz' > "$destination/config.gz" || true
for command in 'dumpsys display' 'dumpsys input' 'dumpsys battery' 'getevent -lp'; do
    remote "$command" > "$destination/${command// /-}.txt" || true
done
remote 'ls -lR /dev/block /sys/class/mmc_host /sys/bus/mmc/devices /sys/bus/sdio/devices /sys/class/net /sys/bus/platform/devices' > "$destination/devices.txt"
remote 'for c in graphics backlight power_supply thermal input; do for d in /sys/class/$c/*; do echo ===$d; ls -l $d/; for f in $d/uevent $d/name $d/type $d/temp $d/modes $d/virtual_size $d/brightness $d/max_brightness; do [ ! -f $f ] || { echo ===$f; cat $f; }; done; done; done' > "$destination/classes.txt"
remote 'ls -ld /proc/device-tree /sys/firmware/devicetree/base /sys/firmware/fdt' > "$destination/dt-paths.txt" || true
if [ "$(remote 'if [ -f /sys/firmware/fdt ]; then echo yes; fi' | tr -d '\r')" = yes ]; then
    remote 'cat /sys/firmware/fdt' > "$destination/stock.dtb"
    dtc -I dtb -O dts "$destination/stock.dtb" -o "$destination/stock.dts"
elif [ "$(remote 'if [ -d /proc/device-tree ]; then echo yes; fi' | tr -d '\r')" = yes ]; then
    remote 'tar -cf - -C /proc/device-tree .' > "$destination/device-tree.tar"
    mkdir -p "$destination/device-tree"
    tar -xf "$destination/device-tree.tar" -C "$destination/device-tree"
    dtc -I fs -O dts "$destination/device-tree" -o "$destination/stock.dts"
fi
remote 'ls -l /dev/block/platform/*/by-name/*' > "$destination/by-name.txt"
# Resolve exact labels before reading; no guessed partition numbers and no writes.
for label in BOOT RECOVERY EFS MODEMST1 MODEMST2 FSG FSC PERSIST PERSDATA PARAM; do
    path=$(remote "for p in /dev/block/platform/*/by-name/$label /dev/block/platform/*/by-name/${label,,}; do [ ! -e \"\$p\" ] || readlink -f \"\$p\"; done" | tr -d '\r' | sort -u)
    if [ -z "$path" ] && [[ "$label" != BOOT && "$label" != RECOVERY && "$label" != EFS ]]; then continue; fi
    [[ "$path" =~ ^/dev/block/mmcblk0p[0-9]+$ ]] || { echo "Cannot uniquely resolve $label"; exit 1; }
    block=${path##*/}
    sectors=$(remote "cat /sys/class/block/$block/size" | tr -d '\r')
    [[ "$sectors" =~ ^[0-9]+$ ]] && [ "$sectors" -gt 0 ]
    printf '%s %s %s\n' "$label" "$path" "$((sectors * 512))" >> "$destination/partition-map.txt"
    [ ! -e "$destination/$label.img" ] || { echo "Existing $label backup: preserve and verify manually"; exit 1; }
    remote "cat $path" > "$destination/$label.img.partial"
    [ "$(stat -c %s "$destination/$label.img.partial")" = "$((sectors * 512))" ] || { echo 'Backup size mismatch'; exit 1; }
    # Second independent full read verifies transport and image content.
    first=$(sha256sum "$destination/$label.img.partial" | cut -d' ' -f1)
    second=$(remote "cat $path" | sha256sum | cut -d' ' -f1)
    [ "$first" = "$second" ] || { echo 'Backup checksum mismatch'; exit 1; }
    mv "$destination/$label.img.partial" "$destination/$label.img"
done
(cd "$destination"; sha256sum *.img > SHA256SUMS; sha256sum -c SHA256SUMS)
date -u +%FT%TZ > "$destination/collection-complete"
echo "Private collection and verified backups: $destination"
echo 'Disable TCP ADB from the tablet after research: setprop service.adb.tcp.port -1; stop adbd; start adbd'
