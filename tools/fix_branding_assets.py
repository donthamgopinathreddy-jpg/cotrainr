"""Fix branding assets: larger icons, clean splash, transparent page logos."""
from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFilter

OUT = r"c:\Users\HP\Documents\projects\cotrainr_flutter\assets\branding"
ICONS = os.path.join(OUT, "icons")
ORANGE = (255, 138, 0)


def remove_near_black(im: Image.Image, threshold: int = 28) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    assert px is not None
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if r <= threshold and g <= threshold and b <= threshold:
                px[x, y] = (0, 0, 0, 0)
    return im


def remove_near_orange(im: Image.Image) -> Image.Image:
    """Keep white/near-white logo pixels; drop orange background."""
    im = im.convert("RGBA")
    px = im.load()
    assert px is not None
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            # Orange / warm fill
            if r > 160 and g < 160 and b < 100:
                px[x, y] = (0, 0, 0, 0)
            elif r > 200 and 60 < g < 170 and b < 90:
                px[x, y] = (0, 0, 0, 0)
            elif r > 180 and g > 80 and g < 150 and b < 70:
                px[x, y] = (0, 0, 0, 0)
    return im


def crop_content(im: Image.Image, pad: int = 4) -> Image.Image:
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


def clean_runner_splash() -> None:
    src = os.path.join(OUT, "cotrainr_runner_splash.png")
    im = Image.open(src).convert("RGB")
    w, h = im.size
    # Cover baked progress bar + glow near the bottom with pure black.
    # Bar sits roughly in the bottom 6–10% of the artwork.
    top = int(h * 0.88)
    draw = ImageDraw.Draw(im)
    draw.rectangle([0, top, w, h], fill=(0, 0, 0))
    # Soft blend a few pixels above to avoid a hard seam.
    band = im.crop((0, top - 8, w, top + 2)).filter(ImageFilter.GaussianBlur(3))
    im.paste(band, (0, top - 8))
    draw.rectangle([0, top, w, h], fill=(0, 0, 0))
    dest = os.path.join(OUT, "cotrainr_runner_splash_clean.png")
    im.save(dest, "PNG")
    print("clean runner", im.size, dest)


def transparent_login_register() -> None:
    black = Image.open(os.path.join(OUT, "cotrainr_logo_black_full.png")).convert("RGBA")
    w, h = black.size
    # Icon + wordmark only (no tagline).
    header = black.crop((0, 0, w, int(h * 0.70)))
    transparent = crop_content(remove_near_black(header, 26), pad=6)
    transparent.save(os.path.join(OUT, "cotrainr_login_header_logo.png"), "PNG")
    transparent.save(os.path.join(OUT, "cotrainr_register_header_logo.png"), "PNG")
    print("login/register header", transparent.size, "alpha ok")


def welcome_logo_white() -> None:
    orange = Image.open(os.path.join(OUT, "cotrainr_orange_full_logo.png")).convert("RGBA")
    white = crop_content(remove_near_orange(orange), pad=8)
    white.save(os.path.join(OUT, "cotrainr_welcome_logo_white.png"), "PNG")
    print("welcome white logo", white.size)


def symbol_only_white() -> Image.Image:
    """White symbol only from black lockup (for tiny favicons)."""
    black = Image.open(os.path.join(OUT, "cotrainr_logo_black_full.png")).convert("RGBA")
    w, h = black.size
    icon_band = black.crop((0, 0, w, int(h * 0.42)))
    # Keep white + orange blade; drop black.
    t = remove_near_black(icon_band, 24)
    return crop_content(t, pad=6)


def make_icons() -> None:
    os.makedirs(ICONS, exist_ok=True)
    orange_src = Image.open(os.path.join(OUT, "cotrainr_orange_full_logo.png")).convert("RGBA")
    # Extract white lockup (symbol + COTRAINR) from orange artwork.
    lockup = crop_content(remove_near_orange(orange_src), pad=4)

    def full_icon(size: int, content_width_ratio: float = 0.71) -> Image.Image:
        canvas = Image.new("RGBA", (size, size), (*ORANGE, 255))
        # Soft pattern from original (very faint).
        pattern = orange_src.resize((size, size), Image.Resampling.LANCZOS)
        canvas = Image.blend(canvas.convert("RGBA"), pattern, 0.18)

        target_w = int(size * content_width_ratio)
        scale = target_w / lockup.width
        # Cap height ~58% of icon.
        max_h = int(size * 0.58)
        if lockup.height * scale > max_h:
            scale = max_h / lockup.height
        nw = max(1, int(lockup.width * scale))
        nh = max(1, int(lockup.height * scale))
        r = lockup.resize((nw, nh), Image.Resampling.LANCZOS)
        canvas.paste(r, ((size - nw) // 2, (size - nh) // 2), r)
        return canvas

    icon_1024 = full_icon(1024, 0.72)
    icon_1024.save(os.path.join(ICONS, "cotrainr_app_icon_1024.png"), "PNG")
    icon_1024.save(os.path.join(OUT, "cotrainr_app_icon.png"), "PNG")

    # Adaptive foreground: larger lockup on transparent (~70% width, 16% margin).
    fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    target_w = int(1024 * 0.70)
    scale = target_w / lockup.width
    max_h = int(1024 * 0.56)
    if lockup.height * scale > max_h:
        scale = max_h / lockup.height
    nw, nh = int(lockup.width * scale), int(lockup.height * scale)
    r = lockup.resize((nw, nh), Image.Resampling.LANCZOS)
    fg.paste(r, ((1024 - nw) // 2, (1024 - nh) // 2), r)
    fg.save(os.path.join(ICONS, "cotrainr_app_icon_foreground.png"), "PNG")

    mono = fg.copy()
    mpx = mono.load()
    assert mpx is not None
    for y in range(mono.height):
        for x in range(mono.width):
            rr, gg, bb, aa = mpx[x, y]
            if aa > 16:
                mpx[x, y] = (255, 255, 255, aa)
    mono.save(os.path.join(ICONS, "cotrainr_app_icon_monochrome.png"), "PNG")

    full_icon(512, 0.72).save(os.path.join(ICONS, "cotrainr_favicon_512.png"), "PNG")
    full_icon(192, 0.72).save(os.path.join(ICONS, "cotrainr_favicon_192.png"), "PNG")

    # Tiny favicons: symbol only on orange.
    symbol = symbol_only_white()
    for size in (32, 16):
        canvas = Image.new("RGBA", (size, size), (*ORANGE, 255))
        margin = max(1, int(size * 0.14))
        max_dim = size - 2 * margin
        scale = min(max_dim / symbol.width, max_dim / symbol.height)
        nw, nh = max(1, int(symbol.width * scale)), max(1, int(symbol.height * scale))
        r = symbol.resize((nw, nh), Image.Resampling.LANCZOS)
        canvas.paste(r, ((size - nw) // 2, (size - nh) // 2), r)
        canvas.save(os.path.join(ICONS, f"cotrainr_favicon_{size}.png"), "PNG")

    print("icons regenerated (larger lockup)")


def main() -> None:
    clean_runner_splash()
    transparent_login_register()
    welcome_logo_white()
    make_icons()
    print("DONE")


if __name__ == "__main__":
    main()
