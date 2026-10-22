# encoding: utf-8
# Mockups: five PokeVial popup designs, each as two screens: using the vial
# (with Heal Preview) over the map, and the refill at a Pokemon Center.
# Design 1 = the old KR/HR flow (a confirm, then a message) in our UI kit.
# Usage: ruby pv_designs.rb "<KIF Beta>" <work dir with metrics.json>
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
CHARGES = 2; MAXC = 4
# [species, name, hp, total, change text, kind]  kind: :hp :none :cure :revive :pp
PARTY = [["PIKACHU", "Pikachu", 78, 95, "+17 HP", :hp], ["GYARADOS", "Gyarados", 120, 120, "Healthy", :none],
         ["GENGAR", "Gengar", 40, 110, "+70 HP, Cures Poison", :cure], ["ALAKAZAM", "Alakazam", 0, 90, "Revived", :revive],
         ["SNORLAX", "Snorlax", 160, 160, "PP Restored", :pp]]
GREEN = Color.new(120, 230, 150); YELLOW = Color.new(240, 200, 70); RED = Color.new(240, 100, 90)
GOLD = Color.new(240, 200, 70); PINK = Color.new(255, 120, 150)
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
BG_MAP = Bitmap.new(File.join(HERE, "backdrop.png"))
BG_PC = Bitmap.new(File.join(HERE, "backdrop_pc.png"))
BASE = layer(0)
CUR = Sprite.new($vp); CUR.z = 1
TOP = layer(2)

def frame(c, bg, dim = 0)
  MAPS.bitmap = bg
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
def draw_img(b, path, cx, cy, size, src = nil)
  i = bmp(path)
  src ||= Rect.new(0, 0, i.width, i.height)
  sc = size.to_f / [src.width, src.height].max
  w = (src.width * sc).round; h = (src.height * sc).round
  b.stretch_blt(Rect.new(cx - w / 2, cy - h / 2, w, h), i, src)
end
def vial_icon(b, cx, cy, size); draw_img(b, File.join(HERE, "icons", "POKEVIAL.png"), cx, cy, size); end
def mon_icon(b, species, cx, cy, size)
  draw_img(b, File.join(GFX, "Pokemon/Icons/#{species}.png"), cx, cy, size, Rect.new(0, 0, 64, 64))
end
def stext(b, x, y, w, h, str, color, font, align, c)
  P.text(b, x + 1, y + 1, w, h, str, c[:shadow], font, align)
  P.text(b, x, y, w, h, str, color, font, align)
end
def panel(b, x0, y0, x1, y1, c, alpha = 235, r = 6)
  UI.rbox(b, x0, y0, x1, y1, r, col(c[:panel], alpha), c[:line])
end
def hp_color(hp, tot); f = hp.to_f / tot; f > 0.5 ? GREEN : (f > 0.25 ? YELLOW : RED); end
# An HP bar with the part the vial restores shown as a pale "ghost"
def hp_bar(b, x, y, w, hp, tot, c, h = 5, gain = true)
  b.fill_rect(x, y, w, h, c[:dark])
  b.fill_rect(x, y, w, h, Color.new(120, 230, 150, 90)) if gain
  b.fill_rect(x, y, (w * hp.to_f / tot).round, h, hp_color(hp, tot)) if hp > 0
end
def change_color(kind); { :hp => GREEN, :cure => GREEN, :revive => PINK, :pp => Color.new(130, 190, 250) }[kind] || nil; end
# Charge pips: filled for charges left, hollow for used
def pips(b, x, y, c, filled = CHARGES, max = MAXC, s = 10, refill = 0)
  max.times do |i|
    px = x + i * (s + 4)
    if i < filled
      UI.rbox(b, px, y, px + s, y + s, 3, PINK)
    elsif i < filled + refill
      UI.rbox(b, px, y, px + s, y + s, 3, Color.new(255, 120, 150, 110), PINK)
    else
      UI.rbox(b, px, y, px + s, y + s, 3, c[:dark], c[:line])
    end
  end
  max * (s + 4) - 4
