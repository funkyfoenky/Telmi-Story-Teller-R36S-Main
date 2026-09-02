#!/usr/bin/env bash
# Place les artefacts prebuilt dans staging/ (Image, bins, U-Boot, DTB, gfx).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

PRE="${TELMI_PREBUILT:-$TELMIOS/vendor/prebuilt}"
VENDOR="${TELMI_VENDOR:-$TELMIOS/vendor/arkos4clone}"

mkdir -p "$STAGING/boot" "$STAGING/uboot" \
	"$STAGING/opt/telmi/bin" "$STAGING/opt/telmi/lib"

if [[ -f "$PRE/boot/Image" ]]; then
	cp -f "$PRE/boot/Image" "$STAGING/boot/Image"
fi
if [[ -f "$VENDOR/rk3326-r36s-v30-linux.dtb" ]]; then
	cp -f "$VENDOR/rk3326-r36s-v30-linux.dtb" "$STAGING/boot/rk3326-r36s-v30-linux.dtb"
fi
if [[ -d "$PRE/telmi/bin" ]]; then
	cp -f "$PRE/telmi/bin/"* "$STAGING/opt/telmi/bin/"
	chmod +x "$STAGING/opt/telmi/bin/"* 2>/dev/null || true
fi
if [[ -d "$PRE/telmi/lib" ]]; then
	cp -a "$PRE/telmi/lib/." "$STAGING/opt/telmi/lib/"
fi
if [[ -d "$PRE/telmi/modules" ]]; then
	mkdir -p "$STAGING/opt/telmi/modules"
	cp -a "$PRE/telmi/modules/." "$STAGING/opt/telmi/modules/"
fi
if [[ -d "$PRE/uboot" ]]; then
	cp -f "$PRE/uboot/"*.img "$STAGING/uboot/" 2>/dev/null || true
fi

echo "OK  staging depuis vendor/prebuilt"
ls -lh "$STAGING/boot/Image" "$STAGING/opt/telmi/bin/storyTeller" \
	"$STAGING/uboot/idbloader.img" 2>/dev/null || true
