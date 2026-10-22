# encoding: utf-8
# Mockups: four Move Effectiveness designs over EBDX's own Fight menu (KR's
# battle features are EBDX only). Each design is two screens: singles
# (Pikachu vs a wild Gyarados: Discharge x4, Iron Tail x1/2, Dig x0, Quick
# Attack x1) and doubles (Pikachu + Lapras vs Gyarados + Onix, Discharge hits
# Gyarados x4, Onix x0 and our Lapras x2: the new Ally Warning).
# Backdrops come from ebdx_backdrop.py with --kr-layers (KR's fix: the
# highlighted move on top); design 1 also uses --no-selector (KR's border
# replaces EBDX's selector, as old KR did).
# Design 1 = old KR on EBDX: the pulsing effectiveness border on the
# highlighted move, grown to every move, with the multiplier and per-target chips.
# Usage (from this folder): ruby fxe_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "bmenu_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "bmenu_designs.rb")

def battle_text(c); end   # EBDX's own text is in the backdrop

# On-screen rects from ebdx_backdrop.py's JSON: [x, y, w, h]
HL = [58, 274, 198, 74]                       # the highlighted move's sprite (Discharge)
BARS = { 1 => [257, 294, 196, 42], 2 => [59, 338, 196, 42], 3 => [257, 338, 196, 42] }
# [singles level, doubles level (best of the foes)]
LEVELS = [[:quad, :quad], [:resisted, :super], [:immune, :super], [:neutral, :neutral]]
LV = { :quad => Color.new(64, 220, 96), :super => Color.new(240, 224, 88), :neutral => Color.new(64, 216, 232),
       :resisted => Color.new(248, 160, 64), :quarter => Color.new(240, 72, 72), :immune => Color.new(152, 158, 168) }
MULT = { :quad => "x4", :super => "x2", :neutral => "x1", :resisted => "x1/2", :quarter => "x1/4", :immune => "x0" }
WARN = Color.new(240, 84, 72)
INKD = Color.new(28, 28, 36)
CLEAR = Color.new(0, 0, 0, 0)
WHITE = Color.new(248, 248, 248)
TARGETS = [["GYARADOS", "Gyarados", :quad, false], ["ONIX", "Onix", :immune, false], ["LAPRAS", "Lapras", :super, true]]

$mode = :singles
def scene(mode, selector = true)
  $mode = mode
  MAPS.bitmap = Bitmap.new(File.join(HERE, "fx", "e_#{mode}#{selector ? '' : '_nosel'}.png"))
end
def level(i); LEVELS[i][$mode == :singles ? 0 : 1]; end
def ring(b, x, y, w, h, r, color, th)
  UI.rbox(b, x, y, x + w, y + h, r, color)
  UI.rbox(b, x + th, y + th, x + w - th, y + h - th, [r - th, 1].max, CLEAR)
end
def warn_mark(b, x, y)
  UI.rbox(b, x, y, x + 15, y + 15, 7, WARN, Color.new(60, 20, 20))
  P.text(TOP.bitmap, x, y, 16, 16, "!", WHITE, PF::TEXT, 2)
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
# Text with a dark outline (EBDX's pbDrawOutlineText look)
def outlined(t, x, y, w, h, s, color, font = PF::ROW, align = 2)
  [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, 1], [-1, 1], [1, -1]].each { |dx, dy| P.text(t, x + dx, y + dy, w, h, s, INKD, font, align) }
  P.text(t, x, y, w, h, s, color, font, align)
end
# A chip like the Field Strip's: TINY caps on a dark panel
def chip(c, x, y, label, mult, colr, ally = false)
  b = BASE.bitmap; t = TOP.bitmap
  w = P.width(PF::TINY, label) + P.width(PF::TINY, mult) + 18 + (ally ? 14 : 0)
  UI.rbox(b, x, y, x + w, y + 16, 5, ally ? Color.new(90, 30, 30, 240) : col(c[:panel], 235), ally ? WARN : colr)
  xx = x + 7
  if ally
    warn_mark(b, x + 1, y); xx += 14
  end
  P.text(t, xx, y, 120, 16, label, ally ? Color.new(255, 210, 200) : c[:txt], PF::TINY)
  P.text(t, x, y, w - 7, 16, mult, ally ? WARN : colr, PF::TINY, 1)
  w
end
def shot(name); dump_as(name); end

c = palette(2)

