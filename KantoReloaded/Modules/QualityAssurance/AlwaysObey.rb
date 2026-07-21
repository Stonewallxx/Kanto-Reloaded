#==============================================================================
# Kanto Reloaded Quality of Life - Always Obey
#==============================================================================

module KantoReloaded
  module QualityAssurance
    module AlwaysObey
      SETTING_KEY = :always_obey

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
          hooks_ready = register_hooks
          if defined?(KantoReloaded::Log)
            state = hooks_ready ? "ready" : "unavailable"
            KantoReloaded::Log.info("Installed Always Obey module (hooks #{state})", :modules)
          end
          hooks_ready
        end

        private

        def register_setting
          KantoReloaded::Settings.register(SETTING_KEY, {
            :name => "Always Obey",
            :description => "Makes Pokemon always follow selected battle commands.",
            :type => :toggle,
            :category => :quality_of_life,
            :owner => :quality_assurance,
            :value_style => :integer,
            :default => 0,
            :priority => 30
          })
        end

        def register_overworld_menu
          return false unless defined?(OverworldMenu) && OverworldMenu.respond_to?(:register)
          OverworldMenu.register(:always_obey,
            :label => "Always Obey",
            :priority => 13,
            :default_enabled => false,
            :status => proc {
              KantoReloaded::QualityAssurance::AlwaysObey.enabled? ? "On" : "Off"
            },
            :handler => proc { |screen|
              enabled = KantoReloaded::QualityAssurance::AlwaysObey.toggle
              state = enabled ? "enabled" : "disabled"
              screen.show_popup("ALWAYS OBEY", ["Always Obey is now #{state}."])
              nil
            }
          )
        end

        def register_hooks
          return false unless defined?(KantoReloaded::Hooks) && defined?(::PokeBattle_Battler)
          obedience_ready = KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :pbObedienceCheck?,
            :quality_of_life_always_obey_check
          ) do |hook, *_arguments|
            KantoReloaded::QualityAssurance::AlwaysObey.enabled? ? true : hook.call
          end
          disobey_ready = KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battler,
            :pbDisobey,
            :quality_of_life_always_obey_disobey
          ) do |hook, *_arguments|
            KantoReloaded::QualityAssurance::AlwaysObey.enabled? ? true : hook.call
          end
          obedience_ready && disobey_ready
        end
      end
    end
  end
end

KantoReloaded::QualityAssurance::AlwaysObey.install
