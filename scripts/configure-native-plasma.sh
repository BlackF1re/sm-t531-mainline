#!/usr/bin/env bash
# Compatibility entry point: device selection is now automatic and read-only.
set -euo pipefail
[[ ${1:-check} == check ]] || {
    echo 'Legacy activate/restore removed. Use the reviewed graphics A/B procedure.' >&2
    exit 2
}
exec /usr/local/libexec/t531-drm-probe --require-unified
