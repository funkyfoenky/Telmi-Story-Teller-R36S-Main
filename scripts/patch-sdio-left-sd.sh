#!/usr/bin/env bash
# Slot gauche = dwmmc@ff380000 (sdio). Le GPIO CD du pack V30 ne voit
# souvent pas la carte : broken-cd + 3.3 V, sans cd-gpios ni UHS 1.8 V.
set -euo pipefail

patch_one() {
	local dtb="$1"
	[[ -f "$dtb" ]] || return 0
	if ! fdtget "$dtb" /dwmmc@ff380000 status >/dev/null 2>&1; then
		return 0
	fi
	fdtput -p "$dtb" /dwmmc@ff380000 broken-cd
	fdtput -p "$dtb" /dwmmc@ff380000 no-1-8-v
	fdtput -d "$dtb" /dwmmc@ff380000 cd-gpios 2>/dev/null || true
	local p
	for p in sd-uhs-sdr12 sd-uhs-sdr25 sd-uhs-sdr50 sd-uhs-sdr104; do
		fdtput -d "$dtb" /dwmmc@ff380000 "$p" 2>/dev/null || true
	done
}

if [[ $# -lt 1 ]]; then
	echo "Usage: $0 <dtb|directory>..." >&2
	exit 1
fi

command -v fdtput >/dev/null && command -v fdtget >/dev/null || {
	echo "ERREUR : fdtput/fdtget absents (device-tree-compiler)" >&2
	exit 1
}

n=0
for arg in "$@"; do
	if [[ -d "$arg" ]]; then
		while IFS= read -r -d '' f; do
			patch_one "$f"
			n=$((n + 1))
		done < <(find "$arg" -type f -name '*.dtb' -print0)
	else
		patch_one "$arg"
		n=$((n + 1))
	fi
done
echo "OK  sdio dual-SD patché ($n DTB)"
