#!/usr/bin/env python3
"""Génère l'icône batterie faible 640x480 (BMP U-Boot + PNG userspace)."""
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    import subprocess

    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow", "-q"])
    from PIL import Image, ImageDraw

W, H = 640, 480
BG = (0, 0, 0)
FG = (255, 255, 255)
RED = (220, 48, 48)


def draw_icon(im: Image.Image) -> None:
    d = ImageDraw.Draw(im)
    # Corps de batterie centré, style firmware d'origine.
    bx, by, bw, bh = 230, 155, 160, 100
    nub_w, nub_h = 22, 40
    thick = 10

    d.rectangle([bx, by, bx + bw, by + bh], outline=FG, width=thick)
    d.rectangle(
        [bx + bw, by + (bh - nub_h) // 2, bx + bw + nub_w, by + (bh + nub_h) // 2],
        fill=FG,
    )
    # Croix rouge = trop faible
    inset = 28
    d.line(
        [(bx + inset, by + inset), (bx + bw - inset, by + bh - inset)],
        fill=RED,
        width=14,
    )
    d.line(
        [(bx + bw - inset, by + inset), (bx + inset, by + bh - inset)],
        fill=RED,
        width=14,
    )
    # Trait sous l'icône (lisibilité, pas de police requise)
    d.rectangle([W // 2 - 70, by + bh + 36, W // 2 + 70, by + bh + 44], fill=RED)


def main() -> int:
    if len(sys.argv) < 2:
        print(
            "Usage: make-low-battery-bmp.py <low_battery.bmp> [batteryLow.png]",
            file=sys.stderr,
        )
        return 1

    bmp = Path(sys.argv[1])
    png = Path(sys.argv[2]) if len(sys.argv) > 2 else None
    bmp.parent.mkdir(parents=True, exist_ok=True)

    im = Image.new("RGB", (W, H), BG)
    draw_icon(im)
    im.save(bmp, "BMP")
    print(f"OK  {bmp} ({bmp.stat().st_size} bytes)")
    if png:
        png.parent.mkdir(parents=True, exist_ok=True)
        im.save(png, "PNG")
        print(f"OK  {png} ({png.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
