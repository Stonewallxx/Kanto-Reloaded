# encoding: utf-8
# Mockups: Summary and Big Icons (topic 27), part 1: the Stats page. Five
# designs, each two screens: the stats table, then the new Stat Hexagon.
# Lapras Lv. 32, Modest (+Sp. Atk, -Attack), Water/Ice, Water Absorb;
# base 130/85/80/85/95/60 (535); IVs 28/12/20/31/25/18; EVs 52/0/12/128/20/8;
# stats 138/56/63/87/75/49. Hidden Power Electric, Friendship 180.
# Weak: Electric, Grass, Fighting, Rock (x2). Resists: Water (x1/2), Ice (x1/4).
# Design 1 = HR's Reloaded stats page (header, Additional, Stats table with
# Base / IV / EV / BST, Ability, Weakness), rebuilt in our kit.
# Usage (from this folder): ruby stats_designs.rb "<KIF Beta>" <work dir with metrics.json>
PRSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "prism_designs.rb"), :encoding => "UTF-8")
eval(PRSRC.split("c = palette(2)\n")[0], binding, "prism_designs.rb")

STATS = [["HP", 138, 130, 28, 52, 0], ["Attack", 56, 85, 12, 0, -1], ["Defense", 63, 80, 20, 12, 0],
         ["Sp. Atk", 87, 85, 31, 128, 1], ["Sp. Def", 75, 95, 25, 20, 0], ["Speed", 49, 60, 18, 8, 0]]
IVC = Color.new(178, 132, 244); EVC = Color.new(120, 230, 150); BSC = Color.new(80, 218, 230)
UPC = Color.new(240, 110, 100); DNC = Color.new(110, 160, 250)
WEAK = [[13, "x2"], [12, "x2"], [1, "x2"], [5, "x2"]]
RES = [[11, "1/2"], [15, "1/4"]]
def tbadge(b, id, x, y, w = 48, h = 21)
  b.stretch_blt(Rect.new(x, y, w, h), bmp(File.join(GFX, "Pictures/types.png")), Rect.new(0, id * 28, 64, 28))
end
def ticon(b, id, x, y, s = 16)
  b.stretch_blt(Rect.new(x, y, s, s), bmp(File.join(GFX, "Pictures/Battle/typesSmall.png")), Rect.new(0, id * 19, 19, 19))
end
def tabs(c, sel)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 26, c[:panel2]); b.fill_rect(0, 25, W, 1, c[:line])
  ["INFO", "MEMO", "STATS", "MOVES", "RIBBONS"].each_with_index do |n, i|
    x = 100 + i * 64
    UI.rbox(b, x, 4, x + 60, 22, 5, i == sel ? c[:sel] : c[:dark], i == sel ? c[:selb] : c[:line])
    P.text(t, x, 5, 60, 16, n, i == sel ? c[:white] : c[:dim], PF::TINY, 2)
  end
  P.poke_ball(t, 10, 6, 13)
  P.text(t, 28, 3, 70, 20, "Lapras", c[:txt], PF::TEXT)
end
# ---- the hexagon: scanline fill, outlines and labels
def hex_pts(cx, cy, r, vals, maxv)
  vals.each_with_index.map do |v, i|
    a = -Math::PI / 2 + i * Math::PI / 3
    rr = r * [v.to_f / maxv, 1.0].min
    [cx + rr * Math.cos(a), cy + rr * Math.sin(a)]
  end
end
def poly_fill(b, pts, color)
  ys = pts.map { |p| p[1] }
  (ys.min.floor..ys.max.ceil).each do |y|
    xs = []
    pts.each_with_index do |p, i|
      q = pts[(i + 1) % pts.length]
      y0, y1 = p[1], q[1]
      next if y0 == y1
      next unless (y >= [y0, y1].min) && (y < [y0, y1].max)
      xs << p[0] + (y - y0) * (q[0] - p[0]) / (y1 - y0)
    end
    xs.sort!
    xs.each_slice(2) { |a, z| b.fill_rect(a.round, y, (z - a).round + 1, 1, color) if z }
  end
end
def line(b, x0, y0, x1, y1, color, w = 1)
  n = [(x1 - x0).abs, (y1 - y0).abs].max.ceil
  (0..n).each { |k| f = n == 0 ? 0 : k.to_f / n; b.fill_rect((x0 + (x1 - x0) * f).round, (y0 + (y1 - y0) * f).round, w, w, color) }
end
def poly_line(b, pts, color, w = 1)
  pts.each_with_index { |p, i| q = pts[(i + 1) % pts.length]; line(b, p[0], p[1], q[0], q[1], color, w) }
