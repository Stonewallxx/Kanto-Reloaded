# encoding: utf-8
# Mockups: five Egg Manager designs, each as two screens: Eggs (every Egg with
# location, progress and steps, filters, incubators, the Hatching Soon alert,
# the Hatch Speed Helper, Auto-Incubate) and Day Care (the two Pokemon, their
# compatibility, the waiting Egg, deposit/withdraw).
# Design 1 = HR's Egg Manager screen in our UI kit.
# Usage: ruby egg_designs.rb "<KIF Beta>" <work dir with metrics.json>
PREVIEW = File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
src = File.read(PREVIEW, :encoding => "UTF-8")
eval(src.split("#---------------------------------------------------------------- A: Ocean Blue")[0], binding, PREVIEW)

P = Reloaded::Pixel
BI = Reloaded::ButtonIcons
PF = KIF::PixelFont
UI = KIF::PixelUI
W = 512; H = 384
HERE = File.expand_path(File.dirname(__FILE__))
GFX = File.join(ARGV[0], "Graphics")
$style = :xbox

# [label, where, steps left, total, incubator slot or nil, tag]
EGGS = [["Egg", "Party", 340, 5120, nil, :soon], ["Egg", "Box 3", 1280, 5120, 1, nil], ["Egg", "Box 3", 2560, 5120, 2, nil],
        ["K-Egg", "Party", 2048, 5120, nil, :reward], ["Egg", "Box 5", 5120, 5120, nil, nil]]
SEL = 0
FILTERS = ["All", "Party", "PC", "Ready", "Reward"]
DAYCARE = [["DITTO", "Ditto", 31, "+3 Levels"], ["CHARMANDER", "Charmander", 18, "+2 Levels"]]
GREEN = Color.new(120, 230, 150); GOLD = Color.new(240, 200, 70); BLUE = Color.new(130, 190, 250); PINK = Color.new(255, 130, 160)
A_BTN = "p:0"; B_BTN = "p:1"; X_BTN = "p:2"; Y_BTN = "p:3"

def palette(theme)
  Reloaded::Settings.set(:"interface.theme", theme)
  return Reloaded::Palette.current
end
def col(c, a); Color.new(c.red, c.green, c.blue, a); end

$vp = Viewport.new(0, 0, W, H)
$vp.z = 99_999
def layer(z); s = Sprite.new($vp); s.bitmap = Bitmap.new(W, H); s.z = z; s; end
MAPS = Sprite.new($vp); MAPS.z = -1
BG_MAP = Bitmap.new(File.join(HERE, "backdrop.png"))
BASE = layer(0)
CUR = Sprite.new($vp); CUR.z = 1
TOP = layer(2)
def frame(c, opaque = true, dim = 0)
  BASE.bitmap.clear; TOP.bitmap.clear
  CUR.visible = false
  MAPS.bitmap = BG_MAP
  if opaque
    BASE.bitmap.fill_rect(0, 0, W, H, c[:bg])
  elsif dim > 0
    BASE.bitmap.fill_rect(0, 0, W, H, Color.new(c[:bg].red, c[:bg].green, c[:bg].blue, dim))
  end
end
def cursor_at(x, y, w, h)
  CUR.bitmap = P.cursor_bitmap(w, h)
  CUR.x = x; CUR.y = y; CUR.opacity = 210; CUR.visible = true
end
$bmps = {}
def bmp(path); $bmps[path] ||= Bitmap.new(path); end
def draw_img(b, path, cx, cy, size, src = nil)
  i = bmp(path)
  src ||= Rect.new(0, 0, i.width, i.height)
  sc = size.to_f / [src.width, src.height].max
  w = (src.width * sc).round; h = (src.height * sc).round
  b.stretch_blt(Rect.new(cx - w / 2, cy - h / 2, w, h), i, src)
end
def egg_icon(b, cx, cy, size); draw_img(b, File.join(GFX, "Pokemon/Eggs/000_icon.png"), cx, cy, size, Rect.new(0, 0, 64, 64)); end
def mon_icon(b, species, cx, cy, size)
  draw_img(b, File.join(GFX, "Pokemon/Icons/#{species}.png"), cx, cy, size, Rect.new(0, 0, 64, 64))
