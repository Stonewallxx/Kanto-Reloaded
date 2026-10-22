# encoding: utf-8
# Mockups: five TM Vault designs, each as two screens: the Vault (tabs Vault /
# Relearn / Checklist, sort, the move list, party compatibility, move info and
# Coverage Check) and Move Compare (teaching Thunderbolt to Gengar).
# Design 1 = HR's TM Vault screen in our UI kit.
# Usage: ruby tm_designs.rb "<KIF Beta>" <work dir with metrics.json>
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

# [move, type id, category 0/1/2, power, accuracy, pp, source]
MOVES = [["Thunderbolt", 13, 1, 90, 100, 15, "TM24"], ["Thunder Wave", 13, 2, nil, 90, 20, "TM45"],
         ["Ice Beam", 15, 1, 90, 100, 10, "TM13"], ["Earthquake", 4, 0, 100, 100, 10, "TM26"],
         ["Psychic", 14, 1, 90, 100, 10, "TM29"], ["Flamethrower", 10, 1, 90, 100, 15, "TM35"],
         ["Shadow Ball", 7, 1, 80, 100, 15, "TM30"], ["Toxic", 3, 2, nil, 90, 10, "TM06"],
         ["Surf", 11, 1, 90, 100, 15, "HM03"], ["Body Slam", 0, 0, 85, 100, 15, "Tutor"]]
SEL = 0
DESC = "A strong electric blast crashes down on the target. This may also leave the target with paralysis."
CHECK = [["PIKACHU", "Pikachu", :knows], ["GYARADOS", "Gyarados", :no], ["GENGAR", "Gengar", :learn],
         ["ALAKAZAM", "Alakazam", :no], ["SNORLAX", "Snorlax", :learn]]
# Gengar's moves for Move Compare
GENGAR = [["Shadow Ball", 7, 1, 80, 100, 15], ["Sludge Bomb", 3, 1, 90, 100, 10], ["Hypnosis", 14, 2, nil, 60, 20], ["Dream Eater", 14, 1, 100, 100, 15]]
FORGET = 2
SE_NOW = [7, 14, 12, 18, 1, 3]       # Ghost, Psychic, Grass, Fairy, Fighting, Poison
SE_ADD = [11, 2]                     # Water, Flying
TABS = ["Vault", "Relearn", "Checklist"]
TYPE_RGB = { 0 => [200, 200, 180], 3 => [190, 120, 220], 4 => [225, 190, 110], 7 => [150, 120, 210], 10 => [245, 140, 90],
             11 => [110, 160, 245], 13 => [245, 215, 70], 14 => [245, 110, 160], 15 => [140, 220, 230] }
GREEN = Color.new(120, 230, 150); GOLD = Color.new(240, 200, 70); BLUE = Color.new(130, 190, 250); RED = Color.new(240, 110, 100)
A_BTN = "p:0"; B_BTN = "p:1"; X_BTN = "p:2"; Y_BTN = "p:3"

def palette(theme)
  Reloaded::Settings.set(:"interface.theme", theme)
  return Reloaded::Palette.current
end
def col(c, a); Color.new(c.red, c.green, c.blue, a); end
def tcol(id); Color.new(*(TYPE_RGB[id] || [220, 220, 220])); end

$vp = Viewport.new(0, 0, W, H)
$vp.z = 99_999
def layer(z); s = Sprite.new($vp); s.bitmap = Bitmap.new(W, H); s.z = z; s; end
BASE = layer(0)
CUR = Sprite.new($vp); CUR.z = 1
TOP = layer(2)
def frame(c)
  BASE.bitmap.clear; TOP.bitmap.clear
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
def mon_icon(b, species, cx, cy, size)
  draw_img(b, File.join(GFX, "Pokemon/Icons/#{species}.png"), cx, cy, size, Rect.new(0, 0, 64, 64))
