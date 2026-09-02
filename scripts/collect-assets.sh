#!/usr/bin/env bash
# Copie PNG/TTF depuis res/ (ce depot) vers staging/opt/telmi/res.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

DEST="$STAGING/opt/telmi/res"
mkdir -p "$DEST"

if [[ -f "$TELMIOS/res/selectStories.png" || -f "$TELMIOS/res/bootScreen.png" ]]; then
	echo "==> assets UI depuis $TELMIOS/res"
	cp -a "$TELMIOS/res/." "$DEST/"
	rm -f "$DEST/selectGameMode.png" "$DEST/README.md" 2>/dev/null || true
	echo "OK  $DEST ($(find "$DEST" -type f | wc -l) fichiers)"
	exit 0
fi

echo "WARN : PNG introuvables dans $TELMIOS/res"
exit 1
