# encoding: utf-8
# Mockups: Shop and Economy, the RLD Shop Editor (part 5), five designs, each
# two screens: the catalog (categories and items; custom prices, added and
# hidden items marked) and editing one item (its price). The overlay is per
# save; Export / Import carry it to another save; Reset clears it.
# Special category: Rare Candy (KIF $4,800, custom $3,500), Master Ball,
# Max Repel, Eviolite, PP Up, PP Max (hidden), Ability Capsule (added).
# Design 1 = old KR's editor (Categories | Shop Contents, an actions menu per
# item), rebuilt in our kit.
# Usage (from this folder): ruby editor_designs.rb "<KIF Beta>" <work dir with metrics.json>
SHSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "shop_designs.rb"), :encoding => "UTF-8")
eval(SHSRC.split("c = palette(2)\n")[0], binding, "shop_designs.rb")

CUSTOM = Color.new(130, 190, 250); WHITE = Color.new(248, 248, 248) unless defined?(WHITE)
CATS2 = [["POKEBALL", "Balls", 6], ["POTION", "Medicine", 9], ["PROTEIN", "Training", 12], ["FIRESTONE", "Evolution", 8],
         ["XATTACK", "Battle", 7], ["RARECANDY", "Special", 7], [:chest, "Bundles", 4]]
CSEL = 5
# [item, name, kif price, custom price, state]  state: :normal, :hidden, :added
ROWS = [["RARECANDY", "Rare Candy", 4800, 3500, :normal], ["MASTERBALL", "Master Ball", 50000, nil, :normal],
        ["MAXREPEL", "Max Repel", 700, nil, :normal], ["EVIOLITE", "Eviolite", 4000, nil, :normal],
        ["PPUP", "PP Up", 9800, nil, :normal], ["PPMAX", "PP Max", 24000, nil, :hidden],
        ["ABILITYCAPSULE", "Ability Capsule", nil, 10000, :added]]
RSEL = 0
def tag(t, x, y, s, fill, colr, right = true); P.pill(t, x, y, s, fill, colr, right); end
def row_price(c, t, x, y, w, kif, custom, state)
  if custom && kif
    strike(t, x, y, w - 74, money(kif), c[:dim]); P.text(t, x + w - 70, y, 70, 20, money(custom), CUSTOM, PF::TEXT, 1)
  elsif custom
    P.text(t, x, y, w, 20, money(custom), CUSTOM, PF::TEXT, 1)
  else
    P.text(t, x, y, w, 20, money(kif), state == :hidden ? c[:dim] : c[:txt], PF::TEXT, 1)
  end
end
def state_tag(t, x, y, state)
  case state
  when :hidden then tag(t, x, y, "HIDDEN", Color.new(40, 44, 56), Color.new(150, 160, 175))
  when :added then tag(t, x, y, "ADDED", Color.new(24, 60, 40), SALE)
  end
end
def ed_title(c, title = "RLD Shop Editor")
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
  P.text(t, 0, 2, W, 28, title, c[:title], PF::TITLE, 2)