end
def pct(e); ((e[3] - e[2]) * 100.0 / e[3]).round; end
def bar(b, x, y, w, p, c, h = 5, color = nil)
  b.fill_rect(x, y, w, h, c[:dark])
  b.fill_rect(x, y, (w * p / 100.0).round, h, color || (p >= 90 ? GOLD : GREEN)) if p > 0
end
def badge(b, x, y, text, color, right = false); P.pill(b, x, y, text, Color.new(color.red / 4, color.green / 4, color.blue / 4), color, right); end
def steps(e); e[2] >= 1000 ? "#{e[2] / 1000},#{format('%03d', e[2] % 1000)} Steps" : "#{e[2]} Steps"; end
def tag_badge(b, e, x, y, right = false)
  case e[5]
  when :soon then badge(b, x, y, "SOON", GOLD, right)
  when :reward then badge(b, x, y, "REWARD", PINK, right)
  else badge(b, x, y, "INCUBATOR #{e[4]}", GREEN, right) if e[4]
  end
end
def tabs(c, x, y, w, current)
  tw = w / 2
  [["Eggs", "1 SOON"], ["Day Care", "EGG WAITING"]].each_with_index do |(tb, note), i|
    on = i == current
    UI.rbox(BASE.bitmap, x + i * tw + 2, y, x + (i + 1) * tw - 2, y + 24, 5, on ? c[:sel] : c[:panel], on ? c[:selb] : c[:line])
    lw = P.width(PF::TEXT, tb)
    sx = x + i * tw + (tw - lw - 12) / 2
    P.text(TOP.bitmap, sx, y, lw + 2, 24, tb, on ? c[:white] : c[:dim], PF::TEXT)
    UI.rbox(BASE.bitmap, sx + lw + 6, y + 9, sx + lw + 12, y + 15, 3, GOLD)
  end
end
def speed_helper(c, x, y, w)
  t = TOP.bitmap
  mon_icon(t, "MAGCARGO", x + 14, y + 12, 28)
  narrow = w < 300
  P.small(t, x + 32, y - 2, w - 34, 15, narrow ? "No Flame Body in party." : "No Flame Body in your party.", c[:txt])
  P.small(t, x + 32, y + 13, w - 34, 15, narrow ? "Try Magcargo (Box 2)." : "Magcargo (Box 2) would halve hatch time.", GOLD)
end
def hints(c, pairs); P.hints(BASE.bitmap, TOP.bitmap, c, pairs, $style); end
H_EGGS = [[:ud, "Choose"], ["p:4", "Filter"], [A_BTN, "Options"], ["p:9", "Tabs"], [B_BTN, "Close"]]
H_DC = [[:ud, "Choose"], [A_BTN, "Select"], ["p:9", "Tabs"], [B_BTN, "Close"]]
def dump_as(name); dump(name); puts "wrote #{name}"; end

c = palette(2)

#================================================================ E1 Recommended: HR's Egg Manager, rebuilt
def e1_header(c, tab)
  b = BASE.bitmap
  b.fill_rect(0, 0, W, 40, c[:panel2]); b.fill_rect(0, 39, W, 1, c[:line])
  tabs(c, 120, 8, 272, tab)
end
frame(c)
b = BASE.bitmap; t = TOP.bitmap
e1_header(c, 0)
UI.rbox(b, 5, 45, 251, 353, 6, c[:panel])
FILTERS.each_with_index do |f, i|
  fx = 10 + i * 48
  UI.rbox(b, fx, 50, fx + 44, 68, 4, i == 0 ? c[:sel] : c[:dark], i == 0 ? c[:selb] : nil)
  P.text(t, fx, 50, 44, 18, f.upcase, i == 0 ? c[:white] : c[:dim], PF::TINY, 2)
end
EGGS.each_with_index do |e, i|
  y = 74 + i * 38
  UI.rbox(b, 10, y, 246, y + 35, 5, col(c[:panel2], 255))
  cursor_at(10, y, 237, 36) if i == SEL
  egg_icon(t, 30, y + 18, 36)
  P.text(t, 52, y + 1, 90, 18, e[0], c[:txt], PF::TEXT)
  P.text(t, 52, y + 19, 90, 14, e[1], c[:dim], PF::TINY)
  bar(b, 110, y + 24, 128, pct(e), c)
  P.text(t, 110, y + 4, 128, 14, steps(e), c[:txt], PF::TINY, 1)
