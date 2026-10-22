# encoding: utf-8
# Mockups: Shop and Economy (topic 25), the Buy screen, five designs, each two
# screens:
#  - the RLD Shop (pause menu; KIF's Kuray Shop stock with KR's overlay) on its
#    new Bundles page: Starter / Evolution / Training Kits and a Mystery Box
#    (HR's chest sprites), with today's Daily Featured item;
#  - Cerulean City's Mart in the same scene (KIF's exact stock and prices)
#    during a Mart Event (Poke Balls 20% off), a starred wanted item (Sale
#    Alerts) and the quantity panel with the Bulk Reward preview
#    (every 10 Poke Balls: 1 Premier Ball).
# Design 1 = old KR's RLD Shop layout, which is the chosen Bag's layout (title
# bar, category bar, list, info panel), rebuilt.
# Usage (from this folder): ruby shop_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "bag_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "bag_designs.rb")

MAPS = Sprite.new($vp); MAPS.z = -1
RED2 = Color.new(240, 100, 90); SALE = Color.new(120, 230, 150)
SHOP = File.join(HERE, "shop")
def item(b, id, cx, cy, size); draw_img(b, File.join(GFX, "Items", id + ".png"), cx, cy, size); end
def chest(b, kind, cx, cy, h = 24)
  draw_img(b, File.join(SHOP, "boxes", kind + ".png"), cx, cy, (48 * h / 32.0).round, Rect.new(0, 0, 48, 32))
end
def money(v); "$" + v.to_s.reverse.scan(/\d{1,3}/).join(",").reverse; end
def strike(t, x, y, w, s, color, align = 1)
  tw = P.width(PF::TEXT, s)
  x0 = align == 1 ? x + w - tw : x
  P.text(t, x, y, w, 20, s, color, PF::TEXT, align)
  t.fill_rect(x0, y + 10, tw, 1, color)
end
def plain(c); MAPS.bitmap = Bitmap.new(W, H); frame(c); end
def over_map(c, name); BASE.bitmap.clear; TOP.bitmap.clear; OVER.bitmap.clear; CUR.visible = false; MAPS.bitmap = Bitmap.new(File.join(SHOP, name)); end

# RLD Shop categories (item icons) and its Bundles page
CATS = [["POKEBALL", "Balls"], ["POTION", "Medicine"], ["PROTEIN", "Training"], ["FIRESTONE", "Evolution"],
        ["XATTACK", "Battle"], ["RARECANDY", "Special"], [:chest, "Bundles"]]
CAT_SEL = 6
BUNDLES = [[:bundle, "Starter Kit", 1200, "5 Potions, 10 Poké Balls", [["POTION", 5], ["POKEBALL", 10]]],
           [:bundle, "Evolution Kit", 7500, "Fire, Water and Thunder Stone", [["FIRESTONE", 1], ["WATERSTONE", 1], ["THUNDERSTONE", 1]]],
           [:bundle, "Training Kit", 12000, "A Protein and a Power Bracer", [["PROTEIN", 1], ["POWERBRACER", 1]]],
           [:mysterybox, "Mystery Box", 5000, "One random item", []]]
BUN_SEL = 1
# Cerulean Mart (KIF's stock and prices); the event: Poke Balls 20% off
MART = [["POKEBALL", "Poké Ball", 200, 160, false], ["GREATBALL", "Great Ball", 600, 480, true], ["POTION", "Potion", 300, nil, false],
        ["SUPERPOTION", "Super Potion", 700, nil, false], ["ANTIDOTE", "Antidote", 100, nil, false], ["PARLYZHEAL", "Parlyz Heal", 200, nil, false],
        ["ESCAPEROPE", "Escape Rope", 550, nil, false], ["REPEL", "Repel", 350, nil, false]]
QTY = 20

def featured(c, x, y, w, compact = false)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + 22, 5, Color.new(60, 48, 14), GOLD)
  item(t, "RARECANDY", x + 14, y + 11, 18)
  P.text(t, x + 26, y + 1, 90, 20, "TODAY", GOLD, PF::TINY)
  P.text(t, x + 66, y + 1, 120, 20, "Rare Candy", c[:txt], PF::TEXT)
  strike(t, x + w - 150, y + 1, 70, money(4800), c[:dim]) unless compact
  P.text(t, x + w - 76, y + 1, 70, 20, money(3600), SALE, PF::TEXT, 1)
