#==============================================================================
# Kanto Reloaded Quality of Life - Upgraded PP
#==============================================================================

module KantoReloaded
  module QualityAssurance
    module UpgradedPP
      SETTING_KEY = :upgraded_pp
      MAX_PP_UPS = 3

      class << self
        def enabled?
          value = KantoReloaded::Settings.get(SETTING_KEY, 0)
          value == true || (value.respond_to?(:to_i) && value.to_i == 1)
        rescue
          false
        end

        def toggle
          value = enabled? ? 0 : 1
          result = KantoReloaded::Settings.set(SETTING_KEY, value)
          result == true || (result.respond_to?(:to_i) && result.to_i == 1)
        rescue
          false
        end

        def upgrade_move(move)
          return false unless enabled? && move
          return false unless move.respond_to?(:ppup) && move.respond_to?(:ppup=)
          return false unless move.respond_to?(:pp) && move.respond_to?(:pp=)
          return false unless move.respond_to?(:total_pp) && move.total_pp.to_i > 1
          return false if move.ppup.to_i >= MAX_PP_UPS
          move.ppup = MAX_PP_UPS
          move.pp = move.total_pp
          true
        rescue StandardError => e
          log_failure("move upgrade", e, :upgraded_pp_move)
          false
        end

        def upgrade_pokemon(pokemon)
          return 0 unless enabled? && pokemon
          return 0 if pokemon.respond_to?(:egg?) && pokemon.egg?
          return 0 unless pokemon.respond_to?(:moves)
          Array(pokemon.moves).count { |move| upgrade_move(move) }
        rescue StandardError => e
          log_failure("Pokemon upgrade", e, :upgraded_pp_pokemon)
          0
        end

        def apply_party
          return 0 unless enabled?
          trainer = defined?($Trainer) ? $Trainer : nil
          return 0 unless trainer && trainer.respond_to?(:party)
          upgraded = Array(trainer.party).inject(0) do |count, pokemon|
            count + upgrade_pokemon(pokemon)
          end
          if upgraded > 0 && defined?(KantoReloaded::Log)
            KantoReloaded::Log.debug("Upgraded PP applied to #{upgraded} move(s)", :modules)
          end
          upgraded
        rescue StandardError => e
          log_failure("party apply", e, :upgraded_pp_party)
          0
        end

        def install
          register_setting
          register_setting_callback
          register_overworld_menu
          hook_ready = register_learn_move_hook
          event_ready = register_battle_start_event
          if defined?(KantoReloaded::Log)
            state = hook_ready && event_ready ? "ready" : "partial"
            KantoReloaded::Log.info("Installed Upgraded PP module (integration #{state})", :modules)
          end
          hook_ready && event_ready
        end

        private

        def register_setting
          KantoReloaded::Settings.register(SETTING_KEY, {
            :name => "Upgraded PP",
            :description => "Applies the maximum PP upgrades to the player's moves.",
            :type => :toggle,
            :category => :quality_of_life,
            :owner => :quality_assurance,
            :value_style => :integer,
            :default => 0,
            :priority => 60
          })
        end

        def register_setting_callback
          return false unless KantoReloaded::Settings.respond_to?(:register_on_change)
          KantoReloaded::Settings.register_on_change(
            SETTING_KEY,
            :upgraded_pp_apply_party,
            :owner => :quality_assurance
          ) do |_value|
            KantoReloaded::QualityAssurance::UpgradedPP.apply_party
          end
        end

        def register_overworld_menu
          return false unless defined?(OverworldMenu) && OverworldMenu.respond_to?(:register)
          OverworldMenu.register(:upgraded_pp,
            :label => "Upgraded PP",
            :priority => 16,
            :default_enabled => false,
            :status => proc {
              KantoReloaded::QualityAssurance::UpgradedPP.enabled? ? "On" : "Off"
            },
            :handler => proc { |screen|
              enabled = KantoReloaded::QualityAssurance::UpgradedPP.toggle
              state = enabled ? "enabled" : "disabled"
              screen.show_popup("UPGRADED PP", ["Upgraded PP is now #{state}."])
              nil
            }
          )
        end

        def register_learn_move_hook
          return false unless defined?(KantoReloaded::Hooks) && defined?(::Pokemon)
          KantoReloaded::Hooks.wrap(
            ::Pokemon,
            :learn_move,
            :quality_of_life_upgraded_pp_learn_move
          ) do |hook, move_id, *_arguments|
            result = hook.call
            module_api = KantoReloaded::QualityAssurance::UpgradedPP
            if module_api.enabled? && module_api.send(:player_party_member?, self)
              move_data = GameData::Move.try_get(move_id) rescue nil
              learned_id = move_data ? move_data.id : move_id
              learned_move = Array(moves).reverse.find { |move| move && move.id == learned_id }
              module_api.upgrade_move(learned_move)
            end
            result
          end
        end

        def register_battle_start_event
          return false unless defined?(::Events) && ::Events.respond_to?(:onStartBattle)
          return true if @battle_start_event_registered
          @battle_start_handler = proc do |_sender, _event|
            KantoReloaded::QualityAssurance::UpgradedPP.apply_party
          end
          ::Events.onStartBattle += @battle_start_handler
          @battle_start_event_registered = true
          true
        end

        def player_party_member?(pokemon)
          trainer = defined?($Trainer) ? $Trainer : nil
          trainer && trainer.respond_to?(:party) && Array(trainer.party).include?(pokemon)
        rescue
          false
        end

        def log_failure(action, error, key)
          KantoReloaded::Log.error_once(
            "Upgraded PP #{action} failed: #{error.class}: #{error.message}",
            :modules,
            :key => key
          ) if defined?(KantoReloaded::Log)
        end
      end
    end
  end
end

KantoReloaded::QualityAssurance::UpgradedPP.install
