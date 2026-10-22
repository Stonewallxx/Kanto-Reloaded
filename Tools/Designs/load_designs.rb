# encoding: utf-8
# Mockups: four Load screen (main menu) designs. Each shows the Continue entry
# (file switching, the file's colour tag, its Save Note (Y edits it here),
# trainer, badges, difficulty and mode, play time, Pokedex and money, map,
# party, backups (hold A to load one) and the health check), the other
# entries (Mystery Gift, New Game, Options, Save Manager, Quit), the What's
# New panel and the version line.
# Design 1 = PIF's own load screen rebuilt in our UI kit.
# Usage: ruby load_designs.rb "<KIF Beta>" <work dir with metrics.json>
PREVIEW = File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
src = File.read(PREVIEW, :encoding => "UTF-8")
eval(src.split("#---------------------------------------------------------------- A: Ocean Blue")[0], binding, PREVIEW)

P = Reloaded::Pixel
BI = Reloaded::ButtonIcons
PF = KIF::PixelFont
UI = KIF::PixelUI
W = 512; H = 384
GFX = File.join(ARGV[0], "Graphics")
$style = :xbox

FILES = [["File A", "Main run. Misty next; I need a Grass type.", [230, 80, 80]], ["File B", "Nuzlocke: dupes clause, no items.", [110, 210, 120]],
         ["File C", "Shiny hunting Abra on Route 24.", [110, 160, 245]]]
PARTY = %w[PIKACHU GYARADOS GENGAR ALAKAZAM SNORLAX CHANSEY]
ENTRIES = ["Mystery Gift", "New Game", "Options", "Save Manager", "Quit"]
NEWS = ["What's New in 2.1.0", "New Reloaded Bag", "PokeVial refills at Centers", "New TM Vault"]
VERSION = "Kanto Reloaded 2.0.0 · KIF Beta 0.21.53"
GREEN = Color.new(120, 230, 150); GOLD = Color.new(240, 200, 70); RED = Color.new(240, 100, 90); BLUE = Color.new(130, 190, 250)
A_BTN = "p:0"; B_BTN = "p:1"; Y_BTN = "p:3"

def palette(theme)
  Reloaded::Settings.set(:"interface.theme", theme)
  return Reloaded::Palette.current
end
def col(c, a); Color.new(c.red, c.green, c.blue, a); end
$vp = Viewport.new(0, 0, W, H)
$vp.z = 99_999
def layer(z); s = Sprite.new($vp); s.bitmap = Bitmap.new(W, H); s.z = z; s; end
MAPS = Sprite.new($vp); MAPS.z = -1
BASE = layer(0)
CUR = Sprite.new($vp); CUR.z = 1
TOP = layer(2)
$bmps = {}
def bmp(path); $bmps[path] ||= Bitmap.new(path); end
def frame(c, bg = nil, dim = 0)
  BASE.bitmap.clear; TOP.bitmap.clear
  CUR.visible = false
  MAPS.bitmap = Bitmap.new(W, H)
  if bg
    i = bmp(bg)
    MAPS.bitmap.stretch_blt(Rect.new(0, 0, W, H), i, Rect.new(0, 0, i.width, i.height))
    BASE.bitmap.fill_rect(0, 0, W, H, Color.new(c[:bg].red, c[:bg].green, c[:bg].blue, dim)) if dim > 0
  else
    BASE.bitmap.fill_rect(0, 0, W, H, c[:bg])
  end
end
def cursor_at(x, y, w, h)
  CUR.bitmap = P.cursor_bitmap(w, h)
  CUR.x = x; CUR.y = y; CUR.opacity = 210; CUR.visible = true
end
def mon(b, sp, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(File.join(GFX, "Pokemon/Icons/#{sp}.png")), Rect.new(0, 0, 64, 64))
end
def trainer(b, cx, cy, size)
  i = bmp(File.join(GFX, "Trainers/POKEMONTRAINER_Red.png"))
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), i, Rect.new(0, 0, i.width, i.height))
end
def badge(b, x, y, text, color, right = false); P.pill(b, x, y, text, Color.new(color.red / 4, color.green / 4, color.blue / 4), color, right); end
def tag(b, x, y, h, f = FILES[0]); UI.rbox(b, x, y, x + 4, y + h, 2, Color.new(*f[2])); end
def file_switch(c, x, y, w, f = FILES[0])
  t = TOP.bitmap
  UI.tri(t, x, y + 7, :l, c[:dim], 4)
  P.text(t, x + 10, y, w - 20, 20, f[0], c[:txt], PF::TEXT, 2)
  UI.tri(t, x + w - 8, y + 7, :r, c[:dim], 4)