end
def event_chip(c, x, y, right = false); P.pill(TOP.bitmap, x, y, "SALE: POKÉ BALLS 20% OFF, 2 DAYS LEFT", Color.new(24, 60, 40), SALE, right); end
def price_cell(c, t, x, y, w, base, sale)
  if sale
    strike(t, x, y, w - 64, money(base), c[:dim]); P.text(t, x + w - 60, y, 60, 20, money(sale), SALE, PF::TEXT, 1)
  else
    P.text(t, x, y, w, 20, money(base), c[:txt], PF::TEXT, 1)
  end
end
# The quantity panel: icon, amount, total, savings, Bulk Reward
def qty_panel(c, x, y, w = 260)
  d = OVER.bitmap
  UI.rbox(d, x, y, x + w, y + 132, 8, col(c[:panel], 255), c[:selb])
  P.text(d, x, y + 6, w, 22, "Choose Quantity", c[:title], PF::ROW, 2)
  d.fill_rect(x + 10, y + 32, w - 20, 1, c[:line])
  item(d, "POKEBALL", x + 30, y + 54, 28)
  P.text(d, x + 50, y + 42, 100, 22, "Poké Ball", c[:txt], PF::TEXT)
  UI.tri(d, x + w - 74, y + 42, :u, c[:selb], 4); UI.tri(d, x + w - 74, y + 62, :d, c[:selb], 4)
  P.text(d, x + w - 60, y + 42, 50, 24, "x#{QTY}", c[:white], PF::ROW, 1)
  P.small(d, x + 14, y + 74, 100, 16, "Total", c[:dim]); P.text(d, x + w - 110, y + 72, 96, 20, money(160 * QTY), c[:txt], PF::TEXT, 1)
  P.small(d, x + 14, y + 92, 100, 16, "Sale Saves", c[:dim]); P.text(d, x + w - 110, y + 90, 96, 20, money(40 * QTY), SALE, PF::TEXT, 1)
  item(d, "PREMIERBALL", x + 22, y + 118, 16)
  P.small(d, x + 34, y + 110, w - 44, 16, "Bonus: 2 Premier Balls", GOLD)
end
def money_box(c, x, y, w = 96)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + 22, 5, c[:dark], c[:line])
  P.text(t, x, y + 1, w, 20, money(41200), GREEN, PF::TEXT, 2)
end
def shop_bar(c, title)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
  P.text(t, 0, 2, W, 28, title, c[:title], PF::TITLE, 2)
  UI.rbox(b, 8, 4, 120, 27, 5, c[:dark], c[:line]); P.text(t, 8, 4, 112, 23, "Sort: Price", c[:dim], PF::TEXT, 2)
  BI.draw(t, 126, 8, "p:9", c, $style)
  UI.rbox(b, W - 128, 4, W - 8, 27, 5, c[:dark], c[:line]); P.text(t, W - 128, 4, 120, 23, "Quick Buy: Off", c[:dim], PF::TEXT, 2)
  BI.draw(t, W - 134 - BI.width("p:10", $style), 8, "p:10", c, $style)
end
def cat_bar(c, y, cats, sel, label)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, y, W, 26, c[:panel]); b.fill_rect(0, y + 25, W, 1, c[:line])
  cats.each_with_index do |(ic, _), i|
    px = 12 + i * 30
    UI.rbox(b, px, y + 2, px + 24, y + 23, 5, c[:sel], c[:selb]) if i == sel
    ic == :chest ? chest(t, "bundle", px + 12, y + 13, 14) : item(t, ic, px + 12, y + 13, i == sel ? 22 : 18)
  end
  P.text(t, 234, y + 1, 158, 24, label, c[:txt], PF::TEXT, 1)
  UI.tri(t, 226, y + 9, :l, c[:dim], 4); UI.tri(t, 394, y + 9, :r, c[:dim], 4)
end
def shot(name); dump_as(name); end
H_BUY = [[:ud, "Choose"], [:lr, "Category"], [A_BTN, "Buy"], [Y_BTN, "Want"], [B_BTN, "Close"]]

c = palette(2)

