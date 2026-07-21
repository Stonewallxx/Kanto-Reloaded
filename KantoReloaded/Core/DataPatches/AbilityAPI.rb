#======================================================
# KantoReloaded Ability API
# Author: Stonewall
#======================================================
# Script-facing helper API for modded ability data and behavior.
#
# Responsibilities:
#   - Let mods register ability data from Ruby scripts.
#   - Let mods register battle handler behavior with clearer names.
#   - Reapply script-registered ability data after GameData reloads.
#   - Keep the base BattleHandlers architecture intact.
#
#======================================================

module KantoReloaded
  module Abilities
    HANDLER_ALIASES = {
      :speed_calc => :SpeedCalcAbility,
      :weight_calc => :WeightCalcAbility,
      :hp_dropped_below_half => :AbilityOnHPDroppedBelowHalf,
      :status_check_non_ignorable => :StatusCheckAbilityNonIgnorable,
      :status_immunity => :StatusImmunityAbility,
      :status_immunity_non_ignorable => :StatusImmunityAbilityNonIgnorable,
      :status_immunity_ally => :StatusImmunityAllyAbility,
      :status_inflicted => :AbilityOnStatusInflicted,
      :status_cure => :StatusCureAbility,
      :stat_loss_immunity => :StatLossImmunityAbility,
      :stat_loss_immunity_non_ignorable => :StatLossImmunityAbilityNonIgnorable,
      :stat_loss_immunity_ally => :StatLossImmunityAllyAbility,
      :stat_gain => :AbilityOnStatGain,
      :stat_loss => :AbilityOnStatLoss,
      :priority_change => :PriorityChangeAbility,
      :priority_bracket_change => :PriorityBracketChangeAbility,
      :priority_bracket_use => :PriorityBracketUseAbility,
      :flinch => :AbilityOnFlinch,
      :move_blocking => :MoveBlockingAbility,
      :move_immunity_target => :MoveImmunityTargetAbility,
      :move_base_type_modifier => :MoveBaseTypeModifierAbility,
      :accuracy_calc_user => :AccuracyCalcUserAbility,
      :accuracy_calc_user_ally => :AccuracyCalcUserAllyAbility,
      :accuracy_calc_target => :AccuracyCalcTargetAbility,
      :damage_calc_user => :DamageCalcUserAbility,
      :damage_calc_user_ally => :DamageCalcUserAllyAbility,
      :damage_calc_target => :DamageCalcTargetAbility,
      :damage_calc_target_non_ignorable => :DamageCalcTargetAbilityNonIgnorable,
      :damage_calc_target_ally => :DamageCalcTargetAllyAbility,
      :critical_calc_user => :CriticalCalcUserAbility,
      :critical_calc_target => :CriticalCalcTargetAbility,
      :target_on_hit => :TargetAbilityOnHit,
      :user_on_hit => :UserAbilityOnHit,
      :user_end_of_move => :UserAbilityEndOfMove,
      :target_after_move_use => :TargetAbilityAfterMoveUse,
      :eor_weather => :EORWeatherAbility,
      :eor_healing => :EORHealingAbility,
      :eor_effect => :EOREffectAbility,
      :eor_gain_item => :EORGainItemAbility,
      :certain_switching_user => :CertainSwitchingUserAbility,
      :trapping_target => :TrappingTargetAbility,
      :switch_in => :AbilityOnSwitchIn,
      :switch_out => :AbilityOnSwitchOut,
      :ability_change_on_battler_fainting => :AbilityChangeOnBattlerFainting,
      :battler_fainting => :AbilityOnBattlerFainting,
      :run_from_battle => :RunFromBattleAbility
    }.freeze

    @definitions = {}
    @managed_symbols = []
    @managed_numbers = []
    @handlers = []

    class << self
      def install
        register_events
        KantoReloaded::Log.info("Installed KantoReloaded ability API", :mods) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Ability API install failed", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def register(id, name: nil, description: nil, id_number: nil)
        ability_id = normalize_symbol(id)
        @definitions[ability_id] = {
          :id => ability_id,
          :id_number => id_number,
          :name => blank?(name) ? ability_id.to_s : name.to_s,
          :description => blank?(description) ? "???" : description.to_s
        }
        apply_definition(ability_id)
        ability_id
      rescue StandardError => e
        KantoReloaded::Log.exception("Ability registration failed for #{id}", e, channel: :mods) if defined?(KantoReloaded::Log)
        nil
      end

      def on(handler_name, ability_id, &block)
        return false unless block
        handler = resolve_handler(handler_name)
        unless handler
          log_error("Unknown ability handler: #{handler_name}")
          return false
        end
        id = normalize_symbol(ability_id)
        handler.add(id, block)
        @handlers << { :handler => handler_name.to_sym, :ability => id }
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Ability handler registration failed for #{ability_id}/#{handler_name}", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      HANDLER_ALIASES.each_key do |alias_name|
        define_method("on_#{alias_name}") do |ability_id, &block|
          on(alias_name, ability_id, &block)
        end
      end

      def copy_behavior(source_ability, *target_abilities)
        source = normalize_symbol(source_ability)
        targets = target_abilities.flatten.map { |ability| normalize_symbol(ability) }
        HANDLER_ALIASES.each do |_alias_name, handler_const|
          next unless defined?(BattleHandlers) && BattleHandlers.const_defined?(handler_const)
          handler = BattleHandlers.const_get(handler_const)
          next unless handler.respond_to?(:copy)
          handler.copy(source, *targets)
        end
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Ability behavior copy failed for #{source_ability}", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def apply_all
        restore_managed_entries
        @definitions.keys.each { |id| apply_definition(id) }
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Ability API reapply failed", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      private

      def apply_definition(id)
        return false unless defined?(GameData::Ability)
        data = @definitions[id]
        return false unless data
        id_number = data[:id_number].nil? ? next_id_number : data[:id_number].to_i
        existing_number_owner = GameData::Ability::DATA[id_number]
        if existing_number_owner && existing_number_owner.id != id && !@managed_numbers.include?(id_number)
          log_error("Ability API #{id} cannot use id_number #{id_number}; it already belongs to #{existing_number_owner.id}.")
          return false
        end
        ability = GameData::Ability.new(
          :id => id,
          :id_number => id_number,
          :name => data[:name],
          :description => data[:description]
        )
        ability.instance_variable_set(:@kanto_reloaded_data_patch, true)
        GameData::Ability::DATA[id] = ability
        GameData::Ability::DATA[id_number] = ability
        @managed_symbols << id unless @managed_symbols.include?(id)
        @managed_numbers << id_number unless @managed_numbers.include?(id_number)
        true
      end

      def restore_managed_entries
        return unless defined?(GameData::Ability)
        Array(@managed_numbers).each { |key| GameData::Ability::DATA.delete(key) }
        Array(@managed_symbols).each { |key| GameData::Ability::DATA.delete(key) }
        @managed_symbols = []
        @managed_numbers = []
      end

      def next_id_number
        keys = []
        GameData::Ability::DATA.each_key { |key| keys << key if key.is_a?(Integer) }
        value = keys.empty? ? 1 : keys.max + 1
        value += 1 while GameData::Ability::DATA.key?(value)
        value
      end

      def resolve_handler(handler_name)
        return nil unless defined?(BattleHandlers)
        key = handler_name.to_s.strip
        alias_key = key.downcase.gsub(/[^a-z0-9]+/, "_").to_sym
        const_name = HANDLER_ALIASES[alias_key] || key.to_sym
        return nil unless BattleHandlers.const_defined?(const_name)
        handler = BattleHandlers.const_get(const_name)
        handler.respond_to?(:add) ? handler : nil
      end

      def register_events
        return unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(:data_patches_loaded, :ability_api_reapply, priority: 150) do |_context|
          KantoReloaded::Abilities.apply_all if defined?(KantoReloaded::Abilities)
        end
      end

      def normalize_symbol(value)
        value.to_s.strip.upcase.gsub(/[^A-Z0-9_]+/, "_").to_sym
      end

      def blank?(value)
        value.nil? || value.to_s.strip.empty?
      end

      def log_error(message)
        if defined?(KantoReloaded::Log)
          if KantoReloaded::Log.respond_to?(:error_once)
            KantoReloaded::Log.error_once(message, :mods, key: "ability_api_error:#{message}")
          else
            KantoReloaded::Log.error(message, :mods)
          end
        end
      end
    end
  end
end

KantoReloaded::Abilities.install if defined?(KantoReloaded::Abilities)
