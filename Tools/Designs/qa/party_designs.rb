# encoding: utf-8
# Mockups: a new party screen for Kanto Reloaded (his ask, 2026-10-21: "just
# draft up a whole new party screen", from the level lock mark). Five
# layouts of the main view, in the look he picked for the Reloaded PC, the
# Summary pages and Big Pokémon Icons: type-tinted cards, battle sprites,
# gold levels, small-capital headings.
# The party: Pikachu (Light Ball), Pidgeot (shiny), Gyarados (20/110 HP,
# level locked at Lv 35, the one highlighted), Eevee (Everstone), Genchoke
# (Gengar's head on Machoke's body, poisoned) and an Egg.
# Design 1 = cards with the highlighted one's details beside them (the PC's
# box-and-details layout, with the Summary's facts).
# Sprites: python qa_assets.py "<KIF Beta>" first (writes art/ here).
# Usage (from this folder): ruby party_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "party_common.rb")

DESIGNS = []

# 1 Recommended: cards and details: six type-tinted cards (two across), and
# the highlighted one's details beside them: types, nature, ability, item,
# moves with PP (the PC's box and details, with the Summary's facts)
DESIGNS << ["QA_PS1_cards_details", MAIN_HINTS, proc { |o, c|
  screen(o, c, "Party")
  cw = 152; ch = 96; gx = 8; gy = 38
  MONS.each_with_index do |m, i|
    x = gx + (i % 2) * (cw + 6); y = gy + (i / 2) * (ch + 6)
    card(o, c, x, y, x + cw, y + ch, m, i == SEL)
    art(o, m[:sp], x + 30, y + 46, m[:egg] ? 34 : 50)
    evolock(o, x + 6, y + 64) if m[:evolock]
    if m[:egg]
      P2.text(o, x + 60, y + 28, cw - 66, 18, "Egg", c[:txt], PF::TEXT)
      P2.small(o, x + 60, y + 48, cw - 66, 16, "Soon", c[:dim])
      next
    end
    item_icon(o, m[:item], x + cw - 14, y + 14, 20) if m[:item]
    P2.text(o, x + 60, y + 6, cw - 84, 18, m[:name], c[:txt], PF::TEXT)
    lw = level(o, m, x + 60, y + 28)
    marks(o, m, x + 60 + lw + 5, y + 30)
    type_icons(o, m[:types], x + 60, y + 44)
    status(o, m, x + cw - 6, y + 44)
    hptext(o, c, x + 60, y + 66, cw - 66, m)
    hpbar(o, c, x + 8, y + ch - 12, cw - 16, m)
  end
  # the details
  dx = gx + 2 * cw + 14; dw = SW - 8 - dx; m = MONS[SEL]
  P2.ui.rbox(o, dx, gy, dx + dw, gy + 3 * ch + 12, 6, c[:panel], c[:line])
  art(o, m[:sp], dx + dw / 2, gy + 46, 72)
  nw = P2.width(PF::TEXT, m[:name])
  P2.text(o, dx, gy + 86, dw, 18, m[:name], c[:txt], PF::TEXT, 2)
  level(o, m, dx, gy + 106, 2, dw)
  tw = m[:types].length * 18 - 2
  type_icons(o, m[:types], dx + (dw - tw) / 2, gy + 122)
  heading(o, c, dx + 8, dx + dw - 8, gy + 146, "About")
  [["Nature", m[:nature]], ["Ability", m[:ability]], ["Item", m[:item] ? "Light Ball" : "None"]].each_with_index do |(k, v), j|
    P2.small(o, dx + 8, gy + 162 + j * 16, 60, 16, k, c[:dim])
    P2.small(o, dx + 66, gy + 162 + j * 16, dw - 74, 16, v, c[:txt])
  end
  heading(o, c, dx + 8, dx + dw - 8, gy + 212, "Moves")
  m[:moves].each_with_index { |mv, j| move_row(o, c, dx + 8, gy + 228 + j * 17, dw - 16, mv) }
}]

