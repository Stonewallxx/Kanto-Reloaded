# encoding: utf-8
# Mockups: five Overworld Menu layouts. Design 1 = the old KR/HR layout in
# our UI kit; 2-5 are new takes. Each shows the same features: entries with
# statuses (Quick Items, PokeVial, Heal with Moves, Fly, Repel, Egg Manager,
# Wild Link, Time Changer, Quick Save), the pages (Main, Toggles, Info),
# Party View, and the Weather/Area panel.
# Usage: ruby ow_designs.rb "<KIF Beta>" <work dir with metrics.json>
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

#---------------------------------------------------------------- content
# [icon file, label, status]
ENTRIES = [["hr:BAG", "Quick Items", "4"], ["hr:POKEVIAL", "PokeVial", "3/5"], ["item:MAXPOTION", "Heal with Moves", "2"],
           ["item:TOWNMAP", "Fly", ""], ["item:REPEL", "Repel", "142"], ["item:OVALCHARM", "Egg Manager", "2 Eggs"],
           ["item:POKERADAR", "Wild Link", "Abra"], ["item:MOONSTONE", "Time Changer", "Day"], ["hr:SAVE", "Quick Save", ""]]
PAGES = ["Main", "Toggles", "Info"]
# [species, name, level, hp, total, [type ids]]; nil species = an Egg
PARTY = [["PIKACHU", "Pikachu", 34, 78, 95, [13]], ["GYARADOS", "Gyarados", 36, 120, 120, [11, 2]],
         ["GENGAR", "Gengar", 35, 40, 110, [7, 3]], ["ALAKAZAM", "Alakazam", 33, 15, 90, [14]],
         ["SNORLAX", "Snorlax", 34, 160, 160, [0]], [nil, "Egg"]]
SEL = 1
GREEN = Color.new(120, 230, 150); YELLOW = Color.new(240, 200, 70); RED = Color.new(240, 100, 90)
GOLD = Color.new(240, 200, 70)
A_BTN = "p:0"; B_BTN = "p:1"; X_BTN = "p:2"; Y_BTN = "p:3"
WEATHER = ["Cerulean City", "Rain from 6 PM", "Here: 3 of 7 Caught"]

def palette(theme)
  Reloaded::Settings.set(:"interface.theme", theme)
  return Reloaded::Palette.current
end
def col(c, a); Color.new(c.red, c.green, c.blue, a); end

#---------------------------------------------------------------- layers
$vp = Viewport.new(0, 0, W, H)
$vp.z = 99_999
def layer(z); s = Sprite.new($vp); s.bitmap = Bitmap.new(W, H); s.z = z; s; end
MAPS = Sprite.new($vp); MAPS.z = -1
MAPS.bitmap = Bitmap.new(File.join(HERE, "backdrop.png"))
BASE = layer(0)
CUR = Sprite.new($vp); CUR.z = 1
TOP = layer(2)

def frame(c, dim = 0)
  BASE.bitmap.clear; TOP.bitmap.clear
  CUR.visible = false
  BASE.bitmap.fill_rect(0, 0, W, H, Color.new(c[:bg].red, c[:bg].green, c[:bg].blue, dim)) if dim > 0
end

def cursor_at(x, y, w, h)
  CUR.bitmap = P.cursor_bitmap(w, h)
  CUR.x = x; CUR.y = y; CUR.opacity = 210; CUR.visible = true
end

$bmps = {}
def bmp(path); $bmps[path] ||= Bitmap.new(path); end
def icon_path(spec)
  kind, name = spec.split(":")
  kind == "hr" ? File.join(HERE, "icons", name + ".png") : File.join(GFX, "Items", name + ".png")
end

# An image fitted in a size x size box centred on cx, cy (src: a Rect or nil)
def draw_img(b, path, cx, cy, size, src = nil)
  i = bmp(path)
  src ||= Rect.new(0, 0, i.width, i.height)
  sc = size.to_f / [src.width, src.height].max
  w = (src.width * sc).round; h = (src.height * sc).round
  b.stretch_blt(Rect.new(cx - w / 2, cy - h / 2, w, h), i, src)
