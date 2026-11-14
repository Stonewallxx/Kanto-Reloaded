# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Weather System
#==============================================================================
# Roadmap topic 22 (rules decided and every screen picked 2026-11-13, built
# in 8 stages the same day): weather that moves across the region and lasts,
# in place of each map rolling its own when you walk in (PIF's Kanto). This
# file is the weather itself; the rest of Core/Weather builds on it: Battle
# (the weather in battle), Encounters (its Pokémon), Display and Screens (the
# Forecast, the menus, the Fly map), Alerts, Sounds, FieldMoves, Records,
# Rainbow, Strikes and Multiplayer.
#
#   switch       per save, On by default, in its own Weather System section;
#                Off gives each map its own roll again, as the game does
#   the cycle    Slow / Normal / Fast: the whole region steps every 12 / 6 /
#                3 hours of the game's clock (1 game hour is a real minute of
#                play; the clock stops in menus and while the game is closed)
#   the weather  now and next, saved, so a reload never rolls it again
#                (Places.rb: where; Fronts.rb: how it moves)
#   the map      outdoors, your place's weather (grown at 8+ into Heavy Rain,
#                a Blizzard, Strong Winds; no sun after dark, his pick);
#                a map whose own weather always happens keeps it; weather a
#                story script sets wins until you leave the map
#   other code   PIF's own weather code (its fog, wind-blown trees, Hoenn
#                Native Overworld's Pokémon) reads it through $game_weather,
#                and Hoenn Essentials' weather stands aside while this is On
#                (Link.rb)
#
# Its data (SaveStore section "weather"): "now" and "next" snapshots (see
# Fronts.rb), "next_at" (the game clock's second the next cycle comes),
# "cycle" (how many have passed) and "seed".
#==============================================================================

