#!/usr/bin/env bash
# Select the display-manager session; native KMS and recovery stay in place.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run as root on SM-T531'; exit 1; }
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
shell=${1:?Usage: select-mobile-shell.sh phosh|plasma}
case $shell in
    phosh) command -v phosh-session >/dev/null; command -v phoc >/dev/null ;;
    plasma) [[ -r /usr/share/wayland-sessions/plasma-mobile.desktop ]] ;;
    *) exit 2 ;;
esac
/usr/local/libexec/t531-drm-probe --require-unified >/dev/null
exec 9>/run/lock/t531-mobile-shell.lock
flock -n 9 || { echo 'Another session switch is active'; exit 1; }
project=$(realpath "$(dirname "$0")/..")
backup=/var/lib/t531/mobile-shell-backup
if [[ ! -d $backup ]]; then
    mkdir -m700 "$backup"
    cp -a /etc/sddm.conf.d "$backup/"
    cp -a /etc/systemd/system/sddm.service.d "$backup/"
    dpkg-query -W >"$backup/packages.txt"
fi
systemctl stop sddm
# End only local graphical sessions. SSH and the USB recovery console survive.
while read -r session _; do
    [[ $(loginctl show-session "$session" -p Name --value) == t531 ]] || continue
    [[ $(loginctl show-session "$session" -p Seat --value) == seat0 ]] || continue
    loginctl terminate-session "$session"
done < <(loginctl list-sessions --no-legend)
userctl() {
    runuser -u t531 -- env XDG_RUNTIME_DIR=/run/user/1000 \
        DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus systemctl --user "$@"
}
userctl stop --no-block graphical-session.target \
    plasma-kwin_wayland.service plasma-plasmashell.service || true
for process in kwin_wayland plasmashell phoc; do
    pkill -TERM -u t531 -x "$process" || true
done
for ((attempt=0; attempt<10; attempt++)); do
    pgrep -u t531 -x 'kwin_wayland|phoc' >/dev/null || break
    sleep 1
done
if pgrep -u t531 -x 'kwin_wayland|phoc' >/dev/null; then
    echo 'Previous compositor has not exited; session selection unchanged'
    exit 1
fi
case $shell in
    phosh)
        install -m755 "$project/scripts/phosh-session.sh" /usr/local/bin/t531-phosh-session
        install -m644 "$project/config/t531-phosh.desktop" /usr/share/wayland-sessions/t531-phosh.desktop
        install -m644 "$project/config/t531-phosh.conf" /etc/sddm.conf.d/90-t531-phosh.conf
        install -m644 "$project/config/t531-phosh-session-environment.conf" \
            /etc/systemd/system/sddm.service.d/30-t531-phosh.conf
        # The bridge's opacity-zero X11 window becomes a white maximized
        # window on this Phoc/wlroots combination. Keep it available for
        # other sessions; XWayland itself remains available in Phosh.
        autostart=/home/t531/.config/autostart
        entry=$autostart/org.kde.xwaylandvideobridge.desktop
        install -d -m755 -o t531 -g t531 "$autostart"
        if [[ -e $entry ]]; then
            cp -an "$entry" "$backup/xwaylandvideobridge.desktop.before"
        fi
        install -m644 -o t531 -g t531 \
            "$project/config/t531-xwaylandvideobridge.desktop" "$entry.new"
        mv -T "$entry.new" "$entry"
        ;;
    plasma)
        rm -f /etc/sddm.conf.d/90-t531-phosh.conf \
            /etc/systemd/system/sddm.service.d/30-t531-phosh.conf
        ;;
esac
# Only display-manager files changed. A failed compositor can leave no user
# manager; recovery must still start SDDM so it can create a fresh session.
systemctl daemon-reload
systemctl start sddm
echo "Selected $shell. Check the actual compositor, display, touch and frame timing."
