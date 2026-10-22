# encoding: utf-8
# Mockups: seven Reloaded Pause Menu layouts, each with everything Hoenn
# Reloaded's REPM shows: a title, Money, Location (map, day, time), a fixed
# row (Shop, TM Vault, PokeVial, PC), a row the player fills, a carousel of
# every entry, a Favourite, statuses, and button hints.
# Usage: ruby pause_designs.rb "<KIF Beta>" <work dir with metrics.json>
PREVIEW = File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
src = File.read(PREVIEW, :encoding => "UTF-8")
eval(src.split("#---------------------------------------------------------------- A: Ocean Blue")[0], binding, PREVIEW)

P = Reloaded::Pixel
BI = Reloaded::ButtonIcons
PF = KIF::PixelFont
UI = KIF::PixelUI
W = 512; H = 384
HERE = File.expand_path(File.dirname(__FILE__))
$style = :xbox

#---------------------------------------------------------------- content
FIXED = [["RELOADEDMART", "Shop"], ["TMVAULT", "TM Vault"], ["POKEVIAL", "PokeVial", "3/5"], ["PC", "PC"]]
CUSTOM = [["POKEDEX", "Pokédex"], ["TRAINERINFO", "Red"], ["GACHA", "Kuray Shop"], [nil, "Add"]]
ALL = [["POKEDEX", "Pokédex"], ["POKEMON", "Pokémon"], ["BAG", "Bag"], ["POKENAV", "PokéNav"],
       ["TRAINERINFO", "Red"], ["OUTFIT", "Outfit"], ["SAVE", "Save"], ["OPTIONS", "Options"],
       ["TITLE", "Quit"], ["RELOADEDMART", "Shop"], ["TMVAULT", "TM Vault"], ["POKEVIAL", "PokeVial"], ["PC", "PC"]]
SEL = 2                                   # Bag, in the carousel
FAV = "TM Vault"
MONEY = "$12,450"
MAP = "Cerulean City"; DAY = "Wednesday"; TIME = "3:42 PM"
GREEN = Color.new(120, 230, 150)
GOLD = Color.new(240, 200, 70)
A_BTN = "p:0"; B_BTN = "p:1"; X_BTN = "p:2"; Y_BTN = "p:3"

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

def frame(c, dim = 0, opaque = false)
  BASE.bitmap.clear; TOP.bitmap.clear
  CUR.visible = false
  BASE.bitmap.fill_rect(0, 0, W, H, opaque ? c[:bg] : Color.new(c[:bg].red, c[:bg].green, c[:bg].blue, dim)) if dim > 0 || opaque
end

def cursor_at(x, y, w, h)
  CUR.bitmap = P.cursor_bitmap(w, h)
  CUR.x = x; CUR.y = y; CUR.opacity = 210; CUR.visible = true
end

$icons = {}
def icon(name)
  $icons[name] ||= Bitmap.new(File.join(HERE, "icons", name + ".png"))
end

# An icon fitted in a size x size box centred on cx, cy.
def draw_icon(b, name, cx, cy, size)
  return unless name
  i = icon(name)
  sc = size.to_f / [i.width, i.height].max
  w = (i.width * sc).round; h = (i.height * sc).round
  b.stretch_blt(Rect.new(cx - w / 2, cy - h / 2, w, h), i, Rect.new(0, 0, i.width, i.height))
end

def plus(b, cx, cy, s, color)
  b.fill_rect(cx - s, cy - 1, s * 2, 3, color)
  b.fill_rect(cx - 1, cy - s, 3, s * 2, color)
end

STAR = ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", "##...##"]
def star(b, x, y, color)
  STAR.each_with_index { |row, j| row.each_char.with_index { |ch, i| b.fill_rect(x + i, y + j, 1, 1, color) if ch == "#" } }
end

def stext(b, x, y, w, h, str, color, font, align, c)
  P.text(b, x + 1, y + 1, w, h, str, c[:shadow], font, align)
  P.text(b, x, y, w, h, str, color, font, align)
end

def panel(b, x0, y0, x1, y1, c, alpha = 225, r = 6)
  UI.rbox(b, x0, y0, x1, y1, r, col(c[:panel], alpha), c[:line])
end

