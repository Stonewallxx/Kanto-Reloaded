# encoding: utf-8
# Mockups: four homes for the Quality of Life toggles (13 kept + Auto-Repel
# Reuse + Faster Evolutions) and their three tools (Nature Selector, Level Lock
# Manager, Super Candy). Design 1 = the old KR way: rows under a Quality of
# Life heading in the Kanto Reloaded section of Settings.
# Usage: ruby qa_designs.rb "<KIF Beta>" <work dir with metrics.json>
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

# [group, label, value, icon item, description]
ROWS = [["Items and Money", "Infinite Repel", "Off", "REPEL", "Repel stays active: no wild encounters in grass or caves."],
        ["Items and Money", "Auto-Repel Reuse", "On", "MAXREPEL", "When a Repel runs out, the same kind is used again from your Bag."],
        ["Items and Money", "Infinite Money", "Off", "AMULETCOIN", "Keeps your money full."],
        ["Items and Money", "Rematch Money", "Off", "COINCASE", "Trainer rematches pay out money again."],
        ["Items and Money", "Infinite Safari Steps", "Off", "SAFARIBALL", "The Safari Zone never runs out of steps."],
        ["Moves", "Infinite PP", "Off", "MAXELIXIR", "A move never drops below 1 PP."],
        ["Moves", "Upgraded PP", "Off", "PPMAX", "Every move gets the maximum 3 PP Ups."],
        ["Moves", "Level-Up Move Learning", "Ask", "machine_NORMAL", "Native, Ask, or Skip moves learned by levelling."],
        ["Pokémon", "Always Obey", "Off", "SOOTHEBELL", "Traded and high-level Pokémon always obey."],
        ["Pokémon", "Level Locking", "On", "EVERSTONE", "Lock a Pokémon at its level so it stops gaining EXP."],
        ["Pokémon", "Instant Hatch", "Off", "OVALCHARM", "Eggs in your party hatch on your next step."],
        ["Pokémon", "Faster Evolutions", "On", "DAWNSTONE", "Shortens the evolution scene; B still cancels."],
        ["Pokémon", "Auto-Hook Fishing", "On", "SUPERROD", "The hook sets itself when something bites."]]
TOOLS = [["Nature Selector", "MENTALHERB", "Change a party Pokémon's nature."], ["Level Lock Manager", "EVERSTONE", "See and change level locks for the party."],
         ["Super Candy", "RARECANDY", "Raise the party to the level cap."]]
SEL = 1
GREEN = Color.new(120, 230, 150); GOLD = Color.new(240, 200, 70)
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
def frame(c, opaque = true)
  BASE.bitmap.clear; TOP.bitmap.clear
  CUR.visible = false
  BASE.bitmap.fill_rect(0, 0, W, H, c[:bg]) if opaque
end
def cursor_at(x, y, w, h)
  CUR.bitmap = P.cursor_bitmap(w, h)
  CUR.x = x; CUR.y = y; CUR.opacity = 210; CUR.visible = true
end
$bmps = {}
def bmp(path); $bmps[path] ||= Bitmap.new(path); end
def item_icon(b, name, cx, cy, size)
  path = File.join(GFX, "Items", name + ".png")
  path = File.join(GFX, "Items", "EVERSTONE.png") unless File.file?(path)
  i = bmp(path)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), i, Rect.new(0, 0, i.width, i.height))
end
def magnifier(base, ix, iy, fg, hole)
  UI.rbox(base, ix, iy, ix + 9, iy + 9, 4, fg)
  UI.rbox(base, ix + 2, iy + 2, ix + 7, iy + 7, 2, hole)
  3.times { |i| base.fill_rect(ix + 8 + i, iy + 8 + i, 2, 2, fg) }
end
# The improved KIF Settings frame: title bar, sidebar of sections, list, description
SECTIONS = [["Kanto Reloaded", [214, 52, 60]], ["Shinies", [230, 180, 60]], ["Battles", [210, 80, 80]], ["Pokémon", [90, 170, 100]],
            ["Graphics", [96, 160, 232]], ["Game", [60, 170, 160]], ["System", [130, 140, 155]]]
