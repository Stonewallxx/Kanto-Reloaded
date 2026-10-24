# encoding: utf-8
# Mockups: the Bag's small popups, three designs each, for his picks (his
# rule, 2026-10-23: "Always design", unless it's a basic action list):
#   add       the Custom List editor's Add Item (Y): 1 the picker as built,
#             2 a list to search, 3 the editor's own list in adding mode
#   defaults  the editor's Defaults (R): 1 the question as built, 2 the
#             question with what changes, 3 press R again
#   export    Kanto Reloaded > Bag > Export Lists, done: 1 the notice as
#             built, 2 a toast, 3 the notice with Open Folder
#   import    Kanto Reloaded > Bag > Import Lists: 1 the question as built,
#             2 the question with what's in the file, 3 choose what comes in
# Drawn by the real editor and the real improved KIF Settings on the Bag
# preview's stand-ins (Tools/Tests/bag_preview.rb), each design painted on
# the screen's popup layer. Dark and Light.
# Usage (from the mod folder): ruby Tools/Designs/bag/small_popups.rb "<KIF Beta>" <work dir with metrics.json>
#                              python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/bag_preview.rb")
eval(File.read(TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- helpers")[0], binding, TEST)
DL = Reloaded::Dialogs
PF = ::KIF::PixelFont
PP = Reloaded::PartyPaint
P = Reloaded::Pixel
MODE = Reloaded::Palette::MODE
SW = 512
SH = 384
# more of the game's Medicine, so Add Item has a list
[[:ANTIDOTE, 20, "Antidote"], [:BURNHEAL, 21, "Burn Heal"], [:PARALYZEHEAL, 22, "Paralyze Heal"], [:AWAKENING, 24, "Awakening"],
 [:MAXPOTION, 25, "Max Potion"], [:FULLRESTORE, 26, "Full Restore"], [:REVIVE, 28, "Revive"], [:MAXREVIVE, 29, "Max Revive"],
 [:ETHER, 40, "Ether"], [:ELIXIR, 42, "Elixir"]].each { |id, n, name| GameData::Item.add(id, n, name, 2, "", 1, 1) }
$PokemonBag.pbStoreItem(:REVIVE, 2)
$PokemonBag.pbStoreItem(:BURNHEAL, 1)
B.set_list(2, ["#Candy", "RARECANDY", "#Healing", "POTION", "SUPERPOTION", "HYPERPOTION", "ICEHEAL"])
$pad_name = "Xbox Series X Controller"
$le = nil
Reloaded::BagListScreen.prepend(Module.new { def main; $le = self; super; end })
MODES = [[0, "dark"], [2, "light"]].freeze

def le_to(id)
  at {
    t = $le.rows.index { |r| r[1] == id }
    n = t - $le.sel
    Input.queue.unshift(*[n > 0 ? I::DOWN : I::UP] * n.abs) if n != 0
  }
end

# A design painted on the editor's popup layer, in each theme
def editor_paint(name, hints, &paint)
  out = []
  MODES.each do |mode, word|
    out << at {
      S.set(MODE, mode)
      $le.instance_variable_set(:@popup_hints, hints)
      $le.refresh
      paint.call($le.overlay, $le.palette, $le)
    }
    out << dmp("#{name}_#{word}")
    out << at { $le.overlay.clear; $le.instance_variable_set(:@popup_hints, nil); S.set(MODE, 0); $le.refresh }
  end
  out
end

# The real popup (opened by keys), in each theme
def editor_real(name, open, close)
  out = []
  MODES.each do |mode, word|
    out << at { S.set(MODE, mode); $le.refresh }
    out.concat(open)
    out << dmp("#{name}_#{word}")
    out.concat(close)
    out << at { S.set(MODE, 0); $le.refresh }
  end
  out
end

def item_name(id); GameData::Item.get(id).name; end
def qty(id); $PokemonBag.pbQuantity(id); end
def candidates
  have = B.custom_list(2)
  ids = GameData::Item::DATA.values.select { |it| it.pocket == 2 && !have.include?(it.id.to_s) }.map(&:id)
  ids.sort_by { |id| [qty(id) > 0 ? 0 : 1, item_name(id).downcase] }
end
def icon(b, id, x, y, size)
  bm = Bitmap.new(pbResolveBitmap(GameData::Item.icon_filename(id)) || GameData::Item.icon_filename(id)) rescue nil
  b.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, bm.width, bm.height)) if bm
