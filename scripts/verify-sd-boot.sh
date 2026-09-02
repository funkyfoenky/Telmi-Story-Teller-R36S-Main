#!/usr/bin/env bash
set -euo pipefail
ROOTDEV="$(lsblk -ln -o NAME,FSTYPE,LABEL | awk '$2=="ext4" && $3=="root"{print "/dev/"$1; exit}')"
BOOTDEV="$(lsblk -ln -o NAME,FSTYPE,LABEL | awk '$3=="BOOT"{print "/dev/"$1; exit}')"
mkdir -p /mnt/telmi-root /mnt/telmi-boot
mount -t ext4 "$ROOTDEV" /mnt/telmi-root
echo "=== early-init ==="
ls -l /mnt/telmi-root/opt/telmi/bin/telmi-early-init.sh
echo "=== fstab ==="
cat /mnt/telmi-root/etc/fstab
umount /mnt/telmi-root
mount -t vfat "$BOOTDEV" /mnt/telmi-boot
echo "=== boot.ini ==="
cat /mnt/telmi-boot/boot.ini
echo "=== inject ==="
cat /mnt/telmi-boot/TELMI-INJECT.txt
umount /mnt/telmi-boot