end
def hexagon(c, cx, cy, r, layers, labels = true)
  b = BASE.bitmap; t = TOP.bitmap
  [1.0, 0.66, 0.33].each { |f| poly_line(b, hex_pts(cx, cy, r * f, [1] * 6, 1), c[:line]) }
  hex_pts(cx, cy, r, [1] * 6, 1).each { |p| line(b, cx, cy, p[0], p[1], c[:line]) }
  layers.each do |vals, maxv, fill, edge|
    pts = hex_pts(cx, cy, r, vals, maxv)
    poly_fill(b, pts, fill); poly_line(b, pts, edge, 2)
  end
  return unless labels
  names = ["HP", "Atk", "Def", "Spe", "SpD", "SpA"]
  hex_pts(cx, cy, r + 16, [1] * 6, 1).each_with_index do |(x, y), i|
    st = { "Atk" => -1, "SpA" => 1 }[names[i]]
    P.text(t, x.round - 24, y.round - 8, 48, 16, names[i], st == 1 ? UPC : (st == -1 ? DNC : c[:txt]), PF::TINY, 2)
  end
end
ORDER = [0, 1, 2, 5, 4, 3]     # hexagon order: HP, Atk, Def, Spe, SpD, SpA
def vals(col); ORDER.map { |i| STATS[i][col] }; end
def nature_col(c, s); s == 1 ? UPC : (s == -1 ? DNC : c[:txt]); end
def header(c, x, y)
  t = TOP.bitmap; b = BASE.bitmap
  P.text(t, x, y, 160, 24, "Lapras", c[:title], PF::ROW)
  P.small(t, x, y + 24, 80, 16, "Lv. 32", c[:txt])
  tbadge(b, 11, x, y + 44); tbadge(b, 15, x + 52, y + 44)
end
def additional(c, x, y, w)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + 70, 8, c[:panel], c[:line])
  P.heading(t, x + 8, x + w - 8, y + 4, "Additional", c[:head], c[:line])
  P.small(t, x + 10, y + 20, 90, 16, "Hidden Power", c[:txt]); ticon(t, 13, x + w - 26, y + 20)
  P.small(t, x + 10, y + 36, 90, 16, "Friendship", c[:txt]); P.small(t, x + w - 60, y + 36, 50, 16, "180", Color.new(240, 140, 200), 1)
  P.small(t, x + 10, y + 52, 90, 16, "Fuse-Type", c[:txt]); P.small(t, x + w - 60, y + 52, 50, 16, "N/A", BSC, 1)
end
def ability(c, x, y, w, h = 58)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + h, 8, c[:panel], c[:line])
  P.heading(t, x + 8, x + w - 8, y + 4, "Ability", c[:head], c[:line])
  P.text(t, x + 10, y + 18, w - 20, 22, "Water Absorb", c[:txt], PF::TEXT)
  P.small(t, x + 10, y + 38, w - 20, 16, "Hidden: Hydration", c[:dim])
end
def weakness(c, x, y, w, h = 58)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + h, 8, c[:panel], c[:line])
  P.heading(t, x + 8, x + w - 8, y + 4, "Weakness", c[:head], c[:line])
  P.small(t, x + 10, y + 18, 56, 16, "Weak", c[:dim]); WEAK.each_with_index { |(id, _), k| ticon(t, id, x + 68 + k * 20, y + 18) }
  P.small(t, x + 10, y + 38, 56, 16, "Resists", c[:dim]); RES.each_with_index { |(id, m), k| ticon(t, id, x + 68 + k * 44, y + 38); P.small(t, x + 86 + k * 44, y + 38, 24, 16, m, c[:dim]) }
end
def table(c, x, y, w)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + 196, 8, c[:panel], c[:line])
  P.heading(t, x + 8, x + w - 8, y + 4, "Stats", c[:head], c[:line])
  cols = [["", x + 110], ["IV", x + 154], ["EV", x + 198], ["BASE", x + w - 12]]
  cols.each_with_index { |(h, cx), k| P.text(t, cx - 40, y + 20, 40, 14, h, [c[:txt], IVC, EVC, BSC][k], PF::TINY, 1) unless h.empty? }
  STATS.each_with_index do |(n, v, bs, iv, ev, nat), k|
    yy = y + 36 + k * 22
    P.text(t, x + 10, yy, 70, 20, n, nature_col(c, nat), PF::TEXT)
    P.text(t, x + 70, yy, 40, 20, v.to_s, c[:txt], PF::TEXT, 1)
    P.text(t, x + 114, yy, 40, 20, iv.to_s, iv == 31 ? GOLD : IVC, PF::TEXT, 1)
    P.text(t, x + 158, yy, 40, 20, ev.to_s, EVC, PF::TEXT, 1)
    P.text(t, x + w - 52, yy, 40, 20, bs.to_s, BSC, PF::TEXT, 1)
  end
  b.fill_rect(x + 8, y + 170, w - 16, 1, c[:line])
  P.small(t, x + 10, y + 174, 60, 16, "Total", c[:dim])
  P.small(t, x + 114, y + 174, 40, 16, "134", IVC, 1); P.small(t, x + 158, y + 174, 40, 16, "220", EVC, 1); P.small(t, x + w - 52, y + 174, 40, 16, "535", BSC, 1)
