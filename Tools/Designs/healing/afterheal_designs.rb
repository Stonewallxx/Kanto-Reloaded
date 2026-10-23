# encoding: utf-8
# Mockups: Healing Moves after a heal (Roadmap topic healing-overworld):
# Chansey's Soft-Boiled on Pikachu was used (Pikachu 40 to 95, Chansey 310
# to 246, Soft-Boiled 8 to 7 left). The list behind is the chosen Healer
# List, as it is after the heal: a move with nothing to do dims and says
# why (Snorlax's Rest: Full HP).
# Design 1 = Toast: back in the list, everything updated; a toast at the top
#            says what happened, as the PokeVial's do.
# Design 2 = Result Popup: the Before and After popup turns into what
#            happened, with OK.
# Design 3 = Message Bar: back in the list; the game's words in a bar along
#            the bottom (the Party Screen's messages), A goes on.
# Sprites: python ../qa/qa_assets.py "<KIF Beta>" first (writes ../qa/art).
# Usage (from this folder): ruby afterheal_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "healing_common.rb")

# the party after the heal
Object.send(:remove_const, :MONS)
Object.send(:remove_const, :HEALERS)
MONS = [[:CHANSEY, "Chansey", 246, 320, [:NORMAL], nil, [["Soft-Boiled", "Heals one Pokémon", 7], ["Heal Bell", "Cures the party", 5]]],
        [:PIKACHU, "Pikachu", 95, 95, [:ELECTRIC], nil, []],
        [:GENGAR, "Gengar", 70, 110, [:GHOST, :POISON], "PSN", []],
        [:ALAKAZAM, "Alakazam", 50, 90, [:PSYCHIC], nil, [["Recover", "Heals itself", 10]]],
        [:SNORLAX, "Snorlax", 160, 160, [:NORMAL], nil, [["Rest", "Full HP", 5, :off]]],
        [:PIDGEOT, "Pidgeot", 80, 120, [:NORMAL, :FLYING], nil, [["Roost", "Heals itself", 9]]]].freeze
HEALERS = MONS.reject { |m| m[6].empty? }

# the Healer List, a row it can't use dimmed with why
def list_after(o, c)
  x, y, w, h = map_panel(o, c, "Heal with Moves")
  ty = y + 40
  bx0 = x + 12; bx1 = x + w - 12
  DG.send(:button, o, c, bx0, ty, bx1, ty + 24, false)
  P2.text(o, bx0 + 14, ty + 3, 200, 18, "Heal Everyone", c[:txt], PF::TEXT)
  P2.small(o, bx0, ty + 4, bx1 - bx0 - 14, 16, "3 moves, 4 PP", c[:dim], 1)
  ry = ty + 32
  HEALERS.each_with_index do |(sp, name, hp, max, types, _st, moves), hi|
    plate(o, c, x + 12, ry, x + w - 12, ry + 22, tcol(types[0]))
    art(o, sp, x + 30, ry + 11, 20)
    P2.text(o, x + 46, ry + 2, 140, 18, name, c[:txt], PF::TEXT)
    hp_line(o, c, x + w - 150, ry + 10, 70, hp, max)
    P2.small(o, x + w - 72, ry + 3, 56, 16, "#{hp}/#{max}", c[:txt], 1)
    ry += 25
    moves.each_with_index do |(mv, what, left, off), mi|
      sel = hi == 0 && mi == 0
      cursor(o, c, x + 30, ry - 1, x + w - 14, ry + 18) if sel
      P2.text(o, x + 44, ry, 130, 18, mv, off ? c[:dim] : (sel ? c[:strong] : c[:txt]), PF::TEXT)
      P2.small(o, x + 176, ry + 1, 200, 16, what, off ? c[:dim] : c[:dim])
      if off
        lock_icon(o, x + w - 34, ry + 3, c[:dim])
      else
        left_pill(o, c, x + w - 22, ry + 1, left)
      end
      ry += 20
    end
    ry += 5
  end
  party_strip(o, c, x + 12, y + h - 50, w - 24, 40)