def settings_frame(c, sections, sel_section)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
  P.text(t, 0, 2, W, 28, "KIF Settings", c[:title], PF::TITLE, 2)
  UI.rbox(b, 8, 4, 120, 27, 5, c[:dark], c[:line]); magnifier(b, 28, 10, c[:dim], c[:dark]); P.text(t, 44, 4, 70, 23, "Search", c[:dim])
  UI.rbox(b, W - 120, 4, W - 8, 27, 5, c[:dark], c[:line]); P.text(t, W - 120, 4, 112, 23, "Presets", c[:dim], PF::TEXT, 2)
  UI.rbox(b, 6, 36, 174, 262, 6, c[:panel])
  sections.each_with_index do |(label, rgb), i|
    y = 40 + i * 20
    on = i == sel_section
    if label == "Kanto Reloaded"
      P.poke_ball(t, 14, y + 2, 15)
    else
      UI.rbox(t, 14, y + 2, 28, y + 16, 3, Color.new(*rgb))
      P.glyph(t, 14, y + 2, 15, 15, label[0], Color.new(248, 248, 248))
    end
    P.text(t, 33, y + 2, 138, 15, label, on ? c[:white] : c[:dim])
  end
  UI.rbox(b, 180, 36, W - 6, 262, 6, c[:panel])
  UI.rbox(b, 6, 268, W - 6, H - 30, 6, c[:panel2], c[:line])
end
def value_cell(t, c, x, y, v, sel)
  vw = P.width(PF::TEXT, v)
  cx = x
  P.text(t, cx - vw / 2, y, vw + 2, 24, v, v == "On" ? GREEN : c[:opt])
  arrow = sel ? c[:txt] : c[:dim]
  UI.tri(t, cx - vw / 2 - 14, y + 8, :l, arrow, 4); UI.tri(t, cx + vw / 2 + 6, y + 8, :r, arrow, 4)
end
def settings_list(c, items, start_y = 40)
  t = TOP.bitmap; b = BASE.bitmap
  y = start_y
  last = nil
  idx = 0
  items.each do |kind, group, label, value|
    if group != last
      P.heading(t, 190, W - 16, y + 3, group, c[:head], c[:line])
      y += 18
      last = group
    end
    break if y > 236
    cursor_at(184, y, W - 194, 24) if idx == SEL
    P.text(t, 201, y, 200, 24, label, c[:opt], PF::ROW)
    if kind == :tool
      P.pill(t, W - 18, y + 5, "OPEN", c[:pill], c[:txt])
    else
      value_cell(t, c, W - 60, y, value, idx == SEL)
    end
    y += 24
    idx += 1
  end
  b.fill_rect(W - 11, 44, 2, 212, c[:line]); b.fill_rect(W - 11, 44, 2, 60, c[:dim])
end
def desc_box(c, title, text, pills = [])
  t = TOP.bitmap
  P.text(t, 14, 269, 330, 26, title, c[:head], PF::ROW)
  x = W - 14
  pills.each { |p| x -= P.pill(t, x, 276, p, c[:pill], c[:txt]) + 6 }
  P.small_wrap(t, text, W - 30).first(3).each_with_index { |ln, k| P.small(t, 14, 297 + k * 17, W - 34, 17, ln, c[:txt]) }
end
def hints(c, pairs); P.hints(BASE.bitmap, TOP.bitmap, c, pairs, $style); end
H_SET = [[:ud, "Select"], [:lr, "Change"], ["p:2", "Default"], [B_BTN, "Sections"]]
def dump_as(name); dump(name); puts "wrote #{name}"; end

c = palette(2)
items = ROWS.map { |g, l, v, _, _| [:row, g == "Items and Money" ? "Quality of Life" : g == "Moves" ? "Quality of Life" : "Quality of Life", l, v] }

#================================================================ Q1 Recommended: rows in the Kanto Reloaded section
frame(c)
settings_frame(c, SECTIONS, 0)
list = ROWS.map { |g, l, v, _, _| [:row, "Quality of Life", l, v] } + TOOLS.map { |l, _, _| [:tool, "Quality of Life Tools", l, nil] }
settings_list(c, list)
desc_box(c, "Auto-Repel Reuse", ROWS[1][4], ["DEFAULT: OFF", "THIS SAVE"])
hints(c, H_SET)
dump_as("Q1_kr_section")

#================================================================ Q2 Own "Assists" section, grouped
frame(c)
secs = [["Kanto Reloaded", [214, 52, 60]], ["Assists", [120, 200, 120]]] + SECTIONS[1..5]
settings_frame(c, secs, 1)
list = ROWS.map { |g, l, v, _, _| [:row, g, l, v] } + TOOLS.map { |l, _, _| [:tool, "Tools", l, nil] }
settings_list(c, list)
desc_box(c, "Auto-Repel Reuse", ROWS[1][4], ["DEFAULT: OFF", "THIS SAVE"])
hints(c, H_SET)
dump_as("Q2_assists_section")

