#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
IMG="$OUTPUT/soysauce-${VERSION}.img"
LOOP="$(losetup -Pf --show "$IMG")"
trap "umount /tmp/v-boot /tmp/v-root /tmp/v-telmi 2>/dev/null; rmdir /tmp/v-boot /tmp/v-root /tmp/v-telmi 2>/dev/null; losetup -d '$LOOP'" EXIT
mkdir -p /tmp/v-boot /tmp/v-root /tmp/v-telmi
mount "${LOOP}p1" /tmp/v-boot
mount "${LOOP}p2" /tmp/v-root
mount "${LOOP}p3" /tmp/v-telmi
echo "=== BOOT (pas de uInitrd / telmi-runtime.sh) ==="
ls /tmp/v-boot
test ! -e /tmp/v-boot/uInitrd && echo "uInitrd=absent OK"
test ! -e /tmp/v-boot/telmi-runtime.sh && echo "runtime-pas-sur-BOOT OK"
echo "--- boot.ini ---"
cat /tmp/v-boot/boot.ini
echo "=== root overlay ==="
ls /tmp/v-root/opt/telmi/bin/
test -f /tmp/v-root/opt/telmi/lib/libSDL2_gfx-1.0.so.0 && echo "gfx=fichier OK"
grep -q 'hold fb0' /tmp/v-root/opt/telmi/bin/telmi-runtime.sh && echo "runtime-hold OK"
grep -q 'sound.target' /tmp/v-root/etc/systemd/system/telmi.service && echo "WARN sound.target" || echo "telmi.service=fast OK"
grep nofail /tmp/v-root/etc/fstab
echo "=== TELMI autorun ==="
cat /tmp/v-telmi/autorun.inf
ls -l /tmp/v-telmi/.tmp_update/res/sdcard.ico
