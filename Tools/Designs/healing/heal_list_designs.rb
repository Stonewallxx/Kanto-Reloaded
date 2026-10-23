# encoding: utf-8
# Mockups: Healing Moves' Heal with Moves list (Roadmap topic
# healing-overworld; Healer List chosen 2026-10-17, its contents agreed
# 2026-10-23), opened from the Overworld Menu as a panel over the map, in
# Reloaded's plate look (his reminder: the Party Screen's angled plates,
# Header Plate popups).
# Design 1 = Healer List: the chosen design in plates. Heal Everyone first,
#            then each healer on a plate of its type, its healing moves
#            under it with uses left; the party's HP along the bottom.
# Design 2 = Healer Cards: the healers as Party Screen cards on the left,
#            the picked one's moves on the right with what each does.
# Design 3 = Party First: the party as cards; pick who needs healing, and
#            the moves that can heal it are listed beside.
# Party: Chansey (Soft-Boiled, Heal Bell), Pikachu hurt, Gengar poisoned,
# Alakazam (Recover), Snorlax (Rest), Pidgeot (Roost).
# Sprites: python ../qa/qa_assets.py "<KIF Beta>" first (writes ../qa/art).
# Usage (from this folder): ruby heal_list_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "healing_common.rb")

#---------------------------------------------------------------- Design 2
def healer_cards(o, c)
  x, y, w, h = map_panel(o, c, "Heal with Moves")
  top = y + 40
  cw = 170; ch = 50; gap = 6
  HEALERS.each_with_index do |(sp, name, hp, max, types), i|
    cy = top + i * (ch + gap)
    plate(o, c, x + 12, cy, x + 12 + cw, cy + ch, tcol(types[0]), 10, i == 0)
    art(o, sp, x + 36, cy + ch / 2, 34)
    P2.text(o, x + 60, cy + 6, 110, 18, name, c[:txt], PF::TEXT)
    hp_line(o, c, x + 62, cy + 33, 52, hp, max)
    P2.small(o, x + 118, cy + 27, cw - 112, 14, "#{hp}/#{max}", c[:txt], 1)
  end
  rx = x + 12 + cw + 12
  rw = x + w - 12 - rx
  P2.heading(o, rx, rx + rw, top, "Chansey's Moves", c[:head], c[:line])
  moves = HEALERS[0][6]
  moves.each_with_index do |(mv, what, left), i|
    my = top + 16 + i * 46
    plate(o, c, rx, my, rx + rw, my + 40, tcol(:NORMAL), 8, i == 0)
    P2.text(o, rx + 12, my + 3, 150, 18, mv, i == 0 ? c[:strong] : c[:txt], PF::TEXT)
    left_pill(o, c, rx + rw - 12, my + 4, left)
    P2.small(o, rx + 12, my + 21, rw - 24, 16, i == 0 ? "Gives a fifth of its HP to one Pokémon" : "Cures every Pokémon's status", c[:dim])
  end
  hy = top + 16 + moves.length * 46 + 6
  DG.send(:button, o, c, rx, hy, rx + rw, hy + 26, false)
  P2.text(o, rx, hy + 2, rw, 22, "Heal Everyone", c[:txt], PF::TEXT, 2)
  party_strip(o, c, x + 12, y + h - 50, w - 24, 40)
end

#---------------------------------------------------------------- Design 3
def party_first(o, c)
  x, y, w, h = map_panel(o, c, "Heal with Moves")
  top = y + 40
  cw = 118; ch = 70; gap = 6
  MONS.each_with_index do |(sp, name, hp, max, types, st), i|
    cx = x + 12 + (i % 2) * (cw + gap)
    cy = top + (i / 2) * (ch + gap)
    plate(o, c, cx, cy, cx + cw, cy + ch, tcol(types[0]), 10, i == 1)
    art(o, sp, cx + 24, cy + 28, 34)
    P2.text(o, cx + 44, cy + 6, cw - 48, 18, name, c[:txt], PF::TEXT)
    hp_line(o, c, cx + 10, cy + ch - 16, cw - 20, hp, max)
    P2.text(o, cx + 44, cy + 30, cw - 52, 12, st || "#{hp}/#{max}", st ? c[:pink] : c[:txt], PF::TINY, 1)
  end
  rx = x + 12 + 2 * cw + gap + 12
  rw = x + w - 12 - rx
  P2.heading(o, rx, rx + rw, top, "Heal Pikachu", c[:head], c[:line])
  opts = [[:CHANSEY, "Soft-Boiled", "+64 HP", "8 Left"], [:CHANSEY, "Heal Bell", "Nothing to cure", "5 Left"]]
  opts.each_with_index do |(sp, mv, what, left), i|
    oy = top + 16 + i * 44
    cursor(o, c, rx - 4, oy, rx + rw + 2, oy + 40) if i == 0
    art(o, sp, rx + 14, oy + 20, 24)
    P2.text(o, rx + 32, oy + 3, rw - 36, 18, mv, i == 0 ? c[:strong] : c[:txt], PF::TEXT)
    P2.small(o, rx + 32, oy + 5, rw - 38, 16, left, c[:green], 1)
    P2.small(o, rx + 32, oy + 21, rw - 36, 16, what, i == 0 ? c[:green] : c[:dim])
  end
  hy = y + h - 40
  DG.send(:button, o, c, rx, hy, rx + rw, hy + 26, false)
  P2.text(o, rx, hy + 2, rw, 22, "Heal Everyone", c[:txt], PF::TEXT, 2)
end

LIST_HINTS = [[:ud, "Choose"], [A_PAD, "Use"], [B_PAD, "Back"]]
CARD_HINTS = [[:ud, "Choose"], [:lr, "Healers"], [A_PAD, "Use"], [B_PAD, "Back"]]
GRID_HINTS = [[:ud, "Choose"], [:lr, "Columns"], [A_PAD, "Heal"], [B_PAD, "Back"]]

queue = []
[["HL1_list", LIST_HINTS, :healer_list], ["HL2_cards", CARD_HINTS, :healer_cards], ["HL3_party", GRID_HINTS, :party_first]].each do |name, hints, what|
  queue << at { panel_shot(name, hints, 0) { |o, c| send(what, o, c) } }
  queue << at { panel_shot("#{name}_light", hints, 2) { |o, c| send(what, o, c) } }
end
queue << at { S.set(:"interface.theme_mode", 0); $qa_hints = nil; om.send(:overlay).clear; om.refresh }
queue << I::BACK
on_map("Heal with Moves designs", queue)
puts "designs done"
