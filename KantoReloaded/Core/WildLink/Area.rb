# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Wild Link's list of the area's Pokémon
#==============================================================================
# The wild Pokémon here, by the way they're met (his picks, 2026-11-14):
#
#   The tables     the game's own for this map and the time of day (Land and
#                  its grass patches, Cave, Surf, the three rods, Rock
#                  Smash), one row per species: its chances added up, its
#                  levels lowest to highest, the likeliest first. Each
#                  species as it really appears: cody's Randomizer's wild
#                  swap applied (KIF::Rand.randomize_wild!, as the game
#                  does); its Area mode is already in the table
#   Weather        the Weather System on: species the weather here makes
#                  more common get their raised share (and a mark); the
#                  place's Weather Visitors are listed under them while it
#                  lasts (Weather Signals), at the Visitors' chance
#   Rare Signal    PIF's Poké Radar-only Pokémon here (cody's Randomizer
#                  turns them into what they became), Land only, opened once
#                  every land Pokémon here has been seen (the radar's green
#                  light), levels from PIF's list
#
#   Reloaded::WildLink::Area.tabs   # [[:land, "Land", rows], ...]
#   row: { :species, :rate (%), :min, :max, :kind (:wild/:visitor/:rare),
#          :boost (weather), :heading (a rod's name), :table (:OldRod...) }
#==============================================================================

