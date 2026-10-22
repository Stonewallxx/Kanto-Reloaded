# encoding: utf-8
# Mockups: the Overworld Menu's Area Encounters, five designs, drawn over the
# real Overworld Menu (the test's stand-ins, Tools/Tests/overworld_menu_preview.rb)
# on Route 24 with its real tables (KIF Beta's Data/encounters.dat, map 8):
# Grass 8, Surfing 2, Old/Good/Super Rod 7 species. This save has caught 6 of
# the 15 and seen 12.
# Design 1 = Wild Link's list (topic 23, its chosen wl-1) in a popup: the same
# method tabs and rows, so the quick look and the DexNav read as one.
# Usage (from this folder): ruby ae_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/overworld_menu_preview.rb")
eval(File.read(TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- A: ")[0], binding, TEST)

AE_HERE = File.expand_path(File.dirname(__FILE__))
AE_GFX = File.join(ARGV[0], "Graphics")
SW = 512
SH = 384
HINT_TOP = SH - Reloaded::Pixel::HINT_H
A_PAD = "p:0"; B_PAD = "p:1"; LB_PAD = "p:9"; RB_PAD = "p:10"
GREEN_T = Color.new(120, 230, 150)

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
NAMES = { :MAGIKARP => "Magikarp", :POLIWAG => "Poliwag", :GOLDEEN => "Goldeen", :PSYDUCK => "Psyduck", :SLOWPOKE => "Slowpoke",
          :BELLSPROUT => "Bellsprout", :CATERPIE => "Caterpie" }
def sp_name(sp); NAMES[sp] || sp.to_s.capitalize; end
def state(sp); CAUGHT.include?(sp) ? :caught : (SEEN.include?(sp) ? :seen : :unseen); end
def lv_words(lo, hi); lo == hi ? "Lv #{lo}" : "Lv #{lo}-#{hi}"; end
# the methods as the popup groups them; fishing by rod, or merged
FISH = [[:OldRod, "Old Rod"], [:GoodRod, "Good Rod"], [:SuperRod, "Super Rod"]]
def fish_merged
  seen = []
  FISH.each { |t, _| R24[t].each { |s| seen << s[1] unless seen.include?(s[1]) } }
  seen
end
def counts(list); [list.count { |s| state(s) != :unseen }, list.count { |s| state(s) == :caught }, list.length]; end

#---------------------------------------------------------------- the map behind the menu
AE_MAPVP = Viewport.new(0, 0, SW, SH)
AE_MAPVP.z = 0
AE_MAP = Sprite.new(AE_MAPVP)
AE_MAP.bitmap = Bitmap.new(File.join(AE_HERE, "wx", "route24_clear.png"))

# a page of the player's with Area Encounters on it, and controller hints
pg = OM.add_page("Exploring")
pg["entries"] = ["area_encounters", "encounters", "since_shiny", "itemfinder", "play_time"]
OM.save_layout
$ae_hints = nil
Reloaded::OverworldMenuScreen.prepend(Module.new { def hint_pairs; $ae_hints || super; end })
Reloaded::Prompts.singleton_class.prepend(Module.new { def style; :xbox; end })

#---------------------------------------------------------------- pieces
P2 = Reloaded::Pixel
PF = ::KIF::PixelFont unless defined?(PF)
UIK = KIF::PixelUI
$ae_bmps = {}
def ae_bmp(path); $ae_bmps[path] ||= Bitmap.new(path); end
def mon(b, sp, cx, cy, size)
  path = state(sp) == :unseen ? File.join(AE_HERE, "ae", "#{sp}_sil.png") : File.join(AE_GFX, "Pokemon/Icons/#{sp}.png")
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), ae_bmp(path), Rect.new(0, 0, 64, 64))
end
def name_of(sp); state(sp) == :unseen ? "???" : sp_name(sp); end
def name_col(c, sp); state(sp) == :unseen ? c[:dim] : c[:txt]; end
# the Overworld Menu's page tabs, as method tabs
def method_tabs(b, c, x, y, names, on = 0)
  names.each_with_index do |n, i|
    w = P2.width(PF::TINY, n) + 14
    P2.ui.rbox(b, x, y, x + w, y + 17, 4, Reloaded::Palette.mix(c[:selb], c[:panel2], 0.7), c[:selb]) if i == on
    P2.text(b, x, y, w, 18, n, i == on ? c[:txt] : c[:dim], PF::TINY, 2)
    x += w + 4
  end
  x
end
def popup(o, c, x, y, w, h, title, dim = true)
  Reloaded::Dialogs.send(:dim, o) if dim
  Reloaded::Dialogs.send(:panel, o, c, x, y, w, h)
  Reloaded::Dialogs.send(:title_bar, o, c, x, y, w, title)
