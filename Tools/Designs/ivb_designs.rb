# encoding: utf-8
# Mockups: IV Boundaries (topic 19), five designs in the improved KIF Settings
# layout (the template for settings-like KR screens). HR's IV Boundaries with
# the new features: Separate Boundaries (Wild, Eggs, Gifts), Max IVs as a
# Preset ("Perfect", taking over KIF's Max IVs Mode), Fusion IVs (Average or
# Best of Both), Live Preview (a sample roll). Trainers' IVs follow the
# difficulty and can't be edited.
# Design 1 = HR's options, laid out as Settings rows.
# Usage (from this folder): ruby ivb_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "qa_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "qa_designs.rb")

X_BTN = "p:2"; Y_BTN = "p:3"
def mon(b, sp, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(File.join(GFX, "Pokemon/Icons/#{sp}.png")), Rect.new(0, 0, 64, 64))
end
SOURCES = [["Wild", 20, 31], ["Eggs", 25, 31], ["Gifts", 15, 31]]
PRESETS = [["Vanilla", 0, 31], ["Accessibility", 15, 31], ["Strong", 20, 31], ["Perfect-ish", 25, 31], ["Perfect", 31, 31], ["Challenge", 0, 15], ["Custom", nil, nil]]
SAMPLE = [["HP", 27], ["Attack", 22], ["Defense", 31], ["Sp. Atk", 20], ["Sp. Def", 29], ["Speed", 24]]
def rng(a, b); "#{a}-#{b}"; end
def iv_bars(b, t, c, x, y, w, row = 16, lo = 20, hi = 31)
  SAMPLE.each_with_index do |(s, v), i|
    yy = y + i * row
    P.text(t, x, yy, 60, row, s, c[:dim], PF::TINY)
    bx = x + 62; bw = w - 62 - 28
    b.fill_rect(bx, yy + row / 2 - 3, bw, 6, c[:dark])
    b.fill_rect(bx, yy + row / 2 - 3, (bw * v / 31.0).round, 6, v == 31 ? GOLD : c[:selb])
    P.text(t, x + w - 24, yy, 24, row, v.to_s, v == 31 ? GOLD : c[:txt], PF::TINY, 1)
  end
end
def locked_pill(t, x, y, label = "BY DIFFICULTY"); P.pill(t, x, y, label, c_pill_dark, Color.new(200, 210, 225), true); end
def c_pill_dark; Color.new(40, 48, 62); end
def row_text(t, c, y, label, sel)
  cursor_at(184, y, W - 194, 24) if sel
  P.text(t, 196, y, 190, 24, label, c[:opt], PF::ROW)
end
def head(t, c, y, label); P.heading(t, 190, W - 16, y + 3, label, c[:head], c[:line]); end
def dual_bar(b, t, c, x, y, w, lo, hi, sel)
  b.fill_rect(x, y + 10, w, 4, c[:dark])
  x1 = x + (w * lo / 31.0).round; x2 = x + (w * hi / 31.0).round
  b.fill_rect(x1, y + 10, [x2 - x1, 2].max, 4, c[:selb])
  [[x1, lo], [x2, hi]].each_with_index do |(hx, v), k|
    UI.rbox(b, hx - 5, y + 5, hx + 5, y + 19, 4, (sel && k == 0) ? c[:white] : c[:selb], c[:dark])
  end
end
H_IV = [[:ud, "Select"], [:lr, "Change"], ["p:2", "Default"], [B_BTN, "Sections"]]
def shot(name); dump_as(name); end

c = palette(2)

#================================================================ IV1 Recommended: HR's options as Settings rows, the preview in the description box
frame(c)
settings_frame(c, SECTIONS, 3)
b = BASE.bitmap; t = TOP.bitmap
y = 40
head(t, c, y, "IV Boundaries"); y += 18
row_text(t, c, y, "IV Boundaries", false); value_cell(t, c, W - 60, y, "On", false); y += 24
row_text(t, c, y, "Preset", false); value_cell(t, c, W - 76, y, "Custom", false); y += 24
head(t, c, y, "Ranges"); y += 18
SOURCES.each_with_index do |(s, lo, hi), i|
  row_text(t, c, y, s, i == 0); value_cell(t, c, W - 60, y, rng(lo, hi), i == 0); y += 24
