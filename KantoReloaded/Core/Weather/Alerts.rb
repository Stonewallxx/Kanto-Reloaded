# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Weather System, the alerts
#==============================================================================
# Stage 5 (his picks, 2026-11-13: Design 1, Kanto Reloaded's Toast). When
# the weather changes across the region and your place's changes with it, a
# toast says so: the weather's 32 px icon, "Rain Started", and the place
# with the strength's word in gold ("Route 24, Moderate"). When Heavy Rain,
# a Blizzard or Strong Winds will reach your place next cycle, a heads-up:
# "Heavy Rain Coming", "Route 24, in 6m", a red HEADS UP pill. Silent (his
# sound pick: Kanto Reloaded's toasts make no sound), 3 seconds of real
# time, no pause. Weather Alerts (Kanto Reloaded > Weather System) switches
# them, On.
#==============================================================================

module Reloaded
  module Weather
    module Alerts
      SETTING = :"weather.alerts"
      TITLES = { :Rain => "Rain Started", :HeavyRain => "Heavy Rain Started", :Storm => "A Storm Rolled In",
                 :Sunny => "The Sun Came Out", :Fog => "Fog Rolled In", :Snow => "Snow Started",
                 :Blizzard => "A Blizzard Started", :Wind => "The Wind Picked Up", :StrongWinds => "Strong Winds Started",
                 :Ash => "Ash Started Falling", :Sandstorm => "A Sandstorm Started", :None => "The Weather Cleared" }.freeze
      COMING = { :HeavyRain => "Heavy Rain Coming", :Blizzard => "A Blizzard Coming", :StrongWinds => "Strong Winds Coming" }.freeze

      class << self
        def install
          return if @installed
          @installed = true
          Reloaded::Events.on(:weather_cycled, :weather_alerts, 50) { |ctx| cycled(ctx) } if defined?(Reloaded::Events)
        end

        def on?
          return Reloaded::Weather.on? && Reloaded::Settings.get(SETTING) ? true : false
        rescue StandardError
          return false
        end

        # Your place, when it's ours and showing (not a story's weather)
        def place_here
          return nil unless defined?($game_map) && $game_map
          map = $game_map.map_id
          return nil if Reloaded::Weather.external?(map)
          return Places.of_map(map)
        end

        # After a cycle: what changed at your place, and what's coming
        def cycled(ctx)
          return unless on?
          key = place_here
          return unless key
          before = ctx.is_a?(Hash) ? ctx[:before] : nil
          was = before.is_a?(Hash) && before[key] ? Reloaded::Weather.shown_type(before[key][0], before[key][1]) : :None
          now_t, now_n = Display.shown(key, "now")
          toasts = []
          toasts << change_toast(key, now_t, now_n) if now_t != was && now_t != :Rainbow
          coming = coming_type(key)
          toasts << coming_toast(key, coming) if coming && coming != now_t
          toasts.compact.each { |t| Reloaded::Toast.queue { show(t) } }
        rescue StandardError => e
          Reloaded::Log.exception("Weather: an alert couldn't be shown", e, :weather)
        end

        # Heavy Rain, a Blizzard or Strong Winds next cycle at your place
        def coming_type(key)
          nt, nn = Display.shown(key, "next")
          return COMING.key?(nt) && nn.to_i >= 8 ? nt : nil
        end

        def change_toast(key, type, n)
          name = Places[key] ? Places[key].name : ""
          word = Display.strength_word(type, n)
          sub = word.empty? ? name : _INTL("{1}, {2}", name, word)
          return [_INTL(TITLES[type] || "{1} Started", Display.name(type)), sub, Display.icon(type, n), nil]
        end

        def coming_toast(key, type)
          name = Places[key] ? Places[key].name : ""
          return [_INTL(COMING[type]), _INTL("{1}, in {2}", name, Display.in_words), Display.icon(type, 8), [_INTL("HEADS UP"), :red]]
        end

        def show(t)
          title, sub, icon, pill = t
          return Reloaded::Toast.show(title, :icon => icon, :icon_size => 32, :sub => sub, :pill => pill)
        end
      end
    end
  end
end
