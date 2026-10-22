# encoding: utf-8
# Mockups: Difficulty (topic 20), five designs, each two screens:
#  - New Game (Oak's intro): picking the difficulty with the What Changes
#    panel (new: Pick at New Game, What Changes Panel, Hard Rewards);
#  - Options: changing it. His rule (with KR on): you can raise or lower it,
#    but wherever difficulty shows (Trainer Card, load screen, Hall of Fame,
#    Run Tags) it shows the LOWEST this save has used: Debug < Easy < Normal < Hard.
# PIF's three levels: Easy (party EXP, no field poison, easier movesets),
# Normal, Hard (trainers x1.1 levels, smartest AI, harder movesets, no switch
# preview); trainer IVs from IV Boundaries (Hard 10-31).
# Design 1 = PIF's choice with HR's warning confirm, in our UI kit.
# Usage (from this folder): ruby diff_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "qa_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "qa_designs.rb")

X_BTN = "p:2"; Y_BTN = "p:3"
AMBER = Color.new(240, 170, 60); RED = Color.new(240, 100, 90)
LEVELS = [["Easy", GREEN, ["Whole party shares EXP", "No poison while walking", "Trainers use easier moves"]],
          ["Normal", Color.new(130, 190, 250), ["The game as designed", "Trainer IVs 0-31"]],
          ["Hard", AMBER, ["Trainer levels x1.1", "Smartest trainer AI", "Trainers use harder moves", "Hides their next Pokémon", "Trainer IVs 10-31", "Earns Hard Rewards"]]]
SELD = 2
OVER = layer(3)
DIMMER = layer(2)
DIMMER.z = 3; OVER.z = 4
def clear_over; OVER.bitmap.clear; DIMMER.bitmap.clear; end
def backdrop(name); MAPS.bitmap = Bitmap.new(File.join(HERE, "fx", name)); end
def intro(c); frame(c, false); clear_over; backdrop("intro.png"); end
def bullet(b, t, c, x, y, w, s, color = nil)
  UI.rbox(b, x, y + 7, x + 5, y + 12, 2, color || c[:selb])
  P.small(t, x + 10, y + 1, w - 10, 16, s, c[:txt])
end
def rewards_pill(t, x, y, right = true); P.pill(t, x, y, "REWARDS", Color.new(80, 60, 10), GOLD, right); end
def confirm(c, title, lines, yes, no)
  DIMMER.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 130))
  b = DIMMER.bitmap; t = OVER.bitmap
  UI.rbox(b, 86, 110, 426, 262, 8, col(c[:panel], 250), AMBER)
  P.text(t, 86, 116, 340, 24, title, AMBER, PF::ROW, 2)
  lines.each_with_index { |l, i| P.small(t, 100, 146 + i * 18, 312, 16, l, c[:txt], 2) }
  [[yes, 120], [no, 270]].each_with_index do |(lbl, x), i|
    UI.rbox(b, x, 222, x + 122, 248, 6, i == 0 ? c[:sel] : c[:dark], i == 0 ? c[:selb] : c[:line])
    P.text(t, x, 224, 122, 22, lbl, i == 0 ? c[:white] : c[:txt], PF::TEXT, 2)
  end
end
def options_page(c, current)
  frame(c)
  clear_over
  MAPS.bitmap = Bitmap.new(W, H)
  settings_frame(c, SECTIONS, 2)
  b = BASE.bitmap; t = TOP.bitmap
  P.heading(t, 190, W - 16, 43, "Difficulty", c[:head], c[:line])
  cursor_at(184, 58, W - 194, 24)
  P.text(t, 196, 58, 200, 24, "Difficulty", c[:opt], PF::ROW)
  P.text(t, 196, 82, 200, 24, "Shown As", c[:dim], PF::ROW)
  P.text(t, W - 210, 82, 100, 24, $shown, c[:txt], PF::TEXT, 1)
  P.pill(t, W - 18, 87, "LOWEST USED", Color.new(40, 48, 62), c[:dim], true)
  [["Battle Style", "Shift"], ["Battle Effects", "On"], ["Exp. Share", "Party"]].each_with_index do |(l, v), i|
    P.text(t, 196, 132 + i * 24, 200, 24, l, c[:opt], PF::ROW)
    value_cell(t, c, W - 60, 132 + i * 24, v, false)
  end
  P.heading(t, 190, W - 16, 117, "Battles", c[:head], c[:line])
  b.fill_rect(W - 11, 44, 2, 212, c[:line]); b.fill_rect(W - 11, 44, 2, 60, c[:dim])
