#!/bin/sh
# SDDM filters its own service environment before spawning a user session.
set -eu
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
export WLR_BACKENDS=drm,libinput
/usr/local/libexec/t531-drm-probe --require-unified >/dev/null
export WLR_RENDERER=gles2
export FD_MESA_DEBUG=inorder
exec /usr/bin/phosh-session "$@"