end
def note_line(c, x, y, w, f = FILES[0])
  P.small(TOP.bitmap, x, y, w, 15, f[1], GOLD, 2)
end
# Two columns of three: trainer / badges / difficulty+mode and time / Pokedex / money
def stats(c, x, y, w)
  t = TOP.bitmap
  half = (w - 10) / 2
  [[["Red", nil, BLUE], ["Badges", "2"], ["Normal", "Classic"]], [["Time", "41h 12m"], ["Pokédex", "87 / 41"], ["Money", "$12,450"]]].each_with_index do |rows, ci|
    cx = x + ci * (half + 10)
    rows.each_with_index do |(k, v, cl), i|
      P.small(t, cx, y + i * 18, half, 17, k, cl || c[:txt])
      P.small(t, cx, y + i * 18, half, 17, v, c[:txt], 1) if v
    end
  end
end
def whats_new(c, x, y, w, h, compact = false)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + h, 6, col(c[:panel2], 245), GOLD)
  P.text(t, x + 8, y + 4, w - 16, 16, NEWS[0], GOLD, PF::TEXT)
  if compact
    P.small(t, x + 8, y + 22, w - 16, 15, "#{NEWS[1]}, #{NEWS[3]} and more", c[:txt])
  else
    NEWS[1..3].each_with_index { |n, i| P.small(t, x + 16, y + 24 + i * 16, w - 24, 15, n, c[:txt]) }
  end
end
def version(c, x, y, w, align = 1); P.text(TOP.bitmap, x, y, w, 12, VERSION, c[:dim], PF::TINY, align); end
def hints(c, pairs); P.hints(BASE.bitmap, TOP.bitmap, c, pairs, $style); end
H_LOAD = [[:ud, "Choose"], [:lr, "Save File"], [A_BTN, "Select"], [A_BTN, "Hold: Backups"], [Y_BTN, "Edit Note"]]
def dump_as(name); dump(name); puts "wrote #{name}"; end

c = palette(2)

#================================================================ L1 Recommended: PIF's load screen, rebuilt
frame(c, File.join(GFX, "Pictures/loadbg.png"), 150)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 48, 8, 464, 216, 8, col(c[:panel], 245), c[:selb])
cursor_at(48, 8, 417, 209)
tag(b, 52, 14, 196)
P.text(t, 62, 12, 200, 22, "Continue", c[:title], PF::ROW)
P.text(t, 260, 14, 196, 18, "Cerulean City", GREEN, PF::TEXT, 1)
b.fill_rect(58, 36, 396, 1, c[:line])
file_switch(c, 62, 40, 392)
note_line(c, 62, 60, 392)
trainer(t, 106, 120, 80)
stats(c, 158, 82, 296)
badge(t, 452, 144, "HEALTHY", GREEN, true)
P.text(t, 158, 146, 200, 14, "7 BACKUPS", c[:dim], PF::TINY)
PARTY.each_with_index { |sp, k| mon(t, sp, 86 + k * 62, 188, 38) }
ENTRIES.each_with_index do |e, i|
  y = 222 + i * 25
  UI.rbox(b, 48, y, 280, y + 21, 6, col(c[:panel], 240), c[:line])
  P.text(t, 60, y, 210, 21, e, e == "Save Manager" ? GOLD : c[:txt], PF::TEXT)
end
whats_new(c, 288, 222, 176, 82)
version(c, 288, 312, 176)
hints(c, H_LOAD)
dump_as("L1_load")

#================================================================ L2 File List + Details
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
P.text(t, 12, 3, 240, 28, "Kanto Reloaded", c[:title], PF::TITLE)
version(c, W - 250, 12, 242)
UI.rbox(b, 6, 38, 190, 354, 6, c[:panel])
P.text(t, 14, 42, 160, 12, "CONTINUE", c[:head], PF::TINY)
FILES.each_with_index do |f, i|
  y = 58 + i * 40
  cursor_at(10, y, 177, 38) if i == 0
  tag(b, 14, y + 3, 32, f)
  P.text(t, 24, y + 2, 120, 18, f[0], c[:txt], PF::TEXT)
  P.text(t, 24, y + 20, 156, 14, PF.fit(PF::TINY, f[1], 156), GOLD, PF::TINY)
  UI.rbox(b, 172, y + 6, 180, y + 14, 4, GREEN)
