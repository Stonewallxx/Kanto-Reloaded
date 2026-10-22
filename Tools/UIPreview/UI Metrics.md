# UI Metrics

This guide covers how Kanto Reloaded's engine (mkxp-z running PIF's Essentials v19 scripts) draws a screen. Use it to size and place UI before you launch the game. The numbers were measured from an in-game screenshot, and the UI preview in this folder (`preview.rb`, then `render.py`) matches that screenshot pixel for pixel.

## The screen

- **Every screen is laid out in 512×384 game pixels.** These come from `Settings::SCREEN_WIDTH` and `SCREEN_HEIGHT`, also available as `Graphics.width` and `Graphics.height`.
- **Screen Size only scales the window.** It doesn't change the layout:

  | Screen Size | Window scale |
  |---|---|
  | S | 0.5× |
  | M | 1× |
  | L | 1.5× |
  | XL | 2× |
  | Full | Fullscreen |

  (`pbSetResizeFactor`: `Graphics.scale = (factor + 1) * 0.5`.)
- **Design at 512×384, and preview at 2× nearest-neighbour** to see the pixels. A mockup drawn at 1024×768 with web fonts is not to scale: the game font is about twice as large relative to the screen.
- **Layering:** `pbFadeOutIn` keeps a black layer at z 99999 while a menu runs. A screen opened inside it needs a viewport at z 99999, created after the fade; otherwise it draws under the black. Message windows are created later still, so they draw on top.

## Fonts

mkxp-z renders a font at **90% of the script's size**, rounded down. So `font.size = 29` draws 26 px tall.

| Font | Set with | Script size | Draws at | Line height | Width per character | Use |
|---|---|---|---|---|---|---|
| Power Green | `pbSetSystemFont` | 29 | 26 px | 26 px | ~10 px | Names, values, titles |
| Power Green Small | `pbSetSmallFont` | 25 | 22 px | 22 px | ~9 px | Descriptions, hints, buttons, tabs |
| Power Green Small | size 20 | 20 | 18 px | 18 px | ~7 px | Button hints |
| Power Green Small | size 14 | 14 | 12 px | 12 px | ~6 px | Badges |
| Power Green Narrow | `pbSetNarrowFont` | 29 | 26 px | 26 px | ~9.5 px | Long text in a tight space |

Examples:
- "Accessibility" is 130 px in the system font.
- One full line of small text fits about 52 characters across 480 px.
- Chinese uses the fusion-pixel fonts (`MessageConfig::FONT_NAME_CHINESE`); give text room to change width.

Always measure with `bitmap.text_size(text).width` after setting the font, rather than estimating.

**Global Small Text** (Kanto Reloaded > Interface) is off by default. While it's on, `pbSetSystemFont` sets the small font, so system-font text draws 22 px tall instead of 26 px. KIF's pixel-font screens and EBDX's battle UI swap their large fonts for the small one too. Build every screen to work with both sizes:
- size boxes for the larger font;
- measure after setting the font (`text_size`, or `KIF::PixelFont.width`);
- check both modes in the UI preview (state 23 turns it on).

The fonts have no arrow or triangle characters (‹ › ◂ ▸ ▾). Draw arrows as pixels (`KIF::PixelUI.tri`).

## How text is placed

`bitmap.draw_text(x, y, w, h, text, align)` in this mkxp-z build works like this:

- **Vertical: it does not centre.** The top of the line (the ascent line) is placed at `y`, whatever `h` is. This was measured for boxes 22, 28 and 32 px tall. Capital letters then start 1 px below `y` in the small font and 2 px below in the system font.
- **Horizontal:** text is placed by its advance width, with align 0 = left, 1 = centre, 2 = right. It never starts left of `x`.
- **Too wide:** text wider than `w` is squeezed horizontally to fit, not cut off. Leave room so names don't squash.
- **Pixels:** `fill_rect` replaces pixels, while text and `blt` blend over them.

PIF's helpers add their own offsets:

