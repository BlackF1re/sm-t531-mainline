#!/usr/bin/env bash
# Exclusive SM-T531 monitor ownership, with a saved managed connection.
set -euo pipefail
state=/run/t531-wifi-monitor

usage() {
    echo 'Usage: t531-wifi-monitor start CHANNEL [NOHT|HT20|HT40+|HT40-] | stop | status' >&2
    exit 2
}

[[ $EUID == 0 ]] || { echo 'Run as root.' >&2; exit 1; }
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
script=$(realpath "$0")

if [[ ${1:-} != --worker ]]; then
    case ${1:-} in
        status)
            if [[ -e $state/created ]]; then
                iw dev mon0 info
            else
                echo 'No monitor session owned by this command.'
            fi
            exit 0
            ;;
        start)
            [[ $# == 2 || $# == 3 ]] || usage
            [[ $2 =~ ^[0-9]{1,3}$ ]] || usage
            case ${3:-NOHT} in NOHT|HT20|HT40+|HT40-) ;; *) usage;; esac
            ;;
        stop) [[ $# == 1 ]] || usage;;
        *) usage;;
    esac
    # The unit survives loss of the Wi-Fi SSH connection during either switch.
    exec systemd-run --no-block --collect --unit="t531-wifi-monitor-switch-$(date +%s)-$$" \
        --property=Type=oneshot --property=TimeoutStartSec=120 \
        "$script" --worker "$@"
fi
shift
exec 9>/run/t531-wifi-monitor.lock
flock -n 9 || { echo 'Another mode switch is running.' >&2; exit 1; }

restore() {
    [[ -d $state ]] || return 0
    local phy mac uuid current radio_driver
    phy=$(cat "$state/phy")
    mac=$(cat "$state/mac")
    uuid=$(cat "$state/uuid")
    [[ $phy =~ ^phy[0-9]+$ && $mac =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]]
    [[ -z $uuid || $uuid =~ ^[[:xdigit:]-]{36}$ ]]
    if [[ -e $state/created && -e /sys/class/net/mon0 ]]; then
        ip link set mon0 down
        iw dev mon0 del
    fi
    if [[ ! -e /sys/class/net/wlan0 ]]; then
        iw phy "$phy" interface add wlan0 type managed
    fi
    radio_driver=$(basename "$(readlink -f /sys/class/net/wlan0/device/driver)")
    [[ $radio_driver == wcn36xx ]]
    ip link set wlan0 down
    iw dev wlan0 set type managed
    ip link set wlan0 address "$mac"
    systemctl start NetworkManager
    nmcli device set wlan0 managed yes
    # Let normal autoconnect finish; an immediate activation can race scanning.
    if [[ -n $uuid ]]; then
        for ((i=0;i<45;i++)); do
            current=$(nmcli -g GENERAL.CON-UUID device show wlan0 2>/dev/null || true)
            if [[ $current == "$uuid" ]] &&
               [[ $(nmcli -g GENERAL.STATE device show wlan0) == 100* ]]; then
                break
            fi
            if (( i == 15 )); then
                nmcli --wait 25 connection up uuid "$uuid" || true
            fi
            sleep 1
        done
        [[ $(nmcli -g GENERAL.CON-UUID device show wlan0) == "$uuid" ]]
        [[ $(nmcli -g GENERAL.STATE device show wlan0) == 100* ]]
    fi
    rm -f "$state/phy" "$state/mac" "$state/uuid" "$state/created"
    rmdir "$state"
    echo 'Managed interface and NetworkManager restored.'
}

case ${1:-} in
    stop) restore;;
    start)
        [[ $# == 2 || $# == 3 ]] || usage
        [[ $2 =~ ^[0-9]{1,3}$ ]] || usage
        case ${3:-NOHT} in NOHT|HT20|HT40+|HT40-) ;; *) usage;; esac
        [[ ! -e $state && ! -e /sys/class/net/mon0 ]]
        [[ $(basename "$(readlink -f /sys/class/net/wlan0/device/driver)") == wcn36xx ]]
        iw dev wlan0 info | grep -Eq '^[[:space:]]+type managed$'
        systemctl is-active --quiet NetworkManager
        install -d -m700 "$state"
        basename "$(readlink -f /sys/class/net/wlan0/phy80211)" >"$state/phy"
        cat /sys/class/net/wlan0/address >"$state/mac"
        uuid=$(nmcli -g GENERAL.CON-UUID device show wlan0 || true)
        [[ $uuid != -- ]] || uuid=
        printf '%s\n' "$uuid" >"$state/uuid"
        trap 'ret=$?; if (( ret )); then restore; fi' EXIT
        trap 'exit 143' TERM
        trap 'exit 130' INT
        systemctl stop NetworkManager
        ip link set wlan0 down
        # Retire the managed vif instead of racing its scans/type change.
        touch "$state/created"
        iw phy "$(cat "$state/phy")" interface add mon0 type monitor flags control otherbss
        iw dev wlan0 del
        ip link set mon0 up
        if [[ ${3:-NOHT} == NOHT ]]; then
            iw dev mon0 set channel "$2"
        else
            iw dev mon0 set channel "$2" "$3"
        fi
        iw dev mon0 info
        ;;
    *) usage;;
esac
