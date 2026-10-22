# encoding: utf-8
# Mockups: four Battle Command Menu designs over a real PIF battle, each as two
# screens: the menu open (entries: Battle Info, Matchup View, Quick Throw (the
# Favorite), Turn Log, Mod Actions; the Field Strip above the command box) and
# the Info screen (tabs per Pokemon, Field and Turn Log, with Battle Info's
# details: stat stages and multipliers, types, revealed ability and item,
# effects with turns left).
# Design 1 = the old KR/HR Battle Menu (a centred panel with a description box)
# in our UI kit.
# Usage: ruby bmenu_designs.rb "<KIF Beta>" <work dir with metrics.json>
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

# [label, status, description, icon item]
ENTRIES = [["Battle Info", "", "Stats, types, abilities, items and effects, plus the field.", "SCOPELENS"],
           ["Matchup View", "", "How each of your moves fares against the foe.", "FIREGEM"],
           ["Quick Throw", "x12 · 41%", "Throws your best Poké Ball without opening the Bag.", "POKEBALL"],
           ["Turn Log", "Turn 6", "What happened each turn: moves, damage, status and fainting.", "TOWNMAP"],
           ["Mod Actions", "2", "Commands added by other mods.", "DEVONSCOPE"]]
FAV = 2
SHORT = ["Stats, effects, field", "Your moves vs the foe", "Best ball, one press", "Each turn's events", "Added by other mods"]
SEL = 0
FIELD = [["RAIN", "3"], ["REFLECT", "2"], ["STEALTH ROCK", "FOE"]]
GREEN = Color.new(120, 230, 150); GOLD = Color.new(240, 200, 70); RED = Color.new(240, 100, 90); BLUE = Color.new(130, 190, 250)
A_BTN = "p:0"; B_BTN = "p:1"; X_BTN = "p:2"; Y_BTN = "p:3"

def palette(theme)
  Reloaded::Settings.set(:"interface.theme", theme)
  return Reloaded::Palette.current
end
def col(c, a); Color.new(c.red, c.green, c.blue, a); end
$vp = Viewport.new(0, 0, W, H)
$vp.z = 99_999
def layer(z); s = Sprite.new($vp); s.bitmap = Bitmap.new(W, H); s.z = z; s; end
MAPS = Sprite.new($vp); MAPS.z = -2
BTXT = layer(-1)
MAPS.bitmap = Bitmap.new(File.join(HERE, "battle_bg.png"))
BASE = layer(0)
CUR = Sprite.new($vp); CUR.z = 1
TOP = layer(2)
def frame(c, dim = 0)
  BASE.bitmap.clear; TOP.bitmap.clear; BTXT.bitmap.clear
  CUR.visible = false
  BASE.bitmap.fill_rect(0, 0, W, H, Color.new(c[:bg].red, c[:bg].green, c[:bg].blue, dim)) if dim > 0
  battle_text(c)
end
def cursor_at(x, y, w, h)
  CUR.bitmap = P.cursor_bitmap(w, h)
  CUR.x = x; CUR.y = y; CUR.opacity = 210; CUR.visible = true
end
$bmps = {}
def bmp(path); $bmps[path] ||= Bitmap.new(path); end
def item_icon(b, name, cx, cy, size)
  i = bmp(File.join(GFX, "Items", name + ".png"))
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), i, Rect.new(0, 0, i.width, i.height))
end
def mon(b, sp, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(File.join(GFX, "Pokemon/Icons/#{sp}.png")), Rect.new(0, 0, 64, 64))
end
def type_icon(b, id, x, y, size = 16)
  b.stretch_blt(Rect.new(x, y, size, size), bmp(File.join(GFX, "Pictures/Battle/typesSmall.png")), Rect.new(0, id * 19, 19, 19))
end
def badge(b, x, y, text, color, right = false); P.pill(b, x, y, text, Color.new(color.red / 4, color.green / 4, color.blue / 4), color, right); end
def star(b, x, y, color)
  ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", "##...##"].each_with_index { |row, j| row.each_char.with_index { |ch, i| b.fill_rect(x + i, y + j, 1, 1, color) if ch == "#" } }
