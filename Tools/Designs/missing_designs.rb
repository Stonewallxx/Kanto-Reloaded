# encoding: utf-8
# Mockups: Expanded Dex, part 3: Missing Sprites. Five designs, each two
# screens: an expanded Pokemon (Glameow, No. 579) when HR's Expanded
# spritepack isn't installed, on the chosen Summary stats page, and what the
# player is told / how it's fixed. The spritepack itself comes from the Mod
# Manager (not ours: these designs only point to it).
# PIF's own fallback is the "?" placeholder (Graphics/Pokemon/Icons/000).
# Design 1 = PIF's placeholder + a one-time notice that points to the Mod
# Manager.
# Usage (from this folder): ruby missing_designs.rb "<KIF Beta>" <work dir with metrics.json>
STSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "stats_designs.rb"), :encoding => "UTF-8")
STSRC2 = STSRC.split("c = palette(2)\n")[0].sub('"134", IVC', 'STATS.sum { |r| r[3] }.to_s, IVC').sub('"220", EVC', 'STATS.sum { |r| r[4] }.to_s, EVC').sub('"535", BSC', 'STATS.sum { |r| r[2] }.to_s, BSC')
eval(STSRC2, binding, "stats_designs.rb")

XD = File.join(HERE, "xd")
OVER2 = layer(3); OVER2.z = 4
Object.send(:remove_const, :STATS)
STATS = [["HP", 37, 49, 21, 0, 0], ["Attack", 24, 55, 14, 0, 0], ["Defense", 18, 42, 9, 0, 0],
         ["Sp. Atk", 18, 42, 25, 0, -1], ["Sp. Def", 17, 37, 11, 0, 0], ["Speed", 33, 85, 30, 4, 1]]
AMB = Color.new(240, 170, 60)
def xpic(b, name, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(File.join(XD, name + ".png")), Rect.new(0, 0, 96, 96))
end
def gheader(c, x, y)
  t = TOP.bitmap; b = BASE.bitmap
  P.text(t, x, y, 160, 24, "Glameow", c[:title], PF::ROW)
  P.small(t, x, y + 24, 80, 16, "Lv. 12", c[:txt])
  tbadge(b, 0, x, y + 44)
end
# The summary stats page (design 1 of the Summary topic) with a given sprite treatment
def summary(c, sprite)
  blank(c); tabs(c, 2); OVER2.bitmap.clear
  b = BASE.bitmap; t = TOP.bitmap
  t.fill_rect(26, 2, 72, 22, CLEAR); P.text(t, 28, 3, 70, 20, "Glameow", c[:txt], PF::TEXT)
  gheader(c, 14, 32)
  sprite.call(b, t)
  table(c, 170, 32, 334)
  UI.rbox(b, 170, 236, 504, 308, 8, c[:panel], c[:line])
  P.heading(t, 178, 496, 240, "Ability", c[:head], c[:line])
  P.text(t, 180, 256, 300, 22, "Limber", c[:txt], PF::TEXT)
  P.small(t, 180, 278, 300, 16, "Hidden: Keen Eye", c[:dim])
end
def notice(c, x, y, w, h, title, lines, buttons)
  d = DIMMER.bitmap; o = OVER.bitmap
  d.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
  UI.rbox(d, x, y, x + w, y + h, 8, col(c[:panel], 255), AMB)
  P.text(o, x, y + 6, w, 22, title, AMB, PF::ROW, 2)
  d.fill_rect(x + 10, y + 32, w - 20, 1, c[:line])
  lines.each_with_index { |l, k| P.small(o, x + 14, y + 40 + k * 18, w - 28, 16, l, c[:txt], 2) }
  bw = (w - 28 - (buttons.length - 1) * 8) / buttons.length
  buttons.each_with_index do |lbl, k|
    bx = x + 14 + k * (bw + 8)
    UI.rbox(d, bx, y + h - 36, bx + bw, y + h - 10, 6, k == 0 ? c[:sel] : c[:dark], k == 0 ? c[:selb] : c[:line])
    P.text(o, bx, y + h - 34, bw, 22, lbl, k == 0 ? c[:white] : c[:txt], PF::TEXT, 2)
  end
end
def ow(c); frame(c, false); clear_over; OVER2.bitmap.clear; MAPS.bitmap = Bitmap.new(File.join(HERE, "wx", "route24_clear.png")); end
HS = [[:lr, "Pages"], [:ud, "Pokémon"], [Y_BTN, "Hexagon"], [B_BTN, "Back"]]

c = palette(2)

