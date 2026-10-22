# encoding: utf-8
# Mockups: Trainer Card Front, three Lanyard ID designs (he liked design 3).
# His notes: glass white plates (more plate colours to unlock later); text in
# black, not grey; Money in green; the Pokedex count coloured by how complete
# it is; Time in light blue; the Started date coloured by the time of year
# (October = autumn orange); new: Run Tags (how you're playing).
# Usage (from this folder): ruby tclanyard.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "bmenu_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "bmenu_designs.rb")

def battle_text(c); end
TABS = ["Front", "Records", "Stats", "Style", "Unlocks"]
SHOW = ["PIKACHU", "LAPRAS", "GYARADOS"]
# KR's own text colours with their shadows (Reloaded::Palette::COLORS: the colour settings' pairs)
def hexc(h); Color.new(h[0, 2].to_i(16), h[2, 2].to_i(16), h[4, 2].to_i(16)); end
PAIR = { "Black" => ["505058", "a0a0a8"], "White" => ["f8f8f8", "485058"], "Red" => ["f07878", "5c2c2c"],
         "Orange" => ["f8a858", "604020"], "Yellow" => ["f0e058", "5c5420"], "Green" => ["32cd32", "146414"],
         "Cyan" => ["58e0e0", "205454"], "Blue" => ["58b0f8", "204060"], "Purple" => ["a880e4", "402c54"], "Pink" => ["f888c0", "603448"] }
# PIF's own colours for light backgrounds: deep text with a light shadow (getSkinColor, MessageConfig)
PIF_PAIR = { "Dark" => ["505058", "a0a0a8"], "Blue" => ["0070f8", "78b8e8"], "Red" => ["e82010", "f8a8b8"], "Green" => ["60b048", "b0d090"],
             "Cyan" => ["48d8d8", "a8e0e0"], "Magenta" => ["d038b8", "e8a0e0"], "Yellow" => ["e8d020", "f8e888"],
             "Purple" => ["9040e8", "b8a8e0"], "Orange" => ["f89818", "f8c898"] }
SHADOW_OF = {}
(PAIR.values + PIF_PAIR.values).each { |b, sh| c0 = hexc(b); SHADOW_OF[[c0.red, c0.green, c0.blue]] = hexc(sh) }
def kr(name); hexc(PAIR[name][0]); end
def pif(name); hexc(PIF_PAIR[name][0]); end
BLACK = pif("Dark")
MONEY = pif("Green")
TIMEC = pif("Blue")
# Pokedex completion: red < 25% < orange < 50% < amber < 75% < green < 100% = gold
# Pokedex: red under a third, orange under two thirds, green after, blue when complete
def dex_color(pct)
  return pif("Red") if pct < 34
  return pif("Orange") if pct < 67
  return pif("Green") if pct < 100
  pif("Blue")
end
# Time of year: winter ice blue, spring pink, summer gold, autumn orange
# Started: winter cyan, spring magenta, summer green, autumn purple
def season_color(month)
  return pif("Cyan") if [12, 1, 2].include?(month)
  return pif("Magenta") if [3, 4, 5].include?(month)
  return pif("Green") if [6, 7, 8].include?(month)
  pif("Purple")
end
FACTS = [["Money", "$12,450", MONEY], ["Pokédex", "88/140", dex_color(63)], ["Time", "24h 13m", TIMEC], ["Started", "Oct 12, 2026", season_color(10)]]
# the Front's facts: Platinum (Multiplayer's currency, $PokemonGlobal.platinum_balance) under Money,
# shown only when Multiplayer is installed
FRONT_FACTS = [FACTS[0], ["Platinum", "2,400 Pt", pif("Cyan")]] + FACTS[1..-1]
# Run Tags (his list): Randomized, Nuzlocke, the difficulty (Easy green / Normal blue / Hard orange), Debug
RUN_TAGS = [["RANDOMIZED", pif("Purple")], ["NUZLOCKE", pif("Red")], ["HARD", pif("Orange")]]
def red(t, cx, bottom, size)
  i = bmp(File.join(GFX, "Trainers", "POKEMONTRAINER_Red.png"))
  t.stretch_blt(Rect.new(cx - size / 2, bottom - size, size, size), i, Rect.new(0, 0, i.height, i.height))
end
def badge_icon(t, k, x, y, size = 20)
  i = bmp(File.join(GFX, "Pictures/Trainer Card/icon_badges.png"))
  t.stretch_blt(Rect.new(x, y, size, size), i, Rect.new((k % 8) * 32, (k / 8) * 32, 32, 32))
