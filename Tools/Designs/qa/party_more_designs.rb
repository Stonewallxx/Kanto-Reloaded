# encoding: utf-8
# Mockups: the party screen's last pieces (his asks, 2026-10-21), in his
# look (His Mix): a message on the screen (a Potion used on Gyarados),
# fewer than six Pokemon, EXP to the next level, and Theme Mode (Light,
# Glass, Frost: what shows behind the see-through ones). Three designs each;
# Design 1 is the recommendation.
# Sprites: python qa_assets.py "<KIF Beta>" first (writes art/ here).
# Usage (from this folder): ruby party_more_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
PARTY_SWITCH_ONLY = true
load File.join(File.dirname(File.expand_path(__FILE__)), "party_switch_designs.rb")

MSG = "Gyarados's HP was restored by 20 points."
MSG_HINTS = [[A_PAD, "Continue"]]
EXP = { :PIKACHU => [0.62, 1240], :PIDGEOT => [0.3, 2980], :EEVEE => [0.8, 310], :GENCHOKE => [0.45, 1720] }
BLACK = Color.new(0, 0, 0)

# lines of small text no wider than w
def lines_of(o, text, w)
  out = [""]
  text.split(" ").each do |word|
    try = out.last.empty? ? word : "#{out.last} #{word}"
    if small_w(o, try) <= w then out[-1] = try else out << word end
  end
  out
end
# the party with Gyarados at 40 HP (the Potion's bar filling)
def mons_healed
  MONS.map(&:dup).tap { |l| l[2] = l[2].merge(:hp => 40) }
end
def continue_mark(o, c, x, y)
  P2.ui.tri(o, x, y, :d, c[:selb], 5)
end
# an outlined bar (as the HP bars), frac full in col
def bar(o, c, x, y, w, frac, col, h = 4)
  P2.ui.rbox(o, x - 2, y - 2, x + w + 2, y + h + 2, 2, Color.new(150, 166, 188))
  P2.ui.rbox(o, x - 1, y - 1, x + w + 1, y + h + 1, 1, Color.new(16, 20, 28))
  P2.ui.rbox(o, x, y, x + w, y + h, 1, c[:dark])
  P2.ui.rbox(o, x, y, x + [(w * frac).round, 2].max, y + h, 1, col) if frac > 0
end

#---------------------------------------------------------------- see-through plates (Theme Mode)
# While $plate_alpha is set, the plates (gradients and cut-corner boxes)
# are drawn see-through: over the map ($wash: a layer between), or blended
# into the screen's own background ($under: its colour at y)
def glassy(col, y = 0)
  return col unless $plate_alpha
  a = $plate_alpha / 255.0
  return Reloaded::Palette.over($under.call(y), col, $plate_alpha) if $under
  if $wash
    w, wa = $wash
    wa /= 255.0
    ae = a + wa * (1 - a)
    f = proc { |cc, ww| ((cc * a + ww * wa * (1 - a)) / ae).round }
    return Color.new(f.call(col.red, w.red), f.call(col.green, w.green), f.call(col.blue, w.blue), (ae * 255).round)
  end
  return Color.new(col.red, col.green, col.blue, $plate_alpha)
end
def grad(o, x0, y0, x1, y1, top, bottom, inset = nil)
  h = [y1 - y0, 1].max
  (y0...y1).each do |y|
    a, b = inset ? inset.call(y) : [0, 0]
    o.fill_rect(x0 + a, y, x1 - x0 - a - b, 1, glassy(MIX.call(top, bottom, (y - y0).to_f / h), y))
  end
end
def chamfer(o, x0, y0, x1, y1, cut, fill, edge)
  (y0...y1).each do |y|
    l = [cut - (y - y0), 0].max; r = [cut - (y1 - 1 - y), 0].max
    o.fill_rect(x0 + l, y, x1 - x0 - l - r, 1, glassy(edge, y))
  end
  (y0 + 1...y1 - 1).each do |y|
    l = [cut - (y - y0), 0].max; r = [cut - (y1 - 1 - y), 0].max
    o.fill_rect(x0 + 1 + l, y, x1 - x0 - 2 - l - r, 1, glassy(fill, y))
  end