end
# The price editor: KR's digit picker (one digit at a time)
def digit_picker(c, d, x, y, w, label, value, base)
  UI.rbox(d, x, y, x + w, y + 122, 8, col(c[:panel], 255), c[:selb])
  P.text(d, x, y + 6, w, 22, label, c[:title], PF::ROW, 2)
  d.fill_rect(x + 10, y + 32, w - 20, 1, c[:line])
  digits = format("%06d", value).chars
  dx0 = x + (w - (6 * 22 + 12)) / 2
  P.text(d, dx0 - 14, y + 44, 14, 24, "$", c[:txt], PF::ROW)
  digits.each_with_index do |ch, i|
    dx = dx0 + i * 22 + (i >= 3 ? 8 : 0)
    on = i == 2
    UI.rbox(d, dx, y + 42, dx + 18, y + 70, 4, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
    P.text(d, dx, y + 45, 18, 24, ch, on ? c[:white] : c[:txt], PF::ROW, 2)
    if on
      UI.tri(d, dx + 4, y + 34, :u, c[:selb], 4); UI.tri(d, dx + 4, y + 74, :d, c[:selb], 4)
    end
  end
  P.small(d, x + 12, y + 86, w - 24, 16, "KIF's Price: #{money(base)}", c[:dim])
  P.small(d, x + 12, y + 102, w - 24, 16, "X: Back to KIF's Price", c[:dim])
end

c = palette(2)

#================================================================ ED1 Recommended: old KR's two columns, rebuilt; an actions menu per item
def ed1(c)
  plain(c); b = BASE.bitmap; t = TOP.bitmap
  ed_title(c)
  UI.rbox(b, 6, 38, 160, 354, 6, c[:panel])
  P.text(t, 6, 40, 154, 16, "CATEGORIES", c[:dim], PF::TINY, 2)
  CATS2.each_with_index do |(ic, n, cnt), i|
    y = 58 + i * 28
    UI.rbox(b, 10, y, 156, y + 26, 5, c[:sel], c[:line]) if i == CSEL
    ic == :chest ? chest(t, "bundle", 26, y + 13, 14) : item(t, ic, 26, y + 13, 18)
    P.text(t, 42, y + 2, 90, 22, n, c[:txt], PF::TEXT)
    P.small(t, 120, y + 5, 30, 16, cnt.to_s, c[:dim], 1)
  end
  UI.rbox(b, 166, 38, 506, 354, 6, c[:panel], c[:selb])
  P.text(t, 166, 40, 340, 16, "SHOP CONTENTS", c[:head], PF::TINY, 2)
  ROWS.each_with_index do |(ic, n, kif, cus, st), i|
    y = 58 + i * 28
    cursor_at(170, y, 332, 27) if i == RSEL
    item(t, ic, 188, y + 13, 20)
    P.text(t, 204, y + 2, 140, 22, n, st == :hidden ? c[:dim] : c[:txt], PF::TEXT)
    state_tag(t, 404, y + 6, st)
    row_price(c, t, 330, y + 3, 168, kif, cus, st) unless st == :hidden
  end
  P.small(t, 176, 316, 320, 16, "Blue: Your Price. Shop changes are per save.", c[:dim])
  hints(c, [[:ud, "Choose"], [:lr, "Panels"], [A_BTN, "Actions"], [X_BTN, "Add"], ["p:6", "Files"], [B_BTN, "Back"]])
end
ed1(c); shot("ED1_list")
ed1(c); d = OVER.bitmap
d.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 110))
UI.rbox(d, 300, 60, 470, 248, 8, col(c[:panel], 255), c[:selb])
P.text(d, 300, 64, 170, 22, "Rare Candy", c[:title], PF::ROW, 2)
["Set Buy Price", "Set Sell Price", "Move Category", "Move Up", "Move Down", "Hide Item"].each_with_index do |a, k|
  y = 92 + k * 25
  UI.rbox(d, 306, y, 464, y + 23, 5, c[:sel], c[:selb]) if k == 0
  P.text(d, 316, y, 150, 23, a, k == 0 ? c[:white] : c[:txt], PF::TEXT)
end
digit_picker(c, d, 40, 150, 236, "Buy Price", 3500, 4800)
shot("ED1_price")

#================================================================ ED2: the editor beside a live preview of the shop
def ed2(c)
  plain(c); b = BASE.bitmap; t = TOP.bitmap
  ed_title(c)
  UI.rbox(b, 6, 38, 250, 354, 6, c[:panel], c[:selb])
  P.text(t, 6, 40, 244, 16, "SPECIAL", c[:head], PF::TINY, 2)
  UI.tri(t, 14, 42, :l, c[:dim], 4); UI.tri(t, 236, 42, :r, c[:dim], 4)
  ROWS.each_with_index do |(ic, n, kif, cus, st), i|
    y = 58 + i * 38
    cursor_at(10, y, 236, 37) if i == RSEL
    item(t, ic, 28, y + 18, 22)
    P.small(t, 44, y + 2, 130, 16, n, st == :hidden ? c[:dim] : c[:txt])
    P.small(t, 44, y + 19, 130, 16, st == :hidden ? "Hidden" : (st == :added ? "Added by You" : (cus ? "Your Price" : "KIF's Price")), st == :added ? SALE : (cus ? CUSTOM : c[:dim]))
    P.small(t, 160, y + 10, 80, 16, money(cus || kif), cus ? CUSTOM : c[:txt], 1)
  end
  UI.rbox(b, 262, 38, 506, 354, 6, c[:dark], c[:line])
  P.text(t, 262, 40, 244, 16, "PREVIEW", c[:dim], PF::TINY, 2)
  ROWS.reject { |x| x[4] == :hidden }.each_with_index do |(ic, n, kif, cus, st), i|
    y = 60 + i * 24
    item(t, ic, 280, y + 11, 16)
    P.small(t, 294, y + 3, 120, 16, n, c[:txt]); P.small(t, 420, y + 3, 78, 16, money(cus || kif), c[:txt], 1)
  end
