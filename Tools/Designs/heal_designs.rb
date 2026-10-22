# encoding: utf-8
# Mockups: four Healing Overworld designs, each as two screens: Heal with Moves
# (the Healing Summary: who can heal, with which moves, how many uses left, and
# the party's HP) and the Heal Preview (Chansey's Soft-Boiled on Pikachu).
# Design 1 = the old KR flow (a list of healers, then a target) in our UI kit.
# Usage: ruby heal_designs.rb "<KIF Beta>" <work dir with metrics.json>
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

PARTY = [["CHANSEY", "Chansey", 310, 320, nil], ["PIKACHU", "Pikachu", 40, 95, nil], ["GENGAR", "Gengar", 40, 110, "PSN"],
         ["ALAKAZAM", "Alakazam", 50, 90, nil], ["SNORLAX", "Snorlax", 160, 160, nil]]
# [healer species, name, [[move, uses, what]]]
HEALERS = [["CHANSEY", "Chansey", [["Soft-Boiled", 8, "Heals one Pokémon"], ["Heal Bell", 5, "Cures the party"]]],
           ["ALAKAZAM", "Alakazam", [["Recover", 10, "Heals itself"]]],
           ["SNORLAX", "Snorlax", [["Rest", 5, "Heals itself, sleeps"]]]]
GREEN = Color.new(120, 230, 150); YELLOW = Color.new(240, 200, 70); RED = Color.new(240, 100, 90); GOLD = Color.new(240, 200, 70)
BLUE = Color.new(130, 190, 250)
A_BTN = "p:0"; B_BTN = "p:1"

def palette(theme)
  Reloaded::Settings.set(:"interface.theme", theme)
  return Reloaded::Palette.current
end
def col(c, a); Color.new(c.red, c.green, c.blue, a); end
$vp = Viewport.new(0, 0, W, H)
$vp.z = 99_999
def layer(z); s = Sprite.new($vp); s.bitmap = Bitmap.new(W, H); s.z = z; s; end
MAPS = Sprite.new($vp); MAPS.z = -1
MAPS.bitmap = Bitmap.new(File.join(HERE, "backdrop.png"))
BASE = layer(0)
CUR = Sprite.new($vp); CUR.z = 1
TOP = layer(2)
def frame(c, opaque = true, dim = 0)
  BASE.bitmap.clear; TOP.bitmap.clear
  CUR.visible = false
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
def mon_icon(b, species, cx, cy, size)
  i = bmp(File.join(GFX, "Pokemon/Icons/#{species}.png"))
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), i, Rect.new(0, 0, 64, 64))
end
def hp_color(hp, tot); f = hp.to_f / tot; f > 0.5 ? GREEN : (f > 0.25 ? YELLOW : RED); end
def hp_bar(b, x, y, w, hp, tot, c, h = 5, after = nil)
  b.fill_rect(x, y, w, h, c[:dark])
  b.fill_rect(x, y, (w * after.to_f / tot).round, h, Color.new(120, 230, 150, 110)) if after
  b.fill_rect(x, y, (w * hp.to_f / tot).round, h, hp_color(hp, tot))
end
def title(c, text)
  BASE.bitmap.fill_rect(0, 0, W, 32, c[:panel2]); BASE.bitmap.fill_rect(0, 31, W, 1, c[:line])
  P.text(TOP.bitmap, 0, 2, W, 28, text, c[:title], PF::TITLE, 2)
end
def buttons(labels, cx, y, c, sel = 0, w = 96)
  b = BASE.bitmap; t = TOP.bitmap
  x = cx - (labels.length * w + (labels.length - 1) * 10) / 2
  labels.each_with_index do |l, i|
    UI.rbox(b, x, y, x + w, y + 24, 5, i == sel ? c[:selb] : c[:dark], i == sel ? nil : c[:line])
    P.text(t, x, y, w, 24, l, i == sel ? c[:dark] : c[:txt], PF::TEXT, 2)
    x += w + 10
  end
end
# Heal Preview body: who heals whom, HP before -> after, the cost
def preview_rows(c, x, y, w)
  b = BASE.bitmap; t = TOP.bitmap
  mon_icon(t, "PIKACHU", x + 20, y + 18, 36)
  P.text(t, x + 44, y, 120, 18, "Pikachu", c[:txt], PF::TEXT)
  hp_bar(b, x + 44, y + 22, w - 130, 40, 95, c, 6, 95)
  P.text(t, x + w - 80, y + 2, 80, 16, "40 to 95", GREEN, PF::TEXT, 1)
  P.text(t, x + w - 80, y + 18, 80, 14, "+55 HP", GREEN, PF::TINY, 1)
  mon_icon(t, "CHANSEY", x + 20, y + 62, 36)
  P.text(t, x + 44, y + 44, 120, 18, "Chansey", c[:txt], PF::TEXT)
  hp_bar(b, x + 44, y + 66, w - 130, 246, 320, c, 6)
  P.text(t, x + w - 80, y + 46, 80, 16, "310 to 246", YELLOW, PF::TEXT, 1)
  P.text(t, x + w - 80, y + 62, 80, 14, "PP 8 to 7", BLUE, PF::TINY, 1)
