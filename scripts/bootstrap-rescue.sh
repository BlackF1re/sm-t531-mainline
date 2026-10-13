#!/bin/sh
export PATH=/bin:/sbin
mkdir -p /sys/fs/pstore
mount -t pstore pstore /sys/fs/pstore
rescue=
case " $(cat /proc/cmdline) " in *" t531.rescue "*) rescue=yes;; esac
printf '\nSM-T531 bootstrap: press Volume Up/Down within 3 seconds for recovery.\n'
if [ -z "$rescue" ] && /bin/volume-wait 3; then rescue=yes; fi
if [ -z "$rescue" ]; then
    /bin/boot-sd
    echo 'Automatic SD boot failed; entering recovery.'
fi
printf '\nSM-T531 recovery: USB ACM shell is ready.\n'
echo 'Press either volume button to boot the SD kernel.'
echo 'Commands: boot-sd, mount-sd [ro|rw], umount-sd, mount-internal-boot, save-logs'
echo 'pstore: /sys/fs/pstore; SD logs after mount-sd: /mnt/sd-root/var/log'
(
    while :; do
        if /bin/volume-wait --press; then /bin/boot-sd; fi
        sleep 1
    done
) &
while :; do setsid cttyhack sh; sleep 1; done
