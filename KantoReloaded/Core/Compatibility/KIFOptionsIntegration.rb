#==============================================================================
# Kanto Reloaded KIF Options Integration
#==============================================================================
# Narrow, guarded aliases that adapt KIF settings scenes without replacing
# their option definitions, callbacks, storage, or source files.
#==============================================================================

module KantoReloaded
  module KIFOptionsIntegration
    ENTRY_LABEL = "Kanto Reloaded"
    MOD_SETTINGS_LABEL = "Mod Settings"
    DEFAULT_EXCLUSIONS = [
      "FusionSelectOptionsScene",
      "FusionMovesOptionsScene",
      "ModSettingsScene",
      "PresetSettingsScene",
      "ModSettingsColorScene"
    ].freeze

    @excluded_scenes = DEFAULT_EXCLUSIONS.dup

    class << self
      def install
        return true if @installed
        return false unless defined?(PokemonOption_Scene)
        install_scene_aliases
        install_kif_empty_scene_hooks
        @installed = true
        KantoReloaded::Log.info("Installed guarded KIF options integration", :ui) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        @installed = false
        KantoReloaded::Log.exception("KIF options integration failed", e, channel: :ui) if defined?(KantoReloaded::Log)
        false
      end

      def style_scene?(scene)
        return false unless scene
        if scene.respond_to?(:kr_options_style?)
          explicit = scene.kr_options_style?
          return !!explicit unless explicit.nil?
        end
        !@excluded_scenes.include?(scene.class.name.to_s)
      rescue
        false
      end

      def exclude_scene(class_name)
        name = class_name.is_a?(Class) ? class_name.name : class_name.to_s
        @excluded_scenes << name unless name.empty? || @excluded_scenes.include?(name)
        true
      end

      def include_scene(class_name)
        name = class_name.is_a?(Class) ? class_name.name : class_name.to_s
        @excluded_scenes.delete(name)
        true
      end

      def excluded_scenes
        @excluded_scenes.dup
      end

      def adapt_options(scene, options)
        result = options.is_a?(Array) ? options : Array(options)
        rename_tutor_net_option(result)
        return result unless root_options_scene?(scene)
        return result unless defined?(ButtonOption)
        result.delete_if do |option|
          option.respond_to?(:name) && option.name.to_s == _INTL(MOD_SETTINGS_LABEL)
        end
        unless result.any? { |option| option.respond_to?(:name) && option.name.to_s == _INTL(ENTRY_LABEL) }
          entry = ButtonOption.new(
            _INTL(ENTRY_LABEL),
            proc { open_settings_from(scene) },
            _INTL("Open Kanto Reloaded settings and modules.")
          )
          multiplayer_index = result.index do |option|
            option.respond_to?(:name) && option.name.to_s == _INTL("Multiplayer")
          end
          multiplayer_index ? result.insert(multiplayer_index + 1, entry) : result << entry
        end
        mod_settings_entry = ButtonOption.new(
          _INTL(MOD_SETTINGS_LABEL),
          proc { open_legacy_settings_from(scene) },
          _INTL("Configure settings registered by installed mods.")
        )
        kanto_index = result.index do |option|
          option.respond_to?(:name) && option.name.to_s == _INTL(ENTRY_LABEL)
        end
        kanto_index ? result.insert(kanto_index + 1, mod_settings_entry) : result << mod_settings_entry
        result
      rescue StandardError => e
        KantoReloaded::Log.exception("Could not add Kanto Reloaded settings entry", e, channel: :ui) if defined?(KantoReloaded::Log)
        options
      end

      def build_window(scene)
        return nil unless style_scene?(scene)
        return nil unless defined?(Window_KROption) && scene.instance_variable_defined?(:@PokemonOptions)
        sprites = scene.instance_variable_get(:@sprites)
        options = scene.instance_variable_get(:@PokemonOptions)
        return nil unless sprites.is_a?(Hash) && sprites["title"] && sprites["textbox"]
        options = KantoReloaded::Options.prepare_collapsible_options(scene, options)
        window = KantoReloaded::Options.build_window(
          options,
          0,
          sprites["title"].height,
          Graphics.width,
          Graphics.height - sprites["title"].height - sprites["textbox"].height
        )
        viewport = scene.instance_variable_get(:@viewport)
        window.viewport = viewport
        window.visible = true
        window
      rescue StandardError => e
        KantoReloaded::Log.exception("Could not build KR option window for #{scene.class}", e, channel: :ui) if defined?(KantoReloaded::Log)
        nil
      end

      def populate_empty_kif_category(scene, options)
        rows = Array(options)
        return rows unless empty_placeholder_rows?(rows)
        return rows unless scene.respond_to?(:pbGetInGameOptions)
        populated = Array(scene.pbGetInGameOptions)
        populated.empty? ? rows : populated
      rescue StandardError => e
        KantoReloaded::Log.exception("Could not populate KIF category #{scene.class}", e, channel: :ui) if defined?(KantoReloaded::Log)
        options
      end

      def setup_scene(scene)
        return false unless style_scene?(scene)
        return false unless hint_footer_enabled?(scene)
        sprites = scene.instance_variable_get(:@sprites)
        viewport = scene.instance_variable_get(:@viewport)
        return false unless sprites.is_a?(Hash) && viewport && defined?(Sprite) && defined?(Bitmap)
        return true if sprites["kr_hint_footer"]
        sprite = Sprite.new(viewport)
        sprite.bitmap = Bitmap.new(Graphics.width, 28)
        sprite.x = 0
        sprite.y = Graphics.height - 28
        sprite.z = 100_000
        sprites["kr_hint_footer"] = sprite
        draw_footer(scene)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Could not create KR options footer", e, channel: :ui) if defined?(KantoReloaded::Log)
        false
      end

      def update_scene(scene)
        return false unless style_scene?(scene)
        signature = KantoReloaded::Options.frame_signature
        if scene.instance_variable_get(:@kr_frame_signature) != signature
          KantoReloaded::Options.refresh_option_scene_skins(scene)
          scene.instance_variable_set(:@kr_frame_signature, signature)
        end
        KantoReloaded::MouseInput.update if defined?(KantoReloaded::MouseInput)
        if hint_footer_enabled?(scene)
          if defined?(KantoReloaded::HintText) && KantoReloaded::HintText.triggered? && !KantoReloaded::UI::Modal.active?
            KantoReloaded::HintText.open_popup(_INTL("Options Controls"), hint_entries)
            draw_footer(scene)
            return true
          end
          handle_footer_mouse(scene)
        end
        false
      rescue StandardError => e
        KantoReloaded::Log.exception("KR options scene update failed", e, channel: :ui) if defined?(KantoReloaded::Log)
        false
      end

      def draw_footer(scene)
        sprites = scene.instance_variable_get(:@sprites)
        sprite = sprites["kr_hint_footer"] rescue nil
        return false unless sprite && sprite.bitmap
        bitmap = sprite.bitmap
        bitmap.clear
        bitmap.fill_rect(0, 0, bitmap.width, bitmap.height, Color.new(18, 22, 28, 220))
        pbSetSystemFont(bitmap) if defined?(pbSetSystemFont)
        KantoReloaded::HintText.draw_footer(
          bitmap, footer_entries, 8, 2, bitmap.width - 16,
          :height => 24, :size => 14, :hint_label => _INTL("Hints")
        )
        true
      rescue
        false
      end

      private

      def rename_tutor_net_option(options)
        Array(options).each do |option|
          next unless option.respond_to?(:name)
          next unless option.name.to_s == _INTL("Tutor.net") || option.name.to_s == "Tutor.net"
          option.instance_variable_set(:@name, _INTL("TM Vault"))
          if option.instance_variable_defined?(:@description)
            option.instance_variable_set(:@description, _INTL("Controls whether TM Vault appears in the pause menu."))
          end
        end
        options
      rescue StandardError => e
        KantoReloaded::Log.exception("Could not rename the Tutor.net option", e, channel: :ui) if defined?(KantoReloaded::Log)
        options
      end

      def install_scene_aliases
        KantoReloaded::Hooks.wrap(
          PokemonOption_Scene, :pbAddOnOptions, :kif_options_add_on, :required => true
        ) do |hook, _options|
          existing = hook.call
          KantoReloaded::KIFOptionsIntegration.adapt_options(self, existing)
        end
        KantoReloaded::Hooks.wrap(
          PokemonOption_Scene, :initOptionsWindow, :kif_options_window, :required => true
        ) do |hook, *_args|
          adapted = KantoReloaded::KIFOptionsIntegration.build_window(self)
          adapted || hook.call
        end
        KantoReloaded::Hooks.wrap(
          PokemonOption_Scene, :pbStartScene, :kif_options_start, :required => true
        ) do |hook, *_args|
          result = hook.call
          KantoReloaded::KIFOptionsIntegration.setup_scene(self)
          result
        end
        KantoReloaded::Hooks.wrap(
          PokemonOption_Scene, :pbUpdate, :kif_options_update, :required => true
        ) do |hook, *_args|
          result = hook.call
          KantoReloaded::KIFOptionsIntegration.update_scene(self)
          result
        end
      end

      def install_kif_empty_scene_hooks
        ["KurayOptSc_5", "KurayOptSc_6"].each do |class_name|
          next unless Object.const_defined?(class_name)
          scene_class = Object.const_get(class_name)
          KantoReloaded::Hooks.wrap(
            scene_class, :pbGetOptions, "kif_populate_#{class_name.downcase}"
          ) do |hook, *_args|
            rows = hook.call
            KantoReloaded::KIFOptionsIntegration.populate_empty_kif_category(self, rows)
          end
        end
      end

      def empty_placeholder_rows?(rows)
        return true if rows.empty?
        rows.all? do |option|
          option.respond_to?(:name) && option.name.to_s =~ /\A\s*###\s*EMPTY\s*###\s*\z/i
        end
      rescue
        false
      end

      def root_options_scene?(scene)
        scene && scene.class == PokemonOption_Scene
      rescue
        false
      end

      def hint_footer_enabled?(scene)
        options = Array(scene.instance_variable_get(:@PokemonOptions))
        options.any? { |option| adjustable_option?(option) }
      rescue
        false
      end

      def adjustable_option?(option)
        return false if defined?(ButtonOption) && option.is_a?(ButtonOption)
        if defined?(KantoReloaded::Options)
          non_adjustable = [
            KantoReloaded::Options::Spacer,
            KantoReloaded::Options::CategoryHeader,
            KantoReloaded::Options::ActionButton,
            KantoReloaded::Options::TextDisplayOption
          ].select { |klass| klass.is_a?(Class) }
          return false if non_adjustable.any? { |klass| option.is_a?(klass) }
        end
        true
      rescue
        true
      end

      def open_settings_from(scene)
        if defined?(pbFadeOutIn)
          pbFadeOutIn { KantoReloaded::SettingsUI.open }
        else
          KantoReloaded::SettingsUI.open
        end
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Kanto Reloaded settings entry failed", e, channel: :ui) if defined?(KantoReloaded::Log)
        false
      end

      def open_legacy_settings_from(scene)
        if defined?(pbFadeOutIn)
          pbFadeOutIn { KantoReloaded::SettingsUI.open_legacy }
        else
          KantoReloaded::SettingsUI.open_legacy
        end
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Converted Mod Settings entry failed", e, channel: :ui) if defined?(KantoReloaded::Log)
        false
      end

      def footer_entries
        [
          KantoReloaded::HintText.confirm(_INTL("Select")),
          KantoReloaded::HintText.back,
          KantoReloaded::HintText.action(_INTL("Adjust"))
        ]
      end

      def hint_entries
        footer_entries + [
          KantoReloaded::HintText.special(_INTL("Open Hints")),
          KantoReloaded::HintText.other(_INTL("Navigate"), _INTL("D-Pad")),
          KantoReloaded::HintText.other(_INTL("Adjust Value"), _INTL("Left/Right")),
          KantoReloaded::HintText.other(_INTL("Mouse Select"), _INTL("Move/Click"))
        ]
      end

      def handle_footer_mouse(scene)
        return false unless KantoReloaded::MouseInput.mouse_triggered?
        sprites = scene.instance_variable_get(:@sprites)
        sprite = sprites["kr_hint_footer"] rescue nil
        return false unless sprite && sprite.bitmap
        position = KantoReloaded::MouseInput.raw_position
        return false unless position
        local_x = position[0] - sprite.x
        local_y = position[1] - sprite.y
        if KantoReloaded::HintText.controls_at?(
          sprite.bitmap, local_x, local_y, 8, 2, sprite.bitmap.width - 16,
          :height => 24, :hint_label => _INTL("Hints")
        )
          KantoReloaded::HintText.open_popup(_INTL("Options Controls"), hint_entries)
          return true
        end
        false
      end
    end
  end
end

KantoReloaded::KIFOptionsIntegration.install if defined?(KantoReloaded::KIFOptionsIntegration)
