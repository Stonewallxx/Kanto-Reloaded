# encoding: utf-8
# Mockups: Summary, part 3: the Info and Moves pages restyled to match the
# chosen Stats page. Five designs, each two screens (Info, Moves). Lapras:
# No. 131, OT Red, ID 04821, Exp. 32,768 (2,301 to Lv. 33), Mystic Water,
# Modest, met at Silph Co. at Lv. 25 on Oct 12, Water Absorb.
# Moves: Surf, Ice Beam, Hidden Power (shown as its real type, Electric),
# Body Slam. PIF's category icons (Graphics/Pictures/category.png).
# Design 1 = the Stats page's layout (left column the same on every page).
# Usage (from this folder): ruby infomoves_designs.rb "<KIF Beta>" <work dir with metrics.json>
STSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "stats_designs.rb"), :encoding => "UTF-8")
eval(STSRC.split("c = palette(2)\n")[0], binding, "stats_designs.rb")

# [name, type id, category 0 phys 1 spec 2 status, power, acc, pp, max, description]
MOVES = [["Surf", 11, 1, 90, 100, 12, 15, "It swamps the area around the user with a giant wave."],
         ["Ice Beam", 15, 1, 90, 100, 8, 10, "An icy beam that may freeze the target."],
         ["Hidden Power", 13, 1, 60, 100, 15, 15, "A move whose type is this Pokémon's own: Electric."],
         ["Body Slam", 0, 0, 85, 100, 14, 15, "A full-body slam that may leave the target paralyzed."]]
MSEL = 2
INFO = [["Dex No.", "131"], ["Species", "Lapras"], ["OT", "Red"], ["ID No.", "04821"], ["Item", "Mystic Water"]]
MEMO = ["Modest nature.", "Met at Silph Co., Lv. 25, Oct 12, 2026.", "Likes to thrash about."]
def cat_icon(b, cat, x, y, w = 48, h = 21)
  b.stretch_blt(Rect.new(x, y, w, h), bmp(File.join(GFX, "Pictures/category.png")), Rect.new(0, cat * 28, 64, 28))
end
def item_icon2(b, id, cx, cy, size)
  i = bmp(File.join(GFX, "Items", id + ".png"))
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), i, Rect.new(0, 0, i.width, i.height))
end
def left_col(c)
  t = TOP.bitmap; b = BASE.bitmap
  header(c, 14, 32)
  spr(t, "LAPRAS_base", 70, 150, 110)
end
def exp_bar(c, b, t, x, y, w)
  P.small(t, x, y, 60, 16, "Exp.", c[:dim]); P.small(t, x + 60, y, w - 60, 16, "32,768", c[:txt], 1)
  b.fill_rect(x, y + 20, w, 6, c[:dark]); b.fill_rect(x, y + 20, (w * 0.62).round, 6, Color.new(80, 200, 240))
  P.small(t, x, y + 28, w, 16, "2,301 to Lv. 33", c[:dim], 1)
end
def move_row(c, b, t, x, y, w, m, sel, h = 34)
  n, ty, cat, pw, ac, pp, mx, _ = m
  cursor_at(x, y, w, h - 2) if sel
  ticon(t, ty, x + 8, y + (h - 16) / 2 - 1)
  P.text(t, x + 30, y + (h - 24) / 2, 140, 24, n, ty == 13 && n == "Hidden Power" ? c[:txt] : c[:txt], PF::TEXT)
  P.small(t, x + w - 70, y + (h - 16) / 2, 62, 16, "#{pp}/#{mx}", pp <= mx / 3 ? GOLD : c[:dim], 1)
end
def move_detail(c, b, t, x, y, w, m)
  n, ty, cat, pw, ac, pp, mx, desc = m
  UI.rbox(b, x, y, x + w, y + 112, 8, c[:panel], c[:line])
  tbadge(b, ty, x + 10, y + 8, 64, 28); cat_icon(b, cat, x + 78, y + 8, 64, 28)
  P.small(t, x + 150, y + 12, 80, 16, "Power", c[:dim]); P.small(t, x + 190, y + 12, 30, 16, pw.to_s, c[:txt], 1)
  P.small(t, x + 226, y + 12, 80, 16, "Acc.", c[:dim]); P.small(t, x + w - 44, y + 12, 34, 16, "#{ac}%", c[:txt], 1)
  P.small_wrap(t, desc, w - 20).first(3).each_with_index { |ln, k| P.small(t, x + 10, y + 40 + k * 17, w - 20, 17, ln, c[:txt]) }
  P.pill(t, x + 10, y + 92, "REAL TYPE: ELECTRIC", Color.new(60, 54, 14), GOLD, false) if n == "Hidden Power"
