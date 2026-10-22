# encoding: utf-8
# Mockups: Shop and Economy, Mart Events and Wanted (part 3), five designs,
# each two screens: the Mart Events page (every active sale and shortage;
# filters All / Sales / Shortages / Ending Soon) with the new Wanted list
# (Sale Alerts), and the overworld Sale Alert (the Weather alert's style).
# Design 1 = old KR's Mart Events page (L/R filters), rebuilt in our kit,
# with Wanted as one more filter.
# Usage (from this folder): ruby events_designs.rb "<KIF Beta>" <work dir with metrics.json>
SHSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "shop_designs.rb"), :encoding => "UTF-8")
eval(SHSRC.split("c = palette(2)\n")[0], binding, "shop_designs.rb")

SHORT = Color.new(240, 140, 90)
# [place, kind, pct, scope, scope icon, time left, ending soon, town map tile]
EVENTS = [["Cerulean City", :sale, 20, "Poké Balls", "POKEBALL", "2d 4h", false, [40, 6]],
          ["Celadon Dept. Store", :sale, 15, "Medicine", "HYPERPOTION", "1d 2h", false, [37, 9]],
          ["Lavender Town", :sale, 30, "Repels", "REPEL", "5h", true, [43, 9]],
          ["Saffron City", :short, 15, "Great Ball", "GREATBALL", "1d 8h", false, [39, 9]],
          ["Vermilion City", :short, 10, "Whole Shop", "ESCAPEROPE", "2d", false, [39, 11]]]
EV_SEL = 1
# [item, name, best now, where]
WANTED = [["HYPERPOTION", "Hyper Potion", "15% Off", "Celadon"], ["GREATBALL", "Great Ball", "+15%", "Saffron City"],
          ["MAXREPEL", "Max Repel", "", "No sale"]]
FILTERS = ["ALL", "SALES", "SHORTAGES", "ENDING SOON", "WANTED"]
def ev_pill(t, x, y, kind, pct, right = false)
  s = kind == :sale ? "#{pct}% OFF" : "+#{pct}%"
  kind == :sale ? P.pill(t, x, y, s, Color.new(24, 60, 40), SALE, right) : P.pill(t, x, y, s, Color.new(70, 34, 18), SHORT, right)
end
def filters(c, x, y, sel, list = FILTERS)
  b = BASE.bitmap; t = TOP.bitmap
  list.each_with_index do |f, i|
    w = P.width(PF::TINY, f) + 14
    UI.rbox(b, x, y, x + w, y + 17, 5, i == sel ? c[:sel] : c[:dark], i == sel ? c[:selb] : c[:line])
    P.text(t, x, y + 1, w, 16, f, i == sel ? c[:white] : c[:dim], PF::TINY, 2)
    x += w + 4
  end
end
def title_only(c, title)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
  P.text(t, 0, 2, W, 28, title, c[:title], PF::TITLE, 2)
end
def ow_bg(c); BASE.bitmap.clear; TOP.bitmap.clear; OVER.bitmap.clear; CUR.visible = false; MAPS.bitmap = Bitmap.new(File.join(HERE, "wx", "route24_clear.png")); end
def alert(c, x, y, w = 250)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + 44, 8, c[:panel], c[:line])
  item(t, "HYPERPOTION", x + 22, y + 22, 28)
  P.text(t, x + 42, y + 1, w - 48, 24, "Hyper Potion 15% Off", c[:txt], PF::TEXT)
  P.small(t, x + 42, y + 23, w - 48, 16, "Celadon Dept. Store, 1 Day", c[:dim])
end
def ev_detail(c, x, y, w)
  b = BASE.bitmap; t = TOP.bitmap
  e = EVENTS[EV_SEL]
  P.text(t, x, y, w, 22, e[0], c[:title], PF::ROW)
  ev_pill(t, x, y + 26, e[1], e[2])
  P.small(t, x + 70, y + 26, w - 70, 16, "#{e[3]}, #{e[5]} left", c[:txt])
  [["HYPERPOTION", "Hyper Potion", 1200, 1020, true], ["SUPERPOTION", "Super Potion", 700, 595, false], ["FULLHEAL", "Full Heal", 600, 510, false]].each_with_index do |(ic, n, p, s, want), k|
    yy = y + 48 + k * 20
    star(t, x, yy + 6, GOLD) if want
    item(t, ic, x + 20, yy + 9, 16)
    P.small(t, x + 32, yy + 1, 120, 16, n, c[:txt])
    strike(t, x + w - 130, yy - 1, 60, money(p), c[:dim]); P.text(t, x + w - 64, yy - 1, 64, 20, money(s), SALE, PF::TEXT, 1)
  end
end

c = palette(2)

#================================================================ EV1 Recommended: old KR's Mart Events page, rebuilt; Wanted as a filter
plain(c); b = BASE.bitmap; t = TOP.bitmap
title_only(c, "Mart Events")
filters(c, 10, 38, 0)
EVENTS.each_with_index do |(pl, k, pct, sc, ic, left, soon, _), i|
  y = 62 + i * 30
  cursor_at(6, y, W - 12, 29) if i == EV_SEL
  item(t, ic, 26, y + 14, 22)
  P.text(t, 44, y + 3, 200, 24, pl, c[:txt], PF::TEXT)
  P.small(t, 246, y + 7, 100, 16, sc, c[:dim])
  ev_pill(t, 350, y + 7, k, pct)
  P.small(t, 400, y + 7, 96, 16, left, soon ? GOLD : c[:dim], 1)
