# encoding: utf-8
# Mockups: five Bag designs. Design 1 = HR's Reloaded Bag in our UI kit; 2-5
# are new takes. Each shows: 8 pockets (NEW dots), the TMs & HMs list with type
# colours, NEW and Favourite marks, the selected item's description, TM Party
# Check, Search and Sort, and the item actions (incl. Add to Quick Items).
# Usage: ruby bag_designs.rb "<KIF Beta>" <work dir with metrics.json>
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

POCKETS = ["Items", "Medicine", "Poké Balls", "TMs & HMs", "Berries", "Mail", "Battle Items", "Key Items"]
POCKET_NEW = [1, 3]
CUR_POCKET = 3
# [label, move, type name, type id, new, fav]
TMS = [["TM06", "Toxic", "POISON", 3], ["TM13", "Ice Beam", "ICE", 15, true], ["TM24", "Thunderbolt", "ELECTRIC", 13, false, true],
       ["TM26", "Earthquake", "GROUND", 4], ["TM29", "Psychic", "PSYCHIC", 14], ["TM35", "Flamethrower", "FIRE", 10],
       ["TM44", "Rest", "PSYCHIC", 14], ["HM01", "Cut", "NORMAL", 0], ["HM03", "Surf", "WATER", 11]]
SEL = 2
DESC = "Fires a strong electric blast. It may also leave the target with paralysis."
STATS = "Electric · Special · Power 90 · Accuracy 100"
# party check: [species, name, :knows / :learn / :no]
CHECK = [["PIKACHU", "Pikachu", :knows], ["GYARADOS", "Gyarados", :no], ["GENGAR", "Gengar", :learn],
         ["ALAKAZAM", "Alakazam", :no], ["SNORLAX", "Snorlax", :learn]]
ACTIONS = ["Use", "Give", "Favourite", "Add to Quick Items", "Toss"]
TYPE_COLORS = { 0 => [200, 200, 180], 3 => [190, 120, 220], 4 => [225, 190, 110], 10 => [245, 140, 90], 11 => [110, 160, 245],
                13 => [245, 215, 70], 14 => [245, 110, 160], 15 => [140, 220, 230] }
GREEN = Color.new(120, 230, 150); GOLD = Color.new(240, 200, 70); BLUE = Color.new(130, 190, 250); NEWC = Color.new(110, 230, 110)
A_BTN = "p:0"; B_BTN = "p:1"; X_BTN = "p:2"; Y_BTN = "p:3"

def palette(theme)
  Reloaded::Settings.set(:"interface.theme", theme)
  return Reloaded::Palette.current
end
def col(c, a); Color.new(c.red, c.green, c.blue, a); end
def tcol(id); Color.new(*(TYPE_COLORS[id] || [220, 220, 220])); end

$vp = Viewport.new(0, 0, W, H)
$vp.z = 99_999
def layer(z); s = Sprite.new($vp); s.bitmap = Bitmap.new(W, H); s.z = z; s; end
BASE = layer(0)
CUR = Sprite.new($vp); CUR.z = 1
TOP = layer(2)
OVER = layer(3)
def frame(c)
  BASE.bitmap.clear; TOP.bitmap.clear; OVER.bitmap.clear
  CUR.visible = false
  BASE.bitmap.fill_rect(0, 0, W, H, c[:bg])
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
def tm_icon(b, tm, cx, cy, size)
  name = tm[0].start_with?("HM") ? "machine_hm_#{tm[2]}" : "machine_#{tm[2]}"
  path = File.join(GFX, "Items", name + ".png")
  path = File.join(GFX, "Items", "machine_#{tm[2]}.png") unless File.file?(path)
  draw_img(b, path, cx, cy, size)
end
def pocket_icon(b, i, cx, cy, size = 28)
  draw_img(b, File.join(GFX, "Pictures/Bag/icon_pocket.png"), cx, cy, size, Rect.new(i * 28, 0, 28, 28))
end
def mon_icon(b, species, cx, cy, size)
  draw_img(b, File.join(GFX, "Pokemon/Icons/#{species}.png"), cx, cy, size, Rect.new(0, 0, 64, 64))
