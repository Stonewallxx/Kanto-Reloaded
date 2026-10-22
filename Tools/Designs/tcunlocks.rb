# encoding: utf-8
# Mockups: Trainer Card, the Unlocks tab (five designs), in the locked style.
# His notes: Unlocks shows every category you can unlock things in, then the
# chosen category's entries with what each needs, your progress, and where it
# comes from. The categories match the Style groups: Backgrounds, Plate
# Colors, Titles, Showcase Frames, Badge Cases.
# Design 1 = the Style tab's icon strip (his pick), with the entries beside it.
# Usage (from this folder): ruby tcunlocks.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "tcdress.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "tcdress.rb")

CATS = [["Backgrounds", "TOWNMAP", 13, 110], ["Plate Colors", "SHINYCHARM", 3, 8], ["Titles", "AMULETCOIN", 4, 20],
        ["Showcase Frames", "OVALCHARM", 1, 6], ["Badge Cases", "EXPSHARE", 1, 3]]
# [name, background file, need, progress [have, of] or nil, state, source]
ENTRIES = [["Cascade Badge", "CASCADEBADGE", "Beat Misty", nil, :got, "Gyms"],
           ["Charizard", "CHARIZARD", "Catch a Charizard", nil, :locked, "Pokédex"],
           ["Eevee Flowers", "EEVEE_FLOWERS", "Hatch 25 Eggs", [9, 25], :locked, "Eggs"],
           ["Blastoise", "BLASTOISE", "Buy for $2,000", nil, :buy, "Poké Mart"],
           ["Bronze", "BRONZE", "Win 50 Battles", [42, 50], :locked, "Battles"],
           ["Cacti", "CACTI", "Find 10 Shinies", [2, 10], :locked, "Shinies"]]
SELE = 1
def state_mark(b, t, x, y, st)
  case st
  when :got then UI.rbox(b, x, y + 1, x + 12, y + 13, 6, pif("Green"))
  when :buy then UI.rbox(b, x, y + 1, x + 12, y + 13, 6, pif("Blue")); P.text(t, x, y, 12, 14, "$", Color.new(255, 255, 255), PF::TINY, 2)
  else lock(b, x, y - 1, Color.new(110, 116, 130))
  end
end
def entry_row(b, t, x, y, w, e, sel, h = 42)
  n, f, need, prog, st, src = e
  cursor_at(x - 4, y - 3, w + 8, h - 4) if sel
  state_mark(b, t, x, y + 4, st)
  stx(t, x + 18, y, w - 18, 20, n, st == :locked ? Color.new(110, 116, 130) : BLACK, PF::TEXT)
  ssm(t, x + 18, y + 18, w - 66, 16, need, BLACK)
  if st == :got
    P.text(t, x, y + 21, w, 12, "UNLOCKED", pif("Green"), PF::TINY, 1)
  elsif prog
    P.text(t, x, y + 21, w, 12, "#{prog[0]}/#{prog[1]}", BLACK, PF::TINY, 1)
    b.fill_rect(x + 18, y + h - 8, w - 18, 3, Color.new(255, 255, 255, 150)); b.fill_rect(x + 18, y + h - 8, ((w - 18) * prog[0] / prog[1].to_f).round, 3, pif("Blue"))
  end
end
def detail(b, t, x, y, w, e)
  n, f, need, prog, st, src = e
  glass(b, x, y, w, 176, 10)
  stx(t, x, y + 6, w, 12, "BACKGROUND", BLACK, PF::TINY, 2)
  tw = w - 24; th = tw * 3 / 4
  thumb(t, f, x + 12, y + 22, tw, th)
  UI.rbox(t, x + 12, y + 22, x + 12 + tw, y + 22 + th, 4, Color.new(0, 0, 0, 90)) if st == :locked
  lock(t, x + w / 2 - 6, y + 22 + th / 2 - 8, Color.new(255, 255, 255)) if st == :locked
  stx(t, x, y + 26 + th, w, 20, n, BLACK, PF::TEXT, 2)
  ssm(t, x, y + 46 + th, w, 16, "#{need}", BLACK, 2)
  ssm(t, x, y + 62 + th, w, 16, "From: #{src}", pif("Blue"), 2)
end
HU = [[:ud, "Choose"], [:lr, "Category"], [A_BTN, "Use"], [B_BTN, "Close"]]

c = palette(2)

