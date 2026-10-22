# encoding: utf-8
# Mockups: Critical EV Gain (topic 18), five designs, each two screens:
#  - back on the overworld after the win: the EV Gain Summary (every EV
#    gained, normal and critical; new);
#  - in battle on EBDX while EXP is handed out: the Critical Sparkle (new).
# Example: Pikachu (holding a Power Bracer: Power Items Boost doubles its
# Attack critical chance) beats a Gyarados: +2 Attack, and a critical +3
# Attack; Lapras gets +2 Attack through the Exp. Share.
# Design 1 = old KR's result popup (a page per Pokemon, normal and critical
# columns), rebuilt in our UI kit.
# Usage (from this folder): ruby evcrit.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "bmenu_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "bmenu_designs.rb")

def battle_text(c); end
STATS6 = ["HP", "Attack", "Defense", "Sp. Atk", "Sp. Def", "Speed"]
SHORT6 = ["HP", "ATK", "DEF", "SPA", "SPD", "SPE"]
# [species, name, normal gains by stat index, critical gains, held item, EV totals now]
PARTY = [["PIKACHU", "Pikachu", { 1 => 2 }, { 1 => 3 }, "POWERBRACER", [4, 126, 0, 12, 0, 252]],
         ["LAPRAS", "Lapras", { 1 => 2 }, {}, nil, [80, 46, 20, 0, 0, 0]]]
def backdrop(name); MAPS.bitmap = Bitmap.new(File.join(HERE, name)); end
def sparkle(b, cx, cy, r, color)
  b.fill_rect(cx - r, cy, 2 * r + 1, 1, color); b.fill_rect(cx, cy - r, 1, 2 * r + 1, color)
  b.fill_rect(cx - r / 2, cy - 1, r + 1, 3, color); b.fill_rect(cx - 1, cy - r / 2, 3, r + 1, color)
end
def sparkles(b, x, y, w, h)
  [[0.05, 0.1, 6], [0.3, -0.3, 4], [0.55, 0.0, 7], [0.82, -0.25, 5], [0.95, 0.6, 4], [0.2, 1.1, 5], [0.7, 1.05, 6]].each do |fx, fy, r|
    sparkle(b, (x + w * fx).round, (y + h * fy).round, r, Color.new(255, 236, 140))
    sparkle(b, (x + w * fx).round, (y + h * fy).round, r / 2, Color.new(255, 255, 255))
  end
end
def ebdx_message(t, b, text)
  b.fill_rect(0, 320, W, 64, Color.new(0, 0, 0, 150))
  P.text(t, 17, 333, W - 30, 24, text, Color.new(40, 40, 48), PF::ROW); P.text(t, 16, 332, W - 30, 24, text, Color.new(248, 248, 248), PF::ROW)
end
def ow(c); frame(c); backdrop("backdrop.png"); end
def ebdx(c); frame(c); backdrop(File.join("fx", "e_exp.png")); end
def crit_badge(t, x, y, right = false); P.pill(t, x, y, "CRITICAL", Color.new(80, 60, 10), GOLD, right); end
def shot(name); dump_as(name); end
H_OK = [[A_BTN, "OK"]]

c = palette(2)

