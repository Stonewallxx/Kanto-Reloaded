# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Trainer Card's counts
#==============================================================================
# What the Records and Stats tabs show. Always counting (his pick): they
# run with the Reloaded Trainer Card Off too, so nothing is lost.
#
#   Records     trainer battles only (his pick): wins, losses, the current
#               and best streak, the last three (who and how it went).
#               Kanto Reloaded counts from the first time it sees the save;
#               Losses start from PIF's own count.
#   Caught      every catch from now, started once with the Pokémon you own
#               that you met yourself
#   Shinies     every shiny met (wild, hatched, received), once each
#   Levels      levels your Pokémon gain from now (battle EXP, candies,
#               Super Candy), started once with how far each Pokémon you own
#               is above the level it was met at
#   PIF's own   Steps, Fusions Made, Eggs Hatched, Trades, Hall of Fame and
#               Gym Rematches are read from PIF's numbers, so they stay right
#               with Kanto Reloaded off
#
# Kept in the save's "trainer_card" section: "counts", "recent", "shinies"
# (personal IDs) and "seeded" (what's been started once).
#
#   Reloaded::TrainerCard::Counters.get(:wins)
#   Reloaded::TrainerCard::Counters.stat(:caught)     # any stat, PIF's too
#   Reloaded::TrainerCard::Counters.add(:caught, 1)   # a mod's own catches
#   (milestone tiers and what each gives: Unlocks.rb)
#==============================================================================

