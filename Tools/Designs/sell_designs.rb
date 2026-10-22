# encoding: utf-8
# Mockups: Shop and Economy, the Sell screen (part 2), five designs, each two
# screens: selling from the Bag's pockets at Cerulean's Mart, then the new
# Sell Valuables total (every pure-money item at once; favourites are kept).
# Items pocket, PIF's sell prices (half the buy price): Nugget x2 5,000,
# Big Pearl 3,750, Star Piece 4,900 (a favourite: kept), Stardust x4 1,000,
# Pearl x3 700, Big Mushroom 2,500, Tiny Mushroom x5 250 -> 23,600.
# Design 1 = the chosen Buy screen's layout (the Bag's), selling.
# Usage (from this folder): ruby sell_designs.rb "<KIF Beta>" <work dir with metrics.json>
SHSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "shop_designs.rb"), :encoding => "UTF-8")
eval(SHSRC.split("c = palette(2)\n")[0], binding, "shop_designs.rb")

# [item, name, qty, sell each, valuable, favourite]
ITEMS = [["NUGGET", "Nugget", 2, 5000, true, false], ["STARPIECE", "Star Piece", 1, 4900, true, true],
         ["BIGPEARL", "Big Pearl", 1, 3750, true, false], ["BIGMUSHROOM", "Big Mushroom", 1, 2500, true, false],
         ["STARDUST", "Stardust", 4, 1000, true, false], ["PEARL", "Pearl", 3, 700, true, false],
         ["TINYMUSHROOM", "Tiny Mushroom", 5, 250, true, false], ["FIRESTONE", "Fire Stone", 1, 1500, false, false],
         ["ESCAPEROPE", "Escape Rope", 2, 275, false, false], ["REPEL", "Repel", 6, 175, false, false]]
VAL = ITEMS.select { |x| x[4] && !x[5] }
VAL_TOTAL = VAL.sum { |x| x[2] * x[3] }
POCKETS8 = ["Items", "Medicine", "Poké Balls", "TMs & HMs", "Berries", "Mail", "Battle Items", "Key Items"]
def sell_bar(c, title)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
  P.text(t, 0, 2, W, 28, title, c[:title], PF::TITLE, 2)
  UI.rbox(b, 8, 4, 120, 27, 5, c[:dark], c[:line]); P.text(t, 8, 4, 112, 23, "Sort: Price", c[:dim], PF::TEXT, 2)
  BI.draw(t, 126, 8, "p:9", c, $style)
  UI.rbox(b, W - 156, 4, W - 8, 27, 5, Color.new(60, 48, 14), GOLD); P.text(t, W - 156, 4, 148, 23, "Sell Valuables", GOLD, PF::TEXT, 2)
  BI.draw(t, W - 162 - BI.width("p:10", $style), 8, "p:10", c, $style)
end
def pocket_bar(c, y, label)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, y, W, 26, c[:panel]); b.fill_rect(0, y + 25, W, 1, c[:line])
  POCKETS8.each_with_index { |_, i| pocket_icon(t, i, 24 + i * 26, y + 13, i == 0 ? 22 : 16) }
  P.text(t, 234, y + 1, 158, 24, label, c[:txt], PF::TEXT, 1)
  UI.tri(t, 226, y + 9, :l, c[:dim], 4); UI.tri(t, 394, y + 9, :r, c[:dim], 4)
end
def val_badge(t, x, y); P.pill(t, x, y, "VALUABLE", Color.new(60, 48, 14), GOLD, false); end
def sell_row(c, t, x, y, w, it, sel, h = 22)
  ic, n, q, p, v, fav = it
  cursor_at(x - 2, y, w + 4, h - 1) if sel
  star(t, x + 2, y + 7, GOLD) if fav
  item(t, ic, x + 22, y + h / 2, 18)
  P.text(t, x + 38, y, 140, h - 1, n, c[:txt], PF::TEXT)
  P.text(t, x + 170, y, 40, h - 1, "x#{q}", c[:dim], PF::TEXT)
  P.text(t, x + w - 90, y, 90, h - 1, money(p), v ? GOLD : c[:txt], PF::TEXT, 1)
