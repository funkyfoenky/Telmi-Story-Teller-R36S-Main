#!/usr/bin/env bash
# libSDL2_gfx : prebuilt du depot, sinon sysroot de cross-compile.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

DST="$STAGING/opt/telmi/lib"
mkdir -p "$DST"
PRE="$TELMIOS/vendor/prebuilt/telmi/lib"
if [[ -f "$PRE/libSDL2_gfx-1.0.so.0" ]]; then
	cp -f "$PRE/libSDL2_gfx-1.0.so.0" "$DST/"
	cp -f "$PRE/libSDL2_gfx-1.0.so.0" "$DST/libSDL2_gfx.so"
	ls -la "$DST"
	exit 0
fi
if SYS="$(resolve_sysroot)"; then
	LIBDIR="$SYS/usr/lib/aarch64-linux-gnu"
	if [[ -f "$LIBDIR/libSDL2_gfx-1.0.so.0" ]]; then
		cp -f "$LIBDIR/libSDL2_gfx-1.0.so.0" "$DST/"
		cp -f "$LIBDIR/libSDL2_gfx-1.0.so.0" "$DST/libSDL2_gfx.so"
		ls -la "$DST"
		exit 0
	fi
fi
echo "WARN : libSDL2_gfx introuvable"
exit 1
