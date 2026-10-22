# encoding: utf-8
# Mockups: Trainer Card, the Stats tab (five designs), in the locked Front /
# Records style: the lanyard card, Glass White, PIF's light-background colour
# pairs, shadows on text (not on tags, badges, hints or the ID), values in the
# regular font. Each stat has an item icon.
# Design 1 = the card's back, like Records.
# Usage (from this folder): ruby tcstats.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "tcrecords.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "tcrecords.rb")

# [label, value, item icon]
STATS = [["Steps", "48,210", "BICYCLE"], ["Caught", "96", "POKEBALL"], ["Fusions Made", "14", "DNASPLICERS"],
         ["Eggs Hatched", "9", "OVALCHARM"], ["Shinies Found", "2", "SHINYCHARM"], ["Trades", "3", "LINKINGCORD"],
         ["Levels Gained", "412", "RARECANDY"], ["Hall of Fame", "0", "AMULETCOIN"]]
def icon(t, name, cx, cy, size = 18)
  i = bmp(File.join(GFX, "Items", name + ".png"))
  t.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), i, Rect.new(0, 0, i.width, i.height))
end
def card_back(b, t, title)
  strap(b, 116, 152, 20, 58); clip(b, 136, 50)
  glass(b, 44, 62, 184, 290, 10)
  stx(t, 44, 68, 184, 22, title, BLACK, PF::ROW, 2)
  title_id(t, 44, 184, 90, "RED", " · ID 04821")
  b.fill_rect(56, 106, 160, 1, Color.new(255, 255, 255, 200))
end
HS = [[:lr, "Tabs"], [A_BTN, "Actions"], [B_BTN, "Close"]]

c = palette(2)

#================================================================ TS1 Recommended: the card's back, like Records
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 2)
card_back(b, t, "Stats")
STATS.each_with_index do |(l, v, ic), i|
  y = 112 + i * 28
  icon(t, ic, 64, y + 10)
  stx(t, 78, y + 4, 110, 12, l.upcase, BLACK, PF::TINY)
  stx(t, 56, y, 160, 20, v, BLACK, PF::TEXT, 1)
end
red(t, 380, 236, 150)
glass(b, 300, 244, 160, 80, 10)
stx(t, 300, 250, 160, 12, "FUSIONS MADE", BLACK, PF::TINY, 2)
stx(t, 300, 266, 160, 34, "14", pif("Purple"), PF::TITLE, 2)
ssm(t, 300, 300, 160, 16, "Newest: Joltras", BLACK, 2)
hints(c, HS)
shot("TS1")

#================================================================ TS2 Icon Grid: the back as a grid of stat tiles
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 2)
card_back(b, t, "Stats")
STATS.each_with_index do |(l, v, ic), i|
  x = 52 + (i % 2) * 84; y = 112 + (i / 2) * 58
  UI.rbox(b, x, y, x + 80, y + 54, 8, Color.new(255, 255, 255, 120))
  icon(t, ic, x + 40, y + 11, 18)
  stx(t, x, y + 18, 80, 20, v, BLACK, PF::TEXT, 2)
  stx(t, x, y + 39, 80, 12, l.upcase, BLACK, PF::TINY, 2)
end
red(t, 380, 262, 170)
hints(c, HS)
shot("TS2")

#================================================================ TS3 Milestones: each stat on its way to the next milestone
MILES = [100_000, 100, 25, 25, 5, 10, 500, 1]
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 2)
card_back(b, t, "Stats")
STATS.first(7).each_with_index do |(l, v, ic), i|
  y = 112 + i * 32
  n = v.delete(",").to_i; m = MILES[i]
  icon(t, ic, 64, y + 8)
  stx(t, 78, y + 2, 110, 12, l.upcase, BLACK, PF::TINY)
  stx(t, 56, y - 2, 160, 20, v, BLACK, PF::TEXT, 1)
  b.fill_rect(78, y + 21, 104, 4, Color.new(255, 255, 255, 140))
  b.fill_rect(78, y + 21, [(104 * n / m.to_f).round, 104].min, 4, pif("Blue"))
  P.text(t, 184, y + 17, 32, 12, "/" + (m >= 1000 ? "#{m / 1000}K" : m.to_s), BLACK, PF::TINY, 1)