# A tile: icon, label and status, as REPM's module boxes. size: icon size;
# font for the label; box: draw the panel behind it.
def tile(c, x, y, w, h, entry, isize, font = PF::TEXT, box = true, sel = false, alpha = 225)
  name, label, status = entry
  base = BASE.bitmap; top = TOP.bitmap
  panel(base, x, y, x + w - 1, y + h - 1, c, alpha, 5) if box
  cursor_at(x, y, w, h) if sel
  font = PF::TINY if P.width(font, label) > w - 8
  label_h = font == PF::TINY ? 12 : 16
  status_h = 0
  icon_cy = y + (h - label_h) / 2 + 1
  if name
    draw_icon(top, name, x + w / 2, icon_cy, isize)
  else
    plus(top, x + w / 2, icon_cy, isize / 4, c[:dim])
  end
  fav = label == FAV
  lc = name.nil? ? c[:dim] : (fav ? GOLD : c[:txt])
  ly = y + h - label_h - status_h - 3
  lw = P.text(top, x, ly, w, label_h, PF.fit(font, label, w - 6), lc, font, 2)
  star(top, x + 4, y + 4, GOLD) if fav
  if status
    a = c[:acc]
    P.pill(top, x + w - 4, y + 4, status, Color.new(a.red / 3, a.green / 3, a.blue / 3), a)
  end
end

# One label font for a whole row: the small one if any label is too wide.
def row_font(row, w, font = PF::TEXT)
  row.any? { |e| P.width(font, e[1]) > w - 8 } ? PF::TINY : font
end

def arrows(c, x_left, x_right, cy, color = nil, sz = 4)
  color ||= c[:dim]
  UI.tri(TOP.bitmap, x_left, cy - sz, :l, color, sz) if x_left
  UI.tri(TOP.bitmap, x_right, cy - sz, :r, color, sz) if x_right
end

def money_lines(c, x, y, w, align = 2)
  P.text(TOP.bitmap, x, y, w, 12, "MONEY", c[:head], PF::TINY, align)
  P.text(TOP.bitmap, x, y + 14, w, 18, MONEY, GREEN, PF::TEXT, align)
end

def location_lines(c, x, y, w, align = 2)
  P.text(TOP.bitmap, x, y, w, 16, MAP, c[:txt], PF::TEXT, align)
  P.small(TOP.bitmap, x, y + 17, w, 15, DAY, c[:dim], align)
  P.small(TOP.bitmap, x, y + 31, w, 15, TIME, c[:dim], align)
end

def hints(c, pairs)
  P.hints(BASE.bitmap, TOP.bitmap, c, pairs, $style)
end
H_ROWS = [[:lr, "Choose"], [:ud, "Rows"], [A_BTN, "Open"], [X_BTN, "Favourite"], [Y_BTN, "Edit Row"], [B_BTN, "Close"]]

# A carousel: the selected entry big in the middle, the others smaller to
# each side. sizes: [big, mid, far]; boxes drawn behind each.
def carousel(c, cx, cy, sizes, gap, sel_focus, isz = 0.62, font = PF::TEXT, far = true, alpha = 225)
  big, mid, farw = sizes
  n = ALL.length
  slots = [[-1, mid], [1, mid]]
  slots += [[-2, farw], [2, farw]] if far
  slots.each do |off, s|
    e = ALL[(SEL + off) % n]
    dist = off.abs == 1 ? big / 2 + gap + s / 2 : big / 2 + gap + mid + gap + s / 2
    x = cx + (off < 0 ? -dist : dist) - s / 2
    y = cy - s / 2
    panel(BASE.bitmap, x, y, x + s - 1, y + s - 1, c, alpha == 255 ? 255 : (off.abs == 1 ? 200 : 150), 5)
    draw_icon(TOP.bitmap, e[0], x + s / 2, y + s / 2, (s * isz).round)
  end
  e = ALL[SEL]
  x = cx - big / 2; y = cy - big / 2
  tile(c, x, y, big, big, e, (big * isz).round, font, true, sel_focus, alpha)
end

def dump_as(name); dump(name); puts "wrote #{name}"; end