end
y0 = 222
b.fill_rect(0, y0, W, 137, c[:panel2]); b.fill_rect(0, y0, W, 1, c[:line])
ev_detail(c, 12, y0 + 6, 488)
P.small(t, 12, y0 + 116, 488, 16, "Events last 3 days. Each Mart rolls its own.", c[:dim])
hints(c, [[:ud, "Choose"], [:lr, "Filter"], [B_BTN, "Back"]])
shot("EV1_page")
ow_bg(c); alert(c, 8, 8)
shot("EV1_alert")

#================================================================ EV2: on the Town Map (like the Forecast)
MAPIMG2 = File.join(GFX, "Pictures/map/map.png")
plain(c); b = BASE.bitmap; t = TOP.bitmap
P.text(t, 0, 6, W, 24, "Mart Events", c[:title], PF::ROW, 2)
filters(c, 10, 10, 0, ["ALL", "SALES", "SHORTAGES"])
UI.rbox(b, 8, 36, 336, 354, 8, c[:panel], c[:line])
b.stretch_blt(Rect.new(10, 38, 324, 314), bmp(MAPIMG2), Rect.new(452, 0, 324, 314))
OFFS = { "Celadon Dept. Store" => [-14, -7, true], "Saffron City" => [6, -7, false] }
EVENTS.each do |pl, k, pct, sc, ic, left, soon, (tx, ty)|
  x = 10 + tx * 16 + 8 - 452; y = 38 + ty * 16 + 8
  dx, dy, right = OFFS[pl] || [-4, -7, false]
  lbl = k == :sale ? "-#{pct}%" : "+#{pct}%"
  k == :sale ? P.pill(t, x + dx, y + dy, lbl, Color.new(24, 60, 40), SALE, right) : P.pill(t, x + dx, y + dy, lbl, Color.new(70, 34, 18), SHORT, right)
end
UI.rbox(b, 344, 36, 504, 354, 8, c[:panel], c[:line])
e = EVENTS[EV_SEL]
P.text(t, 344, 42, 160, 24, "Celadon", c[:title], PF::ROW, 2)
P.small(t, 344, 64, 160, 16, "Dept. Store, 2F", c[:dim], 2)
ev_pill(t, 354, 88, e[1], e[2]); P.small(t, 408, 88, 90, 16, "#{e[5]} left", c[:txt], 1)
P.small(t, 354, 110, 140, 16, "All Medicine", c[:txt])
[["HYPERPOTION", "Hyper Potion", 1020, true], ["SUPERPOTION", "Super Potion", 595, false], ["FULLHEAL", "Full Heal", 510, false]].each_with_index do |(ic, n, s, want), k|
  yy = 134 + k * 34
  star(t, 348, yy + 6, GOLD) if want
  item(t, ic, 366, yy + 14, 20)
  P.small(t, 382, yy, 114, 16, n, c[:txt]); P.small(t, 382, yy + 15, 114, 16, money(s), SALE)
end
hints(c, [[:ud, ""], [:lr, "Move"], [X_BTN, "Filter"], [B_BTN, "Back"]])
shot("EV2_page")
ow_bg(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 96, 8, 416, 36, 8, c[:panel], c[:line])
item(t, "HYPERPOTION", 116, 22, 22)
P.text(t, 132, 9, 280, 24, "Hyper Potion 15% Off in Celadon", c[:txt], PF::TEXT, 2)
shot("EV2_alert")

#================================================================ EV3: Wanted first, events beside it
plain(c); b = BASE.bitmap; t = TOP.bitmap
title_only(c, "Mart Events")
UI.rbox(b, 8, 38, 244, 354, 8, c[:panel], GOLD)
P.text(t, 8, 42, 236, 22, "Wanted", GOLD, PF::ROW, 2)
WANTED.each_with_index do |(ic, n, best, where), i|
  y = 70 + i * 46
  cursor_at(12, y, 228, 44) if i == 0
  item(t, ic, 32, y + 22, 26)
  P.text(t, 52, y + 2, 180, 22, n, c[:txt], PF::TEXT)
  P.small(t, 52, y + 24, 180, 16, best.empty? ? where : "#{best}, #{where}", best.include?("Off") ? SALE : (best.empty? ? c[:dim] : SHORT))
end
P.small(t, 16, 330, 220, 16, "Y in a Mart stars an item.", c[:dim])
UI.rbox(b, 252, 38, 504, 354, 8, c[:panel], c[:line])
P.text(t, 252, 42, 252, 22, "Active Events", c[:title], PF::ROW, 2)
EVENTS.each_with_index do |(pl, k, pct, sc, ic, left, soon, _), i|
  y = 70 + i * 44
  item(t, ic, 272, y + 20, 22)
  P.small(t, 290, y + 2, 150, 16, pl, c[:txt]); P.small(t, 290, y + 20, 110, 16, sc, c[:dim])
  ev_pill(t, 494, y + 2, k, pct, true); P.small(t, 420, y + 20, 74, 16, left, soon ? GOLD : c[:dim], 1)
