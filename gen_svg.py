#!/usr/bin/env python3
"""Export the face layout as an editable SVG (280x280) for Figma / Sketch.

Drag typeface-7x.svg into Figma: every element becomes its own named layer,
text stays editable. Fonts: Public Sans + Archivo + Courier Prime (install them
locally so Figma can match). The bitmap fonts on the watch are horizontally
condensed; the SVG applies the same scaleX (derived from the .fnt advances) so widths
match the device. Layout constants mirror TypeFaceView.mc / preview.py.
"""
import math

CX = CY = 140
BATT_Y, DATE_Y, TIME_Y, SAT_Y = 22, 56, 67, 106
BATT_X, DATE_X = 133, 48
LABEL_X, COL2_X, SAT_X, TIME_X = 34, 176, 178, 22
ROW_Y = [125, 146, 167, 188]
BAND_Y = 214
SEG_COUNT, SEG_LEN, SEG_END, SEG_GAP, SEG_R_OUT, SEG_R_IN = 5, 12.0, 14.0, 3.5, 131, 126
BATT = 33

# from the .fnt files: text glyphs sit at yoffset 4, cap height 13, xadvance 11 (TTF 13);
# time glyphs at yoffset 10, cap height 41, xadvance 24 (TTF 37). Baseline = draw y + yoffset + cap.
TEXT_BASE = 5 + 11    # Courier Prime Regular 20 (rows)
DATE_BASE = 5 + 11    # Courier Prime Regular 20
BOLD_BASE = 4 + 13    # Courier Prime Bold 21, condensed 0.88 (battery, sun time)
TIME_BASE = 13 + 42   # Public Sans 900, 56, condensed 0.89
LABEL_BASE = 4 + 12   # Archivo 800, 18
TEXT_SX = 1.0
BOLD_SX = 11 / 13
TIME_SX = 0.89

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

def text(id_, x, y, s, size, sx, family="Courier Prime", weight=400, anchor="start", stretch=None):
    st = f' font-stretch="{stretch}"' if stretch else ""
    return (f'  <text id="{id_}" transform="translate({x},{y}) scale({sx},1)" '
            f'font-family="{family}" font-weight="{weight}" font-size="{size}"{st} '
            f'text-anchor="{anchor}" fill="#000">{s}</text>')

L = ['<svg xmlns="http://www.w3.org/2000/svg" width="280" height="280" viewBox="0 0 280 280">',
     '  <clipPath id="screen"><circle cx="140" cy="140" r="140"/></clipPath>',
     '  <g id="TypeFace 7X" clip-path="url(#screen)">',
     '  <circle id="background" cx="140" cy="140" r="140" fill="#fff"/>']

# halftone band (dot grid) + hill
L.append('  <pattern id="dots" width="4" height="4" patternUnits="userSpaceOnUse">'
         '<rect width="2" height="2" fill="#000"/></pattern>')
L.append(f'  <rect id="halftone band" x="0" y="{BAND_Y}" width="280" height="72" fill="url(#dots)"/>')
# hill line + sun marker
HILL_DX, MARK_X0, MARK_X1, FRAC = 19, 60, 200, 0.75
def hill(x):
    x -= HILL_DX
    return 273 - 24 * math.exp(-((x - 112) / 58.0) ** 2) - 12 * math.exp(-((x - 268) / 46.0) ** 2)
pts = " ".join(f"{x},{hill(x):.2f}" for x in range(0, 281, 2))
L.append(f'  <polyline id="hill line" points="{pts}" fill="none" stroke="#000" stroke-width="2"/>')
mx = MARK_X0 + FRAC * (MARK_X1 - MARK_X0)
L.append(f'  <circle id="sun marker" cx="{mx:.1f}" cy="{hill(mx):.2f}" r="3" fill="#fff" stroke="#000" stroke-width="2"/>')

# sun row knockout + icon + time
bx, by, bw, bh = 91, 219, 83, 22
L.append(f'  <rect id="sun knockout" x="{bx}" y="{by}" width="{bw}" height="{bh}" fill="#fff"/>')
ix, iy = bx + 12, by + 15
L.append(f'  <path id="sun icon" d="M{ix-8},{iy} A8,8 0 0 1 {ix+8},{iy}" fill="none" stroke="#000" stroke-width="2"/>')
L.append(f'  <line id="sun horizon" x1="{ix-10}" y1="{iy+1}" x2="{ix+10}" y2="{iy+1}" stroke="#000" stroke-width="2"/>')
for n, (x0, y0, x1, y1) in enumerate(((ix - 8.5, iy - 11, ix - 6.5, iy - 9), (ix, iy - 14, ix, iy - 10), (ix + 8.5, iy - 11, ix + 6.5, iy - 9))):
    L.append(f'  <line id="sun ray {n+1}" x1="{x0}" y1="{y0}" x2="{x1}" y2="{y1}" stroke="#000" stroke-width="2"/>')
L.append(text("sun time", bx + 26, by + 1 + BOLD_BASE, "18:13", 21, BOLD_SX, weight=700))

# top segmented bar
filled = min(SEG_COUNT, BATT // 20)
total = (SEG_COUNT - 2) * SEG_LEN + 2 * SEG_END + (SEG_COUNT - 1) * SEG_GAP
a1 = 90.0 + total / 2
for i in range(SEG_COUNT):
    ln = SEG_END if i in (0, SEG_COUNT - 1) else SEG_LEN
    if i > 0:
        a1 -= SEG_GAP
    a0 = a1 - ln
    fill = "#000" if i < filled else "none"
    L.append(f'  <path id="segment {i+1}" d="{seg_path(a1, a0, SEG_R_OUT, SEG_R_IN)}" '
             f'fill="{fill}" stroke="#000" stroke-width="1"/>')
    a1 = a0

# battery: digits + outlined bolt
L.append(text("battery", BATT_X, BATT_Y + BOLD_BASE, str(BATT), 21, BOLD_SX, weight=700))
BOLT = [(128, 26), (124, 26), (122, 35), (126, 35), (124, 41), (130, 32), (126, 32)]
L.append('  <polygon id="bolt" points="' + " ".join(f"{x},{y}" for x, y in BOLT) + '" fill="none" stroke="#000" stroke-width="1"/>')

# date / time / label / rows
L.append(text("date", DATE_X, DATE_Y + DATE_BASE, "MON.09.10", 20, 1.0))
L.append(text("time", TIME_X, TIME_Y + TIME_BASE, "18:13", 56, TIME_SX, family="Public Sans", weight=900))
L.append(text("label", SAT_X, SAT_Y + LABEL_BASE, "SATISFY", 18, 1.0, family="Archivo", weight=800))
for i, (k, v) in enumerate([("RUN", "0.2KM"), ("HEART RATE", "69BPM"), ("RECOVERY", "79%"), ("KCAL", "863")]):
    L.append(text(f"row {i+1} label", LABEL_X, ROW_Y[i] + TEXT_BASE, k, 20, TEXT_SX))
    L.append(text(f"row {i+1} value", COL2_X, ROW_Y[i] + TEXT_BASE, v, 20, TEXT_SX))

L += ['  </g>', '</svg>']
open("typeface-7x.svg", "w").write("\n".join(L) + "\n")
print("wrote typeface-7x.svg")