end
def hints(c, pairs); P.hints(BASE.bitmap, TOP.bitmap, c, pairs, $style); end
def dump_as(name); dump(name); puts "wrote #{name}"; end

c = palette(2)

#================================================================ H1 Recommended: healer list, then a target
frame(c, false, 110)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 70, 20, 442, 352, 8, col(c[:panel], 240), c[:line])
P.text(t, 70, 24, 372, 26, "Heal with Moves", c[:title], PF::ROW, 2)
b.fill_rect(80, 52, 352, 1, c[:line])
y = 58
HEALERS.each_with_index do |(sp, name, moves), hi|
  mon_icon(t, sp, 96, y + 14, 30)
  P.text(t, 116, y + 2, 140, 18, name, c[:txt], PF::TEXT)
  y += 26
  moves.each_with_index do |(mv, uses, what), mi|
    cursor_at(84, y - 2, 344, 24) if hi == 0 && mi == 0
    P.text(t, 124, y, 120, 20, mv, c[:white], PF::TEXT)
    P.small(t, 240, y + 2, 130, 16, what, c[:dim])
    P.text(t, 376, y, 46, 20, "#{uses} Left", GREEN, PF::TINY, 1)
    y += 24
  end
  y += 6
end
b.fill_rect(80, 262, 352, 1, c[:line])
P.text(t, 84, 266, 200, 12, "PARTY", c[:head], PF::TINY)
PARTY.each_with_index do |(sp, name, hp, tot, st), i|
  px = 86 + i * 70
  mon_icon(t, sp, px + 26, 296, 34)
  hp_bar(b, px + 4, 316, 48, hp, tot, c)
  P.text(t, px - 6, 322, 70, 14, st || "#{hp}/#{tot}", st ? Color.new(200, 120, 220) : hp_color(hp, tot), PF::TINY, 2)
end
hints(c, [[:ud, "Choose"], [A_BTN, "Use"], [B_BTN, "Back"]])
dump_as("H1_summary")
frame(c, false, 110)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 86, 70, 426, 290, 8, c[:panel2], c[:line])
P.text(t, 86, 74, 340, 26, "Soft-Boiled on Pikachu?", c[:title], PF::ROW, 2)
b.fill_rect(96, 102, 320, 1, c[:line])
preview_rows(c, 104, 112, 304)
P.small(t, 100, 206, 312, 16, "Chansey gives up a fifth of its max HP.", c[:dim])
buttons(["Use", "Back"], 256, 250, c)
hints(c, [[:lr, "Choose"], [A_BTN, "Select"], [B_BTN, "Back"]])
dump_as("H1_preview")

#================================================================ H2 Healer Cards
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title(c, "Heal with Moves")
HEALERS.each_with_index do |(sp, name, moves), i|
  cx = 8 + i * 168
  UI.rbox(b, cx, 40, cx + 160, 236, 8, c[:panel], i == 0 ? c[:selb] : c[:line])
  mon_icon(t, sp, cx + 80, 76, 56)
  P.text(t, cx, 104, 160, 20, name, c[:txt], PF::ROW, 2)
  moves.each_with_index do |(mv, uses, what), mi|
    my = 132 + mi * 48
    UI.rbox(b, cx + 8, my, cx + 152, my + 42, 5, c[:dark], c[:line])
    cursor_at(cx + 8, my, 145, 43) if i == 0 && mi == 0
    P.text(t, cx + 14, my + 2, 100, 18, mv, c[:white], PF::TEXT)
    P.text(t, cx + 100, my + 3, 46, 16, "#{uses}", GREEN, PF::TEXT, 1)
    P.small(t, cx + 14, my + 22, 136, 15, what, c[:dim])
  end
end
UI.rbox(b, 8, 244, W - 9, 352, 8, c[:panel2], c[:line])
P.text(t, 18, 250, 200, 12, "PARTY HP", c[:head], PF::TINY)
PARTY.each_with_index do |(sp, name, hp, tot, st), i|
  px = 18 + i * 98
  mon_icon(t, sp, px + 20, 290, 38)
  P.text(t, px + 40, 272, 56, 14, name, c[:txt], PF::TINY)
  hp_bar(b, px + 40, 290, 52, hp, tot, c)
  P.text(t, px + 40, 298, 56, 14, st || "#{hp}/#{tot}", st ? Color.new(200, 120, 220) : hp_color(hp, tot), PF::TINY)
