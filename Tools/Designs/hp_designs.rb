# encoding: utf-8
# Mockups: Hidden Power (topic 21). HR's stored random type comes over (rolled
# once when the Pokemon is made, never tied to IVs). Agreed new features:
#  - Real Type Everywhere: EBDX's fight button, Move Effectiveness, the
#    summary and move-learn screens show the real type (PIF shows Normal);
#  - Type Changer: a way to change the type later (five designs below).
# Each design is two screens (the changer, then its result). Example: Pikachu
# Lv. 34, Hidden Power Rock, changed to Ice. Backdrops: hp/lab.png (Map354,
# the Ruins of Alph lab where PIF's researcher tells you the type) and
# hp/chamber.png (Map677, a Hidden Chamber, PIF's type rooms and plates).
# Design 1 = HR's random type + PIF's researcher, who now rerolls it.
# Usage (from this folder): ruby hp_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "qa_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "qa_designs.rb")

X_BTN = "p:2"; Y_BTN = "p:3"
RED = Color.new(240, 100, 90); WHITE = Color.new(248, 248, 248); INKD = Color.new(28, 28, 36)
CLEAR = Color.new(0, 0, 0, 0)
MONEY = Color.new(120, 230, 150)
OVER = layer(3); DIMMER = layer(2)
DIMMER.z = 3; OVER.z = 4
# id_number order (types.png / typesSmall.png rows); Hidden Power's 17 (no Normal, no ???)
TYPES = { 1 => "Fighting", 2 => "Flying", 3 => "Poison", 4 => "Ground", 5 => "Rock", 6 => "Bug", 7 => "Ghost",
          8 => "Steel", 10 => "Fire", 11 => "Water", 12 => "Grass", 13 => "Electric", 14 => "Psychic", 15 => "Ice",
          16 => "Dragon", 17 => "Dark", 18 => "Fairy" }
HP_IDS = TYPES.keys
TCOL = { 5 => Color.new(200, 176, 80), 15 => Color.new(140, 220, 230) }
ROCK = 5; ICE = 15
STRONG = { 15 => [12, 4, 2, 16], 5 => [10, 15, 2, 6] }
RESIST = { 15 => [10, 11, 15, 8], 5 => [1, 4, 8] }

def clear_over; OVER.bitmap.clear; DIMMER.bitmap.clear; end
def backdrop(name); MAPS.bitmap = Bitmap.new(File.join(HERE, "hp", name)); end
def scene(c, name, dim = 0)
  frame(c, false); clear_over; backdrop(name)
  BASE.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, dim)) if dim > 0
end
def mon(b, sp, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(File.join(GFX, "Pokemon/Icons/#{sp}.png")), Rect.new(0, 0, 64, 64))
end
def type_badge(b, id, x, y, w = 64, h = 28)
  b.stretch_blt(Rect.new(x, y, w, h), bmp(File.join(GFX, "Pictures/types.png")), Rect.new(0, id * 28, 64, 28))
end
def type_icon(b, id, x, y, size = 16)
  b.stretch_blt(Rect.new(x, y, size, size), bmp(File.join(GFX, "Pictures/Battle/typesSmall.png")), Rect.new(0, id * 19, 19, 19))
end
def ring(b, x, y, w, h, r, color, th)
  tmp = Bitmap.new(w + 1, h + 1)
  UI.rbox(tmp, 0, 0, w, h, r, color)
  UI.rbox(tmp, th, th, w - th, h - th, [r - th, 1].max, CLEAR)
  b.blt(x, y, tmp, Rect.new(0, 0, w + 1, h + 1))
end
def sparkle(b, cx, cy, r, color)
  b.fill_rect(cx - r, cy, 2 * r + 1, 1, color); b.fill_rect(cx, cy - r, 1, 2 * r + 1, color)
  b.fill_rect(cx - r / 2, cy - 1, r + 1, 3, color); b.fill_rect(cx - 1, cy - r / 2, 3, r + 1, color)
end
def sparkles(b, x, y, w, h)
  [[0.0, 0.1, 5], [0.3, -0.25, 4], [0.62, -0.2, 6], [0.98, 0.15, 5], [1.02, 0.85, 4], [0.15, 1.15, 4], [0.75, 1.2, 5]].each do |fx, fy, r|
    sparkle(b, (x + w * fx).round, (y + h * fy).round, r, Color.new(190, 240, 255))
    sparkle(b, (x + w * fx).round, (y + h * fy).round, r / 2, WHITE)
  end