#================================================================ MS1 Recommended: PIF's "?" placeholder; a one-time notice pointing to the Mod Manager
summary(c, proc { |b, t| xpic(t, "MISSING", 70, 150, 90); P.pill(t, 70 - 40, 206, "NO SPRITE", Color.new(70, 46, 14), AMB, false) })
P.small(TOP.bitmap, 8, 230, 160, 16, "Expanded Spritepack", c[:dim], 2)
P.small(TOP.bitmap, 8, 246, 160, 16, "not installed.", c[:dim], 2)
hints(c, HS); dump_as("MS1_summary")
ow(c)
notice(c, 76, 90, 360, 196, "Expanded Sprites Missing", ["New Pokémon from the Expanded Dex will", "show as \"?\" until their sprites are installed.", "Get the Expanded Spritepack from", "the Mod Manager (Spritepacks)."], ["OK", "Don't Show Again"])
dump_as("MS1_notice")

#================================================================ MS2: a silhouette in the Pokemon's own shape (from its data), name and number
summary(c, proc { |b, t| xpic(t, "GLAMEOW_sil", 70, 150, 110); P.text(t, 20, 196, 100, 20, "No. 579", c[:dim], PF::TEXT, 2) })
hints(c, HS); dump_as("MS2_summary")
frame(c, false); clear_over; OVER2.bitmap.clear
MAPS.bitmap = Bitmap.new(File.join(XD, "dex_missing.png"))
P.pill(TOP.bitmap, 112 - 40, 90, "NO SPRITE", Color.new(70, 46, 14), AMB, false)
dump_as("MS2_dex")

#================================================================ MS3: downloads on demand, like PIF's custom sprites (a spinner, then the sprite)
def spinner(b, cx, cy, r, c, frac)
  12.times do |k|
    a = k * Math::PI / 6
    on = k < (12 * frac).round
    b.fill_rect((cx + r * Math.cos(a)).round - 2, (cy + r * Math.sin(a)).round - 2, 5, 5, on ? c[:selb] : c[:dark])
  end
end
summary(c, proc { |b, t| spinner(t, 70, 140, 26, c, 0.6); P.small(t, 8, 178, 160, 16, "Downloading Sprite", c[:txt], 2); P.small(t, 8, 194, 160, 16, "60%", c[:dim], 2) })
hints(c, HS); dump_as("MS3_downloading")
summary(c, proc { |b, t| xpic(t, "GLAMEOW", 70, 150, 110) })
t = TOP.bitmap; b = BASE.bitmap
UI.rbox(b, 8, 320, 220, 352, 6, c[:panel], GREEN); P.small(t, 8, 328, 212, 16, "Sprite Downloaded", GREEN, 2)
hints(c, HS); dump_as("MS3_done")

#================================================================ MS4: checked at New Game: Expanded needs the spritepack first
def ng(c)
  frame(c, false); clear_over; OVER2.bitmap.clear
  MAPS.bitmap = Bitmap.new(File.join(HERE, "fx", "intro.png"))
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 252, 24, 500, 330, 8, col(c[:panel], 245), c[:line])
  P.text(t, 252, 30, 248, 24, "Choose a Pokédex", c[:title], PF::ROW, 2)
  [["Classic", "576", true], ["Expanded", "Needs Sprites", false]].each_with_index do |(n, cnt, ok), i|
    y = 62 + i * 30
    cursor_at(258, y, 236, 28) if i == 1
    P.text(t, 270, y + 2, 140, 24, n, ok ? c[:txt] : c[:dim], PF::ROW)
    P.small(t, 390, y + 6, 98, 16, cnt, ok ? c[:dim] : AMB, 1)
  end
  b.fill_rect(262, 126, 228, 1, c[:line])
  P.small_wrap(t, "Expanded needs the Expanded Spritepack. Install it from the Mod Manager, then start a new game.", 220).first(4).each_with_index { |ln, k| P.small(t, 266, 136 + k * 18, 224, 16, ln, c[:txt]) }
end
ng(c); hints(c, [[:ud, "Choose"], [A_BTN, "Start"], [B_BTN, "Back"]]); dump_as("MS4_new")
ng(c); notice(c, 96, 110, 320, 150, "Expanded Spritepack", ["Not installed yet.", "Close the game and install it", "from the Mod Manager."], ["OK"]); dump_as("MS4_confirm")

#================================================================ MS5: a Spritepacks check in the Kanto Reloaded settings
def sp_page(c, checked)
  frame(c); clear_over; OVER2.bitmap.clear
  MAPS.bitmap = Bitmap.new(W, H)
  settings_frame(c, SECTIONS, 0)
  b = BASE.bitmap; t = TOP.bitmap
  P.heading(t, 190, W - 16, 43, "Spritepacks", c[:head], c[:line])
  [["Base Spritepack", "Installed", GREEN], ["Expanded Spritepack", "Missing", AMB]].each_with_index do |(l, v, colr), i|
    y = 58 + i * 24
    cursor_at(184, y, W - 194, 24) if i == 1
    P.text(t, 196, y, 220, 24, l, c[:opt], PF::ROW); P.text(t, W - 130, y, 110, 24, v, colr, PF::TEXT, 1)
  end
  P.text(t, 196, 110, 220, 24, "Check Sprites", c[:opt], PF::ROW); P.pill(t, W - 18, 115, "OPEN", c[:pill], c[:txt])
  P.text(t, 14, 269, 300, 26, "Expanded Spritepack", c[:head], PF::ROW)
  txt = "522 Expanded Pokémon need it. Install it from the Mod Manager; until then they show as \"?\"."
  P.small_wrap(t, txt, W - 30).first(3).each_with_index { |ln, k| P.small(t, 14, 297 + k * 17, W - 30, 17, ln, c[:txt]) }