end
def arrows(o, c, x, y0, y1, up, down)
  P2.ui.tri(o, x, y0, :u, up ? c[:txt] : c[:dim], 3)
  P2.ui.tri(o, x, y1, :d, down ? c[:txt] : c[:dim], 3)
end
# one Wild Link-style row: icon, caught ball, name, levels, rate
def enc_row(o, c, x, y, w, slot, h = 26, icon = 30, lv = true)
  rate, sp, lo, hi = slot
  mon(o, sp, x + 18, y + h / 2, icon)
  P2.poke_ball(o, x + 36, y + h / 2 - 6, 11) if state(sp) == :caught
  P2.text(o, x + 52, y + (h - 18) / 2, 110, 18, name_of(sp), name_col(c, sp), PF::TEXT)
  P2.small(o, x + w - 112, y + (h - 16) / 2, 70, 16, lv_words(lo, hi), c[:dim]) if lv
  P2.small(o, x + w - 46, y + (h - 16) / 2, 38, 16, "#{rate}%", c[:dim], 1)
end
def shot(name, hints)
  $ae_hints = hints
  om.refresh
  yield(om.send(:overlay), om.send(:palette))
  dump(name)
end

#---------------------------------------------------------------- the designs
DESIGNS = []

# 1 Recommended: Wild Link's list in a popup: method tabs, Seen and Caught for
# the method, rows with icon, caught ball, levels and rate
DESIGNS << ["AE1_wild_link_list", [[:lr, "Method"], [B_PAD, "Close"]], proc { |o, c|
  w = 392; h = 60 + 8 * 26 + 8
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Area Encounters")
  method_tabs(o, c, x + 10, y + 40, ["GRASS", "SURFING", "FISHING"])
  s, k, n = counts(R24[:Land].map { |r| r[1] })
  P2.small(o, x + w - 170, y + 41, 160, 16, "Seen #{s}/#{n}   Caught #{k}/#{n}", c[:dim], 1)
  R24[:Land].each_with_index { |slot, i| enc_row(o, c, x + 6, y + 62 + i * 26, w - 12, slot) }
}]
# 1b: its Fishing tab: each rod under its own heading, scrolled
DESIGNS << ["AE1b_wild_link_list_fishing", [[:lr, "Method"], [:ud, "Scroll"], [B_PAD, "Close"]], proc { |o, c|
  w = 392; h = 60 + 8 * 26 + 8
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Area Encounters")
  method_tabs(o, c, x + 10, y + 40, ["GRASS", "SURFING", "FISHING"], 2)
  s, k, n = counts(fish_merged)
  P2.small(o, x + w - 170, y + 41, 160, 16, "Seen #{s}/#{n}   Caught #{k}/#{n}", c[:dim], 1)
  lines = []
  FISH.each { |t, words| lines << [:head, words]; R24[t].each { |slot| lines << [:row, slot] } }
  lines.first(8).each_with_index do |(kind, v), i|
    ly = y + 62 + i * 26
    if kind == :head
      P2.heading(o, x + 12, x + w - 24, ly + 9, v.upcase, c[:head], c[:line])
    else
      enc_row(o, c, x + 6, ly, w - 24, v)
    end
  end
  arrows(o, c, x + w - 14, y + 66, y + h - 14, false, true)
}]

# 2: one list like the Pokedex's area page: every method under its heading,
# smaller rows, scrolls
DESIGNS << ["AE2_one_list", [[:ud, "Scroll"], [B_PAD, "Close"]], proc { |o, c|
  w = 310; rows = 12; rh = 22; h = 40 + rows * rh + 8
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Area Encounters")
  lines = [[:head, "GRASS"]] + R24[:Land].map { |s| [:row, s] } + [[:head, "SURFING"]] + R24[:Water].map { |s| [:row, s] } +
          [[:head, "OLD ROD"]] + R24[:OldRod].map { |s| [:row, s] }
  lines.first(rows).each_with_index do |(kind, v), i|
    ly = y + 40 + i * rh
    if kind == :head
      P2.heading(o, x + 12, x + w - 24, ly + 7, v, c[:head], c[:line])
    else
      enc_row(o, c, x + 6, ly, w - 24, v, rh, 24)
    end
  end
  arrows(o, c, x + w - 14, y + 44, y + h - 14, false, true)
}]

