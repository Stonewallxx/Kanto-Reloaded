#==============================================================================
# Kanto Reloaded Quality of Life - Level Locking
#==============================================================================

module KantoReloaded
  module LevelLocking
    DATA_IVAR = :@kanto_reloaded_data
    DATA_KEY = "level_lock"
    NOTICE_IVAR = :@kanto_reloaded_level_lock_notices

    @gain_context = nil

    class << self
      def lock_for(pokemon)
        data = pokemon_data(pokemon, false)
        return nil unless data
        normalize_lock(data[DATA_KEY])
      rescue
        nil
      end

      def set_lock(pokemon, level)
        return false unless pokemon
        lock = normalize_lock(level)
        return false unless lock
        return false if lock < current_level(pokemon)
        data = pokemon_data(pokemon, true)
        return false unless data
        data[DATA_KEY] = lock
        apply!(pokemon)
        emit(:level_lock_set, :pokemon => pokemon, :level => lock)
        true
      rescue StandardError => e
        log_exception("Could not set a Pokemon level lock", e)
        false
      end

      def clear_lock(pokemon)
        data = pokemon_data(pokemon, false)
        return false unless data && data.has_key?(DATA_KEY)
        old_lock = normalize_lock(data.delete(DATA_KEY))
        pokemon.instance_variable_set(DATA_IVAR, nil) if data.empty?
        emit(:level_lock_cleared, :pokemon => pokemon, :level => old_lock)
        true
      rescue StandardError => e
        log_exception("Could not clear a Pokemon level lock", e)
        false
      end

      def locked?(pokemon)
        lock = lock_for(pokemon)
        !!(lock && current_level(pokemon) >= lock)
      rescue
        false
      end

      def maximum_exp(pokemon)
        lock = lock_for(pokemon)
        return nil unless lock && pokemon
        growth_rate = pokemon.growth_rate
        return growth_rate.maximum_exp if lock >= maximum_level
        growth_rate.minimum_exp_for_level(lock + 1) - 1
      rescue
        nil
      end

      def clamp_exp(pokemon, value)
        ceiling = maximum_exp(pokemon)
        return value if ceiling.nil? || value.nil?
        value > ceiling ? ceiling : value
      rescue
        value
      end

      def clamp_level(pokemon, value)
        lock = lock_for(pokemon)
        return value unless lock && value
        value.to_i > lock ? lock : value
      rescue
        value
      end

      def apply!(pokemon)
        ceiling = maximum_exp(pokemon)
        return false unless ceiling && pokemon.respond_to?(:exp) && pokemon.respond_to?(:exp=)
        return true if pokemon.exp <= ceiling
        pokemon.exp = ceiling
        pokemon.calc_stats if pokemon.respond_to?(:calc_stats)
        true
      rescue StandardError => e
        log_exception("Could not apply a Pokemon level lock", e)
        false
      end

      def current_level(pokemon)
        return 0 unless pokemon
        return pokemon.level_simple.to_i if pokemon.respond_to?(:level_simple)
        pokemon.level.to_i
      rescue
        0
      end

      def maximum_level
        return GameData::GrowthRate.max_level if defined?(GameData::GrowthRate)
        return Settings::MAXIMUM_LEVEL if defined?(Settings::MAXIMUM_LEVEL)
        100
      rescue
        100
      end

      def with_gain_context(pokemon)
        previous = @gain_context
        @gain_context = pokemon
        yield
      ensure
        @gain_context = previous
      end

      def clamp_gain_result(value)
        pokemon = @gain_context
        return value unless pokemon
        clamp_exp(pokemon, value)
      rescue
        value
      end

      def notify_battle_lock(battle, pokemon, show_messages)
        return false unless show_messages && battle && pokemon
        lock = lock_for(pokemon)
        ceiling = maximum_exp(pokemon)
        return false unless lock && ceiling && pokemon.exp >= ceiling
        notices = battle.instance_variable_get(NOTICE_IVAR)
        unless notices.is_a?(Hash)
          notices = {}
          battle.instance_variable_set(NOTICE_IVAR, notices)
        end
        key = pokemon.object_id
        return false if notices[key]
        notices[key] = true
        battle.pbDisplayPaused(
          _INTL("{1} is level locked at Lv. {2}.", pokemon.name, lock)
        )
        true
      rescue StandardError => e
        log_exception("Could not display a level lock notice", e)
        false
      end

      def install
        hooks_ready = register_hooks
        if defined?(KantoReloaded::Log)
          state = hooks_ready ? "ready" : "unavailable"
          KantoReloaded::Log.info("Installed Level Locking module (hooks #{state})", :modules)
        end
        hooks_ready
      end

      private

      def pokemon_data(pokemon, create)
        return nil unless pokemon
        data = pokemon.instance_variable_get(DATA_IVAR)
        if data.nil? && create
          data = {}
          pokemon.instance_variable_set(DATA_IVAR, data)
        end
        data.is_a?(Hash) ? data : nil
      end

      def normalize_lock(value)
        return nil if value.nil?
        level = value.to_i
        return nil if level < 1 || level > maximum_level
        level
      rescue
        nil
      end

      def register_hooks
        return false unless defined?(KantoReloaded::Hooks)
        return false unless defined?(Pokemon)
        return false unless defined?(PokeBattle_Battle)
        return false unless defined?(GameData::GrowthRate)

        level_hook = KantoReloaded::Hooks.wrap(
          Pokemon,
          :level=,
          :quality_of_life_level_locking_level
        ) do |hook, value, *_arguments|
          adjusted = KantoReloaded::LevelLocking.clamp_level(self, value)
          arguments = hook.arguments
          arguments[0] = adjusted
          hook.call_with(arguments)
        end

        exp_hook = KantoReloaded::Hooks.wrap(
          Pokemon,
          :exp=,
          :quality_of_life_level_locking_exp
        ) do |hook, value, *_arguments|
          adjusted = KantoReloaded::LevelLocking.clamp_exp(self, value)
          arguments = hook.arguments
          arguments[0] = adjusted
          hook.call_with(arguments)
        end

        change_level_hook = KantoReloaded::Hooks.wrap(
          Object,
          :pbChangeLevel,
          :quality_of_life_level_locking_change_level
        ) do |hook, pokemon, new_level, *_arguments|
          adjusted = KantoReloaded::LevelLocking.clamp_level(pokemon, new_level)
          arguments = hook.arguments
          arguments[1] = adjusted
          hook.call_with(arguments)
        end

        growth_hook = KantoReloaded::Hooks.wrap(
          GameData::GrowthRate,
          :add_exp,
          :quality_of_life_level_locking_exp_calculation
        ) do |hook, *_arguments|
          result = hook.call
          KantoReloaded::LevelLocking.clamp_gain_result(result)
        end

        battle_hook = KantoReloaded::Hooks.wrap(
          PokeBattle_Battle,
          :pbGainExpOne,
          :quality_of_life_level_locking_battle
        ) do |hook, idx_party, _defeated_battler, _num_partic, _exp_share, _exp_all,
             show_messages = true, *_arguments|
          pokemon = begin
            pbParty(0)[idx_party]
          rescue
            nil
          end
          KantoReloaded::LevelLocking.apply!(pokemon) if pokemon
          result = KantoReloaded::LevelLocking.with_gain_context(pokemon) { hook.call }
          KantoReloaded::LevelLocking.notify_battle_lock(
            self, pokemon, show_messages
          )
          result
        end

        level_hook && exp_hook && change_level_hook && growth_hook && battle_hook
      end

      def emit(event, payload)
        return unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.emit(event, payload)
      rescue
        nil
      end

      def log_exception(message, exception)
        return unless defined?(KantoReloaded::Log)
        KantoReloaded::Log.exception(message, exception, channel: :modules)
      rescue
        nil
      end
    end
  end

  module QualityAssurance
    LevelLocking = KantoReloaded::LevelLocking unless const_defined?(:LevelLocking, false)
  end
end

KantoReloaded::LevelLocking.install
