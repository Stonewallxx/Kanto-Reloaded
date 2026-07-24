#==============================================================================
# Kanto Reloaded - Dynamic Randomizer Migration
#==============================================================================

module KantoReloaded
  module Randomizer
    module Migration
      LEGACY_DYNAMIC_WILD_SWITCH = 1700

      class << self
        def install
          return true if @installed
          KantoReloaded::Events.on(
            :kanto_reloaded_save_loaded,
            :randomizer_legacy_dynamic_import,
            priority: 185
          ) { |_context| migrate! }
          KantoReloaded::Events.on(
            :kanto_reloaded_save_new_game,
            :randomizer_new_game_dynamic_import,
            priority: 185
          ) { |_context| migrate! }
          @installed = true
        end

        def migrate!
          return false unless $game_switches
          return false if KantoReloaded::SaveData.get(
            MODULE_ID, MIGRATION_KEY, false, section: :systems
          )

          imported = []
          if !KantoReloaded::Settings.stored?(DYNAMIC_WILD_SETTING) &&
             $game_switches[LEGACY_DYNAMIC_WILD_SWITCH]
            KantoReloaded::Settings.set(DYNAMIC_WILD_SETTING, true)
            imported << "wild Pokemon"
          end
          item_switch = legacy_item_switch
          if !KantoReloaded::Settings.stored?(DYNAMIC_ITEMS_SETTING) &&
             item_switch && $game_switches[item_switch]
            KantoReloaded::Settings.set(DYNAMIC_ITEMS_SETTING, true)
            imported << "items"
          end
          KantoReloaded::SaveData.set(
            MODULE_ID, MIGRATION_KEY, true, section: :systems
          )
          unless imported.empty?
            KantoReloaded::Log.info(
              "Imported legacy dynamic randomizer settings: #{imported.join(', ')}",
              :randomizer
            ) if defined?(KantoReloaded::Log)
          end
          true
        rescue StandardError => e
          KantoReloaded::Log.exception(
            "Dynamic randomizer migration failed", e, channel: :randomizer
          ) if defined?(KantoReloaded::Log)
          false
        end

        private

        def legacy_item_switch
          return SWITCH_RANDOM_ITEMS_DYNAMIC if defined?(SWITCH_RANDOM_ITEMS_DYNAMIC)
          958
        end
      end
    end
  end
end
