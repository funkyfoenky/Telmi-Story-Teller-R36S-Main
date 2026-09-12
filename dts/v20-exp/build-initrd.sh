#!/usr/bin/env bash
# Mini initramfs aarch64 (busybox static) — copie exp, pas le bake officiel.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$SCRIPT_DIR/out"
WORK="$OUT/initrd-root"
DEB="$OUT/busybox-static-arm64.deb"
mkdir -p "$OUT" "$WORK"

if [[ ! -x "$WORK/busybox" ]]; then
	if [[ ! -f "$DEB" ]]; then
		echo "==> busybox-static arm64"
		wget -q -O "$DEB" \
			"http://ports.ubuntu.com/ubuntu-ports/pool/universe/b/busybox/busybox-static_1.30.1-4ubuntu6.4_arm64.deb"
	fi
	rm -rf "$OUT/busybox-deb"
	mkdir -p "$OUT/busybox-deb"
	dpkg-deb -x "$DEB" "$OUT/busybox-deb"
	cp -f "$OUT/busybox-deb/bin/busybox" "$WORK/busybox"
	chmod +x "$WORK/busybox"
	file "$WORK/busybox"
fi

cp -f "$SCRIPT_DIR/initrd-init.sh" "$WORK/init"
sed -i 's/\r$//' "$WORK/init"
chmod +x "$WORK/init"

# cpio newc, gzip (le noyau 4.4 a BLK_DEV_INITRD ; gzip = défaut kconfig)
rm -f "$OUT/telmi-dump.cpio" "$OUT/telmi-dump.cpio.gz" "$OUT/uInitrd-telmi"
(
	cd "$WORK"
	# init + busybox à la racine du ramfs
	printf 'busybox\ninit\n' | cpio -H newc -o
) > "$OUT/telmi-dump.cpio"
gzip -n -f "$OUT/telmi-dump.cpio"
ls -lh "$OUT/telmi-dump.cpio.gz"

MKIMAGE="$(command -v mkimage || true)"
if [[ -n "$MKIMAGE" ]]; then
	"$MKIMAGE" -A arm64 -O linux -T ramdisk -C gzip -n telmi-dump \
		-d "$OUT/telmi-dump.cpio.gz" "$OUT/uInitrd-telmi"
	ls -lh "$OUT/uInitrd-telmi"
else
	echo "WARN : mkimage absent — boot.ini devra passer addr:filesize"
fi
