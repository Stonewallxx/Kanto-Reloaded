# encoding: utf-8
# Mockups: New Game Setup, part 2: the Run Setup. Five designs, each two
# screens: every per-run choice in one place (from a preset: Randomizer Run),
# then the Per-Save Settings First page (any per-save KIF or KR option, set
# before the game starts instead of being reset). Choices: Difficulty
# (Hard), Pokedex (Expanded), Randomizer (opens KIF's randomizer screen),
# IV Boundaries (Strong), Starters (Johto; KIF offers sets after a first
# save), Starting Money ($3,000), Battle Money (1x), Autosave (On).
# Design 1 = the chosen layout (rows beside Oak, a details panel) as a list.
# Usage (from this folder): ruby runsetup_designs.rb "<KIF Beta>" <work dir with metrics.json>
NMSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "ngmode_designs.rb"), :encoding => "UTF-8")
eval(NMSRC.split("c = palette(2)\n")[0], binding, "ngmode_designs.rb")

ROWS = [["Difficulty", "Hard", "Trainer levels x1.1, smartest AI, harder movesets. Shown as the lowest you ever use.", AMBER],
        ["Pokédex", "Expanded", "522 more Pokémon from Gen 4 to 9. Locked once you start.", BLUE2],
        ["Randomizer", "Set Up", "Opens KIF's randomizer: what to shuffle, the seed, starting town.", Color.new(240, 170, 60)],
        ["IV Boundaries", "Strong", "New Pokémon's IVs: 20-31 (wild, eggs, gifts).", GREEN],
        ["Starters", "Johto", "Which three starters Oak offers.", BLUE2],
        ["Starting Money", "$3,000", "Money at the start of the game.", GREEN],
        ["Battle Money", "1x", "Extra prize money from battles (1x-10x).", GREEN],
        ["Autosave", "On", "Saves on its own as you play.", BLUE2],
        ["All Per-Save Settings", "", "Any other per-save option, set now instead of later.", nil]]
CLEAR = Color.new(0, 0, 0, 0) unless defined?(CLEAR)
PERSAVE = [["Kanto Reloaded", [["Quick Throw", "On"], ["Wild Link", "On"], ["Weather System", "On"], ["Double Abilities", "Off"]]],
           ["Battles", [["Battle Style", "Set"], ["Exp. Share", "Party"], ["Level Caps", "Soft"]]]]
def rows_panel(c, x, y, w, sel, rh = 26)
  b = BASE.bitmap; t = TOP.bitmap
  ROWS.each_with_index do |(l, v, _, _), i|
    yy = y + i * rh
    cursor_at(x + 4, yy, w - 8, rh - 2) if i == sel
    P.text(t, x + 14, yy + 1, 170, 22, l, i == 8 ? c[:txt] : c[:opt], PF::TEXT)
    if v.empty?
      P.pill(t, x + w - 12, yy + 5, "OPEN", c[:pill], c[:txt])
    elsif v == "Set Up"
      P.pill(t, x + w - 12, yy + 5, "SET UP", Color.new(70, 46, 14), AMBER)
    else
      value_cell(t, c, x + w - 56, yy - 1, v, i == sel)
    end
  end
end
def preset_tag(t, x, y); P.pill(t, x, y, "PRESET: RANDOMIZER RUN", Color.new(30, 48, 70), BLUE2, false); end
def persave_rows(c, x, y, w)
  b = BASE.bitmap; t = TOP.bitmap
  yy = y
  PERSAVE.each do |sec, rows|
    P.heading(t, x + 8, x + w - 8, yy, sec, c[:head], c[:line]); yy += 18
    rows.each_with_index do |(l, v), k|
      cursor_at(x + 4, yy, w - 8, 22) if sec == "Kanto Reloaded" && k == 0
      P.text(t, x + 16, yy, 180, 22, l, c[:opt], PF::TEXT)
      value_cell(t, c, x + w - 56, yy - 1, v, false)
      yy += 24
    end
  end
end

c = palette(2)
ROWS[8][3] = c[:dim]