end
def money(c, amount)
  b = BASE.bitmap; t = TOP.bitmap
  w = P.width(PF::TEXT, amount) + 24
  UI.rbox(b, W - 8 - w, 8, W - 8, 32, 6, col(c[:panel], 255), c[:line])
  P.text(t, W - 8 - w, 9, w, 22, amount, MONEY, PF::TEXT, 2)
end
# A button: [label, price or nil], selected or not
def button(c, b, t, x, y, w, label, price, sel)
  UI.rbox(b, x, y, x + w, y + 26, 6, sel ? c[:sel] : c[:dark], sel ? c[:selb] : c[:line])
  if price
    lw = P.width(PF::TEXT, label); pw = P.width(PF::TEXT, price)
    x0 = x + (w - lw - pw - 10) / 2
    P.text(t, x0, y + 2, lw + 2, 22, label, sel ? c[:white] : c[:txt], PF::TEXT)
    P.text(t, x0 + lw + 10, y + 2, pw + 2, 22, price, MONEY, PF::TEXT)
  else
    P.text(t, x, y + 2, w, 22, label, sel ? c[:white] : c[:txt], PF::TEXT, 2)
  end
end
def arrow(b, x, y, color); b.fill_rect(x, y + 4, 12, 3, color); UI.tri(b, x + 12, y, :r, color, 5); end
# ROCK -> ICE, centred on cx
def change_badges(b, t, cx, y, from, to, glow = true)
  type_badge(t, from, cx - 82, y); arrow(b, cx - 9, y + 9, WHITE); type_badge(t, to, cx + 18, y)
  sparkles(t, cx + 18, y, 64, 28) if glow
end
def mon_row(c, t, x, y, level = true)
  mon(t, "PIKACHU", x + 20, y + 16, 44)
  P.text(t, x + 46, y - 2, 140, 24, "Pikachu", c[:txt], PF::ROW)
  P.small(t, x + 46, y + 20, 140, 16, "Lv. 34", c[:dim]) if level
end
def card(c, x, y, w, h, title)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + h, 8, col(c[:panel], 255), c[:line])
  P.text(t, x, y + 6, w, 24, title, c[:title], PF::ROW, 2)
  b.fill_rect(x + 10, y + 34, w - 20, 1, c[:line])
end
def dialog(c, x, y, w, h, title)
  DIMMER.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 130))
  UI.rbox(DIMMER.bitmap, x, y, x + w, y + h, 8, col(c[:panel], 250), c[:selb])
  P.text(OVER.bitmap, x, y + 6, w, 24, title, c[:title], PF::ROW, 2)
end
def message(c, lines, b = BASE.bitmap, t = TOP.bitmap)
  UI.rbox(b, 8, 290, W - 8, 352, 8, col(c[:panel], 255), c[:line])
  lines.each_with_index { |l, i| P.text(t, 22, 296 + i * 26, W - 44, 24, l, c[:txt], PF::ROW) }
end
def shot(name); dump_as(name); end

c = palette(2)

#================================================================ HPFIX: Real Type Everywhere (every design)
# KIF Beta now: EBDX draws Hidden Power from the move's data: a Normal button.
frame(c, false); clear_over
MAPS.bitmap = Bitmap.new(File.join(HERE, "hp", "e_kif.png"))
shot("HPFIX_kif")
# Kanto Reloaded: the real type (Rock), and Move Effectiveness (KR's Border) uses it: x2 on Gyarados.
frame(c, false); clear_over
MAPS.bitmap = Bitmap.new(File.join(HERE, "hp", "e_kr.png"))
b = BASE.bitmap
LV = { :quad => Color.new(64, 220, 96), :super => Color.new(240, 224, 88), :neutral => Color.new(64, 216, 232),
       :resisted => Color.new(248, 160, 64) }
{ 1 => [[257, 294, 196, 42], :quad], 2 => [[59, 338, 196, 42], :resisted], 3 => [[257, 338, 196, 42], :neutral] }.each do |_, ((x, y, w, h), lv)|
  ring(b, x - 2, y - 2, w + 4, h + 4, 6, LV[lv], 2)
end
ring(b, 58, 272, 198, 74, 6, LV[:super], 4)
pw = P.width(PF::TINY, "x2") + 12
P.pill(b, 181 - pw / 2, 324, "x2", INKD, LV[:super], false)
shot("HPFIX_kr")

