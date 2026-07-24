#==============================================================================
# Kanto Reloaded - Randomizer Settings
#==============================================================================

module KantoReloaded
  module Randomizer
    MODULE_ID = :randomizer
    SETTINGS_ACTION = :randomizer_settings
    DYNAMIC_WILD_SETTING = :"randomizer.dynamic_wild"
    WILD_MODE_SETTING = :"randomizer.wild_mode"
    DYNAMIC_ITEMS_SETTING = :"randomizer.dynamic_items"
    WILD_MODE_BST = 0
    WILD_MODE_RANDOM = 1
    RECENT_SPECIES_KEY = :recent_wild_species
    MIGRATION_KEY = :legacy_dynamic_randomizer_migration_v1
    RECENT_SPECIES_LIMIT = 10

    class PrerequisiteToggle < EnumOption
      def initialize(name, get_proc, set_proc, prerequisite_proc, blocked_proc, description = "")
        @prerequisite_proc = prerequisite_proc
        @blocked_proc = blocked_proc
        super(name, [_INTL("Off"), _INTL("On")], get_proc, set_proc, description)
      end

      def next(current)
        return blocked(current) unless prerequisite_met?
        super
      end

      def prev(current)
        return blocked(current) unless prerequisite_met?
        super
      end

      private

      def prerequisite_met?
        !!@prerequisite_proc.call
      rescue StandardError
        false
      end

      def blocked(current)
        @blocked_proc.call if @blocked_proc
        current
      end
    end

    class SettingsScene < KantoReloaded::SettingsUI::BaseScene
      def scene_title
        "Randomizer"
      end

      def scene_description
        "Configure runtime randomization that extends KIF's existing randomizer rules."
      end

      def pbGetOptions(_inloadscreen = false)
        rows = []
        rows << KantoReloaded::Options::CollapsibleHeader.new(
          _INTL("Dynamic Pokemon"),
          _INTL("Choose a new eligible species whenever a normal wild encounter is selected."),
          :collapsed => true
        )
        rows << prerequisite_toggle_row(
          DYNAMIC_WILD_SETTING,
          proc { KantoReloaded::Randomizer.base_wild_randomization_enabled? },
          proc { KantoReloaded::Randomizer.show_prerequisite_message(:wild) }
        )
        rows << setting_row(WILD_MODE_SETTING)
        rows << text_row(
          _INTL("Pokemon Pool"),
          proc { KantoReloaded::Randomizer.pokemon_pool_label },
          _INTL("Uses KIF's Custom Sprites Only option; Off means all Pokemon.")
        )
        rows << text_row(
          _INTL("BST Range"),
          proc { KantoReloaded::Randomizer.bst_range_label },
          _INTL("Uses KIF's wild Pokemon randomness degree.")
        )
        rows << text_row(
          _INTL("Legendaries"),
          proc { KantoReloaded::Randomizer.legendary_rule_label },
          _INTL("Uses KIF's Allow Legendaries option while preserving legendary encounters.")
        )
        rows << KantoReloaded::Options::ActionButton.new(
          _INTL("Reset Recent Encounters"),
          proc { reset_recent_encounters },
          _INTL("Clear the recent-species history used to reduce immediate repeats.")
        )

        rows << KantoReloaded::Options::CollapsibleHeader.new(
          _INTL("Dynamic Items"),
          _INTL("Choose a new eligible item whenever KIF randomizes a found or given item."),
          :collapsed => true
        )
        rows << prerequisite_toggle_row(
          DYNAMIC_ITEMS_SETTING,
          proc { KantoReloaded::Randomizer.base_item_randomization_enabled? },
          proc { KantoReloaded::Randomizer.show_prerequisite_message(:items) }
        )
        rows << text_row(
          _INTL("Eligible Sources"),
          proc { KantoReloaded::Randomizer.item_sources_label },
          _INTL("Source selection remains controlled by KIF's item randomizer options.")
        )
        rows << text_row(
          _INTL("Item Rules"),
          proc { KantoReloaded::Randomizer.item_rules_label },
          _INTL("Key items, HMs, protected items, and internal items are never selected.")
        )

        rows << KantoReloaded::Options::ActionButton.new(
          _INTL("Reset Module"),
          proc { reset_module },
          _INTL("Restore Randomizer settings and runtime caches to their defaults.")
        )
        rows.compact
      end

      private

      def setting_row(key)
        definition = KantoReloaded::Settings.definition(key)
        return nil unless definition
        KantoReloaded::SettingsUI::RowFactory.build(
          definition, :scene => self, :randomizer => true
        )
      end

      def prerequisite_toggle_row(key, prerequisite_proc, blocked_proc)
        definition = KantoReloaded::Settings.definition(key)
        return nil unless definition
        PrerequisiteToggle.new(
          _INTL(definition[:name]),
          proc {
            KantoReloaded::SettingsUI::RowFactory.truthy?(
              KantoReloaded::Settings.get(key, definition[:default])
            ) ? 1 : 0
          },
          proc { |value| KantoReloaded::Settings.set(key, value.to_i == 1) },
          prerequisite_proc,
          blocked_proc,
          _INTL(definition[:description])
        )
      end

      def text_row(name, value_proc, description)
        KantoReloaded::Options::TextDisplayOption.new(name, value_proc, description)
      end

      def reset_recent_encounters
        KantoReloaded::Randomizer.clear_recent_species
        KantoReloaded::Toast.success(_INTL("Recent encounter history reset."))
      end

      def reset_module
        return unless KantoReloaded::PopupWindow.confirm(
          _INTL("Reset all Randomizer settings and recent encounter history?"),
          :default => false
        )
        KantoReloaded::Settings.reset_module(MODULE_ID)
        KantoReloaded::Randomizer.clear_recent_species
        KantoReloaded::Randomizer::Pools.clear!
        sync_window_values
        KantoReloaded::Toast.success(_INTL("Randomizer settings reset."))
      end
    end
  end
end
