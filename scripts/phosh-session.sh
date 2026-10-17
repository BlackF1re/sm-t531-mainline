#!/bin/sh
# SDDM filters its own service environment before spawning a user session.
set -eu
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
export WLR_BACKENDS=drm,libinput
export WLR_DRM_DEVICES=/dev/dri/by-path/platform-fd900100.display-controller-card
export WLR_RENDER_DRM_DEVICE=/dev/dri/by-path/platform-fdb00000.gpu-render
export WLR_RENDERER=gles2
export FD_MESA_DEBUG=inorder
test -c "$WLR_DRM_DEVICES"
test -c "$WLR_RENDER_DRM_DEVICE"
exec /usr/bin/phosh-session "$@"
