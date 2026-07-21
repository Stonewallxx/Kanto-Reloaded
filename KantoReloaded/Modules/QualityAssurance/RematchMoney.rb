#==============================================================================
# Kanto Reloaded Quality of Life - Rematch Money
#==============================================================================

module KantoReloaded
  module QualityAssurance
    module RematchMoney
      SETTING_KEY = :rematch_money

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

        def install
          register_setting
          register_overworld_menu
          hook_ready = register_hook
          if defined?(KantoReloaded::Log)
            state = hook_ready ? "ready" : "unavailable"
            KantoReloaded::Log.info("Installed Rematch Money module (hook #{state})", :modules)
          end
          hook_ready
        end

        private

        def register_setting
          KantoReloaded::Settings.register(SETTING_KEY, {
            :name => "Rematch Money",
            :description => "Awards normal trainer prize money after rematch victories.",
            :type => :toggle,
            :category => :quality_of_life,
            :owner => :quality_assurance,
            :value_style => :integer,
            :default => 0,
            :priority => 40
          })
        end

        def register_overworld_menu
          return false unless defined?(OverworldMenu) && OverworldMenu.respond_to?(:register)
          OverworldMenu.register(:rematch_money,
            :label => "Rematch Money",
            :priority => 14,
            :default_enabled => false,
            :status => proc {
              KantoReloaded::QualityAssurance::RematchMoney.enabled? ? "On" : "Off"
            },
            :handler => proc { |screen|
              enabled = KantoReloaded::QualityAssurance::RematchMoney.toggle
              state = enabled ? "enabled" : "disabled"
              screen.show_popup("REMATCH MONEY", ["Rematch Money is now #{state}."])
              nil
            }
          )
        end

        def register_hook
          return false unless defined?(KantoReloaded::Hooks) && defined?(::PokeBattle_Battle)
          KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battle,
            :pbGainMoney,
            :quality_of_life_rematch_money
          ) do |hook, *_arguments|
            switches = defined?($game_switches) ? $game_switches : nil
            switch_defined = defined?(::SWITCH_IS_REMATCH)
            rematch = switch_defined && switches && switches[::SWITCH_IS_REMATCH]
            if !KantoReloaded::QualityAssurance::RematchMoney.enabled? || !rematch
              hook.call
            else
              original_value = switches[::SWITCH_IS_REMATCH]
              result = nil
              begin
                switches[::SWITCH_IS_REMATCH] = false
                result = hook.call
              ensure
                switches[::SWITCH_IS_REMATCH] = original_value
              end
              result
            end
          end
        end
      end
    end
  end
end

KantoReloaded::QualityAssurance::RematchMoney.install
