"""Build safe padded icon exports from the supplied master (no redesign).

Scales the master down and centers it on #FF6A00 so circular / adaptive /
favicon masks do not clip the logo tips.
"""
from __future__ import annotations

import os
import shutil

from PIL import Image

ROOT = r"c:\Users\HP\Documents\projects\cotrainr_flutter"
ICONS = os.path.join(ROOT, "assets", "branding", "icons")
MASTER = os.path.join(ICONS, "cotrainr_app_icon_1024.png")
ORANGE = (255, 106, 0)  # #FF6A00


def pad(scale: float, size: int = 1024) -> Image.Image:
    src = Image.open(MASTER).convert("RGBA")
    canvas = Image.new("RGBA", (size, size), (*ORANGE, 255))
    dim = max(1, int(size * scale))
    scaled = src.resize((dim, dim), Image.Resampling.LANCZOS)
    ox = (size - dim) // 2
    oy = (size - dim) // 2
    canvas.paste(scaled, (ox, oy), scaled)
    return canvas


def main() -> None:
    # ~55% of frame → logo tips stay inside maskable / circle / adaptive crops.
    safe = pad(0.55)
    safe_path = os.path.join(ICONS, "cotrainr_app_icon_safe_1024.png")
    safe.save(safe_path, "PNG")

    # Adaptive foreground: same padded art (solid orange underlay matches bg).
    fg_path = os.path.join(ICONS, "cotrainr_symbol_foreground.png")
    safe.save(fg_path, "PNG")

    # Favicon ladder
    for size, name, sc in [
        (512, "cotrainr_favicon_512.png", 0.55),
        (192, "cotrainr_favicon_192.png", 0.55),
        (32, "cotrainr_favicon_32.png", 0.48),
        (16, "cotrainr_favicon_16.png", 0.48),
    ]:
        img = pad(sc).resize((size, size), Image.Resampling.LANCZOS)
        img.save(os.path.join(ICONS, name), "PNG")
        print("favicon", name, size)

    web = os.path.join(ROOT, "web")
    os.makedirs(os.path.join(web, "icons"), exist_ok=True)
    shutil.copy2(os.path.join(ICONS, "cotrainr_favicon_32.png"), os.path.join(web, "favicon.png"))
    pad(0.55).resize((192, 192), Image.Resampling.LANCZOS).save(
        os.path.join(web, "icons", "Icon-192.png"), "PNG"
    )
    pad(0.55).resize((512, 512), Image.Resampling.LANCZOS).save(
        os.path.join(web, "icons", "Icon-512.png"), "PNG"
    )
    pad(0.48).resize((192, 192), Image.Resampling.LANCZOS).save(
        os.path.join(web, "icons", "Icon-maskable-192.png"), "PNG"
    )
    pad(0.48).resize((512, 512), Image.Resampling.LANCZOS).save(
        os.path.join(web, "icons", "Icon-maskable-512.png"), "PNG"
    )

    # Measure white coverage
    for label, im in [("master", Image.open(MASTER)), ("safe", safe)]:
        arr = im.convert("RGBA")
        w, h = arr.size
        px = arr.load()
        xs, ys = [], []
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a > 20 and r > 200 and g > 200 and b > 200:
                    xs.append(x)
                    ys.append(y)
        if xs:
            bw = max(xs) - min(xs) + 1
            print(f"{label} white width cover={bw/w:.1%}")
    print("safe written", safe_path)


if __name__ == "__main__":
    main()