end
def type_icon(b, id, x, y, size = 16)
  b.stretch_blt(Rect.new(x, y, size, size), bmp(File.join(GFX, "Pictures/Battle/typesSmall.png")), Rect.new(0, id * 19, 19, 19))
end
def star(b, x, y, color)
  ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", "##...##"].each_with_index { |row, j| row.each_char.with_index { |ch, i| b.fill_rect(x + i, y + j, 1, 1, color) if ch == "#" } }
end
def badge(b, x, y, text, color); P.pill(b, x, y, text, Color.new(color.red / 4, color.green / 4, color.blue / 4), color, false); end
def magnifier(base, ix, iy, fg, hole)
  UI.rbox(base, ix, iy, ix + 9, iy + 9, 4, fg)
  UI.rbox(base, ix + 2, iy + 2, ix + 7, iy + 7, 2, hole)
  3.times { |i| base.fill_rect(ix + 8 + i, iy + 8 + i, 2, 2, fg) }
end
# Title bar: Search box left, title centred, Sort box right (keys beside them)
def title_bar(c, title, h = 32)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, h, c[:panel2]); b.fill_rect(0, h - 1, W, 1, c[:line])
  P.text(t, 0, 2, W, h - 4, title, c[:title], PF::TITLE, 2)
  UI.rbox(b, 8, 4, 120, h - 5, 5, c[:dark], c[:line])
  magnifier(b, 28, 10, c[:dim], c[:dark])
  P.text(t, 44, 4, 70, h - 9, "Search", c[:dim])
  BI.draw(t, 126, 8, "p:9", c, $style)
  UI.rbox(b, W - 120, 4, W - 8, h - 5, 5, c[:dark], c[:line])
  P.text(t, W - 120, 4, 112, h - 9, "Sort: Default", c[:dim], PF::TEXT, 2)
  BI.draw(t, W - 126 - BI.width("p:10", $style), 8, "p:10", c, $style)
end
def party_check(c, x, y, w, size = 30, names = false)
  t = TOP.bitmap
  step = w / CHECK.length
  CHECK.each_with_index do |(sp, name, st), i|
    cx = x + i * step + step / 2
    mon_icon(t, sp, cx, y + size / 2, size)
    label, color = { :knows => ["Knows It", BLUE], :learn => ["Can Learn", GREEN], :no => ["Can't", c[:dim]] }[st]
    P.text(t, x + i * step, y + size, step, 12, names ? "#{label}" : label, color, PF::TINY, 2)
  end
end
def hints(c, pairs); P.hints(BASE.bitmap, TOP.bitmap, c, pairs, $style); end
H_MAIN = [[:ud, "Choose"], [:lr, "Pockets"], [A_BTN, "Use"], [X_BTN, "Actions"], [Y_BTN, "Favourite"], [B_BTN, "Close"]]
def dump_as(name); dump(name); puts "wrote #{name}"; end

c = palette(2)

#================================================================ B1 Recommended: HR's Reloaded Bag, rebuilt
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title_bar(c, "Bag")
# pocket bar: name, position, arrows, and pocket icons with NEW dots
b.fill_rect(0, 32, W, 26, c[:panel]); b.fill_rect(0, 57, W, 1, c[:line])
POCKETS.each_with_index do |pn, i|
  px = 12 + i * 30
  pocket_icon(t, i, px + 12, 45, i == CUR_POCKET ? 24 : 18)
  UI.rbox(b, px + 20, 36, px + 24, 40, 2, NEWC) if POCKET_NEW.include?(i)
end
P.text(t, 260, 33, 240, 24, "TMs & HMs  4/8", c[:txt], PF::TEXT, 1)
UI.tri(t, 254, 41, :l, c[:dim], 4); UI.tri(t, W - 10, 41, :r, c[:dim], 4)
# list
rh = 22
TMS.first(8).each_with_index do |tm, i|
  y = 62 + i * rh
  cursor_at(6, y, W - 12, rh - 1) if i == SEL
  star(t, 12, y + 7, GOLD) if tm[5]
  P.text(t, 24, y, 48, rh - 1, tm[0], c[:dim], PF::TEXT)
  P.text(t, 72, y, 200, rh - 1, tm[1], tm[5] ? GOLD : tcol(tm[3]), PF::TEXT)
  badge(t, 300, y + 3, "NEW", NEWC) if tm[4]
  type_icon(t, tm[3], W - 30, y + 3)
