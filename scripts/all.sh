#!/usr/bin/env bash
# Bake image 0.2.3 : prebuilts du depot + debootstrap rootfs (root).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

echo "======== Telmi-os $VERSION ========"
bash "$SCRIPT_DIR/seed-prebuilt.sh"
bash "$SCRIPT_DIR/collect-assets.sh"
if [[ "$(id -u)" -eq 0 ]]; then
	bash "$SCRIPT_DIR/build-rootfs.sh"
	bash "$SCRIPT_DIR/bake-image.sh"
else
	echo "Le bake exige root (loop + debootstrap) :"
	echo "  wsl -u root bash $SCRIPT_DIR/all.sh"
	exit 1
fi
