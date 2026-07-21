#==============================================================================
# Kanto Reloaded Quality of Life - Infinite Money
#==============================================================================

module KantoReloaded
  module QualityAssurance
    module InfiniteMoney
      SETTING_KEY = :infinite_money
      RESET_ACTION_KEY = :reset_money

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

        def maximum_money
          return ::Settings::MAX_MONEY if defined?(::Settings::MAX_MONEY)
          999_999
        end

        def starting_money
          return ::Settings::INITIAL_MONEY if defined?(::Settings::INITIAL_MONEY)
          3_000
        end

        def top_up
          return false unless enabled?
          trainer = defined?($Trainer) ? $Trainer : nil
          return false unless trainer && trainer.respond_to?(:money=)
          trainer.money = maximum_money
          true
        rescue StandardError => e
          KantoReloaded::Log.error_once(
            "Infinite Money top-up failed: #{e.class}: #{e.message}",
            :modules,
            :key => :infinite_money_top_up
          ) if defined?(KantoReloaded::Log)
          false
        end

        def reset_money
          trainer = defined?($Trainer) ? $Trainer : nil
          return false unless trainer && trainer.respond_to?(:money=)
          KantoReloaded::Settings.set(SETTING_KEY, 0)
          return false if enabled?
          trainer.money = starting_money
          true
        rescue StandardError => e
          KantoReloaded::Log.error_once(
            "Reset Money failed: #{e.class}: #{e.message}",
            :modules,
            :key => :infinite_money_reset
          ) if defined?(KantoReloaded::Log)
          false
        end

        def prompt_reset
          amount = starting_money
          return false unless KantoReloaded.confirm(
            _INTL("Reset money to {1}? This will also disable Infinite Money.", amount),
            :default => false
          )
          if reset_money
            KantoReloaded.toast_success(_INTL("Money reset to {1}.", amount))
            true
          else
            KantoReloaded.toast_error(_INTL("Money could not be reset."))
            false
          end
        end

        def install
          register_setting
          register_reset_action
          register_setting_callback
          register_overworld_menu
          hook_ready = register_hook
          if defined?(KantoReloaded::Log)
            state = hook_ready ? "ready" : "unavailable"
            KantoReloaded::Log.info("Installed Infinite Money module (hook #{state})", :modules)
          end
          hook_ready
        end

        private

        def register_setting
          KantoReloaded::Settings.register(SETTING_KEY, {
            :name => "Infinite Money",
            :description => "Keeps the player's money at the maximum while enabled.",
            :type => :toggle,
            :category => :quality_of_life,
            :owner => :quality_assurance,
            :value_style => :integer,
            :default => 0,
            :priority => 50
          })
        end

        def register_reset_action
          KantoReloaded::Settings.register(RESET_ACTION_KEY, {
            :name => "Reset Money",
            :description => "Disables Infinite Money and restores the game's starting balance.",
            :type => :button,
            :category => :quality_of_life,
            :owner => :quality_assurance,
            :priority => 51,
            :metadata => { "after" => SETTING_KEY.to_s },
            :enabled_if => proc {
              trainer = defined?($Trainer) ? $Trainer : nil
              trainer && trainer.respond_to?(:money=)
            },
            :on_press => proc {
              KantoReloaded::QualityAssurance::InfiniteMoney.prompt_reset
            }
          })
        end

        def register_setting_callback
          return false unless KantoReloaded::Settings.respond_to?(:register_on_change)
          KantoReloaded::Settings.register_on_change(
            SETTING_KEY,
            :infinite_money_top_up,
            :owner => :quality_assurance
          ) do |_value|
            KantoReloaded::QualityAssurance::InfiniteMoney.top_up
          end
        end

        def register_overworld_menu
          return false unless defined?(OverworldMenu) && OverworldMenu.respond_to?(:register)
          OverworldMenu.register(:infinite_money,
            :label => "Infinite Money",
            :priority => 15,
            :default_enabled => false,
            :status => proc {
              KantoReloaded::QualityAssurance::InfiniteMoney.enabled? ? "On" : "Off"
            },
            :handler => proc { |screen|
              enabled = KantoReloaded::QualityAssurance::InfiniteMoney.toggle
              state = enabled ? "enabled" : "disabled"
              screen.show_popup("INFINITE MONEY", ["Infinite Money is now #{state}."])
              nil
            }
          )
        end

        def register_hook
          return false unless defined?(KantoReloaded::Hooks) && defined?(::Player)
          KantoReloaded::Hooks.wrap(
            ::Player,
            :money=,
            :quality_of_life_infinite_money
          ) do |hook, _value, *_arguments|
            if KantoReloaded::QualityAssurance::InfiniteMoney.enabled?
              hook.call(KantoReloaded::QualityAssurance::InfiniteMoney.maximum_money)
            else
              hook.call
            end
          end
        end
      end
    end
  end
end

KantoReloaded::QualityAssurance::InfiniteMoney.install
