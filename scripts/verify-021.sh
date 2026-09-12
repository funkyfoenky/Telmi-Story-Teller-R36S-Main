#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
IMG="$OUTPUT/telmi-r36-main-${VERSION}.img"
LOOP="$(losetup -Pf --show "$IMG")"
trap "umount /tmp/v21-boot /tmp/v21-root 2>/dev/null; rmdir /tmp/v21-boot /tmp/v21-root 2>/dev/null; losetup -d '$LOOP'" EXIT
mkdir -p /tmp/v21-boot /tmp/v21-root
mount "${LOOP}p1" /tmp/v21-boot
mount "${LOOP}p2" /tmp/v21-root
echo "=== BOOT ==="
ls /tmp/v21-boot/Select-DTB.bat /tmp/v21-boot/Select-TelmiDTB.ps1 /tmp/v21-boot/USE_DTB_SELECT_TO_SELECT_DEVICE
test ! -e /tmp/v21-boot/uInitrd && echo "uInitrd=absent OK"
echo "DTB packs: $(find /tmp/v21-boot/consoles -mindepth 1 -maxdepth 1 -type d ! -name logo ! -name dtbo | wc -l)"
echo "DTB files: $(find /tmp/v21-boot/consoles -name '*.dtb' | wc -l)"
grep 'booti' /tmp/v21-boot/boot.ini
echo "=== version ==="
cat /tmp/v21-root/opt/telmi/telmiVersion/image-version.txt; echo