end
def mix(a, b, t); Reloaded::Palette.mix(a, b, t); end
def btn(sym); Reloaded::Prompts.input(sym) || Reloaded::Prompts.name(sym); end

#================================================================ add: the editor's Add Item (Y)
def add_d2(b, c, le)
  # a list to search: type straight in (the list follows), names in the
  # pocket's colour when you have some
  DL.send(:dim, b)
  w = 330
  x = (SW - w) / 2
  y = 14
  h = SH - P::HINT_H - 22
  DL.frame(b, c, x, y, w, h, _INTL("Add to Medicine"))
  Reloaded::TextEntry.draw_field(b, b, c, Reloaded::TextEntry::State.new(_INTL("Type to Search"), "", 20), x + 12, y + 42, w - 24, 23)
  rh = 24
  candidates.first(9).each_with_index do |id, i|
    ry = y + 72 + i * rh
    DL.send(:cursor_row, b, c, x + 8, ry, x + w - 8, ry + rh - 2) if i == 0
    icon(b, id, x + 14, ry - 1, 24)
    have = qty(id) > 0
    col = have ? le.send(:item_ink, c, id) : mix(c[:dim], c[:panel2], 0.25)
    P.text(b, x + 44, ry, 200, rh - 2, item_name(id), col, PF::TEXT)
    P.text(b, x + w - 60, ry, 40, rh - 2, "x#{qty(id)}", c[:dim], PF::TEXT, 1) if have
  end
  P.small(b, x, y + h - 22, w, 16, _INTL("It goes after Ice Heal."), c[:dim], 2)
end

def add_d3(_b, c, le)
  # the editor's own list, adding: the pocket's items not on it, the
  # details say where it goes (drawn on the editor's own layers)
  base = le.instance_variable_get(:@sprite).bitmap
  top = le.instance_variable_get(:@top_sprite).bitmap
  base.clear
  top.clear
  PP.paint_background(base, c)
  PP.paint_title(top, c, _INTL("Add to Medicine"))
  le.send(:draw_pockets, base, top, c)
  PP.chamfer_grad(base, 6, 66, SW - 6, 245, 10, c[:panel2], mix(c[:panel2], c[:dark], 0.3), c[:line])
  y = 68
  candidates.first(7).each do |id|
    le.send(:item_row, top, c, 14, y, SW - 38, id)
    y += 25
  end
  le.instance_variable_set(:@cursor_rect, [10, 68, SW - 30, 24])
  le.send(:place_cursor)
  id = candidates.first
  le.send(:plate, base, c, PP.rgb(le.send(:item_rgb, id)), 6, 249, SW - 6, SH - P::HINT_H - 5, 12)
  P.text(top, 18, 254, 360, 22, item_name(id), c[:strong], PF::ROW)
  le.send(:pill, top, c, 18, 281, _INTL("IN THE BAG"), :green)
  P.small_wrap(top, _INTL("A adds it to Medicine's list after Ice Heal, the last on the list."), 360).each_with_index do |ln, i|
    P.small(top, 18, 301 + i * 15, 360, 15, ln, c[:txt])
  end
  P.ui.rbox(base, SW - 92, 257, SW - 18, 319, 6, c[:light] ? mix(c[:panel2], PP::WHITE, 0.5) : mix(c[:dark], c[:panel], 0.3), c[:line])
  icon(top, id, SW - 79, 264, 48)
  le.send(:paint_hints, base, c)
