#!/bin/sh
# Initramfs diag V20 : dump dmesg sur FAT (BOOT + TELMI) et ext4, puis switch_root.
# Tourne AVANT le mount root= du noyau → log même si rootwait / BOOT userspace échoue.
/busybox mkdir -p /proc /sys /dev /mnt/boot /mnt/telmi /mnt/root /tmp
/busybox mount -t proc proc /proc
/busybox mount -t sysfs sysfs /sys
/busybox mount -t devtmpfs devtmpfs /dev 2>/dev/null || /busybox mount -t tmpfs tmpfs /dev

dump_to() {
	_f="$1"
	{
		echo "=== telmi-initrd dump ==="
		echo "cmdline: $(/busybox cat /proc/cmdline 2>/dev/null)"
		echo "--- partitions ---"
		/busybox cat /proc/partitions 2>/dev/null
		echo "--- mmc ---"
		/busybox ls -l /dev/mmcblk* 2>/dev/null || echo "pas de mmcblk"
		echo "--- fb ---"
		/busybox ls -l /dev/fb0 /dev/dri 2>/dev/null || echo "pas de fb/dri"
		echo "--- mounts ---"
		/busybox cat /proc/mounts 2>/dev/null
		echo "--- dmesg ---"
		/busybox dmesg 2>/dev/null || true
	} > "$_f" 2>&1
}

# Attendre les block devices (MMC parfois lent)
i=0
while [ "$i" -lt 30 ]; do
	if /busybox ls /dev/mmcblk*p1 >/dev/null 2>&1; then
		break
	fi
	/busybox sleep 1
	i=$((i + 1))
done

# Toutes les FAT : p1 (BOOT / D:) et p3 (TELMI / E:)
for p in /dev/mmcblk0p1 /dev/mmcblk1p1 /dev/mmcblk0p3 /dev/mmcblk1p3; do
	[ -b "$p" ] || continue
	/busybox mkdir -p /mnt/fat
	if /busybox mount -t vfat -o rw,umask=000 "$p" /mnt/fat 2>/dev/null; then
		dump_to /mnt/fat/telmi-early.log
		# D: historiquement telmi-runtime.log
		dump_to /mnt/fat/telmi-runtime.log
		/busybox sync
		/busybox umount /mnt/fat
	fi
done

# ext4 LABEL=root (p2) — lisible ensuite en WSL
j=0
mounted=0
while [ "$j" -lt 20 ]; do
	for p in /dev/mmcblk0p2 /dev/mmcblk1p2; do
		[ -b "$p" ] || continue
		if /busybox mount -t ext4 "$p" /mnt/root 2>/dev/null; then
			mounted=1
			break 2
		fi
	done
	if /busybox mount -t ext4 -L root /mnt/root 2>/dev/null; then
		mounted=1
		break
	fi
	/busybox sleep 1
	j=$((j + 1))
done

if [ "$mounted" = 1 ]; then
	dump_to /mnt/root/telmi-early.log
	/busybox mkdir -p /mnt/root/var/log
	dump_to /mnt/root/var/log/telmi-early.log
	/busybox sync
	# Continuer le boot Telmi
	if [ -x /mnt/root/lib/systemd/systemd ]; then
		exec /busybox switch_root /mnt/root /lib/systemd/systemd
	fi
	if [ -x /mnt/root/sbin/init ]; then
		exec /busybox switch_root /mnt/root /sbin/init
	fi
	/busybox umount /mnt/root
fi

# Pas de root : on a déjà dumpé sur FAT. Rester vivant (rétro / LED).
while true; do
	/busybox sleep 60
done
