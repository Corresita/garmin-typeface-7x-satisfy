# TypeFace 7X

**A SATISFY-inspired typewriter watch face for Garmin.**

Built for the Fenix 7X / 7X Pro (280×280 MIP display), studying the look of the
SATISFY × COROS APEX 4 exclusive watch faces and recreating that feel on Garmin hardware.

![preview](preview.png)

## Features

- Public Sans time, Archivo label, Courier Prime typewriter text, all bitmap-rendered for crisp 1-bit MIP output
- Data rows, SATISFY style: RUN (today's running distance), HEART RATE, RECOVERY (Body Battery), KCAL
- Weekday date (THU.09.10 style), battery with bolt icon
- Segmented battery bar along the top arc (5 hollow segments, filled from the left, 20% each)
- Dot-grid halftone band with a hill line (a marker slides along it from sunrise to sunset)
  and the next sun event time at the bottom; the sun icon has rays before sunrise, none before sunset

## Build & install

1. Install VS Code and the official **Monkey C** extension
2. Run `Monkey C: Install SDK` (installs the Connect IQ SDK and device files) and
   `Monkey C: Generate a Developer Key` (first time only)
3. Open this folder, press **F5** and pick `fenix7xpro` to run in the simulator
   - The sun time shows `--:--` until you feed data via *Simulation → Weather*
4. `Monkey C: Build for Device` → copy the generated `.prg` to `GARMIN/Apps/`
   on the watch in USB mass-storage mode

Supported targets: `fenix7xpro`, `fenix7xpronowifi`, `fenix7x` (all 280×280, Connect IQ 4.2+
for the complication data).
Other resolutions need the layout constants adjusted.

## Customization

All layout lives in `source/TypeFaceView.mc` as constants at the top of the class
(coordinates, row positions, the `LABEL` text in the right column, the `SEG_*` constants
for the top bar).

Two helper scripts (Python 3 + Pillow, `pip install Pillow`):

- `gen_fonts.py` — regenerates the bitmap fonts (`resources/fonts/*.fnt` + PNG atlases)
  from the bundled TTFs (`PublicSans.ttf`, `Archivo.ttf`, `CourierPrime-Regular.ttf`, `CourierPrime-Bold.ttf`).
  Sizes, weights, horizontal condensing and the slashed-zero stroke width are parameters in
  the last few lines. Time digits are made tabular (equal width) so the clock never shifts.
- `typeface-7x_figma01.svg` — the Figma mockup the current layout is measured from
  (`typeface-7x_figma.svg` / `.png` are the earlier iteration; `preview.png` is the accurate render).
- `gen_svg.py` — exports `typeface-7x.svg`, an editable 280×280 vector version of the
  layout. Drag it into Figma / Sketch: every element is a named layer and the text stays
  editable. Install Archivo and Courier Prime locally first so the fonts
  match; the text is horizontally condensed to the same widths as the bitmap fonts.
- `preview.py` — renders a pixel-exact 280×280 PNG of the face without building or
  flashing anything. Fastest way to iterate on layout; it mirrors the layout constants
  of the Monkey C source, so port your numbers back once you're happy.

## Data notes

- RUN is today's running distance. Garmin only exposes this week's running total to watch
  faces (the daily total distance includes walking), so the face stores the weekly total at
  the start of each day and shows the difference. If another watch face was active at
  midnight, the baseline is taken when this face is next shown
- HEART RATE is the live sensor value if available, otherwise the newest history sample if it is
  less than 5 minutes old (so an unworn watch shows `--`)
- RECOVERY shows Garmin Body Battery (0-100) from the complication, sensor history as fallback.
  COROS-style recovery percentages are not exposed by Garmin; Body Battery is the closest match
  (recovery *time* in hours is also available if you prefer that)
- Sun times come from the watch's own sunrise/sunset complications; if those are unavailable,
  from the weather observation point or the last GPS fix. With nothing, the row shows `--:--`
  and the marker follows the clock (06:00-18:00)
- Optional red ticks at the right end of the top scale: `SHOW_RED_TICKS` in the view (off by default)

## License

Code: [MIT](LICENSE). Fonts: Public Sans, Archivo and Courier Prime under the
[SIL Open Font License 1.1](OFL.txt).

This is an independent fan project. Not affiliated with SATISFY, COROS, or Garmin.