end
# info panel
y0 = 240
b.fill_rect(0, y0, W, 119, c[:panel2]); b.fill_rect(0, y0, W, 1, c[:line])
UI.rbox(b, W - 96, y0 + 8, W - 10, y0 + 70, 6, c[:dark], c[:line])
tm_icon(t, TMS[SEL], W - 53, y0 + 39, 48)
P.text(t, 12, y0 + 4, 300, 22, "TM24 Thunderbolt", GOLD, PF::ROW)
P.small(t, 12, y0 + 26, 380, 16, STATS, c[:acc])
P.small_wrap(t, DESC, 380).first(2).each_with_index { |ln, k| P.small(t, 12, y0 + 42 + k * 17, 380, 17, ln, c[:txt]) }
P.text(t, 12, y0 + 79, 120, 12, "PARTY", c[:head], PF::TINY)
party_check(c, 60, y0 + 76, 380, 26)
hints(c, H_MAIN)
dump_as("B1_recommended")

#================================================================ B2 Pocket Sidebar
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title_bar(c, "Bag")
UI.rbox(b, 6, 36, 150, 354, 6, c[:panel])
POCKETS.each_with_index do |pn, i|
  y = 42 + i * 38
  cursor_at(9, y, 138, 35) if false
  UI.rbox(b, 10, y, 146, y + 34, 5, c[:sel], c[:selb]) if i == CUR_POCKET
  pocket_icon(t, i, 28, y + 17, 26)
  P.text(t, 46, y, 96, 34, pn, i == CUR_POCKET ? c[:white] : c[:txt], PF::TEXT)
  UI.rbox(b, 138, y + 6, 142, y + 10, 2, NEWC) if POCKET_NEW.include?(i)
end
UI.rbox(b, 156, 36, 320, 354, 6, c[:panel])
TMS.each_with_index do |tm, i|
  y = 42 + i * 34
  cursor_at(159, y, 158, 32) if i == SEL
  tm_icon(t, tm, 176, y + 16, 26)
  P.text(t, 194, y - 1, 120, 18, tm[1], tm[5] ? GOLD : c[:txt], PF::TEXT)
  P.text(t, 194, y + 16, 60, 12, tm[0], c[:dim], PF::TINY)
  star(t, 304, y + 4, GOLD) if tm[5]
  badge(t, 276, y + 16, "NEW", NEWC) if tm[4]
end
UI.rbox(b, 326, 36, W - 6, 354, 6, c[:panel])
UI.rbox(b, 370, 44, 462, 116, 8, c[:dark], c[:line])
tm_icon(t, TMS[SEL], 416, 80, 56)
P.text(t, 326, 120, W - 332, 22, "Thunderbolt", GOLD, PF::ROW, 2)
type_icon(t, 13, 384, 146); P.text(t, 404, 144, 60, 18, "TM24", c[:dim], PF::TEXT)
P.small(t, 332, 166, 174, 15, "Power 90 · Accuracy 100", c[:acc], 2)
P.small_wrap(t, DESC, 166).first(4).each_with_index { |ln, k| P.small(t, 336, 184 + k * 16, 166, 16, ln, c[:txt]) }
P.heading(t, 336, W - 14, 254, "Party", c[:head], c[:line])
CHECK.each_with_index do |(sp, name, st), i|
  cx = 344 + (i % 3) * 54 + 20; cy = 268 + (i / 3) * 42
  mon_icon(t, sp, cx, cy + 12, 30)
  label, color = { :knows => ["Knows", BLUE], :learn => ["Learns", GREEN], :no => ["Can't", c[:dim]] }[st]
  P.text(t, cx - 24, cy + 26, 48, 12, label, color, PF::TINY, 2)
