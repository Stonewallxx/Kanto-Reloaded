# encoding: utf-8
# Mockups: Shinies, part 2: the Shiny Log (new). Five designs, each two
# screens: the log and one entry. Every shiny found is recorded: species,
# palette style, date, place, how (wild, Wild Link chain, Poke Radar chain,
# fishing, egg, gift, gamble) and the encounters it took; it feeds the
# Trainer Card's records.
# Design 1 = the chosen Shiny Studio's look as a list and detail page.
# Usage (from this folder): ruby slog_designs.rb "<KIF Beta>" <work dir with metrics.json>
PRSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "prism_designs.rb"), :encoding => "UTF-8")
eval(PRSRC.split("c = palette(2)\n")[0], binding, "prism_designs.rb")

# [species, name, palette, style, date, place, how, encounters]
LOG = [["ABRA", "Abra", "ABRA_rel", "RELOADED", "Oct 18", "Route 24", "Wild Link, Chain 34", "1,204"],
       ["LAPRAS", "Lapras", "LAPRAS_wild", "WILD", "Oct 12", "Silph Co.", "Gift", "1"],
       ["GYARADOS", "Gyarados", "GYARADOS_pif", "DEFAULT", "Oct 9", "Route 25", "Super Rod", "402"],
       ["PIKACHU", "Pikachu", "PIKACHU_rel", "RELOADED", "Oct 3", "Viridian Forest", "Poké Radar, Chain 40", "610"],
       ["GENGAR", "Gengar", "GENGAR_rel2", "RELOADED", "Oct 1", "Day Care", "Egg", "88 Eggs"],
       ["ODDISH", "Oddish", "ODDISH_rel", "RELOADED", "Sep 28", "Route 24", "Wild", "2,931"],
       ["MAGIKARP", "Magikarp", "MAGIKARP_pif", "DEFAULT", "Sep 21", "Route 4", "Old Rod", "377"],
       ["ZUBAT", "Zubat", "ZUBAT_wild", "WILD", "Sep 14", "Mt. Moon", "Wild", "1,812"]]
SELL = 0
def sicon(b, pal, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(File.join(SH, pal + "_icon.png")), Rect.new(0, 0, 64, 64))
end
def star_mark(b, x, y, color = GOLD)
  ["..#..", ".###.", "#####", ".###.", "#.#.#"].each_with_index { |r, j| r.each_char.with_index { |ch, i| b.fill_rect(x + i, y + j, 1, 1, color) if ch == "#" } }
end
def detail(c, b, t, x, y, w, h, e)
  sp, n, pal, st, date, place, how, enc = e
  UI.rbox(b, x, y, x + w, y + h, 8, c[:panel], c[:line])
  UI.rbox(b, x + 10, y + 10, x + 118, y + 118, 6, c[:dark], GOLD)
  spr(t, pal, x + 64, y + 64, 100)
  P.text(t, x + 128, y + 8, w - 136, 24, n, c[:title], PF::ROW)
  style_pill(t, x + 128, y + 36, st)
  swatches(b, x + 128, y + 58, pal.start_with?("LAPRAS") ? pal : "LAPRAS_rel", 10) if pal.start_with?("LAPRAS")
  rows = [["Found", "#{date}, 2026"], ["Where", place], ["How", how], ["Took", enc == "1" ? "First Try" : "#{enc} Encounters"]]
  rows.each_with_index do |(l, v), k|
    yy = y + 128 + k * 22
    P.small(t, x + 14, yy, 70, 16, l, c[:dim]); P.small(t, x + 80, yy, w - 94, 16, v, c[:txt])
  end
end
def counters(c, b, t, x, y, w)
  [["8", "Shinies"], ["2,931", "Longest Hunt"], ["Sep 14", "First Found"]].each_with_index do |(v, l), k|
    cx = x + k * (w / 3)
    P.text(t, cx, y, w / 3, 22, v, GOLD, PF::TEXT, 2); P.small(t, cx, y + 20, w / 3, 16, l, c[:dim], 2)
  end
end

c = palette(2)

#================================================================ SL1 Recommended: a list beside the Studio-style detail
def sl1(c, sel)
  blank(c); b = BASE.bitmap; t = TOP.bitmap
  P.text(t, 0, 4, W, 24, "Shiny Log", c[:title], PF::ROW, 2)
  P.small(t, 10, 8, 120, 16, "8 Shinies", GOLD)
  P.small(t, W - 150, 8, 140, 16, "Sort: Newest", c[:dim], 1)
  UI.rbox(b, 8, 34, 218, 354, 8, c[:panel], c[:line])
  LOG.each_with_index do |e, i|
    y = 40 + i * 39
    cursor_at(12, y, 202, 37) if i == sel
    sicon(t, e[2], 34, y + 18, 36)
    P.text(t, 56, y, 150, 20, e[1], c[:txt], PF::TEXT)
    P.small(t, 56, y + 19, 150, 16, "#{e[4]}, #{e[5]}", c[:dim])
  end
  detail(c, b, t, 226, 34, 278, 230, LOG[sel])
  UI.rbox(b, 226, 272, 504, 354, 8, c[:panel], c[:line])
  P.heading(t, 236, 494, 278, "Your Shinies", c[:head], c[:line])
  counters(c, b, t, 236, 296, 258)