end

c = palette(2)

#================================================================ IM1 Recommended: the Stats page's layout on every page
def im1_info(c)
  blank(c); tabs(c, 0); left_col(c)
  b = BASE.bitmap; t = TOP.bitmap
  additional(c, 8, 214, 154)
  UI.rbox(b, 170, 32, 504, 166, 8, c[:panel], c[:line])
  P.heading(t, 178, 496, 36, "Info", c[:head], c[:line])
  INFO.each_with_index do |(l, v), k|
    y = 54 + k * 21
    P.small(t, 182, y, 90, 16, l, c[:dim]); P.small(t, 280, y, 210, 16, v, c[:txt])
  end
  item_icon2(t, "MYSTICWATER", 470, 146, 22)
  UI.rbox(b, 170, 172, 504, 228, 8, c[:panel], c[:line])
  exp_bar(c, b, t, 182, 178, 310)
  UI.rbox(b, 170, 234, 504, 308, 8, c[:panel], c[:line])
  P.heading(t, 178, 496, 238, "Memo", c[:head], c[:line])
  MEMO.each_with_index { |ln, k| P.small(t, 182, 252 + k * 17, 310, 16, ln, k == 0 ? Color.new(240, 110, 100) : c[:txt]) }
  UI.rbox(b, 8, 314, 504, 354, 8, c[:panel2], c[:line])
  P.small(t, 18, 318, 480, 16, "Ability: Water Absorb. Double Abilities adds a second one here.", c[:txt])
  P.small(t, 18, 334, 480, 16, "Shiny: No.", c[:dim])
  hints(c, H_SUM)
end
def im1_moves(c)
  blank(c); tabs(c, 3); left_col(c)
  b = BASE.bitmap; t = TOP.bitmap
  additional(c, 8, 214, 154)
  UI.rbox(b, 170, 32, 504, 182, 8, c[:panel], c[:line])
  P.heading(t, 178, 496, 36, "Moves", c[:head], c[:line])
  MOVES.each_with_index { |m, k| move_row(c, b, t, 174, 52 + k * 32, 326, m, k == MSEL, 32) }
  move_detail(c, b, t, 170, 190, 334, MOVES[MSEL])
  hints(c, [[:lr, "Pages"], [:ud, "Moves"], [A_BTN, "Swap"], [B_BTN, "Back"]])
end
im1_info(c); shot("IM1_info")
im1_moves(c); shot("IM1_moves")

#================================================================ IM2: big move cards in their type colours
TYC = { 11 => Color.new(70, 120, 200), 15 => Color.new(90, 170, 180), 13 => Color.new(190, 160, 40), 0 => Color.new(130, 130, 110) }
def im2_info(c)
  blank(c); tabs(c, 0)
  b = BASE.bitmap; t = TOP.bitmap
  spr(t, "LAPRAS_base", 70, 90, 110)
  P.text(t, 140, 36, 160, 24, "Lapras", c[:title], PF::ROW); P.small(t, 140, 60, 140, 16, "Lv. 32, No. 131", c[:txt])
  tbadge(b, 11, 140, 82); tbadge(b, 15, 192, 82)
  exp_bar(c, b, t, 300, 40, 200)
  UI.rbox(b, 8, 150, 504, 354, 8, c[:panel], c[:line])
  rows = INFO.drop(2) + [["Nature", "Modest (+SpA, -Atk)"], ["Met", "Silph Co., Lv. 25"], ["Date", "Oct 12, 2026"], ["Ability", "Water Absorb"], ["Hidden Power", "Electric"]]
  rows.each_with_index do |(l, v), k|
    x = 20 + (k % 2) * 244; y = 160 + (k / 2) * 36
    P.small(t, x, y, 110, 16, l, c[:dim]); P.text(t, x, y + 14, 230, 20, v, c[:txt], PF::TEXT)
  end
  hints(c, H_SUM)