end
# glass white
def glass(b, x, y, w, h, r = 8, a = 150); UI.rbox(b, x, y, x + w, y + h, r, Color.new(250, 252, 255, a), Color.new(255, 255, 255, 220)); end
def tabs_row(b, t, x, y)
  widths = TABS.map { |p| P.width(PF::TINY, p.upcase) + 12 }
  TABS.each_with_index do |p, i|
    sel = i == 0
    UI.rbox(b, x, y, x + widths[i], y + 15, 5, sel ? Color.new(40, 96, 176) : Color.new(250, 252, 255, 160))
    P.text(t, x, y, widths[i], 16, p.upcase, sel ? Color.new(255, 255, 255) : BLACK, PF::TINY, 2)
    x += widths[i] + 4
  end
end
# Trainer Card text: a shadow on everything except hints, badges/tags and the ID number (his note)
def shadow_of(color); SHADOW_OF[[color.red, color.green, color.blue]] || hexc("a0a0a8"); end
def stx(t, x, y, w, h, s, color, font = PF::TEXT, align = 0)
  P.text(t, x + 1, y + 1, w, h, s, shadow_of(color), font, align); P.text(t, x, y, w, h, s, color, font, align)
end
def ssm(t, x, y, w, h, s, color, align = 0)
  P.small(t, x + 1, y + 1, w, h, s, shadow_of(color), align); P.small(t, x, y, w, h, s, color, align)
end
# the title with its shadow, then the ID without one, centred together
def title_id(t, x, w, y, title, id_text)
  tw = P.width(PF::TINY, title); iw = P.width(PF::TINY, id_text)
  x0 = x + (w - tw - iw) / 2
  stx(t, x0, y, tw + 2, 12, title, BLACK, PF::TINY); P.text(t, x0 + tw, y, iw + 2, 12, id_text, BLACK, PF::TINY)
end
def tag(b, t, x, y, label, colr)
  w = P.width(PF::TINY, label) + 10
  UI.rbox(b, x, y, x + w, y + 13, 4, colr)
  P.text(t, x, y, w, 14, label, Color.new(255, 255, 255), PF::TINY, 2)
  w
end
def strap(b, x1, x2, top, bottom)
  b.fill_rect(x1, top, 4, bottom - top, Color.new(214, 52, 60)); b.fill_rect(x2, top, 4, bottom - top, Color.new(214, 52, 60))
end
def clip(b, cx, y)
  UI.rbox(b, cx - 12, y, cx + 12, y + 14, 4, Color.new(205, 212, 225), Color.new(150, 160, 178))
  UI.rbox(b, cx - 6, y + 4, cx + 6, y + 9, 2, Color.new(150, 160, 178))
end
def base(c)
  frame(c)
  MAPS.bitmap = Bitmap.new(File.join(HERE, "fx", "tcbg_blue.png"))
end
H = [[:lr, "Tabs"], [A_BTN, "Actions"], [B_BTN, "Close"]]
def shot(name); dump_as(name); end

c = palette(2)

#================================================================ TL1 Portrait ID: the lanyard card from design 3, refined
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_row(b, t, 236, 26)
strap(b, 116, 152, 20, 58); clip(b, 136, 50)
glass(b, 44, 62, 184, 290, 10)
UI.rbox(b, 70, 72, 202, 128, 8, Color.new(255, 255, 255, 110))
red(t, 136, 128, 56)
stx(t, 44, 128, 184, 26, "Red", BLACK, PF::TITLE, 2)
title_id(t, 44, 184, 154, "ACE TRAINER", " · ID 04821")
FRONT_FACTS.each_with_index do |(l, v, cl), i|
  y = 168 + i * 20
  stx(t, 56, y + 5, 80, 12, l.upcase, BLACK, PF::TINY)
  # the date is longer than the rest: the small font keeps it in scale
  l == "Started" ? ssm(t, 56, y + 3, 160, 16, v, cl, 1) : stx(t, 56, y, 160, 20, v, cl, PF::TEXT, 1)
end
b.fill_rect(56, 269, 160, 1, Color.new(255, 255, 255, 200))
x = 56; y = 273
RUN_TAGS.each { |l, cl| w = P.width(PF::TINY, l) + 10; (x = 56; y += 16) if x + w > 216; x += tag(b, t, x, y, l, cl) + 4 }
# the badge case: Kanto on top, Johto under it (shown after the League, like PIF)
16.times { |k| bx = 56 + (k % 8) * 20; by = 308 + (k / 8) * 20; UI.rbox(b, bx, by, bx + 18, by + 18, 9, Color.new(255, 255, 255, 120)); badge_icon(t, k, bx - 1, by - 1) if k < 11 }
red(t, 380, 262, 170)
SHOW.each_with_index { |sp, i| glass(b, 300 + i * 56, 268, 50, 44, 10); mon(t, sp, 325 + i * 56, 290, 42) }
hints(c, H)
shot("TL1")

