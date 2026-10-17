#!/bin/sh
set -eu
umask 022
[ "$(id -u)" = 0 ] || { echo 'Run as root'; exit 1; }
command -v startplasmamobile >/dev/null
command -v kwin_wayland >/dev/null
command -v kwriteconfig6 >/dev/null
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
# MDP5 KMS and the Adreno render node are separate devices.
# Historical framebuffer recovery must be selected explicitly.
graphics_device=/dev/dri/by-path/platform-fd900100.display-controller-card
if [ "${NATIVE_KMS:-1}" = 0 ]; then
    graphics_device=/dev/dri/by-path/platform-3200000.framebuffer-card
fi
# Disable Freedreno batch reordering: native Qt scrolling otherwise loses glyphs.
cat > /etc/environment.d/60-t531-graphics.conf <<CONFIG
KWIN_DRM_DEVICES=$graphics_device
QSG_RHI_BACKEND=opengl
FD_MESA_DEBUG=inorder
CONFIG
cat > /etc/systemd/system/sddm.service.d/20-t531-graphics.conf <<CONFIG
[Service]
Environment=KWIN_DRM_DEVICES=$graphics_device
Environment=QSG_RHI_BACKEND=opengl
Environment=FD_MESA_DEBUG=inorder
CONFIG
chmod 644 /etc/sddm.conf.d/20-t531.conf \
    /etc/environment.d/60-t531-graphics.conf \
    /etc/systemd/system/sddm.service.d/20-t531-graphics.conf
# Use systemd for sleep and PowerDevil for the graphical power-key policy.
install -d /etc/systemd/sleep.conf.d
cat > /etc/systemd/sleep.conf.d/20-t531-bringup.conf <<'CONFIG'
[Sleep]
AllowSuspend=yes
AllowHibernation=no
AllowHybridSleep=no
AllowSuspendThenHibernate=no
SuspendState=mem
MemorySleepMode=s2idle
CONFIG
# Keep automatic sleep off during bring-up; explicit sleep remains available.
for profile in AC Battery LowBattery; do
    for key in DimDisplayWhenIdle TurnOffDisplayWhenIdle; do
        runuser -u t531 -- kwriteconfig6 --file powerdevilrc \
            --group "$profile" --group Display --key "$key" --type bool false
    done
    runuser -u t531 -- kwriteconfig6 --file powerdevilrc \
        --group "$profile" --group SuspendAndShutdown \
        --key AutoSuspendAction --type int 0
    runuser -u t531 -- kwriteconfig6 --file powerdevilrc \
        --group "$profile" --group SuspendAndShutdown \
        --key PowerButtonAction --type int 1
    runuser -u t531 -- kwriteconfig6 --file powerdevilrc \
        --group "$profile" --group SuspendAndShutdown \
        --key SleepMode --type int 1
done
# Tablet mode assigns Power to display-off in PowerDevil by default.
# Change the standard global shortcut to its existing Suspend action.
runuser -u t531 -- kwriteconfig6 --file kglobalshortcutsrc \
    --group org_kde_powerdevil --key 'Turn Off Screen' \
    'none,Power Off,Turn Off Screen'
runuser -u t531 -- kwriteconfig6 --file kglobalshortcutsrc \
    --group org_kde_powerdevil --key Sleep 'Power Off,Sleep,Suspend'
user_uid=$(id -u t531)
if [ -f /usr/lib/t531-powerdevil/powerdevil/action/powerdevil_suspendsessionaction.so ]; then
    dropin=/home/t531/.config/systemd/user/plasma-powerdevil.service.d
    install -d -o t531 -g t531 "$dropin"
    cat > "$dropin/20-t531-suspend.conf" <<'CONFIG'
[Service]
Environment=QT_PLUGIN_PATH=/usr/lib/t531-powerdevil
CONFIG
    chown t531:t531 "$dropin/20-t531-suspend.conf"
    chmod 644 "$dropin/20-t531-suspend.conf"
    if [ -S "/run/user/$user_uid/bus" ]; then
        runuser -u t531 -- env XDG_RUNTIME_DIR="/run/user/$user_uid" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$user_uid/bus" \
            systemctl --user daemon-reload
    fi
fi
if [ -S "/run/user/$user_uid/bus" ]; then
    for action in 'Turn Off Screen' Sleep; do
        if [ "$action" = Sleep ]; then
            # Qt::Key_PowerOff; setForeignShortcut saves the live assignment.
            set -- 1 16777399
        else
            set -- 0
        fi
        runuser -u t531 -- env XDG_RUNTIME_DIR="/run/user/$user_uid" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$user_uid/bus" \
            busctl --user call org.kde.kglobalaccel /kglobalaccel \
            org.kde.KGlobalAccel setForeignShortcut asai 4 \
            org_kde_powerdevil "$action" 'Power Management' "$action" "$@"
    done
fi
install -d /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/20-t531-power-key.conf <<'CONFIG'
[Login]
HandlePowerKey=suspend
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
