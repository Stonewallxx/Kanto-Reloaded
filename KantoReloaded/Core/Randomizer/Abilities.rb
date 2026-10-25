# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Per-Pokémon Abilities
#==============================================================================
# Per Pokémon (a row under cody's Abilities): each Pokémon rolls its own
# ability from the pool his Abilities row picks for its types (Random: any;
# Flavour: his themed list; Bound: what its types have in the base game),
# with his No Self-Harm and the player's banned abilities. Abilities only
# one Pokémon may have (Disguise, Stance Change...) stay with their own.
#
#   New Pokémon      rolled when made (wild, gift, static, egg): from the
#                    seed, the Pokémon's personal ID and species, so the
#                    same Pokémon always rolls the same
#   Trainers         Fixed by the seed, the trainer and the slot (the same
#                    every battle), or Dynamic (a new roll each battle)
#   Evolving         keeps its ability (the game clears it; it's put back)
#   Fusing           the game's own choice between the two parts' abilities
#   Unfusing         each part comes back as it was, its roll with it (the
#                    game keeps the two original Pokémon in the fusion)
#   Turned On        only Pokémon made from then on; the party and boxes
#   mid-run          keep theirs
#   Pinkan Island    no rolls (cody's rule: the island plays as in PIF)
#
# A rolled Pokémon is marked @kr_ability (a Symbol: loads without Kanto
# Reloaded). Rolls never touch the game's random numbers.
#==============================================================================

begin
  require "zlib" unless defined?(::Zlib)
rescue LoadError
  nil
end

module Reloaded
  module Randomizer
    module Abilities
      # Abilities only their own Pokémon may roll; other features can add
      # theirs (add_owner_only)
      OWNER_ONLY = [:DISGUISE, :SHIELDSDOWN, :STANCECHANGE, :MULTITYPE, :FORECAST, :WONDERGUARD, :POWERCONSTRUCT,
                    :SCHOOLING, :ZENMODE, :RKSSYSTEM, :COMATOSE, :BATTLEBOND, :FLOWERGIFT, :ICEFACE, :GULPMISSILE,
                    :HUNGERSWITCH, :TERASHIFT, :ZEROTOHERO].freeze

      class << self
        def owner_only
          @owner_only ||= OWNER_ONLY.dup
        end

        def add_owner_only(id)
          owner_only << id.to_sym unless owner_only.include?(id.to_sym)
        end

        # Rolling now: the feature, his module, a randomized save, Per
        # Pokémon On, an Abilities pool, not on Pinkan Island
        def active?
          r = Reloaded::Randomizer
          return false unless r.randomized? && r.per_pokemon?
          return false unless ::KIF::Rand.dget(:abilities) > 0
          return false if (::KIF::Rand.pinkan? rescue false)
          return true
        rescue StandardError
          return false
        end

        # The pool for this Pokémon: his, for its (randomized) types, minus
        # abilities only another Pokémon may have
        def pool_for(pkmn)
          types = [pkmn.type1, pkmn.type2].compact.uniq
          own = own_abilities(pkmn)
          return ::KIF::Rand.ability_pool(types).reject { |a| owner_only.include?(a) && !own.include?(a) }
        end

        # The base game's abilities of its species (both parts of a fusion)
        def own_abilities(pkmn)
          sp = pkmn.species_data
          parts = if pkmn.isFusion? && sp.respond_to?(:head_pokemon) && sp.respond_to?(:body_pokemon)
                    [sp.head_pokemon.species, sp.body_pokemon.species]
                  else
                    [sp.species]
                  end
          orig = ::KIF::Rand.originals
          return parts.flat_map do |s|
            o = orig[s]
            o ? Array(o[:@abilities]) + Array(o[:@hidden_abilities]) : []
          end
        rescue StandardError
          return []
        end

        # Sets the ability the key rolls (index from its CRC: the same key,
        # the same ability)
        def roll(pkmn, key = nil, rng = nil)
          pool = pool_for(pkmn)
          return nil if pool.empty?
          i = rng ? rng.rand(pool.length) : Zlib.crc32(key.to_s) % pool.length
          pkmn.ability = pool[i]
          pkmn.instance_variable_set(:@kr_ability, pool[i])
          return pool[i]
        end

        def roll_new(pkmn)
          roll(pkmn, "#{::KIF::Rand.seed}|abil|#{pkmn.personalID}|#{pkmn.species}")
        end

        # A trainer's team: Fixed (the seed, the trainer, the slot) or Dynamic
        def roll_trainer(trainer_data, party)
          dynamic = Reloaded::Randomizer.get(:kr_trainer_rolls) == 1
          rng = dynamic ? Random.new : nil
          who = [(trainer_data.trainer_type rescue nil), (trainer_data.real_name rescue nil), (trainer_data.version rescue nil)].join("|")
          Array(party).each_with_index do |pkmn, slot|
            next unless pkmn
            roll(pkmn, "#{::KIF::Rand.seed}|abil|#{who}|#{slot}", rng)
          end
        end

        def install
          h = Reloaded::Hooks
          feature = Reloaded::Randomizer::FEATURE
          if defined?(::Pokemon)
            h.around(feature, ::Pokemon, :initialize, :id => :randomizer_per_pokemon) do |original, *args|
              result = original.call(*args)
              Reloaded::Randomizer::Abilities.roll_new(original.receiver) if Reloaded::Randomizer::Abilities.active?
              result
            end
            # the game clears a forced ability on evolving and fusing: a
            # rolled one is put back (fusing then asks as the game does)
            h.around(feature, ::Pokemon, :species=, :id => :randomizer_keep_ability) do |original, *args|
              pkmn = original.receiver
              kept = pkmn.instance_variable_get(:@kr_ability) ? pkmn.instance_variable_get(:@ability) : nil
              result = original.call(*args)
              pkmn.instance_variable_set(:@ability, kept) if kept && pkmn.instance_variable_get(:@ability).nil?
              result
            end
          end
          if defined?(::GameData::Trainer)
            h.around(feature, ::GameData::Trainer, :to_trainer, :id => :randomizer_trainer_abilities) do |original, *args|
              trainer = original.call(*args)
              if Reloaded::Randomizer::Abilities.active? && trainer.respond_to?(:party)
                Reloaded::Randomizer::Abilities.roll_trainer(original.receiver, trainer.party)
              end
              trainer
            end
          end
        end
      end
    end
  end
end
