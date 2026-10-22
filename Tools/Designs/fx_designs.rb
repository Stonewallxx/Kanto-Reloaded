# encoding: utf-8
# Mockups: four Move Effectiveness designs over PIF's own Fight menu, each as
# two screens: singles (Pikachu vs a wild Gyarados: x4, x1/2, x0, x1) and
# doubles (Pikachu + Lapras vs Gyarados + Onix) with Discharge highlighted:
# x4 on Gyarados, x0 on Onix, and the new Ally Warning (x2 on our Lapras).
# Design 1 = old KR's coloured borders (6 levels) with cody's per-foe lines.
# Usage (from this folder): ruby fx_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "bmenu_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "bmenu_designs.rb")

FY = H - 96
# [name, type id, pp, singles level, doubles levels [Gyarados, Onix], spread?]
MOVESET = [["Discharge", 13, "15/15", :quad, [:quad, :immune], true],
           ["Iron Tail", 8, "15/15", :resisted, [:resisted, :super], false],
           ["Dig", 4, "10/10", :immune, [:immune, :super], false],
           ["Quick Attack", 0, "30/30", :neutral, [:neutral, :resisted], false]]
SEL = 0
TYPE_INK = { 13 => Color.new(128, 104, 8), 8 => Color.new(88, 88, 72), 4 => Color.new(104, 56, 8), 0 => Color.new(80, 72, 88) }
# old KR's default border colours
LV = { :quad => Color.new(64, 220, 96), :super => Color.new(240, 224, 88), :neutral => Color.new(64, 216, 232),
       :resisted => Color.new(248, 160, 64), :quarter => Color.new(240, 72, 72), :immune => Color.new(152, 158, 168) }
MULT = { :quad => "x4", :super => "x2", :neutral => "x1", :resisted => "x1/2", :quarter => "x1/4", :immune => "x0" }
WORD = { :quad => "Super Eff.", :super => "Super Eff.", :neutral => "Neutral", :resisted => "Resisted", :quarter => "Resisted", :immune => "No Effect" }
WARN = Color.new(240, 84, 72)
INK = Color.new(80, 80, 88); INK_SH = Color.new(160, 160, 168)
CLEAR = Color.new(0, 0, 0, 0)

$mode = :singles
def scene(mode)
  $mode = mode
  MAPS.bitmap = Bitmap.new(File.join(HERE, "fx", "fight_#{mode}.png"))
end
def shadowed(t, x, y, w, h, s, font = PF::TEXT, align = 0, color = Color.new(248, 248, 248))
  P.text(t, x + 1, y + 1, w, h, s, Color.new(40, 40, 48), font, align); P.text(t, x, y, w, h, s, color, font, align)
end
# The battle's own text: databox names and levels, move names, PP
def battle_text(c)
  t = BTXT.bitmap
  if $mode == :singles
    shadowed(t, 16, 14, 160, 18, "Gyarados"); shadowed(t, 170, 14, 50, 18, "Lv31")
    shadowed(t, 316, 222, 160, 18, "Pikachu"); shadowed(t, 448, 222, 50, 18, "Lv34")
  else
    shadowed(t, 28, 8, 150, 18, "Gyarados"); shadowed(t, 182, 8, 50, 18, "Lv31")
    shadowed(t, 16, 42, 150, 18, "Onix"); shadowed(t, 170, 42, 50, 18, "Lv30")
    shadowed(t, 304, 204, 150, 18, "Pikachu"); shadowed(t, 436, 204, 50, 18, "Lv34")
    shadowed(t, 316, 238, 150, 18, "Lapras"); shadowed(t, 448, 238, 50, 18, "Lv33")
  end
  MOVESET.each_with_index do |(n, ty, *), i|
    bx, by = button_xy(i)
    room = ($name_room || {})[i].to_i
    P.text(t, bx + 1, by + 7, 192 - room, 24, n, INK_SH, PF::ROW, 2); P.text(t, bx, by + 6, 192 - room, 24, n, TYPE_INK[ty], PF::ROW, 2)
  end
end
def button_xy(i); [4 + (i % 2) * 188, FY + 6 + (i / 2) * 42]; end
def type_badge(b, ty, x, y)
  b.stretch_blt(Rect.new(x, y, 64, 28), bmp(File.join(GFX, "Pictures/types.png")), Rect.new(0, ty * 28, 64, 28))
end
def pif_info(t)
  type_badge(t, MOVESET[SEL][1], 416, FY + 20); pp_text(t, MOVESET[SEL][2])
