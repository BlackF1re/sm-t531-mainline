#!/bin/bash
# Kernel-triggered, bounded private capture; no persistent polling daemon.
set -Eeuo pipefail
[[ $EUID == 0 && ${1:-} =~ ^devcd[0-9]+$ ]]
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
node=/sys/class/devcoredump/$1
[[ -r $node/data ]]
# The rule selects this device; verify again when running with root privileges.
[[ $(readlink -f "$node") == */fdb00000.gpu/* ]]
umask 077
out=/var/lib/t531/gpu-coredumps
install -d -m700 "$out"
stem=$(date -u +%Y%m%dT%H%M%SZ)-$1
trap 'rm -f -- "$out/$stem.txt.gz.new"' EXIT
# Never let an anomalous dump fill the SD rootfs.
head -c 33554432 "$node/data" | gzip -1 > "$out/$stem.txt.gz.new"
mv "$out/$stem.txt.gz.new" "$out/$stem.txt.gz"
dmesg > "$out/$stem.dmesg.txt"
uname -a > "$out/$stem.kernel.txt"
# Keep three bounded captures, never touch other project/private files.
mapfile -t old < <(find "$out" -maxdepth 1 -type f -name '????????T??????Z-devcd*.txt.gz' -printf '%f\n' | LC_ALL=C sort -r | tail -n +4)
for file in "${old[@]}"; do
 rm -f -- "$out/$file" "$out/${file%.txt.gz}.dmesg.txt" "$out/${file%.txt.gz}.kernel.txt"
done
