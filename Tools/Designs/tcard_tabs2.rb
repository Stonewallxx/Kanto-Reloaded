# encoding: utf-8
# Mockups: the Trainer Card redesign (topic 17), every tab, second pass. Per his
# notes: no PIF frame, row plates or badge strip any more, only the background
# art (PIF's 110 backgrounds, Charizard here) with new KR panels in the KR Theme
# on top; the Unlocks tab lists every category you can unlock things in, then
# the entries of the chosen category.
# Layout: tabs along the top; the content panel on the left; your trainer
# standing on the art at the right with the tab's key number under it.
# Usage (from this folder): ruby tcard_tabs2.rb "<KIF Beta>" <work dir with metrics.json>
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
def panel(b, c, x, y, w, h, a = 228); UI.rbox(b, x, y, x + w, y + h, 8, col(c[:panel], a), c[:line]); end
def tabs(b, t, c, on)
  widths = TABS.map { |p| P.width(PF::TEXT, p) + 18 }
  x = (W - widths.sum - 4 * (TABS.length - 1)) / 2
  TABS.each_with_index do |p, i|
    sel = i == on
    UI.rbox(b, x, 8, x + widths[i], 28, 6, sel ? c[:sel] : col(c[:panel], 225), sel ? c[:selb] : c[:line])
    P.text(t, x, 8, widths[i], 20, p, sel ? c[:white] : c[:dim], PF::TEXT, 2)
    x += widths[i] + 4
  end
end
def kv(t, c, x, y, w, label, value, vc = nil)
  P.text(t, x, y, 170, 22, label, c[:dim], PF::TEXT)
  P.text(t, x, y, w, 22, value, vc || c[:txt], PF::TEXT, 1)
end
def rows(b, t, c, x, y, w, list, step = 26)
  list.each_with_index do |(l, v, vc), i|
    kv(t, c, x, y + i * step, w, l, v, vc)
    b.fill_rect(x, y + i * step + step - 3, w, 1, c[:line]) if i < list.length - 1
  end
end
def key_tile(b, t, c, label, value, vc = nil)
  panel(b, c, 320, 262, 184, 70)
  P.text(t, 320, 270, 184, 14, label.upcase, c[:head], PF::TINY, 2)
  P.text(t, 320, 286, 184, 32, value, vc || c[:title], PF::TITLE, 2)
end
def badge_case(b, t, c, x, y, n)
  i = bmp(File.join(GFX, "Pictures/Trainer Card/icon_badges.png"))
  8.times do |k|
    bx = x + k * 31
    UI.rbox(b, bx, y, bx + 28, y + 28, 6, c[:dark], c[:line])
    t.stretch_blt(Rect.new(bx + 1, y + 1, 26, 26), i, Rect.new(k * 32, 0, 32, 32)) if k < n
  end
end
def lock(b, x, y, color)
  UI.rbox(b, x + 2, y, x + 10, y + 7, 3, color); UI.rbox(b, x + 4, y + 2, x + 8, y + 7, 1, Color.new(0, 0, 0, 0))
  UI.rbox(b, x, y + 6, x + 12, y + 15, 2, color)
end
def card(c, on, art = "tcbg_charizard.png", trainer = true)
  frame(c)
  backdrop(art)
  tabs(BASE.bitmap, TOP.bitmap, c, on)
  red(TOP.bitmap, 412, 258, 168) if trainer
end
HINTS_CARD = [[:lr, "Tabs"], [A_BTN, "Actions"], [B_BTN, "Close"]]
def shot(name); dump_as(name); end

c = palette(2)

#================================================================ Front
card(c, 0)
b = BASE.bitmap; t = TOP.bitmap
panel(b, c, 8, 36, 300, 296)
P.text(t, 20, 40, 200, 30, "Red", c[:title], PF::TITLE)
P.text(t, 20, 70, 200, 12, "ACE TRAINER", GOLD, PF::TINY)
P.text(t, 20, 44, 276, 14, "ID 04821", c[:head], PF::TINY, 1)
b.fill_rect(20, 88, 276, 1, c[:line])
rows(b, t, c, 20, 94, 276, [["Money", "$12,450"], ["Pokédex", "88/140"], ["Time", "24h 13m"], ["Started", "Oct 12, 2026"]])
P.text(t, 20, 200, 200, 12, "SHOWCASE", c[:head], PF::TINY)
SHOW.each_with_index do |sp, i|
  x = 20 + i * 62
  UI.rbox(b, x, 214, x + 56, 262, 8, c[:dark], c[:line])
  mon(t, sp, x + 28, 238, 48)
end
P.text(t, 20, 270, 200, 12, "BADGES 3/8", c[:head], PF::TINY)
badge_case(b, t, c, 20, 286, 3)
hints(c, HINTS_CARD)
shot("TN_front")

#================================================================ Records
card(c, 1)
b = BASE.bitmap; t = TOP.bitmap
panel(b, c, 8, 36, 300, 296)
P.text(t, 20, 42, 200, 14, "RECORDS", c[:head], PF::TINY)
rows(b, t, c, 20, 60, 276, [["Wins", "42", GREEN], ["Losses", "7", RED], ["Battles", "49"], ["Best Streak", "12", GOLD],
                            ["Current Streak", "3"], ["Pink Slips Won", "5"], ["Gym Rematches", "9"]], 30)
P.small(t, 20, 280, 276, 16, "A: Open Battle Records", c[:dim])
key_tile(b, t, c, "Win Rate", "86%")
hints(c, HINTS_CARD)
shot("TN_records")

