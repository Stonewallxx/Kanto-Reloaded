#==============================================================================
# Kanto Reloaded Quality of Life - Infinite PP
#==============================================================================

module KantoReloaded
  module QualityAssurance
    module InfinitePP
      SETTING_KEY = :infinite_pp

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

        def restore_party
          return 0 unless enabled?
          trainer = defined?($Trainer) ? $Trainer : nil
          return 0 unless trainer && trainer.respond_to?(:party)
          restored = 0
          Array(trainer.party).each do |pokemon|
            next unless pokemon
            next if pokemon.respond_to?(:egg?) && pokemon.egg?
            next unless pokemon.respond_to?(:heal_PP)
            pokemon.heal_PP
            restored += 1
          end
          restored
        rescue StandardError => e
          log_failure("party restore", e, :infinite_pp_party)
          0
        end

        def install
          register_setting
          register_setting_callback
          register_overworld_menu
          hook_ready = register_pp_hook
          events_ready = register_battle_events
          if defined?(KantoReloaded::Log)
            state = hook_ready && events_ready ? "ready" : "partial"
            KantoReloaded::Log.info("Installed Infinite PP module (integration #{state})", :modules)
          end
          hook_ready && events_ready
        end

        private

        def register_setting
          KantoReloaded::Settings.register(SETTING_KEY, {
            :name => "Infinite PP",
            :description => "Restores party PP around battles and refills moves that reach zero PP.",
            :type => :toggle,
            :category => :quality_of_life,
            :owner => :quality_assurance,
            :value_style => :integer,
            :default => 0,
            :priority => 70
          })
        end

        def register_setting_callback
          return false unless KantoReloaded::Settings.respond_to?(:register_on_change)
          KantoReloaded::Settings.register_on_change(
            SETTING_KEY,
            :infinite_pp_restore_party,
            :owner => :quality_assurance
          ) do |_value|
            KantoReloaded::QualityAssurance::InfinitePP.restore_party
          end
        end

        def register_overworld_menu
          return false unless defined?(OverworldMenu) && OverworldMenu.respond_to?(:register)
          OverworldMenu.register(:infinite_pp,
            :label => "Infinite PP",
            :priority => 17,
            :default_enabled => false,
            :status => proc {
              KantoReloaded::QualityAssurance::InfinitePP.enabled? ? "On" : "Off"
            },
            :handler => proc { |screen|
              enabled = KantoReloaded::QualityAssurance::InfinitePP.toggle
              state = enabled ? "enabled" : "disabled"
              screen.show_popup("INFINITE PP", ["Infinite PP is now #{state}."])
              nil
            }
          )
        end

        def register_pp_hook
          return false unless defined?(KantoReloaded::Hooks) && defined?(::PokeBattle_Battler)
          KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :pbSetPP,
            :quality_of_life_infinite_pp
          ) do |hook, move, _value, *_arguments|
            result = hook.call
            module_api = KantoReloaded::QualityAssurance::InfinitePP
            if module_api.enabled? && module_api.send(:player_battler?, self) &&
               move && move.respond_to?(:pp) && move.respond_to?(:total_pp) &&
               move.total_pp.to_i > 0 && move.pp.to_i <= 0
              hook.call(move, move.total_pp)
            end
            result
          end
        end

        def register_battle_events
          return false unless defined?(::Events)
          return false unless ::Events.respond_to?(:onStartBattle) && ::Events.respond_to?(:onEndBattle)
          return true if @battle_events_registered
          @battle_start_handler = proc do |_sender, _event|
            KantoReloaded::QualityAssurance::InfinitePP.restore_party
          end
          @battle_end_handler = proc do |_sender, _event|
            KantoReloaded::QualityAssurance::InfinitePP.restore_party
          end
          ::Events.onStartBattle += @battle_start_handler
          ::Events.onEndBattle += @battle_end_handler
          @battle_events_registered = true
          true
        end

        def player_battler?(battler)
          battler.respond_to?(:pbOwnedByPlayer?) && battler.pbOwnedByPlayer?
        rescue
          false
        end

        def log_failure(action, error, key)
          KantoReloaded::Log.error_once(
            "Infinite PP #{action} failed: #{error.class}: #{error.message}",
            :modules,
            :key => key
          ) if defined?(KantoReloaded::Log)
        end
      end
    end
  end
end

KantoReloaded::QualityAssurance::InfinitePP.install
