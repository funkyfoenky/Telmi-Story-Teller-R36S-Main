#!/usr/bin/env bash
# Cross-compile storyTeller / bootScreen / batmon (glibc aarch64, blit fb0).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if ! SYSROOT="$(resolve_sysroot)"; then
	echo "ERREUR : sysroot introuvable."
	echo "  Attendu : $CACHE/sysroot  ou  $LAB_SYSROOT"
	exit 1
fi
export SYSROOT

CC="${CC:-aarch64-linux-gnu-gcc}"
STRIP="${STRIP:-aarch64-linux-gnu-strip}"
if p="$(linaro_prefix 2>/dev/null)"; then
	CC="${p}gcc"
	STRIP="${p}strip"
fi

if ! command -v "$CC" >/dev/null 2>&1 && [[ ! -x "$CC" ]]; then
	echo "ERREUR : $CC introuvable. sudo apt install gcc-aarch64-linux-gnu  ou  make toolchain"
	exit 1
fi

LIBDIR="$SYSROOT/usr/lib/aarch64-linux-gnu"
[[ -d "$LIBDIR" ]] || LIBDIR="$SYSROOT/usr/lib"

# Debian SDL_config.h fait #include <SDL2/_real_SDL_config.h> (hors arbre SDL2/).
# Le sysroot labo n'a souvent que le _real_ x86_64 (immintrin.h) — on prend un .deb arm64.
INC="$CACHE/telmi-includes"
mkdir -p "$INC/SDL2"
need_arm_sdl_config() {
	[[ -f "$INC/SDL2/_real_SDL_config.h" ]] || return 0
	grep -q 'HAVE_ARMNEON\|HAVE_NEON\|__ARM_NEON' "$INC/SDL2/_real_SDL_config.h" && return 1
	grep -q 'HAVE_IMMINTRIN_H 1' "$INC/SDL2/_real_SDL_config.h" && return 0
	return 1
}
if need_arm_sdl_config; then
	echo "==> headers SDL2 arm64 (_real_SDL_config.h)"
	tmp="$(mktemp -d /tmp/sdl2dev-XXXX)"
	ok=0
	for url in \
		"http://ports.ubuntu.com/ubuntu-ports/pool/universe/libs/libsdl2/libsdl2-dev_2.30.0+dfsg-1ubuntu3_arm64.deb" \
		"http://ftp.debian.org/debian/pool/main/libs/libsdl2/libsdl2-dev_2.30.12+dfsg-1_arm64.deb" \
		"http://ports.ubuntu.com/ubuntu-ports/pool/universe/libs/libsdl2/libsdl2-dev_2.0.10+dfsg1-3_arm64.deb"
	do
		echo "    $url"
		if curl -fsSL --retry 2 -o "$tmp/pkg.deb" "$url"; then
			dpkg-deb -x "$tmp/pkg.deb" "$tmp/x"
			real="$(find "$tmp/x" -name '_real_SDL_config.h' | head -1)"
			[[ -z "$real" ]] && real="$(find "$tmp/x" -path '*aarch64*' -name 'SDL_config.h' | head -1)"
			[[ -z "$real" ]] && real="$(find "$tmp/x" -name 'SDL_config.h' | head -1)"
			if [[ -n "$real" ]]; then
				cp -f "$real" "$INC/SDL2/_real_SDL_config.h"
				ok=1
				break
			fi
		fi
	done
	rm -rf "$tmp"
	if [[ "$ok" -ne 1 ]]; then
		echo "WARN : pas de SDL_config arm64 — fallback x86_64 (risque immintrin)"
		if [[ -f "$SYSROOT/usr/include/x86_64-linux-gnu/SDL2/_real_SDL_config.h" ]]; then
			cp -f "$SYSROOT/usr/include/x86_64-linux-gnu/SDL2/_real_SDL_config.h" "$INC/SDL2/"
		fi
	fi
fi