module Reloaded
  module TrainerCard
    module Counters
      COUNTS = %w[wins losses streak best_streak caught levels].freeze
      RECENT = 3
      # The Stats tab, in order: [id, name, the item whose Bag icon shows]
      STATS = [[:steps, "Steps", :BICYCLE], [:caught, "Caught", :POKEBALL], [:fusions, "Fusions Made", :DNASPLICERS],
               [:eggs, "Eggs Hatched", :OVALCHARM], [:shinies, "Shinies Found", :SHINYCHARM], [:trades, "Trades", :LINKINGCORD],
               [:levels, "Levels Gained", :RARECANDY], [:hall_of_fame, "Hall of Fame", :AMULETCOIN]].freeze
      NAMES = { :wins => "Wins", :best_streak => "Best Streak" }.freeze

      class << self
        def boot
          Reloaded::Events.on(:save_loaded, :trainer_card_counts, 60) { seed }
          Reloaded::Events.on(:new_game, :trainer_card_counts, 60) { seed }
          Reloaded::Events.on(:saving, :trainer_card_counts, 60) { note_owned_shinies }
          install
          return true
        end

        def data
          return Reloaded::SaveStore.section(Reloaded::TrainerCard::SECTION)
        end

        def counts
          d = data
          return {} unless d
          return (d["counts"] ||= {})
        end

        def get(id)
          return counts[id.to_s].to_i
        end

        def add(id, n = 1)
          return unless data && n.to_i != 0
          c = counts
          c[id.to_s] = c[id.to_s].to_i + n.to_i
        end

        #----------------------------------------------------------------------
        # Every stat and record by name, PIF's own read live
        #----------------------------------------------------------------------
        def stat(id)
          tc = Reloaded::TrainerCard
          case id.to_sym
          when :steps then return ($PokemonGlobal.stepcount rescue 0).to_i
          when :fusions then return tc.variable(:VAR_FUSE_COUNTER)
          when :eggs then return tc.variable(:VAR_NB_EGGS_HATCHED)
          when :trades then return pif_stat(:@nb_trades)
          when :hall_of_fame then return ($PokemonGlobal.hallOfFameLastNumber rescue 0).to_i
          when :gym_rematches then return tc.variable(:VAR_STAT_LEADER_REMATCH)
          when :shinies then return shinies.length
          when :battles then return get(:wins) + get(:losses)
          end
          return get(id)
        end

        # PIF's TrainerStatistics keeps its numbers with no readers
        def pif_stat(field)
          s = $Trainer && $Trainer.respond_to?(:stats) ? $Trainer.stats : nil
          return s ? s.instance_variable_get(field).to_i : 0
        rescue StandardError
          return 0
        end

        def shinies
          d = data
          return [] unless d
          return (d["shinies"] ||= [])
        end

        # The last three trainer battles, newest first:
        # [{ "won", "type", "name" }]
        def recent
          d = data
          return [] unless d
          return (d["recent"] ||= [])
        end

        def name(id)
          entry = STATS.find { |s| s[0] == id }
          return _INTL(entry ? entry[1] : NAMES[id].to_s)
        end

        def num(v)
          return v.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
        end

        # A count moved: unlocks it reaches are earned (their toasts wait for the map)
        def changed
          Reloaded::TrainerCard::Unlocks.check if defined?(Reloaded::TrainerCard::Unlocks)
        end

        #----------------------------------------------------------------------
        # Started once per save (his picks: Records and Levels from now,
        # seeded from what the save already has)
        #----------------------------------------------------------------------
        def seed
          d = data
          return unless d && $Trainer
          seeded = (d["seeded"] ||= {})
          c = counts
          unless seeded["losses"]
            c["losses"] = c["losses"].to_i + pif_stat(:@nb_battles_lost)
            seeded["losses"] = true
          end
          mons = owned
          unless seeded["caught"]
            c["caught"] = c["caught"].to_i + mons.count { |pk| met_by_player?(pk) }
            seeded["caught"] = true
          end
          unless seeded["levels"]
            c["levels"] = c["levels"].to_i + mons.sum { |pk| levels_above_met(pk) }
            seeded["levels"] = true
          end
          note_owned_shinies
          seeded["shinies"] = true
          Reloaded::Log.info("Trainer Card counts: #{c.map { |k, v| "#{k} #{v}" }.join(", ")}, shinies #{shinies.length}", :trainer_card)
        rescue StandardError => e
          Reloaded::Log.exception("The Trainer Card's counts couldn't be started", e, :trainer_card)
        end

        def owned
          return Reloaded::TrainerCard.owned_pokemon
        end

        # How far a Pokémon is above the level it was met at
        def levels_above_met(pk)
          lv = pk.level.to_i
          met = (pk.obtain_level rescue nil)
          return met ? [lv - met.to_i, 0].max : 0
        rescue StandardError
          return 0
        end

        def met_by_player?(pk)
          return false unless (pk.obtain_method rescue nil).to_i == 0
          me = ($Trainer.id rescue nil)
          return !me.nil? && (pk.owner.id rescue nil) == me
        end

        # A shiny you own now, once each (catches, hatches, gifts, trades)
        def note_owned_shinies
          return unless data
          owned.each { |pk| shiny_met(pk) }
        end

        def shiny_met(pk)
          return unless pk && (pk.shiny? rescue false)
          pid = (pk.personalID rescue nil)
          list = shinies
          list << pid if pid && !list.include?(pid)
        end

        #----------------------------------------------------------------------
        # The battle's end (trainer battles only; link battles, the battle
        # facilities and Multiplayer's left out)
        #----------------------------------------------------------------------
        def counts?(battle)
          return false unless (battle.trainerBattle? rescue false)
          return false unless battle.instance_variable_get(:@internalBattle)
          return false if (pbBattleChallenge.pbInChallenge? rescue false)
          return false if battle.class.name.to_s =~ /Multiplayer|Coop|PvP|Online|Sandbox/i
          return true
        end

        def battle_ended(battle)
          return unless data
          won = case battle.instance_variable_get(:@decision)
                when 1 then true
                when 2 then false
                end
          return if won.nil? || !counts?(battle)
          c = counts
          if won
            add(:wins)
            c["streak"] = c["streak"].to_i + 1
            c["best_streak"] = [c["best_streak"].to_i, c["streak"]].max
          else
            add(:losses)
            c["streak"] = 0
          end
          foe = Array(battle.instance_variable_get(:@opponent)).compact.first
          entry = { "won" => won, "type" => (foe.trainer_type.to_s rescue ""), "name" => (foe.name.to_s rescue "") }
          list = recent
          list.unshift(entry)
          list.slice!(RECENT..-1)
          changed
        rescue StandardError => e
          Reloaded::Log.warning_once("A battle couldn't be counted on the Trainer Card: #{e.message}", :trainer_card)
        end

        # A wild battle's shiny, met
        def battle_started(battle)
          return unless data && (battle.wildBattle? rescue false)
          Array(battle.pbParty(1)).each { |pk| shiny_met(pk) }
        rescue StandardError
          nil
        end

        # A Pokémon of yours went up from level `from`
        def gained(pkmn, from)
          return unless data && pkmn
          up = pkmn.level.to_i - from.to_i
          return unless up > 0
          add(:levels, up)
          changed
        rescue StandardError
          nil
        end

        #----------------------------------------------------------------------
        # Hooks
        #----------------------------------------------------------------------
        def install
          h = Reloaded::Hooks
          if defined?(::PokeBattle_Battle)
            if ::PokeBattle_Battle.method_defined?(:pbStartBattle)
              h.around(nil, ::PokeBattle_Battle, :pbStartBattle, :id => :trainer_card_battle_start) do |original, *args|
                Reloaded::TrainerCard::Counters.battle_started(original.receiver)
                original.call(*args)
              end
            end
            if defined?(Reloaded::TrainerControl)
              # one place counts a trainer battle's end: Trainer Control's
              # (its records and these never disagree)
              Reloaded::Events.on(:trainer_battle_ended, :trainer_card_counts) do |context|
                Reloaded::TrainerCard::Counters.battle_ended(context[:battle])
              end
            elsif ::PokeBattle_Battle.method_defined?(:pbEndOfBattle)
              h.around(nil, ::PokeBattle_Battle, :pbEndOfBattle, :id => :trainer_card_battle_end) do |original, *args|
                Reloaded::TrainerCard::Counters.battle_ended(original.receiver)
                original.call(*args)
              end
            end
            if ::PokeBattle_Battle.method_defined?(:pbRecordAndStoreCaughtPokemon)
              h.around(nil, ::PokeBattle_Battle, :pbRecordAndStoreCaughtPokemon, :id => :trainer_card_caught) do |original, *args|
                caught = Array(original.receiver.instance_variable_get(:@caughtPokemon)).compact
                Reloaded::TrainerCard::Counters.add(:caught, caught.length)
                caught.each { |pk| Reloaded::TrainerCard::Counters.shiny_met(pk) }
                ret = original.call(*args)
                Reloaded::TrainerCard::Counters.changed
                ret
              end
            end
            if ::PokeBattle_Battle.method_defined?(:pbGainExpOne)
              h.around(nil, ::PokeBattle_Battle, :pbGainExpOne, :id => :trainer_card_levels) do |original, *args|
                pkmn = (original.receiver.pbParty(0)[args[0]] rescue nil)
                from = pkmn ? pkmn.level : nil
                ret = original.call(*args)
                Reloaded::TrainerCard::Counters.gained(pkmn, from) if from
                ret
              end
            end
          end
          if ::Object.private_method_defined?(:pbChangeLevel) || ::Object.method_defined?(:pbChangeLevel)
            h.around(nil, ::Object, :pbChangeLevel, :id => :trainer_card_candies) do |original, pkmn, *rest|
              from = (pkmn.level rescue nil)
              ret = original.call(pkmn, *rest)
              Reloaded::TrainerCard::Counters.gained(pkmn, from) if from
              ret
            end
          end
          if ::Object.private_method_defined?(:pbHatch) || ::Object.method_defined?(:pbHatch)
            h.around(nil, ::Object, :pbHatch, :id => :trainer_card_hatched) do |original, pkmn, *rest|
              ret = original.call(pkmn, *rest)
              Reloaded::TrainerCard::Counters.shiny_met(pkmn)
              Reloaded::TrainerCard::Counters.changed
              ret
            end
          end
        end
      end
    end
  end
end
