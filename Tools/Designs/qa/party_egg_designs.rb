# encoding: utf-8
# Mockups: the party screen's details panel for an Egg (the cursor on the
# Egg). PIF's Summary has four stages for an Egg (016_UI Summary
# drawPageOneEgg: under 1275 steps "Sounds can be heard coming from inside!
# It will hatch soon!", then 2550, 10200, and "a long time"); this one is
# at the last. Three designs.
# Sprites: python qa_assets.py "<KIF Beta>" first (writes art/ here).
# Usage (from this folder): ruby party_egg_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
PARTY_SWITCH_ONLY = true
load File.join(File.dirname(File.expand_path(__FILE__)), "party_switch_designs.rb")

EGG_AT = 5
STAGE = "Sounds can be heard coming from inside! It will hatch soon!"
EGG_HINTS = [[:ud, "Choose"], [A_PAD, "Options"], [X_PAD, "Switch"], [B_PAD, "Close"]]
# lines of small text no wider than w
def wrap(o, text, w)
  lines = [""]
  text.split(" ").each do |word|
    try = lines.last.empty? ? word : "#{lines.last} #{word}"
    if small_w(o, try) <= w then lines[-1] = try else lines << word end
  end
  lines
end
def egg_plate(o, c)
  top = MIX.call(c[:panel], Color.new(150, 200, 140), 0.25); bottom = MIX.call(c[:panel], c[:dark], 0.4)
  chamfer_grad(o, DX, GY, DX + DW, GY + DH, 16, top, bottom, MIX.call(c[:line], Color.new(150, 200, 140), 0.4))
  (GY + 2...GY + 137).each do |y|
    under = MIX.call(top, bottom, (y - GY).to_f / DH)
    o.fill_rect(DX + 52 + (GY + 137 - y) / 3, y, 64, 1, MIX.call(under, Color.new(150, 200, 140), 0.3))
  end
  art(o, :EGG, DX + DW / 2, GY + 52, 60)
  P2.text(o, DX, GY + 90, DW, 18, "Egg", c[:txt], PF::TEXT, 2)
  o.fill_rect(DX + 8, GY + 137, DW - 16, 2, POKE_RED)
end

EGGS = []

# 1 Recommended: how close it is as four pips (PIF's four stages, all lit
# here) with PIF's words for the stage, and where it came from
EGGS << ["QA_EG1_stage_pips", EGG_HINTS, proc { |o, c|
  party_view(o, c, "Party", EGG_AT, nil, proc { |o, c, st|
    egg_plate(o, c)
    P2.heading(o, DX + 8, DX + DW - 8, GY + 146, "Hatching", c[:dim], c[:line])
    4.times do |k|
      px = DX + DW / 2 - 4 * 14 / 2 + k * 14
      P2.ui.rbox(o, px, GY + 164, px + 10, GY + 174, 3, GREEN_T)
    end
    wrap(o, STAGE, DW - 20).each_with_index { |ln, j| P2.small(o, DX + 10, GY + 180 + j * 15, DW - 20, 16, ln, c[:txt], 2) }
    P2.heading(o, DX + 8, DX + DW - 8, GY + 232, "From", c[:dim], c[:line])
    P2.small(o, DX + 10, GY + 248, DW - 20, 16, "The Day Care, Route 5", c[:txt], 2)
  })
}]

# 2: the steps left as a bar and a number, with PIF's words under it
EGGS << ["QA_EG2_steps_bar", EGG_HINTS, proc { |o, c|
  party_view(o, c, "Party", EGG_AT, nil, proc { |o, c, st|
    egg_plate(o, c)
    P2.heading(o, DX + 8, DX + DW - 8, GY + 146, "Steps Left", c[:dim], c[:line])
    P2.text(o, DX, GY + 160, DW, 18, "640", c[:txt], PF::TEXT, 2)
    bx = DX + 14; bw = DW - 28
    P2.ui.rbox(o, bx - 2, GY + 182, bx + bw + 2, GY + 190, 2, Color.new(150, 166, 188))
    P2.ui.rbox(o, bx - 1, GY + 183, bx + bw + 1, GY + 189, 1, Color.new(16, 20, 28))
    P2.ui.rbox(o, bx, GY + 184, bx + bw, GY + 188, 1, c[:dark])
    P2.ui.rbox(o, bx, GY + 184, bx + (bw * 0.9).round, GY + 188, 1, GREEN_T)
    wrap(o, STAGE, DW - 20).each_with_index { |ln, j| P2.small(o, DX + 10, GY + 198 + j * 15, DW - 20, 16, ln, c[:dim], 2) }
  })
}]

# 3: only PIF's words for the stage, in a bubble under the Egg
EGGS << ["QA_EG3_bubble", EGG_HINTS, proc { |o, c|
  party_view(o, c, "Party", EGG_AT, nil, proc { |o, c, st|
    egg_plate(o, c)
    lines = wrap(o, STAGE, DW - 36)
    by = GY + 152; bh = lines.length * 15 + 14
    P2.ui.rbox(o, DX + 10, by, DX + DW - 10, by + bh, 6, c[:panel2], c[:line])
    P2.ui.tri(o, DX + DW / 2 - 5, by - 6, :u, c[:line], 5)
    lines.each_with_index { |ln, j| P2.small(o, DX + 18, by + 7 + j * 15, DW - 36, 16, ln, c[:txt], 2) }
  })
}]

run_designs("Party egg designs", EGGS)
