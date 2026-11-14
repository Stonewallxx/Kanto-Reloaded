# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Weather System, Multiplayer
#==============================================================================
# Stage 8 (his picks, 2026-11-13; KIF's Multiplayer, F-NET-01, through its
# mod sharing: KIF::Net.share / on_share). While players are connected and
# each has Kanto Reloaded:
#
#   the host's     the host's game sends its weather (now, next, when it
#   weather        changes, the rainbows, its Visitors' seed) whenever it
#                  changes and every few seconds; every guest sees it, on
#                  the map, in battle, in the Forecast, the alerts too. A
#                  guest's own saved weather is left as it was (its clock
#                  waits) and comes back when they leave. Sun after dark
#                  still follows each player's own clock.
#   a guest's      a Field Weather Move a guest uses asks the host's game to
#   moves          change that place, so everyone sees it (the guest's PP
#                  and cry are theirs; their save's weather untouched)
#
# What arrives is checked: only the host's game sends the weather, only the
# host takes moves, places are matched against this game's own list, each
# weather against the kinds there are, every number kept in its range.
# Hoenn Essentials' own weather sharing stands aside while this is On.
#==============================================================================

module Reloaded
  module Weather
    module Multiplayer
      ID = "kr_weather"
      VERSION = 1
      KINDS = %w[Rain Storm Sunny Fog Snow Wind Ash Sandstorm].freeze
      HEARTBEAT = 5.0            # seconds between the host's sends when nothing changed
      GAME_PER_REAL = 60         # game seconds a real second (1 game hour a real minute)

      @remote = nil
      @sent_version = -1
      @sent_at = -100.0

      class << self
        attr_reader :remote

        def install
          return if @installed
          @installed = true
          return unless net?
          ::KIF::Net.on_share(ID) { |_name, key, data, from = nil| Reloaded::Weather::Multiplayer.receive(key, data, from) }
        rescue StandardError => e
          Reloaded::Log.exception("Weather: Multiplayer sharing couldn't be set up", e, :weather)
        end

        def net?
          return defined?(::KIF::Net) && ::KIF::Net.respond_to?(:on_share) && ::KIF::Net.respond_to?(:share)
        end

        def connected?
          return net? && ::KIF::Net.connected?
        rescue StandardError
          return false
        end

        def host?
          return connected? && ::KIF::Net.host?
        rescue StandardError
          return false
        end

        def guest?
          return connected? && !host?
        end

        def partner_has?
          return ::KIF::Net.partner_has?(ID) rescue false
        end

        # Showing the host's weather (a guest, connected, the host's arrived)
        def remote?
          return @remote && guest? ? true : false
        end

        def now
          return Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        #----------------------------------------------------------------------
        # Every check on the map
        #----------------------------------------------------------------------
        def frame
          return unless net?
          if host?
            send_state if Reloaded::Weather.on? && partner_has? &&
                          (Reloaded::Weather.version != @sent_version || now - @sent_at >= HEARTBEAT)
          elsif @remote && !guest?
            leave
          end
        rescue StandardError => e
          Reloaded::Log.warning_once("Weather: the weather couldn't be shared (#{e.class})", :weather)
        end

        # The host's weather to every guest
        def send_state
          d = Reloaded::Weather.ensure_started
          return unless d
          data = { "v" => VERSION, "c" => d["cycle"].to_i, "seed" => d["seed"].to_i, "left" => Reloaded::Weather.seconds_left,
                   "now" => rows(d["now"]), "next" => rows(d["next"]), "rb" => rainbows_left }
          @sent_version = Reloaded::Weather.version
          @sent_at = now
          ::KIF::Net.share(ID, "state", data)
        end

        def rows(snap)
          out = {}
          (snap || {}).each { |k, (t, n)| out[k.to_s] = [t.to_s, n.to_i] if Places[k] }
          return out
        end

        def rainbows_left
          t = (Reloaded::Weather.data || {})["rainbows"] || {}
          clock = Reloaded::Weather.clock
          out = {}
          t.each { |k, e| out[k.to_s] = [e[0].to_i - clock, 0].max if Places[k] && e[0].to_i > clock }
          return out
        end

        #----------------------------------------------------------------------
        # What arrives
        #----------------------------------------------------------------------
        def receive(key, data, from = nil)
          return unless Reloaded::Weather.on? && data.is_a?(Hash) && data["v"] == VERSION
          case key
          when "state"
            return unless guest? && (from.nil? || from == 0)
            take_state(data)
          when "move"
            return unless host?
            take_move(data)
          end
        rescue StandardError => e
          Reloaded::Log.warning_once("Weather: shared weather couldn't be read (#{e.class})", :weather)
        end

        def checked_rows(h)
          return nil unless h.is_a?(Hash) && h.length <= Places.keys.length
          out = {}
          h.each do |k, w|
            return nil unless k.is_a?(String) && Places[k] && w.is_a?(Array) && w.length == 2
            return nil unless KINDS.include?(w[0]) && w[1].is_a?(Integer) && w[1].between?(1, 10)
            out[k] = [w[0], w[1]]
          end
          return out
        end

        def take_state(d)
          now_rows = checked_rows(d["now"])
          next_rows = checked_rows(d["next"])
          left = d["left"]
          cycle = d["c"]
          seed = d["seed"]
          return unless now_rows && next_rows && left.is_a?(Integer) && left.between?(0, 2 * 86_400) &&
                        cycle.is_a?(Integer) && cycle >= 0 && seed.is_a?(Integer) && seed.abs < 2**31
          rb = {}
          if d["rb"].is_a?(Hash)
            d["rb"].each { |k, s| rb[k] = [Reloaded::Weather.clock + s, "Rain"] if k.is_a?(String) && Places[k] && s.is_a?(Integer) && s.between?(0, 86_400) }
          end
          before = @remote ? @remote["now"] : nil
          stepped = @remote && @remote["cycle"] != cycle
          @remote = { "now" => now_rows, "next" => next_rows, "left" => left, "at" => now, "cycle" => cycle, "seed" => seed,
                      "rainbows" => rb }
          Reloaded::Weather.changed!
          Reloaded::Events.emit(:weather_cycled, :steps => 1, :before => before, :shared => true) if stepped && defined?(Reloaded::Events)
          Reloaded::Weather.show_on_map(true)
          Link.fog_changed($game_map.map_id) if defined?($game_map) && $game_map
        end

        # A guest's Field Weather Move, on the host's game
        def take_move(d)
          key = d["k"]
          type = d["t"]
          return unless key.is_a?(String) && Places[key] && (type == "None" || KINDS.include?(type))
          Reloaded::Weather.set_by_move(key, type == "None" ? nil : type.to_sym, FieldMoves::STRENGTH)
          send_state
        end

        #----------------------------------------------------------------------
        # A guest's side
        #----------------------------------------------------------------------
        def snap(which)
          return nil unless remote?
          return @remote[which]
        end

        def seed
          return remote? ? @remote["seed"] : nil
        end

        def rainbows
          return remote? ? @remote["rainbows"] : nil
        end

        def seconds_left
          gone = ((now - @remote["at"]) * GAME_PER_REAL).to_i
          return [@remote["left"] - gone, 0].max
        end

        # A guest's move: shown at once, and asked of the host
        def ask_move(key, type)
          t = type.nil? || type.to_s == "None" ? "None" : type.to_s
          if t == "None"
            @remote["now"].delete(key)
          else
            @remote["now"][key] = [t, FieldMoves::STRENGTH]
          end
          Reloaded::Weather.changed!
          Reloaded::Weather.show_on_map(true)
          ::KIF::Net.share(ID, "move", { "v" => VERSION, "k" => key.to_s, "t" => t })
        end

        # Left the game: their own weather again
        def leave
          @remote = nil
          Reloaded::Weather.changed!
          Reloaded::Weather.show_on_map(true)
        end

        def reset
          @remote = nil
          @sent_version = -1
          @sent_at = -100.0
        end
      end
    end
  end
end
