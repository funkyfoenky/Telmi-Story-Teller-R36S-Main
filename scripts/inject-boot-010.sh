#!/usr/bin/env bash
# Remet le boot 0.1.0 (U-Boot + logo + uInitrd ArkOS) sur l'image 0.2.0.
# Ne modifie PAS soysauce-0.1.0.img.gz (lecture seule).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [[ "$(id -u)" -ne 0 ]]; then
	echo "ERREUR : root requis"
	exit 1
fi

IMG="$OUTPUT/soysauce-${VERSION}.img"
VENDOR="$PARENT/../Soysauce/vendor/arkos4clone"
GZ="$PARENT/../Soysauce/output/soysauce-0.1.0.img.gz"
HEAD="$CACHE/soysauce-010-head16.img"
UBDIR="$CACHE/uboot-010"

need() { [[ -e "$1" ]] || { echo "manque $1"; exit 1; }; }
need "$IMG"
need "$GZ"
need "$VENDOR/rk3326-r36s-v30-linux.dtb"
need "$VENDOR/logo.bmp"

mkdir -p "$UBDIR"
if [[ ! -s "$HEAD" ]] || [[ "$(stat -c%s "$HEAD")" -lt 16000000 ]]; then
	echo "==> extraire 16 MiB d'en-tête 0.1.0 (U-Boot) — lecture seule"
	rm -f "$HEAD"
	set +o pipefail
	gzip -dc "$GZ" | dd of="$HEAD" bs=1M count=16 iflag=fullblock status=progress
	set -o pipefail
	[[ "$(stat -c%s "$HEAD")" -ge 16000000 ]] || { echo "ERREUR : en-tête 0.1.0 incomplet"; exit 1; }
fi

dd if="$HEAD" of="$UBDIR/idbloader.img" bs=512 skip=64 count=1024 status=none
dd if="$HEAD" of="$UBDIR/uboot.img" bs=512 skip=16384 count=8192 status=none
dd if="$HEAD" of="$UBDIR/trust.img" bs=512 skip=24576 count=8192 status=none
echo "==> blobs 0.1.0"
ls -lh "$UBDIR"

echo "==> écrire U-Boot 0.1.0 dans $IMG"
dd if="$UBDIR/idbloader.img" of="$IMG" conv=notrunc seek=64
dd if="$UBDIR/uboot.img" of="$IMG" conv=notrunc seek=16384
dd if="$UBDIR/trust.img" of="$IMG" conv=notrunc seek=24576

LOOP="$(losetup -Pf --show "$IMG")"
trap "umount /tmp/soy-fix-boot 2>/dev/null; rmdir /tmp/soy-fix-boot 2>/dev/null; losetup -d '$LOOP'" EXIT
udevadm settle 2>/dev/null || sleep 1
mkdir -p /tmp/soy-fix-boot
mount "${LOOP}p1" /tmp/soy-fix-boot

DTB="$VENDOR/rk3326-r36s-v30-linux.dtb"
cp -f "$DTB" /tmp/soy-fix-boot/rk3326-r36s-v30-linux.dtb
cp -f "$DTB" /tmp/soy-fix-boot/rk3326-odroidgo3-linux.dtb
cp -f "$DTB" /tmp/soy-fix-boot/rk3326-odroidgo2-linux.dtb
cp -f "$DTB" /tmp/soy-fix-boot/rk3326-odroidgo2-linux-v11.dtb
cp -f "$DTB" /tmp/soy-fix-boot/rk-kernel.dtb
cp -f "$VENDOR/logo.bmp" /tmp/soy-fix-boot/logo.bmp
# Ne PAS copier l'uInitrd ArkOS (modules d'un autre noyau = hang).

echo "==> BOOT"
ls -lh /tmp/soy-fix-boot/Image /tmp/soy-fix-boot/logo.bmp /tmp/soy-fix-boot/*.dtb /tmp/soy-fix-boot/boot.ini
sync
umount /tmp/soy-fix-boot
rmdir /tmp/soy-fix-boot
losetup -d "$LOOP"
trap - EXIT
gzip -kf "$IMG"
echo "OK  boot 0.1.0 + logo + DTB vendor sur $IMG"
ls -lh "$IMG" "$IMG.gz"