- **`pbDrawShadowText(bitmap, x, y, w, h, ...)`** adds 4 to `y`, then draws the shadow at (+2, 0), (0, +2) and (+2, +2). PIF's lists call it with 32-px rows.
- **`pbDrawTextPositions`** adds 6 to `y` before calling `pbDrawShadowText`. Its `y` is therefore about 10 px above where the text appears.

## KIF's pixel fonts

KIF Beta's own screens (KIF Settings, Battle Info) don't use `draw_text`. `KIF::PixelFont` (`990_KIF/000_Core/013`) holds the game fonts as bitmaps at four sizes, and draws each letter as a tiny bitmap copied with `blt`. So letters are never smoothed or squeezed.

| Font | Constant | Capitals: top row, height |
|---|---|---|
| Power Green 26 | `TITLE` | 2, 18 |
| Power Green Narrow 26 | `ROW` | 2, 18 |
| Power Green Small 22 | `TEXT` | 1, 14 |
| Power Green 13 | `TINY` | 1, 9 |

These are measured on flat capitals (H, E, K); Q and J hang lower.

KIF's `PixelUI.text` centres on the font's height, which sits text a few pixels low. **Use `Reloaded::Pixel.text(bitmap, x, y, w, h, text, colour, font, align)` for our screens.** It centres the capitals in the box, so text lines up with icons, badges and arrows centred in the same box. It also follows Global Small Text. `Pixel.glyph` centres one character on its own pixels (section tiles), and `Pixel.pill` draws a badge with its text centred.

The pixel fonts stay crisp only at their own sizes and twice them. A size in between (18 or 16 px) has broken strokes. So the smaller text of hints and descriptions is the game's small font at size 20 (18 px), drawn by the engine with `Pixel.small`, as the Kanto Reloaded mod's hints were. Its capitals are 13 px tall, starting 1 px below the line's top. Counts beside a tab's label are `TINY`, 5 px after the label. The size below it is `Pixel::HALF` (`[:small, 11]`), half of `TEXT`.

**Shadow rule:** only screen titles and headers have shadows. Setting names, values, help text, hints, buttons and badges don't.

## Rows, windows and spacing

- **List rows are 32 px**, as in `Window_DrawableCommand`. A 26-px system-font line sits in a 32-px row.
- **Small-font lines are 22 px apart.**
- **PIF windows lose 32 px to their frame** horizontally and vertically: 16 px each side (`borderX` / `borderY` with a standard skin). There is also 4 px of text padding (`SpriteWindow_Base::TEXTPADDING`).
- **Badges are 14 px tall**, in the small font at size 14.
- **To centre something in a row,** put its centre at `y + h / 2` (icons: `y + (h - 16) / 2`; badges: `y + (h - 14) / 2`) and draw text with `Draw.text` using the same box.
- **Page icons are 16×16 pixel art**, drawn at 1×.
- **Leave 6–10 px between a label and the next element.** On the right, keep a gap between the end of a centred title and any right-aligned text. A centred page name takes the middle ~200 px of the row.

## The improved KIF Settings layout

These are the values from `Reloaded::SettingsScreen`, as a worked example. Everything is drawn in KIF's pixel fonts.

| Area | y | Contents |
|---|---|---|
| Title bar | 0–31 | Search (x 8, w 112; a mouse click opens it), "KIF Settings" centred (`TITLE`), Presets (x 392, w 112). Buttons are 23 px tall (y 4–27). While typing, the text field fills the bar. |
| Sidebar | 36–264 | x 6–174. Sections every 20 px from y 40: a 15-px colour tile at x 14, the name at x 33 (`TEXT`). |
| List | 36–264 | x 180–506. Headings 18 px (`TINY`, left), rows 26 px: the cursor from x 184, the changed dot from x 190, the name from x 201 (`ROW`), values between arrows centred around x 446. |
| Description | 268–354 | The name at +1 (`ROW`, 26 px box, Header Color), ALL SAVES / THIS SAVE and DEFAULT badges right-aligned at +7, help from +28 (the smaller text, 17 px lines, 3 lines). |
| Hints | 359–384 | The button in text colour, its label dimmed (the smaller text). |

The cursor is its own layer between the panels and the text, so its see-through colours and pulse show over the panel and under the text.