end
def type_icon(b, id, x, y, size = 16)
  b.stretch_blt(Rect.new(x, y, size, size), bmp(File.join(GFX, "Pictures/Battle/typesSmall.png")), Rect.new(0, id * 19, 19, 19))
end
def cat_icon(b, cat, x, y, w = 32)
  h = (w * 28 / 64.0).round
  b.stretch_blt(Rect.new(x, y, w, h), bmp(File.join(GFX, "Pictures/category.png")), Rect.new(0, cat * 28, 64, 28))
end
def magnifier(base, ix, iy, fg, hole)
  UI.rbox(base, ix, iy, ix + 9, iy + 9, 4, fg)
  UI.rbox(base, ix + 2, iy + 2, ix + 7, iy + 7, 2, hole)
  3.times { |i| base.fill_rect(ix + 8 + i, iy + 8 + i, 2, 2, fg) }
end
def title_bar(c, title, sort = "Sort: Type")
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
  P.text(t, 0, 2, W, 28, title, c[:title], PF::TITLE, 2)
  UI.rbox(b, 8, 4, 120, 27, 5, c[:dark], c[:line])
  magnifier(b, 28, 10, c[:dim], c[:dark]); P.text(t, 44, 4, 70, 23, "Search", c[:dim])
  BI.draw(t, 126, 8, "p:9", c, $style)
  UI.rbox(b, W - 120, 4, W - 8, 27, 5, c[:dark], c[:line])
  P.text(t, W - 120, 4, 112, 23, sort, c[:dim], PF::TEXT, 2)
  BI.draw(t, W - 126 - BI.width("p:10", $style), 8, "p:10", c, $style)
end
def tabs(c, x, y, w, current = 0, counts = ["10", "", "14 Left"])
  tw = w / TABS.length
  TABS.each_with_index do |tb, i|
    on = i == current
    UI.rbox(BASE.bitmap, x + i * tw + 1, y, x + (i + 1) * tw - 2, y + 19, 4, on ? c[:sel] : c[:panel], on ? c[:selb] : c[:line])
    n = counts[i].to_s.split(" ").first.to_s
    label = n.empty? ? tb.upcase : "#{tb.upcase} #{n}"
    P.text(TOP.bitmap, x + i * tw, y, tw, 20, label, on ? c[:white] : c[:dim], PF::TINY, 2)
  end
end
def compat_label(st, c)
  { :knows => ["Knows It", BLUE], :learn => ["Can Learn", GREEN], :no => ["Can't", c[:dim]] }[st]
end
def party_row(c, x, y, w, size = 30)
  step = w / CHECK.length
  CHECK.each_with_index do |(sp, name, st), i|
    cx = x + i * step + step / 2
    mon_icon(TOP.bitmap, sp, cx, y + size / 2, size)
    l, color = compat_label(st, c)
    P.text(TOP.bitmap, x + i * step, y + size, step, 12, l, color, PF::TINY, 2)
  end
end
def move_stats(c, x, y, mv)
  t = TOP.bitmap
  type_icon(t, mv[1], x, y + 1); cat_icon(t, mv[2], x + 20, y + 3, 32)
  P.text(t, x + 58, y, 220, 18, "Power #{mv[3] || '--'} · Acc. #{mv[4]} · PP #{mv[5]}", c[:acc], PF::TINY)
end
def coverage(c, x, y, w, compact = false)
  t = TOP.bitmap
  P.text(t, x, y, w, 12, "COVERAGE (GENGAR)", c[:head], PF::TINY)
  SE_NOW.each_with_index { |id, i| type_icon(t, id, x + i * 18, y + 15, 16) }
  P.text(t, x + SE_NOW.length * 18 + 8, y + 15, 40, 16, "+", GREEN, PF::TEXT)
  SE_ADD.each_with_index { |id, i| type_icon(t, id, x + SE_NOW.length * 18 + 22 + i * 18, y + 15, 16) }
  P.text(t, x, y + 34, w, 12, "Thunderbolt adds Water and Flying", GREEN, PF::TINY) unless compact
