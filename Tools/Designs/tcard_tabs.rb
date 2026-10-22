# encoding: utf-8
# Mockups: the chosen Trainer Card (topic 17, design 1) with every tab, as he
# asked: Front, Records, Stats, Style, Unlocks. Plates follow the KR Theme
# (Ocean Blue here); the Style tab picks the plate style (Theme / Light /
# Dark), the background (previewed on the card itself) and the showcase.
# Unlocks lists backgrounds and other unlockables with what each needs.
# Usage (from this folder): ruby tcard_tabs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "bmenu_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "bmenu_designs.rb")

def battle_text(c); end
TABS = ["Front", "Records", "Stats", "Style", "Unlocks"]
SHOW = ["PIKACHU", "LAPRAS", "GYARADOS"]
def backdrop(name); MAPS.bitmap = Bitmap.new(File.join(HERE, "fx", name)); end
def red(t, cx, bottom, size)
  i = bmp(File.join(GFX, "Trainers", "POKEMONTRAINER_Red.png"))
  t.stretch_blt(Rect.new(cx - size / 2, bottom - size, size, size), i, Rect.new(0, 0, i.height, i.height))
end
def badges(t, x, y, n)
  i = bmp(File.join(GFX, "Pictures/Trainer Card/icon_badges.png"))
  n.times { |k| t.stretch_blt(Rect.new(x + k * 48, y, 32, 32), i, Rect.new(k * 32, 0, 32, 32)) }
end
# a themed plate: the KR Theme's panel colour, its text colours
def plate(b, c, x, y, w, h = 30); UI.rbox(b, x, y, x + w, y + h, 6, col(c[:panel], 230), c[:line]); end
def row(b, t, c, y, label, value, value_color = nil)
  plate(b, c, 28, y, 280)
  P.text(t, 38, y + 3, 170, 24, label, c[:dim], PF::ROW)
  P.text(t, 28, y + 3, 270, 24, value, value_color || c[:txt], PF::ROW, 1)
end
def id_box(b, t, c, head, value)
  plate(b, c, 330, 40, 140, 48)
  P.text(t, 330, 43, 140, 14, head, c[:head], PF::TINY, 2)
  P.text(t, 330, 58, 140, 24, value, c[:txt], PF::ROW, 2)
end
def tabs(b, t, c, on)
  widths = TABS.map { |p| P.width(PF::TINY, p.upcase) + 12 }
  x = (W - widths.sum - 4 * (TABS.length - 1)) / 2
  TABS.each_with_index do |p, i|
    UI.rbox(b, x, 344, x + widths[i], 359, 5, i == on ? c[:selb] : col(c[:panel], 220))
    P.text(t, x, 344, widths[i], 16, p.upcase, i == on ? Color.new(16, 24, 40) : c[:dim], PF::TINY, 2)
    x += widths[i] + 4
  end
end
def lock(b, x, y, color)
  UI.rbox(b, x + 2, y, x + 10, y + 7, 3, color); UI.rbox(b, x + 4, y + 2, x + 8, y + 7, 1, Color.new(0, 0, 0, 0))
  UI.rbox(b, x, y + 6, x + 12, y + 15, 2, color)
end
def card(c, on)
  frame(c)
  backdrop("tc_blue.png")
  tabs(BASE.bitmap, TOP.bitmap, c, on)
end
CARD_HINTS = [[:lr, "Tabs"], [A_BTN, "Actions"], [Y_BTN, "Background"], [B_BTN, "Close"]]
def shot(name); dump_as(name); end

c = palette(2)

#================================================================ Front
card(c, 0)
b = BASE.bitmap; t = TOP.bitmap
[["Name", "Red"], ["Money", "$12,450"], ["Pokédex", "88/140"], ["Time", "24h 13m"], ["Started", "Oct 12, 2026"]].each_with_index { |(l, v), i| row(b, t, c, 62 + i * 48, l, v) }
id_box(b, t, c, "TRAINER ID", "04821")
plate(b, c, 330, 100, 140, 150)
red(t, 400, 214, 112)
SHOW.each_with_index { |sp, i| mon(t, sp, 352 + i * 48, 232, 44) }
badges(t, 72, 310, 3)
hints(c, CARD_HINTS)
shot("TT_front")

#================================================================ Records
card(c, 1)
b = BASE.bitmap; t = TOP.bitmap
[["Wins", "42", GREEN], ["Losses", "7", RED], ["Best Streak", "12", GOLD], ["Pink Slips Won", "5", nil], ["Gym Rematches", "9", nil]].each_with_index { |(l, v, cl), i| row(b, t, c, 62 + i * 48, l, v, cl) }
id_box(b, t, c, "RECORDS", "Battles 49")
plate(b, c, 330, 100, 140, 150)
P.text(t, 330, 110, 140, 14, "WIN RATE", c[:head], PF::TINY, 2); P.text(t, 330, 126, 140, 30, "86%", c[:title], PF::TITLE, 2)
P.text(t, 330, 170, 140, 14, "CURRENT STREAK", c[:head], PF::TINY, 2); P.text(t, 330, 186, 140, 30, "3", GOLD, PF::TITLE, 2)
P.small(t, 336, 226, 128, 16, "A: Battle Records", c[:dim], 2)
badges(t, 72, 310, 3)
hints(c, CARD_HINTS)
shot("TT_records")