end

#---------------------------------------------------------------- Design 1
def toast_after(o, c)
  list_after(o, c)
  text = "Pikachu regained 55 HP"
  tw = P2.width(PF::TEXT, text)
  badge = "7 LEFT"
  bw = P2.width(PF::TINY, badge) + 12
  w = 34 + tw + 10 + bw + 10; h = 30
  x = (SW - w) / 2; y = 12
  P2.ui.rbox(o, x, y, x + w - 1, y + h - 1, 7, c[:panel], c[:line])
  art(o, :CHANSEY, x + 18, y + h / 2, 22)
  P2.text(o, x + 34, y + 6, tw + 2, 18, text, c[:txt], PF::TEXT)
  fill = c[:light] ? mix(c[:panel2], c[:gold], 0.22) : Color.new(70, 58, 20)
  P2.pill(o, x + w - 10, y + 7, badge, fill, c[:gold], true)
end

#---------------------------------------------------------------- Design 2
def result_popup(o, c)
  list_after(o, c)
  shade(o)
  w = 360; h = 196
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  DG.send(:panel, o, c, x, y, w, h)
  DG.send(:title_bar, o, c, x, y, w, "Soft-Boiled Used")
  rows = [[:PIKACHU, "Pikachu", 95, 95, "95/95", "+55 HP", c[:green]], [:CHANSEY, "Chansey", 246, 320, "246/320", "PP 7 Left", c[:blue]]]
  rows.each_with_index do |(sp, name, hp, max, words, sub, sub_col), i|
    ry = y + 44 + i * 44
    art(o, sp, x + 30, ry + 16, 30)
    P2.text(o, x + 54, ry - 2, 140, 18, name, c[:txt], PF::TEXT)
    PP.bar(o, c, x + 56, ry + 20, 150, hp.to_f / max, hp_col(c, hp, max))
    P2.text(o, x + 214, ry - 2, w - 230, 18, words, c[:txt], PF::TEXT, 1)
    P2.small(o, x + 214, ry + 16, w - 230, 16, sub, sub_col, 1)
  end
  P2.small(o, x + 16, y + 132, w - 32, 16, "Pikachu regained 55 HP.", c[:green])
  button(o, c, x + w / 2 - 60, y + h - 38, x + w / 2 + 60, y + h - 10, "OK", true)
end

#---------------------------------------------------------------- Design 3
def message_bar(o, c)
  list_after(o, c)
  y0 = HINT_TOP - 58; y1 = HINT_TOP - 6
  PP.chamfer_grad(o, 8, y0, SW - 8, y1, 12, mix(c[:panel], c[:selb], 0.22), c[:panel], c[:selb])
  art(o, :PIKACHU, 34, y0 + 26, 30)
  P2.text(o, 58, y0 + 8, 400, 20, "Pikachu's HP was restored by 55 points.", c[:txt], PF::TEXT)
  P2.small(o, 58, y0 + 28, 400, 16, "Chansey has 7 Soft-Boiled left.", c[:dim])
  P2.ui.tri(o, SW - 30, y1 - 13, :d, c[:selb], 4)
end

LIST_HINTS = [[:ud, "Choose"], [A_PAD, "Use"], [B_PAD, "Back"]]
OK_HINTS = [[A_PAD, "OK"]]
GO_HINTS = [[A_PAD, "Continue"]]
queue = []
[["AH1_toast", LIST_HINTS, :toast_after], ["AH2_result", OK_HINTS, :result_popup], ["AH3_message", GO_HINTS, :message_bar]].each do |name, hints, what|
  queue << at { panel_shot(name, hints, 0) { |o, c| send(what, o, c) } }
  queue << at { panel_shot("#{name}_light", hints, 2) { |o, c| send(what, o, c) } }
end
queue << at { S.set(:"interface.theme_mode", 0); $qa_hints = nil; om.send(:overlay).clear; om.refresh }
queue << I::BACK
on_map("After a heal designs", queue)
puts "designs done"
