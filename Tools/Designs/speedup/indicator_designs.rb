# encoding: utf-8
# Mockups: the Speed Indicator (topic speed-up, his ask 2026-10-23): a small
# toast in the top-right corner, only when the speed changes, fading after a
# moment. The speed also goes in the window title.
# Design 1 = Speed Plate: an angled plate (Reloaded's plate look) with a
#            fast-forward mark and the speed.
# Design 2 = Speed Pips: the plate with a row of pips up to the Toggle
#            Limit, lit up to the speed.
# Design 3 = Toast: Kanto Reloaded's shared toast, moved to the corner, the
#            speed in a gold pill.
# His pick (2026-10-23): Design 3, smaller than Design 1. SI4_built draws
# the one built (Reloaded::SpeedUpIndicator.paint).
# Each shows Speed x4 above and back to x1 below it (in the game only one
# shows at a time).
# Sprites: python ../qa/qa_assets.py "<KIF Beta>" first (writes ../qa/art).
# Usage (from this folder): ruby indicator_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "..", "pokevial", "pokevial_common.rb")

LIMIT = 5
TOP = 8
GAP = 40     # the x1 example sits this far under the x4 one

def map_shot(name, mode)
  S.set(:"interface.theme_mode", mode)
  $qa_hints = nil
  om.refresh
  o = om.send(:overlay)
  hidden = om.send(:sprites).reject { |s| s.bitmap.equal?(o) }
  hidden.each { |s| s.visible = false }
  o.clear
  yield(o, om.send(:palette))
  dump(name)
  hidden.each { |s| s.visible = true }
end

# Fast-forward (two triangles) or play (one) at x, centred on cy
def ff_mark(o, x, cy, col, fast)
  (fast ? 2 : 1).times do |k|
    5.times { |r| o.fill_rect(x + k * 6 + r, cy - 5 + r, 1, 11 - r * 2, col) }
  end
end

def speed_col(c, v); v > 1 ? c[:gold] : c[:dim]; end

#---------------------------------------------------------------- Design 1: Speed Plate
def plate(o, c, v, y)
  w = 74; h = 26
  x1 = SW - 8; x0 = x1 - w
  PP.chamfer_grad(o, x0, y, x1, y + h, 8, mix(c[:panel], c[:selb], 0.25), c[:panel], v > 1 ? c[:gold] : c[:line])
  ff_mark(o, x0 + 14, y + h / 2, speed_col(c, v), v > 1)
  P2.text(o, x0 + 30, y + 3, w - 38, 20, "x#{v}", v > 1 ? c[:strong] : c[:txt], PF::ROW, 1)
end

#---------------------------------------------------------------- Design 2: Speed Pips
def pips_plate(o, c, v, y)
  w = 132; h = 26
  x1 = SW - 8; x0 = x1 - w
  PP.chamfer_grad(o, x0, y, x1, y + h, 8, mix(c[:panel], c[:selb], 0.25), c[:panel], v > 1 ? c[:gold] : c[:line])
  ff_mark(o, x0 + 12, y + h / 2, speed_col(c, v), v > 1)
  LIMIT.times do |k|
    px = x0 + 32 + k * 12
    lit = k < v
    P2.ui.rbox(o, px, y + 8, px + 8, y + 17, 2, lit ? (v > 1 ? c[:gold] : c[:dim]) : c[:dark], lit ? nil : c[:line])
  end
  P2.text(o, x0 + 32 + LIMIT * 12, y + 4, x1 - 12 - (x0 + 32 + LIMIT * 12), 18, "x#{v}", v > 1 ? c[:strong] : c[:txt], PF::TEXT, 1)
end

#---------------------------------------------------------------- Design 3: Toast
def corner_toast(o, c, v, y)
  text = "Game Speed"
  pill = "X#{v}"
  tw = P2.width(PF::TEXT, text)
  pw = P2.width(PF::TINY, pill) + 12
  w = 34 + tw + 10 + pw + 10; h = 30
  x0 = SW - 8 - w
  P2.ui.rbox(o, x0, y, x0 + w - 1, y + h - 1, 7, c[:panel], c[:line])
  ff_mark(o, x0 + 10, y + h / 2, speed_col(c, v), v > 1)
  P2.text(o, x0 + 34, y + 6, tw + 2, 18, text, c[:txt], PF::TEXT)
  tone = v > 1 ? c[:gold] : c[:dim]
  fill = c[:light] ? mix(c[:panel2], tone, 0.22) : (v > 1 ? GOLD_FILL : c[:dark])
  P2.pill(o, x0 + w - 10, y + 7, pill, fill, tone, true)
end

#---------------------------------------------------------------- the one built
def built(o, c, v, y)
  si = Reloaded::SpeedUpIndicator
  si.paint(o, c, v, SW - 8 - si.width(v), y)
end

queue = []
[["SI1_plate", :plate], ["SI2_pips", :pips_plate], ["SI3_toast", :corner_toast], ["SI4_built", :built]].each do |name, what|
  [[name, 0], ["#{name}_light", 2]].each do |file, mode|
    queue << at { map_shot(file, mode) { |o, c| send(what, o, c, 4, TOP); send(what, o, c, 1, TOP + GAP) } }
  end
end
queue << at { S.set(:"interface.theme_mode", 0); om.send(:overlay).clear; om.refresh }
queue << I::BACK
on_map("Speed Indicator designs", queue)
puts "designs done"
