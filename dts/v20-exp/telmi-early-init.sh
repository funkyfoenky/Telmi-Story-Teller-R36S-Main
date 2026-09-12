#!/bin/sh
# PID 1 : dump sur ext4 (et FAT si possible) puis systemd.
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

mkdir -p /proc /sys /dev
mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true

if [ -x /opt/telmi/bin/telmi-dump-dmesg.sh ]; then
	/opt/telmi/bin/telmi-dump-dmesg.sh || true
else
	# secours si le dump n'a pas été copié sur la SD
	{ echo "=== telmi-early-init fallback ==="; dmesg; } > /telmi-early.log 2>&1 || true
	sync
fi

if [ -x /lib/systemd/systemd ]; then
	exec /lib/systemd/systemd
fi
exec /sbin/init
