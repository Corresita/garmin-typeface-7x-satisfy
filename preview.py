#!/usr/bin/env python3
"""v2 preview: Environment face, per reference photo."""
from PIL import Image, ImageDraw
import math, os

FD = "resources/fonts"
DD = "resources/drawables"
os.makedirs(DD, exist_ok=True)

# dotted band: 2x2 dots on a 4 px grid (1 px dots on a 2 px grid read as flat grey on the MIP screen)
band = Image.new("RGBA", (280, 72), (0, 0, 0, 0))
px = band.load()
for yy in range(72):
    for xx in range(280):
        if xx % 4 < 2 and yy % 4 < 2:
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
flabel = load_fnt("label")
fbold = load_fnt("bold")
ftext = load_fnt("text")
fdate = load_fnt("date")

W = H = 280
CX, CY = 140, 140
img = Image.new("RGBA", (W, H), (255, 255, 255, 255))
d = ImageDraw.Draw(img)

# ---- v2 layout constants ----
BATT_Y  = 22
BATT_X  = 133
DATE_X  = 48
DATE_Y  = 56
TIME_Y  = 67
TIME_X  = 22
COL2_X  = 176
SAT_X   = 178
SAT_Y   = 106
ROW_Y   = [125, 146, 167, 188]
LABEL_X = 34
BAND_Y  = 214

# band + hill line with sun marker
img.paste(band, (0, BAND_Y), band)
HILL_DX, MARK_X0, MARK_X1, FRAC = 19, 60, 200, 0.75
def hill(x):
    x -= HILL_DX
    return 273 - 24 * math.exp(-((x - 112) / 58.0) ** 2) - 12 * math.exp(-((x - 268) / 46.0) ** 2)
d.line([(x, hill(x)) for x in range(0, 281, 2)], fill=(0, 0, 0, 255), width=2)
mx = MARK_X0 + FRAC * (MARK_X1 - MARK_X0); my = hill(mx)
d.ellipse([mx - 3, my - 3, mx + 3, my + 3], fill=(255, 255, 255, 255), outline=(0, 0, 0, 255), width=2)

# sun time box + icon + text
bx, by, bw, bh = 91, 219, 83, 22
d.rectangle([bx, by, bx + bw - 1, by + bh - 1], fill=(255, 255, 255, 255))
ix, iy = bx + 10, by + 15
d.arc([ix - 8, iy - 8, ix + 8, iy + 8], 180, 360, fill=(0, 0, 0, 255), width=2)
d.line([ix - 10, iy + 1, ix + 10, iy + 1], fill=(0, 0, 0, 255), width=2)
for (x0, y0, x1, y1) in ((ix - 10, iy - 12, ix - 7, iy - 9), (ix - 9, iy - 12, ix - 6, iy - 9), (ix, iy - 14, ix, iy - 10),
                         (ix + 10, iy - 12, ix + 7, iy - 9), (ix + 9, iy - 12, ix + 6, iy - 9)):
    d.line([x0, y0, x1, y1], fill=(0, 0, 0, 255), width=2)
draw_text(img, fbold, bx + 24, by + 1, "18:13")

# top scale: hollow segments filled from the left by battery (mirrors drawScale in TypeFaceView.mc)
SEG_COUNT, SEG_LEN, SEG_END, SEG_GAP, SEG_R_OUT, SEG_R_IN = 5, 12.0, 14.0, 3.5, 131, 126
BATT = 33
def bbox(r):
    return [CX - r, CY - r, CX + r, CY + r]
def radial(a, r0, r1, fill, w):
    c, sn = math.cos(math.radians(a)), math.sin(math.radians(a))
    d.line([(CX + r0 * c, CY - r0 * sn), (CX + r1 * c, CY - r1 * sn)], fill=fill, width=w)
filled = min(SEG_COUNT, BATT // 20)
total = (SEG_COUNT - 2) * SEG_LEN + 2 * SEG_END + (SEG_COUNT - 1) * SEG_GAP
a1 = 90.0 + total / 2
BLACK = (0, 0, 0, 255)
for i in range(SEG_COUNT):
    ln = SEG_END if i in (0, SEG_COUNT - 1) else SEG_LEN
    if i > 0:
        a1 -= SEG_GAP
    a0 = a1 - ln
    if i < filled:   # PIL arc draws inward from bbox, Garmin centers the pen on r
        d.arc(bbox(SEG_R_OUT + 1), 360 - a1, 360 - a0, fill=BLACK, width=SEG_R_OUT - SEG_R_IN + 1)
    else:
        d.arc(bbox(SEG_R_OUT + 1), 360 - a1, 360 - a0, fill=BLACK, width=1)
        d.arc(bbox(SEG_R_IN + 1), 360 - a1, 360 - a0, fill=BLACK, width=1)
        radial(a0, SEG_R_IN, SEG_R_OUT, BLACK, 1)
        radial(a1, SEG_R_IN, SEG_R_OUT, BLACK, 1)
    a1 = a0

# battery: digits + outlined bolt
draw_text(img, fbold, BATT_X, BATT_Y, "33")
BOLT = [(128, 26), (124, 26), (122, 35), (126, 35), (124, 41), (130, 32), (126, 32)]
d.line(BOLT + [BOLT[0]], fill=(0, 0, 0, 255), width=1)

# date, time, label
draw_text(img, fdate, DATE_X, DATE_Y, "MON.09.10")
draw_text(img, ftime, TIME_X, TIME_Y, "18:13")
draw_text(img, flabel, SAT_X, SAT_Y, "SATISFY")

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
