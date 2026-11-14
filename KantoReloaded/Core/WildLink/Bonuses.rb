# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Wild Link's bonuses
#==============================================================================
# What a species' Search Level and your chain bring its Wild Link targets
# (his picks, 2026-11-14): old Kanto Reloaded's tables and caps, with every
# Search Level step halved (5, 12, 25, 50, 100, 250, so the best comes at
# about 125 catches), the chain's steps as they were (10, 20, 50, 100, 150).
#
#   Shiny          the chain on KIF's PokeRadar+ curve (on Wild Shiny Odds:
#                  1 in 200 at 20, 1 in 20 at 100, 1 in 10 at 200, still
#                  better after), plus extra rolls from Search Level: 1 at
#                  12, 2 at 50, 3 at 100, 4 at 250
#   Perfect IVs    1 at Search Level 25 (15% at 12), sometimes 2 from 50, 2
#                  at 100, sometimes 3 from 250; the chain makes it at least
#                  2 at 50, 3 at 100, 4 at 150 (half the time one more from
#                  30); never more than 4
#   Hidden Ability 2% at Search Level 5 up to 25% at 250, plus 5% at chain 10
#                  up to 25% at 150; never more than 50%
#   Egg Move       10% at 5 up to 70% at 250, plus 5% to 25% from the chain
#                  (90% at most); a second one opens at Search Level 50 or
#                  chain 50: 10% to 30%, plus 15% to 35% (65% at most)
#   Held Item      5% at 5 up to 30% at 250, plus 5% to 30% from the chain
#                  (60% at most), leaning toward its rarer items
#   Level          +0-1 at 5, +0-2 at 12, +1-2 at 25, +1-3 at 50, +2-4 at
#                  100, +3-5 at 250
#==============================================================================

