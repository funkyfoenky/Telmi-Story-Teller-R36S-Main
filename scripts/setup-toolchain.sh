#!/usr/bin/env bash
# Toolchain Linaro 6.3.1-2017.05 (celle du Image lcdyk). Gitignored.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

VER="6.3.1-2017.05"
NAME="gcc-linaro-${VER}-x86_64_aarch64-linux-gnu"
DEST="$CACHE/toolchains"
MARKER="$DEST/$NAME/bin/aarch64-linux-gnu-gcc"

if [[ -x "$MARKER" ]]; then
	echo "OK  déjà présent : $MARKER"
	exit 0
fi

mkdir -p "$DEST" "$CACHE"
TAR="$CACHE/${NAME}.tar.xz"
URLS=(
	"https://releases.linaro.org/components/toolchain/binaries/6.3-2017.05/aarch64-linux-gnu/${NAME}.tar.xz"
	"http://releases.linaro.org/components/toolchain/binaries/6.3-2017.05/aarch64-linux-gnu/${NAME}.tar.xz"
	"https://mirrors.edge.kernel.org/pub/tools/crosstool/files/bin/x86_64/6.3.1/${NAME}.tar.xz"
)

tar_ok() {
	local f="$1" sz
	[[ -f "$f" ]] || return 1
	sz="$(stat -c%s "$f" 2>/dev/null || echo 0)"
	[[ "$sz" -ge 50000000 ]]
}

if ! tar_ok "$TAR"; then
	rm -f "$TAR"
	for url in "${URLS[@]}"; do
		echo "==> téléchargement $url"
		if curl -fL --retry 3 -A "Mozilla/5.0" -o "$TAR" "$url"; then
			if tar_ok "$TAR"; then
				break
			fi
			echo "    (fichier trop petit — pas un tarball)"
			rm -f "$TAR"
		fi
	done
fi

if ! tar_ok "$TAR"; then
	echo "ERREUR : impossible de télécharger Linaro 6.3.1"
	echo "  Fallback : gcc-aarch64-linux-gnu du distro (peut casser le noyau 4.4)"
	exit 1
fi

echo "==> extraction -> $DEST"
tar -xJf "$TAR" -C "$DEST"
echo "OK  $MARKER"
