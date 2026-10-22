# encoding: utf-8
# Mockups: Summary, part 2: the Fusion Breakdown (new). Five designs, each two
# screens: what the head and body each give a fusion. Genras = Gengar head +
# Lapras body (PIF's name and autogen sprite). PIF's rules: the head gives
# 2/3 of HP, Sp. Atk, Sp. Def; the body 2/3 of Attack, Defense, Speed; type 1
# from the head, type 2 from the body.
# Head Gengar 60/65/60/130/75/110, body Lapras 130/85/80/85/95/60,
# Genras 83/78/73/115/82/77 (508), Ghost/Ice.
# Design 1 = three columns (Head, Genras, Body) in the chosen Stats page's look.
# Usage (from this folder): ruby fusion_designs.rb "<KIF Beta>" <work dir with metrics.json>
STSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "stats_designs.rb"), :encoding => "UTF-8")
eval(STSRC.split("c = palette(2)\n")[0], binding, "stats_designs.rb")

HEADC = Color.new(190, 130, 240); BODYC = Color.new(110, 170, 250)
# [stat, head, body, fused, from]
FS = [["HP", 60, 130, 83, :head], ["Attack", 65, 85, 78, :body], ["Defense", 60, 80, 73, :body],
      ["Sp. Atk", 130, 85, 115, :head], ["Sp. Def", 75, 95, 82, :head], ["Speed", 110, 60, 77, :body]]
def spr2(b, file, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(File.join(SH, file + ".png")), Rect.new(0, 0, 96, 96))
end
def fcol(from); from == :head ? HEADC : BODYC; end
def ftabs(c); tabs(c, 2); TOP.bitmap.fill_rect(26, 2, 72, 22, CLEAR); P.text(TOP.bitmap, 28, 3, 70, 20, "Genras", c[:txt], PF::TEXT); end
def name_row(c, x, y)
  t = TOP.bitmap
  P.text(t, x, y, 60, 24, "Gen", HEADC, PF::ROW)
  P.text(t, x + P.width(PF::ROW, "Gen"), y, 60, 24, "ras", BODYC, PF::ROW)
end
def types_abil(c, x, y, w)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + 120, 8, c[:panel], c[:line])
  P.heading(t, x + 8, x + w - 8, y + 4, "Types and Abilities", c[:head], c[:line])
  tbadge(b, 7, x + 12, y + 22); P.small(t, x + 66, y + 24, 140, 16, "Type 1, from Gengar", HEADC)
  tbadge(b, 15, x + 12, y + 46); P.small(t, x + 66, y + 48, 140, 16, "Type 2, from Lapras", BODYC)
  P.small(t, x + 12, y + 74, 120, 16, "Cursed Body", c[:txt]); P.small(t, x + 128, y + 74, w - 140, 16, "Gengar (Head)", HEADC)
  P.small(t, x + 12, y + 94, 120, 16, "Water Absorb", c[:txt]); P.small(t, x + 128, y + 94, w - 140, 16, "Lapras (Body)", BODYC)
end
H_F = [[:lr, "Pages"], [:ud, "Pokémon"], [Y_BTN, "Swap View"], [B_BTN, "Back"]]

c = palette(2)

#================================================================ FB1 Recommended: three columns, the giving part lit; types and abilities below
def fb1(c, second)
  blank(c); ftabs(c)
  b = BASE.bitmap; t = TOP.bitmap
  [["GENGAR_base", "Gengar", "HEAD", 70, HEADC], ["GENRAS_auto", nil, nil, 256, c[:title]], ["LAPRAS_base", "Lapras", "BODY", 442, BODYC]].each do |s, n, role, cx, colr|
    spr2(t, s, cx, 70, s == "GENRAS_auto" ? 88 : 64)
    if n
      P.text(t, cx - 60, 104, 120, 22, n, colr, PF::TEXT, 2); P.text(t, cx - 60, 124, 120, 14, role, colr, PF::TINY, 2)
    else
      name_row(c, cx - 30, 108)
    end
  end
  if second
    types_abil(c, 8, 146, 496)
    UI.rbox(b, 8, 272, 504, 354, 8, c[:panel2], c[:line])
    P.small(t, 18, 278, 480, 16, "The head gives HP, Sp. Atk, Sp. Def and type 1.", HEADC)
    P.small(t, 18, 296, 480, 16, "The body gives Attack, Defense, Speed and type 2.", BODYC)
    P.small(t, 18, 320, 480, 16, "Swapped (Lapras head) it would be Lapgar: Water/Poison.", c[:dim])
  else
    UI.rbox(b, 8, 146, 504, 354, 8, c[:panel], c[:line])
    P.heading(t, 18, 494, 150, "Base Stats", c[:head], c[:line])
    FS.each_with_index do |(n, h, bo, f, from), k|
      y = 170 + k * 26
      P.text(t, 20, y, 90, 22, n, c[:txt], PF::TEXT)
      P.text(t, 110, y, 50, 22, h.to_s, from == :head ? HEADC : c[:dim], PF::TEXT, 2)
      P.text(t, 230, y, 50, 22, f.to_s, c[:white], PF::TEXT, 2)
      P.text(t, 416, y, 50, 22, bo.to_s, from == :body ? BODYC : c[:dim], PF::TEXT, 2)
      UI.tri(t, from == :head ? 176 : 316, y + 6, from == :head ? :r : :l, fcol(from), 5)
      b.fill_rect(from == :head ? 162 : 290, y + 10, 24, 3, fcol(from))
    end
    b.fill_rect(18, 328, 476, 1, c[:line])
    P.small(t, 20, 332, 100, 16, "Total", c[:dim]); P.small(t, 110, 332, 50, 16, "500", c[:dim], 2); P.small(t, 230, 332, 50, 16, "508", c[:white], 2); P.small(t, 416, 332, 50, 16, "535", c[:dim], 2)
  end
  hints(c, H_F)
