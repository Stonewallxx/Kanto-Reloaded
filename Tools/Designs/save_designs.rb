# encoding: utf-8
# Mockups: four Save Manager designs, each as two screens: Saves (every save
# with its note, health check, details and party, actions) and the Backup
# Browser (one save's backups, the Backup Cap, restore).
# Design 1 = the old KR Save Manager screen in our UI kit.
# Usage: ruby save_designs.rb "<KIF Beta>" <work dir with metrics.json>
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

# [slot, note, trainer, location, saved, play time, badges, health, party]
SAVES = [["File A", "Main Run", "Red", "Cerulean City", "Today 3:42 PM", "41:12", 2, :ok, %w[PIKACHU GYARADOS GENGAR ALAKAZAM SNORLAX CHANSEY]],
         ["File B", "Nuzlocke", "Leaf", "Mt. Moon", "Yesterday", "12:05", 1, :ok, %w[BULBASAUR PIDGEOTTO GEODUDE]],
         ["File C", "Shiny Hunt", "Red", "Route 24", "Oct 14", "88:40", 4, :ok, %w[ABRA CHANSEY]],
         ["File D", "", "Blue", "Viridian City", "Oct 2", "03:11", 0, :damaged, %w[SQUIRTLE]]]
SEL = 0
# backups of File A: [when, location, play time, name]
BACKUPS = [["Today 3:42 PM", "Cerulean City", "41:12", "Before Misty"], ["Today 3:10 PM", "Route 4", "40:41", nil],
           ["Today 2:58 PM", "Mt. Moon", "40:22", nil], ["Today 2:31 PM", "Mt. Moon", "39:55", nil], ["Today 1:47 PM", "Route 3", "39:02", "Got Pikachu"],
           ["Yesterday", "Pewter City", "35:40", nil], ["Oct 15", "Viridian Forest", "30:12", nil]]
BSEL = 0
NOTES = ["Main run. Misty next; I need a Grass type before the gym.", "Nuzlocke: dupes clause, no items in battle.", "Shiny hunting Abra on Route 24.", ""]
TAGS = [[230, 80, 80], [110, 210, 120], [110, 160, 245], [150, 150, 160]]
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
MAPS = Sprite.new($vp); MAPS.z = -1
TITLE_BG = Bitmap.new(File.join(GFX, "Titles/gen1_bg.png"))
BLANK = Bitmap.new(W, H)
BASE = layer(0)
CUR = Sprite.new($vp); CUR.z = 1
TOP = layer(2)
def frame(c, bg = nil)
  BASE.bitmap.clear; TOP.bitmap.clear
  CUR.visible = false
  if bg
    MAPS.bitmap = Bitmap.new(W, H)
    MAPS.bitmap.stretch_blt(Rect.new(0, 0, W, H), bg, Rect.new(0, 0, bg.width, bg.height))
  else
    MAPS.bitmap = BLANK
    BASE.bitmap.fill_rect(0, 0, W, H, c[:bg])
  end
end
def cursor_at(x, y, w, h)
  CUR.bitmap = P.cursor_bitmap(w, h)
  CUR.x = x; CUR.y = y; CUR.opacity = 210; CUR.visible = true
end
$bmps = {}
def bmp(path); $bmps[path] ||= Bitmap.new(path); end
def mon(b, sp, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(File.join(GFX, "Pokemon/Icons/#{sp}.png")), Rect.new(0, 0, 64, 64))
end
def badge(b, x, y, text, color, right = false); P.pill(b, x, y, text, Color.new(color.red / 4, color.green / 4, color.blue / 4), color, right); end
def health(b, s, x, y, right = false)
  s[7] == :ok ? badge(b, x, y, "HEALTHY", GREEN, right) : badge(b, x, y, "DAMAGED", RED, right)
end
def header(c, title, tabs, current, y0 = 0)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, y0, W, 56, c[:panel2]); b.fill_rect(0, y0 + 55, W, 1, c[:line])
  P.text(t, 0, y0 + 2, W, 26, title, c[:title], PF::TITLE, 2)
  tw = 130
  x0 = (W - tabs.length * tw) / 2
  tabs.each_with_index do |tb, i|
    on = i == current
    UI.rbox(b, x0 + i * tw + 3, y0 + 30, x0 + (i + 1) * tw - 3, y0 + 50, 4, on ? c[:sel] : c[:panel], on ? c[:selb] : c[:line])
    P.text(t, x0 + i * tw, y0 + 30, tw, 20, tb, on ? c[:white] : c[:dim], PF::TEXT, 2)
  end