end
hints(c, [[:lr, "Healer"], [:ud, "Move"], [A_BTN, "Use"], [B_BTN, "Back"]])
dump_as("H2_summary")
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title(c, "Heal Preview")
UI.rbox(b, 8, 40, W - 9, 160, 8, c[:panel], c[:line])
mon_icon(t, "CHANSEY", 60, 100, 64)
P.text(t, 100, 64, 120, 20, "Soft-Boiled", c[:white], PF::ROW)
P.text(t, 100, 90, 160, 14, "PP 8 to 7 · HP 310 to 246", BLUE, PF::TINY)
UI.tri(t, 254, 94, :r, c[:dim], 8)
mon_icon(t, "PIKACHU", 330, 100, 64)
P.text(t, 370, 64, 120, 20, "Pikachu", c[:txt], PF::ROW)
P.text(t, 370, 90, 140, 14, "+55 HP · 40 to 95", GREEN, PF::TINY)
UI.rbox(b, 8, 168, W - 9, 300, 8, c[:panel2], c[:line])
P.text(t, 18, 174, 200, 12, "AFTER", c[:head], PF::TINY)
PARTY.each_with_index do |(sp, name, hp, tot, st), i|
  px = 18 + i * 98
  after = sp == "PIKACHU" ? 95 : (sp == "CHANSEY" ? 246 : hp)
  mon_icon(t, sp, px + 20, 214, 38)
  P.text(t, px + 40, 196, 56, 14, name, c[:txt], PF::TINY)
  hp_bar(b, px + 40, 214, 52, after, tot, c)
  P.text(t, px + 40, 222, 56, 14, "#{after}/#{tot}", hp_color(after, tot), PF::TINY)
end
buttons(["Use", "Back"], 256, 262, c)
hints(c, [[:lr, "Choose"], [A_BTN, "Select"], [B_BTN, "Back"]])
dump_as("H2_preview")

#================================================================ H3 Party Grid (pick who needs healing)
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title(c, "Heal with Moves")
PARTY.each_with_index do |(sp, name, hp, tot, st), i|
  gx = 8 + (i % 3) * 168; gy = 40 + (i / 3) * 74
  UI.rbox(b, gx, gy, gx + 160, gy + 68, 8, c[:panel], c[:line])
  cursor_at(gx, gy, 161, 69) if i == 1
  mon_icon(t, sp, gx + 30, gy + 34, 48)
  P.text(t, gx + 58, gy + 6, 100, 18, name, c[:txt], PF::TEXT)
  hp_bar(b, gx + 58, gy + 32, 94, hp, tot, c, 6)
  P.text(t, gx + 58, gy + 42, 100, 14, st ? "#{hp}/#{tot} · #{st}" : "#{hp}/#{tot}", hp_color(hp, tot), PF::TINY)
end
UI.rbox(b, 344, 114, W - 8, 184, 8, c[:panel2], c[:line])
P.text(t, 352, 118, 150, 12, "HEALS LEFT", c[:head], PF::TINY)
P.small(t, 352, 132, 152, 15, "Soft-Boiled 8", GREEN)
P.small(t, 352, 147, 152, 15, "Heal Bell 5", GREEN)
P.small(t, 352, 162, 152, 15, "Recover 10, Rest 5", c[:dim])
UI.rbox(b, 8, 192, W - 9, 352, 8, c[:panel2], c[:line])
P.text(t, 18, 198, 300, 12, "WHO CAN HEAL PIKACHU", c[:head], PF::TINY)
[["CHANSEY", "Chansey", "Soft-Boiled", "8 Left", "+55 HP"], ["CHANSEY", "Chansey", "Heal Bell", "5 Left", "No Status"]].each_with_index do |(sp, n, mv, left, gain), i|
  y = 216 + i * 40
  cursor_at(14, y, W - 30, 36) if i == 0 && false
  UI.rbox(b, 14, y, W - 16, y + 36, 6, i == 0 ? c[:sel] : c[:dark], i == 0 ? c[:selb] : c[:line])
  mon_icon(t, sp, 36, y + 18, 30)
  P.text(t, 58, y + 2, 200, 18, "#{n} · #{mv}", c[:txt], PF::TEXT)
  P.text(t, 58, y + 20, 100, 14, left, BLUE, PF::TINY)
  P.text(t, 360, y + 8, 130, 18, gain, i == 0 ? GREEN : c[:dim], PF::TEXT, 1)
