#!/usr/bin/env bash
# Assemble telmi-os/output/soysauce-0.2.0.img — V30 only, tailles réduites.
# Image 0.1.0 : lecture seule (U-Boot blobs), jamais écrite.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [[ "$(id -u)" -ne 0 ]]; then
	echo "ERREUR : le bake d'image exige root (loop devices)."
	echo "  wsl -u root bash scripts/bake-image.sh"
	exit 1
fi

need() {
	local f="$1"
	[[ -e "$f" ]] || { echo "ERREUR : artefact manquant : $f"; exit 1; }
}

bash "$SCRIPT_DIR/seed-prebuilt.sh"

need "$STAGING/boot/Image"
need "$STAGING/boot/rk3326-r36s-v30-linux.dtb"
need "$STAGING/opt/telmi/bin/storyTeller"

ROOTFS_TAR="${ROOTFS_TAR:-$CACHE/rootfs-telmi-os.tar}"
if [[ ! -f "$ROOTFS_TAR" ]]; then
	echo "==> pas de rootfs tar — build-rootfs.sh"
	bash "$SCRIPT_DIR/build-rootfs.sh"
fi
need "$ROOTFS_TAR"

bash "$SCRIPT_DIR/collect-assets.sh"
bash "$SCRIPT_DIR/copy-gfx-staging.sh"

VENDOR="${TELMI_VENDOR:-$TELMIOS/vendor/arkos4clone}"
UBDIR="${TELMIOS}/vendor/prebuilt/uboot"
if [[ ! -s "$UBDIR/idbloader.img" || ! -s "$UBDIR/uboot.img" ]]; then
	UBDIR="$STAGING/uboot"
fi
need "$VENDOR/logo.bmp"
need "$VENDOR/rk3326-r36s-v30-linux.dtb"
need "$UBDIR/idbloader.img"
need "$UBDIR/uboot.img"

IMG="$OUTPUT/soysauce-${VERSION}.img"
BOOT_MIB=128
ROOT_MIB=768
TELMI_MIB=256
GAP_MIB=16
TOTAL_MIB=$((GAP_MIB + BOOT_MIB + ROOT_MIB + TELMI_MIB + 8))

echo "==> $IMG (${TOTAL_MIB} MiB) VERSION=$VERSION DTB=ArkOS4Clone+Select-DTB"
mkdir -p "$OUTPUT"
rm -f "$IMG"
dd if=/dev/zero of="$IMG" bs=1M count="$TOTAL_MIB" status=progress

dd if="$UBDIR/idbloader.img" of="$IMG" conv=notrunc seek=64
dd if="$UBDIR/uboot.img" of="$IMG" conv=notrunc seek=16384
if [[ -f "$UBDIR/trust.img" ]]; then
	dd if="$UBDIR/trust.img" of="$IMG" conv=notrunc seek=24576
fi

parted -s "$IMG" mklabel msdos
parted -s "$IMG" unit MiB mkpart primary fat32 "$GAP_MIB" $((GAP_MIB + BOOT_MIB))
parted -s "$IMG" unit MiB mkpart primary ext4 $((GAP_MIB + BOOT_MIB)) $((GAP_MIB + BOOT_MIB + ROOT_MIB))
parted -s "$IMG" unit MiB mkpart primary fat32 $((GAP_MIB + BOOT_MIB + ROOT_MIB)) $((GAP_MIB + BOOT_MIB + ROOT_MIB + TELMI_MIB))
parted -s "$IMG" set 1 boot on

LOOP="$(losetup -Pf --show "$IMG")"
# shellcheck disable=SC2064
trap "losetup -d '$LOOP' 2>/dev/null || true" EXIT
udevadm settle 2>/dev/null || sleep 1
P1="${LOOP}p1"
P2="${LOOP}p2"
P3="${LOOP}p3"

mkfs.vfat -F 32 -n BOOT "$P1"
mkfs.ext4 -F -L root "$P2"
mkfs.vfat -F 32 -n TELMI "$P3"

MBOOT="$(mktemp -d /tmp/soy-boot-XXXX)"
MROOT="$(mktemp -d /tmp/soy-root-XXXX)"
MTELMI="$(mktemp -d /tmp/soy-telmi-XXXX)"
mount "$P1" "$MBOOT"
mount "$P2" "$MROOT"
mount "$P3" "$MTELMI"

cp -f "$STAGING/boot/Image" "$MBOOT/Image"
# DTB vendor v30 (aliases U-Boot Odroid avant boot.ini).
DTB="$VENDOR/rk3326-r36s-v30-linux.dtb"
cp -f "$DTB" "$MBOOT/rk3326-r36s-v30-linux.dtb"
cp -f "$DTB" "$MBOOT/rk3326-odroidgo3-linux.dtb"
cp -f "$DTB" "$MBOOT/rk3326-odroidgo2-linux.dtb"
cp -f "$DTB" "$MBOOT/rk3326-odroidgo2-linux-v11.dtb"
cp -f "$DTB" "$MBOOT/rk-kernel.dtb"
cp -f "$VENDOR/logo.bmp" "$MBOOT/logo.bmp"

