# encoding: utf-8
# Mockups: four Battle Tools designs over the same PIF battle, each as two
# screens: Quick Throw with the Ball Advisor (every ball owned, its catch
# chance against this Pokemon now, the best one marked) and Matchup View
# (your moves against the foe, its type profile). The catch chance also sits
# beside the foe's HP bar.
# Design 1 = HR's Quick Throw / Matchup View in the chosen Battle Menu style.
# Usage: ruby tools_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "bmenu_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "bmenu_designs.rb")

# [ball item, name, owned, catch %, note]
BALLS = [["NETBALL", "Net Ball", 4, 52, "x3.5 on Water"], ["ULTRABALL", "Ultra Ball", 6, 36, "x2"], ["GREATBALL", "Great Ball", 9, 27, "x1.5"],
         ["POKEBALL", "Poké Ball", 12, 18, "x1"], ["DUSKBALL", "Dusk Ball", 3, 18, "x3 at night"], ["QUICKBALL", "Quick Ball", 2, 18, "x5 on turn 1"]]
BEST = 0
# [move, type id, effect text, multiplier label, colour key]
MOVES = [["Thunderbolt", 13, "Super Effective", "x2", :good], ["Quick Attack", 0, "Effective", "x1", :ok], ["Iron Tail", 8, "Not Very Effective", "x0.5", :bad],
         ["Thunder Wave", 13, "Status", "", :dim]]
PROFILE = [["Weak To", [13, 12]], ["Resists", [10, 11, 15, 8]], ["Immune To", []]]

def catch_tag(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 228, 36, 300, 54, 6, col(c[:panel], 235), GREEN)
  item_icon(t, "NETBALL", 240, 45, 14)
  P.text(t, 250, 36, 48, 18, "52%", GREEN, PF::TEXT, 2)
end
def bar(b, x, y, w, pctv, colr, c)
  b.fill_rect(x, y, w, 5, c[:dark]); b.fill_rect(x, y, (w * pctv / 100.0).round, 5, colr)
end
def ecol(k, c); { :good => GREEN, :ok => c[:txt], :bad => RED, :dim => c[:dim] }[k]; end
H_QT = [[:ud, "Choose"], [A_BTN, "Throw"], [Y_BTN, "Set Default"], [B_BTN, "Back"]]
H_MV = [[:ud, "Moves"], [:lr, "Foes"], [B_BTN, "Back"]]

c = palette(2)

#================================================================ TT1 Recommended: centred panels (Battle Menu style)
frame(c)
b = BASE.bitmap; t = TOP.bitmap
catch_tag(c)
px = 116; pw = 280; py = 60; rh = 24
UI.rbox(b, px, py, px + pw, py + 26 + BALLS.length * rh + 6, 6, col(c[:panel], 242), c[:line])
P.text(t, px, py + 4, pw, 22, "Quick Throw", c[:title], PF::ROW, 2)
b.fill_rect(px + 8, py + 26, pw - 16, 1, c[:line])
BALLS.each_with_index do |(ic, n, q, p, note), i|
  y = py + 30 + i * rh
  cursor_at(px + 4, y, pw - 8, rh - 1) if i == BEST
  item_icon(t, ic, px + 18, y + 11, 18)
  P.text(t, px + 32, y, 100, rh - 1, n, i == BEST ? GOLD : c[:txt], PF::TEXT)
  star(t, px + 34 + P.width(PF::TEXT, n) + 4, y + 8, GOLD) if i == BEST
  P.text(t, px + 130, y, 26, rh - 1, "x#{q}", c[:dim], PF::TINY)
  bar(b, px + 158, y + 9, 66, p, i == BEST ? GOLD : GREEN, c)
  P.text(t, px + 228, y, 44, rh - 1, "#{p}%", i == BEST ? GOLD : c[:txt], PF::TEXT, 1)
