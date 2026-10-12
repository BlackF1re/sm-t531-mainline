#!/bin/sh
set -eu
[ "$(id -u)" = 0 ] || { echo 'Run as root'; exit 1; }
install -d /usr/local/sbin
cat > /usr/local/sbin/t531-charge-ramp <<'RAMP'
#!/bin/sh
# Explicit local policy: allow SDP above its default 500 mA. SMB358 AICL
# measures input droop in hardware; CURRENT_MAX reports its completed result.
set -u
supply=/sys/class/power_supply/smb358-usb
request=0
hold=0
offline_seconds=0
previous=500000
while :; do
    read -r online 2>/dev/null < "$supply/online" || online=0
    read -r status 2>/dev/null < "$supply/status" || status=Unknown
    if [ "$online" != 1 ]; then
        offline_seconds=$((offline_seconds + 1))
        if [ "$request" -gt 500000 ] && [ "$hold" = 0 ]; then
            if echo "$previous" > "$supply/input_current_limit"; then
                request=$previous
                hold=1
                echo "Input undervoltage; back off to $((request / 1000)) mA"
            fi
        fi
        if [ "$offline_seconds" -ge 5 ]; then
            request=0
            hold=0
        fi
    elif [ "$status" != Charging ]; then
        # AICL can briefly pause charging. Do not repeatedly restart its ramp.
        # Hardware termination and temperature inhibition must remain in charge.
        offline_seconds=0
    elif [ "$request" = 0 ]; then
        offline_seconds=0
        if echo 500000 > "$supply/input_current_limit"; then
            request=500000
            echo 'Input ramp starts at 500 mA; hardware AICL enabled'
        fi
    else
        offline_seconds=0
        read -r configured 2>/dev/null < "$supply/input_current_limit" || configured=0
        read -r actual 2>/dev/null < "$supply/current_max" || actual=0
        if [ "$configured" != "$request" ]; then
            # The kernel resets the ceiling after a source/temperature change.
            request=0
            hold=0
        elif [ "$actual" -gt 0 ] && [ "$actual" -lt "$request" ]; then
            if echo "$actual" > "$supply/input_current_limit"; then
                request=$actual
                hold=1
                echo "AICL limited input to $((actual / 1000)) mA; holding until reconnect"
            fi
        elif [ "$actual" -ge "$request" ] && [ "$hold" = 0 ]; then
            case "$request" in
                500000) next=700000;;
                700000) next=1000000;;
                1000000) next=1200000;;
                1200000) next=1500000;;
                1500000) next=1800000;;
                1800000) next=2000000;;
                *) next=$request;;
            esac
            if [ "$next" != "$request" ] && echo "$next" > "$supply/input_current_limit"; then
                previous=$request
                request=$next
                echo "Input ceiling $((request / 1000)) mA"
            fi
        fi
    fi
    sleep 1
done
RAMP
chmod 755 /usr/local/sbin/t531-charge-ramp
cat > /etc/systemd/system/t531-charge-ramp.service <<'UNIT'
[Unit]
Description=SMB358 one-second input ramp with hardware AICL
After=systemd-udev-trigger.service
[Service]
ExecStart=/usr/local/sbin/t531-charge-ramp
Restart=on-failure
RestartSec=2
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable t531-charge-ramp.service
if [ "${INSTALL_ONLY:-0}" != 1 ]; then
    systemctl restart t531-charge-ramp.service
fi
