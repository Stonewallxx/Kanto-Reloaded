# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Double Abilities with KIF: Elite Redux (cody's)
#==============================================================================
# His ask 2026-10-26: Double Abilities supports KIF-ER rather than standing
# down. With its Innates On a Pokémon's ability is one of its KIF-ER choices
# (006_Choice.rb), and a fusion KIF-ER calls dual has two of them, Ability 1
# and 2, and all six innates; KIF-ER runs Ability 2 in battle as an innate
# (010_DualAbilities.rb). So:
#
#   Dual       KIF-ER's dual check knows Kanto Reloaded's (it looks only for
#              Legacy's module, B9): a fusion is dual while Double Abilities
#              is On. Answered from Kanto Reloaded's side, KIF-ER's files
#              untouched; it stands down once KIF-ER reads Reloaded itself
#   The pair   Ability 1 and 2 (the head's pick on the Fusion Screen is
#              Ability 1, the body's Ability 2: Q2a)
#   Battle     KIF-ER runs both: Kanto Reloaded's battle side steps aside for
#              these Pokémon (Battle.rb: no second on the battler)
#   Its rules  no banned pairs, copies stack, no 1 HP for a second Wonder
#              Guard (Q7b, Q8)
#   Fusing     KIF-ER's own picks after a fusion stand down when Kanto
#              Reloaded's Fusion Screen made them
#==============================================================================

module Reloaded
  module DoubleAbilities
    module EliteRedux
      class << self
        def install
          link
          Reloaded::Events.on(:system_ready, :double_abilities_kifer, 50) { link }
          return true
        end

        def link
          return false if @linked || !defined?(::KIFER) || !::KIFER.respond_to?(:dual?)
          Reloaded::Hooks.prepend(FEATURE, ::KIFER.singleton_class, Link, :id => :double_abilities_kifer)
          @linked = true
        end

        def er
          return ::KIFER
        end

        # Its Innates On, and this Pokémon has its choices
        def runs?(pkmn)
          return false unless defined?(::KIFER) && er.respond_to?(:enabled?) && er.enabled?
          return !er.choice_list(pkmn).empty?
        rescue StandardError
          return false
        end

        def second(pkmn)
          return er.chosen_ability2(pkmn)
        rescue StandardError
          return nil
        end

        def head_count(pkmn)
          return er.choices_of(pkmn.get_head_species.id).length
        end

        def side_of(pkmn, index)
          return index.to_i < head_count(pkmn) ? :head : :body
        end

        # Ability 1 and 2, head first
        def pair(pkmn)
          c1 = er.choice_index(pkmn)
          c2 = er.choice2_index(pkmn)
          return nil if c1.nil? || c2.nil?
          list = er.choice_list(pkmn)
          both = [[side_of(pkmn, c1), list[c1]], [side_of(pkmn, c2), list[c2]]]
          return both.sort_by { |s, _id| s == :head ? 0 : 1 }
        rescue StandardError
          return nil
        end

        # A side's choices as [index, id, false]
        def entries(pkmn, side)
          list = er.choice_list(pkmn)
          n = head_count(pkmn)
          range = side == :head ? (0...n) : (n...list.length)
          return range.map { |i| [i, list[i], false] }
        end

        # A capsule's change: the slot holding the ability changed (Ability 1
        # or 2) takes the new index
        def change(pkmn, now, index)
          if er.chosen_ability(pkmn) == now
            er.set_choice(pkmn, index)
          else
            er.set_choice2(pkmn, index)
          end
        end
      end

      module Link
        def dual?(pkmn)
          return true if super
          da = Reloaded::DoubleAbilities
          return false unless da.on? && enabled? && pkmn
          return false unless pkmn.respond_to?(:isFusion?) && pkmn.isFusion?
          return false if pkmn.respond_to?(:isTripleFusion?) && pkmn.isTripleFusion?
          return false if pkmn.respond_to?(:egg?) && pkmn.egg?
          return true
        rescue StandardError
          return false
        end

        def fusion_pick_after(fused, ctx)
          return if Reloaded::DoubleAbilities::Fusing.take_handled
          return super
        end

        def fusion_ability_picker(fused)
          return if Reloaded::DoubleAbilities::Fusing.take_handled
          return super
        end
      end
    end
  end
end
