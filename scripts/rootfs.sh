#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib/host-paths.sh
t531_host_paths
root=$work/rootfs
native_kms=${NATIVE_KMS:-1}
snapshot=https://snapshot.debian.org/archive/debian/20261003T000000Z/
mkdir -p "$artifacts"
if [ ! -f "$root/debootstrap/debootstrap" ] && [ ! -f "$root/etc/debian_version" ]; then
    sudo debootstrap --arch=armhf --foreign --variant=minbase --components=main,contrib,non-free,non-free-firmware \
        --keyring=/usr/share/keyrings/debian-archive-keyring.gpg \
        --include=systemd-sysv,openssh-server,iproute2,iputils-ping,kmod,udev,procps,util-linux,e2fsprogs,ca-certificates,firmware-qcom-soc,wpasupplicant,iw,sudo,systemd-timesyncd,dbus,util-linux-extra \
        trixie "$root" "$snapshot"
fi
# binfmt with the F flag uses the host interpreter; otherwise copy static qemu.
if ! rg -q '^flags:.*F' /proc/sys/fs/binfmt_misc/qemu-arm; then
    echo 'Enable static qemu-arm binfmt with F (fix-binary) before rootfs build'; exit 1
fi
if [ -f "$root/debootstrap/debootstrap" ]; then
    sudo chroot "$root" /debootstrap/debootstrap --second-stage
fi
sudo tee "$root/etc/apt/sources.list" >/dev/null <<SOURCES
deb [check-valid-until=no] $snapshot trixie main contrib non-free non-free-firmware
SOURCES
sudo chroot "$root" apt-get update
sudo chroot "$root" env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    --no-install-recommends systemd-timesyncd dbus util-linux-extra wpasupplicant iw sudo python3
sudo systemctl --root="$root" enable systemd-timesyncd
case "${ROOTFS_PROFILE:-base}" in
    base) ;;
    graphics|mobile)
        sudo chroot "$root" env DEBIAN_FRONTEND=noninteractive apt-get install -y \
            --no-install-recommends libgl1-mesa-dri libegl-mesa0 libgbm1 \
            mesa-utils libdrm-tests glmark2-es2-drm glmark2-es2-wayland weston
        [[ $native_kms == 1 ]] || { echo 'Production graphics requires native unified DRM'; exit 1; }
        sudo install -D -m644 config/msm.conf "$root/etc/modprobe.d/msm.conf"
        sudo install -D -m644 config/t531-graphics.conf "$root/etc/environment.d/60-t531-graphics.conf"
        sudo install -D -m644 config/t531-sddm-graphics.conf "$root/etc/systemd/system/sddm.service.d/20-t531-graphics.conf"
        [[ -x "$work/artifacts/tools/t531-drm-probe" ]] || {
            echo 'Build the ARM DRM capability probe with scripts/graphics/build-probe.sh first'; exit 1;
        }
        sudo install -D -m755 "$work/artifacts/tools/t531-drm-probe" "$root/usr/local/libexec/t531-drm-probe"
        if [ "${ROOTFS_PROFILE}" = mobile ]; then
            sudo chroot "$root" env DEBIAN_FRONTEND=noninteractive apt-get install -y \
                plasma-mobile-full sddm xwayland
            ./scripts/build-powerdevil.sh
            sudo cp "$artifacts/t531-powerdevil-suspend_0.20261013-1_armhf.deb" "$root/tmp/"
            sudo chroot "$root" dpkg -i /tmp/t531-powerdevil-suspend_0.20261013-1_armhf.deb
            sudo python3 -c 'import pathlib,sys; pathlib.Path(sys.argv[1]).unlink()' "$root/tmp/t531-powerdevil-suspend_0.20261013-1_armhf.deb"
            sudo install -m 755 scripts/configure-plasma.sh "$root/tmp/t531-configure-plasma.sh"
            sudo chroot "$root" env INSTALL_ONLY=1 NATIVE_KMS="$native_kms" /tmp/t531-configure-plasma.sh
            sudo rm -f "$root/tmp/t531-configure-plasma.sh"
            sudo install -D -m644 -o 1000 -g 1000 config/t531-kwin-graphics.conf "$root/home/t531/.config/systemd/user/plasma-kwin_wayland.service.d/10-t531-graphics.conf"
            if [ "$native_kms" = 1 ]; then
                sudo install -D -m755 scripts/start-native-graphics.sh "$root/usr/local/sbin/t531-start-native-graphics"
                sudo install -D -m644 config/t531-native-graphics.service "$root/etc/systemd/system/t531-native-graphics.service"
                sudo install -D -m755 scripts/graphics/ab.sh "$root/usr/local/sbin/t531-graphics-ab"
                sudo install -D -m755 scripts/graphics/save-gpu-coredump.sh "$root/usr/local/libexec/t531-save-gpu-coredump"
                sudo install -D -m644 config/90-t531-gpu-coredump.rules "$root/etc/udev/rules.d/90-t531-gpu-coredump.rules"
                sudo install -D -m644 config/t531-gpu-coredump@.service "$root/etc/systemd/system/t531-gpu-coredump@.service"
                sudo install -D -m755 scripts/graphics/rollback-compat.sh "$root/usr/local/sbin/t531-graphics-rollback"
                sudo install -D -m644 tools/graphics-ab/slots.py "$root/usr/local/lib/t531-graphics-ab/slots.py"
                for unit in t531-native-kms-recovery.service t531-graphics-ab-guard.service t531-graphics-ab-timeout.service t531-graphics-ab-timeout.timer; do
                    sudo install -D -m644 "config/$unit" "$root/etc/systemd/system/$unit"
                done
                sudo systemctl --root="$root" enable t531-native-graphics.service t531-graphics-ab-guard.service
            fi
        fi
        ;;
    *) echo 'ROOTFS_PROFILE must be base, graphics or mobile'; exit 1;;