end
def detail_rows(c, x, y, w, rows)
  t = TOP.bitmap
  rows.each_with_index do |(k, v, cl), i|
    P.text(t, x, y + i * 20, 90, 18, k, c[:dim], PF::TEXT)
    P.text(t, x + 90, y + i * 20, w - 90, 18, v, cl || c[:txt], PF::TEXT, 1)
  end
end
def save_rows(s)
  [["Trainer", s[2], BLUE], ["Location", s[3], GREEN], ["Saved", s[4], nil], ["Play Time", s[5], GOLD], ["Badges", s[6].to_s, nil]]
end
def hints(c, pairs); P.hints(BASE.bitmap, TOP.bitmap, c, pairs, $style); end
H_SAVES = [[:ud, "Choose"], [A_BTN, "Options"], [Y_BTN, "Note"], ["p:9", "Tabs"], [B_BTN, "Close"]]
H_BACK = [[:ud, "Choose"], [A_BTN, "Restore"], [Y_BTN, "Name"], ["p:9", "Tabs"], [B_BTN, "Back"]]
def dump_as(name); dump(name); puts "wrote #{name}"; end

c = palette(2)

#================================================================ S1 Recommended: old KR Save Manager, rebuilt
frame(c)
b = BASE.bitmap; t = TOP.bitmap
header(c, "Save Manager", ["Active", "Backups", "Deleted"], 0)
UI.rbox(b, 8, 62, 232, 352, 6, c[:panel])
SAVES.each_with_index do |s, i|
  y = 68 + i * 44
  cursor_at(12, y, 217, 42) if i == SEL
  UI.rbox(b, 14, y + 4, 18, y + 38, 2, Color.new(*TAGS[i]))
  P.text(t, 24, y + 2, 120, 18, s[0], c[:txt], PF::TEXT)
  note = NOTES[i].empty? ? "No Note" : NOTES[i]
  P.text(t, 24, y + 22, 196, 14, PF.fit(PF::TINY, note, 196), NOTES[i].empty? ? c[:dim] : GOLD, PF::TINY)
  health(t, s, 224, y + 4, true)
end
UI.rbox(b, 238, 62, 504, 352, 6, c[:panel])
s = SAVES[SEL]
UI.rbox(b, 246, 68, 252, 84, 2, Color.new(*TAGS[0]))
P.text(t, 258, 66, 240, 20, "File A", c[:txt], PF::ROW)
P.small(t, 330, 68, 164, 16, "Tag: Red", c[:dim], 1)
detail_rows(c, 248, 90, 246, save_rows(s).first(4))
s[8].each_with_index { |sp, k| mon(t, sp, 266 + k * 40, 186, 36) }
b.fill_rect(248, 206, 246, 1, c[:line])
P.text(t, 248, 210, 150, 12, "NOTES", c[:head], PF::TINY)
BI.draw(t, 432, 208, "p:3", c, $style); P.text(t, 450, 208, 44, 16, "EDIT", c[:dim], PF::TINY, 1)
P.small_wrap(t, NOTES[0], 240).first(3).each_with_index { |ln, k| P.small(t, 248, 226 + k * 16, 246, 16, ln, c[:txt]) }
UI.rbox(b, 248, 300, 494, 344, 5, col(GREEN, 40), GREEN)
P.text(t, 248, 302, 246, 20, "Healthy · Ready to Archive", GREEN, PF::TEXT, 2)
P.text(t, 248, 322, 246, 14, "7 BACKUPS · KEEPING UNLIMITED", c[:dim], PF::TINY, 2)
hints(c, H_SAVES)
dump_as("S1_saves")
frame(c)
b = BASE.bitmap; t = TOP.bitmap
header(c, "Save Manager", ["Active", "Backups", "Deleted"], 1)
UI.rbox(b, 8, 62, 232, 352, 6, c[:panel])
P.text(t, 16, 66, 210, 14, "FILE A: MAIN RUN", c[:head], PF::TINY)
BACKUPS.each_with_index do |bk, i|
  y = 82 + i * 38
  cursor_at(12, y, 217, 36) if i == BSEL
  P.text(t, 18, y, 150, 18, bk[0], c[:txt], PF::TEXT)
  P.text(t, 18, y + 18, 200, 14, bk[3] ? "\"#{bk[3]}\"" : bk[1], bk[3] ? GOLD : c[:dim], PF::TINY)