#================================================================ HP1 Recommended: the researcher rerolls it (HR's random type)
def hp1_card(c, result)
  b = BASE.bitmap; t = TOP.bitmap
  x = 86; y = 190; w = 340
  card(c, x, y, w, 162, "Hidden Power")
  mon_row(c, t, x + 14, y + 44)
  if result
    change_badges(b, t, x + w - 96, y + 46, ROCK, ICE)
    P.small(t, x, y + 90, w, 16, "Pikachu's Hidden Power is now Ice type!", c[:txt], 2)
  else
    type_badge(t, ROCK, x + w - 80, y + 46)
    P.small(t, x, y + 90, w, 16, "A reroll gives it a random new type.", c[:dim], 2)
  end
  b.fill_rect(x + 10, y + 114, w - 20, 1, c[:line])
  button(c, b, t, x + 16, y + 124, 196, result ? "Again" : "Reroll", "$5,000", !result)
  button(c, b, t, x + 222, y + 124, 102, result ? "Done" : "Keep", nil, result)
end
scene(c, "lab.png")
money(c, "$41,200")
hp1_card(c, false)
hints(c, [[:lr, "Choose"], [A_BTN, "OK"], [B_BTN, "Back"]])
shot("HP1_pick")
scene(c, "lab.png")
money(c, "$36,200")
hp1_card(c, true)
hints(c, [[:lr, "Choose"], [A_BTN, "OK"], [B_BTN, "Back"]])
shot("HP1_result")

#================================================================ HP2: pick any type from a grid (costs more)
def hp2_grid(c)
  b = BASE.bitmap; t = TOP.bitmap
  card(c, 20, 16, 472, 336, "Choose a Type")
  mon_row(c, t, 34, 54)
  P.small(t, 300, 62, 112, 16, "Now", c[:dim], 1)
  type_badge(t, ROCK, 416, 56)
  b.fill_rect(30, 94, 452, 1, c[:line])
  x0 = 256 - (6 * 64 + 5 * 10) / 2
  HP_IDS.each_with_index do |id, i|
    bx = x0 + (i % 6) * 74 + (i >= 12 ? 37 : 0); by = 104 + (i / 6) * 36
    type_badge(t, id, bx, by)
    ring(b, bx - 3, by - 3, 70, 34, 6, GOLD, 2) if id == ROCK
    cursor_at(bx - 4, by - 4, 72, 36) if id == ICE
  end
  b.fill_rect(30, 216, 452, 1, c[:line])
  P.text(t, 40, 222, 200, 24, "Ice", TCOL[ICE], PF::ROW)
  [["Strong Against", STRONG[ICE], c[:txt]], ["Resisted By", RESIST[ICE], c[:dim]]].each_with_index do |(label, ids, colr), r|
    y = 252 + r * 26
    P.small(t, 40, y, 120, 16, label, c[:dim])
    ids.each_with_index do |id, k|
      type_icon(t, id, 150 + k * 82, y, 16)
      P.small(t, 170 + k * 82, y, 64, 16, TYPES[id], colr)
    end
  end
  ring(b, 40, 309, 22, 16, 4, GOLD, 2)
  P.small(t, 68, 309, 60, 16, "Now", c[:dim])
  P.text(t, 260, 304, 216, 24, "$20,000", MONEY, PF::TEXT, 1)
end
scene(c, "lab.png", 130)
hp2_grid(c)
hints(c, [[:lr, "Choose"], [A_BTN, "Change"], [B_BTN, "Back"]])
shot("HP2_grid")
scene(c, "lab.png", 130)
hp2_grid(c)
hints(c, [[:lr, "Choose"], [A_BTN, "OK"], [B_BTN, "Back"]])
dialog(c, 96, 104, 320, 168, "Change to Ice?")
t = OVER.bitmap; b = DIMMER.bitmap
change_badges(b, t, 256, 142, ROCK, ICE, false)
P.small(t, 96, 180, 320, 16, "Pikachu's Hidden Power becomes Ice type.", c[:txt], 2)
P.small(t, 96, 198, 320, 16, "This costs $20,000.", c[:dim], 2)
button(c, b, t, 124, 228, 124, "Change", nil, true)
button(c, b, t, 264, 228, 124, "Cancel", nil, false)
shot("HP2_confirm")

#================================================================ HP3: Plates (Map677's chambers hold them); use one, not used up
PLATES = [["ICICLEPLATE", "Icicle Plate", 15], ["STONEPLATE", "Stone Plate", 5], ["FLAMEPLATE", "Flame Plate", 10],
          ["SPLASHPLATE", "Splash Plate", 11], ["ZAPPLATE", "Zap Plate", 13], ["MEADOWPLATE", "Meadow Plate", 12],
          ["MINDPLATE", "Mind Plate", 14], ["DRACOPLATE", "Draco Plate", 16], ["DREADPLATE", "Dread Plate", 17]]