end

#================================================================ defaults: the editor's Defaults (R)
def defaults_d2(b, c, le)
  mine = B.custom_list(2)
  dflt = B.default_list(2)
  items = proc { |l| l.count { |e| !B.heading?(e) } }
  heads = proc { |l| l.count { |e| B.heading?(e) } }
  segs = [[_INTL("{1} items, {2} headings", items.call(mine), heads.call(mine)), c[:txt], true], [_INTL(" become "), c[:dim]],
          [_INTL("{1} items", items.call(dflt)), c[:txt], true]]
  DL.send(:draw_buttons, b, c, _INTL("Restore the Defaults?"),
          _INTL("Medicine's list goes back to the one Kanto Reloaded starts with."), [_INTL("Restore"), _INTL("Keep Mine")], 1, segs)
end

def defaults_d3(b, c, le)
  # no popup: R again restores, anything else keeps yours
  x0, y0, x1, y1 = Reloaded::BagListScreen::DEFAULTS_BOX
  red = c[:red] || PP::POKE_RED
  PP.chamfer_grad(b, x0, y0, x1, y1, 6, mix(c[:panel2], red, 0.45), mix(c[:panel2], red, 0.2), red)
  P.text(b, x0, y0 + 1, x1 - x0, 20, _INTL("Restore?"), c[:strong], PF::TEXT, 2)
  # a red banner across the list's top says what pressing again does
  PP.chamfer_grad(b, 8, 68, SW - 8, 88, 6, mix(c[:panel2], red, 0.45), mix(c[:panel2], red, 0.2), red)
  P.text(b, 8, 70, SW - 16, 16, _INTL("PRESS AGAIN: MEDICINE'S STARTING LIST REPLACES YOURS"), c[:strong], PF::TINY, 2)
end

#================================================================ the editor
Input.queue = [
  le_to(:ICEHEAL),
  *editor_real("sp-add-1", [I::X], [I::BACK]),
  *editor_paint("sp-add-2", [[:ud, _INTL("Choose")], [btn(:C), _INTL("Add")], [btn(:X), _INTL("Search")], [btn(:B), _INTL("Back")]]) { |b, c, le| add_d2(b, c, le) },
  *editor_paint("sp-add-3", [[:ud, _INTL("Choose")], [btn(:C), _INTL("Add")], [btn(:B), _INTL("Back")]]) { |b, c, le| add_d3(b, c, le) },
  *editor_real("sp-defaults-1", [I::JUMPDOWN], [I::BACK]),
  *editor_paint("sp-defaults-2", [[:lr, _INTL("Choose")], [btn(:C), _INTL("OK")], [btn(:B), _INTL("Keep Mine")]]) { |b, c, le| defaults_d2(b, c, le) },
  *editor_paint("sp-defaults-3", [[Reloaded::Prompts.input(:R) || "R", _INTL("Restore")], [btn(:B), _INTL("Keep Mine")]]) { |b, c, le| defaults_d3(b, c, le) },
  at { Reloaded::Toast.dispose },
  I::BACK
]
begin
  Reloaded::BagListScreen.open(2)
rescue QueueEmpty
  check("the editor's designs: ran out of input", false)
end
Reloaded::Toast.dispose

#================================================================ export and import: the Bag page
$in_game = true
B.export_lists

def export_d2(b, c)
  Reloaded::Toast.show(_INTL("Lists Exported: Exports\\Bag Lists.txt"), :pill => [_INTL("8 POCKETS"), :gold])
end

def export_d3(b, c)
  segs = [[_INTL("8 pockets, 312 items, 6 headings."), c[:dim]]]
  DL.send(:draw_buttons, b, c, _INTL("Lists Exported"), _INTL("Saved to the Kanto Reloaded folder: Exports\\Bag Lists.txt"),
          [_INTL("OK"), _INTL("Open Folder")], 0, segs)