end
ed2(c); hints(c, [[:ud, "Choose"], [:lr, "Category"], [A_BTN, "Edit"], [X_BTN, "Add"], [Y_BTN, "Hide"], [B_BTN, "Back"]]); shot("ED2_list")
ed2(c); d = OVER.bitmap
d.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 110))
digit_picker(c, d, 138, 120, 236, "Buy Price", 3500, 4800)
shot("ED2_price")

#================================================================ ED3: one table (item, category, buy, sell, shown), Import / Export / Reset as buttons
def ed3(c)
  plain(c); b = BASE.bitmap; t = TOP.bitmap
  ed_title(c)
  UI.rbox(b, 6, 38, 506, 300, 6, c[:panel])
  [["ITEM", 30, 0], ["CATEGORY", 190, 0], ["BUY", 330, 1], ["SELL", 410, 1], ["SHOWN", 447, 2]].each do |h, x, al|
    P.text(t, al == 1 ? x - 60 : x, 42, 60, 14, h, c[:head], PF::TINY, al == 1 ? 1 : (al == 2 ? 2 : 0))
  end
  ROWS.each_with_index do |(ic, n, kif, cus, st), i|
    y = 60 + i * 30
    cursor_at(10, y, 492, 29) if i == RSEL
    item(t, ic, 22, y + 14, 18)
    P.small(t, 34, y + 7, 150, 16, n, st == :hidden ? c[:dim] : c[:txt])
    P.small(t, 190, y + 7, 90, 16, "Special", c[:dim])
    P.small(t, 270, y + 7, 60, 16, money(cus || kif).sub(",000", "k"), cus ? CUSTOM : c[:txt], 1)
    P.small(t, 350, y + 7, 60, 16, money((cus || kif) / 2).sub(",000", "k").sub(",500", ".5k").sub(",750", ".75k"), c[:dim], 1)
    UI.rbox(b, 464, y + 8, 490, y + 22, 7, st == :hidden ? c[:dark] : SALE)
    UI.rbox(b, st == :hidden ? 466 : 478, y + 10, st == :hidden ? 476 : 488, y + 20, 5, WHITE)
  end
  [["Export", 6], ["Import", 172], ["Reset", 338]].each do |l, x|
    UI.rbox(b, x, 306, x + 160, 334, 6, c[:dark], l == "Reset" ? RED2 : c[:line])
    P.text(t, x, 308, 160, 24, l, l == "Reset" ? RED2 : c[:txt], PF::TEXT, 2)
  end
end
ed3(c); hints(c, [[:ud, "Choose"], [:lr, "Column"], [A_BTN, "Edit"], [X_BTN, "Add"], [B_BTN, "Back"]]); shot("ED3_list")
ed3(c); d = OVER.bitmap
d.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 110))
UI.rbox(d, 86, 84, 426, 254, 8, col(c[:panel], 255), c[:selb])
P.text(d, 86, 90, 340, 22, "Export Catalog", c[:title], PF::ROW, 2)
d.fill_rect(96, 116, 320, 1, c[:line])
P.small(d, 100, 124, 312, 16, "Saved to Exports:", c[:txt])
P.small(d, 100, 140, 312, 16, "ReloadedShopCatalog.json", CUSTOM)
P.small(d, 100, 160, 312, 16, "7 categories, 53 items, 4 custom prices.", c[:dim])
P.small(d, 100, 176, 312, 16, "Import it in another save to use it there.", c[:dim])
UI.rbox(d, 196, 208, 316, 234, 6, c[:sel], c[:selb]); P.text(d, 196, 210, 120, 22, "OK", c[:white], PF::TEXT, 2)
shot("ED3_export")