# 3: a grid of icons per method (silhouettes for the unseen), the chosen one's
# details along the bottom
DESIGNS << ["AE3_icon_grid", [[:ud, ""], [:lr, "Choose"], [LB_PAD, ""], [RB_PAD, "Method"], [B_PAD, "Close"]], proc { |o, c|
  w = 376; tw = 86; th = 70; h = 60 + 2 * (th + 6) + 46
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Area Encounters")
  method_tabs(o, c, x + 10, y + 40, ["GRASS", "SURFING", "FISHING"])
  s, k, n = counts(R24[:Land].map { |r| r[1] })
  P2.small(o, x + w - 170, y + 41, 160, 16, "Seen #{s}/#{n}   Caught #{k}/#{n}", c[:dim], 1)
  R24[:Land].each_with_index do |(rate, sp, lo, hi), i|
    tx = x + 10 + (i % 4) * (tw + 4); ty = y + 64 + (i / 4) * (th + 6)
    if i == 0
      P2.ui.rbox(o, tx, ty, tx + tw, ty + th, 6, Reloaded::Palette.mix(c[:selb], c[:panel2], 0.7), c[:selb])
    else
      P2.ui.rbox(o, tx, ty, tx + tw, ty + th, 6, c[:panel], c[:line])
    end
    mon(o, sp, tx + tw / 2, ty + 30, 52)
    P2.poke_ball(o, tx + 5, ty + 5, 11) if state(sp) == :caught
    P2.small(o, tx, ty + th - 18, tw, 16, "#{rate}%", c[:dim], 2)
  end
  by = y + 64 + 2 * (th + 6) + 2
  o.fill_rect(x + 10, by, w - 20, 1, c[:line])
  P2.text(o, x + 12, by + 6, 120, 24, "Abra", c[:txt], PF::ROW)
  P2.small(o, x + 124, by + 10, 70, 16, "Lv 8-12", c[:dim])
  P2.small(o, x + 204, by + 10, 40, 16, "20%", c[:dim])
  P2.small(o, x + w - 92, by + 10, 80, 16, "Caught", GREEN_T, 1)
}]

# 4: no popup: the area panel drops down the right side into the list, the
# menu and party still in view
DESIGNS << ["AE4_area_panel", [[:lr, "Method"], [B_PAD, "Close"]], proc { |o, c|
  o.clear
  x0 = 300; x1 = SW - 6; y0 = 6; y1 = 300
  P2.ui.rbox(o, x0, y0, x1, y1, 7, c[:panel2], c[:selb])
  w = x1 - x0 - 16
  P2.text(o, x0 + 8, y0 + 1, w, 22, "Route 24", c[:txt], PF::ROW)
  P2.text(o, x0 + 8, y0 + 22, w, 16, "Clear, Day", Color.new(130, 190, 250), PF::TEXT)
  P2.text(o, x0 + 8, y0 + 38, w, 16, "Here: 6 of 15 Caught", c[:txt], PF::TEXT)
  o.fill_rect(x0 + 8, y0 + 58, x1 - x0 - 16, 1, c[:line])
  method_tabs(o, c, x0 + 8, y0 + 64, ["GRASS", "SURF", "FISHING"])
  R24[:Land].each_with_index do |(rate, sp, lo, hi), i|
    ry = y0 + 86 + i * 25
    mon(o, sp, x0 + 18, ry + 12, 26)
    P2.poke_ball(o, x0 + 34, ry + 6, 11) if state(sp) == :caught
    P2.text(o, x0 + 50, ry + 3, 100, 18, name_of(sp), name_col(c, sp), PF::TEXT)
    P2.small(o, x1 - 48, ry + 4, 40, 16, "#{rate}%", c[:dim], 1)
  end
}]

# 5: everything at once: a column per method, Pokedex marks only (caught,
# seen by name, ??? for the rest), no tabs and no scrolling
DESIGNS << ["AE5_columns", [[B_PAD, "Close"]], proc { |o, c|
  w = 500; rh = 26; h = 40 + 22 + 8 * rh + 10
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Area Encounters")
  cols = [["GRASS", R24[:Land].map { |r| r[1] }], ["SURFING", R24[:Water].map { |r| r[1] }], ["FISHING", fish_merged]]
  cw = (w - 20) / 3
  cols.each_with_index do |(head, list), ci|
    cx = x + 10 + ci * cw
    P2.heading(o, cx + 2, cx + cw - 8, y + 48, head, c[:head], c[:line])
    list.each_with_index do |sp, i|
      ry = y + 62 + i * rh
      mon(o, sp, cx + 16, ry + rh / 2, 30)
      P2.poke_ball(o, cx + 34, ry + rh / 2 - 6, 11) if state(sp) == :caught
      P2.text(o, cx + 50, ry + 4, cw - 54, 18, name_of(sp), name_col(c, sp), PF::TEXT)
    end
  end
}]

queue = [at { i = OM.pages.length - 1; OM.page_index = i; om.instance_variable_set(:@page, i); om.instance_variable_set(:@sel, 0); om.refresh }]
DESIGNS.each { |name, hints, painter| queue << at { shot(name, hints, &painter) } }
queue << at { $ae_hints = nil; om.send(:overlay).clear; om.refresh }
queue << I::BACK
on_map("Area Encounters designs", queue)
puts "designs: #{DESIGNS.map(&:first).join(', ')}"
