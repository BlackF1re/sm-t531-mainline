#!/usr/bin/env bash
# Install the board's NetworkManager default and exclusive monitor helper.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $EUID == 0 ]]
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
[[ $(basename "$(readlink -f /sys/class/net/wlan0/device/driver)") == wcn36xx ]]
install -Dm644 config/wcn36xx-networkmanager.conf \
 /etc/NetworkManager/conf.d/35-wcn36xx.conf
install -Dm644 config/wcn36xx-standby.networkmanager.conf \
 /etc/NetworkManager/conf.d/40-wcn36xx-standby.conf
install -Dm755 scripts/wifi-monitor.sh /usr/local/sbin/t531-wifi-monitor
nmcli general reload conf
NetworkManager --print-config | grep -A2 '^\[connection-wcn36xx-no-pmf\]'
echo 'Default PMF disabled only for wcn36xx; current connection left active.'
