# encoding: utf-8
# Mockups: the Nature Selector (a Quality of Life tool), opened from the
# Overworld Menu (or the Quality of Life page in Settings). Two steps, a
# gallery each: Pick a Pokémon (shared with the Level Lock Manager), then Pick
# a Nature. Gyarados Lv 35, Adamant, with Jolly highlighted: Attack 106 to 97,
# Speed 66 to 72 (Sp. Atk stays lowered).
# Design 1 = the old Kanto Reloaded's way made into a popup (it used KIF's
# full party screen, then a list of the 25 natures).
# Sprites: python qa_assets.py "<KIF Beta>" first (writes art/ here).
# Usage (from this folder): ruby nature_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "qa_common.rb")

#---------------------------------------------------------------- the natures
SHORT = ["Atk", "Def", "SpA", "SpD", "Spe"]
LONG = ["Attack", "Defense", "Sp. Atk", "Sp. Def", "Speed"]
# raised stat (row) x lowered stat (column); the same stat in both: no change
CHART = [["Hardy", "Lonely", "Adamant", "Naughty", "Brave"],
         ["Bold", "Docile", "Impish", "Lax", "Relaxed"],
         ["Modest", "Mild", "Bashful", "Rash", "Quiet"],
         ["Calm", "Gentle", "Careful", "Quirky", "Sassy"],
         ["Timid", "Hasty", "Jolly", "Naive", "Serious"]]
NATURE = {}
CHART.each_with_index { |row, up| row.each_with_index { |n, down| NATURE[n] = [up, down] } }
ALPHA = NATURE.keys.sort
# his pick (2026-10-21): grouped by the stat raised (Attack first), A to Z in
# each group, then the ones with no change, A to Z
ORDER = (0..4).flat_map { |up| CHART[up].each_with_index.reject { |_, d| d == up }.map(&:first).sort } +
        (0..4).map { |i| CHART[i][i] }.sort
NOW = "Adamant"
PICK = "Jolly"
BASE = [97, 65, 52, 80, 66]      # Gyarados Lv 35 with no nature
def stats_for(n)
  up, down = NATURE[n]
  BASE.each_with_index.map { |v, i| up == down ? v : (i == up ? (v * 1.1).floor : (i == down ? (v * 0.9).floor : v)) }
end

#---------------------------------------------------------------- pieces
# "+Spe -SpA" (green, pink), or "No Change"; from x, or ending at x (:right),
# or centred on x (:centre)
def tags(o, c, x, y, n, align = :left)
  up, down = NATURE[n]
  parts = up == down ? [["No Change", c[:dim]]] : [["+#{SHORT[up]}", GREEN_T], ["-#{SHORT[down]}", PINK_T]]
  ws = parts.map { |t, _| small_w(o, t) }
  total = ws.sum + 5 * (parts.length - 1)
  x0 = align == :right ? x - total : (align == :centre ? x - total / 2 : x)
  parts.each_with_index do |(t, col), i|
    P2.small(o, x0, y, ws[i] + 2, 16, t, col)
    x0 += ws[i] + 5
  end
end
# "Attack  106 > 97" with the new value coloured by which way it went
def stat_line(o, c, x, y, w, i, now, new)
  P2.small(o, x, y, 60, 16, LONG[i], c[:dim])
  if now == new
    P2.small(o, x + w - 34, y, 34, 16, now.to_s, c[:txt], 1)
    return
  end
  col = new > now ? GREEN_T : PINK_T
  P2.small(o, x + w - 80, y, 30, 16, now.to_s, c[:dim], 1)
  P2.ui.tri(o, x + w - 44, y + 4, :r, col, 4)
  P2.small(o, x + w - 34, y, 34, 16, new.to_s, col, 1)
end
DESIGNS = []

#================================================================ Pick a Pokémon
# 1 Recommended: the party as rows in a popup (as Area Encounters and the
# Day Care are): sprite, name, level, and the tool's own column (here each
# one's nature and what it changes)
DESIGNS << ["QA_PK1_party_rows", [[A_PAD, "Choose"], [B_PAD, "Close"]], proc { |o, c|
  party_rows(o, c, "Nature Selector", 2) do |o, c, x, ry, w, (sp, name, lv, nat), i|
    P2.text(o, x + 204, ry + 7, 90, 18, nat, c[:txt], PF::TEXT)
    tags(o, c, x + w - 14, ry + 9, nat, :right)
  end
}]

# 2: the party as six cards, two rows of three, each with its nature
DESIGNS << ["QA_PK2_party_cards", [[A_PAD, "Choose"], [B_PAD, "Close"]], proc { |o, c|
  cw = 136; ch = 96; gap = 8
  w = 3 * cw + 4 * gap; h = 40 + 2 * ch + 3 * gap
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Nature Selector")
  PARTY.each_with_index do |(sp, name, lv, nat), i|
    cx0 = x + gap + (i % 3) * (cw + gap)
    cy0 = y + 38 + gap + (i / 3) * (ch + gap)
    sel = i == 2
    P2.ui.rbox(o, cx0, cy0, cx0 + cw, cy0 + ch, 6, sel ? c[:sel] : c[:panel2], sel ? c[:selb] : c[:line])
    art(o, sp, cx0 + cw / 2, cy0 + 26, 40)
    P2.text(o, cx0, cy0 + 48, cw, 18, name, c[:txt], PF::TEXT, 2)
    P2.text(o, cx0, cy0 + 66, cw, 12, "LV #{lv}  ·  #{nat.upcase}", GOLD_T, PF::TINY, 2)
    tags(o, c, cx0 + cw / 2, cy0 + 78, nat, :centre)
  end
}]