end
def buttons(b, top, labels, cx, y, c, sel = 0, w = nil)
  widths = labels.map { |l| w || [P.width(PF::TEXT, l) + 28, 84].max }
  x = cx - (widths.sum + 10 * (labels.length - 1)) / 2
  labels.each_with_index do |l, i|
    if i == sel
      UI.rbox(b, x, y, x + widths[i], y + 24, 5, c[:selb])
      P.text(top, x, y, widths[i], 24, l, c[:dark], PF::TEXT, 2)
    else
      UI.rbox(b, x, y, x + widths[i], y + 24, 5, c[:dark], c[:line])
      P.text(top, x, y, widths[i], 24, l, c[:txt], PF::TEXT, 2)
    end
    x += widths[i] + 10
  end
end
def speech(c, text, y = 300, h = 76)
  panel(BASE.bitmap, 8, y, W - 9, y + h, c, 245, 8)
  P.wrap(text, W - 44, PF::TEXT).first(3).each_with_index { |ln, k| P.text(TOP.bitmap, 22, y + 10 + k * 20, W - 44, 18, ln, c[:txt], PF::TEXT) }
end
def hints(c, pairs); P.hints(BASE.bitmap, TOP.bitmap, c, pairs, $style); end
def dump_as(name); dump(name); puts "wrote #{name}"; end

c = palette(2)

#================================================================ V1 Recommended: confirm dialog + preview, then a message
frame(c, BG_MAP, 120)
b = BASE.bitmap; t = TOP.bitmap
x0 = 86; x1 = 426; y0 = 40; y1 = 342
UI.rbox(b, x0, y0, x1, y1, 6, c[:panel2], c[:line])
vial_icon(t, x0 + 24, y0 + 19, 26)
P.text(t, x0, y0 + 6, x1 - x0, 26, "PokeVial", c[:title], PF::ROW, 2)
pw = pips(b, x1 - 70, y0 + 13, c)
b.fill_rect(x0 + 10, y0 + 34, x1 - x0 - 20, 1, c[:line])
P.text(t, x0 + 14, y0 + 38, 200, 14, "HEAL PREVIEW", c[:head], PF::TINY)
P.text(t, x1 - 154, y0 + 38, 140, 14, "FULL HEAL", c[:dim], PF::TINY, 1)
PARTY.each_with_index do |(sp, name, hp, tot, chg, kind), i|
  ry = y0 + 56 + i * 38
  mon_icon(t, sp, x0 + 28, ry + 16, 36)
  P.text(t, x0 + 50, ry + 1, 120, 16, name, c[:txt], PF::TEXT)
  hp_bar(b, x0 + 50, ry + 21, 110, hp, tot, c, 5, kind != :none)
  P.text(t, x0 + 166, ry + 14, 70, 14, "#{hp}/#{tot}", hp_color([hp, 1].max, tot), PF::TINY)
  cc = change_color(kind)
  P.text(t, x0 + 210, ry + 3, x1 - x0 - 224, 16, chg, cc || c[:dim], PF::TINY, 1)
end
buttons(b, t, ["Use PokeVial", "Back"], (x0 + x1) / 2, y1 - 34, c)
hints(c, [[:lr, "Choose"], [A_BTN, "Select"], [B_BTN, "Back"]])
dump_as("V1_use")
frame(c, BG_PC)
b = BASE.bitmap; t = TOP.bitmap
x0 = 116; x1 = 396; y0 = 70; y1 = 226
UI.rbox(b, x0, y0, x1, y1, 6, c[:panel2], c[:line])
vial_icon(t, x0 + 24, y0 + 19, 26)
P.text(t, x0, y0 + 6, x1 - x0, 26, "Refill PokeVial?", c[:title], PF::ROW, 2)
b.fill_rect(x0 + 10, y0 + 34, x1 - x0 - 20, 1, c[:line])
pips(b, (x0 + x1) / 2 - 27, y0 + 46, c, CHARGES, MAXC, 10, 2)
P.text(t, x0, y0 + 62, x1 - x0, 18, "2 Charges Missing", c[:txt], PF::TEXT, 2)
P.small(t, x0, y0 + 82, x1 - x0, 16, "$500 each: $1,000 (you have $12,450)", c[:dim], 2)
buttons(b, t, ["Refill", "Not Now"], (x0 + x1) / 2, y1 - 34, c)
speech(c, "We've restored your Pokémon to full health. We hope to see you again!")
dump_as("V1_center")

