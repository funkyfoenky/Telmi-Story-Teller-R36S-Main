#!/usr/bin/env bash
# Packs Select-DTB : boot.ini (arkos4clone-src) + DTB compilés depuis le noyau 4.4.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

CONS_SRC="$TELMIOS/third_party/arkos4clone-src/consoles"
DEST="$STAGING/boot/consoles"
RK="$LINUX/arch/arm64/boot/dts/rockchip"
INC="$LINUX/scripts/dtc/include-prefixes"
DTB_DIR="$STAGING/boot/dtbs-arkos"

[[ -d "$CONS_SRC" ]] || { echo "ERREUR : $CONS_SRC"; exit 1; }
[[ -d "$RK" ]] || { echo "ERREUR : $RK (noyau)"; exit 1; }
DTC="$(resolve_dtc)" || { echo "ERREUR : dtc introuvable"; exit 1; }

mkdir -p "$DTB_DIR"
echo "==> compile DTB ArkOS4Clone depuis $RK"
shopt -s nullglob
for dts in "$RK"/rk3326-*.dts; do
	name="$(basename "$dts" .dts).dtb"
	out="$DTB_DIR/$name"
	if [[ -f "$out" && "$out" -nt "$dts" ]]; then
		continue
	fi
	if ! cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
		-I "$RK" -I "$LINUX/arch/arm64/boot/dts" \
		-I "$INC" -I "$LINUX/include" \
		"$dts" 2>/dev/null \
		| "$DTC" -I dts -O dtb -o "$out" - 2>/dev/null; then
		rm -f "$out"
		echo "    skip $(basename "$dts")"
	fi
done
shopt -u nullglob

# Pack Telmi « v22 panel4 » : même DTB qu'origin panel4 type2 (lcdyk adjust name).
# Anciens boot.ini éventuels (snapshot pré-20260826).
alias_dtb() {
	local src="$DTB_DIR/$1" dst="$DTB_DIR/$2"
	if [[ -f "$src" ]]; then
		cp -f "$src" "$dst"
		echo "    alias $2 <- $1"
	fi
}
alias_dtb rk3326-r36s-panel4-type2-linux.dtb rk3326-r36s-v22-linux.dtb
alias_dtb rk3326-r36s-panel4-type1-linux.dtb rk3326-r36s-panel4-linux.dtb
alias_dtb rk3326-rg351v-panel1-linux.dtb rk3326-rg351v-linux.dtb
alias_dtb rk3326-rg351v-panel2-linux.dtb rk3326-rg351v-v2-linux.dtb
alias_dtb rk3326-u8-panel1-linux.dtb rk3326-u8-linux.dtb
alias_dtb rk3326-u8-panel2-linux.dtb rk3326-u8-v2-linux.dtb

# v30 Telmi (DTS décompilé, pas dans le tree lcdyk).
if [[ -f "$STAGING/boot/rk3326-r36s-v30-linux.dtb" ]]; then
	cp -f "$STAGING/boot/rk3326-r36s-v30-linux.dtb" "$DTB_DIR/rk3326-r36s-v30-linux.dtb"
	echo "    v30 <- staging/boot"
elif [[ -f "$TELMIOS/dts/rk3326-r36s-v30-linux.dts" ]]; then
	echo "==> dtc v30"
	"$DTC" -I dts -O dtb -f -o "$DTB_DIR/rk3326-r36s-v30-linux.dtb" \
		"$TELMIOS/dts/rk3326-r36s-v30-linux.dts"
fi
if [[ -f "$STAGING/boot/rk3326-r36s-v20-linux.dtb" ]]; then
	cp -f "$STAGING/boot/rk3326-r36s-v20-linux.dtb" "$DTB_DIR/rk3326-r36s-v20-linux.dtb"
fi

rm -rf "$DEST"
mkdir -p "$DEST"
cp -a "$CONS_SRC/." "$DEST/"
rm -rf "$DEST/kernel" "$DEST/dtbo" "$DEST/logo"

n_ok=0
n_miss=0
for dir in "$DEST"/*/; do
	ini="$dir/boot.ini"
	[[ -f "$ini" ]] || continue
	dtb="$(grep -oE 'rk3326-[A-Za-z0-9._-]+\.dtb' "$ini" | head -1 || true)"
	[[ -n "$dtb" ]] || continue
	if [[ -f "$DTB_DIR/$dtb" ]]; then
		cp -f "$DTB_DIR/$dtb" "$dir/"
		n_ok=$((n_ok + 1))
	else
		echo "    WARN : pas de DTS pour $dtb ($(basename "$dir"))"
		n_miss=$((n_miss + 1))
	fi
done
echo "OK  $DEST ($n_ok DTB, $n_miss manquants)"