#================================================================ Stats
card(c, 2)
b = BASE.bitmap; t = TOP.bitmap
[["Steps", "48,210"], ["Caught", "96"], ["Fusions Made", "14"], ["Eggs Hatched", "9"], ["Shinies Found", "2"]].each_with_index { |(l, v), i| row(b, t, c, 62 + i * 48, l, v) }
id_box(b, t, c, "STATS", "Since Oct 12")
plate(b, c, 330, 100, 140, 150)
P.text(t, 330, 110, 140, 14, "BATTLES WON", c[:head], PF::TINY, 2); P.text(t, 330, 126, 140, 30, "87", c[:title], PF::TITLE, 2)
P.text(t, 330, 170, 140, 14, "TRADES", c[:head], PF::TINY, 2); P.text(t, 330, 186, 140, 30, "3", c[:title], PF::TITLE, 2)
badges(t, 72, 310, 3)
hints(c, CARD_HINTS)
shot("TT_stats")

#================================================================ Style
card(c, 3)
b = BASE.bitmap; t = TOP.bitmap
style_rows = [["Background", "Blue", :value], ["Plates", "Theme", :value], ["Showcase", "EDIT", :tool], ["Glimmer Coins", "1,250", :info], ["Clothes / Hats", "12/30", :info]]
style_rows.each_with_index do |(l, v, k), i|
  y = 62 + i * 48
  plate(b, c, 28, y, 280)
  cursor_at(30, y + 2, 276, 26) if i == 1
  P.text(t, 38, y + 3, 150, 24, l, c[:dim], PF::ROW)
  case k
  when :value
    vw = P.width(PF::ROW, v); cx = 238
    P.text(t, cx - vw / 2, y + 3, vw + 2, 24, v, c[:txt], PF::ROW)
    UI.tri(t, cx - vw / 2 - 14, y + 11, :l, c[:txt], 4); UI.tri(t, cx + vw / 2 + 6, y + 11, :r, c[:txt], 4)
  when :tool then P.pill(t, 298, y + 8, v, c[:pill], c[:txt])
  else P.text(t, 28, y + 3, 270, 24, v, c[:txt], PF::ROW, 1)
  end
end
id_box(b, t, c, "STYLE", "Live Preview")
plate(b, c, 330, 100, 140, 150)
P.text(t, 330, 106, 140, 14, "PLATES", c[:head], PF::TINY, 2)
[["Theme", col(c[:panel], 230), c[:txt]], ["Light", Color.new(248, 248, 252, 230), Color.new(56, 56, 64)], ["Dark", Color.new(20, 20, 26, 230), Color.new(230, 230, 236)]].each_with_index do |(n, bg, fg), i|
  y = 124 + i * 36
  UI.rbox(b, 342, y, 458, y + 28, 6, bg, i == 0 ? c[:selb] : c[:line])
  P.text(t, 342, y + 2, 116, 24, n, fg, PF::TEXT, 2)
end
badges(t, 72, 310, 3)
hints(c, [[:ud, "Select"], [:lr, "Change"], [:tabs, "Tabs"], [B_BTN, "Close"]].reject { |k, _| k == :tabs })
shot("TT_style")

#================================================================ Unlocks
card(c, 4)
b = BASE.bitmap; t = TOP.bitmap
UN = [["Cascade Badge", "BACKGROUND", "Beat Misty", nil, true],
      ["Charizard", "BACKGROUND", "Catch a Charizard", nil, false],
      ["Eevee Flowers", "BACKGROUND", "Hatch 25 eggs", [9, 25], false],
      ["Gold Plates", "PLATE STYLE", "Find 10 shinies", [2, 10], false],
      ["Ace Trainer", "TITLE", "Win 100 battles", [87, 100], false]]
SELU = 1
UN.each_with_index do |(n, kind, need, prog, got), i|
  y = 62 + i * 48
  plate(b, c, 28, y, 280, 40)
  cursor_at(30, y + 2, 276, 36) if i == SELU
  if got
    UI.rbox(b, 36, y + 12, 50, y + 26, 7, GREEN)
  else
    lock(b, 37, y + 12, c[:dim])
  end
  P.text(t, 58, y + 2, 170, 20, n, got ? c[:txt] : c[:dim], PF::TEXT)
  P.text(t, 58, y + 22, 140, 12, kind, c[:head], PF::TINY)
  P.small(t, 150, y + 3, 150, 16, need, c[:dim], 1)
  if prog
    b.fill_rect(222, y + 27, 78, 5, c[:dark]); b.fill_rect(222, y + 27, (78 * prog[0] / prog[1].to_f).round, 5, c[:selb])
    P.text(t, 170, y + 23, 46, 12, "#{prog[0]}/#{prog[1]}", c[:dim], PF::TINY, 1)
  elsif got
    P.text(t, 170, y + 23, 130, 12, "UNLOCKED", GREEN, PF::TINY, 1)
  end
end
id_box(b, t, c, "UNLOCKS", "12 of 40")
plate(b, c, 330, 100, 140, 150)
thumb = bmp(File.join(GFX, "Pictures/Trainer Card/backgrounds/CHARIZARD.png"))
t.stretch_blt(Rect.new(338, 108, 124, 93), thumb, Rect.new(0, 0, 512, 384))
b.fill_rect(338, 108, 124, 93, Color.new(0, 0, 0, 0))
lock(t, 394, 146, Color.new(240, 240, 248))
P.small(t, 336, 206, 128, 16, "Catch a Charizard", c[:txt], 2)
P.text(t, 336, 226, 128, 14, "BACKGROUND", c[:head], PF::TINY, 2)
badges(t, 72, 310, 3)
hints(c, [[:ud, "Select"], [A_BTN, "Use"], [B_BTN, "Close"]])
shot("TT_unlocks")
