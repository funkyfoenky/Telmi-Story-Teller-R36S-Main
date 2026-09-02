#!/bin/sh
# Tampon lisible Windows sur BOOT dès que telmi.service démarre.
# Toujours exit 0 (ne doit pas bloquer ExecStart).

ensure_boot() {
	mkdir -p /boot
	mountpoint -q /boot 2>/dev/null && return 0
	mount -L BOOT /boot 2>/dev/null && return 0
	mount /dev/mmcblk0p1 /boot 2>/dev/null && return 0
	mount /dev/mmcblk1p1 /boot 2>/dev/null && return 0
	return 1
}

ensure_boot || exit 0

{
	echo "=== Telmi ArkOS4Clone stamp ==="
	echo "date=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)"
	echo "uptime=$(cat /proc/uptime 2>/dev/null || true)"
	echo "--- bins ---"
	ls -l /opt/telmi/bin 2>/dev/null || echo "pas de /opt/telmi/bin"
	echo "--- battery ---"
	ls -l /sys/class/power_supply/ 2>/dev/null || true
	cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo "no battery/capacity"
	echo "--- fb0 ---"
	ls -l /dev/fb0 2>/dev/null || echo "no /dev/fb0"
	cat /sys/class/graphics/fb0/virtual_size 2>/dev/null || true
	echo "--- drm ---"
	ls /sys/class/drm/ 2>/dev/null || true
	echo "--- mounts ---"
	awk '$2=="/boot"||$2=="/telmi"||$2=="/"{print}' /proc/mounts 2>/dev/null || true
} > /boot/TELMI-STAMP.txt 2>/dev/null || true
sync
exit 0