#================================================================ SH1 Recommended: old KR's RLD Shop, rebuilt like the Bag
def sh1_shop(c)
  plain(c); b = BASE.bitmap; t = TOP.bitmap
  shop_bar(c, "RLD Shop")
  cat_bar(c, 32, CATS, CAT_SEL, "Bundles  7/7")
  money_box(c, W - 104, 34)
  featured(c, 8, 62, W - 16)
  BUNDLES.each_with_index do |(k, n, p, sub, _), i|
    y = 90 + i * 30
    cursor_at(6, y, W - 12, 29) if i == BUN_SEL
    chest(t, k.to_s, 26, y + 14, 22)
    P.text(t, 48, y + 4, 160, 22, n, k == :mysterybox ? GOLD : c[:txt], PF::TEXT)
    P.small(t, 190, y + 6, 200, 16, sub, c[:dim])
    P.text(t, W - 110, y + 4, 96, 22, money(p), c[:txt], PF::TEXT, 1)
  end
  P.pill(t, 314, 186, "1 A DAY", Color.new(60, 48, 14), GOLD, false)
  y0 = 240
  b.fill_rect(0, y0, W, 119, c[:panel2]); b.fill_rect(0, y0, W, 1, c[:line])
  P.text(t, 12, y0 + 4, 300, 22, "Evolution Kit", c[:title], PF::ROW)
  P.small(t, 12, y0 + 28, 380, 16, "Three evolution stones for less than buying each.", c[:txt])
  P.heading(t, 12, 380, y0 + 52, "Contains", c[:head], c[:line])
  [["FIRESTONE", "Fire Stone"], ["WATERSTONE", "Water Stone"], ["THUNDERSTONE", "Thunder Stone"]].each_with_index do |(ic, n), k|
    item(t, ic, 30 + k * 120, y0 + 82, 24); P.small(t, 46 + k * 120, y0 + 74, 90, 16, n, c[:txt])
  end
  P.small(t, 12, y0 + 98, 300, 16, "Bought apart: #{money(9000)}. You save #{money(1500)}.", SALE)
  UI.rbox(b, W - 96, y0 + 8, W - 10, y0 + 70, 6, c[:dark], c[:line])
  chest(t, "bundle", W - 53, y0 + 39, 40)
  hints(c, H_BUY)
end
def sh1_mart(c)
  plain(c); b = BASE.bitmap; t = TOP.bitmap
  shop_bar(c, "Mart")
  cat_bar(c, 32, [["POKEBALL", ""], ["POTION", ""], ["ESCAPEROPE", ""]], 0, "All Items")
  money_box(c, W - 104, 34)
  event_chip(c, 8, 64)
  MART.first(7).each_with_index do |(ic, n, p, s, want), i|
    y = 86 + i * 22
    cursor_at(6, y, W - 12, 21) if i == 0
    star(t, 12, y + 7, GOLD) if want
    item(t, ic, 34, y + 10, 18)
    P.text(t, 50, y, 200, 21, n, c[:txt], PF::TEXT)
    price_cell(c, t, W - 200, y, 186, p, s)
  end
  y0 = 240
  b.fill_rect(0, y0, W, 119, c[:panel2]); b.fill_rect(0, y0, W, 1, c[:line])
  P.text(t, 12, y0 + 4, 300, 22, "Poké Ball", c[:title], PF::ROW)
  P.small(t, 12, y0 + 28, 380, 16, "A device for catching wild Pokémon.", c[:txt])
  P.small(t, 12, y0 + 48, 380, 16, "In Bag: 14", c[:dim])
  hints(c, [[:ud, "Change"], [A_BTN, "Buy"], [B_BTN, "Back"]])
  OVER.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 110))
  qty_panel(c, 126, 96)
end
sh1_shop(c); shot("SH1_shop")
sh1_mart(c); shot("SH1_mart")

#================================================================ SH2: a storefront grid of tiles
def tile(c, b, t, x, y, w, h, sel, gold = false)
  UI.rbox(b, x, y, x + w, y + h, 8, gold ? Color.new(60, 48, 14) : c[:panel], gold ? GOLD : c[:line])
  cursor_at(x - 2, y - 2, w + 4, h + 4) if sel
