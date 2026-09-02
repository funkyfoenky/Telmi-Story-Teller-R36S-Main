#!/usr/bin/env bash
# Overlay Telmi-os + bins glibc sur un ROOTFS déjà monté (ext4).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
OVERLAY="$TELMIOS/overlay"
ROOT="${1:-}"
BUILD_ID="$(date -u '+%Y%m%dT%H%M%SZ')"

if [[ -z "$ROOT" ]]; then
	echo "Usage: $0 <ROOTFS_MONTÉ>"
	exit 1
fi
if [[ ! -d "$ROOT/etc" ]]; then
	echo "ERREUR: $ROOT n'est pas une racine Linux (pas de etc/)."
	ls -la "$ROOT" || true
	exit 1
fi

echo "==> Overlay Telmi-os $VERSION -> $ROOT"
install -d "$ROOT/opt/soysauce/bin" "$ROOT/opt/telmi/bin" "$ROOT/opt/telmi/lib" \
	"$ROOT/opt/telmi/res" "$ROOT/opt/telmi/telmiVersion" \
	"$ROOT/etc/systemd/system" "$ROOT/etc/systemd/system/multi-user.target.wants" \
	"$ROOT/etc/systemd/journald.conf.d" "$ROOT/etc/systemd/system.conf.d" \
	"$ROOT/etc/systemd/logind.conf.d" \
	"$ROOT/boot"

cp -f "$OVERLAY/opt/telmi/bin/telmi-runtime.sh" "$ROOT/opt/telmi/bin/"
cp -f "$OVERLAY/opt/telmi/bin/telmi-early-init.sh" "$ROOT/opt/telmi/bin/"
cp -f "$OVERLAY/opt/telmi/bin/telmi-mount-content.sh" "$ROOT/opt/telmi/bin/"
cp -f "$OVERLAY/opt/soysauce/bin/soysauce-telmi-stamp.sh" "$ROOT/opt/soysauce/bin/"
cp -f "$OVERLAY/etc/systemd/system/telmi.service" "$ROOT/etc/systemd/system/"
cp -f "$OVERLAY/etc/soysauce" "$ROOT/etc/soysauce"
if [[ -f "$OVERLAY/etc/systemd/journald.conf.d/telmi.conf" ]]; then
	cp -f "$OVERLAY/etc/systemd/journald.conf.d/telmi.conf" \
		"$ROOT/etc/systemd/journald.conf.d/"
fi
if [[ -f "$OVERLAY/etc/systemd/system.conf.d/telmi.conf" ]]; then
	cp -f "$OVERLAY/etc/systemd/system.conf.d/telmi.conf" \
		"$ROOT/etc/systemd/system.conf.d/"
fi
if [[ -f "$OVERLAY/etc/systemd/logind.conf.d/telmi.conf" ]]; then
	cp -f "$OVERLAY/etc/systemd/logind.conf.d/telmi.conf" \
		"$ROOT/etc/systemd/logind.conf.d/"
fi
rm -f "$ROOT/etc/asound.conf" "$ROOT/root/.asoundrc"

if [[ -d "$STAGING/opt/telmi/modules" ]]; then
	install -d "$ROOT/opt/telmi/modules"
	cp -a "$STAGING/opt/telmi/modules/." "$ROOT/opt/telmi/modules/" 2>/dev/null || true
fi
if [[ -x "$STAGING/opt/telmi/bin/storyTeller" ]]; then
	cp -f "$STAGING/opt/telmi/bin/"* "$ROOT/opt/telmi/bin/"
	chmod +x "$ROOT/opt/telmi/bin/"*
	echo "    bins Telmi copiés"
else
	echo "WARN : staging/opt/telmi/bin/storyTeller absent — compilez d'abord (make telmi)"
fi
if [[ -d "$STAGING/opt/telmi/lib" ]]; then
	cp -a "$STAGING/opt/telmi/lib/." "$ROOT/opt/telmi/lib/" 2>/dev/null || true
fi
if [[ -d "$STAGING/opt/telmi/res" ]]; then
	cp -a "$STAGING/opt/telmi/res/." "$ROOT/opt/telmi/res/" 2>/dev/null || true
	echo "    assets UI copiés"
fi
ICO_SRC=""
for c in \
	"$STAGING/opt/telmi/res/sdcard.ico" \
	"$PARENT/../Telmi-R36/assets/res/sdcard.ico"
do
	[[ -f "$c" ]] && ICO_SRC="$c" && break
done
if [[ -n "$ICO_SRC" ]]; then
	cp -f "$ICO_SRC" "$ROOT/opt/telmi/res/sdcard.ico"
fi

echo -n "$VERSION" > "$ROOT/opt/telmi/telmiVersion/image-version.txt"
echo -n "$BUILD_ID" > "$ROOT/opt/telmi/telmiVersion/build-id.txt"
echo -n "telmi-os" > "$ROOT/opt/telmi/telmiVersion/profile.txt"

chmod +x "$ROOT/opt/telmi/bin/"*.sh "$ROOT/opt/soysauce/bin/"*.sh
sed -i 's/\r$//' "$ROOT/opt/telmi/bin/telmi-runtime.sh" \
	"$ROOT/opt/telmi/bin/telmi-early-init.sh" \
	"$ROOT/opt/telmi/bin/telmi-mount-content.sh" \
	"$ROOT/opt/soysauce/bin/soysauce-telmi-stamp.sh" \
	"$ROOT/etc/systemd/system/telmi.service"

# BOOT ne doit pas bloquer systemd (nofail, pas de fsck).
if [[ -f "$ROOT/etc/fstab" ]]; then
	sed -i 's|^LABEL=BOOT .*|LABEL=BOOT /boot vfat defaults,umask=0077,nofail,x-systemd.device-timeout=3 0 0|' \
		"$ROOT/etc/fstab"
fi

ln -sfn /etc/systemd/system/telmi.service \
	"$ROOT/etc/systemd/system/multi-user.target.wants/telmi.service"

mask_unit() {
	local name="$1"
	local unit="$ROOT/etc/systemd/system/$name"
	if [[ -f "$unit" && ! -L "$unit" ]]; then
		mv -f "$unit" "$unit.telmi-bak"
	fi
	ln -sfn /dev/null "$unit"
	rm -f "$ROOT/etc/systemd/system/multi-user.target.wants/$name" 2>/dev/null || true
}
mask_unit getty@tty1.service
mask_unit getty@tty2.service
mask_unit console-getty.service
mask_unit alsa-restore.service
mask_unit alsa-state.service
mask_unit NetworkManager.service
mask_unit NetworkManager-wait-online.service
mask_unit systemd-networkd.service
mask_unit systemd-networkd-wait-online.service
mask_unit systemd-resolved.service
mask_unit systemd-timesyncd.service
mask_unit ssh.service
mask_unit ssh.socket
mask_unit apt-daily.service
mask_unit apt-daily.timer
mask_unit apt-daily-upgrade.timer
mask_unit systemd-udev-settle.service
mask_unit motd-news.service
mask_unit motd-news.timer
mask_unit e2scrub_all.timer
mask_unit e2scrub_reap.service

# Pas de mot de passe root (console série éventuelle).
chroot "$ROOT" passwd -d root 2>/dev/null || true

sync
echo "OK  overlay Telmi-os injecté."
