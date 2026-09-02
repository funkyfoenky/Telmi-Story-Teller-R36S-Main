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

# make.sh odroidgoa exige Linaro à un chemin relatif figé.
PRE_ROOT="$CACHE/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu"
PRE_BIN="$PRE_ROOT/bin"
mkdir -p "$PRE_BIN"
echo "==> toolchain pour make.sh -> $PRE_BIN"
if p="$(linaro_prefix 2>/dev/null)"; then
	for f in "${p}"*; do
		[[ -e "$f" ]] && ln -sfn "$f" "$PRE_BIN/$(basename "$f")"
	done
else
	for t in gcc g++ as ld ar nm objcopy objdump strip ranlib size addr2line cpp readelf strings elfedit gcov gprof gcc-ar gcc-nm gcc-ranlib; do
		src="$(command -v aarch64-linux-gnu-$t || true)"
		[[ -n "$src" ]] && ln -sfn "$src" "$PRE_BIN/aarch64-linux-gnu-$t"
	done
fi
mkdir -p "$PARENT/third_party/prebuilts/gcc/linux-x86/aarch64"
ln -sfn "$PRE_ROOT" \
	"$PARENT/third_party/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu"

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
