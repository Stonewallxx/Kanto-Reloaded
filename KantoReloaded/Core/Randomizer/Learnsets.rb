# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Random Learnsets
#==============================================================================
# Learnsets: Random. Once, at Randomize Now (or the New Game randomizing),
# every base species' level-up moves are rolled again: the same levels and
# count, each move replaced by one of the same kind (physical, special or
# status) and similar power (within 10, widening), any type (his pick),
# never one of the player's banned moves (Exclusions) or one the species
# already got. Fusions follow by themselves (a fusion's moves are its
# parts'). Egg and tutor moves stay. Pokémon the player has keep their
# moves; new moves come from the new learnset.
#
# It runs on its own sub-seed of cody's seed, on a Random of its own (never
# the game's random numbers): the same seed gives the same learnsets.
# Moves are sorted by power once, so a roll is a few comparisons.
#
# Rolls: Dynamic (the row under Learnsets) rolls every Pokémon's own from
# its species' list, by its personal ID: two Pidgey can learn different
# moves, and the seed won't give the same ones each time. A Pokémon always
# reads the same list (the move relearner agrees with levelling up); it
# changes with its species (evolving, fusing). A new Pokémon's first moves
# come from its own list too (the game sets them before it has an ID, so
# they're set again).
#==============================================================================

begin
  require "zlib" unless defined?(::Zlib)
rescue LoadError
  nil
end

module Reloaded
  module Randomizer
    module Learnsets
      CACHE = 128

      class << self
        def dynamic?
          return Reloaded::Randomizer.get(:kr_learnsets) == 1 && Dynamic.on?(:kr_learnsets_dynamic)
        end

        # This Pokémon's own list, rolled from its species' (kept per
        # Pokémon and species)
        def roll_for(pkmn, list)
          pid = pkmn.instance_variable_get(:@personalID)
          return list unless pid && list.is_a?(Array)
          r = ::KIF::Rand
          key = [pid, pkmn.species, r.seed]
          @cache ||= {}
          hit = @cache[key]
          return hit if hit
          rng = Random.new(Zlib.crc32("#{r.seed}|moves|#{pid}|#{pkmn.species}"))
          pools = cached_pools(r)
          used = []
          out = list.map do |level, move|
            pick = pick(r, pools, move, used, rng) || move
            used << pick
            [level, pick]
          end
          @cache.clear if @cache.length >= CACHE
          return @cache[key] = out
        end

        # The pools, made again only for another seed or other banned moves
        def cached_pools(r)
          token = [r.seed, r.bans(:moves).hash]
          @pools = [token, pools_for(r)] unless @pools && @pools[0] == token
          return @pools[1]
        end

        def install
          return unless defined?(::Pokemon)
          h = Reloaded::Hooks
          feature = Reloaded::Randomizer::FEATURE
          h.around(feature, ::Pokemon, :getMoveList, :id => :randomizer_dynamic_learnsets) do |original, *args|
            list = original.call(*args)
            Reloaded::Randomizer::Learnsets.dynamic? ? Reloaded::Randomizer::Learnsets.roll_for(original.receiver, list) : list
          end
          h.around(feature, ::Pokemon, :initialize, :id => :randomizer_dynamic_first_moves) do |original, *args|
            result = original.call(*args)
            pkmn = original.receiver
            if args[3] != false && Reloaded::Randomizer::Learnsets.dynamic? && !pkmn.egg?
              pkmn.instance_variable_set(:@learned_moves, [])     # (the species' moves it never had)
              pkmn.reset_moves
            end
            result
          end
        end

        # { species => { :@moves => [[level, move], ...] } }
        def roll
          r = ::KIF::Rand
          rng = Random.new(r.sub_seed(:kr_learnsets))
          pools = pools_for(r)
          out = {}
          r.originals.keys.sort_by { |s| ::GameData::Species.get(s).id_number }.each do |s|
            used = []
            moves = Array(r.orig(s, :@moves)).map do |level, move|
              pick = pick(r, pools, move, used, rng) || move
              used << pick
              [level, pick]
            end
            out[s] = { :@moves => moves }
          end
          return out
        end

        # Each kind's moves: status as a list, physical and special sorted by
        # power ([[power...], [id...]])
        def pools_for(r)
          by = { :status => [], :physical => [], :special => [] }
          r.move_pool.each do |m|
            next if r.banned?(:moves, m.id)
            by[r.move_kind(m)] << m
          end
          out = { :status => by[:status].map(&:id) }
          [:physical, :special].each do |kind|
            list = by[kind].sort_by { |m| [m.base_damage, m.id_number] }
            out[kind] = [list.map(&:base_damage), list.map(&:id)]
          end
          return out
        end

        def pick(r, pools, move_id, used, rng)
          m = (::GameData::Move.get(move_id) rescue nil)
          return nil unless m
          kind = r.move_kind(m)
          if kind == :status
            cands = pools[:status].reject { |id| used.include?(id) }
            cands = pools[:status] if cands.empty?
            return cands.empty? ? nil : cands[rng.rand(cands.length)]
          end
          powers, ids = pools[kind]
          return nil if ids.empty?
          range = 10
          loop do
            lo = lower_bound(powers, m.base_damage - range)
            hi = lower_bound(powers, m.base_damage + range + 1)
            cands = ids[lo...hi].reject { |id| used.include?(id) }
            return cands[rng.rand(cands.length)] unless cands.empty?
            range += 10
            return ids[rng.rand(ids.length)] if range > 250
          end
        end

        # The first index whose value is at least v
        def lower_bound(sorted, v)
          lo = 0
          hi = sorted.length
          while lo < hi
            mid = (lo + hi) / 2
            sorted[mid] < v ? lo = mid + 1 : hi = mid
          end
          return lo
        end
      end
    end
  end
end
