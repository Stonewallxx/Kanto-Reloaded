# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Weather System, how the weather is shown
#==============================================================================
# What every weather screen shares (the Forecast, the Fly map's card, the
# Overworld Menu's row, the Pause Menu's tile, the alerts): each weather's
# name, colour and icon, the strength's word, the season, and the time until
# the weather changes.
#
# The icons: old Kanto Reloaded's 32 px set (PIF's own map icons), PIF's
# Wind and Ash from the same set (his pick, 2026-11-13: he's having others
# made, on the To-Do), and a new Rainbow. They ship in Graphics/Pictures/
# Weather, where PIF's own weather code looks for them too.
#==============================================================================

module Reloaded
  module Weather
    module Display
      DIR = "Graphics/Pictures/Weather/"
      COLOURS = { :Rain => [90, 160, 250], :Storm => [250, 200, 60], :Sunny => [250, 150, 40], :Fog => [176, 186, 206],
                  :Snow => [140, 210, 250], :Wind => [110, 220, 160], :Ash => [170, 150, 150], :Sandstorm => [222, 178, 96],
                  :Rainbow => [236, 96, 200], :None => [150, 160, 175] }.freeze
      # a grown weather is drawn in its own weather's colour
      BASE = { :HeavyRain => :Rain, :Blizzard => :Snow, :StrongWinds => :Wind }.freeze
      # icons with one picture for every strength
      ONE_ICON = { :Snow => "mapSnow", :Blizzard => "mapBlizzard", :HeavyRain => "mapHeavyRain", :StrongWinds => "mapStrongWinds",
                   :Ash => "mapAsh", :Sandstorm => "mapSand", :Rainbow => "mapRainbow", :None => "mapClear" }.freeze
      LEVELED = { :Rain => "mapRain", :Storm => "mapStorm", :Fog => "mapFog", :Sunny => "mapSun", :Wind => "mapWind" }.freeze
      SEASONS = [["Spring", [250, 140, 190]], ["Summer", [250, 204, 60]], ["Autumn", [240, 160, 60]], ["Winter", [140, 210, 250]]].freeze
      # 4 x 5 pixel marks for the season's chip (Autumn's leaf is the picked one)
      SEASON_MARKS = [[".#.#", "####", ".##.", "####", ".#.#"],     # a blossom
                      ["#..#", ".##.", "####", ".##.", "#..#"],     # a sun
                      ["..##", ".###", "###.", "#.#.", "#..."],     # a leaf
                      ["#.#.", ".#..", "####", ".#..", "#.#."]].freeze  # a snowflake

      module_function

      def base(type)
        t = type.to_s.to_sym
        return BASE[t] || t
      end

      def name(type)
        t = type.to_s.to_sym
        return _INTL(Reloaded::Weather::NAMES[t] || t.to_s)
      end

      def rgb(type)
        return COLOURS[base(type)] || COLOURS[:None]
      end

      def colour(type)
        return Color.new(*rgb(type))
      end

      # The weather's word for its strength (none for clear weather)
      def strength_word(type, n)
        return "" if type.nil? || type.to_s.to_sym == :None || type.to_s.to_sym == :Rainbow
        n = n.to_i
        return n >= 7 ? _INTL("Heavy") : (n >= 4 ? _INTL("Moderate") : _INTL("Light"))
      end

      # The icon's game path for a weather and strength
      def icon(type, n)
        t = (type || :None).to_s.to_sym
        file = ONE_ICON[t]
        unless file
          stem = LEVELED[t]
          return DIR + "mapClear" unless stem
          n = n.to_i
          file = stem + (n <= 2 ? "_light" : (n <= 4 ? "_medium" : "_heavy"))
        end
        return DIR + file
      end

      def season_name(i = nil)
        i ||= Reloaded::Weather.season
        return _INTL(SEASONS[i.to_i % 4][0])
      end

      def season_rgb(i = nil)
        i ||= Reloaded::Weather.season
        return SEASONS[i.to_i % 4][1]
      end

      def season_mark(i = nil)
        i ||= Reloaded::Weather.season
        return SEASON_MARKS[i.to_i % 4]
      end

      # Minutes of play until the next cycle (an hour of the game's clock is
      # a minute of play): "4m", at least 1
      def minutes_left
        m = (Reloaded::Weather.seconds_left / 3600.0).ceil
        return [m, 1].max
      end

      def in_words
        return _INTL("{1}m", minutes_left)
      end

      # A place's weather as it shows, now or next: [type, strength] (:None, 0
      # when clear; sun after dark shows clear, the next one by its own hour)
      def shown(key, which = "now")
        w = Reloaded::Weather.at(key, which)
        if !w && which == "now" && defined?(Reloaded::Weather::Rainbow) && Reloaded::Weather::Rainbow.at?(key)
          return [:Rainbow, 1]
        end
        return [:None, 0] unless w
        time = nil
        if which == "next"
          d = Reloaded::Weather.data
          time = Time.at(d["next_at"].to_i) if d && d["next_at"]
        end
        t = Reloaded::Weather.shown_type(w[0], w[1], time)
        return t == :None ? [:None, 0] : [t, w[1]]
      end
    end
  end
end
