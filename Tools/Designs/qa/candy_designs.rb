# encoding: utf-8
# Mockups: Super Candy (a Quality of Life tool): raises the party to a level,
# one level at a time, with their moves and evolutions as the game does
# them; level locks and KIF's level cap are kept to. Choosing how high,
# three designs. KIF's level cap is Lv 38; Gyarados is locked at Lv 35,
# Eevee (Lv 22) at Lv 25.
# Design 1 = the old Kanto Reloaded's choices (the level cap, the highest
# in the party, a level of your own) with what each Pokémon would reach.
# Sprites: python qa_assets.py "<KIF Beta>" first (writes art/ here).
# Usage (from this folder): ruby candy_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "qa_common.rb")

LOCKS = { :GYARADOS => 35, :EEVEE => 25 }
CAP = 38
HIGHEST = PARTY.map { |e| e[2] }.max
# where each one would end up, and why it stops there
def reach(entry, target)
  sp, _, lv = entry
  to = [target, LOCKS[sp] || 100].min
  return [lv, :locked] if LOCKS[sp] && LOCKS[sp] <= lv
  return [lv, :already] if to <= lv
  return [to, LOCKS[sp] && LOCKS[sp] < target ? :locked_at : :ok]
end
# "34 > 38" (green), or a gold lock and Locked, or Already There (dim);
# ending at x1
def reach_column(o, c, x1, y, entry, target)
  lv = entry[2]
  to, why = reach(entry, target)
  case why
  when :locked
    tw = P2.small(o, x1 - 120, y, 120, 16, "Locked at Lv #{lv}", GOLD_T, 1)
    lock_icon(o, x1 - tw - 14, y + 2, GOLD_T)
  when :already
    P2.small(o, x1 - 120, y, 120, 16, "Already There", c[:dim], 1)
  else
    P2.small(o, x1 - 30, y, 30, 16, to.to_s, GREEN_T, 1)
    P2.ui.tri(o, x1 - 44, y + 4, :r, GREEN_T, 4)
    P2.small(o, x1 - 80, y, 30, 16, lv.to_s, c[:dim], 1)
    lock_icon(o, x1 - 100, y + 2, GOLD_T) if why == :locked_at
  end
end

DESIGNS = []

# 1 Recommended: one popup: Raise To at the top (Left and Right: the Level
# Cap, the Highest in the Party, or a level of your own), the party under it
# with where each would end up; A raises them all
DESIGNS << ["QA_SC1_one_panel", [[A_PAD, "Raise"], [B_PAD, "Close"]], proc { |o, c|
  w = 380; rh = 26; h = 42 + 30 + 8 + PARTY.length * rh + 30
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Super Candy")
  ry = y + 40
  cursor(o, c, x + 6, ry, x + w - 6, ry + 26)
  P2.text(o, x + 16, ry + 5, 100, 18, "Raise To", c[:txt], PF::TEXT)
  P2.ui.tri(o, x + 150, ry + 8, :l, c[:dim], 5)
  P2.text(o, x + 162, ry + 5, w - 194, 18, "Level Cap (Lv #{CAP})", GOLD_T, PF::TEXT, 2)
  P2.ui.tri(o, x + w - 30, ry + 8, :r, c[:dim], 5)
  o.fill_rect(x + 12, ry + 32, w - 24, 1, c[:line])
  PARTY.each_with_index do |entry, i|
    py = ry + 38 + i * rh
    art(o, entry[0], x + 24, py + rh / 2, 22)
    P2.text(o, x + 42, py + 4, 120, 18, entry[1], c[:txt], PF::TEXT)
    reach_column(o, c, x + w - 16, py + 5, entry, CAP)
  end
  P2.small(o, x, y + h - 26, w, 16, "Moves and evolutions happen as they would.", c[:dim], 2)
}]

