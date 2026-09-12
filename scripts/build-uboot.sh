#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

[[ -x "$UBOOT/make.sh" || -f "$UBOOT/Makefile" ]] || { echo "ERREUR : u-boot absent"; exit 1; }

RKBIN="$CACHE/rkbin"
if [[ ! -d "$RKBIN/bin" ]]; then
	echo "==> git clone rkbin (blobs, hors git) -> $RKBIN"
	git clone --depth 1 https://github.com/rockchip-linux/rkbin.git "$RKBIN"
fi

CROSS="$(kernel_cross)"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

# U-Boot 2017 (odroidgoa) ne boot pas s'il est compilé avec gcc 13.
# 0.3.8 a brické des consoles (écran noir rétroéclairé, pas de logo) pour ça.
if ! p="$(linaro_prefix 2>/dev/null)"; then
	echo "ERREUR : gcc-linaro 6.3.1 requis pour make uboot (pas le gcc distro)."
	echo "  Lancez : bash scripts/setup-toolchain.sh"
	echo "  En attendant, utilisez staging/uboot-0.3.7-known-good (bootloader connu bon)."
	exit 1
fi
ver="$("${p}gcc" -dumpversion 2>/dev/null || true)"
case "$ver" in
	6.*) ;;
	*)
		echo "ERREUR : ${p}gcc est gcc $ver — U-Boot odroidgoa exige Linaro 6.x"
		exit 1
		;;
esac

# make.sh odroidgoa exige Linaro à un chemin relatif figé.
PRE_ROOT="$CACHE/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu"
PRE_BIN="$PRE_ROOT/bin"
mkdir -p "$PRE_BIN"
echo "==> toolchain pour make.sh -> $PRE_BIN (${p}gcc $ver)"
for f in "${p}"*; do
	[[ -e "$f" ]] && ln -sfn "$f" "$PRE_BIN/$(basename "$f")"
done
mkdir -p "$CACHE/prebuilts/gcc/linux-x86/aarch64"
ln -sfn "$PRE_ROOT" \
	"$CACHE/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu"
# make.sh cherche ../prebuilts depuis third_party/u-boot (pas $CACHE).
mkdir -p "$TELMIOS/third_party"
ln -sfn "$CACHE/prebuilts" "$TELMIOS/third_party/prebuilts"

cd "$UBOOT"
# gcc 13 : u-boot 2017 traite tous les warnings en erreur.
sed -i 's/-fshort-wchar -Werror/-fshort-wchar -Wno-error/' Makefile
export RKBIN_DIR="$RKBIN" RKBIN="$RKBIN" CROSS_COMPILE="$CROSS"

if [[ -x ./make.sh ]]; then
	echo "==> ./make.sh odroidgoa"
	./make.sh odroidgoa
else
	make odroidgoa_defconfig || make rk3326_defconfig
	make -j"$JOBS"
fi

found=0
for f in sd_fuse/idbloader.img sd_fuse/uboot.img sd_fuse/trust.img \
	idbloader.img uboot.img trust.img; do
	if [[ -f "$f" ]]; then
		install -m 0644 "$f" "$STAGING/uboot/$(basename "$f")"
		found=1
	fi
done
[[ "$found" -eq 1 ]] || { echo "ERREUR : pas d'idbloader/uboot.img"; ls -la "$UBOOT" | head; exit 1; }
echo "OK  $STAGING/uboot"
ls -lh "$STAGING/uboot"
