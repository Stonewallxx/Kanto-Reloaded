# encoding: utf-8
# Mockups: Healing Moves' Morning Sun and Moonlight (Roadmap topic
# healing-overworld): heal, or PIF's own Wait Until Morning or Night (only
# outdoors). Espeon's Morning Sun, 80/130 HP, 5 PP, at 3:42 PM.
# Design 1 = Choice Popup: a Header Plate popup with the two choices, each
#            saying what it does.
# Design 2 = In the Preview: the chosen Before and After popup with three
#            buttons: Heal, Wait (until morning), Back.
# Design 3 = Two Rows: no popup; the list has Morning Sun twice, healing
#            and waiting (the wait only outdoors).
# Sprites: python ../qa/qa_assets.py "<KIF Beta>" first (writes ../qa/art).
# Usage (from this folder): ruby timemove_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "healing_common.rb")

# Espeon in Pidgeot's place, with Morning Sun
Object.send(:remove_const, :MONS)
Object.send(:remove_const, :HEALERS)
MONS = [[:CHANSEY, "Chansey", 310, 320, [:NORMAL], nil, [["Soft-Boiled", "Heals one Pokémon", 8], ["Heal Bell", "Cures the party", 5]]],
        [:PIKACHU, "Pikachu", 40, 95, [:ELECTRIC], nil, []],
        [:GENGAR, "Gengar", 70, 110, [:GHOST, :POISON], "PSN", []],
        [:ALAKAZAM, "Alakazam", 50, 90, [:PSYCHIC], nil, [["Recover", "Heals itself", 10]]],
        [:SNORLAX, "Snorlax", 160, 160, [:NORMAL], nil, [["Rest", "Heals itself, sleeps", 5]]],
        [:ESPEON, "Espeon", 80, 130, [:PSYCHIC], nil, [["Morning Sun", "Heals itself, or waits", 5]]]].freeze
HEALERS = MONS.reject { |m| m[6].empty? }

def change_bar(o, c, x, y, w, hp, after, max, h = 4)
  PP.bar(o, c, x, y, w, after.to_f / max, mix(hp_col(c, after, max), c[:white], 0.5), h)
  o.fill_rect(x, y, (w * hp.to_f / max).round, h, hp_col(c, hp, max)) if hp > 0
end

def behind(o, c)
  healer_list(o, c)
  shade(o)
end

#---------------------------------------------------------------- Design 1
def choice_popup(o, c)
  behind(o, c)
  w = 340; rh = 44
  h = 40 + 2 * rh + 30
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  DG.send(:panel, o, c, x, y, w, h)
  DG.send(:title_bar, o, c, x, y, w, "Morning Sun")
  rows = [["Heal Itself", "Espeon: 80 to 130 HP, PP 5 to 4", c[:green]],
          ["Wait Until Morning", "It's 3:42 PM: The game skips to morning", c[:gold]]]
  rows.each_with_index do |(label, sub, col), i|
    ry = y + 40 + i * rh
    cursor(o, c, x + 6, ry, x + w - 6, ry + rh - 4) if i == 0
    P2.text(o, x + 18, ry + 3, w - 36, 18, label, i == 0 ? c[:strong] : c[:txt], PF::TEXT)
    P2.small(o, x + 18, ry + 22, w - 36, 16, sub, col)
  end
  P2.small(o, x + 12, y + h - 26, w - 24, 16, "Waiting works outdoors only.", c[:dim], 2)
end

