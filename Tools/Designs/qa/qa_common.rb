# encoding: utf-8
# What the Quality of Life tools' mockups share: the Overworld Menu's preview
# (its stand-ins and the map behind), the party, and the popup pieces.
# Loaded by nature_designs.rb, lock_designs.rb and the rest here.
TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/overworld_menu_preview.rb")
eval(File.read(TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- A: ")[0], binding, TEST)

QA_HERE = File.expand_path(File.dirname(__FILE__))
SW = 512
SH = 384
HINT_TOP = SH - Reloaded::Pixel::HINT_H
B_PAD = "p:1"; A_PAD = "p:0"; X_PAD = "p:2"; Y_PAD = "p:3"
GREEN_T = Color.new(120, 230, 150)
GOLD_T = Color.new(240, 200, 80)
PINK_T = Color.new(240, 130, 160)
GOLD_FILL = Color.new(70, 58, 20)
P2 = Reloaded::Pixel
PF = ::KIF::PixelFont unless defined?(PF)

#---------------------------------------------------------------- the party
# [species, name, level, nature]
PARTY = [[:PIKACHU, "Pikachu", 34, "Timid"], [:PIDGEOT, "Pidgeot", 36, "Jolly"], [:GYARADOS, "Gyarados", 35, "Adamant"],
         [:EEVEE, "Eevee", 22, "Bashful"], [:MACHOKE, "Machoke", 33, "Brave"], [:GENGAR, "Gengar", 37, "Modest"]]

#---------------------------------------------------------------- the menu behind
QA_MAPVP = Viewport.new(0, 0, SW, SH)
QA_MAPVP.z = 0
QA_MAP = Sprite.new(QA_MAPVP)
QA_MAP.bitmap = Bitmap.new(File.join(QA_HERE, "backdrop.png"))
$qa_hints = nil
Reloaded::OverworldMenuScreen.prepend(Module.new { def hint_pairs; $qa_hints || super; end })
Reloaded::Prompts.singleton_class.prepend(Module.new { def style; :xbox; end })

#---------------------------------------------------------------- pieces
$qa_bmps = {}
def qa_bmp(path); $qa_bmps[path] ||= Bitmap.new(path); end
# the trimmed battle sprite fitted to a box x box square centred at cx, cy
def art(b, sp, cx, cy, box)
  bm = qa_bmp(File.join(QA_HERE, "art", "#{sp}.png"))
  k = box.to_f / [bm.width, bm.height].max
  w = (bm.width * k).round; h = (bm.height * k).round
  b.stretch_blt(Rect.new(cx - w / 2, cy - h / 2, w, h), bm, Rect.new(0, 0, bm.width, bm.height))
end
def popup(o, c, x, y, w, h, title, dim = true)
  Reloaded::Dialogs.send(:dim, o) if dim
  Reloaded::Dialogs.send(:panel, o, c, x, y, w, h)
  Reloaded::Dialogs.send(:title_bar, o, c, x, y, w, title)
end
# darkens what's drawn so far, for a popup over a popup (the game draws
# that on a layer of its own; dim would clear the one below)
def shade(o)
  t = Bitmap.new(SW, SH)
  t.fill_rect(0, 0, SW, SH, Color.new(0, 0, 0, 120))
  o.blt(0, 0, t, Rect.new(0, 0, SW, SH))
  t.dispose
end
def cursor(o, c, x0, y0, x1, y1); Reloaded::Dialogs.send(:cursor_row, o, c, x0, y0, x1, y1); end
def small_w(o, s); P2.send(:small_font, o); o.text_size(s).width; end
# a padlock 9 x 11, top-left at x, y
def lock_icon(o, x, y, col)
  o.fill_rect(x + 2, y, 5, 1, col)
  o.fill_rect(x + 1, y + 1, 1, 4, col)
  o.fill_rect(x + 7, y + 1, 1, 4, col)
  P2.ui.rbox(o, x, y + 5, x + 9, y + 11, 1, col)
end
# The chosen Pick a Pokémon popup (Party Rows): sprite, name, level, then
# the tool's own column, painted by the block (o, c, row x, row y, row w,
# party entry, index). Returns the popup's [x, y, w, h].
def party_rows(o, c, title, sel, dim = true)
  w = 380; rh = 34; h = 42 + PARTY.length * rh + 8
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, title, dim)
  PARTY.each_with_index do |entry, i|
    sp, name, lv = entry
    ry = y + 40 + i * rh
    cursor(o, c, x + 6, ry, x + w - 6, ry + rh - 2) if i == sel
    art(o, sp, x + 26, ry + rh / 2, 28)
    P2.text(o, x + 48, ry + 7, 110, 18, name, c[:txt], PF::TEXT)
    P2.text(o, x + 150, ry + 10, 50, 12, "LV #{lv}", GOLD_T, PF::TINY)
    yield(o, c, x, ry, w, entry, i) if block_given?
  end
  return [x, y, w, h]
end
def shot(name, hints)
  $qa_hints = hints
  om.refresh
  yield(om.send(:overlay), om.send(:palette))
  dump(name)
end
# Opens the menu on the map, then each design in turn
def run_designs(label, designs)
  queue = []
  designs.each { |name, hints, painter| queue << at { shot(name, hints, &painter) } }
  queue << at { $qa_hints = nil; om.send(:overlay).clear; om.refresh }
  queue << I::BACK
  on_map(label, queue)
  puts "designs: #{designs.map(&:first).join(', ')}"
end