#================================================================ D1 Classic
c = palette(2)
frame(c)
stext(TOP.bitmap, 0, 6, W, 32, "Pause Menu", c[:title], PF::TITLE, 2, c)
panel(BASE.bitmap, 4, 4, 133, 52, c)
money_lines(c, 4, 10, 130)
panel(BASE.bitmap, W - 134, 4, W - 5, 52, c)
P.text(TOP.bitmap, W - 134, 7, 130, 16, MAP, c[:txt], PF::TEXT, 2)
P.small(TOP.bitmap, W - 134, 23, 130, 13, DAY, c[:dim], 2)
P.small(TOP.bitmap, W - 134, 36, 130, 13, TIME, c[:dim], 2)
[FIXED, CUSTOM].each_with_index do |row, r|
  y = 60 + r * 96
  f = row_font(row, 104)
  row.each_with_index { |e, i| tile(c, 24 + i * 120, y, 104, 88, e, 50, f) }
  arrows(c, nil, W - 14, y + 44)
end
carousel(c, W / 2, 297, [84, 60, 48], 10, true, 0.6)
hints(c, H_ROWS)
dump_as("P1_classic")

#================================================================ D2 Info Sidebar
frame(c, 150)
base = BASE.bitmap; top = TOP.bitmap
panel(base, 6, 6, 158, 352, c, 235)
stext(top, 6, 10, 152, 24, "Pause Menu", c[:title], PF::ROW, 2, c)
base.fill_rect(16, 38, 132, 1, c[:line])
money_lines(c, 6, 48, 152)
base.fill_rect(16, 86, 132, 1, c[:line])
P.text(top, 6, 96, 152, 12, "LOCATION", c[:head], PF::TINY, 2)
location_lines(c, 6, 112, 152)
base.fill_rect(16, 166, 132, 1, c[:line])
P.text(top, 6, 176, 152, 12, "FAVOURITE", c[:head], PF::TINY, 2)
UI.rbox(base, 22, 194, 142, 266, 5, col(c[:sel], 230), c[:line])
draw_icon(top, "TMVAULT", 82, 220, 40)
P.text(top, 22, 242, 120, 16, FAV, GOLD, PF::TEXT, 2)
w = BI.width(Y_BTN, $style)
lw = P.width(PF::TINY, "OPENS IT")
x = 82 - (w + 5 + lw) / 2
BI.draw(top, x, 276, Y_BTN, c, $style)
P.text(top, x + w + 5, 276, lw + 2, 16, "OPENS IT", c[:dim], PF::TINY)
[["PINNED", FIXED], ["YOUR ROW", CUSTOM]].each_with_index do |(head, row), r|
  y = 10 + r * 106
  P.heading(top, 172, 500, y, head, c[:head], c[:line])
  f = row_font(row, 76)
  row.each_with_index { |e, i| tile(c, 172 + i * 84, y + 16, 76, 82, e, 40, f, true, r == 0 && i == 1) }
end
P.heading(top, 172, 500, 222, "ALL", c[:head], c[:line])
carousel(c, 336, 292, [76, 56, 40], 8, false, 0.6)
hints(c, [[:lr, "Choose"], [:ud, "Rows"], [A_BTN, "Open"], [X_BTN, "Set Favourite"], [B_BTN, "Close"]])
dump_as("P2_info_sidebar")

#================================================================ D3 Hero Carousel
frame(c, 90)
base = BASE.bitmap; top = TOP.bitmap
base.fill_rect(0, 0, W, 42, col(c[:panel2], 238))
base.fill_rect(0, 41, W, 1, c[:line])
P.text(top, 12, 5, 120, 12, "MONEY", c[:head], PF::TINY, 0)
P.text(top, 12, 18, 120, 18, MONEY, GREEN, PF::TEXT, 0)
stext(top, 0, 6, W, 30, "Pause Menu", c[:title], PF::TITLE, 2, c)
P.text(top, W - 172, 4, 160, 16, MAP, c[:txt], PF::TEXT, 1)
P.small(top, W - 172, 22, 160, 15, "#{DAY[0, 3]} #{TIME}", c[:dim], 1)
def chip_row(c, row, y, focus = -1)
  w = 66; gap = 10
  x0 = (W - (row.length * w + (row.length - 1) * gap)) / 2
  UI.rbox(BASE.bitmap, x0 - 8, y - 4, x0 + row.length * (w + gap) - gap + 7, y + 62, 8, col(c[:panel2], 200))
  row.each_with_index { |e, i| tile(c, x0 + i * (w + gap), y, w, 58, e, 30, PF::TINY, true, i == focus) }
  arrows(c, x0 - 22, x0 + row.length * (w + gap) - gap + 14, y + 29)
