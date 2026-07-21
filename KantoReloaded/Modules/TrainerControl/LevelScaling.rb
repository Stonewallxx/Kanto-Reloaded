#==============================================================================
# Kanto Reloaded - Trainer Control Level Scaling
#==============================================================================

module KantoReloaded
  module TrainerControl
    module LevelScaling
      ENABLED_SETTING = :trainer_control_level_scaling
      REFERENCE_SETTING = :trainer_control_level_reference
      OFFSET_SETTING = :trainer_control_level_offset
      PRESERVE_SETTING = :trainer_control_preserve_level_spread
      REGULAR_SETTING = :trainer_control_scale_regular
      LEADER_SETTING = :trainer_control_scale_leaders
      REMATCH_SETTING = :trainer_control_scale_rematches

      class << self
        def enabled?
          truthy?(setting(ENABLED_SETTING, false))
        end

        def scope_enabled?(scope)
          key = case scope.to_sym
                when :leader then LEADER_SETTING
                when :rematch then REMATCH_SETTING
                else REGULAR_SETTING
                end
          truthy?(setting(key, true))
        rescue StandardError
          false
        end

        def apply(trainer, scope)
          return 0 unless enabled? && scope_enabled?(scope)
          return 0 if scripted_level_override?
          opponents = usable_party(trainer)
          players = player_party
          return 0 if opponents.empty? || players.empty?

          reference = reference_mode
          player_anchor = party_anchor(players, reference)
          trainer_anchor = party_anchor(opponents, reference)
          target = clamp_level(player_anchor + level_offset)
          return 0 if target <= trainer_anchor

          adjusted = preserve_spread? ?
            raise_by_difference(opponents, target - trainer_anchor) :
            raise_to_target(opponents, target)
          log_adjustment(trainer, adjusted, target, scope) if adjusted > 0
          adjusted
        rescue StandardError => e
          KantoReloaded::Log.exception(
            "Trainer level scaling failed", e, channel: :trainer_control
          ) if defined?(KantoReloaded::Log)
          0
        end

        def level_offset
          [[setting(OFFSET_SETTING, 0).to_i, -99].max, 99].min
        end

        def formatted_offset
          value = level_offset
          value > 0 ? "+#{value}" : value.to_s
        end

        def preserve_spread?
          truthy?(setting(PRESERVE_SETTING, true))
        end

        def scripted_level_override?
          return false unless defined?(::Settings::OVERRIDE_BATTLE_LEVEL_SWITCH)
          return false unless defined?($game_switches) && $game_switches
          !!$game_switches[::Settings::OVERRIDE_BATTLE_LEVEL_SWITCH]
        rescue StandardError
          false
        end

        private

        def reference_mode
          setting(REFERENCE_SETTING, 0).to_i == 1 ? :average : :highest
        end

        def usable_party(trainer)
          return [] unless trainer && trainer.respond_to?(:party)
          Array(trainer.party).compact.reject { |pokemon| pokemon.egg? rescue false }
        end

        def player_party
          return [] unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
          Array($Trainer.party).compact.reject { |pokemon| pokemon.egg? rescue false }
        end

        def party_anchor(party, mode)
          levels = Array(party).map { |pokemon| pokemon.level.to_i }.select { |level| level > 0 }
          return 1 if levels.empty?
          return levels.max if mode == :highest
          (levels.inject(0) { |sum, level| sum + level }.to_f / levels.length).round
        end

        def raise_by_difference(party, difference)
          changed = 0
          party.each do |pokemon|
            new_level = clamp_level(pokemon.level.to_i + difference.to_i)
            changed += apply_level(pokemon, new_level)
          end
          changed
        end

        def raise_to_target(party, target)
          changed = 0
          party.each do |pokemon|
            changed += apply_level(pokemon, [pokemon.level.to_i, target.to_i].max)
          end
          changed
        end

        def apply_level(pokemon, level)
          return 0 unless pokemon && level.to_i > pokemon.level.to_i
          pokemon.level = level.to_i
          pokemon.calc_stats if pokemon.respond_to?(:calc_stats)
          1
        end

        def clamp_level(value)
          maximum = if defined?(GameData::GrowthRate)
                      GameData::GrowthRate.max_level.to_i
                    else
                      100
                    end
          [[value.to_i, 1].max, [maximum, 1].max].min
        rescue StandardError
          [[value.to_i, 1].max, 100].min
        end

        def setting(key, fallback)
          return fallback unless defined?(KantoReloaded::Settings)
          KantoReloaded::Settings.get(key, fallback)
        end

        def truthy?(value)
          value == true || (value.is_a?(Numeric) && value.to_i != 0) ||
            ["true", "on", "yes", "enabled", "1"].include?(value.to_s.downcase)
        end

        def log_adjustment(trainer, count, target, scope)
          name = trainer.respond_to?(:name) ? trainer.name.to_s : "Trainer"
          KantoReloaded::Log.debug(
            "Scaled #{count} Pokemon for #{name} toward level #{target} (#{scope})",
            :trainer_control
          ) if defined?(KantoReloaded::Log)
        end
      end
    end
  end
end
