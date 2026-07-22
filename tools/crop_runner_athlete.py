"""Crop athlete-only splash PNG (logo rendered from SVG in Flutter)."""
from PIL import Image
import os

OUT = r"c:\Users\HP\Documents\projects\cotrainr_flutter\assets\branding"
src = os.path.join(OUT, "cotrainr_runner_splash_clean.png")
im = Image.open(src).convert("RGBA")
w, h = im.size
cut = int(h * 0.58)
athlete = im.crop((0, 0, w, cut))
canvas = Image.new("RGBA", (w, h), (0, 0, 0, 255))
canvas.paste(athlete, (0, 0), athlete)
dest = os.path.join(OUT, "cotrainr_runner_athlete.png")
canvas.save(dest, "PNG")
print("saved", dest, canvas.size, "cut", cut)
