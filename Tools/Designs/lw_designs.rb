# encoding: utf-8
# Mockups for the chosen Load Screen (design 1) with What's New as its own
# row: (1) Continue selected, (2) a lower row selected after the list has
# scrolled (the Continue panel moves up above it, as PIF's list does), and
# (3) the What's New screen: sources (Kanto Reloaded, KIF Beta, other mods
# that register) and each source's version notes.
# Usage: ruby lw_designs.rb "<KIF Beta>" <work dir with metrics.json>
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

FILE = ["File A", "Main run. Misty next; I need a Grass type.", [230, 80, 80]]
PARTY = %w[PIKACHU GYARADOS GENGAR ALAKAZAM SNORLAX CHANSEY]
ROWS = ["New Game", "What's New", "Mystery Gift", "Options", "Save Manager", "KIF Discord", "KIF Documentation", "Quit"]
VERSION = "Kanto Reloaded 2.0.0 · KIF Beta 0.21.53"
GREEN = Color.new(120, 230, 150); GOLD = Color.new(240, 200, 70); BLUE = Color.new(130, 190, 250)
A_BTN = "p:0"; B_BTN = "p:1"; Y_BTN = "p:3"
ROW_H = 24
PANEL_H = 190

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
def hints(c, pairs); P.hints(BASE.bitmap, TOP.bitmap, c, pairs, $style); end
def dump_as(name); dump(name); puts "wrote #{name}"; end

# The Continue panel at y (it can start above the screen when the list has scrolled)
def continue_panel(c, y, selected)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 48, y, 464, y + PANEL_H, 8, col(c[:panel], 245), selected ? c[:selb] : c[:line])
  cursor_at(48, y, 417, PANEL_H + 1) if selected
  UI.rbox(b, 52, y + 6, 56, y + PANEL_H - 6, 2, Color.new(*FILE[2]))
  P.text(t, 62, y + 4, 200, 22, "Continue", selected ? c[:title] : c[:dim], PF::ROW)
  P.text(t, 260, y + 6, 196, 18, "Cerulean City", GREEN, PF::TEXT, 1)
  b.fill_rect(58, y + 28, 396, 1, c[:line])
  UI.tri(t, 62, y + 37, :l, c[:dim], 4); UI.tri(t, 446, y + 37, :r, c[:dim], 4)
  P.text(t, 72, y + 30, 372, 20, FILE[0], c[:txt], PF::TEXT, 2)
  P.small(t, 62, y + 50, 392, 15, FILE[1], GOLD, 2)
  trainer(t, 106, y + 104, 72)
  half = 143
  [[["Red", nil, BLUE], ["Badges", "2"], ["Normal", "Classic"]], [["Time", "41h 12m"], ["Pokédex", "87 / 41"], ["Money", "$12,450"]]].each_with_index do |rows, ci|
    cx = 158 + ci * (half + 10)
    rows.each_with_index do |(k, v, cl), i|
      P.small(t, cx, y + 70 + i * 18, half, 17, k, cl || c[:txt])
      P.small(t, cx, y + 70 + i * 18, half, 17, v, c[:txt], 1) if v
    end
  end
  P.text(t, 158, y + 128, 120, 14, "7 BACKUPS", c[:dim], PF::TINY)
  badge(t, 452, y + 126, "HEALTHY", GREEN, true)
  PARTY.each_with_index { |sp, k| mon(t, sp, 86 + k * 62, y + 166, 36) }
end
def rows(c, y0, sel)
  b = BASE.bitmap; t = TOP.bitmap
  ROWS.each_with_index do |r, i|
    y = y0 + i * ROW_H
    next if y + ROW_H - 3 < 0 || y > 356 - ROW_H + 3
    UI.rbox(b, 64, y, 448, y + ROW_H - 3, 6, col(c[:panel], 240), i == sel ? c[:selb] : c[:line])
    cursor_at(64, y, 385, ROW_H - 2) if i == sel
    color = r == "Save Manager" ? GOLD : c[:txt]
    P.text(t, 76, y, 300, ROW_H - 3, r, color, PF::TEXT)
    badge(t, 440, y + 3, "NEW", GOLD, true) if r == "What's New"
  end
end
def scroll_marks(c, up, down)
  t = TOP.bitmap
  UI.rbox(BASE.bitmap, 474, 150, 488, 230, 6, col(c[:panel], 230), c[:line])
  UI.tri(t, 477, 156, :u, up ? c[:txt] : c[:line], 4)
  UI.tri(t, 477, 218, :d, down ? c[:txt] : c[:line], 4)