end
def pp_text(t, s, y = FY + 44); P.text(t, 392, y, 112, 18, "PP: #{s}", INK, PF::TEXT, 2); end
def level(i); $mode == :singles ? MOVESET[i][3] : MOVESET[i][4].max_by { |l| [:immune, :quarter, :resisted, :neutral, :super, :quad].index(l) }; end
# Clear the info box (the white area right of the buttons) so a design can redraw it
def info_clear(b, c); UI.rbox(b, 392, FY + 6, 506, FY + 90, 3, Color.new(248, 248, 248)); end
def ring(b, x, y, w, h, r, color, th = 3)
  UI.rbox(b, x, y, x + w, y + h, r, color)
  UI.rbox(b, x + th, y + th, x + w - th, y + h - th, [r - th, 1].max, CLEAR)
end
def warn_mark(b, x, y)
  UI.rbox(b, x, y, x + 15, y + 15, 7, WARN, Color.new(60, 20, 20))
  P.text(TOP.bitmap, x, y, 16, 16, "!", Color.new(255, 255, 255), PF::TEXT, 2)
end
def chevrons(b, x, y, lvl)
  colr = LV[lvl]
  case lvl
  when :quad then UI.tri(b, x, y, :u, colr, 4); UI.tri(b, x, y + 6, :u, colr, 4)
  when :super then UI.tri(b, x, y + 3, :u, colr, 4)
  when :resisted then UI.tri(b, x, y + 3, :d, colr, 4)
  when :quarter then UI.tri(b, x, y, :d, colr, 4); UI.tri(b, x, y + 6, :d, colr, 4)
  when :immune
    5.times { |k| b.fill_rect(x + k * 2, y + 2 + k * 2, 2, 2, colr); b.fill_rect(x + 8 - k * 2, y + 2 + k * 2, 2, 2, colr) }
  end
end
def comp(name, a, bb)
  # the two screens side by side, as the earlier galleries
  [a, bb]
end
$pairs = []
def shot(name); dump_as(name); end

c = palette(2)

#================================================================ FX1 Recommended: KR borders, cody's per-foe lines
[:singles, :doubles].each do |m|
  scene(m); frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  MOVESET.each_index do |i|
    bx, by = button_xy(i)
    ring(b, bx + 3, by + 2, 185, 40, 7, LV[level(i)])
  end
  info_clear(b, c)
  mv = MOVESET[SEL]
  if m == :singles
    type_badge(t, mv[1], 416, FY + 8)
    pp_text(t, mv[2], FY + 38)
    lv = mv[3]
    label = "#{MULT[lv]} SUPER EFFECTIVE"
    w = P.width(PF::TINY, label) + 12
    P.pill(b, 448 - w / 2, FY + 62, label, Color.new(40, 40, 48), LV[lv], false)
  else
    pp_text(t, mv[2], FY + 8)
    rows = [["Gyarados", :quad, false], ["Onix", :immune, false], ["Lapras", :super, true]]
    rows.each_with_index do |(n, lv, ally), k|
      y = FY + 28 + k * 19
      if ally
        UI.rbox(b, 396, y, 502, y + 18, 4, Color.new(252, 220, 214))
        warn_mark(b, 398, y + 1)
        P.small(t, 416, y + 1, 60, 16, n, WARN)
      else
        P.small(t, 400, y + 1, 70, 16, n, INK)
      end
      P.text(t, 450, y, 50, 18, MULT[lv], ally ? WARN : (lv == :immune ? Color.new(110, 114, 124) : Color.new(40, 150, 64)), PF::TEXT, 1)
    end
    bx, by = button_xy(SEL)
    warn_mark(b, bx + 170, by + 4)
  end
  shot("FX1_#{m}")
end

