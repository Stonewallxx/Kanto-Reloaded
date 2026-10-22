# encoding: utf-8
# Mockups: the Trainer Card redesign (topic 17). Each design is two screens:
# the front (name, ID, money, Pokedex, time, started, badges, your trainer,
# and the new Showcase Pokemon) and the new Stats page. Pages: Front,
# Records (topic 16), Stats, Style (PIF's Glimmer Coins and Clothes/Hats).
# Backgrounds stay PIF's (110 to buy): BLUE (the default) or CHARIZARD here.
# New: Background Preview and Save as Image sit on the card's actions.
# Design 1 = PIF's card rebuilt: its frame and backgrounds, readable on any
# background, the showcase under your trainer, page dots.
# Usage (from this folder): ruby tcard_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "bmenu_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "bmenu_designs.rb")

def battle_text(c); end
INK = Color.new(56, 56, 64); INK_SH = Color.new(176, 176, 184)
FRONT = [["Name", "Red"], ["Money", "$12,450"], ["Pokédex", "88/140"], ["Time", "24h 13m"], ["Started", "Oct 12, 2026"]]
STATS = [["Steps", "48,210"], ["Caught", "96"], ["Fusions Made", "14"], ["Eggs Hatched", "9"], ["Shinies Found", "2"], ["Battles Won", "87"]]
SHOW = ["PIKACHU", "LAPRAS", "GYARADOS"]
PAGES = ["Front", "Records", "Stats", "Style"]
def backdrop(name); MAPS.bitmap = Bitmap.new(File.join(HERE, "fx", name)); end
def red(t, cx, bottom, size)
  i = bmp(File.join(GFX, "Trainers", "POKEMONTRAINER_Red.png"))
  t.stretch_blt(Rect.new(cx - size / 2, bottom - size, size, size), i, Rect.new(0, 0, i.height, i.height))
end
def badges(t, x, y, n, step = 48, size = 32)
  i = bmp(File.join(GFX, "Pictures/Trainer Card/icon_badges.png"))
  n.times { |k| t.stretch_blt(Rect.new(x + k * step, y, size, size), i, Rect.new(k * 32, 0, 32, 32)) }
end
def card_row(b, t, x, y, w, label, value, plate = true)
  UI.rbox(b, x, y, x + w, y + 30, 6, Color.new(248, 248, 252, 225)) if plate
  P.text(t, x + 11, y + 4, 180, 24, label, INK_SH, PF::ROW); P.text(t, x + 10, y + 3, 180, 24, label, INK, PF::ROW)
  P.text(t, x + 1, y + 4, w - 10, 24, value, INK_SH, PF::ROW, 1); P.text(t, x, y + 3, w - 10, 24, value, INK, PF::ROW, 1)
end
def page_dots(b, t, c, x, y, on, light = false)
  PAGES.each_with_index do |p, i|
    w = P.width(PF::TINY, p.upcase) + 12
    UI.rbox(b, x, y, x + w, y + 15, 5, i == on ? c[:selb] : Color.new(20, 24, 36, light ? 140 : 200))
    P.text(t, x, y, w, 16, p.upcase, i == on ? Color.new(16, 24, 40) : Color.new(220, 228, 240), PF::TINY, 2)
    x += w + 4
  end
end
def kr_panel(b, x, y, w, h, c, a = 225); UI.rbox(b, x, y, x + w, y + h, 8, col(c[:panel], a), c[:line]); end
def kr_row(t, c, x, y, w, label, value)
  P.text(t, x, y, 160, 22, label, c[:dim], PF::TEXT)
  P.text(t, x, y, w, 22, value, c[:txt], PF::TEXT, 1)
end
CARD_HINTS = [[:lr, "Pages"], [A_BTN, "Actions"], [Y_BTN, "Background"], [B_BTN, "Close"]]
def shot(name); dump_as(name); end

c = palette(2)