end
def hex_panel(c, x, y, w, h, mode = :all)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + h, 8, c[:panel], c[:line])
  P.heading(t, x + 8, x + w - 8, y + 4, "Stat Hexagon", c[:head], c[:line])
  cx = x + w / 2; cy = y + h / 2 + 8; r = [w, h].min / 2 - 34
  layers = [[vals(3), 31, Color.new(70, 52, 104), IVC], [vals(2), 150, Color.new(36, 96, 112), BSC]]
  layers = [[vals(2), 150, Color.new(36, 96, 112), BSC]] if mode == :base
  hexagon(c, cx, cy, r, layers)
  P.pill(t, x + 10, y + h - 20, "BASE", Color.new(20, 54, 60), BSC, false)
  P.pill(t, x + 54, y + h - 20, "IV", Color.new(44, 34, 64), IVC, false) unless mode == :base
end
H_SUM = [[:lr, "Pages"], [:ud, "Pokémon"], [Y_BTN, "Hexagon"], [B_BTN, "Back"]]

c = palette(2)

#================================================================ ST1 Recommended: HR's page, rebuilt; Y swaps the table for the hexagon
def st1(c, hex)
  blank(c); tabs(c, 2)
  b = BASE.bitmap; t = TOP.bitmap
  header(c, 14, 32)
  spr(t, "LAPRAS_base", 70, 150, 110)
  additional(c, 8, 214, 154)
  hex ? hex_panel(c, 170, 32, 334, 196) : table(c, 170, 32, 334)
  ability(c, 170, 236, 164, 72)
  weakness(c, 340, 236, 164, 72)
  UI.rbox(b, 8, 290, 162, 308, 5, c[:dark], c[:line]); P.small(t, 8, 291, 154, 16, "Modest: +SpA, -Atk", c[:dim], 2)
  UI.rbox(b, 8, 314, 504, 354, 8, c[:panel2], c[:line])
  P.small(t, 18, 318, 480, 16, "Water Absorb: Restores HP when hit by a Water-type move.", c[:txt])
  P.small(t, 18, 334, 480, 16, "Hidden Power: Electric.  Water/Ice.", c[:dim])
  hints(c, H_SUM)
end
st1(c, false); shot("ST1_table")
st1(c, true); shot("ST1_hex")

#================================================================ ST2: one wide table with value bars; the hexagon full width
def st2(c, hex)
  blank(c); tabs(c, 2)
  b = BASE.bitmap; t = TOP.bitmap
  spr(t, "LAPRAS_base", 52, 72, 72)
  P.text(t, 96, 34, 160, 24, "Lapras", c[:title], PF::ROW); P.small(t, 96, 58, 140, 16, "Lv. 32, Modest", c[:txt])
  tbadge(b, 11, 230, 40); tbadge(b, 15, 282, 40)
  P.small(t, 340, 42, 100, 16, "Hidden Power", c[:dim]); ticon(t, 13, 444, 42)
  if hex
    UI.rbox(b, 8, 96, 504, 354, 8, c[:panel], c[:line])
    hexagon(c, 160, 236, 88, [[vals(3), 31, Color.new(70, 52, 104), IVC], [vals(2), 150, Color.new(36, 96, 112), BSC]])
    hexagon(c, 380, 236, 88, [[vals(4), 252, Color.new(30, 80, 50), EVC]])
    P.text(t, 18, 102, 200, 16, "BASE AND IV", BSC, PF::TINY); P.text(t, 290, 102, 200, 16, "EV SPREAD", EVC, PF::TINY)
  else
    UI.rbox(b, 8, 96, 504, 354, 8, c[:panel], c[:line])
    ["", "VALUE", "IV", "EV", "BASE"].each_with_index { |h2, k| P.text(t, [20, 100, 330, 390, 450][k], 102, 50, 14, h2, [c[:txt], c[:txt], IVC, EVC, BSC][k], PF::TINY) }
    STATS.each_with_index do |(n, v, bs, iv, ev, nat), k|
      yy = 120 + k * 32
      P.text(t, 20, yy, 80, 22, n, nature_col(c, nat), PF::TEXT)
      P.text(t, 96, yy, 40, 22, v.to_s, c[:txt], PF::TEXT, 1)
      b.fill_rect(146, yy + 8, 170, 8, c[:dark]); b.fill_rect(146, yy + 8, (170 * v / 160.0).round, 8, nature_col(c, nat) == c[:txt] ? c[:selb] : nature_col(c, nat))
      P.text(t, 330, yy, 40, 22, iv.to_s, IVC, PF::TEXT); P.text(t, 390, yy, 40, 22, ev.to_s, EVC, PF::TEXT); P.text(t, 450, yy, 40, 22, bs.to_s, BSC, PF::TEXT)
    end
    P.small(t, 20, 316, 480, 16, "Ability: Water Absorb.  Weak: Electric, Grass, Fighting, Rock.", c[:dim])
  end
  hints(c, H_SUM)
