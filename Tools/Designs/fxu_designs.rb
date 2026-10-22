# encoding: utf-8
# Mockups: four Battle UI designs on EBDX's own scene (topic 14). Each is two
# screens: EBDX's command screen (the cursor on FIGHT, the new Button Hints,
# the Field Strip from topic 11) and the doubles target screen (the cursor on
# Gyarados, the fused ally Joltras with its real fusion icon instead of KIF's
# DNA placeholder). The cursor follows the KR Theme (Ocean Blue here).
# Design 1 = old KR's Reloaded EBDX Cursor: a rounded border in place of
# EBDX's corner brackets.
# Backdrops (ebdx_backdrop.py): fx/u_cmd(_nosel).png = singles command,
# fx/u_tgt(_nosel).png = doubles target --fused-ally 135.131 --fusion-icons.
# Usage (from this folder): ruby fxu_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "bmenu_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "bmenu_designs.rb")

def battle_text(c); end   # EBDX's own text is in the backdrop
CMD = [37, 327, 96, 42]          # FIGHT, highlighted
TGT = [256, 288, 96, 42]         # Gyarados's target button, highlighted
CLEAR = Color.new(0, 0, 0, 0)
INKD = Color.new(28, 28, 36)
HINTS = [[Y_BTN, "Battle Menu"], [X_BTN, "Quick Throw"]]

def scene(name, selector)
  MAPS.bitmap = Bitmap.new(File.join(HERE, "fx", "#{name}#{selector ? '' : '_nosel'}.png"))
end
def ring(b, x, y, w, h, r, color, th)
  UI.rbox(b, x, y, x + w, y + h, r, color)
  UI.rbox(b, x + th, y + th, x + w - th, y + h - th, [r - th, 1].max, CLEAR)
end
# A hint: the button glyph, then its label in small caps
def hint_w(label); 16 + 4 + P.width(PF::TINY, label.upcase); end
def hint(x, y, btn, label, c)
  BI.draw(TOP.bitmap, x, y, btn, c, $style, 14)
  P.text(TOP.bitmap, x + 18, y, 120, 14, label.upcase, c[:txt], PF::TINY)
end
# hints on a dark pill, right-aligned at x
def hint_pill(c, right, y)
  w = HINTS.sum { |_, l| hint_w(l) } + 12 * (HINTS.length - 1) + 16
  x = right - w
  UI.rbox(BASE.bitmap, x, y, right, y + 18, 6, col(c[:panel], 230), c[:line])
  xx = x + 8
  HINTS.each { |btn, l| hint(xx, y + 2, btn, l, c); xx += hint_w(l) + 12 }
end
def accent(c); c[:selb]; end
def shot(name); dump_as(name); end

c = palette(2)

#================================================================ FXU1 Recommended: KR's rounded border cursor
frame(c)
scene("u_cmd", false)
b = BASE.bitmap
field_strip(c, 305)
ring(b, CMD[0] - 3, CMD[1] - 3, CMD[2] + 6, CMD[3] + 6, 8, accent(c), 3)
hint_pill(c, 506, 304)
shot("FXU1_cmd")
frame(c)
scene("u_tgt", false)
b = BASE.bitmap
ring(b, TGT[0] - 3, TGT[1] - 3, TGT[2] + 6, TGT[3] + 6, 8, accent(c), 3)
shot("FXU1_tgt")

#================================================================ FXU2 Theme Glow: a soft fill and outline, hints along the bottom
frame(c)
scene("u_cmd", false)
b = BASE.bitmap; t = TOP.bitmap
field_strip(c, 305)
UI.rbox(b, CMD[0] - 4, CMD[1] - 4, CMD[0] + CMD[2] + 4, CMD[1] + CMD[3] + 4, 10, col(accent(c), 90))
ring(b, CMD[0] - 4, CMD[1] - 4, CMD[2] + 8, CMD[3] + 8, 10, accent(c), 2)
b.fill_rect(0, 370, W, 14, Color.new(10, 12, 20, 210))
total = HINTS.sum { |_, l| hint_w(l) } + 24 * (HINTS.length - 1)
xx = (W - total) / 2
HINTS.each { |btn, l| hint(xx, 370, btn, l, c); xx += hint_w(l) + 24 }
shot("FXU2_cmd")
frame(c)
scene("u_tgt", false)
b = BASE.bitmap
UI.rbox(b, TGT[0] - 4, TGT[1] - 4, TGT[0] + TGT[2] + 4, TGT[1] + TGT[3] + 4, 10, col(accent(c), 90))
ring(b, TGT[0] - 4, TGT[1] - 4, TGT[2] + 8, TGT[3] + 8, 10, accent(c), 2)
shot("FXU2_tgt")

#================================================================ FXU3 Underline: a bar under the highlighted item with a notch
underline = lambda do |b, x, y, w|
  UI.rbox(b, x + 6, y, x + w - 6, y + 5, 2, accent(c), INKD)
  UI.tri(b, x + w / 2 - 5, y - 6, :u, accent(c), 5)
end
frame(c)
scene("u_cmd", false)
b = BASE.bitmap
field_strip(c, 305)
underline.call(b, CMD[0], CMD[1] + CMD[3] - 2, CMD[2])
hint_pill(c, 506, 304)
shot("FXU3_cmd")
frame(c)
scene("u_tgt", false)
b = BASE.bitmap
underline.call(b, TGT[0], TGT[1] + TGT[3] - 2, TGT[2])
shot("FXU3_tgt")

#================================================================ FXU4 Brackets, Recoloured: EBDX's own corner brackets in the theme colour
brackets = lambda do |b, x, y, w, h|
  l = 12; th = 3
  [[x, y, 1, 1], [x + w, y, -1, 1], [x, y + h, 1, -1], [x + w, y + h, -1, -1]].each do |cx, cy, sx, sy|
    b.fill_rect(sx > 0 ? cx : cx - l, sy > 0 ? cy : cy - th, l, th, accent(c))
    b.fill_rect(sx > 0 ? cx : cx - th, sy > 0 ? cy : cy - l, th, l, accent(c))
  end
end
frame(c)
scene("u_cmd", false)
b = BASE.bitmap
field_strip(c, 305)
brackets.call(b, 31, 319, 108, 54)
x = 506
HINTS.reverse.each do |btn, l|
  w = hint_w(l) + 14
  UI.rbox(b, x - w, 304, x, 320, 5, col(c[:panel], 230), c[:line])
  hint(x - w + 7, 305, btn, l, c)
  x -= w + 4
end
shot("FXU4_cmd")
frame(c)
scene("u_tgt", false)
b = BASE.bitmap
brackets.call(b, 248, 280, 112, 58)
shot("FXU4_tgt")
