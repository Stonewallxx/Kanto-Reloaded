# encoding: utf-8
# Mockups: Shinies, part 3: the Shinies page in Settings (the improved KIF
# Settings layout). Five designs, each two screens: the page with Reloaded
# colours, then with KIF Colors (KIF's own engine rows come back).
# Rows: Shiny Colors (Reloaded / KIF Colors / PIF Only), Overworld Sparkle,
# Shiny Log; KIF's Shiny Animation, Shiny Icons, Wild Shiny Odds, Shiny
# Trainer Pokemon, Shiny Gamble Odds. With Reloaded on, KIF's colour rows
# (Shiny Colors, PIF's Improved Shinies, Shiny Fuse Dye, Cache, Filter) are
# taken over.
# Design 1 = plain Settings rows with the description box.
# Usage (from this folder): ruby sset_designs.rb "<KIF Beta>" <work dir with metrics.json>
PRSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "prism_designs.rb"), :encoding => "UTF-8")
eval(PRSRC.split("c = palette(2)\n")[0], binding, "prism_designs.rb")

REL_ROWS = [["Shiny System", "Shiny Colors", "Reloaded"], ["Shiny System", "Overworld Sparkle", "On"], ["Shiny System", "Shiny Log", "On"],
            ["Look", "Shiny Animation", "On"], ["Look", "Shiny Icons", "On"],
            ["Odds", "Wild Shiny Odds", "1 in 4096"], ["Odds", "Trainer Shinies", "Off"], ["Odds", "Gamble Odds", "1 in 100"]]
KIF_ROWS = [["Shiny System", "Shiny Colors", "KIF Colors"], ["Shiny System", "KIF Color Mode", "Normal"], ["Shiny System", "PIF's Shinies", "Hybrid"],
            ["Shiny System", "Fuse Dye", "Off"], ["Shiny System", "Overworld Sparkle", "On"], ["Look", "Shiny Cache", "Permanent"],
            ["Look", "Shiny Filter", "Off"], ["Odds", "Wild Shiny Odds", "1 in 4096"]]
def rows(c, list, sel, x0 = 180, x1 = W - 6, max_y = 236)
  t = TOP.bitmap; b = BASE.bitmap
  y = 40; last = nil
  list.each_with_index do |(group, label, value), idx|
    if group != last
      P.heading(t, x0 + 10, x1 - 10, y + 3, group, c[:head], c[:line]); y += 18; last = group
    end
    break if y > max_y
    cursor_at(x0 + 4, y, x1 - x0 - 14, 24) if idx == sel
    P.text(t, x0 + 21, y, 200, 24, label, c[:opt], PF::ROW)
    value_cell(t, c, x1 - 66, y, value, idx == sel)
    y += 24
  end
  b.fill_rect(x1 - 5, 44, 2, 212, c[:line]); b.fill_rect(x1 - 5, 44, 2, 70, c[:dim])
end
def page(c); blank(c); settings_frame(c, SECTIONS, 1); end
HS = [[:ud, "Select"], [:lr, "Change"], [X_BTN, "Default"], [B_BTN, "Sections"]]

c = palette(2)

#================================================================ SS1 Recommended: Settings rows with the description box
page(c); rows(c, REL_ROWS, 0)
desc_box(c, "Shiny Colors", "Reloaded: every shiny gets its own palette (Default, Reloaded or Wild style). KIF Colors: KIF's own engine. PIF Only: PIF's shinies.", ["TAKES OVER KIF COLORS"])
hints(c, HS); shot("SS1_reloaded")
page(c); rows(c, KIF_ROWS, 0)
desc_box(c, "Shiny Colors", "KIF Colors: KIF's own shiny engine and its options come back (Color Mode, PIF's Shinies, Fuse Dye, Cache, Filter).")
hints(c, HS); shot("SS1_kif")

#================================================================ SS2: a live sample beside the description
def sample(c, pals, label)
  b = BASE.bitmap; t = TOP.bitmap
  pals.each_with_index do |p, k|
    x = W - 14 - (pals.length - k) * 58
    UI.rbox(b, x, 274, x + 52, 326, 6, c[:dark], c[:line])
    spr(t, p, x + 26, 300, 48)
  end
  P.small(t, W - 14 - pals.length * 58, 330, pals.length * 58 - 6, 16, label, c[:dim], 2)