end
# His Mix, its type bands see-through with the plates, and a pale
# background on a Light palette
HIS_MIX = method(:his_mix_style)
def his_mix_style
  st = HIS_MIX.call
  st[:bg] = proc do |o, c|
    next if $no_bg
    bottom = c[:light] ? MIX.call(c[:bg], c[:acc], 0.15) : MIX.call(c[:bg], BLACK, 0.4)
    keep = $plate_alpha
    $plate_alpha = nil
    grad(o, 0, 0, SW, SH, MIX.call(c[:bg], c[:sel], 0.35), bottom)
    $plate_alpha = keep
    dot = MIX.call(c[:bg], c[:line], 0.6)
    (40...HINT_TOP).step(12) { |y| (6...SW).step(12) { |x| o.fill_rect(x, y, 1, 1, dot) } }
  end
  card = st[:card]
  st[:card] = proc do |o, c, x0, y0, x1, y1, m, sel|
    next card.call(o, c, x0, y0, x1, y1, m, sel) unless $plate_alpha
    # the same card, its slash band drawn through glassy
    cut = 12
    if sel
      chamfer(o, x0 - 3, y0 - 3, x1 + 3, y1 + 3, cut + 2, MIX.call(c[:bg], c[:selb], 0.25), MIX.call(c[:bg], c[:selb], 0.25))
      chamfer(o, x0 - 1, y0 - 1, x1 + 1, y1 + 1, cut + 1, MIX.call(c[:bg], c[:selb], 0.6), MIX.call(c[:bg], c[:selb], 0.6))
    end
    top = MIX.call(c[:panel2], tone(c, m), m[:egg] ? 0.1 : 0.5)
    bottom = MIX.call(c[:panel2], c[:dark], 0.5)
    chamfer_grad(o, x0, y0, x1, y1, cut, top, bottom, sel ? c[:selb] : MIX.call(c[:line], tone(c, m), 0.4))
    unless m[:egg]
      (y0 + 2...y1 - 2).each do |y|
        under = MIX.call(top, bottom, (y - y0).to_f / (y1 - y0))
        o.fill_rect(x0 + 8 + (y1 - y) / 3, y, 30, 1, glassy(MIX.call(under, tone(c, m), 0.45), y))
      end
      o.fill_rect(x0 + 13, y0 + 1, x1 - x0 - 16, 1, MIX.call(tone(c, m), WHITE, 0.4))
    end
    nil
  end
  details = st[:details]
  st[:details] = proc do |o, c, x0, y0, x1, y1, m|
    next details.call(o, c, x0, y0, x1, y1, m) unless $plate_alpha
    top = MIX.call(c[:panel], tcol(m[:types][0]), 0.4); bottom = MIX.call(c[:panel], c[:dark], 0.4)
    chamfer_grad(o, x0, y0, x1, y1, 16, top, bottom, MIX.call(c[:line], tcol(m[:types][0]), 0.5))
    line_y = y0 + 137
    (y0 + 2...line_y).each do |y|
      under = MIX.call(top, bottom, (y - y0).to_f / (y1 - y0))
      o.fill_rect(x0 + 52 + (line_y - y) / 3, y, 64, 1, glassy(MIX.call(under, tcol(m[:types][0]), 0.4), y))
    end
    o.fill_rect(x0 + 8, line_y, x1 - x0 - 16, 2, POKE_RED)
    nil
  end
  header = st[:header]
  st[:header] = proc do |o, c, t|
    grad(o, 0, 0, SW, 30, MIX.call(c[:panel], c[:selb], 0.25), c[:panel])
    o.fill_rect(0, 29, SW, 2, POKE_RED)
    P2.text(o, 0, 4, SW, 22, t, c[:txt], PF::ROW, 2)
  end
  st
end

# Light: the Light frames' look (Matching Frames, as the map menus), with
# the statuses deepened
LIGHT_SWAP = { :GREEN_T => [30, 140, 70], :GOLD_T => [176, 118, 0], :PINK_T => [196, 56, 116], :RED_T => [196, 48, 48],
               :AMBER_T => [196, 104, 0], :BLUE_T => [30, 96, 196], :GOLD_FILL => [244, 230, 196] }
