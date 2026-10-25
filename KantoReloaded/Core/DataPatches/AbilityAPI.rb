#==============================================================================
# Kanto Reloaded: abilities from a mod's scripts
#==============================================================================
# For a mod whose new ability needs behaviour, not only data:
#
#   Reloaded::Abilities.register(:SAND_SPIRIT, :name => "Sand Spirit",
#     :description => "Raises Speed in a sandstorm.", :mod => "My Mod")
#   Reloaded::Abilities.on_speed_calc(:SAND_SPIRIT) { |ability, battler, mult| ... }
#   Reloaded::Abilities.copy_behavior(:SAND_RUSH, :SAND_SPIRIT)
#
# register adds the ability as an abilities data patch (it shows in the
# Patch Viewer under the mod), so it is in the game's data after every build,
# Hot Reload too. on_<event> adds the behaviour to the game's battle handlers
# (BattleHandlers::*); each friendly name below maps to one, and on(name,
# ability) takes a handler's own name too.
#==============================================================================

module Reloaded
  module Abilities
    HANDLERS = {
      :speed_calc => :SpeedCalcAbility, :weight_calc => :WeightCalcAbility,
      :hp_dropped_below_half => :AbilityOnHPDroppedBelowHalf,
      :status_check_non_ignorable => :StatusCheckAbilityNonIgnorable,
      :status_immunity => :StatusImmunityAbility, :status_immunity_non_ignorable => :StatusImmunityAbilityNonIgnorable,
      :status_immunity_ally => :StatusImmunityAllyAbility, :status_inflicted => :AbilityOnStatusInflicted,
      :status_cure => :StatusCureAbility, :stat_loss_immunity => :StatLossImmunityAbility,
      :stat_loss_immunity_non_ignorable => :StatLossImmunityAbilityNonIgnorable,
      :stat_loss_immunity_ally => :StatLossImmunityAllyAbility, :stat_gain => :AbilityOnStatGain,
      :stat_loss => :AbilityOnStatLoss, :priority_change => :PriorityChangeAbility,
      :priority_bracket_change => :PriorityBracketChangeAbility, :priority_bracket_use => :PriorityBracketUseAbility,
      :flinch => :AbilityOnFlinch, :move_blocking => :MoveBlockingAbility,
      :move_immunity_target => :MoveImmunityTargetAbility, :move_base_type_modifier => :MoveBaseTypeModifierAbility,
      :accuracy_calc_user => :AccuracyCalcUserAbility, :accuracy_calc_user_ally => :AccuracyCalcUserAllyAbility,
      :accuracy_calc_target => :AccuracyCalcTargetAbility, :damage_calc_user => :DamageCalcUserAbility,
      :damage_calc_user_ally => :DamageCalcUserAllyAbility, :damage_calc_target => :DamageCalcTargetAbility,
      :damage_calc_target_non_ignorable => :DamageCalcTargetAbilityNonIgnorable,
      :damage_calc_target_ally => :DamageCalcTargetAllyAbility, :critical_calc_user => :CriticalCalcUserAbility,
      :critical_calc_target => :CriticalCalcTargetAbility, :target_on_hit => :TargetAbilityOnHit,
      :user_on_hit => :UserAbilityOnHit, :user_end_of_move => :UserAbilityEndOfMove,
      :target_after_move_use => :TargetAbilityAfterMoveUse, :eor_weather => :EORWeatherAbility,
      :eor_healing => :EORHealingAbility, :eor_effect => :EOREffectAbility, :eor_gain_item => :EORGainItemAbility,
      :certain_switching_user => :CertainSwitchingUserAbility, :trapping_target => :TrappingTargetAbility,
      :switch_in => :AbilityOnSwitchIn, :switch_out => :AbilityOnSwitchOut,
      :ability_change_on_battler_fainting => :AbilityChangeOnBattlerFainting,
      :battler_fainting => :AbilityOnBattlerFainting, :run_from_battle => :RunFromBattleAbility
    }.freeze

    class << self
      # A new ability, as a data patch. Returns its symbol.
      def register(id, name: nil, description: nil, id_number: nil, mod: "Scripts")
        sym = Reloaded::DataPatches.symbol(id)
        data = { "name" => name || sym.to_s, "description" => description || "???" }
        data["id_number"] = id_number if id_number
        owner = "scripts_#{mod.to_s.downcase.gsub(/[^a-z0-9]+/, "_")}"
        Reloaded::DataPatches.register_internal_patch("abilities", sym.to_s, data, :owner => owner, :name => mod, :hidden => false)
        return sym
      end

      # The ability's behaviour on one of the game's battle handlers.
      def on(handler, ability, &block)
        return false unless block
        h = handler_for(handler)
        unless h
          Reloaded::Log.error("Reloaded::Abilities: no battle handler is called #{handler}", :data_patches)
          return false
        end
        h.add(Reloaded::DataPatches.symbol(ability), block)
        return true
      end

      HANDLERS.each_key do |name|
        define_method(:"on_#{name}") { |ability, &block| on(name, ability, &block) }
      end

      # Another ability's behaviour, on every handler it has.
      def copy_behavior(source, *targets)
        from = Reloaded::DataPatches.symbol(source)
        to = targets.flatten.map { |t| Reloaded::DataPatches.symbol(t) }
        HANDLERS.each_value do |const|
          next unless defined?(::BattleHandlers) && ::BattleHandlers.const_defined?(const)
          h = ::BattleHandlers.const_get(const)
          h.copy(from, *to) if h.respond_to?(:copy)
        end
        return true
      end

      private

      def handler_for(name)
        return nil unless defined?(::BattleHandlers)
        key = name.to_s.strip
        const = HANDLERS[key.downcase.gsub(/[^a-z0-9]+/, "_").to_sym] || key.to_sym
        return nil unless ::BattleHandlers.const_defined?(const)
        h = ::BattleHandlers.const_get(const)
        return h.respond_to?(:add) ? h : nil
      end
    end
  end
end