end
def hints(c, pairs); P.hints(BASE.bitmap, TOP.bitmap, c, pairs, $style); end
H_VAULT = [[:ud, "Choose"], [:lr, "Party"], ["p:4", "Tabs"], [A_BTN, "Teach"], [B_BTN, "Close"]]
H_CMP = [[:ud, "Choose"], [A_BTN, "Forget This"], [B_BTN, "Cancel"]]
def dump_as(name); dump(name); puts "wrote #{name}"; end

# Move Compare in a dialog: the new move on top, the four it can replace
def compare_dialog(c, x0, y0, x1, y1)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
  UI.rbox(b, x0, y0, x1, y1, 6, c[:panel2], c[:line])
  mon_icon(t, "GENGAR", x0 + 24, y0 + 18, 34)
  P.text(t, x0 + 44, y0 + 4, x1 - x0 - 50, 26, "Teach Thunderbolt to Gengar?", c[:title], PF::ROW)
  b.fill_rect(x0 + 10, y0 + 34, x1 - x0 - 20, 1, c[:line])
  cols = [x0 + 150, x0 + 214, x0 + 262, x0 + 306]
  ["TYPE", "POWER", "ACC.", "PP"].each_with_index { |h, i| P.text(t, cols[i], y0 + 38, 50, 12, h, c[:dim], PF::TINY) }
  rows = [[MOVES[0], true]] + GENGAR.map { |m| [m, false] }
  rows.each_with_index do |(mv, is_new), i|
    y = y0 + 54 + i * 26 + (is_new ? 0 : 8)
    if is_new
      UI.rbox(b, x0 + 8, y - 2, x1 - 8, y + 22, 4, col(GREEN, 40), GREEN)
      P.text(t, x1 - 60, y, 50, 20, "NEW", GREEN, PF::TINY, 1)
    end
    cursor_at(x0 + 8, y - 2, x1 - x0 - 15, 25) if i == FORGET + 1
    P.text(t, x0 + 18, y, 128, 20, mv[0], is_new ? GREEN : tcol(mv[1]), PF::TEXT)
    type_icon(t, mv[1], cols[0], y + 2)
    cat_icon(t, mv[2], cols[0] + 18, y + 4, 30)
    P.text(t, cols[1], y, 40, 20, (mv[3] || "--").to_s, c[:txt], PF::TEXT)
    P.text(t, cols[2], y, 40, 20, mv[4].to_s, c[:txt], PF::TEXT)
    P.text(t, cols[3], y, 40, 20, mv[5].to_s, c[:txt], PF::TEXT)
  end
  P.text(t, x0 + 14, y1 - 40, 300, 12, "COVERAGE AFTER", c[:head], PF::TINY)
  (SE_NOW + SE_ADD).each_with_index { |id, i| type_icon(t, id, x0 + 14 + i * 18, y1 - 25, 16) }
  P.small(t, x0 + 14 + 8 * 18 + 8, y1 - 27, 200, 16, "Forgetting Hypnosis loses none", c[:dim])
end

c = palette(2)

#================================================================ T1 Recommended: HR's TM Vault, rebuilt
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title_bar(c, "TM Vault")
tabs(c, 8, 36, 216)
UI.rbox(b, 6, 60, 228, 354, 6, c[:panel])
MOVES.each_with_index do |mv, i|
  y = 64 + i * 26
  cursor_at(9, y, 216, 25) if i == SEL
  P.text(t, 16, y, 150, 25, mv[0], tcol(mv[1]), PF::TEXT)
  P.text(t, 150, y, 40, 25, mv[6], c[:dim], PF::TINY)
  type_icon(t, mv[1], 204, y + 4)