#================================================================ TCD1 Recommended: PIF's card, rebuilt
frame(c)
backdrop("tc_blue.png")
b = BASE.bitmap; t = TOP.bitmap
FRONT.each_with_index { |(l, v), i| card_row(b, t, 28, 62 + i * 48, 280, l, v) }
UI.rbox(b, 330, 40, 470, 88, 6, Color.new(248, 248, 252, 225))
P.text(t, 330, 42, 140, 20, "TRAINER ID", INK, PF::TINY, 2); P.text(t, 330, 58, 140, 24, "04821", INK, PF::ROW, 2)
red(t, 400, 214, 112)
SHOW.each_with_index { |sp, i| mon(t, sp, 352 + i * 48, 232, 44) }
badges(t, 72, 310, 3)
page_dots(b, t, c, 152, 344, 0)
hints(c, CARD_HINTS)
shot("TCD1_front")
frame(c)
backdrop("tc_blue.png")
b = BASE.bitmap; t = TOP.bitmap
STATS.first(5).each_with_index { |(l, v), i| card_row(b, t, 28, 62 + i * 48, 280, l, v) }
UI.rbox(b, 330, 40, 470, 88, 6, Color.new(248, 248, 252, 225))
P.text(t, 330, 42, 140, 20, "STATS", INK, PF::TINY, 2); P.text(t, 330, 58, 140, 24, "Page 3 of 4", INK, PF::TEXT, 2)
UI.rbox(b, 330, 104, 470, 248, 6, Color.new(248, 248, 252, 225))
P.text(t, 330, 112, 140, 20, STATS[5][0].upcase, INK, PF::TINY, 2); P.text(t, 330, 128, 140, 30, STATS[5][1], INK, PF::TITLE, 2)
P.text(t, 330, 172, 140, 20, "BEST STREAK", INK, PF::TINY, 2); P.text(t, 330, 188, 140, 30, "12", INK, PF::TITLE, 2)
badges(t, 72, 310, 3)
page_dots(b, t, c, 152, 344, 2)
hints(c, CARD_HINTS)
shot("TCD1_stats")

#================================================================ TCD2 Full-Bleed Art: the background fills the screen, KR panels on top
frame(c)
backdrop("tc_char_art.png")
b = BASE.bitmap; t = TOP.bitmap
page_dots(b, t, c, 8, 8, 0, true)
kr_panel(b, 8, 30, 236, 188, c)
P.text(t, 20, 36, 200, 26, "Red", c[:title], PF::TITLE)
P.text(t, 20, 64, 200, 12, "TRAINER ID 04821", c[:head], PF::TINY)
FRONT.drop(1).each_with_index { |(l, v), i| kr_row(t, c, 20, 84 + i * 30, 212, l, v) }
red(t, 380, 262, 150)
SHOW.each_with_index do |sp, i|
  UI.rbox(b, 300 + i * 56, 268, 348 + i * 56, 316, 10, col(c[:panel], 200), c[:line])
  mon(t, sp, 324 + i * 56, 292, 44)
end
kr_panel(b, 8, 226, 236, 90, c)
P.text(t, 20, 232, 200, 12, "BADGES 3/8", c[:head], PF::TINY)
badges(t, 20, 250, 3, 36, 28)
5.times { |k| UI.rbox(b, 20 + (3 + k) * 36, 250, 48 + (3 + k) * 36, 278, 6, Color.new(20, 24, 36, 160)) }
hints(c, CARD_HINTS)
shot("TCD2_front")
frame(c)
backdrop("tc_char_art.png")
b = BASE.bitmap; t = TOP.bitmap
page_dots(b, t, c, 8, 8, 2, true)
STATS.each_with_index do |(l, v), i|
  x = 8 + (i % 3) * 168; y = 40 + (i / 3) * 100
  kr_panel(b, x, y, 160, 92, c)
  P.text(t, x, y + 16, 160, 30, v, c[:title], PF::TITLE, 2)
  P.text(t, x, y + 56, 160, 14, l.upcase, c[:head], PF::TINY, 2)
end
hints(c, CARD_HINTS)
shot("TCD2_stats")

