# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Weather System, the weather's Pokémon
#==============================================================================
# Stage 3 (his picks, 2026-11-13). While the Weather System is On, outdoors
# on a place with weather (grass, surfing and fishing alike, Hoenn Native
# Overworld's walking Pokémon too):
#
#   More Common    the place's own Pokémon of the weather's types show up
#                  more: x1.5 in light weather up to x3 at full strength
#                  (Rain: Water and Electric; Storm: Electric and Water;
#                  Sunny: Fire and Grass; Fog: Ghost and Psychic; Snow: Ice;
#                  Wind: Flying and Normal; Ash: Fire and Rock; Sandstorm:
#                  Ground and Rock)
#   Weather        now and then a Pokémon from outside the place's list: 2%
#   Visitors       of encounters in light weather up to 8% at full strength.
#                  Kanto Reloaded's own rules: of the weather's types, at
#                  home in the place (forest, coast, mountain...: by its
#                  habitat), at the place's levels (its stage for them),
#                  never a legendary or a fossil; the same two per place and weather in
#                  a save (land and water each have their own two)
#
# The Randomizer changes a Visitor as it changes any wild Pokémon. Hoenn
# Native's PokéRadar app lists the Visitors (PIF's list_weather_encounters).
# Hoenn Essentials' own Weather Visitors stand aside while this is On, so
# there's one set, the one the Forecast shows (Link.rb).
#==============================================================================

