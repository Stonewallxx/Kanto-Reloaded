# encoding: utf-8
# What the PokeVial mockups share: the Overworld Menu on the map (the Quality
# of Life mockups' stand-ins), the popups' real pieces (Reloaded::Dialogs,
# Header Plate) and the PokeVial dialog as the roadmap chose it (Design 1,
# Confirm Dialog: charge pips, Heal Preview, Use / Back).
# Loaded by the designs here.
load File.join(File.dirname(File.expand_path(__FILE__)), "..", "qa", "qa_common.rb")

PP = Reloaded::PartyPaint
DG = Reloaded::Dialogs
POKE_RED = PP::POKE_RED
VIAL = Bitmap.new(File.join(ARGV[0], "Mods/KantoReloaded/Graphics/PauseMenu/POKEVIAL.png"))

def mix(a, b, t); Reloaded::Palette.mix(a, b, t); end
def vial_icon(o, x, y, w = 20, h = 24)
  o.stretch_blt(Rect.new(x, y, w, h), VIAL, Rect.new(0, 0, VIAL.width, VIAL.height))
end

# The charge pips, the first `full` filled, right edge at x1
def pips(o, c, x1, y, full, total)
  total.times do |i|
    px = x1 - (total - i) * 13
    if i < full
      P2.ui.rbox(o, px, y, px + 10, y + 10, 2, POKE_RED)
    else
      P2.ui.rbox(o, px, y, px + 10, y + 10, 2, c[:dark], c[:line])
    end
  end
end

# A popup in the real look: dim, frame, the title plate; the vial at the
# plate's left and the pips at its right when given
def frame(o, c, x, y, w, h, title, charges = nil, dim = true)
  DG.send(:dim, o) if dim
  DG.send(:panel, o, c, x, y, w, h)
  DG.send(:title_bar, o, c, x, y, w, title)
  vial_icon(o, x + 12, y + 6) if charges
  pips(o, c, x + w - 12, y + 12, charges[0], charges[1]) if charges
end

def button(o, c, x0, y0, x1, y1, label, on)
  DG.send(:button, o, c, x0, y0, x1, y1, on)
  P2.text(o, x0, y0 + 2, x1 - x0, 24, label, on ? c[:strong] : c[:txt], PF::TEXT, 2)
end

VIAL_ROWS = [[:PIKACHU, "Pikachu", 78, 95, "+17 HP", :green], [:GYARADOS, "Gyarados", 120, 120, "Healthy", :dim],
             [:GENGAR, "Gengar", 40, 110, "+70 HP, Cures Poison", :green], [:MACHOKE, "Machoke", 0, 90, "Revived", :pink],
             [:EEVEE, "Eevee", 60, 60, "PP Restored", :blue]].freeze

# The PokeVial dialog; the block paints the foot (buttons) at by, else Use / Back
def vial_dialog(o, c, charges = [2, 4], mode = "FULL HEAL")
  w = 380; rh = 34
  x = (SW - w) / 2
  h = 40 + 18 + VIAL_ROWS.length * rh + 44
  y = [(HINT_TOP - h) / 2, 4].max
  frame(o, c, x, y, w, h, "PokeVial", charges)
  top = y + 40
  P2.text(o, x + 18, top, 150, 14, "HEAL PREVIEW", c[:head], PF::TINY)
  P2.text(o, x + w - 168, top, 150, 14, mode, c[:dim], PF::TINY, 1)
  VIAL_ROWS.each_with_index do |(sp, name, hp, max, gain, tone), i|
    ry = top + 18 + i * rh
    art(o, sp, x + 30, ry + rh / 2, 28)
    P2.text(o, x + 52, ry - 1, 120, 18, name, c[:txt], PF::TEXT)
    frac = hp.to_f / max
    col = frac > 0.5 ? c[:green] : (frac > 0.25 ? c[:amber] : c[:red])
    PP.bar(o, c, x + 54, ry + 20, 92, frac, col)
    P2.small(o, x + 156, ry + 13, 70, 16, "#{hp}/#{max}", c[:txt])
    P2.small(o, x + 200, ry + 4, w - 218, 16, gain, tone == :dim ? c[:dim] : c[tone], 1)
  end
  by = y + h - 38
  if block_given?
    yield(x, y, w, h, by)
  else
    button(o, c, x + 40, by, x + 200, by + 28, "Use PokeVial", true)
    button(o, c, x + 214, by, x + w - 40, by + 28, "Back", false)
  end
end

# Theme Mode for a shot (0 Dark, 2 Light), the menu redrawn in it
def run_pokevial(label, designs)
  queue = []
  designs.each do |name, hints, mode, painter|
    queue << at do
      S.set(:"interface.theme_mode", mode)
      shot(name, hints, &painter)
    end
  end
  queue << at { S.set(:"interface.theme_mode", 0); $qa_hints = nil; om.send(:overlay).clear; om.refresh }
  queue << I::BACK
  on_map(label, queue)
  puts "designs: #{designs.map(&:first).join(', ')}"
end