end
def im2_moves(c)
  blank(c); tabs(c, 3)
  b = BASE.bitmap; t = TOP.bitmap
  MOVES.each_with_index do |(n, ty, cat, pw, ac, pp, mx, desc), k|
    x = 8 + (k % 2) * 250; y = 32 + (k / 2) * 92
    UI.rbox(b, x, y, x + 246, y + 86, 8, TYC[ty], k == MSEL ? c[:white] : c[:line])
    cursor_at(x - 2, y - 2, 250, 90) if k == MSEL
    P.text(t, x + 10, y + 6, 180, 24, n, c[:white], PF::ROW)
    cat_icon(b, cat, x + 10, y + 36); ticon(t, ty, x + 220, y + 10)
    P.small(t, x + 70, y + 38, 160, 16, "Power #{pw}  Acc. #{ac}%", c[:white])
    P.small(t, x + 10, y + 64, 226, 16, "PP #{pp}/#{mx}", c[:white], 1)
  end
  UI.rbox(b, 8, 220, 504, 354, 8, c[:panel], c[:line])
  P.text(t, 18, 226, 300, 24, "Hidden Power", c[:title], PF::ROW)
  P.small_wrap(t, MOVES[MSEL][7], 470).first(2).each_with_index { |ln, k| P.small(t, 18, 252 + k * 17, 480, 17, ln, c[:txt]) }
  P.pill(t, 18, 296, "REAL TYPE: ELECTRIC", Color.new(60, 54, 14), GOLD, false)
  hints(c, [[:lr, "Pages"], [:ud, "Moves"], [A_BTN, "Swap"], [B_BTN, "Back"]])
end
im2_info(c); shot("IM2_info")
im2_moves(c); shot("IM2_moves")

#================================================================ IM3: PIF's page order kept (Info, Memo apart), restyled
def im3(c, page)
  blank(c); tabs(c, page)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 32, 200, 354, 8, c[:panel], c[:line])
  spr(t, "LAPRAS_base", 104, 110, 130)
  P.text(t, 8, 184, 192, 24, "Lapras", c[:title], PF::ROW, 2); P.small(t, 8, 208, 192, 16, "Lv. 32", c[:txt], 2)
  tbadge(b, 11, 52, 230); tbadge(b, 15, 104, 230)
  item_icon2(t, "MYSTICWATER", 40, 290, 24); P.small(t, 58, 282, 140, 16, "Mystic Water", c[:txt])
  UI.rbox(b, 208, 32, 504, 354, 8, c[:panel], c[:line])
  if page == 0
    (INFO + [["Ability", "Water Absorb"]]).each_with_index do |(l, v), k|
      y = 44 + k * 36
      P.small(t, 220, y, 100, 16, l, c[:dim]); P.text(t, 220, y + 14, 270, 22, v, c[:txt], PF::TEXT)
    end
    exp_bar(c, b, t, 220, 266, 272)
  else
    MOVES.each_with_index { |m, k| move_row(c, b, t, 212, 40 + k * 38, 288, m, k == MSEL, 36) }
    b.fill_rect(216, 196, 280, 1, c[:line])
    m = MOVES[MSEL]
    tbadge(b, m[1], 220, 202, 64, 28); cat_icon(b, m[2], 288, 202, 64, 28)
    P.small(t, 356, 208, 136, 16, "60, 100%", c[:txt], 1)
    P.small_wrap(t, m[7], 270).first(3).each_with_index { |ln, k| P.small(t, 220, 236 + k * 17, 272, 17, ln, c[:txt]) }
  end
  hints(c, page == 0 ? H_SUM : [[:lr, "Pages"], [:ud, "Moves"], [A_BTN, "Swap"], [B_BTN, "Back"]])
end
im3(c, 0); shot("IM3_info")
im3(c, 3); shot("IM3_moves")

#================================================================ IM4: an overview page (Info, Memo, ability, top stats) and moves with matchups
def im4_info(c)
  blank(c); tabs(c, 0)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 32, 504, 140, 8, c[:panel], c[:line])
  spr(t, "LAPRAS_base", 64, 86, 96)
  P.text(t, 120, 38, 160, 24, "Lapras", c[:title], PF::ROW); P.small(t, 120, 62, 160, 16, "Lv. 32, Modest", c[:txt])
  tbadge(b, 11, 120, 84); tbadge(b, 15, 172, 84)
  exp_bar(c, b, t, 300, 42, 194)
  P.small(t, 120, 112, 380, 16, "OT Red, ID 04821. Met at Silph Co., Lv. 25, Oct 12.", c[:dim])
  [["Ability", "Water Absorb", "Restores HP when hit by Water."], ["Item", "Mystic Water", "Powers up Water moves."], ["Hidden Power", "Electric", "Its own type, from HR."]].each_with_index do |(l, v, d), k|
    y = 148 + k * 68
    UI.rbox(b, 8, y, 504, y + 62, 8, c[:panel], c[:line])
    P.small(t, 18, y + 4, 120, 16, l, c[:dim]); P.text(t, 18, y + 20, 200, 22, v, c[:txt], PF::TEXT)
    P.small(t, 220, y + 22, 276, 16, d, c[:dim])
  end
  hints(c, H_SUM)
