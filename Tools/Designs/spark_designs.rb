# encoding: utf-8
# Mockups: Shinies, part 4: Overworld Sparkle. Five designs, each two
# screens, on Route 24 with a shiny Abra (a Wild Link target, its follower
# sprite in its palette). Sparkles use EBDX's own shiny pieces
# (ebShiny1-3, ebStar), so they match the battle's shiny sparkle.
# Design 1 = EBDX's sparkle every few seconds, and an alert in the Weather
# alert's corner the first time it's seen.
# Usage (from this folder): ruby spark_designs.rb "<KIF Beta>" <work dir with metrics.json>
PRSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "prism_designs.rb"), :encoding => "UTF-8")
eval(PRSRC.split("c = palette(2)\n")[0], binding, "prism_designs.rb")

def star_mark(b, x, y, color = GOLD)
  ["..#..", ".###.", "#####", ".###.", "#.#.#"].each_with_index { |r, j| r.each_char.with_index { |ch, i| b.fill_rect(x + i, y + j, 1, 1, color) if ch == "#" } }
end
def alert(c, title, sub, x = 8, y = 8, w = 200)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + 44, 8, c[:panel], GOLD)
  icon(t, "ABRA_rel", x + 22, y + 22, 40)
  P.text(t, x + 44, y + 1, w - 50, 24, title, GOLD, PF::TEXT)
  P.small(t, x + 44, y + 23, w - 50, 16, sub, c[:dim])
end
def hud(c, x = 8, y = 8, w = 196)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + 44, 8, c[:panel], GOLD)
  icon(t, "ABRA_rel", x + 22, y + 22, 40)
  P.text(t, x + 44, y + 1, 90, 24, "Abra", c[:txt], PF::TEXT)
  star_mark(t, x + 44 + P.width(PF::TEXT, "Abra") + 4, y + 9)
  P.small(t, x + 44, y + 23, 90, 16, "Chain 12", GOLD)
  P.small(t, x + w - 96, y + 4, 88, 16, "SL 34", c[:dim], 1)
  P.small(t, x + w - 96, y + 23, 88, 16, "Shiny!", GOLD, 1)
end

c = palette(2)

#================================================================ SP1 Recommended: EBDX's sparkle every few seconds; an alert the first time
bg(c, "sp_sparkle.png"); shot("SP1_sparkle")
bg(c, "sp_burst.png"); alert(c, "Shiny Abra!", "Route 24"); shot("SP1_alert")

#================================================================ SP2: a soft golden glow, always on; the Chain HUD marks it
bg(c, "sp_glow.png"); shot("SP2_glow")
bg(c, "sp_glow.png"); hud(c); shot("SP2_hud")

#================================================================ SP3: EBDX's shiny star above it
bg(c, "sp_star.png"); shot("SP3_star")
bg(c, "sp_star.png"); alert(c, "Shiny Abra!", "Route 24"); shot("SP3_alert")

#================================================================ SP4: one burst on first sight (and its sound), then it looks normal
bg(c, "sp_burst.png"); shot("SP4_burst")
bg(c, "sp_plain.png"); hud(c); shot("SP4_after")

#================================================================ SP5: off screen, an arrow at the edge points to it
bg(c, "sp_off.png")
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 380, 192, 504, 240, 8, c[:panel], GOLD)
UI.tri(b, 488, 206, :r, GOLD, 8)
star_mark(t, 392, 202)
P.small(t, 402, 196, 84, 16, "Shiny", GOLD)
P.small(t, 392, 216, 94, 16, "Nearby", c[:txt])
shot("SP5_edge")
bg(c, "sp_sparkle.png"); alert(c, "Shiny Abra!", "Route 24"); shot("SP5_found")
