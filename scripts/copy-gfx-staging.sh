#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
DST="$STAGING/opt/telmi/lib"
mkdir -p "$DST"

if [[ -e "$DST/libSDL2_gfx.so" || -e "$DST/libSDL2_gfx-1.0.so.0" ]]; then
	echo "OK  SDL2_gfx déjà dans $DST"
	ls -la "$DST"
	exit 0
fi

if ! SYSROOT="$(resolve_sysroot)"; then
	echo "WARN : pas de sysroot — SDL2_gfx sera fourni par make telmi"
	exit 0
fi
LIBDIR="$SYSROOT/usr/lib/aarch64-linux-gnu"
[[ -f "$LIBDIR/libSDL2_gfx-1.0.so.0" ]] || {
	echo "WARN : $LIBDIR/libSDL2_gfx-1.0.so.0 absent"
	exit 0
}
rm -f "$DST"/libSDL2_gfx.so "$DST"/libSDL2_gfx.so.*
cp -f "$LIBDIR/libSDL2_gfx-1.0.so.0" "$DST/"
cp -f "$LIBDIR/libSDL2_gfx-1.0.so.0" "$DST/libSDL2_gfx.so"
ls -la "$DST"
