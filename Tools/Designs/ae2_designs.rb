# encoding: utf-8
# Mockups: Area Encounters with bigger sprites (his ask, 2026-10-21: "These are
# hard to see"), five designs over the real Overworld Menu on Route 24's real
# tables, with Big Pokémon Icons on (battle sprites, as he plays). Every design
# trims each sprite to the Pokémon itself (ae2_assets.py) and fits it to its
# box; the layouts differ in how big the box is.
# Design 1 = his pick (Wild Link's List) with taller rows and bigger sprites.
# Usage (from this folder): ruby ae2_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/overworld_menu_preview.rb")
eval(File.read(TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- A: ")[0], binding, TEST)

AE_HERE = File.expand_path(File.dirname(__FILE__))
SW = 512
SH = 384
HINT_TOP = SH - Reloaded::Pixel::HINT_H
B_PAD = "p:1"; LB_PAD = "p:9"; RB_PAD = "p:10"
GREEN_T = Color.new(120, 230, 150)
P2 = Reloaded::Pixel
PF = ::KIF::PixelFont unless defined?(PF)

#---------------------------------------------------------------- Route 24
R24 = {
  :Land => [[20, :ABRA, 8, 12], [15, :CATERPIE, 7, 7], [15, :PIDGEY, 11, 13], [15, :WEEDLE, 7, 7],
            [13, :ODDISH, 12, 14], [12, :BELLSPROUT, 12, 14], [5, :KAKUNA, 8, 8], [5, :METAPOD, 8, 8]],
  :Water => [[50, :PSYDUCK, 20, 40], [50, :SLOWPOKE, 20, 40]],
  :OldRod => [[80, :MAGIKARP, 5, 5], [20, :POLIWAG, 5, 5]],
  :GoodRod => [[60, :POLIWAG, 5, 15], [20, :GOLDEEN, 5, 15], [20, :MAGIKARP, 5, 15]],
  :SuperRod => [[45, :POLIWAG, 15, 25], [30, :POLIWHIRL, 20, 30], [15, :GYARADOS, 15, 25], [5, :PSYDUCK, 15, 35], [5, :SLOWPOKE, 15, 35]]
}
$PokemonEncounters.instance_variable_set(:@encounter_tables, R24)
CAUGHT = [:ABRA, :CATERPIE, :PIDGEY, :ODDISH, :MAGIKARP, :PSYDUCK]
SEEN = CAUGHT + [:WEEDLE, :BELLSPROUT, :KAKUNA, :POLIWAG, :GOLDEEN, :SLOWPOKE]
class DexPM; def owned?(s); CAUGHT.include?(s); end; def seen?(s); SEEN.include?(s); end; end
def pbGetMapNameFromId(id); "Route 24"; end
def state(sp); CAUGHT.include?(sp) ? :caught : (SEEN.include?(sp) ? :seen : :unseen); end
def name_of(sp); state(sp) == :unseen ? "???" : { :BELLSPROUT => "Bellsprout", :CATERPIE => "Caterpie" }.fetch(sp, sp.to_s.capitalize); end
def name_col(c, sp); state(sp) == :unseen ? c[:dim] : c[:txt]; end
def lv_words(lo, hi); lo == hi ? "Lv #{lo}" : "Lv #{lo}-#{hi}"; end
LAND = R24[:Land]
def counts(list); [list.count { |s| state(s) != :unseen }, list.count { |s| state(s) == :caught }, list.length]; end

AE_MAPVP = Viewport.new(0, 0, SW, SH)
AE_MAPVP.z = 0
AE_MAP = Sprite.new(AE_MAPVP)
AE_MAP.bitmap = Bitmap.new(File.join(AE_HERE, "wx", "route24_clear.png"))
pg = OM.add_page("Exploring")
pg["entries"] = ["area_encounters", "encounters", "since_shiny", "itemfinder", "play_time"]
OM.save_layout
$ae_hints = nil
Reloaded::OverworldMenuScreen.prepend(Module.new { def hint_pairs; $ae_hints || super; end })
Reloaded::Prompts.singleton_class.prepend(Module.new { def style; :xbox; end })

#---------------------------------------------------------------- pieces
$ae_bmps = {}
def ae_bmp(path); $ae_bmps[path] ||= Bitmap.new(path); end
# the trimmed sprite fitted to a box x box square centred at cx, cy
def art(b, sp, cx, cy, box)
  path = File.join(AE_HERE, "ae2", state(sp) == :unseen ? "#{sp}_sil.png" : "#{sp}.png")
  bm = ae_bmp(path)
  k = box.to_f / [bm.width, bm.height].max
  w = (bm.width * k).round; h = (bm.height * k).round
  b.stretch_blt(Rect.new(cx - w / 2, cy - h / 2, w, h), bm, Rect.new(0, 0, bm.width, bm.height))
end
def method_tabs(b, c, x, y, names, on = 0)
  names.each_with_index do |n, i|
    w = P2.width(PF::TINY, n) + 14
    P2.ui.rbox(b, x, y, x + w, y + 17, 4, Reloaded::Palette.mix(c[:selb], c[:panel2], 0.7), c[:selb]) if i == on
    P2.text(b, x, y, w, 18, n, i == on ? c[:txt] : c[:dim], PF::TINY, 2)
    x += w + 4
  end
  x
end
def seen_caught(o, c, x1, y, list)
  s, k, n = counts(list)
  P2.small(o, x1 - 80, y, 80, 16, "Caught #{k}/#{n}", c[:dim], 1)
  P2.small(o, x1 - 170, y, 80, 16, "Seen #{s}/#{n}", c[:dim], 1)
end
def popup(o, c, x, y, w, h, title)
  Reloaded::Dialogs.send(:dim, o)
  Reloaded::Dialogs.send(:panel, o, c, x, y, w, h)
  Reloaded::Dialogs.send(:title_bar, o, c, x, y, w, title)
end
def arrows(o, c, x, y0, y1, up, down)
  P2.ui.tri(o, x, y0, :u, up ? c[:txt] : c[:dim], 3)
  P2.ui.tri(o, x, y1, :d, down ? c[:txt] : c[:dim], 3)
end
def sel_box(o, c, x0, y0, x1, y1)
  P2.ui.rbox(o, x0, y0, x1, y1, 6, Reloaded::Palette.mix(c[:selb], c[:panel2], 0.7), c[:selb])
end
def shot(name, hints)
  $ae_hints = hints
  om.refresh
  yield(om.send(:overlay), om.send(:palette))
  dump(name)
end

DESIGNS = []

# 1 Recommended: his pick, Wild Link's List, with rows 36 px tall and each
# sprite trimmed and fitted to 34 px (6 rows show; the rest scroll)
DESIGNS << ["AE2_1_bigger_rows", [[:lr, "Method"], [:ud, "Scroll"], [B_PAD, "Close"]], proc { |o, c|
  w = 392; rh = 36; rows = 6; h = 60 + rows * rh + 8
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Area Encounters")
  method_tabs(o, c, x + 10, y + 40, ["GRASS", "SURFING", "FISHING"])
  seen_caught(o, c, x + w - 10, y + 41, LAND.map { |r| r[1] })
  rw = w - 24
  LAND.first(rows).each_with_index do |(rate, sp, lo, hi), i|
    ry = y + 62 + i * rh
    art(o, sp, x + 28, ry + rh / 2, 34)
    P2.poke_ball(o, x + 50, ry + rh / 2 - 6, 11) if state(sp) == :caught
    P2.text(o, x + 66, ry + (rh - 18) / 2, 120, 18, name_of(sp), name_col(c, sp), PF::TEXT)
    P2.small(o, x + 6 + rw - 112, ry + (rh - 16) / 2, 70, 16, lv_words(lo, hi), c[:dim])
    P2.small(o, x + 6 + rw - 46, ry + (rh - 16) / 2, 38, 16, "#{rate}%", c[:dim], 1)
  end
  arrows(o, c, x + w - 14, y + 66, y + h - 14, false, true)
}]

# 2: two columns of cards, a 42 px sprite each, name with levels and rate
# under it; all eight show
DESIGNS << ["AE2_2_two_columns", [[:lr, "Method"], [B_PAD, "Close"]], proc { |o, c|
  w = 468; ch = 50; h = 62 + 4 * (ch + 4) + 6
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Area Encounters")
  method_tabs(o, c, x + 10, y + 40, ["GRASS", "SURFING", "FISHING"])
  seen_caught(o, c, x + w - 10, y + 41, LAND.map { |r| r[1] })
  cw = (w - 24) / 2
  LAND.each_with_index do |(rate, sp, lo, hi), i|
    cx0 = x + 10 + (i % 2) * (cw + 4); cy0 = y + 62 + (i / 2) * (ch + 4)
    P2.ui.rbox(o, cx0, cy0, cx0 + cw, cy0 + ch, 6, c[:panel], c[:line])
    art(o, sp, cx0 + 28, cy0 + ch / 2, 42)
    P2.poke_ball(o, cx0 + 4, cy0 + 4, 11) if state(sp) == :caught
    P2.text(o, cx0 + 56, cy0 + 6, cw - 62, 18, name_of(sp), name_col(c, sp), PF::TEXT)
    P2.small(o, cx0 + 56, cy0 + 27, 90, 16, lv_words(lo, hi), c[:dim])
    P2.small(o, cx0 + cw - 50, cy0 + 27, 42, 16, "#{rate}%", c[:dim], 1)
  end
}]

# 3: the list on the left (small rows, all eight), the chosen one big on the
# right with its levels, rate and Caught, like Wild Link's details
DESIGNS << ["AE2_3_list_and_big_sprite", [[:ud, "Choose"], [:lr, "Method"], [B_PAD, "Close"]], proc { |o, c|
  w = 468; rh = 26; h = 62 + 8 * rh + 8
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Area Encounters")
  method_tabs(o, c, x + 10, y + 40, ["GRASS", "SURFING", "FISHING"])
  seen_caught(o, c, x + w - 10, y + 41, LAND.map { |r| r[1] })
  lw = 250
  LAND.each_with_index do |(rate, sp, lo, hi), i|
    ry = y + 62 + i * rh
    sel_box(o, c, x + 8, ry, x + lw, ry + rh - 1) if i == 0
    art(o, sp, x + 24, ry + rh / 2, 22)
    P2.poke_ball(o, x + 40, ry + rh / 2 - 6, 11) if state(sp) == :caught
    P2.text(o, x + 56, ry + 4, 130, 18, name_of(sp), name_col(c, sp), PF::TEXT)
    P2.small(o, x + lw - 46, ry + 5, 38, 16, "#{rate}%", c[:dim], 1)
  end
  px = x + lw + 8; pw = x + w - 10 - px
  P2.ui.rbox(o, px, y + 62, px + pw, y + h - 10, 6, c[:panel], c[:line])
  art(o, :ABRA, px + pw / 2, y + 120, 88)
  P2.text(o, px, y + 170, pw, 24, "Abra", c[:txt], PF::ROW, 2)
  P2.small(o, px, y + 194, pw, 16, "Caught", GREEN_T, 2)
  P2.small(o, px + 12, y + 220, 80, 16, "Levels", c[:dim]); P2.small(o, px + pw - 92, y + 220, 80, 16, "8-12", c[:txt], 1)
  P2.small(o, px + 12, y + 240, 80, 16, "Appears", c[:dim]); P2.small(o, px + pw - 92, y + 240, 80, 16, "20%", c[:txt], 1)
}]

# 4: a grid of tiles, a 56 px sprite each, the rate under it; the chosen
# one's name, levels and Caught along the bottom
DESIGNS << ["AE2_4_icon_grid", [[:ud, ""], [:lr, "Choose"], [LB_PAD, ""], [RB_PAD, "Method"], [B_PAD, "Close"]], proc { |o, c|
  w = 376; tw = 86; th = 78; h = 62 + 2 * (th + 6) + 44
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Area Encounters")
  method_tabs(o, c, x + 10, y + 40, ["GRASS", "SURFING", "FISHING"])
  seen_caught(o, c, x + w - 10, y + 41, LAND.map { |r| r[1] })
  LAND.each_with_index do |(rate, sp, lo, hi), i|
    tx = x + 10 + (i % 4) * (tw + 4); ty = y + 62 + (i / 4) * (th + 6)
    i == 0 ? sel_box(o, c, tx, ty, tx + tw, ty + th) : P2.ui.rbox(o, tx, ty, tx + tw, ty + th, 6, c[:panel], c[:line])
    art(o, sp, tx + tw / 2, ty + 32, 52)
    P2.poke_ball(o, tx + 5, ty + 5, 11) if state(sp) == :caught
    P2.small(o, tx, ty + th - 19, tw, 16, "#{rate}%", c[:dim], 2)
  end
  by = y + 62 + 2 * (th + 6)
  o.fill_rect(x + 10, by, w - 20, 1, c[:line])
  P2.text(o, x + 12, by + 8, 120, 24, "Abra", c[:txt], PF::ROW)
  P2.small(o, x + 124, by + 12, 70, 16, "Lv 8-12", c[:dim])
  P2.small(o, x + 204, by + 12, 40, 16, "20%", c[:dim])
  P2.small(o, x + w - 92, by + 12, 80, 16, "Caught", GREEN_T, 1)
}]

# 5: a row of big cards across the popup (a 64 px sprite each), Left/Right
# along it, LB/RB for the method; name, levels and rate on each card
DESIGNS << ["AE2_5_cards_across", [[:lr, "Choose"], [LB_PAD, ""], [RB_PAD, "Method"], [B_PAD, "Close"]], proc { |o, c|
  w = 496; cw = 92; ch = 132; h = 62 + ch + 14
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Area Encounters")
  method_tabs(o, c, x + 10, y + 40, ["GRASS", "SURFING", "FISHING"])
  seen_caught(o, c, x + w - 10, y + 41, LAND.map { |r| r[1] })
  LAND.first(5).each_with_index do |(rate, sp, lo, hi), i|
    cx0 = x + 10 + i * (cw + 4); cy0 = y + 64
    i == 0 ? sel_box(o, c, cx0, cy0, cx0 + cw, cy0 + ch) : P2.ui.rbox(o, cx0, cy0, cx0 + cw, cy0 + ch, 6, c[:panel], c[:line])
    art(o, sp, cx0 + cw / 2, cy0 + 42, 64)
    P2.poke_ball(o, cx0 + 5, cy0 + 5, 11) if state(sp) == :caught
    P2.text(o, cx0, cy0 + 80, cw, 18, name_of(sp), name_col(c, sp), PF::TEXT, 2)
    P2.small(o, cx0, cy0 + 98, cw, 16, lv_words(lo, hi), c[:dim], 2)
    P2.small(o, cx0, cy0 + 114, cw, 16, "#{rate}%", c[:dim], 2)
  end
  P2.ui.tri(o, x + w - 8, y + 64 + ch / 2 - 3, :r, c[:txt], 3)
}]

queue = [at { i = OM.pages.length - 1; OM.page_index = i; om.instance_variable_set(:@page, i); om.instance_variable_set(:@sel, 0); om.refresh }]
DESIGNS.each { |name, hints, painter| queue << at { shot(name, hints, &painter) } }
queue << at { $ae_hints = nil; om.send(:overlay).clear; om.refresh }
queue << I::BACK
on_map("Area Encounters, bigger sprites", queue)
puts "designs: #{DESIGNS.map(&:first).join(', ')}"
