# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Wild Link's search and its target
#==============================================================================
# His picks (2026-11-14):
#
#   The target     PIF's own overworld Pokémon (its Hoenn game's, the same
#                  engine Hoenn Native Overworld uses), behaving as PIF wrote
#                  that species, on a tile you can walk (or surf) to, 3 to 7
#                  steps away and on screen: grass for Land, the cave's floor
#                  for Cave, the water for Surf (while you surf). Its
#                  Pokémon gets the species' Search Level and your chain's
#                  bonuses (Bonuses.apply). One at a time
#   Its battle     won (knocked out +1 Search Level, caught +2) grows the
#                  chain; running from it or losing breaks the chain
#   Gets away      it flees out of reach, teleports off or explodes: that
#                  search ends, the chain stays
#   The chain      also breaks on leaving the map, or searching another
#   The wild       ordinary wild battles still happen while you search (they
#                  don't break the chain), and your Repel's steps don't run
#                  down while a search is on
#   Continue       after a won target battle: Ask (Kanto Reloaded's popup),
#                  Automatic (the next target appears) or Off
#
# Fishing spots and Rock Smash rocks: Fields.rb.
#==============================================================================

module Reloaded
  module WildLink
    module Search
      TERRAIN = { :land => :Land, :cave => :Cave, :surf => :Water }.freeze
      MIN_STEPS = 3
      MAX_STEPS = 7
      SCREEN_X = 7                     # tiles from you to the screen's edge
      SCREEN_Y = 5
      DIRS = [[2, 0, 1], [4, -1, 0], [6, 1, 0], [8, 0, -1]].freeze   # [direction, dx, dy]

      @target = nil
      @battle = false

      # A Surf target only swims (his test, 2026-11-14: one walked out onto
      # the grass; PIF's water rule misses a shore tile with something drawn
      # over its water): a step anywhere but water is refused, even fleeing
      module StayInWater
        def passable?(x, y, d, strict = false)
          nx = x + (d == 6 ? 1 : d == 4 ? -1 : 0)
          ny = y + (d == 2 ? 1 : d == 8 ? -1 : 0)
          t = Reloaded::WildLink::Search.tag(nx, ny)
          return false unless t && t.can_surf && !(t.respond_to?(:bridge) && t.bridge)
          return super
        end
      end

      class << self
        # { "event", "map", "species", "way", "row" } while a target is out
        attr_reader :target
        attr_accessor :battle

        def install
          return if @installed
          @installed = true
          if defined?(::Events)
            ::Events.onWildBattleEnd += proc { |_s, e| Reloaded::WildLink::Search.battle_ended(Array(e)[2]) } if ::Events.respond_to?(:onWildBattleEnd)
            ::Events.onMapChange += proc { |_s, _e| Reloaded::WildLink::Search.map_changed } if ::Events.respond_to?(:onMapChange)
            ::Events.onStepTaken += proc { |_s, _e| Reloaded::WildLink::Search.step_taken } if ::Events.respond_to?(:onStepTaken)
            ::Events.onMapUpdate += proc { |_s, _e| Reloaded::WildLink::Search.watch } if ::Events.respond_to?(:onMapUpdate)
          end
          if defined?(::OverworldPokemonEvent) && ::OverworldPokemonEvent.method_defined?(:overworldPokemonBattle)
            Reloaded::Hooks.around(FEATURE, ::OverworldPokemonEvent, :overworldPokemonBattle, :id => :wild_link_target_battle) do |original, *args|
              Reloaded::WildLink::Search.battle = true if original.receiver.instance_variable_get(:@kr_wl_target)
              original.call(*args)
            end
          end
        end

        def searching?
          return @target ? true : false
        end

        # A field target (Fields.rb: a fishing spot, a rock) taken on
        def adopt(t)
          @target = t
          @battle = false
        end

        #----------------------------------------------------------------------
        # Starting
        #----------------------------------------------------------------------
        # A search for a row of Wild Link's list (Area's), met this way; true
        # when its target is out
        def start(row, way)
          return false unless row && WildLink.on?
          why = WildLink.blocked
          return say(_INTL("Wild Link can't search here now.")) && false if why
          return Fields.start(row, way) if defined?(Fields) && Fields.handles?(way)
          terrain = TERRAIN[way]
          return say(_INTL("Wild Link can't search that way yet.")) && false unless terrain
          surfing = $PokemonGlobal && $PokemonGlobal.respond_to?(:surfing) && $PokemonGlobal.surfing
          return say(_INTL("Surf out onto the water to search there.")) && false if terrain == :Water && !surfing
          spot = find_spot(terrain)
          return say(_INTL("Nothing answered nearby. Try somewhere with more room.")) && false unless spot
          species = row[:species]
          map = $game_map.map_id
          c = WildLink.chain
          WildLink.break_chain(:other) if c && c["key"] != WildLink.chain_key(species, way, map)
          clear
          sl = WildLink.search_level(species)
          chain = WildLink.chain_for(species, way, map)
          level = target_level(row, sl)
          event = make_event(species, level, spot, terrain)
          return say(_INTL("Nothing answered nearby.")) && false unless event
          event.instance_variable_set(:@kr_wl_target, true)
          event.extend(StayInWater) if terrain == :Water
          pk = event.respond_to?(:pokemon) ? event.pokemon : nil
          got = Bonuses.apply(pk, sl, chain) { event.respond_to?(:make_shiny) ? event.make_shiny : (pk.shiny = true) }
          @target = { "event" => event.id, "map" => map, "species" => species, "way" => way, "row" => row, "got" => got }
          Reloaded::Events.emit(:wild_link_target, :species => species, :way => way, :level => level, :got => got)
          return true
        rescue StandardError => e
          Reloaded::Log.exception("Wild Link couldn't make its target", e, :wild_link)
          return false
        end

        # The row's levels, plus Search Level's
        def target_level(row, sl)
          lo = row[:min].to_i
          hi = [row[:max].to_i, lo].max
          blo, bhi = Bonuses.level_range(sl)
          max = defined?(::GameData::GrowthRate) && ::GameData::GrowthRate.respond_to?(:max_level) ? ::GameData::GrowthRate.max_level : 100
          return [[lo + rand(hi - lo + 1) + blo + rand(bhi - blo + 1), 1].max, max].min
        end

        # PIF's own overworld Pokémon (OverworldPokemonSpawning.rb)
        def make_event(species, level, spot, terrain)
          return nil unless defined?(create_overworld_pokemon_event)
          return create_overworld_pokemon_event([species, level], spot, terrain)
        end

        #----------------------------------------------------------------------
        # Where: a tile you can reach, 3 to 7 steps away, on screen
        #----------------------------------------------------------------------
        def find_spot(terrain)
          px = $game_player.x
          py = $game_player.y
          steps = { [px, py] => 0 }
          queue = [[px, py]]
          found = []
          until queue.empty?
            x, y = queue.shift
            d = steps[[x, y]]
            next if d >= MAX_STEPS
            DIRS.each do |dir, dx, dy|
              nx = x + dx
              ny = y + dy
              next if steps.key?([nx, ny]) || !$game_map.valid?(nx, ny)
              next unless walkable?(x, y, dir)
              steps[[nx, ny]] = d + 1
              queue << [nx, ny]
              next unless d + 1 >= MIN_STEPS && (nx - px).abs <= SCREEN_X && (ny - py).abs <= SCREEN_Y
              found << [nx, ny] if spawnable?(nx, ny, terrain)
            end
          end
          return found.empty? ? nil : found[rand(found.length)]
        end

        def walkable?(x, y, dir)
          return $game_player.passable?(x, y, dir)
        rescue StandardError
          return false
        end

        # The tile as it is, bridges counted (his test, 2026-11-14: PIF's
        # terrain_tag skips a bridge while you aren't on one, so a pier or a
        # bridge over water read as water and a Surf target stood on it)
        def tag(x, y)
          return $game_map.terrain_tag(x, y, true)
        rescue ArgumentError
          return $game_map.terrain_tag(x, y)
        end

        def spawnable?(x, y, terrain)
          ok = defined?(can_spawn_pokemon_there) ? can_spawn_pokemon_there(x, y, terrain) : true
          return false unless ok
          t = tag(x, y)
          return false if t.respond_to?(:bridge) && t.bridge
          return t.can_surf ? true : false if terrain == :Water
          return t.land_wild_encounters ? true : false if terrain == :Land
          return true
        rescue StandardError
          return false
        end

        #----------------------------------------------------------------------
        # While it's out
        #----------------------------------------------------------------------
        def event
          return nil unless @target && $game_map && $game_map.map_id == @target["map"]
          return $game_map.events[@target["event"]]
        end

        # Every frame on the map: after a won battle, what comes next; gone
        # without a battle = it got away
        def watch
          after_battle if @after
          return unless @target && !@target["kind"] && !@battle && !(defined?($PokemonTemp) && $PokemonTemp && $PokemonTemp.respond_to?(:overworld_wild_battle_triggered) && $PokemonTemp.overworld_wild_battle_triggered)
          ev = event
          return if ev && !(ev.respond_to?(:erased) && ev.erased) && !(ev.instance_variable_get(:@erased))
          got_away
        end

        def got_away
          t = @target
          @target = nil
          return unless t
          Reloaded::Events.emit(:wild_link_got_away, :species => t["species"], :n => WildLink.chain_for(t["species"], t["way"], t["map"]))
        end

        # A Repel step back for every step while a search is on (KIF's
        # radar rule)
        def step_taken
          return unless @target && $PokemonGlobal && $PokemonGlobal.repel.to_i > 0
          $PokemonGlobal.repel += 1
        end

        # Leaving the map: the target's gone, the chain broken
        def map_changed
          t = @target
          c = WildLink.chain
          now = $game_map ? $game_map.map_id : 0
          @target = nil if t && t["map"] != now
          WildLink.break_chain(:left) if c && c["map"].to_i != now
        end

        # The target taken off the map (a new search, Wild Link Off)
        def clear
          Fields.remove_rock(@target) if defined?(Fields) && @target && @target["kind"] == :rock_smash
          ev = @target && !@target["kind"] ? event : nil
          ev.despawn if ev && ev.respond_to?(:despawn)
          @target = nil
          @battle = false
        rescue StandardError
          @target = nil
        end

        #----------------------------------------------------------------------
        # Its battle
        #----------------------------------------------------------------------
        # PIF's decision: 1 won, 2 lost, 3 ran, 4 caught, 5 a draw
        def battle_ended(decision)
          return unless @battle
          @battle = false
          t = @target
          @target = nil
          return unless t
          sp = t["species"]
          case decision.to_i
          when 1, 4
            caught = decision.to_i == 4
            was, now = WildLink.raise_search_level(sp, caught)
            n = WildLink.advance_chain(sp, t["way"], t["map"])
            Reloaded::Events.emit(:wild_link_won, :species => sp, :caught => caught, :n => n, :was => was, :sl => now,
                                  :steps => WildLink.steps_passed(was, now))
            go_on(t)
          when 3
            WildLink.break_chain(:ran)
          else
            WildLink.break_chain(:lost)
          end
        rescue StandardError => e
          Reloaded::Log.exception("Wild Link couldn't finish a target battle", e, :wild_link)
        end

        # Continue Search: Ask, Automatic or Off (once the map is back)
        def go_on(t)
          @after = t unless WildLink.continue_mode == WildLink::STOP
        end

        def after_battle
          return if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:message_window_showing) && $game_temp.message_window_showing
          t = @after
          @after = nil
          return unless t && WildLink.on?
          return if t["map"] != ($game_map ? $game_map.map_id : 0)
          go = WildLink.continue_mode == WildLink::AUTOMATIC || ask_again(t)
          start(t["row"], t["way"]) if go
        rescue StandardError => e
          Reloaded::Log.exception("Wild Link couldn't go on with the search", e, :wild_link)
        end

        # Kanto Reloaded's own popup (his pick, 2026-11-14: Standard Popup)
        def ask_again(t)
          return false unless defined?(Continue)
          return Continue.ask(t["species"], WildLink.chain_for(t["species"], t["way"], t["map"]))
        end

        def say(text)
          pbMessage(text) if defined?(pbMessage)
          return true
        end
      end
    end
  end
end
