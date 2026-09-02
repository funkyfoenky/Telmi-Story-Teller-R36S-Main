#!/usr/bin/env bash
# DTB v30 (DTS décompilé) + v20 (squelette 4.4 type2 + diffs stock).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

DTC="$(command -v dtc || true)"
if [[ -z "$DTC" && -x "$LINUX/scripts/dtc/dtc" ]]; then
	DTC="$LINUX/scripts/dtc/dtc"
fi
[[ -n "$DTC" ]] || { echo "ERREUR : dtc introuvable (apt install device-tree-compiler)"; exit 1; }

compile_v30() {
	local dts="$TELMIOS/dts/rk3326-r36s-v30-linux.dts"
	local out="$STAGING/boot/rk3326-r36s-v30-linux.dtb"
	[[ -f "$dts" ]] || { echo "ERREUR : $dts"; exit 1; }
	echo "==> dtc v30 $dts"
	# -f : le DTS décompilé a des phandles / labels parfois stricts
	"$DTC" -I dts -O dtb -f -o "$out" "$dts"
	echo "OK  $out"
	ls -lh "$out"
}

compile_v20() {
	local dts="$TELMIOS/dts/rk3326-r36s-v20-linux.dts"
	local out="$STAGING/boot/rk3326-r36s-v20-linux.dtb"
	local rk="$LINUX/arch/arm64/boot/dts/rockchip"
	local inc="$LINUX/scripts/dtc/include-prefixes"
	[[ -f "$dts" ]] || { echo "ERREUR : $dts"; exit 1; }
	[[ -d "$rk" ]] || { echo "ERREUR : $rk (submodule linux)"; exit 1; }
	echo "==> cpp+dtc v20 $dts"
	# Includes type2 du tree 4.4 (bindings + dtsi SoC).
	cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
		-I "$rk" -I "$LINUX/arch/arm64/boot/dts" \
		-I "$inc" -I "$LINUX/include" \
		"$dts" \
		| "$DTC" -I dts -O dtb -o "$out" -
	python3 - <<PY
from pathlib import Path
p = Path("$out")
assert p.read_bytes()[:4] == bytes.fromhex("d00dfeed"), "pas un FDT"
print("FDT OK", p.stat().st_size, "bytes")
PY
	echo "OK  $out"
	ls -lh "$out"
}

compile_v30
compile_v20