#================================================================ Q3 Assists screen of toggle tiles
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
P.text(t, 0, 2, W, 28, "Assists", c[:title], PF::TITLE, 2)
tw = 122; th = 54
(ROWS + TOOLS.map { |l, ic, d| ["Tools", l, "Open", ic, d] }).each_with_index do |(g, l, v, ic, d), i|
  tx = 8 + (i % 4) * (tw + 4); ty = 38 + (i / 4) * (th + 2)
  on = v == "On"
  UI.rbox(b, tx, ty, tx + tw - 1, ty + th - 1, 6, on ? Reloaded::Palette.mix(c[:panel], GREEN, 0.2) : c[:panel], on ? GREEN : c[:line])
  cursor_at(tx, ty, tw, th) if i == SEL
  item_icon(t, ic, tx + 18, ty + 20, 26)
  P.text(t, tx + 34, ty + 6, tw - 38, 14, v.upcase, on ? GREEN : (v == "Open" ? c[:acc] : c[:dim]), PF::TINY)
  P.text(t, tx + 4, ty + 34, tw - 8, 14, PF.fit(PF::TINY, l, tw - 8), c[:txt], PF::TINY)
end
UI.rbox(b, 6, 268, W - 6, H - 30, 6, c[:panel2], c[:line])
desc_box(c, "Auto-Repel Reuse", ROWS[1][4], ["THIS SAVE"])
hints(c, [[:ud, "Choose"], [:lr, "Choose"], [A_BTN, "Toggle"], [B_BTN, "Close"]])
dump_as("Q3_tiles")

#================================================================ Q4 Overworld Menu's Toggles page (Tabbed Panel)
frame(c, false)
b = BASE.bitmap; t = TOP.bitmap
px0 = 4; pw = 236
UI.rbox(b, px0, 4, px0 + pw - 1, 352, 6, col(c[:panel], 238), c[:line])
P.text(t, px0 + 1, 7, pw, 22, "Overworld Menu", c[:shadow], PF::ROW, 2)
P.text(t, px0, 6, pw, 22, "Overworld Menu", c[:title], PF::ROW, 2)
["Main", "Toggles", "Info"].each_with_index do |pg, i|
  tw2 = (pw - 16) / 3; on = i == 1
  UI.rbox(b, px0 + 8 + i * tw2 + 1, 30, px0 + 8 + (i + 1) * tw2 - 2, 47, 4, on ? c[:sel] : col(c[:panel2], 230), on ? c[:selb] : nil)
  P.text(t, px0 + 8 + i * tw2, 30, tw2, 18, pg.upcase, on ? c[:white] : c[:dim], PF::TINY, 2)
end
(ROWS + TOOLS.map { |l, ic, d| ["Tools", l, "Open", ic, d] }).first(12).each_with_index do |(g, l, v, ic, d), i|
  y = 52 + i * 24
  cursor_at(px0 + 5, y, pw - 10, 23) if i == SEL
  item_icon(t, ic, px0 + 18, y + 11, 18)
  P.text(t, px0 + 32, y, 150, 23, PF.fit(PF::TEXT, l, 150), c[:txt], PF::TEXT)
  on = v == "On"
  if v != "On" && v != "Off"
    P.text(t, px0 + pw - 60, y, 48, 23, v, c[:acc], PF::TEXT, 1)
  else
    UI.rbox(b, px0 + pw - 44, y + 5, px0 + pw - 12, y + 18, 6, on ? GREEN : c[:dark], on ? nil : c[:line])
    UI.rbox(b, on ? px0 + pw - 25 : px0 + pw - 42, y + 7, on ? px0 + pw - 14 : px0 + pw - 31, y + 16, 4, on ? c[:dark] : c[:dim])
  end
end
UI.rbox(b, 248, 270, W - 6, 352, 6, col(c[:panel2], 240), c[:line])
P.text(t, 256, 274, 240, 18, "Auto-Repel Reuse", c[:head], PF::TEXT)
P.small_wrap(t, ROWS[1][4], 240).first(3).each_with_index { |ln, k| P.small(t, 256, 294 + k * 16, 244, 16, ln, c[:txt]) }
hints(c, [[:ud, "Choose"], [:lr, "Pages"], [A_BTN, "Toggle"], [B_BTN, "Close"]])
dump_as("Q4_owm_toggles")
puts "done"
