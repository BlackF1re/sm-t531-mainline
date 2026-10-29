#!/bin/bash
# Compatibility for the previous command; use the verified baseline controller.
set -euo pipefail
case ${1:-native} in
    native|original) exec /usr/local/sbin/t531-graphics-ab recover ;;
    *) echo 'Usage: t531-graphics-rollback [native|original]' >&2; exit 2 ;;
esac
