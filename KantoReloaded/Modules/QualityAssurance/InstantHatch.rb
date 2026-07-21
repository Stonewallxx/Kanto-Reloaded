#==============================================================================
# Kanto Reloaded Quality of Life - Instant Hatch
#==============================================================================

module KantoReloaded
  module QualityAssurance
    module InstantHatch
      SETTING_KEY = :instant_hatch

      class << self
        def enabled?
          return @enabled_cache if instance_variable_defined?(:@enabled_cache)
          value = KantoReloaded::Settings.get(SETTING_KEY, 0)
          cache_enabled(value)
        rescue
          false
        end

        def cache_enabled(value)
          @enabled_cache = value == true || (value.respond_to?(:to_i) && value.to_i == 1)
        end

        def toggle
          value = enabled? ? 0 : 1
          result = KantoReloaded::Settings.set(SETTING_KEY, value)
          result == true || (result.respond_to?(:to_i) && result.to_i == 1)
        rescue
          false
        end

        def prepare_party_eggs
          return 0 unless enabled?
          trainer = defined?($Trainer) ? $Trainer : nil
          return 0 unless trainer && trainer.respond_to?(:party)
          party = trainer.party
          return 0 unless party.respond_to?(:each)

          prepared = 0
          party.each do |pokemon|
            next unless pokemon
            next unless pokemon.respond_to?(:steps_to_hatch) && pokemon.respond_to?(:steps_to_hatch=)
            remaining = pokemon.steps_to_hatch.to_i
            next unless remaining > 1
            pokemon.steps_to_hatch = 1
            prepared += 1
          end
          if prepared > 0 && defined?(KantoReloaded::Log)
            KantoReloaded::Log.debug("Instant Hatch prepared #{prepared} party Egg(s)", :modules)
          end
          prepared
        rescue StandardError => e
          KantoReloaded::Log.error_once(
            "Instant Hatch step handler failed: #{e.class}: #{e.message}",
            :modules,
            :key => :instant_hatch_step_handler
          ) if defined?(KantoReloaded::Log)
          0
        end

        def install
          register_setting
          register_setting_callback
          register_overworld_menu
          step_event_ready = register_step_event
          if defined?(KantoReloaded::Log)
            state = step_event_ready ? "ready" : "unavailable"
            KantoReloaded::Log.info("Installed Instant Hatch module (step event #{state})", :modules)
          end
          step_event_ready
        end

        private

        def register_setting
          KantoReloaded::Settings.register(SETTING_KEY, {
            :name => "Instant Hatch",
            :description => "Makes party Eggs hatch on their next step while enabled.",
            :type => :toggle,
            :category => :quality_of_life,
            :owner => :quality_assurance,
            :value_style => :integer,
            :default => 0,
            :priority => 20
          })
        end

        def register_overworld_menu
          return false unless defined?(OverworldMenu) && OverworldMenu.respond_to?(:register)
          OverworldMenu.register(:instant_hatch,
            :label => "Instant Hatch",
            :priority => 12,
            :default_enabled => false,
            :status => proc {
              KantoReloaded::QualityAssurance::InstantHatch.enabled? ? "On" : "Off"
            },
            :handler => proc { |screen|
              enabled = KantoReloaded::QualityAssurance::InstantHatch.toggle
              state = enabled ? "enabled" : "disabled"
              screen.show_popup("INSTANT HATCH", ["Instant Hatch is now #{state}."])
              nil
            }
          )
        end

        def register_setting_callback
          return false unless KantoReloaded::Settings.respond_to?(:register_on_change)
          KantoReloaded::Settings.register_on_change(
            SETTING_KEY,
            :instant_hatch_prepare_party,
            :owner => :quality_assurance
          ) do |value|
            state = KantoReloaded::QualityAssurance::InstantHatch.cache_enabled(value)
            if defined?(KantoReloaded::Log)
              KantoReloaded::Log.info("Instant Hatch setting changed: #{state ? 'On' : 'Off'}", :modules)
            end
            KantoReloaded::QualityAssurance::InstantHatch.prepare_party_eggs if state
          end
        end

        def register_step_event
          return false unless defined?(::Events) && ::Events.respond_to?(:onStepTaken)
          return true if @step_event_registered
          @step_event_handler = proc do |_sender, _event|
            KantoReloaded::QualityAssurance::InstantHatch.prepare_party_eggs
          end
          ::Events.onStepTaken += @step_event_handler
          @step_event_registered = true
          true
        end
      end
    end
  end
end

KantoReloaded::QualityAssurance::InstantHatch.install