end
H_LOAD = [[:ud, "Choose"], [:lr, "Save File"], [A_BTN, "Select"], [A_BTN, "Hold: Backups"], [Y_BTN, "Edit Note"]]

c = palette(2)

#================================================================ 1: Continue selected (top of the list)
frame(c, File.join(GFX, "Pictures/loadbg.png"), 150)
P.text(TOP.bitmap, 0, 1, W - 8, 12, VERSION, c[:dim], PF::TINY, 1)
continue_panel(c, 14, true)
rows(c, 14 + PANEL_H + 6, -1)
scroll_marks(c, false, true)
hints(c, H_LOAD)
dump_as("LW1_continue")

#================================================================ 2: a lower row selected, the list scrolled up
frame(c, File.join(GFX, "Pictures/loadbg.png"), 150)
shift = 2 * ROW_H + 24
continue_panel(c, 14 - shift, false)
rows(c, 14 + PANEL_H + 6 - shift, 1)
scroll_marks(c, true, false)
hints(c, [[:ud, "Choose"], [A_BTN, "Open"], [B_BTN, "Back"]])
dump_as("LW2_scrolled")

#================================================================ 3: the What's New screen
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
P.text(t, 0, 2, W, 28, "What's New", c[:title], PF::TITLE, 2)
UI.rbox(b, 6, 36, 174, 290, 6, c[:panel])
[["Kanto Reloaded", true], ["KIF Beta", false], ["Other Mods", false]].each_with_index do |(n, nw), i|
  y = 40 + i * 24
  UI.rbox(b, 10, y, 170, y + 21, 5, c[:sel], c[:selb]) if i == 0
  if n == "Kanto Reloaded"
    P.poke_ball(t, 14, y + 3, 15)
  else
    UI.rbox(t, 14, y + 3, 28, y + 17, 3, i == 1 ? Color.new(96, 160, 232) : Color.new(130, 140, 155))
    P.glyph(t, 14, y + 3, 15, 15, n[0], Color.new(248, 248, 248))
  end
  P.text(t, 34, y, 120, 21, n, i == 0 ? c[:white] : (i == 2 ? c[:dim] : c[:txt]), PF::TEXT)
  UI.rbox(b, 160, y + 8, 166, y + 14, 3, GOLD) if nw
end
# the small versions box
UI.rbox(b, 6, 296, 174, 354, 6, c[:panel2], c[:line])
P.text(t, 14, 300, 156, 12, "VERSIONS", c[:head], PF::TINY)
P.small(t, 14, 314, 156, 16, "Kanto Reloaded", c[:txt]); P.small(t, 14, 314, 152, 16, "2.0.0", c[:acc], 1)
P.small(t, 14, 331, 156, 16, "KIF Beta", c[:txt]); P.small(t, 14, 331, 152, 16, "0.21.53", c[:acc], 1)
# the right section, full height, with a scrollbar like Settings
UI.rbox(b, 180, 36, W - 6, 354, 6, c[:panel])
P.heading(t, 190, W - 22, 42, "Kanto Reloaded", c[:head], c[:line])
[["2.1.0", "Today", true], ["2.0.1", "Oct 20", false], ["2.0.0", "Oct 17", false]].each_with_index do |(v, d, nw), i|
  y = 58 + i * 26
  cursor_at(184, y, W - 202, 25) if i == 0
  P.text(t, 196, y, 120, 25, "Version #{v}", c[:txt], PF::ROW)
  P.text(t, 330, y, 90, 25, d, c[:dim], PF::TEXT, 1)
  badge(t, W - 24, y + 5, "NEW", GOLD, true) if nw
end
b.fill_rect(190, 142, W - 214, 1, c[:line])
P.text(t, 196, 148, 300, 12, "IN 2.1.0", c[:head], PF::TINY)
notes = ["The new Reloaded Bag, with Item Search", "PokeVial refills at Pokémon Centers", "TM Vault replaces Tutor.net",
         "Egg Manager with PC incubators", "Overworld Menu: Quest Tracker", "Fix: Pause Menu text on light frames",
         "Fix: Speech frame on light themes", "Faster Settings search"]
notes.each_with_index do |n, i|
  y = 164 + i * 22
  break if y > 334
  UI.rbox(b, 198, y + 7, 202, y + 11, 2, c[:acc])
  P.small(t, 210, y + 1, 280, 17, n, c[:txt])
end
b.fill_rect(W - 13, 44, 2, 302, c[:line]); b.fill_rect(W - 13, 44, 2, 190, c[:dim])
hints(c, [[:ud, "Choose"], [:lr, "Sources"], [A_BTN, "Read"], [B_BTN, "Back"]])
dump_as("LW3_whats_new")
puts "done"
