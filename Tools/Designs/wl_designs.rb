# encoding: utf-8
# Mockups: Wild Link (topic 23), five designs, each two screens:
#  - the Wild Link screen (now also the DexNav: the area's encounters with
#    rates and levels, Seen / Caught), Route 24's real Land table
#    (Data/encounters.dat): Abra 20%, Caterpie, Pidgey, Weedle 15%, Oddish 13%,
#    Bellsprout 12%, Kakuna, Metapod 5%; its Poke Radar species Buneary as the
#    locked Rare Signal; Sunny now, so Weather Signals mark Oddish/Bellsprout;
#  - the overworld: the Abra target (curious: PIF's ? reaction) and the new
#    Chain HUD.
# Abra: Search Level 34, Chain 12 -> old KR's tables: Shiny +2 rolls, 15% one
# perfect IV, Hidden Ability 10%, Egg Move 25%, item roll 15%, level +0-2.
# Design 1 = old KR's Wild Link (header with method tabs, list, details),
# rebuilt in our kit.
# Usage (from this folder): ruby wl_designs.rb "<KIF Beta>" <work dir with metrics.json>
WXSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "wx_designs.rb"), :encoding => "UTF-8")
eval(WXSRC.split("wx1(c, false)\n")[0], binding, "wx_designs.rb")

GOLD2 = Color.new(240, 200, 70); GREEN2 = Color.new(120, 230, 150); RED2 = Color.new(240, 100, 90)
WL = File.join(HERE, "wl")
# [species, name, levels, rate, state, boosted rate]
ROWS = [["ABRA", "Abra", "8-12", "20%", :caught, nil], ["CATERPIE", "Caterpie", "7", "15%", :caught, nil],
        ["PIDGEY", "Pidgey", "11-13", "15%", :caught, nil], ["WEEDLE", "Weedle", "7", "15%", :seen, nil],
        ["ODDISH", "Oddish", "12-14", "13%", :caught, "18%"], ["BELLSPROUT", "Bellsprout", "12-14", "12%", :seen, "17%"],
        ["KAKUNA", "Kakuna", "8", "5%", :seen, nil], ["METAPOD", "???", "8", "5%", :unseen, nil],
        ["BUNEARY", "Rare Signal", "12-13", "", :rare, nil]]
SL_INFO = [[1, "Target Level"], [5, "Temperament"], [10, "Perfect IVs"], [15, "Held Item"], [20, "Ability"], [25, "Egg Moves"], [50, "Signal Location"]]
BONUS = [["Shiny", "+2 Rolls"], ["Perfect IV", "15%"], ["Hidden Ability", "10%"], ["Egg Move", "25%"], ["Item Roll", "15%"], ["Level", "+0-2"]]
METHODS = ["LAND", "SURF", "FISHING"]

def ow(c, name = "ow_curious.png"); frame(c, false); clear_over; MAPS.bitmap = Bitmap.new(File.join(WL, name)); end
def mon(b, sp, cx, cy, size, state = :caught)
  path = [:unseen, :rare].include?(state) ? File.join(WL, "#{sp}_sil.png") : File.join(GFX, "Pokemon/Icons/#{sp}.png")
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(path), Rect.new(0, 0, 64, 64))
end
def full(b, sp, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(File.join(WL, "#{sp}_full.png")), Rect.new(0, 0, 96, 96))
end
def caught_ball(t, x, y); P.poke_ball(t, x, y, 11); end
def sun_mark(t, x, y); wicon(t, :Sun, 5, x, y, 18); end
def method_tabs(c, b, t, x, y)
  METHODS.each_with_index do |m, i|
    w = P.width(PF::TINY, m) + 16
    UI.rbox(b, x, y, x + w, y + 17, 5, i == 0 ? c[:sel] : c[:dark], i == 0 ? c[:selb] : c[:line])
    P.text(t, x, y + 1, w, 16, m, i == 0 ? c[:white] : c[:dim], PF::TINY, 2)
    x += w + 4
  end
  x
end
def weather_chip(t, x, y, right = true); P.pill(t, x, y, "SUNNY", Color.new(70, 46, 10), Color.new(250, 190, 80), right); end
def row_name_color(c, st); st == :rare ? GOLD2 : (st == :unseen ? c[:dim] : c[:txt]); end
def sl_bar(b, x, y, w, sl, nxt, c)
  b.fill_rect(x, y, w, 6, c[:dark]); b.fill_rect(x, y, (w * sl / nxt.to_f).round, 6, c[:selb])
