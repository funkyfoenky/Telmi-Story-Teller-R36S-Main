#!/bin/sh
# Dump dmesg sur la root ext4 (lisible en WSL) + BOOT/TELMI si montables.
# Appelé par early-init (PID 1) et par telmi-dump.service (si systemd démarre).
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

mkdir -p /proc /sys /dev /boot /run /tmp /mnt/telmi-content /var/log
mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true

_stamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo nogps)"

dump_to() {
	_f="$1"
	{
		echo "=== telmi-dump $_stamp ==="
		echo "script=$0"
		echo "cmdline: $(cat /proc/cmdline 2>/dev/null)"
		echo "--- mmc ---"
		ls -l /dev/mmcblk* 2>/dev/null || echo "pas de mmcblk"
		echo "--- blk ---"
		cat /proc/partitions 2>/dev/null || true
		echo "--- fb ---"
		ls -l /dev/fb0 /dev/dri 2>/dev/null || echo "pas de fb/dri"
		echo "--- mounts ---"
		cat /proc/mounts 2>/dev/null
		echo "--- dmesg ---"
		dmesg 2>/dev/null || true
	} > "$_f" 2>&1
}

# Root ext4 : toujours écrivable si ce script tourne (on EST sur p2).
dump_to /telmi-early.log
dump_to /var/log/telmi-early.log
sync

# FAT BOOT (D: sous Windows)
if ! mountpoint -q /boot 2>/dev/null; then
	mount -t vfat -L BOOT /boot 2>/dev/null \
		|| mount -t vfat /dev/mmcblk0p1 /boot 2>/dev/null \
		|| mount -t vfat /dev/mmcblk1p1 /boot 2>/dev/null \
		|| true
fi
if mountpoint -q /boot 2>/dev/null; then
	dump_to /boot/telmi-runtime.log
	sync
fi

# FAT TELMI (E: sous Windows) — même si BOOT refuse de monter
if ! mountpoint -q /mnt/telmi-content 2>/dev/null; then
	mount -t vfat -L TELMI /mnt/telmi-content 2>/dev/null \
		|| mount -t vfat /dev/mmcblk0p3 /mnt/telmi-content 2>/dev/null \
		|| mount -t vfat /dev/mmcblk1p3 /mnt/telmi-content 2>/dev/null \
		|| true
fi
if mountpoint -q /mnt/telmi-content 2>/dev/null; then
	dump_to /mnt/telmi-content/telmi-early.log
	sync
fi

exit 0
