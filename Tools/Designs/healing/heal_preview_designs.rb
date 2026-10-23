# encoding: utf-8
# Mockups: Healing Moves' Heal Preview (Roadmap topic healing-overworld):
# what using a move will do before it's used, over the chosen Heal with
# Moves list (and the same from the party menu). Chansey's Soft-Boiled on
# Pikachu: 1 PP and a fifth of Chansey's max HP (64), Pikachu 40 to 95.
# Design 1 = Before and After: the chosen Roadmap design in a Header Plate
#            popup; the target picked first, then the target's and the
#            healer's HP before and after, the PP, what it costs, Use / Back.
# Design 2 = Pick in the Preview: one popup for both steps; the party's
#            rows each say what the move would do for it, the cursor picks
#            the target, the healer's cost along the foot.
# Design 3 = Side Panel: the list stays; a panel at the right picks the
#            target with Left / Right and shows before and after.
# Sprites: python ../qa/qa_assets.py "<KIF Beta>" first (writes ../qa/art).
# Usage (from this folder): ruby heal_preview_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "healing_common.rb")

AMOUNT = 64     # a fifth of Chansey's 320

# an HP bar showing the change: a gain as a paler stretch after the HP it
# has now, a loss as the part that goes, in a pale red
def change_bar(o, c, x, y, w, hp, after, max, h = 4)
  if after >= hp
    PP.bar(o, c, x, y, w, after.to_f / max, mix(hp_col(c, after, max), c[:white], 0.5), h)
    o.fill_rect(x, y, (w * hp.to_f / max).round, h, hp_col(c, hp, max)) if hp > 0
  else
    PP.bar(o, c, x, y, w, hp.to_f / max, mix(c[:red], c[:white], 0.45), h)
    o.fill_rect(x, y, (w * after.to_f / max).round, h, hp_col(c, after, max)) if after > 0
  end
end

def behind(o, c)
  healer_list(o, c)
  shade(o)
end

#---------------------------------------------------------------- Design 1
def before_after(o, c)
  behind(o, c)
  w = 360; h = 196
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  DG.send(:panel, o, c, x, y, w, h)
  DG.send(:title_bar, o, c, x, y, w, "Soft-Boiled on Pikachu?")
  rows = [[:PIKACHU, "Pikachu", 40, 95, 95, "40 to 95", "+55 HP", c[:green]],
          [:CHANSEY, "Chansey", 310, 246, 320, "310 to 246", "PP 8 to 7", c[:blue]]]
  rows.each_with_index do |(sp, name, hp, after, max, words, sub, sub_col), i|
    ry = y + 44 + i * 44
    art(o, sp, x + 30, ry + 16, 30)
    P2.text(o, x + 54, ry - 2, 140, 18, name, c[:txt], PF::TEXT)
    change_bar(o, c, x + 56, ry + 20, 150, hp, after, max)
    P2.text(o, x + 214, ry - 2, w - 230, 18, words, after >= hp ? c[:green] : c[:amber], PF::TEXT, 1)
    P2.small(o, x + 214, ry + 16, w - 230, 16, sub, sub_col, 1)
  end
  P2.small(o, x + 16, y + 132, w - 32, 16, "Chansey gives up a fifth of its max HP.", c[:dim])
  button(o, c, x + 40, y + h - 38, x + w / 2 - 4, y + h - 10, "Use", true)
  button(o, c, x + w / 2 + 4, y + h - 38, x + w - 40, y + h - 10, "Back", false)
end

#---------------------------------------------------------------- Design 2
def pick_in_preview(o, c)
  behind(o, c)
  w = 380; rh = 32
  others = MONS.reject { |m| m[0] == :CHANSEY }
  h = 40 + others.length * rh + 46
  x = (SW - w) / 2; y = [(HINT_TOP - h) / 2, 4].max
  DG.send(:panel, o, c, x, y, w, h)
  DG.send(:title_bar, o, c, x, y, w, "Soft-Boiled")
  others.each_with_index do |(sp, name, hp, max, _types, st), i|
    ry = y + 40 + i * rh
    after = [hp + AMOUNT, max].min
    full = hp >= max
    cursor(o, c, x + 6, ry, x + w - 6, ry + rh - 2) if i == 0
    art(o, sp, x + 26, ry + rh / 2, 26)
    P2.text(o, x + 46, ry + 1, 120, 18, name, i == 0 ? c[:strong] : c[:txt], PF::TEXT)
    change_bar(o, c, x + 48, ry + 21, 110, hp, after, max, 3)
    if full
      P2.small(o, x + 170, ry + 8, w - 186, 16, "Healthy", c[:green], 1)
    else
      P2.small(o, x + 170, ry + 8, w - 186, 16, "#{hp} to #{after}  +#{after - hp} HP", c[:green], 1)
    end
  end
  fy = y + h - 40
  o.fill_rect(x + 12, fy, w - 24, 1, c[:line])
  art(o, :CHANSEY, x + 26, fy + 18, 24)
  P2.small(o, x + 46, fy + 10, w - 60, 16, "Chansey: 310 to 246 HP, PP 8 to 7", c[:amber])
end

#---------------------------------------------------------------- Design 3
def side_panel(o, c)
  behind(o, c)
  w = 230; h = HINT_TOP - 30
  x = SW - w - 12; y = 14
  DG.send(:panel, o, c, x, y, w, h)
  DG.send(:title_bar, o, c, x, y, w, "Soft-Boiled")
  # the target, picked with Left / Right
  ty = y + 44
  P2.ui.tri(o, x + 14, ty + 30, :l, c[:selb], 5)
  P2.ui.tri(o, x + w - 20, ty + 30, :r, c[:selb], 5)
  art(o, :PIKACHU, x + w / 2, ty + 24, 44)
  P2.text(o, x, ty + 50, w, 18, "Pikachu", c[:strong], PF::TEXT, 2)
  change_bar(o, c, x + 30, ty + 76, w - 60, 40, 95, 95)
  P2.text(o, x, ty + 86, w, 18, "40 to 95", c[:green], PF::TEXT, 2)
  P2.small(o, x, ty + 104, w, 16, "+55 HP", c[:green], 2)
  o.fill_rect(x + 14, ty + 128, w - 28, 1, c[:line])
  art(o, :CHANSEY, x + 30, ty + 150, 26)
  P2.text(o, x + 50, ty + 136, w - 64, 18, "Chansey", c[:txt], PF::TEXT)
  P2.small(o, x + 50, ty + 154, w - 64, 16, "310 to 246 HP, PP 8 to 7", c[:amber])
  button(o, c, x + 20, y + h - 40, x + w - 20, y + h - 12, "Use", true)
end

ONE_HINTS = [[:lr, "Choose"], [A_PAD, "Select"], [B_PAD, "Back"]]
PICK_HINTS = [[:ud, "Pokémon"], [A_PAD, "Use"], [B_PAD, "Back"]]
SIDE_HINTS = [[:lr, "Pokémon"], [A_PAD, "Use"], [B_PAD, "Back"]]
queue = []
[["HP1_before_after", ONE_HINTS, :before_after], ["HP2_pick", PICK_HINTS, :pick_in_preview], ["HP3_side", SIDE_HINTS, :side_panel]].each do |name, hints, what|
  queue << at { panel_shot(name, hints, 0) { |o, c| send(what, o, c) } }
  queue << at { panel_shot("#{name}_light", hints, 2) { |o, c| send(what, o, c) } }
end
queue << at { S.set(:"interface.theme_mode", 0); $qa_hints = nil; om.send(:overlay).clear; om.refresh }
queue << I::BACK
on_map("Heal Preview designs", queue)
puts "designs done"
