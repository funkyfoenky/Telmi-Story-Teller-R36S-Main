#!/usr/bin/env bash
# Paquets hôte WSL pour compiler Telmi-os 0.2.0.
set -euo pipefail
if [[ "$(id -u)" -ne 0 ]]; then
	echo "ERREUR : apt exige root — wsl -u root bash scripts/setup-host.sh"
	exit 1
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
	build-essential bc bison flex libssl-dev libncurses-dev \
	gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
	device-tree-compiler u-boot-tools \
	debootstrap qemu-user-static binfmt-support \
	parted dosfstools e2fsprogs rsync curl python3 \
	cpio gzip git ca-certificates \
	pkg-config python-is-python3
echo "OK  paquets hôte"
