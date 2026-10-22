# encoding: utf-8
# Mockups: four Reloaded PC designs, each as two screens: the box view (box
# name with Sort/Export locks, wallpaper, Pokemon, details, party) and Tools
# (Box Overview of every box with Buy Box, and Party Presets).
# Design 1 = HR's Reloaded PC screen in our UI kit.
# Usage: ruby pc_designs.rb "<KIF Beta>" <work dir with metrics.json>
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

BOX = %w[SQUIRTLE PSYDUCK POLIWAG TENTACOOL SLOWPOKE SEEL SHELLDER KRABBY HORSEA GOLDEEN STARYU MAGIKARP LAPRAS VAPOREON OMANYTE] +
      [:egg] + [nil] * 14
SHINY = ["MAGIKARP"]
SEL = 12                 # Lapras
PARTY = %w[PIKACHU GYARADOS GENGAR ALAKAZAM SNORLAX CHANSEY]
DETAIL = { :name => "Lapras", :lv => 30, :types => [11, 15], :nature => "Modest", :ability => "Water Absorb", :ivs => "IVs 142/186", :item => "Mystic Water" }
# Box Overview: [name, count, shiny?, egg?]
BOXES = [["Starters", 30, true, false], ["Grass", 22, false, true], ["Water Types", 16, true, true], ["Fire", 12, false, false],
         ["Bugs", 30, false, false], ["Fusions", 27, true, false], ["Legends", 9, true, false], ["Breeding", 18, false, true],
         ["Box 9", 4, false, false], ["Box 10", 0, false, false], ["Box 11", 0, false, false], ["Transfer", 2, false, false]]
CUR_BOX = 2
PRESETS = [["Main Team", %w[PIKACHU GYARADOS GENGAR ALAKAZAM SNORLAX CHANSEY]], ["Gym 4: Erika", %w[CHARIZARD PIDGEOT GENGAR ALAKAZAM LAPRAS JOLTEON]],
           ["Shiny Hunting", %w[GENGAR SNORLAX]]]
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
def mon(b, sp, cx, cy, size)
  return unless sp
  path = if sp == :egg
           File.join(GFX, "Pokemon/Eggs/000_icon.png")
         elsif SHINY.include?(sp)
           File.join(GFX, "Pokemon/Icons shiny/#{sp}.png")
         else
           File.join(GFX, "Pokemon/Icons/#{sp}.png")
         end
  path = File.join(GFX, "Pokemon/Icons/#{sp}.png") unless File.file?(path)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(path), Rect.new(0, 0, 64, 64))
end
def wallpaper(b, x, y, w, h)
  i = bmp(File.join(GFX, "Pictures/Storage/Wallpapers/box_11.png"))
  src = i.width >= 320 && i.height >= 290 ? Rect.new(4, 56, i.width - 8, i.height - 60) : Rect.new(0, 0, i.width, i.height)
  b.stretch_blt(Rect.new(x, y, w, h), i, src)
end
def type_icon(b, id, x, y, size = 16)
  b.stretch_blt(Rect.new(x, y, size, size), bmp(File.join(GFX, "Pictures/Battle/typesSmall.png")), Rect.new(0, id * 19, 19, 19))
end
def star(b, x, y, color)
  ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", "##...##"].each_with_index { |row, j| row.each_char.with_index { |ch, i| b.fill_rect(x + i, y + j, 1, 1, color) if ch == "#" } }
end
# Box name with KIF's Sort/Export lock letters: S green (unlocked), E red (locked)
def box_title(c, x, y, w, name = "Water Types", count = "16/30", font = PF::ROW)
  t = TOP.bitmap
  label = "#{name} (#{count})"
  lw = P.width(font, label)
  sx = x + (w - lw - 28) / 2
  P.text(t, sx, y, 12, 22, "S", GREEN, PF::TEXT)
  P.text(t, sx + 12, y, 12, 22, "E", RED, PF::TEXT)
  P.text(t, sx + 28, y, lw + 2, 22, label, c[:txt], font)
end
def details(c, x, y, w, big = 72)
  t = TOP.bitmap; b = BASE.bitmap
  P.text(t, x, y, w, 20, "#{DETAIL[:name]}  Lv #{DETAIL[:lv]}", c[:txt], PF::TEXT, 2)
  mon(t, "LAPRAS", x + w / 2, y + 22 + big / 2, big)
  ty = y + 26 + big
  DETAIL[:types].each_with_index { |id, k| type_icon(t, id, x + w / 2 - 18 + k * 20, ty) }
  [[DETAIL[:nature], c[:txt]], [DETAIL[:ability], c[:txt]], [DETAIL[:ivs], c[:acc]], [DETAIL[:item], c[:dim]]].each_with_index do |(s, cl), k|
    P.small(t, x, ty + 20 + k * 15, w, 15, s, cl, 2)
  end
