# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Hidden Power's map events (the researcher)
#==============================================================================
# PIF's map events are command lists in the game's map files. Kanto
# Reloaded never edits them: when an event starts (Interpreter#setup), a
# list registered here for that map and event is given in place of PIF's,
# only while PIF's list is still the one it was written for (its
# fingerprint matches), so a game update that changes the event leaves it
# PIF's and the log says so.
#
#   Reloaded::HiddenPower::EventLists.register(map, event, crc) { |list| new_list }
#
# The researcher (the Ruins of Alph lab, Map354 event 6): PIF's talk about
# Unown stays; then, for $5,000 a spin, the Type Reel (his pick, Q10
# Design 2) on a Pokémon from the party. Unown gets its notice instead.
#==============================================================================

module Reloaded
  module HiddenPower
    module EventLists
      @swaps = {}
      @made = {}

      class << self
        # build: proc(PIF's list) -> the list to run instead
        def register(map_id, event_id, crc, name, &build)
          (@swaps[[map_id, event_id]] ||= []) << { :crc => crc, :name => name, :build => build }
        end

        def registered
          return @swaps.dup
        end

        # A list's fingerprint: every command's code, indent and parameters
        # (text as its bytes, whatever encoding the map file gave it; a
        # move route or sound by its class)
        def crc(list)
          return Zlib.crc32(Array(list).map { |c| "#{c.code}|#{c.indent}|#{flat(c.parameters)}" }.join("\n"))
        end

        def flat(value)
          case value
          when Array then return "[" + value.map { |v| flat(v) }.join(",") + "]"
          when String then return "'" + value.b + "'"
          when Integer, Float, Symbol, TrueClass, FalseClass, NilClass then return value.inspect
          else return "<#{value.class}>"
          end
        end

        # The list to run for this event: ours when PIF's matches, else PIF's
        def swap(list, event_id, map_id)
          entries = @swaps[[map_id, event_id]]
          return list unless entries && list
          made = @made[[map_id, event_id]]
          return made[1] if made && made[0].equal?(list)
          sum = crc(list)
          entry = entries.find { |e| e[:crc] == sum }
          unless entry
            warn_once(map_id, event_id, entries, sum)
            return list
          end
          ours = entry[:build].call(list)
          @made[[map_id, event_id]] = [list, ours]
          return ours
        end

        def warn_once(map_id, event_id, entries, sum)
          @warned ||= {}
          return if @warned[[map_id, event_id, sum]]
          @warned[[map_id, event_id, sum]] = true
          Reloaded::Log.info("#{entries.map { |e| e[:name] }.join(", ")}: PIF's event (map #{map_id}, event #{event_id}) isn't the one Kanto Reloaded was written for (#{sum}); it runs as PIF's", :hidden_power)
        end

        # A command for a list
        def command(code, indent, parameters)
          return RPG::EventCommand.new(code, indent, parameters)
        end

        def script(line, indent = 0)
          return command(355, indent, [line])
        end

        # once, whichever part asks first
        def install
          return if @installed
          return unless defined?(::Interpreter) && ::Interpreter.method_defined?(:setup)
          @installed = true
          Reloaded::Hooks.around(nil, ::Interpreter, :setup, :id => :hidden_power_events) do |original, *args|
            list, event_id, map_id = args
            map = map_id || ($game_map ? $game_map.map_id : nil)
            args[0] = Reloaded::HiddenPower::EventLists.swap(list, event_id, map)
            original.call(*args)
          end
        end
      end
    end

    module Researcher
      MAP = 354
      EVENT = 6
      CRC = 359_793_996             # PIF's list (KIF Beta 1.2.3)
      KEEP = 3                      # PIF's talk about Unown: the bubble and its two lines
      PRICE = 5_000

      class << self
        def install
          EventLists.register(MAP, EVENT, CRC, "The Hidden Power Researcher") do |list|
            list[0, KEEP] + [EventLists.script("Reloaded::HiddenPower::Researcher.talk(@event_id)"), EventLists.command(0, 0, [])]
          end
          EventLists.install
        end

        def cash(n)
          return "$" + n.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
        end

        def bubble(event_id)
          pbCallBub(2, event_id) if defined?(pbCallBub)
        rescue StandardError
          nil
        end

        # After PIF's lines about Unown
        def talk(event_id)
          bubble(event_id)
          if pbConfirmMessage(_INTL("My research can spin your Pokémon's Hidden Power to a new type, for {1} a spin. Shall I?", cash(PRICE)))
            pkmn = choose
            if pkmn && Reloaded::HiddenPower.unown?(pkmn)
              Reloaded::HiddenPowerScreen.unown(pkmn, true)
            elsif pkmn
              Reloaded::HiddenPowerScreen.reel(pkmn)
            end
          end
          bubble(event_id)
          pbMessage(_INTL("Do come visit again."))
        end

        # The Party Screen with what it's for; Eggs can't be chosen
        def choose
          party = $Trainer.party
          ret = nil
          pbFadeOutIn do
            scene = PokemonParty_Scene.new
            screen = PokemonPartyScreen.new(scene, party)
            title = _INTL("Spin Whose Hidden Power?")
            annot = party.map { |pk| Reloaded::HiddenPower.changeable?(pk) ? _INTL("ABLE") : _INTL("NOT ABLE") }
            screen.pbStartScene(title, false, annot)
            loop do
              i = screen.pbChoosePokemon(title)
              break if i.nil? || i < 0
              if party[i].egg?
                screen.pbDisplay(_INTL("This Pokémon can't be chosen."))
                next
              end
              ret = party[i]
              break
            end
            screen.pbEndScene
          end
          return ret
        end
      end
    end
  end
end