end
page(c); rows(c, REL_ROWS, 0)
t = TOP.bitmap
P.text(t, 14, 269, 250, 26, "Shiny Colors", c[:head], PF::ROW)
P.small_wrap(t, "Every shiny gets its own palette. Three Lapras, three looks.", 230).first(3).each_with_index { |ln, k| P.small(t, 14, 297 + k * 17, 240, 17, ln, c[:txt]) }
sample(c, ["LAPRAS_rel", "LAPRAS_wild", "LAPRAS_rel2"], "Samples Change With It")
hints(c, HS); shot("SS2_reloaded")
page(c); rows(c, KIF_ROWS, 1)
t = TOP.bitmap
P.text(t, 14, 269, 250, 26, "KIF Color Mode", c[:head], PF::ROW)
P.small_wrap(t, "Normal: KIF's hue shifts and channel swaps.", 230).first(3).each_with_index { |ln, k| P.small(t, 14, 297 + k * 17, 240, 17, ln, c[:txt]) }
sample(c, ["LAPRAS_pif", "LAPRAS_rel2", "LAPRAS_wild"], "KIF Colors Samples")
hints(c, HS); shot("SS2_kif")

#================================================================ SS3: three mode cards on top, rows below
def cards(c, sel)
  blank(c); b = BASE.bitmap; t = TOP.bitmap
  P.text(t, 0, 4, W, 24, "Shinies", c[:title], PF::ROW, 2)
  [["Reloaded", "LAPRAS_rel", "Own Palette Each"], ["KIF Colors", "LAPRAS_rel2", "KIF's Engine"], ["PIF Only", "LAPRAS_pif", "One per Species"]].each_with_index do |(n, p, sub), k|
    x = 8 + k * 168
    UI.rbox(b, x, 34, x + 160, 150, 8, k == sel ? c[:sel] : c[:panel], k == sel ? c[:selb] : c[:line])
    spr(t, p, x + 80, 78, 72)
    P.text(t, x, 112, 160, 22, n, k == sel ? c[:white] : c[:txt], PF::TEXT, 2)
    P.small(t, x, 130, 160, 16, sub, c[:dim], 2)
  end
  UI.rbox(b, 8, 158, 504, 354, 8, c[:panel], c[:line])
  list = sel == 0 ? REL_ROWS.drop(1) : KIF_ROWS.drop(1)
  y = 164
  list.first(7).each_with_index do |(g, l, v), i|
    P.text(t, 24, y, 200, 24, l, c[:opt], PF::ROW)
    value_cell(t, c, W - 70, y, v, false)
    y += 26
  end
end
cards(c, 0); hints(c, [[:lr, "Colors"], [:ud, "Options"], [B_BTN, "Back"]]); shot("SS3_reloaded")
cards(c, 1); hints(c, [[:lr, "Colors"], [:ud, "Options"], [B_BTN, "Back"]]); shot("SS3_kif")

#================================================================ SS4: the odds broken down (what changes your chances)
page(c); rows(c, REL_ROWS, 5)
t = TOP.bitmap; b = BASE.bitmap
P.text(t, 14, 269, 200, 26, "Wild Shiny Odds", c[:head], PF::ROW)
P.small(t, 14, 297, 220, 17, "Base odds for wild Pokémon.", c[:txt])
P.small(t, 14, 314, 220, 17, "Changes affect new ones.", c[:dim])
[["Shiny Charm", "x3"], ["Wild Link, SL 34", "+2 Rolls"], ["Poké Radar, Chain 40", "1 in 99"]].each_with_index do |(l, v), k|
  P.small(t, 250, 280 + k * 18, 160, 16, l, c[:txt]); P.small(t, 410, 280 + k * 18, 88, 16, v, GOLD, 1)
