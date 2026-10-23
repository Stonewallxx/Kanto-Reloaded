# encoding: utf-8
# What the Healing Moves mockups share: the Overworld Menu on the map, the
# popups' real pieces (pokevial_common.rb), the party with its healers, the
# plates, and the chosen Heal with Moves list (Healer List, his pick
# 2026-10-23), drawn behind the popups that open from it.
# Loaded by the designs here.
load File.join(File.dirname(File.expand_path(__FILE__)), "..", "pokevial", "pokevial_common.rb")

PS = Reloaded::PartyScreen
GREEN_C = :green
# [species, name, hp, max, types, status, healing moves [name, what it does, PP left]]
MONS = [[:CHANSEY, "Chansey", 310, 320, [:NORMAL], nil, [["Soft-Boiled", "Heals one Pokémon", 8], ["Heal Bell", "Cures the party", 5]]],
        [:PIKACHU, "Pikachu", 40, 95, [:ELECTRIC], nil, []],
        [:GENGAR, "Gengar", 70, 110, [:GHOST, :POISON], "PSN", []],
        [:ALAKAZAM, "Alakazam", 50, 90, [:PSYCHIC], nil, [["Recover", "Heals itself", 10]]],
        [:SNORLAX, "Snorlax", 160, 160, [:NORMAL], nil, [["Rest", "Heals itself, sleeps", 5]]],
        [:PIDGEOT, "Pidgeot", 80, 120, [:NORMAL, :FLYING], nil, [["Roost", "Heals itself", 9]]]].freeze
HEALERS = MONS.reject { |m| m[6].empty? }

def tcol(type); Color.new(*PS.type_rgb(type)); end
def hp_col(c, hp, max); f = hp.to_f / max; f > 0.5 ? c[:green] : (f > 0.25 ? c[:amber] : c[:red]); end

# an angled plate lit in a colour (the Party Screen's), cut at top left and
# bottom right
def plate(o, c, x0, y0, x1, y1, col, cut = 8, glow = false)
  top = mix(c[:panel2], col, 0.45)
  bottom = mix(c[:panel2], c[:dark], 0.45)
  PP.chamfer_grad(o, x0, y0, x1, y1, cut, top, bottom, glow ? c[:selb] : mix(c[:line], col, 0.5))
end

def hp_line(o, c, x, y, w, hp, max)
  PP.bar(o, c, x, y, w, hp.to_f / max, hp_col(c, hp, max), 3)
end

def left_pill(o, c, x1, y, n)
  P2.small(o, x1 - 60, y, 60, 16, "#{n} Left", c[:green], 1)
end

# the party's HP along the bottom: six small plates
def party_strip(o, c, x, y, w, h = 40)
  gap = 6
  pw = (w - gap * 5) / 6
  MONS.each_with_index do |(sp, _name, hp, max, types, st), i|
    px = x + i * (pw + gap)
    plate(o, c, px, y, px + pw, y + h, tcol(types[0]), 7)
    art(o, sp, px + 16, y + h / 2, 24)
    words = st ? st : "#{hp}/#{max}"
    P2.text(o, px + 30, y + 8, pw - 36, 12, words, st ? c[:pink] : c[:txt], PF::TINY, 1)
    hp_line(o, c, px + 32, y + h - 12, pw - 40, hp, max)
  end
end

def map_panel(o, c, title)
  x = 10; y = 4; w = SW - 20; h = HINT_TOP - 8
  o.fill_rect(0, 0, SW, HINT_TOP, Color.new(0, 0, 0, 90))
  DG.send(:panel, o, c, x, y, w, h)
  DG.send(:title_bar, o, c, x, y, w, title)
  return [x, y, w, h]
end

# The chosen Heal with Moves list (Design 1, Healer List)
def healer_list(o, c)
  x, y, w, h = map_panel(o, c, "Heal with Moves")
  ty = y + 40
  # Heal Everyone, a plate button of its own
  bx0 = x + 12; bx1 = x + w - 12
  DG.send(:button, o, c, bx0, ty, bx1, ty + 24, false)
  P2.text(o, bx0 + 14, ty + 3, 200, 18, "Heal Everyone", c[:txt], PF::TEXT)
  P2.small(o, bx0, ty + 4, bx1 - bx0 - 14, 16, "3 moves, 5 PP", c[:dim], 1)
  ry = ty + 32
  sel = [0, 0]
  HEALERS.each_with_index do |(sp, name, hp, max, types, _st, moves), hi|
    plate(o, c, x + 12, ry, x + w - 12, ry + 22, tcol(types[0]))
    art(o, sp, x + 30, ry + 11, 20)
    P2.text(o, x + 46, ry + 2, 140, 18, name, c[:txt], PF::TEXT)
    hp_line(o, c, x + w - 150, ry + 10, 70, hp, max)
    P2.small(o, x + w - 72, ry + 3, 56, 16, "#{hp}/#{max}", c[:txt], 1)
    ry += 25
    moves.each_with_index do |(mv, what, left), mi|
      cursor(o, c, x + 30, ry - 1, x + w - 14, ry + 18) if [hi, mi] == sel
      P2.text(o, x + 44, ry, 130, 18, mv, [hi, mi] == sel ? c[:strong] : c[:txt], PF::TEXT)
      P2.small(o, x + 176, ry + 1, 200, 16, what, c[:dim])
      left_pill(o, c, x + w - 22, ry + 1, left)
      ry += 20
    end
    ry += 5
  end
  party_strip(o, c, x + 12, y + h - 50, w - 24, 40)
end

def panel_shot(name, hints, mode)
  S.set(:"interface.theme_mode", mode)
  $qa_hints = hints
  om.refresh
  o = om.send(:overlay)
  hidden = om.send(:sprites).reject { |s| s.bitmap.equal?(o) }
  hidden.each { |s| s.visible = false }
  o.clear
  yield(o, om.send(:palette))
  P2.hints(o, o, om.send(:palette), hints, :xbox)
  dump(name)
  hidden.each { |s| s.visible = true }
end