#================================================================ V2 Vial Gauge
frame(c, BG_MAP, 140)
b = BASE.bitmap; t = TOP.bitmap
def big_vial(b, t, c, x, y, filled, refill = 0)
  # a bottle: neck, body split into MAXC segments filled from the bottom
  UI.rbox(b, x + 30, y, x + 58, y + 14, 3, c[:line])
  UI.rbox(b, x + 26, y + 12, x + 62, y + 22, 3, c[:key])
  UI.rbox(b, x, y + 22, x + 88, y + 222, 16, c[:dark], c[:selb])
  seg = 46
  MAXC.times do |i|
    sy = y + 216 - (i + 1) * (seg + 2)
    color = i < filled ? PINK : (i < filled + refill ? Color.new(255, 120, 150, 120) : nil)
    UI.rbox(b, x + 8, sy, x + 80, sy + seg, 8, color) if color
  end
end
panel(b, 14, 14, 498, 352, c, 235, 10)
stext(t, 14, 18, 484, 26, "PokeVial", c[:title], PF::TITLE, 2, c)
big_vial(b, t, c, 46, 64, CHARGES)
P.text(t, 20, 300, 140, 20, "2 of 4 Charges", c[:txt], PF::TEXT, 2)
P.small(t, 20, 320, 140, 14, "Full Heal", c[:dim], 2)
PARTY.each_with_index do |(sp, name, hp, tot, chg, kind), i|
  cx = 176 + (i % 2) * 160; cy = 58 + (i / 2) * 78
  UI.rbox(b, cx, cy, cx + 152, cy + 70, 6, col(c[:panel2], 240), c[:line])
  mon_icon(t, sp, cx + 26, cy + 30, 44)
  P.text(t, cx + 52, cy + 6, 96, 16, name, c[:txt], PF::TEXT)
  hp_bar(b, cx + 52, cy + 28, 92, hp, tot, c, 5, kind != :none)
  P.text(t, cx + 52, cy + 36, 96, 14, "#{hp}/#{tot}", hp_color([hp, 1].max, tot), PF::TINY)
  P.text(t, cx + 6, cy + 52, 140, 14, chg, change_color(kind) || c[:dim], PF::TINY, 1)
end
buttons(b, t, ["Use", "Back"], 416, 296, c, 0, 70)
hints(c, [[:lr, "Choose"], [A_BTN, "Use"], [B_BTN, "Back"]])
dump_as("V2_use")
frame(c, BG_PC, 120)
b = BASE.bitmap; t = TOP.bitmap
panel(b, 96, 40, 416, 270, c, 240, 10)
stext(t, 96, 44, 320, 26, "Refill PokeVial", c[:title], PF::ROW, 2, c)
big_vial(b, t, c, 122, 62, CHARGES, 2)
P.text(t, 232, 92, 170, 18, "2 Charges Missing", c[:txt], PF::TEXT)
P.small(t, 232, 114, 170, 16, "$500 each", c[:dim])
P.text(t, 232, 140, 170, 18, "Total: $1,000", GOLD, PF::TEXT)
P.small(t, 232, 162, 170, 16, "You have $12,450", c[:dim])
buttons(b, t, ["Refill", "Not Now"], 316, 228, c, 0, 76)
speech(c, "We've restored your Pokémon to full health. We hope to see you again!", 290, 64)
dump_as("V2_center")

