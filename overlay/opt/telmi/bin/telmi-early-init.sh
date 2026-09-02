#!/bin/sh
# PID 1 de diagnostic : dump dmesg sur BOOT puis systemd.
# Ne doit jamais bloquer le boot (toujours exec init).
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

mkdir -p /proc /sys /dev /boot /run /tmp
mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
mount -t tmpfs tmpfs /run 2>/dev/null || true

mount_boot() {
	mountpoint -q /boot 2>/dev/null && return 0
	mount -t vfat -L BOOT /boot 2>/dev/null && return 0
	mount -t vfat /dev/mmcblk0p1 /boot 2>/dev/null && return 0
	mount -t vfat /dev/mmcblk1p1 /boot 2>/dev/null && return 0
	return 1
}

if mount_boot; then
	{
		echo "=== telmi-early-init $(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null) ==="
		echo "cmdline: $(cat /proc/cmdline 2>/dev/null)"
		echo "--- mmc ---"
		ls -l /dev/mmcblk* 2>/dev/null || echo "pas de mmcblk"
		echo "--- fb ---"
		ls -l /dev/fb0 2>/dev/null || echo "pas de fb0"
		echo "--- mounts ---"
		cat /proc/mounts 2>/dev/null
		echo "--- dmesg ---"
		dmesg 2>/dev/null || true
	} > /boot/telmi-runtime.log 2>&1
	sync
fi

if [ -x /lib/systemd/systemd ]; then
	exec /lib/systemd/systemd
fi
exec /sbin/init
