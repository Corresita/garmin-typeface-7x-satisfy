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
draw_text(img, ftext, scx - 24, scy - 15, "18:13")

# top scale (mirrors DASHES in TypeFaceView.mc; Garmin deg -> PIL deg is 360-a)
DASH_R = 128
dashes = [
    (136.0, 5.0, 4),
    (120.5, 3.0, 2), (116.0, 3.0, 2), (111.5, 3.0, 2),
    (93.0, 15.0, 4),
    (86.0, 4.0, 3), (81.0, 3.5, 3),
    (62.0, 16.0, 4),
    (53.0, 4.0, 3), (48.0, 3.0, 3),
]
for a0, ln, pw in dashes:
    d.arc([CX - DASH_R, CY - DASH_R, CX + DASH_R, CY + DASH_R],
          360 - (a0 + ln), 360 - a0, fill=(0, 0, 0, 255), width=pw)
for a in (39.0, 41.5, 44.0):  # red ticks, right end
    c, sn = math.cos(math.radians(a)), math.sin(math.radians(a))
    d.line([(CX + (DASH_R - 4) * c, CY - (DASH_R - 4) * sn),
            (CX + (DASH_R + 4) * c, CY - (DASH_R + 4) * sn)], fill=(200, 0, 0, 255), width=2)

# battery
draw_text(img, ftext, CX + 8, BATT_Y, "33")
bx, by = CX - 4, BATT_Y + 15
d.polygon([(bx, by - 12), (bx - 7, by + 2), (bx - 2, by + 2), (bx - 4, by + 12),
           (bx + 4, by - 2), (bx - 1, by - 2)], fill=(0, 0, 0, 255))

# date, time, label
draw_text(img, ftext, LABEL_X, DATE_Y, "周一.07.09")
draw_text(img, ftime, LABEL_X - 4, TIME_Y, "10:19")
draw_text(img, ftext, COL2_X, SAT_Y, "SATISFY")

# rows
for i, (s, v) in enumerate([("RUN", "0.2KM"), ("HEART RATE", "69BPM"),
                            ("RECOVERY", "79%"), ("KCAL", "863")]):
    draw_text(img, ftext, LABEL_X, ROW_Y[i], s)
    draw_text(img, ftext, COL2_X, ROW_Y[i], v)

mask = Image.new("L", (W, H), 0)
ImageDraw.Draw(mask).ellipse([0, 0, W - 1, H - 1], fill=255)
out = Image.new("RGBA", (W, H), (20, 20, 20, 255))
out.paste(img, (0, 0), mask)
out.resize((560, 560), Image.NEAREST).save("preview.png")
print("ok")