end
def draw_icon(b, spec, cx, cy, size); draw_img(b, icon_path(spec), cx, cy, size); end
def mon_icon(b, species, cx, cy, size)
  path = species ? File.join(GFX, "Pokemon/Icons/#{species}.png") : File.join(GFX, "Pokemon/Eggs/000_icon.png")
  draw_img(b, path, cx, cy, size, Rect.new(0, 0, 64, 64))
end
def type_icon(b, id, x, y, size = 14)
  b.stretch_blt(Rect.new(x, y, size, size), bmp(File.join(GFX, "Pictures/Battle/typesSmall.png")), Rect.new(0, id * 19, 19, 19))
end

def stext(b, x, y, w, h, str, color, font, align, c)
  P.text(b, x + 1, y + 1, w, h, str, c[:shadow], font, align)
  P.text(b, x, y, w, h, str, color, font, align)
end
def panel(b, x0, y0, x1, y1, c, alpha = 228, r = 6)
  UI.rbox(b, x0, y0, x1, y1, r, col(c[:panel], alpha), c[:line])
end
def hp_color(hp, tot); f = hp.to_f / tot; f > 0.5 ? GREEN : (f > 0.25 ? YELLOW : RED); end
def hp_bar(b, x, y, w, hp, tot, c, h = 4)
  b.fill_rect(x, y, w, h, c[:dark])
  b.fill_rect(x, y, (w * hp.to_f / tot).round, h, hp_color(hp, tot))
end
def hints(c, pairs); P.hints(BASE.bitmap, TOP.bitmap, c, pairs, $style); end
H_LIST = [[:ud, "Choose"], [:lr, "Pages"], [A_BTN, "Use"], [Y_BTN, "Party View"], [B_BTN, "Close"]]

# Page tabs: Main / Toggles / Info, the current one lit
def page_tabs(c, x, y, w, current = 0)
  tw = w / PAGES.length
  PAGES.each_with_index do |pg, i|
    on = i == current
    UI.rbox(BASE.bitmap, x + i * tw + 1, y, x + (i + 1) * tw - 2, y + 17, 4, on ? c[:sel] : col(c[:panel2], 230), on ? c[:selb] : nil)
    P.text(TOP.bitmap, x + i * tw, y, tw, 18, pg.upcase, on ? c[:white] : c[:dim], PF::TINY, 2)
  end
end

# The weather / area info lines
def weather_box(c, x, y, w, h)
  panel(BASE.bitmap, x, y, x + w - 1, y + h - 1, c)
  draw_icon(TOP.bitmap, "item:DAMPROCK", x + 20, y + h / 2, 26)
  P.text(TOP.bitmap, x + 38, y + 4, w - 42, 16, WEATHER[0], c[:txt], PF::TEXT)
  P.small(TOP.bitmap, x + 38, y + 20, w - 42, 14, WEATHER[1], c[:acc])
  P.small(TOP.bitmap, x + 38, y + 34, w - 42, 14, WEATHER[2], c[:dim]) if h > 48
end

def dump_as(name); dump(name); puts "wrote #{name}"; end

#================================================================ O1 Recommended: the old layout, rebuilt
c = palette(2)
frame(c)
base = BASE.bitmap; top = TOP.bitmap
# the menu panel, top right (old: 182 wide, header, rows with statuses)
mx = 312; mw = 197; row_h = 22
panel(base, mx, 3, mx + mw - 1, 3 + 26 + ENTRIES.length * row_h + 18, c)
stext(top, mx, 4, mw, 22, "Overworld Menu", c[:title], PF::ROW, 2, c)
UI.tri(top, mx + 8, 11, :l, c[:dim], 3); UI.tri(top, mx + mw - 12, 11, :r, c[:dim], 3)
base.fill_rect(mx + 8, 27, mw - 16, 1, c[:line])
ENTRIES.each_with_index do |(ic, label, status), i|
  y = 30 + i * row_h
  cursor_at(mx + 4, y, mw - 8, row_h - 1) if i == SEL
  P.text(top, mx + 12, y, mw - 70, row_h - 1, label, i == SEL ? c[:white] : c[:txt], PF::TEXT)
  P.text(top, mx + mw - 74, y, 62, row_h - 1, status, GREEN, PF::TEXT, 1) unless status.empty?