end
hints(c, [[:ud, "Choose"], [:lr, "Pockets"], [A_BTN, "Use"], [X_BTN, "Actions"], [B_BTN, "Close"]])
dump_as("B2_pocket_sidebar")

#================================================================ B3 Icon Grid
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title_bar(c, "Bag")
POCKETS.each_with_index do |pn, i|
  px = 14 + i * 62
  on = i == CUR_POCKET
  UI.rbox(b, px, 38, px + 56, 70, 6, on ? c[:sel] : c[:panel], on ? c[:selb] : nil)
  pocket_icon(t, i, px + 28, 54, on ? 26 : 22)
  UI.rbox(b, px + 48, 41, px + 52, 45, 2, NEWC) if POCKET_NEW.include?(i)
end
P.text(t, 0, 72, W, 16, "TMS & HMS", c[:head], PF::TINY, 2)
gw = 92; gh = 66
TMS.each_with_index do |tm, i|
  gx = 18 + (i % 5) * (gw + 4); gy = 90 + (i / 5) * (gh + 4)
  UI.rbox(b, gx, gy, gx + gw - 1, gy + gh - 1, 6, c[:panel], c[:line])
  cursor_at(gx, gy, gw, gh) if i == SEL
  tm_icon(t, tm, gx + gw / 2, gy + 24, 34)
  P.text(t, gx, gy + gh - 20, gw, 16, PF.fit(PF::TINY, tm[1], gw - 6), tm[5] ? GOLD : c[:txt], PF::TINY, 2)
  star(t, gx + 5, gy + 5, GOLD) if tm[5]
  badge(t, gx + gw - 30, gy + 4, "NEW", NEWC) if tm[4]
end
UI.rbox(b, 6, 236, W - 6, 354, 6, c[:panel2], c[:line])
P.text(t, 16, 240, 300, 22, "TM24 Thunderbolt", GOLD, PF::ROW)
type_icon(t, 13, W - 34, 244)
P.small(t, 16, 262, 480, 16, STATS, c[:acc])
P.small_wrap(t, DESC, 440).first(2).each_with_index { |ln, k| P.small(t, 16, 278 + k * 16, 440, 16, ln, c[:txt]) }
P.text(t, 16, 314, 80, 12, "PARTY", c[:head], PF::TINY)
party_check(c, 70, 308, 420, 26)
hints(c, [[:ud, "Choose"], [:lr, "Choose"], ["p:4", "Pockets"], [A_BTN, "Use"], [X_BTN, "Actions"], [B_BTN, "Close"]])
dump_as("B3_icon_grid")

#================================================================ B4 Classic (PIF's layout, themed)
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title_bar(c, "Bag")
UI.rbox(b, 6, 36, 182, 250, 6, c[:panel])
draw_img(t, File.join(GFX, "Pictures/Bag/bag_4.PNG"), 94, 120, 128)
UI.tri(t, 18, 214, :l, c[:dim], 4); UI.tri(t, 166, 214, :r, c[:dim], 4)
P.text(t, 6, 204, 176, 22, "TMs & HMs", c[:txt], PF::ROW, 2)
POCKETS.each_with_index do |pn, i|
  dx = 38 + i * 15
  UI.rbox(b, dx, 232, dx + 8, 240, 4, i == CUR_POCKET ? c[:acc] : c[:line])
end
UI.rbox(b, 188, 36, W - 6, 250, 6, c[:panel])
TMS.first(8).each_with_index do |tm, i|
  y = 42 + i * 26
  cursor_at(191, y, W - 200, 25) if i == SEL
  tm_icon(t, tm, 206, y + 12, 20)
  P.text(t, 222, y, 160, 25, "#{tm[0]} #{tm[1]}", tm[5] ? GOLD : c[:txt], PF::TEXT)
  badge(t, 410, y + 5, "NEW", NEWC) if tm[4]
  star(t, 420, y + 9, GOLD) if tm[5]
  type_icon(t, tm[3], W - 30, y + 4)
