#!/usr/bin/env python3
"""Generate Garmin CIQ bitmap fonts (.fnt + .png) from the bundled TTFs, 1-bit."""
from PIL import Image, ImageDraw, ImageFont
import os

OUT = "resources/fonts"
os.makedirs(OUT, exist_ok=True)

def raster_glyph(font, ch, condense, slash_w=0):
    # render white on black, threshold, then condense horizontally
    a = font.getbbox(ch)
    if a is None:
        return None, 0
    adv = font.getlength(ch)
    W = int(adv) + 8
    H = int(font.size * 1.6) + 8
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    d.text((4, 4), ch, font=font, fill=255)
    if condense != 1.0:
        img = img.resize((max(1, int(W * condense)), H), Image.LANCZOS)
        adv = adv * condense
    img = img.point(lambda p: 255 if p > 110 else 0)
    if ch == "0" and slash_w > 0:
        # slashed zero: diagonal through the counter, lower-left to upper-right
        x0, y0, x1, y1 = img.getbbox()
        w, h = x1 - x0, y1 - y0
        ImageDraw.Draw(img).line(
            [(x0 + w * 0.30, y1 - h * 0.24), (x1 - w * 0.30, y0 + h * 0.24)],
            fill=255, width=slash_w)
    return img, adv

def build(name, specs, out_prefix):
    """specs: list of (font, chars, condense, slash_zero_width). Shared metrics from first font."""
    glyphs = []
    max_h = 0
    for font, chars, condense, slash_w in specs:
        asc, desc = font.getmetrics()
        for ch in chars:
            img, adv = raster_glyph(font, ch, condense, slash_w)
            if img is None:
                continue
            bbox = img.getbbox()
            if bbox is None:  # space
                glyphs.append((ch, None, 0, 0, 0, 0, int(round(adv))))
                continue
            g = img.crop(bbox)
            xoff = bbox[0] - int(4 * condense)
            yoff = bbox[1] - 4
            glyphs.append((ch, g, g.width, g.height, xoff, yoff, int(round(adv))))
            max_h = max(max_h, bbox[3] - 4)
    line_h = max_h + 6
    base = line_h - 2
    # row packing
    atlas_w = 512
    x, y, row_h = 1, 1, 0
    placed = []
    for ch, g, w, h, xo, yo, adv in glyphs:
        if g is not None and x + w + 1 > atlas_w:
            x = 1
            y += row_h + 1
            row_h = 0
        placed.append((ch, g, x, y, w, h, xo, yo, adv))
        if g is not None:
            x += w + 1
            row_h = max(row_h, h)
    atlas_h = y + row_h + 1
    atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    for ch, g, gx, gy, w, h, xo, yo, adv in placed:
        if g is None:
            continue
        rgba = Image.new("RGBA", g.size, (255, 255, 255, 255))
        rgba.putalpha(g)
        atlas.paste(rgba, (gx, gy))
    png = f"{out_prefix}.png"
    atlas.save(os.path.join(OUT, png))
    lines = [
        f'info face="{name}" size={line_h} bold=1 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=1,1 outline=0',
        f'common lineHeight={line_h} base={base} scaleW={atlas_w} scaleH={atlas_h} pages=1 packed=0 alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0',
        f'page id=0 file="{png}"',
        f'chars count={len(placed)}',
    ]
    for ch, g, gx, gy, w, h, xo, yo, adv in placed:
        lines.append(
            f"char id={ord(ch)} x={gx} y={gy} width={w} height={h} "
            f"xoffset={xo} yoffset={max(0, yo)} xadvance={adv} page=0 chnl=15"
        )
    with open(os.path.join(OUT, f"{out_prefix}.fnt"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{out_prefix}: {len(placed)} glyphs, atlas {atlas_w}x{atlas_h}, lineH {line_h}")
    return line_h

# Fonts measured from typeface-7x_figma.svg:
#   time / label   Archivo wght 800 (46 px / 18 px)
#   battery, sun time  Courier Prime Bold 21 px condensed 0.88
#   rows               Courier Prime Regular 19 px;  date 20 px
def archivo(size, weight):
    f = ImageFont.truetype("Archivo.ttf", size)
    f.set_variation_by_axes([weight, 100])
    return f

DIGITS = "0123456789"
UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

build("time",  [(archivo(46, 800), DIGITS + ":", 1.0, 0)], "time")
build("label", [(archivo(18, 800), UPPER + " ", 1.0, 0)], "label")
build("bold",  [(ImageFont.truetype("CourierPrime-Bold.ttf", 21), DIGITS + ":-", 0.88, 2)], "bold")
build("text",  [(ImageFont.truetype("CourierPrime-Regular.ttf", 19), UPPER + DIGITS + ".:%-+/ ", 1.0, 2)], "text")
build("date",  [(ImageFont.truetype("CourierPrime-Regular.ttf", 20), UPPER + DIGITS + ". ", 1.0, 2)], "date")
