#==============================================================================
# Kanto Reloaded: a mod's own icon in Kanto Reloaded's lists
#==============================================================================
# Where a list shows a mod with a letter tile (What's New's sources, the
# Timing Profiler's owners, KR Debug's Debug Menu...), a mod registered here
# shows its own Poke Ball instead, in its colour, and with an outline round
# it when it has one (his picks, 2026-10-25: Ghostly Possession's purple
# ball with the possessed Outline; Kanto Reloaded Debug's grey ball).
#
#   Reloaded::ModIcons.register("My Mod", :ids => ["MyMod"], :ball => [r, g, b],
#                               :outline => [r, g, b])
#   Reloaded::ModIcons.for("My Mod")                 # its icon, or nil
#   Reloaded::ModIcons.draw(bitmap, x, y, icon)      # 15 px, its outline round it
#
# A mod is found by its name or its id, case and spaces aside.
#==============================================================================

module Reloaded
  module ModIcons
    SIZE = 15
    GHOSTLY = [170, 100, 255].freeze     # Ghostly Possession's purple (its aura)
    DEBUG_GREY = [150, 150, 160].freeze   # Kanto Reloaded Debug's grey

    @icons = {}
    @rings = {}

    class << self
      def register(name, options = {})
        icon = { :ball => options[:ball], :outline => options[:outline] }
        ([name] + Array(options[:ids])).each { |k| @icons[key(k)] = icon }
        return icon
      end

      def for(name)
        return nil if name.nil?
        return @icons[key(name)]
      end

      # The ball at x, y (its top left), the outline a pixel round it
      def draw(b, x, y, icon, size = SIZE)
        if icon[:outline]
          col = Color.new(*icon[:outline])
          ring(size).each { |dx, dy, w| b.fill_rect(x + dx, y + dy, w, 1, col) }
        end
        Reloaded::Pixel.poke_ball(b, x, y, size, icon[:ball])
      end

      private

      def key(name)
        return name.to_s.downcase.delete(" _-")
      end

      # Every pixel next to the ball (corners too) and not in it, as runs
      # [dx, dy, width] on each row: each pixel set once
      def ring(size)
        return @rings[size] if @rings[size]
        ball = {}
        size.times { |y| size.times { |x| ball[[x, y]] = true if Reloaded::Pixel.send(:ball_pixel, x, y, size) } }
        out = {}
        ball.each_key do |(x, y)|
          (-1..1).each { |dx| (-1..1).each { |dy| out[[x + dx, y + dy]] = true unless ball[[x + dx, y + dy]] } }
        end
        runs = []
        out.keys.group_by { |(_x, y)| y }.each do |y, pts|
          xs = pts.map(&:first).sort
          start = xs.first
          prev = start
          xs.drop(1).each do |x|
            next prev = x if x == prev + 1
            runs << [start, y, prev - start + 1]
            start = prev = x
          end
          runs << [start, y, prev - start + 1]
        end
        return @rings[size] = runs
      end
    end

    register("Ghostly Possession", :ids => ["GhostlyPossession"], :ball => GHOSTLY, :outline => GHOSTLY)
    register("Kanto Reloaded Debug", :ids => ["KantoReloadedDebug", "KR Debug"], :ball => DEBUG_GREY)
  end
end
