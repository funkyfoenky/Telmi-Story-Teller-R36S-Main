#!/usr/bin/env bash
# Injecte les alias DTB Odroid sur BOOT d'une image déjà bakée (0.2.0).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [[ "$(id -u)" -ne 0 ]]; then
	echo "ERREUR : root requis"
	exit 1
fi

IMG="${1:-$OUTPUT/soysauce-${VERSION}.img}"
DTB="$STAGING/boot/rk3326-r36s-v30-linux.dtb"
need() { [[ -e "$1" ]] || { echo "manque $1"; exit 1; }; }
need "$IMG"
need "$DTB"

python3 - <<PY
from pathlib import Path
p = Path("$DTB")
magic = p.read_bytes()[:4]
assert magic == bytes.fromhex("d00dfeed"), magic.hex()
print("FDT magic OK", p.stat().st_size, "bytes")
PY

LOOP="$(losetup -Pf --show "$IMG")"
trap "umount /tmp/soy-fix-boot 2>/dev/null; rmdir /tmp/soy-fix-boot 2>/dev/null; losetup -d '$LOOP'" EXIT
udevadm settle 2>/dev/null || sleep 1
mkdir -p /tmp/soy-fix-boot
mount "${LOOP}p1" /tmp/soy-fix-boot
cp -f "$DTB" /tmp/soy-fix-boot/rk3326-r36s-v30-linux.dtb
cp -f "$DTB" /tmp/soy-fix-boot/rk3326-odroidgo3-linux.dtb
cp -f "$DTB" /tmp/soy-fix-boot/rk3326-odroidgo2-linux.dtb
cp -f "$DTB" /tmp/soy-fix-boot/rk3326-odroidgo2-linux-v11.dtb
cp -f "$DTB" /tmp/soy-fix-boot/rk-kernel.dtb
ls -lh /tmp/soy-fix-boot/*.dtb
sync
umount /tmp/soy-fix-boot
rmdir /tmp/soy-fix-boot
losetup -d "$LOOP"
trap - EXIT
gzip -kf "$IMG"
echo "OK  aliases DTB injectés"
ls -lh "$IMG" "$IMG.gz"
