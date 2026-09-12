#!/usr/bin/env bash
# Réécrit le boot de l'image bakée avec U-Boot / DTB / logo compilés dans ce dépôt.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [[ "$(id -u)" -ne 0 ]]; then
	echo "ERREUR : root requis"
	exit 1
fi

IMG="$OUTPUT/telmi-r36-main-${VERSION}.img"
UBDIR="$STAGING/uboot"
DTB="$STAGING/boot/rk3326-r36s-v30-linux.dtb"
LOGO="$STAGING/boot/logo.bmp"
LOWBATT="$STAGING/boot/low_battery.bmp"

need() { [[ -e "$1" ]] || { echo "manque $1 — lancez make uboot dtb (et collect-assets pour le logo)"; exit 1; }; }
need "$IMG"
need "$UBDIR/idbloader.img"
need "$UBDIR/uboot.img"
need "$DTB"
if [[ ! -s "$LOGO" ]]; then
	PNG="$TELMIOS/vendor/telmi-r36s/assets/res/bootScreen.png"
	need "$PNG"
	python3 "$SCRIPT_DIR/make-logo-bmp.py" "$PNG" "$LOGO"
fi
need "$LOGO"
if [[ ! -s "$LOWBATT" ]]; then
	python3 "$SCRIPT_DIR/make-low-battery-bmp.py" "$LOWBATT"
fi
need "$LOWBATT"

echo "==> écrire U-Boot (staging) dans $IMG"
dd if="$UBDIR/idbloader.img" of="$IMG" conv=notrunc seek=64
dd if="$UBDIR/uboot.img" of="$IMG" conv=notrunc seek=16384
if [[ -f "$UBDIR/trust.img" ]]; then
	dd if="$UBDIR/trust.img" of="$IMG" conv=notrunc seek=24576
fi

LOOP="$(losetup -Pf --show "$IMG")"
trap "umount /tmp/telmi-fix-boot 2>/dev/null; rmdir /tmp/telmi-fix-boot 2>/dev/null; losetup -d '$LOOP'" EXIT
udevadm settle 2>/dev/null || sleep 1
mkdir -p /tmp/telmi-fix-boot
mount "${LOOP}p1" /tmp/telmi-fix-boot

cp -f "$DTB" /tmp/telmi-fix-boot/rk3326-r36s-v30-linux.dtb
cp -f "$DTB" /tmp/telmi-fix-boot/rk3326-odroidgo3-linux.dtb
cp -f "$DTB" /tmp/telmi-fix-boot/rk3326-odroidgo2-linux.dtb
cp -f "$DTB" /tmp/telmi-fix-boot/rk3326-odroidgo2-linux-v11.dtb
cp -f "$DTB" /tmp/telmi-fix-boot/rk-kernel.dtb
cp -f "$LOGO" /tmp/telmi-fix-boot/logo.bmp
if [[ -s "$LOWBATT" ]]; then
	cp -f "$LOWBATT" /tmp/telmi-fix-boot/low_battery.bmp
	cp -f "$LOWBATT" /tmp/telmi-fix-boot/low_battery_b.bmp
fi
if [[ -f "$STAGING/opt/telmi/res/batteryLow.png" ]]; then
	cp -f "$STAGING/opt/telmi/res/batteryLow.png" /tmp/telmi-fix-boot/batteryLow.png
fi

echo "==> BOOT"
ls -lh /tmp/telmi-fix-boot/Image /tmp/telmi-fix-boot/logo.bmp /tmp/telmi-fix-boot/*.dtb /tmp/telmi-fix-boot/boot.ini
sync
umount /tmp/telmi-fix-boot
rmdir /tmp/telmi-fix-boot
losetup -d "$LOOP"
trap - EXIT
gzip -kf "$IMG"
echo "OK  U-Boot + logo + DTB (sources locales) sur $IMG"
ls -lh "$IMG" "$IMG.gz"
