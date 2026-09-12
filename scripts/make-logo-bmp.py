#!/usr/bin/env python3
"""bootScreen.png -> 640x480 24-bit BMP pour U-Boot (logo.bmp)."""
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    import subprocess

    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow", "-q"])
    from PIL import Image

if len(sys.argv) < 3:
    print("Usage: make-logo-bmp.py <bootScreen.png> <logo.bmp>", file=sys.stderr)
    sys.exit(1)

src = Path(sys.argv[1])
out = Path(sys.argv[2])
if not src.is_file():
    print(f"ERREUR : PNG introuvable : {src}", file=sys.stderr)
    sys.exit(1)

out.parent.mkdir(parents=True, exist_ok=True)
im = Image.open(src).convert("RGB")
if im.size != (640, 480):
    im = im.resize((640, 480), Image.Resampling.LANCZOS)
im.save(out, "BMP")
print(f"OK  {out} ({out.stat().st_size} bytes)")