PARTY = [["PIKACHU", "Pikachu", ROCK, true], ["LAPRAS", "Lapras", 10, true], ["GENGAR", "Gengar", 2, false]]
scene(c, "chamber.png", 110)
b = BASE.bitmap; t = TOP.bitmap
card(c, 12, 12, 236, 340, "Plates")
PLATES.each_with_index do |(icon, name, id), i|
  y = 54 + i * 32
  ring(b, 20, y - 2, 220, 30, 6, c[:selb], 2) if i == 0
  item_icon(t, icon, 38, y + 13, 24)
  P.text(t, 58, y + 2, 140, 24, name, c[:txt], PF::TEXT)
  type_icon(t, id, 216, y + 5, 16)
end
b.fill_rect(243, 50, 2, 292, c[:line]); b.fill_rect(243, 50, 2, 150, c[:dim])
card(c, 256, 12, 244, 218, "Use On")
PARTY.each_with_index do |(sp, name, id, knows), i|
  y = 50 + i * 44
  cursor_at(262, y, 232, 40) if i == 0
  mon(t, sp, 284, y + 20, 40)
  P.text(t, 308, y, 120, 24, name, c[:txt], PF::TEXT)
  P.small(t, 308, y + 20, 140, 16, knows ? "Knows Hidden Power" : "Doesn't Know It", knows ? c[:dim] : c[:dim])
  type_icon(t, id, 470, y + 12, 16)
end
UI.rbox(b, 256, 238, 500, 352, 8, col(c[:panel], 255), c[:line])
item_icon(t, "ICICLEPLATE", 278, 262, 24)
P.text(t, 298, 248, 190, 24, "Icicle Plate", c[:title], PF::ROW)
["Sets Hidden Power to Ice type.", "Not used up. Use it again later.", "Found in the Hidden Chambers."].each_with_index do |l, i|
  P.small(t, 270, 280 + i * 20, 224, 16, l, i == 1 ? MONEY : c[:txt])
end
hints(c, [[:ud, "Choose"], [A_BTN, "Use"], [B_BTN, "Back"]])
shot("HP3_use")
scene(c, "chamber.png")
b = BASE.bitmap; t = TOP.bitmap
sparkles(t, 232, 128, 48, 56)
UI.rbox(b, 116, 210, 396, 270, 8, col(c[:panel], 255), c[:line])
mon(t, "PIKACHU", 148, 240, 44)
change_badges(b, t, 290, 226, ROCK, ICE)
message(c, ["The Icicle Plate glowed!", "Pikachu's Hidden Power became Ice type!"])
shot("HP3_result")

#================================================================ HP4: Type Roulette (a reel; A stops it)
REEL = [18, 16, 15, 14, 13]
def hp4(c, landed)
  b = BASE.bitmap; t = TOP.bitmap
  card(c, 116, 16, 280, 336, "Type Roulette")
  mon_row(c, t, 130, 54)
  P.small(t, 290, 62, 64, 16, "Now", c[:dim], 1)
  type_icon(t, ROCK, 360, 60, 20)
  b.fill_rect(126, 94, 260, 1, c[:line])
  # the reel: five rows, the middle one framed
  UI.rbox(b, 176, 102, 336, 274, 8, col(c[:dark], 255), c[:line])
  REEL.each_with_index do |id, i|
    y = 104 + i * 34
    mid = i == 2
    alpha = mid ? 255 : (i == 0 || i == 4 ? 70 : 140)
    icon = Bitmap.new(26, 26)
    icon.stretch_blt(Rect.new(0, 0, 26, 26), bmp(File.join(GFX, "Pictures/Battle/typesSmall.png")), Rect.new(0, id * 19, 19, 19))
    t.blt(196, y + 4, icon, Rect.new(0, 0, 26, 26), alpha)
    colr = mid ? (TCOL[id] || c[:txt]) : col(c[:dim], alpha)
    P.text(t, 230, y + 4, 100, 24, TYPES[id], colr, PF::ROW)
  end
  ring(b, 180, 170, 152, 34, 6, landed ? TCOL[ICE] : c[:selb], 2)
  UI.tri(b, 164, 181, :r, c[:selb], 6); UI.tri(b, 342, 181, :l, c[:selb], 6)
  sparkles(t, 186, 170, 140, 34) if landed
  b.fill_rect(126, 284, 260, 1, c[:line])
  if landed
    button(c, b, t, 128, 298, 92, "Keep", nil, true)
    button(c, b, t, 228, 298, 156, "Spin", "$5,000", false)
  else
    P.small(t, 116, 292, 280, 16, "Spinning... press A to stop.", c[:dim], 2)
    P.text(t, 116, 310, 280, 24, "$5,000 a Spin", MONEY, PF::TEXT, 2)
  end