end
def hud(c, x, y, w = 196)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + 44, 8, c[:panel], c[:line])
  mon(t, "ABRA", x + 22, y + 22, 40)
  P.text(t, x + 44, y + 1, 90, 24, "Abra", c[:txt], PF::TEXT)
  P.small(t, x + 44, y + 23, 90, 16, "Chain 12", GOLD2)
  P.small(t, x + w - 96, y + 4, 88, 16, "SL 34", c[:dim], 1)
  P.small(t, x + w - 96, y + 23, 88, 16, "Shiny +2", GREEN2, 1)
end
def shot(name); dump_as(name); end

c = palette(2)

#================================================================ WL1 Recommended: old KR's Wild Link, rebuilt (and the DexNav)
blank(c)
b = BASE.bitmap; t = TOP.bitmap
P.text(t, 0, 4, W, 24, "Wild Link", c[:title], PF::ROW, 2)
method_tabs(c, b, t, 10, 32)
weather_chip(t, W - 10, 33)
P.small(t, 200, 33, 200, 16, "Seen 7/9   Caught 4/9", c[:dim], 2)
UI.rbox(b, 8, 56, 318, 354, 8, c[:panel], c[:line])
ROWS.each_with_index do |(sp, n, lv, rate, st, boost), i|
  y = 62 + i * 29
  cursor_at(12, y, 302, 28) if i == 0
  mon(t, sp, 30, y + 14, 34, st)
  caught_ball(t, 50, y + 8) if st == :caught
  P.text(t, 66, y + 2, 120, 24, n, row_name_color(c, st), PF::TEXT)
  P.small(t, 176, y + 6, 70, 16, st == :rare ? "Locked" : "Lv. #{lv}", st == :rare ? GOLD2 : c[:dim])
  if boost
    sun_mark(t, 262, y + 14); P.small(t, 270, y + 6, 40, 16, boost, GREEN2, 1)
  else
    P.small(t, 260, y + 6, 50, 16, rate, c[:dim], 1)
  end
end
UI.rbox(b, 326, 56, 504, 354, 8, c[:panel], c[:line])
full(t, "ABRA", 415, 106, 96)
P.text(t, 326, 146, 178, 24, "Abra", c[:title], PF::ROW, 2)
P.small(t, 326, 168, 178, 16, "Caught", GREEN2, 2)
P.small(t, 336, 188, 90, 16, "Search Level", c[:dim]); P.small(t, 430, 188, 64, 16, "34", c[:txt], 1)
sl_bar(b, 336, 206, 158, 34, 50, c)
P.small(t, 336, 214, 90, 16, "Chain", c[:dim]); P.small(t, 430, 214, 64, 16, "12", GOLD2, 1)
P.heading(t, 336, 494, 236, "SL Info", c[:head], c[:line])
SL_INFO.each_with_index do |(lv, lbl), k|
  y = 250 + k * 14
  on = lv <= 34
  P.text(t, 336, y, 40, 14, "SL #{lv}", on ? GREEN2 : c[:dim], PF::TINY)
  P.small(t, 376, y - 1, 120, 14, lbl, on ? c[:txt] : c[:dim])
end
hints(c, [[:ud, "Choose"], [:lr, "Method"], [A_BTN, "Search"], [X_BTN, "Bonuses"], [B_BTN, "Back"]])
shot("WL1_screen")
ow(c); hud(c, 8, 8)
shot("WL1_target")

#================================================================ WL2: a DexNav-style grid of icons, details along the bottom
blank(c)
b = BASE.bitmap; t = TOP.bitmap
P.text(t, 0, 4, W, 24, "Wild Link", c[:title], PF::ROW, 2)
method_tabs(c, b, t, 10, 32)
weather_chip(t, W - 10, 33)
P.small(t, 200, 33, 200, 16, "Seen 7/9   Caught 4/9", c[:dim], 2)
ROWS.each_with_index do |(sp, n, lv, rate, st, boost), i|
  x = 10 + (i % 5) * 99; y = 58 + (i / 5) * 96
  UI.rbox(b, x, y, x + 92, y + 88, 8, st == :rare ? Color.new(60, 48, 14) : c[:panel], st == :rare ? GOLD2 : c[:line])
  cursor_at(x - 2, y - 2, 96, 92) if i == 0
  mon(t, sp, x + 46, y + 36, 56, st)
  caught_ball(t, x + 6, y + 6) if st == :caught
  sun_mark(t, x + 80, y + 12) if boost
  P.small(t, x, y + 66, 92, 16, st == :rare ? "Rare Signal" : (st == :unseen ? "???" : (boost || rate)), st == :rare ? GOLD2 : (boost ? GREEN2 : c[:dim]), 2)
