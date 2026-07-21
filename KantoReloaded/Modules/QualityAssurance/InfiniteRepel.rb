#==============================================================================
# Kanto Reloaded Quality of Life - Infinite Repel
#==============================================================================

module KantoReloaded
  module QualityAssurance
    module InfiniteRepel
      SETTING_KEY = :miscmods_infinite_repel

      class << self
        def enabled?
          value = KantoReloaded::Settings.get(SETTING_KEY, 0)
          value == true || value.to_i == 1
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
          return false unless defined?(KantoReloaded::Hooks)
          KantoReloaded::Hooks.wrap(Object, :isRepelActive, :quality_of_life_infinite_repel) do |hook, *_args|
            KantoReloaded::QualityAssurance::InfiniteRepel.enabled? ? true : hook.call
          end
        end

        private

        def register_setting
          KantoReloaded::Settings.register(SETTING_KEY, {
            :name => "Infinite Repel",
            :description => "Makes the repel effect permanent while enabled.",
            :type => :toggle,
            :category => :quality_of_life,
            :owner => :quality_assurance,
            :value_style => :integer,
            :default => 0,
            :priority => 10
          })
        end

        def register_overworld_menu
          return false unless defined?(OverworldMenu) && OverworldMenu.respond_to?(:register)
          OverworldMenu.register(:infinite_repel,
            :label => "Infinite Repel",
            :priority => 11,
            :default_enabled => false,
            :status => proc {
              KantoReloaded::QualityAssurance::InfiniteRepel.enabled? ? "On" : "Off"
            },
            :handler => proc { |screen|
              enabled = KantoReloaded::QualityAssurance::InfiniteRepel.toggle
              state = enabled ? "enabled" : "disabled"
              screen.show_popup("INFINITE REPEL", ["Infinite Repel is now #{state}."])
              nil
            }
          )
        end
      end
    end
  end
end

KantoReloaded::QualityAssurance::InfiniteRepel.install
