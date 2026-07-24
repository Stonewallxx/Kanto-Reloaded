#==============================================================================
# Kanto Reloaded - Randomizer
#==============================================================================
# Runtime randomizer extensions built on KIF's existing randomizer controls.
# Original Dynamic Randomiser concept by An Unsocial Pigeon.
#==============================================================================

module KantoReloaded
  module Randomizer
    class << self
      def boot
        return true if @booted
        register_settings
        Migration.install
        hooks = [DynamicWildPokemon.install, DynamicItems.install, install_summary_hook]
        Migration.migrate! if $game_switches
        @booted = hooks.all?
        state = @booted ? "ready" : "partial"
        KantoReloaded::Log.info(
          "Randomizer integration #{state}", :randomizer
        ) if defined?(KantoReloaded::Log)
        @booted
      rescue StandardError => e
        @booted = false
        KantoReloaded::Log.exception(
          "Randomizer failed to boot", e, channel: :randomizer
        ) if defined?(KantoReloaded::Log)
        false
      end

      def dynamic_wild?
        dynamic_wild_configured? && base_wild_randomization_enabled?
      end

      def dynamic_items?
        dynamic_items_configured? && base_item_randomization_enabled?
      end

      def dynamic_wild_configured?
        !!KantoReloaded::Settings.get(DYNAMIC_WILD_SETTING, false)
      end

      def dynamic_items_configured?
        !!KantoReloaded::Settings.get(DYNAMIC_ITEMS_SETTING, false)
      end

      def base_wild_randomization_enabled?
        base_switch(:SWITCH_RANDOM_WILD)
      end

      def base_item_randomization_enabled?
        base_switch(:SWITCH_RANDOM_ITEMS_GENERAL)
      end

      def show_prerequisite_message(kind)
        message = case kind
                  when :wild
                    _INTL(
                      "Enable Pokemon in KIF's Randomizer settings first. " \
                      "Dynamic Wild Pokemon selects a new species only after " \
                      "KIF's Pokemon randomizer is active."
                    )
                  when :items
                    _INTL(
                      "Enable Items in KIF's Randomizer settings first. " \
                      "Dynamic Items rerolls only the item sources KIF has " \
                      "enabled for randomization."
                    )
                  else
                    _INTL("Enable the corresponding KIF randomizer option first.")
                  end
        pbPlayBuzzerSE rescue nil
        KantoReloaded::PopupWindow.message(message, :theme => :warning)
      end

      def wild_mode
        KantoReloaded::Settings.get(WILD_MODE_SETTING, WILD_MODE_BST).to_i
      end

      def use_bst_range?
        wild_mode == WILD_MODE_BST
      end

      def recent_species
        Array(KantoReloaded::SaveData.get(
          MODULE_ID, RECENT_SPECIES_KEY, [], section: :modules
        )).dup
      rescue StandardError
        Array(@recent_species).dup
      end

      def remember_species(species)
        values = recent_species
        values.delete(species)
        values << species
        values = values.last(RECENT_SPECIES_LIMIT)
        @recent_species = values
        KantoReloaded::SaveData.set(
          MODULE_ID, RECENT_SPECIES_KEY, values, section: :modules
        )
        species
      rescue StandardError
        species
      end

      def clear_recent_species
        @recent_species = []
        KantoReloaded::SaveData.delete(
          MODULE_ID, RECENT_SPECIES_KEY, section: :modules
        )
        true
      rescue StandardError
        false
      end

      def pokemon_pool_label
        base_switch(:SWITCH_RANDOM_WILD_ONLY_CUSTOMS) ?
          _INTL("Custom Sprites Only") : _INTL("All Pokemon")
      end

      def bst_range_label
        return _INTL("Not Used") unless use_bst_range?
        return _INTL("Default") unless defined?(VAR_RANDOMIZER_WILD_POKE_BST) && $game_variables
        _INTL("+/- {1} BST", $game_variables[VAR_RANDOMIZER_WILD_POKE_BST].to_i)
      rescue StandardError
        _INTL("Default")
      end

      def legendary_rule_label
        base_switch(:SWITCH_RANDOM_WILD_LEGENDARIES) ?
          _INTL("Allowed") : _INTL("Matched Only")
      end

      def item_sources_label
        return _INTL("Disabled in KIF") unless base_switch(:SWITCH_RANDOM_ITEMS_GENERAL)
        sources = []
        sources << _INTL("Found Items") if base_switch(:SWITCH_RANDOM_FOUND_ITEMS)
        sources << _INTL("Found TMs") if base_switch(:SWITCH_RANDOM_FOUND_TMS)
        sources << _INTL("Given Items") if base_switch(:SWITCH_RANDOM_GIVEN_ITEMS)
        sources << _INTL("Given TMs") if base_switch(:SWITCH_RANDOM_GIVEN_TMS)
        sources.empty? ? _INTL("No Sources Enabled") : sources.join(", ")
      end

      def item_rules_label
        item_on = base_switch(:SWITCH_RANDOM_ITEMS)
        tm_on = base_switch(:SWITCH_RANDOM_TMS)
        return _INTL("Items and TMs") if item_on && tm_on
        return _INTL("Items Only") if item_on
        return _INTL("TMs Only") if tm_on
        _INTL("No Item Types Enabled")
      end

      def summary_lines
        [
          _INTL("Dynamic Wild Pokemon: {1}", dynamic_wild? ? "On" : "Off"),
          _INTL("Wild Selection: {1}", use_bst_range? ? "BST Range" : "Random"),
          _INTL("Dynamic Items: {1}", dynamic_items? ? "On" : "Off")
        ]
      end

      private

      def register_settings
        KantoReloaded::Settings.register(SETTINGS_ACTION, {
          :name => "Randomizer",
          :description => "Configure runtime randomization using KIF's existing rules.",
          :type => :button,
          :category => :gameplay,
          :owner => :kanto_reloaded,
          :priority => 1500,
          :on_press => proc {
            pbFadeOutIn {
              PokemonOptionScreen.new(
                KantoReloaded::Randomizer::SettingsScene.new
              ).pbStartScreen
            }
          }
        })
        visible = proc do |context|
          context.is_a?(Hash) && !!(context[:randomizer] || context["randomizer"])
        end
        KantoReloaded::Settings.register(DYNAMIC_WILD_SETTING, {
          :name => "Dynamic Wild Pokemon",
          :description => "Randomize each future normal wild encounter without rebuilding KIF mappings.",
          :type => :toggle,
          :default => false,
          :category => :gameplay,
          :owner => MODULE_ID,
          :priority => 10,
          :visible_if => visible
        })
        wild_enabled = proc { KantoReloaded::Randomizer.dynamic_wild? }
        KantoReloaded::Settings.register(WILD_MODE_SETTING, {
          :name => "Wild Selection",
          :description => "Match KIF's BST range or choose any eligible Pokemon at random.",
          :type => :enum,
          :values => ["BST Range", "Random"],
          :default => WILD_MODE_BST,
          :category => :gameplay,
          :owner => MODULE_ID,
          :priority => 20,
          :visible_if => visible,
          :enabled_if => wild_enabled
        })
        KantoReloaded::Settings.register(DYNAMIC_ITEMS_SETTING, {
          :name => "Dynamic Items",
          :description => "Randomize each future eligible found or given item without rebuilding KIF mappings.",
          :type => :toggle,
          :default => false,
          :category => :gameplay,
          :owner => MODULE_ID,
          :priority => 30,
          :visible_if => visible
        })
        true
      end

      def install_summary_hook
        return true unless Kernel.respond_to?(:sumRandomOptions)
        KantoReloaded::Hooks.wrap(
          Kernel,
          :sumRandomOptions,
          :randomizer_summary,
          :singleton => true,
          :required => true
        ) do |hook, *_arguments|
          base = hook.call.to_s
          lines = KantoReloaded::Randomizer.summary_lines
          base + "\n" + lines.join("\n")
        end
      end

      def base_switch(name)
        return false unless Object.const_defined?(name) && $game_switches
        !!$game_switches[Object.const_get(name)]
      rescue StandardError
        false
      end
    end
  end
end

KantoReloaded::Randomizer.boot