end
hints(c, [[:ud, "Choose"], [:lr, "Panels"], [Y_BTN, "Unstar"], [B_BTN, "Back"]])
shot("EV3_page")
ow_bg(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 8, 312, 260, 372, 8, c[:panel], GOLD)
item(t, "HYPERPOTION", 34, 342, 32)
P.text(t, 58, 316, 200, 24, "Wanted on Sale!", GOLD, PF::TEXT)
P.small(t, 58, 338, 200, 16, "Hyper Potion, Celadon", c[:txt])
shot("EV3_alert")

#================================================================ EV4: event cards with a countdown bar
plain(c); b = BASE.bitmap; t = TOP.bitmap
title_only(c, "Mart Events")
filters(c, 10, 38, 0)
EVENTS.first(4).each_with_index do |(pl, k, pct, sc, ic, left, soon, _), i|
  x = 8 + (i % 2) * 250; y = 62 + (i / 2) * 140
  UI.rbox(b, x, y, x + 244, y + 132, 8, c[:panel], k == :sale ? SALE : SHORT)
  cursor_at(x - 2, y - 2, 248, 136) if i == EV_SEL
  P.text(t, x + 10, y + 4, 224, 22, pl, c[:txt], PF::TEXT)
  ev_pill(t, x + 234, y + 30, k, pct, true)
  item(t, ic, x + 34, y + 58, 40)
  P.text(t, x + 66, y + 38, 170, 22, sc, c[:txt], PF::TEXT)
  P.small(t, x + 66, y + 60, 170, 16, k == :sale ? "Cheaper here" : "Pricier here", c[:dim])
  frac = { "2d 4h" => 0.72, "1d 2h" => 0.36, "5h" => 0.07, "1d 8h" => 0.44 }[left]
  b.fill_rect(x + 10, y + 100, 224, 6, c[:dark]); b.fill_rect(x + 10, y + 100, (224 * frac).round, 6, soon ? GOLD : c[:selb])
  P.small(t, x + 10, y + 108, 224, 16, "#{left} left", soon ? GOLD : c[:dim], 1)
end
hints(c, [[:ud, ""], [:lr, "Choose"], [X_BTN, "Filter"], [B_BTN, "Back"]])
shot("EV4_page")
ow_bg(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 324, 8, 504, 64, 8, c[:panel], SALE)
item(t, "HYPERPOTION", 414, 28, 30)
P.small(t, 324, 44, 180, 16, "Hyper Potion: 15% Off", SALE, 2)
shot("EV4_alert")

#================================================================ EV5: in the Overworld Menu's Info page
ow_bg(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 4, 4, 223, 296, 6, col(c[:panel], 235))
P.text(t, 4, 6, 220, 22, "Overworld Menu", c[:title], PF::ROW, 2)
["MAIN", "TOGGLES", "INFO"].each_with_index do |pg, i|
  tw = 204 / 3
  UI.rbox(b, 12 + i * tw + 1, 30, 12 + (i + 1) * tw - 2, 47, 4, i == 2 ? c[:sel] : col(c[:panel2], 230), i == 2 ? c[:selb] : nil)
  P.text(t, 12 + i * tw, 30, tw, 18, pg, i == 2 ? c[:white] : c[:dim], PF::TINY, 2)
end
[["Mart Events", "5"], ["Quest Tracker", ""], ["Encounters", "212"]].each_with_index do |(l, s), i|
  y = 52 + i * 26
  cursor_at(9, y, 210, 25) if i == 0
  item(t, ["POKEBALL", "TOWNMAP", "POKERADAR"][i], 24, y + 12, 18)
  P.text(t, 40, y, 120, 25, l, i == 0 ? c[:white] : c[:txt], PF::TEXT)
  P.text(t, 150, y, 60, 25, s, GREEN, PF::TEXT, 1) unless s.empty?
end
b.fill_rect(14, 134, 200, 1, c[:line])
EVENTS.first(4).each_with_index do |(pl, k, pct, sc, ic, left, soon, _), i|
  y = 140 + i * 36
  item(t, ic, 26, y + 14, 18)
  P.small(t, 40, y, 120, 16, pl.sub(" Dept. Store", ""), c[:txt]); P.small(t, 40, y + 16, 100, 16, sc, c[:dim])
  ev_pill(t, 216, y + 2, k, pct, true); P.small(t, 150, y + 16, 66, 16, left, soon ? GOLD : c[:dim], 1)
end
hints(c, [[:ud, "Choose"], [:lr, "Pages"], [A_BTN, "Open"], [B_BTN, "Close"]])
shot("EV5_page")
ow_bg(c); alert(c, 8, 8)
b = BASE.bitmap; t = TOP.bitmap
P.pill(t, 12, 56, "WANTED", Color.new(60, 48, 14), GOLD, false)
shot("EV5_alert")