end
UI.rbox(b, 257, 45, 507, 353, 6, c[:panel])
egg_icon(t, 382, 92, 72)
badge(t, 382 + 30, 60, "HATCHING SOON", GOLD)
[["Location", "Party, Slot 6"], ["Steps Left", "340 of 5,120"], ["Status", "Hatching Soon"]].each_with_index do |(k, v), i|
  y = 132 + i * 22
  P.text(t, 268, y, 100, 20, k, c[:dim], PF::TEXT)
  P.text(t, 368, y, 132, 20, v, i == 2 ? GOLD : c[:txt], PF::TEXT, 1)
end
bar(b, 268, 200, 228, 93, c, 7)
P.text(t, 268, 210, 228, 12, "93%", GOLD, PF::TINY, 1)
b.fill_rect(268, 228, 228, 1, c[:line])
P.text(t, 268, 234, 228, 12, "INCUBATORS  2/3", c[:head], PF::TINY)
3.times { |k| UI.rbox(b, 268 + k * 30, 250, 292 + k * 30, 270, 4, k < 2 ? col(GREEN, 120) : c[:dark], k < 2 ? GREEN : c[:line]) }
P.small(t, 362, 252, 140, 16, "Auto-Incubate: On", GREEN)
b.fill_rect(268, 280, 228, 1, c[:line])
speed_helper(c, 268, 294, 230)
hints(c, H_EGGS)
dump_as("E1_eggs")
frame(c)
b = BASE.bitmap; t = TOP.bitmap
e1_header(c, 1)
UI.rbox(b, 5, 45, 251, 353, 6, c[:panel])
rows = ["Ditto  Lv 31", "Charmander  Lv 18", "Egg Waiting", "Deposit a Pokémon", "Settings"]
rows.each_with_index do |r, i|
  y = 52 + i * 34
  cursor_at(10, y, 237, 32) if i == 2
  if i < 2
    mon_icon(t, DAYCARE[i][0], 30, y + 15, 32)
  elsif i == 2
    egg_icon(t, 30, y + 15, 30)
  end
  P.text(t, 52, y, 190, 32, r, i == 2 ? GOLD : c[:txt], PF::TEXT)
end
UI.rbox(b, 257, 45, 507, 353, 6, c[:panel])
mon_icon(t, "DITTO", 330, 92, 64); mon_icon(t, "CHARMANDER", 434, 92, 64)
P.text(t, 257, 128, 250, 14, "THEY SEEM TO GET ALONG", PINK, PF::TINY, 2)
3.times { |k| UI.rbox(b, 356 + k * 14, 146, 366 + k * 14, 156, 5, k < 2 ? PINK : c[:dark]) }
[["Ditto", "+3 Levels · $400"], ["Charmander", "+2 Levels · $300"]].each_with_index do |(k, v), i|
  y = 170 + i * 22
  P.text(t, 268, y, 110, 20, k, c[:txt], PF::TEXT); P.small(t, 376, y + 2, 120, 16, v, c[:dim], 1)
end
b.fill_rect(268, 220, 228, 1, c[:line])
egg_icon(t, 288, 248, 34)
P.text(t, 310, 230, 190, 18, "An Egg Is Waiting", GOLD, PF::TEXT)
P.small(t, 310, 250, 190, 15, "If your party is full, it goes", c[:dim])
P.small(t, 310, 264, 190, 15, "to Incubator 3.", c[:dim])
[["Collect", true], ["Discard", false]].each_with_index do |(l, on), i|
  bx = 290 + i * 110
  UI.rbox(b, bx, 290, bx + 100, 314, 5, on ? c[:selb] : c[:dark], on ? nil : c[:line])
  P.text(t, bx, 290, 100, 24, l, on ? c[:dark] : c[:txt], PF::TEXT, 2)
end
hints(c, H_DC)
dump_as("E1_daycare")