end
b.fill_rect(250, 335, 248, 1, c[:line])
hints(c, HS); shot("SS4_reloaded")
page(c); rows(c, KIF_ROWS, 7)
t = TOP.bitmap
P.text(t, 14, 269, 200, 26, "Wild Shiny Odds", c[:head], PF::ROW)
P.small(t, 14, 297, 220, 17, "Same odds with KIF Colors.", c[:txt])
[["Shiny Charm", "x3"], ["Wild Link, SL 34", "+2 Rolls"], ["Poké Radar, Chain 40", "1 in 99"]].each_with_index do |(l, v), k|
  P.small(t, 250, 280 + k * 18, 160, 16, l, c[:txt]); P.small(t, 410, 280 + k * 18, 88, 16, v, GOLD, 1)
end
hints(c, HS); shot("SS4_kif")

#================================================================ SS5: Shiny Colors opens a dropdown with a sample per choice (Option Dropdowns)
page(c); rows(c, REL_ROWS, 0)
desc_box(c, "Shiny Colors", "Reloaded: every shiny gets its own palette.")
d = OVER.bitmap
UI.rbox(d, 330, 56, 500, 222, 6, col(c[:panel], 255), c[:selb])
[["Reloaded", "LAPRAS_rel", "NOW"], ["KIF Colors", "LAPRAS_rel2", ""], ["PIF Only", "LAPRAS_pif", ""]].each_with_index do |(n, p, tag), k|
  y = 60 + k * 54
  UI.rbox(d, 334, y, 496, y + 50, 5, c[:sel], c[:selb]) if k == 0
  spr(d, p, 362, y + 25, 44)
  P.text(d, 390, y + 4, 100, 22, n, k == 0 ? c[:white] : c[:txt], PF::TEXT)
  P.pill(d, 390, y + 28, tag, Color.new(40, 60, 90), RELC, false) unless tag.empty?
end
hints(c, [[:ud, "Choose"], [A_BTN, "Pick"], [B_BTN, "Close"]]); shot("SS5_dropdown")
page(c); rows(c, KIF_ROWS, 0)
desc_box(c, "Shiny Colors", "KIF Colors: KIF's own engine and its options.")
hints(c, HS); shot("SS5_kif")

#================================================================ SSX: his mix: 1's rows + 2's live samples, in the Kanto Reloaded section (Shinies heading)
KR_REL = [["Shinies", "Shiny Colors", "Reloaded"], ["Shinies", "Overworld Sparkle", "On"], ["Shinies", "Shiny Log", "On"],
          ["Shinies", "Shiny Animation", "On"], ["Shinies", "Shiny Icons", "On"], ["Shinies", "Wild Shiny Odds", "1 in 4096"],
          ["Shinies", "Trainer Shinies", "Off"]]
KR_KIF = [["Shinies", "Shiny Colors", "KIF Colors"], ["Shinies", "KIF Color Mode", "Normal"], ["Shinies", "PIF's Shinies", "Hybrid"],
          ["Shinies", "Fuse Dye", "Off"], ["Shinies", "Overworld Sparkle", "On"], ["Shinies", "Shiny Cache", "Permanent"], ["Shinies", "Shiny Filter", "Off"]]
def kr_page(c); blank(c); settings_frame(c, SECTIONS, 0); end
kr_page(c); rows(c, KR_REL, 0)
t = TOP.bitmap
P.text(t, 14, 269, 250, 26, "Shiny Colors", c[:head], PF::ROW)
P.small_wrap(t, "Reloaded: every shiny gets its own palette. KIF Colors: KIF's engine. PIF Only: PIF's shinies.", 230).first(3).each_with_index { |ln, k| P.small(t, 14, 297 + k * 17, 240, 17, ln, c[:txt]) }
sample(c, ["LAPRAS_rel", "LAPRAS_wild", "LAPRAS_rel2"], "Samples Change With It")
hints(c, HS); shot("SSX_reloaded")
kr_page(c); rows(c, KR_KIF, 1)
t = TOP.bitmap
P.text(t, 14, 269, 250, 26, "KIF Color Mode", c[:head], PF::ROW)
P.small_wrap(t, "KIF Colors brings KIF's engine and its options back. Normal: hue shifts and channel swaps.", 230).first(3).each_with_index { |ln, k| P.small(t, 14, 297 + k * 17, 240, 17, ln, c[:txt]) }
sample(c, ["LAPRAS_pif", "LAPRAS_rel2", "LAPRAS_wild"], "KIF Colors Samples")
hints(c, HS); shot("SSX_kif")
