#!/usr/bin/env bash
set -euo pipefail
sleep 2
echo "=== lsblk ==="
lsblk -o NAME,FSTYPE,LABEL,SIZE,MOUNTPOINT
ROOTDEV="$(lsblk -ln -o NAME,FSTYPE,LABEL | awk '$2=="ext4" && $3=="root"{print "/dev/"$1; exit}')"
echo "ROOTDEV=$ROOTDEV"
mkdir -p /mnt/telmi-root
mountpoint -q /mnt/telmi-root && umount /mnt/telmi-root
mount -t ext4 "$ROOTDEV" /mnt/telmi-root
echo "=== journal? ==="
ls -la /mnt/telmi-root/var/log/journal 2>/dev/null | head || echo "pas de journal dir"
find /mnt/telmi-root/var/log -type f 2>/dev/null | head -30
echo "=== wtmp/lastlog sizes ==="
ls -l /mnt/telmi-root/var/log/wtmp /mnt/telmi-root/var/log/lastlog /mnt/telmi-root/var/log/syslog 2>/dev/null || true
echo "=== fstab ==="
cat /mnt/telmi-root/etc/fstab
echo "=== telmi wants ==="
ls -l /mnt/telmi-root/etc/systemd/system/multi-user.target.wants/ | head
umount /mnt/telmi-root
bash /mnt/c/Users/Utilisateur/Downloads/Tools/HelloWorld_R36S/soysauce-git/telmi-os/scripts/inject-sd.sh