end
sp_page(c, false); hints(c, [[:ud, "Select"], [A_BTN, "Open"], [B_BTN, "Sections"]]); dump_as("MS5_settings")
sp_page(c, true)
d = DIMMER.bitmap; o = OVER.bitmap
d.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
UI.rbox(d, 96, 70, 416, 290, 8, col(c[:panel], 255), c[:selb])
P.text(o, 96, 76, 320, 22, "Sprite Check", c[:title], PF::ROW, 2)
d.fill_rect(106, 102, 300, 1, c[:line])
[["Kanto Pokémon", "576/576", GREEN], ["Expanded Pokémon", "0/522", AMB], ["Seen Without Sprites", "2", AMB], ["Custom Fusions", "Online", c[:txt]]].each_with_index do |(l, v, colr), k|
  y = 112 + k * 26
  P.text(o, 116, y, 200, 24, l, c[:txt], PF::TEXT); P.text(o, 290, y, 110, 24, v, colr, PF::TEXT, 1)
end
P.small(o, 96, 226, 320, 16, "Install the Expanded Spritepack", c[:dim], 2)
P.small(o, 96, 242, 320, 16, "from the Mod Manager.", c[:dim], 2)
dump_as("MS5_check")

#================================================================ MSX: his mix: 1's placeholder + notice, 3's download on demand, 5's Spritepacks settings with a Download
def msx_settings(c, dl)
  frame(c); clear_over; OVER2.bitmap.clear
  MAPS.bitmap = Bitmap.new(W, H)
  settings_frame(c, SECTIONS, 0)
  b = BASE.bitmap; t = TOP.bitmap
  P.heading(t, 190, W - 16, 43, "Spritepacks", c[:head], c[:line])
  rows = [["Base Spritepack", "Installed", GREEN], ["Expanded Pokémon", dl ? "42%" : "Missing", dl ? c[:selb] : AMB],
          ["Download Pokémon", "", nil], ["Download Fusions", "", nil], ["Download as Needed", "On", nil], ["Check Sprites", "", nil]]
  rows.each_with_index do |(l, v, colr), i|
    y = 58 + i * 24
    cursor_at(184, y, W - 194, 24) if i == 2
    P.text(t, 196, y, 220, 24, l, c[:opt], PF::ROW)
    if colr
      P.text(t, W - 130, y, 110, 24, v, colr, PF::TEXT, 1)
    elsif v.empty?
      P.pill(t, W - 18, y + 5, { 2 => (dl ? "CANCEL" : "41 MB"), 3 => "3.8 GB" }[i] || "OPEN", c[:pill], c[:txt])
    else
      value_cell(t, c, W - 60, y, v, false)
    end
  end
  if dl
    b.fill_rect(196, 210, 300, 8, c[:dark]); b.fill_rect(196, 210, 126, 8, c[:selb])
    P.small(t, 196, 222, 300, 16, "17 MB of 41 MB. You can keep playing.", c[:dim])
  end
  P.text(t, 14, 269, 300, 26, dl ? "Downloading" : "Download Pokémon", c[:head], PF::ROW)
  txt = dl ? "The Expanded Pokémon's sprites download in the background. Ones already seen get their sprites as soon as it finishes." : "Every Expanded Pokémon's own sprites (41 MB). Their fusions are 3.8 GB, so they come as needed unless you get them all."
  P.small_wrap(t, txt, W - 30).first(3).each_with_index { |ln, k| P.small(t, 14, 297 + k * 17, W - 30, 17, ln, c[:txt]) }
  hints(c, [[:ud, "Select"], [A_BTN, dl ? "Cancel" : "Download"], [B_BTN, "Sections"]])
end
msx_settings(c, false); dump_as("MSX_settings")
ow(c)
notice(c, 66, 84, 380, 210, "Expanded Sprites Missing", ["New Pokémon from the Expanded Dex show as \"?\"", "until their sprites are downloaded.", "Get them all now (41 MB), or each one the", "first time it's seen. Settings > Spritepacks."], ["Download All", "As Needed", "Later"])
dump_as("MSX_notice")
msx_settings(c, true); dump_as("MSX_downloading")