# 2: a menu of where to (each with its level), then a check before it
# raises them: who goes where, and who's locked
DESIGNS << ["QA_SC2_menu_then_check", [[A_PAD, "Choose"], [B_PAD, "Back"]], proc { |o, c|
  # the menu, left
  mw = 222; mh = 42 + 3 * 28 + 10
  mx = 14; my = (HINT_TOP - 250) / 2
  popup(o, c, mx, my, mw, mh, "Super Candy")
  [["Level Cap", "LV #{CAP}"], ["Highest in Party", "LV #{HIGHEST}"], ["A Level...", ""]].each_with_index do |(label, val), i|
    ry = my + 40 + i * 28
    cursor(o, c, mx + 6, ry, mx + mw - 6, ry + 26) if i == 0
    P2.text(o, mx + 14, ry + 5, 130, 18, label, c[:txt], PF::TEXT)
    P2.text(o, mx + mw - 58, ry + 8, 44, 14, val, GOLD_T, PF::TINY, 1) unless val.empty?
  end
  # the check, right (what A on Level Cap opens)
  w = 258; rh = 22; h = 42 + 20 + PARTY.length * rh + 44
  x = SW - 14 - w; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Raise to Lv #{CAP}?", false)
  P2.small(o, x, y + 40, w, 16, "Level locks are kept.", c[:dim], 2)
  PARTY.each_with_index do |entry, i|
    py = y + 60 + i * rh
    P2.text(o, x + 16, py + 2, 120, 18, entry[1], c[:txt], PF::TEXT)
    reach_column(o, c, x + w - 16, py + 3, entry, CAP)
  end
  by = y + h - 36
  [["Raise", true], ["Cancel", false]].each_with_index do |(label, on), i|
    bx = x + w / 2 - 104 + i * 108
    P2.ui.rbox(o, bx, by, bx + 100, by + 24, 5, on ? c[:sel] : c[:panel2], on ? c[:selb] : c[:line])
    P2.text(o, bx, by + 3, 100, 18, label, c[:txt], PF::TEXT, 2)
  end
}]

# 3: pick who: the party with a tick each (A ticks, all ticked at first),
# Raise To at the top; X raises the ticked ones
DESIGNS << ["QA_SC3_pick_who", [[A_PAD, "Tick"], [X_PAD, "Raise"], [B_PAD, "Close"]], proc { |o, c|
  w = 380; rh = 26; h = 42 + 30 + 8 + PARTY.length * rh + 12
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Super Candy")
  ry = y + 40
  P2.text(o, x + 16, ry + 5, 100, 18, "Raise To", c[:txt], PF::TEXT)
  P2.ui.tri(o, x + 150, ry + 8, :l, c[:dim], 5)
  P2.text(o, x + 162, ry + 5, w - 194, 18, "Level Cap (Lv #{CAP})", GOLD_T, PF::TEXT, 2)
  P2.ui.tri(o, x + w - 30, ry + 8, :r, c[:dim], 5)
  o.fill_rect(x + 12, ry + 32, w - 24, 1, c[:line])
  ticked = [true, false, false, true, true, true]
  PARTY.each_with_index do |entry, i|
    py = ry + 38 + i * rh
    cursor(o, c, x + 6, py, x + w - 6, py + rh - 2) if i == 1
    can = ![:locked, :already].include?(reach(entry, CAP)[1])
    bx = x + 14
    P2.ui.rbox(o, bx, py + 6, bx + 12, py + 18, 2, ticked[i] && can ? GREEN_T : c[:dark], can ? c[:line] : c[:dark])
    art(o, entry[0], x + 44, py + rh / 2, 22)
    P2.text(o, x + 62, py + 4, 120, 18, entry[1], can ? c[:txt] : c[:dim], PF::TEXT)
    reach_column(o, c, x + w - 16, py + 5, entry, CAP) if ticked[i] || !can
    P2.small(o, x + w - 136, py + 5, 120, 16, "Left Out", c[:dim], 1) if can && !ticked[i]
  end
}]

run_designs("Super Candy designs", DESIGNS)
