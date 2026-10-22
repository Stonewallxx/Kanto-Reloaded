# encoding: utf-8
# Mockups: the Overworld Menu's Day Care popup (A on the Day Care readout),
# five designs, drawn over the real Overworld Menu (the test's stand-ins).
# Ditto Lv 31 (left at 28: +3, $400) and Charmander Lv 18 (left at 16: +2,
# $300), compatibility 2 ("They seem to get along"), an Egg waiting: the
# Egg Manager mockup's own example (topic 10, eggs-1).
# KIF Beta: the cost is (levels gained + 1) x $100 (pbDayCareGetCost); the
# compatibility 0-3 (pbDayCareGetCompat); an Egg waiting (pbEggGenerated?).
# Design 1 = the Egg Manager's Day Care panel (its chosen design) as a popup.
# Usage (from this folder): ruby dc_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/overworld_menu_preview.rb")
eval(File.read(TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- A: ")[0], binding, TEST)

DC_HERE = File.expand_path(File.dirname(__FILE__))
DC_GFX = File.join(ARGV[0], "Graphics")
SW = 512
SH = 384
HINT_TOP = SH - Reloaded::Pixel::HINT_H
B_PAD = "p:1"; A_PAD = "p:0"
GREEN_T = Color.new(120, 230, 150)
GOLD_T = Color.new(240, 200, 80)
PINK_T = Color.new(240, 130, 160)
P2 = Reloaded::Pixel
PF = ::KIF::PixelFont unless defined?(PF)

#---------------------------------------------------------------- the Day Care
class GlobalOM; attr_accessor :daycare; end
DITTO = PkPM.new("Ditto", :DITTO, 31, 90, 90, [:NORMAL])
CHAR = PkPM.new("Charmander", :CHARMANDER, 18, 50, 50, [:FIRE])
$PokemonGlobal.daycare = [[DITTO, 28], [CHAR, 16]]
def pbEggGenerated?; true; end
COMPAT = 2
COMPAT_WORDS = ["They prefer to play with others", "They don't seem to like each other", "They seem to get along", "They get along very well"]
MONS = [[DITTO, 28], [CHAR, 16]]
def gained(m, lv); m.level - lv; end
def cost(m, lv); (gained(m, lv) + 1) * 100; end

#---------------------------------------------------------------- the map behind the menu
DC_MAPVP = Viewport.new(0, 0, SW, SH)
DC_MAPVP.z = 0
DC_MAP = Sprite.new(DC_MAPVP)
DC_MAP.bitmap = Bitmap.new(File.join(DC_HERE, "backdrop.png"))

pg = OM.add_page("Breeding")
pg["entries"] = ["day_care", "encounters", "since_shiny", "play_time"]
OM.save_layout
$dc_hints = nil
Reloaded::OverworldMenuScreen.prepend(Module.new { def hint_pairs; $dc_hints || super; end })
Reloaded::Prompts.singleton_class.prepend(Module.new { def style; :xbox; end })

#---------------------------------------------------------------- pieces
$dc_bmps = {}
def dc_bmp(path); $dc_bmps[path] ||= Bitmap.new(path); end
def mon(b, sp, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), dc_bmp(File.join(DC_GFX, "Pokemon/Icons/#{sp}.png")), Rect.new(0, 0, 64, 64))
end
def egg(b, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), dc_bmp(File.join(DC_GFX, "Icons/iconEgg.png")), Rect.new(0, 0, 64, 64))
end
def hearts(b, cx, y, n, c)
  3.times do |i|
    x = cx - 22 + i * 16
    P2.ui.rbox(b, x, y, x + 10, y + 10, 5, i < n ? PINK_T : c[:dark], i < n ? PINK_T : c[:line])
  end
end
def popup(o, c, x, y, w, h, title, dim = true)
  Reloaded::Dialogs.send(:dim, o) if dim
  Reloaded::Dialogs.send(:panel, o, c, x, y, w, h)
  Reloaded::Dialogs.send(:title_bar, o, c, x, y, w, title)
end
def shot(name, hints)
  $dc_hints = hints
  om.refresh
  yield(om.send(:overlay), om.send(:palette))
  dump(name)