end
def shot(name); dump_as(name); end

c = palette(2)
$shown = "Normal"

#================================================================ DF1 Recommended: three rows and the What Changes panel; a warning confirm to lower
intro(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 252, 24, 500, 326, 8, col(c[:panel], 245), c[:line])
P.text(t, 252, 30, 248, 24, "Choose a Difficulty", c[:title], PF::ROW, 2)
LEVELS.each_with_index do |(n, colr, _), i|
  y = 62 + i * 30
  cursor_at(258, y, 236, 28) if i == SELD
  UI.rbox(b, 268, y + 9, 278, y + 19, 5, colr)
  P.text(t, 286, y + 2, 150, 24, n, c[:txt], PF::ROW)
  rewards_pill(t, 486, y + 7) if n == "Hard"
end
b.fill_rect(262, 156, 228, 1, c[:line])
P.text(t, 266, 162, 200, 12, "WHAT CHANGES", c[:head], PF::TINY)
LEVELS[SELD][2].each_with_index { |s, i| bullet(b, t, c, 268, 178 + i * 18, 224, s, AMBER) }
P.small(t, 262, 290, 232, 16, "Your card shows the lowest used.", c[:dim], 2)
hints(c, [[:ud, "Choose"], [A_BTN, "Start"], [B_BTN, "Back"]])
shot("DF1_new")
options_page(c, "Hard")
value_cell(TOP.bitmap, c, W - 60, 58, "Normal", true)
confirm(c, "Lower to Normal?", ["You can raise it again later, but your", "Trainer Card will show Normal from now on:", "it always shows the lowest you've used."], "Lower", "Keep Hard")
hints(c, [[:lr, "Choose"], [A_BTN, "OK"], [B_BTN, "Cancel"]])
shot("DF1_opt")

#================================================================ DF2 Cards: three tall cards with their changes; higher levels locked in Options
intro(c)
b = BASE.bitmap; t = TOP.bitmap
P.text(t, 0, 8, W, 24, "How tough a journey?", Color.new(30, 50, 60), PF::ROW, 2)
LEVELS.each_with_index do |(n, colr, ch), i|
  x = 12 + i * 166; sel = i == SELD
  UI.rbox(b, x, 36, x + 160, 330, 10, col(c[:panel], 240), sel ? GOLD : c[:line])
  UI.rbox(b, x + 8, 44, x + 152, 68, 6, colr)
  P.text(t, x, 45, 160, 22, n, Color.new(20, 24, 32), PF::ROW, 2)
  yy = 78
  ch.each do |s2|
    lines = P.small_wrap(t, s2, 132)
    UI.rbox(b, x + 10, yy + 7, x + 15, yy + 12, 2, colr)
    lines.each_with_index { |ln, k| P.small(t, x + 20, yy + 1 + k * 15, 134, 16, ln, c[:txt]) }
    yy += lines.length * 15 + 8
  end
  rewards_pill(t, x + 80, 300, false) if n == "Hard"
end
hints(c, [[:lr, "Choose"], [A_BTN, "Start"], [B_BTN, "Back"]])
shot("DF2_new")
$shown = "Easy"
options_page(c, "Normal")
$shown = "Normal"
b = BASE.bitmap; t = TOP.bitmap
value_cell(t, c, W - 60, 58, "Normal", true)
d = DIMMER.bitmap; o = OVER.bitmap
UI.rbox(d, W - 150, 82, W - 14, 158, 6, col(c[:panel2], 255), c[:selb])
[["Easy", true], ["Normal", true], ["Hard", true]].each_with_index do |(n, ok), i|
  y = 86 + i * 24
  UI.rbox(d, W - 146, y, W - 18, y + 22, 4, c[:sel]) if n == "Normal"
  P.text(o, W - 138, y, 80, 22, n, ok ? c[:txt] : c[:dim], PF::TEXT)