#================================================================ FXE1 Recommended: KR's border, rebuilt
[:singles, :doubles].each do |m|
  scene(m, false); frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  # every move: a thin border in its colour; the highlighted one gets KR's 4px border (it replaces EBDX's selector)
  BARS.each { |i, (x, y, w, h)| ring(b, x - 2, y - 2, w + 4, h + 4, 6, LV[level(i)], 2) }
  ring(b, HL[0], HL[1] - 2, HL[2], HL[3], 6, LV[level(0)], 4)
  # the multiplier sits between the category icon and the PP
  pw = P.width(PF::TINY, MULT[level(0)]) + 12
  P.pill(b, 181 - pw / 2, 324, MULT[level(0)], INKD, LV[level(0)], false)
  if m == :doubles
    x = 58
    TARGETS.each { |_, n, lv, ally| x += chip(c, x, 252, n.upcase, MULT[lv], LV[lv], ally) + 4 }
    warn_mark(b, HL[0] + HL[2] - 20, HL[1] + 2)
  end
  shot("FXE1_#{m}")
end

#================================================================ FXE2 Markers: arrow badges with the multiplier on each move
[:singles, :doubles].each do |m|
  scene(m); frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  badge = lambda do |x, y, lv|
    w = P.width(PF::TINY, MULT[lv]) + 22
    UI.rbox(b, x - w, y, x, y + 18, 6, Color.new(40, 40, 48, 235), LV[lv])
    chevrons(t, x - w + 4, y + 3, lv)
    P.text(t, x - w + 14, y, w - 16, 18, MULT[lv], LV[lv], PF::TINY, 2)
  end
  BARS.each do |i, (x, y, w, h)|
    lv = level(i)
    badge.call(x + w - 6, y + 12, lv) unless lv == :neutral
  end
  badge.call(HL[0] + HL[2] - 8, HL[1] + 6, level(0))
  if m == :doubles
    px = 58; py = 206
    UI.rbox(b, px, py, px + 120, py + 62, 6, col(c[:panel], 235), c[:line])
    TARGETS.each_with_index do |(sp, _, lv, ally), k|
      x = px + 6 + k * 38
      UI.rbox(b, x, py + 6, x + 34, py + 56, 5, ally ? Color.new(90, 30, 30, 240) : col(c[:panel2], 240), ally ? WARN : nil)
      mon(t, sp, x + 17, py + 24, 32)
      P.text(t, x, py + 38, 34, 16, MULT[lv], ally ? WARN : LV[lv], PF::TEXT, 2)
      warn_mark(b, x + 22, py + 1) if ally
    end
  end
  shot("FXE2_#{m}")
end

#================================================================ FXE3 EBDX's Own Label, Grown: the label above the highlighted move
[:singles, :doubles].each do |m|
  scene(m); frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  BARS.each do |i, (x, y, w, h)|
    UI.rbox(b, x + 6, y + 9, x + 13, y + 33, 3, LV[level(i)], INKD)
  end
  cx = HL[0]; cw = HL[2]
  lines = m == :singles ? [["x4 Super Effective", LV[:quad]]] : [["Gyarados x4", LV[:quad]], ["Onix x0", LV[:immune]], ["Lapras x2 (Ally)", WARN]]
  top = 270 - lines.length * 21
  UI.rbox(b, cx + 14, top - 2, cx + cw - 14, 268, 6, Color.new(16, 18, 26, 200))
  lines.each_with_index { |(s, colr), k| outlined(t, cx, top + k * 21, cw, 22, s, colr) }
  warn_mark(b, cx + cw / 2 - P.width(PF::ROW, lines[2][0]) / 2 - 19, top + 2 * 21 + 3) if m == :doubles
  shot("FXE3_#{m}")
end

#================================================================ FXE4 On the Targets: the multiplier beside each Pokemon's box
[:singles, :doubles].each do |m|
  scene(m); frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  flag = lambda do |x, y, lv|
    next if lv == :neutral
    16.times { |k| b.fill_rect(x - (16 - k), y + k, 16 - k, 1, LV[lv]) }
    16.times { |k| b.fill_rect(x - (16 - k) - 1, y + k, 1, 1, INKD) }
    b.fill_rect(x - 16, y, 16, 1, INKD)
  end
  BARS.each { |i, (x, y, w, h)| flag.call(x + w - 3, y + 3, level(i)) }
  flag.call(HL[0] + HL[2] - 4, HL[1] + 3, level(0))
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
    tag.call(230, 55, :quad, false)
  else
    tag.call(230, 39, :quad, false)
    tag.call(222, 89, :immune, false)
    tag.call(250, 251, :super, true)
  end
  shot("FXE4_#{m}")
end
