# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Weather System, Lightning Strikes
#==============================================================================
# Stage 7 (his pick, 2026-11-13: Design 1, Bolt and Sparkle). Now and then
# in a storm (a few minutes of play apart, on average), lightning strikes a
# tile near you: the game's own bolt (Graphics/Weather/lightning) lands on
# it, the screen flashes white, the short snap of thunder (SE Thunder3, his
# pick). A twinkling sparkle stays on that tile; step on it for what the
# strike left: a hidden item (a Thunder Stone now and then, else a Cell
# Battery or a Magnet) or an Electric Visitor at the place's levels. No toast.
# The sparkle goes when you leave the map. Placed on the map as the
# game places its characters, so Map Zoom moves it with them.
#==============================================================================

module Reloaded
  module Weather
    module Strikes
      CHANCE = 4                     # in 1000, each check (40 frames) in a storm: one every 3 minutes or so
      OFFSETS = [[2, -1], [-2, -1], [2, 1], [-2, 1], [1, -2], [-1, -2], [3, 0], [-3, 0]].freeze
      ITEMS = [[:THUNDERSTONE, 2], [:CELLBATTERY, 4], [:MAGNET, 4]].freeze
      BOLT = "Graphics/Weather/lightning"
      TIP = [200, 399]               # the bolt's tip in its picture
      BOLT_STEPS = [255, 255, 180, 110, 50].freeze     # its fade, a step each 6 frames
      FLASH = 170
      SE = "Thunder3"
      CREAM = Color.new(255, 248, 200)
      WHITE = Color.new(255, 255, 255)

      class << self
        attr_reader :spot

        # Every few frames on the map: a strike now and then in a storm
        def check
          return unless Reloaded::Weather.on? && defined?($game_map) && $game_map && $game_player
          return if @spot || @anim
          return unless storm_here?
          return unless rand(1000) < CHANCE
          strike!
        rescue StandardError => e
          Reloaded::Log.warning_once("Weather: a lightning strike couldn't happen (#{e.class})", :weather)
        end

        def storm_here?
          return false unless defined?($game_screen) && $game_screen && $game_screen.weather_type == :Storm
          meta = (::GameData::MapMetadata.try_get($game_map.map_id) rescue nil)
          return meta && meta.outdoor_map ? true : false
        end

        # A tile near you to strike: free to stand on, nothing on it
        def target
          px = $game_player.x
          py = $game_player.y
          OFFSETS.each do |dx, dy|
            x = px + dx
            y = py + dy
            next unless $game_map.valid?(x, y)
            next unless [2, 4, 6, 8].any? { |d| $game_map.passable?(x, y, d) }
            next if $game_map.events.values.any? { |e| e.x == x && e.y == y && !e.instance_variable_get(:@erased) }
            return [x, y]
          end
          return nil
        end

        def strike!(at = nil)
          xy = at || target
          return false unless xy
          @spot = { :map => $game_map.map_id, :x => xy[0], :y => xy[1], :reward => rand(2) == 0 ? :item : :visitor }
          pbSEPlay(SE, 90) if defined?(pbSEPlay)
          $game_screen.start_flash(Color.new(255, 255, 255, FLASH), 18) if $game_screen.respond_to?(:start_flash)
          make_sprites
          @anim = 0
          Reloaded::Events.emit(:weather_strike, :spot => @spot) if defined?(Reloaded::Events)
          return true
        rescue StandardError => e
          clear
          Reloaded::Log.warning_once("Weather: a lightning strike couldn't be drawn (#{e.class})", :weather)
          return false
        end

        # Every frame: the bolt fading, the sparkle twinkling, stepping on it
        def frame
          return unless @spot
          if $game_map.nil? || $game_map.map_id != @spot[:map]
            clear
            return
          end
          @tick = (@tick || 0) + 1
          place
          if @anim
            i = @anim / 6
            if i < BOLT_STEPS.length
              @bolt.opacity = BOLT_STEPS[i] if @bolt && !@bolt.disposed?
            else
              @bolt.dispose if @bolt && !@bolt.disposed?
              @bolt = nil
              @anim = nil
            end
            @anim += 1 if @anim
          end
          if @sparkle && !@sparkle.disposed?
            @sparkle.visible = @anim.nil? || @anim >= 18
            @sparkle.bitmap = sparkle_bitmap((@tick / 6) % 3)
          end
          collect if on_spot?
        rescue StandardError => e
          Reloaded::Log.warning_once("Weather: the strike's sparkle couldn't update (#{e.class})", :weather)
        end

        def on_spot?
          return false unless @anim.nil? && $game_player.x == @spot[:x] && $game_player.y == @spot[:y]
          return false if $game_player.respond_to?(:moving?) && $game_player.moving?
          return false if $game_temp && ($game_temp.respond_to?(:message_window_showing) && $game_temp.message_window_showing)
          interp = $game_system && $game_system.respond_to?(:map_interpreter) ? $game_system.map_interpreter : nil
          return false if interp && interp.respond_to?(:running?) && interp.running?
          return true
        end

        # What the strike left: an item, or an Electric Visitor's battle
        def collect
          reward = @spot[:reward]
          key = Places.of_map(@spot[:map])
          clear
          if reward == :visitor && (sp = electric_visitor(key))
            pbWildBattle(sp[0], sp[1]) if defined?(pbWildBattle)
          else
            item = pick_item
            if item && defined?(pbItemBall)
              pbItemBall(item)
            elsif item && defined?($PokemonBag) && $PokemonBag
              $PokemonBag.pbStoreItem(item)
            end
          end
        rescue StandardError => e
          Reloaded::Log.exception("Weather: what the lightning left couldn't be given", e, :weather)
        end

        def pick_item
          list = ITEMS.select { |id, _w| (::GameData::Item.exists?(id) rescue false) }
          return nil if list.empty?
          r = rand(list.sum { |_id, w| w })
          list.each do |id, w|
            return id if r < w
            r -= w
          end
          return list.last[0]
        end

        # [species, level]: an Electric Pokémon at home here, at the place's
        # levels (a Weather Visitor of the storm, else any Electric one)
        def electric_visitor(key)
          en = Encounters
          list = key ? en.visitors(key, :Storm, :land) : []
          elec = list.select { |sp| (d = ::GameData::Species.try_get(sp)) && [d.type1, d.type2].include?(:ELECTRIC) }
          lvl = level_here(key)
          if elec.empty?
            pool = en.candidates.map { |sp| en.stage_for(sp, lvl) }
            pool = pool.select { |sp| (d = ::GameData::Species.try_get(sp)) && [d.type1, d.type2].include?(:ELECTRIC) }
            return nil if pool.empty?
            return [pool[rand(pool.length)], lvl]
          end
          return [elec[rand(elec.length)], lvl]
        end

        def level_here(key)
          pl = key ? Places[key] : nil
          lists = pl ? Encounters.place_lists(pl, Encounters.encounter_mode, :land) : []
          return 10 if lists.empty?
          lo = lists.map { |e| e[2].to_i }.min
          hi = lists.map { |e| e[3].to_i }.max
          return lo + rand(hi - lo + 1)
        end

        #----------------------------------------------------------------------
        # The bolt and the sparkle
        #----------------------------------------------------------------------
        def scale
          return 1.0 unless defined?(::KIF::MapZoom) && ::KIF::MapZoom.respond_to?(:scale)
          s = ::KIF::MapZoom.scale.to_f
          return s > 0 ? s : 1.0
        rescue StandardError
          return 1.0
        end

        # The tile's middle on screen, as the game places a character there
        def tile_xy
          @marker ||= ::Game_Character.new($game_map)
          @marker.moveto(@spot[:x], @spot[:y]) if @marker.x != @spot[:x] || @marker.y != @spot[:y]
          return [@marker.screen_x, @marker.screen_y - (16 * scale).round]
        end

        def make_sprites
          @viewport ||= Viewport.new(0, 0, Graphics.width, Graphics.height)
          @viewport.z = 160
          @marker = nil
          k = scale
          @bolt = Sprite.new(@viewport)
          @bolt.bitmap = (Bitmap.new(BOLT) rescue nil)
          @bolt.ox = TIP[0]
          @bolt.oy = TIP[1]
          @bolt.zoom_x = @bolt.zoom_y = k
          @sparkle = Sprite.new(@viewport)
          @sparkle.bitmap = sparkle_bitmap(0)
          @sparkle.ox = 12
          @sparkle.oy = 12
          @sparkle.zoom_x = @sparkle.zoom_y = k
          @sparkle.visible = false
          @tick = 0
          place
        end

        def place
          sx, sy = tile_xy
          [@bolt, @sparkle].each do |s|
            next unless s && !s.disposed?
            s.x = sx
            s.y = sy
          end
        end

        # A 4-point sparkle, cream, its size one of three (it twinkles)
        def sparkle_bitmap(i)
          @sparkles ||= []
          return @sparkles[i] if @sparkles[i] && !@sparkles[i].disposed?
          b = Bitmap.new(24, 24)
          s = 3 + i
          c = 12
          b.fill_rect(c - 1, c - s * 2, 2, s * 4 + 1, CREAM)
          b.fill_rect(c - s * 2, c - 1, s * 4 + 1, 2, CREAM)
          b.fill_rect(c - 2, c - 2, 4, 4, WHITE)
          @sparkles[i] = b
          return b
        end

        def clear
          [@bolt, @sparkle].each { |s| s.dispose if s && !s.disposed? }
          @bolt = @sparkle = nil
          @viewport.dispose if @viewport && !@viewport.disposed?
          @viewport = nil
          @spot = nil
          @anim = nil
          @marker = nil
        end
      end
    end
  end
end