module Reloaded
  module Weather
    module Encounters
      MORE = { :Rain => [:WATER, :ELECTRIC], :Storm => [:ELECTRIC, :WATER], :Sunny => [:FIRE, :GRASS], :Fog => [:GHOST, :PSYCHIC],
               :Snow => [:ICE], :Wind => [:FLYING, :NORMAL], :Ash => [:FIRE, :ROCK], :Sandstorm => [:GROUND, :ROCK] }.freeze
      BOOST_LIGHT = 1.5
      BOOST_FULL = 3.0
      VISIT_LIGHT = 2.0          # % of encounters at strength 1
      VISIT_FULL = 8.0           # and at 10
      VISITORS = 2
      # Revived from fossils, never found wild
      FOSSILS = [:OMANYTE, :KABUTO, :AERODACTYL, :LILEEP, :ANORITH, :CRANIDOS, :SHIELDON, :TIRTOUGA, :ARCHEN, :TYRUNT,
                 :AMAURA, :DRACOZOLT, :ARCTOZOLT, :DRACOVISH, :ARCTOVISH].freeze
      # Where a place's land Visitors live (the species' habitat); water ones
      # anywhere live in water
      HABITATS = { "Temperate" => [:Grassland, :Urban, :Forest, :RoughTerrain, :WatersEdge],
                   "Forest" => [:Forest, :Grassland],
                   "Coastal" => [:WatersEdge, :Grassland, :Sea],
                   "Mountain" => [:Mountain, :Cave, :RoughTerrain],
                   "Volcanic" => [:Mountain, :RoughTerrain, :Cave] }.freeze
      WATER_HABITATS = [:WatersEdge, :Sea].freeze
      # A species with no habitat in the game's data lives where its type does
      TYPE_HOMES = { :WATER => [:WatersEdge, :Sea], :ROCK => [:Mountain, :RoughTerrain, :Cave],
                     :GROUND => [:Mountain, :RoughTerrain, :Cave], :STEEL => [:Mountain, :Cave, :Urban],
                     :GRASS => [:Forest, :Grassland], :BUG => [:Forest, :Grassland], :GHOST => [:Cave, :Urban, :Forest],
                     :DARK => [:Cave, :Urban, :Forest], :ICE => [:Mountain, :Sea], :FIRE => [:Mountain, :RoughTerrain, :Grassland],
                     :ELECTRIC => [:Urban, :Grassland], :FLYING => [:Grassland, :Forest, :Mountain],
                     :NORMAL => [:Grassland, :Urban, :Forest], :POISON => [:Urban, :Forest, :Cave],
                     :PSYCHIC => [:Urban, :Forest, :Grassland], :FIGHTING => [:Mountain, :Urban, :RoughTerrain],
                     :DRAGON => [:Mountain, :WatersEdge, :Cave], :FAIRY => [:Forest, :Grassland, :Urban] }.freeze

      # Hoenn Native's PokéRadar app: the Visitors with the weather's own
      module RadarList
        def list_weather_encounters(enctype, *args)
          ret = super
          ret = [] unless ret.is_a?(Array)
          extra = Reloaded::Weather::Encounters.radar_entries(self, enctype)
          return ret if extra.empty?
          return ret + extra.reject { |e| ret.any? { |o| o[1] == e[1] } }
        end
      end

      @cache = {}

      class << self
        def install
          return if @installed
          @installed = true
          return unless defined?(::PokemonEncounters)
          if ::PokemonEncounters.method_defined?(:choose_wild_pokemon)
            Reloaded::Hooks.around(FEATURE, ::PokemonEncounters, :choose_wild_pokemon, :id => :weather_encounters) do |original, enc_type, *rest|
              Reloaded::Weather::Encounters.choose(original.receiver, enc_type, original, rest)
            end
          end
          if ::PokemonEncounters.method_defined?(:list_weather_encounters)
            Reloaded::Hooks.prepend(FEATURE, ::PokemonEncounters, RadarList, :id => :weather_radar)
          end
        end

        def clamp(n)
          return [[n.to_i, 1].max, 10].min
        end

        def more_types(type)
          return MORE[type.to_s.to_sym] || []
        end

        def boost(n)
          return BOOST_LIGHT + (clamp(n) - 1) * (BOOST_FULL - BOOST_LIGHT) / 9.0
        end

        # A Visitor's chance (%), a rainbow doubling it (Stage 7)
        def visitor_chance(n, key = nil)
          ch = VISIT_LIGHT + (clamp(n) - 1) * (VISIT_FULL - VISIT_LIGHT) / 9.0
          ch *= Reloaded::Weather::Rainbow.visitor_boost(key) if defined?(Reloaded::Weather::Rainbow)
          return ch
        end

        # The weather that counts here: [place, type, strength] (ours, showing),
        # or nil
        def here
          return nil unless Reloaded::Weather.on? && defined?($game_map) && $game_map
          map = $game_map.map_id
          return nil if Reloaded::Weather.external?(map)
          key = Places.of_map(map)
          w = key ? Reloaded::Weather.at(key) : nil
          return nil unless w
          return nil if Reloaded::Weather.shown_type(w[0], w[1]) == :None
          return [key, w[0], w[1]]
        end

        def water?(enc_type)
          s = enc_type.to_s
          return s.include?("Water") || s.include?("Rod") || s.include?("Fish") || s.include?("Surf")
        end

        #----------------------------------------------------------------------
        # A wild Pokémon chosen
        #----------------------------------------------------------------------
        def choose(enc, enc_type, original, rest)
          h = here
          unless h
            # under a rainbow: the rain's Visitors, twice as likely as in light rain
            rb = rainbow_here
            return original.call(enc_type, *rest) unless rb
            ret = original.call(enc_type, *rest)
            return visit_or(ret, enc, enc_type, rb[0], rb[1], 1)
          end
          key, type, n = h
          ret = with_boost(enc, enc_type, more_types(type), boost(n)) { original.call(enc_type, *rest) }
          return visit_or(ret, enc, enc_type, key, type, n)
        rescue StandardError => e
          Reloaded::Log.warning_once("Weather: a weather encounter couldn't be chosen (#{e.class}: #{e.message})", :weather)
          return ret if ret
          return original.call(enc_type, *rest)
        end

        # Now and then a Visitor in place of the one chosen (at its level)
        def visit_or(ret, enc, enc_type, key, type, n)
          return ret unless ret.is_a?(Array) && ret[0]
          return ret unless rand(10_000) < (visitor_chance(n, key) * 100).round
          list = visitors(key, type, water?(enc_type) ? :water : :land, enc)
          return ret if list.empty?
          visit = [list[rand(list.length)], ret[1]]
          visit = ::KIF::Rand.randomize_wild!(visit) if defined?(::KIF::Rand) && ::KIF::Rand.respond_to?(:randomize_wild!)
          Reloaded::Events.emit(:weather_visitor, :species => visit[0], :place => key) if defined?(Reloaded::Events)
          return visit
        end

        # [place, the rain's kind] under a rainbow here, or nil
        def rainbow_here
          return nil unless defined?(Reloaded::Weather::Rainbow) && Reloaded::Weather.on? && defined?($game_map) && $game_map
          map = $game_map.map_id
          return nil if Reloaded::Weather.external?(map)
          key = Places.of_map(map)
          r = key ? Reloaded::Weather::Rainbow.rain_of(key) : nil
          return r ? [key, r] : nil
        end

        # The table, the weather's types weighted up, for this one choice
        def with_boost(enc, enc_type, types, mult)
          tables = enc.instance_variable_get(:@encounter_tables)
          list = tables.is_a?(Hash) ? tables[enc_type] : nil
          return yield if types.empty? || !list.is_a?(Array) || list.empty?
          tables[enc_type] = list.map do |e|
            next e unless e.is_a?(Array) && e[0].is_a?(Numeric) && matches?(e[1], types)
            [(e[0] * mult).round] + e[1..-1]
          end
          begin
            return yield
          ensure
            tables[enc_type] = list
          end
        end

        def matches?(species, types)
          d = ::GameData::Species.try_get(species)
          return false unless d
          return ([d.type1, d.type2] & types).any?
        rescue StandardError
          return false
        end

        #----------------------------------------------------------------------
        # Weather Visitors
        #----------------------------------------------------------------------
        # A place's Visitors in a weather (:land or :water): their species, the
        # same two in a save (for the encounter mode the save plays)
        def visitors(key, type, kind = :land, enc = nil)
          base = type.to_s.to_sym
          base = { :HeavyRain => :Rain, :Blizzard => :Snow, :StrongWinds => :Wind }[base] || base
          mode = encounter_mode(enc)
          seed = Reloaded::Weather.seed
          ck = [key, base, kind, mode.to_s, seed, version]
          return @cache[ck] if @cache.key?(ck)
          @cache.clear if @cache.length > 400
          @cache[ck] = pick(key, base, kind, mode, seed)
        rescue StandardError => e
          Reloaded::Log.warning_once("Weather: a place's Visitors couldn't be worked out (#{e.class}: #{e.message})", :weather)
          return []
        end

        def version
          return defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:encounter_version) ? $PokemonGlobal.encounter_version.to_i : 0
        end

        def encounter_mode(enc = nil)
          enc ||= (defined?($PokemonEncounters) ? $PokemonEncounters : nil)
          return enc.getEncounterMode if enc && enc.respond_to?(:getEncounterMode)
          return ::GameData::Encounter
        rescue StandardError
          return ::GameData::Encounter
        end

        # The place's own lists in this encounter mode (every map of it)
        def place_lists(pl, mode, kind)
          out = []
          pl.maps.each do |m|
            data = (mode.get(m, version) rescue nil) || (mode.get(m, 0) rescue nil)
            next unless data && data.respond_to?(:types) && data.types.is_a?(Hash)
            data.types.each { |t, list| out.concat(list) if list.is_a?(Array) && water?(t) == (kind == :water) }
          end
          return out.select { |e| e.is_a?(Array) && e.length >= 4 }
        end

        def pick(key, type, kind, mode, seed)
          pl = Places[key]
          types = more_types(type)
          return [] unless pl && !types.empty?
          lists = place_lists(pl, mode, kind)
          return [] if lists.empty?                  # no grass (or water) here, no Visitors there
          natives = lists.map { |e| family(e[1]) }.compact.uniq
          level = (lists.map { |e| e[2].to_i }.min + lists.map { |e| e[3].to_i }.max) / 2
          homes = kind == :water ? WATER_HABITATS : (HABITATS[pl.climate] || HABITATS["Temperate"])
          found = []
          candidates.each do |sp|
            next if natives.include?(sp)
            stage = stage_for(sp, level)
            d = ::GameData::Species.try_get(stage)
            next unless d && ([d.type1, d.type2] & types).any?
            next unless at_home?(sp, homes, kind)
            found << stage
          end
          salt = "#{key}|#{type}|#{kind}|#{seed}"
          return found.uniq.sort_by { |sp| [zlib(salt + "|" + sp.to_s), sp.to_s] }.first(VISITORS)
        end

        def zlib(s)
          return Zlib.crc32(s)
        end

        # Every species that can be a Visitor: a first stage, not a legendary,
        # not a rare one, the base form, of the game's own Pokédex (no fusions)
        def candidates
          return @candidates if @candidates
          most = defined?(::NB_POKEMON) ? ::NB_POKEMON : 9999
          legends = defined?(::LEGENDARIES_LIST) ? ::LEGENDARIES_LIST : []
          out = []
          ::GameData::Species.each do |d|
            next unless d.form.to_i == 0 && d.id_number.to_i.between?(1, most)
            next if legends.include?(d.species) || FOSSILS.include?(d.species) || d.habitat == :Rare
            next if (d.evolutions || []).any? { |e| e[3] }            # has a prevolution
            out << d.species
          end
          @candidates = out.uniq
          return @candidates
        end

        # The first stage of a species' family (natives count as their family)
        def family(species)
          d = ::GameData::Species.try_get(species)
          return nil unless d
          seen = 0
          while (prev = (d.evolutions || []).find { |e| e[3] }) && seen < 4
            d = ::GameData::Species.try_get(prev[0]) || break
            seen += 1
          end
          return d.species
        rescue StandardError
          return nil
        end

        def at_home?(species, homes, kind)
          d = ::GameData::Species.try_get(species)
          return false unless d
          hab = d.habitat
          places = hab && hab != :None ? [hab] : [d.type1, d.type2].uniq.flat_map { |t| TYPE_HOMES[t] || [:Grassland] }
          return false if kind == :land && places == [:Sea]
          return (places & homes).any?
        end

        # Its stage at a level: by level up, friendship from 18, stones from
        # 30, trading from 40 (the first that fits)
        def stage_for(species, level)
          sp = species
          4.times do
            d = ::GameData::Species.try_get(sp)
            break unless d
            nxt = d.get_evolutions(true).find { |_s, method, param| evolves_by?(method, param, level) }
            break unless nxt
            sp = nxt[0]
          end
          return sp
        end

        def evolves_by?(method, param, level)
          m = method.to_s
          return param.is_a?(Integer) && param <= level if m.start_with?("Level") || m == "Ninjask" || m == "Shedinja"
          return level >= 18 if m.start_with?("Happiness")
          return level >= 30 if m.start_with?("Item")
          return level >= 40 if m.start_with?("Trade")
          return false
        end

        #----------------------------------------------------------------------
        # PokéRadar lists
        #----------------------------------------------------------------------
        def radar_entries(enc, enc_type)
          h = here
          return [] unless h && enc_type
          key, type, _n = h
          list = visitors(key, type, water?(enc_type) ? :water : :land, enc)
          return [] if list.empty?
          tables = enc.instance_variable_get(:@encounter_tables)
          rows = tables.is_a?(Hash) ? Array(tables[enc_type]) : []
          rows = rows.select { |e| e.is_a?(Array) && e.length >= 4 }
          return [] if rows.empty?
          lo = rows.map { |e| e[2].to_i }.min
          hi = rows.map { |e| e[3].to_i }.max
          return list.map { |sp| [1, sp, lo, hi] }
        rescue StandardError
          return []
        end

        # Seen in battle (the Forecast shows a shadow until then)
        def seen?(species)
          return defined?($Trainer) && $Trainer && $Trainer.respond_to?(:seen?) && $Trainer.seen?(species) ? true : false
        rescue StandardError
          return false
        end

        def reset
          @cache = {}
          @candidates = nil
        end
      end
    end
  end
end