end
sl1(c, 0); hints(c, [[:ud, "Choose"], [A_BTN, "Studio"], [X_BTN, "Sort"], [B_BTN, "Back"]]); shot("SL1_log")
sl1(c, 1); hints(c, [[:ud, "Choose"], [A_BTN, "Studio"], [X_BTN, "Sort"], [B_BTN, "Back"]]); shot("SL1_entry")

#================================================================ SL2: a trophy wall of sprites
def wall(c, sel)
  blank(c); b = BASE.bitmap; t = TOP.bitmap
  P.text(t, 0, 4, W, 24, "Shiny Log", c[:title], PF::ROW, 2)
  LOG.each_with_index do |e, i|
    x = 12 + (i % 4) * 124; y = 34 + (i / 4) * 116
    UI.rbox(b, x, y, x + 116, y + 108, 8, c[:panel], i == sel ? GOLD : c[:line])
    cursor_at(x - 2, y - 2, 120, 112) if i == sel
    spr(t, e[2], x + 58, y + 46, 80)
    P.small(t, x, y + 86, 116, 16, e[1], c[:txt], 2)
    star_mark(t, x + 8, y + 8)
  end
  e = LOG[sel]
  UI.rbox(b, 8, 270, 504, 354, 8, c[:panel2], c[:line])
  P.text(t, 18, 274, 200, 22, e[1], c[:title], PF::ROW)
  style_pill(t, 18, 300, e[3])
  P.small(t, 18, 322, 200, 16, "#{e[4]}, 2026", c[:dim])
  P.small(t, 220, 280, 270, 16, e[5], c[:txt]); P.small(t, 220, 300, 270, 16, e[6], c[:txt])
  P.small(t, 220, 320, 270, 16, "#{e[7]} Encounters", GOLD)
end
wall(c, 0); hints(c, [[:ud, ""], [:lr, "Choose"], [A_BTN, "Studio"], [B_BTN, "Back"]]); shot("SL2_log")
wall(c, 3); hints(c, [[:ud, ""], [:lr, "Choose"], [A_BTN, "Studio"], [B_BTN, "Back"]]); shot("SL2_entry")

#================================================================ SL3: a timeline with month headings
def timeline(c, sel)
  blank(c); b = BASE.bitmap; t = TOP.bitmap
  P.text(t, 0, 4, W, 24, "Shiny Log", c[:title], PF::ROW, 2)
  b.fill_rect(42, 40, 2, 300, c[:line])
  y = 36; idx = 0
  [["October", LOG.first(5)], ["September", LOG.last(3)]].each do |m, list|
    P.heading(t, 56, 496, y, m, c[:head], c[:line]); y += 18
    list.each do |e|
      UI.rbox(b, 36, y + 10, 50, y + 24, 7, GOLD)
      cursor_at(56, y, 444, 34) if idx == sel
      sicon(t, e[2], 78, y + 17, 32)
      P.text(t, 98, y + 1, 120, 20, e[1], c[:txt], PF::TEXT)
      P.small(t, 98, y + 18, 120, 16, e[4], c[:dim])
      P.small(t, 220, y + 1, 170, 16, e[5], c[:txt]); P.small(t, 220, y + 18, 170, 16, e[6], c[:dim])
      P.small(t, 396, y + 9, 96, 16, e[7], GOLD, 1)
      y += 36; idx += 1
    end
  end
end
timeline(c, 0); hints(c, [[:ud, "Choose"], [A_BTN, "Details"], [B_BTN, "Back"]]); shot("SL3_log")
blank(c); b = BASE.bitmap; t = TOP.bitmap
P.text(t, 0, 4, W, 24, "Shiny Log", c[:title], PF::ROW, 2)
detail(c, b, t, 106, 40, 300, 236, LOG[0])
hints(c, [[:lr, "Previous / Next"], [A_BTN, "Studio"], [B_BTN, "Back"]]); shot("SL3_entry")