end
# The Sell Valuables panel (on OVER)
def valuables_panel(c, x, y, w = 300)
  d = OVER.bitmap
  rows = VAL
  h = 74 + rows.length * 18 + 56
  UI.rbox(d, x, y, x + w, y + h, 8, col(c[:panel], 255), GOLD)
  P.text(d, x, y + 6, w, 22, "Sell Valuables", GOLD, PF::ROW, 2)
  d.fill_rect(x + 10, y + 32, w - 20, 1, c[:line])
  rows.each_with_index do |(ic, n, q, p, _, _), k|
    yy = y + 38 + k * 18
    item(d, ic, x + 22, yy + 8, 14)
    P.small(d, x + 34, yy, 120, 16, n, c[:txt]); P.small(d, x + 150, yy, 40, 16, "x#{q}", c[:dim])
    P.small(d, x + w - 90, yy, 76, 16, money(q * p), c[:txt], 1)
  end
  yy = y + 42 + rows.length * 18
  d.fill_rect(x + 10, yy, w - 20, 1, c[:line])
  star(d, x + 14, yy + 9, GOLD); P.small(d, x + 26, yy + 4, 200, 16, "Star Piece kept (Favourite)", c[:dim])
  P.small(d, x + 14, yy + 22, 80, 16, "Total", c[:dim]); P.text(d, x + w - 110, yy + 20, 96, 22, money(VAL_TOTAL), GREEN, PF::TEXT, 1)
  [["Sell All", true, x + 16], ["Cancel", false, x + w / 2 + 6]].each do |lbl, on, bx|
    UI.rbox(d, bx, yy + 46, bx + w / 2 - 22, yy + 70, 6, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
    P.text(d, bx, yy + 47, w / 2 - 22, 22, lbl, on ? c[:white] : c[:txt], PF::TEXT, 2)
  end
end
H_SELL = [[:ud, "Choose"], [:lr, "Pockets"], [A_BTN, "Sell"], [Y_BTN, "Favourite"], [B_BTN, "Back"]]

c = palette(2)

#================================================================ SL1 Recommended: the Buy screen's (the Bag's) layout, selling
def sl1(c)
  plain(c); b = BASE.bitmap; t = TOP.bitmap
  sell_bar(c, "Sell")
  pocket_bar(c, 32, "Items  1/8")
  money_box(c, W - 104, 34)
  ITEMS.first(8).each_with_index { |it, i| sell_row(c, t, 8, 62 + i * 22, W - 16, it, i == 0) }
  y0 = 240
  b.fill_rect(0, y0, W, 119, c[:panel2]); b.fill_rect(0, y0, W, 1, c[:line])
  P.text(t, 12, y0 + 4, 300, 22, "Nugget", c[:title], PF::ROW)
  P.small(t, 12, y0 + 28, 380, 16, "A nugget of pure gold. It can be sold at a high price.", c[:txt])
  P.small(t, 12, y0 + 52, 300, 16, "Sells for #{money(5000)} each, #{money(10000)} for both.", GREEN)
  UI.rbox(b, W - 96, y0 + 8, W - 10, y0 + 70, 6, c[:dark], c[:line])
  item(t, "NUGGET", W - 53, y0 + 39, 48)
  hints(c, H_SELL)
end
sl1(c); shot("SL1_sell")
sl1(c); OVER.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120)); valuables_panel(c, 106, 40); shot("SL1_valuables")

#================================================================ SL2: valuables pinned at the top with their total
plain(c); b = BASE.bitmap; t = TOP.bitmap
sell_bar(c, "Sell")
pocket_bar(c, 32, "Items  1/8")
money_box(c, W - 104, 34)
UI.rbox(b, 6, 62, W - 6, 88, 6, Color.new(60, 48, 14), GOLD)
P.text(t, 14, 63, 200, 24, "Valuables: 6 Items", GOLD, PF::TEXT)
P.text(t, 220, 63, 150, 24, money(VAL_TOTAL), GREEN, PF::TEXT, 1)
P.pill(t, W - 14, 68, "RB SELL ALL", Color.new(80, 60, 10), GOLD, true)
ITEMS.first(7).each_with_index { |it, i| sell_row(c, t, 8, 94 + i * 22, W - 16, it, i == 0) }
y0 = 256
b.fill_rect(0, y0, W, 103, c[:panel2]); b.fill_rect(0, y0, W, 1, c[:line])
item(t, "NUGGET", 36, y0 + 30, 40)
P.text(t, 66, y0 + 6, 300, 22, "Nugget", c[:title], PF::ROW)
P.small(t, 66, y0 + 30, 400, 16, "Sells for #{money(5000)} each, #{money(10000)} for both.", GREEN)
hints(c, H_SELL)
shot("SL2_sell")
OVER.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120)); valuables_panel(c, 106, 40); shot("SL2_valuables")

#================================================================ SL3: a sell basket (pick several, sell once)
def basket(c, x, y, w, rows, total)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, 354, 6, c[:panel2], GOLD)
  P.text(t, x, y + 4, w, 22, "To Sell", c[:title], PF::ROW, 2)
  rows.each_with_index do |(ic, n, q, p), i|
    yy = y + 32 + i * 30
    item(t, ic, x + 18, yy + 13, 20)
    P.small(t, x + 34, yy, w - 42, 16, n, c[:txt])
    P.small(t, x + 34, yy + 14, 40, 16, "x#{q}", c[:dim]); P.small(t, x + 74, yy + 14, w - 82, 16, money(q * p), c[:txt], 1)
  end
  b.fill_rect(x + 8, 280, w - 16, 1, c[:line])
  P.small(t, x + 10, 286, 60, 16, "Total", c[:dim]); P.text(t, x + w - 90, 284, 80, 20, money(total), GREEN, PF::TEXT, 1)
  UI.rbox(b, x + 10, 320, x + w - 10, 346, 6, c[:sel], c[:selb])
  P.text(t, x + 10, 322, w - 20, 22, "Sell (X)", c[:white], PF::TEXT, 2)
