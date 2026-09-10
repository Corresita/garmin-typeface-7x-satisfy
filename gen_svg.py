#!/usr/bin/env python3
"""Export the face layout as an editable SVG (280x280) for Figma / Sketch.

Drag typeface-7x.svg into Figma: every element becomes its own named layer,
text stays editable. Fonts: Courier Prime Bold + Noto Sans SC (install them
locally so Figma can match). The bitmap fonts on the watch are horizontally
condensed; the SVG applies the same scaleX (derived from the .fnt advances) so widths
match the device. Layout constants mirror TypeFaceView.mc / preview.py.
"""
import math

CX = CY = 140
BATT_Y, DATE_Y, TIME_Y, SAT_Y = 18, 42, 62, 86
LABEL_X, COL2_X = 40, 176
ROW_Y = [124, 145, 166, 187]
BAND_Y = 208
SEG_COUNT, SEG_LEN, SEG_GAP, SEG_R_OUT, SEG_R_IN = 5, 14.0, 4.0, 132, 125
RED_TICKS = [42.0, 39.0, 36.0]
BATT = 33

# from the .fnt files: text glyphs sit at yoffset 4, cap height 13, xadvance 11 (TTF 13);
# time glyphs at yoffset 10, cap height 41, xadvance 24 (TTF 37). Baseline = draw y + yoffset + cap.
TEXT_BASE = 4 + 13
TIME_BASE = 10 + 41
TEXT_SX = 11 / 13   # horizontal condensing that reproduces the bitmap widths
TIME_SX = 24 / 37

def pt(a, r):
    return CX + r * math.cos(math.radians(a)), CY - r * math.sin(math.radians(a))

def arc_path(a1, a0, r):  # a1 > a0, counter-clockwise degrees (90 = up)
    x1, y1 = pt(a1, r); x0, y0 = pt(a0, r)
    return f"M{x1:.2f},{y1:.2f} A{r},{r} 0 0 1 {x0:.2f},{y0:.2f}"

def seg_path(a1, a0, ro, ri):
    xo1, yo1 = pt(a1, ro); xo0, yo0 = pt(a0, ro)
    xi0, yi0 = pt(a0, ri); xi1, yi1 = pt(a1, ri)
    return (f"M{xo1:.2f},{yo1:.2f} A{ro},{ro} 0 0 1 {xo0:.2f},{yo0:.2f} "
            f"L{xi0:.2f},{yi0:.2f} A{ri},{ri} 0 0 0 {xi1:.2f},{yi1:.2f} Z")

def text(id_, x, y, s, size, sx, family="Courier Prime", anchor="start"):
    return (f'  <text id="{id_}" transform="translate({x},{y}) scale({sx},1)" '
            f'font-family="{family}" font-weight="700" font-size="{size}" '
            f'text-anchor="{anchor}" fill="#000">{s}</text>')

L = ['<svg xmlns="http://www.w3.org/2000/svg" width="280" height="280" viewBox="0 0 280 280">',
     '  <clipPath id="screen"><circle cx="140" cy="140" r="140"/></clipPath>',
     '  <g id="TypeFace 7X" clip-path="url(#screen)">',
     '  <circle id="background" cx="140" cy="140" r="140" fill="#fff"/>']

# halftone band (dot grid) + hill
L.append('  <pattern id="dots" width="2" height="2" patternUnits="userSpaceOnUse">'
         '<rect width="1" height="1" fill="#000"/></pattern>')
L.append(f'  <rect id="halftone band" x="0" y="{BAND_Y}" width="280" height="72" fill="url(#dots)"/>')
def hill(x):
    return 272 - 24 * math.exp(-((x - 112) / 58.0) ** 2) - 12 * math.exp(-((x - 268) / 46.0) ** 2)
pts = " ".join(f"{x},{hill(x):.2f}" for x in range(0, 281, 4))
L.append(f'  <polygon id="hill fill" points="0,281 {pts} 280,281" fill="#fff"/>')
L.append(f'  <polyline id="hill line" points="{pts}" fill="none" stroke="#000" stroke-width="2"/>')

# sun row knockout + icon + time
scx, scy = 140, BAND_Y + 12
L.append(f'  <rect id="sun knockout" x="{scx-52}" y="{scy-14}" width="104" height="27" fill="#fff"/>')
L.append(f'  <path id="sun icon" d="M{scx-46},{scy+6} A8,8 0 0 1 {scx-30},{scy+6}" fill="none" stroke="#000" stroke-width="2"/>')
L.append(f'  <line id="sun horizon" x1="{scx-48}" y1="{scy+7}" x2="{scx-28}" y2="{scy+7}" stroke="#000" stroke-width="2"/>')
L.append(text("sun time", scx - 24, scy - 15 + TEXT_BASE, "18:13", 21, TEXT_SX))

# top segmented bar
filled = min(SEG_COUNT, BATT // 20)
total = SEG_COUNT * SEG_LEN + (SEG_COUNT - 1) * SEG_GAP
left = 90.0 + total / 2
for i in range(SEG_COUNT):
    a1 = left - i * (SEG_LEN + SEG_GAP); a0 = a1 - SEG_LEN
    fill = "#000" if i < filled else "none"
    L.append(f'  <path id="segment {i+1}" d="{seg_path(a1, a0, SEG_R_OUT, SEG_R_IN)}" '
             f'fill="{fill}" stroke="#000" stroke-width="1"/>')
for i, a in enumerate(RED_TICKS):
    (x0, y0), (x1, y1) = pt(a, SEG_R_IN), pt(a, SEG_R_OUT)
    L.append(f'  <line id="red tick {i+1}" x1="{x0:.2f}" y1="{y0:.2f}" x2="{x1:.2f}" y2="{y1:.2f}" stroke="#e00" stroke-width="2"/>')

# battery
L.append(text("battery", CX + 8, BATT_Y + TEXT_BASE, str(BATT), 21, TEXT_SX))
bx, by = CX - 4, BATT_Y + 15
L.append(f'  <polygon id="bolt" points="{bx},{by-10} {bx-7},{by+2} {bx-2},{by+2} {bx-4},{by+10} {bx+4},{by-2} {bx-1},{by-2}" fill="#000"/>')

# date / time / label / rows
L.append(f'  <g id="date" transform="translate({LABEL_X},{DATE_Y + TEXT_BASE})">'
         f'<text font-family="Noto Sans SC" font-weight="700" font-size="19" fill="#000">周一</text>'
         f'<text x="38" transform="scale({TEXT_SX:.4f},1)" font-family="Courier Prime" font-weight="700" font-size="21" fill="#000">.07.09</text></g>')
L.append(text("time", LABEL_X - 4, TIME_Y + TIME_BASE, "10:19", 62, TIME_SX))
L.append(text("label", COL2_X, SAT_Y + TEXT_BASE, "SATISFY", 21, TEXT_SX))
for i, (k, v) in enumerate([("RUN", "0.2KM"), ("HEART RATE", "69BPM"), ("RECOVERY", "79%"), ("KCAL", "863")]):
    L.append(text(f"row {i+1} label", LABEL_X, ROW_Y[i] + TEXT_BASE, k, 21, TEXT_SX))
    L.append(text(f"row {i+1} value", COL2_X, ROW_Y[i] + TEXT_BASE, v, 21, TEXT_SX))

L += ['  </g>', '</svg>']
open("typeface-7x.svg", "w").write("\n".join(L) + "\n")
print("wrote typeface-7x.svg")