end
UI.rbox(b, 234, 36, W - 6, 354, 6, c[:panel])
CHECK.each_with_index do |(sp, name, st), i|
  cx = 270 + (i % 3) * 82; cy = 40 + (i / 3) * 62
  mon_icon(t, sp, cx, cy + 20, 40)
  P.text(t, cx - 40, cy + 38, 80, 12, name, c[:txt], PF::TINY, 2)
  l, color = compat_label(st, c)
  P.text(t, cx - 40, cy + 49, 80, 12, l, color, PF::TINY, 2)
end
b.fill_rect(244, 166, W - 260, 1, c[:line])
P.text(t, 244, 170, 200, 22, "Thunderbolt", tcol(13), PF::ROW)
move_stats(c, 244, 194, MOVES[0])
P.small_wrap(t, DESC, 252).first(3).each_with_index { |ln, k| P.small(t, 244, 214 + k * 16, 252, 16, ln, c[:txt]) }
coverage(c, 244, 268, 260)
hints(c, H_VAULT)
dump_as("T1_vault")
frame(c)
title_bar(c, "TM Vault")
compare_dialog(c, 56, 52, 456, 332)
hints(c, H_CMP)
dump_as("T1_compare")

#================================================================ T2 Party First
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title_bar(c, "TM Vault")
CHECK.each_with_index do |(sp, name, st), i|
  px = 8 + i * 100
  on = i == 2
  UI.rbox(b, px, 36, px + 94, 94, 6, on ? c[:sel] : c[:panel], on ? c[:selb] : c[:line])
  mon_icon(t, sp, px + 24, 62, 40)
  P.text(t, px + 44, 44, 50, 16, PF.fit(PF::TINY, name, 48), c[:txt], PF::TINY)
  l, color = compat_label(st, c)
  P.text(t, px + 44, 62, 50, 12, l, color, PF::TINY)
end
tabs(c, 8, 100, 240, 0, ["7", "", "14 Left"])
UI.rbox(b, 6, 124, 250, 354, 6, c[:panel])
P.text(t, 14, 126, 230, 14, "GENGAR CAN LEARN", c[:head], PF::TINY)
MOVES.first(8).each_with_index do |mv, i|
  y = 142 + i * 26
  cursor_at(9, y, 238, 25) if i == SEL
  type_icon(t, mv[1], 16, y + 4)
  P.text(t, 38, y, 150, 25, mv[0], c[:txt], PF::TEXT)
  P.text(t, 196, y, 46, 25, mv[6], c[:dim], PF::TINY, 1)
end
UI.rbox(b, 256, 100, W - 6, 354, 6, c[:panel])
P.text(t, 266, 104, 200, 22, "Thunderbolt", tcol(13), PF::ROW)
move_stats(c, 266, 130, MOVES[0])
P.small_wrap(t, DESC, 230).first(4).each_with_index { |ln, k| P.small(t, 266, 152 + k * 16, 230, 16, ln, c[:txt]) }
coverage(c, 266, 230, 236)
P.text(t, 266, 290, 236, 12, "ALSO LEARNS IT", c[:head], PF::TINY)
mon_icon(t, "SNORLAX", 286, 318, 30)
P.small(t, 304, 310, 120, 16, "Snorlax", c[:txt])
hints(c, [[:lr, "Pokémon"], [:ud, "Choose"], [A_BTN, "Teach"], [B_BTN, "Close"]])
dump_as("T2_vault")
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title_bar(c, "Move Compare", "Gengar")
UI.rbox(b, 6, 40, 250, 230, 8, c[:panel], GREEN)
P.text(t, 16, 46, 120, 12, "NEW MOVE", GREEN, PF::TINY)
P.text(t, 16, 60, 230, 24, "Thunderbolt", tcol(13), PF::ROW)
move_stats(c, 16, 92, MOVES[0])
P.small_wrap(t, DESC, 226).first(4).each_with_index { |ln, k| P.small(t, 16, 116 + k * 16, 226, 16, ln, c[:txt]) }
UI.rbox(b, 262, 40, W - 6, 230, 8, c[:panel], c[:line])
P.text(t, 272, 46, 200, 12, "FORGET", c[:head], PF::TINY)
GENGAR.each_with_index do |mv, i|
  y = 62 + i * 40
  cursor_at(266, y - 2, W - 276, 38) if i == FORGET
  P.text(t, 276, y - 2, 140, 20, mv[0], tcol(mv[1]), PF::TEXT)
  type_icon(t, mv[1], 276, y + 18, 14); cat_icon(t, mv[2], 294, y + 20, 26)
  P.text(t, 326, y + 17, 170, 14, "Pow #{mv[3] || '--'} · Acc #{mv[4]} · PP #{mv[5]}", c[:dim], PF::TINY)
