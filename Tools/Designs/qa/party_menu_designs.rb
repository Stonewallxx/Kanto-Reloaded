# encoding: utf-8
# Mockups: the party screen's command menu (what A opens on a Pokémon), over
# the main view he locked in (QA_PS1f, His Mix). Five designs.
# Gyarados's options, as KIF Beta builds them (016_UI/005_UI_Party.rb
# pbPokemonScreen, then KIF's hooks): Summary, its field move Waterfall,
# Switch, Hat, Item, Nickname, Change Moves, Fuse (with DNA Splicers in the
# Bag), KIF's Kuray Actions (KIF::PCActions: Export, Lock Evolution, the
# shiny actions...), and "Walk Together", an option another mod adds (his
# ask: other mods' options show here too). B is Cancel.
# Sprites: python qa_assets.py "<KIF Beta>" first (writes art/ here).
# Usage (from this folder): ruby party_menu_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
PARTY_LOOK_ONLY = true
load File.join(File.dirname(File.expand_path(__FILE__)), "party_styled_designs.rb")

# [label, kind]: :field (a field move, its type), :sub (opens more), :mod
CMDS = [["Summary"], ["Waterfall", :field, :WATER], ["Switch"], ["Hat"], ["Item"], ["Nickname"], ["Change Moves"],
        ["Fuse"], ["Kuray Actions", :sub], ["Walk Together", :mod]]
FIELD_T = Color.new(130, 190, 250)
MENU_HINTS = [[:ud, "Choose"], [A_PAD, "Select"], [B_PAD, "Back"]]
SEL_CARD = [GX, GY + (CH + 6), GX + CW, GY + (CH + 6) + CH]   # Gyarados's card

# one option: a field move in blue with its type's chip, an arrow on one
# that opens more
def cmd_row(o, c, x, y, w, cmd, on, h = 18)
  label, kind, type = cmd
  cursor(o, c, x - 4, y, x + w + 4, y + h) if on
  tx = x + 4
  if kind == :field
    P2.ui.rbox(o, tx, y + 4, tx + 4, y + 14, 1, tcol(type))
    tx += 9
  end
  # a label too long for the row steps down to the small font (as names do)
  room = w - (tx - x) - (kind == :sub ? 12 : 2)
  font = P2.width(PF::TEXT, label) > room ? PF::TINY : PF::TEXT
  P2.text(o, tx, y + (font == PF::TINY ? 4 : 1), room, 16, label, kind == :field ? FIELD_T : c[:txt], font)
  P2.ui.tri(o, x + w - 8, y + 5, :r, c[:dim], 4) if kind == :sub
end
def menu_backdrop(o, c)
  his_mix(o, c)
  # the hint bar becomes the menu's; the rest of the screen dims
  shade(o)
  P2.hints(o, o, c, $qa_hints)
end

MENU = []

# 1 Recommended: a popup beside the highlighted card, the options in the
# game's order; the card stays lit
MENU << ["QA_PM1_beside_card", MENU_HINTS, proc { |o, c|
  menu_backdrop(o, c)
  x0, y0, x1, y1 = SEL_CARD
  # the card again, undimmed
  his = his_mix_style
  $hp_outline = Color.new(150, 166, 188)
  his[:card].call(o, c, x0, y0, x1, y1, MONS[SEL], true)
  card_content(o, c, x0, y0, CW, CH, MONS[SEL])
  $hp_outline = nil
  w = 168; rh = 19; h = 40 + CMDS.length * rh + 8
  x = x1 + 10; y = [[y0 + CH / 2 - h / 2, 36].max, HINT_TOP - h - 6].min
  popup(o, c, x, y, w, h, "Gyarados", false)
  CMDS.each_with_index { |cmd, i| cmd_row(o, c, x + 12, y + 38 + i * rh, w - 24, cmd, i == 0, rh) }
}]

# 2: the details panel turns into the menu: a short top (name, level,
# types, the red line), the options under it, and a line saying what the
# highlighted one does
DESC = { "Summary" => "Gyarados's details." }
# the panel's short top: its plate, the type band, sprite, name, level and
# the red line (his pick, Panel Menu)
def panel_top(o, c)
  m = MONS[SEL]
  top = MIX.call(c[:panel], tcol(m[:types][0]), 0.4); bottom = MIX.call(c[:panel], c[:dark], 0.4)
  chamfer_grad(o, DX, GY, DX + DW, GY + DH, 16, top, bottom, MIX.call(c[:line], tcol(m[:types][0]), 0.5))
  (GY + 2...GY + 44).each do |y|
    under = MIX.call(top, bottom, (y - GY).to_f / DH)
    o.fill_rect(DX + 96 + (GY + 44 - y) / 3, y, 50, 1, MIX.call(under, tcol(m[:types][0]), 0.4))
  end
  art(o, m[:sp], DX + 26, GY + 22, 34)
  P2.text(o, DX + 48, GY + 6, 100, 18, m[:name], c[:txt], PF::TEXT)
  level(o, m, DX + 48, GY + 25)
  o.fill_rect(DX + 8, GY + 44, DW - 16, 2, POKE_RED)