end
# The battle's own text (names, levels, HP, the prompt), as PIF draws it
def battle_text(c)
  t = BTXT.bitmap
  sh = Color.new(40, 40, 48)
  P.text(t, 17, 15, 160, 18, "Golduck", sh, PF::TEXT); P.text(t, 16, 14, 160, 18, "Golduck", Color.new(248, 248, 248), PF::TEXT)
  P.text(t, 171, 15, 50, 18, "Lv31", sh, PF::TEXT); P.text(t, 170, 14, 50, 18, "Lv31", Color.new(248, 248, 248), PF::TEXT)
  P.text(t, 317, 223, 160, 18, "Pikachu", sh, PF::TEXT); P.text(t, 316, 222, 160, 18, "Pikachu", Color.new(248, 248, 248), PF::TEXT)
  P.text(t, 449, 223, 50, 18, "Lv34", sh, PF::TEXT); P.text(t, 448, 222, 50, 18, "Lv34", Color.new(248, 248, 248), PF::TEXT)
  P.text(t, 420, 268, 80, 16, "78/95", Color.new(64, 64, 72), PF::TEXT, 1)
  P.text(t, 18, 302, 220, 22, "What will", Color.new(80, 80, 88), PF::ROW)
  P.text(t, 18, 326, 220, 22, "Pikachu do?", Color.new(80, 80, 88), PF::ROW)
end
# The Field Strip: weather, screens, hazards with turns left, above the command box
def field_strip(c, y = 266, x = 6)
  b = BASE.bitmap; t = TOP.bitmap
  FIELD.each do |label, n|
    w = P.width(PF::TINY, "#{label} #{n}") + 14
    UI.rbox(b, x, y, x + w, y + 16, 5, col(c[:panel], 230), c[:line])
    P.text(t, x + 7, y, w, 16, label, c[:txt], PF::TINY)
    P.text(t, x + 7 + P.width(PF::TINY, label) + 4, y, 30, 16, n, GOLD, PF::TINY)
    x += w + 4
  end
end
def hints(c, pairs); P.hints(BASE.bitmap, TOP.bitmap, c, pairs, $style); end
H_MENU = [[:ud, "Choose"], [A_BTN, "Use"], [Y_BTN, "Favourite"], [B_BTN, "Close"]]
def dump_as(name); dump(name); puts "wrote #{name}"; end

# The Info screen: tabs, then Golduck's page with Battle Info's details
TABS = ["Pikachu", "Golduck", "Field", "Turn Log"]
STAGES = [["Attack", 0, ""], ["Defense", -1, "x0.67"], ["Sp. Atk", 2, "x2.0"], ["Sp. Def", 0, ""], ["Speed", -1, "x0.67"], ["Accuracy", 0, ""], ["Evasion", 1, "x1.33"]]
def stage_rows(c, x, y, w, rh = 20)
  t = TOP.bitmap; b = BASE.bitmap
  STAGES.each_with_index do |(k, v, mult), i|
    yy = y + i * rh
    P.text(t, x, yy, 90, rh, k, c[:txt], PF::TEXT)
    6.times do |s|
      px = x + 96 + s * 12
      filled = v > 0 ? s < v : (v < 0 ? s < -v : false)
      UI.rbox(b, px, yy + 6, px + 9, yy + 13, 2, filled ? (v > 0 ? GREEN : RED) : c[:dark])
    end
    P.text(t, x + 172, yy, 40, rh, v == 0 ? "0" : format("%+d", v), v > 0 ? GREEN : (v < 0 ? RED : c[:dim]), PF::TEXT)
    P.text(t, x + 202, yy, w - 202, rh, mult, c[:dim], PF::TINY, 1)
  end
end
def info_side(c, x, y, w)
  t = TOP.bitmap
  [["Types", nil], ["Ability", "Damp (Revealed)"], ["Item", "Not Seen Yet"], ["Effects", "Leech Seed, Confused (2)"]].each_with_index do |(k, v), i|
    P.text(t, x, y + i * 34, w, 12, k.upcase, c[:head], PF::TINY)
    if k == "Types"
      type_icon(t, 11, x, y + 14, 16)
    else
      P.small(t, x, y + i * 34 + 13, w, 16, v, i == 2 ? c[:dim] : c[:txt])
    end
  end
end

c = palette(2)

