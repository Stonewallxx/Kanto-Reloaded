# encoding: utf-8
# Mockups: Healing Moves' Heal Everyone (a new feature, agreed 2026-10-23):
# the plan it worked out (the most HP for the fewest PP), shown before it
# runs, over the chosen Heal with Moves list.
# The plan: Alakazam's Recover (+40), Pidgeot's Roost (+40), Chansey's
# Soft-Boiled on Pikachu (+55) and on Gengar (+40), Chansey's Heal Bell
# (cures Gengar's poison): 5 PP; Chansey ends at 182/320.
# Design 1 = Plan Steps: each move in the plan as a row (healer, move,
#            target, what it does), the party's HP after along the foot.
# Design 2 = Party After: each Pokemon's HP before and after, with the move
#            that heals it; what each healer spends at the foot.
# Design 3 = Healer Costs: each healer on its plate with what it uses (PP,
#            HP) and who it heals; the party's HP after along the foot.
# Sprites: python ../qa/qa_assets.py "<KIF Beta>" first (writes ../qa/art).
# Usage (from this folder): ruby heal_everyone_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "healing_common.rb")

def change_bar(o, c, x, y, w, hp, after, max, h = 4)
  if after >= hp
    PP.bar(o, c, x, y, w, after.to_f / max, mix(hp_col(c, after, max), c[:white], 0.5), h)
    o.fill_rect(x, y, (w * hp.to_f / max).round, h, hp_col(c, hp, max)) if hp > 0
  else
    PP.bar(o, c, x, y, w, hp.to_f / max, mix(c[:red], c[:white], 0.45), h)
    o.fill_rect(x, y, (w * after.to_f / max).round, h, hp_col(c, after, max)) if after > 0
  end
end

# [healer, move, target, what it does]
PLAN = [[:ALAKAZAM, "Recover", :ALAKAZAM, "+40 HP"], [:PIDGEOT, "Roost", :PIDGEOT, "+40 HP"],
        [:CHANSEY, "Soft-Boiled", :PIKACHU, "+55 HP"], [:CHANSEY, "Soft-Boiled", :GENGAR, "+40 HP"],
        [:CHANSEY, "Heal Bell", :GENGAR, "Cures Poison"]].freeze
# [species, name, hp, after, max, status before, status after, healed by]
AFTER = [[:CHANSEY, "Chansey", 310, 182, 320, nil, nil, "Gives 128 HP"], [:PIKACHU, "Pikachu", 40, 95, 95, nil, nil, "Soft-Boiled"],
         [:GENGAR, "Gengar", 70, 110, 110, "PSN", nil, "Soft-Boiled, Heal Bell"], [:ALAKAZAM, "Alakazam", 50, 90, 90, nil, nil, "Recover"],
         [:SNORLAX, "Snorlax", 160, 160, 160, nil, nil, "Healthy"], [:PIDGEOT, "Pidgeot", 80, 120, 120, nil, nil, "Roost"]].freeze

def popup_frame(o, c, w, h, title)
  healer_list(o, c)
  shade(o)
  x = (SW - w) / 2; y = [(HINT_TOP - h) / 2, 4].max
  DG.send(:panel, o, c, x, y, w, h)
  DG.send(:title_bar, o, c, x, y, w, title)
  return [x, y]
end

# the party's HP after, six small plates
def after_strip(o, c, x, y, w, h = 40)
  gap = 6
  pw = (w - gap * 5) / 6
  AFTER.each_with_index do |(sp, _name, hp, after, max, _st, st2), i|
    px = x + i * (pw + gap)
    types = MONS.find { |m| m[0] == sp }[4]
    plate(o, c, px, y, px + pw, y + h, tcol(types[0]), 7)
    art(o, sp, px + 13, y + h / 2, 20)
    P2.text(o, px + 24, y + 8, pw - 28, 12, "#{after}/#{max}", after > hp ? c[:green] : (after < hp ? c[:amber] : c[:txt]), PF::TINY, 1)
    change_bar(o, c, px + 27, y + h - 12, pw - 33, hp, after, max, 3)
  end
end

def foot_buttons(o, c, x, y, w, h)
  button(o, c, x + 40, y + h - 38, x + w / 2 - 4, y + h - 10, "Heal Everyone", true)
  button(o, c, x + w / 2 + 4, y + h - 38, x + w - 40, y + h - 10, "Back", false)
end

