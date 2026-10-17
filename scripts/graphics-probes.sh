#!/usr/bin/env bash
# Temporary probes for the GRAPHICS_TRACE build. Disabled unless perf records them.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run as root'; exit 1; }
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
trace=/sys/kernel/tracing
[[ -e $trace/kprobe_events ]] || { echo 'Boot GRAPHICS_TRACE=1 build first'; exit 1; }
for event in blit blit_end update update_end wait wait_end; do
    [[ ! -d $trace/events/t531/$event ]] || { echo "Existing probe $event; refusing replacement"; exit 1; }
done
cat >> "$trace/kprobe_events" <<'PROBES'
p:t531/blit drm_fb_xrgb8888_to_rgb888
r:t531/blit_end drm_fb_xrgb8888_to_rgb888
p:t531/update drm_sysfb_plane_helper_atomic_update
r:t531/update_end drm_sysfb_plane_helper_atomic_update
p:t531/wait drm_atomic_helper_wait_for_fences
r:t531/wait_end drm_atomic_helper_wait_for_fences
PROBES
echo 'Temporary t531 probes installed. Reboot clears them.'