end
UI.rbox(b, 238, 62, 504, 352, 6, c[:panel])
P.text(t, 238, 66, 266, 20, "Backup: Before Misty", GOLD, PF::ROW, 2)
detail_rows(c, 248, 92, 246, [["Saved", "Today 3:42 PM", nil], ["Location", "Cerulean City", GREEN], ["Play Time", "41:12", GOLD], ["Health", "Healthy", GREEN]])
SAVES[0][8].each_with_index { |sp, k| mon(t, sp, 270 + (k % 3) * 84, 198 + (k / 3) * 50, 46) }
P.text(t, 248, 282, 246, 14, "BACKUP CAP: UNLIMITED (NAMED ONES ARE KEPT)", c[:dim], PF::TINY, 2)
[["Restore", true], ["Name", false]].each_with_index do |(l, on), i|
  bx = 258 + i * 120
  UI.rbox(b, bx, 304, bx + 110, 330, 5, on ? c[:selb] : c[:dark], on ? nil : c[:line])
  P.text(t, bx, 304, 110, 26, l, on ? c[:dark] : c[:txt], PF::TEXT, 2)
end
hints(c, H_BACK)
dump_as("S1_backups")

#================================================================ S2 Save Cards
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
P.text(t, 0, 3, W, 28, "Your Saves", c[:title], PF::TITLE, 2)
SAVES.each_with_index do |s, i|
  y = 40 + i * 78
  UI.rbox(b, 8, y, W - 9, y + 72, 8, c[:panel], s[7] == :damaged ? RED : c[:line])
  cursor_at(8, y, W - 16, 73) if i == SEL
  P.text(t, 18, y + 4, 200, 20, "#{s[0]}", c[:txt], PF::ROW)
  P.text(t, 100, y + 8, 200, 16, s[1].empty? ? "" : s[1], GOLD, PF::TEXT)
  P.small(t, 18, y + 30, 240, 15, "#{s[2]} · #{s[3]} · #{s[5]}", c[:txt])
  P.small(t, 18, y + 46, 240, 15, "Saved #{s[4]} · #{s[6]} Badges", c[:dim])
  s[8].each_with_index { |sp, k| mon(t, sp, 280 + k * 36, y + 46, 34) }
  health(t, s, W - 20, y + 6, true)
end
P.small(t, 0, 352, W, 6, "", c[:dim])
hints(c, [[:ud, "Choose"], [A_BTN, "Options"], [X_BTN, "Backups"], [Y_BTN, "Note"], [B_BTN, "Close"]])
dump_as("S2_saves")
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
P.text(t, 0, 3, W, 28, "Backups: Main Run", c[:title], PF::TITLE, 2)
b.fill_rect(40, 44, 3, 300, c[:line])
BACKUPS.each_with_index do |bk, i|
  y = 42 + i * 44
  UI.rbox(b, 34, y + 12, 49, y + 27, 7, bk[3] ? GOLD : c[:acc])
  UI.rbox(b, 60, y + 2, W - 9, y + 40, 6, c[:panel], c[:line])
  cursor_at(60, y + 2, W - 69, 39) if i == BSEL
  P.text(t, 70, y + 4, 160, 18, bk[0], c[:txt], PF::TEXT)
  P.small(t, 70, y + 22, 200, 15, "#{bk[1]} · #{bk[2]}", c[:dim])
  P.text(t, 260, y + 10, 160, 18, bk[3] ? "\"#{bk[3]}\"" : "", GOLD, PF::TEXT)
end
P.text(t, 0, 350, W - 12, 12, "CAP: UNLIMITED", c[:dim], PF::TINY, 1)
hints(c, H_BACK)
dump_as("S2_backups")

#================================================================ S3 Settings Style
def s3_frame(c, title, sec)
  frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
  P.text(t, 0, 2, W, 28, title, c[:title], PF::TITLE, 2)
  UI.rbox(b, 6, 36, 150, 262, 6, c[:panel])
  SAVES.each_with_index do |s, i|
    y = 42 + i * 34
    UI.rbox(b, 10, y, 146, y + 30, 5, c[:sel], c[:selb]) if i == sec
    P.text(t, 18, y, 80, 30, s[0], i == sec ? c[:white] : c[:txt], PF::TEXT)
    UI.rbox(b, 132, y + 11, 140, y + 19, 4, s[7] == :ok ? GREEN : RED)
  end
  P.text(t, 14, 182, 130, 12, "DELETED", c[:head], PF::TINY)
  P.text(t, 18, 196, 130, 22, "2 Archived", c[:dim], PF::TEXT)
  UI.rbox(b, 156, 36, W - 6, 262, 6, c[:panel])
  UI.rbox(b, 6, 268, W - 6, H - 30, 6, c[:panel2], c[:line])
end
s3_frame(c, "Save Manager", 0)
b = BASE.bitmap; t = TOP.bitmap
P.heading(t, 166, W - 16, 42, "File A: Main Run", c[:head], c[:line])
detail_rows(c, 170, 58, 324, save_rows(SAVES[0]))
SAVES[0][8].each_with_index { |sp, k| mon(t, sp, 186 + k * 52, 182, 44) }
["Backups (7)", "Archive Save", "Open Save Folder"].each_with_index do |l, i|
  y = 208 + i * 0