end
P.text(top, mx, 30 + ENTRIES.length * row_h + 2, mw, 12, "MAIN  1/3", c[:dim], PF::TINY, 2)
weather_box(c, mx, 256, mw, 52)
# the party panel, left (old: 2 columns x 3 slots, 71 px)
pw = 300; sw = (pw - 12) / 2; sh = 76
panel(base, 3, 3, 3 + pw - 1, 3 + 26 + 3 * sh + 6, c)
stext(top, 3, 4, pw, 22, "Party", c[:title], PF::ROW, 2, c)
base.fill_rect(11, 27, pw - 16, 1, c[:line])
PARTY.each_with_index do |(sp, name, lv, hp, tot, types), i|
  sx = 8 + (i % 2) * (sw + 2); sy = 31 + (i / 2) * sh
  UI.rbox(base, sx, sy, sx + sw - 1, sy + sh - 4, 4, col(c[:panel2], 240))
  mon_icon(top, sp, sx + 30, sy + 34, 56)
  lx = sx + 60; tw = sw - 64
  if sp.nil?
    P.text(top, lx, sy + 26, tw, 18, "Egg", c[:dim], PF::TEXT)
    P.small(top, lx, sy + 44, tw, 14, "Hatches Soon", c[:dim])
    next
  end
  P.text(top, lx, sy + 4, tw, 16, name, c[:txt], PF::TEXT)
  P.text(top, lx, sy + 22, 40, 14, "Lv #{lv}", GOLD, PF::TINY)
  types.each_with_index { |t, k| type_icon(top, t, lx + 38 + k * 16, sy + 22) }
  hp_bar(base, lx, sy + 41, tw - 4, hp, tot, c)
  P.text(top, lx, sy + 49, tw, 14, "#{hp}/#{tot}", hp_color(hp, tot), PF::TINY)
end
hints(c, H_LIST)
dump_as("O1_recommended")

#================================================================ O2 Hotbar
frame(c)
base = BASE.bitmap; top = TOP.bitmap
# info chips, top left
chips = [["item:DAMPROCK", "Rain from 6 PM"], ["item:MOONSTONE", "Day"], ["item:REPEL", "142 Steps"], ["item:POKERADAR", "3 of 7 Caught"]]
x = 6
chips.each do |ic, t|
  w = P.width(PF::TEXT, t) + 34
  panel(base, x, 6, x + w, 30, c, 220, 12)
  draw_icon(top, ic, x + 14, 18, 18)
  P.text(top, x + 26, 6, w - 28, 24, t, c[:txt], PF::TEXT)
  x += w + 6
end
# the hotbar: page tabs, then the entries as buttons
page_tabs(c, 106, 222, 300)
bw = 54; gap = 2
x0 = (W - (ENTRIES.length * bw + (ENTRIES.length - 1) * gap)) / 2
panel(base, x0 - 6, 244, x0 + ENTRIES.length * (bw + gap) - gap + 5, 306, c, 232, 8)
ENTRIES.each_with_index do |(ic, label, status), i|
  bx = x0 + i * (bw + gap)
  cursor_at(bx, 248, bw, 54) if i == SEL
  draw_icon(top, ic, bx + bw / 2, 266, 26)
  P.text(top, bx, 284, bw, 12, PF.fit(PF::TINY, label, bw - 2), i == SEL ? c[:white] : c[:dim], PF::TINY, 2)
  unless status.empty?
    a = GREEN
    P.pill(top, bx + bw - 1, 249, status, Color.new(a.red / 4, a.green / 4, a.blue / 4), a)
  end
end
stext(top, 0, 196, W, 24, ENTRIES[SEL][1], c[:title], PF::ROW, 2, c)
# the party strip
pw = 82
PARTY.each_with_index do |(sp, name, lv, hp, tot, types), i|
  px = 6 + i * (pw + 2)
  panel(base, px, 312, px + pw - 1, 354, c, 228, 6)
  mon_icon(top, sp, px + 20, 333, 40)
  if sp
    P.text(top, px + 40, 318, 40, 12, "Lv #{lv}", GOLD, PF::TINY)
    hp_bar(base, px + 40, 334, 36, hp, tot, c)
    P.text(top, px + 40, 340, 40, 12, "#{hp}", hp_color(hp, tot), PF::TINY)
  else
    P.text(top, px + 40, 326, 40, 12, "EGG", c[:dim], PF::TINY)
  end
