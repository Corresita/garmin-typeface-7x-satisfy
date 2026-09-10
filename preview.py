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
BATT_X  = 133
DATE_X  = 48
DATE_Y  = 57
TIME_Y  = 66
COL2_X  = 177
SAT_Y   = 100
ROW_Y   = [122, 143, 164, 185]
LABEL_X = 40
BAND_Y  = 208

# band + sun path arc with marker
img.paste(band, (0, BAND_Y), band)
ARC_CX, ARC_CY, ARC_R, ARC_A0, ARC_A1 = 146, 384, 131, 62.0, 118.0
SUN_BOX = (88, 206, 104, 27)
FRAC = 0.75
d.arc([ARC_CX - ARC_R, ARC_CY - ARC_R, ARC_CX + ARC_R, ARC_CY + ARC_R],
      360 - ARC_A1, 360 - ARC_A0, fill=(0, 0, 0, 255), width=2)
a = math.radians(ARC_A1 - FRAC * (ARC_A1 - ARC_A0))
mx, my = ARC_CX + ARC_R * math.cos(a), ARC_CY - ARC_R * math.sin(a)
d.ellipse([mx - 4, my - 4, mx + 4, my + 4], fill=(255, 255, 255, 255), outline=(0, 0, 0, 255), width=1)

# sun time box + icon + text
bx, by, bw, bh = SUN_BOX
d.rectangle([bx, by, bx + bw - 1, by + bh - 1], fill=(255, 255, 255, 255))
ix, iy = bx + 14, by + 20
d.arc([ix - 8, iy - 8, ix + 8, iy + 8], 180, 360, fill=(0, 0, 0, 255), width=2)
d.line([ix - 10, iy + 1, ix + 10, iy + 1], fill=(0, 0, 0, 255), width=2)
draw_text(img, ftext, bx + 28, by - 1, "18:13")

# top scale: hollow segments filled from the left by battery (mirrors drawScale in TypeFaceView.mc)
SEG_COUNT, SEG_LEN, SEG_GAP, SEG_R_OUT, SEG_R_IN = 5, 12.0, 3.5, 131, 126
BATT = 33
def bbox(r):
    return [CX - r, CY - r, CX + r, CY + r]
def radial(a, r0, r1, fill, w):
    c, sn = math.cos(math.radians(a)), math.sin(math.radians(a))
    d.line([(CX + r0 * c, CY - r0 * sn), (CX + r1 * c, CY - r1 * sn)], fill=fill, width=w)
filled = min(SEG_COUNT, BATT // 20)
total = SEG_COUNT * SEG_LEN + (SEG_COUNT - 1) * SEG_GAP
left = 90.0 + total / 2
BLACK = (0, 0, 0, 255)
for i in range(SEG_COUNT):
    a1 = left - i * (SEG_LEN + SEG_GAP)
    a0 = a1 - SEG_LEN
    if i < filled:   # PIL arc draws inward from bbox, Garmin centers the pen on r
        d.arc(bbox(SEG_R_OUT + 1), 360 - a1, 360 - a0, fill=BLACK, width=SEG_R_OUT - SEG_R_IN + 1)
    else:
        d.arc(bbox(SEG_R_OUT + 1), 360 - a1, 360 - a0, fill=BLACK, width=1)
        d.arc(bbox(SEG_R_IN + 1), 360 - a1, 360 - a0, fill=BLACK, width=1)
        radial(a0, SEG_R_IN, SEG_R_OUT, BLACK, 1)
        radial(a1, SEG_R_IN, SEG_R_OUT, BLACK, 1)

# battery: digits + outlined bolt
draw_text(img, ftext, BATT_X, BATT_Y, "33")
BOLT = [(128, 26), (124, 26), (122, 35), (126, 35), (124, 41), (130, 32), (126, 32)]
d.line(BOLT + [BOLT[0]], fill=(0, 0, 0, 255), width=1)

# date, time, label
draw_text(img, ftext, DATE_X, DATE_Y, "THU.09.10")
draw_text(img, ftime, LABEL_X - 4, TIME_Y, "12:17")
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