end
row_text(t, c, y, "Fusion IVs", false); value_cell(t, c, W - 76, y, "Average", false); y += 24
row_text(t, c, y, "Trainers", false); P.text(t, W - 200, y, 182, 24, "Normal: 0-31", c[:dim], PF::TEXT, 1)
b.fill_rect(W - 11, 44, 2, 212, c[:line]); b.fill_rect(W - 11, 44, 2, 120, c[:dim])
P.text(t, 14, 269, 200, 26, "Wild", c[:head], PF::ROW)
P.small(t, 14, 292, 210, 16, "New wild Pokémon roll", c[:txt]); P.small(t, 14, 308, 210, 16, "each IV in this range.", c[:txt])
P.text(t, 14, 328, 200, 12, "LIVE PREVIEW: A FRESH CATCH", c[:head], PF::TINY)
iv_bars(b, t, c, 236, 272, 262, 13)
hints(c, H_IV)
shot("IV1")

#================================================================ IV2 Range Sliders: each source as a two-handle bar, presets as chips
frame(c)
settings_frame(c, SECTIONS, 3)
b = BASE.bitmap; t = TOP.bitmap
head(t, c, 40, "Preset")
x = 190; cy = 56
PRESETS.each_with_index do |(n, _, _), i|
  w = P.width(PF::TINY, n.upcase) + 12
  (x = 190; cy += 18) if x + w > W - 16
  UI.rbox(b, x, cy, x + w, cy + 15, 5, n == "Strong" ? c[:sel] : c[:dark], n == "Strong" ? c[:selb] : c[:line])
  P.text(t, x, cy, w, 16, n.upcase, n == "Strong" ? c[:white] : c[:dim], PF::TINY, 2)
  x += w + 3
end
head(t, c, 92, "Ranges")
SOURCES.each_with_index do |(s, lo, hi), i|
  y = 110 + i * 30
  cursor_at(184, y - 2, W - 194, 28) if i == 0
  P.text(t, 196, y, 70, 24, s, c[:opt], PF::ROW)
  dual_bar(b, t, c, 262, y + 2, 168, lo, hi, i == 0)
  P.text(t, 448, y, 50, 24, rng(lo, hi), c[:txt], PF::TEXT, 1)
end
head(t, c, 204, "More")
P.text(t, 196, 222, 140, 24, "Fusion IVs", c[:opt], PF::ROW); value_cell(t, c, W - 76, 222, "Average", false)
iv_bars(b, t, c, 236, 272, 262, 13)
P.text(t, 14, 269, 200, 26, "Wild Floor", c[:head], PF::ROW)
P.small(t, 14, 294, 210, 16, "Left and right move the handle; Y swaps to the ceiling.", c[:txt]) if false
P.small(t, 14, 292, 210, 16, "Y switches between the", c[:txt]); P.small(t, 14, 308, 210, 16, "floor and the ceiling.", c[:txt])
P.text(t, 14, 328, 200, 12, "LIVE PREVIEW: A FRESH CATCH", c[:head], PF::TINY)
hints(c, [[:ud, "Select"], [:lr, "Move"], [Y_BTN, "Floor / Ceiling"], [B_BTN, "Sections"]])
shot("IV2")

#================================================================ IV3 Table: sources by Floor and Ceiling, preview in its own column
frame(c)
settings_frame(c, SECTIONS, 3)
b = BASE.bitmap; t = TOP.bitmap
head(t, c, 40, "IV Boundaries")
P.text(t, 196, 58, 140, 24, "Preset", c[:opt], PF::ROW); value_cell(t, c, W - 76, 58, "Custom", false)
P.text(t, 270, 88, 60, 12, "FLOOR", c[:head], PF::TINY, 2); P.text(t, 340, 88, 60, 12, "CEILING", c[:head], PF::TINY, 2)
rowsx = SOURCES + [["Trainers", 0, 31]]
rowsx.each_with_index do |(s, lo, hi), i|
  y = 102 + i * 26
  P.text(t, 196, y, 80, 24, s, s == "Trainers" ? c[:dim] : c[:opt], PF::ROW)
  [[lo, 270], [hi, 340]].each_with_index do |(v, cx), k|
    sel = i == 0 && k == 0
    UI.rbox(b, cx + 8, y + 2, cx + 52, y + 22, 5, sel ? c[:sel] : c[:dark], sel ? c[:selb] : c[:line])
    P.text(t, cx + 8, y, 44, 24, v.to_s, s == "Trainers" ? c[:dim] : c[:txt], PF::TEXT, 2)
  end
  locked_pill(t, W - 18, y + 5, "LOCKED") if s == "Trainers"