#================================================================ E2 Incubator Shelf
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
P.text(t, 0, 3, W, 28, "Eggs", c[:title], PF::TITLE, 2)
badge(t, W - 10, 9, "1 HATCHING SOON", GOLD, true)
P.text(t, 12, 40, 200, 12, "PC INCUBATORS · AUTO-INCUBATE ON", c[:head], PF::TINY)
3.times do |k|
  px = 12 + k * 166
  UI.rbox(b, px, 56, px + 156, 150, 10, c[:panel], k < 2 ? GREEN : c[:line])
  UI.rbox(b, px + 48, 64, px + 108, 124, 30, k < 2 ? col(GREEN, 40) : c[:dark], k < 2 ? GREEN : c[:line])
  if k < 2
    e = EGGS[k + 1]
    egg_icon(t, px + 78, 94, 44)
    bar(b, px + 14, 132, 128, pct(e), c, 6)
    P.text(t, px + 14, 136, 128, 14, steps(e), c[:dim], PF::TINY, 2)
  else
    P.text(t, px, 82, 156, 24, "Empty", c[:dim], PF::TEXT, 2)
  end
end
P.text(t, 12, 158, 200, 12, "PARTY AND PC", c[:head], PF::TINY)
[EGGS[0], EGGS[3], EGGS[4]].each_with_index do |e, i|
  y = 174 + i * 40
  UI.rbox(b, 8, y, W - 9, y + 36, 6, c[:panel])
  cursor_at(8, y, W - 16, 37) if i == 0
  egg_icon(t, 30, y + 18, 34)
  P.text(t, 52, y + 2, 120, 18, "#{e[0]} · #{e[1]}", c[:txt], PF::TEXT)
  bar(b, 52, y + 24, 260, pct(e), c)
  P.text(t, 320, y + 2, 100, 18, steps(e), c[:txt], PF::TINY)
  tag_badge(t, e, W - 16, y + 10, true)
end
UI.rbox(b, 8, 300, W - 9, 352, 6, c[:panel2], c[:line])
speed_helper(c, 16, 316, 480)
hints(c, [[:lr, "Choose"], [:ud, "Choose"], [A_BTN, "Options"], ["p:9", "Day Care"], [B_BTN, "Close"]])
dump_as("E2_eggs")
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
P.text(t, 0, 3, W, 28, "Day Care", c[:title], PF::TITLE, 2)
2.times do |k|
  px = 30 + k * 300
  UI.rbox(b, px, 50, px + 152, 200, 12, c[:panel], c[:line])
  mon_icon(t, DAYCARE[k][0], px + 76, 104, 80)
  P.text(t, px, 150, 152, 18, "#{DAYCARE[k][1]}  Lv #{DAYCARE[k][2]}", c[:txt], PF::TEXT, 2)
  P.text(t, px, 172, 152, 14, DAYCARE[k][3], GREEN, PF::TINY, 2)
end
3.times { |k| UI.rbox(b, 236 + k * 16, 112, 248 + k * 16, 124, 6, k < 2 ? PINK : c[:dark]) }
P.text(t, 196, 132, 120, 14, "GET ALONG", PINK, PF::TINY, 2)
UI.rbox(b, 120, 220, 392, 300, 10, c[:panel], GOLD)
egg_icon(t, 160, 260, 50)
P.text(t, 190, 230, 190, 18, "An Egg Is Waiting", GOLD, PF::TEXT)
P.small(t, 190, 250, 196, 15, "Goes to Incubator 3 if", c[:dim])
P.small(t, 190, 264, 196, 15, "your party is full.", c[:dim])
cursor_at(120, 220, 273, 81)
hints(c, [[A_BTN, "Collect"], [X_BTN, "Discard"], [:lr, "Pokémon"], ["p:9", "Eggs"], [B_BTN, "Close"]])
dump_as("E2_daycare")

#================================================================ E3 Hatch Race (progress-first)
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
tabs(c, 120, 5, 272, 0)
EGGS.sort_by { |e| e[2] }.each_with_index do |e, i|
  y = 42 + i * 46
  UI.rbox(b, 8, y, W - 9, y + 42, 6, c[:panel])
  cursor_at(8, y, W - 16, 43) if i == 0
  egg_icon(t, 30, y + 21, 36)
  P.text(t, 52, y + 2, 200, 18, "#{e[0]} · #{e[1]}", c[:txt], PF::TEXT)
  tag_badge(t, e, 220, y + 5)
  bar(b, 52, y + 26, 330, pct(e), c, 8)
  P.text(t, 392, y + 2, 110, 18, steps(e), c[:txt], PF::TEXT, 1)
  P.text(t, 392, y + 22, 110, 14, "#{pct(e)}%", c[:dim], PF::TINY, 1)