#================================================================ TU1 Recommended: the Style icon strip, the entries beside it
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 4)
glass(b, 36, 48, 64, 300, 10)
CATS.each_with_index do |(n, ic, have, all), i|
  y = 54 + i * 48
  UI.rbox(b, 42, y, 94, y + 44, 8, i == 0 ? Color.new(40, 96, 176, 220) : Color.new(255, 255, 255, 120))
  icon(t, ic, 68, y + 15, 22)
  P.text(t, 42, y + 30, 52, 12, "#{have}/#{all}", i == 0 ? Color.new(255, 255, 255) : BLACK, PF::TINY, 2)
end
glass(b, 108, 48, 200, 300, 10)
stx(t, 118, 54, 180, 12, "BACKGROUNDS · 13 OF 110", BLACK, PF::TINY)
ENTRIES.each_with_index { |e, i| entry_row(b, t, 118, 72 + i * 44, 180, e, i == SELE) }
detail(b, t, 318, 48, 168, ENTRIES[SELE])
hints(c, HU)
shot("TU1")

#================================================================ TU2 The Card's Back: categories on the card, the entries beside it
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 4)
card_back(b, t, "Unlocks")
CATS.each_with_index do |(n, ic, have, all), i|
  y = 114 + i * 44
  UI.rbox(b, 50, y - 4, 222, y + 36, 6, Color.new(40, 96, 176, 210)) if i == 0
  icon(t, ic, 64, y + 10, 18)
  i == 0 ? P.small(t, 78, y + 2, 140, 16, n, Color.new(255, 255, 255)) : ssm(t, 78, y + 2, 140, 16, n, BLACK)
  b.fill_rect(78, y + 24, 96, 4, Color.new(255, 255, 255, 150)); b.fill_rect(78, y + 24, [(96 * have / all.to_f).round, 2].max, 4, i == 0 ? Color.new(255, 255, 255) : pif("Blue"))
  P.text(t, 176, y + 20, 40, 12, "#{have}/#{all}", i == 0 ? Color.new(255, 255, 255) : BLACK, PF::TINY, 1)
end
glass(b, 240, 48, 246, 300, 10)
ENTRIES.first(4).each_with_index { |e, i| entry_row(b, t, 250, 58 + i * 40, 226, e, i == SELE, 40) }
glass(b, 250, 222, 226, 118, 8, 120)
thumb(t, "CHARIZARD", 258, 230, 100, 75); UI.rbox(t, 258, 230, 358, 305, 4, Color.new(0, 0, 0, 90)); lock(t, 302, 260, Color.new(255, 255, 255))
stx(t, 366, 232, 106, 20, "Charizard", BLACK, PF::TEXT)
ssm(t, 366, 254, 106, 16, "Catch a", BLACK); ssm(t, 366, 270, 106, 16, "Charizard", BLACK)
ssm(t, 366, 290, 106, 16, "From: Pokédex", pif("Blue"))
hints(c, HU)
shot("TU2")

#================================================================ TU3 Gallery: category tabs over a grid of entries
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 4)
glass(b, 36, 48, 450, 300, 10)
x = 46
CATS.each_with_index do |(n, ic, have, all), i|
  label = i == 0 ? "#{n} #{have}/#{all}".upcase : "#{have}/#{all}"
  w = P.width(PF::TINY, label) + 28
  UI.rbox(b, x, 56, x + w, 74, 6, i == 0 ? Color.new(40, 96, 176) : Color.new(255, 255, 255, 140))
  icon(t, ic, x + 11, 65, 14)
  P.text(t, x + 20, 57, w - 22, 16, label, i == 0 ? Color.new(255, 255, 255) : BLACK, PF::TINY, 2)
  x += w + 4
end
ENTRIES.each_with_index do |e, i|
  n, f, need, prog, st, src = e
  gx = 50 + (i % 3) * 146; gy = 84 + (i / 3) * 116
  cursor_at(gx - 3, gy - 3, 140, 110) if i == SELE
  thumb(t, f, gx, gy, 134, 70)
  UI.rbox(t, gx, gy, gx + 134, gy + 70, 4, Color.new(0, 0, 0, 90)) if st == :locked
  lock(t, gx + 61, gy + 27, Color.new(255, 255, 255)) if st == :locked
  P.pill(t, gx + 132, gy + 2, "$2,000", pif("Blue"), Color.new(255, 255, 255), true) if st == :buy
  P.pill(t, gx + 132, gy + 2, "UNLOCKED", pif("Green"), Color.new(255, 255, 255), true) if st == :got
  P.pill(t, gx + 2, gy + 2, "#{prog[0]}/#{prog[1]}", Color.new(20, 24, 36), Color.new(255, 255, 255), false) if prog
  stx(t, gx, gy + 72, 134, 16, n, BLACK, PF::TEXT, 2)
  ssm(t, gx, gy + 89, 134, 16, need, BLACK, 2)
