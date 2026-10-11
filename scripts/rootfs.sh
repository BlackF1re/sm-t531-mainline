#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
work=$PWD/.work
root=$work/rootfs
snapshot=https://snapshot.debian.org/archive/debian/20261003T000000Z/
mkdir -p "$work/artifacts/current"
if [ ! -f "$root/debootstrap/debootstrap" ] && [ ! -f "$root/etc/debian_version" ]; then
    sudo debootstrap --arch=armhf --foreign --variant=minbase --components=main,contrib,non-free,non-free-firmware \
        --keyring=/usr/share/keyrings/debian-archive-keyring.gpg \
        --include=systemd-sysv,openssh-server,iproute2,iputils-ping,kmod,udev,procps,util-linux,e2fsprogs,ca-certificates,firmware-qcom-soc \
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
sudo tee "$root/etc/fstab" >/dev/null <<'FSTAB'
LABEL=T531_ROOT / ext4 defaults,noatime 0 1
FSTAB
echo t531 | sudo tee "$root/etc/hostname" >/dev/null
sudo mkdir -p "$root/etc/systemd/network" "$root/etc/ssh/sshd_config.d"
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
if [ -d "$work/artifacts/current/modules/lib/modules" ]; then
    sudo mkdir -p "$root/lib/modules"
    sudo cp -a "$work/artifacts/current/modules/lib/modules/." "$root/lib/modules/"
fi
sudo chroot "$root" dpkg-query -W '-f=${Package}\t${Version}\t${Architecture}\n' > "$work/artifacts/current/debian-packages.tsv"
sudo chroot "$root" apt-get clean
# Fresh installations generate their own machine-id and SSH host keys.
sudo rm -f "$root/etc/ssh/ssh_host_"* "$root/var/lib/dbus/machine-id"
sudo truncate -s 0 "$root/etc/machine-id"
sudo tar --sort=name --numeric-owner --mtime='2026-10-03 00:00:00 UTC' \
    --exclude='./dev/*' --exclude='./proc/*' --exclude='./sys/*' -C "$root" -cf - . \
    | gzip -n -1 > "$work/artifacts/current/debian-armhf.tar.gz"
echo "Rootfs: $work/artifacts/current/debian-armhf.tar.gz"