module Reloaded
  module Weather
    FEATURE = :weather_system
    PAGE = :weather_system
    SECTION = "weather"
    CYCLE_HOURS = [12, 6, 3].freeze      # Slow, Normal, Fast
    CATCH_UP = 4                         # most cycles caught up at once (the Time Changer, a long sleep)
    CHECK_EVERY = 40                     # frames between clock checks on the map
    GROWN = { :Rain => :HeavyRain, :Snow => :Blizzard, :Wind => :StrongWinds }.freeze
    NAMES = { :Rain => "Rain", :Storm => "Storm", :Sunny => "Sunny", :Fog => "Fog", :Snow => "Snow", :Wind => "Wind",
              :Ash => "Ash", :Sandstorm => "Sandstorm", :HeavyRain => "Heavy Rain", :Blizzard => "Blizzard",
              :StrongWinds => "Strong Winds", :None => "Clear" }.freeze

    @setting_weather = false
    @armed_map = nil
    @external_map = nil
    @shown_map = nil
    @frames = 0
    @version = 0

    class << self
      attr_reader :version

      def boot
        Reloaded::Features.register(FEATURE, :name => "Weather System", :core => true, :order => 51,
          :description => "Weather that moves across the region, with a Forecast.") if defined?(Reloaded::Features)
        Reloaded::SaveStore.register(SECTION)
        register_settings if defined?(Reloaded::Settings)
        Reloaded::Events.on(:save_loaded, :weather_loaded, 60) { |_ctx| loaded }
        install
        Link.install if defined?(Link)
        Battle.install if defined?(Battle)
        Encounters.install if defined?(Encounters)
        Screens.install if defined?(Screens)
        Alerts.install if defined?(Alerts)
        FieldMoves.install if defined?(FieldMoves)
        Records.install if defined?(Records)
        Rainbow.install if defined?(Rainbow)
        Multiplayer.install if defined?(Multiplayer)
        return true
      end

      def key(id)
        return :"weather.#{id}"
      end

      # On for this save (the feature is a core part: its switch is per save)
      def on?
        return false unless Reloaded::Features.on?(FEATURE)
        return Reloaded::Settings.get(key(:enabled)) ? true : false
      rescue StandardError
        return false
      end

      def data
        return Reloaded::SaveStore.section(SECTION)
      rescue StandardError
        return nil
      end

      def cycle_seconds
        i = (Reloaded::Settings.get(key(:cycle)) rescue 1).to_i
        return (CYCLE_HOURS[i] || 6) * 3600
      end

      def clock
        return (defined?(pbGetTimeNow) ? pbGetTimeNow : Time.now).to_i
      end

      def season
        return defined?(pbGetSeason) ? pbGetSeason.to_i % 4 : 0
      rescue StandardError
        return 0
      end

      #------------------------------------------------------------------------
      # The weather: now, next, and the cycle
      #------------------------------------------------------------------------
      # The snapshots exist (a new save, or the first time it's switched on)
      def ensure_started
        d = data
        return nil unless d
        return d if d["now"].is_a?(Hash) && d["next"].is_a?(Hash) && d["next_at"]
        d["seed"] ||= rand(1 << 30)
        d["cycle"] ||= 0
        rng = Random.new(d["seed"].to_i)
        d["now"] = Fronts.first(Places, rng, season)
        d["next"] = Fronts.step(d["now"], Places, rng, season)
        d["next_at"] = clock + cycle_seconds
        changed!
        return d
      end

      # Steps the weather when the game's clock has reached the next cycle
      # (a few at most at once). True when it stepped.
      def advance
        return false if defined?(Multiplayer) && Multiplayer.remote?   # a guest: the host's weather, their own waits
        d = ensure_started
        return false unless d
        now = clock
        return false if now < d["next_at"].to_i
        len = cycle_seconds
        steps = 0
        before = d["now"]
        while now >= d["next_at"].to_i && steps < CATCH_UP
          d["cycle"] = d["cycle"].to_i + 1
          d["now"] = d["next"]
          d["next"] = Fronts.step(d["now"], Places, Random.new(d["seed"].to_i ^ d["cycle"].to_i * 7919), season)
          d["next_at"] = d["next_at"].to_i + len
          steps += 1
        end
        d["next_at"] = now + len if now >= d["next_at"].to_i
        changed!
        Reloaded::Events.emit(:weather_cycled, :steps => steps, :before => before) if defined?(Reloaded::Events)
        return true
      end

      # A Field Weather Move: the place's weather now (type nil or :None
      # clears it), and its next from the fronts, as if it had always been
      # there (the rest of the region's next stays as it was)
      def set_by_move(key, type, n)
        d = ensure_started
        return false unless d && key
        if type.nil? || type.to_s.to_sym == :None
          d["now"].delete(key)
        else
          d["now"][key] = [type.to_s, n.to_i]
        end
        rng = Random.new(d["seed"].to_i ^ (d["cycle"].to_i * 7919) ^ Zlib.crc32(key.to_s))
        stepped = Fronts.step(d["now"], Places, rng, season)
        if stepped[key]
          d["next"][key] = stepped[key]
        else
          d["next"].delete(key)
        end
        changed!
        show_on_map(true)
        Link.fog_changed($game_map.map_id) if defined?($game_map) && $game_map
        Sounds.update if defined?(Sounds)
        return true
      end

      # Seconds of game time until the weather next changes
      def seconds_left
        return Multiplayer.seconds_left if defined?(Multiplayer) && Multiplayer.remote?
        d = data
        return 0 unless d && d["next_at"]
        return [d["next_at"].to_i - clock, 0].max
      end

      def changed!
        @version += 1
      end

      # The seed of the save's weather (a guest's: the host's, for the same
      # Visitors)
      def seed
        s = defined?(Multiplayer) ? Multiplayer.seed : nil
        return s || (data || {})["seed"].to_i
      end

      # A place's weather: [type, strength] now (or next), or nil when clear
      def at(key, which = "now")
        d = data
        return nil unless d && key
        snap = (defined?(Multiplayer) && Multiplayer.snap(which)) || d[which]
        w = snap.is_a?(Hash) ? snap[key] : nil
        return w ? [w[0].to_sym, w[1].to_i] : nil
      end

      # The weather as it shows: grown at 8+, no sun after dark
      def shown_type(type, n, time = nil)
        type = type.to_sym
        type = GROWN[type] if n.to_i >= 8 && GROWN[type]
        return :None if [:Sunny].include?(type) && dark?(time)
        return type
      end

      def dark?(time = nil)
        return false unless defined?(::PBDayNight)
        return ::PBDayNight.isNight?(time) || ::PBDayNight.isEvening?(time)
      rescue StandardError
        return false
      end

      # A map's weather as it shows now: [type, strength], or nil (not ours,
      # or clear)
      def map_weather(map_id)
        key = Places.of_map(map_id)
        w = at(key)
        return nil unless w
        t = shown_type(w[0], w[1])
        return t == :None ? nil : [t, w[1]]
      end

      #------------------------------------------------------------------------
      # The map
      #------------------------------------------------------------------------
      # Puts the place's weather on the map (fade: over a moment, as when the
      # weather changes while you're there)
      def show_on_map(fade = false)
        return unless on? && defined?($game_map) && $game_map && defined?($game_screen) && $game_screen
        map = $game_map.map_id
        return if @external_map == map
        return if Places.fixed_weather(map)
        return unless Places.of_map(map)
        w = map_weather(map)
        type, n = w || [:None, 0]
        @setting_weather = true
        $game_screen.weather(type, n, fade ? 20 : 0)
        @shown_map = map
        @shown = w
        @armed_map = map
      ensure
        @setting_weather = false
      end

      # A map change: a new map's script hasn't set weather yet
      def map_changed
        @external_map = nil
        @armed_map = nil
        Link.sync
        unless on?
          Sounds.update if defined?(Sounds)
          return
        end
        advance
        show_on_map(false)
        Link.fog_arrived($game_map.map_id) if $game_map
        Sounds.update if defined?(Sounds)
        Rainbow.update_view if defined?(Rainbow)
      rescue StandardError => e
        Reloaded::Log.exception("Weather: the map's weather couldn't be set", e, :weather)
      end

      # Every few frames on the map: a cycle that's come, or a map not shown yet
      def tick
        @frames += 1
        Strikes.frame if defined?(Strikes) && Strikes.spot
        Rainbow.frame if defined?(Rainbow) && Rainbow.shown?
        return unless @frames % CHECK_EVERY == 0
        Link.sync
        Sounds.update if defined?(Sounds)
        return unless on?
        Multiplayer.frame if defined?(Multiplayer)
        stepped = advance
        map = $game_map ? $game_map.map_id : nil
        if stepped
          show_on_map(true)
          Link.fog_changed(map) if map
        elsif map && map != @shown_map
          show_on_map(false)
          Link.fog_arrived(map)
        elsif map && @external_map != map && map_weather(map) != @shown
          # the sun setting (or rising) while you're here
          show_on_map(true)
          Link.fog_changed(map)
        end
        Rainbow.update_view if defined?(Rainbow)
        Strikes.check if defined?(Strikes)
      rescue StandardError => e
        Reloaded::Log.exception("Weather: the weather couldn't update", e, :weather)
      end

      # Someone else set this map's weather (a story script): theirs stands
      # until you leave
      def note_weather_call
        return if @setting_weather
        map = $game_map ? $game_map.map_id : nil
        @external_map = map if map && map == @armed_map
      end

      # A story script's weather stands on this map
      def external?(map_id)
        return map_id && @external_map == map_id ? true : false
      end

      def loaded
        @shown_map = nil
        @external_map = nil
        @armed_map = nil
        changed!
      end

      private

      def register_settings
        s = Reloaded::Settings
        s.register_page(PAGE, :group => :general, :name => "Weather System", :icon => :features, :priority => 50.5,
          :description => "Weather that moves across the region and lasts, with seasons and a Forecast.")
        s.register(key(:enabled), :page => PAGE, :priority => 10, :type => :toggle, :default => true, :scope => :save,
          :name => "Weather System",
          :description => "Weather moves between places, changes over time and follows the seasons. Off: Each map rolls its own weather when you arrive, as the game does.")
        s.register(key(:cycle), :page => PAGE, :priority => 20, :type => :enum, :default => 1, :scope => :save,
          :values => ["Slow", "Normal", "Fast"], :name => "Weather Changes", :needs => key(:enabled),
          :descriptions => ["Every 12 hours of the game's clock (12 minutes of play).",
                            "Every 6 hours of the game's clock (6 minutes of play).",
                            "Every 3 hours of the game's clock (3 minutes of play)."],
          :description => "How often the weather changes across the region.")
        s.register(:"weather.alerts", :page => PAGE, :priority => 30, :type => :toggle, :default => true,
          :name => "Weather Alerts", :needs => key(:enabled),
          :description => "A short notice when the weather changes where you are, and when Heavy Rain, a Blizzard or Strong Winds is coming.")
        s.register(:"weather.sounds", :page => PAGE, :priority => 40, :type => :toggle, :default => true,
          :name => "Weather Sounds", :needs => key(:enabled),
          :description => "Rain, storms and thunder you can hear outdoors.")
      end

      def install
        return if @installed
        @installed = true
        if defined?(::Events) && ::Events.respond_to?(:onMapChange)
          ::Events.onMapChange += proc { |_sender, _e| Reloaded::Weather.map_changed }
          ::Events.onMapUpdate += proc { |_sender, _e| Reloaded::Weather.tick } if ::Events.respond_to?(:onMapUpdate)
        end
        return unless defined?(::Game_Screen)
        Reloaded::Hooks.around(FEATURE, ::Game_Screen, :weather, :id => :weather_calls) do |original, *args|
          Reloaded::Weather.note_weather_call
          original.call(*args)
        end
      end
    end
  end
end
