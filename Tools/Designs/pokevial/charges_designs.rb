# encoding: utf-8
# Mockups: how the PokeVial's charges look (his ask, 2026-10-22), shown in
# the PokeVial dialog's title plate with 2 of 4 charges full.
# Now      = red squares.
# Design 1 = Capsules: small upright vial capsules, red with a shine.
# Design 2 = Droplets: drops, filled or hollow.
# Design 3 = Poke Balls: little balls, the empty ones muted.
# Design 4 = Gauge: one short bar in segments.
# Sprites: python ../qa/qa_assets.py "<KIF Beta>" first (writes ../qa/art).
# Usage (from this folder): ruby charges_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "pokevial_common.rb")

DROP = ["....#....", "...###...", "...###...", "..#####..", ".#######.", ".#######.",
        "#########", "#########", ".#######.", "..#####..", "...###..."].freeze
# the drop one pixel in from its edge
DROP_IN = DROP.each_with_index.map do |ln, r|
  ln.chars.each_with_index.map do |ch, k|
    inside = ch == "#" && r > 0 && r < DROP.length - 1 && k > 0 && k < ln.length - 1 &&
             DROP[r - 1][k] == "#" && DROP[r + 1][k] == "#" && ln[k - 1] == "#" && ln[k + 1] == "#"
    inside ? "#" : "."
  end.join
end.freeze

$pip_style = :now

# Every style centres its charges on the plate's middle (cy), the last one
# ending at x1
def pips(o, c, x1, y, full, total)
  cy = y + 5
  hollow = mix(c[:line], c[:dim], 0.55)             # an empty charge's edge, seen on Dark too
  case $pip_style
  when :now
    total.times do |i|
      px = x1 - (total - i) * 13
      P2.ui.rbox(o, px, cy - 5, px + 10, cy + 5, 2, i < full ? POKE_RED : c[:dark], i < full ? nil : hollow)
    end
  when :capsules
    w = 7; h = 15; gap = 4
    total.times do |i|
      px = x1 - (total - i) * (w + gap)
      top = cy - h / 2
      if i < full
        P2.ui.rbox(o, px, top, px + w, top + h, 3, POKE_RED, mix(POKE_RED, c[:white], 0.35))
        o.fill_rect(px + 2, top + 3, 1, h - 7, mix(POKE_RED, c[:white], 0.65))      # the shine
      else
        P2.ui.rbox(o, px, top, px + w, top + h, 3, c[:dark], hollow)
      end
    end
  when :drops
    gap = 3
    total.times do |i|
      px = x1 - (total - i) * (9 + gap)
      top = cy - 5
      if i < full
        PP.pixels(o, DROP, px, top, POKE_RED)
        o.fill_rect(px + 3, top + 5, 1, 2, mix(POKE_RED, c[:white], 0.65))         # the shine
      else
        PP.pixels(o, DROP, px, top, hollow)
        PP.pixels(o, DROP_IN, px, top, c[:dark])
      end
    end
  when :balls
    size = 11; gap = 3
    total.times do |i|
      px = x1 - (total - i) * (size + gap)
      top = cy - size / 2
      if i < full
        P2.poke_ball(o, px, top, size)
      else
        muted = { :ink => hollow, :red => c[:dark], :white => mix(c[:dark], hollow, 0.35) }
        size.times do |r|
          size.times do |k|
            part = P2.send(:ball_pixel, k, r, size)
            o.fill_rect(px + k, top + r, 1, 1, muted[part]) if part
          end
        end
      end
    end
  when :gauge
    bw = 64; bh = 9; gap = 2
    x0 = x1 - bw
    top = cy - bh / 2
    P2.ui.rbox(o, x0 - 2, top - 2, x1 + 2, top + bh + 2, 2, c[:dark], hollow)
    seg = (bw - gap * (total - 1)) / total
    total.times do |i|
      sx = x0 + i * (seg + gap)
      next o.fill_rect(sx, top, seg, bh, mix(c[:dark], hollow, 0.3)) unless i < full   # an empty slot
      o.fill_rect(sx, top, seg, bh, POKE_RED)
      o.fill_rect(sx, top, seg, 2, mix(POKE_RED, c[:white], 0.45))                 # lit from the top
    end
  end
end

DIALOG_HINTS = [[:lr, "Choose"], [A_PAD, "Select"], [B_PAD, "Back"]]
DESIGNS = []
[[:now, "PV_CH0_now"], [:capsules, "PV_CH1_capsules"], [:drops, "PV_CH2_drops"], [:balls, "PV_CH3_balls"],
 [:gauge, "PV_CH4_gauge"]].each do |style, name|
  DESIGNS << [name, DIALOG_HINTS, 0, proc { |o, c| $pip_style = style; vial_dialog(o, c) }]
  DESIGNS << ["#{name}_light", DIALOG_HINTS, 2, proc { |o, c| $pip_style = style; vial_dialog(o, c) }]
end
run_pokevial("PokeVial charges designs", DESIGNS)
