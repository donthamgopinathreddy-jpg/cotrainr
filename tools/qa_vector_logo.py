"""Rasterize cotrainr_logo.svg paths for visual QA."""
from __future__ import annotations

import re

from PIL import Image, ImageDraw

SVG = r"assets/branding/vector/cotrainr_logo.svg"
OUT = r"assets/branding/_diag_svg_raster.png"


def parse_polys(d: str) -> list[list[tuple[int, int]]]:
    tokens = re.findall(r"[MLZ]|-?\d+", d)
    i = 0
    mode = None
    cur: list[tuple[int, int]] = []
    polys: list[list[tuple[int, int]]] = []
    while i < len(tokens):
        t = tokens[i]
        if t in ("M", "L", "Z"):
            if t == "Z":
                if cur:
                    polys.append(cur)
                    cur = []
            else:
                mode = t
            i += 1
            continue
        x = int(t)
        y = int(tokens[i + 1])
        i += 2
        if mode == "M":
            if cur:
                polys.append(cur)
            cur = [(x, y)]
        else:
            cur.append((x, y))
    if cur:
        polys.append(cur)
    return polys


def main() -> None:
    svg = open(SVG, encoding="utf-8").read()
    print("bytes", len(svg))
    im = Image.new("RGBA", (1024, 1024), (0, 0, 0, 255))
    draw = ImageDraw.Draw(im)
    for m in re.finditer(r'fill="(#[A-Fa-f0-9]+)"[^>]*d="([^"]+)"', svg):
        color = m.group(1)
        polys = parse_polys(m.group(2))
        print(color, "polys", [len(p) for p in polys])
        for poly in polys:
            if len(poly) >= 3:
                draw.polygon(poly, fill=color)
    im.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    import subprocess
    import sys

    subprocess.check_call([sys.executable, "tools/build_vector_branding.py"])
    main()
