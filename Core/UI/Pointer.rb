#==============================================================================
# Kanto Reloaded: the mouse in Kanto Reloaded's screens
#==============================================================================
# The mouse works in Kanto Reloaded's own screens and popups, never on the
# map (decided 2026-10-16/17): moving it over something picks it (hover), a
# left click does it, a right click goes back, the wheel scrolls. A screen
# notes where it drew what can be clicked ("hits": [value, x0, y0, x1, y1])
# and asks which one is under the mouse.
#
# mkxp-z: Input::MOUSELEFT / MOUSERIGHT work with Input.trigger?, the wheel is
# Input.scroll_v, and PIF's Mouse.getMousePos gives the position (nil when
# the mouse is outside the window).
#==============================================================================

module Reloaded
  module Pointer
    module_function

    # [x, y] in game pixels, or nil.
    def pos
      return nil unless defined?(::Mouse) && ::Mouse.respond_to?(:getMousePos)
      return ::Mouse.getMousePos
    rescue StandardError
      return nil
    end

    def left?
      return button?(:MOUSELEFT)
    end

    def right?
      return button?(:MOUSERIGHT)
    end

    # True while the left button is held down (dragging)
    def held?
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
      v = ::Input.respond_to?(:scroll_v) ? ::Input.scroll_v.to_i : 0
      return v > 0 ? -1 : (v < 0 ? 1 : 0)
    rescue StandardError
      return 0
    end

    # True when the mouse moved since the last call (each screen's loop asks
    # once a frame): hover follows the mouse only when it moves, so a mouse
    # resting over a list never fights the controller.
    def moved?
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
