"""Shrink logo within favicon canvas so maskable/circle crops don't clip edges.

Does not redesign artwork — only scales the supplied master down and centers
it on #FF6A00 with extra safe padding for web favicons.
"""
from __future__ import annotations

import os
import shutil

from PIL import Image

ROOT = r"c:\Users\HP\Documents\projects\cotrainr_flutter"
MASTER = os.path.join(ROOT, "assets", "branding", "icons", "cotrainr_app_icon_1024.png")
OUT_ICONS = os.path.join(ROOT, "assets", "branding", "icons")
WEB = os.path.join(ROOT, "web")
ORANGE = (255, 106, 0)  # #FF6A00


def padded_master(scale: float = 0.72, size: int = 1024) -> Image.Image:
    src = Image.open(MASTER).convert("RGBA")
    # Fill with brand orange, then paste scaled master centered.
    canvas = Image.new("RGBA", (size, size), (*ORANGE, 255))
    dim = max(1, int(size * scale))
    scaled = src.resize((dim, dim), Image.Resampling.LANCZOS)
    ox = (size - dim) // 2
    oy = (size - dim) // 2
    canvas.paste(scaled, (ox, oy), scaled)
    return canvas


def main() -> None:
    # Favicon-safe 1024 (extra padding so circular/squircle masks don't clip).
    safe = padded_master(scale=0.58)
    safe_path = os.path.join(OUT_ICONS, "cotrainr_favicon_master_1024.png")
    safe.save(safe_path, "PNG")

    # Tiny favicons need even more safe zone.
    tiny = padded_master(scale=0.50)
    for size, name in [
        (512, "cotrainr_favicon_512.png"),
        (192, "cotrainr_favicon_192.png"),
        (32, "cotrainr_favicon_32.png"),
        (16, "cotrainr_favicon_16.png"),
    ]:
        src = safe if size >= 192 else tiny
        out = src.resize((size, size), Image.Resampling.LANCZOS)
        path = os.path.join(OUT_ICONS, name)
        out.save(path, "PNG")
        print("wrote", path, out.size)

    # Web exports
    os.makedirs(os.path.join(WEB, "icons"), exist_ok=True)
    shutil.copy2(
        os.path.join(OUT_ICONS, "cotrainr_favicon_32.png"),
        os.path.join(WEB, "favicon.png"),
    )
    safe.resize((192, 192), Image.Resampling.LANCZOS).save(
        os.path.join(WEB, "icons", "Icon-192.png"), "PNG"
    )
    safe.resize((512, 512), Image.Resampling.LANCZOS).save(
        os.path.join(WEB, "icons", "Icon-512.png"), "PNG"
    )
    # Maskable needs ~20%+ safe zone per Android/PWA guidance.
    maskable = padded_master(scale=0.50)
    maskable.resize((192, 192), Image.Resampling.LANCZOS).save(
        os.path.join(WEB, "icons", "Icon-maskable-192.png"), "PNG"
    )
    maskable.resize((512, 512), Image.Resampling.LANCZOS).save(
        os.path.join(WEB, "icons", "Icon-maskable-512.png"), "PNG"
    )
    print("web favicons updated")


if __name__ == "__main__":
    main()