end
UI.rbox(b, 8, 252, 504, 354, 8, c[:panel], c[:line])
full(t, "ABRA", 48, 302, 76)
P.text(t, 88, 256, 140, 24, "Abra", c[:title], PF::ROW)
P.small(t, 88, 278, 140, 16, "Caught", GREEN2); P.small(t, 130, 278, 92, 16, "Lv. 8-12", c[:dim], 1)
P.small(t, 88, 298, 90, 16, "Search Level", c[:dim]); P.small(t, 182, 298, 40, 16, "34", c[:txt], 1)
sl_bar(b, 88, 316, 134, 34, 50, c)
P.small(t, 88, 324, 90, 16, "Chain", c[:dim]); P.small(t, 182, 324, 40, 16, "12", GOLD2, 1)
b.fill_rect(231, 262, 1, 82, c[:line])
P.heading(t, 240, 494, 262, "Current Bonuses", c[:head], c[:line])
[0, 1, 4, 2, 3, 5].each_with_index do |bi, k|
  l, v = BONUS[bi]
  x0, x1 = k < 3 ? [240, 356] : [368, 496]
  y = 280 + (k % 3) * 22
  P.small(t, x0, y, 110, 16, l, c[:dim]); P.small(t, x1 - 60, y, 60, 16, v, GREEN2, 1)
end
hints(c, [[:ud, ""], [:lr, "Choose"], [A_BTN, "Search"], [X_BTN, "SL Info"], [B_BTN, "Back"]])
shot("WL2_screen")
ow(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 126, 8, 386, 36, 8, c[:panel], c[:line])
mon(t, "ABRA", 146, 22, 30)
P.text(t, 166, 9, 210, 24, "Abra   Chain 12   Shiny +2", c[:txt], PF::TEXT)
shot("WL2_target")

#================================================================ WL3: every method at once in columns (the DexNav overview)
COLS = [["LAND", ROWS], ["SURF", [["PSYDUCK", "Psyduck", "20-40", "50%", :caught, nil], ["SLOWPOKE", "Slowpoke", "20-40", "50%", :seen, nil]]],
        ["FISHING", [["MAGIKARP", "Magikarp", "5", "Old", :caught, nil], ["POLIWAG", "Poliwag", "5-25", "All", :caught, nil],
                     ["GOLDEEN", "Goldeen", "5-15", "Good", :seen, nil], ["POLIWHIRL", "Poliwhirl", "20-30", "Super", :seen, nil],
                     ["GYARADOS", "Gyarados", "15-25", "Super", :seen, nil]]]]
blank(c)
b = BASE.bitmap; t = TOP.bitmap
P.text(t, 0, 4, W, 24, "Wild Link", c[:title], PF::ROW, 2)
weather_chip(t, W - 10, 10)
P.small(t, 10, 10, 160, 16, "Route 24", c[:dim])
COLS.each_with_index do |(m, rows), ci|
  x = 8 + ci * 166
  UI.rbox(b, x, 34, x + 160, 266, 8, c[:panel], ci == 0 ? c[:selb] : c[:line])
  P.text(t, x, 36, 160, 16, m, ci == 0 ? c[:head] : c[:dim], PF::TINY, 2)
  rows.each_with_index do |(sp, n, lv, rate, st, boost), i|
    y = 54 + i * 23
    cursor_at(x + 3, y, 154, 23) if ci == 0 && i == 0
    mon(t, sp, x + 16, y + 11, 26, st)
    P.small(t, x + 32, y + 3, 90, 16, n, row_name_color(c, st))
    sun_mark(t, x + 138, y + 11) if boost
    caught_ball(t, x + 142, y + 6) if st == :caught && !boost
  end
end
UI.rbox(b, 8, 274, 504, 354, 8, c[:panel], c[:line])
mon(t, "ABRA", 36, 312, 52)
P.text(t, 64, 280, 120, 24, "Abra", c[:title], PF::ROW)
P.small(t, 64, 304, 160, 16, "Land, Lv. 8-12, 20%", c[:dim])
P.small(t, 64, 324, 160, 16, "Caught", GREEN2)
P.small(t, 230, 282, 90, 16, "Search Level 34", c[:txt]); sl_bar(b, 230, 302, 120, 34, 50, c)
P.small(t, 230, 312, 90, 16, "Chain 12", GOLD2)
P.small(t, 370, 282, 126, 16, "Shiny +2 Rolls", GREEN2, 1)
P.small(t, 370, 302, 126, 16, "Hidden Ability 10%", c[:txt], 1)
P.small(t, 370, 322, 126, 16, "Egg Move 25%", c[:txt], 1)
hints(c, [[:ud, "Choose"], [:lr, "Method"], [A_BTN, "Search"], [X_BTN, "Bonuses"], [B_BTN, "Back"]])
shot("WL3_screen")
ow(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 8, 312, 236, 372, 8, c[:panel], c[:line])
mon(t, "ABRA", 34, 342, 40)
P.text(t, 58, 316, 176, 24, "Abra, Chain 12", c[:txt], PF::TEXT)
P.small(t, 58, 338, 176, 16, "Shiny +2. Curious.", GREEN2)
shot("WL3_target")