#================================================================ Pick a Nature
# 1 Recommended (his pick, ordered as ORDER): the 25 natures in a list, each
# with what it raises and lowers; beside it, the Pokémon and its stats now and
# with the one highlighted. The nature it has now says NOW.
DESIGNS << ["QA_NS1_list_and_stats", [[A_PAD, "Choose"], [B_PAD, "Back"]], proc { |o, c|
  w = 440; rh = 18; rows = 12; h = 42 + rows * rh + 10
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Gyarados's Nature")
  lx1 = x + 250
  top = 8
  ORDER[top, rows].each_with_index do |n, i|
    ry = y + 40 + i * rh
    cursor(o, c, x + 6, ry, lx1, ry + rh) if n == PICK
    P2.text(o, x + 14, ry + 1, 90, 16, n, c[:txt], PF::TEXT)
    P2.pill(o, x + 92, ry + 1, "NOW", Color.new(70, 58, 20), GOLD_T, false) if n == NOW
    tags(o, c, lx1 - 8, ry + 1, n, :right)
  end
  # the scroll bar: 12 of 25
  bx = lx1 + 4
  P2.ui.rbox(o, bx, y + 42, bx + 3, y + 40 + rows * rh, 1, c[:dark])
  t0 = y + 42 + rows * rh * top / 25
  P2.ui.rbox(o, bx, t0, bx + 3, t0 + rows * rh * rows / 25, 1, c[:selb])
  # the Pokémon and its stats
  px = lx1 + 16; pw = x + w - 12 - px
  art(o, :GYARADOS, px + pw / 2, y + 74, 56)
  P2.text(o, px, y + 106, pw, 12, "LV 35  ·  NOW #{NOW.upcase}", GOLD_T, PF::TINY, 2)
  now = stats_for(NOW); new = stats_for(PICK)
  5.times { |i| stat_line(o, c, px, y + 126 + i * 18, pw, i, now[i], new[i]) }
}]

# 2: the nature chart: a row for each stat it raises, a column for each it
# lowers (the same stat in both changes nothing); the one it has now has a
# gold edge
DESIGNS << ["QA_NS2_chart", [[A_PAD, "Choose"], [B_PAD, "Back"]], proc { |o, c|
  cw = 80; ch = 28
  w = 56 + 5 * cw + 14; h = 40 + 18 + 5 * ch + 44
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Gyarados's Nature")
  gx = x + 56; gy = y + 58
  5.times do |i|
    P2.text(o, gx + i * cw, y + 42, cw, 12, "-#{SHORT[i].upcase}", PINK_T, PF::TINY, 2)
    P2.text(o, x + 8, gy + i * ch + 8, 44, 12, "+#{SHORT[i].upcase}", GREEN_T, PF::TINY, 2)
  end
  CHART.each_with_index do |row, up|
    row.each_with_index do |n, down|
      x0 = gx + down * cw + 2; y0 = gy + up * ch + 2
      fill = n == PICK ? c[:sel] : (up == down ? c[:dark] : c[:panel2])
      edge = n == PICK ? c[:selb] : (n == NOW ? GOLD_T : c[:line])
      P2.ui.rbox(o, x0, y0, x0 + cw - 4, y0 + ch - 4, 4, fill, edge)
      P2.text(o, x0, y0 + 3, cw - 4, 16, n, up == down ? c[:dim] : c[:txt], PF::TEXT, 2)
    end
  end
  iy = gy + 5 * ch + 8
  now = stats_for(NOW); new = stats_for(PICK)
  P2.small(o, x + 14, iy, w - 28, 16, "Attack #{now[0]} > #{new[0]}  ·  Sp. Atk #{new[2]}  ·  Speed #{now[4]} > #{new[4]}", c[:txt], 2)
  P2.small(o, x + 14, iy + 16, w - 28, 16, "Gold edge: the nature it has now.", c[:dim], 2)
}]

# 3: Raise and Lower: pick the stat to raise and the one to lower, and the
# nature that does it shows (the same stat in both: one with no change)
DESIGNS << ["QA_NS3_raise_lower", [[A_PAD, "Choose"], [B_PAD, "Back"]], proc { |o, c|
  w = 360; h = 260
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Gyarados's Nature")
  [["Raise", LONG[4], GREEN_T], ["Lower", LONG[2], PINK_T]].each_with_index do |(label, val, col), i|
    ry = y + 42 + i * 28
    cursor(o, c, x + 6, ry, x + w - 6, ry + 26) if i == 0
    P2.text(o, x + 16, ry + 5, 100, 18, label, c[:txt], PF::TEXT)
    P2.ui.tri(o, x + 168, ry + 8, :l, c[:dim], 5)
    P2.text(o, x + 180, ry + 5, w - 212, 18, val, col, PF::TEXT, 2)
    P2.ui.tri(o, x + w - 30, ry + 8, :r, c[:dim], 5)
  end
  P2.text(o, x, y + 104, w, 22, PICK.upcase, GOLD_T, PF::ROW, 2)
  P2.small(o, x, y + 126, w, 16, "Now #{NOW}", c[:dim], 2)
  now = stats_for(NOW); new = stats_for(PICK)
  5.times { |i| stat_line(o, c, x + 60, y + 148 + i * 18, w - 120, i, now[i], new[i]) }
  P2.small(o, x, y + 240, w, 16, "The same stat in both: no change.", c[:dim], 2)
}]

run_designs("Nature Selector designs", DESIGNS)
