# encoding: utf-8
# Mockups: what using a PokeVial Charge (or Refill) from the Bag shows, and
# what it says when the PokeVial is already full (the item isn't used).
# Shown over a stand-in of the game's Bag (PIF's 016_UI/007_UI_Bag.rb
# layout, KIF's own art); the charges as little Poke Balls (his pick).
# Design 1 = Toast (Hoenn Reloaded's): a toast at the top, the Bag stays
#            open (the Bag's update would move it on).
# Design 2 = Message Bar: a bar along the bottom (as the Party Screen's
#            messages), A goes on.
# Design 3 = PokeVial Popup: a small Header Plate popup, the new charge
#            ringed, and OK.
# Item icons: Hoenn Reloaded's, stand-ins (read only).
# Sprites: python ../qa/qa_assets.py "<KIF Beta>" first (writes ../qa/art).
# Usage (from this folder): ruby itemmsg_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "pokevial_common.rb")
load File.join(File.dirname(File.expand_path(__FILE__)), "lowhp_common.rb")

GFX = File.join(ARGV[0], "Graphics")
HR_ITEMS = File.expand_path(File.join(ARGV[0], "..", "Github", "Hoenn-Reloaded-Testing", "Reloaded", "Graphics", "Items"))
CHARGE = Bitmap.new(File.join(HR_ITEMS, "pokevial_charge.png"))

# Charges as Poke Balls (his pick) wherever the common pieces draw them
def pips(o, c, x1, y, full, total); LowHP.balls(o, c, x1, y + 5, full, total); end

#---------------------------------------------------------------- the Bag behind
BAG_VP = Viewport.new(0, 0, SW, SH)
BAG_VP.z = 50
def bag_sprite(bitmap, x = 0, y = 0, z = 0)
  s = Sprite.new(BAG_VP)
  s.bitmap = bitmap
  s.x = x; s.y = y; s.z = z
  s
end
bag_sprite(Bitmap.new(File.join(GFX, "Pictures/Bag/bg_2.png")))
bag_sprite(Bitmap.new(File.join(GFX, "Pictures/Bag/bag_2.PNG")), 30, 20, 1)
BAG_TEXT = bag_sprite(Bitmap.new(SW, SH), 0, 0, 2)
ITEMS = [["Potion", 5], ["Super Potion", 2], ["PokeVial Charge", 3], ["PokeVial Refill", 1], ["Full Heal", 2],
         ["Revive", 1], ["CLOSE BAG", nil]].freeze
SEL = 2
def paint_bag
  t = BAG_TEXT.bitmap
  t.clear
  ink = Color.new(88, 88, 80)
  shade = Color.new(168, 184, 184)
  cursor = Bitmap.new(File.join(GFX, "Pictures/Bag/cursor.png"))
  t.blt(184, 8 + SEL * 32 - 11, cursor, Rect.new(0, 0, 282, 68))      # the outline sits mid-picture
  ITEMS.each_with_index do |(name, qty), i|
    y = 8 + i * 32 + 12
    [[1, shade], [0, ink]].each do |d, col|
      P2.text(t, 200 + d, y + d, 200, 20, name, col, PF::TEXT)
      P2.text(t, 380 + d, y + d, 64, 20, format("x%3d", qty), col, PF::TEXT, 1) if qty
    end
  end
  t.stretch_blt(Rect.new(24, SH - 72, 48, 49), CHARGE, Rect.new(0, 0, 48, 49))
  ["A compact charge that restores", "one PokeVial use."].each_with_index do |ln, k|
    P2.text(t, 89, 297 + k * 28, 410, 24, ln, Color.new(0, 0, 0), PF::TEXT)
    P2.text(t, 88, 296 + k * 28, 410, 24, ln, Color.new(248, 248, 248), PF::TEXT)
  end
end

# A shot over the Bag: the Overworld Menu's own sprites hidden, only its
# overlay (where the design is drawn) left
def bag_shot(name, mode)
  S.set(:"interface.theme_mode", mode)
  $qa_hints = nil
  om.refresh
  o = om.send(:overlay)
  hidden = om.send(:sprites).reject { |s| s.bitmap.equal?(o) }
  hidden.each { |s| s.visible = false }
  o.clear
  paint_bag
  yield(o, om.send(:palette))
  dump(name)
  hidden.each { |s| s.visible = true }
end

