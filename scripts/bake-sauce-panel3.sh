#!/usr/bin/env bash
# Image bakée + DTB sauce panel 3 compilé depuis le noyau 4.4.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [[ "$(id -u)" -ne 0 ]]; then
	echo "ERREUR : root requis (loop devices)"
	exit 1
fi

SRC="$OUTPUT/telmi-r36-main-${VERSION}.img"
OUT="$OUTPUT/telmi-r36-main-${VERSION}-sauce-panel3.img"
DTB_NAME="rk3326-r36s-sauce-panel3-linux.dtb"
DTS="$LINUX/arch/arm64/boot/dts/rockchip/rk3326-r36s-sauce-panel3-linux.dts"
DTB="$STAGING/boot/$DTB_NAME"
RK="$LINUX/arch/arm64/boot/dts/rockchip"
INC="$LINUX/scripts/dtc/include-prefixes"

[[ -f "$SRC" ]] || { echo "ERREUR : $SRC absent — baker V30 d'abord"; exit 1; }
[[ -f "$DTS" ]] || { echo "ERREUR : $DTS"; exit 1; }
DTC="$(resolve_dtc)" || { echo "ERREUR : dtc introuvable"; exit 1; }

if [[ ! -f "$DTB" ]]; then
	echo "==> compile $DTB_NAME"
	cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
		-I "$RK" -I "$LINUX/arch/arm64/boot/dts" \
		-I "$INC" -I "$LINUX/include" \
		"$DTS" | "$DTC" -I dts -O dtb -o "$DTB" -
fi
python3 - <<PY
from pathlib import Path
p = Path(r"$DTB")
assert p.read_bytes()[:4] == bytes.fromhex("d00dfeed"), "pas un FDT"
print("FDT OK", p.stat().st_size, "bytes")
PY

echo "==> copie $SRC -> $OUT"
cp -f "$SRC" "$OUT"

LOOP="$(losetup -Pf --show "$OUT")"
trap "umount /tmp/telmi-p3-boot 2>/dev/null; rmdir /tmp/telmi-p3-boot 2>/dev/null; losetup -d '$LOOP' 2>/dev/null || true" EXIT
mkdir -p /tmp/telmi-p3-boot
mount "${LOOP}p1" /tmp/telmi-p3-boot

cp -f "$DTB" "/tmp/telmi-p3-boot/$DTB_NAME"
cp -f "$DTB" /tmp/telmi-p3-boot/rk3326-odroidgo3-linux.dtb
cp -f "$DTB" /tmp/telmi-p3-boot/rk3326-odroidgo2-linux.dtb
cp -f "$DTB" /tmp/telmi-p3-boot/rk3326-odroidgo2-linux-v11.dtb
cp -f "$DTB" /tmp/telmi-p3-boot/rk-kernel.dtb
cp -f "$DTB" /tmp/telmi-p3-boot/rk3326-r36s-v30-linux.dtb

python3 - <<PY
from pathlib import Path
src = Path("$TELMIOS/boot/boot.ini")
text = src.read_text(encoding="ascii", errors="replace").replace("\r\n", "\n").replace("\r", "\n")
text = text.replace("rk3326-r36s-v30-linux.dtb", "$DTB_NAME")
text = text.replace("DTB v30 only", "DTB sauce panel 3")
Path("/tmp/telmi-p3-boot/boot.ini").write_bytes(
    text.encode("ascii", errors="replace") + (b"" if text.endswith("\n") else b"\n")
)
print("boot.ini -> $DTB_NAME")
PY

echo "==> BOOT"
ls -lh /tmp/telmi-p3-boot/*.dtb /tmp/telmi-p3-boot/boot.ini
grep 'load mmc' /tmp/telmi-p3-boot/boot.ini
sync
umount /tmp/telmi-p3-boot
rmdir /tmp/telmi-p3-boot
losetup -d "$LOOP"
trap - EXIT

gzip -kf "$OUT"
echo "OK  $OUT"
ls -lh "$OUT" "$OUT.gz"
echo "    V30 intact : $SRC"