#================================================================ TL2 Landscape ID: a wide card on a strap, photo left
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_row(b, t, 236, 26)
strap(b, 140, 176, 20, 52); clip(b, 160, 44)
glass(b, 36, 56, 292, 186, 10)
UI.rbox(b, 46, 66, 136, 162, 8, Color.new(255, 255, 255, 110))
red(t, 91, 162, 92)
P.text(t, 146, 62, 176, 28, "Red", BLACK, PF::TITLE)
P.text(t, 146, 90, 176, 12, "ACE TRAINER · ID 04821", BLACK, PF::TINY)
FACTS.each_with_index { |(l, v, cl), i| y = 106 + i * 18; P.text(t, 146, y + 3, 80, 12, l.upcase, BLACK, PF::TINY); P.small(t, 146, y, 172, 16, v, cl, 1) }
x = 46
shown = 0
RUN_TAGS.each { |l, cl| w = P.width(PF::TINY, l) + 10; next if x + w > 318; x += tag(b, t, x, 184, l, cl) + 4; shown += 1 }
P.text(t, x, 185, 60, 12, "+#{RUN_TAGS.length - shown} MORE", BLACK, PF::TINY) if shown < RUN_TAGS.length
8.times { |k| bx = 46 + k * 34; UI.rbox(b, bx, 206, bx + 26, 232, 13, Color.new(255, 255, 255, 120)); badge_icon(t, k, bx + 1, 207, 24) if k < 3 }
red(t, 420, 272, 150)
glass(b, 36, 250, 292, 60, 10)
P.text(t, 46, 254, 120, 12, "SHOWCASE", BLACK, PF::TINY)
SHOW.each_with_index { |sp, i| mon(t, sp, 82 + i * 90, 286, 44) }
hints(c, H)
shot("TL2")

#================================================================ TL3 Badge Pins: the badges pinned on the lanyard strap itself
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_row(b, t, 236, 26)
# two straps run down from the top to the clip; the badges are pinned along them
thick = lambda do |x0, y0, x1, y1, w, colr|
  n = [(x1 - x0).abs, (y1 - y0).abs].max
  (0..n).each { |k| b.fill_rect(x0 + (x1 - x0) * k / n - w / 2, y0 + (y1 - y0) * k / n - w / 2, w, w, colr) }
end
thick.call(56, 20, 128, 108, 8, Color.new(214, 52, 60)); thick.call(216, 20, 144, 108, 8, Color.new(214, 52, 60))
8.times do |k|
  f = (k % 4 + 1) / 5.0
  px = k < 4 ? (56 + 72 * f).round : (216 - 72 * f).round
  py = (20 + 88 * f).round
  UI.rbox(b, px - 9, py - 9, px + 9, py + 9, 9, Color.new(255, 255, 255, 170), Color.new(255, 255, 255))
  badge_icon(t, k, px - 10, py - 10) if k < 3
end
clip(b, 136, 104)
glass(b, 52, 118, 168, 214, 10)
UI.rbox(b, 74, 128, 198, 188, 8, Color.new(255, 255, 255, 110))
red(t, 136, 188, 60)
P.text(t, 52, 190, 168, 24, "Red", BLACK, PF::TITLE, 2)
P.text(t, 52, 214, 168, 12, "ACE TRAINER · ID 04821", BLACK, PF::TINY, 2)
FACTS.each_with_index { |(l, v, cl), i| y = 230 + i * 17; P.text(t, 62, y + 3, 80, 12, l.upcase, BLACK, PF::TINY); P.small(t, 62, y, 148, 16, v, cl, 1) }
x = 62; y = 302
RUN_TAGS.first(2).each { |l, cl| x += tag(b, t, x, y, l, cl) + 4 }
P.text(t, 62, 316, 150, 12, "+2 MORE", BLACK, PF::TINY)
red(t, 380, 268, 180)
SHOW.each_with_index { |sp, i| UI.rbox(b, 448, 70 + i * 54, 496, 118 + i * 54, 24, Color.new(250, 252, 255, 150), Color.new(255, 255, 255)); mon(t, sp, 472, 94 + i * 54, 42) }
hints(c, H)
shot("TL3")
