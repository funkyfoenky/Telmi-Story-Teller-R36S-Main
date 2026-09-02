#!/usr/bin/env bash
# Chaîne complète Telmi-os 0.2.0 (kernel + dtb + uboot + telmi + rootfs + image).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

echo "======== Telmi-os $VERSION (V30 only, image réduite) ========"
bash "$SCRIPT_DIR/setup-toolchain.sh"
bash "$SCRIPT_DIR/build-kernel.sh"
bash "$SCRIPT_DIR/build-dtb.sh"
bash "$SCRIPT_DIR/build-uboot.sh"
bash "$SCRIPT_DIR/build-telmi.sh"
bash "$SCRIPT_DIR/collect-assets.sh"
if [[ "$(id -u)" -eq 0 ]]; then
	bash "$SCRIPT_DIR/build-rootfs.sh"
	bash "$SCRIPT_DIR/bake-image.sh"
else
	echo "NOTE : rootfs + image exigent root :"
	echo "  wsl -u root bash $SCRIPT_DIR/build-rootfs.sh"
	echo "  wsl -u root bash $SCRIPT_DIR/bake-image.sh"
fi
