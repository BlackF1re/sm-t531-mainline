#!/bin/sh
set -eu
umask 022
[ "$(id -u)" = 0 ] || { echo 'Run as root'; exit 1; }
command -v startplasmamobile >/dev/null
command -v kwin_wayland >/dev/null
if ! id t531 >/dev/null 2>&1; then
    useradd -m -s /bin/bash t531
fi
usermod -a -G video,render,input t531
install -d /etc/sddm.conf.d /etc/environment.d /etc/systemd/system/sddm.service.d
cat > /etc/sddm.conf.d/20-t531.conf <<'CONFIG'
[General]
DisplayServer=wayland
[Wayland]
CompositorCommand=/usr/bin/kwin_wayland --no-lockscreen --no-global-shortcuts --locale1
[Autologin]
User=t531
Session=plasma-mobile.desktop
Relogin=false
CONFIG
# The framebuffer KMS node and Adreno render node are separate devices.
# Mesa's installed simpledrm KMSRO entry point selects the Adreno renderer.
# Disable Freedreno batch reordering: native Qt scrolling otherwise loses glyphs.
cat > /etc/environment.d/60-t531-graphics.conf <<'CONFIG'
KWIN_DRM_DEVICES=/dev/dri/by-path/platform-3200000.framebuffer-card
QSG_RHI_BACKEND=opengl
FD_MESA_DEBUG=inorder
CONFIG
cat > /etc/systemd/system/sddm.service.d/20-t531-graphics.conf <<'CONFIG'
[Service]
Environment=KWIN_DRM_DEVICES=/dev/dri/by-path/platform-3200000.framebuffer-card
Environment=QSG_RHI_BACKEND=opengl
Environment=FD_MESA_DEBUG=inorder
CONFIG
chmod 644 /etc/sddm.conf.d/20-t531.conf \
    /etc/environment.d/60-t531-graphics.conf \
    /etc/systemd/system/sddm.service.d/20-t531-graphics.conf
# Firmware-owned scanout is not reliably restored after system sleep.
# Keep normal screen blanking, CPU frequency scaling and CPU idle available.
install -d /etc/systemd/sleep.conf.d
cat > /etc/systemd/sleep.conf.d/20-t531-bringup.conf <<'CONFIG'
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowHybridSleep=no
AllowSuspendThenHibernate=no
CONFIG
systemctl daemon-reload
systemctl enable sddm
systemctl set-default graphical.target
if [ "${INSTALL_ONLY:-0}" != 1 ]; then
    # SDDM alone can leave the previous user compositor holding the old VT.
    systemctl stop sddm
    user_uid=$(id -u t531)
    if [ -S "/run/user/$user_uid/bus" ]; then
        runuser -u t531 -- env XDG_RUNTIME_DIR="/run/user/$user_uid" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$user_uid/bus" \
            systemctl --user stop graphical-session.target plasma-kwin_wayland.service
    fi
    systemctl start sddm
fi