end

DESIGNS = []

# 1 Recommended: the Egg Manager's Day Care panel in a popup: the two side
# by side, how well they get along (hearts), each one's levels gained and
# cost, and the Egg waiting
DESIGNS << ["DC1_egg_manager_panel", [[B_PAD, "Close"]], proc { |o, c|
  w = 300; h = 250
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Day Care")
  mon(o, :DITTO, x + w / 2 - 50, y + 70, 56)
  mon(o, :CHARMANDER, x + w / 2 + 50, y + 70, 56)
  P2.text(o, x, y + 100, w, 13, COMPAT_WORDS[COMPAT].upcase, PINK_T, PF::TINY, 2)
  hearts(o, x + w / 2, y + 116, COMPAT, c)
  MONS.each_with_index do |(m, lv), i|
    ry = y + 134 + i * 24
    P2.text(o, x + 14, ry, 120, 20, m.name, c[:txt], PF::TEXT)
    P2.small(o, x + w - 164, ry + 2, 150, 16, "+#{gained(m, lv)} Levels  ·  $#{cost(m, lv)}".sub("  ·  ", " · "), c[:dim], 1)
  end
  o.fill_rect(x + 12, y + 186, w - 24, 1, c[:line])
  egg(o, x + 30, y + 214, 34)
  P2.text(o, x + 52, y + 196, 200, 20, "An Egg Is Waiting", GOLD_T, PF::TEXT)
  P2.small(o, x + 52, y + 216, 230, 16, "Collect it from the Day Care Man.", c[:dim])
}]

# 2: two cards, one each: icon, level now, the level when left, levels
# gained and cost; the hearts between them, the Egg along the bottom
DESIGNS << ["DC2_two_cards", [[B_PAD, "Close"]], proc { |o, c|
  w = 400; h = 236
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Day Care")
  cw = 150
  MONS.each_with_index do |(m, lv), i|
    cx0 = i == 0 ? x + 14 : x + w - 14 - cw
    P2.ui.rbox(o, cx0, y + 44, cx0 + cw, y + 168, 6, c[:panel], c[:line])
    mon(o, m.species, cx0 + cw / 2, y + 76, 56)
    P2.text(o, cx0, y + 102, cw, 20, m.name, c[:txt], PF::TEXT, 2)
    P2.text(o, cx0, y + 122, cw, 12, "LV #{m.level}", GOLD_T, PF::TINY, 2)
    P2.small(o, cx0, y + 136, cw, 16, "Left at Lv #{lv}  +#{gained(m, lv)}".sub("  ", " · "), c[:dim], 2)
    P2.small(o, cx0, y + 150, cw, 16, "$#{cost(m, lv)} to Take Back", c[:dim], 2)
  end
  hearts(o, x + w / 2, y + 96, COMPAT, c)
  P2.text(o, x + w / 2 - 40, y + 112, 80, 24, "GET", PINK_T, PF::TINY, 2)
  P2.text(o, x + w / 2 - 40, y + 124, 80, 24, "ALONG", PINK_T, PF::TINY, 2)
  P2.ui.rbox(o, x + 14, y + 178, x + w - 14, y + h - 12, 6, Color.new(60, 48, 14), GOLD_T)
  egg(o, x + 36, y + 178 + 23, 34)
  P2.text(o, x + 58, y + 190, 200, 20, "An Egg Is Waiting", GOLD_T, PF::TEXT)
}]