end
def hints(c, pairs); P.hints(BASE.bitmap, TOP.bitmap, c, pairs, $style); end
H_BOX = [[:ud, "Move"], [A_BTN, "Pick Up"], [X_BTN, "Actions"], ["p:9", "Box"], ["p:4", "Tools"], [B_BTN, "Close"]]
def dump_as(name); dump(name); puts "wrote #{name}"; end

# Tools screen shared shape: Box Overview grid on the left, Party Presets on the right
def tools_screen(c, title_text, cols = 3, cell_w = 84, cell_h = 52, presets_x = 284, list = false)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
  P.text(t, 0, 2, W, 28, title_text, c[:title], PF::TITLE, 2)
  UI.rbox(b, 6, 36, presets_x - 6, 354, 6, c[:panel])
  P.text(t, 14, 40, 200, 12, "BOX OVERVIEW", c[:head], PF::TINY)
  if list
    (BOXES + [["+ Buy Box ($3,900)", -1, false, false]]).each_with_index do |(n, cnt, sh, eg), i|
      y = 54 + i * 23
      cursor_at(10, y, presets_x - 20, 22) if i == CUR_BOX
      P.text(t, 18, y, 120, 22, n, cnt < 0 ? c[:acc] : c[:txt], PF::TEXT)
      next if cnt < 0
      b.fill_rect(140, y + 9, 70, 5, c[:dark]); b.fill_rect(140, y + 9, (70 * cnt / 30.0).round, 5, cnt == 30 ? GOLD : GREEN)
      P.text(t, 214, y + 4, 34, 14, "#{cnt}", c[:dim], PF::TINY, 1)
      star(t, 254, y + 7, GOLD) if sh
      mon(t, :egg, presets_x - 18, y + 11, 14) if eg
    end
  end
  (list ? [] : (BOXES + [["Buy Box", -1, false, false]])).each_with_index do |(n, cnt, sh, eg), i|
    gx = 12 + (i % cols) * (cell_w + 4); gy = 56 + (i / cols) * (cell_h + 4)
    buy = cnt < 0
    UI.rbox(b, gx, gy, gx + cell_w - 1, gy + cell_h - 1, 5, buy ? c[:dark] : col(c[:panel2], 255), i == CUR_BOX ? c[:selb] : c[:line])
    cursor_at(gx, gy, cell_w, cell_h) if i == CUR_BOX
    if buy
      P.text(t, gx, gy + 6, cell_w, 18, "+ Buy Box", c[:acc], PF::TEXT, 2)
      P.text(t, gx, gy + 28, cell_w, 14, "$3,900", c[:dim], PF::TINY, 2)
      next
    end
    P.text(t, gx + 4, gy + 3, cell_w - 8, 16, PF.fit(PF::TINY, n, cell_w - 8), c[:txt], PF::TINY)
    b.fill_rect(gx + 4, gy + 22, cell_w - 8, 5, c[:dark])
    b.fill_rect(gx + 4, gy + 22, ((cell_w - 8) * cnt / 30.0).round, 5, cnt == 30 ? GOLD : GREEN)
    P.text(t, gx + 4, gy + 30, 40, 14, "#{cnt}/30", c[:dim], PF::TINY)
    star(t, gx + cell_w - 22, gy + 33, GOLD) if sh
    mon(t, :egg, gx + cell_w - 8, gy + 37, 14) if eg
  end
  UI.rbox(b, presets_x, 36, W - 6, 354, 6, c[:panel])
  P.text(t, presets_x + 8, 40, 200, 12, "PARTY PRESETS", c[:head], PF::TINY)
  PRESETS.each_with_index do |(n, team), i|
    py = 56 + i * 66
    UI.rbox(b, presets_x + 6, py, W - 12, py + 60, 5, col(c[:panel2], 255), c[:line])
    P.text(t, presets_x + 12, py + 2, 180, 18, n, c[:txt], PF::TEXT)
    team.each_with_index { |sp, k| mon(t, sp, presets_x + 24 + k * ((W - presets_x - 30) / 6), py + 40, 30) }
  end
  y = 56 + PRESETS.length * 66
  ["Save Current Party", "Swap In"].each_with_index do |l, i|
    UI.rbox(b, presets_x + 6, y + i * 30, W - 12, y + i * 30 + 24, 5, i == 1 ? c[:selb] : c[:dark], i == 1 ? nil : c[:line])
    P.text(t, presets_x + 6, y + i * 30, W - presets_x - 18, 24, l, i == 1 ? c[:dark] : c[:txt], PF::TEXT, 2)
  end