end
plain(c); b = BASE.bitmap; t = TOP.bitmap
shop_bar(c, "RLD Shop")
cat_bar(c, 32, CATS, CAT_SEL, "Bundles")
money_box(c, W - 104, 34)
# featured as the big first tile
tile(c, b, t, 8, 64, 160, 152, false, true)
P.text(t, 8, 68, 160, 16, "TODAY", GOLD, PF::TINY, 2)
item(t, "RARECANDY", 88, 118, 52)
P.text(t, 8, 150, 160, 22, "Rare Candy", c[:txt], PF::TEXT, 2)
strike(t, 18, 172, 60, money(4800), c[:dim]); P.text(t, 88, 172, 72, 20, money(3600), SALE, PF::TEXT)
P.small(t, 8, 194, 160, 16, "25% off today", GOLD, 2)
BUNDLES.each_with_index do |(k, n, p, _, _), i|
  x = 176 + (i % 2) * 166; y = 64 + (i / 2) * 78
  tile(c, b, t, x, y, 160, 72, i == BUN_SEL, k == :mysterybox)
  chest(t, k.to_s, x + 30, y + 36, 28)
  P.small(t, x + 56, y + 14, 100, 16, n, k == :mysterybox ? GOLD : c[:txt])
  P.text(t, x + 56, y + 34, 96, 22, money(p), c[:txt], PF::TEXT)
end
UI.rbox(b, 8, 224, 504, 354, 8, c[:panel2], c[:line])
P.text(t, 18, 228, 300, 22, "Evolution Kit", c[:title], PF::ROW)
P.small(t, 18, 252, 300, 16, "Three evolution stones for less.", c[:txt])
[["FIRESTONE", "Fire Stone"], ["WATERSTONE", "Water Stone"], ["THUNDERSTONE", "Thunder Stone"]].each_with_index do |(ic, n), k|
  item(t, ic, 34 + k * 120, 290, 24); P.small(t, 50 + k * 120, 282, 90, 16, n, c[:txt])
end
P.small(t, 18, 318, 300, 16, "Bought apart: #{money(9000)}. You save #{money(1500)}.", SALE)
hints(c, [[:ud, ""], [:lr, "Choose"], [A_BTN, "Buy"], [Y_BTN, "Want"], [B_BTN, "Close"]])
shot("SH2_shop")
plain(c); b = BASE.bitmap; t = TOP.bitmap
shop_bar(c, "Mart")
money_box(c, W - 104, 36)
event_chip(c, 8, 38)
MART.first(8).each_with_index do |(ic, n, p, s, want), i|
  x = 8 + (i % 4) * 124; y = 64 + (i / 4) * 92
  tile(c, b, t, x, y, 118, 86, i == 0, false)
  star(t, x + 8, y + 8, GOLD) if want
  item(t, ic, x + 59, y + 30, 32)
  P.small(t, x, y + 50, 118, 16, n, c[:txt], 2)
  s ? P.text(t, x, y + 64, 118, 20, money(s), SALE, PF::TEXT, 2) : P.text(t, x, y + 64, 118, 20, money(p), c[:txt], PF::TEXT, 2)
end
hints(c, [[:ud, ""], [:lr, "Choose"], [A_BTN, "Buy"], [Y_BTN, "Want"], [B_BTN, "Back"]])
OVER.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 110))
qty_panel(c, 126, 120)
shot("SH2_mart")

#================================================================ SH3: categories in a sidebar (the Settings layout), details on the right
def sidebar(c, cats, sel)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 36, 132, 354, 6, c[:panel])
  cats.each_with_index do |(ic, n), i|
    y = 42 + i * 34
    UI.rbox(b, 10, y, 128, y + 30, 5, c[:sel], c[:selb]) if i == sel
    ic == :chest ? chest(t, "bundle", 26, y + 15, 14) : item(t, ic, 26, y + 15, 20)
    P.text(t, 42, y, 84, 30, n, i == sel ? c[:white] : c[:txt], PF::TEXT)
  end
end
plain(c); b = BASE.bitmap; t = TOP.bitmap
shop_bar(c, "RLD Shop")
sidebar(c, CATS, CAT_SEL)
featured(c, 138, 36, 366)
UI.rbox(b, 138, 62, 318, 354, 6, c[:panel])
BUNDLES.each_with_index do |(k, n, p, _, _), i|
  y = 68 + i * 30
  cursor_at(141, y, 174, 29) if i == BUN_SEL
  chest(t, k.to_s, 158, y + 14, 20)
  P.text(t, 176, y + 4, 140, 22, n, k == :mysterybox ? GOLD : c[:txt], PF::TEXT)
