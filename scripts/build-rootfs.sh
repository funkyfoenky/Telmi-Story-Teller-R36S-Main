#!/usr/bin/env bash
# Rootfs Ubuntu focal arm64 minbase — Telmi-os 0.2.0 (pas d'ES, pas de réseau).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ROOTFS_TAR="${ROOTFS_TAR:-$CACHE/rootfs-telmi-os.tar}"
ROOTFS_DIR="$CACHE/rootfs-telmi-os"
SUITE="${SUITE:-focal}"
MIRROR="${MIRROR:-http://ports.ubuntu.com/ubuntu-ports}"

if [[ -f "$ROOTFS_TAR" ]]; then
	echo "OK  déjà présent : $ROOTFS_TAR"
	exit 0
fi

if [[ "$(id -u)" -ne 0 ]]; then
	echo "ERREUR : debootstrap exige root (wsl -u root bash scripts/build-rootfs.sh)"
	exit 1
fi

command -v debootstrap >/dev/null || { echo "ERREUR : apt install debootstrap qemu-user-static"; exit 1; }

install_qemu() {
	if [[ "$(uname -m)" == "aarch64" ]]; then
		return 0
	fi
	command -v qemu-aarch64-static >/dev/null || { echo "ERREUR : apt install qemu-user-static"; exit 1; }
	mkdir -p "$ROOTFS_DIR/usr/bin"
	cp -f "$(command -v qemu-aarch64-static)" "$ROOTFS_DIR/usr/bin/"
	if [[ -r /etc/resolv.conf ]]; then
		cp -L /etc/resolv.conf "$ROOTFS_DIR/etc/resolv.conf" 2>/dev/null || true
	fi
}

if [[ -x "$ROOTFS_DIR/bin/sh" ]]; then
	echo "==> reprise chroot existant $ROOTFS_DIR"
	install_qemu
else
	echo "==> debootstrap $SUITE arm64 minbase -> $ROOTFS_DIR"
	rm -rf "$ROOTFS_DIR"
	mkdir -p "$ROOTFS_DIR"

	if [[ "$(uname -m)" != "aarch64" ]]; then
		command -v qemu-aarch64-static >/dev/null || { echo "ERREUR : apt install qemu-user-static"; exit 1; }
		debootstrap --arch=arm64 --foreign --variant=minbase "$SUITE" "$ROOTFS_DIR" "$MIRROR"
		install_qemu
		chroot "$ROOTFS_DIR" /debootstrap/debootstrap --second-stage
	else
		debootstrap --arch=arm64 --variant=minbase "$SUITE" "$ROOTFS_DIR" "$MIRROR"
	fi
fi

cat > "$ROOTFS_DIR/etc/apt/sources.list" <<EOF
deb $MIRROR $SUITE main universe
deb $MIRROR $SUITE-updates main universe
deb $MIRROR $SUITE-security main universe
EOF

chroot "$ROOTFS_DIR" apt-get update -qq
chroot "$ROOTFS_DIR" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
	systemd systemd-sysv udev dbus \
	alsa-utils libasound2 \
	libsdl2-2.0-0 libsdl2-image-2.0-0 libsdl2-ttf-2.0-0 libsdl2-mixer-2.0-0 \
	libsdl2-gfx-1.0-0 \
	libpng16-16 libfreetype6 ca-certificates \
	dosfstools e2fsprogs util-linux mount kmod tzdata

# Slim : caches apt + docs
chroot "$ROOTFS_DIR" apt-get clean
rm -rf "$ROOTFS_DIR/var/lib/apt/lists/"* \
	"$ROOTFS_DIR/usr/share/doc/"* \
	"$ROOTFS_DIR/usr/share/man/"* \
	"$ROOTFS_DIR/usr/share/info/"* \
	"$ROOTFS_DIR/var/cache/apt/archives/"*.deb 2>/dev/null || true

echo "soysauce" > "$ROOTFS_DIR/etc/hostname"
cat > "$ROOTFS_DIR/etc/hosts" <<'EOF'
127.0.0.1	localhost
127.0.1.1	soysauce
::1		localhost ip6-localhost ip6-loopback
EOF

cat > "$ROOTFS_DIR/etc/fstab" <<'EOF'
LABEL=root / ext4 defaults,noatime 0 1
LABEL=BOOT /boot vfat defaults,umask=0077,nofail,x-systemd.device-timeout=3 0 0
EOF

tar -C "$ROOTFS_DIR" -cf "$ROOTFS_TAR" .
echo "OK  $ROOTFS_TAR"
ls -lh "$ROOTFS_TAR"