end
dy = py + 26 + BALLS.length * rh + 10
UI.rbox(b, px, dy, px + pw, dy + 40, 6, col(c[:panel2], 240), c[:line])
P.small(t, px + 8, dy + 4, pw - 16, 16, "Net Ball: x3.5 on Water and Bug types.", c[:txt])
P.small(t, px + 8, dy + 20, pw - 16, 16, "Golduck at 55% HP, no status.", c[:dim])
dump_as("TT1_throw")
frame(c)
b = BASE.bitmap; t = TOP.bitmap
catch_tag(c)
px = 96; pw = 320; py = 60
UI.rbox(b, px, py, px + pw, py + 214, 6, col(c[:panel], 242), c[:line])
P.text(t, px, py + 4, pw, 22, "Matchup View", c[:title], PF::ROW, 2)
b.fill_rect(px + 8, py + 26, pw - 16, 1, c[:line])
P.text(t, px + 10, py + 30, 200, 12, "YOUR MOVES VS GOLDUCK", c[:head], PF::TINY)
MOVES.each_with_index do |(m, ty, eff, mult, k), i|
  y = py + 44 + i * 22
  cursor_at(px + 4, y, pw - 8, 21) if i == 0
  type_icon(t, ty, px + 12, y + 3)
  P.text(t, px + 34, y, 130, 21, m, c[:txt], PF::TEXT)
  P.text(t, px + 160, y, 120, 21, eff, ecol(k, c), PF::TINY)
  P.text(t, px + pw - 50, y, 40, 21, mult, ecol(k, c), PF::TEXT, 1)
end
b.fill_rect(px + 8, py + 136, pw - 16, 1, c[:line])
P.text(t, px + 10, py + 140, 200, 12, "GOLDUCK'S TYPE PROFILE", c[:head], PF::TINY)
type_icon(t, 11, px + pw - 30, py + 138)
PROFILE.each_with_index do |(k, ids), i|
  y = py + 154 + i * 20
  P.text(t, px + 12, y, 100, 20, k, c[:txt], PF::TEXT)
  if ids.empty?
    P.text(t, px + 110, y, 100, 20, "None", c[:dim], PF::TEXT)
  else
    ids.each_with_index { |id, j| type_icon(t, id, px + 110 + j * 20, y + 2) }
  end
end
hints(c, H_MV)
dump_as("TT1_matchup")

#================================================================ TT2 Ball Row above the command box
frame(c)
b = BASE.bitmap; t = TOP.bitmap
catch_tag(c)
UI.rbox(b, 4, 210, W - 5, 286, 8, col(c[:panel], 245), c[:line])
BALLS.each_with_index do |(ic, n, q, p, note), i|
  bx = 10 + i * 83
  UI.rbox(b, bx, 216, bx + 78, 280, 6, i == BEST ? Reloaded::Palette.mix(c[:panel], GOLD, 0.2) : c[:dark], i == BEST ? GOLD : c[:line])
  cursor_at(bx, 216, 79, 65) if i == BEST
  item_icon(t, ic, bx + 20, 236, 26)
  P.text(t, bx + 36, 222, 40, 14, "x#{q}", c[:dim], PF::TINY)
  P.text(t, bx + 36, 236, 42, 18, "#{p}%", i == BEST ? GOLD : c[:txt], PF::TEXT)
  P.text(t, bx, 262, 78, 14, n.upcase, i == BEST ? GOLD : c[:txt], PF::TINY, 2)
end
dump_as("TT2_throw")
frame(c)
b = BASE.bitmap; t = TOP.bitmap
catch_tag(c)
UI.rbox(b, 4, 196, W - 5, 286, 8, col(c[:panel], 245), c[:line])
MOVES.each_with_index do |(m, ty, eff, mult, k), i|
  bx = 10 + (i % 2) * 168; by = 202 + (i / 2) * 42
  UI.rbox(b, bx, by, bx + 162, by + 38, 6, c[:dark], k == :good ? GREEN : c[:line])
  type_icon(t, ty, bx + 6, by + 4)
  P.text(t, bx + 26, by + 2, 110, 18, m, c[:txt], PF::TEXT)
  P.text(t, bx + 6, by + 22, 150, 14, "#{eff} #{mult}", ecol(k, c), PF::TINY)
end
P.text(t, 352, 202, 150, 12, "GOLDUCK", c[:head], PF::TINY)
PROFILE.each_with_index do |(k, ids), i|
  y = 218 + i * 20
  P.text(t, 352, y, 70, 18, k.split(" ").first, c[:txt], PF::TINY)
  ids.empty? ? P.text(t, 410, y, 60, 18, "NONE", c[:dim], PF::TINY) : ids.each_with_index { |id, j| type_icon(t, id, 410 + j * 18, y + 1, 15) }
end
dump_as("TT2_matchup")

#================================================================ TT3 Side Drawer
frame(c)
b = BASE.bitmap; t = TOP.bitmap
catch_tag(c); field_strip(c)
UI.rbox(b, 290, 6, W - 6, 284, 8, col(c[:panel], 242), c[:line])
P.text(t, 290, 10, W - 296, 22, "Quick Throw", c[:title], PF::ROW, 2)
BALLS.each_with_index do |(ic, n, q, p, note), i|
  y = 38 + i * 40
  cursor_at(294, y, W - 304, 38) if i == BEST
  item_icon(t, ic, 312, y + 18, 24)
  P.text(t, 330, y + 1, 110, 18, n, i == BEST ? GOLD : c[:txt], PF::TEXT)
  P.text(t, 330, y + 20, 110, 14, "x#{q} · #{note}", c[:dim], PF::TINY)
  P.text(t, 440, y + 6, 60, 22, "#{p}%", i == BEST ? GOLD : c[:txt], PF::ROW, 1)