#================================================================ SL4: a stats page first (totals, by method), then the list
def stats(c)
  blank(c); b = BASE.bitmap; t = TOP.bitmap
  P.text(t, 0, 4, W, 24, "Shiny Log", c[:title], PF::ROW, 2)
  UI.rbox(b, 8, 34, 504, 110, 8, c[:panel], GOLD)
  counters(c, b, t, 20, 46, 470)
  P.small(t, 20, 88, 470, 16, "Average Hunt: 1,067 Encounters", c[:txt], 2)
  UI.rbox(b, 8, 118, 252, 354, 8, c[:panel], c[:line])
  P.heading(t, 18, 242, 124, "By How", c[:head], c[:line])
  [["Wild", 2], ["Wild Link", 1], ["Poké Radar", 1], ["Fishing", 2], ["Eggs", 1], ["Gifts", 1]].each_with_index do |(l, n), k|
    y = 144 + k * 32
    P.small(t, 18, y, 90, 16, l, c[:txt])
    b.fill_rect(108, y + 4, 100, 8, c[:dark]); b.fill_rect(108, y + 4, n * 50, 8, GOLD)
    P.small(t, 214, y, 30, 16, n.to_s, c[:dim], 1)
  end
  UI.rbox(b, 260, 118, 504, 354, 8, c[:panel], c[:line])
  P.heading(t, 270, 494, 124, "By Style", c[:head], c[:line])
  [["RELOADED", 4], ["WILD", 2], ["DEFAULT", 2]].each_with_index do |(s, n), k|
    y = 146 + k * 34
    style_pill(t, 270, y, s); P.text(t, 440, y - 2, 50, 20, n.to_s, c[:txt], PF::TEXT, 1)
  end
  P.heading(t, 270, 494, 254, "Rarest Find", c[:head], c[:line])
  sicon(t, "ODDISH_rel", 290, 296, 40); P.small(t, 314, 280, 180, 16, "Oddish", c[:txt]); P.small(t, 314, 298, 180, 16, "2,931 Encounters", GOLD)
end
stats(c); hints(c, [[:lr, "Pages"], [B_BTN, "Back"]]); shot("SL4_stats")
sl1(c, 0)
b = BASE.bitmap; t = TOP.bitmap
hints(c, [[:ud, "Choose"], [:lr, "Pages"], [A_BTN, "Studio"], [B_BTN, "Back"]]); shot("SL4_log")

#================================================================ SL5: dex order: every species, found shinies lit
DEX = [["PIKACHU", 25, true], ["ZUBAT", 41, true], ["ODDISH", 43, true], ["ABRA", 63, true], ["GENGAR", 94, true], ["MAGIKARP", 129, true],
       ["GYARADOS", 130, true], ["LAPRAS", 131, true]]
DEXALL = [[1, "BULBASAUR"], [4, "CHARMANDER"], [7, "SQUIRTLE"], [25, "PIKACHU"], [41, "ZUBAT"], [43, "ODDISH"], [63, "ABRA"], [74, "GEODUDE"],
          [94, "GENGAR"], [129, "MAGIKARP"], [130, "GYARADOS"], [131, "LAPRAS"], [133, "EEVEE"], [143, "SNORLAX"], [147, "DRATINI"]]
def dexgrid(c, sel)
  blank(c); b = BASE.bitmap; t = TOP.bitmap
  P.text(t, 0, 4, W, 24, "Shiny Log", c[:title], PF::ROW, 2)
  P.small(t, 10, 8, 160, 16, "8 of 576 Species", GOLD)
  DEXALL.each_with_index do |(n, sp), i|
    x = 12 + (i % 5) * 98; y = 34 + (i / 5) * 76
    found = LOG.find { |e| e[0] == sp }
    UI.rbox(b, x, y, x + 92, y + 70, 6, found ? c[:panel] : c[:dark], found ? GOLD : c[:line])
    cursor_at(x - 2, y - 2, 96, 74) if i == sel
    if found
      sicon(t, found[2], x + 46, y + 30, 48); star_mark(t, x + 6, y + 6)
    else
      sicon(t, "#{sp}_sil", x + 46, y + 30, 48)
    end
    P.text(t, x, y + 52, 92, 16, format("No. %03d", n), found ? c[:txt] : c[:dim], PF::TINY, 2)
  end
end
dexgrid(c, 6); hints(c, [[:ud, ""], [:lr, "Choose"], [A_BTN, "Details"], [B_BTN, "Back"]]); shot("SL5_log")
blank(c); b = BASE.bitmap; t = TOP.bitmap
P.text(t, 0, 4, W, 24, "No. 063 Abra", c[:title], PF::ROW, 2)
detail(c, b, t, 106, 40, 300, 236, LOG[0])
hints(c, [[:lr, "Previous / Next"], [A_BTN, "Studio"], [B_BTN, "Back"]]); shot("SL5_entry")
