# TypeFace 7X

**A SATISFY-inspired typewriter watch face for Garmin.**

Built for the Fenix 7X / 7X Pro (280×280 MIP display), studying the look of the
SATISFY × COROS APEX 4 exclusive watch faces and recreating that feel on Garmin hardware.

![preview](preview.png)

## Features

- Heavy condensed typewriter time display (Courier Prime, bitmap-rendered for crisp 1-bit MIP output)
- Data rows, SATISFY style: RUN (today's distance), HEART RATE, RECOVERY (Body Battery), KCAL
- Weekday date (THU.09.10 style), battery with bolt icon
- Segmented battery bar along the top arc (5 hollow segments, filled from the left, 20% each)
- Dot-grid halftone band with hill silhouette and next sun event (sunrise / sunset) at the bottom

## Build & install

1. Install VS Code and the official **Monkey C** extension
2. Run `Monkey C: Install SDK` (installs the Connect IQ SDK and device files) and
   `Monkey C: Generate a Developer Key` (first time only)
3. Open this folder, press **F5** and pick `fenix7xpro` to run in the simulator
   - The sun time shows `--:--` until you feed data via *Simulation → Weather*
4. `Monkey C: Build for Device` → copy the generated `.prg` to `GARMIN/Apps/`
   on the watch in USB mass-storage mode

Supported targets: `fenix7xpro`, `fenix7xpronowifi`, `fenix7x` (all 280×280).
Other resolutions need the layout constants adjusted.

## Customization

All layout lives in `source/TypeFaceView.mc` as constants at the top of the class
(coordinates, row positions, the `LABEL` text in the right column, the `SEG_*` constants
for the top bar).

Two helper scripts (Python 3 + Pillow, `pip install Pillow`):

- `gen_fonts.py` — regenerates the bitmap fonts (`resources/fonts/*.fnt` + PNG atlases)
  from the bundled `CourierPrime-Bold.ttf`. Size, horizontal condensing, and stroke weight
  are parameters in the last few lines. Swap in any monospace TTF.
- `gen_svg.py` — exports `typeface-7x.svg`, an editable 280×280 vector version of the
  layout. Drag it into Figma / Sketch: every element is a named layer and the text stays
  editable. Install `CourierPrime-Bold.ttf` locally first so the font
  matches; the text is horizontally condensed to the same widths as the bitmap fonts.
- `preview.py` — renders a pixel-exact 280×280 PNG of the face without building or
  flashing anything. Fastest way to iterate on layout; it mirrors the layout constants
  of the Monkey C source, so port your numbers back once you're happy.

## Data notes

- RUN is today's total distance from the activity monitor; HEART RATE is the live
  sensor value if available, otherwise the newest history sample
- RECOVERY shows Garmin Body Battery (0-100). COROS-style recovery / training load
  numbers are not exposed to third-party watch faces by Garmin, so this is the closest match
- The sun row needs weather synced from the phone; otherwise `--:--`
- Optional red ticks at the right end of the top scale: `SHOW_RED_TICKS` in the view (off by default)

## License

Code: [MIT](LICENSE). Font: Courier Prime under the
[SIL Open Font License 1.1](OFL.txt).

This is an independent fan project. Not affiliated with SATISFY, COROS, or Garmin.