#================================================================ EV1 Recommended: old KR's result popup, rebuilt
ow(c)
b = BASE.bitmap; t = TOP.bitmap
px = 106; pw = 300; py = 70
UI.rbox(b, px, py, px + pw, py + 248, 8, col(c[:panel], 245), c[:line])
P.text(t, px, py + 6, pw, 24, "EV Gains", c[:title], PF::ROW, 2)
P.text(t, px + pw - 50, py + 10, 40, 14, "1/2", c[:dim], PF::TINY, 1)
b.fill_rect(px + 10, py + 32, pw - 20, 1, c[:line])
mon(t, "PIKACHU", px + 34, py + 56, 44)
P.text(t, px + 62, py + 40, 200, 22, "Pikachu", c[:txt], PF::ROW)
P.text(t, px + 62, py + 62, 200, 14, "+5 EVS", GOLD, PF::TINY)
crit_badge(t, px + pw - 12, py + 44, true)
P.text(t, px + 20, py + 86, 120, 12, "STAT", c[:head], PF::TINY)
P.text(t, px + 150, py + 86, 60, 12, "NORMAL", c[:head], PF::TINY, 2)
P.text(t, px + 220, py + 86, 60, 12, "CRITICAL", c[:head], PF::TINY, 2)
STATS6.each_with_index do |s, i|
  y = py + 102 + i * 20
  P.text(t, px + 20, y, 120, 20, s, c[:txt], PF::TEXT)
  n = PARTY[0][2][i]; cr = PARTY[0][3][i]
  P.text(t, px + 150, y, 60, 20, n ? "+#{n}" : "", c[:txt], PF::TEXT, 2)
  P.text(t, px + 220, y, 60, 20, cr ? "+#{cr}" : "", GOLD, PF::TEXT, 2)
end
b.fill_rect(px + 10, py + 226, pw - 20, 1, c[:line])
item_icon(t, "POWERBRACER", px + 24, py + 237, 16)
P.small(t, px + 36, py + 229, pw - 48, 14, "Power Bracer: Attack Chance x2", c[:dim])
hints(c, [[:lr, "Pokémon"], [A_BTN, "OK"]])
shot("EV1_ow")
ebdx(c)
b = BASE.bitmap; t = TOP.bitmap
sparkles(b, 300, 248, 200, 34)
P.pill(t, 312, 208, "CRITICAL +3 ATTACK", Color.new(80, 60, 10), GOLD, false)
ebdx_message(t, b, "Pikachu gained 214 Exp. Points!")
shot("EV1_battle")

#================================================================ EV2 Toasts: one small toast per Pokemon, top-left
ow(c)
b = BASE.bitmap; t = TOP.bitmap
PARTY.each_with_index do |(sp, n, norm, crit, item, _), i|
  y = 8 + i * 52
  UI.rbox(b, 8, y, 268, y + 46, 8, col(c[:panel], 240), crit.empty? ? c[:line] : GOLD)
  mon(t, sp, 32, y + 23, 40)
  P.text(t, 56, y + 3, 120, 20, n, c[:txt], PF::TEXT)
  x = 56
  norm.each { |k, v| x += P.pill(t, x, y + 25, "+#{v} #{SHORT6[k]}", c[:pill], c[:txt], false) + 4 }
  crit.each { |k, v| x += P.pill(t, x, y + 25, "+#{v} #{SHORT6[k]} CRITICAL", Color.new(80, 60, 10), GOLD, false) + 4 }
  item_icon(t, item, 252, y + 12, 18) if item
end
shot("EV2_ow")
ebdx(c)
b = BASE.bitmap; t = TOP.bitmap
sparkles(b, 40, 120, 170, 150)
P.text(t, 81, 101, 120, 26, "+3 ATK", Color.new(80, 60, 10), PF::TITLE, 2); P.text(t, 80, 100, 120, 26, "+3 ATK", GOLD, PF::TITLE, 2)
ebdx_message(t, b, "Pikachu gained 214 Exp. Points!")
shot("EV2_battle")

#================================================================ EV3 Party Strip: the whole party along the bottom, stat chips
ow(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 8, 244, W - 8, 344, 8, col(c[:panel], 245), c[:line])
P.text(t, 18, 248, 200, 14, "EV GAINS", c[:head], PF::TINY)
PARTY.each_with_index do |(sp, n, norm, crit, item, _), i|
  x = 18 + i * 246
  mon(t, sp, x + 20, 288, 40)
  P.text(t, x + 44, 264, 140, 20, n, c[:txt], PF::TEXT)
  6.times do |k|
    cx = x + 44 + k * 32
    gain = norm[k].to_i + crit[k].to_i
    on = gain > 0
    UI.rbox(b, cx, 288, cx + 28, 320, 5, crit[k] ? Color.new(80, 60, 10) : (on ? c[:sel] : c[:dark]), crit[k] ? GOLD : nil)
    P.text(t, cx, 290, 28, 12, SHORT6[k], crit[k] ? GOLD : c[:dim], PF::TINY, 2)
    P.text(t, cx, 302, 28, 16, on ? "+#{gain}" : "-", crit[k] ? GOLD : (on ? c[:txt] : c[:dim]), PF::TEXT, 2)
  end