# 2: six big cards, three across: a big sprite, the name, level and marks,
# types, status, HP; the held item in the corner
DESIGNS << ["QA_PS2_big_cards", MAIN_HINTS, proc { |o, c|
  screen(o, c, "Party")
  cw = 162; ch = 156; gx = 7; gy = 38
  MONS.each_with_index do |m, i|
    x = gx + (i % 3) * (cw + 4); y = gy + (i / 3) * (ch + 6)
    card(o, c, x, y, x + cw, y + ch, m, i == SEL)
    art(o, m[:sp], x + cw / 2, y + 44, m[:egg] ? 46 : 70)
    evolock(o, x + cw / 2 - 40, y + 62) if m[:evolock]
    if m[:egg]
      P2.text(o, x, y + 92, cw, 18, "Egg", c[:txt], PF::TEXT, 2)
      P2.small(o, x, y + 112, cw, 16, "Hatching soon.", c[:dim], 2)
      next
    end
    item_icon(o, m[:item], x + cw - 16, y + 16, 22) if m[:item]
    status(o, m, x + 6, y + 8, false)
    P2.text(o, x, y + 84, cw, 18, m[:name], c[:txt], PF::TEXT, 2)
    mw = m[:g] || m[:shiny] ? 12 : 0
    lw = level(o, m, x, y + 104, 2, cw - mw)
    marks(o, m, x + (cw - mw + lw) / 2 + 4, y + 106)
    tw = m[:types].length * 18 - 2
    type_icons(o, m[:types], x + (cw - tw) / 2, y + 118)
    hptext(o, c, x, y + 136, cw - 10, m)
    hpbar(o, c, x + 10, y + ch - 9, cw - 20, m)
  end
}]

# 3: rows: the whole party top to bottom, each with its sprite, name and
# marks, nature and ability, level, types, HP and status, and item
DESIGNS << ["QA_PS3_rows", MAIN_HINTS, proc { |o, c|
  screen(o, c, "Party")
  rh = 51; gy = 36
  MONS.each_with_index do |m, i|
    y = gy + i * (rh + 2); x = 8; w = SW - 16
    card(o, c, x, y, x + w, y + rh, m, i == SEL)
    art(o, m[:sp], x + 28, y + rh / 2, m[:egg] ? 30 : 42)
    evolock(o, x + 6, y + rh - 18) if m[:evolock]
    if m[:egg]
      P2.text(o, x + 56, y + 8, 160, 18, "Egg", c[:txt], PF::TEXT)
      P2.small(o, x + 56, y + 28, 200, 16, "Hatching soon.", c[:dim])
      next
    end
    nw = P2.text(o, x + 56, y + 6, 120, 18, m[:name], c[:txt], PF::TEXT)
    marks(o, m, x + 56 + nw + 5, y + 10)
    small = m[:fusion] ? m[:fusion] : "#{m[:nature]} · #{m[:ability]}"
    P2.small(o, x + 56, y + 27, 170, 16, small, c[:dim])
    level(o, m, x + 236, y + 10)
    type_icons(o, m[:types], x + 236, y + 26)
    hpbar(o, c, x + 306, y + 14, 112, m)
    hptext(o, c, x + 306, y + 24, 112, m)
    status(o, m, x + 306, y + 22, false)
    item_icon(o, m[:item], x + w - 24, y + rh / 2, 24) if m[:item]
  end
}]

