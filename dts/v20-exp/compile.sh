#!/usr/bin/env bash
# Compile les DTB V20 expérimentaux (copies). Ne touche pas build-dtb.sh / v30.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELMIOS="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TELMIOS/scripts/common.sh"

DTC="$(command -v dtc || true)"
[[ -n "$DTC" ]] || { echo "ERREUR : dtc introuvable"; exit 1; }
RK="$LINUX/arch/arm64/boot/dts/rockchip"
INC="$LINUX/scripts/dtc/include-prefixes"
OUTDIR="$SCRIPT_DIR/out"
mkdir -p "$OUTDIR"

compile_one() {
	local src="$1"
	local name
	name="$(basename "$src" .dts).dtb"
	echo "==> $name"
	cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
		-I "$SCRIPT_DIR" -I "$TELMIOS/dts" -I "$RK" \
		-I "$LINUX/arch/arm64/boot/dts" -I "$INC" -I "$LINUX/include" \
		"$src" \
		| "$DTC" -I dts -O dtb -o "$OUTDIR/$name" -
	python3 -c "from pathlib import Path; p=Path(r'$OUTDIR/$name'); assert p.read_bytes()[:4]==bytes.fromhex('d00dfeed'); print('FDT', p.stat().st_size)"
}

compile_one "$SCRIPT_DIR/rk3326-r36s-v20-exp-type2-vanilla.dts"
compile_one "$SCRIPT_DIR/rk3326-r36s-v20-exp-type2-bcd.dts"
compile_one "$SCRIPT_DIR/rk3326-r36s-v20-exp-pb7-bcd.dts"
compile_one "$SCRIPT_DIR/rk3326-r36s-v20-exp-dsioff-bcd.dts"
ls -lh "$OUTDIR"
