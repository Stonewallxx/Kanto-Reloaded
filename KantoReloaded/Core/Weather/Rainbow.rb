# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Weather System, Rainbows
#==============================================================================
# Stage 7 (his pick, 2026-11-13: Design 1, Sky Arc). When the rain (or a
# storm) clears by day, the place gets a rainbow for 3 hours of the game's
# clock (3 minutes of play): the Forecast shows it, Weather Visitors of the
# rain come there twice as often as in light rain, and on its maps a
# see-through pixel rainbow arcs across the top of the screen (2 x 2 blocks,
# 7 bands, fading toward the horizon), fading in over a moment. Seen as it
# appears, the toast says so: "A Rainbow Appeared" (with Weather Alerts On).
# It goes at dusk, when weather comes back, or when its time is up.
#==============================================================================

module Reloaded
  module Weather
    module Rainbow
      HOURS = 3
      BANDS = [[232, 64, 64], [248, 152, 48], [248, 216, 64], [88, 192, 96], [72, 136, 232], [120, 96, 220], [176, 96, 216]].freeze
      CX = 256                   # the arc: its centre (below the screen), outer radius, band width
      CY = 560
      RADIUS = 520
      BAND = 6
      HORIZON = 300              # it fades out toward here
      ALPHA = 150
      FADE_FRAMES = 72           # 1.2 seconds in
      RAINY = [:Rain, :Storm].freeze

      class << self
        def install
          return if @installed
          @installed = true
          Reloaded::Events.on(:weather_cycled, :weather_rainbows, 40) { |ctx| cycled(ctx) } if defined?(Reloaded::Events)
        end

        def table
          return Multiplayer.rainbows if defined?(Multiplayer) && Multiplayer.remote?
          d = Reloaded::Weather.data
          return nil unless d
          return (d["rainbows"] ||= {})
        end

        # A rainbow at a place now (by day, the sky clear, its time not up)
        def at?(key)
          t = table
          e = t && key ? t[key] : nil
          return false unless e
          return false if Reloaded::Weather.clock >= e[0].to_i
          return false if Reloaded::Weather.dark?
          return Reloaded::Weather.at(key).nil?
        end

        # The rain's kind it follows (its Visitors), or nil
        def rain_of(key)
          return nil unless at?(key)
          return table[key][1].to_s.to_sym
        end

        # Visitors under a rainbow come twice as often
        def visitor_boost(key)
          return key && at?(key) ? 2.0 : 1.0
        end

        # After a cycle: rain that cleared by day leaves a rainbow; old ones go
        def cycled(ctx)
          t = table
          return unless t
          before = ctx.is_a?(Hash) ? ctx[:before] : nil
          now = Reloaded::Weather.clock
          t.delete_if { |k, e| now >= e[0].to_i || Reloaded::Weather.at(k) }
          return if Reloaded::Weather.dark? || !before.is_a?(Hash)
          here = Alerts.place_here
          before.each do |key, (type, _n)|
            next unless RAINY.include?(type.to_s.to_sym) && Reloaded::Weather.at(key).nil? && Places[key]
            t[key] = [now + HOURS * 3600, "Rain"]
            toast(key) if key == here
          end
        rescue StandardError => e
          Reloaded::Log.exception("Weather: a rainbow couldn't be made", e, :weather)
        end

        def toast(key)
          return unless Alerts.on? && defined?(Reloaded::Toast)
          words = _INTL("{1}: Visitors twice as likely", Places[key].name)
          Reloaded::Toast.queue do
            Reloaded::Toast.show(_INTL("A Rainbow Appeared"), :icon => Display.icon(:Rainbow, 1), :icon_size => 32, :sub => words)
          end
        end

        #----------------------------------------------------------------------
        # The arc on the screen
        #----------------------------------------------------------------------
        # Every few frames on the map: shown on a rainbow's place outdoors
        def update_view
          key = Alerts.place_here
          want = key && at?(key) && outdoors?
          @want = want ? true : false
          make if @want && !(@sprite && !@sprite.disposed?)
        rescue StandardError => e
          Reloaded::Log.warning_once("Weather: the rainbow couldn't show (#{e.class})", :weather)
        end

        # Every frame while it's up: fading in or out
        def frame
          return unless @sprite && !@sprite.disposed?
          step = 255.0 / FADE_FRAMES
          @alpha = @want ? [@alpha.to_f + step, 255.0].min : [@alpha.to_f - step, 0.0].max
          @sprite.opacity = @alpha.round
          dispose if !@want && @alpha <= 0
        end

        def outdoors?
          meta = (::GameData::MapMetadata.try_get($game_map.map_id) rescue nil)
          return meta && meta.outdoor_map ? true : false
        end

        def make
          @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
          @viewport.z = 150
          @sprite = Sprite.new(@viewport)
          @sprite.bitmap = arc_bitmap
          @sprite.opacity = 0
          @alpha = 0.0
        end

        def dispose
          @sprite.dispose if @sprite && !@sprite.disposed?
          @viewport.dispose if @viewport && !@viewport.disposed?
          @sprite = @viewport = nil
        end

        def shown?
          return @sprite && !@sprite.disposed? ? true : false
        end

        # The rainbow, once (2 x 2 blocks, the game's pixel scale)
        def arc_bitmap
          return @arc if @arc && !@arc.disposed?
          b = Bitmap.new(512, 384)
          inner = RADIUS - BAND * BANDS.length
          (0...HORIZON).step(2) do |y|
            fade = [[(HORIZON - y) / 80.0, 1.0].min, 0.0].max
            a = (ALPHA * fade).to_i
            next if a <= 0
            dy = y + 1 - CY
            next if dy.abs >= RADIUS
            half_out = Math.sqrt(RADIUS * RADIUS - dy * dy)
            half_in = dy.abs < inner ? Math.sqrt(inner * inner - dy * dy) : 0
            [[CX - half_out, CX - half_in], [CX + half_in, CX + half_out]].each do |from, to|
              x = (from.floor / 2) * 2
              while x < to
                d = Math.hypot(x + 1 - CX, dy)
                if d >= inner && d < RADIUS
                  c = BANDS[[((RADIUS - d) / BAND).to_i, 6].min]
                  b.fill_rect(x, y, 2, 2, Color.new(c[0], c[1], c[2], a))
                end
                x += 2
              end
            end
          end
          @arc = b
          return b
        end
      end
    end
  end
end
