# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Weather System, Rainbows
#==============================================================================
# Stage 7 (his pick, 2026-11-13: Design 1, Sky Arc). When the rain (or a
# storm) clears by day, the place gets a rainbow for 3 hours of the game's
# clock (3 minutes of play): the Forecast shows it, Weather Visitors of the
# rain come there twice as often as in light rain, and on its maps a
# see-through pixel rainbow stands in the world (his pick 2026-11-14, Sky
# Arc on the Map: 8 tiles wide, 2 x 2 blocks, 7 bands, its ends fading),
# a little north of where you are as it shows. It stays put in the world
# as you walk, onto the maps connected to its map too, as Ghostly
# Possession's lights do (his ask, 2026-11-14): drawn on the map's own
# layer, over the ground and under the characters and the treetops, sized
# with Map Zoom. Once its map is unloaded (you've gone far enough, or
# through a door) it's gone for good: the place keeps its rainbow (the
# Forecast, the Visitors) but no new arc rises. It fades in over a moment.
# Seen as it appears, the toast says so: "A Rainbow Appeared" (with Weather
# Alerts On). It goes at dusk, when weather comes back, or when its time is up.
#==============================================================================

module Reloaded
  module Weather
    module Rainbow
      HOURS = 3
      BANDS = [[232, 64, 64], [248, 152, 48], [248, 216, 64], [88, 192, 96], [72, 136, 232], [120, 96, 220], [176, 96, 216]].freeze
      RADIUS = 128               # the arc: 8 tiles wide, bands of 4 (his pick, 2026-11-14: Sky Arc, on the Map)
      BAND = 4
      BASE_FADE = 46             # its ends fade toward its base over this many pixels
      LIFT = 40                  # its base this far above the top of the tile it's anchored to
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
        # The arc on the map
        #----------------------------------------------------------------------
        # Every few frames on the map: a rainbow's place outdoors shows its arc
        # (once: its 4th part marks it gone for good); one up stays while its
        # map is loaded and the rainbow lasts
        def update_view
          if shown?
            @want = at?(@key) && loaded?(@anchor[0])
            return
          end
          key = Alerts.place_here
          return unless key && at?(key) && outdoors? && !spent?(key)
          make(key)
        rescue StandardError => e
          Reloaded::Log.warning_once("Weather: the rainbow couldn't show (#{e.class})", :weather)
        end

        # Every frame while it's up: where its spot is on screen now (from
        # whichever connected map you're on), fading in or out; its map
        # unloaded, it's gone for good
        def frame
          return unless shown?
          unless loaded?(@anchor[0])
            spend
            dispose
            return
          end
          place
          step = 255.0 / FADE_FRAMES
          @alpha = @want ? [@alpha.to_f + step, 255.0].min : [@alpha.to_f - step, 0.0].max
          @sprite.opacity = @alpha.round
          dispose if !@want && @alpha <= 0
        rescue StandardError => e
          Reloaded::Log.warning_once("Weather: the rainbow couldn't move with the map (#{e.class})", :weather)
          dispose
        end

        # The game has this map loaded (yours, or one connected and near)
        def loaded?(map_id)
          return true if $game_map && $game_map.map_id == map_id
          maps = defined?($MapFactory) && $MapFactory && $MapFactory.respond_to?(:maps) ? $MapFactory.maps : nil
          return Array(maps).compact.any? { |m| m.map_id == map_id }
        rescue StandardError
          return false
        end

        def spent?(key)
          e = table ? table[key] : nil
          return e.is_a?(Array) && e[3] == true
        end

        def spend
          e = @key && table ? table[@key] : nil
          e[3] = true if e.is_a?(Array)
        end

        def outdoors?
          meta = (::GameData::MapMetadata.try_get($game_map.map_id) rescue nil)
          return meta && meta.outdoor_map ? true : false
        end

        def scale
          return 1.0 unless defined?(::KIF::MapZoom) && ::KIF::MapZoom.respond_to?(:scale)
          s = ::KIF::MapZoom.scale.to_f
          return s > 0 ? s : 1.0
        rescue StandardError
          return 1.0
        end

        # On the map's own layer (over the ground, under the characters and
        # the treetops), anchored a little north of where you stand
        def make(key)
          @key = key
          @anchor = [$game_map.map_id, $game_player.x, $game_player.y]
          vp = defined?(::Spriteset_Map) && ::Spriteset_Map.respond_to?(:viewport) ? ::Spriteset_Map.viewport : nil
          @own_viewport = nil
          unless vp && !vp.disposed?
            vp = @own_viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
            vp.z = 1
          end
          @sprite = Sprite.new(vp)
          @sprite.bitmap = arc_bitmap
          @sprite.ox = @sprite.bitmap.width / 2
          @sprite.oy = @sprite.bitmap.height
          @sprite.z = 1
          @alpha = 0.0
          @sprite.opacity = 0
          @want = true
          place
        end

        # Its base on screen: the anchor tile's middle, LIFT pixels above its top
        def place
          k = scale
          sx, sy = anchor_xy
          @sprite.x = sx
          @sprite.y = sy - ((32 + LIFT) * k).round
          @sprite.zoom_x = @sprite.zoom_y = k
        end

        # The anchor tile on screen: [its middle, its bottom], from the map
        # you're on (the anchor's map, or one connected to it: the game's
        # connection offsets), as Ghostly Possession places its lights (a
        # Normal-size screen spot, Map Zoom's scale times it)
        def anchor_xy
          m = $game_map
          ax = @anchor[1]
          ay = @anchor[2]
          if m.map_id != @anchor[0] && defined?($MapFactory) && $MapFactory
            ax, ay = $MapFactory.getRelativePos(m.map_id, 0, 0, @anchor[0], ax, ay)
          end
          k = scale
          sx = (((ax * 128 - m.display_x) / 4.0).round + 16) * k
          sy = (((ay * 128 - m.display_y) / 4.0).round + 32) * k
          return [sx.round, sy.round]
        end

        def dispose
          @sprite.dispose if @sprite && !@sprite.disposed?
          @own_viewport.dispose if @own_viewport && !@own_viewport.disposed?
          @sprite = @own_viewport = nil
        end

        def shown?
          return @sprite && !@sprite.disposed? ? true : false
        end

        # The rainbow, once: 2 x 2 blocks (the game's pixel scale), its ends
        # fading toward its base
        def arc_bitmap
          return @arc if @arc && !@arc.disposed?
          w = RADIUS * 2 + 4
          h = RADIUS + 4
          b = Bitmap.new(w, h)
          inner = RADIUS - BAND * BANDS.length
          cx = w / 2
          (0...h).step(2) do |y|
            fade = [[(h - y) / BASE_FADE.to_f, 1.0].min, 0.0].max
            a = (ALPHA * fade).to_i
            next if a <= 0
            dy = y + 1 - h
            (0...w).step(2) do |x|
              d = Math.hypot(x + 1 - cx, dy)
              next unless d >= inner && d < RADIUS
              c = BANDS[[((RADIUS - d) / BAND).to_i, 6].min]
              b.fill_rect(x, y, 2, 2, Color.new(c[0], c[1], c[2], a))
            end
          end
          @arc = b
          return b
        end
      end
    end
  end
end