end
UI.rbox(b, 6, 236, W - 6, 354, 8, c[:panel2], c[:line])
P.text(t, 16, 242, 300, 12, "COVERAGE", c[:head], PF::TINY)
P.small(t, 16, 258, 80, 16, "Now", c[:dim]); SE_NOW.each_with_index { |id, i| type_icon(t, id, 70 + i * 18, 258) }
P.small(t, 16, 282, 80, 16, "After", c[:dim]); (SE_NOW + SE_ADD).each_with_index { |id, i| type_icon(t, id, 70 + i * 18, 282) }
P.small(t, 16, 306, 480, 16, "Thunderbolt adds Water and Flying. Forgetting Hypnosis loses none.", GREEN)
hints(c, H_CMP)
dump_as("T2_compare")

#================================================================ T3 Move Cards
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title_bar(c, "TM Vault")
tabs(c, 106, 36, 300)
cw = 244; ch = 42
MOVES.first(10).each_with_index do |mv, i|
  cx = 8 + (i % 2) * (cw + 8); cy = 60 + (i / 2) * (ch + 4)
  UI.rbox(b, cx, cy, cx + cw - 1, cy + ch - 1, 6, c[:panel], c[:line])
  b.fill_rect(cx + 1, cy + 4, 4, ch - 8, tcol(mv[1]))
  cursor_at(cx, cy, cw, ch) if i == SEL
  P.text(t, cx + 12, cy + 2, 150, 20, mv[0], c[:txt], PF::TEXT)
  P.text(t, cx + 12, cy + 22, 160, 14, "#{mv[6]} · Pow #{mv[3] || '--'} · Acc #{mv[4]}", c[:dim], PF::TINY)
  type_icon(t, mv[1], cx + cw - 54, cy + 13); cat_icon(t, mv[2], cx + cw - 36, cy + 15, 30)
end
UI.rbox(b, 6, 292, W - 6, 354, 6, c[:panel2], c[:line])
P.small_wrap(t, DESC, 240).first(3).each_with_index { |ln, k| P.small(t, 14, 296 + k * 16, 240, 16, ln, c[:txt]) }
party_row(c, 260, 294, 246, 28)
hints(c, [[:ud, "Choose"], [:lr, "Choose"], ["p:4", "Tabs"], [A_BTN, "Teach"], [B_BTN, "Close"]])
dump_as("T3_vault")
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title_bar(c, "Teach Thunderbolt", "Gengar")
UI.rbox(b, 130, 40, 382, 90, 6, c[:panel], GREEN)
b.fill_rect(131, 44, 4, 42, tcol(13))
P.text(t, 142, 44, 160, 20, "Thunderbolt", GREEN, PF::TEXT)
P.text(t, 142, 66, 200, 14, "NEW · Pow 90 · Acc 100 · PP 15", c[:dim], PF::TINY)
type_icon(t, 13, 332, 55); cat_icon(t, 1, 350, 57, 26)
GENGAR.each_with_index do |mv, i|
  cx = 8 + (i % 2) * (cw + 8); cy = 100 + (i / 2) * (ch + 6)
  UI.rbox(b, cx, cy, cx + cw - 1, cy + ch - 1, 6, c[:panel], c[:line])
  b.fill_rect(cx + 1, cy + 4, 4, ch - 8, tcol(mv[1]))
  cursor_at(cx, cy, cw, ch) if i == FORGET
  P.text(t, cx + 12, cy + 2, 150, 20, mv[0], c[:txt], PF::TEXT)
  P.text(t, cx + 12, cy + 22, 170, 14, "Pow #{mv[3] || '--'} · Acc #{mv[4]} · PP #{mv[5]}", c[:dim], PF::TINY)
  type_icon(t, mv[1], cx + cw - 54, cy + 13); cat_icon(t, mv[2], cx + cw - 36, cy + 15, 30)
