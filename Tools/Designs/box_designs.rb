# encoding: utf-8
# Mockups: Shop and Economy, Mystery Box Opening (part 4), five designs, each
# two screens: the box opening (HR's 6-frame chest sprites, 48x32) and the
# reveal. Box Animation Off (HR's option) falls back to a plain popup.
# Mystery Box ($5,000): Common 70% (Ultra Ball x5, Revive x3, Nugget),
# Uncommon 25% (Rare Candy, PP Max, Max Revive), Rare 5% (Ability Capsule,
# Lucky Egg, Leftovers). Example: Ability Capsule (Rare).
# Design 1 = HR's chest animation and result, rebuilt in our kit over the
# chosen Buy screen.
# Usage (from this folder): ruby box_designs.rb "<KIF Beta>" <work dir with metrics.json>
SHSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "shop_designs.rb"), :encoding => "UTF-8")
eval(SHSRC.split("c = palette(2)\n")[0], binding, "shop_designs.rb")

UNC = Color.new(130, 190, 250)
TIERS = [["Common", 70, nil, [["ULTRABALL", "Ultra Ball x5"], ["REVIVE", "Revive x3"], ["NUGGET", "Nugget"]]],
         ["Uncommon", 25, nil, [["RARECANDY", "Rare Candy"], ["PPMAX", "PP Max"], ["MAXREVIVE", "Max Revive"]]],
         ["Rare", 5, nil, [["ABILITYCAPSULE", "Ability Capsule"], ["LUCKYEGG", "Lucky Egg"], ["LEFTOVERS", "Leftovers"]]]]
def tier_col(c, n); { "Common" => c[:txt], "Uncommon" => UNC, "Rare" => GOLD }[n]; end
def chest_frame(b, kind, frame, cx, cy, scale)
  w = 48 * scale; h = 32 * scale
  b.stretch_blt(Rect.new(cx - w / 2, cy - h / 2, w, h), bmp(File.join(SHOP, "boxes", kind + ".png")), Rect.new(frame * 48, 0, 48, 32))
end
def sparkle(b, cx, cy, r, color)
  b.fill_rect(cx - r, cy, 2 * r + 1, 1, color); b.fill_rect(cx, cy - r, 1, 2 * r + 1, color)
  b.fill_rect(cx - r / 2, cy - 1, r + 1, 3, color); b.fill_rect(cx - 1, cy - r / 2, 3, r + 1, color)
end
def burst(b, cx, cy, spread, color)
  [[-1.0, -0.6, 7], [-0.5, -1.0, 5], [0.1, -1.1, 8], [0.7, -0.8, 6], [1.0, -0.2, 5], [-0.9, 0.3, 4], [0.85, 0.45, 4]].each do |fx, fy, r|
    x = (cx + fx * spread).round; y = (cy + fy * spread * 0.7).round
    sparkle(b, x, y, r, color); sparkle(b, x, y, r / 2, WHITE)
  end
end
WHITE = Color.new(255, 255, 255) unless defined?(WHITE)
def shop_behind(c)
  plain(c); b = BASE.bitmap; t = TOP.bitmap
  shop_bar(c, "RLD Shop")
  cat_bar(c, 32, CATS, CAT_SEL, "Bundles  7/7")
  money_box(c, W - 104, 34)
  BUNDLES.each_with_index do |(k, n, p, sub, _), i|
    y = 90 + i * 30
    chest(t, k.to_s, 26, y + 14, 22)
    P.text(t, 48, y + 4, 160, 22, n, k == :mysterybox ? GOLD : c[:txt], PF::TEXT)
    P.text(t, W - 110, y + 4, 96, 22, money(p), c[:txt], PF::TEXT, 1)
  end
  OVER.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 150))
end
def odds(c, d, x, y, w)
  TIERS.each_with_index do |(n, pct, _, _), k|
    P.small(d, x, y + k * 18, 80, 16, n, tier_col(c, n)); P.small(d, x + w - 40, y + k * 18, 40, 16, "#{pct}%", c[:dim], 1)
  end
