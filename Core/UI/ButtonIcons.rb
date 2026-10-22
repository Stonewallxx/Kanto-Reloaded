#==============================================================================
# Kanto Reloaded: button icons
#==============================================================================
# Every key and controller button drawn as a small pixel icon, for hints and
# the Controls screen. Inputs are Reloaded Controls' ("k:225", "p:0",
# "a:5+", "hold:p:3"); the style follows the controller in use:
#
#   Xbox         A B X Y on their coloured buttons, LB RB LT RT LS RS
#   PlayStation  the cross, circle, square and triangle in their colours,
#                L1 R1 L2 R2 L3 R3
#   Nintendo     B A Y X where Nintendo puts them, L R ZL ZR, + and -
#   Keyboard     a keycap with the key's name (arrows drawn as arrows)
#
#   ButtonIcons.draw(bitmap, x, y, "p:2", palette, :playstation)  # width
#   ButtonIcons.width("p:2", :playstation)
#
# Icons are h pixels tall (16 in hints, 18 in lists), top-left at x, y.
#==============================================================================

module Reloaded
  module ButtonIcons
    XBOX = { 0 => [96, 176, 72], 1 => [208, 64, 64], 2 => [64, 128, 224], 3 => [232, 184, 48] }.freeze
    PLAYSTATION = { 0 => [124, 178, 232], 1 => [232, 96, 96], 2 => [216, 132, 196], 3 => [80, 200, 160] }.freeze
    PAD_FILL = [44, 46, 56].freeze
    ARROW_KEYS = { 82 => :u, 81 => :d, 80 => :l, 79 => :r }.freeze
    DPAD = { 11 => :u, 12 => :d, 13 => :l, 14 => :r }.freeze

    module_function

    def pf; return ::KIF::PixelFont; end
    def ui; return ::KIF::PixelUI; end

    # How wide an input's icon is.
    def width(token, style = :xbox, h = 16)
      kind, code, _positive, held = Reloaded::Controls::Inputs.parse(token)
      return 0 unless kind
      w = held ? hold_width : 0
      return w + shape_width(kind, code, style, h)
    end

    # Draws an input's icon; returns its width.
    def draw(b, x, y, token, c, style = :xbox, h = 16)
      kind, code, positive, held = Reloaded::Controls::Inputs.parse(token)
      return 0 unless kind
      w = 0
      if held
        Reloaded::Pixel.text(b, x, y, hold_width, h, _INTL("Hold"), c[:dim], pf::TINY)
        w = hold_width
        x += w
      end
      case kind
      when :key then return w + keycap(b, x, y, code, c, h)
      when :pad then return w + pad(b, x, y, code, c, style, h)
      else return w + axis(b, x, y, code, positive, c, style, h)
      end
    end

    def hold_width
      return pf.width(pf::TINY, _INTL("Hold")) + 3
    end

    def shape_width(kind, code, style, h)
      case kind
      when :key
        return h + 2 if ARROW_KEYS[code]
        return [pf.width(pf::TINY, key_label(code)) + 10, h + 2].max
      when :pad
        return h if code <= 3 || code == 7 || code == 8 || DPAD[code]
        return pill_width(pad_label(code, style), h)
      else
        return pill_width(trigger_label(code, style), h) if code >= 4
        return h + pf.width(pf::TINY, "L") + 1
      end
    end

    #--------------------------------------------------------------------------
    # Keyboard
    #--------------------------------------------------------------------------
    def key_label(code)
      return Reloaded::Controls::Inputs::KEYS[code] || "?"
    end

    def keycap(b, x, y, code, c, h)
      w = shape_width(:key, code, nil, h)
      ui.rbox(b, x, y, x + w - 1, y + h - 1, 3, c[:line])
      ui.rbox(b, x + 1, y + 1, x + w - 2, y + h - 3, 2, c[:key])
      if (dir = ARROW_KEYS[code])
        ui.tri(b, x + (w - 7) / 2, y + (h - 2 - 7) / 2, dir, c[:txt], 3)
      else
        Reloaded::Pixel.text(b, x, y, w, h - 2, key_label(code), c[:txt], pf::TINY, 2)
      end
      return w
    end

    #--------------------------------------------------------------------------
    # Controller
    #--------------------------------------------------------------------------
    def pad_label(code, style)
      names = Reloaded::Controls::Inputs::PAD[style] || Reloaded::Controls::Inputs::PAD[:xbox]
      return names[code] || "?"
    end

    def trigger_label(code, style)
      t = Reloaded::Controls::Inputs::TRIGGERS[style] || Reloaded::Controls::Inputs::TRIGGERS[:xbox]
      return t[code - 4] || "?"
    end

    def pill_width(label, h)
      return [pf.width(pf::TINY, label) + 10, h + 4].max
    end

    def circle(b, x, y, d, color)
      ui.rrect(b, x, y, x + d - 1, y + d - 1, d / 2, color)
    end

    def pad(b, x, y, code, c, style, h)
      if code <= 3
        face(b, x, y, code, c, style, h)
        return h
      end
      if (dir = DPAD[code])
        dpad(b, x, y, dir, c, h)
        return h
      end
      if code == 7 || code == 8
        circle(b, x, y, h, c[:dim])
        circle(b, x + 2, y + 2, h - 4, Color.new(*PAD_FILL))
        Reloaded::Pixel.glyph(b, x, y, h, h, code == 7 ? "L" : "R", c[:white])
        return h
      end
      label = pad_label(code, style)
      w = pill_width(label, h)
      pill(b, x, y, w, h, label, c)
      return w
    end

    def pill(b, x, y, w, h, label, c, top_round = 6)
      ui.rbox(b, x, y + 1, x + w - 1, y + h - 2, [top_round, (h - 3) / 2].min, c[:dim])
      ui.rbox(b, x + 1, y + 2, x + w - 2, y + h - 3, [top_round - 1, (h - 5) / 2].min, Color.new(*PAD_FILL))
      Reloaded::Pixel.text(b, x, y + 1, w, h - 2, label, c[:white], pf::TINY, 2)
    end

    # The four face buttons
    def face(b, x, y, code, c, style, h)
      case style
      when :playstation
        circle(b, x, y, h, Color.new(*PAD_FILL))
        ps_shape(b, x, y, code, Color.new(*PLAYSTATION[code]), h)
      when :nintendo
        circle(b, x, y, h, c[:dim])
        circle(b, x + 1, y + 1, h - 2, Color.new(*PAD_FILL))
        Reloaded::Pixel.glyph(b, x, y, h, h, pad_label(code, style), c[:white])
      else
        circle(b, x, y, h, Color.new(*XBOX[code]))
        Reloaded::Pixel.glyph(b, x, y, h, h, pad_label(code, :xbox), c[:white])
      end
    end

    # PlayStation's shapes, drawn in pixels: 0 cross, 1 circle, 2 square,
    # 3 triangle
    def ps_shape(b, x, y, code, color, h)
      s = h >= 18 ? 9 : 8                  # the shape's size
      sx = x + (h - s) / 2
      sy = y + (h - s) / 2
      case code
      when 0
        s.times do |i|
          b.fill_rect(sx + i, sy + i, 2, 1, color)
          b.fill_rect(sx + s - 1 - i - 1, sy + i, 2, 1, color)
        end
      when 1
        ui.rrect(b, sx, sy, sx + s - 1, sy + s - 1, s / 2, color)
        ui.rrect(b, sx + 2, sy + 2, sx + s - 3, sy + s - 3, (s - 4) / 2, Color.new(*PAD_FILL))
      when 2
        b.fill_rect(sx, sy, s, 2, color)
        b.fill_rect(sx, sy + s - 2, s, 2, color)
        b.fill_rect(sx, sy, 2, s, color)
        b.fill_rect(sx + s - 2, sy, 2, s, color)
      else
        ps_triangle(b, x, y, color, h)
      end
    end

    # The triangle's outline (2 px sides, a 2 px base), its box centred in
    # the button: w wide and w - 2 tall, both even like the button, so it
    # sits exactly in the middle.
    def ps_triangle(b, x, y, color, h)
      w = h >= 18 ? 12 : (h >= 16 ? 10 : 8)
      th = w - 2
      tx = x + (h - w) / 2
      ty = y + (h - th) / 2
      mid = tx + w / 2                     # the apex is mid - 1 and mid
      th.times do |r|
        hw = 1 + (r * (w / 2 - 1)).fdiv(th - 1).round
        if r >= th - 2
          b.fill_rect(mid - hw, ty + r, hw * 2, 1, color)
        else
          b.fill_rect(mid - hw, ty + r, 2, 1, color)
          b.fill_rect(mid + hw - 2, ty + r, 2, 1, color)
        end
      end
    end

    def dpad(b, x, y, dir, c, h)
      a = h / 3
      ui.rbox(b, x + a, y, x + 2 * a + 1, y + h - 1, 1, c[:dim])
      ui.rbox(b, x, y + a, x + h - 1, y + 2 * a + 1, 1, c[:dim])
      case dir
      when :u then ui.rbox(b, x + a, y, x + 2 * a + 1, y + a, 1, c[:white])
      when :d then ui.rbox(b, x + a, y + h - 1 - a, x + 2 * a + 1, y + h - 1, 1, c[:white])
      when :l then ui.rbox(b, x, y + a, x + a, y + 2 * a + 1, 1, c[:white])
      else ui.rbox(b, x + h - 1 - a, y + a, x + h - 1, y + 2 * a + 1, 1, c[:white])
      end
    end

    def axis(b, x, y, code, positive, c, style, h)
      if code >= 4
        label = trigger_label(code, style)
        w = pill_width(label, h)
        pill(b, x, y, w, h, label, c, 3)
        return w
      end
      circle(b, x, y, h, c[:dim])
      circle(b, x + 2, y + 2, h - 4, Color.new(*PAD_FILL))
      dir = code.even? ? (positive ? :r : :l) : (positive ? :d : :u)
      ui.tri(b, x + (h - 7) / 2, y + (h - 7) / 2, dir, c[:white], 3)
      Reloaded::Pixel.text(b, x + h + 1, y, 10, h, code < 2 ? "L" : "R", c[:dim], pf::TINY)
      return h + pf.width(pf::TINY, "L") + 1
    end
  end
end