#================================================================ V3 Bottom Sheet
frame(c, BG_MAP)
b = BASE.bitmap; t = TOP.bitmap
panel(b, 6, 222, W - 7, 352, c, 240, 10)
vial_icon(t, 30, 246, 30)
P.text(t, 50, 232, 140, 20, "PokeVial", c[:title], PF::ROW)
pips(b, 52, 254, c)
P.small(t, 120, 251, 140, 16, "2 of 4 · Full Heal", c[:dim])
pw = 96
(PARTY + [[nil]]).first(5).each_with_index do |(sp, name, hp, tot, chg, kind), i|
  px = 20 + i * pw
  mon_icon(t, sp, px + 40, 296, 44)
  hp_bar(b, px + 12, 320, 66, hp, tot, c, 5, kind != :none)
  cc = change_color(kind)
  short = { :hp => "+17", :none => "Full", :cure => "+70, Cured", :revive => "Revive", :pp => "PP" }[kind]
  P.text(t, px, 328, 90, 14, short, cc || c[:dim], PF::TINY, 2)
end
hints(c, [[A_BTN, "Use a Charge"], [B_BTN, "Back"]])
dump_as("V3_use")
frame(c, BG_PC)
b = BASE.bitmap; t = TOP.bitmap
panel(b, 6, 222, W - 7, 352, c, 240, 10)
P.text(t, 20, 230, 400, 18, "Nurse Joy", c[:head], PF::TEXT)
P.text(t, 20, 252, W - 40, 18, "Your Pokémon are healed! Refill your PokeVial too?", c[:txt], PF::TEXT)
vial_icon(t, 34, 300, 30)
pips(b, 56, 294, c, CHARGES, MAXC, 10, 2)
P.small(t, 116, 291, 200, 16, "2 Charges for $1,000", GOLD)
buttons(b, t, ["Refill", "Not Now"], 400, 290, c, 0, 76)
hints(c, [[:lr, "Choose"], [A_BTN, "Select"], [B_BTN, "Not Now"]])
dump_as("V3_center")

#================================================================ V4 Full Screen (Settings look)
def fs_screen(c, bg, title)
  frame(c, bg, 255)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, H, c[:bg])
  b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
  P.text(t, 0, 3, W, 28, title, c[:title], PF::TITLE, 2)
end
fs_screen(c, BG_MAP, "PokeVial")
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 6, 40, 174, 262, 6, c[:panel])
vial_icon(t, 90, 80, 56)
P.text(t, 6, 112, 168, 18, "2 of 4 Charges", c[:txt], PF::TEXT, 2)
pips(b, 62, 134, c)
[["Heal Mode", "Full Heal"], ["Cooldown", "Ready"], ["Refill", "At Centers, $500"]].each_with_index do |(k, v), i|
  y = 160 + i * 32
  P.text(t, 16, y, 150, 12, k.upcase, c[:head], PF::TINY)
  P.text(t, 16, y + 12, 150, 16, v, c[:txt], PF::TEXT)
end
UI.rbox(b, 180, 40, W - 6, 262, 6, c[:panel])
P.heading(t, 190, W - 16, 46, "Heal Preview", c[:head], c[:line])
PARTY.each_with_index do |(sp, name, hp, tot, chg, kind), i|
  ry = 62 + i * 39
  mon_icon(t, sp, 206, ry + 17, 36)
  P.text(t, 228, ry + 1, 110, 16, name, c[:txt], PF::TEXT)
  hp_bar(b, 228, ry + 21, 120, hp, tot, c, 5, kind != :none)
  P.text(t, 354, ry + 14, 70, 14, "#{hp}/#{tot}", hp_color([hp, 1].max, tot), PF::TINY)
  P.text(t, 330, ry + 2, W - 340, 16, chg, change_color(kind) || c[:dim], PF::TINY, 1)
