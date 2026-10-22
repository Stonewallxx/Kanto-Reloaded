# encoding: utf-8
# Mockups: Switch on the party screen (his look, Panel Menu picks): Switch
# on Gyarados, the cursor now on Eevee; A swaps them, B cancels. The title
# says what's being chosen ("Move Gyarados Where?", as KIF's "Move to
# where?"). Three designs.
# Sprites: python qa_assets.py "<KIF Beta>" first (writes art/ here).
# Usage (from this folder): ruby party_switch_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
PARTY_MENU_ONLY = true
load File.join(File.dirname(File.expand_path(__FILE__)), "party_menu_designs.rb")

SRC = 2; DST = 3                                # Gyarados, Eevee
SWITCH_HINTS = [[:ud, "Choose"], [A_PAD, "Switch Here"], [B_PAD, "Cancel"]]
def slot_xy(i); [GX + (i % 2) * (CW + 6), GY + (i / 2) * (CH + 6)]; end

# The party view with each card's state (:sel, or a block for the moving
# one) and a details panel painter
def party_view(o, c, title, sel, source = nil, details = nil, mons = MONS)
  st = his_mix_style
  $type_scale = 0.75
  $hp_outline = Color.new(150, 166, 188)
  o.clear
  st[:bg].call(o, c)
  st[:header].call(o, c, title)
  P2.hints(o, o, c, $qa_hints)
  mons.each_with_index do |m, i|
    x, y = slot_xy(i)
    if i == SRC && source
      source.call(o, c, x, y, m, st)
      next
    end
    st[:card].call(o, c, x, y, x + CW, y + CH, m, i == sel)
    card_content(o, c, x, y, CW, CH, m)
  end
  if details
    details.call(o, c, st)
  else
    st[:details].call(o, c, DX, GY, DX + DW, GY + DH, mons[sel])
    details_content(o, c, DX, GY, DW, mons[sel])
  end
  $type_scale = nil
  $hp_outline = nil
end
# a cut-corner outline, dashed when dash is given
def chamfer_outline(o, x0, y0, x1, y1, cut, col, dash = nil)
  pts = []
  (x0 + cut..x1 - 1).each { |x| pts << [x, y0] }
  (y0..y1 - 1 - cut).each { |y| pts << [x1 - 1, y] }
  (0..cut).each { |k| pts << [x1 - 1 - k, y1 - 1 - cut + k] }
  (x0..x1 - 1 - cut).each { |x| pts << [x, y1 - 1] }
  (y0 + cut..y1 - 1).each { |y| pts << [x0, y] }
  (0..cut).each { |k| pts << [x0 + k, y0 + cut - k] }
  pts.each_with_index do |(x, y), i|
    next if dash && (i / dash).odd?
    o.fill_rect(x, y, 2, 2, col)
  end
end
def swap_badge(o, c, cx, cy)
  disc(o, cx, cy, 11, c[:selb])
  disc(o, cx, cy, 10, c[:sel])
  P2.ui.tri(o, cx + 1, cy - 7, :r, WHITE, 4)
  o.fill_rect(cx - 5, cy - 3, 7, 2, WHITE)
  P2.ui.tri(o, cx - 6, cy + 1, :l, WHITE, 4)
  o.fill_rect(cx - 1, cy + 4, 7, 2, WHITE)
end

SWITCH = []

# 1 Recommended: the one moving keeps its place with a gold edge and a
# MOVING tag; the panel shows the swap (the two of them, with arrows)
SWITCH << ["QA_SW1_gold_and_preview", SWITCH_HINTS, proc { |o, c|
  moving = proc do |o, c, x, y, m, st|
    st[:card].call(o, c, x, y, x + CW, y + CH, m, false)
    card_content(o, c, x, y, CW, CH, m)
    chamfer_outline(o, x, y, x + CW, y + CH, 12, GOLD_T)
    P2.pill(o, x + 6, y + 6, "MOVING", GOLD_FILL, GOLD_T, false)
  end
  preview = proc do |o, c, st|
    a = MONS[SRC]; b = MONS[DST]
    top = MIX.call(c[:panel], c[:selb], 0.25); bottom = MIX.call(c[:panel], c[:dark], 0.4)
    chamfer_grad(o, DX, GY, DX + DW, GY + DH, 16, top, bottom, MIX.call(c[:line], c[:selb], 0.5))
    P2.heading(o, DX + 10, DX + DW - 10, GY + 10, "Switch", c[:dim], c[:line])
    [[a, GY + 30], [b, GY + 168]].each do |m, yy|
      art(o, m[:sp], DX + DW / 2, yy + 44, 72)
      P2.text(o, DX, yy + 86, DW, 18, m[:name], c[:txt], PF::TEXT, 2)
    end
    o.fill_rect(DX + 8, GY + 147, DW - 16, 2, POKE_RED)
    swap_badge(o, c, DX + DW / 2, GY + 148)
  end
  party_view(o, c, "Move Gyarados Where?", DST, moving, preview)
}]

# 2: lifted: the one moving is picked up and floats over the slot the
# cursor is on (a dashed outline where it was); the panel shows the one
# under it
SWITCH << ["QA_SW2_lifted", SWITCH_HINTS, proc { |o, c|
  empty = proc do |o, c, x, y, m, st|
    chamfer_outline(o, x, y, x + CW, y + CH, 12, MIX.call(c[:line], c[:selb], 0.5), 4)
  end
  party_view(o, c, "Move Gyarados Where?", DST, empty)
  st = his_mix_style
  $type_scale = 0.75; $hp_outline = Color.new(150, 166, 188)
  x, y = slot_xy(DST)
  x -= 6; y -= 8
  chamfer(o, x + 5, y + 6, x + CW + 5, y + CH + 6, 12, Color.new(8, 10, 16), Color.new(8, 10, 16))
  st[:card].call(o, c, x, y, x + CW, y + CH, MONS[SRC], true)
  card_content(o, c, x, y, CW, CH, MONS[SRC])
  $type_scale = nil; $hp_outline = nil
}]

# 3: a swap mark: the one moving dims with a dashed gold edge, the one the
# cursor is on glows, and a swap badge sits between them
SWITCH << ["QA_SW3_swap_mark", SWITCH_HINTS, proc { |o, c|
  dimmed = proc do |o, c, x, y, m, st|
    st[:card].call(o, c, x, y, x + CW, y + CH, m, false)
    card_content(o, c, x, y, CW, CH, m)
    t = Bitmap.new(CW, CH)
    t.fill_rect(0, 0, CW, CH, Color.new(0, 0, 0, 110))
    o.blt(x, y, t, Rect.new(0, 0, CW, CH)); t.dispose
    chamfer_outline(o, x, y, x + CW, y + CH, 12, GOLD_T, 5)
  end
  party_view(o, c, "Move Gyarados Where?", DST, dimmed)
  ax, ay = slot_xy(SRC); bx, by = slot_xy(DST)
  swap_badge(o, c, (ax + CW + bx) / 2, ay + CH / 2)
}]

run_designs("Party switch designs", SWITCH) unless defined?(PARTY_SWITCH_ONLY)