end
hints(c, [[:lr, "Choose"], [:ud, "Pages"], [A_BTN, "Use"], [Y_BTN, "Party View"], [B_BTN, "Close"]])
dump_as("O2_hotbar")

#================================================================ O3 Ring
frame(c, 110)
base = BASE.bitmap; top = TOP.bitmap
cx = 256; cy = 196; rad = 96
n = 8
ring = ENTRIES.first(8)
ring.each_with_index do |(ic, label, status), i|
  ang = -Math::PI / 2 + i * 2 * Math::PI / n
  ex = (cx + rad * Math.cos(ang)).round; ey = (cy + rad * Math.sin(ang)).round
  s = i == SEL ? 50 : 40
  UI.rbox(base, ex - s / 2, ey - s / 2, ex + s / 2, ey + s / 2, s / 2, col(c[:panel], 235), i == SEL ? c[:selb] : c[:line])
  cursor_at(ex - s / 2, ey - s / 2, s + 1, s + 1) if i == SEL
  draw_icon(top, ic, ex, ey, (s * 0.62).round)
  unless status.empty?
    a = GREEN
    P.pill(top, ex + s / 2 + 6, ey + s / 2 - 12, status, Color.new(a.red / 4, a.green / 4, a.blue / 4), a)
  end
end
UI.rbox(base, cx - 58, 52, cx + 58, 72, 6, col(c[:panel2], 240), c[:line])
P.text(top, cx - 58, 52, 116, 20, ENTRIES[SEL][1], c[:white], PF::TEXT, 2)
stext(top, 0, 6, W, 24, "Overworld Menu", c[:title], PF::ROW, 2, c)
page_tabs(c, 176, 32, 160)
# ninth entry (Quick Save) sits on its own key
w = BI.width(X_BTN, $style)
panel(base, cx - 60, 326, cx + 60, 352, c)
BI.draw(top, cx - 52, 331, X_BTN, c, $style)
P.text(top, cx - 52 + w + 6, 326, 100, 26, "Quick Save", c[:txt], PF::TEXT)
# party column, left; weather, right
panel(base, 4, 40, 112, 352, c)
P.text(top, 4, 44, 108, 12, "PARTY", c[:head], PF::TINY, 2)
PARTY.each_with_index do |(sp, name, lv, hp, tot, types), i|
  py = 60 + i * 48
  mon_icon(top, sp, 28, py + 20, 40)
  if sp
    P.text(top, 50, py + 4, 60, 12, "Lv #{lv}", GOLD, PF::TINY)
    hp_bar(base, 50, py + 20, 54, hp, tot, c)
    P.text(top, 50, py + 26, 60, 12, "#{hp}/#{tot}", hp_color(hp, tot), PF::TINY)
  else
    P.text(top, 50, py + 12, 60, 12, "EGG", c[:dim], PF::TINY)
  end
end
weather_box(c, 338, 40, 170, 60)
hints(c, [[:ud, "Choose"], [:lr, "Choose"], [A_BTN, "Use"], [X_BTN, "Quick Save"], [B_BTN, "Close"]])
dump_as("O3_ring")

#================================================================ O4 Tabbed Side Panel
frame(c)
base = BASE.bitmap; top = TOP.bitmap
px0 = 4; pw = 220
panel(base, px0, 4, px0 + pw - 1, 296, c, 235)
stext(top, px0, 6, pw, 22, "Overworld Menu", c[:title], PF::ROW, 2, c)
page_tabs(c, px0 + 8, 30, pw - 16)
ENTRIES.each_with_index do |(ic, label, status), i|
  y = 52 + i * 26
  cursor_at(px0 + 5, y, pw - 10, 25) if i == SEL
  draw_icon(top, ic, px0 + 20, y + 12, 20)
  P.text(top, px0 + 36, y, 120, 25, label, i == SEL ? c[:white] : c[:txt], PF::TEXT)
  P.text(top, px0 + pw - 70, y, 60, 25, status, GREEN, PF::TEXT, 1) unless status.empty?
