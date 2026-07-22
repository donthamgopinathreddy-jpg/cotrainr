"""Install exact master app icon and export sizes by downscale only.

Does NOT redesign, re-pad, crop, or reposition the logo.
"""
from __future__ import annotations

import os
import shutil

from PIL import Image
import numpy as np

ROOT = r"c:\Users\HP\Documents\projects\cotrainr_flutter"
ICONS = os.path.join(ROOT, "assets", "branding", "icons")
WEB = os.path.join(ROOT, "web")
ANDROID_RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

# Newest supplied master from Cursor assets
SOURCES = [
    r"C:\Users\HP\.cursor\projects\c-Users-HP-Documents-projects-cotrainr-flutter\assets\c__Users_HP_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_file_00000000a03c81f4af375d7c82ffbe68-3a31965f-59f6-4526-8ead-97cd4ad045a8.png",
]

ORANGE = (255, 106, 0)  # #FF6A00 adaptive background


def find_source() -> str:
    for p in SOURCES:
        if os.path.isfile(p):
            return p
    raise FileNotFoundError("supplied master PNG not found")


def copy_master(src: str) -> str:
    os.makedirs(ICONS, exist_ok=True)
    dest = os.path.join(ICONS, "cotrainr_app_icon_1024.png")
    shutil.copy2(src, dest)
    shutil.copy2(src, os.path.join(ROOT, "assets", "branding", "cotrainr_app_icon.png"))
    im = Image.open(dest)
    assert im.size == (1024, 1024), im.size
    print("master", dest, os.path.getsize(dest), im.size, im.mode)
    return dest


def extract_white_symbol_foreground(master_path: str) -> str:
    """Export white symbol (+ soft shadow alpha) from master onto transparent canvas.

    Same position/size as in the master — no re-centering or rescale of the mark.
    """
    im = Image.open(master_path).convert("RGBA")
    arr = np.array(im)
    r, g, b, a = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
    # Keep near-white logo pixels; also keep darker soft-shadow under the mark.
    white = (r > 200) & (g > 200) & (b > 200) & (a > 20)
    # Soft shadow: darker than orange bg, near logo (not bright orange)
    # Orange bg is high R, mid G, low B — shadow is darker/low saturation near white.
    luminance = (r.astype(np.int16) + g.astype(np.int16) + b.astype(np.int16)) / 3
    # Pixels that are not orange-ish and not pure white — candidate shadow
    orangeish = (r > 180) & (g > 40) & (g < 200) & (b < 120) & (r > g)
    shadow = (~orangeish) & (~white) & (a > 20) & (luminance < 160) & (luminance > 20)

    out = np.zeros_like(arr)
    out[white] = (255, 255, 255, 255)
    # Preserve shadow with original RGB/alpha but ensure visible
    out[shadow, 0:3] = arr[shadow, 0:3]
    out[shadow, 3] = np.clip(arr[shadow, 3], 40, 180)

    fg = Image.fromarray(out, "RGBA")
    path = os.path.join(ICONS, "cotrainr_symbol_foreground.png")
    fg.save(path, "PNG")
    print("foreground", path, os.path.getsize(path))
    return path


def downscale(master: Image.Image, size: int) -> Image.Image:
    return master.resize((size, size), Image.Resampling.LANCZOS)


def export_android_mipmaps(master: Image.Image) -> None:
    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in sizes.items():
        d = os.path.join(ANDROID_RES, folder)
        os.makedirs(d, exist_ok=True)
        img = downscale(master, size)
        for name in ("ic_launcher.png", "ic_launcher_round.png"):
            img.save(os.path.join(d, name), "PNG")
        print("android", folder, size)


def export_play_store(master: Image.Image) -> None:
    path = os.path.join(ICONS, "cotrainr_play_store_512.png")
    downscale(master, 512).save(path, "PNG")
    print("play", path)


def export_web_favicons(master: Image.Image) -> None:
    sizes = [16, 32, 48, 64, 96, 180, 192, 512]
    fav_dir = os.path.join(ICONS, "favicon")
    os.makedirs(fav_dir, exist_ok=True)
    os.makedirs(os.path.join(WEB, "icons"), exist_ok=True)

    for size in sizes:
        img = downscale(master, size)
        img.save(os.path.join(fav_dir, f"favicon_{size}.png"), "PNG")
        img.save(os.path.join(ICONS, f"cotrainr_favicon_{size}.png"), "PNG")
        print("favicon", size)

    # Standard web entry points (direct downscales of master)
    shutil.copy2(
        os.path.join(fav_dir, "favicon_32.png"),
        os.path.join(WEB, "favicon.png"),
    )
    downscale(master, 192).save(os.path.join(WEB, "icons", "Icon-192.png"), "PNG")
    downscale(master, 512).save(os.path.join(WEB, "icons", "Icon-512.png"), "PNG")
    downscale(master, 192).save(os.path.join(WEB, "icons", "Icon-maskable-192.png"), "PNG")
    downscale(master, 512).save(os.path.join(WEB, "icons", "Icon-maskable-512.png"), "PNG")
    # Apple touch
    downscale(master, 180).save(os.path.join(WEB, "icons", "Icon-180.png"), "PNG")


def main() -> None:
    src = find_source()
    print("source", src)
    master_path = copy_master(src)
    extract_white_symbol_foreground(master_path)
    master = Image.open(master_path).convert("RGBA")
    export_android_mipmaps(master)
    export_play_store(master)
    export_web_favicons(master)
    print("DONE exports")


if __name__ == "__main__":
    main()
