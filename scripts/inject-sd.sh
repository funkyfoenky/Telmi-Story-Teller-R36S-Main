#!/usr/bin/env bash
# Patche la partition root ext4 de la SD (via WSL / usbipd).
# BOOT (FAT) : logs uniquement — on n'y copie pas de bins ni de runtime.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [[ "$(id -u)" -ne 0 ]]; then
	echo "ERREUR : root requis (wsl -u root)"
	exit 1
fi

ROOTDEV="$(lsblk -ln -o NAME,FSTYPE,LABEL | awk '$2=="ext4" && ($3=="root" || $3=="ROOTFS"){print "/dev/"$1; exit}')"
if [[ -z "$ROOTDEV" ]]; then
	echo "ERREUR : partition ext4 LABEL=root introuvable dans WSL."
	echo "  Sur Windows (admin) : usbipd attach --wsl --busid 1-1"
	lsblk -o NAME,FSTYPE,LABEL,SIZE,MOUNTPOINT
	exit 1
fi

echo "==> root $ROOTDEV"
mkdir -p /mnt/telmi-root
if mountpoint -q /mnt/telmi-root; then
	umount /mnt/telmi-root
fi
mount -t ext4 "$ROOTDEV" /mnt/telmi-root

bash "$TELMIOS/scripts/patch-rootfs.sh" /mnt/telmi-root

# Vraie libSDL2_gfx (pas un symlink cassé).
mkdir -p /mnt/telmi-root/opt/telmi/lib
rm -f /mnt/telmi-root/opt/telmi/lib/libSDL2_gfx.so \
	/mnt/telmi-root/opt/telmi/lib/libSDL2_gfx.so.0 \
	/mnt/telmi-root/opt/telmi/lib/libSDL2_gfx-1.0.so.0
if [[ -e "$STAGING/opt/telmi/lib/libSDL2_gfx-1.0.so.0" ]]; then
	cp -f "$STAGING/opt/telmi/lib/libSDL2_gfx-1.0.so.0" \
		/mnt/telmi-root/opt/telmi/lib/libSDL2_gfx-1.0.so.0
	cp -f "$STAGING/opt/telmi/lib/libSDL2_gfx-1.0.so.0" \
		/mnt/telmi-root/opt/telmi/lib/libSDL2_gfx.so
elif [[ -e /mnt/telmi-root/usr/lib/aarch64-linux-gnu/libSDL2_gfx-1.0.so.0 ]]; then
	cp -f /mnt/telmi-root/usr/lib/aarch64-linux-gnu/libSDL2_gfx-1.0.so.0 \
		/mnt/telmi-root/opt/telmi/lib/
	cp -f /mnt/telmi-root/usr/lib/aarch64-linux-gnu/libSDL2_gfx-1.0.so.0 \
		/mnt/telmi-root/opt/telmi/lib/libSDL2_gfx.so
fi

echo "    /opt/telmi/bin :"
ls -l /mnt/telmi-root/opt/telmi/bin/bootScreen \
	/mnt/telmi-root/opt/telmi/bin/storyTeller \
	/mnt/telmi-root/opt/telmi/bin/telmi-runtime.sh
echo "    /opt/telmi/lib :"
ls -l /mnt/telmi-root/opt/telmi/lib/ || true

sync
umount /mnt/telmi-root

# Nettoyer BOOT : pas de bins / runtime, uniquement de la place pour les logs.
BOOTDEV="$(lsblk -ln -o NAME,FSTYPE,LABEL | awk '$3=="BOOT"{print "/dev/"$1; exit}')"
if [[ -n "$BOOTDEV" ]]; then
	echo "==> BOOT $BOOTDEV (nettoie leftovers, logs conservés)"
	mkdir -p /mnt/telmi-boot
	if mountpoint -q /mnt/telmi-boot; then
		umount /mnt/telmi-boot
	fi
	mount -t vfat "$BOOTDEV" /mnt/telmi-boot
	rm -f /mnt/telmi-boot/telmi-runtime.sh \
		/mnt/telmi-boot/bootScreen \
		/mnt/telmi-boot/storyTeller \
		/mnt/telmi-boot/batmon
	rm -rf /mnt/telmi-boot/telmi-lib
	# boot.ini : sans uInitrd, init early-log. LF only.
	cp -f "$TELMIOS/boot/boot.ini" /mnt/telmi-boot/boot.ini
	sed -i 's/\r$//' /mnt/telmi-boot/boot.ini
	: > /mnt/telmi-boot/telmi-runtime.log
	date -u '+%Y-%m-%dT%H:%M:%SZ inject-sd boot-fast' > /mnt/telmi-boot/TELMI-INJECT.txt
	sync
	umount /mnt/telmi-boot
fi

TELDEV="$(lsblk -ln -o NAME,FSTYPE,LABEL | awk '$3=="TELMI"{print "/dev/"$1; exit}')"
if [[ -n "$TELDEV" ]]; then
	echo "==> TELMI $TELDEV (autorun.inf + icone Sync)"
	mkdir -p /mnt/telmi-content
	if mountpoint -q /mnt/telmi-content; then
		umount /mnt/telmi-content
	fi
	mount -t vfat "$TELDEV" /mnt/telmi-content
	mkdir -p /mnt/telmi-content/.tmp_update/res
	cat > /mnt/telmi-content/autorun.inf <<'EOF'
[autorun]
icon  = .tmp_update/res/sdcard.ico
label = TelmiOS-v1.10.1
EOF
	sed -i 's/\r$//' /mnt/telmi-content/autorun.inf
	ICO=""
	for c in \
		"$STAGING/opt/telmi/res/sdcard.ico" \
		"$TELMIOS/content-skel/.tmp_update/res/sdcard.ico" \
		"$PARENT/../Telmi-R36/assets/res/sdcard.ico"
	do
		if [[ -f "$c" ]]; then
			ICO="$c"
			break
		fi
	done
	if [[ -n "$ICO" ]]; then
		cp -f "$ICO" /mnt/telmi-content/.tmp_update/res/sdcard.ico
		echo "    icone depuis $ICO"
	else
		echo "WARN : sdcard.ico introuvable"
	fi
	echo "    autorun.inf :"
	cat /mnt/telmi-content/autorun.inf
	sync
	umount /mnt/telmi-content
fi

echo "OK  root ext4 patché. Détache le lecteur (usbipd detach) puis reteste."
