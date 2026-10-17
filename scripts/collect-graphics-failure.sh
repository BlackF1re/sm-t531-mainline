#!/usr/bin/env bash
# Collect evidence before resetting a compositor/GPU; never unload drivers.
set -euo pipefail
umask 077
[[ $EUID == 0 ]] || { echo 'Run as root on SM-T531'; exit 1; }
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
out=${1:?Usage: collect-graphics-failure.sh NEW_OUTPUT_DIRECTORY}
[[ ! -e $out ]] || { echo 'Output directory already exists'; exit 1; }
mkdir -m700 "$out"
cat /proc/sys/kernel/random/boot_id >"$out/boot-id.txt"
cat /proc/uptime >"$out/uptime.txt"
date -u --iso-8601=seconds >"$out/collected-at.txt"
dmesg >"$out/kernel-current.txt"
cat /proc/interrupts >"$out/interrupts.txt"
ps -eo pid,ppid,comm,stat,wchan:40 >"$out/tasks.txt"

# sysfs may already have been consumed by systemd-pstore. The bootstrap also
# archives the previous SD kernel's records before kexec reuses the RAM zone.
for name in sysfs systemd bootstrap rescue; do
    case "$name" in
        sysfs) source=/sys/fs/pstore ;;
        systemd) source=/var/lib/systemd/pstore ;;
        bootstrap) source=/var/log/t531-pstore ;;
        rescue) source=/var/log/t531-rescue/pstore ;;
    esac
    [[ -d $source ]] || continue
    mkdir "$out/pstore-$name"
    cp -a "$source/." "$out/pstore-$name/"
    printf '%s\t%s\n' "$name" "$source" >>"$out/pstore-sources.tsv"
done

for boot in current previous; do
    number=0
    [[ $boot != previous ]] || number=-1
    timeout -k 1s 10s journalctl -b "$number" --no-pager \
        >"$out/journal-$boot.txt" 2>"$out/journal-$boot.stderr" || true
done
journalctl --list-boots --no-pager >"$out/boots.txt"

for irq in /proc/irq/[0-9]*/smp_affinity_list; do
    printf '%s\t%s\n' "$irq" "$(cat "$irq")"
done >"$out/irq-affinity.tsv"
for state in /sys/devices/system/cpu/cpu[0-9]*/cpuidle/state*; do
    [[ -d $state ]] || continue
    printf '%s' "$state"
    for field in name disable usage time; do
        printf '\t%s=%s' "$field" "$(cat "$state/$field")"
    done
    printf '\n'
done >"$out/cpuidle.tsv"
for field in control runtime_status runtime_active_time runtime_suspended_time; do
    file=/sys/bus/platform/devices/fdb00000.gpu/power/$field
    [[ ! -r $file ]] || printf '%s=%s\n' "$field" "$(cat "$file")"
done >"$out/gpu-power.txt"
for field in min_freq max_freq cur_freq; do
    file=/sys/class/devfreq/fdb00000.gpu/$field
    [[ ! -r $file ]] || printf '%s=%s\n' "$field" "$(cat "$file")"
done >"$out/gpu-frequency.txt"

for pid in $(pgrep -u t531 -x 'phoc|kwin_wayland|phosh|plasmashell' || true); do
    cat "/proc/$pid/comm" >"$out/process-$pid-name.txt" 2>/dev/null || true
    # Whitelist loader/graphics settings; don't collect session credentials.
    tr '\0' '\n' <"/proc/$pid/environ" | \
        grep -E '^(LD_LIBRARY_PATH|LD_PRELOAD|LIBGL_DRIVERS_PATH|GBM_BACKENDS_PATH|FD_MESA_DEBUG|WLR_|KWIN_DRM_DEVICES)' \
        >"$out/process-$pid-graphics-env.txt" || true
    grep -E '/(libgallium|libEGL_mesa|libgbm|dri_gbm|msm-kms_dri)' \
        "/proc/$pid/maps" >"$out/process-$pid-graphics-maps.txt" || true
done

# The records may span several boots; timestamps alone are insufficient when
# the bootstrap RTC is unset. Keep boot IDs and source paths for attribution.
(
    cd "$out"
    find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum
) >"$out/SHA256SUMS"
sync -f "$out"
echo "Collected graphics failure evidence in $out"
