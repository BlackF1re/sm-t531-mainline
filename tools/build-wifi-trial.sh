#!/usr/bin/env bash
# Build a separate diagnostic module from production WLAN source; never install it.
set -euo pipefail
cd "$(dirname "$0")/.."
project=$PWD
linux=${LINUX_DIR:-$project/.work/linux}
out=${KERNEL_OUT:-$project/.work/out}
stage=${WIFI_TRIAL_OUT:-$project/.work/wifi-trial-build}
[[ -f $out/.config && -f $out/Module.symvers ]]
[[ ! -e $stage ]] || { echo "Refusing existing output: $stage" >&2; exit 1; }
mkdir -p "$stage"
cp "$linux"/drivers/net/wireless/ath/wcn36xx/*.[ch] "$stage/"
# Build the already patched production source; never mutate it or bind the driver.
grep -q 'wcn36xx_tx_vif' "$stage/txrx.c"
grep -q 'No valid DT MAC address' "$stage/main.c"
grep -q 'WCN36XX_MON_DPU_ERROR_WQ' "$stage/smd.c"
grep -q 'RX_FLAG_ONLY_MONITOR' "$stage/txrx.c"
sed -i 's/\.name = "wcn36xx",/.name = "t531-wcn36xx-trial",/' "$stage/main.c"
cat >"$stage/Makefile" <<'KBUILD'
obj-m += t531_wcn36xx_trial.o
t531_wcn36xx_trial-y := main.o dxe.o txrx.o smd.o pmc.o debug.o firmware.o
t531_wcn36xx_trial-$(CONFIG_NL80211_TESTMODE) += testmode.o
KBUILD
make -C "$linux" O="$out" ARCH=arm \
 CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabihf-}" M="$stage" -j"${JOBS:-4}" modules
sha256sum "$stage/t531_wcn36xx_trial.ko"
echo 'Standalone build only; raw management/control/encrypted payload RX tested on SM-T531.'