end
UI.rbox(b, 6, 204, W - 6, 290, 6, c[:panel2], c[:line])
P.text(t, 16, 210, 300, 12, "COVERAGE AFTER", c[:head], PF::TINY)
(SE_NOW + SE_ADD).each_with_index { |id, i| type_icon(t, id, 16 + i * 20, 228, 18) }
P.small(t, 16, 252, 480, 16, "Thunderbolt adds Water and Flying. Forgetting Hypnosis loses none.", GREEN)
hints(c, [[:ud, "Choose"], [:lr, "Choose"], [A_BTN, "Forget This"], [B_BTN, "Cancel"]])
dump_as("T3_compare")

#================================================================ T4 Settings Style (sidebar sections)
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title_bar(c, "TM Vault")
UI.rbox(b, 6, 36, 150, 262, 6, c[:panel])
[["Vault", "10"], ["Relearn", ""], ["Checklist", "14"]].each_with_index do |(s, n), i|
  y = 42 + i * 30
  UI.rbox(b, 10, y, 146, y + 26, 5, c[:sel], c[:selb]) if i == 0
  P.text(t, 18, y, 80, 26, s, i == 0 ? c[:white] : c[:txt], PF::TEXT)
  P.text(t, 90, y, 50, 26, n, c[:dim], PF::TINY, 1)
end
P.text(t, 14, 140, 130, 12, "SORT", c[:head], PF::TINY)
["Name", "Type", "Category", "Recent", "Level Learned"].each_with_index { |s, i| P.text(t, 18, 154 + i * 20, 120, 18, s, i == 1 ? c[:acc] : c[:dim], PF::TEXT) }
UI.rbox(b, 156, 36, W - 6, 262, 6, c[:panel])
MOVES.first(8).each_with_index do |mv, i|
  y = 40 + i * 27
  cursor_at(159, y, W - 168, 26) if i == SEL
  type_icon(t, mv[1], 166, y + 5)
  P.text(t, 188, y, 160, 26, mv[0], c[:txt], PF::ROW)
  cat_icon(t, mv[2], 380, y + 7, 28)
  P.text(t, 414, y, 80, 26, mv[6], c[:dim], PF::TEXT, 1)
end
UI.rbox(b, 6, 268, W - 6, H - 30, 6, c[:panel2], c[:line])
P.text(t, 16, 270, 200, 24, "Thunderbolt", c[:head], PF::ROW)
move_stats(c, 150, 274, MOVES[0])
P.small_wrap(t, DESC, 240).first(3).each_with_index { |ln, k| P.small(t, 16, 294 + k * 16, 240, 16, ln, c[:txt]) }
party_row(c, 262, 292, 244, 22)
hints(c, [[:ud, "Choose"], [:lr, "Sections"], [A_BTN, "Teach"], [B_BTN, "Close"]])
dump_as("T4_vault")
frame(c)
title_bar(c, "TM Vault")
compare_dialog(c, 56, 52, 456, 332)
hints(c, H_CMP)
dump_as("T4_compare")

