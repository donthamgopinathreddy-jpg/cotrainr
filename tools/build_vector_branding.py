"""Build Cotrainr vector master SVG + PNG ladder from the official logo.

Does NOT redesign the logo. Contours are extracted from official raster masters
via OpenCV (vtracer crashes on this Windows host).
"""
from __future__ import annotations

import os
import shutil

import cv2
import numpy as np
from PIL import Image

ROOT = r"c:\Users\HP\Documents\projects\cotrainr_flutter"
OUT = os.path.join(ROOT, "assets", "branding")
VECTOR = os.path.join(OUT, "vector")
ICONS = os.path.join(OUT, "icons")
PNG_LADDER = os.path.join(OUT, "png")
ORANGE = (255, 138, 0)
LOG = os.path.join(ROOT, "tools", "_vector_build_log.txt")


def log(msg: str) -> None:
    print(msg, flush=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(msg + "\n")


def ensure_dirs() -> None:
    for d in (VECTOR, ICONS, PNG_LADDER, os.path.join(PNG_LADDER, "color")):
        os.makedirs(d, exist_ok=True)


def remove_near_black(im: Image.Image, threshold: int = 24) -> Image.Image:
    arr = np.array(im.convert("RGBA"))
    r, g, b, a = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
    kill = (a < 8) | ((r <= threshold) & (g <= threshold) & (b <= threshold))
    arr[kill] = 0
    return Image.fromarray(arr, "RGBA")


def remove_near_orange(im: Image.Image) -> Image.Image:
    arr = np.array(im.convert("RGBA"))
    r, g, b, a = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
    kill = (a < 8) | ((r > 160) & (g < 170) & (b < 120)) | (
        (r > 180) & (g > 70) & (g < 160) & (b < 100)
    )
    arr[kill] = 0
    return Image.fromarray(arr, "RGBA")


def crop_content(im: Image.Image, pad: int = 2) -> Image.Image:
    bbox = im.getbbox()
    if not bbox:
        return im
    l, t, r, b = bbox
    return im.crop(
        (
            max(0, l - pad),
            max(0, t - pad),
            min(im.width, r + pad),
            min(im.height, b + pad),
        )
    )


def to_square(im: Image.Image, size: int = 1024, margin_frac: float = 0.10) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    margin = int(size * margin_frac)
    max_dim = size - 2 * margin
    scale = min(max_dim / im.width, max_dim / im.height)
    nw, nh = max(1, int(im.width * scale)), max(1, int(im.height * scale))
    r = im.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas.paste(r, ((size - nw) // 2, (size - nh) // 2), r)
    return canvas


def extract_official_white_symbol() -> Image.Image:
    """Official mark geometry from supplied orange symbol icon (white only)."""
    src = Image.open(os.path.join(OUT, "cotrainr_orange_symbol_icon.png"))
    white = crop_content(remove_near_orange(src), pad=6)
    log(f"official white symbol: {white.size}")
    return white


def extract_color_symbol_from_lockup() -> Image.Image | None:
    """Prefer brand lockup (white + orange blade) if present and valid."""
    for name in (
        "cotrainr_brand_lockup.png",
        "cotrainr_logo_black_full.png",
        "cotrainr_splash_lockup.png",
    ):
        path = os.path.join(OUT, name)
        if not os.path.exists(path):
            continue
        im = Image.open(path).convert("RGBA")
        arr = np.array(im)
        r, g, b, a = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
        # Non-black rows
        content = (a > 20) & ((r > 40) | (g > 40) | (b > 40))
        rows = np.where(content.any(axis=1))[0]
        if len(rows) == 0:
            continue
        # Find first large empty gap after symbol (before wordmark).
        top = int(rows[0])
        bottom = int(rows[-1])
        empty_run = 0
        stop = bottom
        for y in range(top + 5, min(bottom, int(im.height * 0.7))):
            if not content[y].any() or content[y].sum() < im.width * 0.008:
                empty_run += 1
                if empty_run >= max(3, im.height // 100):
                    stop = y - empty_run + 1
                    break
            else:
                empty_run = 0
        band = im.crop((0, top, im.width, stop))
        symbol = crop_content(remove_near_black(band, 22), pad=4)
        # Must contain both white and orange.
        sarr = np.array(symbol)
        sr, sg, sb, sa = sarr[..., 0], sarr[..., 1], sarr[..., 2], sarr[..., 3]
        white_n = int(((sa > 40) & (sr > 200) & (sg > 200) & (sb > 200)).sum())
        orange_n = int(
            ((sa > 40) & (sr > 170) & (sg < 180) & (sb < 110) & (sr > sg + 40)).sum()
        )
        log(f"lockup {name} crop {symbol.size} W={white_n} O={orange_n}")
        if white_n > 500 and orange_n > 200:
            return symbol
    return None


def _mask_white(arr: np.ndarray) -> np.ndarray:
    r, g, b, a = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
    return ((a > 40) & (r > 195) & (g > 195) & (b > 195)).astype(np.uint8) * 255


def _mask_orange(arr: np.ndarray) -> np.ndarray:
    r, g, b, a = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
    return (
        (a > 40) & (r > 170) & (g < 180) & (b < 110) & (r > (g.astype(np.int16) + 40))
    ).astype(np.uint8) * 255


def _contour_to_path(contour: np.ndarray, epsilon: float = 1.0) -> str:
    # Absolute epsilon keeps sharp brand corners; fractional peri collapses them.
    approx = cv2.approxPolyDP(contour, epsilon, True)
    pts = approx.reshape(-1, 2)
    if len(pts) < 3:
        return ""
    cmds = [f"M{int(pts[0][0])} {int(pts[0][1])}"]
    for x, y in pts[1:]:
        cmds.append(f"L{int(x)} {int(y)}")
    cmds.append("Z")
    return " ".join(cmds)


def _paths_from_mask(mask: np.ndarray, min_area: float = 80.0) -> list[tuple[float, str]]:
    # RETR_CCOMP: outer contours + holes as children
    result = cv2.findContours(mask, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE)
    contours, hierarchy = result if len(result) == 2 else (result[0], result[1])
    if hierarchy is None:
        return []
    hierarchy = hierarchy[0]
    out: list[tuple[float, str]] = []
    for i, cnt in enumerate(contours):
        # Only top-level exteriors; holes appended into same path via evenodd
        if hierarchy[i][3] != -1:
            continue
        area = abs(cv2.contourArea(cnt))
        if area < min_area:
            continue
        d = _contour_to_path(cnt)
        if not d:
            continue
        # Append holes (children)
        child = hierarchy[i][2]
        while child != -1:
            hole = contours[child]
            if abs(cv2.contourArea(hole)) >= min_area * 0.25:
                hd = _contour_to_path(hole)
                if hd:
                    d = f"{d} {hd}"
            child = hierarchy[child][0]
        out.append((area, d))
    out.sort(key=lambda t: t[0], reverse=True)
    return out


def write_logo_svg_from_rgba(
    im: Image.Image,
    svg_path: str,
    *,
    force_blade_orange: bool = False,
) -> None:
    """Write SVG from image silhouettes.

    If force_blade_orange: treat all white components as white except the
    rightmost component (blade), which becomes #FF8A00.
    """
    arr = np.array(im.convert("RGBA"))
    h, w = arr.shape[:2]
    white_mask = _mask_white(arr)
    orange_mask = _mask_orange(arr)

    # Clean speckles
    k = np.ones((3, 3), np.uint8)
    white_mask = cv2.morphologyEx(white_mask, cv2.MORPH_OPEN, k, iterations=1)
    orange_mask = cv2.morphologyEx(orange_mask, cv2.MORPH_OPEN, k, iterations=1)

    layers: list[str] = []

    if force_blade_orange and int(orange_mask.sum()) < 255 * 50:
        # Split white connected components: largest = body, rightmost = blade.
        n, labels, stats, centroids = cv2.connectedComponentsWithStats(
            white_mask, connectivity=8
        )
        comps: list[tuple[int, int, float, np.ndarray]] = []
        for i in range(1, n):
            area = int(stats[i, cv2.CC_STAT_AREA])
            if area < 80:
                continue
            cx = float(centroids[i][0])
            m = ((labels == i).astype(np.uint8) * 255)
            comps.append((area, i, cx, m))
        comps.sort(key=lambda t: t[0], reverse=True)
        if len(comps) >= 2:
            # Blade = rightmost among significant comps
            blade = max(comps[:4], key=lambda t: t[2])
            body_mask = np.zeros_like(white_mask)
            blade_mask = blade[3]
            for area, i, cx, m in comps:
                if i == blade[1]:
                    continue
                body_mask = cv2.bitwise_or(body_mask, m)
            for area, d in _paths_from_mask(body_mask):
                layers.append(
                    f'  <path fill="#FFFFFF" fill-rule="evenodd" d="{d}"/>'
                )
            for area, d in _paths_from_mask(blade_mask):
                layers.append(
                    f'  <path fill="#FF8A00" fill-rule="evenodd" d="{d}"/>'
                )
        else:
            for area, d in _paths_from_mask(white_mask):
                layers.append(
                    f'  <path fill="#FFFFFF" fill-rule="evenodd" d="{d}"/>'
                )
    else:
        for area, d in _paths_from_mask(white_mask):
            layers.append(f'  <path fill="#FFFFFF" fill-rule="evenodd" d="{d}"/>')
        for area, d in _paths_from_mask(orange_mask):
            layers.append(f'  <path fill="#FF8A00" fill-rule="evenodd" d="{d}"/>')

    vb = f"0 0 {w} {h}"
    svg = (
        f'<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" '
        f'width="{w}" height="{h}">\n'
        + "\n".join(layers)
        + "\n</svg>\n"
    )
    with open(svg_path, "w", encoding="utf-8") as f:
        f.write(svg)
    log(f"SVG {svg_path} bytes={os.path.getsize(svg_path)} layers={len(layers)}")


def export_png_ladder(master_png: str, dest_dir: str, prefix: str = "cotrainr_logo") -> None:
    master = Image.open(master_png).convert("RGBA")
    assert master.width >= 1024 and master.height >= 1024
    for size in [1024, 512, 256, 192, 144, 96, 72, 48, 32, 16]:
        out = master.resize((size, size), Image.Resampling.LANCZOS)
        path = os.path.join(dest_dir, f"{prefix}_{size}.png")
        out.save(path, "PNG", optimize=True)
        log(f"png {size} -> {path}")


def build_app_icon(white_master: Image.Image) -> None:
    size = 1024
    pattern_src = os.path.join(OUT, "cotrainr_orange_symbol_icon.png")
    base = Image.new("RGBA", (size, size), (*ORANGE, 255))

    if os.path.exists(pattern_src):
        wash = Image.open(pattern_src).convert("RGBA").resize(
            (size, size), Image.Resampling.LANCZOS
        )
        warr = np.array(wash)
        r, g, b = warr[..., 0], warr[..., 1], warr[..., 2]
        whiteish = (r > 210) & (g > 210) & (b > 210)
        warr[whiteish, 0:3] = ORANGE
        wash = Image.fromarray(warr, "RGBA")
        base = Image.blend(base, wash, 0.38)

    sym = crop_content(remove_near_black(white_master, 30), pad=2)
    sarr = np.array(sym)
    a = sarr[..., 3]
    sarr[a > 20, 0:3] = 255
    sym = Image.fromarray(sarr, "RGBA")

    margin = int(size * 0.18)
    max_dim = size - 2 * margin
    scale = min(max_dim / sym.width, max_dim / sym.height)
    nw, nh = int(sym.width * scale), int(sym.height * scale)
    r = sym.resize((nw, nh), Image.Resampling.LANCZOS)
    base.paste(r, ((size - nw) // 2, (size - nh) // 2), r)
    base.save(os.path.join(ICONS, "cotrainr_app_icon_1024.png"), "PNG")
    base.save(os.path.join(OUT, "cotrainr_app_icon.png"), "PNG")

    fg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fg.paste(r, ((size - nw) // 2, (size - nh) // 2), r)
    fg.save(os.path.join(ICONS, "cotrainr_app_icon_foreground.png"), "PNG")
    fg.save(os.path.join(ICONS, "cotrainr_app_icon_monochrome.png"), "PNG")

    for s, name in [
        (512, "cotrainr_favicon_512.png"),
        (192, "cotrainr_favicon_192.png"),
        (32, "cotrainr_favicon_32.png"),
        (16, "cotrainr_favicon_16.png"),
    ]:
        base.resize((s, s), Image.Resampling.LANCZOS).save(
            os.path.join(ICONS, name), "PNG"
        )
    log(f"icons done symbol={nw}x{nh}")


def write_decorative_svgs() -> None:
    orange = "#FF8A00"
    files = {
        "orange_gradient.svg": f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 800" fill="none">
  <defs>
    <linearGradient id="g" x1="200" y1="0" x2="200" y2="800" gradientUnits="userSpaceOnUse">
      <stop stop-color="{orange}" stop-opacity="0.35"/>
      <stop offset="0.55" stop-color="{orange}" stop-opacity="0.08"/>
      <stop offset="1" stop-color="{orange}" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <rect width="400" height="800" fill="url(#g)"/>
</svg>
''',
        "light_glow.svg": f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" fill="none">
  <defs>
    <radialGradient id="r" cx="0.5" cy="0.5" r="0.5">
      <stop stop-color="{orange}" stop-opacity="0.45"/>
      <stop offset="1" stop-color="{orange}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <circle cx="200" cy="200" r="200" fill="url(#r)"/>
</svg>
''',
        "orange_particles.svg": f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 800" fill="{orange}">
  <g opacity="0.35">
    <circle cx="40" cy="120" r="2"/><circle cx="90" cy="80" r="1.5"/><circle cx="140" cy="160" r="2"/>
    <circle cx="220" cy="60" r="1.5"/><circle cx="300" cy="140" r="2"/><circle cx="360" cy="100" r="1.5"/>
    <circle cx="60" cy="300" r="1.5"/><circle cx="180" cy="280" r="2"/><circle cx="320" cy="320" r="1.5"/>
    <circle cx="100" cy="480" r="2"/><circle cx="250" cy="520" r="1.5"/><circle cx="340" cy="460" r="2"/>
    <circle cx="70" cy="660" r="1.5"/><circle cx="200" cy="700" r="2"/><circle cx="310" cy="640" r="1.5"/>
  </g>
</svg>
''',
        "abstract_lines.svg": f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 800" fill="none" stroke="{orange}" stroke-width="1.5" stroke-linecap="round">
  <g opacity="0.28">
    <path d="M20 40 L80 100"/><path d="M40 30 L110 100"/><path d="M320 60 L380 120"/>
    <path d="M300 40 L370 110"/><path d="M30 700 L90 760"/><path d="M310 680 L380 750"/>
  </g>
</svg>
''',
        "corner_overlay.svg": f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 800" fill="none">
  <g fill="{orange}" opacity="0.18">
    <path d="M0 0 L120 0 L0 160 Z"/>
    <path d="M400 800 L280 800 L400 640 Z"/>
  </g>
  <g fill="{orange}" opacity="0.22">
    <circle cx="340" cy="70" r="2"/><circle cx="350" cy="82" r="2"/><circle cx="360" cy="94" r="2"/>
    <circle cx="340" cy="94" r="2"/><circle cx="350" cy="106" r="2"/><circle cx="360" cy="118" r="2"/>
    <circle cx="50" cy="700" r="2"/><circle cx="62" cy="712" r="2"/><circle cx="74" cy="724" r="2"/>
  </g>
</svg>
''',
        "orange_smoke.svg": f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 800" fill="none">
  <defs>
    <radialGradient id="s1" cx="0.3" cy="0.4" r="0.55">
      <stop stop-color="{orange}" stop-opacity="0.22"/>
      <stop offset="1" stop-color="{orange}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="s2" cx="0.7" cy="0.55" r="0.5">
      <stop stop-color="{orange}" stop-opacity="0.16"/>
      <stop offset="1" stop-color="{orange}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <ellipse cx="140" cy="320" rx="160" ry="220" fill="url(#s1)"/>
  <ellipse cx="280" cy="420" rx="150" ry="200" fill="url(#s2)"/>
</svg>
''',
        "orange_overlays.svg": f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 800" fill="none">
  <rect width="400" height="800" fill="{orange}" opacity="0.06"/>
</svg>
''',
    }
    for name, content in files.items():
        path = os.path.join(VECTOR, name)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content.strip() + "\n")
        log(f"decor {name}")


def main() -> None:
    if os.path.exists(LOG):
        os.remove(LOG)
    ensure_dirs()
    log("=== Cotrainr vector branding build (OpenCV) ===")

    white_sym = extract_official_white_symbol()
    color_sym = extract_color_symbol_from_lockup()

    white_master = to_square(white_sym, 1024, margin_frac=0.10)
    if color_sym is not None:
        color_master = to_square(color_sym, 1024, margin_frac=0.10)
    else:
        # Build color master from white geometry (blade -> orange).
        color_master = white_master.copy()

    color_png = os.path.join(OUT, "cotrainr_logo_master_1024.png")
    white_png = os.path.join(OUT, "cotrainr_logo_white_master_1024.png")
    color_master.save(color_png, "PNG")
    white_master.save(white_png, "PNG")

    diag = Image.new("RGBA", (1024, 1024), (0, 0, 0, 255))
    diag.paste(color_master if color_sym is not None else white_master, (0, 0),
               color_master if color_sym is not None else white_master)
    diag.save(os.path.join(OUT, "cotrainr_logo_master_1024_on_black.png"), "PNG")

    master_svg = os.path.join(VECTOR, "cotrainr_logo.svg")
    white_svg = os.path.join(VECTOR, "cotrainr_logo_white.svg")

    # Master SVG: prefer true white+orange lockup symbol; else white+blade orange.
    if color_sym is not None:
        write_logo_svg_from_rgba(color_master, master_svg, force_blade_orange=False)
    else:
        write_logo_svg_from_rgba(white_master, master_svg, force_blade_orange=True)
    write_logo_svg_from_rgba(white_master, white_svg, force_blade_orange=False)

    # If lockup color SVG diverges from official icon silhouette, also write
    # cotrainr_logo.svg from official icon with orange blade (canonical mark).
    # User rule: official supplied logo = orange symbol icon geometry.
    write_logo_svg_from_rgba(white_master, master_svg, force_blade_orange=True)

    export_png_ladder(white_png, PNG_LADDER)
    export_png_ladder(
        color_png if color_sym is not None else white_png,
        os.path.join(PNG_LADDER, "color"),
    )
    # Also export color ladder from SVG-intent master (white + orange blade raster)
    # Rebuild a color raster from white master for ladder consistency with SVG.
    color_from_white = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    # Paint via masks
    warr = np.array(white_master)
    white_mask = _mask_white(warr)
    n, labels, stats, centroids = cv2.connectedComponentsWithStats(white_mask, 8)
    comps = []
    for i in range(1, n):
        area = int(stats[i, cv2.CC_STAT_AREA])
        if area < 80:
            continue
        comps.append((area, i, float(centroids[i][0])))
    comps.sort(key=lambda t: t[0], reverse=True)
    out_arr = np.zeros_like(warr)
    if comps:
        blade_i = max(comps[:4], key=lambda t: t[2])[1]
        for area, i, cx in comps:
            sel = labels == i
            if i == blade_i:
                out_arr[sel] = (255, 138, 0, 255)
            else:
                out_arr[sel] = (255, 255, 255, 255)
    Image.fromarray(out_arr, "RGBA").save(color_png, "PNG")
    export_png_ladder(color_png, os.path.join(PNG_LADDER, "color"))

    diag = Image.new("RGBA", (1024, 1024), (0, 0, 0, 255))
    cm = Image.open(color_png)
    diag.paste(cm, (0, 0), cm)
    diag.save(os.path.join(OUT, "cotrainr_logo_master_1024_on_black.png"), "PNG")

    build_app_icon(white_master)
    write_decorative_svgs()

    web = os.path.join(ROOT, "web")
    os.makedirs(os.path.join(web, "icons"), exist_ok=True)
    shutil.copy2(os.path.join(ICONS, "cotrainr_favicon_32.png"), os.path.join(web, "favicon.png"))
    shutil.copy2(os.path.join(ICONS, "cotrainr_favicon_192.png"), os.path.join(web, "icons", "Icon-192.png"))
    shutil.copy2(os.path.join(ICONS, "cotrainr_favicon_512.png"), os.path.join(web, "icons", "Icon-512.png"))
    log("DONE")


if __name__ == "__main__":
    main()
