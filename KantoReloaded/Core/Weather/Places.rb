# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Weather System, the places
#==============================================================================
# Every outdoor map grouped into places by its name (two maps called Route 2
# share one place's weather; the Safari Zone's Area 1-5 are one place), each
# with its pool of weathers by what kind of place it is (Hoenn Essentials'
# pools, his pick 2026-11-13: forests rainy and foggy, coasts wet and windy,
# mountains snowy, volcanic places ashy, some routes their own) and its
# neighbours (the game's map connections, then the Town Map's spots).
#
# A place's spot is where the Town Map itself puts it: the Town Map's tiles
# carry their place's name (town_map.dat, 278 of them), the place takes the
# middle tile of those with its name. A place the Town Map doesn't show
# (Hoenn's maps, Pinkan Island, the S.S. Anne...) has no spot: it has
# weather, but no icon on the Forecast or the Fly map. (The maps' own
# MapPosition put some of those on Kanto's tiles, and Route 16 on the
# wrong side: PIF's Town Map never reads it either.)
#
# Left out: maps with no name, the debug and message maps, the dive maps
# (Underwater), maps renamed .old. A map whose own weather always happens
# (Route 25's rain, Mt. Ember's sun, the Ice Mountains' and one of Mt.
# Silver's snow) keeps it and is never simulated; a map with a chance of its
# own weather (Cerulean Cape, Lavender Town, Treasure Beach, New Bark Town)
# joins in with a rainy lean (his pick).
#
# Built from the game's data the first time weather is needed after a save
# loads (never at boot: Kanto Reloaded boots before GameData).
#==============================================================================