end
plain(c); b = BASE.bitmap; t = TOP.bitmap
sell_bar(c, "Sell")
pocket_bar(c, 32, "Items")
ITEMS.first(10).each_with_index do |it, i|
  ic, n, q, p, v, fav = it
  y = 62 + i * 26
  cursor_at(6, y, 326, 25) if i == 0
  star(t, 10, y + 9, GOLD) if fav
  item(t, ic, 30, y + 12, 18)
  P.text(t, 46, y + 1, 140, 24, n, c[:txt], PF::TEXT)
  P.text(t, 180, y + 1, 40, 24, "x#{q}", c[:dim], PF::TEXT)
  P.text(t, 230, y + 1, 96, 24, money(p), v ? GOLD : c[:txt], PF::TEXT, 1)
end
basket(c, 340, 62, 164, [["NUGGET", "Nugget", 2, 5000], ["BIGPEARL", "Big Pearl", 1, 3750]], 13750)
hints(c, [[:ud, "Choose"], [A_BTN, "Add"], [X_BTN, "Sell"], [Y_BTN, "Favourite"], [B_BTN, "Back"]])
shot("SL3_sell")
OVER.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120)); valuables_panel(c, 106, 40); shot("SL3_valuables")

#================================================================ SL4: the Bag itself in Sell mode (Search, pockets, the same info panel)
plain(c); b = BASE.bitmap; t = TOP.bitmap
title_bar(c, "Bag: Sell")
pocket_bar(c, 32, "Items  1/8")
UI.rbox(b, W - 104, 34, W - 8, 56, 5, c[:dark], c[:line]); P.text(t, W - 104, 35, 96, 20, money(41200), GREEN, PF::TEXT, 2)
ITEMS.first(8).each_with_index do |it, i|
  ic, n, q, p, v, fav = it
  y = 62 + i * 22
  cursor_at(6, y, W - 12, 21) if i == 0
  star(t, 12, y + 7, GOLD) if fav
  P.text(t, 24, y, 160, 21, n, c[:txt], PF::TEXT)
  P.text(t, 190, y, 40, 21, "x#{q}", c[:dim], PF::TEXT)
  P.text(t, W - 110, y, 96, 21, money(p), v ? GOLD : c[:txt], PF::TEXT, 1)
end
y0 = 240
b.fill_rect(0, y0, W, 119, c[:panel2]); b.fill_rect(0, y0, W, 1, c[:line])
UI.rbox(b, W - 96, y0 + 8, W - 10, y0 + 70, 6, c[:dark], c[:line])
item(t, "NUGGET", W - 53, y0 + 39, 48)
P.text(t, 12, y0 + 4, 300, 22, "Nugget", c[:title], PF::ROW)
P.small(t, 12, y0 + 28, 380, 16, "A nugget of pure gold. It can be sold at a high price.", c[:txt])
P.small(t, 12, y0 + 52, 380, 16, "Sells for #{money(5000)} each.", GREEN)
P.pill(t, 12, y0 + 78, "VALUABLE", Color.new(60, 48, 14), GOLD, false)
hints(c, [[:ud, "Choose"], [:lr, "Pockets"], [A_BTN, "Sell"], [X_BTN, "Sell Valuables"], [B_BTN, "Back"]])
shot("SL4_sell")
OVER.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120)); valuables_panel(c, 106, 40); shot("SL4_valuables")

#================================================================ SL5: at the counter, a panel beside the clerk
over_map(c, "mart.png")
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 236, 8, 504, 352, 8, col(c[:panel], 250), c[:line])
P.text(t, 236, 12, 268, 24, "Sell", c[:title], PF::ROW, 2)
POCKETS8.each_with_index { |_, i| pocket_icon(t, i, 256 + i * 30, 50, i == 0 ? 22 : 16) }
ITEMS.first(9).each_with_index do |it, i|
  ic, n, q, p, v, fav = it
  y = 66 + i * 26
  cursor_at(242, y, 256, 25) if i == 0
  star(t, 246, y + 9, GOLD) if fav
  item(t, ic, 266, y + 12, 18)
  P.text(t, 280, y + 1, 120, 24, n, c[:txt], PF::TEXT)
  P.text(t, 400, y + 1, 92, 24, money(p), v ? GOLD : c[:txt], PF::TEXT, 1)
end
UI.rbox(b, 8, 300, 228, 352, 8, Color.new(60, 48, 14), GOLD)
P.text(t, 8, 304, 220, 22, "Valuables #{money(VAL_TOTAL)}", GOLD, PF::TEXT, 2)
P.small(t, 8, 328, 220, 16, "RB: Sell them all", c[:dim], 2)
money_box(c, 8, 8, 110)
hints(c, H_SELL)
shot("SL5_sell")
OVER.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120)); valuables_panel(c, 106, 40); shot("SL5_valuables")