end
weather_box(c, W - 186, 4, 182, 52)
# party along the bottom, right of the panel
PARTY.each_with_index do |(sp, name, lv, hp, tot, types), i|
  cw = 90; chh = 56
  px = W - 4 - 3 * (cw + 4) + 4 + (i % 3) * (cw + 4); py = 238 + (i / 3) * (chh + 4)
  panel(base, px, py, px + cw - 1, py + chh - 1, c, 228, 6)
  mon_icon(top, sp, px + 22, py + 28, 44)
  if sp
    P.text(top, px + 44, py + 5, 48, 12, PF.fit(PF::TINY, name, 48), c[:txt], PF::TINY)
    P.text(top, px + 44, py + 19, 48, 12, "Lv #{lv}", GOLD, PF::TINY)
    hp_bar(base, px + 44, py + 35, 44, hp, tot, c)
    P.text(top, px + 44, py + 41, 48, 12, "#{hp}/#{tot}", hp_color(hp, tot), PF::TINY)
  else
    P.text(top, px + 44, py + 22, 48, 12, "EGG", c[:dim], PF::TINY)
  end
end
panel(base, px0, 302, px0 + pw - 1, 352, c, 235)
P.text(top, px0 + 10, 306, 120, 12, "QUICK ITEMS", c[:head], PF::TINY)
["item:SUPERROD", "item:BICYCLE", "item:ITEMFINDER", "item:ESCAPEROPE"].each_with_index do |ic, k|
  draw_icon(top, ic, px0 + 30 + k * 48, 334, 28)
end
hints(c, H_LIST)
dump_as("O4_tabbed_panel")

#================================================================ O5 Quick Grid
frame(c, 90)
base = BASE.bitmap; top = TOP.bitmap
gx = 270; tile_w = 76; tile_h = 70; gap = 4
panel(base, gx - 6, 4, W - 4, 4 + 26 + 3 * (tile_h + gap) + 20, c, 235)
stext(top, gx - 6, 6, W - gx + 2, 22, "Overworld Menu", c[:title], PF::ROW, 2, c)
ENTRIES.each_with_index do |(ic, label, status), i|
  tx = gx + (i % 3) * (tile_w + gap); ty = 30 + (i / 3) * (tile_h + gap)
  UI.rbox(base, tx, ty, tx + tile_w - 1, ty + tile_h - 1, 6, col(c[:panel2], 240), c[:line])
  cursor_at(tx, ty, tile_w, tile_h) if i == SEL
  draw_icon(top, ic, tx + tile_w / 2, ty + 28, 32)
  P.text(top, tx, ty + tile_h - 18, tile_w, 14, PF.fit(PF::TINY, label, tile_w - 4), i == SEL ? c[:white] : c[:txt], PF::TINY, 2)
  unless status.empty?
    a = GREEN
    P.pill(top, tx + tile_w - 3, ty + 3, status, Color.new(a.red / 4, a.green / 4, a.blue / 4), a)
  end
end
dy = 30 + 3 * (tile_h + gap) + 2
PAGES.each_with_index do |pg, i|
  dx = (gx - 6 + W - 4) / 2 - 24 + i * 24
  UI.rbox(base, dx - 4, dy + 4, dx + 4, dy + 12, 4, i == 0 ? c[:acc] : c[:line])
end
weather_box(c, gx - 6, 288, W - gx + 2, 64)
panel(base, 4, 4, 160, 352, c, 235)
P.text(top, 4, 8, 156, 12, "PARTY", c[:head], PF::TINY, 2)
PARTY.each_with_index do |(sp, name, lv, hp, tot, types), i|
  py = 24 + i * 54
  UI.rbox(base, 9, py, 155, py + 50, 4, col(c[:panel2], 240))
  mon_icon(top, sp, 32, py + 25, 46)
  if sp
    P.text(top, 56, py + 3, 96, 16, name, c[:txt], PF::TEXT)
    P.text(top, 56, py + 20, 40, 12, "Lv #{lv}", GOLD, PF::TINY)
    types.each_with_index { |t, k| type_icon(top, t, 96 + k * 16, py + 19, 13) }
    hp_bar(base, 56, py + 36, 92, hp, tot, c)
    P.text(top, 56, py + 40, 96, 12, "", c[:dim], PF::TINY)
  else
    P.text(top, 56, py + 16, 96, 16, "Egg", c[:dim], PF::TEXT)
  end
end
hints(c, [[:ud, "Choose"], [:lr, "Choose"], ["p:4", "Pages"], [A_BTN, "Use"], [B_BTN, "Close"]])
dump_as("O5_quick_grid")
puts "done"
