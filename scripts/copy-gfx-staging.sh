#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
LIBDIR="$LAB_SYSROOT/usr/lib/aarch64-linux-gnu"
DST="$STAGING/opt/telmi/lib"
mkdir -p "$DST"
rm -f "$DST"/libSDL2_gfx.so "$DST"/libSDL2_gfx.so.*
cp -f "$LIBDIR/libSDL2_gfx-1.0.so.0" "$DST/"
cp -f "$LIBDIR/libSDL2_gfx-1.0.so.0" "$DST/libSDL2_gfx.so"
ls -la "$DST"
