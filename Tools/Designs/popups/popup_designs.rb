# encoding: utf-8
# Mockups: a new look for every Kanto Reloaded popup, after the Party
# Screen's angled plates (his ask, 2026-10-22). Each style is shown on a
# choice menu and on the PokeVial dialog (Dark, and the dialog in Light).
# Design 0 = the popups as they are now, to compare.
# Design 1 = Angled Plate (my pick): cut corners, lit from the top, the Poke
#            red line under the title, a faint slash.
# Design 2 = Header Plate: the title on a plate of its own across the top.
# Design 3 = Slash Tab: the title on an angled tab breaking the top edge.
# HIS PICK (2026-10-22): Design 2, with the title centred and no accent bar
# on the plate; list rows keep the regular rounded cursor (only plates, the
# frame and buttons, get cut corners). Built in Core/UI/Dialogs.rb.
# Sprites: python ../qa/qa_assets.py "<KIF Beta>" first (writes ../qa/art).
# Usage (from this folder): ruby popup_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "..", "qa", "qa_common.rb")

PP = Reloaded::PartyPaint
POKE_RED = PP::POKE_RED
VIAL = Bitmap.new(File.join(ARGV[0], "Mods/KantoReloaded/Graphics/PauseMenu/POKEVIAL.png"))

def mix(a, b, t); Reloaded::Palette.mix(a, b, t); end

# a band leaning right, w wide, rows y0...y0 + h, its foot at x0
def slash(o, x0, y0, w, h, col)
  h.times { |r| o.fill_rect(x0 + (h - r) / 2, y0 + r, w, 1, col) }
end

#---------------------------------------------------------------- the styles
# Each answers panel (content top), cursor and button.
class NowStyle
  def panel(o, c, x, y, w, h, title, icon = nil)
    Reloaded::Dialogs.send(:panel, o, c, x, y, w, h)
    Reloaded::Dialogs.send(:title_bar, o, c, x, y, w, title)
    draw_icon(o, icon, x + 26, y + 6)
    y + 40
  end

  # a title icon 20 x 24 at x, y
  def draw_icon(o, icon, x, y)
    o.stretch_blt(Rect.new(x, y, 20, 24), icon, Rect.new(0, 0, icon.width, icon.height)) if icon
  end

  # where the charge pips sit (their top)
  def pips_y(y)
    y + 13
  end

  def cursor(o, c, x0, y0, x1, y1)
    Reloaded::Dialogs.send(:cursor_row, o, c, x0, y0, x1, y1)
  end

  def button(o, c, x0, y0, x1, y1, label, on)
    if on
      P2.ui.rbox(o, x0, y0, x1, y1, 6, c[:sel], c[:selb])
    else
      P2.ui.rbox(o, x0, y0, x1, y1, 6, c[:dark], c[:line])
    end
    P2.text(o, x0, y0 + 2, x1 - x0, 24, label, on ? c[:strong] : c[:txt], PF::TEXT, 2)
  end
end

class PlateStyle < NowStyle
  CUT = 14

  def panel(o, c, x, y, w, h, title, icon = nil)
    top = mix(c[:panel2], c[:acc], 0.10)
    bottom = mix(c[:panel2], c[:bg], 0.55)
    PP.chamfer_grad(o, x, y, x + w, y + h, CUT, top, bottom, mix(c[:line], c[:acc], 0.35))
    slash(o, x + w - 112, y + 2, 44, 31, mix(top, c[:acc], 0.16))
    P2.text(o, x, y + 5, w, 26, title, c[:title], PF::ROW, 2)
    o.fill_rect(x + CUT + 2, y + 33, w - 2 * CUT - 4, 2, POKE_RED)
    draw_icon(o, icon, x + 26, y + 6)
    y + 42
  end

  def cursor(o, c, x0, y0, x1, y1)
    fill, border = Reloaded::Palette.cursor(nil, c)
    PP.chamfer(o, x0, y0, x1, y1, 6, Reloaded::Palette.over(c[:panel2], fill), Reloaded::Palette.over(c[:panel2], border))
  end

  def button(o, c, x0, y0, x1, y1, label, on)
    if on
      PP.chamfer(o, x0, y0, x1, y1, 7, c[:sel], c[:selb])
    else
      PP.chamfer(o, x0, y0, x1, y1, 7, mix(c[:panel2], c[:bg], 0.45), c[:line])
    end
    P2.text(o, x0, y0 + 2, x1 - x0, 24, label, on ? c[:strong] : c[:txt], PF::TEXT, 2)
  end
end

class HeaderStyle < PlateStyle
  def panel(o, c, x, y, w, h, title, icon = nil)
    PP.chamfer(o, x, y, x + w, y + h, 12, c[:panel2], mix(c[:line], c[:acc], 0.35))
    PP.chamfer_grad(o, x + 4, y + 4, x + w - 4, y + 36, 9, mix(c[:panel2], c[:acc], 0.30),
                    mix(c[:panel2], c[:acc], 0.12), mix(c[:line], c[:acc], 0.45))
    o.fill_rect(x + 16, y + 10, 3, 20, c[:selb])
    tx = x + 26
    if icon
      draw_icon(o, icon, tx, y + 8)
      tx += 26
    end
    P2.text(o, tx, y + 6, w - 40, 26, title, c[:title], PF::ROW)
    o.fill_rect(x + 4, y + 38, w - 8, 2, POKE_RED)
    y + 46
  end

  def pips_y(y)
    y + 15
  end
