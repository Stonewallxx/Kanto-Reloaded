# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Double Abilities (Battle)
#==============================================================================
# A fusion's second ability works in battle wherever its first does, in
# EBDX's battle and PIF's alike (abilities are battle logic: only the pop-up
# is per scene, PopUps.rb). The design is KIF: Elite Redux's (cody's,
# 004_Triggers.rb, credited) with old Kanto Reloaded's slot:
#
#   The second   @kr_ability2_id on the battler, set as its Pokémon comes in
#                (nil: none, the same as the first, or KIF-ER runs it)
#   Handlers     each of the game's 46 BattleHandlers.trigger*Ability calls
#                runs the first as asked; when it was for the owner's first
#                and the owner has a second, the second runs too, in a mode:
#                  :chain  the first's answer goes into the second's call
#                          (speed, priority, a move's type, the crit stage)
#                  :any    the second only when the first said no (an
#                          immunity or a block shows one pop-up)
#                  :all    both (damage, switch-in, end of round)
#                The owner is an argument, or for the ally hashes the ally of
#                one whose first is the ability passed (KIF-ER's search).
#                While the second runs its battler's @kr_slot is 2, so its
#                pop-up and every message name it
#   Checks       hasActiveAbility? sees the second too; a hit leaves @kr_inline
#                so the pop-up the caller shows next names it (cleared when a
#                pop-up hides, a move starts or a round ends)
#   Changes      a new ability goes to the slot that's working (his pick, Q13):
#                Trace or Receiver as the second change the second; Worry
#                Seed, Simple Beam, Entrainment, Skill Swap, Role Play and
#                Mummy the first; a change that makes a banned pair switches
#                the second off for the battle. Transform and Imposter copy
#                both. Gastro Acid stops both
#   By name      Stance Change, Disguise and Shields Down work as the second
#                too (his pick, Q14): the game checks them by name
#   Wonder Guard a paired one blocks Wonder Guard Blocks hits a battle, then
#                wears off (his pick, Q8)
#   Switch-in    the second's switch-in runs once per time in (Skill Swap,
#                Trace and Mega Evolution run the first's again)
#   Battle Info  cody's record of revealed abilities isn't told the first was
#                shown when the second's pop-up was (B5)
#
# Hooked through Reloaded::Hooks.prepend (battle hot paths): with no second
# the cost is one ivar check per call.
#==============================================================================

