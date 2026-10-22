# encoding: utf-8
# Mockups: Trainer Card, the Front tab only (topic 17, one tab at a time).
# Five designs on PIF's base Blue background with no PIF frame or plates:
# KR elements in the KR Theme, kept light so most of the art shows, like the
# default card. Each holds: name, title, Trainer ID, Money, Pokedex, Time,
# Started, three Showcase Pokemon, 8 badges, your trainer, the tab row.
# Design 1 = the default card's layout (rows left, ID and trainer right,
# badges along the bottom), redrawn lighter in our kit.
# White plates (his note): solid white like the default card, or glass white.
# Usage (from this folder): ruby tcfront_white.rb "<KIF Beta>" <work dir> solid|glass
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "bmenu_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "bmenu_designs.rb")

def battle_text(c); end
TABS = ["Front", "Records", "Stats", "Style", "Unlocks"]
SHOW = ["PIKACHU", "LAPRAS", "GYARADOS"]
FACTS = [["Money", "$12,450"], ["Pokédex", "88/140"], ["Time", "24h 13m"], ["Started", "Oct 12, 2026"]]
def red(t, cx, bottom, size)
  i = bmp(File.join(GFX, "Trainers", "POKEMONTRAINER_Red.png"))
  t.stretch_blt(Rect.new(cx - size / 2, bottom - size, size, size), i, Rect.new(0, 0, i.height, i.height))
end
def badge_icon(t, k, x, y, size = 26)
  i = bmp(File.join(GFX, "Pictures/Trainer Card/icon_badges.png"))
  t.stretch_blt(Rect.new(x, y, size, size), i, Rect.new(k * 32, 0, 32, 32))
end
MODE = (ENV["TCMODE"] || "glass")
def glass(b, c, x, y, w, h, a = 170, r = 8)
  a = MODE == "solid" ? 238 : 150
  UI.rbox(b, x, y, x + w, y + h, r, Color.new(250, 252, 255, a), Color.new(255, 255, 255, MODE == "solid" ? 255 : 220))
end
def tabs_row(b, t, c, x, y, on = 0, a = 190)
  widths = TABS.map { |p| P.width(PF::TINY, p.upcase) + 12 }
  x = (W - widths.sum - 4 * (TABS.length - 1)) / 2 if x == :center
  TABS.each_with_index do |p, i|
    sel = i == on
    UI.rbox(b, x, y, x + widths[i], y + 15, 5, sel ? Color.new(40, 96, 176) : Color.new(250, 252, 255, MODE == "solid" ? 238 : 160))
    P.text(t, x, y, widths[i], 16, p.upcase, sel ? Color.new(255, 255, 255) : c[:dim], PF::TINY, 2)
    x += widths[i] + 4
  end
end
def base(c)
  frame(c)
  MAPS.bitmap = Bitmap.new(File.join(HERE, "fx", "tcbg_blue.png"))
end
H = [[:lr, "Tabs"], [A_BTN, "Actions"], [B_BTN, "Close"]]
def shot(name); dump_as("#{name}_#{MODE}"); end

c = palette(2)
C0 = c
c = c.merge(:txt => Color.new(40, 44, 56), :dim => Color.new(96, 104, 120), :head => Color.new(40, 96, 176),
            :title => Color.new(24, 28, 40), :panel => Color.new(250, 252, 255), :line => Color.new(200, 210, 225),
            :dark => Color.new(150, 168, 196))
Object.send(:remove_const, :GOLD); GOLD = Color.new(176, 120, 0)

#================================================================ TF1 Recommended: the default card's layout, lighter
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_row(b, t, c, :center, 26)
glass(b, c, 36, 48, 268, 40, 175)
P.text(t, 46, 50, 160, 24, "Red", c[:title], PF::ROW)
P.text(t, 46, 72, 160, 12, "ACE TRAINER", GOLD, PF::TINY)
FACTS.each_with_index do |(l, v), i|
  y = 96 + i * 34
  glass(b, c, 36, y, 268, 28, 150, 6)
  P.text(t, 46, y + 3, 150, 22, l, c[:dim], PF::TEXT)
  P.text(t, 36, y + 3, 258, 22, v, c[:txt], PF::TEXT, 1)
end
glass(b, c, 330, 48, 144, 40, 175)
P.text(t, 330, 52, 144, 12, "TRAINER ID", c[:head], PF::TINY, 2); P.text(t, 330, 64, 144, 22, "04821", c[:txt], PF::ROW, 2)
red(t, 402, 238, 140)
SHOW.each_with_index { |sp, i| glass(b, c, 344 + i * 44, 240, 40, 36, 150, 8); mon(t, sp, 364 + i * 44, 258, 36) }
glass(b, c, 36, 292, 438, 40, 140)
8.times { |k| x = 52 + k * 52; UI.rbox(b, x, 298, x + 28, 326, 7, Color.new(255, 255, 255, 120)); badge_icon(t, k, x + 1, 299) if k < 3 }
hints(C0, H)
shot("TF1")

#================================================================ TF2 Corners: everything tucked into the corners
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_row(b, t, c, :center, 26)
glass(b, c, 36, 48, 170, 52)
P.text(t, 46, 50, 160, 26, "Red", c[:title], PF::TITLE)
P.text(t, 46, 78, 150, 12, "ACE TRAINER · 04821", GOLD, PF::TINY)
FACTS.each_with_index do |(l, v), i|
  y = 232 + i * 24
  w = P.width(PF::TINY, l.upcase) + P.width(PF::TEXT, v) + 24
  glass(b, c, 36, y, w, 20, 175, 6)
  P.text(t, 44, y + 4, 80, 12, l.upcase, c[:head], PF::TINY)
  P.text(t, 36, y, w - 8, 20, v, c[:txt], PF::TEXT, 1)