#================================================================ WL4: a big preview with the bonuses as chips
blank(c)
b = BASE.bitmap; t = TOP.bitmap
P.text(t, 0, 4, W, 24, "Wild Link", c[:title], PF::ROW, 2)
method_tabs(c, b, t, 10, 32)
weather_chip(t, W - 10, 33)
UI.rbox(b, 8, 56, 176, 354, 8, c[:panel], c[:line])
ROWS.each_with_index do |(sp, n, lv, rate, st, boost), i|
  y = 62 + i * 32
  cursor_at(12, y, 160, 31) if i == 0
  mon(t, sp, 30, y + 15, 30, st)
  P.small(t, 50, y + 7, 100, 16, n, row_name_color(c, st))
  sun_mark(t, 160, y + 15) if boost
end
UI.rbox(b, 184, 56, 504, 354, 8, c[:panel], c[:line])
full(t, "ABRA", 270, 150, 160)
P.text(t, 352, 66, 148, 24, "Abra", c[:title], PF::ROW)
P.small(t, 352, 90, 148, 16, "Caught. Lv. 8-12", c[:dim])
P.small(t, 352, 110, 148, 16, "Search Level 34", c[:txt]); sl_bar(b, 352, 130, 140, 34, 50, c)
P.small(t, 352, 140, 148, 16, "Next at SL 50", c[:dim])
P.small(t, 352, 164, 148, 16, "Chain 12", GOLD2)
P.small(t, 352, 184, 148, 16, "Curious", c[:txt])
x = 194; y = 240
BONUS.each do |l, v|
  s = "#{l} #{v}"
  w = P.width(PF::TINY, s.upcase) + 12
  if x + w > 496 then x = 194; y += 22 end
  P.pill(t, x, y, s.upcase, Color.new(24, 60, 40), GREEN2, false)
  x += w + 6
end
P.small(t, 194, 316, 300, 16, "Searching more raises every bonus.", c[:dim])
hints(c, [[:ud, "Choose"], [:lr, "Method"], [A_BTN, "Search"], [X_BTN, "SL Info"], [B_BTN, "Back"]])
shot("WL4_screen")
ow(c)
b = BASE.bitmap; t = TOP.bitmap
hud(c, 8, 8, 196)
x = 10; [["SHINY +2"], ["HA 10%"], ["EGG 25%"]].each { |(s)| x += P.pill(t, x, 58, s, Color.new(24, 60, 40), GREEN2, false) + 4 }
shot("WL4_target")

#================================================================ WL5: a side panel over the overworld (no full screen)
ow(c, "ow_curious.png")
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 8, 8, 228, 352, 8, col(c[:panel], 250), c[:line])
P.text(t, 8, 12, 220, 24, "Wild Link", c[:title], PF::ROW, 2)
weather_chip(t, 220, 16)
x = method_tabs(c, b, t, 16, 40)
ROWS.first(7).each_with_index do |(sp, n, lv, rate, st, boost), i|
  y = 64 + i * 26
  cursor_at(12, y, 212, 25) if i == 0
  mon(t, sp, 30, y + 12, 26, st)
  P.small(t, 48, y + 5, 100, 16, n, row_name_color(c, st))
  boost ? sun_mark(t, 206, y + 12) : P.small(t, 150, y + 5, 66, 16, rate, c[:dim], 1)
end
b.fill_rect(18, 250, 200, 1, c[:line])
P.small(t, 18, 256, 120, 16, "Search Level 34", c[:txt]); sl_bar(b, 18, 274, 200, 34, 50, c)
P.small(t, 18, 282, 120, 16, "Chain 12", GOLD2); P.small(t, 118, 282, 100, 16, "Shiny +2", GREEN2, 1)
P.small(t, 18, 302, 200, 16, "Curious. Lv. 8-12.", c[:dim])
hints(c, [[:ud, "Choose"], [:lr, "Method"], [A_BTN, "Search"], [B_BTN, "Close"]])
shot("WL5_screen")
ow(c, "ow_skittish.png"); hud(c, 8, 8)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 8, 56, 204, 78, 6, c[:panel], c[:line])
P.small(t, 8, 59, 196, 16, "Skittish: It may run.", Color.new(250, 190, 80), 2)
shot("WL5_target")
