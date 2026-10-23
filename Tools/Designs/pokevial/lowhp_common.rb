# encoding: utf-8
# What the Low HP Reminder mockups share (lowhp_pause.rb, lowhp_owm.rb): how
# each design marks the PokeVial's tile or row when the party is badly hurt
# (any Pokemon fainted, or the party's total HP under half), and the charges
# as little Poke Balls (his pick).
# Now      = no reminder.
# Design 1 = Red Glow: a soft red glow around it (slowly pulsing in game).
# Design 2 = Alert Badge: a small red "!" badge.
# Design 3 = Red Wash: its plate tinted red.
# Design 4 = Red Name: its name (and the tile's pill) in red.
LOWHP_STYLES = [[:none, "LH0_now"], [:glow, "LH1_glow"], [:badge, "LH2_badge"], [:wash, "LH3_wash"], [:name, "LH4_name"]].freeze
$lowhp = :none

module LowHP
  PX = Reloaded::Pixel
  BANG = ["##", "##", "##", "##", "..", "##"].freeze

  module_function

  def mix(a, b, t); Reloaded::Palette.mix(a, b, t); end
  def alpha(col, a); Color.new(col.red, col.green, col.blue, a); end

  # Before the tile or row is drawn (its corners x0, y0 to x1, y1): the glow
  # around it, blended over what's there; `row` for an Overworld Menu row,
  # which has no plate of its own, so its tint and edge are drawn here too
  def behind(b, c, x0, y0, x1, y1, row)
    red = c[:red]
    case $lowhp
    when :glow
      [[3, 35], [2, 70], [1, 130]].each { |d, a| ring(b, x0 - d, y0 - d, x1 + d, y1 + d, red, a) }
      if row
        blend(b, x0 + 1, y0 + 1, x1 - x0 - 1, y1 - y0 - 1, red, 30)
        ring(b, x0, y0, x1, y1, red, 220)
      end
    when :wash
      if row
        blend(b, x0 + 1, y0 + 1, x1 - x0 - 1, y1 - y0 - 1, red, 80)
        ring(b, x0, y0, x1, y1, red, 140)
      end
    end
  end

  # A colour laid over a box at an opacity (a one-pixel bitmap stretched:
  # blts blend where fill_rect replaces)
  def blend(b, x, y, w, h, col, a)
    return if w <= 0 || h <= 0
    @dots ||= {}
    key = [col.red, col.green, col.blue]
    dot = (@dots[key] ||= Bitmap.new(1, 1).tap { |d| d.fill_rect(0, 0, 1, 1, Color.new(*key)) })
    b.stretch_blt(Rect.new(x, y, w, h), dot, Rect.new(0, 0, 1, 1), a)
  end

  # A one-pixel ring through x0, y0 and x1, y1, its corners rounded off
  def ring(b, x0, y0, x1, y1, col, a)
    blend(b, x0 + 2, y0, x1 - x0 - 3, 1, col, a)
    blend(b, x0 + 2, y1, x1 - x0 - 3, 1, col, a)
    blend(b, x0, y0 + 2, 1, y1 - y0 - 3, col, a)
    blend(b, x1, y0 + 2, 1, y1 - y0 - 3, col, a)
    [[x0 + 1, y0 + 1], [x1 - 1, y0 + 1], [x0 + 1, y1 - 1], [x1 - 1, y1 - 1]].each { |px, py| blend(b, px, py, 1, 1, col, a) }
  end

  # The palette the tile or row draws with
  def colours(c)
    case $lowhp
    when :name then return c.merge(:txt => c[:red])
    when :wash, :glow then return c.merge(:panel => mix(c[:panel], c[:red], $lowhp == :wash ? 0.32 : 0.12), :line => c[:red])
    end
    return c
  end

  # After: the badge, its top left at x, y
  def over(b, c, x, y)
    return unless $lowhp == :badge
    PX.ui.rbox(b, x, y, x + 11, y + 11, 5, c[:red], mix(c[:red], c[:white], 0.4))
    BANG.each_with_index { |ln, r| ln.each_char.with_index { |ch, k| b.fill_rect(x + 5 + k - 1, y + 3 + r, 1, 1, c[:white]) if ch == "#" } }
  end

  # The charges as Poke Balls, the last one ending at x1; returns the width
  def balls(b, c, x1, cy, full, total, size = 11, gap = 3)
    hollow = mix(c[:line], c[:dim], 0.55)
    muted = { :ink => hollow, :red => c[:dark], :white => mix(c[:dark], hollow, 0.35) }
    w = total * size + (total - 1) * gap
    total.times do |i|
      px = x1 - w + i * (size + gap)
      top = cy - size / 2
      if i < full
        PX.poke_ball(b, px, top, size)
      else
        size.times do |r|
          size.times do |k|
            part = PX.send(:ball_pixel, k, r, size)
            b.fill_rect(px + k, top + r, 1, 1, muted[part]) if part
          end
        end
      end
    end
    return w
  end
end