EXTRA_CFLAGS="--sysroot=$SYSROOT -I$INC -I$SYSROOT/usr/include/aarch64-linux-gnu -I$SYSROOT/usr/include -I$SYSROOT/usr/include/SDL2"
EXTRA_LDFLAGS="--sysroot=$SYSROOT -L$LIBDIR -Wl,-rpath-link,$LIBDIR -Wl,-rpath-link,$SYSROOT/lib/aarch64-linux-gnu -Wl,--allow-shlib-undefined -lm"

write_sdl_gfx_wrapper() {
	mkdir -p "$SYSROOT/usr/include/SDL2"
	[[ -f "$SYSROOT/usr/include/SDL2/SDL_gfx.h" ]] && return 0
	{
		echo '#ifndef SDL_GFX_H'
		echo '#define SDL_GFX_H'
		echo '#include "SDL2_rotozoom.h"'
		echo '#include "SDL2_gfxPrimitives.h"'
		echo '#endif'
	} > "$SYSROOT/usr/include/SDL2/SDL_gfx.h"
}

fix_abs_so_symlinks() {
	local dir="$1" f t base
	[[ -d "$dir" ]] || return 0
	shopt -s nullglob
	for f in "$dir"/*.so "$dir"/*.so.*; do
		[[ -L "$f" ]] || continue
		t="$(readlink "$f")"
		case "$t" in
			/*)
				base="$(basename "$t")"
				ln -sfn "$base" "$f"
				;;
		esac
	done
	shopt -u nullglob
}

ensure_link_sonames() {
	local real
	real="$(basename "$(ls -1 "$LIBDIR"/libSDL2-2.0.so.0.[0-9]* 2>/dev/null | tail -1)")"
	if [[ -n "$real" && -f "$LIBDIR/$real" ]]; then
		ln -sfn "$real" "$LIBDIR/libSDL2-2.0.so.0"
		ln -sfn libSDL2-2.0.so.0 "$LIBDIR/libSDL2-2.0.so"
		ln -sfn libSDL2-2.0.so.0 "$LIBDIR/libSDL2.so"
	fi
	ln -sfn libpng16.so.16 "$LIBDIR/libpng16.so" 2>/dev/null || true
	ln -sfn libpng16.so.16 "$LIBDIR/libpng.so" 2>/dev/null || true
	ln -sfn libz.so.1 "$LIBDIR/libz.so" 2>/dev/null || true
	ln -sfn libfreetype.so.6 "$LIBDIR/libfreetype.so" 2>/dev/null || true
	ln -sfn libSDL2_image-2.0.so.0 "$LIBDIR/libSDL2_image.so" 2>/dev/null || true
	ln -sfn libSDL2_ttf-2.0.so.0 "$LIBDIR/libSDL2_ttf.so" 2>/dev/null || true
	ln -sfn libSDL2_mixer-2.0.so.0 "$LIBDIR/libSDL2_mixer.so" 2>/dev/null || true
	if [[ -e "$LIBDIR/libSDL2_gfx-1.0.so.0" ]]; then
		ln -sfn libSDL2_gfx-1.0.so.0 "$LIBDIR/libSDL2_gfx.so"
	fi
	# Ne pas parcourir tout le sysroot (NTFS / locales) — seulement les libs Telmi.
	for n in libSDL2 libSDL2_image libSDL2_ttf libSDL2_mixer libSDL2_gfx \
		libpng16 libz libfreetype libasound; do
		for f in "$LIBDIR"/${n}.so "$LIBDIR"/${n}.so.*; do
			[[ -L "$f" ]] || continue
			t="$(readlink "$f")"
			case "$t" in
				/*) ln -sfn "$(basename "$t")" "$f" ;;
			esac
		done
	done
}

ensure_sdl2_gfx() {
	if [[ -e "$LIBDIR/libSDL2_gfx-1.0.so.0" || -e "$LIBDIR/libSDL2_gfx.so" ]]; then
		ln -sfn libSDL2_gfx-1.0.so.0 "$LIBDIR/libSDL2_gfx.so" 2>/dev/null || true
		write_sdl_gfx_wrapper
		if [[ -f "$SYSROOT/usr/include/SDL2/SDL2_rotozoom.h" ]]; then
			return 0
		fi
	fi
	if [[ -f "$SYSROOT/usr/include/SDL2/SDL2_rotozoom.h" && -e "$LIBDIR/libSDL2_gfx.so" ]]; then
		write_sdl_gfx_wrapper
		return 0
	fi
	echo "==> libSDL2_gfx depuis les sources (ferzkopp)"
	local srcdir tarball url
	srcdir="$(mktemp -d /tmp/sdl2gfx-XXXXXX)"
	tarball="$srcdir/SDL2_gfx-1.0.4.tar.gz"
	url="https://www.ferzkopp.net/Software/SDL2_gfx/SDL2_gfx-1.0.4.tar.gz"
	if ! curl -fsSL "$url" -o "$tarball"; then
		echo "ERREUR : téléchargement SDL2_gfx échoué ($url)"
		rm -rf "$srcdir"
		return 1
	fi
	tar -xzf "$tarball" -C "$srcdir"
	mkdir -p "$SYSROOT/usr/include/SDL2" "$LIBDIR"
	cp -f "$srcdir"/SDL2_gfx-1.0.4/SDL2_*.h "$SYSROOT/usr/include/SDL2/"
	if [[ ! -e "$LIBDIR/libSDL2_gfx-1.0.so.0" && ! -e "$LIBDIR/libSDL2_gfx.so.0" ]]; then
		"$CC" -shared -fPIC -O2 \
			--sysroot="$SYSROOT" \
			-I"$SYSROOT/usr/include" -I"$SYSROOT/usr/include/SDL2" \
			-Wl,-soname,libSDL2_gfx.so.0 \
			-o "$LIBDIR/libSDL2_gfx.so.1.0.4" \
			"$srcdir"/SDL2_gfx-1.0.4/SDL2_framerate.c \
			"$srcdir"/SDL2_gfx-1.0.4/SDL2_gfxPrimitives.c \
			"$srcdir"/SDL2_gfx-1.0.4/SDL2_imageFilter.c \
			"$srcdir"/SDL2_gfx-1.0.4/SDL2_rotozoom.c \
			-L"$LIBDIR" -Wl,-rpath-link,"$LIBDIR" -lSDL2 -lm
		ln -sfn libSDL2_gfx.so.1.0.4 "$LIBDIR/libSDL2_gfx.so.0"
		ln -sfn libSDL2_gfx.so.0 "$LIBDIR/libSDL2_gfx.so"
	fi
	rm -rf "$srcdir"
	write_sdl_gfx_wrapper
}

ensure_link_sonames
ensure_sdl2_gfx

echo "============================================================"
echo " Build Telmi-os $VERSION (glibc fb0)"
echo " CC=$CC"
echo " SYSROOT=$SYSROOT"
echo "============================================================"

mkdir -p "$STAGING/opt/telmi/bin" "$STAGING/opt/telmi/lib"

make -C "$TELMIOS/src" \
	CC="$CC" \
	STRIP="$STRIP" \
	STAGING="$STAGING/opt/telmi/bin" \
	EXTRA_CFLAGS="$EXTRA_CFLAGS" \
	EXTRA_LDFLAGS="$EXTRA_LDFLAGS" \
	"${@:-all}"

for so in "$LIBDIR"/libSDL2_gfx.so* "$SYSROOT/usr/lib"/libSDL2_gfx.so*; do
	[[ -e "$so" ]] || continue
	cp -a "$so" "$STAGING/opt/telmi/lib/"
done

echo "OK  $STAGING/opt/telmi/bin/"
ls -la "$STAGING/opt/telmi/bin/"
ls -la "$STAGING/opt/telmi/lib/" 2>/dev/null || true
