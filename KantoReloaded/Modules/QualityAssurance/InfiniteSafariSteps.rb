#==============================================================================
# Kanto Reloaded Quality of Life - Infinite Safari Steps
#==============================================================================

module KantoReloaded
  module QualityAssurance
    module InfiniteSafariSteps
      SETTING_KEY = :infinite_safari_steps

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

        def preserve_steps?(state, requested_steps)
          return false unless enabled?
          return false unless state && state.respond_to?(:inProgress?) && state.inProgress?
          return false unless state.respond_to?(:decision) && state.decision.to_i == 0
          return false unless state.respond_to?(:steps)
          return false unless requested_steps.respond_to?(:to_i)
          requested_steps.to_i < state.steps.to_i
        rescue
          false
        end

        def install
          register_setting
          register_overworld_menu
          hook_ready = register_hook
          if defined?(KantoReloaded::Log)
            state = hook_ready ? "ready" : "unavailable"
            KantoReloaded::Log.info("Installed Infinite Safari Steps module (hook #{state})", :modules)
          end
          hook_ready
        end

        private

        def register_setting
          KantoReloaded::Settings.register(SETTING_KEY, {
            :name => "Infinite Safari Steps",
            :description => "Prevents walking from reducing Safari Zone steps.",
            :type => :toggle,
            :category => :quality_of_life,
            :owner => :quality_assurance,
            :value_style => :integer,
            :default => 0,
            :priority => 27
          })
        end

        def register_overworld_menu
          return false unless defined?(OverworldMenu) && OverworldMenu.respond_to?(:register)
          OverworldMenu.register(:infinite_safari_steps,
            :label => "Infinite Safari Steps",
            :priority => 20,
            :default_enabled => false,
            :status => proc {
              KantoReloaded::QualityAssurance::InfiniteSafariSteps.enabled? ? "On" : "Off"
            },
            :handler => proc { |screen|
              enabled = KantoReloaded::QualityAssurance::InfiniteSafariSteps.toggle
              state = enabled ? "enabled" : "disabled"
              screen.show_popup("INFINITE SAFARI STEPS", ["Infinite Safari Steps is now #{state}."])
              nil
            }
          )
        end

        def register_hook
          return false unless defined?(KantoReloaded::Hooks) && defined?(::SafariState)
          KantoReloaded::Hooks.wrap(
            ::SafariState,
            :steps=,
            :quality_of_life_infinite_safari_steps
          ) do |hook, requested_steps, *_arguments|
            if KantoReloaded::QualityAssurance::InfiniteSafariSteps.preserve_steps?(self, requested_steps)
              steps
            else
              hook.call
            end
          end
        end
      end
    end
  end
end

KantoReloaded::QualityAssurance::InfiniteSafariSteps.install