def with_light
  keep = {}
  $VERBOSE = nil
  LIGHT_SWAP.each do |k, rgb|
    keep[k] = Object.const_get(k)
    Object.send(:remove_const, k)
    Object.const_set(k, Color.new(*rgb))
  end
  yield Reloaded::Palette.light_from(Reloaded::Palette.current, nil)
ensure
  keep.each { |k, v| Object.send(:remove_const, k); Object.const_set(k, v) }
end
# the Overworld Menu under the mockups stays out of sight (the map shows)
def hide_menu
  %i[@sprite @top_sprite @left @hint_sprite @cursor_sprite].each { |v| (s = om.instance_variable_get(v)) && s.visible = false }
  (om.instance_variable_get(:@cards) || []).each { |s| s.visible = false }
end
# the party in a Theme Mode (:light, :glass, :frost) with what's behind
# the see-through ones (:map, :dim, :own)
def themed(o, c, mode, behind)
  hide_menu
  draw = proc do |pal|
    $plate_alpha = { :glass => 170, :frost => 185 }[mode]
    $no_bg = $plate_alpha && behind != :own
    $wash = nil
    $under = nil
    o.clear
    if $plate_alpha && behind == :dim
      $wash = pal[:light] ? [pal[:panel2], 130] : [BLACK, 110]
      w = $wash[0]
      o.fill_rect(0, 0, SW, SH, Color.new(w.red, w.green, w.blue, $wash[1]))
    end
    if $plate_alpha && behind == :own
      top = MIX.call(pal[:bg], pal[:sel], 0.35)
      bottom = pal[:light] ? MIX.call(pal[:bg], pal[:acc], 0.15) : MIX.call(pal[:bg], BLACK, 0.4)
      $under = proc { |y| MIX.call(top, bottom, y.to_f / SH) }
    end
    party_view_keep(o, pal, "Party", SEL)
    $plate_alpha = $no_bg = $wash = $under = nil
  end
  mode == :glass ? draw.call(c) : with_light { |pal| draw.call(pal) }
end
# party_view, without clearing what's been drawn (the wash)
def party_view_keep(o, c, title, sel)
  st = his_mix_style
  $type_scale = 0.75
  $hp_outline = Color.new(150, 166, 188)
  st[:bg].call(o, c)
  st[:header].call(o, c, title)
  P2.hints(o, o, c, $qa_hints)
  MONS.each_with_index do |m, i|
    x, y = slot_xy(i)
    st[:card].call(o, c, x, y, x + CW, y + CH, m, i == sel)
    card_content(o, c, x, y, CW, CH, m)
  end
  st[:details].call(o, c, DX, GY, DX + DW, GY + DH, MONS[sel])
  details_content(o, c, DX, GY, DW, MONS[sel])
  $type_scale = nil
  $hp_outline = nil
end

DESIGNS_MORE = []

#---------------------------------------------------------------- messages
# 1 Recommended: in the panel: its short top, the HP filling, and the
# message under it; A goes on
DESIGNS_MORE << ["QA_PX_M1_in_panel", MSG_HINTS, proc { |o, c|
  mons = mons_healed
  party_view(o, c, "Party", SEL, nil, proc { |o, c, st|
    panel_top(o, c)
    P2.heading(o, DX + 10, DX + DW - 10, GY + 56, "HP", c[:dim], c[:line])
    bar(o, c, DX + 14, GY + 76, DW - 28, 40 / 110.0, AMBER_T, 5)
    P2.text(o, DX, GY + 88, DW - 14, 12, "40/110", c[:txt], PF::TINY, 1)
    lines_of(o, MSG, DW - 24).each_with_index { |ln, j| P2.small(o, DX + 12, GY + 112 + j * 16, DW - 24, 16, ln, c[:txt], 2) }
    continue_mark(o, c, DX + DW / 2 - 5, GY + DH - 22)
  }, mons)
}]