end
red(t, 300, 300, 170)
SHOW.each_with_index { |sp, i| UI.rbox(b, 408, 60 + i * 52, 456, 104 + i * 52, 22, Color.new(250, 252, 255, MODE == "solid" ? 238 : 150), Color.new(255, 255, 255)); mon(t, sp, 432, 82 + i * 52, 40) }
glass(b, c, 378, 280, 110, 62, 175)
8.times { |k| badge_icon(t, k, 386 + (k % 4) * 25, 286 + (k / 4) * 27, 22) if k < 3; UI.rbox(b, 386 + (k % 4) * 25, 286 + (k / 4) * 27, 408 + (k % 4) * 25, 308 + (k / 4) * 27, 6, Color.new(255, 255, 255, 110)) if k >= 3 }
hints(C0, H)
shot("TF2")

#================================================================ TF3 Lanyard ID: an ID card hanging on a strap
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_row(b, t, c, 236, 26)
b.fill_rect(118, 20, 4, 40, c[:selb]); b.fill_rect(150, 20, 4, 40, c[:selb])
UI.rbox(b, 124, 52, 148, 66, 4, Color.new(200, 210, 225))
glass(b, c, 48, 62, 176, 230, 200, 10)
UI.rbox(b, 76, 72, 196, 142, 8, Color.new(255, 255, 255, 120))
red(t, 136, 142, 72)
P.text(t, 48, 146, 176, 26, "Red", c[:title], PF::TITLE, 2)
P.text(t, 48, 172, 176, 12, "ACE TRAINER", GOLD, PF::TINY, 2)
P.text(t, 48, 186, 176, 12, "ID 04821", c[:head], PF::TINY, 2)
FACTS.each_with_index { |(l, v), i| y = 204 + i * 20; P.text(t, 58, y + 3, 80, 12, l.upcase, c[:head], PF::TINY); P.small(t, 58, y, 156, 16, v, c[:txt], 1) }
red(t, 380, 262, 170)
SHOW.each_with_index { |sp, i| glass(b, c, 300 + i * 56, 268, 50, 44, 160, 10); mon(t, sp, 325 + i * 56, 290, 42) }
8.times { |k| x = 60 + k * 22; UI.rbox(b, x, 304, x + 18, 322, 9, Color.new(255, 255, 255, 120)); badge_icon(t, k, x - 1, 303, 20) if k < 3 }
hints(C0, H)
shot("TF3")

#================================================================ TF4 Ribbon: the art up top, one ribbon across the lower card
base(c)
b = BASE.bitmap; t = TOP.bitmap
P.text(t, 45, 37, 300, 34, "Red", Color.new(20, 40, 80), PF::TITLE); P.text(t, 44, 36, 300, 34, "Red", Color.new(250, 252, 255), PF::TITLE)
P.text(t, 46, 70, 200, 12, "ACE TRAINER · ID 04821", Color.new(250, 252, 255), PF::TINY)
tabs_row(b, t, c, 236, 30)
red(t, 400, 248, 170)
glass(b, c, 24, 236, 464, 96, 190, 0)
FACTS.each_with_index do |(l, v), i|
  x = 36 + i * 92
  P.text(t, x, 242, 90, 12, l.upcase, c[:head], PF::TINY)
  P.text(t, x, 254, 90, 22, v, c[:txt], PF::TEXT)
end
b.fill_rect(36, 282, 440, 1, c[:line])
8.times { |k| x = 36 + k * 24; UI.rbox(b, x, 292, x + 20, 312, 6, Color.new(255, 255, 255, 120)); badge_icon(t, k, x, 292, 20) if k < 3 }
SHOW.each_with_index { |sp, i| mon(t, sp, 372 + i * 42, 304, 38) }
P.text(t, 240, 298, 106, 12, "SHOWCASE", c[:head], PF::TINY, 1)
hints(C0, H)
shot("TF4")

#================================================================ TF5 Glass Column: a slim column on the right, the trainer on the art
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_row(b, t, c, 36, 26)
red(t, 170, 300, 200)
SHOW.each_with_index { |sp, i| mon(t, sp, 60 + i * 52, 318, 44) }
glass(b, c, 318, 26, 170, 344, 175, 0)
P.text(t, 330, 32, 150, 26, "Red", c[:title], PF::TITLE)
P.text(t, 330, 60, 150, 12, "ACE TRAINER", GOLD, PF::TINY)
P.text(t, 330, 74, 150, 12, "ID 04821", c[:head], PF::TINY)
FACTS.each_with_index do |(l, v), i|
  y = 96 + i * 40
  b.fill_rect(330, y - 4, 146, 1, c[:line])
  P.text(t, 330, y, 146, 12, l.upcase, c[:head], PF::TINY)
  P.text(t, 330, y + 12, 146, 22, v, c[:txt], PF::TEXT)
end
b.fill_rect(330, 256, 146, 1, c[:line])
P.text(t, 330, 262, 146, 12, "BADGES 3/8", c[:head], PF::TINY)
8.times { |k| x = 330 + (k % 4) * 36; y = 278 + (k / 4) * 36; UI.rbox(b, x, y, x + 30, y + 30, 7, Color.new(255, 255, 255, 120)); badge_icon(t, k, x + 2, y + 2) if k < 3 }
hints(C0, H)
shot("TF5")