end

c = palette(2)

#================================================================ PC1 Recommended: HR's Reloaded PC, rebuilt
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, 42, c[:panel2]); b.fill_rect(0, 41, W, 1, c[:line])
P.text(t, 8, 10, 130, 22, "< Grass", BLUE, PF::TEXT)
box_title(c, 146, 10, 220)
P.text(t, W - 138, 10, 130, 22, "Fire >", BLUE, PF::TEXT, 1)
UI.rbox(b, 6, 46, 331, 273, 6, c[:panel])
wallpaper(b, 9, 49, 320, 222)
15.times do |k|
  cx = 12 + (k % 5) * 62; cy = 50 + (k / 5) * 72
  sp = BOX[k + 10 - 10 + 0]
  idx = k
  sp = BOX[idx]
  cursor_at(cx, cy, 60, 68) if idx == SEL
  mon(t, sp, cx + 30, cy + 34, 56)
  star(t, cx + 4, cy + 4, GOLD) if SHINY.include?(sp)
end
b.fill_rect(326, 52, 2, 214, c[:line]); b.fill_rect(326, 52, 2, 70, c[:dim])
UI.rbox(b, 338, 46, 506, 273, 6, c[:panel])
details(c, 340, 52, 164)
UI.rbox(b, 6, 280, 506, 350, 6, c[:panel])
P.text(t, 14, 284, 70, 14, "PARTY", c[:head], PF::TINY)
PARTY.each_with_index { |sp, k| mon(t, sp, 112 + k * 64, 316, 52) }
hints(c, H_BOX)
dump_as("PC1_box")
frame(c)
tools_screen(c, "PC Tools")
hints(c, [[:ud, "Choose"], [:lr, "Choose"], [A_BTN, "Open Box"], ["p:9", "Presets"], [B_BTN, "Back"]])
dump_as("PC1_tools")

#================================================================ PC2 Classic Full Box (PIF's layout)
frame(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 6, 6, 98, 354, 6, c[:panel])
P.text(t, 6, 10, 92, 14, "PARTY", c[:head], PF::TINY, 2)
PARTY.each_with_index { |sp, k| mon(t, sp, 52, 52 + k * 50, 48) }
UI.rbox(b, 104, 6, 506, 38, 6, c[:panel2], c[:line])
UI.tri(t, 114, 18, :l, c[:dim], 5); UI.tri(t, 490, 18, :r, c[:dim], 5)
box_title(c, 104, 11, 402)
UI.rbox(b, 104, 42, 506, 262, 6, c[:panel])
wallpaper(b, 107, 45, 396, 214)
30.times do |k|
  cx = 110 + (k % 6) * 65; cy = 46 + (k / 6) * 42
  cursor_at(cx, cy, 63, 41) if k == SEL
  mon(t, BOX[k], cx + 32, cy + 20, 40)
  star(t, cx + 4, cy + 3, GOLD) if SHINY.include?(BOX[k])
end
UI.rbox(b, 104, 268, 506, 354, 6, c[:panel2], c[:line])
mon(t, "LAPRAS", 144, 311, 64)
P.text(t, 184, 272, 200, 22, "Lapras  Lv 30", c[:txt], PF::ROW)
DETAIL[:types].each_with_index { |id, k| type_icon(t, id, 380 + k * 20, 278) }
P.small(t, 184, 298, 310, 15, "Modest · Water Absorb · Mystic Water", c[:txt])
P.small(t, 184, 314, 310, 15, "IVs 142/186", c[:acc])
hints(c, H_BOX)
dump_as("PC2_box")
frame(c)
tools_screen(c, "PC Tools", 4, 62, 52)
hints(c, [[:ud, "Choose"], [:lr, "Choose"], [A_BTN, "Open Box"], ["p:9", "Presets"], [B_BTN, "Back"]])
dump_as("PC2_tools")

#================================================================ PC3 List View (stats at a glance)
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
UI.tri(t, 12, 12, :l, c[:dim], 5); UI.tri(t, W - 18, 12, :r, c[:dim], 5)
box_title(c, 0, 6, W)
UI.rbox(b, 6, 38, 330, 354, 6, c[:panel])
["", "NAME", "LV", "TYPE", "IVS"].each_with_index { |h, i| P.text(t, [14, 46, 160, 200, 268][i], 42, 60, 12, h, c[:dim], PF::TINY) }
names = { "SQUIRTLE" => ["Squirtle", 18, [11], 120], "PSYDUCK" => ["Psyduck", 21, [11], 98], "POLIWAG" => ["Poliwag", 15, [11], 133],
          "TENTACOOL" => ["Tentacool", 22, [11, 3], 87], "SLOWPOKE" => ["Slowpoke", 20, [11, 14], 150], "SEEL" => ["Seel", 24, [11], 101],
          "SHELLDER" => ["Shellder", 19, [11], 77], "KRABBY" => ["Krabby", 23, [11], 112], "HORSEA" => ["Horsea", 17, [11], 140],
          "GOLDEEN" => ["Goldeen", 16, [11], 95], "STARYU" => ["Staryu", 21, [11], 128], "MAGIKARP" => ["Magikarp", 9, [11], 60],
          "LAPRAS" => ["Lapras", 30, [11, 15], 142] }