end

def import_d2(b, c)
  segs = [[_INTL("In it: 8 pockets, 312 items, 6 headings and 9 Favorites, exported today at 22:41."), c[:dim]]]
  DL.send(:draw_buttons, b, c, _INTL("Replace Your Lists?"), _INTL("Bag Lists.txt replaces the lists, Favorites and Auto-Sort it has."),
          [_INTL("Replace"), _INTL("Keep Mine")], 1, segs)
end

def import_d3(b, c)
  # choose what comes in: each part on or off, then Import
  DL.send(:dim, b)
  w = 320
  h = 214
  x = (SW - w) / 2
  y = (SH - h) / 2
  DL.frame(b, c, x, y, w, h, _INTL("Import Lists"))
  P.small(b, x, y + 40, w, 16, _INTL("From Bag Lists.txt: Choose what comes in."), c[:dim], 2)
  [[_INTL("Lists"), _INTL("8 pockets, 6 headings"), true], [_INTL("Favorites"), _INTL("9 items"), true],
   [_INTL("Auto-Sort"), _INTL("Medicine A-Z"), false]].each_with_index do |(label, note, on), i|
    ry = y + 62 + i * 30
    DL.send(:cursor_row, b, c, x + 8, ry, x + w - 8, ry + 26) if i == 0
    P.ui.rbox(b, x + 16, ry + 6, x + 30, ry + 20, 3, on ? c[:selb] : c[:panel], c[:line])
    b.fill_rect(x + 19, ry + 9, 8, 8, c[:strong]) if on
    P.text(b, x + 40, ry + 2, 120, 22, label, c[:opt], PF::TEXT)
    P.small(b, x + 150, ry + 6, w - 166, 16, note, c[:dim], 1)
  end
  bw = 96
  bx = x + (w - (bw * 2 + 10)) / 2
  by = y + h - 36
  [[_INTL("Import"), true], [_INTL("Cancel"), false]].each_with_index do |(label, on), i|
    DL.send(:button, b, c, bx + i * (bw + 10), by, bx + i * (bw + 10) + bw, by + 24, false)
    P.text(b, bx + i * (bw + 10), by, bw, 24, label, c[:txt], nil, 2)
  end
end

# A design painted on the settings screen's popup layer, in each theme
def page_paint(name, &paint)
  out = []
  MODES.each do |mode, word|
    out << at { S.set(MODE, mode); scr.refresh; paint.call(scr.overlay, scr.palette) }
    out << dmp("#{name}_#{word}")
    out << at { scr.overlay.clear; Reloaded::Toast.dispose; S.set(MODE, 0); scr.refresh }
  end
  out
end

def page_real(name, row, close)
  out = []
  MODES.each do |mode, word|
    out << at { S.set(MODE, mode); scr.refresh }
    out << down_to(row)
    out << I::USE
    out << dmp("#{name}_#{word}")
    out.concat(close)
    out << at { S.set(MODE, 0); scr.refresh }
  end
  out
end

drive("the Bag page's designs", [
  I::RIGHT,
  *page_real("sp-export-1", "Export Lists", [I::USE]),
  *page_paint("sp-export-2") { |b, c| export_d2(b, c) },
  *page_paint("sp-export-3") { |b, c| export_d3(b, c) },
  down_to("Import Lists"),
  *page_real("sp-import-1", "Import Lists", [I::USE]),
  *page_paint("sp-import-2") { |b, c| import_d2(b, c) },
  *page_paint("sp-import-3") { |b, c| import_d3(b, c) },
  I::BACK, I::BACK
])
S.set(MODE, 0)
errors = File.read(Reloaded::Log.path).lines.grep(/ERROR/) rescue []
check("no errors in Kanto Reloaded's log (#{errors.length})", errors.empty?)
errors.first(5).each { |l| puts "  " + l }
puts "designs done"