#================================================================ FX2 Markers: cody's markers grown to 6 levels, multiplier on the button
[:singles, :doubles].each do |m|
  scene(m)
  $mode = m
  $name_room = {}
  MOVESET.each_index { |i| lv = level(i); $name_room[i] = P.width(PF::TINY, MULT[lv]) + 26 unless lv == :neutral }
  frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  MOVESET.each_index do |i|
    bx, by = button_xy(i)
    lv = level(i)
    next if lv == :neutral
    w = P.width(PF::TINY, MULT[lv]) + 22
    UI.rbox(b, bx + 182 - w, by + 12, bx + 182, by + 30, 6, Color.new(40, 40, 48, 235), LV[lv])
    chevrons(t, bx + 186 - w, by + 15, lv)
    P.text(t, bx + 182 - w + 14, by + 12, w - 16, 18, MULT[lv], LV[lv], PF::TINY, 2)
  end
  info_clear(b, c)
  mv = MOVESET[SEL]
  if m == :singles
    type_badge(t, mv[1], 416, FY + 12)
    pp_text(t, mv[2], FY + 42)
    P.text(t, 392, FY + 62, 112, 18, "Super Eff.", Color.new(40, 150, 64), PF::TEXT, 2)
  else
    pp_text(t, mv[2], FY + 8)
    [["GYARADOS", "x4", LV[:quad], false], ["ONIX", "x0", LV[:immune], false], ["LAPRAS", "x2", WARN, true]].each_with_index do |(sp, mul, colr, ally), k|
      x = 400 + k * 35
      UI.rbox(b, x - 2, FY + 30, x + 31, FY + 86, 5, ally ? Color.new(252, 220, 214) : Color.new(236, 236, 240), ally ? WARN : nil)
      mon(t, sp, x + 14, FY + 46, 32)
      P.text(t, x - 2, FY + 64, 34, 18, mul, colr, PF::TEXT, 2)
    end
    warn_mark(b, 487, FY + 28)
    bx, by = button_xy(SEL)
    warn_mark(b, bx + 4, by + 4)
  end
  shot("FX2_#{m}")
end

$name_room = {}
#================================================================ FX3 Target Strip: a strip above the Fight box names what the move hits
[:singles, :doubles].each do |m|
  scene(m); frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  MOVESET.each_index do |i|
    bx, by = button_xy(i)
    UI.rbox(b, bx + 8, by + 8, bx + 16, by + 36, 3, LV[level(i)], Color.new(40, 40, 48))
  end
  mv = MOVESET[SEL]
  pif_info(t)
  rows = m == :singles ? [["Gyarados", :quad, false]] : [["Gyarados", :quad, false], ["Onix", :immune, false], ["Lapras", :super, true]]
  x = 6; y = FY - 20
  w = P.width(PF::TINY, "HITS") + 14
  UI.rbox(b, x, y, x + w, y + 16, 5, col(c[:panel], 235), c[:line])
  P.text(t, x, y, w, 16, "HITS", c[:head], PF::TINY, 2)
  x += w + 4
  rows.each do |n, lv, ally|
    label = n.upcase
    w = P.width(PF::TINY, label) + P.width(PF::TINY, MULT[lv]) + 18 + (ally ? 14 : 0)
    UI.rbox(b, x, y, x + w, y + 16, 5, ally ? Color.new(90, 30, 30, 240) : col(c[:panel], 235), ally ? WARN : LV[lv])
    xx = x + 7
    if ally
      warn_mark(b, x + 1, y); xx += 14
    end
    P.text(t, xx, y, 120, 16, label, ally ? Color.new(255, 210, 200) : c[:txt], PF::TINY)
    P.text(t, x, y, w - 7, 16, MULT[lv], ally ? WARN : LV[lv], PF::TINY, 1)
    x += w + 4
  end
  shot("FX3_#{m}")
end

#================================================================ FX4 On the Targets: tags beside each databox, corner flags on the buttons
[:singles, :doubles].each do |m|
  scene(m); frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  MOVESET.each_index do |i|
    bx, by = button_xy(i)
    lv = level(i)
    next if lv == :neutral
    16.times { |k| b.fill_rect(bx + 186 - (16 - k), by + 3 + k, 16 - k, 1, k == 0 || k == 15 ? Color.new(40, 40, 48) : LV[lv]) }
    16.times { |k| b.fill_rect(bx + 186 - (16 - k) - 1, by + 3 + k, 1, 1, Color.new(40, 40, 48)) }
  end
  pif_info(t)
  tag = lambda do |x, y, lv, ally|
    s = MULT[lv]
    w = P.width(PF::TEXT, s) + 16 + (ally ? 18 : 0)
    UI.rbox(b, x, y, x + w, y + 20, 6, ally ? Color.new(90, 30, 30, 240) : col(c[:panel], 235), ally ? WARN : LV[lv])
    if ally
      warn_mark(b, x + 3, y + 2)
      P.text(t, x + 18, y + 1, w - 18, 18, s, WARN, PF::TEXT, 2)
    else
      P.text(t, x, y + 1, w, 18, s, LV[lv], PF::TEXT, 2)
    end
  end
  if m == :singles
    tag.call(228, 14, :quad, false)
  else
    tag.call(240, 8, :quad, false)
    tag.call(228, 42, :immune, false)
    tag.call(222, 238, :super, true)
  end
  shot("FX4_#{m}")
end
