#!/usr/bin/env bash
# Image 0.2.0 + DTB vendor « sauce panel 3 ».
# Ne touche pas soysauce-0.2.0.img (V30) ni l'image 0.1.0.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [[ "$(id -u)" -ne 0 ]]; then
	echo "ERREUR : root requis (loop devices)"
	exit 1
fi

SRC="$OUTPUT/soysauce-${VERSION}.img"
OUT="$OUTPUT/soysauce-${VERSION}-sauce-panel3.img"
VENDOR="$PARENT/../Soysauce/vendor/arkos4clone"
DTB="$VENDOR/consoles/sauce panel3/rk3326-r36s-sauce-panel3-linux.dtb"
DTB_NAME="rk3326-r36s-sauce-panel3-linux.dtb"

[[ -f "$SRC" ]] || { echo "ERREUR : $SRC absent — baker V30 d'abord"; exit 1; }
[[ -f "$DTB" ]] || { echo "ERREUR : $DTB"; exit 1; }
python3 - <<PY
from pathlib import Path
p = Path(r"$DTB")
assert p.read_bytes()[:4] == bytes.fromhex("d00dfeed"), "pas un FDT"
print("FDT OK", p.stat().st_size, "bytes")
PY

echo "==> copie $SRC -> $OUT"
cp -f "$SRC" "$OUT"

LOOP="$(losetup -Pf --show "$OUT")"
trap "umount /tmp/soy-p3-boot 2>/dev/null; rmdir /tmp/soy-p3-boot 2>/dev/null; losetup -d '$LOOP' 2>/dev/null || true" EXIT
mkdir -p /tmp/soy-p3-boot
mount "${LOOP}p1" /tmp/soy-p3-boot

cp -f "$DTB" "/tmp/soy-p3-boot/$DTB_NAME"
cp -f "$DTB" /tmp/soy-p3-boot/rk3326-odroidgo3-linux.dtb
cp -f "$DTB" /tmp/soy-p3-boot/rk3326-odroidgo2-linux.dtb
cp -f "$DTB" /tmp/soy-p3-boot/rk3326-odroidgo2-linux-v11.dtb
cp -f "$DTB" /tmp/soy-p3-boot/rk-kernel.dtb
# garder aussi le nom v30 au cas où un boot.ini ancien le charge
cp -f "$DTB" /tmp/soy-p3-boot/rk3326-r36s-v30-linux.dtb

python3 - <<PY
from pathlib import Path
src = Path("$TELMIOS/boot/boot.ini")
text = src.read_text(encoding="ascii", errors="replace").replace("\r\n", "\n").replace("\r", "\n")
text = text.replace("rk3326-r36s-v30-linux.dtb", "$DTB_NAME")
text = text.replace("DTB v30 only", "DTB sauce panel 3")
Path("/tmp/soy-p3-boot/boot.ini").write_bytes(
    text.encode("ascii", errors="replace") + (b"" if text.endswith("\n") else b"\n")
)
print("boot.ini -> $DTB_NAME")
PY

echo "==> BOOT"
ls -lh /tmp/soy-p3-boot/*.dtb /tmp/soy-p3-boot/boot.ini
grep 'load mmc' /tmp/soy-p3-boot/boot.ini
sync
umount /tmp/soy-p3-boot
rmdir /tmp/soy-p3-boot
losetup -d "$LOOP"
trap - EXIT

gzip -kf "$OUT"
echo "OK  $OUT"
ls -lh "$OUT" "$OUT.gz"
echo "    V30 intact : $SRC"