end
b.fill_rect(14, 182, 168, 1, c[:line])
ENTRIES.each_with_index { |e, i| P.text(t, 18, 188 + i * 32, 160, 30, e, e == "Save Manager" ? GOLD : c[:txt], PF::ROW) }
UI.rbox(b, 196, 38, W - 6, 270, 6, c[:panel])
tag(b, 200, 44, 220)
P.text(t, 206, 42, 296, 22, "File A", c[:txt], PF::ROW, 2)
note_line(c, 206, 64, 296)
trainer(t, 244, 128, 76)
stats(c, 286, 88, 216)
P.text(t, 286, 150, 216, 18, "Cerulean City", GREEN, PF::TEXT, 1)
badge(t, W - 16, 174, "HEALTHY", GREEN, true)
P.text(t, 286, 176, 120, 14, "7 BACKUPS", c[:dim], PF::TINY)
PARTY.each_with_index { |sp, k| mon(t, sp, 226 + k * 46, 230, 40) }
whats_new(c, 196, 276, W - 202, 76)
hints(c, [[:ud, "Choose"], [A_BTN, "Select"], [A_BTN, "Hold: Backups"], [Y_BTN, "Edit Note"]])
dump_as("L2_load")

#================================================================ L3 Big Card Carousel
frame(c, File.join(GFX, "Titles/gen1_bg.png"))
b = BASE.bitmap; t = TOP.bitmap
[[-1, FILES[2]], [1, FILES[1]]].each do |side, f|
  x = side < 0 ? -150 : W - 34
  UI.rbox(b, x, 34, x + 184, 230, 10, col(c[:panel], 200), c[:line])
  tag(b, side < 0 ? x + 176 : x + 4, 40, 184, f)
end
UI.rbox(b, 60, 16, 452, 244, 12, col(c[:panel], 245), c[:selb])
cursor_at(60, 16, 393, 229)
tag(b, 64, 22, 216)
file_switch(c, 72, 22, 368)
note_line(c, 72, 44, 368)
trainer(t, 122, 118, 84)
stats(c, 176, 72, 266)
P.text(t, 176, 136, 266, 18, "Cerulean City", GREEN, PF::TEXT, 1)
badge(t, 440, 160, "HEALTHY", GREEN, true)
P.text(t, 176, 162, 160, 14, "7 BACKUPS", c[:dim], PF::TINY)
PARTY.each_with_index { |sp, k| mon(t, sp, 106 + k * 60, 210, 42) }
ENTRIES.each_with_index do |e, i|
  w = 92; x = 8 + i * (w + 9)
  UI.rbox(b, x, 252, x + w, 280, 6, col(c[:panel], 240), c[:line])
  P.text(t, x, 252, w, 28, e.upcase, e == "Save Manager" ? GOLD : c[:txt], PF::TINY, 2)
end
whats_new(c, 8, 288, W - 16, 44, true)
version(c, 8, 340, W - 16, 2)
hints(c, [[:lr, "Save File"], [:ud, "Menu"], [A_BTN, "Continue"], [A_BTN, "Hold: Backups"], [Y_BTN, "Edit Note"]])
dump_as("L3_load")

#================================================================ L4 Menu Left, Summary Right
frame(c, File.join(GFX, "Titles/gen1_bg.png"))
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 8, 40, 176, 330, 10, col(c[:panel], 240), c[:line])
(["Continue"] + ENTRIES).each_with_index do |e, i|
  y = 48 + i * 44
  cursor_at(14, y, 157, 38) if i == 0
  P.text(t, 26, y, 140, 38, e, e == "Save Manager" ? GOLD : c[:txt], PF::ROW)
end
version(c, 186, 22, W - 195)
UI.rbox(b, 186, 40, W - 9, 268, 10, col(c[:panel], 240), c[:line])
tag(b, 190, 46, 214)
file_switch(c, 198, 46, W - 216)
note_line(c, 198, 66, W - 216)
b.fill_rect(198, 84, W - 216, 1, c[:line])
trainer(t, 232, 134, 76)
stats(c, 274, 94, 222)
P.text(t, 274, 156, 222, 18, "Cerulean City", GREEN, PF::TEXT, 1)
badge(t, W - 20, 180, "HEALTHY", GREEN, true)
P.text(t, 274, 182, 120, 14, "7 BACKUPS", c[:dim], PF::TINY)
PARTY.each_with_index { |sp, k| mon(t, sp, 214 + k * 47, 236, 40) }
whats_new(c, 186, 274, W - 195, 56, true)
hints(c, H_LOAD)
dump_as("L4_load")
puts "done"
