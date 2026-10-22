# encoding: utf-8
# Mockups: a submenu in the party screen's Panel Menu (his pick): KIF's
# Kuray Actions on Gyarados (KIF::PCActions: Export, Export All Pokemons,
# Lock Evolution, Gamble for Shiny; labels as KIF gives them). Item's Give /
# Take / Move, and any mod's submenu, open the same way. Three designs.
# Sprites: python qa_assets.py "<KIF Beta>" first (writes art/ here).
# Usage (from this folder): ruby party_sub_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
PARTY_MENU_ONLY = true
load File.join(File.dirname(File.expand_path(__FILE__)), "party_menu_designs.rb")

KURAY = [["Export"], ["Export All Pokemons"], ["Lock Evolution"], ["Gamble for Shiny"]]
KURAY_AT = 8                                   # its row in the main list
SUB_HINTS = [[:ud, "Choose"], [A_PAD, "Select"], [B_PAD, "Back"]]
EXPORT_WORDS = "Saves it to a file."

SUB = []

# 1 Recommended: in place: the panel's list becomes the submenu, under a
# heading naming it; B goes back to the main list (on Kuray Actions)
SUB << ["QA_PB1_in_place", SUB_HINTS, proc { |o, c|
  his_mix(o, c)
  panel_top(o, c)
  P2.heading(o, DX + 10, DX + DW - 10, GY + 52, "Kuray Actions", c[:dim], c[:line])
  KURAY.each_with_index { |cmd, i| cmd_row(o, c, DX + 12, GY + 68 + i * 19, DW - 24, cmd, i == 0, 19) }
  panel_foot(o, c, EXPORT_WORDS)
  P2.hints(o, o, c, $qa_hints)
}]

# 2: slide-out: the main list stays (Kuray Actions marked), and the
# submenu opens beside the panel, over the cards
SUB << ["QA_PB2_slide_out", SUB_HINTS, proc { |o, c|
  his_mix(o, c)
  panel_top(o, c)
  CMDS.each_with_index { |cmd, i| cmd_row(o, c, DX + 12, GY + 52 + i * 19, DW - 24, cmd, i == KURAY_AT, 19) }
  panel_foot(o, c, EXPORT_WORDS)
  shade(o)
  # the panel's list again, undimmed, with the submenu out to its left
  w = 176; rh = 19; h = 40 + KURAY.length * rh + 8
  x = DX - w - 4; y = GY + 52 + KURAY_AT * 19 - 40
  popup(o, c, x, y, w, h, "Kuray Actions", false)
  KURAY.each_with_index { |cmd, i| cmd_row(o, c, x + 12, y + 38 + i * rh, w - 24, cmd, i == 0, rh) }
  P2.hints(o, o, c, $qa_hints)
}]

# 3: inline: Kuray Actions opens under itself in the list, its options set
# in with a line down their left; the rows below move down
SUB << ["QA_PB3_inline", SUB_HINTS, proc { |o, c|
  his_mix(o, c)
  panel_top(o, c)
  rows = CMDS[0, KURAY_AT + 1].map { |cmd| [cmd, false] } + KURAY.map { |cmd| [cmd, true] } + CMDS[KURAY_AT + 1..-1].map { |cmd| [cmd, false] }
  # the list scrolls to keep the open group in view
  top_row = 3
  rh = 17
  rows[top_row, 11].each_with_index do |(cmd, inner), i|
    y = GY + 52 + i * rh
    x = DX + 12 + (inner ? 12 : 0)
    on = inner && cmd == KURAY[0]
    o.fill_rect(DX + 16, y, 1, rh, c[:selb]) if inner
    label, kind = cmd
    kind = :open if cmd == CMDS[KURAY_AT]
    cmd_row(o, c, x, y - 1, DW - 24 - (inner ? 12 : 0), [label, kind == :open ? nil : kind], on, rh)
    P2.ui.tri(o, DX + DW - 22, y + 5, :d, c[:dim], 4) if kind == :open
  end
  P2.ui.tri(o, DX + DW / 2 - 4, GY + 47, :u, c[:dim], 4)
  panel_foot(o, c, EXPORT_WORDS)
  P2.hints(o, o, c, $qa_hints)
}]

run_designs("Party submenu designs", SUB)