end
# what the highlighted option does, along the panel's foot
def panel_foot(o, c, words)
  o.fill_rect(DX + 8, GY + 250, DW - 16, 1, c[:line])
  P2.small(o, DX + 8, GY + 256, DW - 16, 16, words, c[:dim], 2)
end
MENU << ["QA_PM2_panel_menu", MENU_HINTS, proc { |o, c|
  his_mix(o, c)
  panel_top(o, c)
  CMDS.each_with_index { |cmd, i| cmd_row(o, c, DX + 12, GY + 52 + i * 19, DW - 24, cmd, i == 0, 19) }
  panel_foot(o, c, DESC["Summary"])
  P2.hints(o, o, c, $qa_hints)
}]

# 3: grouped: the options under small headings (Pokémon, Field Moves, Party,
# Fusion, More); options from other mods go under More
MENU << ["QA_PM3_grouped", MENU_HINTS, proc { |o, c|
  menu_backdrop(o, c)
  groups = [["Pokémon", [CMDS[0], CMDS[5], CMDS[6], CMDS[3]]], ["Field Moves", [CMDS[1]]],
            ["Party", [CMDS[2], CMDS[4]]], ["Fusion", [CMDS[7]]], ["More", [CMDS[8], CMDS[9]]]]
  w = 330; h = 196
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2 + 10
  popup(o, c, x, y, w, h, "Gyarados", false)
  cols = [[groups[0], groups[1]], [groups[2], groups[3], groups[4]]]
  first = true
  cols.each_with_index do |col, ci|
    cx = x + 14 + ci * (w / 2)
    cy = y + 40
    col.each do |title, list|
      P2.heading(o, cx, cx + w / 2 - 28, cy, title, c[:dim], c[:line])
      cy += 14
      list.each { |cmd| cmd_row(o, c, cx, cy, w / 2 - 28, cmd, first); first = false; cy += 18 }
      cy += 4
    end
  end
}]

# 4: tiles: the options as buttons, three across, in a popup over the
# middle; a field move's tile in its type's colour
MENU << ["QA_PM4_tiles", MENU_HINTS, proc { |o, c|
  menu_backdrop(o, c)
  tw = 150; th = 30; gap = 6
  rows = (CMDS.length + 2) / 3
  w = 3 * tw + 4 * gap; h = 40 + rows * (th + gap) + gap
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2 + 8
  popup(o, c, x, y, w, h, "Gyarados", false)
  CMDS.each_with_index do |(label, kind, type), i|
    tx = x + gap + (i % 3) * (tw + gap); ty = y + 38 + gap + (i / 3) * (th + gap)
    on = i == 0
    P2.ui.rbox(o, tx, ty, tx + tw, ty + th, 5, on ? c[:sel] : c[:panel2], on ? c[:selb] : c[:line])
    P2.ui.rbox(o, tx + 6, ty + 9, tx + 10, ty + 21, 1, tcol(type)) if kind == :field
    P2.text(o, tx, ty + 6, tw - (kind == :sub ? 10 : 0), 18, label, kind == :field ? FIELD_T : c[:txt], PF::TEXT, 2)
    P2.ui.tri(o, tx + tw - 10, ty + 11, :r, c[:dim], 4) if kind == :sub
  end
}]

# 5: short, then More: the everyday options (Summary, Switch, Item, field
# moves); More opens the rest beside it (shown open)
MENU << ["QA_PM5_short_and_more", MENU_HINTS, proc { |o, c|
  menu_backdrop(o, c)
  x0, y0, x1, y1 = SEL_CARD
  short = [CMDS[0], CMDS[1], CMDS[2], CMDS[4], ["More", :sub]]
  w = 140; rh = 19; h = 40 + short.length * rh + 8
  x = x1 + 10; y = y0 - 10
  popup(o, c, x, y, w, h, "Gyarados", false)
  short.each_with_index { |cmd, i| cmd_row(o, c, x + 12, y + 38 + i * rh, w - 24, cmd, false, rh) }
  cursor(o, c, x + 8, y + 38 + 4 * rh, x + w - 8, y + 38 + 5 * rh)
  cmd_row(o, c, x + 12, y + 38 + 4 * rh, w - 24, short[4], false, rh)
  more = [CMDS[3], CMDS[5], CMDS[6], CMDS[7], CMDS[8], CMDS[9]]
  mw = 160; mh = 40 + more.length * rh + 8
  mx = x + w + 6; my = y + 38 + 4 * rh - 20
  my = [my, HINT_TOP - mh - 6].min
  popup(o, c, mx, my, mw, mh, "More", false)
  more.each_with_index { |cmd, i| cmd_row(o, c, mx + 12, my + 38 + i * rh, mw - 24, cmd, i == 0, rh) }
}]

run_designs("Party command menu designs", MENU) unless defined?(PARTY_MENU_ONLY)