end
P.text(t, 14, 269, 200, 26, "Difficulty", c[:head], PF::ROW)
P.small(t, 14, 294, 480, 16, "Pick any. This save once used Easy, so it shows as Easy.", c[:txt])
hints(c, [[:ud, "Choose"], [A_BTN, "Set"], [B_BTN, "Close"]])
shot("DF2_opt")

#================================================================ DF3 Slider: Easy to Hard on one line, the changes below; Options arrow only points down
intro(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 236, 40, 500, 320, 8, col(c[:panel], 245), c[:line])
P.text(t, 236, 46, 264, 24, "Difficulty", c[:title], PF::ROW, 2)
b.fill_rect(266, 92, 204, 4, c[:dark])
LEVELS.each_with_index do |(n, colr, _), i|
  x = 266 + i * 102
  UI.rbox(b, x - 8, 86, x + 8, 102, 8, i == SELD ? colr : c[:dark], i == SELD ? c[:white] : c[:line])
  P.text(t, x - 40, 106, 80, 20, n, i == SELD ? colr : c[:dim], PF::TEXT, 2)
end
b.fill_rect(266, 92, 204, 4, col(AMBER, 120))
P.text(t, 248, 136, 240, 12, "HARD CHANGES", c[:head], PF::TINY)
LEVELS[SELD][2].each_with_index { |s, i| bullet(b, t, c, 252, 152 + i * 18, 240, s, AMBER) }
P.small(t, 240, 266, 256, 16, "Your card shows the lowest you use.", c[:dim], 2)
rewards_pill(t, 368, 288, false)
hints(c, [[:lr, "Choose"], [A_BTN, "Start"], [B_BTN, "Back"]])
shot("DF3_new")
$shown = "Hard"
options_page(c, "Hard")
$shown = "Normal"
b = BASE.bitmap; t = TOP.bitmap
P.text(t, W - 92, 58, 60, 24, "Hard", AMBER, PF::TEXT, 2)
UI.tri(t, W - 104, 66, :l, c[:txt], 4)
UI.tri(t, W - 30, 66, :r, c[:txt], 4)
P.text(t, 14, 269, 200, 26, "Difficulty", c[:head], PF::ROW)
P.small(t, 14, 294, 480, 16, "Raise or lower it any time. Your card shows the lowest used.", c[:txt])
hints(c, [[:ud, "Select"], [:lr, "Change"], [B_BTN, "Sections"]])
shot("DF3_opt")

#================================================================ DF4 Table: every rule by difficulty; lowering lists what you give up
intro(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 196, 24, 504, 326, 8, col(c[:panel], 245), c[:line])
P.text(t, 196, 30, 308, 24, "Choose a Difficulty", c[:title], PF::ROW, 2)
cols = [["Easy", 336], ["Normal", 400], ["Hard", 464]]
cols.each_with_index do |(n, x), i|
  UI.rbox(b, x - 30, 58, x + 30, 300, 6, Color.new((c[:panel].red * 3 + AMBER.red) / 4, (c[:panel].green * 3 + AMBER.green) / 4, (c[:panel].blue * 3 + AMBER.blue) / 4)) if i == SELD
  P.text(t, x - 30, 60, 60, 16, n.upcase, LEVELS[i][1], PF::TINY, 2)
end
rules = [["Trainer Levels", "-", "-", "x1.1"], ["Trainer AI", "Basic", "Normal", "Smartest"], ["Movesets", "Easier", "-", "Harder"], ["Switch Preview", "Yes", "Yes", "No"],
         ["Party EXP", "Yes", "-", "-"], ["Field Poison", "Off", "On", "On"], ["Trainer IVs", "0-31", "0-31", "10-31"], ["Rewards", "-", "-", "Yes"]]