end

class TabStyle < PlateStyle
  def panel(o, c, x, y, w, h, title, icon = nil)
    body = y + 13
    PP.chamfer_grad(o, x, body, x + w, y + h, CUT, mix(c[:panel2], c[:acc], 0.06),
                    mix(c[:panel2], c[:bg], 0.55), mix(c[:line], c[:acc], 0.35))
    o.fill_rect(x + CUT, body, w - CUT - 2, 2, POKE_RED)
    tw = P2.width(PF::ROW, title) + 34 + (icon ? 24 : 0)
    tab = mix(c[:selb], c[:panel2], 0.15)
    27.times do |r|
      lx = x + 12 + (27 - r) / 2
      o.fill_rect(lx, y + r, tw, 1, r == 0 ? mix(tab, c[:white], 0.25) : tab)
    end
    tx = x + 24
    if icon
      draw_icon(o, icon, tx, y + 1)
      tx += 24
    end
    P2.text(o, tx, y + 1, tw - 20, 26, title, c[:white], PF::ROW)
    y + 46
  end

  def pips_y(y)
    y + 22
  end
end

STYLES = [["Now", NowStyle.new], ["Angled Plate", PlateStyle.new], ["Header Plate", HeaderStyle.new], ["Slash Tab", TabStyle.new]]

#---------------------------------------------------------------- the popups
# A choice menu with what the highlighted row does at its foot
def menu(o, c, s)
  rows = ["Summary", "Switch", "Item", "Nickname", "Cancel"]
  sel = 1
  w = 250; rh = 26
  x = (SW - w) / 2
  h = 46 + rows.length * rh + 40
  y = (HINT_TOP - h) / 2
  Reloaded::Dialogs.send(:dim, o)
  top = s.panel(o, c, x, y, w, h, "Gengar")
  rows.each_with_index do |r, i|
    ry = top + i * rh
    s.cursor(o, c, x + 8, ry, x + w - 8, ry + rh - 2) if i == sel
    P2.text(o, x + 22, ry, w - 40, rh, r, c[:txt], PF::TEXT)
  end
  ly = top + rows.length * rh + 6
  o.fill_rect(x + 16, ly, w - 32, 1, c[:line])
  P2.small(o, x, ly + 8, w, 16, "Move Gengar to another place.", c[:dim], 2)
end

# The PokeVial dialog (the roadmap's Design 1) in a style
VIAL_ROWS = [[:PIKACHU, "Pikachu", 78, 95, "+17 HP", :green], [:GYARADOS, "Gyarados", 120, 120, "Healthy", :dim],
             [:GENGAR, "Gengar", 40, 110, "+70 HP, Cures Poison", :green], [:MACHOKE, "Machoke", 0, 90, "Revived", :pink],
             [:EEVEE, "Eevee", 60, 60, "PP Restored", :blue]].freeze

def vial(o, c, s)
  w = 380; rh = 34
  x = (SW - w) / 2
  h = 46 + 18 + VIAL_ROWS.length * rh + 44
  y = [(HINT_TOP - h) / 2, 4].max
  Reloaded::Dialogs.send(:dim, o)
  top = s.panel(o, c, x, y, w, h, "PokeVial", VIAL)
  py = s.pips_y(y)
  4.times do |i|                                      # charges: 2 of 4
    px = x + w - 72 + i * 13
    if i < 2
      P2.ui.rbox(o, px, py, px + 10, py + 10, 2, POKE_RED)
    else
      P2.ui.rbox(o, px, py, px + 10, py + 10, 2, c[:dark], c[:line])
    end
  end
  P2.text(o, x + 18, top, 150, 14, "HEAL PREVIEW", c[:head], PF::TINY)
  P2.text(o, x + w - 168, top, 150, 14, "FULL HEAL", c[:dim], PF::TINY, 1)
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
  s.button(o, c, x + 40, by, x + 200, by + 28, "Use PokeVial", true)
  s.button(o, c, x + 214, by, x + w - 40, by + 28, "Back", false)
end

#---------------------------------------------------------------- run
HINTS_MENU = [[A_PAD, "Select"], [B_PAD, "Back"]]
HINTS_VIAL = [[:lr, "Choose"], [A_PAD, "Select"], [B_PAD, "Back"]]
queue = []
STYLES.each_with_index do |(name, style), n|
  [["a_menu", 0, HINTS_MENU, :menu], ["b_vial", 0, HINTS_VIAL, :vial], ["c_vial_light", 2, HINTS_VIAL, :vial]].each do |tag, mode, hints, what|
    queue << at do
      S.set(:"interface.theme_mode", mode)
      shot("PU#{n}#{tag}", hints) { |o, c| send(what, o, c, style) }
    end
  end
end
queue << at { S.set(:"interface.theme_mode", 0); $qa_hints = nil; om.send(:overlay).clear; om.refresh }
queue << I::BACK
on_map("Popup designs", queue)
puts "styles: #{STYLES.map(&:first).join(', ')}"