end
UI.rbox(b, 324, 62, 504, 354, 6, c[:panel2])
chest(t, "bundle", 414, 110, 54)
P.text(t, 324, 146, 180, 24, "Evolution Kit", c[:title], PF::ROW, 2)
P.text(t, 324, 170, 180, 22, money(7500), c[:txt], PF::TEXT, 2)
P.heading(t, 334, 494, 198, "Contains", c[:head], c[:line])
[["FIRESTONE", "Fire Stone"], ["WATERSTONE", "Water Stone"], ["THUNDERSTONE", "Thunder Stone"]].each_with_index do |(ic, n), k|
  item(t, ic, 346, 222 + k * 22, 18); P.small(t, 360, 214 + k * 22, 130, 16, n, c[:txt])
end
P.small(t, 334, 286, 164, 16, "You save #{money(1500)}.", SALE)
money_box(c, 334, 324, 160)
hints(c, [[:ud, "Choose"], [:lr, "Categories"], [A_BTN, "Buy"], [Y_BTN, "Want"], [B_BTN, "Close"]])
shot("SH3_shop")
plain(c); b = BASE.bitmap; t = TOP.bitmap
shop_bar(c, "Mart")
sidebar(c, [["POKEBALL", "Balls"], ["POTION", "Medicine"], ["ESCAPEROPE", "Field"]], 0)
UI.rbox(b, 138, 36, 504, 60, 6, Color.new(24, 60, 40), SALE)
P.text(t, 138, 37, 366, 22, "Sale: Poké Balls 20% Off, 2 Days Left", SALE, PF::TEXT, 2)
UI.rbox(b, 138, 66, 504, 354, 6, c[:panel])
MART.first(2).each_with_index do |(ic, n, p, s, want), i|
  y = 72 + i * 30
  cursor_at(141, y, 360, 29) if i == 0
  star(t, 148, y + 11, GOLD) if want
  item(t, ic, 172, y + 14, 22)
  P.text(t, 190, y + 4, 140, 22, n, c[:txt], PF::TEXT)
  price_cell(c, t, 330, y + 4, 164, p, s)
end
money_box(c, 334, 324, 160)
hints(c, [[:ud, "Choose"], [:lr, "Categories"], [A_BTN, "Buy"], [Y_BTN, "Want"], [B_BTN, "Back"]])
OVER.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 110))
qty_panel(c, 190, 140)
shot("SH3_mart")

#================================================================ SH4: a cart (add several items, then pay once; rewards count the whole cart)
def cart(c, x, y, w, rows, total, bonus)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, 354, 6, c[:panel2], c[:selb])
  P.text(t, x, y + 4, w, 22, "Cart", c[:title], PF::ROW, 2)
  rows.each_with_index do |(ic, n, q, p), i|
    yy = y + 32 + i * 34
    ic.is_a?(Symbol) ? chest(t, ic.to_s, x + 18, yy + 15, 18) : item(t, ic, x + 18, yy + 15, 20)
    P.small(t, x + 34, yy, w - 42, 16, n, c[:txt])
    P.small(t, x + 34, yy + 15, 40, 16, "x#{q}", c[:dim]); P.small(t, x + 74, yy + 15, w - 82, 16, money(p), c[:txt], 1)
  end
  b.fill_rect(x + 8, 270, w - 16, 1, c[:line])
  P.small(t, x + 10, 276, 60, 16, "Total", c[:dim]); P.text(t, x + w - 90, 274, 80, 20, money(total), c[:txt], PF::TEXT, 1)
  P.small(t, x + 10, 296, w - 20, 16, bonus, GOLD) if bonus
  UI.rbox(b, x + 10, 320, x + w - 10, 346, 6, c[:sel], c[:selb])
  P.text(t, x + 10, 322, w - 20, 22, "Pay (X)", c[:white], PF::TEXT, 2)
end
plain(c); b = BASE.bitmap; t = TOP.bitmap
shop_bar(c, "RLD Shop")
cat_bar(c, 32, CATS, CAT_SEL, "Bundles")
featured(c, 8, 62, 324)
BUNDLES.each_with_index do |(k, n, p, sub, _), i|
  y = 90 + i * 30
  cursor_at(6, y, 326, 29) if i == BUN_SEL
  chest(t, k.to_s, 26, y + 14, 22)
  P.text(t, 48, y + 4, 160, 22, n, k == :mysterybox ? GOLD : c[:txt], PF::TEXT)
  P.text(t, 230, y + 4, 96, 22, money(p), c[:txt], PF::TEXT, 1)
