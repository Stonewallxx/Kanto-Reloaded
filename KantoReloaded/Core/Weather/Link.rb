# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Weather System, the link to the game's own weather code
#==============================================================================
# PIF has weather code of its own that only wakes up when $game_weather is
# there (in Hoenn): its drifting fog (Overworld_Fog.rb), trees blowing in the
# wind (the tilemap), the Fly map's weather layer, Feebas in the rain, and
# the Hoenn overworld Pokémon that Hoenn Native Overworld brings to Kanto
# (storms make them slower to notice you, fog shortens their sight, wind,
# rain and sun change how they roam, Castform takes the weather's form).
# While the Weather System is On, $game_weather is a link that answers all of
# them from Kanto Reloaded's weather; Off, it goes again.
#
# PIF's Hoenn weather update (update_overworld_weather and its sounds, run on
# every map change once $game_weather is there) stands aside: Kanto
# Reloaded puts the weather on the map itself. Hoenn Essentials' own weather
# (its clock, its grey fog veil, its fog misses in battle) stands aside too
# while ours is On (his pick, 2026-11-13), and so do its Weather Visitors:
# Kanto Reloaded's own take over (Encounters.rb), the ones the Forecast shows.
#==============================================================================

module Reloaded
  module Weather
    module Link
      NONE = [:None, 0].freeze
      FAR = 100 * 365 * 86_400          # PIF's update never comes due

      # What PIF's code calls on $game_weather; anything else does nothing
      class GameWeatherLink
        def current_weather
          return Link.table
        end

        def get_map_weather_type(map_id = nil)
          return Link.table[(map_id || $game_map.map_id).to_i][0]
        end

        def get_map_weather_intensity(map_id = nil)
          return Link.table[(map_id || $game_map.map_id).to_i][1]
        end

        def get_current_map_weather
          w = Link.table[$game_map.map_id]
          return w.equal?(NONE) ? nil : w
        end

        def map_current_weather_type(map_id)
          w = Link.table[map_id.to_i]
          return w.equal?(NONE) ? nil : w[0]
        end

        def last_update_time
          return (defined?(pbGetTimeNow) ? pbGetTimeNow : Time.now) + FAR
        end

        # update_weather, try_spawn_new_weather, set_map_weather,
        # update_neighbor_map, print_current_weather... (Hoenn's own engine)
        def method_missing(*_args)
          return nil
        end

        def respond_to_missing?(*_args)
          return true
        end
      end

      # PIF's Hoenn weather update stands aside while ours is On
      module StandAside
        def update_overworld_weather(*args)
          return nil if Reloaded::Weather.on?
          return super
        end

        def set_weather_ambient_sounds(*args)
          return nil if Reloaded::Weather.on?
          return super
        end
      end

      # PIF's Hoenn overworld Pokémon (Hoenn Native Overworld brings them to
      # Kanto) work out their sight and how long they take to notice you
      # before they read the weather, and the fog check compares the fog's
      # strength with :Fog, so fog and storms never did anything (the old
      # prep's find). Done again once the weather is read: fog shortens their
      # sight (thick fog much more), a storm slows them by its strength.
      module OverworldWeather
        def setup_pokemon(*args)
          ret = super
          return ret unless Reloaded::Weather.on?
          if @weather_type_at_spawn == :Fog && @detection_radius
            ff = (@weather_level_at_spawn.to_i / 10.0) ** 2
            @detection_radius = [(@detection_radius * (1.0 - ff)).round, 1].max
          elsif @weather_type_at_spawn == :Storm && @nearby_notice_limit
            @nearby_notice_limit += @weather_level_at_spawn.to_i
          end
          return ret
        end
      end

      class << self
        def install
          @link = GameWeatherLink.new
          @table = nil
          @table_version = -1
          Reloaded::Hooks.prepend(FEATURE, Object, StandAside, :id => :weather_pif_update) if defined?(::Object)
          if defined?(::OverworldPokemonEvent)
            Reloaded::Hooks.prepend(FEATURE, ::OverworldPokemonEvent, OverworldWeather, :id => :weather_ow_pokemon)
          end
        end

        # { map id => [shown type, strength] } for every map with our weather
        # (others answer [:None, 0]). PIF's tilemap asks every frame, and twice
        # for each tile it redraws as you walk: the answer is kept, and the
        # game's clock (for sun after dark) read at most once a second
        RECHECK = 60
        def table
          v = Reloaded::Weather.version
          f = (::Graphics.frame_count rescue 0)
          return @table if @table && @table_version == v && @table_frame && (f - @table_frame).abs < RECHECK
          @table_frame = f
          if @table.nil? || @table_version != v || @table_hour != hour
            t = Hash.new(NONE)
            if Reloaded::Weather.on?
              Places.keys.each do |key|
                w = Reloaded::Weather.at(key)
                next unless w
                shown = Reloaded::Weather.shown_type(w[0], w[1])
                next if shown == :None
                Places[key].maps.each { |m| t[m] = [shown, w[1]] }
              end
            end
            @table = t
            @table_version = v
            @table_hour = hour
          end
          return @table
        end

        def hour
          return (defined?(pbGetTimeNow) ? pbGetTimeNow : Time.now).hour
        end

        # $game_weather is the link while ours is On (and gone when Off, unless
        # it's someone else's)
        def sync
          on = Reloaded::Weather.on?
          if on
            $game_weather = @link unless $game_weather.equal?(@link)
          elsif $game_weather.equal?(@link)
            $game_weather = nil
          end
          hook_hoenn_essentials if !@he_hooked && defined?(::HoennWeatherKIF)
        end

        # The fog fades in or out when it changes while you're on the map
        # (PIF's fog only fades as you arrive)
        def fog_changed(map)
          w = Reloaded::Weather.map_weather(map)
          now = w && w[0] == :Fog ? w[1] : 0
          was = @fog_shown || 0
          @fog_shown = now
          return if now == was
          sp = $scene.respond_to?(:spriteset) ? $scene.spriteset : nil
          sp.fade_in_fog(was, now) if sp && sp.respond_to?(:fade_in_fog)
        rescue StandardError => e
          Reloaded::Log.warning_once("Weather: the fog couldn't fade (#{e.class})", :weather)
        end

        def fog_arrived(map)
          w = Reloaded::Weather.map_weather(map)
          @fog_shown = w && w[0] == :Fog ? w[1] : 0
        end

        private

        # Hoenn Essentials' weather (Mods/hoenn_essentials 13_dynamic_weather.rb)
        # stands aside while ours is On: its clock and its showing, its fog
        # veil, its fog misses, its Weather Visitors (14_weather_visitors.rb),
        # its weather sharing in Multiplayer (27_multiplayer_weather.rb)
        def hook_hoenn_essentials
          @he_hooked = true
          he = ::HoennWeatherKIF.singleton_class
          Reloaded::Hooks.around(FEATURE, he, :tick, :id => :weather_he_tick) do |original, *args|
            Reloaded::Weather.on? ? nil : original.call(*args)
          end
          Reloaded::Hooks.around(FEATURE, he, :update_fog_overlay, :id => :weather_he_fog) do |original, *args|
            if Reloaded::Weather.on?
              ::HoennWeatherKIF.clear_fog_overlay rescue nil
              nil
            else
              original.call(*args)
            end
          end
          Reloaded::Hooks.around(FEATURE, he, :foggy_here?, :id => :weather_he_foggy) do |original, *args|
            Reloaded::Weather.on? ? false : original.call(*args)
          end
          if defined?(::HoennWeatherMultiplayer) && ::HoennWeatherMultiplayer.respond_to?(:frame)
            Reloaded::Hooks.around(FEATURE, ::HoennWeatherMultiplayer.singleton_class, :frame, :id => :weather_he_multiplayer) do |original, *args|
              Reloaded::Weather.on? ? nil : original.call(*args)
            end
          end
          if defined?(::HoennWeatherVisitors) && ::HoennWeatherVisitors.respond_to?(:entries)
            Reloaded::Hooks.around(FEATURE, ::HoennWeatherVisitors.singleton_class, :entries, :id => :weather_he_visitors) do |original, *args|
              Reloaded::Weather.on? ? [] : original.call(*args)
            end
          end
          Reloaded::Log.info("Weather: Hoenn Essentials' weather stands aside while the Weather System is On", :weather)
        end
      end
    end
  end
end
