"""Organize Cotrainr branding assets per final spec. Does not redraw logos."""
from __future__ import annotations

import os
import shutil

from PIL import Image

SRC = r"C:\Users\HP\.cursor\projects\c-Users-HP-Documents-projects-cotrainr-flutter\assets"
OUT = r"c:\Users\HP\Documents\projects\cotrainr_flutter\assets\branding"
ICONS = os.path.join(OUT, "icons")
REFS = os.path.join(OUT, "references")
ORANGE = (255, 138, 0)  # DesignTokens.accentOrange

BLACK_FULL = os.path.join(
    SRC,
    "c__Users_HP_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_"
    "file_0000000019ec8246a0f575e7b7b27b35-1098a169-0fbb-4db6-b55e-6d36f5e57a19.png",
)
RUNNER = os.path.join(
    SRC,
    "c__Users_HP_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_"
    "file_00000000e9bc81f4948b03442c206e08-b5cbce63-97c9-46d7-b39b-0af0c24440c7.png",
)
ORANGE_FULL = os.path.join(
    SRC,
    "c__Users_HP_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_"
    "file_000000008a5081f499ec298030f5ee8f-b3f3c3ec-008b-4b5f-a185-65a890fa6595.png",
)


def ensure_dirs() -> None:
    os.makedirs(ICONS, exist_ok=True)
    os.makedirs(REFS, exist_ok=True)


def copy_named(src: str, dest_name: str) -> str:
    dest = os.path.join(OUT, dest_name)
    shutil.copy2(src, dest)
    print("copied", dest_name, Image.open(dest).size)
    return dest


def crop_login_header(black_path: str) -> None:
    """Crop symbol + wordmark from black full lockup (omit tagline)."""
    im = Image.open(black_path).convert("RGBA")
    w, h = im.size
    # Keep upper ~72% (icon + wordmark); drop tagline band.
    header = im.crop((0, 0, w, int(h * 0.72)))
    header.save(os.path.join(OUT, "cotrainr_login_header_logo.png"), "PNG")
    print("login header", header.size)


def crop_native_splash(black_path: str) -> None:
    """Native splash: symbol + wordmark (tagline optional/omitted for legibility)."""
    im = Image.open(black_path).convert("RGBA")
    w, h = im.size
    native = im.crop((0, 0, w, int(h * 0.72)))
    # On black canvas with padding for OS splash.
    size = 1024
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    margin = int(size * 0.12)
    max_w = size - 2 * margin
    max_h = size - 2 * margin
    scale = min(max_w / native.width, max_h / native.height)
    nw, nh = int(native.width * scale), int(native.height * scale)
    resized = native.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas.paste(resized, ((size - nw) // 2, (size - nh) // 2), resized)
    canvas.save(os.path.join(OUT, "cotrainr_native_splash_logo.png"), "PNG")
    print("native splash logo", canvas.size)


def make_app_icons(orange_path: str) -> None:
    """Full orange artwork with COTRAINR wordmark + safe padding."""
    src = Image.open(orange_path).convert("RGBA")

    def padded(size: int, pad_ratio: float = 0.14) -> Image.Image:
        canvas = Image.new("RGBA", (size, size), (*ORANGE, 255))
        margin = int(size * pad_ratio)
        max_dim = size - 2 * margin
        scale = min(max_dim / src.width, max_dim / src.height)
        nw, nh = max(1, int(src.width * scale)), max(1, int(src.height * scale))
        r = src.resize((nw, nh), Image.Resampling.LANCZOS)
        canvas.paste(r, ((size - nw) // 2, (size - nh) // 2), r)
        return canvas

    icon_1024 = padded(1024, 0.12)
    icon_1024.save(os.path.join(ICONS, "cotrainr_app_icon_1024.png"), "PNG")
    icon_1024.save(os.path.join(OUT, "cotrainr_app_icon.png"), "PNG")

    # Adaptive foreground: full lockup on transparent (orange bg separate).
    fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    margin = int(1024 * 0.18)  # extra inset for adaptive masks
    max_dim = 1024 - 2 * margin
    scale = min(max_dim / src.width, max_dim / src.height)
    nw, nh = int(src.width * scale), int(src.height * scale)
    r = src.resize((nw, nh), Image.Resampling.LANCZOS)
    # Keep near-white logo pixels; drop orange fill to transparency.
    px = r.load()
    assert px is not None
    for y in range(r.height):
        for x in range(r.width):
            rr, gg, bb, aa = px[x, y]
            # Orange-ish background → transparent
            if rr > 180 and gg < 140 and bb < 80:
                px[x, y] = (0, 0, 0, 0)
            elif rr > 200 and gg > 90 and bb < 60 and gg < 160:
                px[x, y] = (0, 0, 0, 0)
    fg.paste(r, ((1024 - nw) // 2, (1024 - nh) // 2), r)
    fg.save(os.path.join(ICONS, "cotrainr_app_icon_foreground.png"), "PNG")

    # Monochrome (white silhouette) for Android themed icons.
    mono = fg.copy()
    mpx = mono.load()
    assert mpx is not None
    for y in range(mono.height):
        for x in range(mono.width):
            rr, gg, bb, aa = mpx[x, y]
            if aa > 20:
                mpx[x, y] = (255, 255, 255, aa)
    mono.save(os.path.join(ICONS, "cotrainr_app_icon_monochrome.png"), "PNG")

    for size, name in [
        (512, "cotrainr_favicon_512.png"),
        (192, "cotrainr_favicon_192.png"),
        (32, "cotrainr_favicon_32.png"),
        (16, "cotrainr_favicon_16.png"),
    ]:
        padded(size, 0.10 if size >= 192 else 0.08).save(
            os.path.join(ICONS, name), "PNG"
        )

    print("icons generated")


def main() -> None:
    ensure_dirs()
    copy_named(BLACK_FULL, "cotrainr_logo_black_full.png")
    copy_named(RUNNER, "cotrainr_runner_splash.png")
    copy_named(ORANGE_FULL, "cotrainr_orange_full_logo.png")
    crop_login_header(BLACK_FULL)
    crop_native_splash(BLACK_FULL)
    make_app_icons(ORANGE_FULL)

    # Optional references (error screenshot only if present).
    err = os.path.join(
        SRC,
        "c__Users_HP_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_"
        "Screenshot_20260721_204749-e8d74665-b7be-4ac5-b4ae-2dda3ad4db8b.png",
    )
    # Placeholders: store orange/black as visual refs until dedicated screenshots exist.
    Image.open(ORANGE_FULL).convert("RGB").save(
        os.path.join(REFS, "welcome_page_reference.jpg"), "JPEG", quality=85
    )
    Image.open(BLACK_FULL).convert("RGB").save(
        os.path.join(REFS, "login_page_reference.jpg"), "JPEG", quality=85
    )
    if os.path.exists(err):
        print("note: runtime error screenshot present but not used as UI reference")

    print("DONE")


if __name__ == "__main__":
    main()