end
st2(c, false); shot("ST2_table")
st2(c, true); shot("ST2_hex")

#================================================================ ST3: sub-tabs inside the page (Stats, Ability, Matchups)
def st3(c, sub)
  blank(c); tabs(c, 2)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 32, 176, 354, 8, c[:panel], c[:line])
  spr(t, "LAPRAS_base", 92, 110, 120)
  header(c, 20, 188)
  P.small(t, 20, 260, 150, 16, "Modest", c[:txt]); P.small(t, 20, 278, 150, 16, "+Sp. Atk, -Attack", c[:dim])
  ["STATS", "HEXAGON", "ABILITY", "MATCHUPS"].each_with_index do |n, i|
    x = 184 + i * 80
    UI.rbox(b, x, 32, x + 76, 50, 5, i == sub ? c[:sel] : c[:dark], i == sub ? c[:selb] : c[:line])
    P.text(t, x, 33, 76, 16, n, i == sub ? c[:white] : c[:dim], PF::TINY, 2)
  end
  if sub == 0
    table(c, 184, 56, 320)
  else
    hex_panel(c, 184, 56, 320, 296)
  end
  hints(c, [[:lr, "Pages"], ["p:9", ""], ["p:10", "Sub-Pages"], [B_BTN, "Back"]])
end
st3(c, 0); shot("ST3_table")
st3(c, 1); shot("ST3_hex")

#================================================================ ST4: six stat cards with mini bars
def st4(c, hex)
  blank(c); tabs(c, 2)
  b = BASE.bitmap; t = TOP.bitmap
  header(c, 14, 32)
  spr(t, "LAPRAS_base", 210, 74, 84)
  additional(c, 300, 32, 204)
  if hex
    hex_panel(c, 8, 110, 496, 244)
  else
    STATS.each_with_index do |(n, v, bs, iv, ev, nat), k|
      x = 8 + (k % 3) * 166; y = 110 + (k / 3) * 122
      UI.rbox(b, x, y, x + 160, y + 116, 8, c[:panel], nat == 1 ? UPC : (nat == -1 ? DNC : c[:line]))
      P.text(t, x + 10, y + 4, 90, 22, n, nature_col(c, nat), PF::TEXT)
      P.text(t, x + 90, y + 2, 60, 26, v.to_s, c[:txt], PF::ROW, 1)
      [["BASE", bs, 150, BSC], ["IV", iv, 31, IVC], ["EV", ev, 252, EVC]].each_with_index do |(l, val, mx, colr), j|
        yy = y + 36 + j * 24
        P.text(t, x + 10, yy, 36, 14, l, colr, PF::TINY)
        b.fill_rect(x + 46, yy + 4, 76, 6, c[:dark]); b.fill_rect(x + 46, yy + 4, (76 * [val.to_f / mx, 1].min).round, 6, colr)
        P.small(t, x + 124, yy - 2, 30, 16, val.to_s, colr, 1)
      end
    end
  end
  hints(c, H_SUM)
end
st4(c, false); shot("ST4_table")
st4(c, true); shot("ST4_hex")

#================================================================ ST5: a big sprite with the hexagon drawn behind it
def st5(c, hex)
  blank(c); tabs(c, 2)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 32, 250, 354, 8, c[:panel], c[:line])
  if hex
    hexagon(c, 129, 196, 92, [[vals(3), 31, Color.new(70, 52, 104), IVC], [vals(2), 150, Color.new(36, 96, 112), BSC]])
  else
    spr(t, "LAPRAS_base", 129, 190, 200)
  end
  P.text(t, 18, 38, 160, 24, "Lapras", c[:title], PF::ROW); P.small(t, 18, 62, 120, 16, "Lv. 32", c[:txt])
  tbadge(b, 11, 140, 40); tbadge(b, 15, 192, 40)
  table(c, 258, 32, 246)
  ability(c, 258, 236, 246, 56)
  weakness(c, 258, 296, 246, 58)
  hints(c, H_SUM)
end
st5(c, false); shot("ST5_table")
st5(c, true); shot("ST5_hex")
