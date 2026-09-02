#!/usr/bin/env bash
# Noyau 4.4 telmi_defconfig → staging/boot/Image
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

[[ -f "$LINUX/Makefile" ]] || { echo "ERREUR : submodule linux absent"; exit 1; }

install -m 0644 "$TELMIOS/kconfig/telmi_defconfig" \
	"$LINUX/arch/arm64/configs/telmi_defconfig"

# Submodule fs/exfat souvent non initialisé — stub Kconfig (vfat suffit).
if [[ ! -f "$LINUX/fs/exfat/Kconfig" ]]; then
	mkdir -p "$LINUX/fs/exfat"
	cat > "$LINUX/fs/exfat/Kconfig" <<'EOF'
config EXFAT_FS
	tristate "exFAT (stub — submodule absent, vfat utilisé)"
	depends on BLOCK
	default n
EOF
fi

CROSS="$(kernel_cross)"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
# Objets hors NTFS (WSL /mnt/c) — sinon compile 4.4 interminable.
if [[ -z "${LINUX_O:-}" ]]; then
	if [[ "$LINUX" == /mnt/* ]]; then
		LINUX_O="${HOME}/.cache/telmi-os/linux-build"
	else
		LINUX_O="$LINUX"
	fi
fi
mkdir -p "$LINUX_O"
# gcc 13+ : le 4.4 n'est pas -Werror-clean. On saute gcc-wrapper.py (interdit les warnings).
if grep -q 'extern unsigned long max_gpufreq_khz' \
	"$LINUX/drivers/soc/rockchip/rockchip_opp_select.c" 2>/dev/null; then
	patch -d "$LINUX" -p1 --forward < "$TELMIOS/patches/kernel-max_gpufreq-stub.patch" || true
fi
export KCFLAGS="${KCFLAGS:--Wno-error -Wno-implicit-function-declaration -Wno-incompatible-pointer-types -fno-strict-aliasing}"
KMAKE=(make -C "$LINUX" ARCH=arm64 CROSS_COMPILE="$CROSS" CC="${CROSS}gcc" PYTHON=python3)
if [[ "$LINUX_O" != "$LINUX" ]]; then
	KMAKE+=("O=$LINUX_O")
fi
echo "==> kernel telmi_defconfig CROSS=$CROSS jobs=$JOBS O=$LINUX_O CC=${CROSS}gcc"
"${KMAKE[@]}" telmi_defconfig
"${KMAKE[@]}" -j"$JOBS" Image
# Nom kbuild 4.4 : gpio_keys.ko (pas gpio-keys). Reste un module (=m), jamais builtin.
"${KMAKE[@]}" -j"$JOBS" drivers/input/keyboard/gpio_keys.ko
if [[ "$LINUX_O" == "$LINUX" ]]; then
	IMG_OUT="$LINUX/arch/arm64/boot/Image"
	KO_OUT="$LINUX/drivers/input/keyboard/gpio_keys.ko"
else
	IMG_OUT="$LINUX_O/arch/arm64/boot/Image"
	KO_OUT="$LINUX_O/drivers/input/keyboard/gpio_keys.ko"
fi
install -m 0644 "$IMG_OUT" "$STAGING/boot/Image"
if [[ -f "$KO_OUT" ]]; then
	mkdir -p "$STAGING/opt/telmi/modules"
	install -m 0644 "$KO_OUT" "$STAGING/opt/telmi/modules/gpio_keys.ko"
	echo "OK  $STAGING/opt/telmi/modules/gpio_keys.ko"
else
	echo "WARN : gpio_keys.ko absent — Vol+/- ne probe pas (manette intacte)"
fi
echo "OK  $STAGING/boot/Image"
ls -lh "$STAGING/boot/Image"