end
cursor_at(160, 212, W - 170, 24)
P.text(t, 170, 212, 200, 24, "Backups", c[:txt], PF::ROW)
P.text(t, 380, 212, 110, 24, "7", c[:dim], PF::TEXT, 1)
P.text(t, 170, 236, 200, 24, "Archive Save", c[:txt], PF::ROW)
P.text(t, 16, 270, 300, 24, "Backups", c[:head], PF::ROW)
P.small(t, 16, 296, 480, 16, "Every save keeps a backup. Restore any of them. Keeping: Unlimited.", c[:txt])
P.small(t, 16, 312, 480, 16, "Healthy: the save file checked out fine when this screen opened.", GREEN)
hints(c, [[:ud, "Choose"], [:lr, "Saves"], [A_BTN, "Open"], [Y_BTN, "Note"], [B_BTN, "Close"]])
dump_as("S3_saves")
s3_frame(c, "Backups", 0)
b = BASE.bitmap; t = TOP.bitmap
P.heading(t, 166, W - 16, 42, "File A Backups", c[:head], c[:line])
BACKUPS.first(7).each_with_index do |bk, i|
  y = 58 + i * 28
  cursor_at(160, y, W - 170, 26) if i == BSEL
  P.text(t, 170, y, 130, 26, bk[0], c[:txt], PF::TEXT)
  P.text(t, 300, y, 196, 26, bk[3] ? "\"#{bk[3]}\"" : bk[1], bk[3] ? GOLD : c[:dim], PF::TEXT, 1)
end
P.text(t, 16, 270, 300, 24, "Before Misty", c[:head], PF::ROW)
P.small(t, 16, 296, 480, 16, "Cerulean City · 41:12 · Healthy.", c[:txt])
P.small(t, 260, 330, 240, 16, "Restoring keeps your current save as a backup.", c[:dim], 1)
SAVES[0][8].each_with_index { |sp, k| mon(t, sp, 30 + k * 34, 330, 30) }
hints(c, H_BACK)
dump_as("S3_backups")

#================================================================ S4 Title Screen Style
frame(c, TITLE_BG)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 8, 8, W - 9, 46, 8, col(c[:panel], 235), c[:line])
P.text(t, 8, 10, W - 16, 34, "Save Manager", c[:title], PF::TITLE, 2)
SAVES.first(3).each_with_index do |s, i|
  y = 54 + i * 98
  UI.rbox(b, 40, y, W - 41, y + 92, 10, col(c[:panel], 240), i == SEL ? c[:selb] : c[:line])
  cursor_at(40, y, W - 80, 93) if i == SEL
  P.text(t, 54, y + 6, 200, 22, "#{s[0]}  ", c[:txt], PF::ROW)
  P.text(t, 130, y + 8, 200, 20, s[1], GOLD, PF::TEXT)
  health(t, s, W - 54, y + 10, true)
  P.small(t, 54, y + 34, 240, 15, "#{s[2]} · #{s[3]}", c[:txt])
  P.small(t, 54, y + 50, 240, 15, "#{s[5]} played · #{s[6]} Badges", c[:dim])
  P.small(t, 54, y + 66, 240, 15, "Saved #{s[4]} · 7 Backups", c[:dim])
  s[8].each_with_index { |sp, k| mon(t, sp, 300 + (k % 3) * 46, y + 28 + (k / 3) * 38, 38) }
end
hints(c, [[:ud, "Choose"], [A_BTN, "Options"], [X_BTN, "Backups"], [Y_BTN, "Note"], [B_BTN, "Back"]])
dump_as("S4_saves")
frame(c, TITLE_BG)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 8, 8, W - 9, 46, 8, col(c[:panel], 235), c[:line])
P.text(t, 8, 10, W - 16, 34, "Backups: Main Run", c[:title], PF::TITLE, 2)
UI.rbox(b, 40, 54, W - 41, 352, 10, col(c[:panel], 240), c[:line])
BACKUPS.each_with_index do |bk, i|
  y = 60 + i * 40
  cursor_at(46, y, W - 92, 38) if i == BSEL
  P.text(t, 60, y + 2, 150, 18, bk[0], c[:txt], PF::TEXT)
  P.small(t, 60, y + 20, 200, 15, "#{bk[1]} · #{bk[2]}", c[:dim])
  P.text(t, 260, y + 8, 200, 18, bk[3] ? "\"#{bk[3]}\"" : "", GOLD, PF::TEXT, 1)
end
hints(c, H_BACK)
dump_as("S4_backups")
puts "done"