#---------------------------------------------------------------- Design 1
def plan_steps(o, c)
  w = 440; rh = 26
  h = 40 + 16 + PLAN.length * rh + 10 + 44 + 46
  x, y = popup_frame(o, c, w, h, "Heal Everyone")
  top = y + 40
  P2.text(o, x + 16, top, 150, 14, "THE PLAN", c[:head], PF::TINY)
  P2.text(o, x + w - 166, top, 150, 14, "5 PP", c[:dim], PF::TINY, 1)
  PLAN.each_with_index do |(healer, move, target, what), i|
    ry = top + 16 + i * rh
    art(o, healer, x + 28, ry + rh / 2, 22)
    P2.text(o, x + 46, ry + 2, 120, 18, move, c[:txt], PF::TEXT)
    P2.small(o, x + 164, ry + 4, 20, 16, "on", c[:dim])
    art(o, target, x + 198, ry + rh / 2, 22)
    name = MONS.find { |m| m[0] == target }[1]
    P2.text(o, x + 214, ry + 2, 100, 18, target == healer ? "Itself" : name, c[:txt], PF::TEXT)
    P2.small(o, x + 300, ry + 4, w - 316, 16, what, c[:green], 1)
  end
  after_strip(o, c, x + 12, top + 16 + PLAN.length * rh + 10, w - 24)
  foot_buttons(o, c, x, y, w, h)
end

#---------------------------------------------------------------- Design 2
def party_after(o, c)
  w = 420; rh = 30
  h = 40 + AFTER.length * rh + 30 + 44
  x, y = popup_frame(o, c, w, h, "Heal Everyone")
  top = y + 40
  AFTER.each_with_index do |(sp, name, hp, after, max, st, _st2, by), i|
    ry = top + i * rh
    art(o, sp, x + 26, ry + rh / 2, 24)
    P2.text(o, x + 44, ry, 110, 18, name, c[:txt], PF::TEXT)
    change_bar(o, c, x + 46, ry + 20, 100, hp, after, max, 3)
    words = hp == after ? "#{hp}/#{max}" : "#{hp} to #{after}"
    P2.small(o, x + 156, ry + 4, 90, 16, words, after > hp ? c[:green] : (after < hp ? c[:amber] : c[:txt]))
    P2.small(o, x + 244, ry + 4, w - 260, 16, by, by == "Healthy" ? c[:green] : c[:dim], 1)
  end
  fy = top + AFTER.length * rh + 4
  o.fill_rect(x + 12, fy, w - 24, 1, c[:line])
  P2.small(o, x + 12, fy + 6, w - 24, 16, "PP: Chansey 3, Alakazam 1, Pidgeot 1", c[:blue], 2)
  foot_buttons(o, c, x, y, w, h)
end

#---------------------------------------------------------------- Design 3
def healer_costs(o, c)
  w = 440
  costs = [[:CHANSEY, "Chansey", [:NORMAL], "Soft-Boiled x2, Heal Bell", "PP 8 to 6, 5 to 4", "HP 310 to 182", [:PIKACHU, :GENGAR]],
           [:ALAKAZAM, "Alakazam", [:PSYCHIC], "Recover", "PP 10 to 9", nil, [:ALAKAZAM]],
           [:PIDGEOT, "Pidgeot", [:NORMAL, :FLYING], "Roost", "PP 9 to 8", nil, [:PIDGEOT]]]
  ph = 48; gap = 6
  h = 40 + costs.length * (ph + gap) + 6 + 44 + 46
  x, y = popup_frame(o, c, w, h, "Heal Everyone")
  top = y + 40
  costs.each_with_index do |(sp, name, types, moves, pp, hp_cost, heals), i|
    py = top + i * (ph + gap)
    plate(o, c, x + 12, py, x + w - 12, py + ph, tcol(types[0]), 9)
    art(o, sp, x + 34, py + ph / 2, 32)
    P2.text(o, x + 58, py + 4, 120, 18, name, c[:txt], PF::TEXT)
    P2.small(o, x + 58, py + 25, 200, 16, moves, c[:dim])
    P2.small(o, x + 220, py + 6, w - 320, 16, pp, c[:blue], 1)
    P2.small(o, x + 220, py + 25, w - 320, 16, hp_cost, c[:amber], 1) if hp_cost
    o.fill_rect(x + w - 92, py + 8, 1, ph - 16, c[:line])
    P2.small(o, x + w - 86, py + 4, 70, 16, "Heals", c[:dim], 2)
    heals.each_with_index { |t, k| art(o, t, x + w - 51 - (heals.length - 1) * 12 + k * 24, py + 32, 20) }
  end
  after_strip(o, c, x + 12, top + costs.length * (ph + gap) + 6, w - 24)
  foot_buttons(o, c, x, y, w, h)
end

HINTS = [[:lr, "Choose"], [A_PAD, "Select"], [B_PAD, "Back"]]
queue = []
[["HE1_steps", :plan_steps], ["HE2_after", :party_after], ["HE3_costs", :healer_costs]].each do |name, what|
  queue << at { panel_shot(name, HINTS, 0) { |o, c| send(what, o, c) } }
  queue << at { panel_shot("#{name}_light", HINTS, 2) { |o, c| send(what, o, c) } }
end
queue << at { S.set(:"interface.theme_mode", 0); $qa_hints = nil; om.send(:overlay).clear; om.refresh }
queue << I::BACK
on_map("Heal Everyone designs", queue)
puts "designs done"