#---------------------------------------------------------------- Design 2
def in_preview(o, c)
  behind(o, c)
  w = 380; h = 166
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  DG.send(:panel, o, c, x, y, w, h)
  DG.send(:title_bar, o, c, x, y, w, "Morning Sun")
  ry = y + 44
  art(o, :ESPEON, x + 30, ry + 16, 30)
  P2.text(o, x + 54, ry - 2, 140, 18, "Espeon", c[:txt], PF::TEXT)
  change_bar(o, c, x + 56, ry + 20, 150, 80, 130, 130)
  P2.text(o, x + 214, ry - 2, w - 230, 18, "80 to 130", c[:green], PF::TEXT, 1)
  P2.small(o, x + 214, ry + 16, w - 230, 16, "PP 5 to 4", c[:blue], 1)
  P2.small(o, x + 16, y + 90, w - 32, 16, "Wait: Skips to morning (it's 3:42 PM now).", c[:gold])
  bw = (w - 32 - 16) / 3
  [["Heal", true], ["Wait", false], ["Back", false]].each_with_index do |(label, on), i|
    bx = x + 16 + i * (bw + 8)
    button(o, c, bx, y + h - 38, bx + bw, y + h - 10, label, on)
  end
end

#---------------------------------------------------------------- Design 3
def two_rows(o, c)
  x, y, w, h = map_panel(o, c, "Heal with Moves")
  ty = y + 40
  bx0 = x + 12; bx1 = x + w - 12
  DG.send(:button, o, c, bx0, ty, bx1, ty + 24, false)
  P2.text(o, bx0 + 14, ty + 3, 200, 18, "Heal Everyone", c[:txt], PF::TEXT)
  P2.small(o, bx0, ty + 4, bx1 - bx0 - 14, 16, "3 moves, 4 PP", c[:dim], 1)
  ry = ty + 32
  list = HEALERS.reject { |m| m[0] == :SNORLAX }.map { |m| m.dup }   # (the list scrolls; one healer less to fit here)
  list[-1] = list[-1].dup
  list[-1][6] = [["Morning Sun", "Heals itself", 5], ["Morning Sun", "Waits until morning", 5]]
  list.each_with_index do |(sp, name, hp, max, types, _st, moves), hi|
    plate(o, c, x + 12, ry, x + w - 12, ry + 22, tcol(types[0]))
    art(o, sp, x + 30, ry + 11, 20)
    P2.text(o, x + 46, ry + 2, 140, 18, name, c[:txt], PF::TEXT)
    hp_line(o, c, x + w - 150, ry + 10, 70, hp, max)
    P2.small(o, x + w - 72, ry + 3, 56, 16, "#{hp}/#{max}", c[:txt], 1)
    ry += 25
    moves.each_with_index do |(mv, what, left), mi|
      sel = sp == :ESPEON && mi == 1
      cursor(o, c, x + 30, ry - 1, x + w - 14, ry + 18) if sel
      P2.text(o, x + 44, ry, 130, 18, mv, sel ? c[:strong] : c[:txt], PF::TEXT)
      P2.small(o, x + 176, ry + 1, 200, 16, what, what.start_with?("Waits") ? c[:gold] : c[:dim])
      left_pill(o, c, x + w - 22, ry + 1, left)
      ry += 20
    end
    ry += 5
  end
  party_strip(o, c, x + 12, y + h - 50, w - 24, 40)
end

POP_HINTS = [[:ud, "Choose"], [A_PAD, "Select"], [B_PAD, "Back"]]
BTN_HINTS = [[:lr, "Choose"], [A_PAD, "Select"], [B_PAD, "Back"]]
LIST_HINTS = [[:ud, "Choose"], [A_PAD, "Use"], [B_PAD, "Back"]]
queue = []
[["TM1_choice", POP_HINTS, :choice_popup], ["TM2_preview", BTN_HINTS, :in_preview], ["TM3_rows", LIST_HINTS, :two_rows]].each do |name, hints, what|
  queue << at { panel_shot(name, hints, 0) { |o, c| send(what, o, c) } }
  queue << at { panel_shot("#{name}_light", hints, 2) { |o, c| send(what, o, c) } }
end
queue << at { S.set(:"interface.theme_mode", 0); $qa_hints = nil; om.send(:overlay).clear; om.refresh }
queue << I::BACK
on_map("Morning Sun designs", queue)
puts "designs done"
