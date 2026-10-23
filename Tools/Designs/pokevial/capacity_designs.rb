# encoding: utf-8
# Mockups: the PokeVial can hold more charges (Progressive Uses: +1 per two
# badges, up to 5). Shown on the map once the badge's scene is over; the new
# charge arrives full.
# Design 1 = Hoenn Reloaded's: a toast ("capacity increased to 4").
# Design 2 = Notice: a gold Header Plate popup, the new pip marked, and OK.
# Design 3 = Message Box: like getting an item, a plate along the bottom
#            with the vial in a small window above it.
# Sprites: python ../qa/qa_assets.py "<KIF Beta>" first (writes ../qa/art).
# Usage (from this folder): ruby capacity_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "pokevial_common.rb")

# A shot of the bare map: the Overworld Menu's own sprites hidden, only the
# overlay (where the design is drawn) left
def map_shot(name, hints, mode)
  S.set(:"interface.theme_mode", mode)
  $qa_hints = hints
  om.refresh
  o = om.send(:overlay)
  hidden = om.send(:sprites).reject { |s| s.bitmap.equal?(o) }
  hidden.each { |s| s.visible = false }
  o.clear
  yield(o, om.send(:palette))
  dump(name)
  hidden.each { |s| s.visible = true }
end

def toast(o, c)
  text = "PokeVial now holds 4 charges"
  tw = P2.width(PF::TEXT, text)
  badge = "+1"
  bw = P2.width(PF::TINY, badge) + 12
  w = 34 + tw + 10 + bw + 10; h = 30
  x = (SW - w) / 2; y = 10
  P2.ui.rbox(o, x, y, x + w - 1, y + h - 1, 7, c[:panel], c[:line])
  vial_icon(o, x + 8, y + 4, 18, 22)
  P2.text(o, x + 34, y + 6, tw + 2, 18, text, c[:txt], PF::TEXT)
  fill = c[:light] ? mix(c[:panel2], c[:green], 0.22) : Color.new(24, 60, 36)
  P2.pill(o, x + w - 10, y + 7, badge, fill, c[:green], true)
end

# four pips, the newest one ringed
def big_pips(o, c, cx, y, total, new_one)
  size = 16; gap = 8
  x0 = cx - (total * size + (total - 1) * gap) / 2
  total.times do |i|
    px = x0 + i * (size + gap)
    if i == new_one                            # a gold ring, 2 px, around it
      o.fill_rect(px - 4, y - 4, size + 8, 2, c[:gold])
      o.fill_rect(px - 4, y + size + 2, size + 8, 2, c[:gold])
      o.fill_rect(px - 4, y - 4, 2, size + 8, c[:gold])
      o.fill_rect(px + size + 2, y - 4, 2, size + 8, c[:gold])
    end
    P2.ui.rbox(o, px, y, px + size, y + size, 3, POKE_RED)
  end
end

def notice(o, c)
  w = 320; h = 170
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  gold = c[:gold]
  DG.send(:dim, o)
  DG.send(:panel, o, c, x, y, w, h, gold)
  DG.send(:title_bar, o, c, x, y, w, "PokeVial Upgraded", gold, gold, gold)
  vial_icon(o, x + 12, y + 6)
  big_pips(o, c, x + w / 2, y + 50, 4, 3)
  P2.text(o, x + 14, y + 80, w - 28, 18, "It holds 4 charges now.", c[:txt], nil, 2)
  P2.small(o, x + 14, y + 100, w - 28, 16, "The new charge is ready to use.", c[:dim], 2)
  button(o, c, x + w / 2 - 60, y + h - 38, x + w / 2 + 60, y + h - 10, "OK", true)
end

def message_box(o, c)
  # the box along the bottom, as the game's messages sit
  x = 8; w = SW - 16; h = 64; y = HINT_TOP - h - 6
  DG.send(:panel, o, c, x, y, w, h)
  P2.text(o, x + 18, y + 10, w - 36, 22, "Your PokeVial can now hold 4 charges!", c[:txt], PF::TEXT)
  P2.small(o, x + 18, y + 36, w - 36, 16, "The new charge is ready to use.", c[:dim])
  # the vial in its own small window above, as an item you get
  iw = 64; ih = 72; ix = x + 14; iy = y - ih - 6
  DG.send(:panel, o, c, ix, iy, iw, ih)
  vial_icon(o, ix + 14, iy + 8, 36, 43)
  4.times { |i| P2.ui.rbox(o, ix + 8 + i * 13, iy + ih - 14, ix + 18 + i * 13, iy + ih - 4, 2, POKE_RED) }
end

queue = []
[["PV_CAP1_toast", nil, 0, :toast], ["PV_CAP2_notice", [[A_PAD, "OK"]], 0, :notice],
 ["PV_CAP2_notice_light", [[A_PAD, "OK"]], 2, :notice], ["PV_CAP3_message", [[A_PAD, "Next"]], 0, :message_box]].each do |name, hints, mode, what|
  queue << at { map_shot(name, hints, mode) { |o, c| send(what, o, c) } }
end
queue << at { S.set(:"interface.theme_mode", 0); $qa_hints = nil; om.send(:overlay).clear; om.refresh }
queue << I::BACK
on_map("PokeVial capacity designs", queue)
puts "designs done"