end
def im4_moves(c)
  blank(c); tabs(c, 3)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 32, 504, 354, 8, c[:panel], c[:line])
  ["MOVE", "", "POW", "ACC", "PP"].each_with_index { |h, k| P.text(t, [20, 0, 290, 350, 420][k], 38, 60, 14, h, c[:head], PF::TINY) }
  MOVES.each_with_index do |(n, ty, cat, pw, ac, pp, mx, desc), k|
    y = 56 + k * 40
    cursor_at(12, y, 488, 38) if k == MSEL
    ticon(t, ty, 20, y + 10); P.text(t, 42, y + 6, 160, 24, n, c[:txt], PF::TEXT)
    cat_icon(b, cat, 210, y + 8, 44, 20)
    P.text(t, 280, y + 6, 40, 24, pw.to_s, c[:txt], PF::TEXT, 1); P.text(t, 340, y + 6, 50, 24, "#{ac}%", c[:txt], PF::TEXT, 1); P.text(t, 410, y + 6, 70, 24, "#{pp}/#{mx}", c[:dim], PF::TEXT, 1)
  end
  b.fill_rect(16, 220, 480, 1, c[:line])
  P.small_wrap(t, MOVES[MSEL][7], 470).first(2).each_with_index { |ln, k| P.small(t, 20, 228 + k * 17, 476, 17, ln, c[:txt]) }
  P.heading(t, 20, 494, 270, "Super Effective On", c[:head], c[:line])
  [[11, "Water"], [2, "Flying"]].each_with_index { |(id, n), k| ticon(t, id, 20 + k * 90, 290); P.small(t, 40 + k * 90, 290, 60, 16, n, c[:txt]) }
  hints(c, [[:lr, "Pages"], [:ud, "Moves"], [A_BTN, "Swap"], [B_BTN, "Back"]])
end
im4_info(c); shot("IM4_info")
im4_moves(c); shot("IM4_moves")

#================================================================ IM5: compact: a facts list and moves with their text inline
def im5(c, page)
  blank(c); tabs(c, page)
  b = BASE.bitmap; t = TOP.bitmap
  spr(t, "LAPRAS_base", 52, 72, 72)
  P.text(t, 96, 34, 160, 24, "Lapras", c[:title], PF::ROW); P.small(t, 96, 58, 140, 16, "Lv. 32", c[:txt])
  tbadge(b, 11, 230, 40); tbadge(b, 15, 282, 40)
  UI.rbox(b, 8, 96, 504, 354, 8, c[:panel], c[:line])
  if page == 0
    (INFO + [["Exp.", "32,768 (2,301 to go)"], ["Nature", "Modest"], ["Met", "Silph Co., Lv. 25, Oct 12"], ["Ability", "Water Absorb"]]).each_with_index do |(l, v), k|
      y = 104 + k * 26
      b.fill_rect(16, y + 24, 480, 1, c[:line]) if k < 8
      P.text(t, 20, y, 140, 24, l, c[:dim], PF::TEXT); P.text(t, 170, y, 320, 24, v, c[:txt], PF::TEXT)
    end
  else
    MOVES.each_with_index do |(n, ty, cat, pw, ac, pp, mx, desc), k|
      y = 104 + k * 62
      cursor_at(12, y, 488, 60) if k == MSEL
      ticon(t, ty, 20, y + 6); P.text(t, 42, y + 2, 160, 24, n, c[:txt], PF::TEXT)
      cat_icon(b, cat, 230, y + 4, 40, 18); P.small(t, 280, y + 4, 140, 16, "#{pw}, #{ac}%", c[:txt]); P.small(t, 420, y + 4, 70, 16, "#{pp}/#{mx}", c[:dim], 1)
      P.small(t, 42, y + 28, 450, 16, desc, c[:dim])
    end
  end
  hints(c, page == 0 ? H_SUM : [[:lr, "Pages"], [:ud, "Moves"], [A_BTN, "Swap"], [B_BTN, "Back"]])
end
im5(c, 0); shot("IM5_info")
im5(c, 3); shot("IM5_moves")