end
hints(c, H_OK)
shot("EV3_ow")
ebdx(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 286, 250, 512, 282, 2, Color.new(255, 220, 90, 70))
sparkles(b, 300, 248, 200, 34)
UI.rbox(b, 380, 194, 504, 224, 6, Color.new(80, 60, 10, 235), GOLD)
P.text(t, 380, 195, 124, 14, "CRITICAL EVS", GOLD, PF::TINY, 2); P.text(t, 380, 208, 124, 14, "ATK +3", Color.new(255, 255, 255), PF::TINY, 2)
ebdx_message(t, b, "Pikachu gained 214 Exp. Points!")
shot("EV3_battle")

#================================================================ EV4 EV Bars: every stat's EVs with this battle's gain lit up
ow(c)
b = BASE.bitmap; t = TOP.bitmap
px = 96; pw = 320; py = 54
UI.rbox(b, px, py, px + pw, py + 262, 8, col(c[:panel], 245), c[:line])
P.text(t, px, py + 6, pw, 24, "EV Gains", c[:title], PF::ROW, 2)
b.fill_rect(px + 10, py + 32, pw - 20, 1, c[:line])
sp, n, norm, crit, item, tot = PARTY[0]
mon(t, sp, px + 30, py + 54, 40)
P.text(t, px + 56, py + 40, 160, 22, n, c[:txt], PF::ROW)
crit_badge(t, px + pw - 12, py + 44, true)
STATS6.each_with_index do |s, i|
  y = py + 76 + i * 26
  P.text(t, px + 16, y, 70, 20, s, c[:txt], PF::TEXT)
  bx = px + 90; bw = 170
  b.fill_rect(bx, y + 7, bw, 8, c[:dark])
  before = tot[i] - norm[i].to_i - crit[i].to_i
  b.fill_rect(bx, y + 7, (bw * before / 252.0).round, 8, c[:dim])
  x1 = bx + (bw * before / 252.0).round
  w1 = (bw * norm[i].to_i / 252.0).round.clamp(norm[i] ? 2 : 0, bw); b.fill_rect(x1, y + 7, w1, 8, c[:acc])
  w2 = (bw * crit[i].to_i / 252.0).round.clamp(crit[i] ? 3 : 0, bw); b.fill_rect(x1 + w1, y + 7, w2, 8, GOLD)
  P.text(t, px + 266, y, 44, 20, tot[i].to_s, tot[i] >= 252 ? GREEN : c[:txt], PF::TEXT, 1)
end
P.small(t, px + 14, py + 238, pw - 28, 14, "Blue: Earned · Gold: Critical · Max 252", c[:dim], 2)
hints(c, [[:lr, "Pokémon"], [A_BTN, "OK"]])
shot("EV4_ow")
ebdx(c)
b = BASE.bitmap; t = TOP.bitmap
sparkles(b, 300, 248, 200, 34)
ebdx_message(t, b, "Critical! Pikachu gained 3 extra Attack EVs!")
shot("EV4_battle")

#================================================================ EV5 Corner Chip: no popup, a chip that fades on its own
ow(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, W - 228, 8, W - 8, 40, 8, col(c[:panel], 235), GOLD)
mon(t, "PIKACHU", W - 208, 24, 30)
P.text(t, W - 190, 9, 170, 16, "Critical EVs", GOLD, PF::TINY)
P.text(t, W - 190, 22, 170, 16, "Pikachu +3 Attack", c[:txt], PF::TINY)
shot("EV5_ow")
ebdx(c)
b = BASE.bitmap; t = TOP.bitmap
sparkles(b, 300, 248, 200, 34)
ebdx_message(t, b, "Pikachu gained 214 Exp. Points!")
shot("EV5_battle")