end
chip_row(c, FIXED, 54)
carousel(c, W / 2, 196, [118, 76, 56], 12, true, 0.6, PF::ROW)
chip_row(c, CUSTOM, 286)
hints(c, H_ROWS)
dump_as("P3_hero_carousel")

#================================================================ D4 Shelves (Settings look)
frame(c, 0, true)
base = BASE.bitmap; top = TOP.bitmap
base.fill_rect(0, 0, W, 46, c[:panel2])
base.fill_rect(0, 45, W, 1, c[:line])
UI.rbox(base, 8, 5, 136, 40, 5, c[:dark], c[:line])
money_lines(c, 8, 8, 128)
UI.rbox(base, W - 136, 5, W - 8, 40, 5, c[:dark], c[:line])
P.text(top, W - 136, 7, 128, 16, MAP, c[:txt], PF::TEXT, 2)
P.small(top, W - 136, 23, 128, 14, "#{DAY[0, 3]} #{TIME}", c[:dim], 2)
P.text(top, 0, 9, W, 28, "Pause Menu", c[:title], PF::TITLE, 2)
UI.rbox(base, 6, 50, W - 6, 354, 6, c[:panel])
def shelf(c, head, y, items, focus = -1, scroll = false)
  P.heading(TOP.bitmap, 16, W - 16, y, head, c[:head], c[:line])
  w = 86; gap = 8
  x0 = (W - (5 * w + 4 * gap)) / 2
  f = row_font(items.first(5), w)
  items.first(5).each_with_index do |e, i|
    tile(c, x0 + i * (w + gap), y + 15, w, 74, e, 38, f, true, i == focus, 255)
  end
  arrows(c, scroll ? x0 - 14 : nil, x0 + 5 * (w + gap) - gap + 6, y + 15 + 37)
end
shelf(c, "Pinned", 58, FIXED + [["OUTFIT", "Outfit"]])
shelf(c, "Your Row", 156, CUSTOM)
all5 = (-2..2).map { |o| ALL[(SEL + o) % ALL.length] }
shelf(c, "All", 254, all5, 2, true)
hints(c, H_ROWS)
dump_as("P4_shelves")

#================================================================ D5 Vertical Wheel
frame(c, 140)
base = BASE.bitmap; top = TOP.bitmap
panel(base, 6, 6, 196, 352, c, 235)
stext(top, 6, 10, 190, 24, "Pause Menu", c[:title], PF::ROW, 2, c)
base.fill_rect(16, 38, 170, 1, c[:line])
UI.tri(top, 97, 42, :u, c[:dim], 4)
n = ALL.length
[-3, -2, -1, 1, 2, 3].each do |off|
  e = ALL[(SEL + off) % n]
  y = off < 0 ? 152 + off * 34 : 210 + (off - 1) * 34
  dimc = off.abs == 1 ? c[:txt] : c[:dim]
  draw_icon(top, e[0], 40, y + 16, off.abs == 1 ? 26 : 20)
  P.text(top, 60, y, 130, 32, e[1], dimc, PF::TEXT)
end
e = ALL[SEL]
panel(base, 14, 154, 188, 206, c, 245, 6)
cursor_at(14, 154, 175, 53)
draw_icon(top, e[0], 44, 180, 38)
P.text(top, 72, 164, 112, 32, e[1], c[:txt], PF::ROW)
UI.tri(top, 97, 340, :d, c[:dim], 4)
panel(base, 204, 6, 350, 70, c)
money_lines(c, 204, 14, 146)
panel(base, 356, 6, 506, 70, c)
location_lines(c, 356, 11, 150)
[["Pinned", FIXED], ["Your Row", CUSTOM]].each_with_index do |(head, row), r|
  y = 80 + r * 100
  P.heading(top, 206, 504, y, head, c[:head], c[:line])
  f = row_font(row, 70)
  row.each_with_index { |ent, i| tile(c, 206 + i * 75, y + 15, 70, 78, ent, 38, f) }