#---------------------------------------------------------------- the designs
WORDS = { :charge => ["The PokeVial regained a charge.", 3], :full => ["The PokeVial is already full.", 4] }.freeze

def toast(o, c, kind)
  text, full = WORDS[kind]
  tw = P2.width(PF::TEXT, text)
  bw = kind == :full ? P2.width(PF::TINY, "FULL") + 12 : 4 * 9 + 3 * 2 + 12
  w = 34 + tw + 10 + bw + 10; h = 30
  x = (SW - w) / 2; y = 10
  P2.ui.rbox(o, x, y, x + w - 1, y + h - 1, 7, c[:panel], c[:line])
  vial_icon(o, x + 8, y + 4, 18, 22)
  P2.text(o, x + 34, y + 6, tw + 2, 18, text, c[:txt], PF::TEXT)
  if kind == :full
    fill = c[:light] ? mix(c[:panel2], c[:gold], 0.22) : Color.new(70, 58, 20)
    P2.pill(o, x + w - 10, y + 7, "FULL", fill, c[:gold], true)
  else
    px1 = x + w - 10
    P2.ui.rbox(o, px1 - bw, y + 7, px1, y + 22, 7, c[:dark], c[:line])
    LowHP.balls(o, c, px1 - 6, y + 15, full, 4, 9, 2)
  end
end

def message_bar(o, c, kind)
  text, full = WORDS[kind]
  y0 = SH - 62; y1 = SH - 8
  PP.chamfer_grad(o, 8, y0, SW - 8, y1, 12, mix(c[:panel], c[:selb], 0.22), c[:panel], c[:selb])
  vial_icon(o, 22, y0 + 12, 26, 31)
  P2.text(o, 58, y0 + 8, 300, 20, text, c[:txt], PF::TEXT)
  sub = kind == :full ? "The Charge wasn't used." : "Charges: 3 of 4."
  P2.small(o, 58, y0 + 28, 300, 16, sub, c[:dim])
  LowHP.balls(o, c, SW - 26, y0 + 20, full, 4)
  P2.ui.tri(o, SW - 30, y1 - 13, :d, c[:selb], 4)
end

# the popup's big balls, the newest one ringed in gold
def big_balls(o, c, cx, y, full, total, ringed)
  size = 17; gap = 9
  x0 = cx - (total * size + (total - 1) * gap) / 2
  LowHP.balls(o, c, x0 + total * size + (total - 1) * gap, y + size / 2, full, total, size, gap)
  return unless ringed
  px = x0 + ringed * (size + gap)
  [[px - 4, y - 4, size + 8, 2], [px - 4, y + size + 2, size + 8, 2], [px - 4, y - 4, 2, size + 8],
   [px + size + 2, y - 4, 2, size + 8]].each { |rx, ry, rw, rh| o.fill_rect(rx, ry, rw, rh, c[:gold]) }
end

def vial_popup(o, c, kind)
  text, full = WORDS[kind]
  w = 300; h = 158
  x = (SW - w) / 2; y = (SH - h) / 2
  frame(o, c, x, y, w, h, "PokeVial", nil)
  vial_icon(o, x + 12, y + 6)
  big_balls(o, c, x + w / 2, y + 48, full, 4, kind == :full ? nil : 2)
  P2.text(o, x + 14, y + 76, w - 28, 18, kind == :full ? "It's already full." : "It regained a charge.", c[:txt], nil, 2)
  P2.small(o, x + 14, y + 96, w - 28, 16, kind == :full ? "The Charge wasn't used." : "Charges: 3 of 4.", c[:dim], 2)
  button(o, c, x + w / 2 - 60, y + h - 38, x + w / 2 + 60, y + h - 10, "OK", true)
end

queue = []
[["IM1_toast", :toast], ["IM2_bar", :message_bar], ["IM3_popup", :vial_popup]].each do |name, what|
  [:charge, :full].each do |kind|
    queue << at { bag_shot("#{name}_#{kind}", 0) { |o, c| send(what, o, c, kind) } }
    queue << at { bag_shot("#{name}_#{kind}_light", 2) { |o, c| send(what, o, c, kind) } }
  end
end
queue << at { S.set(:"interface.theme_mode", 0); om.send(:overlay).clear; om.refresh }
queue << I::BACK
on_map("PokeVial item message designs", queue)
puts "designs done"