end
P.text(t, 196, 210, 140, 24, "Fusion IVs", c[:opt], PF::ROW); value_cell(t, c, W - 76, 210, "Average", false)
P.text(t, 196, 234, 140, 24, "Preview", c[:opt], PF::ROW); P.pill(t, W - 18, 239, "REROLL", c[:pill], c[:txt])
iv_bars(b, t, c, 236, 272, 262, 13)
P.text(t, 14, 269, 200, 26, "Wild Floor", c[:head], PF::ROW)
P.small(t, 14, 292, 210, 16, "The lowest IV a new", c[:txt]); P.small(t, 14, 308, 210, 16, "wild Pokémon can roll.", c[:txt])
hints(c, [[:ud, "Row"], [:lr, "Floor / Ceiling"], [A_BTN, "Edit"], [B_BTN, "Sections"]])
shot("IV3")

#================================================================ IV4 Preset Cards: pick a preset card, Custom opens the ranges
frame(c)
settings_frame(c, SECTIONS, 3)
b = BASE.bitmap; t = TOP.bitmap
head(t, c, 40, "Preset")
PRESETS.each_with_index do |(n, lo, hi), i|
  x = 188 + (i % 3) * 104; y = 58 + (i / 3) * 60
  sel = n == "Strong"
  UI.rbox(b, x, y, x + 98, y + 54, 7, sel ? c[:sel] : c[:dark], sel ? c[:selb] : c[:line])
  P.width(PF::TEXT, n) > 88 ? P.small(t, x, y + 6, 98, 16, n, sel ? c[:white] : c[:opt], 2) : P.text(t, x, y + 4, 98, 20, n, sel ? c[:white] : c[:opt], PF::TEXT, 2)
  if lo
    b.fill_rect(x + 10, y + 32, 78, 5, c[:panel2]); b.fill_rect(x + 10 + (78 * lo / 31.0).round, y + 32, [(78 * (hi - lo) / 31.0).round, 3].max, 5, n == "Perfect" ? GOLD : c[:selb])
    P.text(t, x, y + 38, 98, 14, rng(lo, hi), c[:dim], PF::TINY, 2)
  else
    P.text(t, x, y + 30, 98, 14, "YOUR OWN RANGES", c[:dim], PF::TINY, 2)
  end
end
P.text(t, 14, 269, 260, 26, "Strong", c[:head], PF::ROW)
P.small(t, 14, 292, 210, 16, "Wild, Eggs and Gifts", c[:txt]); P.small(t, 14, 308, 210, 16, "all roll 20-31.", c[:txt])
P.small(t, 14, 328, 210, 16, "Perfect: KIF's Max IVs Mode.", c[:dim])
iv_bars(b, t, c, 236, 272, 262, 13)
hints(c, [[:ud, "Choose"], [A_BTN, "Use"], [B_BTN, "Sections"]])
shot("IV4")

#================================================================ IV5 Sample Pokemon: a sample catch with its IVs, rerolled as you change things
frame(c)
settings_frame(c, SECTIONS, 3)
b = BASE.bitmap; t = TOP.bitmap
y = 40
head(t, c, y, "IV Boundaries"); y += 18
[["Preset", "Custom"], ["Wild", rng(20, 31)], ["Eggs", rng(25, 31)], ["Gifts", rng(15, 31)], ["Fusion IVs", "Best"], ["Trainers", rng(0, 31)]].each_with_index do |(l, v), i|
  cursor_at(184, y, 158, 24) if i == 1
  P.text(t, 194, y, 90, 24, l, l == "Trainers" ? c[:dim] : c[:opt], PF::TEXT)
  P.text(t, 270, y, 66, 24, v, l == "Trainers" ? c[:dim] : c[:txt], PF::TEXT, 1)
  y += 30
end
UI.rbox(b, 346, 40, W - 10, 258, 6, c[:panel2], c[:line])
P.text(t, 346, 44, W - 356, 12, "SAMPLE CATCH", c[:head], PF::TINY, 2)
mon(t, "PIKACHU", 400, 84, 52)
P.text(t, 426, 64, 80, 20, "Pikachu", c[:txt], PF::TEXT)
P.text(t, 426, 84, 80, 12, "WILD 20-31", c[:dim], PF::TINY)
iv_bars(b, t, c, 352, 112, 148, 17)
P.pill(t, W - 16, 228, "Y REROLL", c[:pill], c[:txt], true)
P.text(t, 14, 269, 260, 26, "Wild", c[:head], PF::ROW)
P.small(t, 14, 292, 480, 16, "New wild Pokémon roll each IV in this range.", c[:txt]); P.small(t, 14, 308, 480, 16, "The sample rolls again whenever you change it.", c[:dim])
hints(c, [[:ud, "Select"], [:lr, "Change"], [Y_BTN, "Reroll"], [B_BTN, "Sections"]])
shot("IV5")
