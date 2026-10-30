# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the battle cursor
#==============================================================================
# Battle Scene's cursor (his picks, 2026-10-29): a 4 px ring in Interface's
# Cursor Color (the Theme's by default), Vivid, a deeper shade in Theme Mode
# Light, with a soft glow fading 5 px out past it, pulsing like every Kanto
# Reloaded cursor. Its shapes:
#
#   :edge    rounded, the button snug inside it (his ask, 2026-10-29: "our
#            cursor against its borders"): the ring's inside on the edge of
#            the button's solid pixels, measured from its picture (EBDX's
#            buttons carry a see-through shadow under them and soft edges,
#            left out). On EBDX's command row it's where old Kanto Reloaded
#            put its ring (92 x 38). EBDX's command row, Bag, target window
#            and Fight menu
#   :plate   on a Kanto Reloaded plate's own edge, cut like it at the top
#            left and bottom right: the Plates and Corner Panel rows
#
# A ring's picture is made once per size, shape and colour and kept for the
# battle (a handful of sizes ever appear); following a button costs a few
# assignments a frame and makes nothing.
#==============================================================================

module Reloaded
  module BattleCursor
    P = Reloaded::Pixel
    PP = Reloaded::PartyPaint
    CLEAR = Color.new(0, 0, 0, 0)
    GLOW = [[0, 24], [1, 46], [2, 72], [3, 104], [4, 140]].freeze     # the glow's rings, outside in: [step, alpha]
    RING = 4
    GLOW_W = 5
    SOLID = 200                   # a picture's pixels this solid are its button (EBDX's shadows are 143 at most)
    CORNER = 4                    # how far into each corner the button's own shape is read (EBDX cuts 2 px)

    @bitmaps = {}

    class << self
      # The ring's colour: Cursor Color through PartyPaint.ink (Vivid, and
      # deeper in Theme Mode Light)
      def colour
        return @colour if @colour
        fill, _border = Reloaded::Palette.cursor_colours
        @colour = PP.ink(Reloaded::Palette.map_menu, [fill.red.to_i, fill.green.to_i, fill.blue.to_i])
        return @colour
      end

      # [bitmap, dx, dy] for a ring whose outer edge is a w x h box (:edge,
      # corners of radius r) or round a w x h plate (:plate, cut r): its
      # picture and its top-left from the box's. corners (:edge): the
      # button's own corners (BattleCursor.corners), the ring filling the
      # pixels they leave empty
      def bitmap(w, h, shape, r, corners = nil)
        key = [w, h, shape, r, corners]
        hit = @bitmaps[key]
        return hit if hit && !hit[0].disposed?
        col = colour
        if shape == :plate
          m = RING + GLOW_W
          b = Bitmap.new(w + 2 * m, h + 2 * m)
          grow = proc { |e| r + (e * 0.41).round }    # a 45-degree cut grows about 0.41 a pixel outward
          GLOW.each { |k, a| PP.chamfer(b, k, k, b.width - k, b.height - k, grow.call(m - k), nil, alpha(col, a)) }
          PP.chamfer(b, 5, 5, b.width - 5, b.height - 5, grow.call(RING), nil, col)
          PP.chamfer(b, m, m, b.width - m, b.height - m, r, nil, CLEAR)
          return @bitmaps[key] = [b, -m, -m]
        end
        g = GLOW_W
        b = Bitmap.new(w + 2 * g, h + 2 * g)
        GLOW.each { |k, a| P.ui.rrect(b, k, k, b.width - 1 - k, b.height - 1 - k, r + g - k, alpha(col, a)) }
        P.ui.rrect(b, g, g, b.width - 1 - g, b.height - 1 - g, r, col)
        if corners
          # inside: the button's own shape at its corners (EBDX cuts each by
          # 2 px; the ring fills what it leaves, so nothing shows through)
          i = g + RING
          b.fill_rect(i, i, b.width - 2 * i, b.height - 2 * i, CLEAR)
          bw = b.width - 2 * i
          bh = b.height - 2 * i
          CORNER.times do |dy|
            CORNER.times do |dx|
              4.times do |k|
                next unless corners.getbyte(k * CORNER * CORNER + dy * CORNER + dx) == 48
                x = k.odd? ? i + bw - 1 - dx : i + dx
                y = k >= 2 ? i + bh - 1 - dy : i + dy
                b.fill_rect(x, y, 1, 1, col)
              end
            end
          end
        else
          P.ui.rrect(b, g + RING, g + RING, b.width - 1 - g - RING, b.height - 1 - g - RING, [r - RING, 0].max, CLEAR)
        end
        return @bitmaps[key] = [b, -g, -g]
      end

      def alpha(col, a)
        return Color.new(col.red, col.green, col.blue, a)
      end

      # The button's solid part of a frame: [x, y, w, h] in the frame, read
      # inward from each side (a few rows and columns a button, not all of it)
      def solid(src, rx, ry, rw, rh)
        hit = proc { |x, y| src.get_pixel(rx + x, ry + y).alpha >= SOLID }
        top = (0...rh).find { |y| (0...rw).any? { |x| hit.call(x, y) } }
        return [0, 0, rw, rh] unless top
        bottom = (rh - 1).downto(top).find { |y| (0...rw).any? { |x| hit.call(x, y) } }
        left = (0...rw).find { |x| (top..bottom).any? { |y| hit.call(x, y) } }
        right = (rw - 1).downto(left).find { |x| (top..bottom).any? { |y| hit.call(x, y) } }
        return [left, top, right - left + 1, bottom - top + 1]
      end

      # A button's corners inside its solid part (bx, by, bw, bh in its
      # frame): CORNER x CORNER pixels at each (top left, top right, bottom
      # left, bottom right; each read from its own corner inward), "1" solid
      def corners(src, rx, ry, bounds)
        bx, by, bw, bh = bounds
        s = String.new(:capacity => 4 * CORNER * CORNER)
        4.times do |k|
          CORNER.times do |dy|
            CORNER.times do |dx|
              x = k.odd? ? bx + bw - 1 - dx : bx + dx
              y = k >= 2 ? by + bh - 1 - dy : by + dy
              s << (src.get_pixel(rx + x, ry + y).alpha >= SOLID ? "1" : "0")
            end
          end
        end
        return s
      end

      # A new battle, or Cursor Color / the Theme changed: pictures are made
      # again (the old ones go when the battle that showed them ends)
      def reset
        @colour = nil
        @old = (@old || []) + @bitmaps.values.map(&:first)
        @bitmaps = {}
      end

      def dispose_all
        (@old || []).each { |b| b.dispose unless b.disposed? }
        @bitmaps.each_value { |b, _x, _y| b.dispose unless b.disposed? }
        @old = []
        @bitmaps = {}
        @colour = nil
      end
    end

    #--------------------------------------------------------------------------
    # One ring on a viewport, put round a button each frame
    #--------------------------------------------------------------------------
    class Ring
      # shape :edge (option :radius, its outside corners) or :plate (option :cut)
      def initialize(viewport, z, shape = :edge, options = {})
        @sprite = Sprite.new(viewport)
        @sprite.z = z
        @sprite.visible = false
        @shape = shape
        @r = shape == :plate ? (options[:cut] || 7) : (options[:radius] || 6)
      end

      # A ring whose box is x, y, w, h (:edge: its outer edge; :plate: the
      # plate's own); opacity scales the pulse (EBDX's half-strength buttons)
      def place(x, y, w, h, opacity = 255, corners = nil)
        return if disposed? || @broken
        if w != @w || h != @h || !corners.equal?(@built) || @sprite.bitmap.nil? || @sprite.bitmap.disposed?
          @w = w
          @h = h
          @built = corners
          begin
            @sprite.bitmap, @dx, @dy = Reloaded::BattleCursor.bitmap(w, h, @shape, @r, corners)
          rescue StandardError => e
            # a cursor that can't be drawn hides for the rest of the battle;
            # the battle carries on
            @broken = true
            @sprite.visible = false
            Reloaded::Log.exception("Battle Scene: the battle cursor couldn't be drawn", e, :battle_scene)
            return
          end
        end
        @sprite.x = x + @dx
        @sprite.y = y + @dy
        @sprite.opacity = Reloaded::Pixel.cursor_opacity * opacity / 255
        @sprite.visible = true
      end

      # Round an EBDX button, snug: the ring's inside on its solid part's
      # edge, its corners filling the button's cut corners (measured when the
      # button or its frame changes). EBDX's 4-frame
      # hop on a new pick (src_rect.y below 0) isn't followed: the game trims
      # the picture then rather than moving it.
      def follow(spr, opacity = nil)
        return hide if spr.nil? || spr.disposed? || !spr.visible || disposed? || @broken
        src = spr.bitmap
        return hide if src.nil? || src.disposed?
        r = spr.src_rect
        sy = r.y < 0 ? 0 : r.y
        unless src.equal?(@src) && r.x == @rx && sy == @ry && r.width == @rw && r.height == @rh
          @src = src
          @rx = r.x
          @ry = sy
          @rw = r.width
          @rh = r.height
          begin
            @solid = Reloaded::BattleCursor.solid(src, r.x, sy, r.width, r.height)
            @corners = Reloaded::BattleCursor.corners(src, r.x, sy, @solid)
          rescue StandardError => e
            @broken = true
            @sprite.visible = false
            Reloaded::Log.exception("Battle Scene: a button's edge couldn't be read", e, :battle_scene)
            return
          end
        end
        bx, by, bw, bh = @solid
        place(spr.x - spr.ox + bx - RING, spr.y - spr.oy + by - RING, bw + 2 * RING, bh + 2 * RING, opacity || spr.opacity, @corners)
      end

      def hide
        @sprite.visible = false unless disposed?
      end

      def visible?
        return !disposed? && @sprite.visible
      end

      def z=(value)
        @sprite.z = value unless disposed?
      end

      def disposed?
        return @sprite.nil? || @sprite.disposed?
      end

      def dispose
        @sprite.dispose unless disposed?
        @sprite = nil
      end
    end
  end
end