end
fb1(c, false); shot("FB1_stats")
fb1(c, true); shot("FB1_types")

#================================================================ FB2: each stat bar split by how much the head and body give
def fb2(c, second)
  blank(c); ftabs(c)
  b = BASE.bitmap; t = TOP.bitmap
  spr2(t, "GENRAS_auto", 60, 80, 96)
  name_row(c, 120, 36); P.small(t, 120, 62, 200, 16, "Gengar Head, Lapras Body", c[:dim])
  tbadge(b, 7, 120, 84); tbadge(b, 15, 172, 84)
  if second
    types_abil(c, 8, 138, 496)
  else
    UI.rbox(b, 8, 138, 504, 354, 8, c[:panel], c[:line])
    P.pill(t, 18, 146, "HEAD", Color.new(50, 34, 64), HEADC, false); P.pill(t, 62, 146, "BODY", Color.new(26, 44, 64), BODYC, false)
    FS.each_with_index do |(n, h, bo, f, from), k|
      y = 170 + k * 28
      P.text(t, 20, y, 90, 22, n, c[:txt], PF::TEXT)
      hw = (from == :head ? 2 * h : h) / 3.0; bw = (from == :body ? 2 * bo : bo) / 3.0
      sc = 1.9
      b.fill_rect(110, y + 6, (hw * sc).round, 10, HEADC); b.fill_rect(110 + (hw * sc).round, y + 6, (bw * sc).round, 10, BODYC)
      P.text(t, 420, y, 70, 22, f.to_s, c[:white], PF::TEXT, 1)
    end
  end
  hints(c, H_F)
end
fb2(c, false); shot("FB2_stats")
fb2(c, true); shot("FB2_types")

#================================================================ FB3: the three sprites big, stats as rows under each
def fb3(c, second)
  blank(c); ftabs(c)
  b = BASE.bitmap; t = TOP.bitmap
  [["GENGAR_base", "Gengar", HEADC, 8], ["GENRAS_auto", "Genras", c[:white], 176], ["LAPRAS_base", "Lapras", BODYC, 344]].each_with_index do |(s, n, colr, x), k|
    UI.rbox(b, x, 32, x + 160, 354, 8, c[:panel], k == 1 ? GOLD : c[:line])
    spr2(t, s, x + 80, 96, 104)
    k == 1 ? name_row(c, x + 50, 150) : P.text(t, x, 150, 160, 24, n, colr, PF::ROW, 2)
    if second
      [[7, 3], [7, 15], [11, 15]][k].each_with_index { |id, j| tbadge(b, id, x + 30 + j * 52, 182) }
      P.small(t, x + 8, 214, 144, 16, ["Cursed Body", "Cursed Body", "Water Absorb"][k], c[:txt], 2)
      P.small(t, x + 8, 232, 144, 16, ["", "Water Absorb", ""][k], c[:txt], 2)
    else
      FS.each_with_index do |(n2, h, bo, f, from), j|
        y = 180 + j * 24
        v = [h, f, bo][k]
        lit = (k == 0 && from == :head) || (k == 2 && from == :body) || k == 1
        P.small(t, x + 12, y, 70, 16, n2, lit ? c[:txt] : c[:dim]); P.small(t, x + 100, y, 48, 16, v.to_s, k == 1 ? c[:white] : (lit ? colr : c[:dim]), 1)
      end
    end
  end
  hints(c, H_F)
