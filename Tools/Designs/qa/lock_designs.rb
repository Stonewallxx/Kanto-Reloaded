# encoding: utf-8
# Mockups: the Level Lock Manager (a Quality of Life tool). Pick a Pokémon is
# his pick for the Nature Selector (Party Rows), with a lock column here;
# then setting the lock, three designs, drawn over it. Gyarados Lv 35 is
# locked at Lv 35, Eevee Lv 22 at Lv 25; KIF's level cap is Lv 38.
# Design 1 = the old Kanto Reloaded's way (a number from the Pokémon's level
# to 100) as a popup.
# Sprites: python qa_assets.py "<KIF Beta>" first (writes art/ here).
# Usage (from this folder): ruby lock_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "qa_common.rb")

LOCKS = { :GYARADOS => 35, :EEVEE => 25 }
CAP = 38
# the lock column: a gold padlock and the level, or Not Locked
def lock_column(o, c, x, ry, w, sp)
  lv = LOCKS[sp]
  unless lv
    P2.small(o, x + w - 134, ry + 9, 120, 16, "Not Locked", c[:dim], 1)
    return
  end
  tw = P2.text(o, x + w - 74, ry + 9, 60, 14, "LV #{lv}", GOLD_T, PF::TINY, 1)
  lock_icon(o, x + w - 14 - tw - 14, ry + 10, GOLD_T)
end
def manager(o, c, dim = true)
  party_rows(o, c, "Level Lock Manager", 2, dim) { |o, c, x, ry, w, entry, i| lock_column(o, c, x, ry, w, entry[0]) }
end

DESIGNS = []

# 0: the manager itself (Party Rows with the lock column)
DESIGNS << ["QA_LL0_manager", [[A_PAD, "Choose"], [B_PAD, "Close"]], proc { |o, c| manager(o, c) }]

# 1 Recommended: the old way: the level as a number (Left and Right), from
# its level now to 100, and Unlock
DESIGNS << ["QA_LL1_number", [[A_PAD, "Set"], [B_PAD, "Back"]], proc { |o, c|
  manager(o, c)
  shade(o)
  w = 320; h = 132
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Gyarados's Level Lock", false)
  ry = y + 42
  cursor(o, c, x + 6, ry, x + w - 6, ry + 26)
  P2.text(o, x + 16, ry + 5, 100, 18, "Lock At", c[:txt], PF::TEXT)
  P2.ui.tri(o, x + 150, ry + 8, :l, c[:dim], 5)
  P2.text(o, x + 162, ry + 5, w - 194, 18, "Lv 35", GOLD_T, PF::TEXT, 2)
  P2.ui.tri(o, x + w - 30, ry + 8, :r, c[:dim], 5)
  P2.text(o, x + 16, ry + 33, 100, 18, "Unlock", c[:txt], PF::TEXT)
  P2.small(o, x, y + h - 26, w, 16, "It gains no EXP past this level.", c[:dim], 2)
}]

# 2: choices: lock where it is, at the level cap, at another level, or unlock
DESIGNS << ["QA_LL2_choices", [[A_PAD, "Choose"], [B_PAD, "Back"]], proc { |o, c|
  manager(o, c)
  w = 300; rh = 28; rows = [["Lock Here", "Lv 35"], ["Lock at the Level Cap", "Lv #{CAP}"], ["Lock at Another Level", ""], ["Unlock", ""]]
  h = 42 + rows.length * rh + 10
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  shade(o)
  popup(o, c, x, y, w, h, "Gyarados's Level Lock", false)
  rows.each_with_index do |(label, val), i|
    ry = y + 40 + i * rh
    cursor(o, c, x + 6, ry, x + w - 6, ry + rh - 2) if i == 1
    P2.text(o, x + 16, ry + 5, 200, 18, label, c[:txt], PF::TEXT)
    next if val.empty?
    if i == 0
      P2.pill(o, x + w - 60, ry + 6, "NOW", GOLD_FILL, GOLD_T, true)
    end
    P2.text(o, x + w - 58, ry + 8, 44, 14, val.upcase, GOLD_T, PF::TINY, 1)
  end
}]

# 3: a level ruler: the lock stays in the middle and the levels slide under
# it with Left and Right (L and R by 10); its level now and the level cap
# are marked
DESIGNS << ["QA_LL3_ruler", [[A_PAD, "Set"], [X_PAD, "Unlock"], [B_PAD, "Back"]], proc { |o, c|
  manager(o, c)
  shade(o)
  w = 400; h = 168
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Gyarados's Level Lock", false)
  lock = 40
  P2.text(o, x, y + 42, w, 20, "Lock at Lv #{lock}", c[:txt], PF::ROW, 2)
  bx0 = x + 24; bx1 = x + w - 24; by = y + 96
  step = (bx1 - bx0) / 20.0
  o.fill_rect(bx0, by, bx1 - bx0, 1, c[:line])
  (lock - 10..lock + 10).each do |lv|
    tx = (bx0 + (lv - lock + 10) * step).round
    tall = lv % 5 == 0
    col = lv == CAP ? GOLD_T : (lv == 35 ? c[:txt] : c[:dim])
    o.fill_rect(tx, by - (tall ? 8 : 4), lv == CAP || lv == 35 ? 2 : 1, tall ? 8 : 4, col)
    P2.text(o, tx - 15, by + 6, 30, 12, lv.to_s, c[:dim], PF::TINY, 2) if tall
  end
  # the lock in the middle
  mx = (bx0 + 10 * step).round
  P2.ui.tri(o, mx - 4, by - 22, :d, c[:selb], 5)
  o.fill_rect(mx, by - 12, 2, 14, c[:selb])
  # its level now and the cap, named above their marks
  P2.text(o, (bx0 + 5 * step).round - 20, by - 26, 40, 12, "NOW", c[:txt], PF::TINY, 2)
  P2.text(o, (bx0 + (CAP - lock + 10) * step).round - 20, by - 26, 40, 12, "CAP", GOLD_T, PF::TINY, 2)
  P2.small(o, x, y + h - 30, w, 16, "Left and Right: 1 level. L and R: 10.", c[:dim], 2)
}]

run_designs("Level Lock Manager designs", DESIGNS)