#================================================================ TCD3 License: a portrait on the art, an info column
frame(c)
backdrop("tc_char_art.png")
b = BASE.bitmap; t = TOP.bitmap
kr_panel(b, 8, 8, 176, 316, c, 160)
red(t, 96, 196, 150)
P.text(t, 8, 198, 176, 26, "Red", c[:title], PF::TITLE, 2)
P.text(t, 8, 226, 176, 12, "ID 04821", c[:head], PF::TINY, 2)
SHOW.each_with_index { |sp, i| mon(t, sp, 48 + i * 48, 270, 44) }
kr_panel(b, 192, 8, W - 200, 316, c)
P.text(t, 204, 14, 200, 12, "TRAINER CARD", c[:head], PF::TINY)
FRONT.drop(1).each_with_index { |(l, v), i| y = 34 + i * 30; kr_row(t, c, 204, y, W - 224, l, v); b.fill_rect(204, y + 26, W - 224, 1, c[:line]) }
P.text(t, 204, 160, 200, 12, "BADGES", c[:head], PF::TINY)
badges(t, 204, 176, 3, 36, 28)
5.times { |k| UI.rbox(b, 204 + (3 + k) * 36, 176, 232 + (3 + k) * 36, 204, 6, c[:dark]) }
page_dots(b, t, c, 204, 300, 0)
hints(c, CARD_HINTS)
shot("TCD3_front")
frame(c)
backdrop("tc_char_art.png")
b = BASE.bitmap; t = TOP.bitmap
kr_panel(b, 8, 8, 176, 316, c, 160)
red(t, 96, 196, 150)
P.text(t, 8, 198, 176, 26, "Red", c[:title], PF::TITLE, 2)
kr_panel(b, 192, 8, W - 200, 316, c)
P.text(t, 204, 14, 200, 12, "STATS", c[:head], PF::TINY)
STATS.each_with_index { |(l, v), i| y = 34 + i * 30; kr_row(t, c, 204, y, W - 224, l, v); b.fill_rect(204, y + 26, W - 224, 1, c[:line]) }
page_dots(b, t, c, 204, 300, 2)
hints(c, CARD_HINTS)
shot("TCD3_stats")

#================================================================ TCD4 Two Sides: an identity front, everything else on the back
frame(c)
backdrop("tc_char.png")
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 28, 60, 308, 140, 8, Color.new(248, 248, 252, 225))
P.text(t, 40, 66, 260, 34, "Red", INK, PF::TITLE)
P.text(t, 40, 104, 260, 20, "TRAINER ID 04821", INK, PF::TINY)
UI.rbox(b, 28, 156, 308, 284, 8, Color.new(248, 248, 252, 225))
P.text(t, 40, 162, 200, 12, "SHOWCASE", INK, PF::TINY)
SHOW.each_with_index { |sp, i| mon(t, sp, 76 + i * 92, 226, 72) }
red(t, 400, 240, 120)
badges(t, 72, 310, 3)
P.pill(t, 482, 362, "FRONT · A TO FLIP", Color.new(20, 24, 36), Color.new(220, 228, 240), true)
hints(c, [[A_BTN, "Flip"], [B_BTN, "Close"]])
shot("TCD4_front")
frame(c)
backdrop("tc_char.png")
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 28, 62, 484, 296, 8, Color.new(248, 248, 252, 230))
rows = FRONT.drop(1) + STATS.first(4)
rows.each_with_index do |(l, v), i|
  x = 40 + (i / 5) * 224; y = 68 + (i % 5) * 45
  P.text(t, x, y, 200, 14, l.upcase, Color.new(90, 90, 100), PF::TINY)
  P.text(t, x, y + 14, 200, 26, v, INK, PF::ROW)
end
P.pill(t, 482, 362, "BACK · A TO FLIP", Color.new(20, 24, 36), Color.new(220, 228, 240), true)
hints(c, [[A_BTN, "Flip"], [B_BTN, "Close"]])
shot("TCD4_stats")
