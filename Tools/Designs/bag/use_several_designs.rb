# encoding: utf-8
# Mockups: Use Several at Once (his pick, 2026-10-23): after picking the
# Pokémon for a Rare Candy, a vitamin, a Wing, an EV-lowering Berry or a PP
# Up, how many to use; then what it did. Drawn over the real Party Screen
# on its preview's stand-ins (Tools/Tests/party_screen_preview.rb).
#   count    "Use How Many?" (top: Rare Candy on Pikachu; bottom: Protein)
#              1 Number With Both   the item and the Pokémon, the number, what it makes
#              2 A Bar              a bar from one to the most that helps
#              3 Quick Picks        1, 5, 10 and Max buttons, Left/Right fine-tunes
#   result   after 5 Proteins
#              1 A Notice           what changed, before and after
#              2 A Toast            one line at the top
#              3 On the Card        a pill on the Pokémon's card for a moment
# (A Rare Candy's result is the game's own level-up window: one, to the new
# level.)
# Usage (from the mod folder): ruby Tools/Designs/bag/use_several_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                              python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
PARTY_PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/party_screen_preview.rb")
DL = Reloaded::Dialogs
P = Reloaded::Pixel unless defined?(P)
PF = ::KIF::PixelFont unless defined?(PF)
PP = Reloaded::PartyPaint unless defined?(PP)
SW = 512
SH = 384
$pad_name = "Xbox Series X Controller"

def mix(a, b, t); Reloaded::Palette.mix(a, b, t); end
def btn(sym); Reloaded::Prompts.input(sym) || Reloaded::Prompts.name(sym); end
def pic(b, path, x, y, size, frame = nil)
  bm = Bitmap.new(pbResolveBitmap(path) || path) rescue nil
  return unless bm
  f = frame || [bm.width, bm.height].min
  b.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, f, f))
end
def item_pic(b, id, x, y, size); pic(b, "Graphics/Items/#{id}", x, y, size); end
def mon_pic(b, species, x, y, size); pic(b, "Graphics/Pokemon/Icons/#{species}", x, y, size, 64); end
def box(b, c, x0, y0, x1, y1)
  P.ui.rbox(b, x0, y0, x1, y1, 6, c[:light] ? mix(c[:panel2], PP::WHITE, 0.5) : mix(c[:dark], c[:panel], 0.3), c[:line])
end

# kind: [item, item name, what it makes, the most]
CANDY = [:RARECANDY, "Rare Candy", proc { |n| ["", _INTL("Lv. 34"), _INTL("Lv. {1}", 34 + n)] }, 66].freeze
PROTEIN = [:PROTEIN, "Protein", proc { |n| [_INTL("Attack EVs: "), "40", (40 + n * 10).to_s] }, 6].freeze

# "Attack EVs: 40 > 90", centred on cx, the arrow a small triangle
def change(b, c, cx, y, parts, col = nil)
  label, before, after = parts
  col ||= c[:green]
  lw = label.empty? ? 0 : P.width(PF::TEXT, label)
  bw = P.width(PF::TEXT, before)
  aw = P.width(PF::TEXT, after)
  total = lw + bw + 18 + aw
  x = cx - total / 2
  P.text(b, x, y, lw + 2, 20, label, c[:dim], PF::TEXT) if lw > 0
  P.text(b, x + lw, y, bw + 2, 20, before, c[:txt], PF::TEXT)
  P.ui.tri(b, x + lw + bw + 6, y + 6, :r, c[:dim], 4)
  P.text(b, x + lw + bw + 18, y, aw + 2, 20, after, col, PF::TEXT)
end

def count_d1(b, c, kind, n)
  id, name, makes, max = kind
  w = 330
  h = 168
  x = (SW - w) / 2
  y = (SH - h) / 2 - 10
  DL.frame(b, c, x, y, w, h, _INTL("Use How Many?"))
  box(b, c, x + 14, y + 46, x + 64, y + 96)
  item_pic(b, id, x + 17, y + 49, 44)
  box(b, c, x + w - 64, y + 46, x + w - 14, y + 96)
  mon_pic(b, :PIKACHU, x + w - 63, y + 47, 48)
  P.small(b, x, y + 42, w, 16, _INTL("{1} on Pikachu", name), c[:dim], 2)
  label = n.to_s
  tw = P.width(PF::ROW, label)
  cx = x + w / 2
  P.text(b, cx - 40, y + 58, 80, 30, label, c[:txt], PF::ROW, 2)
  P.ui.tri(b, cx - tw / 2 - 16, y + 68, :l, c[:selb], 5)
  P.ui.tri(b, cx + tw / 2 + 6, y + 68, :r, c[:selb], 5)
  change(b, c, x + w / 2, y + 102, makes.call(n))
  P.small(b, x, y + h - 28, w, 16, _INTL("1 to {1}: The Most That Helps", max), c[:dim], 2)
end

