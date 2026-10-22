# encoding: utf-8
# Mockups: Battle Sandbox (topic 35), screen 2: the Pokémon Editor. Editing
# one battler for this battle only: species or fusion, level, abilities
# (Double Abilities: two), item, nature, shiny, moves, and Start Mid-Battle
# (HP, status, stat stages, confusion).
# Sample: Genras (Gengar head, Lapras body), Lv. 50.
# Each design is a pair: the Pokémon itself (left), Start Mid-Battle (right).
# Design 1 = the Settings layout, like the chosen Setup Screen.
# Usage (from this folder): ruby ed_designs.rb "<KIF Beta>" <work dir with metrics.json>
BSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "bs_designs.rb"), :encoding => "UTF-8")
eval(BSRC.split("c = palette(2)\n")[0], binding, "bs_designs.rb")
eval("SIDEX = " + BSRC.split("SIDEX = ")[1].split("bsx(c, 0, nil, 3)")[0], binding, "bs_designs.rb")   # the chosen Setup Screen (mix)

INFO = [["Species", "Gengar"], ["Fused With", "Lapras"], ["Level", "50"], ["Ability", "Cursed Body"], ["Second Ability", "Water Absorb"],
        ["Item", "Leftovers"], ["Nature", "Modest"], ["Shiny", "Off"]]
MOVES = [["Shadow Ball", "GHOST", "15/15"], ["Ice Beam", "ICE", "10/10"], ["Hypnosis", "PSYCHIC", "20/20"], ["Surf", "WATER", "15/15"]]
MID = [["HP", "35%"], ["Status", "Burned"], ["Attack", "-1"], ["Defense", "+2"], ["Sp. Atk", "0"], ["Speed", "0"], ["Accuracy", "0"], ["Confused", "Off"]]
ESECS = [["Pokémon", [96, 160, 232]], ["Moves", [210, 80, 80]], ["Stats", [90, 170, 100]], ["Mid-Battle", [230, 180, 60]]]
def stage_col(c, v); v.start_with?("+") ? GREEN : (v.start_with?("-") ? RED2 : c[:opt]); end
def ed_frame(c, title = "Edit: Genras")
  page_frame(c, title)
  b = BASE.bitmap; t = TOP.bitmap
  mon(t, "GENGAR.LAPRAS", 24, 16, 28)
  P.small(t, 42, 9, 120, 16, "Other Side? No: Yours", c[:dim]) if false
  UI.rbox(b, W - 120, 4, W - 8, 27, 5, c[:dark], c[:line]); P.text(t, W - 120, 4, 112, 23, "Reset", c[:dim], PF::TEXT, 2)
end
def esecs(c, sel)
  t = TOP.bitmap
  UI.rbox(BASE.bitmap, 6, 36, 174, 262, 6, c[:panel])
  ESECS.each_with_index do |(l, rgb), i|
    y = 40 + i * 22
    UI.rbox(t, 14, y + 3, 28, y + 17, 3, Color.new(*rgb)); P.glyph(t, 14, y + 3, 15, 15, l[0], Color.new(248, 248, 248))
    P.text(t, 33, y + 2, 136, 18, l, i == sel ? c[:white] : c[:dim])
  end
end
def rows_list(c, rows, sel, x0 = 184, x1 = W - 10, y0 = 56, step = 25, valx = W - 76)
  t = TOP.bitmap
  rows.each_with_index do |(l, v), i|
    y = y0 + i * step
    cursor_at(x0, y, x1 - x0, step - 1) if i == sel
    P.text(t, x0 + 12, y, 180, step - 1, l, c[:opt], PF::TEXT)
    vc = (v =~ /\A[+-]\d/) ? stage_col(c, v) : nil
    if vc
      vw = P.width(PF::TEXT, v)
      P.text(t, valx - vw / 2, y, vw + 2, step - 1, v, vc, PF::TEXT)
      UI.tri(t, valx - vw / 2 - 14, y + 7, :l, i == sel ? c[:txt] : c[:dim], 4); UI.tri(t, valx + vw / 2 + 6, y + 7, :r, i == sel ? c[:txt] : c[:dim], 4)
    else
      value_cell(t, c, valx, y, v, i == sel)
    end
  end