# 2: a message bar along the bottom, over the last row, as the game's
# own box is
DESIGNS_MORE << ["QA_PX_M2_message_bar", MSG_HINTS, proc { |o, c|
  party_view(o, c, "Party", SEL, nil, nil, mons_healed)
  y0 = HINT_TOP - 52; y1 = HINT_TOP - 8
  chamfer_grad(o, 8, y0, SW - 8, y1, 12, MIX.call(c[:panel], c[:selb], 0.22), c[:panel], c[:selb])
  o.fill_rect(20, y0 + 1, SW - 40, 1, MIX.call(c[:selb], WHITE, 0.4))
  P2.text(o, 22, y0 + 13, SW - 70, 18, MSG, c[:txt], PF::TEXT)
  continue_mark(o, c, SW - 30, y0 + 19)
}]

# 3: a bubble over the Pokemon it's about
DESIGNS_MORE << ["QA_PX_M3_bubble", MSG_HINTS, proc { |o, c|
  party_view(o, c, "Party", SEL, nil, nil, mons_healed)
  x, y = slot_xy(SEL)
  bx0 = x + 4; bx1 = x + 2 * CW + 2; by1 = y - 4; by0 = by1 - 40
  P2.ui.rbox(o, bx0, by0, bx1, by1, 6, c[:panel2], c[:selb])
  P2.ui.tri(o, x + 26, by1 - 1, :d, c[:selb], 6)
  lines_of(o, MSG, bx1 - bx0 - 30).each_with_index { |ln, j| P2.small(o, bx0 + 10, by0 + 5 + j * 15, bx1 - bx0 - 30, 16, ln, c[:txt]) }
  continue_mark(o, c, bx1 - 16, by1 - 14)
}]

#---------------------------------------------------------------- fewer than six
FOUR = MONS.first(4)
def empties(o, c)
  (4..5).each { |i| x, y = slot_xy(i); yield x, y }
end
# 1 Recommended: faint plates, so the layout never moves
DESIGNS_MORE << ["QA_PX_E1_faint_plates", MAIN_HINTS, proc { |o, c|
  party_view(o, c, "Party", SEL, nil, nil, FOUR)
  empties(o, c) { |x, y| chamfer(o, x, y, x + CW, y + CH, 12, MIX.call(c[:bg], c[:panel2], 0.35), MIX.call(c[:bg], c[:line], 0.55)) }
}]
# 2: a dashed outline saying EMPTY
DESIGNS_MORE << ["QA_PX_E2_dashed", MAIN_HINTS, proc { |o, c|
  party_view(o, c, "Party", SEL, nil, nil, FOUR)
  empties(o, c) do |x, y|
    chamfer_outline(o, x, y, x + CW, y + CH, 12, MIX.call(c[:line], c[:dim], 0.3), 4)
    P2.text(o, x, y + CH / 2 - 6, CW, 12, "EMPTY", c[:dim], PF::TINY, 2)
  end
}]
# 3: a faint plate with a Poke Ball's outline where the sprite would be
DESIGNS_MORE << ["QA_PX_E3_ball_slot", MAIN_HINTS, proc { |o, c|
  party_view(o, c, "Party", SEL, nil, nil, FOUR)
  empties(o, c) do |x, y|
    chamfer(o, x, y, x + CW, y + CH, 12, MIX.call(c[:bg], c[:panel2], 0.35), MIX.call(c[:bg], c[:line], 0.55))
    faint = MIX.call(c[:bg], c[:line], 0.75)
    disc(o, x + 30, y + 46, 17, faint)
    disc(o, x + 30, y + 46, 15, MIX.call(c[:bg], c[:panel2], 0.35))
    o.fill_rect(x + 13, y + 45, 35, 2, faint)
    disc(o, x + 30, y + 46, 5, faint)
    disc(o, x + 30, y + 46, 3, MIX.call(c[:bg], c[:panel2], 0.35))
  end
}]