# 3: rows like Area Encounters': icon, name, level now, levels gained, cost;
# the Egg as a row, how well they get along as a line under them
DESIGNS << ["DC3_rows", [[B_PAD, "Close"]], proc { |o, c|
  w = 392; rh = 28; h = 40 + 3 * rh + 34
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Day Care")
  MONS.each_with_index do |(m, lv), i|
    ry = y + 42 + i * rh
    mon(o, m.species, x + 24, ry + rh / 2, 30)
    P2.text(o, x + 46, ry + 5, 120, 18, m.name, c[:txt], PF::TEXT)
    P2.text(o, x + 170, ry + 8, 50, 12, "LV #{m.level}", GOLD_T, PF::TINY)
    P2.small(o, x + 222, ry + 6, 60, 16, "+#{gained(m, lv)} Levels", GREEN_T)
    P2.small(o, x + w - 66, ry + 6, 52, 16, "$#{cost(m, lv)}", c[:dim], 1)
  end
  ry = y + 42 + 2 * rh
  egg(o, x + 24, ry + rh / 2, 26)
  P2.text(o, x + 46, ry + 5, 200, 18, "An Egg Is Waiting", GOLD_T, PF::TEXT)
  o.fill_rect(x + 12, y + 42 + 3 * rh + 4, w - 24, 1, c[:line])
  hearts(o, x + 36, y + 42 + 3 * rh + 14, COMPAT, c)
  P2.small(o, x + 66, y + 42 + 3 * rh + 11, w - 80, 16, COMPAT_WORDS[COMPAT] + ".", PINK_T)
}]

# 4: no popup: the area panel drops down the right side into the Day Care,
# the menu and party still in view
DESIGNS << ["DC4_area_panel", [[B_PAD, "Close"]], proc { |o, c|
  o.clear
  x0 = 300; x1 = SW - 6; y0 = 6; y1 = 248
  P2.ui.rbox(o, x0, y0, x1, y1, 7, c[:panel2], c[:selb])
  w = x1 - x0 - 16
  P2.text(o, x0 + 8, y0 + 1, w, 22, "Day Care", c[:txt], PF::ROW)
  o.fill_rect(x0 + 8, y0 + 26, x1 - x0 - 16, 1, c[:line])
  MONS.each_with_index do |(m, lv), i|
    ry = y0 + 32 + i * 46
    mon(o, m.species, x0 + 22, ry + 20, 36)
    P2.text(o, x0 + 44, ry + 2, 110, 18, m.name, c[:txt], PF::TEXT)
    P2.text(o, x1 - 58, ry + 6, 50, 12, "LV #{m.level}", GOLD_T, PF::TINY, 1)
    P2.small(o, x0 + 44, ry + 20, 80, 16, "+#{gained(m, lv)} Levels", GREEN_T)
    P2.small(o, x1 - 58, ry + 20, 50, 16, "$#{cost(m, lv)}", c[:dim], 1)
  end
  hearts(o, x0 + 30, y0 + 130, COMPAT, c)
  P2.small(o, x0 + 60, y0 + 127, w - 52, 16, "Get along", PINK_T)
  o.fill_rect(x0 + 8, y0 + 150, x1 - x0 - 16, 1, c[:line])
  egg(o, x0 + 22, y0 + 176, 32)
  P2.text(o, x0 + 44, y0 + 160, 150, 18, "An Egg Is", GOLD_T, PF::TEXT)
  P2.text(o, x0 + 44, y0 + 178, 150, 18, "Waiting", GOLD_T, PF::TEXT)
  P2.small(o, x0 + 8, y0 + 206, w, 16, "Ask the Day Care Man.", c[:dim])
}]

# 5: the notice it is now, with an icon by each line
DESIGNS << ["DC5_notice_icons", [[A_PAD, "OK"]], proc { |o, c|
  w = 320; h = 150
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Day Care")
  MONS.each_with_index do |(m, lv), i|
    ry = y + 42 + i * 28
    mon(o, m.species, x + 24, ry + 12, 28)
    P2.small(o, x + 44, ry + 4, w - 56, 16, "#{m.name}: Lv #{m.level}, +#{gained(m, lv)} gained.", c[:txt])
  end
  egg(o, x + 24, y + 42 + 2 * 28 + 12, 26)
  P2.small(o, x + 44, y + 42 + 2 * 28 + 4, w - 56, 16, "An egg is waiting.", c[:txt])
}]

queue = [at { i = OM.pages.length - 1; OM.page_index = i; om.instance_variable_set(:@page, i); om.instance_variable_set(:@sel, 0); om.refresh }]
DESIGNS.each { |name, hints, painter| queue << at { shot(name, hints, &painter) } }
queue << at { $dc_hints = nil; om.send(:overlay).clear; om.refresh }
queue << I::BACK
on_map("Day Care designs", queue)
puts "designs: #{DESIGNS.map(&:first).join(', ')}"