end

c = palette(2)

#================================================================ ED1 Recommended: the Settings layout; Pokémon, Moves, Stats, Mid-Battle as sections
def ed1(c, sec, sel)
  ed_frame(c); esecs(c, sec); boxes(c)
  P.heading(TOP.bitmap, 190, W - 16, 43, ESECS[sec][0], c[:head], c[:line])
  rows_list(c, sec == 0 ? INFO : MID, sel)
end
ed1(c, 0, 4); desc_box(c, "Second Ability", "Double Abilities: a fusion has two. Any ability can be set here, even one the species can't have, for testing.", ["THIS BATTLE ONLY"])
hints(c, [[:ud, "Select"], [:lr, "Change"], [A_BTN, "List"], [X_BTN, "Default"], [B_BTN, "Sections"]]); dump_as("ED1_info")
ed1(c, 3, 3); desc_box(c, "Defense", "Start Mid-Battle: Genras starts the battle at +2 Defense, as if it had used a move twice.", ["MID-BATTLE"])
hints(c, [[:ud, "Select"], [:lr, "Change"], [X_BTN, "Default"], [B_BTN, "Sections"]]); dump_as("ED1_mid")

#================================================================ ED2: like the Summary: the Pokémon on the left, tabs on the right
def ed2(c, tab, sel)
  ed_frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 36, 186, H - 30, 6, c[:panel])
  mon(t, "GENGAR.LAPRAS", 96, 110, 120)
  P.text(t, 6, 176, 180, 24, "Genras", c[:white], PF::ROW, 2)
  P.small(t, 6, 200, 180, 16, "Gengar + Lapras", c[:dim], 2)
  P.small(t, 6, 218, 180, 16, "Lv. 50  Modest", c[:txt], 2)
  UI.rbox(b, 26, 242, 166, 250, 4, c[:dark]); UI.rbox(b, 26, 242, 26 + (140 * (tab == 2 ? 0.35 : 1.0)).to_i, 250, 4, tab == 2 ? AMB : GREEN)
  P.small(t, 6, 254, 180, 16, tab == 2 ? "HP 35%, Burned" : "HP 100%", tab == 2 ? AMB : c[:dim], 2)
  ["INFO", "MOVES", "MID-BATTLE"].each_with_index do |n, i|
    x = 194 + i * 104
    UI.rbox(b, x, 38, x + 100, 56, 5, i == tab ? c[:sel] : c[:dark], i == tab ? c[:selb] : c[:line])
    P.text(t, x, 39, 100, 16, n, i == tab ? c[:white] : c[:dim], PF::TINY, 2)
  end
  UI.rbox(b, 192, 60, W - 6, H - 30, 6, c[:panel])
  if tab == 0
    rows_list(c, INFO, sel, 196, W - 10, 66, 26)
  else
    rows_list(c, MID, sel, 196, W - 10, 66, 26)
  end
  hints(c, [["p:9", ""], ["p:10", "Tabs"], [:ud, "Select"], [:lr, "Change"], [B_BTN, "Done"]])
end
ed2(c, 0, 4); dump_as("ED2_info")
ed2(c, 2, 1); dump_as("ED2_mid")

