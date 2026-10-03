#!/usr/bin/env python3
"""Rasterize icon.svg to icon.png for Godot and Linux packaging."""
from pathlib import Path
from PIL import Image

import cairosvg

ROOT = Path(__file__).resolve().parents[1]
SVG = ROOT / "icon.svg"
PNG = ROOT / "icon.png"


def main() -> None:
    cairosvg.svg2png(
        bytestring=SVG.read_bytes(),
        write_to=str(PNG),
        output_width=512,
        output_height=512,
    )
    Image.open(PNG).save(ROOT / "icon.ico", format="ICO", sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
    print(f"wrote {PNG} and icon.ico")


if __name__ == "__main__":
    main()