end
hints(c, [[:lr, "Pokémon"], [:ud, "Healer"], [A_BTN, "Use"], [B_BTN, "Back"]])
dump_as("H3_summary")
frame(c)
b = BASE.bitmap; t = TOP.bitmap
title(c, "Heal with Moves")
PARTY.each_with_index do |(sp, name, hp, tot, st), i|
  gx = 8 + (i % 3) * 168; gy = 40 + (i / 3) * 74
  after = sp == "PIKACHU" ? 95 : (sp == "CHANSEY" ? 246 : hp)
  UI.rbox(b, gx, gy, gx + 160, gy + 68, 8, c[:panel], [1, 0].include?(i) ? GREEN : c[:line])
  mon_icon(t, sp, gx + 30, gy + 34, 48)
  P.text(t, gx + 58, gy + 6, 100, 18, name, c[:txt], PF::TEXT)
  hp_bar(b, gx + 58, gy + 32, 94, hp, tot, c, 6, after > hp ? after : nil)
  label = after != hp ? "#{hp} to #{after}" : "#{hp}/#{tot}"
  P.text(t, gx + 58, gy + 42, 100, 14, label, after > hp ? GREEN : (after < hp ? YELLOW : hp_color(hp, tot)), PF::TINY)
end
UI.rbox(b, 70, 200, 442, 340, 8, c[:panel2], c[:line])
P.text(t, 70, 206, 372, 22, "Soft-Boiled on Pikachu?", c[:title], PF::ROW, 2)
P.small(t, 80, 236, 352, 16, "Pikachu +55 HP. Chansey -64 HP and 1 PP (8 to 7).", c[:txt], 2)
buttons(["Use", "Back"], 256, 290, c)
hints(c, [[:lr, "Choose"], [A_BTN, "Select"], [B_BTN, "Back"]])
dump_as("H3_preview")

#================================================================ H4 Settings Style
def h4_frame(c, title_text)
  frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  title(c, title_text)
  UI.rbox(b, 6, 36, 150, 262, 6, c[:panel])
  UI.rbox(b, 156, 36, W - 6, 262, 6, c[:panel])
  UI.rbox(b, 6, 268, W - 6, H - 30, 6, c[:panel2], c[:line])
end
h4_frame(c, "Heal with Moves")
b = BASE.bitmap; t = TOP.bitmap
HEALERS.each_with_index do |(sp, name, moves), i|
  y = 42 + i * 34
  UI.rbox(b, 10, y, 146, y + 30, 5, c[:sel], c[:selb]) if i == 0
  mon_icon(t, sp, 28, y + 15, 28)
  P.text(t, 46, y, 96, 30, name, i == 0 ? c[:white] : c[:txt], PF::TEXT)
end
P.heading(t, 166, W - 16, 42, "Chansey's Healing Moves", c[:head], c[:line])
HEALERS[0][2].each_with_index do |(mv, uses, what), i|
  y = 58 + i * 30
  cursor_at(160, y, W - 170, 28) if i == 0
  P.text(t, 172, y, 160, 28, mv, c[:txt], PF::ROW)
  P.text(t, 380, y, 110, 28, "#{uses} Left", GREEN, PF::TEXT, 1)
end
P.heading(t, 166, W - 16, 130, "Party", c[:head], c[:line])
PARTY.each_with_index do |(sp, name, hp, tot, st), i|
  px = 166 + i * 68
  mon_icon(t, sp, px + 26, 168, 34)
  hp_bar(b, px + 4, 188, 48, hp, tot, c)
  P.text(t, px - 6, 194, 70, 14, st || "#{hp}/#{tot}", st ? Color.new(200, 120, 220) : hp_color(hp, tot), PF::TINY, 2)
end
P.text(t, 16, 270, 300, 24, "Soft-Boiled", c[:head], PF::ROW)
P.small(t, 16, 296, 480, 16, "Gives a fifth of Chansey's max HP to another Pokémon. 8 uses left.", c[:txt])
P.small(t, 16, 312, 480, 16, "Your party can heal 23 more times before you need a Center.", c[:dim])
hints(c, [[:ud, "Choose"], [:lr, "Sections"], [A_BTN, "Use"], [B_BTN, "Back"]])
dump_as("H4_summary")
h4_frame(c, "Heal Preview")
b = BASE.bitmap; t = TOP.bitmap
HEALERS.each_with_index do |(sp, name, moves), i|
  y = 42 + i * 34
  UI.rbox(b, 10, y, 146, y + 30, 5, c[:sel], c[:selb]) if i == 0
  mon_icon(t, sp, 28, y + 15, 28)
  P.text(t, 46, y, 96, 30, name, i == 0 ? c[:white] : c[:txt], PF::TEXT)
end
P.heading(t, 166, W - 16, 42, "Soft-Boiled on Pikachu", c[:head], c[:line])
preview_rows(c, 166, 62, 330)
cursor_at(160, 60, W - 170, 40)
P.text(t, 16, 270, 300, 24, "Use Soft-Boiled?", c[:head], PF::ROW)
P.small(t, 16, 296, 480, 16, "Pikachu +55 HP. Chansey gives 64 HP and 1 PP.", c[:txt])
hints(c, [[A_BTN, "Use"], [B_BTN, "Back"]])
dump_as("H4_preview")
puts "done"