module Reloaded
  module WildLink
    module Area
      # What a way needs to happen at all (his test, 2026-11-14: Pallet Town's
      # table lists the starters' lines, but its grass is walled off): grass
      # you can walk to for Land, water beside it for Surf, water to fish from
      # it for Fishing, a rock to smash beside it for Rock Smash; a cave's own
      # encounters happen on any tile
      NEEDS = { :land => :land, :surf => :surf, :fishing => :fish, :rock_smash => :rock }.freeze
      TABS = [[:land, "Land", [[:Land, nil], [:Land1, nil], [:Land2, nil], [:Land3, nil], [:TallGrass, nil]]],
              [:cave, "Cave", [[:Cave, nil]]],
              [:surf, "Surf", [[:Water, nil]]],
              [:fishing, "Fishing", [[:OldRod, "Old Rod"], [:GoodRod, "Good Rod"], [:SuperRod, "Super Rod"]]],
              [:rock_smash, "Rock Smash", [[:RockSmash, nil]]]].freeze

      module_function

      # Every way the wild Pokémon here are met, with its rows, for now
      def tabs
        enc = $PokemonEncounters
        tables = enc ? (enc.instance_variable_get(:@encounter_tables) || {}) : {}
        return [] if tables.empty?
        now = defined?(pbGetTimeNow) ? pbGetTimeNow : Time.now
        weather = weather_here
        out = []
        TABS.each do |id, label, parts|
          next unless possible?(id)
          rows = []
          parts.each do |base, heading|
            type = enc.respond_to?(:find_valid_encounter_type_for_time) ? enc.find_valid_encounter_type_for_time(base, now) : base
            part = merged(tables[type])
            next if part.empty?
            part = raised(part, weather, id) if weather
            part.each { |r| r[:table] = base }
            part.first[:heading] = heading if heading
            rows.concat(part)
          end
          next if rows.empty?
          rows.concat(visitor_rows(weather, id, rows)) if weather
          rows.concat(rare_rows(rows)) if id == :land
          out << [id, label, rows]
        end
        return out
      rescue StandardError => e
        Reloaded::Log.exception("Wild Link couldn't read this map's encounters", e, :wild_link)
        return []
      end

      # A table's slots, one row per species (as it appears), likeliest first
      def merged(slots)
        rows = {}
        order = []
        Array(slots).each do |slot|
          next unless slot.is_a?(Array) && slot[1]
          sp = appears_as(slot[1])
          unless rows[sp]
            rows[sp] = { :species => sp, :weight => 0.0, :min => slot[2].to_i, :max => slot[3].to_i, :kind => :wild, :boost => false }
            order << sp
          end
          r = rows[sp]
          r[:weight] += slot[0].to_f
          r[:min] = [r[:min], slot[2].to_i].min
          r[:max] = [r[:max], [slot[3].to_i, slot[2].to_i].max].max
        end
        list = order.map { |sp| rows[sp] }
        total = list.sum { |r| r[:weight] }
        list.each { |r| r[:rate] = total > 0 ? (r[:weight] * 100.0 / total).round : 0 }
        return list.each_with_index.sort_by { |r, i| [-r[:weight], i] }.map(&:first)
      end

      # The species a table's entry really appears as (cody's wild swap; his
      # Dynamic mode rolls on the spot, so the entry stays as it is)
      def appears_as(species)
        return species unless defined?(::KIF::Rand) && ::KIF::Rand.respond_to?(:randomize_wild!)
        return species if ::KIF::Rand.respond_to?(:dynamic?) && ::KIF::Rand.dynamic?
        got = ::KIF::Rand.randomize_wild!([species, 1])
        return got.is_a?(Array) && got[0] ? got[0] : species
      rescue StandardError
        return species
      end

      #------------------------------------------------------------------------
      # What this map's tiles let happen
      #------------------------------------------------------------------------
      def possible?(way)
        need = NEEDS[way]
        return true unless need && $game_map
        return here[need] ? true : false
      end

      ALL = { :land => true, :surf => true, :fish => true, :rock => true }.freeze
      STEPS = [[2, 0, 1], [4, -1, 0], [6, 1, 0], [8, 0, -1]].freeze

      # { :land, :surf, :fish, :rock } for where you are: the tiles you can
      # reach from here, walking as the map lets you step (and across water
      # when you can surf), events aside since they move. Kept until you
      # change maps or stand outside what was reached
      def here
        return ALL unless $game_player && $game_map.respond_to?(:terrain_tag) && $game_map.respond_to?(:valid?)
        w = ($game_map.width rescue 0).to_i
        h = ($game_map.height rescue 0).to_i
        return ALL if w <= 0 || h <= 0
        swim = can_swim?
        spot = [$game_player.x, $game_player.y]
        key = [$game_map.map_id, swim]
        return @here if @here && @here_key == key && @here_seen && @here_seen[spot]
        seen = reach(spot, swim)
        got = { :land => false, :surf => false, :fish => false, :rock => false }
        seen.each_key do |x, y|
          t = tag(x, y)
          got[:land] = true if t && t.land_wild_encounters
          STEPS.each do |_d, dx, dy|
            n = tag(x + dx, y + dy)
            next unless n
            got[:surf] = true if n.can_surf
            got[:fish] = true if n.respond_to?(:can_fish) && n.can_fish
          end
        end
        events = $game_map.respond_to?(:events) ? $game_map.events.values : []
        rocks = events.select { |e| (e.name rescue "").to_s =~ /smashrock/i && !(e.name rescue "").to_s.include?("Wild Link") }
        got[:rock] = rocks.any? { |e| STEPS.any? { |_d, dx, dy| seen[[e.x + dx, e.y + dy]] } }
        @here_key = key
        @here_seen = seen
        @here = got
        return got
      rescue StandardError => e
        Reloaded::Log.exception("Wild Link couldn't read this map's tiles", e, :wild_link)
        return ALL
      end

      # Every tile you can get to from spot (a flood, as the map lets you step)
      def reach(spot, swim)
        seen = { spot => true }
        queue = [spot]
        until queue.empty?
          x, y = queue.shift
          STEPS.each do |d, dx, dy|
            n = [x + dx, y + dy]
            next if seen[n] || !$game_map.valid?(n[0], n[1])
            next unless side?(x, y, d, swim) && side?(n[0], n[1], 10 - d, swim)
            seen[n] = true
            queue << n
          end
        end
        return seen
      end

      # Whether you can leave or enter x,y on its d side: PIF's own rule for
      # you, with water open when you can surf
      def side?(x, y, d, swim)
        if swim
          t = tag(x, y)
          return true if t && t.can_surf && !(t.respond_to?(:waterfall) && t.waterfall)
        end
        return $game_map.playerPassable?(x, y, d, $game_player) if $game_map.respond_to?(:playerPassable?)
        return $game_map.passable?(x, y, d, $game_player)
      rescue StandardError
        return false
      end

      def tag(x, y)
        return nil unless $game_map.valid?(x, y)
        return $game_map.terrain_tag(x, y)
      rescue StandardError
        return nil
      end

      # Surfing now, or able to (PIF's own test: the badge and a Pokémon that
      # knows Surf, or the Surfboard)
      def can_swim?
        return true if $PokemonGlobal && $PokemonGlobal.respond_to?(:surfing) && $PokemonGlobal.surfing
        board = defined?($PokemonBag) && $PokemonBag && $PokemonBag.respond_to?(:pbQuantity) && $PokemonBag.pbQuantity(:SURFBOARD) > 0
        return true if board
        return false unless defined?(pbCheckHiddenMoveBadge) && defined?(Settings::BADGE_FOR_SURF) && $Trainer.respond_to?(:get_pokemon_with_move)
        return pbCheckHiddenMoveBadge(Settings::BADGE_FOR_SURF, false) && $Trainer.get_pokemon_with_move(:SURF) ? true : false
      rescue StandardError
        return false
      end

      #------------------------------------------------------------------------
      # Weather Signals
      #------------------------------------------------------------------------
      # [place, type, strength] while the Weather System's weather counts here
      def weather_here
        return nil unless defined?(Reloaded::Weather::Encounters) && Reloaded::Weather::Encounters.respond_to?(:here)
        return Reloaded::Weather::Encounters.here
      rescue StandardError
        return nil
      end

      def water?(id)
        return id == :surf || id == :fishing
      end

      # The weather's types weighted up, as the Weather System chooses
      def raised(rows, weather, id)
        we = Reloaded::Weather::Encounters
        _key, type, n = weather
        types = we.more_types(type)
        return rows if types.empty?
        mult = we.boost(n)
        rows.each do |r|
          next unless we.matches?(r[:species], types)
          r[:weight] *= mult
          r[:boost] = true
        end
        total = rows.sum { |r| r[:weight] }
        rows.each { |r| r[:rate] = total > 0 ? (r[:weight] * 100.0 / total).round : 0 }
        return rows.each_with_index.sort_by { |r, i| [-r[:weight], i] }.map(&:first)
      end

      # The place's Weather Visitors for this way of meeting them (at the
      # level of the one each replaces: the tab's range)
      def visitor_rows(weather, id, rows = [])
        return [] if id == :rock_smash
        we = Reloaded::Weather::Encounters
        key, type, n = weather
        list = we.visitors(key, type, water?(id) ? :water : :land)
        return [] if list.empty?
        each = (we.visitor_chance(n, key) / list.length.to_f)
        lo = rows.map { |r| r[:min] }.min.to_i
        hi = rows.map { |r| r[:max] }.max.to_i
        return list.map do |sp|
          { :species => appears_as(sp), :rate => [each.round, 1].max, :min => lo, :max => hi, :kind => :visitor, :boost => true, :weather => type }
        end
      rescue StandardError
        return []
      end

      #------------------------------------------------------------------------
      # The Rare Signal
      #------------------------------------------------------------------------
      # PIF's radar-only Pokémon here, as they appear (cody's Randomizer's own
      # list), at PIF's levels; open once every land Pokémon here is seen
      def rare_rows(land)
        return [] unless defined?(::Settings::POKE_RADAR_ENCOUNTERS) && $game_map
        map = $game_map.map_id
        entries = ::Settings::POKE_RADAR_ENCOUNTERS.select { |e| e[0] == map }
        return [] if entries.empty?
        species = defined?(listPokeradarRareEncounters) ? (listPokeradarRareEncounters rescue nil) : nil
        species = entries.map { |e| e[2] } unless species.is_a?(Array) && species.length == entries.length
        open = rare_open?(land)
        return entries.each_with_index.map do |e, i|
          { :species => species[i], :rate => e[1].to_i, :min => e[3].to_i, :max => (e[4] || e[3]).to_i, :kind => :rare, :boost => false, :open => open }
        end
      rescue StandardError
        return []
      end

      # Every land Pokémon here seen (the Weather Visitors aside)
      def rare_open?(land)
        wild = land.select { |r| r[:kind] == :wild }
        return false if wild.empty?
        return wild.all? { |r| seen?(r[:species]) }
      end

      def seen?(species)
        return $Trainer && $Trainer.respond_to?(:seen?) && $Trainer.seen?(species) ? true : false
      rescue StandardError
        return false
      end

      def caught?(species)
        return $Trainer && $Trainer.respond_to?(:owned?) && $Trainer.owned?(species) ? true : false
      rescue StandardError
        return false
      end

      # [seen, all] among a tab's own wild Pokémon
      def seen_count(rows)
        wild = rows.select { |r| r[:kind] == :wild }.map { |r| r[:species] }.uniq
        return [wild.count { |sp| seen?(sp) }, wild.length]
      end

      def caught_count(rows)
        wild = rows.select { |r| r[:kind] == :wild }.map { |r| r[:species] }.uniq
        return [wild.count { |sp| caught?(sp) }, wild.length]
      end
    end
  end
end