end
UI.rbox(b, 8, 276, W - 9, 352, 6, c[:panel2], c[:line])
P.text(t, 16, 280, 300, 12, "INCUBATORS 2/3 · AUTO-INCUBATE ON", GREEN, PF::TINY)
speed_helper(c, 16, 308, 480)
hints(c, H_EGGS)
dump_as("E3_eggs")
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
tabs(c, 120, 5, 272, 1)
DAYCARE.each_with_index do |(sp, name, lv, gain), i|
  y = 44 + i * 64
  UI.rbox(b, 8, y, W - 9, y + 58, 6, c[:panel])
  mon_icon(t, sp, 40, y + 29, 52)
  P.text(t, 76, y + 6, 200, 20, "#{name}  Lv #{lv}", c[:txt], PF::ROW)
  P.text(t, 76, y + 32, 200, 14, "#{gain} · $#{i == 0 ? 400 : 300} to take back", c[:dim], PF::TINY)
end
P.text(t, 0, 176, W, 14, "COMPATIBILITY: THEY SEEM TO GET ALONG", PINK, PF::TINY, 2)
UI.rbox(b, 8, 196, W - 9, 270, 6, c[:panel], GOLD)
cursor_at(8, 196, W - 16, 75)
egg_icon(t, 44, 233, 50)
P.text(t, 80, 204, 300, 20, "An Egg Is Waiting", GOLD, PF::ROW)
P.small(t, 80, 230, 400, 15, "Collect it, or it goes to Incubator 3", c[:dim])
P.small(t, 80, 246, 400, 15, "when your party is full.", c[:dim])
hints(c, [[A_BTN, "Collect"], [X_BTN, "Discard"], [:ud, "Choose"], ["p:9", "Eggs"], [B_BTN, "Close"]])
dump_as("E3_daycare")

#================================================================ E4 Settings Style (sidebar)
def e4_frame(c, sec)
  frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
  P.text(t, 0, 2, W, 28, "Egg Manager", c[:title], PF::TITLE, 2)
  UI.rbox(b, 6, 36, 150, 262, 6, c[:panel])
  [["Eggs", "5"], ["Day Care", "1"], ["Incubators", "2/3"], ["Settings", ""]].each_with_index do |(s, n), i|
    y = 42 + i * 30
    UI.rbox(b, 10, y, 146, y + 26, 5, c[:sel], c[:selb]) if i == sec
    P.text(t, 18, y, 90, 26, s, i == sec ? c[:white] : c[:txt], PF::TEXT)
    P.text(t, 100, y, 40, 26, n, i == 1 ? GOLD : c[:dim], PF::TINY, 1)
  end
  UI.rbox(b, 156, 36, W - 6, 262, 6, c[:panel])
  UI.rbox(b, 6, 268, W - 6, H - 30, 6, c[:panel2], c[:line])
end
e4_frame(c, 0)
b = BASE.bitmap; t = TOP.bitmap
EGGS.each_with_index do |e, i|
  y = 40 + i * 44
  cursor_at(159, y, W - 168, 42) if i == SEL
  egg_icon(t, 180, y + 21, 34)
  P.text(t, 202, y + 2, 120, 20, "#{e[0]} · #{e[1]}", c[:txt], PF::ROW)
  bar(b, 202, y + 28, 200, pct(e), c)
  P.text(t, 410, y + 4, 90, 14, steps(e), c[:dim], PF::TINY, 1)
  tag_badge(t, e, W - 14, y + 24, true)