end
panel(base, 204, 284, 506, 352, c)
P.text(top, 214, 290, 120, 12, "FAVOURITE", c[:head], PF::TINY)
draw_icon(top, "TMVAULT", 236, 325, 34)
P.text(top, 262, 308, 140, 32, FAV, GOLD, PF::ROW)
star(top, 214, 304, GOLD)
w = BI.width(Y_BTN, $style)
BI.draw(top, 470 - w, 317, Y_BTN, c, $style)
P.text(top, 400, 317, 70 - w - 8, 16, "OPEN", c[:dim], PF::TINY, 1)
hints(c, [[:ud, "Choose"], [:lr, "Rows"], [A_BTN, "Open"], [X_BTN, "Favourite"], [Y_BTN, "Edit Row"], [B_BTN, "Close"]])
dump_as("P5_vertical_wheel")

#================================================================ D6 Device
frame(c, 70)
base = BASE.bitmap; top = TOP.bitmap
body = c[:key]
UI.rbox(base, 30, 8, 482, 354, 20, body, Reloaded::Palette.mix(body, c[:white], 0.35))
UI.rbox(base, 38, 16, 474, 346, 16, Reloaded::Palette.mix(body, c[:bg], 0.45))
UI.rbox(base, 214, 20, 298, 25, 2, Reloaded::Palette.mix(body, c[:bg], 0.75))
UI.rbox(base, 50, 30, 462, 334, 8, c[:bg], c[:line])
base.fill_rect(51, 31, 411, 24, c[:panel2])
base.fill_rect(51, 54, 411, 1, c[:line])
P.text(top, 60, 33, 120, 18, MONEY, GREEN, PF::TEXT, 0)
P.text(top, 50, 33, 412, 18, MAP, c[:txt], PF::TEXT, 2)
P.small(top, 330, 34, 124, 15, "#{DAY[0, 3]} #{TIME}", c[:dim], 1)
stext(top, 50, 58, 412, 24, "Pause Menu", c[:title], PF::ROW, 2, c)
[["Pinned", FIXED], ["Your Row", CUSTOM]].each_with_index do |(head, row), r|
  y = 86 + r * 86
  P.heading(top, 62, 450, y, head, c[:head], c[:line])
  f = row_font(row, 84)
  row.each_with_index do |ent, i|
    x = 76 + i * 92
    tile(c, x, y + 13, 84, 68, ent, 38, f, false, r == 0 && i == 2)
  end
end
UI.rbox(base, 62, 262, 450, 326, 12, col(c[:panel], 255), c[:line])
n = ALL.length
[-2, -1, 1, 2].each do |off|
  e = ALL[(SEL + off) % n]
  x = 256 + off * 66
  draw_icon(top, e[0], x, 292, off.abs == 1 ? 40 : 32)
end
UI.rbox(base, 226, 246, 286, 306, 10, c[:sel], c[:selb])
draw_icon(top, ALL[SEL][0], 256, 274, 46)
P.text(top, 216, 307, 80, 16, ALL[SEL][1], c[:txt], PF::TEXT, 2)
hints(c, H_ROWS)
dump_as("P6_device")

#================================================================ D7 Side Panel
frame(c)
base = BASE.bitmap; top = TOP.bitmap
panel(base, 262, 6, 506, 352, c, 240)
stext(top, 262, 10, 244, 24, "Pause Menu", c[:title], PF::ROW, 2, c)
base.fill_rect(272, 38, 224, 1, c[:line])
P.text(top, 274, 44, 130, 16, MAP, c[:txt], PF::TEXT, 0)
P.text(top, 394, 44, 102, 16, MONEY, GREEN, PF::TEXT, 1)
P.small(top, 274, 61, 220, 14, "#{DAY} #{TIME}", c[:dim], 0)
[["Pinned", FIXED], ["Your Row", CUSTOM]].each_with_index do |(head, row), r|
  y = 82 + r * 76
  P.heading(top, 272, 496, y, head, c[:head], c[:line])
  row.first(3).each_with_index { |ent, i| tile(c, 286 + i * 72, y + 14, 66, 58, ent, 32, PF::TINY) }
  arrows(c, nil, 496, y + 43)
end
P.heading(top, 272, 496, 234, "All", c[:head], c[:line])
carousel(c, 384, 296, [80, 52, 0], 8, true, 0.58, PF::TEXT, false)
hints(c, H_ROWS)
dump_as("P7_side_panel")
puts "done"