#================================================================ ED3: Mid-Battle as a picture: an HP bar, status chips, a -6 to +6 grid of stat stages
STAGES = [["Attack", -1], ["Defense", 2], ["Sp. Atk", 0], ["Sp. Def", 0], ["Speed", 0], ["Accuracy", 0], ["Evasion", 0]]
def ed3(c, mid)
  ed_frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 36, W - 6, 92, 6, c[:panel2], c[:line])
  mon(t, "GENGAR.LAPRAS", 34, 64, 44)
  P.text(t, 64, 40, 200, 22, "Genras  Lv. 50", c[:white], PF::TEXT)
  P.small(t, 64, 62, 300, 16, "Cursed Body, Water Absorb.  Leftovers.  Modest.", c[:dim])
  UI.rbox(b, 6, 98, W - 6, H - 30, 6, c[:panel])
  if mid
    P.text(t, 16, 102, 60, 22, "HP", c[:opt], PF::TEXT)
    UI.rbox(b, 70, 108, 420, 118, 5, c[:dark]); UI.rbox(b, 70, 108, 70 + (350 * 0.35).to_i, 118, 5, AMB)
    P.text(t, 430, 102, 70, 22, "35%", AMB, PF::TEXT, 1)
    P.text(t, 16, 126, 60, 22, "Status", c[:opt], PF::TEXT)
    ["None", "Burned", "Poisoned", "Paralyzed", "Asleep", "Frozen"].each_with_index do |s, i|
      x = 86 + i * 70
      on = s == "Burned"
      UI.rbox(b, x, 128, x + 64, 146, 5, on ? Color.new(80, 40, 20) : c[:dark], on ? AMB : c[:line])
      P.text(t, x, 129, 64, 16, s.upcase, on ? AMB : c[:dim], PF::TINY, 2)
    end
    STAGES.each_with_index do |(n, v), i|
      y = 156 + i * 22
      cursor_at(10, y - 1, W - 20, 22) if n == "Defense"
      P.text(t, 16, y, 90, 20, n, c[:opt], PF::TEXT)
      13.times do |k|
        st = k - 6
        x = 110 + k * 26
        fill = st == 0 ? c[:line] : (st > 0 ? (st <= v ? GREEN : c[:dark]) : (st >= v ? RED2 : c[:dark]))
        UI.rbox(t, x, y + 5, x + 22, y + 15, 3, fill)
      end
      P.text(t, 450, y, 50, 20, v > 0 ? "+#{v}" : v.to_s, v > 0 ? GREEN : (v < 0 ? RED2 : c[:dim]), PF::TEXT, 1)
    end
    hints(c, [[:ud, "Select"], [:lr, "Change"], [X_BTN, "Default"], [B_BTN, "Done"]])
  else
    MOVES.each_with_index do |(m, ty, pp), i|
      y = 108 + i * 40
      cursor_at(10, y, W - 20, 36) if i == 0
      type_id = { "GHOST" => 7, "ICE" => 14, "PSYCHIC" => 13, "WATER" => 11 }[ty]
      t.stretch_blt(Rect.new(20, y + 9, 18, 18), bmp(File.join(GFX, "Pictures/Battle/typesSmall.png")), Rect.new(0, type_id * 19, 19, 19)) rescue nil
      P.text(t, 46, y + 6, 200, 22, m, c[:opt], PF::TEXT)
      P.text(t, 330, y + 6, 160, 22, "PP #{pp}", c[:txt], PF::TEXT, 1)
    end
    P.small(t, 16, 272, 480, 16, "A picks any move in the game. Left and right set its PP.", c[:dim])
    hints(c, [[:ud, "Select"], [A_BTN, "Change"], [:lr, "PP"], [B_BTN, "Done"]])
  end
end
ed3(c, false); dump_as("ED3_moves")
ed3(c, true); dump_as("ED3_mid")

#================================================================ ED4: a panel over the Teams view, so the setup stays in sight; LB and RB turn pages
def ed4(c, page, sel)
  bsx(c, 1, :you, 1); OVER.bitmap.clear
  o = OVER.bitmap
  o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
  UI.rbox(o, 80, 30, 432, 350, 8, c[:panel2], c[:selb])
  mon(o, "GENGAR.LAPRAS", 108, 54, 36)
  P.text(o, 132, 38, 200, 24, "Genras", c[:title], PF::ROW)
  pages = ["INFO", "MOVES", "MID-BATTLE"]
  pages.each_with_index do |n, i|
    x = 250 + i * 60
    P.text(o, x, 46, 60, 14, n == "MID-BATTLE" ? "MID" : n, i == page ? c[:white] : c[:dim], PF::TINY, 2)
    o.fill_rect(x + 8, 60, 44, 2, i == page ? c[:selb] : c[:line])
  end
  rows = page == 0 ? INFO : MID
  rows.each_with_index do |(l, v), i|
    y = 74 + i * 26
    UI.rbox(o, 86, y, 426, y + 24, 4, c[:sel], c[:selb]) if i == sel
    P.text(o, 100, y, 180, 24, l, c[:opt], PF::TEXT)
    colr = (v =~ /\A[+-]\d/) ? stage_col(c, v) : c[:opt]
    vw = P.width(PF::TEXT, v)
    P.text(o, 360 - vw / 2, y, vw + 2, 24, v, colr, PF::TEXT)
    UI.tri(o, 360 - vw / 2 - 14, y + 7, :l, c[:dim], 4); UI.tri(o, 360 + vw / 2 + 6, y + 7, :r, c[:dim], 4)
  end
  o.fill_rect(0, H - 28, W, 28, Color.new(0, 0, 0, 0))
  BASE.bitmap.fill_rect(0, H - 28, W, 28, c[:bg]); TOP.bitmap.fill_rect(0, H - 28, W, 28, Color.new(0, 0, 0, 0))
  hints(c, [["p:9", ""], ["p:10", "Pages"], [:ud, "Select"], [:lr, "Change"], [B_BTN, "Done"]])
