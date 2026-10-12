#!/bin/sh
set -eu
# Run on the tablet with a local wpa_supplicant configuration; never commit it.
[ "$(id -u)" = 0 ] || { echo 'Run as root'; exit 1; }
[ "$#" = 1 ] || { echo 'Usage: configure-network.sh PRIVATE_WPA_CONFIG'; exit 1; }
install -d -m 700 /etc/wpa_supplicant
install -m 600 "$1" /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
if ! id t531 >/dev/null 2>&1; then
    useradd -m -s /bin/bash t531
fi
passwd -d t531 >/dev/null
passwd -d root >/dev/null
usermod -a -G sudo,video,render,input t531
install -d -m 755 /etc/sudoers.d /etc/systemd/network /usr/local/sbin
printf '%s\n' 't531 ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/t531
chmod 440 /etc/sudoers.d/t531
visudo -cf /etc/sudoers.d/t531
if [ "${NETWORK_MANAGER:-0}" = 1 ]; then
    command -v nmcli >/dev/null
    ssid=$(sed -n 's/^[[:space:]]*ssid="\(.*\)"$/\1/p' "$1")
    psk=$(sed -n 's/^[[:space:]]*psk=\([0-9a-fA-F]*\)$/\1/p' "$1")
    [ -n "$ssid" ] && [ "${#psk}" = 64 ] || { echo 'Expected one SSID and a derived 64-digit PSK'; exit 1; }
    install -d -m 700 /etc/NetworkManager/system-connections
    umask 077
    nmcli --offline connection add type wifi ifname wlan0 con-name t531-wifi \
        ssid "$ssid" wifi.cloned-mac-address preserve wifi-sec.key-mgmt wpa-psk \
        wifi-sec.psk "$psk" ipv4.method auto ipv6.method disabled \
        > /etc/NetworkManager/system-connections/t531-wifi.nmconnection
    rm -f /etc/NetworkManager/conf.d/20-t531-staging.conf
    rm -f /etc/systemd/network/20-wlan.network
    systemctl disable --now t531-wifi.service systemd-networkd.service 2>/dev/null || true
    wifi_service=NetworkManager.service
    network_services=NetworkManager
else
cat > /etc/systemd/network/20-wlan.network <<'EOF'
[Match]
Name=wlan0
[Network]
DHCP=ipv4
[DHCPv4]
UseDNS=true
EOF
cat > /etc/systemd/system/t531-wifi.service <<'EOF'
[Unit]
Description=Wi-Fi station connection
After=sys-subsystem-net-devices-wlan0.device
Wants=systemd-networkd.service
[Service]
ExecStart=/usr/sbin/wpa_supplicant -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
    wifi_service=t531-wifi.service
    network_services="systemd-networkd t531-wifi"
fi
cat > /usr/local/sbin/t531-ssh-wifi <<'EOF'
#!/bin/sh
set -eu
mkdir -p /run/sshd
ssh-keygen -A
while :; do
    address=$(ip -4 -o addr show dev wlan0 scope global 2>/dev/null | awk '{split($4,a,"/"); print a[1]; exit}')
    [ -n "$address" ] && break
    sleep 2
done
umask 077
cat > /run/sshd-wifi.conf <<CONFIG
ListenAddress $address
HostKey /etc/ssh/ssh_host_ed25519_key
PidFile /run/sshd-wifi.pid
AllowUsers root t531
PermitRootLogin yes
UsePAM yes
PasswordAuthentication yes
PermitEmptyPasswords yes
PubkeyAuthentication no
KbdInteractiveAuthentication no
Subsystem sftp internal-sftp
CONFIG
/usr/sbin/sshd -t -f /run/sshd-wifi.conf
exec /usr/sbin/sshd -D -e -f /run/sshd-wifi.conf
EOF
chmod 755 /usr/local/sbin/t531-ssh-wifi
cat > /etc/systemd/system/t531-ssh-wifi.service <<EOF
[Unit]
Description=SSH on the Wi-Fi address with empty-password local access
After=$wifi_service
Wants=$wifi_service
[Service]
ExecStart=/usr/local/sbin/t531-ssh-wifi
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
systemctl disable --now ssh.service ssh.socket wpa_supplicant.service 2>/dev/null || true
systemctl daemon-reload
systemctl enable $network_services t531-ssh-wifi
if [ "${INSTALL_ONLY:-0}" != 1 ]; then
    if [ "${NETWORK_MANAGER:-0}" = 1 ]; then
        systemctl restart NetworkManager
    fi
    systemctl start $network_services t531-ssh-wifi
fi