#================================================================ RS1 Recommended: rows beside Oak with the details panel (the chosen layout)
def rs1(c, sel)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 196, 8, 504, 350, 8, col(c[:panel], 245), c[:line])
  P.text(t, 196, 12, 308, 24, "Run Setup", c[:title], PF::ROW, 2)
  preset_tag(t, 204, 38)
  rows_panel(c, 196, 58, 308, sel, 24)
  b.fill_rect(206, 278, 288, 1, c[:line])
  _, _, d, colr = ROWS[sel]
  P.small_wrap(t, d, 280).first(3).each_with_index { |ln, k| P.small(t, 210, 284 + k * 17, 284, 16, ln, k == 0 ? colr : c[:txt]) }
  hints(c, [[:ud, "Choose"], [:lr, "Change"], [A_BTN, "Open"], [Y_BTN, "Next"], [B_BTN, "Back"]])
end
rs1(c, 0); shot("RS1_setup")
intro(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 196, 8, 504, 350, 8, col(c[:panel], 245), c[:line])
P.text(t, 196, 12, 308, 24, "Per-Save Settings", c[:title], PF::ROW, 2)
P.small(t, 196, 36, 308, 16, "Set now; KIF won't reset them.", c[:dim], 2)
persave_rows(c, 196, 58, 308)
b.fill_rect(206, 278, 288, 1, c[:line])
P.small(t, 210, 284, 284, 16, "Quick Throw", BLUE2)
P.small(t, 210, 301, 284, 16, "Throws your best ball in one press.", c[:txt])
hints(c, [[:ud, "Choose"], [:lr, "Change"], ["p:9", ""], ["p:10", "Sections"], [B_BTN, "Back"]])
shot("RS1_persave")

#================================================================ RS2: the improved KIF Settings layout with a New Game section first
NG_SECTIONS = [["New Game", [240, 200, 70]]] + SECTIONS
def rs2(c, persave)
  frame(c); clear_over
  MAPS.bitmap = Bitmap.new(W, H)
  settings_frame(c, NG_SECTIONS, persave ? 1 : 0)
  b = BASE.bitmap; t = TOP.bitmap
  t.fill_rect(130, 2, 252, 28, CLEAR); P.text(t, 130, 2, 252, 28, "New Game", c[:title], PF::TITLE, 2)
  if persave
    persave_rows(c, 180, 40, W - 186)
    P.text(t, 14, 269, 330, 26, "Quick Throw", c[:head], PF::ROW)
    P.small(t, 14, 297, 480, 16, "Every section's per-save options can be set before you start.", c[:txt])
  else
    ROWS.first(8).each_with_index do |(l, v, _, _), i|
      y = 40 + i * 26
      cursor_at(184, y, W - 194, 24) if i == 0
      P.text(t, 196, y, 200, 24, l, c[:opt], PF::ROW)
      v == "Set Up" ? P.pill(t, W - 18, y + 5, "SET UP", Color.new(70, 46, 14), AMBER) : value_cell(t, c, W - 60, y, v, i == 0)
    end
    P.text(t, 14, 269, 330, 26, "Difficulty", c[:head], PF::ROW)
    P.small_wrap(t, ROWS[0][2], W - 30).first(2).each_with_index { |ln, k| P.small(t, 14, 297 + k * 17, W - 30, 16, ln, c[:txt]) }
  end
  hints(c, [[:ud, "Select"], [:lr, "Change"], [Y_BTN, "Start"], [B_BTN, "Sections"]])
end
rs2(c, false); shot("RS2_setup")
rs2(c, true); shot("RS2_persave")

#================================================================ RS3: one question per page with progress dots
def rs3(c, step)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 216, 30, 500, 320, 10, col(c[:panel], 250), c[:line])
  8.times { |k| UI.rbox(b, 300 + k * 16, 40, 308 + k * 16, 48, 4, k == step ? GOLD : (k < step ? c[:selb] : c[:dark])) }
  l, v, d, colr = ROWS[step]
  P.text(t, 216, 56, 284, 24, l, c[:title], PF::ROW, 2)
  opts = step == 0 ? ["Easy", "Normal", "Hard"] : ["Classic", "Expanded"]
  opts.each_with_index do |o, i|
    y = 92 + i * 34
    cursor_at(232, y, 252, 32) if o == v
    P.text(t, 248, y + 4, 200, 24, o, c[:txt], PF::ROW)
  end
  P.small_wrap(t, d, 252).first(3).each_with_index { |ln, k| P.small(t, 232, 210 + k * 17, 252, 16, ln, k == 0 ? colr : c[:txt]) }
  P.small(t, 216, 290, 284, 16, "Step #{step + 1} of 8", c[:dim], 2)
  hints(c, [[:ud, "Choose"], [A_BTN, "Next"], [B_BTN, "Back"]])