#================================================================ BM1 Recommended: the old KR/HR centred panel
frame(c)
b = BASE.bitmap; t = TOP.bitmap
field_strip(c)
px = 126; pw = 260
UI.rbox(b, px, 24, px + pw, 24 + 26 + ENTRIES.length * 24 + 6, 6, col(c[:panel], 240), c[:line])
P.text(t, px, 28, pw, 22, "Battle Menu", c[:title], PF::ROW, 2)
b.fill_rect(px + 8, 50, pw - 16, 1, c[:line])
ENTRIES.each_with_index do |(l, st, d, ic), i|
  y = 54 + i * 24
  cursor_at(px + 4, y, pw - 8, 23) if i == SEL
  item_icon(t, ic, px + 18, y + 11, 18)
  P.text(t, px + 32, y, 140, 23, l, i == FAV ? GOLD : c[:txt], PF::TEXT)
  star(t, px + 34 + P.width(PF::TEXT, l) + 4, y + 8, GOLD) if i == FAV
  P.text(t, px + pw - 90, y, 80, 23, st, c[:acc], PF::TINY, 1) unless st.empty?
end
dy = 24 + 26 + ENTRIES.length * 24 + 10
UI.rbox(b, px, dy, px + pw, dy + 52, 6, col(c[:panel2], 240), c[:line])
P.small_wrap(t, ENTRIES[SEL][2], pw - 16).first(2).each_with_index { |ln, k| P.small(t, px + 8, dy + 6 + k * 16, pw - 16, 16, ln, c[:txt]) }
P.text(t, px, dy + 34, pw, 14, "PAGE 1/2  ·  LB/RB", c[:dim], PF::TINY, 2)
dump_as("BM1_menu")
frame(c, 160)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 16, 16, W - 17, 352, 8, col(c[:panel], 248), c[:line])
tw = (W - 48) / 4
TABS.each_with_index do |tb, i|
  on = i == 1
  UI.rbox(b, 24 + i * tw + 1, 24, 24 + (i + 1) * tw - 2, 44, 4, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
  P.text(t, 24 + i * tw, 24, tw, 20, tb, on ? c[:white] : c[:dim], PF::TEXT, 2)
end
mon(t, "GOLDUCK", 52, 74, 44)
P.text(t, 78, 56, 200, 20, "Golduck  Lv31", c[:txt], PF::ROW)
P.text(t, 78, 78, 200, 14, "HP 55% · No Status", c[:dim], PF::TINY)
stage_rows(c, 32, 104, 260)
b.fill_rect(304, 56, 1, 280, c[:line])
info_side(c, 316, 58, 180)
hints(c, [[:lr, "Tabs"], [:ud, "Scroll"], [B_BTN, "Back"]])
dump_as("BM1_info")

#================================================================ BM2 Second Command Row (EBDX-like)
frame(c)
b = BASE.bitmap; t = TOP.bitmap
field_strip(c, 222, 6)
UI.rbox(b, 252, 240, W - 4, 286, 6, col(c[:panel], 245), c[:line])
ENTRIES.each_with_index do |(l, st, d, ic), i|
  bx = 256 + i * 50
  UI.rbox(b, bx, 244, bx + 46, 282, 5, i == FAV ? Reloaded::Palette.mix(c[:panel], GOLD, 0.25) : c[:dark], i == FAV ? GOLD : c[:line])
  cursor_at(bx, 244, 47, 39) if i == SEL
  item_icon(t, ic, bx + 23, 256, 22)
  P.text(t, bx, 268, 46, 14, PF.fit(PF::TINY, l.split(" ").first.upcase, 44), i == FAV ? GOLD : c[:txt], PF::TINY, 2)
end
UI.rbox(b, 6, 244, 246, 282, 6, col(c[:panel2], 240), c[:line])
P.text(t, 12, 246, 230, 16, ENTRIES[SEL][0], c[:head], PF::TEXT)
P.small(t, 12, 264, 232, 15, "Stats, effects and the field.", c[:txt])
dump_as("BM2_menu")
frame(c, 160)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 8, 8, W - 9, 352, 8, col(c[:panel], 248), c[:line])
TABS.each_with_index do |tb, i|
  on = i == 1
  ix = 16 + i * 60
  UI.rbox(b, ix, 16, ix + 54, 70, 6, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
  if i < 2
    mon(t, i == 0 ? "PIKACHU" : "GOLDUCK", ix + 27, 38, 36)
  else
    item_icon(t, i == 2 ? "DAMPROCK" : "TOWNMAP", ix + 27, 38, 26)
  end
  P.text(t, ix, 56, 54, 12, tb.upcase, on ? c[:white] : c[:dim], PF::TINY, 2)
end
P.text(t, 270, 20, 230, 20, "Golduck  Lv31", c[:txt], PF::ROW, 1)
P.text(t, 270, 44, 230, 14, "HP 55% · No Status", c[:dim], PF::TINY, 1)
stage_rows(c, 24, 84, 270, 22)
info_side(c, 316, 84, 180)
hints(c, [[:lr, "Tabs"], [:ud, "Scroll"], [B_BTN, "Back"]])
dump_as("BM2_info")

#================================================================ BM3 Side Drawer
frame(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 300, 6, W - 6, 284, 8, col(c[:panel], 242), c[:line])
P.text(t, 300, 10, W - 306, 22, "Battle Menu", c[:title], PF::ROW, 2)
ENTRIES.each_with_index do |(l, st, d, ic), i|
  y = 38 + i * 48
  cursor_at(304, y, W - 314, 46) if i == SEL
  item_icon(t, ic, 322, y + 22, 24)
  P.text(t, 340, y + 2, 140, 20, l, i == FAV ? GOLD : c[:txt], PF::TEXT)
  P.small(t, 340, y + 22, 150, 15, SHORT[i], c[:dim])
  P.text(t, 420, y + 4, 80, 14, st, c[:acc], PF::TINY, 1) unless st.empty?
  star(t, 340 + P.width(PF::TEXT, l) + 6, y + 8, GOLD) if i == FAV
end
field_strip(c, 266)
dump_as("BM3_menu")
frame(c, 120)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 200, 6, W - 6, 352, 8, col(c[:panel], 248), c[:line])
TABS.each_with_index do |tb, i|
  on = i == 1
  tw2 = (W - 220) / 4
  UI.rbox(b, 208 + i * tw2, 12, 208 + (i + 1) * tw2 - 3, 30, 4, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
  P.text(t, 208 + i * tw2, 12, tw2 - 3, 18, tb.upcase, on ? c[:white] : c[:dim], PF::TINY, 2)
end
mon(t, "GOLDUCK", 228, 56, 36)
P.text(t, 250, 40, 200, 20, "Golduck  Lv31", c[:txt], PF::TEXT)
P.text(t, 250, 60, 200, 14, "HP 55% · No Status", c[:dim], PF::TINY)
stage_rows(c, 214, 82, 286, 20)
info_side(c, 214, 230, 286)
hints(c, [[:lr, "Tabs"], [:ud, "Scroll"], [B_BTN, "Back"]])
dump_as("BM3_info")

#================================================================ BM4 Bottom Tabs (replaces the command box)
frame(c)
b = BASE.bitmap; t = TOP.bitmap
field_strip(c, 196)
UI.rbox(b, 4, 214, W - 5, 356, 8, col(c[:panel], 246), c[:line])
["Actions", "Info", "Log"].each_with_index do |tb, i|
  on = i == 0
  UI.rbox(b, 12 + i * 90, 220, 96 + i * 90, 238, 4, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
  P.text(t, 12 + i * 90, 220, 84, 18, tb.upcase, on ? c[:white] : c[:dim], PF::TINY, 2)
end
ENTRIES.each_with_index do |(l, st, d, ic), i|
  gx = 12 + (i % 3) * 164; gy = 246 + (i / 3) * 52
  UI.rbox(b, gx, gy, gx + 158, gy + 46, 6, c[:dark], i == FAV ? GOLD : c[:line])
  cursor_at(gx, gy, 159, 47) if i == SEL
  item_icon(t, ic, gx + 20, gy + 23, 24)
  P.text(t, gx + 38, gy + 4, 116, 18, l, i == FAV ? GOLD : c[:txt], PF::TEXT)
  P.text(t, gx + 38, gy + 24, 116, 14, st.empty? ? " " : st, c[:acc], PF::TINY)
end
dump_as("BM4_menu")
frame(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 4, 120, W - 5, 356, 8, col(c[:panel], 246), c[:line])
["Actions", "Info", "Log"].each_with_index do |tb, i|
  on = i == 1
  UI.rbox(b, 12 + i * 90, 126, 96 + i * 90, 144, 4, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
  P.text(t, 12 + i * 90, 126, 84, 18, tb.upcase, on ? c[:white] : c[:dim], PF::TINY, 2)
end
P.text(t, 290, 126, 210, 18, "< Golduck >", c[:txt], PF::TEXT, 1)
stage_rows(c, 16, 150, 270, 20)
info_side(c, 300, 152, 200)
hints(c, [[:lr, "Pokémon"], ["p:9", "Tabs"], [B_BTN, "Back"]])
dump_as("BM4_info")
puts "done"
