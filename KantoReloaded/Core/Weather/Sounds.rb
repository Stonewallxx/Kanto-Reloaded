# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Weather System, the weather's sounds
#==============================================================================
# Stage 5 (his picks on the Reloaded Sounds page, 2026-11-13). Outdoors,
# while the weather shows on the map:
#
#   Rain, Storm,   old Kanto Reloaded's loops (KR_Weather_Rain, _Storm,
#   Heavy Rain     _HeavyRain), louder the stronger it is
#   thunder        in a storm every 6 to 14 seconds, in heavy rain every 10
#                  to 20 (real time), both of old Kanto Reloaded's thunders
#                  (his words: "We should use both Thunder sounds"), turn
#                  about
#   Wind           no sound (his pick)
#
# A map with a sound of its own (the sea, a waterfall) keeps it: the weather
# plays nothing there. The loop stops when the weather goes, or indoors, and
# only ever stops its own. Weather Sounds (Kanto Reloaded > Weather System)
# switches them, On.
#==============================================================================

module Reloaded
  module Weather
    module Sounds
      SETTING = :"weather.sounds"
      LOOPS = { :Rain => "KR_Weather_Rain", :Storm => "KR_Weather_Storm", :HeavyRain => "KR_Weather_HeavyRain" }.freeze
      THUNDER = ["KR_Weather_Thunder1", "KR_Weather_Thunder2"].freeze
      GAPS = { :Storm => [6.0, 14.0], :HeavyRain => [10.0, 20.0] }.freeze

      @playing = nil
      @next_thunder = nil
      @turn = 0

      class << self
        attr_reader :playing

        def on?
          return Reloaded::Weather.on? && Reloaded::Settings.get(SETTING) ? true : false
        rescue StandardError
          return false
        end

        def now
          return Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        # [loop, volume] wanted now, or nil
        def wanted
          return nil unless on? && defined?($game_map) && $game_map && defined?($game_screen) && $game_screen
          meta = (::GameData::MapMetadata.try_get($game_map.map_id) rescue nil)
          return nil unless meta && meta.outdoor_map
          return nil if own_sound?
          type = $game_screen.weather_type
          name = LOOPS[type]
          return nil unless name
          n = Battle.screen_strength
          return [name, [40 + n * 6, 100].min]
        end

        # The map plays a sound of its own
        def own_sound?
          map = $game_map.instance_variable_get(:@map)
          return map && map.respond_to?(:autoplay_bgs) && map.autoplay_bgs && map.bgs && !map.bgs.name.to_s.empty? ? true : false
        rescue StandardError
          return false
        end

        # Every check on the map (and as it changes): the loop and thunder
        def update
          want = wanted
          if want != @playing
            want ? play(want) : stop
          end
          thunder(want)
        rescue StandardError => e
          Reloaded::Log.warning_once("Weather: the weather's sounds couldn't play (#{e.class})", :weather)
        end

        def play(want)
          name, vol = want
          pbBGSPlay(name, vol, 100) if defined?(pbBGSPlay)
          @playing = want
        end

        # Stops the loop only when it's ours that's playing
        def stop
          return unless @playing
          cur = defined?($game_system) && $game_system && $game_system.respond_to?(:playing_bgs) ? $game_system.playing_bgs : nil
          pbBGSFade(0.8) if cur && cur.name.to_s == @playing[0] && defined?(pbBGSFade)
          @playing = nil
          @next_thunder = nil
        end

        def thunder(want)
          type = want ? $game_screen.weather_type : nil
          gap = GAPS[type]
          unless gap
            @next_thunder = nil
            return
          end
          t = now
          @next_thunder ||= t + rand_between(*gap)
          return if t < @next_thunder
          @turn = (@turn + 1) % THUNDER.length
          pbSEPlay(THUNDER[@turn], [want[1] + 10, 100].min, 100) if defined?(pbSEPlay)
          @next_thunder = t + rand_between(*gap)
        end

        def rand_between(a, b)
          return a + rand * (b - a)
        end

        def reset
          @playing = nil
          @next_thunder = nil
        end
      end
    end
  end
end
