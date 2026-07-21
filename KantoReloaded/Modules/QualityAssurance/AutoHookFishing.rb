#==============================================================================
# Kanto Reloaded Quality of Life - Auto Hook Fishing
#==============================================================================

module KantoReloaded
  module QualityAssurance
    module AutoHookFishing
      SETTING_KEY = :auto_hook_fishing

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
            KantoReloaded::Log.info("Installed Auto Hook Fishing module (hook #{state})", :modules)
          end
          hook_ready
        end

        private

        def register_setting
          KantoReloaded::Settings.register(SETTING_KEY, {
            :name => "Auto Hook Fishing",
            :description => "Automatically reels in a biting Pokemon without reaction input.",
            :type => :toggle,
            :category => :quality_of_life,
            :owner => :quality_assurance,
            :value_style => :integer,
            :default => 0,
            :priority => 25
          })
        end

        def register_overworld_menu
          return false unless defined?(OverworldMenu) && OverworldMenu.respond_to?(:register)
          OverworldMenu.register(:auto_hook_fishing,
            :label => "Auto Hook Fishing",
            :priority => 19,
            :default_enabled => false,
            :status => proc {
              KantoReloaded::QualityAssurance::AutoHookFishing.enabled? ? "On" : "Off"
            },
            :handler => proc { |screen|
              enabled = KantoReloaded::QualityAssurance::AutoHookFishing.toggle
              state = enabled ? "enabled" : "disabled"
              screen.show_popup("AUTO HOOK FISHING", ["Auto Hook Fishing is now #{state}."])
              nil
            }
          )
        end

        def register_hook
          return false unless defined?(KantoReloaded::Hooks)
          KantoReloaded::Hooks.wrap(
            Object,
            :pbWaitForInput,
            :quality_of_life_auto_hook_fishing
          ) do |hook, message_window, message, _frames, *_arguments|
            unless KantoReloaded::QualityAssurance::AutoHookFishing.enabled?
              next hook.call
            end

            pbMessageDisplay(message_window, message, false)
            $game_player.pattern = 0 if defined?($game_player) && $game_player
            true
          end
        end
      end
    end
  end
end

KantoReloaded::QualityAssurance::AutoHookFishing.install
