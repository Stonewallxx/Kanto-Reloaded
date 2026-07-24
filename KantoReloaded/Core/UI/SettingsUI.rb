#==============================================================================
# Kanto Reloaded Settings UI
#==============================================================================
# Registry-backed settings scenes and row adapters.
#==============================================================================

module KantoReloaded
  module SettingsUI
    ROOT_CATEGORY_IDS = [
      :interface,
      :gameplay,
      :quality_of_life,
      :economy,
      :utility
    ].freeze

    class << self
      def open
        return false unless available?
        scene = RootScene.new
        PokemonOptionScreen.new(scene).pbStartScreen
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Could not open Kanto Reloaded settings", e, channel: :ui) if defined?(KantoReloaded::Log)
        false
      end

      def open_category(category_id)
        return false unless available?
        PokemonOptionScreen.new(CategoryScene.new(category_id)).pbStartScreen
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Could not open settings category #{category_id}", e, channel: :ui) if defined?(KantoReloaded::Log)
        false
      end

      def open_module(module_id, options = {})
        return false unless available?
        PokemonOptionScreen.new(ModuleScene.new(module_id, options)).pbStartScreen
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Could not open settings module #{module_id}", e, channel: :ui) if defined?(KantoReloaded::Log)
        false
      end

      def open_legacy
        return false unless available?
        KantoReloaded::MSMCompatibility.activate if defined?(KantoReloaded::MSMCompatibility)
        PokemonOptionScreen.new(LegacyRootScene.new).pbStartScreen
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Could not open converted Mod Settings", e, channel: :ui) if defined?(KantoReloaded::Log)
        false
      end

      def available?
        defined?(PokemonOptionScreen) && defined?(PokemonOption_Scene) && defined?(KantoReloaded::Settings)
      end

      def definitions_for(options = {})
        KantoReloaded::Settings.definitions(options).select do |definition|
          KantoReloaded::Settings.visible?(definition[:key], options)
        end
      end

      def ordered_definitions(definitions)
        actions, values = Array(definitions).partition { |definition| definition[:type] == :button }
        anchored, leading = actions.partition { |definition| ordering_anchor(definition) }
        ordered = leading + values
        anchored.each do |definition|
          anchor = ordering_anchor(definition)
          index = ordered.index { |entry| entry[:key] == anchor }
          index ? ordered.insert(index + 1, definition) : ordered << definition
        end
        ordered
      end

      def reset_definitions(definitions)
        Array(definitions).each { |definition| KantoReloaded::Settings.reset(definition[:key]) }
        true
      end

      private

      def ordering_anchor(definition)
        metadata = definition[:metadata]
        return nil unless metadata.is_a?(Hash)
        value = metadata["after"] || metadata[:after]
        text = value.to_s.strip
        text.empty? ? nil : text.to_sym
      rescue
        nil
      end
    end

    module RowFactory
      module_function

      def build(definition, context = nil)
        return nil unless definition.is_a?(Hash)
        row = case definition[:type]
              when :toggle then toggle(definition)
              when :enum then enum(definition)
              when :number then RegistryNumberOption.new(definition)
              when :slider then RegistrySliderOption.new(definition)
              when :button then action(definition, context)
              when :text then text(definition)
              else
                KantoReloaded::Options::DisabledOption.new(
                  definition[:name],
                  proc {
                    KantoReloaded::Settings.get(
                      definition[:key], ""
                    ).to_s
                  },
                  definition[:description]
                )
              end
        attach_availability(row, definition, context)
      end

      def attach_availability(row, definition, context)
        return row unless row && definition[:enabled_if]
        row.extend(ConditionalAvailability)
        row.kr_availability_key = definition[:key]
        row.kr_availability_context = context
        row
      end

      def toggle(definition)
        EnumOption.new(
          _INTL(definition[:name]),
          [_INTL("Off"), _INTL("On")],
          proc { truthy?(KantoReloaded::Settings.get(definition[:key], definition[:default])) ? 1 : 0 },
          proc { |value| KantoReloaded::Settings.set(definition[:key], value.to_i == 1) },
          _INTL(definition[:description])
        )
      end

      def enum(definition)
        EnumOption.new(
          _INTL(definition[:name]),
          Array(definition[:values]).map { |value| _INTL(value) },
          proc { KantoReloaded::Settings.get(definition[:key], definition[:default]).to_i },
          proc { |value| KantoReloaded::Settings.set(definition[:key], value) },
          _INTL(definition[:description])
        )
      end

      def action(definition, context = nil)
        scene = context.is_a?(Hash) ? (context[:scene] || context["scene"]) : nil
        KantoReloaded::Options::ActionButton.new(
          _INTL(definition[:name]),
          proc {
            result = KantoReloaded::Settings.activate(definition[:key])
            scene.sync_window_values if scene && scene.respond_to?(:sync_window_values)
            result
          },
          _INTL(definition[:description])
        )
      end

      def text(definition)
        KantoReloaded::Options::TextDisplayOption.new(
          _INTL(definition[:name]),
          proc { KantoReloaded::Settings.get(definition[:key], definition[:default]).to_s },
          _INTL(definition[:description])
        )
      end

      def truthy?(value)
        value == true || (value.is_a?(Numeric) && value.to_i != 0) ||
          ["true", "on", "yes", "enabled", "1"].include?(value.to_s.downcase)
      end
    end

    module ConditionalAvailability
      attr_writer :kr_availability_key, :kr_availability_context

      def kr_enabled?
        KantoReloaded::Settings.enabled?(
          @kr_availability_key, @kr_availability_context
        )
      rescue StandardError
        false
      end

      def disabled?
        !kr_enabled?
      end

      def non_interactive?
        return true unless kr_enabled?
        return super if defined?(super)
        false
      end

      def set(value)
        return unless kr_enabled?
        super
      end

      def next(current)
        return current unless kr_enabled?
        super
      end

      def prev(current)
        return current unless kr_enabled?
        super
      end
    end

    if defined?(NumberOption)
      class RegistryNumberOption < NumberOption
        attr_reader :description

        def initialize(definition)
          @definition = definition
          @minimum = (definition[:minimum] || 0).to_i
          @description = _INTL(definition[:description])
          super(
            _INTL(definition[:name]),
            @minimum,
            (definition[:maximum] || @minimum).to_i,
            proc { KantoReloaded::Settings.get(definition[:key], definition[:default]).to_i - @minimum },
            proc { |value| KantoReloaded::Settings.set(definition[:key], value.to_i + @minimum) }
          )
        end
      end
    end

    if defined?(SliderOption)
      class RegistrySliderOption < SliderOption
        def initialize(definition)
          super(
            _INTL(definition[:name]),
            definition[:minimum] || 0,
            definition[:maximum] || 100,
            definition[:step] || 1,
            proc { KantoReloaded::Settings.get(definition[:key], definition[:default]) },
            proc { |value| KantoReloaded::Settings.set(definition[:key], value) },
            _INTL(definition[:description])
          )
        end
      end
    end

    if defined?(PokemonOption_Scene)
      class BaseScene < PokemonOption_Scene
        def kr_options_style?
          true
        end

        def pbFadeInAndShow(sprites, visiblesprites = nil)
          if visiblesprites
            visiblesprites.each { |key| sprites[key].visible = true if sprites[key] }
          else
            sprites.each_value { |sprite| sprite.visible = true if sprite }
          end
        end

        def initUIElements
          super
          @sprites["title"].text = _INTL(scene_title) if @sprites["title"].respond_to?(:text=)
          @sprites["textbox"].text = _INTL(scene_description) if @sprites["textbox"] && @sprites["textbox"].respond_to?(:text=)
        end

        def getDefaultDescription
          _INTL(scene_description)
        end

        def scene_title
          "Kanto Reloaded"
        end

        def scene_description
          "Kanto Reloaded settings."
        end

        def build_rows(definitions, context = nil)
          SettingsUI.ordered_definitions(definitions).map do |definition|
            RowFactory.build(definition, context)
          end.compact
        end

        def open_child(scene)
          pbFadeOutIn { PokemonOptionScreen.new(scene).pbStartScreen }
        end

        def sync_window_values
          return unless @sprites && @sprites["option"] && @PokemonOptions
          window = @sprites["option"]
          @PokemonOptions.each_with_index do |option, index|
            window.setValueNoRefresh(index, option.get || 0)
          end
          window.refresh
          updateDescription(window.index) if respond_to?(:updateDescription)
          true
        rescue StandardError => e
          KantoReloaded::Log.exception("Could not refresh settings values", e, channel: :ui) if defined?(KantoReloaded::Log)
          false
        end
      end

      class RootScene < BaseScene
        def pbGetOptions(_inloadscreen = false)
          rows = []
          categories_with_definitions.each do |category, definitions|
            description = category[:description].to_s
            description = "#{category[:name]} settings." if description.empty?
            rows << KantoReloaded::Options::CollapsibleHeader.new(
              _INTL(category[:name]), _INTL(description), :collapsed => true
            )
            rows.concat(build_rows(definitions, :category => category[:id], :scene => self))
            unless definitions.none? { |definition| definition[:type] != :button }
              rows << KantoReloaded::Options::ActionButton.new(
                _INTL("Reset Category"),
                proc { reset_category(category, definitions) },
                _INTL("Restore every setting in this category to its default value.")
              )
            end
          end
          rows << KantoReloaded::Options::CollapsibleHeader.new(
            _INTL("About"), _INTL("Kanto Reloaded framework information."), :collapsed => true
          )
          rows << KantoReloaded::Options::TextDisplayOption.new(
            _INTL("Framework"), proc { "Kanto Reloaded #{KantoReloaded.version}" },
            _INTL("Current Kanto Reloaded framework version.")
          )
          rows << KantoReloaded::Options::TextDisplayOption.new(
            _INTL("Author"), proc { "Stonewall" },
            _INTL("Kanto Reloaded author.")
          )
          rows << KantoReloaded::Options::ActionButton.new(
            _INTL("Discord Link"),
            proc { KantoReloaded::BugReport.open_discord },
            _INTL("Open the Kanto Reloaded Discord thread.")
          )
          rows << KantoReloaded::Options::StandaloneActionButton.new(
            _INTL("File A Bug Report"),
            proc { KantoReloaded::BugReport.file },
            _INTL("Create a sanitized report, upload it, copy its link, and open the bug report thread.")
          )
          rows
        end

        private

        def reset_category(category, definitions)
          return unless KantoReloaded::PopupWindow.confirm(
            _INTL("Reset all {1} settings to their defaults?", category[:name]), :default => false
          )
          SettingsUI.reset_definitions(definitions)
          sync_window_values
          KantoReloaded::Toast.success(_INTL("Category reset complete."))
        end

        def categories_with_definitions
          ROOT_CATEGORY_IDS.map do |category_id|
            category = KantoReloaded::Settings.category(category_id)
            next nil unless category
            definitions = SettingsUI.definitions_for(:category => category[:id], :scene => self).reject do |definition|
              definition[:owner] == KantoReloaded::MSMCompatibility::LEGACY_OWNER
            end
            [category, definitions]
          end.compact
        end
      end

      class CategoryScene < BaseScene
        def initialize(category_id)
          super()
          @category_id = category_id.to_sym
          @category = KantoReloaded::Settings.category(@category_id) || {
            :id => @category_id, :name => @category_id.to_s, :description => ""
          }
        end

        def scene_title
          @category[:name]
        end

        def scene_description
          text = @category[:description].to_s
          text.empty? ? "#{@category[:name]} settings." : text
        end

        def pbGetOptions(_inloadscreen = false)
          definitions = SettingsUI.definitions_for(:category => @category_id, :scene => self)
          rows = build_rows(definitions, :category => @category_id, :scene => self)
          unless definitions.empty?
            rows << KantoReloaded::Options::ActionButton.new(
              _INTL("Reset Category"),
              proc { reset_category(definitions) },
              _INTL("Restore every setting in this category to its default value.")
            )
          end
          rows
        end

        private

        def reset_category(definitions)
          return unless KantoReloaded::PopupWindow.confirm(
            _INTL("Reset all {1} settings to their defaults?", @category[:name]), :default => false
          )
          SettingsUI.reset_definitions(definitions)
          sync_window_values
          KantoReloaded::Toast.success(_INTL("Category reset complete."))
        end
      end

      class LegacyRootScene < BaseScene
        def scene_title
          "Mod Settings"
        end

        def scene_description
          "Settings registered by installed mods."
        end

        def pbGetOptions(_inloadscreen = false)
          rows = []
          legacy_categories.each do |category, definitions|
            description = category[:description].to_s
            description = "#{category[:name]} settings." if description.empty?
            rows << KantoReloaded::Options::CollapsibleHeader.new(
              _INTL(category[:name]), _INTL(description), :collapsed => true
            )
            rows.concat(build_rows(definitions, :category => category[:id], :scene => self, :legacy_msm => true))
            rows << KantoReloaded::Options::ActionButton.new(
              _INTL("Reset Category"),
              proc { reset_category(category, definitions) },
              _INTL("Restore every setting in this category to its default value.")
            )
          end
          rows.concat(build_rows(
            loose_legacy_definitions,
            :scene => self, :legacy_msm => true, :no_category => true
          ))
          if rows.empty?
            rows << KantoReloaded::Options::TextDisplayOption.new(
              _INTL("Installed Mods"), proc { _INTL("No settings registered") },
              _INTL("No installed mods have registered settings.")
            )
          end
          rows
        end

        private

        def legacy_categories
          KantoReloaded::Settings.categories.map do |category|
            next if category[:id] == :nocategory
            definitions = SettingsUI.definitions_for(:category => category[:id], :scene => self).select do |definition|
              definition[:owner] == KantoReloaded::MSMCompatibility::LEGACY_OWNER
            end
            definitions.empty? ? nil : [category, definitions]
          end.compact
        end

        def loose_legacy_definitions
          SettingsUI.definitions_for(:category => :nocategory, :scene => self).select do |definition|
            definition[:owner] == KantoReloaded::MSMCompatibility::LEGACY_OWNER
          end
        end

        def reset_category(category, definitions)
          return unless KantoReloaded::PopupWindow.confirm(
            _INTL("Reset all {1} settings to their defaults?", category[:name]), :default => false
          )
          SettingsUI.reset_definitions(definitions)
          sync_window_values
          KantoReloaded::Toast.success(_INTL("Category reset complete."))
        end
      end

      class ModuleScene < BaseScene
        def initialize(module_id, options = {})
          super()
          @module_id = module_id.to_sym
          data = options.is_a?(Hash) ? options : { :title => options }
          @module_title = data[:title].to_s.strip
        end

        def scene_title
          return @module_title unless @module_title.empty?
          @module_id.to_s.split(/[_.-]+/).map { |part| part.capitalize }.join(" ")
        end

        def pbGetOptions(_inloadscreen = false)
          definitions = SettingsUI.definitions_for(:owner => @module_id, :scene => self)
          rows = build_rows(definitions, :module => @module_id, :scene => self)
          unless definitions.empty?
            rows << KantoReloaded::Options::ActionButton.new(
              _INTL("Reset Module"),
              proc { reset_module },
              _INTL("Restore this module's settings to their defaults.")
            )
          end
          rows
        end

        private

        def reset_module
          return unless KantoReloaded::PopupWindow.confirm(
            _INTL("Reset all {1} settings to their defaults?", scene_title), :default => false
          )
          KantoReloaded::Settings.reset_module(@module_id)
          sync_window_values
          KantoReloaded::Toast.success(_INTL("Module reset complete."))
        end
      end
    end
  end

  class << self
    def open_settings
      SettingsUI.open
    end

    def open_module_settings(module_id, options = {})
      SettingsUI.open_module(module_id, options)
    end
  end
end