end
hints(c, [[:lr, "Choose"], [:ud, "Row"], [A_BTN, "Use"], [B_BTN, "Close"]])
shot("TU3")

#================================================================ TU4 Collection Book: categories with completion rings on the left page
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 4)
glass(b, 36, 48, 450, 300, 10)
b.fill_rect(260, 56, 2, 284, Color.new(255, 255, 255, 220))
stx(t, 46, 54, 200, 12, "COLLECTION · 22 OF 147", BLACK, PF::TINY)
CATS.each_with_index do |(n, ic, have, all), i|
  cx = 80 + (i % 2) * 110; cy = 110 + (i / 2) * 90
  ring(b, cx, cy, 30, 5, (100 * have / all.to_f).round, pif("Blue"))
  icon(t, ic, cx, cy - 6, 20)
  P.text(t, cx - 30, cy + 6, 60, 12, "#{have}/#{all}", BLACK, PF::TINY, 2)
  i == 0 ? UI.rbox(b, cx - 52, cy + 34, cx + 52, cy + 52, 6, Color.new(40, 96, 176, 220)) : nil
  i == 0 ? P.small(t, cx - 52, cy + 35, 104, 16, n, Color.new(255, 255, 255), 2) : ssm(t, cx - 52, cy + 35, 104, 16, n, BLACK, 2)
end
ENTRIES.first(5).each_with_index { |e, i| entry_row(b, t, 274, 60 + i * 44, 202, e, i == SELE) }
stx(t, 274, 286, 202, 12, "SELECTED", BLACK, PF::TINY)
ssm(t, 274, 300, 202, 16, "Charizard: Catch a Charizard", BLACK)
ssm(t, 274, 318, 202, 16, "From: Pokédex", pif("Blue"))
hints(c, HU)
shot("TU4")

#================================================================ TU5 Next Up: the unlocks you're closest to, across every category
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 4)
glass(b, 36, 48, 280, 300, 10)
stx(t, 46, 54, 200, 12, "CLOSEST TO UNLOCKING", BLACK, PF::TINY)
near = [["Bronze", "Background", "Win 50 Battles", 42, 50, "TOWNMAP"], ["Gold Plates", "Plate Color", "Find 10 Shinies", 2, 10, "SHINYCHARM"],
        ["Ace Trainer", "Title", "Win 100 Battles", 87, 100, "AMULETCOIN"], ["Eevee Flowers", "Background", "Hatch 25 Eggs", 9, 25, "TOWNMAP"],
        ["Star Frame", "Showcase Frame", "Catch 100", 96, 100, "OVALCHARM"]].sort_by { |e| -e[3] / e[4].to_f }
near.each_with_index do |(n, kind, need, have, of, ic), i|
  y = 70 + i * 54
  cursor_at(42, y - 3, 268, 50) if i == 0
  icon(t, ic, 58, y + 14, 20)
  stx(t, 74, y, 170, 20, n, BLACK, PF::TEXT)
  P.text(t, 74, y, 228, 12, "#{have}/#{of}", BLACK, PF::TINY, 1)
  P.text(t, 74, y + 21, 120, 12, kind.upcase, BLACK, PF::TINY)
  ssm(t, 150, y + 18, 152, 16, need, BLACK, 1)
  b.fill_rect(74, y + 38, 228, 3, Color.new(255, 255, 255, 150)); b.fill_rect(74, y + 38, (228 * have / of.to_f).round, 3, pif("Blue"))
end
glass(b, 326, 48, 160, 300, 10)
stx(t, 326, 54, 160, 12, "CATEGORIES", BLACK, PF::TINY, 2)
CATS.each_with_index do |(n, ic, have, all), i|
  y = 72 + i * 52
  icon(t, ic, 344, y + 12, 20)
  ssm(t, 358, y + 2, 124, 16, n, BLACK)
  b.fill_rect(358, y + 24, 84, 4, Color.new(255, 255, 255, 150)); b.fill_rect(358, y + 24, [(84 * have / all.to_f).round, 2].max, 4, pif("Blue"))
  P.text(t, 444, y + 20, 38, 12, "#{have}/#{all}", BLACK, PF::TINY, 1)
end
hints(c, [[:ud, "Choose"], [:lr, "Next Up / Categories"], [B_BTN, "Close"]])
shot("TU5")