#================================================================ T5 Coverage First
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title_bar(c, "TM Vault")
UI.rbox(b, 6, 36, 214, 354, 6, c[:panel])
mon_icon(t, "GENGAR", 30, 58, 40)
P.text(t, 54, 42, 150, 18, "Gengar", c[:txt], PF::TEXT)
P.text(t, 54, 60, 150, 12, "COVERAGE WITH THUNDERBOLT", c[:head], PF::TINY)
all = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16, 17, 18]
all.each_with_index do |id, i|
  gx = 14 + (i % 3) * 66; gy = 84 + (i / 3) * 40
  se = SE_NOW.include?(id); add = SE_ADD.include?(id)
  UI.rbox(b, gx, gy, gx + 62, gy + 36, 5, add ? col(GREEN, 50) : (se ? c[:sel] : c[:dark]), add ? GREEN : c[:line])
  type_icon(t, id, gx + 4, gy + 10, 16)
  P.text(t, gx + 24, gy + 10, 36, 16, add ? "NEW" : (se ? "2x" : "-"), add ? GREEN : (se ? c[:txt] : c[:dim]), PF::TINY)
end
tabs(c, 220, 36, 286, 0, ["10", "", "14 Left"])
UI.rbox(b, 220, 60, W - 6, 260, 6, c[:panel])
MOVES.first(7).each_with_index do |mv, i|
  y = 64 + i * 27
  cursor_at(223, y, W - 232, 26) if i == SEL
  type_icon(t, mv[1], 230, y + 5)
  P.text(t, 252, y, 150, 26, mv[0], c[:txt], PF::TEXT)
  P.text(t, 400, y, 100, 26, mv[6], c[:dim], PF::TINY, 1)
end
UI.rbox(b, 220, 266, W - 6, 354, 6, c[:panel2], c[:line])
move_stats(c, 228, 270, MOVES[0])
party_row(c, 224, 292, 280, 26)
hints(c, [[:ud, "Choose"], [:lr, "Pokémon"], [A_BTN, "Teach"], [B_BTN, "Close"]])
dump_as("T5_vault")
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title_bar(c, "Teach Thunderbolt", "Gengar")
UI.rbox(b, 6, 36, 214, 354, 6, c[:panel])
P.text(t, 14, 42, 190, 12, "COVERAGE IF YOU FORGET HYPNOSIS", c[:head], PF::TINY)
all.each_with_index do |id, i|
  gx = 14 + (i % 3) * 66; gy = 62 + (i / 3) * 40
  se = SE_NOW.include?(id); add = SE_ADD.include?(id)
  UI.rbox(b, gx, gy, gx + 62, gy + 36, 5, add ? col(GREEN, 50) : (se ? c[:sel] : c[:dark]), add ? GREEN : c[:line])
  type_icon(t, id, gx + 4, gy + 10, 16)
  P.text(t, gx + 24, gy + 10, 36, 16, add ? "NEW" : (se ? "2x" : "-"), add ? GREEN : (se ? c[:txt] : c[:dim]), PF::TINY)
end
UI.rbox(b, 220, 36, W - 6, 92, 6, c[:panel], GREEN)
P.text(t, 230, 40, 200, 20, "Thunderbolt", GREEN, PF::TEXT)
move_stats(c, 230, 64, MOVES[0])
GENGAR.each_with_index do |mv, i|
  y = 102 + i * 40
  UI.rbox(b, 220, y, W - 6, y + 36, 6, c[:panel], c[:line])
  cursor_at(220, y, W - 226, 37) if i == FORGET
  P.text(t, 230, y, 150, 20, mv[0], tcol(mv[1]), PF::TEXT)
  P.text(t, 230, y + 20, 200, 14, "Pow #{mv[3] || '--'} · Acc #{mv[4]} · PP #{mv[5]}", c[:dim], PF::TINY)
  type_icon(t, mv[1], W - 52, y + 10); cat_icon(t, mv[2], W - 34, y + 12, 24)
end
P.small(t, 222, 270, 284, 16, "Forgetting Hypnosis loses no coverage.", GREEN)
hints(c, H_CMP)
dump_as("T5_compare")
puts "done"