module Reloaded
  module WildLink
    module Bonuses
      SL_STEPS = [5, 12, 25, 50, 100, 250].freeze
      CHAIN_STEPS = [10, 20, 50, 100, 150].freeze
      LEVELS = [[0, 0], [0, 1], [0, 2], [1, 2], [1, 3], [2, 4], [3, 5]].freeze
      HA_SL = [0, 2, 5, 8, 12, 18, 25].freeze
      HA_CHAIN = [0, 5, 10, 15, 20, 25].freeze
      EGG_SL = [0, 10, 20, 30, 40, 55, 70].freeze
      EGG_CHAIN = [0, 5, 10, 15, 20, 25].freeze
      EGG2_SL = { 4 => 10, 5 => 20, 6 => 30 }.freeze
      EGG2_CHAIN = { 3 => 15, 4 => 25, 5 => 35 }.freeze
      ITEM_SL = [0, 5, 10, 15, 20, 25, 30].freeze
      ITEM_CHAIN = [0, 5, 10, 15, 20, 30].freeze
      ROLLS = [0, 0, 1, 1, 2, 3, 4].freeze
      IVS = [0, 0, 0, 1, 1, 2, 2].freeze           # the sure ones by Search Level band
      IV_EXTRA = [0, 0, 15, 0, 20, 0, 20].freeze  # % chance of one more by band
      CAPS = { :ha => 50, :egg => 90, :egg2 => 65, :item => 60, :ivs => 4 }.freeze

      module_function

      def band(sl)
        return SL_STEPS.count { |s| sl.to_i >= s }
      end

      def cband(chain)
        return CHAIN_STEPS.count { |s| chain.to_i >= s }
      end

      def level_range(sl)
        return LEVELS[band(sl)]
      end

      def hidden_ability(sl, chain)
        return [HA_SL[band(sl)] + HA_CHAIN[cband(chain)], CAPS[:ha]].min
      end

      def egg_move(sl, chain)
        return [EGG_SL[band(sl)] + EGG_CHAIN[cband(chain)], CAPS[:egg]].min
      end

      # A second Egg Move's chance, or nil while it's locked (Search Level 50
      # or chain 50 opens it)
      def second_egg_move(sl, chain)
        return nil unless sl.to_i >= 50 || chain.to_i >= 50
        return [EGG2_SL[band(sl)].to_i + EGG2_CHAIN[cband(chain)].to_i, CAPS[:egg2]].min
      end

      def held_item(sl, chain)
        return [ITEM_SL[band(sl)] + ITEM_CHAIN[cband(chain)], CAPS[:item]].min
      end

      # The perfect IVs a target is sure to have
      def perfect_ivs(sl, chain)
        n = IVS[band(sl)]
        c = chain.to_i
        n = [n, 4].max if c >= 150
        n = [n, 3].max if c >= 100 && c < 150
        n = [n, 2].max if c >= 50 && c < 100
        return [n, CAPS[:ivs]].min
      end

      # How many it gets this time (the sure ones, sometimes one more)
      def roll_perfect_ivs(sl, chain, rng = Random)
        n = perfect_ivs(sl, chain)
        n += 1 if IV_EXTRA[band(sl)] > 0 && rng.rand(100) < IV_EXTRA[band(sl)] && n == IVS[band(sl)]
        n += 1 if chain.to_i >= 30 && chain.to_i < 50 && rng.rand(100) < 50
        return [n, CAPS[:ivs]].min
      end

      def shiny_rolls(sl)
        return ROLLS[band(sl)]
      end

      #------------------------------------------------------------------------
      # Shiny odds
      #------------------------------------------------------------------------
      # Wild Shiny Odds (KIF's setting), out of 65536
      def odds_setting
        return ::KIF::RadarPlus.shiny_odds if defined?(::KIF::RadarPlus) && ::KIF::RadarPlus.respond_to?(:shiny_odds)
        return defined?(::Settings::SHINY_POKEMON_CHANCE) ? ::Settings::SHINY_POKEMON_CHANCE : 16
      rescue StandardError
        return 16
      end

      # 1 in this many with no chain (the wild odds)
      def base
        return [65536 / [odds_setting, 1].max, 1].max
      end

      # 1 in this many from the chain alone: KIF's PokeRadar+ curve
      def chain_denominator(chain)
        odds = odds_setting
        if defined?(::KIF::RadarPlus) && ::KIF::RadarPlus.respond_to?(:odds_denominator)
          return ::KIF::RadarPlus.odds_denominator(chain.to_i, odds)
        end
        pif = [(65536 / [odds, 1].max) - [chain.to_i, 40].min * 200, 200].max
        return pif if chain.to_i <= 20
        best = [(65536 / [odds, 1].max) - 4000, 200].max
        a = [[20, 200.0], [100, 20.0], [200, 10.0]]
        i = chain.to_i <= 100 ? 0 : 1
        c0, v0 = a[i]
        c1, v1 = a[i + 1]
        v = (best * (v0 * ((v1 / v0) ** ((chain.to_i - c0).to_f / (c1 - c0)))) / 200.0).round
        return [[v, pif].min, 1].max
      end

      # The chance a target is shiny (0..1): the chain's, then Search Level's
      # extra rolls at the wild odds
      def shiny_chance(sl, chain)
        miss = (1.0 - 1.0 / chain_denominator(chain)) * ((1.0 - 1.0 / base) ** shiny_rolls(sl))
        return 1.0 - miss
      end

      # ...as 1 in N (1 = always)
      def shiny_odds(sl, chain)
        p = shiny_chance(sl, chain)
        return 1 if p >= 1.0
        return [(1.0 / p).round, 1].max
      end

      #------------------------------------------------------------------------
      # What a species can get
      #------------------------------------------------------------------------
      # [has a Hidden Ability, how many Egg Moves, has wild held items]
      def can_get(species)
        d = (::GameData::Species.try_get(species) rescue nil)
        return [false, 0, false] unless d
        ha = d.respond_to?(:hidden_abilities) && !Array(d.hidden_abilities).compact.empty?
        eggs = d.respond_to?(:egg_moves) ? Array(d.egg_moves).compact.uniq.length : 0
        items = [:wild_item_common, :wild_item_uncommon, :wild_item_rare].any? { |m| d.respond_to?(m) && d.send(m) }
        return [ha, eggs, items]
      rescue StandardError
        return [false, 0, false]
      end

      # The screen's rows: [label key, value words, how far toward its cap
      # (0..1), can the species get it]
      def rows(species, sl, chain)
        ha, eggs, items = can_get(species)
        lo, hi = level_range(sl)
        odds = shiny_odds(sl, chain)
        shiny_far = [Math.log(base.to_f / odds) / Math.log(base / 10.0), 0].max
        ivs = perfect_ivs(sl, chain)
        out = []
        out << [:shiny, odds <= 1 ? "Always" : "1 in #{commas(odds)}", [shiny_far, 1].min, true]
        out << [:ivs, ivs.to_s, ivs / 4.0, true]
        out << [:ha, ha ? "#{hidden_ability(sl, chain)}%" : nil, hidden_ability(sl, chain) / 50.0, ha]
        out << [:egg, eggs > 0 ? "#{egg_move(sl, chain)}%" : nil, egg_move(sl, chain) / 90.0, eggs > 0]
        out << [:item, items ? "#{held_item(sl, chain)}%" : nil, held_item(sl, chain) / 60.0, items]
        out << [:level, hi == 0 ? "+0" : (lo == hi ? "+#{lo}" : "+#{lo}-#{hi}"), hi / 5.0, true]
        return out
      end

      def commas(n)
        return n.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
      end

      #------------------------------------------------------------------------
      # A target made (Search.start): its bonuses rolled onto the Pokémon the
      # game made for it. shiny_hit: a block that makes it shiny (the event's
      # own make_shiny, so its sprite shows it). What it got, for the log and
      # the tests: { :shiny, :ivs, :ha, :eggs, :item }
      #------------------------------------------------------------------------
      STATS = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].freeze

      def apply(pkmn, sl, chain, rng = Random, &shiny_hit)
        got = { :shiny => false, :ivs => 0, :ha => false, :eggs => [], :item => nil }
        return got unless pkmn
        pkmn.instance_variable_set(:@kr_wl_target, true)
        got[:shiny] = roll_shiny(pkmn, sl, chain, rng, &shiny_hit)
        got[:ivs] = give_ivs(pkmn, roll_perfect_ivs(sl, chain, rng), rng)
        got[:ha] = give_hidden_ability(pkmn, hidden_ability(sl, chain), rng)
        got[:eggs] = give_egg_moves(pkmn, sl, chain, rng)
        got[:item] = give_item(pkmn, held_item(sl, chain), sl, chain, rng)
        pkmn.calc_stats if pkmn.respond_to?(:calc_stats)
        return got
      end

      # The chain's odds and Search Level's rolls, on top of the game's own
      # roll (a shiny it already is stays)
      def roll_shiny(pkmn, sl, chain, rng)
        return true if (pkmn.shiny? rescue false)
        natural = 1.0 / base
        p = shiny_chance(sl, chain)
        extra = natural >= 1 ? 0 : (p - natural) / (1.0 - natural)
        return false unless rng.rand < extra
        block_given? ? yield : (pkmn.shiny = true)
        return true
      rescue StandardError
        return false
      end

      def give_ivs(pkmn, n, rng)
        return 0 unless n > 0 && pkmn.respond_to?(:iv)
        have = STATS.select { |s| pkmn.iv[s].to_i >= 31 }
        free = (STATS - have).shuffle(:random => rng)
        free.first([n - have.length, 0].max).each { |s| pkmn.iv[s] = 31 }
        return STATS.count { |s| pkmn.iv[s].to_i >= 31 }
      rescue StandardError
        return 0
      end

      def give_hidden_ability(pkmn, chance, rng)
        return false unless chance > 0 && rng.rand(100) < chance
        hidden = Array((pkmn.species_data.hidden_abilities rescue nil)).compact
        return false if hidden.empty?
        pkmn.ability_index = 2 + rng.rand(hidden.length)
        pkmn.ability = nil if pkmn.respond_to?(:ability=)
        return true
      rescue StandardError
        return false
      end

      def give_egg_moves(pkmn, sl, chain, rng)
        pool = Array((pkmn.species_data.egg_moves rescue nil)).compact.uniq
        out = []
        return out if pool.empty?
        return out unless rng.rand(100) < egg_move(sl, chain)
        out << pool.delete_at(rng.rand(pool.length))
        second = second_egg_move(sl, chain)
        out << pool.delete_at(rng.rand(pool.length)) if second && !pool.empty? && rng.rand(100) < second
        out.each { |m| pkmn.learn_move(m) if pkmn.respond_to?(:learn_move) }
        pkmn.record_first_moves if pkmn.respond_to?(:record_first_moves)
        pkmn.instance_variable_set(:@kr_wl_eggs, out.map(&:to_s))
        return out
      rescue StandardError
        return out || []
      end

      # One of its wild held items, the rarer ones likelier as the hunt goes
      # on (old Kanto Reloaded's weights); never a worse one than it has
      def give_item(pkmn, chance, sl, chain, rng)
        return nil unless chance > 0 && rng.rand(100) < chance
        d = (pkmn.species_data rescue nil)
        return nil unless d
        common = (d.wild_item_common rescue nil)
        uncommon = (d.wild_item_uncommon rescue nil)
        rare = (d.wild_item_rare rescue nil)
        score = [sl.to_i / 10 + chain.to_i, 200].min
        rare_w = [5 + score / 5, 40].min
        unc_w = [25 + score / 4, 55].min
        bag = []
        bag.concat([rare] * rare_w) if rare
        bag.concat([uncommon] * unc_w) if uncommon
        bag.concat([common] * [100 - rare_w - unc_w, 10].max) if common
        bag.compact!
        return nil if bag.empty?
        pick = bag[rng.rand(bag.length)]
        rank = proc { |i| i.nil? ? -1 : (i == rare ? 2 : (i == uncommon ? 1 : 0)) }
        now = (pkmn.item_id rescue nil)
        return nil unless now.nil? || rank.call(pick) > rank.call(now)
        pkmn.item = pick
        return pick
      rescue StandardError
        return nil
      end
    end
  end
end