#================================================================ ED4: edit in place: the real RLD Shop with Edit Mode on
def ed4(c, moving)
  plain(c); b = BASE.bitmap; t = TOP.bitmap
  shop_bar(c, "Edit Mode")
  b.fill_rect(0, 30, W, 2, Color.new(240, 140, 90))
  cat_bar(c, 32, CATS, CSEL, "Special  6/7")
  money_box(c, W - 104, 34)
  order = moving ? [1, 0, 2, 3, 4, 5, 6] : (0...7).to_a
  order.each_with_index do |ri, i|
    ic, n, kif, cus, st = ROWS[ri]
    y = 62 + i * 25
    sel = moving ? ri == 0 : i == RSEL
    cursor_at(6, y, W - 12, 24) if sel
    if moving && ri == 0
      UI.tri(t, 10, y + 4, :u, c[:selb], 3); UI.tri(t, 10, y + 14, :d, c[:selb], 3)
    else
      3.times { |k| b.fill_rect(10, y + 8 + k * 4, 8, 2, c[:dim]) }
    end
    item(t, ic, 34, y + 12, 18)
    P.text(t, 50, y + 1, 180, 22, n, st == :hidden ? c[:dim] : c[:txt], PF::TEXT)
    state_tag(t, 330, y + 5, st)
    row_price(c, t, W - 200, y + 1, 186, kif, cus, st) unless st == :hidden
  end
  y0 = 244
  b.fill_rect(0, y0, W, 115, c[:panel2]); b.fill_rect(0, y0, W, 1, c[:line])
  P.text(t, 12, y0 + 4, 300, 22, moving ? "Moving Rare Candy" : "Rare Candy", c[:title], PF::ROW)
  P.small(t, 12, y0 + 28, 480, 16, moving ? "Up and down move it; A drops it here." : "A: Price.  X: Add.  Y: Hide.  RB: Move.  Select: Leave Edit Mode.", c[:txt])
end
ed4(c, false); hints(c, [[:ud, "Choose"], [A_BTN, "Price"], [X_BTN, "Add"], [Y_BTN, "Hide"], [B_BTN, "Done"]]); shot("ED4_list")
ed4(c, true); hints(c, [[:ud, "Move"], [A_BTN, "Drop"], [B_BTN, "Cancel"]]); shot("ED4_move")

#================================================================ ED5: the Settings layout (categories as sections, items as rows with value cells)
def ed5(c)
  plain(c); b = BASE.bitmap; t = TOP.bitmap
  ed_title(c)
  UI.rbox(b, 6, 38, 150, 354, 6, c[:panel])
  CATS2.each_with_index do |(ic, n, cnt), i|
    y = 44 + i * 30
    UI.rbox(b, 10, y, 146, y + 26, 5, c[:sel], c[:selb]) if i == CSEL
    ic == :chest ? chest(t, "bundle", 26, y + 13, 14) : item(t, ic, 26, y + 13, 18)
    P.text(t, 42, y + 2, 100, 22, n, i == CSEL ? c[:white] : c[:txt], PF::TEXT)
  end
  P.heading(t, 164, W - 12, 42, "Special", c[:head], c[:line])
  ROWS.each_with_index do |(ic, n, kif, cus, st), i|
    y = 58 + i * 34
    cursor_at(158, y, W - 166, 33) if i == RSEL
    item(t, ic, 176, y + 16, 18)
    P.text(t, 192, y + 5, 150, 22, n, st == :hidden ? c[:dim] : c[:opt], PF::TEXT)
    state_tag(t, 374, y + 9, st)
    unless st == :hidden
      UI.rbox(b, 380, y + 6, 496, y + 28, 5, c[:dark], cus ? CUSTOM : c[:line])
      P.text(t, 380, y + 7, 116, 20, money(cus || kif), cus ? CUSTOM : c[:txt], PF::TEXT, 2)
    end
  end
end
ed5(c); hints(c, [[:ud, "Select"], [:lr, "Change"], [A_BTN, "Edit"], ["p:2", "Default"], [B_BTN, "Sections"]]); shot("ED5_list")
ed5(c); d = OVER.bitmap
UI.rbox(d, 380, 84, 496, 236, 6, col(c[:panel], 255), c[:selb])
[["Your Price", "$3,500"], ["KIF's Price", "$4,800"], ["Free", ""], ["Hide Item", ""]].each_with_index do |(l, v), k|
  y = 88 + k * 36
  UI.rbox(d, 384, y, 492, y + 32, 5, c[:sel], c[:selb]) if k == 0
  P.small(d, 390, y + 2, 100, 16, l, k == 0 ? c[:white] : c[:txt])
  P.small(d, 390, y + 16, 100, 16, v, k == 0 ? CUSTOM : c[:dim]) unless v.empty?
end
shot("ED5_dropdown")
