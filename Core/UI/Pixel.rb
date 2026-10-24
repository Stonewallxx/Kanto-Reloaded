#==============================================================================
# Kanto Reloaded: pixel drawing helpers
#==============================================================================
# Kanto Reloaded's screens draw with KIF Beta's crisp pixel fonts
# (KIF::PixelFont, 990_KIF/000_Core/013-014) in the current Palette. These
# helpers add what KIF's don't do:
#
#   text          centred on the capitals' real height (KIF's text helper
#                 centres on a smaller "height", so text sits a few pixels low)
#   small         the smaller text of hints and descriptions: the game's small
#                 font at size 20, drawn by the engine (as the Kanto Reloaded
#                 mod's hints were); the pixel fonts have no size between
#                 22 and 11 that stays crisp
#   glyph         one character centred on its own pixels (section initials)
#   pill          a badge with its text centred
#   heading       a section heading, the line after it
#   hints         the hint line: the button white, its label dimmed
#   cursor_bitmap the Kanto Reloaded mod's cursor: see-through fill and border
#==============================================================================

module Reloaded
  module Pixel
    # Rows of flat capitals (H, E, K; Q and J hang lower) per font: [top, height]
    CAPS = { [:system, 26] => [2, 18], [:narrow, 26] => [2, 18], [:small, 22] => [1, 14],
             [:small, 11] => [1, 7], [:system, 13] => [1, 9] }.freeze
    HALF = [:small, 11]          # half the size of TEXT
    SMALL_SIZE = 20              # the small font at 20 draws 18 px tall
    SMALL_CAPS = [1, 13]         # its capitals: [top, height]
    SMALL_LINE = 20

    module_function

    def pf
      return ::KIF::PixelFont
    end

    def ui
      return ::KIF::PixelUI
    end

    def available?
      return defined?(::KIF::PixelFont) && defined?(::KIF::PixelUI)
    end

    # The font Global Small Text would swap a large one for, so centring
    # uses the font that is really drawn.
    def drawn_font(font)
      return Reloaded::GlobalSmallText.pixel_font(font) if defined?(Reloaded::GlobalSmallText)
      return font
    end

    def width(font, str)
      return pf.width(font, str.to_s)
    end

    # Text in a box, centred vertically on its capitals; align 0 left,
    # 1 right, 2 centre. Returns the text's width.
    def text(b, x, y, w, h, str, color, font = nil, align = 0)
      font ||= pf::TEXT
      str = pf.utf8(str.to_s)
      sw = pf.width(font, str)
      tx = case align
           when 1 then x + w - sw
           when 2 then x + (w - sw) / 2
           else x
           end
      top, ink = CAPS[drawn_font(font)] || [0, pf.height(font)]
      pf.draw(b, tx, y + (h - ink) / 2 - top, str, font, color)
      return sw
    end

    # Smaller text (hints, descriptions), centred on its capitals; align 0
    # left, 1 right, 2 centre. Returns its width.
    def small(b, x, y, w, h, str, color, align = 0)
      str = str.to_s
      small_font(b)
      b.font.color = color
      sw = b.text_size(str).width
      tx = case align
           when 1 then x + w - sw
           when 2 then x + (w - sw) / 2
           else x
           end
      top, ink = SMALL_CAPS
      b.draw_text(tx, y + (h - ink) / 2 - top, sw + 4, SMALL_LINE, str, 0)
      return sw
    end

    def small_font(b)
      pbSetSmallFont(b)
      b.font.size = SMALL_SIZE
    end

    # Coloured text in the smaller size, wrapped to w and each line centred:
    # segments [[text, colour, whole], ...]; a whole segment (a highlighted
    # phrase) is never split across lines. Returns the number of lines.
    def small_rich(b, x, y, w, line_h, segments)
      small_font(b)
      tokens = []
      segments.each do |text, color, whole|
        if whole
          tokens << [text.to_s, color]
        else
          text.to_s.scan(/\S+|\s+/).each { |t| tokens << [t, color] }
        end
      end
      lines = [[]]
      width = 0
      tokens.each do |t, color|
        tw = b.text_size(t).width
        if t =~ /\A\s+\z/
          next if lines.last.empty?
        elsif width + tw > w && !lines.last.empty?
          lines.last.pop while lines.last.last && lines.last.last[0] =~ /\A\s+\z/
          lines << []
          width = 0
        end
        lines.last << [t, color, tw]
        width += tw
      end
      lines.each_with_index do |line, i|
        lx = x + (w - line.sum { |_, _, tw| tw }) / 2
        line.each do |t, color, tw|
          small(b, lx, y + i * line_h, tw + 2, line_h, t, color)
          lx += tw
        end
      end
      return lines.length
    end

    # Words wrapped to a width in the smaller text.
    def small_wrap(b, str, width)
      small_font(b)
      out = []
      line = ""
      str.to_s.split(/\s+/).each do |word|
        t = line.empty? ? word : "#{line} #{word}"
        if b.text_size(t).width > width && !line.empty?
          out << line
          line = word
        else
          line = t
        end
      end
      out << line unless line.empty?
      return out
    end

    # One character centred on its own pixels.
    def glyph(b, x, y, w, h, ch, color, font = nil)
      font ||= pf::TINY
      g = pf.glyph(pf.data(font), ch)
      return unless g
      pf.draw(b, x + (w - g[3]) / 2 - g[1], y + (h - g[4]) / 2 - g[2], ch, font, color)
    end

    # A Poke Ball size x size at x, y (Kanto Reloaded's section icon): a dark
    # outline, a red top and a white bottom, a dark band and button, drawn in
    # one fill per run of a colour.
    BALL_COLOURS = { :ink => [28, 24, 30], :red => [238, 64, 64], :white => [248, 248, 248] }.freeze

    def poke_ball(b, x, y, size = 13)
      size.times do |row|
        start = 0
        prev = ball_pixel(0, row, size)
        1.upto(size) do |col|
          now = col < size ? ball_pixel(col, row, size) : :end
          next if now == prev
          b.fill_rect(x + start, y + row, col - start, 1, Color.new(*BALL_COLOURS[prev])) if prev
          start = col
          prev = now
        end
      end
    end

    def ball_pixel(x, y, size)
      c = (size - 1) / 2.0
      d = Math.sqrt((x - c)**2 + (y - c)**2)
      return nil if d > size / 2.0 - 0.15
      return d > 1.2 ? :ink : :white if d <= 2.3              # the button
      return :ink if d > size / 2.0 - 1.2 || (y - c).abs < 0.6   # the outline, the band
      return y < c ? :red : :white
    end

    # A badge; right-aligned at x when right is true. Returns its width.
    def pill(b, x, y, label, fill, color, right = true)
      w = pf.width(pf::TINY, label) + 12
      x -= w if right
      ui.rbox(b, x, y, x + w, y + 15, 4, fill)
      text(b, x, y, w, 16, label, color, pf::TINY, 2)
      return w
    end

    # A heading in small capitals, left-aligned, with a line after it.
    def heading(b, x0, x1, y, label, color, line)
      label = label.to_s.upcase
      w = text(b, x0, y, 300, 13, label, color, pf::TINY, 0)
      b.fill_rect(x0 + w + 6, y + 6, x1 - (x0 + w + 6), 1, line) if x1 > x0 + w + 6
    end

    HINT_H = 25           # the hint bar

    # The hint line at the bottom, centred: [[button, label], ...]. A button
    # is :ud, :lr, :u or :d (drawn arrows), an input ("p:2", "k:6") drawn as its
    # icon (ButtonIcons, in the controller's style), a key name ("Enter")
    # drawn as a keycap, or nil. The bar is drawn on base, the hints on top.
    def hints(base, top, c, pairs, style = :xbox)
      w = base.width
      h = base.height
      base.fill_rect(0, h - HINT_H, w, HINT_H, c[:panel2])
      base.fill_rect(0, h - HINT_H, w, 1, c[:line])
      draw_hints(top, [(w - hints_width(top, pairs, style)) / 2, 10].max, h - HINT_H, c, pairs, style)
    end

    # The hints along a strip HINT_H tall at y; returns their width. hover:
    # the hint drawn lit (the mouse is over it); spans: filled with [index,
    # x0, x1] per hint, for clicks.
    def draw_hints(b, x0, y, c, pairs, style = :xbox, hover = nil, spans = nil)
      x = x0
      pairs.each_with_index do |(button, label), i|
        start = x
        case button
        when :ud
          ui.tri(b, x, y + 7, :u, c[:txt], 3)
          ui.tri(b, x + 8, y + 11, :d, c[:txt], 3)
          x += 20
        when :lr
          ui.tri(b, x, y + 9, :l, c[:txt], 3)
          ui.tri(b, x + 8, y + 9, :r, c[:txt], 3)
          x += 20
        when :d
          ui.tri(b, x, y + 9, :d, c[:txt], 3)
          x += 12
        when :u
          ui.tri(b, x, y + 9, :u, c[:txt], 3)
          x += 12
        when nil
          nil
        else
          x += hint_button(b, x, y + 5, button.to_s, c, style) + 5
        end
        x += small(b, x, y + 1, 300, 24, label, i == hover ? (c[:strong] || c[:white]) : c[:dim]) + 12
        spans << [i, start, x - 12] if spans
      end
      return x - x0 - 12
    end

    # How wide those hints are.
    def hints_width(probe, pairs, style = :xbox)
      x = 0
      pairs.each do |button, label|
        case button
        when :ud, :lr then x += 20
        when :d, :u then x += 12
        when nil then nil
        else
          t = button.to_s
          x += (Reloaded::Controls::Inputs.valid?(t) ? Reloaded::ButtonIcons.width(t, style) : cap_width(t)) + 5
        end
        small_font(probe)
        x += probe.text_size(label.to_s).width + 12
      end
      return x - 12
    end

    def hint_button(b, x, y, button, c, style)
      return Reloaded::ButtonIcons.draw(b, x, y, button, c, style) if Reloaded::Controls::Inputs.valid?(button)
      w = cap_width(button)
      ui.rbox(b, x, y, x + w - 1, y + 15, 3, c[:line])
      ui.rbox(b, x + 1, y + 1, x + w - 2, y + 13, 2, c[:key])
      text(b, x, y, w, 14, button, c[:txt], pf::TINY, 2)
      return w
    end

    def cap_width(label)
      return [pf.width(pf::TINY, label) + 10, 18].max
    end

    # The Kanto Reloaded mod's cursor (Cursor Color): a rounded box with a
    # see-through fill and border, drawn on its own transparent bitmap so its
    # sprite can pulse by opacity.
    def cursor_bitmap(w, h, cursor_value = nil, palette = nil)
      fill, border = Reloaded::Palette.cursor(cursor_value, palette)
      bmp = Bitmap.new(w, h)
      ui.rbox(bmp, 0, 0, w - 1, h - 1, 4, fill, border)
      return bmp
    end

    # The cursor's opacity this frame: the Kanto Reloaded mod's pulse.
    def cursor_opacity(frame = nil)
      frame ||= (Graphics.frame_count rescue 0)
      pulse = Math.sin(frame * Math::PI / 20.0) * 0.5 + 0.5
      return (150 + 105 * pulse).round
    end

    # Words wrapped to a width in the small font.
    def wrap(str, width, font = nil)
      font ||= pf::TEXT
      out = []
      line = ""
      pf.utf8(str.to_s).split(/\s+/).each do |word|
        t = line.empty? ? word : "#{line} #{word}"
        if pf.width(font, t) > width && !line.empty?
          out << line
          line = word
        else
          line = t
        end
      end
      out << line unless line.empty?
      return out
    end
  end
end