end
P.text(t, 16, 270, 300, 24, "Hatching Soon", c[:head], PF::ROW)
P.small(t, 16, 294, 340, 16, "In your party, 340 steps to go. Keep walking!", c[:txt])
speed_helper(c, 16, 320, 480)
hints(c, [[:ud, "Choose"], [:lr, "Sections"], [A_BTN, "Options"], [B_BTN, "Close"]])
dump_as("E4_eggs")
e4_frame(c, 1)
b = BASE.bitmap; t = TOP.bitmap
DAYCARE.each_with_index do |(sp, name, lv, gain), i|
  y = 40 + i * 44
  mon_icon(t, sp, 180, y + 21, 40)
  P.text(t, 204, y + 2, 160, 20, "#{name}  Lv #{lv}", c[:txt], PF::ROW)
  P.text(t, 204, y + 24, 200, 14, "#{gain} · $#{i == 0 ? 400 : 300}", c[:dim], PF::TINY)
end
P.text(t, 166, 132, 300, 14, "THEY SEEM TO GET ALONG", PINK, PF::TINY)
cursor_at(159, 152, W - 168, 40)
egg_icon(t, 180, 172, 34)
P.text(t, 204, 152, 200, 40, "Egg Waiting", GOLD, PF::ROW)
["Deposit a Pokémon", "Take Both Back"].each_with_index { |l, i| P.text(t, 170, 198 + i * 28, 300, 26, l, c[:txt], PF::ROW) }
P.text(t, 16, 270, 300, 24, "Egg Waiting", c[:head], PF::ROW)
P.small(t, 16, 294, 480, 16, "Collect it, or Auto-Incubate moves it to Incubator 3.", c[:txt])
hints(c, [[:ud, "Choose"], [:lr, "Sections"], [A_BTN, "Collect"], [B_BTN, "Close"]])
dump_as("E4_daycare")

#================================================================ E5 Over the Map
frame(c, false, 100)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 252, 6, W - 6, 352, 8, col(c[:panel], 240), c[:line])
tabs(c, 256, 12, 250, 0)
EGGS.each_with_index do |e, i|
  y = 44 + i * 42
  cursor_at(258, y, W - 270, 40) if i == SEL
  egg_icon(t, 278, y + 20, 32)
  P.text(t, 298, y + 2, 120, 18, "#{e[0]} · #{e[1]}", c[:txt], PF::TEXT)
  bar(b, 298, y + 26, 120, pct(e), c)
  P.text(t, 424, y + 4, 78, 14, steps(e).sub(" Steps", ""), c[:dim], PF::TINY, 1)
  tag_badge(t, e, W - 14, y + 22, true)
end
b.fill_rect(262, 262, W - 278, 1, c[:line])
P.text(t, 262, 266, 240, 12, "INCUBATORS 2/3 · AUTO ON", GREEN, PF::TINY)
speed_helper(c, 262, 296, 240)
hints(c, H_EGGS)
dump_as("E5_eggs")
frame(c, false, 100)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 252, 6, W - 6, 352, 8, col(c[:panel], 240), c[:line])
tabs(c, 256, 12, 250, 1)
DAYCARE.each_with_index do |(sp, name, lv, gain), i|
  y = 46 + i * 46
  mon_icon(t, sp, 280, y + 20, 38)
  P.text(t, 302, y + 2, 190, 18, "#{name}  Lv #{lv}", c[:txt], PF::TEXT)
  P.text(t, 302, y + 22, 190, 14, gain, GREEN, PF::TINY)
end
P.text(t, 262, 142, 240, 14, "THEY SEEM TO GET ALONG", PINK, PF::TINY)
cursor_at(258, 162, W - 270, 50)
egg_icon(t, 280, 186, 34)
P.text(t, 302, 166, 190, 18, "Egg Waiting", GOLD, PF::TEXT)
P.small(t, 302, 186, 196, 15, "Party Full? Incubator 3", c[:dim])
["Collect", "Discard", "Deposit", "Take Back"].each_with_index do |l, i|
  bx = 262 + (i % 2) * 120; by = 230 + (i / 2) * 30
  UI.rbox(b, bx, by, bx + 112, by + 24, 5, i == 0 ? c[:selb] : c[:dark], i == 0 ? nil : c[:line])
  P.text(t, bx, by, 112, 24, l, i == 0 ? c[:dark] : c[:txt], PF::TEXT, 2)
end
hints(c, H_DC)
dump_as("E5_daycare")
puts "done"