rules.each_with_index do |(r, *v), i|
  y = 78 + i * 27
  P.small(t, 206, y + 3, 100, 16, r, c[:opt])
  v.each_with_index { |s2, k| P.small(t, cols[k][1] - 30, y + 3, 60, 16, s2, s2 == "-" ? c[:dim] : c[:txt], 2) }
end
hints(c, [[:lr, "Choose"], [A_BTN, "Start"], [B_BTN, "Back"]])
shot("DF4_new")
options_page(c, "Hard")
value_cell(TOP.bitmap, c, W - 60, 58, "Normal", true)
confirm(c, "Lower to Normal?", ["Your record becomes Normal for good, even if", "you raise it again: no more Hard Rewards and", "your card shows Normal."], "Lower", "Keep Hard")
hints(c, [[:lr, "Choose"], [A_BTN, "OK"], [B_BTN, "Cancel"]])
shot("DF4_opt")

#================================================================ DF5 Oak Asks: in Oak's own words, with the changes beside the choices
intro(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 10, 300, W - 10, 376, 8, col(c[:panel], 245), c[:line])
P.text(t, 24, 308, W - 48, 24, "How tough a journey are you after?", c[:txt], PF::ROW)
P.small(t, 24, 336, W - 48, 16, "You can change it later; your Trainer Card keeps the lowest.", c[:dim])
UI.rbox(b, 284, 30, 504, 290, 8, col(c[:panel], 245), c[:line])
LEVELS.each_with_index do |(n, colr, _), i|
  y = 38 + i * 28
  cursor_at(306, y, 188, 26) if i == SELD
  UI.rbox(b, 316, y + 8, 326, y + 18, 5, colr)
  P.text(t, 334, y + 1, 120, 24, n, c[:txt], PF::ROW)
  rewards_pill(t, 488, y + 6) if n == "Hard"
end
b.fill_rect(294, 126, 200, 1, c[:line])
LEVELS[SELD][2].each_with_index { |s2, i| bullet(b, t, c, 296, 132 + i * 24, 204, s2, AMBER) }
shot("DF5_new")
$shown = "Easy"
options_page(c, "Hard")
$shown = "Normal"
value_cell(TOP.bitmap, c, W - 60, 58, "Hard", true)
P.text(TOP.bitmap, 14, 269, 200, 26, "Difficulty", c[:head], PF::ROW)
P.small(TOP.bitmap, 14, 294, 480, 16, "Change it any time. Debug counts lowest, under Easy.", c[:txt])
hints(c, [[:ud, "Select"], [:lr, "Change"], [B_BTN, "Sections"]])
shot("DF5_opt")

#================================================================ DF chosen: design 1's New Game, design 2's dropdown in Settings
$shown = "Hard"
options_page(c, "Hard")
$shown = "Normal"
b = BASE.bitmap; t = TOP.bitmap
value_cell(t, c, W - 60, 58, "Hard", true)
d = DIMMER.bitmap; o = OVER.bitmap
UI.rbox(d, W - 150, 82, W - 14, 158, 6, col(c[:panel2], 255), c[:selb])
[["Easy", GREEN], ["Normal", Color.new(130, 190, 250)], ["Hard", AMBER]].each_with_index do |(n, colr), i|
  y = 86 + i * 24
  UI.rbox(d, W - 146, y, W - 18, y + 22, 4, c[:sel]) if n == "Normal"
  UI.rbox(d, W - 140, y + 7, W - 132, y + 15, 4, colr)
  P.text(o, W - 126, y, 80, 22, n, c[:txt], PF::TEXT)
  P.pill(o, W - 22, y + 4, "NOW", Color.new(80, 60, 10), GOLD, true) if n == "Hard"
end
P.text(t, 14, 269, 200, 26, "Difficulty", c[:head], PF::ROW)
P.small(t, 14, 294, 480, 16, "Pick any level. Lowering asks first: your card keeps", c[:txt])
P.small(t, 14, 310, 480, 16, "the lowest difficulty this save has used (Hard so far).", c[:txt])
hints(c, [[:ud, "Choose"], [A_BTN, "Set"], [B_BTN, "Close"]])
shot("DFX_opt")
