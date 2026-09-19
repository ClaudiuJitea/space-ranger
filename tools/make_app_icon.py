#!/usr/bin/env python3
"""Rasterize icon.svg to icon.png for Godot and Linux packaging."""
from pathlib import Path

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
    print(f"wrote {PNG}")


if __name__ == "__main__":
    main()