end
UI.rbox(b, 6, 256, W - 6, 354, 6, c[:panel2], c[:line])
tm_icon(t, TMS[SEL], 34, 288, 40)
P.small(t, 62, 262, 300, 16, STATS, c[:acc])
P.small_wrap(t, DESC, 300).first(2).each_with_index { |ln, k| P.small(t, 62, 278 + k * 17, 300, 17, ln, c[:txt]) }
UI.rbox(b, 370, 262, W - 12, 348, 5, c[:dark])
CHECK.each_with_index do |(sp, name, st), i|
  cx = 386 + (i % 3) * 40; cy = 270 + (i / 3) * 40
  mon_icon(t, sp, cx, cy + 10, 26)
  label, color = { :knows => ["Knows", BLUE], :learn => ["Learns", GREEN], :no => ["Can't", c[:dim]] }[st]
  P.text(t, cx - 20, cy + 22, 40, 12, label, color, PF::TINY, 2)
end
hints(c, H_MAIN)
dump_as("B4_classic")

#================================================================ B5 Split Info with actions
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title_bar(c, "Bag")
b.fill_rect(0, 32, W, 24, c[:panel]); b.fill_rect(0, 55, W, 1, c[:line])
pw = W / POCKETS.length
POCKETS.each_with_index do |pn, i|
  on = i == CUR_POCKET
  b.fill_rect(i * pw, 53, pw, 3, c[:acc]) if on
  pocket_icon(t, i, i * pw + pw / 2, 43, on ? 20 : 16)
  UI.rbox(b, i * pw + pw / 2 + 9, 34, i * pw + pw / 2 + 13, 38, 2, NEWC) if POCKET_NEW.include?(i)
end
UI.rbox(b, 6, 60, 250, 354, 6, c[:panel])
P.text(t, 14, 62, 230, 14, "TMS & HMS", c[:head], PF::TINY)
TMS.each_with_index do |tm, i|
  y = 78 + i * 30
  cursor_at(9, y, 238, 28) if i == SEL
  tm_icon(t, tm, 26, y + 14, 22)
  P.text(t, 42, y, 150, 28, tm[1], tm[5] ? GOLD : c[:txt], PF::TEXT)
  star(t, 236, y + 11, GOLD) if tm[5]
  badge(t, 200, y + 7, "NEW", NEWC) if tm[4]
end
UI.rbox(b, 256, 60, W - 6, 354, 6, c[:panel])
tm_icon(t, TMS[SEL], 290, 94, 48)
P.text(t, 320, 70, 180, 22, "Thunderbolt", GOLD, PF::ROW)
type_icon(t, 13, 322, 96); P.text(t, 342, 94, 100, 18, "TM24", c[:dim], PF::TEXT)
P.small(t, 266, 122, 236, 16, "Power 90 · Accuracy 100", c[:acc])
P.small_wrap(t, DESC, 232).first(3).each_with_index { |ln, k| P.small(t, 266, 140 + k * 16, 232, 16, ln, c[:txt]) }
P.heading(t, 266, W - 16, 192, "Party", c[:head], c[:line])
party_check(c, 262, 204, 240, 30)
P.heading(t, 266, W - 16, 256, "Actions", c[:head], c[:line])
[["Use", 0], ["Give", 1], ["Favourite", 2], ["Toss", 3], ["Add to Quick Items", 4]].each do |a, i|
  full = i == 4
  bx = full ? 266 : 266 + (i % 2) * 118; by = 268 + (i / 2) * 28
  bw = full ? 230 : 112
  UI.rbox(b, bx, by, bx + bw, by + 23, 5, i == 0 ? c[:sel] : c[:dark], i == 0 ? c[:selb] : c[:line])
  P.text(t, bx, by, bw, 23, a, c[:txt], PF::TEXT, 2)
end
hints(c, [[:ud, "Choose"], [:lr, "Pockets"], [A_BTN, "Use"], [X_BTN, "Actions"], [Y_BTN, "Favourite"], [B_BTN, "Close"]])
dump_as("B5_split_actions")
puts "done"