BOX.first(13).each_with_index do |sp, i|
  y = 56 + i * 22
  next if y > 334
  cursor_at(9, y, 318, 21) if i == SEL
  mon(t, sp, 26, y + 10, 22)
  n, lv, tys, iv = names[sp]
  P.text(t, 46, y, 110, 21, n, SHINY.include?(sp) ? GOLD : c[:txt], PF::TEXT)
  P.text(t, 160, y, 30, 21, lv.to_s, c[:txt], PF::TEXT)
  tys.each_with_index { |id, k| type_icon(t, id, 200 + k * 18, y + 3, 15) }
  P.text(t, 268, y, 50, 21, iv.to_s, iv > 130 ? GREEN : c[:dim], PF::TEXT)
end
UI.rbox(b, 336, 38, 506, 274, 6, c[:panel])
details(c, 338, 44, 166)
UI.rbox(b, 336, 280, 506, 354, 6, c[:panel])
P.text(t, 344, 284, 100, 12, "PARTY", c[:head], PF::TINY)
PARTY.each_with_index { |sp, k| mon(t, sp, 356 + (k % 6) * 26, 324, 26) }
hints(c, [[:ud, "Choose"], ["p:4", "Sort"], [A_BTN, "Pick Up"], [X_BTN, "Actions"], ["p:9", "Box"], [B_BTN, "Close"]])
dump_as("PC3_box")
frame(c)
tools_screen(c, "PC Tools", 3, 84, 52, 284, true)
hints(c, [[:ud, "Choose"], [A_BTN, "Open Box"], ["p:9", "Presets"], [B_BTN, "Back"]])
dump_as("PC3_tools")

#================================================================ PC4 Two Boxes Side by Side
frame(c)
b = BASE.bitmap; t = TOP.bitmap
[[6, "Water Types", "16/30", BOX, true], [259, "Fire", "12/30", %w[CHARMANDER VULPIX GROWLITHE PONYTA MAGMAR FLAREON CHARMELEON NINETALES ARCANINE RAPIDASH MAGMAR VULPIX] + [nil] * 18, false]].each do |x, n, cnt, list, active|
  UI.rbox(b, x, 6, x + 246, 34, 6, c[:panel2], active ? c[:selb] : c[:line])
  box_title(c, x, 9, 246, n, cnt, PF::TEXT)
  UI.rbox(b, x, 38, x + 246, 262, 6, c[:panel])
  wallpaper(b, x + 3, 41, 240, 218)
  30.times do |k|
    cx = x + 5 + (k % 6) * 40; cy = 42 + (k / 6) * 43
    cursor_at(cx, cy, 39, 42) if active && k == SEL
    mon(t, list[k], cx + 20, cy + 20, 38)
    star(t, cx + 2, cy + 2, GOLD) if SHINY.include?(list[k])
  end
end
UI.rbox(b, 6, 268, 506, 354, 6, c[:panel2], c[:line])
PARTY.each_with_index { |sp, k| mon(t, sp, 28 + k * 42, 312, 40) }
b.fill_rect(262, 276, 1, 70, c[:line])
mon(t, "LAPRAS", 290, 310, 46)
P.text(t, 316, 274, 190, 20, "Lapras  Lv 30", c[:txt], PF::TEXT)
DETAIL[:types].each_with_index { |id, k| type_icon(t, id, 470 + k * 18, 276, 15) }
P.small(t, 316, 296, 186, 15, "Modest · Water Absorb", c[:txt])
P.small(t, 316, 312, 186, 15, "IVs 142/186 · Mystic Water", c[:acc])
hints(c, [[:lr, "Move"], ["p:9", "Left Box"], ["p:10", "Right Box"], [A_BTN, "Pick Up"], [X_BTN, "Actions"], [B_BTN, "Close"]])
dump_as("PC4_box")
frame(c)
tools_screen(c, "PC Tools", 3, 84, 52)
hints(c, [[:ud, "Choose"], [:lr, "Choose"], [A_BTN, "Open Box"], ["p:9", "Presets"], [B_BTN, "Back"]])
dump_as("PC4_tools")
puts "done"
