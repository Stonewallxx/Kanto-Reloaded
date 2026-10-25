#==============================================================================
# Kanto Reloaded: Quality of Life: level locks
#==============================================================================
# A Pokémon locked at a level (set in the Level Lock Manager) gains no EXP
# past it while Level Locking is On; Off pauses every lock without
# forgetting it. The lock is kept on the Pokémon itself (@kr_level_lock, a
# plain number), so it goes with it to the PC, a trade or the Day Care, and
# a save still loads without Kanto Reloaded.
#
# Held at the start of its level, as KIF's Level Cap (Lock) holds a Pokémon
# at its cap: battle EXP (GrowthRate#add_exp while PokeBattle_Battle#
# pbGainExpOne runs), any other EXP (Pokemon#exp=), Pokemon#level= and
# pbChangeLevel stop there. A Rare Candy is refused (can_use_rare_candy)
# instead of used up for nothing (a fix: the old version used it up).
#==============================================================================

module Reloaded
  module QualityOfLife
    module LevelLocks
      IVAR = :@kr_level_lock

      class << self
        def get(pkmn)
          v = pkmn.instance_variable_get(IVAR) rescue nil
          return v.is_a?(Integer) && v > 0 ? v : nil
        end

        def set(pkmn, level)
          pkmn.instance_variable_set(IVAR, level.to_i)
          Reloaded::Log.info("Level Lock Manager: #{pkmn.name} locked at Lv #{level}.", :quality_of_life)
        end

        def clear(pkmn)
          return unless pkmn.instance_variable_defined?(IVAR)
          pkmn.remove_instance_variable(IVAR)
          Reloaded::Log.info("Level Lock Manager: #{pkmn.name} unlocked.", :quality_of_life)
        end

        # The level it's held at now, or nil (no lock, or Level Locking Off)
        def limit(pkmn)
          return nil unless pkmn && Reloaded::QualityOfLife.on?(:level_locking)
          return nil if (pkmn.egg? rescue false)
          return get(pkmn)
        end

        # The most EXP it may have: the start of its locked level
        def exp_limit(pkmn)
          lv = limit(pkmn)
          return nil unless lv
          return pkmn.growth_rate.minimum_exp_for_level(lv)
        rescue StandardError
          return nil
        end

        def install
          h = Reloaded::Hooks
          f = Reloaded::QualityOfLife::FEATURE
          around("Pokemon", :exp=, :qol_lock_exp) do |original, value|
            me = original.receiver
            max = Reloaded::QualityOfLife::LevelLocks.exp_limit(me)
            value = [value.to_i, [max, (me.exp rescue 0).to_i].max].min if max && value.is_a?(Numeric)
            original.call(value)
          end
          around("Pokemon", :level=, :qol_lock_level) do |original, value|
            me = original.receiver
            lv = Reloaded::QualityOfLife::LevelLocks.limit(me)
            value = [value.to_i, [lv, (me.level rescue 0).to_i].max].min if lv && value.is_a?(Numeric)
            original.call(value)
          end
          around("PokeBattle_Battle", :pbGainExpOne, :qol_lock_battle_exp) do |original, idx, *rest|
            Reloaded::QualityOfLife::LevelLocks.gaining = (original.receiver.pbParty(0)[idx] rescue nil)
            begin
              original.call(idx, *rest)
            ensure
              Reloaded::QualityOfLife::LevelLocks.gaining = nil
            end
          end
          around("GameData::GrowthRate", :add_exp, :qol_lock_add_exp) do |original, exp, gain|
            total = original.call(exp, gain)
            pkmn = Reloaded::QualityOfLife::LevelLocks.gaining
            max = pkmn ? Reloaded::QualityOfLife::LevelLocks.exp_limit(pkmn) : nil
            max ? [total, [max, exp].max].min : total
          end
          around(Object, :pbChangeLevel, :qol_lock_change_level) do |original, pkmn, newlevel, *rest|
            lv = Reloaded::QualityOfLife::LevelLocks.limit(pkmn)
            newlevel = [newlevel.to_i, [lv, pkmn.level].max].min if lv
            original.call(pkmn, newlevel, *rest)
          end
          around(Object, :can_use_rare_candy, :qol_lock_rare_candy) do |original, pkmn, *rest|
            lv = Reloaded::QualityOfLife::LevelLocks.limit(pkmn)
            lv && pkmn.level >= lv ? false : original.call(pkmn, *rest)
          end
          return true
        end

        attr_accessor :gaining

        private

        # A hook, made only when its target is there: the game has every
        # one; tests and the preview tool have few (a top-level method is
        # looked for too, as Object always is)
        def around(target, method, id, &blk)
          return false unless Reloaded::QualityOfLife.present?(target, method)
          return Reloaded::Hooks.around(Reloaded::QualityOfLife::FEATURE, target, method, :id => id, &blk)
        end
      end
    end
  end
end