module Reloaded
  module Weather
    module Places
      # Hoenn Essentials' pool (HoennWeatherKIF.weights): None is "no new
      # front here"; no natural Sandstorm (his pick: only the field move)
      BASE = { :None => 42, :Rain => 26, :Sunny => 18, :Wind => 12, :Fog => 7, :Storm => 4 }.freeze
      FOREST = /forest|woods|grove|garden|park|clearing|ilex/i
      COAST = /sea|ocean|coast|cape|beach|island|bridge|road|whirl|cianwood|vermil|olivine|cinnabar|labyrinth|s\.?s\.? anne/i
      MOUNTAIN = /mount|\bmt\.?|peak|summit|silver|ice |seafoam|blackthorn|plateau|square/i
      VOLCANIC = /cinnabar|volcan|ember|burned tower/i
      LEAN_RAIN = 30                 # a map's own chance of rain, as a lean
      LEFT_OUT = /\A(debug|common|messages|soaring|johto|hall of origin)\b|debug island|\.old\z/i
      SAFARI = /\AArea \d+\z/i
      # Places whose Town Map tiles go by another name
      TILE_NAMES = { "indigo plateau" => "pokémon league", "mt. moon square" => "mt. moon", "mt. moon summit" => "mt. moon",
                     "mt. silver summit" => "mt. silver" }.freeze

      Place = Struct.new(:key, :name, :maps, :pool, :spot, :lean, :climate, :tiles)

      class << self
        attr_reader :places, :fixed

        def built?
          return !@places.nil?
        end

        def reset
          @places = nil
          @fixed = nil
          @by_map = nil
          @neighbours = nil
        end

        # The place a map belongs to (nil: no weather of ours there)
        def of_map(map_id)
          build unless built?
          return @by_map[map_id.to_i]
        end

        def [](key)
          build unless built?
          return @places[key]
        end

        def keys
          build unless built?
          return @places.keys
        end

        def neighbours(key)
          build unless built?
          return @neighbours[key] || []
        end

        # A map whose own weather always happens: [type, chance]
        def fixed_weather(map_id)
          build unless built?
          return @fixed[map_id.to_i]
        end

        def build(source = Source)
          @places = {}
          @fixed = {}
          @by_map = {}
          town = source.town_tiles
          @town = town
          source.outdoor_maps.each do |id, name, weather, _spot|
            name = name.to_s.strip
            next if name.empty? || name =~ LEFT_OUT || source.dive_map?(id)
            if weather && weather[1].to_i >= 100
              @fixed[id] = weather
              next
            end
            label = name =~ SAFARI ? "Safari Zone" : name
            key = label.downcase
            pl = (@places[key] ||= Place.new(key, label, [], nil, nil, false, nil))
            pl.maps << id
            pl.lean = true if weather && weather[0].to_s == "Rain"
          end
          @places.each_value do |pl|
            tiles = town[pl.key] || town[TILE_NAMES[pl.key]]
            if tiles && !tiles.empty?
              pl.tiles = tiles
              pl.spot = [0] + tiles[(tiles.length - 1) / 2]
            end
            pl.pool, pl.climate = pool_for(pl.name, pl.lean)
            pl.maps.each { |m| @by_map[m] = pl.key }
          end
          @neighbours = link(source)
          return @places
        end

        # [weights, climate word] for a place's name
        def pool_for(name, lean = false)
          w = BASE.dup
          climate = "Temperate"
          if name =~ FOREST
            w[:Rain] += 10; w[:Fog] += 14; w[:Sunny] = 6
            climate = "Forest"
          elsif name =~ VOLCANIC
            w[:Ash] = 9; w[:Sunny] += 6
            climate = "Volcanic"
          elsif name =~ COAST
            w[:Rain] += 12; w[:Wind] += 16; w[:Storm] += 4
            climate = "Coastal"
          elsif name =~ MOUNTAIN
            w[:Snow] = 30; w[:Wind] += 15; w[:Fog] += 6
            climate = "Mountain"
          end
          w[:Ash] = 9 if name =~ VOLCANIC
          route = name[/\broute\s*0*(\d+)\b/i, 1].to_i
          case route
          when 10, 33, 43 then w[:Rain] += 24; w[:Storm] += 5
          when 19, 20, 21, 40, 41 then w[:Wind] += 22; w[:Rain] += 12; climate = "Coastal"
          when 26, 27, 28, 42, 44, 45, 46, 47, 48 then w[:Wind] += 12; w[:Snow] = 8
          when 2, 30, 31, 34, 35, 36, 37 then w[:Fog] += 10; w[:Rain] += 8
          end
          if name =~ /lake of rage/i
            w[:Rain] += 28; w[:Storm] += 6
          end
          w[:Rain] += LEAN_RAIN if lean
          return [w.select { |_t, n| n > 0 }, climate]
        end

        # A place on this Town Map tile, or nil
        def at_tile(x, y)
          build unless built?
          @places.each_value { |pl| return pl.key if pl.tiles && pl.tiles.include?([x, y]) }
          return nil
        end

        # Where a map is on the Town Map: its place's spot, else the Town
        # Map's own tile for it (a town's), else nil: [x, y]
        def spot_for_map(map_id)
          build unless built?
          key = of_map(map_id)
          return @places[key].spot[1, 2] if key && @places[key].spot
          Array(Source.town_locations).each { |l| return [l[0], l[1]] if l[4] == map_id }
          return nil
        rescue StandardError
          return nil
        end

        private

        # Neighbours: the game's map connections between two places, then
        # places a step apart on the Town Map (same region); a place with
        # none gets its nearest on the Town Map
        def link(source)
          out = Hash.new { |h, k| h[k] = [] }
          add = proc do |a, b|
            next if a.nil? || b.nil? || a == b
            out[a] << b unless out[a].include?(b)
            out[b] << a unless out[b].include?(a)
          end
          source.connections.each { |a, b| add.call(@by_map[a], @by_map[b]) }
          list = @places.values.select(&:spot)
          list.combination(2) do |p, q|
            next unless p.spot[0] == q.spot[0]
            add.call(p.key, q.key) if (p.spot[1] - q.spot[1]).abs <= 1 && (p.spot[2] - q.spot[2]).abs <= 1
          end
          list.each do |p|
            next unless out[p.key].empty?
            near = list.select { |q| q != p && q.spot[0] == p.spot[0] }
                       .min_by { |q| (p.spot[1] - q.spot[1]).abs + (p.spot[2] - q.spot[2]).abs }
            add.call(p.key, near.key) if near
          end
          return out
        end
      end

      # Where the places come from: the game's own data (a test hands in its
      # own)
      module Source
        module_function

        # [[map id, name, own weather or nil, Town Map spot or nil], ...]
        def outdoor_maps
          return [] unless defined?(::GameData::MapMetadata) && ::GameData::MapMetadata.respond_to?(:each)   # (a test without the game's maps)
          infos = pbLoadMapInfos rescue {}
          out = []
          ::GameData::MapMetadata.each do |m|
            next unless m.outdoor_map
            info = infos[m.id]
            out << [m.id, info ? info.name : "", m.weather, m.town_map_position]
          end
          return out
        rescue StandardError => e
          Reloaded::Log.exception("Weather: the maps couldn't be read", e, :weather)
          return []
        end

        def dive_map?(id)
          @dives ||= begin
            list = []
            ::GameData::MapMetadata.each { |m| list << m.dive_map_id if m.dive_map_id }
            list
          rescue StandardError
            []
          end
          return @dives.include?(id)
        end

        # The Town Map's tiles: [x, y, name, point of interest, map, ...]
        def town_locations
          data = defined?(pbLoadTownMapData) ? pbLoadTownMapData : nil
          return data && data[0] ? Array(data[0][2]) : []
        rescue StandardError
          return []
        end

        # { a place's name, small => [[x, y], ...] } from the Town Map's tiles
        def town_tiles
          out = Hash.new { |h, k| h[k] = [] }
          town_locations.each { |l| out[l[2].to_s.strip.downcase] << [l[0].to_i, l[1].to_i] if l[2] }
          return out
        end

        # [[map, map], ...] from the game's map connections
        def connections
          return [] unless defined?(::MapFactoryHelper)
          return ::MapFactoryHelper.getMapConnections.map { |c| [c[0], c[3]] }
        rescue StandardError
          return []
        end
      end
    end
  end
end
