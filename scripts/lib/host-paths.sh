# SPDX-License-Identifier: MIT
# Source from host-side Bash scripts; this helper creates no files.
t531_host_paths() {
    local profile=${1:-main}
    project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
    workspace=${WORK_DIR:-$project/../build/sm-t531}
    sources_dir=${SOURCES_DIR:-$project/../sources}
    case "$profile" in
        main)
            work=$workspace
            linux=${KERNEL_SRC:-$sources_dir/linux-mainline}
            artifacts=${ARTIFACTS_DIR:-$work/artifacts/current}
            ;;
        bootstrap)
            work=$workspace/bootstrap
            linux=${KERNEL_SRC:-$sources_dir/linux-bootstrap}
            artifacts=${ARTIFACTS_DIR:-$work/artifacts}
            ;;
        *) printf 'Unknown host build profile: %s\n' "$profile" >&2; return 1 ;;
    esac
    out=${KERNEL_OUT:-$work/out}
    export WORK_DIR="$workspace" KERNEL_SRC="$linux" KERNEL_OUT="$out"
    export ARTIFACTS_DIR="$artifacts"
}