end
red(t, 380, 236, 150)
glass(b, 300, 244, 160, 80, 10)
stx(t, 300, 250, 160, 12, "NEXT MILESTONE", BLACK, PF::TINY, 2)
stx(t, 300, 266, 160, 22, "Caught 100", pif("Blue"), PF::ROW, 2)
ssm(t, 300, 292, 160, 16, "4 to go: Gold Card", BLACK, 2)
hints(c, HS)
shot("TS3")

#================================================================ TS4 Highlights: the stats on the card, your story beside it
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 2)
card_back(b, t, "Stats")
STATS.each_with_index do |(l, v, ic), i|
  y = 112 + i * 28
  icon(t, ic, 64, y + 10)
  stx(t, 78, y + 4, 110, 12, l.upcase, BLACK, PF::TINY)
  stx(t, 56, y, 160, 20, v, BLACK, PF::TEXT, 1)
end
glass(b, 244, 62, 240, 260, 10)
stx(t, 256, 68, 200, 12, "HIGHLIGHTS", BLACK, PF::TINY)
[["PIKACHU", "First Partner", "Pikachu, since Oct 12"], ["PIKACHU", "Most Battles", "Pikachu, 38 battles"],
 ["GYARADOS", "Strongest", "Gyarados, Lv. 41"], ["LAPRAS", "Newest Catch", "Lapras, Route 24"]].each_with_index do |(sp, h, d), i|
  y = 86 + i * 58
  UI.rbox(b, 252, y, 476, y + 52, 8, Color.new(255, 255, 255, 120))
  mon(t, sp, 282, y + 26, 44)
  stx(t, 312, y + 6, 160, 12, h.upcase, BLACK, PF::TINY)
  ssm(t, 312, y + 24, 162, 16, d, BLACK)
end
hints(c, HS)
shot("TS4")

#================================================================ TS5 Stamps: the stats as round stamps on the art around your trainer
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 2)
red(t, 256, 270, 170)
spots = [[64, 84], [64, 160], [64, 236], [150, 300], [362, 300], [448, 236], [448, 160], [448, 84]]
STATS.each_with_index do |(l, v, ic), i|
  cx, cy = spots[i]
  UI.rbox(b, cx - 38, cy - 34, cx + 38, cy + 34, 30, Color.new(250, 252, 255, 160), Color.new(255, 255, 255))
  icon(t, ic, cx, cy - 16, 20)
  stx(t, cx - 38, cy - 6, 76, 20, v, BLACK, PF::TEXT, 2)
  stx(t, cx - 38, cy + 14, 76, 12, l.upcase, BLACK, PF::TINY, 2)
end
hints(c, HS)
shot("TS5")

#================================================================ TS chosen: the card's back (1) with the Next Milestone tile (3) under the trainer
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 2)
card_back(b, t, "Stats")
STATS.each_with_index do |(l, v, ic), i|
  y = 112 + i * 28
  icon(t, ic, 64, y + 10)
  stx(t, 78, y + 4, 110, 12, l.upcase, BLACK, PF::TINY)
  stx(t, 56, y, 160, 20, v, BLACK, PF::TEXT, 1)
end
red(t, 380, 236, 150)
glass(b, 284, 236, 192, 96, 10)
stx(t, 284, 242, 192, 12, "NEXT MILESTONE", BLACK, PF::TINY, 2)
stx(t, 284, 256, 192, 22, "Caught 100", pif("Blue"), PF::ROW, 2)
b.fill_rect(320, 283, 120, 4, Color.new(255, 255, 255, 150)); b.fill_rect(320, 283, 115, 4, pif("Blue"))
ssm(t, 284, 289, 192, 16, "96 of 100", BLACK, 2)
ssm(t, 284, 308, 192, 16, "Next Unlock: Gold Card", BLACK, 2)
hints(c, HS)
shot("TSX")