end
dump_as("TT3_throw")
frame(c, 120)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 220, 6, W - 6, 352, 8, col(c[:panel], 248), c[:line])
P.text(t, 220, 10, W - 226, 22, "Matchup View", c[:title], PF::ROW, 2)
MOVES.each_with_index do |(m, ty, eff, mult, k), i|
  y = 38 + i * 40
  cursor_at(224, y, W - 234, 38) if i == 0
  type_icon(t, ty, 232, y + 10)
  P.text(t, 254, y + 1, 150, 18, m, c[:txt], PF::TEXT)
  P.text(t, 254, y + 20, 150, 14, eff, ecol(k, c), PF::TINY)
  P.text(t, 440, y + 6, 60, 22, mult, ecol(k, c), PF::ROW, 1)
end
P.heading(t, 230, W - 16, 206, "Golduck", c[:head], c[:line])
PROFILE.each_with_index do |(k, ids), i|
  y = 222 + i * 24
  P.text(t, 232, y, 100, 22, k, c[:txt], PF::TEXT)
  ids.empty? ? P.text(t, 336, y, 100, 22, "None", c[:dim], PF::TEXT) : ids.each_with_index { |id, j| type_icon(t, id, 336 + j * 20, y + 3) }
end
hints(c, H_MV)
dump_as("TT3_matchup")

#================================================================ TT4 Bottom Panel
frame(c)
b = BASE.bitmap; t = TOP.bitmap
catch_tag(c)
UI.rbox(b, 4, 196, W - 5, 356, 8, col(c[:panel], 246), c[:line])
P.text(t, 14, 200, 200, 18, "Quick Throw", c[:head], PF::TEXT)
P.text(t, 300, 200, 200, 18, "Golduck · 55% HP", c[:dim], PF::TINY, 1)
BALLS.each_with_index do |(ic, n, q, p, note), i|
  gx = 12 + (i % 3) * 164; gy = 222 + (i / 3) * 62
  UI.rbox(b, gx, gy, gx + 158, gy + 56, 6, c[:dark], i == BEST ? GOLD : c[:line])
  cursor_at(gx, gy, 159, 57) if i == BEST
  item_icon(t, ic, gx + 20, gy + 22, 26)
  P.text(t, gx + 40, gy + 4, 110, 18, n, i == BEST ? GOLD : c[:txt], PF::TEXT)
  P.text(t, gx + 40, gy + 24, 60, 14, "x#{q}", c[:dim], PF::TINY)
  P.text(t, gx + 90, gy + 20, 62, 20, "#{p}%", i == BEST ? GOLD : c[:txt], PF::ROW, 1)
  bar(b, gx + 8, gy + 46, 142, p, i == BEST ? GOLD : GREEN, c)
end
dump_as("TT4_throw")
frame(c)
b = BASE.bitmap; t = TOP.bitmap
catch_tag(c)
UI.rbox(b, 4, 196, W - 5, 356, 8, col(c[:panel], 246), c[:line])
P.text(t, 14, 200, 200, 18, "Matchup View", c[:head], PF::TEXT)
MOVES.each_with_index do |(m, ty, eff, mult, k), i|
  y = 222 + i * 32
  cursor_at(10, y, 300, 30) if i == 0
  type_icon(t, ty, 18, y + 7)
  P.text(t, 40, y, 130, 30, m, c[:txt], PF::TEXT)
  P.text(t, 160, y, 110, 30, eff, ecol(k, c), PF::TINY)
  P.text(t, 268, y, 36, 30, mult, ecol(k, c), PF::TEXT, 1)
end
b.fill_rect(318, 222, 1, 124, c[:line])
P.text(t, 328, 222, 170, 12, "GOLDUCK", c[:head], PF::TINY)
PROFILE.each_with_index do |(k, ids), i|
  y = 240 + i * 34
  P.text(t, 328, y, 170, 14, k.upcase, c[:txt], PF::TINY)
  ids.empty? ? P.text(t, 328, y + 14, 100, 16, "None", c[:dim], PF::TEXT) : ids.each_with_index { |id, j| type_icon(t, id, 328 + j * 20, y + 15) }
end
dump_as("TT4_matchup")
puts "done"