module Reloaded
  module DoubleAbilities
    module Battle
      # Owner (the argument after the ability, or [:ally, i]) and mode,
      # checked against 002_BattleHandlers.rb's signatures (:99-470); a
      # :chain's third is the argument the answer goes into
      TRIGGERS = {
        :SpeedCalcAbility                    => [0, :chain, 1],
        :WeightCalcAbility                   => [0, :chain, 1],
        :AbilityOnHPDroppedBelowHalf         => [0, :any],
        :StatusCheckAbilityNonIgnorable      => [0, :any],
        :StatusImmunityAbility               => [0, :any],
        :StatusImmunityAbilityNonIgnorable   => [0, :any],
        :StatusImmunityAllyAbility           => [[:ally, 0], :any],
        :AbilityOnStatusInflicted            => [0, :all],
        :StatusCureAbility                   => [0, :all],
        :StatLossImmunityAbility             => [0, :any],
        :StatLossImmunityAbilityNonIgnorable => [0, :any],
        :StatLossImmunityAllyAbility         => [0, :any],
        :AbilityOnStatGain                   => [0, :all],
        :AbilityOnStatLoss                   => [0, :all],
        :PriorityChangeAbility               => [0, :chain, 2],
        :PriorityBracketChangeAbility        => [0, :chain, 1],
        :PriorityBracketUseAbility           => [0, :all],
        :AbilityOnFlinch                     => [0, :all],
        :MoveBlockingAbility                 => [0, :any],
        :MoveImmunityTargetAbility           => [1, :any],
        :MoveBaseTypeModifierAbility         => [0, :chain, 2],
        :AccuracyCalcUserAbility             => [1, :all],
        :AccuracyCalcUserAllyAbility         => [[:ally, 1], :all],
        :AccuracyCalcTargetAbility           => [2, :all],
        :DamageCalcUserAbility               => [0, :all],
        :DamageCalcUserAllyAbility           => [[:ally, 0], :all],
        :DamageCalcTargetAbility             => [1, :all],
        :DamageCalcTargetAbilityNonIgnorable => [1, :all],
        :DamageCalcTargetAllyAbility         => [[:ally, 1], :all],
        :CriticalCalcUserAbility             => [0, :chain, 2],
        :CriticalCalcTargetAbility           => [1, :chain, 2],
        :TargetAbilityOnHit                  => [1, :all],
        :UserAbilityOnHit                    => [0, :all],
        :UserAbilityEndOfMove                => [0, :all],
        :TargetAbilityAfterMoveUse           => [0, :all],
        :EORWeatherAbility                   => [1, :all],
        :EORHealingAbility                   => [0, :all],
        :EOREffectAbility                    => [0, :all],
        :EORGainItemAbility                  => [0, :all],
        :CertainSwitchingUserAbility         => [0, :any],
        :TrappingTargetAbility               => [1, :any],
        :AbilityOnSwitchIn                   => [0, :all],
        :AbilityOnSwitchOut                  => [0, :all],
        :AbilityChangeOnBattlerFainting      => [0, :all],
        :AbilityOnBattlerFainting            => [0, :all],
        :RunFromBattleAbility                => [0, :any]
      }.freeze

      class << self
        def install
          h = Reloaded::Hooks
          h.prepend(FEATURE, ::BattleHandlers.singleton_class, Dispatch, :id => :double_abilities_dispatch) if defined?(::BattleHandlers)
          h.prepend(FEATURE, ::PokeBattle_Battle, BattleSplash, :id => :double_abilities_battle) if defined?(::PokeBattle_Battle)
          h.prepend(FEATURE, ::PokeBattle_Move, MoveByName, :id => :double_abilities_move) if defined?(::PokeBattle_Move)
          return true unless defined?(::PokeBattle_Battler)
          h.prepend(FEATURE, ::PokeBattle_Battler, BattlerSecond, :id => :double_abilities_battler)
          h.around(FEATURE, "PokeBattle_Battler", :pbInitPokemon, :id => :double_abilities_init) do |original, *args|
            ret = original.call(*args)
            Reloaded::DoubleAbilities::Battle.take(original.receiver)
            ret
          end
          h.around(FEATURE, "PokeBattle_Battler", :pbUpdate, :id => :double_abilities_update) do |original, *args|
            ret = original.call(*args)
            Reloaded::DoubleAbilities::Battle.take(original.receiver, false) if args[0]
            ret
          end
          h.around(FEATURE, "PokeBattle_Battler", :pbTransform, :id => :double_abilities_transform) do |original, target, *rest|
            ret = original.call(target, *rest)
            b = original.receiver
            b.instance_variable_set(:@kr_ability2_id, target.instance_variable_get(:@kr_ability2_id)) if target.is_a?(::PokeBattle_Battler)
            ret
          end
          return true
        end

        def id_of(a)
          return nil if a.nil?
          return a if a.is_a?(Symbol)
          return a.respond_to?(:id) ? a.id : a
        end

        # The battler's second as its Pokémon comes in (fresh: its switch-in
        # may run)
        def take(battler, fresh = true)
          pkmn = battler.pokemon
          da = Reloaded::DoubleAbilities
          a2 = nil
          if pkmn && da.applies?(pkmn) && !da.elite_redux?(pkmn)
            a2 = da.second_id(pkmn)
            a2 = nil if a2 == battler.instance_variable_get(:@ability_id)
          end
          battler.instance_variable_set(:@kr_ability2_id, a2)
          battler.instance_variable_set(:@kr_inline, nil)
          battler.instance_variable_set(:@kr_entry_done, nil) if fresh
        rescue StandardError => e
          Reloaded::Log.warning_once("Double Abilities: a battler's second couldn't be read (#{e.class}: #{e.message})", FEATURE)
        end

        # The battler a trigger is for
        def owner(spec, ability, args)
          if spec.is_a?(Array)
            b = args[spec[1]]
            return nil unless b.respond_to?(:eachAlly)
            want = id_of(ability)
            hit = nil
            b.eachAlly { |a| hit ||= a if a.instance_variable_get(:@ability_id) == want }
            return hit
          end
          b = args[spec]
          return b.is_a?(::PokeBattle_Battler) ? b : nil
        end

        # The owner's second, when this call was for its first and the second
        # may run (not the same, not already running, not Gastro Acid)
        def second(owner, ability)
          a2 = owner.instance_variable_get(:@kr_ability2_id)
          return nil if a2.nil?
          main = owner.instance_variable_get(:@ability_id)
          return nil if a2 == main || id_of(ability) != main
          return nil if owner.instance_variable_get(:@kr_slot) == 2
          return nil unless owner.abilityActive?(true)
          return a2
        end

        def with_slot(battler, slot)
          old = battler.instance_variable_get(:@kr_slot)
          battler.instance_variable_set(:@kr_slot, slot)
          battler.instance_variable_set(:@kr_inline, nil)
          return yield
        ensure
          battler.instance_variable_set(:@kr_slot, old)
        end

        # Both run inside the pop-ups' hold (PopUps.rb): a pop-up the first
        # shows waits for the second's
        def holding(battler, &block)
          pu = defined?(Reloaded::DoubleAbilities::PopUps) ? Reloaded::DoubleAbilities::PopUps : nil
          return pu ? pu.holding(battler, &block) : block.call
        end

        #----------------------------------------------------------------------
        # Wonder Guard with a partner: blocks this many hits a battle (his
        # pick, Q8; the number is Wonder Guard Blocks)
        #----------------------------------------------------------------------
        def wonder_guard_spent?(battler)
          return blocks_used(battler) >= Reloaded::DoubleAbilities.blocks
        end

        def blocks_used(battler)
          t = battler.battle.instance_variable_get(:@kr_wg_blocks)
          return t ? t[battler.pokemon].to_i : 0
        end

        def wonder_guard_blocked(battler)
          battle = battler.battle
          t = battle.instance_variable_get(:@kr_wg_blocks) || battle.instance_variable_set(:@kr_wg_blocks, {}.compare_by_identity)
          t[battler.pokemon] = t[battler.pokemon].to_i + 1
          return unless t[battler.pokemon] == Reloaded::DoubleAbilities.blocks
          battle.pbDisplay(_INTL("{1}'s Wonder Guard wore off!", battler.pbThis))
        end

        def clear_inline(battle)
          battle.battlers.each { |b| b.instance_variable_set(:@kr_inline, nil) if b }
        end
      end

      #------------------------------------------------------------------------
      # The handlers: one method per trigger on BattleHandlers' singleton (no
      # allocation when the owner has no second)
      #------------------------------------------------------------------------
      Dispatch = Module.new
      TRIGGERS.each do |name, spec|
        Dispatch.send(:define_method, :"trigger#{name}") do |ability, *args|
          bt = Reloaded::DoubleAbilities::Battle
          owner = bt.owner(spec[0], ability, args)
          return super(ability, *args) unless owner && owner.instance_variable_get(:@kr_ability2_id)
          return super(ability, *args) unless Reloaded::DoubleAbilities.on?
          a2 = bt.second(owner, ability)
          return super(ability, *args) unless a2
          wg = name == :MoveImmunityTargetAbility
          entry = name == :AbilityOnSwitchIn
          bt.holding(owner) do
            main = bt.id_of(ability)
            ret = if wg && main == :WONDERGUARD && bt.wonder_guard_spent?(owner)
                    false
                  else
                    bt.with_slot(owner, 1) { super(ability, *args) }
                  end
            bt.wonder_guard_blocked(owner) if wg && ret && main == :WONDERGUARD
            if entry && owner.instance_variable_get(:@kr_entry_done)
              ret
            else
              owner.instance_variable_set(:@kr_entry_done, true) if entry
              case spec[1]
              when :chain
                more = args.dup
                more[spec[2]] = ret
                bt.with_slot(owner, 2) { super(a2, *more) }
              when :any
                next ret if ret
                next false if wg && a2 == :WONDERGUARD && bt.wonder_guard_spent?(owner)
                shown = owner.instance_variable_get(:@kr_splash_n).to_i
                r2 = bt.with_slot(owner, 2) { super(a2, *args) }
                bt.wonder_guard_blocked(owner) if wg && r2 && a2 == :WONDERGUARD
                # an immunity its caller announces after this returns (PIF's
                # status immunities): name the second there (old KR's splash
                # serial: only when the handler showed none itself)
                if r2 && owner.instance_variable_get(:@kr_splash_n).to_i == shown
                  owner.instance_variable_set(:@kr_inline, a2)
                end
                r2
              else
                r2 = bt.with_slot(owner, 2) { super(a2, *args) }
                ret || r2
              end
            end
          end
        end
      end

      #------------------------------------------------------------------------
      # The battler
      #------------------------------------------------------------------------
      module BattlerSecond
        # (ignore_fainted, and KIF's mold_broken: passed on as they came)
        def hasActiveAbility?(check_ability, *rest)
          if super
            @kr_inline = nil if @kr_inline
            return true
          end
          return kr_second_matches?(check_ability, rest[0] || false, rest[1] || false)
        end

        # PIF's alias of the old hasActiveAbility? (001_PokeBattle_Battler.rb:398)
        def hasWorkingAbility(check_ability, *rest)
          if super
            @kr_inline = nil if @kr_inline
            return true
          end
          return kr_second_matches?(check_ability, rest[0] || false, false)
        end

        def kr_second_matches?(check_ability, ignore_fainted, mold_broken)
          a2 = @kr_ability2_id
          return false if a2.nil? || mold_broken || a2 == @ability_id
          hit = check_ability.is_a?(Array) ? check_ability.include?(a2) : Reloaded::DoubleAbilities::Battle.id_of(check_ability) == a2
          return false unless hit && abilityActive?(ignore_fainted) && Reloaded::DoubleAbilities.on?
          @kr_inline = a2
          return true
        end

        # The second's while it works (its handler, or right after a check
        # found it): every pop-up and message names it
        def kr_second_showing?
          a2 = @kr_ability2_id
          return false if a2.nil?
          return @kr_slot == 2 || (@kr_slot.nil? && @kr_inline == a2)
        end

        def abilityName
          if kr_second_showing?
            d = GameData::Ability.try_get(@kr_ability2_id)
            return d.name if d
          end
          return super
        end

        # The slot that's working takes the new ability (his pick, Q13)
        def ability=(value)
          return super if @kr_ability2_id.nil?
          da = Reloaded::DoubleAbilities
          if kr_second_showing?
            d = GameData::Ability.try_get(value)
            @kr_ability2_id = d ? d.id : nil
            @kr_inline = @kr_ability2_id if @kr_inline
          else
            super
          end
          if @kr_ability2_id && (@kr_ability2_id == @ability_id || da.banned?(@ability_id, @kr_ability2_id))
            Reloaded::Log.info("Double Abilities: #{pbThis}'s second switched off for this battle (#{@ability_id} + #{@kr_ability2_id})", FEATURE) if @kr_ability2_id != @ability_id
            @kr_ability2_id = nil
          end
        end

        # Other mods asking the battler (KIF's ModCompat names)
        def ability2_id
          return @kr_ability2_id || super
        end

        def ability2
          return GameData::Ability.try_get(@kr_ability2_id) if @kr_ability2_id
          return super
        end

        def ability2Name
          a = @kr_ability2_id && GameData::Ability.try_get(@kr_ability2_id)
          return a ? a.name : super
        end

        # Stance Change as the second: the game checks the first by name just
        # before the move's type (007_Battler_UseMove.rb:221-232)
        def pbUseMove(choice, specialUsage = false)
          Reloaded::DoubleAbilities::Battle.clear_inline(@battle)
          @kr_stance = (@kr_ability2_id == :STANCECHANGE && @ability_id != :STANCECHANGE) ? choice : nil
          return super
        ensure
          @kr_stance = nil
        end

        # Shields Down as the second (001_PokeBattle_Battler.rb:761)
        def checkHPRelatedFormChange(new_hp)
          return super unless @kr_ability2_id == :SHIELDSDOWN && @ability_id != :SHIELDSDOWN && abilityActive?
          first = @ability_id
          @ability_id = :SHIELDSDOWN
          begin
            return super
          ensure
            @ability_id = first
          end
        end
      end

      #------------------------------------------------------------------------
      # The moves: Stance Change and Disguise as the second
      #------------------------------------------------------------------------
      module MoveByName
        def pbCalcType(user)
          choice = user.respond_to?(:pokemon) ? user.instance_variable_get(:@kr_stance) : nil
          if choice && equal?(choice[2])
            user.instance_variable_set(:@kr_stance, nil)
            if damagingMove?
              user.instance_variable_set(:@kr_inline, :STANCECHANGE)
              user.stanceChangeEffect(user.pbFindUser(choice, self), true)
            elsif id == :KINGSSHIELD
              user.instance_variable_set(:@kr_inline, :STANCECHANGE)
              user.stanceChangeEffect(user.pbFindUser(choice, self), false)
            end
          end
          return super
        end

        # 002_Move_Usage.rb:166-170: the game asks target.ability == :DISGUISE
        def pbCheckDamageAbsorption(user, target)
          a2 = target.instance_variable_get(:@kr_ability2_id)
          return super unless a2 == :DISGUISE && target.instance_variable_get(:@ability_id) != :DISGUISE
          return super unless target.abilityActive?
          first = target.instance_variable_get(:@ability_id)
          target.instance_variable_set(:@ability_id, :DISGUISE)
          begin
            super
          ensure
            target.instance_variable_set(:@ability_id, first)
          end
          target.instance_variable_set(:@kr_inline, :DISGUISE) if target.damageState.disguise
        end
      end

      #------------------------------------------------------------------------
      # The battle: pop-ups counted, inline names ended, cody's record kept
      #------------------------------------------------------------------------
      module BattleSplash
        def pbShowAbilitySplash(battler, *args)
          return super unless battler && battler.instance_variable_get(:@kr_ability2_id)
          battler.instance_variable_set(:@kr_splash_n, battler.instance_variable_get(:@kr_splash_n).to_i + 1)
          return super unless battler.kr_second_showing? && battler.pokemon
          # cody's Battle Info notes the first for a pop-up without a name
          # (BattleInfo.rb:915-923): put its note back after the second's
          known = @cody_known_abilities
          k = battler.pokemon.object_id
          had = known && known.has_key?(k)
          was = had ? known[k] : nil
          ret = super
          if @cody_known_abilities
            had ? @cody_known_abilities[k] = was : @cody_known_abilities.delete(k)
          end
          return ret
        end

        def pbHideAbilitySplash(battler, *args)
          ret = super
          battler.instance_variable_set(:@kr_inline, nil) if battler && battler.instance_variable_get(:@kr_inline)
          return ret
        end

        def pbEndOfRoundPhase(*args)
          Reloaded::DoubleAbilities::Battle.clear_inline(self)
          return super
        end
      end
    end
  end
end