esac
sudo tee "$root/etc/fstab" >/dev/null <<'FSTAB'
LABEL=T531_ROOT / ext4 defaults,noatime 0 1
FSTAB
echo t531 | sudo tee "$root/etc/hostname" >/dev/null
sudo mkdir -p "$root/etc/systemd/network" "$root/etc/ssh/sshd_config.d"
sudo install -Dm644 config/wcn36xx-networkmanager.conf \
    "$root/etc/NetworkManager/conf.d/35-wcn36xx.conf"
sudo install -Dm755 scripts/wifi-monitor.sh "$root/usr/local/sbin/t531-wifi-monitor"
sudo tee "$root/etc/systemd/network/usb.network" >/dev/null <<'NETWORK'
[Match]
Name=usb*
[Network]
Address=192.168.77.2/24
NETWORK
sudo tee "$root/etc/ssh/sshd_config.d/10-t531.conf" >/dev/null <<'SSH'
PasswordAuthentication no
PermitRootLogin prohibit-password
SSH
# Authorized key is supplied explicitly from a local file; never embed keys.
if [ -n "${SSH_AUTHORIZED_KEY:-}" ]; then
    sudo install -d -m 700 "$root/root/.ssh"
    sudo install -m 600 "$SSH_AUTHORIZED_KEY" "$root/root/.ssh/authorized_keys"
fi
sudo tee "$root/etc/systemd/system/t531-ssh-keys.service" >/dev/null <<'KEYS'
[Unit]
Description=Generate SSH host keys on first boot
Before=ssh.service
ConditionPathExists=!/etc/ssh/ssh_host_ed25519_key
[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A
[Install]
WantedBy=multi-user.target
KEYS
sudo systemctl --root="$root" enable systemd-networkd ssh t531-ssh-keys.service serial-getty@ttyGS0.service
if [ -d "$artifacts/modules/lib/modules" ]; then
    sudo mkdir -p "$root/lib/modules"
    sudo cp -a "$artifacts/modules/lib/modules/." "$root/lib/modules/"
fi
# Optional private SX9500 calibration becomes a normal udev attribute rule.
sudo install -Dm755 scripts/configure-grip.py "$root/usr/local/sbin/t531-configure-grip"
if [ -n "${GRIP_CALIBRATION_FILE:-}" ]; then
    python3 scripts/configure-grip.py "$GRIP_CALIBRATION_FILE" \
        --output "$work/grip-calibration.rules"
    sudo install -Dm600 "$work/grip-calibration.rules" \
        "$root/etc/udev/rules.d/70-t531-grip-calibration.rules"
fi
sudo install -m 755 scripts/configure-charging.sh "$root/tmp/t531-configure-charging.sh"
sudo chroot "$root" env INSTALL_ONLY=1 /tmp/t531-configure-charging.sh
sudo rm -f "$root/tmp/t531-configure-charging.sh"
if [ -n "${WIFI_LINK_CONFIG:-}" ]; then
    sudo install -m 600 "$WIFI_LINK_CONFIG" "$root/etc/systemd/network/10-wlan.link"
fi
if [ -n "${WIFI_CONFIG:-}" ]; then
    sudo install -m 600 "$WIFI_CONFIG" "$root/tmp/t531-wifi.conf"
    sudo install -m 755 scripts/configure-network.sh "$root/tmp/t531-configure-network.sh"
    network_manager=0
    [ "${ROOTFS_PROFILE:-base}" != mobile ] || network_manager=1
    sudo chroot "$root" env INSTALL_ONLY=1 NETWORK_MANAGER="$network_manager" \
        /tmp/t531-configure-network.sh /tmp/t531-wifi.conf
    sudo rm -f "$root/tmp/t531-wifi.conf" "$root/tmp/t531-configure-network.sh"
fi
sudo chroot "$root" dpkg-query -W '-f=${Package}\t${Version}\t${Architecture}\n' > "$artifacts/debian-packages.tsv"
sudo chroot "$root" apt-get clean
# Fresh installations generate their own machine-id and SSH host keys.
sudo rm -f "$root/etc/ssh/ssh_host_"* "$root/var/lib/dbus/machine-id"
sudo truncate -s 0 "$root/etc/machine-id"
sudo tar --sort=name --numeric-owner --mtime='2026-10-03 00:00:00 UTC' \
    --exclude='./dev/*' --exclude='./proc/*' --exclude='./sys/*' -C "$root" -cf - . \
    | gzip -n -1 > "$artifacts/debian-armhf.tar.gz"
echo "Rootfs: $artifacts/debian-armhf.tar.gz"