end
rs3(c, 0); shot("RS3_difficulty")
rs3(c, 1); shot("RS3_dex")

#================================================================ RS4: tiles (each choice a tile with its value)
def rs4(c)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, H, Color.new(10, 14, 24, 150))
  P.text(t, 0, 4, W, 24, "Run Setup", c[:title], PF::ROW, 2)
  preset_tag(t, 10, 8)
  ROWS.each_with_index do |(l, v, _, colr), i|
    x = 10 + (i % 3) * 166; y = 34 + (i / 3) * 96
    UI.rbox(b, x, y, x + 160, y + 90, 8, c[:panel], i == 1 ? c[:selb] : c[:line])
    cursor_at(x - 2, y - 2, 164, 94) if i == 1
    P.small(t, x + 10, y + 8, 140, 16, i == 8 ? "Per-Save Settings" : l, c[:dim])
    P.text(t, x + 10, y + 30, 140, 26, v.empty? ? "Open" : v, i == 8 ? c[:txt] : colr, PF::ROW)
  end
  hints(c, [[:ud, ""], [:lr, "Choose"], [A_BTN, "Change"], [Y_BTN, "Next"], [B_BTN, "Back"]])
end
rs4(c); shot("RS4_setup")
rs4(c)
d = DIMMER.bitmap; o = OVER.bitmap
UI.rbox(d, 176, 70, 336, 160, 6, col(c[:panel2], 255), c[:selb])
[["Classic", "576"], ["Expanded", "1,098"]].each_with_index do |(n, cnt), i|
  y = 76 + i * 40
  UI.rbox(d, 180, y, 332, y + 36, 5, c[:sel]) if i == 1
  P.text(o, 190, y + 6, 100, 24, n, c[:txt], PF::ROW); P.small(o, 270, y + 10, 56, 16, cnt, c[:dim], 1)
end
shot("RS4_dropdown")

#================================================================ RS5: choices on the left, a live Run Card on the right
def run_card_mini(c, x, y, w)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + 270, 10, col(c[:panel2], 250), GOLD)
  P.text(t, x, y + 6, w, 22, "Your Run", GOLD, PF::ROW, 2)
  [["RANDOMIZED", Color.new(240, 170, 60)], ["HARD", AMBER], ["EXPANDED", BLUE2]].each_with_index { |(s, colr), k| pill_tag(t, x + 12 + k * 74, y + 36, s, colr, false) }
  [["IVs", "20-31"], ["Starters", "Johto"], ["Money", "$3,000"], ["Seed", "7F3A91C2"]].each_with_index do |(l, v), k|
    yy = y + 64 + k * 22
    P.small(t, x + 12, yy, 70, 16, l, c[:dim]); P.small(t, x + 80, yy, w - 92, 16, v, c[:txt], 1)
  end
  b.fill_rect(x + 10, y + 158, w - 20, 1, c[:line])
  P.small(t, x, y + 166, w, 16, "Share Code", c[:dim], 2)
  P.text(t, x, y + 184, w, 22, CODE, c[:white], PF::TEXT, 2)
end
def rs5(c, sel)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, H, Color.new(10, 14, 24, 120))
  UI.rbox(b, 8, 8, 272, 350, 8, col(c[:panel], 250), c[:line])
  P.text(t, 8, 12, 264, 24, "Run Setup", c[:title], PF::ROW, 2)
  rows_panel(c, 8, 40, 264, sel, 26)
  run_card_mini(c, 282, 40, 222)
  hints(c, [[:ud, "Choose"], [:lr, "Change"], [A_BTN, "Open"], [Y_BTN, "Next"], [B_BTN, "Back"]])
end
rs5(c, 0); shot("RS5_setup")
rs5(c, 8); shot("RS5_persave")