#---------------------------------------------------------------- EXP to the next level
PIKA = 0
# 1 Recommended: a thin bar under the level in the panel, how much to go
# beside the level
DESIGNS_MORE << ["QA_PX_X1_under_level", MAIN_HINTS, proc { |o, c|
  party_view(o, c, "Party", PIKA)
  frac, left = EXP[:PIKACHU]
  bw = 96; bx = DX + (DW - bw) / 2
  bar(o, c, bx, GY + 108, bw, frac, BLUE_T, 2)
  P2.small(o, DX, GY + 95, DW - 10, 14, "", c[:dim], 1)
}]
# 2: a row of its own under About: the bar and what's left
DESIGNS_MORE << ["QA_PX_X2_about_row", MAIN_HINTS, proc { |o, c|
  party_view(o, c, "Party", PIKA, nil, proc { |o, c, st|
    m = MONS[PIKA]
    $type_scale = 0.75
    st[:details].call(o, c, DX, GY, DX + DW, GY + DH, m)
    # details_content, with an EXP row under About (moves move down)
    art(o, m[:sp], DX + DW / 2, GY + 40, 64)
    P2.text(o, DX, GY + 76, DW, 18, m[:name], c[:txt], PF::TEXT, 2)
    level(o, m, DX, GY + 95, 2, DW)
    lw = 48; tw = m[:types].length * (lw + 2) - 2
    m[:types].each_with_index { |t, j| big_type(o, t, DX + (DW - tw) / 2 + j * (lw + 2), GY + 113, 0.75) }
    P2.heading(o, DX + 8, DX + DW - 8, GY + 144, "About", c[:dim], c[:line])
    [["Nature", m[:nature]], ["Ability", m[:ability]], ["Item", "Light Ball"]].each_with_index do |(k, v), j|
      P2.small(o, DX + 8, GY + 158 + j * 16, 60, 16, k, c[:dim])
      P2.small(o, DX + 66, GY + 158 + j * 16, DW - 74, 16, v, c[:txt])
    end
    P2.small(o, DX + 8, GY + 206, 60, 16, "EXP", c[:dim])
    bar(o, c, DX + 68, GY + 212, DW - 120, EXP[:PIKACHU][0], BLUE_T, 3)
    P2.small(o, DX + DW - 48, GY + 206, 40, 16, "1,240", c[:txt], 1)
    P2.heading(o, DX + 8, DX + DW - 8, GY + 226, "Moves", c[:dim], c[:line])
    m[:moves].each_with_index do |(name, pp, max, t), j|
      yy = GY + 238 + j * 16
      P2.ui.rbox(o, DX + 8, yy + 3, DX + 12, yy + 13, 1, tcol(t))
      P2.text(o, DX + 17, yy, DW - 66, 16, name, c[:txt], PF::TEXT)
      P2.text(o, DX + DW - 48, yy + 2, 40, 12, "#{pp}/#{max}", pp < max ? AMBER_T : c[:dim], PF::TINY, 1)
    end
    $type_scale = nil
  })
}]
# 3: on every card, under the HP bar (a locked one's gold and full)
DESIGNS_MORE << ["QA_PX_X3_every_card", MAIN_HINTS, proc { |o, c|
  party_view(o, c, "Party", PIKA)
  MONS.each_with_index do |m, i|
    next if m[:egg]
    x, y = slot_xy(i)
    locked = m[:lock] && m[:lock] <= m[:lv]
    frac = locked ? 1.0 : (EXP[m[:sp]] || [0.5])[0]
    o.fill_rect(x + 10, y + CH - 6, CW - 28, 2, c[:dark])
    o.fill_rect(x + 10, y + CH - 6, ((CW - 28) * frac).round, 2, locked ? GOLD_T : BLUE_T)
  end
}]

#---------------------------------------------------------------- Theme Mode
# each design: Light, Glass and Frost (three pictures; Light is the same in
# all three). What's behind the see-through ones is what was on screen when
# it opened (the map, a battle). 1 Recommended: that, dimmed (Glass) or
# washed pale (Frost), so the words read over a busy map
[["dim", :dim], ["map", :map], ["own", :own]].each_with_index do |(word, behind), k|
  [:light, :glass, :frost].each do |mode|
    DESIGNS_MORE << ["QA_PX_T#{k + 1}_#{word}_#{mode}", MAIN_HINTS, proc { |o, c| themed(o, c, mode, behind) }]
  end
end

run_designs("Party screen, the last pieces", DESIGNS_MORE)
