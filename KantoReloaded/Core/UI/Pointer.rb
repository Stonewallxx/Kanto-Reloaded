#==============================================================================
# Kanto Reloaded: the mouse in Kanto Reloaded's screens
#==============================================================================
# The mouse works in Kanto Reloaded's own screens and popups (on the map it's
# KIF's): moving it over something picks it (hover), a left click does it, a
# right click goes back, the wheel scrolls. A screen notes where it drew what
# can be clicked ("hits": [value, x0, y0, x1, y1]) and asks which one is under
# the mouse.
#
# On KIF's mouse (KIF 1.2, his call 2026-10-25: KIF's over our own, for
# phones' touch too): the pointer is KIF::Mouse's, so KIF's Mouse option
# (Touch controls on a phone) turns it on and off, and a phone's taps land
# where they should. KIF makes a click A and B and the wheel Up / Down on
# every screen; the first time a Kanto Reloaded screen reads the pointer in a
# frame it claims that frame's click and wheel (KIF::Mouse.swallow! /
# eat_wheel!), so a click isn't A too and the wheel doesn't step twice. A
# game window opened over a Kanto Reloaded screen (a message's choices)
# doesn't read this, so KIF's mouse still works there.
#
# On a KIF without it: mkxp-z's own (Input::MOUSELEFT / MOUSERIGHT with
# Input.trigger?, the wheel in Input.scroll_v, PIF's Mouse.getMousePos).
#==============================================================================

module Reloaded
  module Pointer
    module_function

    # KIF's mouse, when this KIF has it
    def kif
      m = defined?(::KIF::Mouse) ? ::KIF::Mouse : nil
      return m && m.respond_to?(:swallow!) && m.respond_to?(:x) ? m : nil
    end

    # This frame's click and wheel are a Kanto Reloaded screen's (once a
    # frame; the wheel kept for wheel below)
    def claim(m)
      f = ::Graphics.frame_count
      return if @claimed == f
      @claimed = f
      @wheel_now = m.on ? m.wheel.to_i : 0
      m.swallow! if m.on && (m.left || m.right)
      m.eat_wheel! if @wheel_now != 0
    rescue StandardError
      nil
    end

    # [x, y] in game pixels, or nil.
    def pos
      if (m = kif)
        claim(m)
        return m.on && m.x ? [m.x, m.y] : nil
      end
      return nil unless defined?(::Mouse) && ::Mouse.respond_to?(:getMousePos)
      return ::Mouse.getMousePos
    rescue StandardError
      return nil
    end

    def left?
      if (m = kif)
        claim(m)
        return m.on && m.left ? true : false
      end
      return button?(:MOUSELEFT)
    end

    def right?
      if (m = kif)
        claim(m)
        return m.on && m.right ? true : false
      end
      return button?(:MOUSERIGHT)
    end

    # True while the left button is held down (dragging)
    def held?
      if (m = kif)
        claim(m)
        return m.on && m.held ? true : false
      end
      return false unless ::Input.const_defined?(:MOUSELEFT)
      return ::Input.press?(::Input::MOUSELEFT) ? true : false
    rescue StandardError
      return false
    end

    def button?(name)
      return false unless ::Input.const_defined?(name)
      return ::Input.trigger?(::Input.const_get(name)) ? true : false
    rescue StandardError
      return false
    end

    # The wheel since the last step: -1 (up), 1 (down) or 0.
    def wheel
      if (m = kif)
        claim(m)
        v = @wheel_now.to_i
        return v > 0 ? -1 : (v < 0 ? 1 : 0)
      end
      v = ::Input.respond_to?(:scroll_v) ? ::Input.scroll_v.to_i : 0
      return v > 0 ? -1 : (v < 0 ? 1 : 0)
    rescue StandardError
      return 0
    end

    # True when the mouse moved since the last call (each screen's loop asks
    # once a frame): hover follows the mouse only when it moves, so a mouse
    # resting over a list never fights the controller. On KIF's mouse, KIF's
    # (it also waits after a wheel turn, until the pointer really moves).
    def moved?
      if (m = kif)
        claim(m)
        return m.on && m.moved ? true : false
      end
      p = pos
      moved = !p.nil? && p != @last
      @last = p
      return moved
    end

    def inside?(x0, y0, x1, y1)
      p = pos
      return false unless p
      return p[0] >= x0 && p[0] <= x1 && p[1] >= y0 && p[1] <= y1
    end

    # The value of the hit under the mouse, or nil.
    def hit(hits)
      p = pos
      return nil unless p && hits
      found = hits.find { |_v, x0, y0, x1, y1| p[0] >= x0 && p[0] <= x1 && p[1] >= y0 && p[1] <= y1 }
      return found ? found[0] : nil
    end
  end
end