end
scene(c, "lab.png", 130)
money(c, "$36,200")
hp4(c, false)
hints(c, [[A_BTN, "Stop"]])
shot("HP4_spin")
scene(c, "lab.png", 130)
money(c, "$36,200")
hp4(c, true)
hints(c, [[:lr, "Choose"], [A_BTN, "OK"]])
shot("HP4_landed")

#================================================================ HP5: a tutor list that shows what each type adds to your moves
MOVES = [["Discharge", 13], ["Iron Tail", 8], ["Quick Attack", 0]]
LIST = [5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16, 17]
NEW = { 5 => 2, 6 => 3, 7 => 2, 8 => 0, 10 => 3, 11 => 2, 12 => 1, 13 => 0, 14 => 2, 15 => 3, 16 => 1, 17 => 2 }
def hp5(c)
  b = BASE.bitmap; t = TOP.bitmap
  card(c, 12, 12, 488, 340, "Hidden Power Tutor")
  LIST.each_with_index do |id, i|
    y = 44 + i * 25
    cursor_at(18, y, 216, 24) if id == ICE
    type_icon(t, id, 26, y + 4, 16)
    P.text(t, 48, y, 120, 24, TYPES[id], c[:txt], PF::TEXT)
    if id == ROCK
      P.pill(t, 226, y + 5, "NOW", Color.new(80, 60, 10), GOLD, true)
    elsif NEW[id] > 0
      P.text(t, 150, y, 76, 24, "+#{NEW[id]}", MONEY, PF::TEXT, 1)
    end
  end
  b.fill_rect(239, 44, 2, 300, c[:line]); b.fill_rect(239, 150, 2, 110, c[:dim])
  x = 252
  P.heading(t, x, 490, 44, "Pikachu's Moves", c[:head], c[:line])
  MOVES.each_with_index do |(n, id), i|
    type_icon(t, id, x, 62 + i * 22, 16); P.text(t, x + 22, 58 + i * 22, 200, 22, n, c[:txt], PF::TEXT)
  end
  type_icon(t, ICE, x, 128, 16); P.text(t, x + 22, 124, 200, 22, "Hidden Power", TCOL[ICE], PF::TEXT)
  P.heading(t, x, 490, 156, "Super Effective On", c[:head], c[:line])
  cover = [11, 2, 5, 15, 18, 12, 4, 16]
  cover.each_with_index do |id, k|
    cx = x + (k % 3) * 80; cy = 174 + (k / 3) * 20
    type_icon(t, id, cx, cy, 16)
    P.small(t, cx + 20, cy, 60, 16, TYPES[id], k >= 5 ? MONEY : c[:dim])
  end
  P.heading(t, x, 490, 240, "Lost From Rock", c[:head], c[:line])
  [10, 6].each_with_index do |id, k|
    type_icon(t, id, x + k * 80, 258, 16); P.small(t, x + 20 + k * 80, 258, 60, 16, TYPES[id], RED)
  end
  b.fill_rect(250, 286, 240, 1, c[:line])
  P.small(t, x, 300, 120, 16, "Green: New", c[:dim])
  P.text(t, 300, 296, 188, 24, "$10,000", MONEY, PF::TEXT, 1)
end
scene(c, "lab.png", 170)
hp5(c)
hints(c, [[:ud, "Choose"], [A_BTN, "Teach"], [B_BTN, "Back"]])
shot("HP5_list")
scene(c, "lab.png", 170)
hp5(c)
hints(c, [[:ud, "Choose"], [A_BTN, "Teach"], [B_BTN, "Back"]])
dialog(c, 86, 90, 340, 200, "Hidden Power: Ice")
t = OVER.bitmap; b = DIMMER.bitmap
change_badges(b, t, 256, 140, ROCK, ICE)
P.text(t, 86, 180, 340, 22, "+3 New Coverage", MONEY, PF::TEXT, 2)
P.small(t, 86, 204, 340, 16, "Adds Grass, Ground and Dragon.", c[:txt], 2)
P.small(t, 86, 222, 340, 16, "Loses Fire and Bug.", c[:dim], 2)
button(c, b, t, 196, 252, 120, "OK", nil, true)
shot("HP5_done")
