# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's Rematch Ranks (Tougher Trainers K)
#==============================================================================
# PIF Today: a rematch team gains a level every few rematches and evolves at
# 5, 10, 20 and 30 rematches; nothing else about the trainer changes.
# (Kanto Reloaded: Level Scaling sets rematch levels; PIF's evolutions stay.)
#
# His picks (2026-11-01), on Normal and Hard (Easy as PIF), always on, for
# ordinary trainers only (leaders already bring builds, rules and Ace
# Moments): a trainer ranks up with your wins against them, with the bond
# steps, each rank keeping the ones before it:
#
#   Seasoned   3 wins   one more Pokémon
#   Veteran    7 wins   their ace fully built (a Leader Build); its extra
#                       Adaptation change went (his call, 2026-11-09)
#   Elite     12 wins   one more Pokémon again; their type's Gym Rule (as a
#                       gym's, one: Gym Rules)
#   Master    22 wins   every Pokémon fully built; one more item in their bag
#
# Shown (his picks): the rank's word in its colour on Battle Records (over
# the name on the plate, before the class in the list) and in the record
# toast ("Veteran Hiker Marcos"); the Promotion Card toast when they rank up,
# back on the map (UI/RankToast.rb). Nothing is kept: a rank is read from
# the record's wins.
#==============================================================================

module Reloaded
  module TrainerControl
    module RematchRanks
      Rank = Struct.new(:key, :name, :wins, :rgb, :index)
      RANKS = [Rank.new(:seasoned, "Seasoned", 3, [120, 230, 150], 0), Rank.new(:veteran, "Veteran", 7, [240, 140, 60], 1),
               Rank.new(:elite, "Elite", 12, [176, 96, 240], 2), Rank.new(:master, "Master", 22, [240, 200, 80], 3)].freeze

      class << self
        def install
          Reloaded::Events.on(:trainer_battle_ended, :trainer_control_ranks, 106) { |c| battle_ended(c) }
        end

        def on?
          return defined?(Reloaded::Difficulty) && Reloaded::Difficulty.respond_to?(:level) && Reloaded::Difficulty.level >= 1
        end

        def rank_for(wins)
          return RANKS.reverse.find { |r| wins.to_i >= r.wins }
        end

        # A record's rank: nil under Seasoned, for leaders and your rival, on Easy
        def rank(rec)
          return nil unless on? && rec.is_a?(Hash) && TrainerControl.kind(rec["type"]) == :trainer
          return rank_for(rec["wins"])
        end

        # A trainer's rank as their team loads
        def rank_of(type, name)
          key = TrainerControl.person_key(type, name)
          return key ? rank(Records.get(key)) : nil
        end

        # A trainer in a battle (the one Trainer Control counts)
        def rank_in_battle(trainer)
          key = TrainerControl.person(trainer)
          return key ? rank(Records.get(key)) : nil
        end

        #----------------------------------------------------------------------
        # What each rank brings (Team Expansion, Gym Rules and Trainer Bags
        # ask)
        #----------------------------------------------------------------------
        # Seasoned one more Pokémon, Elite another
        def extra_pokemon(r)
          return 0 unless r
          return r.index >= 2 ? 2 : 1
        end

        # Elite: their type's Gym Rule
        def gym_rule?(r)
          return r && r.index >= 2 ? true : false
        end

        # Master: one more item in their bag
        def extra_items(type, name)
          r = rank_of(type, name)
          return r && r.index >= 3 ? 1 : 0
        end

        # A trainer just loaded (TrainerControl.build_team, after Notoriety):
        # Veteran their ace fully built, Master every Pokémon
        def apply(trainer, type, name, _version)
          r = rank_of(type, name)
          return unless r && r.index >= 1 && defined?(LeaderBuilds)
          party = trainer ? Array(trainer.party).compact : []
          return if party.empty?
          list = r.index >= 3 ? party : [party[Adaptation.ace_index(party)]]
          list.each { |pk| LeaderBuilds.build(pk, nil) }
        rescue StandardError => e
          Reloaded::Log.exception("Rematch Ranks couldn't build #{type}'s team", e, :trainer_control)
        end

        #----------------------------------------------------------------------
        # Ranking up: a win that reaches a rank, its toast back on the map
        #----------------------------------------------------------------------
        def battle_ended(context)
          return unless context[:won] && on?
          Array(context[:people]).each do |key|
            rec = Records.get(key)
            r = rank(rec)
            (@due ||= []) << key if r && rec["wins"].to_i == r.wins
          end
        rescue StandardError => e
          Reloaded::Log.exception("Rematch Ranks couldn't read a battle", e, :trainer_control)
        end

        # Back on the map (TrainerControl's battle hook)
        def after_battle
          due = @due
          @due = nil
          Array(due).each do |key|
            rec = Records.get(key)
            r = rank(rec)
            Reloaded::RankToast.promoted(rec, r) if r && defined?(Reloaded::RankToast)
          end
        end
      end
    end
  end
end