end
ed4(c, 0, 4); dump_as("ED4_info")
ed4(c, 2, 3); dump_as("ED4_mid")

#================================================================ ED5: one list with headings, and its EBDX data box as a live preview
def databox(c, x, y, hp, status)
  o = TOP.bitmap; b = BASE.bitmap
  UI.rbox(b, x, y, x + 196, y + 52, 6, Color.new(240, 240, 232), Color.new(80, 84, 96))
  P.text(o, x + 10, y + 2, 120, 20, "Genras", Color.new(40, 40, 48), PF::TEXT)
  P.text(o, x + 120, y + 2, 70, 20, "Lv. 50", Color.new(40, 40, 48), PF::TEXT, 1)
  UI.rbox(b, x + 50, y + 28, x + 186, y + 36, 3, Color.new(60, 60, 70)); UI.rbox(b, x + 50, y + 28, x + 50 + (136 * hp).to_i, y + 36, 3, hp > 0.5 ? GREEN : AMB)
  P.small(o, x + 10, y + 24, 40, 14, "HP", Color.new(200, 120, 40))
  if status
    UI.rbox(b, x + 10, y + 38, x + 44, y + 50, 3, Color.new(220, 110, 60)); P.text(o, x + 10, y + 38, 34, 12, "BRN", Color.new(255, 255, 255), PF::TINY, 2)
  end
end
def ed5(c, mid, sel)
  ed_frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 36, 300, H - 30, 6, c[:panel])
  items = mid ? [[:h, "Mid-Battle"]] + MID.map { |r| [:r] + r } : [[:h, "Pokémon"]] + INFO.map { |r| [:r] + r }
  y = 40; ri = -1
  items.each do |k, l, v|
    if k == :h
      P.heading(t, 14, 292, y + 3, l, c[:head], c[:line]); y += 18
      next
    end
    ri += 1
    cursor_at(10, y, 286, 24) if ri == sel
    P.text(t, 18, y, 140, 24, l, c[:opt], PF::TEXT)
    colr = (v =~ /\A[+-]\d/) ? stage_col(c, v) : nil
    colr ? P.text(t, 180, y, 110, 24, v, colr, PF::TEXT, 1) : P.text(t, 180, y, 110, 24, v, c[:txt], PF::TEXT, 1)
    y += 26
  end
  UI.rbox(b, 312, 36, W - 6, H - 30, 6, c[:panel2], c[:line])
  P.text(t, 312, 40, 194, 18, "PREVIEW", c[:dim], PF::TINY, 2)
  mon(t, "GENGAR.LAPRAS", 409, 110, 96)
  databox(c, 312 + 0, 176, mid ? 0.35 : 1.0, mid)
  P.small_wrap(t, mid ? "Starts at 35% HP, burned, Attack -1, Defense +2." : "Cursed Body and Water Absorb. Holds Leftovers.", 180).each_with_index { |ln, k| P.small(t, 320, 240 + k * 17, 180, 16, ln, c[:txt]) }
  hints(c, [[:ud, "Select"], [:lr, "Change"], [X_BTN, "Default"], [B_BTN, "Done"]])
end
ed5(c, false, 4); dump_as("ED5_info")
ed5(c, true, 3); dump_as("ED5_mid")