end
UI.rbox(b, 6, 268, W - 6, H - 30, 6, c[:panel2], c[:line])
P.text(t, 16, 270, 300, 24, "Use a Charge?", c[:head], PF::ROW)
P.small(t, 16, 296, W - 34, 17, "Heals your whole party as shown. 1 of 4 charges will be left.", c[:txt])
P.small(t, 16, 314, W - 34, 17, "Refills at any Pokémon Center.", c[:dim])
hints(c, [[A_BTN, "Use a Charge"], [B_BTN, "Back"]])
dump_as("V4_use")
fs_screen(c, BG_PC, "PokeVial Refill")
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 6, 40, 174, 262, 6, c[:panel])
vial_icon(t, 90, 80, 56)
P.text(t, 6, 112, 168, 18, "2 of 4 Charges", c[:txt], PF::TEXT, 2)
pips(b, 62, 134, c, CHARGES, MAXC, 10, 2)
UI.rbox(b, 180, 40, W - 6, 262, 6, c[:panel])
P.heading(t, 190, W - 16, 46, "Refill", c[:head], c[:line])
[["Missing Charges", "2"], ["Cost per Charge", "$500"], ["Total", "$1,000"], ["Your Money", "$12,450"], ["After Refill", "$11,450"]].each_with_index do |(k, v), i|
  y = 64 + i * 30
  cursor_at(184, y - 2, W - 194, 28) if i == 2
  P.text(t, 196, y, 200, 24, k, c[:txt], PF::ROW)
  P.text(t, 330, y, W - 350, 24, v, i == 2 ? GOLD : c[:txt], PF::TEXT, 1)
end
UI.rbox(b, 6, 268, W - 6, H - 30, 6, c[:panel2], c[:line])
P.text(t, 16, 270, 300, 24, "Refill Your PokeVial?", c[:head], PF::ROW)
P.small(t, 16, 296, W - 34, 17, "Your Pokémon are healed. Refilling brings the vial back to 4 of 4.", c[:txt])
hints(c, [[A_BTN, "Refill"], [B_BTN, "Not Now"]])
dump_as("V4_center")

#================================================================ V5 Speech Native
frame(c, BG_MAP)
b = BASE.bitmap; t = TOP.bitmap
# floating preview strip above the message box
panel(b, 8, 180, 380, 262, c, 235, 8)
PARTY.each_with_index do |(sp, name, hp, tot, chg, kind), i|
  px = 18 + i * 72
  mon_icon(t, sp, px + 32, 202, 40)
  hp_bar(b, px + 6, 226, 54, hp, tot, c, 4, kind != :none)
  short = { :hp => "+17", :none => "Full", :cure => "Cured", :revive => "Revive", :pp => "PP" }[kind]
  P.text(t, px - 6, 234, 76, 14, short, change_color(kind) || c[:dim], PF::TINY, 2)
end
speech(c, "Use the PokeVial? It has 2 of 4 charges. Your party will be fully healed.", 270, 82)
panel(b, 388, 204, 504, 262, c, 245, 6)
["Use", "Back"].each_with_index do |l, i|
  y = 208 + i * 26
  cursor_at(394, y, 104, 24) if i == 0
  P.text(t, 408, y, 90, 24, l, c[:txt], PF::TEXT)
end
dump_as("V5_use")
frame(c, BG_PC)
b = BASE.bitmap; t = TOP.bitmap
speech(c, "Your Pokémon are healed! Your PokeVial is missing 2 charges. Refill it for $1,000?", 270, 82)
panel(b, 356, 160, 504, 262, c, 245, 6)
vial_icon(t, 376, 180, 24)
pips(b, 392, 175, c, CHARGES, MAXC, 9, 2)
["Refill ($1,000)", "Not Now"].each_with_index do |l, i|
  y = 204 + i * 26
  cursor_at(362, y, 136, 24) if i == 0
  P.text(t, 374, y, 124, 24, l, c[:txt], PF::TEXT)
end
dump_as("V5_center")
puts "done"
