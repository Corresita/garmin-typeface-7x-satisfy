#!/usr/bin/env python3
"""Export the face layout as an editable SVG (280x280) for Figma / Sketch.

Drag typeface-7x.svg into Figma: every element becomes its own named layer,
text stays editable. Font: Courier Prime Bold (install it
locally so Figma can match). The bitmap fonts on the watch are horizontally
condensed; the SVG applies the same scaleX (derived from the .fnt advances) so widths
match the device. Layout constants mirror TypeFaceView.mc / preview.py.
"""
import math

CX = CY = 140
BATT_Y, DATE_Y, TIME_Y, SAT_Y = 22, 57, 66, 100
BATT_X, DATE_X = 133, 48
LABEL_X, COL2_X = 40, 177
ROW_Y = [122, 143, 164, 185]
BAND_Y = 208
SEG_COUNT, SEG_LEN, SEG_GAP, SEG_R_OUT, SEG_R_IN = 5, 12.0, 3.5, 131, 126
BATT = 33

# from the .fnt files: text glyphs sit at yoffset 4, cap height 13, xadvance 11 (TTF 13);
# time glyphs at yoffset 10, cap height 41, xadvance 24 (TTF 37). Baseline = draw y + yoffset + cap.
TEXT_BASE = 4 + 13
TIME_BASE = 11 + 40
TEXT_SX = 11 / 13   # horizontal condensing that reproduces the bitmap widths
TIME_SX = 25 / 38.4

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
# sun path arc + marker
ARC_CX, ARC_CY, ARC_R, ARC_A0, ARC_A1 = 146, 384, 131, 62.0, 118.0
FRAC = 0.75
(x1, y1), (x0, y0) = pt(ARC_A1, ARC_R), pt(ARC_A0, ARC_R)
x1, y1 = ARC_CX + ARC_R * math.cos(math.radians(ARC_A1)), ARC_CY - ARC_R * math.sin(math.radians(ARC_A1))
x0, y0 = ARC_CX + ARC_R * math.cos(math.radians(ARC_A0)), ARC_CY - ARC_R * math.sin(math.radians(ARC_A0))
L.append(f'  <path id="sun path" d="M{x1:.2f},{y1:.2f} A{ARC_R},{ARC_R} 0 0 1 {x0:.2f},{y0:.2f}" fill="none" stroke="#000" stroke-width="2"/>')
ma = math.radians(ARC_A1 - FRAC * (ARC_A1 - ARC_A0))
L.append(f'  <circle id="sun marker" cx="{ARC_CX + ARC_R * math.cos(ma):.2f}" cy="{ARC_CY - ARC_R * math.sin(ma):.2f}" r="4" fill="#fff" stroke="#000" stroke-width="1"/>')

# sun row knockout + icon + time
bx, by, bw, bh = 88, 206, 104, 27
L.append(f'  <rect id="sun knockout" x="{bx}" y="{by}" width="{bw}" height="{bh}" fill="#fff"/>')
ix, iy = bx + 14, by + 20
L.append(f'  <path id="sun icon" d="M{ix-8},{iy} A8,8 0 0 1 {ix+8},{iy}" fill="none" stroke="#000" stroke-width="2"/>')
L.append(f'  <line id="sun horizon" x1="{ix-10}" y1="{iy+1}" x2="{ix+10}" y2="{iy+1}" stroke="#000" stroke-width="2"/>')
L.append(text("sun time", bx + 28, by - 1 + TEXT_BASE, "18:13", 21, TEXT_SX))

# top segmented bar
filled = min(SEG_COUNT, BATT // 20)
total = SEG_COUNT * SEG_LEN + (SEG_COUNT - 1) * SEG_GAP
left = 90.0 + total / 2
for i in range(SEG_COUNT):
    a1 = left - i * (SEG_LEN + SEG_GAP); a0 = a1 - SEG_LEN
    fill = "#000" if i < filled else "none"
    L.append(f'  <path id="segment {i+1}" d="{seg_path(a1, a0, SEG_R_OUT, SEG_R_IN)}" '
             f'fill="{fill}" stroke="#000" stroke-width="1"/>')

# battery: digits + outlined bolt
L.append(text("battery", BATT_X, BATT_Y + TEXT_BASE, str(BATT), 21, TEXT_SX))
BOLT = [(128, 26), (124, 26), (122, 35), (126, 35), (124, 41), (130, 32), (126, 32)]
L.append('  <polygon id="bolt" points="' + " ".join(f"{x},{y}" for x, y in BOLT) + '" fill="none" stroke="#000" stroke-width="1"/>')

# date / time / label / rows
L.append(text("date", DATE_X, DATE_Y + TEXT_BASE, "THU.09.10", 21, TEXT_SX))
L.append(text("time", LABEL_X - 4, TIME_Y + TIME_BASE, "12:17", 64, TIME_SX))
L.append(text("label", COL2_X, SAT_Y + TEXT_BASE, "SATISFY", 21, TEXT_SX))
for i, (k, v) in enumerate([("RUN", "0.2KM"), ("HEART RATE", "69BPM"), ("RECOVERY", "79%"), ("KCAL", "863")]):
    L.append(text(f"row {i+1} label", LABEL_X, ROW_Y[i] + TEXT_BASE, k, 21, TEXT_SX))
    L.append(text(f"row {i+1} value", COL2_X, ROW_Y[i] + TEXT_BASE, v, 21, TEXT_SX))

L += ['  </g>', '</svg>']
open("typeface-7x.svg", "w").write("\n".join(L) + "\n")
print("wrote typeface-7x.svg")