end
P.small(t, 12, 216, 320, 16, "Evolution Kit: Fire, Water and Thunder Stone.", c[:dim])
cart(c, 340, 62, 164, [["RARECANDY", "Rare Candy", 2, 7200], [:bundle, "Evolution Kit", 1, 7500]], 14700, nil)
money_box(c, 8, 330, 120)
hints(c, [[:ud, "Choose"], [A_BTN, "Add"], [X_BTN, "Pay"], [Y_BTN, "Want"], [B_BTN, "Close"]])
shot("SH4_shop")
plain(c); b = BASE.bitmap; t = TOP.bitmap
shop_bar(c, "Mart")
event_chip(c, 8, 38)
MART.first(8).each_with_index do |(ic, n, p, s, want), i|
  y = 62 + i * 24
  cursor_at(6, y, 326, 23) if i == 0
  star(t, 12, y + 8, GOLD) if want
  item(t, ic, 34, y + 11, 18)
  P.text(t, 50, y + 1, 150, 22, n, c[:txt], PF::TEXT)
  price_cell(c, t, 180, y + 1, 146, p, s)
end
cart(c, 340, 36, 164, [["POKEBALL", "Poké Ball", 20, 3200], ["GREATBALL", "Great Ball", 5, 2400], ["POTION", "Potion", 4, 1200]], 6800, "+2 Premier Balls")
money_box(c, 8, 330, 120)
hints(c, [[:ud, "Choose"], [A_BTN, "Add"], [X_BTN, "Pay"], [Y_BTN, "Want"], [B_BTN, "Back"]])
shot("SH4_mart")

#================================================================ SH5: at the counter (a panel over the Mart, the map stays visible)
def counter_panel(c, title, rows)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 236, 8, 504, 352, 8, col(c[:panel], 250), c[:line])
  P.text(t, 236, 12, 268, 24, title, c[:title], PF::ROW, 2)
  rows.call(b, t)
end
over_map(c, "mart.png")
counter_panel(c, "RLD Shop", proc { |b, t|
  cat_x = 246
  CATS.each_with_index do |(ic, _), i|
    px = cat_x + i * 32
    UI.rbox(b, px, 40, px + 26, 62, 5, c[:sel], c[:selb]) if i == CAT_SEL
    ic == :chest ? chest(t, "bundle", px + 13, 51, 14) : item(t, ic, px + 13, 51, 18)
  end
  featured(c, 244, 68, 252, true)
  BUNDLES.each_with_index do |(k, n, p, _, _), i|
    y = 96 + i * 28
    cursor_at(242, y, 256, 27) if i == BUN_SEL
    chest(t, k.to_s, 260, y + 13, 18)
    P.text(t, 278, y + 3, 120, 22, n, k == :mysterybox ? GOLD : c[:txt], PF::TEXT)
    P.text(t, 400, y + 3, 92, 22, money(p), c[:txt], PF::TEXT, 1)
  end
  b.fill_rect(246, 214, 248, 1, c[:line])
  P.small(t, 248, 220, 244, 16, "Fire, Water and Thunder Stone.", c[:txt])
  P.small(t, 248, 238, 244, 16, "You save #{money(1500)}.", SALE)
})
money_box(c, 8, 8, 110)
hints(c, H_BUY)
shot("SH5_shop")
over_map(c, "mart.png")
counter_panel(c, "Mart", proc { |b, t|
  MART.first(8).each_with_index do |(ic, n, p, s, want), i|
    y = 62 + i * 24
    cursor_at(242, y, 256, 23) if i == 0
    star(t, 246, y + 8, GOLD) if want
    item(t, ic, 266, y + 11, 18)
    P.text(t, 280, y + 1, 110, 22, n, c[:txt], PF::TEXT)
    price_cell(c, t, 372, y + 1, 124, p, s)
  end
})
P.pill(TOP.bitmap, 246, 40, "SALE 20% OFF", Color.new(24, 60, 40), SALE, false)
money_box(c, 8, 8, 110)
hints(c, [[:ud, "Change"], [A_BTN, "Buy"], [B_BTN, "Back"]])
qty_panel(c, 8, 210, 222)
shot("SH5_mart")