def count_d2(b, c, kind, n)
  id, name, makes, max = kind
  w = 340
  h = 156
  x = (SW - w) / 2
  y = (SH - h) / 2 - 10
  DL.frame(b, c, x, y, w, h, _INTL("Use How Many?"))
  item_pic(b, id, x + 16, y + 42, 24)
  P.text(b, x + 46, y + 42, 200, 24, _INTL("{1} on Pikachu", name), c[:txt], PF::TEXT)
  P.text(b, x + w - 116, y + 40, 100, 28, _INTL("{1} of {2}", n, max), c[:strong], PF::ROW, 1)
  bx0 = x + 22
  bw = w - 44
  PP.bar(b, c, bx0, y + 82, bw, n.to_f / max, c[:green], 6)
  change(b, c, x + w / 2, y + 98, makes.call(n))
  P.small(b, x, y + h - 26, w, 16, _INTL("Left and Right: One. Up and Down: Ten."), c[:dim], 2)
end

def count_d3(b, c, kind, n)
  id, name, makes, max = kind
  w = 340
  h = 168
  x = (SW - w) / 2
  y = (SH - h) / 2 - 10
  DL.frame(b, c, x, y, w, h, _INTL("Use How Many?"))
  item_pic(b, id, x + 16, y + 42, 24)
  P.text(b, x + 46, y + 42, 200, 24, _INTL("{1} on Pikachu", name), c[:txt], PF::TEXT)
  P.text(b, x + w - 70, y + 40, 54, 28, n.to_s, c[:strong], PF::ROW, 1)
  picks = [1, 5, 10, max].uniq
  bw = 64
  gap = 8
  bx = x + (w - (picks.length * bw + (picks.length - 1) * gap)) / 2
  picks.each_with_index do |k, i|
    on = k == n
    DL.send(:button, b, c, bx, y + 76, bx + bw, y + 100, on)
    P.text(b, bx, y + 76, bw, 24, k == max ? _INTL("Max {1}", k) : k.to_s, on ? c[:strong] : c[:txt], nil, 2)
    bx += bw + gap
  end
  change(b, c, x + w / 2, y + 108, makes.call(n))
  P.small(b, x, y + h - 26, w, 16, _INTL("Up and Down: One More or Less."), c[:dim], 2)
end

def result_d1(b, c)
  DL.send(:draw_buttons, b, c, _INTL("Pikachu's Attack Rose"), _INTL("Used 5 Proteins. Pikachu is a little friendlier too."), [_INTL("OK")], 0,
          [[" ", c[:dim]]])
  w = DL::TEXT_W
  h = 40 + 2 * 18 + 24 + 48
  y = (SH - h) / 2
  change(b, c, SW / 2, y + 40 + 36 + 4, PROTEIN[2].call(5))
end

def result_d2(_b, _c)
  Reloaded::Toast.show(_INTL("Used 5 Proteins on Pikachu"), :icon => :PROTEIN, :pill => [_INTL("ATK EVS 90"), :green])
end

def result_d3(b, c)
  hit = ($ps.instance_variable_get(:@kr_card_hits) || []).find { |i, *| i == 0 }
  return unless hit
  _i, x0, y0, x1, y1 = hit
  P.pill(b, x1 - 6, y1 - 20, _INTL("+50 ATK EVS"), *PP.badge(c, [120, 230, 150]), true)
end

def designs(name, hints, &paint)
  out = []
  [[0, "dark"], [2, "light"]].each do |mode, word|
    out << at {
      S.set(Reloaded::Palette::MODE, mode)
      $ps.instance_variable_set(:@kr_design_hints, hints)
      $ps.refresh
      b = $ps.overlay
      b.clear
      DL.send(:dim, b) if hints
      paint.call(b, $ps.palette)
    }
    out << dmp("#{name}_#{word}")
    out << at { $ps.overlay.clear; Reloaded::Toast.dispose; $ps.instance_variable_set(:@kr_design_hints, nil); S.set(Reloaded::Palette::MODE, 0); $ps.refresh }
  end
  out
end

PS.scene_class.prepend(Module.new { def hint_pairs; @kr_design_hints || super; end })
count_hints = [[:lr, _INTL("One")], [:ud, _INTL("Ten")], [btn(:C), _INTL("Use")], [btn(:B), _INTL("Cancel")]]
quick_hints = [[:lr, _INTL("Quick Pick")], [:ud, _INTL("One")], [btn(:C), _INTL("Use")], [btn(:B), _INTL("Cancel")]]
q = []
q.concat(designs("us-count-1a", count_hints) { |b, c| count_d1(b, c, CANDY, 5) })
q.concat(designs("us-count-1b", count_hints) { |b, c| count_d1(b, c, PROTEIN, 5) })
q.concat(designs("us-count-2a", count_hints) { |b, c| count_d2(b, c, CANDY, 5) })
q.concat(designs("us-count-2b", count_hints) { |b, c| count_d2(b, c, PROTEIN, 5) })
q.concat(designs("us-count-3a", quick_hints) { |b, c| count_d3(b, c, CANDY, 5) })
q.concat(designs("us-count-3b", quick_hints) { |b, c| count_d3(b, c, PROTEIN, 5) })
q.concat(designs("us-result-1", [[btn(:C), _INTL("OK")]]) { |b, c| result_d1(b, c) })
q.concat(designs("us-result-2", nil) { |b, c| result_d2(b, c) })
q.concat(designs("us-result-3", nil) { |b, c| result_d3(b, c) })
q << I::BACK
S.set(Reloaded::Palette::MODE, 0)
$Trainer.party = make_party
party_screen("use several designs", q)
puts $failed ? "SOME DESIGNS FAILED" : "designs done"