#================================================================ Stats
card(c, 2)
b = BASE.bitmap; t = TOP.bitmap
panel(b, c, 8, 36, 300, 296)
P.text(t, 20, 42, 200, 14, "STATS", c[:head], PF::TINY)
rows(b, t, c, 20, 60, 276, [["Steps", "48,210"], ["Caught", "96"], ["Fusions Made", "14"], ["Eggs Hatched", "9"],
                            ["Shinies Found", "2"], ["Trades", "3"], ["Hall of Fame", "0"]], 30)
key_tile(b, t, c, "Battles Won", "87")
hints(c, HINTS_CARD)
shot("TN_stats")

#================================================================ Style (previewing a background live)
card(c, 3, "tcbg_eevee_flowers.png")
b = BASE.bitmap; t = TOP.bitmap
panel(b, c, 8, 36, 300, 296)
P.text(t, 20, 42, 200, 14, "STYLE", c[:head], PF::TINY)
style = [["Background", "Eevee Flowers", :value], ["Panels", "Theme", :value], ["Title", "Ace Trainer", :value],
         ["Showcase", "EDIT", :tool], ["Glimmer Coins", "1,250", :info], ["Clothes / Hats", "12/30", :info]]
style.each_with_index do |(l, v, k), i|
  y = 60 + i * 34
  cursor_at(12, y - 3, 292, 28) if i == 0
  P.text(t, 20, y, 140, 22, l, c[:dim], PF::TEXT)
  case k
  when :value
    vw = P.width(PF::TEXT, v); cx = 222
    P.text(t, cx - vw / 2, y, vw + 2, 22, v, c[:txt], PF::TEXT)
    UI.tri(t, cx - vw / 2 - 13, y + 7, :l, c[:txt], 4); UI.tri(t, cx + vw / 2 + 5, y + 7, :r, c[:txt], 4)
  when :tool then P.pill(t, 296, y + 4, v, c[:pill], c[:txt])
  else P.text(t, 20, y, 276, 22, v, c[:txt], PF::TEXT, 1)
  end
end
P.small(t, 20, 268, 276, 16, "Previewing on the card. A: Keep.", c[:dim])
P.small(t, 20, 286, 276, 16, "Locked ones show what unlocks them.", c[:dim])
key_tile(b, t, c, "Backgrounds", "13/110")
hints(c, [[:ud, "Select"], [:lr, "Change"], [A_BTN, "Keep"], [B_BTN, "Close"]])
shot("TN_style")

#================================================================ Unlocks: every category, then its entries
card(c, 4, "tcbg_charizard.png", false)
b = BASE.bitmap; t = TOP.bitmap
CATS = [["Backgrounds", 13, 110], ["Titles", 3, 20], ["Panel Styles", 1, 4], ["Showcase Frames", 0, 6], ["Badge Cases", 1, 3]]
panel(b, c, 8, 36, 176, 296)
P.text(t, 20, 42, 160, 14, "CATEGORIES", c[:head], PF::TINY)
CATS.each_with_index do |(n, have, all), i|
  y = 60 + i * 46
  UI.rbox(b, 12, y - 3, 180, y + 37, 6, c[:sel], c[:selb]) if i == 0
  P.text(t, 20, y, 150, 20, n, c[:txt], PF::TEXT)
  b.fill_rect(20, y + 26, 110, 5, c[:dark]); b.fill_rect(20, y + 26, [(110 * have / all.to_f).round, 2].max, 5, c[:selb])
  P.text(t, 132, y + 20, 44, 14, "#{have}/#{all}", c[:dim], PF::TINY, 1)
end
panel(b, c, 190, 36, 314, 296)
P.text(t, 202, 42, 200, 14, "BACKGROUNDS", c[:head], PF::TINY)
thumb = bmp(File.join(GFX, "Pictures/Trainer Card/backgrounds/CHARIZARD.png"))
t.stretch_blt(Rect.new(386, 46, 108, 81), thumb, Rect.new(0, 0, 512, 384))
lock(t, 434, 79, Color.new(240, 240, 248))
ENTRIES_U = [["Cascade Badge", "Beat Misty", nil, true], ["Charizard", "Catch a Charizard", nil, false],
             ["Eevee Flowers", "Hatch 25 eggs", [25, 25], true], ["Gold Card", "Become Champion", nil, false],
             ["Shiny Sparkle", "Find 10 shinies", [2, 10], false], ["Blue", "Poké Mart, $2,000", nil, true]]
ENTRIES_U.each_with_index do |(n, need, prog, got), i|
  y = 134 + i * 32
  cursor_at(194, y - 2, 306, 30) if i == 1
  if got
    UI.rbox(b, 202, y + 6, 214, y + 18, 6, GREEN)
  else
    lock(b, 202, y + 4, c[:dim])
  end
  P.text(t, 222, y, 150, 22, n, got ? c[:txt] : c[:dim], PF::TEXT)
  P.small(t, 330, y + 2, 166, 16, need, c[:dim], 1)
  if prog && !got
    b.fill_rect(430, y + 21, 66, 4, c[:dark]); b.fill_rect(430, y + 21, (66 * prog[0] / prog[1].to_f).round, 4, c[:selb])
  end
end
P.text(t, 202, 52, 180, 22, "Charizard", c[:txt], PF::ROW)
P.small(t, 202, 76, 180, 16, "Catch a Charizard.", c[:dim])
P.small(t, 202, 94, 180, 16, "From: Pokédex", c[:head])
hints(c, [[:ud, "Select"], [:lr, "Category / List"], [A_BTN, "Use"], [B_BTN, "Close"]])
shot("TN_unlocks")