end
fb3(c, false); shot("FB3_stats")
fb3(c, true); shot("FB3_types")

#================================================================ FB4: head, body and fusion as overlaid hexagons
def fb4(c, second)
  blank(c); ftabs(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 32, 300, 354, 8, c[:panel], c[:line])
  order = [0, 1, 2, 5, 4, 3]
  hv = order.map { |i| FS[i][1] }; bv = order.map { |i| FS[i][2] }; fv = order.map { |i| FS[i][3] }
  hexagon(c, 154, 196, 110, [[hv, 140, Color.new(60, 40, 80), HEADC], [bv, 140, Color.new(30, 50, 80), BODYC], [fv, 140, Color.new(70, 70, 90), WHITE]].first(second ? 3 : 3))
  P.pill(t, 18, 334, "GENGAR", Color.new(50, 34, 64), HEADC, false); P.pill(t, 84, 334, "LAPRAS", Color.new(26, 44, 64), BODYC, false); P.pill(t, 150, 334, "GENRAS", Color.new(50, 50, 60), WHITE, false)
  spr2(t, "GENRAS_auto", 400, 90, 96)
  name_row(c, 370, 140)
  if second
    types_abil(c, 308, 172, 196)
  else
    UI.rbox(b, 308, 172, 504, 354, 8, c[:panel], c[:line])
    FS.each_with_index do |(n, h, bo, f, from), k|
      y = 180 + k * 26
      P.small(t, 318, y, 70, 16, n, c[:txt]); P.small(t, 384, y, 40, 16, f.to_s, c[:white], 1)
      P.small(t, 430, y, 70, 16, from == :head ? "Head" : "Body", fcol(from), 1)
    end
  end
  hints(c, H_F)
end
fb4(c, false); shot("FB4_stats")
fb4(c, true); shot("FB4_types")

#================================================================ FB5: this fusion beside the swapped one (which way round is better)
def fb5(c, second)
  blank(c); ftabs(c)
  b = BASE.bitmap; t = TOP.bitmap
  [["GENRAS_auto", "Genras", "Gengar Head", [7, 15], [83, 78, 73, 115, 82, 77]], ["LAPGAR_auto", "Lapgar", "Lapras Head", [11, 3], [107, 72, 67, 100, 88, 93]]].each_with_index do |(s, n, sub, ty, st), k|
    x = 8 + k * 250
    UI.rbox(b, x, 32, x + 246, 354, 8, c[:panel], k == 0 ? GOLD : c[:line])
    spr2(t, s, x + 50, 80, 80)
    P.text(t, x + 96, 40, 140, 24, n, k == 0 ? c[:title] : c[:dim], PF::ROW)
    P.small(t, x + 96, 64, 140, 16, k == 0 ? "This One" : "Swapped", k == 0 ? GOLD : c[:dim])
    ty.each_with_index { |id, j| tbadge(b, id, x + 96 + j * 52, 86) }
    if second
      P.small(t, x + 12, 134, 222, 16, sub, c[:txt])
      P.small(t, x + 12, 156, 222, 16, "Weak:", c[:dim])
      P.small(t, x + 12, 172, 222, 16, k == 0 ? "Ghost, Dark, Fire, Rock, Steel" : "Electric, Ground, Psychic", c[:txt])
      P.small(t, x + 12, 194, 222, 16, k == 0 ? "Immune:" : "Resists:", c[:dim])
      P.small(t, x + 12, 210, 222, 16, k == 0 ? "Normal, Fighting" : "Fire, Water, Ice, Bug", c[:txt])
      P.small(t, x + 12, 232, 222, 16, "Abilities:", c[:dim])
      P.small(t, x + 12, 248, 222, 16, k == 0 ? "Cursed Body, Water Absorb" : "Water Absorb, Cursed Body", c[:txt])
    else
      FS.each_with_index do |(n2, *_), j|
        y = 134 + j * 26
        better = st[j] > [[83, 78, 73, 115, 82, 77], [107, 72, 67, 100, 88, 93]][1 - k][j]
        P.text(t, x + 12, y, 100, 22, n2, c[:txt], PF::TEXT); P.text(t, x + 160, y, 70, 22, st[j].to_s, better ? GREEN : c[:dim], PF::TEXT, 1)
      end
      P.small(t, x + 12, 300, 222, 16, "Total #{st.sum}", c[:txt])
    end
  end
  hints(c, H_F)
end
fb5(c, false); shot("FB5_stats")
fb5(c, true); shot("FB5_types")
