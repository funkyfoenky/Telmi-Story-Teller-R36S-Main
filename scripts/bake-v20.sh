#!/usr/bin/env bash
# Image 0.2.0 V20 — clone de soysauce-0.2.0.img + DTB 4.4 porté du stock V20.
# Ne touche pas soysauce-0.2.0.img (V30) ni l'image 0.1.0.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [[ "$(id -u)" -ne 0 ]]; then
	echo "ERREUR : root requis (loop devices)"
	echo "  wsl -u root bash telmi-os/scripts/bake-v20.sh"
	exit 1
fi

SRC="$OUTPUT/soysauce-${VERSION}.img"
OUT="$OUTPUT/soysauce-${VERSION}-v20.img"
DTB="$STAGING/boot/rk3326-r36s-v20-linux.dtb"
DTB_NAME="rk3326-r36s-v20-linux.dtb"

[[ -f "$SRC" ]] || { echo "ERREUR : $SRC absent — baker V30 d'abord (bake-image.sh)"; exit 1; }
[[ -f "$DTB" ]] || { echo "ERREUR : $DTB — lancer build-dtb.sh"; exit 1; }
python3 - <<PY
from pathlib import Path
p = Path(r"$DTB")
assert p.read_bytes()[:4] == bytes.fromhex("d00dfeed"), "pas un FDT"
print("FDT OK", p.stat().st_size, "bytes")
PY

echo "==> copie $SRC -> $OUT"
cp -f "$SRC" "$OUT"

LOOP="$(losetup -Pf --show "$OUT")"
trap "umount /tmp/soy-v20-boot 2>/dev/null; rmdir /tmp/soy-v20-boot 2>/dev/null; losetup -d '$LOOP' 2>/dev/null || true" EXIT
mkdir -p /tmp/soy-v20-boot
mount "${LOOP}p1" /tmp/soy-v20-boot

cp -f "$DTB" "/tmp/soy-v20-boot/$DTB_NAME"
cp -f "$DTB" /tmp/soy-v20-boot/rk3326-odroidgo3-linux.dtb
cp -f "$DTB" /tmp/soy-v20-boot/rk3326-odroidgo2-linux.dtb
cp -f "$DTB" /tmp/soy-v20-boot/rk3326-odroidgo2-linux-v11.dtb
cp -f "$DTB" /tmp/soy-v20-boot/rk-kernel.dtb
# U-Boot 0.1.0 peut encore chercher le nom v30
cp -f "$DTB" /tmp/soy-v20-boot/rk3326-r36s-v30-linux.dtb

python3 - <<PY
from pathlib import Path
src = Path("$TELMIOS/boot/boot-v20.ini")
text = src.read_text(encoding="ascii", errors="replace").replace("\r\n", "\n").replace("\r", "\n")
Path("/tmp/soy-v20-boot/boot.ini").write_bytes(
    text.encode("ascii", errors="replace") + (b"" if text.endswith("\n") else b"\n")
)
print("boot.ini -> $DTB_NAME")
PY

printf 'v20' > /tmp/soy-v20-boot/TELMI-REV.txt
printf 'SPK' > /tmp/soy-v20-boot/TELMI-AUDIO-PATH.txt

echo "==> BOOT"
ls -lh /tmp/soy-v20-boot/*.dtb /tmp/soy-v20-boot/boot.ini
grep 'load mmc' /tmp/soy-v20-boot/boot.ini
echo -n "TELMI-REV="; cat /tmp/soy-v20-boot/TELMI-REV.txt; echo
echo -n "AUDIO="; cat /tmp/soy-v20-boot/TELMI-AUDIO-PATH.txt; echo
sync
umount /tmp/soy-v20-boot
rmdir /tmp/soy-v20-boot
losetup -d "$LOOP"
trap - EXIT

gzip -kf "$OUT"
echo "OK  $OUT"
ls -lh "$OUT" "$OUT.gz"
echo "    V30 intact : $SRC"