python3 - <<PY
from pathlib import Path
src = Path("$TELMIOS/boot/boot.ini")
text = src.read_text(encoding="ascii", errors="replace").replace("\r\n", "\n").replace("\r", "\n")
Path("$MBOOT/boot.ini").write_bytes(text.encode("ascii", errors="replace") + (b"" if text.endswith("\n") else b"\n"))
PY

echo -n "SPK" > "$MBOOT/TELMI-AUDIO-PATH.txt"
: > "$MBOOT/doneit"
: > "$MBOOT/telmi-runtime.log"

echo "==> consoles ArkOS4Clone + Select-DTB"
CONS_SRC="$VENDOR/consoles"
if [[ ! -d "$CONS_SRC" ]]; then
	echo "ERREUR : $CONS_SRC introuvable"
	exit 1
fi
cp -r --no-preserve=ownership "$CONS_SRC" "$MBOOT/consoles"
# Pas les Images ArkOS dans consoles/kernel (BOOT trop petit / mauvais noyau).
rm -rf "$MBOOT/consoles/kernel"
# Cmdline Telmi dans les packs (le nom du DTB est conserve).
ARGS='root=/dev/mmcblk0p2 rootwait rw fsck.mode=skip net.ifnames=0 fbcon=map:9 vt.global_cursor_default=0 console=/dev/ttyFIQ0 quiet loglevel=3 nosplash plymouth.enable=0 consoleblank=0 systemd.show_status=false max_cpufreq=1296 boot_cpufreq=1248 max_gpufreq=520 max_ddrfreq=666'
find "$MBOOT/consoles" -type f -name boot.ini -print0 | while IFS= read -r -d '' f; do
	sed -i "s|setenv bootargs \".*\"|setenv bootargs \"$ARGS\"|" "$f"
	sed -i 's/\r$//' "$f"
done
SEL="$TELMIOS/dtb-selector"
cp -f "$SEL/Select-DTB.bat" "$MBOOT/Select-DTB.bat"
cp -f "$SEL/Select-SoysauceDTB.ps1" "$MBOOT/Select-SoysauceDTB.ps1"
cp -f "$SEL/boot.ini.template" "$MBOOT/boot.ini.template"
sed -i 's/\r$//' "$MBOOT/Select-DTB.bat" "$MBOOT/boot.ini.template" || true
if [[ -f "$VENDOR/USE_DTB_SELECT_TO_SELECT_DEVICE" ]]; then
	cp -f "$VENDOR/USE_DTB_SELECT_TO_SELECT_DEVICE" "$MBOOT/USE_DTB_SELECT_TO_SELECT_DEVICE"
else
	: > "$MBOOT/USE_DTB_SELECT_TO_SELECT_DEVICE"
fi
echo "    $(find "$MBOOT/consoles" -name '*.dtb' | wc -l) DTB, Select-DTB.bat"

echo "==> rootfs"
tar -C "$MROOT" -xf "$ROOTFS_TAR"
bash "$SCRIPT_DIR/patch-rootfs.sh" "$MROOT"

echo "==> TELMI skel"
mkdir -p "$MTELMI/Stories" "$MTELMI/Music" "$MTELMI/Saves/Stories" "$MTELMI/logs" \
	"$MTELMI/.tmp_update/res"
if [[ -d "$TELMIOS/content-skel" ]]; then
	cp -r --no-preserve=ownership "$TELMIOS/content-skel/." "$MTELMI/" || \
		cp -r "$TELMIOS/content-skel/." "$MTELMI/" || true
fi
cat > "$MTELMI/autorun.inf" <<'EOF'
[autorun]
icon  = .tmp_update/res/sdcard.ico
label = TelmiOS-v1.10.1
EOF
sed -i 's/\r$//' "$MTELMI/autorun.inf"
ICO=""
for c in \
	"$STAGING/opt/telmi/res/sdcard.ico" \
	"$TELMIOS/res/sdcard.ico" \
	"$TELMIOS/content-skel/.tmp_update/res/sdcard.ico"
do
	[[ -f "$c" ]] && ICO="$c" && break
done
if [[ -n "$ICO" ]]; then
	cp -f "$ICO" "$MTELMI/.tmp_update/res/sdcard.ico"
	cp -f "$ICO" "$MROOT/opt/telmi/res/sdcard.ico"
fi

sync
umount "$MBOOT" "$MROOT" "$MTELMI"
rmdir "$MBOOT" "$MROOT" "$MTELMI"
losetup -d "$LOOP"
trap - EXIT

gzip -kf "$IMG"
echo "OK  $IMG"
echo "    ${IMG}.gz"
ls -lh "$IMG" "$IMG.gz"
