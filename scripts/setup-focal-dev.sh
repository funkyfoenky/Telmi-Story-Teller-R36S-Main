#!/usr/bin/env bash
# Headers + crt Ubuntu 20.04 arm64 (glibc 2.31). Le gcc 13 du distro
# utilise sinon Scrt1.o / <sys/stat.h> de Ubuntu 24 → GLIBC_2.33/2.34.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

DEST="$CACHE/focal-dev"
MARKER="$DEST/usr/lib/aarch64-linux-gnu/crt1.o"
LINK="$CACHE/focal-link"
if [[ -f "$MARKER" && -f "$DEST/usr/include/stdio.h" && -f "$LINK/libc.so" && -f "$LINK/crt1.o" ]]; then
	echo "OK  $DEST + $LINK"
	exit 0
fi

POOL="http://ports.ubuntu.com/ubuntu-ports/pool"
PKGS=(
	"main/g/glibc/libc6-dev_2.31-0ubuntu9.18_arm64.deb"
	"main/l/linux/linux-libc-dev_5.4.0-218.238_arm64.deb"
	"main/libp/libpng1.6/libpng-dev_1.6.37-2_arm64.deb"
	"main/z/zlib/zlib1g-dev_1.2.11.dfsg-2ubuntu1.5_arm64.deb"
)

mkdir -p "$DEST" "$CACHE/focal-debs"
tmp="$(mktemp -d /tmp/focal-dev-XXXX)"
trap 'rm -rf "$tmp"' EXIT

for rel in "${PKGS[@]}"; do
	deb="$(basename "$rel")"
	url="$POOL/$rel"
	out="$CACHE/focal-debs/$deb"
	echo "==> $deb"
	if [[ ! -s "$out" ]]; then
		if ! curl -fL --retry 3 -o "$out" "$url"; then
			# zlib focal parfois 1.2.11.dfsg-2ubuntu1
			alt="${url/1.2.11.dfsg-2ubuntu1.5/1.2.11.dfsg-2ubuntu1}"
			if [[ "$alt" != "$url" ]]; then
				curl -fL --retry 3 -o "$out" "$alt"
			else
				exit 1
			fi
		fi
	fi
	dpkg-deb -x "$out" "$tmp/x"
done

mkdir -p "$DEST"
cp -a "$tmp/x/." "$DEST/"
[[ -f "$MARKER" ]] || { echo "ERREUR : crt1.o absent après extract"; exit 1; }
[[ -f "$DEST/usr/include/stdio.h" ]] || { echo "ERREUR : stdio.h absent"; exit 1; }

# Répertoire de lien : crt + libc.so réécrit (=sysroot). Les .so Focal
# pointent vers /lib/... de l'hôte et cassent le --sysroot.
ARCHLIB="$DEST/usr/lib/aarch64-linux-gnu"
rm -rf "$LINK"
mkdir -p "$LINK"
cp -a "$ARCHLIB/crt1.o" "$ARCHLIB/crti.o" "$ARCHLIB/crtn.o" "$LINK/"
[[ -f "$ARCHLIB/Scrt1.o" ]] && cp -a "$ARCHLIB/Scrt1.o" "$LINK/"
cp -a "$ARCHLIB/libc_nonshared.a" "$LINK/"
[[ -f "$ARCHLIB/libpthread_nonshared.a" ]] && cp -a "$ARCHLIB/libpthread_nonshared.a" "$LINK/"
cat > "$LINK/libc.so" <<'EOF'
OUTPUT_FORMAT(elf64-littleaarch64)
GROUP ( =/lib/aarch64-linux-gnu/libc.so.6 libc_nonshared.a AS_NEEDED ( =/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 ) )
EOF
cat > "$LINK/libpthread.so" <<'EOF'
OUTPUT_FORMAT(elf64-littleaarch64)
GROUP ( AS_NEEDED ( =/lib/aarch64-linux-gnu/libpthread.so.0 ) )
EOF

echo "OK  $DEST + $LINK"
