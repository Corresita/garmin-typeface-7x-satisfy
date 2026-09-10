#!/usr/bin/env python3
"""v2 preview: Environment face, per reference photo."""
from PIL import Image, ImageDraw
import math, os

FD = "resources/fonts"
DD = "resources/drawables"
os.makedirs(DD, exist_ok=True)

# dotted band: 25% dot grid, 280x82
band = Image.new("RGBA", (280, 72), (0, 0, 0, 0))
px = band.load()
for yy in range(72):
    for xx in range(280):
        if xx % 2 == 0 and yy % 2 == 0:
            px[xx, yy] = (0, 0, 0, 255)
band.save(f"{DD}/halftone.png")

def load_fnt(prefix):
    chars = {}
    atlas = Image.open(f"{FD}/{prefix}.png")
    for line in open(f"{FD}/{prefix}.fnt"):
        if line.startswith("char "):
            kv = dict(p.split("=") for p in line.split()[1:])
            chars[int(kv["id"])] = {k: int(v) for k, v in kv.items() if k not in ("page", "chnl")}
    return atlas, chars

def draw_text(img, font, x, y, s, justify="left"):
    atlas, chars = font
    wsum = sum(chars[ord(c)]["xadvance"] for c in s if ord(c) in chars)
    if justify == "center":
        x -= wsum // 2
    for c in s:
        g = chars.get(ord(c))
        if not g:
            continue
        if g["width"] > 0:
            glyph = atlas.crop((g["x"], g["y"], g["x"] + g["width"], g["y"] + g["height"]))
            img.paste((0, 0, 0, 255), (x + g["xoffset"], y + g["yoffset"]), glyph)
        x += g["xadvance"]

ftime = load_fnt("time")
ftext = load_fnt("text")

W = H = 280
CX, CY = 140, 140
img = Image.new("RGBA", (W, H), (255, 255, 255, 255))
d = ImageDraw.Draw(img)

# ---- v2 layout constants ----
BATT_Y  = 22
DATE_Y  = 42
TIME_Y  = 62
COL2_X  = 176
SAT_Y   = 86
ROW_Y   = [124, 145, 166, 187]
LABEL_X = 40
BAND_Y  = 208

# band + hill silhouette
img.paste(band, (0, BAND_Y), band)
def hill(x):
    return 272 - 24 * math.exp(-((x - 112) / 58.0) ** 2) - 12 * math.exp(-((x - 268) / 46.0) ** 2)
poly = [(0, 281)] + [(x, hill(x)) for x in range(0, 281, 4)] + [(280, 281)]
d.polygon(poly, fill=(255, 255, 255, 255))
d.line([(x, hill(x)) for x in range(0, 281, 2)], fill=(0, 0, 0, 255), width=2)

# sunrise, centered on band with knockout
scx, scy = 140, BAND_Y + 12
d.rectangle([scx - 52, scy - 14, scx + 52, scy + 12], fill=(255, 255, 255, 255))
d.arc([scx - 46, scy - 6, scx - 30, scy + 8], 180, 360, fill=(0, 0, 0, 255), width=2)
d.line([scx - 48, scy + 7, scx - 28, scy + 7], fill=(0, 0, 0, 255), width=2)
draw_text(img, ftext, scx - 24, scy - 15, "05:35")

# top dashes: irregular lengths, two doubled
dashes = [(48, 5), (60, 14), (80, 9), (95, 16), (117, 11), (132, 6)]
for i, (a0, ln) in enumerate(dashes):
    d.arc([CX - 132, CY - 132, CX + 132, CY + 132], 180 + a0, 180 + a0 + ln,
          fill=(0, 0, 0, 255), width=3)
    if i in (1, 3):
        d.arc([CX - 126, CY - 126, CX + 126, CY + 126], 180 + a0 + 2, 180 + a0 + ln - 2,
              fill=(0, 0, 0, 255), width=3)

# battery
draw_text(img, ftext, CX + 8, BATT_Y, "33")
bx, by = CX - 4, BATT_Y + 15
d.polygon([(bx, by - 12), (bx - 7, by + 2), (bx - 2, by + 2), (bx - 4, by + 12),
           (bx + 4, by - 2), (bx - 1, by - 2)], fill=(0, 0, 0, 255))

# date, time, label
draw_text(img, ftext, LABEL_X, DATE_Y, "周一.07.09")
draw_text(img, ftime, LABEL_X - 4, TIME_Y, "21:42")
draw_text(img, ftext, COL2_X, SAT_Y, "TYPEFACE")

# rows
for i, (s, v) in enumerate([("TEMPERATURE", "27°C"), ("RAIN CHANCE", "0%"),
                            ("HUMIDITY", "84%"), ("ACTIVE", "0MIN")]):
    draw_text(img, ftext, LABEL_X, ROW_Y[i], s)
    draw_text(img, ftext, COL2_X, ROW_Y[i], v)

mask = Image.new("L", (W, H), 0)
ImageDraw.Draw(mask).ellipse([0, 0, W - 1, H - 1], fill=255)
out = Image.new("RGBA", (W, H), (20, 20, 20, 255))
out.paste(img, (0, 0), mask)
out.resize((560, 560), Image.NEAREST).save("preview.png")
print("ok")