end
def two_buttons(c, d, x, y, w, a, b2)
  [[a, true, x], [b2, false, x + w / 2 + 4]].each do |lbl, on, bx|
    UI.rbox(d, bx, y, bx + w / 2 - 4, y + 26, 6, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
    P.text(d, bx, y + 2, w / 2 - 4, 22, lbl, on ? c[:white] : c[:txt], PF::TEXT, 2)
  end
end

c = palette(2)

#================================================================ BX1 Recommended: HR's chest in a panel over the shop, then the reveal
shop_behind(c); d = OVER.bitmap
UI.rbox(d, 126, 56, 386, 330, 8, col(c[:panel], 255), c[:selb])
P.text(d, 126, 62, 260, 22, "Mystery Box", GOLD, PF::ROW, 2)
chest_frame(d, "mysterybox", 3, 256, 170, 4)
burst(d, 256, 150, 70, GOLD)
P.small(d, 126, 238, 260, 16, "Opening...", c[:dim], 2)
odds(c, d, 196, 260, 120)
shot("BX1_open")
shop_behind(c); d = OVER.bitmap
UI.rbox(d, 106, 56, 406, 330, 8, col(c[:panel], 255), GOLD)
P.text(d, 106, 62, 300, 22, "You Got", c[:title], PF::ROW, 2)
item(d, "ABILITYCAPSULE", 256, 132, 44)
burst(d, 256, 132, 42, GOLD)
chest_frame(d, "mysterybox", 5, 256, 194, 2)
P.pill(d, 256 - 22, 230, "RARE", Color.new(70, 56, 14), GOLD, false)
P.text(d, 106, 248, 300, 24, "Ability Capsule", c[:txt], PF::ROW, 2)
two_buttons(c, d, 122, 290, 268, "Open Another", "Done")
shot("BX1_reveal")

#================================================================ BX2: full screen, a spotlight on the chest
def stage(c)
  frame(c); b = BASE.bitmap
  MAPS.bitmap = Bitmap.new(W, H)
  b.fill_rect(0, 0, W, H, Color.new(10, 12, 20))
  # a soft light cone from above, in solid steps
  10.times { |k| w = 60 + k * 14; b.fill_rect(256 - w, k * 30, 2 * w, 30, Color.new(16 + k, 18 + k, 28 + k * 2)) }
  6.times { |k| UI.rbox(b, 256 - 150 + k * 20, 300 - 30 + k * 4, 256 + 150 - k * 20, 300 + 30 - k * 4, 40, Color.new(30 + k * 6, 34 + k * 6, 54 + k * 8)) }
end
stage(c); t = TOP.bitmap
chest_frame(t, "mysterybox", 4, 256, 250, 5)
burst(t, 256, 200, 90, GOLD)
P.text(t, 0, 20, W, 30, "Mystery Box", GOLD, PF::TITLE, 2)
hints(c, [[A_BTN, "Skip"]])
shot("BX2_open")
stage(c); t = TOP.bitmap
chest_frame(t, "mysterybox", 5, 256, 270, 4)
UI.rbox(BASE.bitmap, 196, 76, 316, 196, 60, Color.new(60, 50, 22))
item(t, "ABILITYCAPSULE", 256, 136, 72)
burst(t, 256, 136, 80, GOLD)
P.pill(t, 256 - 22, 14, "RARE", Color.new(70, 56, 14), GOLD, false)
P.text(t, 0, 30, W, 30, "Ability Capsule!", c[:txt], PF::TITLE, 2)
hints(c, [[A_BTN, "Open Another"], [B_BTN, "Done"]])
shot("BX2_reveal")

#================================================================ BX3: a reel of the possible items that stops on the prize
REEL = [["NUGGET", "Common"], ["REVIVE", "Common"], ["RARECANDY", "Uncommon"], ["ULTRABALL", "Common"], ["ABILITYCAPSULE", "Rare"],
        ["REVIVE", "Common"], ["PPMAX", "Uncommon"], ["NUGGET", "Common"]]
def reel(c, d, stopped)
  UI.rbox(d, 16, 120, 496, 220, 8, col(c[:dark], 255), c[:line])
  REEL.each_with_index do |(ic, tier), i|
    x = 16 + 10 + i * 60 - (stopped ? 10 : 34)
    next if x < 18 || x > 450
    col_t = tier_col(c, tier)
    UI.rbox(d, x, 130, x + 54, 210, 6, c[:panel], col_t)
    item(d, ic, x + 27, 162, 36)
    d.fill_rect(x + 6, 200, 42, 3, col_t)
  end
  d.fill_rect(255, 114, 3, 112, stopped ? GOLD : c[:selb])
  UI.tri(d, 251, 108, :d, stopped ? GOLD : c[:selb], 5); UI.tri(d, 251, 222, :u, stopped ? GOLD : c[:selb], 5)
end
shop_behind(c); d = OVER.bitmap
P.text(d, 0, 76, W, 26, "Mystery Box", GOLD, PF::ROW, 2)
reel(c, d, false)
P.small(d, 0, 236, W, 16, "Common 70%   Uncommon 25%   Rare 5%", c[:dim], 2)
shot("BX3_open")
shop_behind(c); d = OVER.bitmap
P.text(d, 0, 76, W, 26, "Ability Capsule!", GOLD, PF::ROW, 2)
reel(c, d, true)
UI.rbox(d, 140, 248, 372, 302, 8, col(c[:panel], 255), GOLD)
P.pill(d, 150, 256, "RARE", Color.new(70, 56, 14), GOLD, false)
P.small(d, 196, 256, 170, 16, "Added to the Bag.", c[:txt])
two_buttons(c, d, 150, 274, 212, "Again", "Done")
shot("BX3_reveal")

#================================================================ BX4: the box's contents list (bundles show what was added)
shop_behind(c); d = OVER.bitmap
UI.rbox(d, 56, 50, 456, 322, 8, col(c[:panel], 255), c[:selb])
P.text(d, 56, 56, 400, 22, "Mystery Box", GOLD, PF::ROW, 2)
chest_frame(d, "mysterybox", 1, 256, 102, 2)
P.small(d, 56, 128, 400, 16, "One item from:", c[:dim], 2)
TIERS.each_with_index do |(n, pct, _, items), k|
  y = 146 + k * 44
  P.small(d, 72, y, 120, 16, "#{n} #{pct}%", tier_col(c, n))
  items.each_with_index do |(ic, nm), j|
    item(d, ic, 76 + j * 140, y + 28, 20); P.small(d, 90 + j * 140, y + 20, 110, 16, nm.sub(" x5", "").sub(" x3", ""), c[:txt])
  end
end
two_buttons(c, d, 72, 290, 368, "Open", "Later")
shot("BX4_open")
shop_behind(c); d = OVER.bitmap
UI.rbox(d, 56, 50, 456, 322, 8, col(c[:panel], 255), GOLD)
P.text(d, 56, 56, 400, 22, "Opened!", c[:title], PF::ROW, 2)
chest_frame(d, "mysterybox", 5, 256, 110, 2)
item(d, "ABILITYCAPSULE", 256, 88, 26)
TIERS.each_with_index do |(n, pct, _, items), k|
  y = 146 + k * 44
  P.small(d, 72, y, 120, 16, "#{n} #{pct}%", tier_col(c, n))
  items.each_with_index do |(ic, nm), j|
    hit = ic == "ABILITYCAPSULE"
    UI.rbox(d, 62 + j * 140, y + 16, 196 + j * 140, y + 40, 5, Color.new(70, 56, 14), GOLD) if hit
    item(d, ic, 76 + j * 140, y + 28, 20); P.small(d, 90 + j * 140, y + 20, 110, 16, nm.sub(" x5", "").sub(" x3", ""), hit ? GOLD : c[:dim])
  end
end
two_buttons(c, d, 72, 290, 368, "Open Another", "Done")
shot("BX4_reveal")

#================================================================ BX5: quick (Box Animation Off): the result straight in the info panel
def quick(c, revealed)
  plain(c); b = BASE.bitmap; t = TOP.bitmap
  shop_bar(c, "RLD Shop")
  cat_bar(c, 32, CATS, CAT_SEL, "Bundles  7/7")
  money_box(c, W - 104, 34)
  BUNDLES.each_with_index do |(k, n, p, sub, _), i|
    y = 90 + i * 30
    cursor_at(6, y, W - 12, 29) if i == 3
    chest(t, k.to_s, 26, y + 14, 22)
    P.text(t, 48, y + 4, 160, 22, n, k == :mysterybox ? GOLD : c[:txt], PF::TEXT)
    P.text(t, W - 110, y + 4, 96, 22, money(p), c[:txt], PF::TEXT, 1)
  end
  y0 = 240
  b.fill_rect(0, y0, W, 119, c[:panel2]); b.fill_rect(0, y0, W, 1, c[:line])
  UI.rbox(b, W - 96, y0 + 8, W - 10, y0 + 70, 6, c[:dark], revealed ? GOLD : c[:line])
  if revealed
    item(t, "ABILITYCAPSULE", W - 53, y0 + 39, 44)
    P.text(t, 12, y0 + 4, 300, 22, "You got an Ability Capsule!", GOLD, PF::ROW)
    P.pill(t, 12, y0 + 32, "RARE", Color.new(70, 56, 14), GOLD, false)
    P.small(t, 60, y0 + 32, 320, 16, "Added to the Bag.", c[:txt])
    P.small(t, 12, y0 + 56, 380, 16, "A to buy another.", c[:dim])
  else
    chest(t, "mysterybox", W - 53, y0 + 39, 40)
    P.text(t, 12, y0 + 4, 300, 22, "Mystery Box", GOLD, PF::ROW)
    P.small(t, 12, y0 + 28, 380, 16, "One random item. The rarer, the better.", c[:txt])
    odds(c, t, 12, y0 + 50, 150)
  end
  hints(c, H_BUY)
end
quick(c, false); shot("BX5_open")
quick(c, true); shot("BX5_reveal")