# 4: focus: the party down the left as small cards; the highlighted one big
# on the right with everything about it (Up and Down pick)
DESIGNS << ["QA_PS4_focus", MAIN_HINTS, proc { |o, c|
  screen(o, c, "Party")
  sw = 124; sh = 50; gy = 36
  MONS.each_with_index do |m, i|
    y = gy + i * (sh + 2); x = 8
    card(o, c, x, y, x + sw, y + sh, m, i == SEL)
    art(o, m[:sp], x + 22, y + sh / 2, m[:egg] ? 24 : 34)
    evolock(o, x + 4, y + sh - 17) if m[:evolock]
    font = P2.width(PF::TEXT, m[:name]) > sw - 46 ? PF::TINY : PF::TEXT
    P2.text(o, x + 42, y + (font == PF::TINY ? 9 : 6), sw - 46, 18, m[:name], c[:txt], font)
    next if m[:egg]
    level(o, m, x + 42, y + 24)
    hpbar(o, c, x + 42, y + 40, sw - 50, m, 3)
  end
  m = MONS[SEL]
  dx = 8 + sw + 8; dw = SW - 8 - dx; dy = gy; dh = 6 * (sh + 2) - 2
  P2.ui.rbox(o, dx, dy, dx + dw, dy + dh, 7, tint(c, m), c[:line])
  art(o, m[:sp], dx + 74, dy + 70, 112)
  P2.text(o, dx + 150, dy + 12, 200, 22, m[:name], c[:txt], PF::ROW)
  lw = level(o, m, dx + 150, dy + 40)
  marks(o, m, dx + 150 + lw + 6, dy + 42)
  type_icons(o, m[:types], dx + 150, dy + 56)
  hpbar(o, c, dx + 150, dy + 82, dw - 166, m, 5)
  P2.text(o, dx + 150, dy + 92, dw - 166, 12, "HP #{m[:hp]}/#{m[:tot]}", c[:txt], PF::TINY, 1)
  heading(o, c, dx + 12, dx + dw - 12, dy + 140, "About")
  [["Nature", m[:nature]], ["Ability", m[:ability]], ["Item", "None"], ["Level Lock", "Lv #{m[:lock]}"]].each_with_index do |(k, v), j|
    P2.small(o, dx + 14, dy + 156 + j * 16, 80, 16, k, c[:dim])
    P2.small(o, dx + 100, dy + 156 + j * 16, 120, 16, v, k == "Level Lock" ? GOLD_T : c[:txt])
  end
  heading(o, c, dx + 12, dx + dw - 12, dy + 226, "Moves")
  m[:moves].each_with_index do |mv, j|
    move_row(o, c, dx + 14 + (j % 2) * ((dw - 28) / 2 + 6), dy + 242 + (j / 2) * 20, (dw - 28) / 2 - 6, mv)
  end
}]

# 5: the game's own layout, restyled: two columns of panels set a little
# apart as KIF's are, the help line and Cancel along the bottom
DESIGNS << ["QA_PS5_classic_restyled", [[:ud, "Choose"], [A_PAD, "Options"], [B_PAD, "Close"]], proc { |o, c|
  o.clear
  o.fill_rect(0, 0, SW, SH, c[:bg])
  P2.hints(o, o, c, $qa_hints)
  pw = 248; ph = 88
  MONS.each_with_index do |m, i|
    x = (i % 2) == 0 ? 6 : SW - 6 - pw
    y = 6 + (i / 2) * (ph + 6) + ((i % 2) * 16)
    card(o, c, x, y, x + pw, y + ph, m, i == SEL)
    art(o, m[:sp], x + 36, y + ph / 2, m[:egg] ? 36 : 56)
    evolock(o, x + 8, y + ph - 22) if m[:evolock]
    if m[:egg]
      P2.text(o, x + 74, y + 30, 120, 18, "Egg", c[:txt], PF::TEXT)
      next
    end
    nw = P2.text(o, x + 74, y + 8, 130, 18, m[:name], c[:txt], PF::TEXT)
    marks(o, m, x + 74 + nw + 5, y + 12)
    item_icon(o, m[:item], x + pw - 16, y + 16, 20) if m[:item]
    hpbar(o, c, x + 74, y + 36, pw - 88, m, 5)
    level(o, m, x + 74, y + 50)
    status(o, m, x + 74 + 60, y + 48, false)
    hptext(o, c, x + 74, y + 50, pw - 88, m)
    type_icons(o, m[:types], x + 74, y + 66)
  end
  hy = HINT_TOP - 42
  P2.ui.rbox(o, 6, hy, 380, hy + 36, 6, c[:panel], c[:line])
  P2.text(o, 18, hy + 9, 350, 18, "Choose a Pokémon or cancel.", c[:txt], PF::TEXT)
  P2.ui.rbox(o, 388, hy, SW - 6, hy + 36, 6, c[:panel2], c[:line])
  P2.text(o, 388, hy + 9, SW - 394, 18, "Cancel", c[:txt], PF::TEXT, 2)
}]

run_designs("Party screen designs", DESIGNS)
