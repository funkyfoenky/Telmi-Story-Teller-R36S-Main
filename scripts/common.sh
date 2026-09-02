#!/usr/bin/env bash
# Chemins Telmi-os. Cache toolchain / rootfs hors NTFS sous WSL.
TELMIOS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT="$(cd "$TELMIOS/.." && pwd)"
export TELMIOS PARENT
VERSION="$(tr -d '[:space:]' < "$TELMIOS/VERSION" 2>/dev/null || echo 0.2.3)"
if [[ -z "${CACHE:-}" ]]; then
	case "$TELMIOS" in
		/mnt/*) CACHE="${HOME}/.cache/telmi-os" ;;
		*) CACHE="$TELMIOS/cache" ;;
	esac
fi
STAGING="${STAGING:-$TELMIOS/staging}"
OUTPUT="${OUTPUT:-$TELMIOS/output}"
LINUX="${LINUX:-$PARENT/third_party/linux}"
UBOOT="${UBOOT:-$PARENT/third_party/u-boot}"
LAB_SYSROOT="${TELMI_SYSROOT:-$TELMIOS/sysroot}"

mkdir -p "$CACHE" "$STAGING" "$OUTPUT" "$STAGING/boot" "$STAGING/uboot" \
	"$STAGING/opt/telmi/bin" "$STAGING/opt/telmi/res" "$STAGING/opt/telmi/telmiVersion"

linaro_prefix() {
	local matches
	shopt -s nullglob
	matches=("$CACHE"/toolchains/gcc-linaro-*-aarch64-linux-gnu/bin/aarch64-linux-gnu-gcc)
	shopt -u nullglob
	if [[ ${#matches[@]} -ge 1 && -x "${matches[0]}" ]]; then
		echo "${matches[0]%-gcc}"
		return 0
	fi
	return 1
}

kernel_cross() {
	local p
	if p="$(linaro_prefix)"; then
		echo "$p"
		return 0
	fi
	echo "aarch64-linux-gnu-"
}

resolve_sysroot() {
	if [[ -n "${SYSROOT:-}" && -d "$SYSROOT/usr" ]]; then
		echo "$SYSROOT"
		return 0
	fi
	if [[ -d "$CACHE/sysroot/usr/lib/aarch64-linux-gnu" ]]; then
		echo "$CACHE/sysroot"
		return 0
	fi
	if [[ -d "$LAB_SYSROOT/usr/lib/aarch64-linux-gnu" ]]; then
		echo "$LAB_SYSROOT"
		return 0
	fi
	return 1
}
