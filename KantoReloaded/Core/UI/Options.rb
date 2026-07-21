#==============================================================================
# Kanto Reloaded Options UI
#==============================================================================
# Themes, reusable option rows, and the KR option window renderer.
#==============================================================================

module KantoReloaded
  module Options
    COLOR_THEMES = [
      { :id => :purple, :name => "Purple", :base => Color.new(168, 128, 228), :shadow => Color.new(64, 44, 84) },
      { :id => :blue,   :name => "Blue",   :base => Color.new(88, 176, 248),  :shadow => Color.new(32, 64, 96) },
      { :id => :green,  :name => "Green",  :base => Color.new(50, 205, 50),   :shadow => Color.new(20, 100, 20) },
      { :id => :red,    :name => "Red",    :base => Color.new(240, 120, 120), :shadow => Color.new(92, 44, 44) },
      { :id => :orange, :name => "Orange", :base => Color.new(248, 168, 88),  :shadow => Color.new(96, 64, 32) },
      { :id => :cyan,   :name => "Cyan",   :base => Color.new(88, 224, 224),  :shadow => Color.new(32, 84, 84) },
      { :id => :pink,   :name => "Pink",   :base => Color.new(248, 136, 192), :shadow => Color.new(96, 52, 72) },
      { :id => :yellow, :name => "Yellow", :base => Color.new(240, 224, 88),  :shadow => Color.new(92, 84, 32) },
      { :id => :white,  :name => "White",  :base => Color.new(248, 248, 248), :shadow => Color.new(72, 80, 88) },
      { :id => :black,  :name => "Black",  :base => Color.new(80, 80, 88),    :shadow => Color.new(160, 160, 168) }
    ].freeze

    CURSOR_THEMES = [
      { :id => :blue,   :name => "Blue",   :fill => Color.new(100, 160, 220, 160), :border => Color.new(60, 120, 180, 220) },
      { :id => :purple, :name => "Purple", :fill => Color.new(160, 120, 220, 160), :border => Color.new(100, 60, 170, 220) },
      { :id => :green,  :name => "Green",  :fill => Color.new(80, 200, 100, 160),  :border => Color.new(40, 140, 60, 220) },
      { :id => :red,    :name => "Red",    :fill => Color.new(220, 100, 100, 160), :border => Color.new(170, 50, 50, 220) },
      { :id => :orange, :name => "Orange", :fill => Color.new(220, 160, 80, 160),  :border => Color.new(170, 110, 30, 220) },
      { :id => :cyan,   :name => "Cyan",   :fill => Color.new(80, 220, 220, 160),  :border => Color.new(30, 160, 160, 220) },
      { :id => :pink,   :name => "Pink",   :fill => Color.new(220, 120, 180, 160), :border => Color.new(160, 60, 120, 220) },
      { :id => :yellow, :name => "Yellow", :fill => Color.new(220, 210, 80, 160),  :border => Color.new(160, 150, 30, 220) },
      { :id => :white,  :name => "White",  :fill => Color.new(220, 220, 220, 160), :border => Color.new(160, 160, 160, 220) },
      { :id => :black,  :name => "Black",  :fill => Color.new(60, 60, 70, 160),    :border => Color.new(30, 30, 40, 220) }
    ].freeze

    OPTION_THEME_KEY = :"ui.option_theme"
    CATEGORY_THEME_KEY = :"ui.category_theme"
    CURSOR_THEME_KEY = :"ui.cursor_theme"
    SMALL_TEXT_KEY = :"ui.small_text"
    MENU_FRAME_KEY = :"ui.menu_frame"
    SPEECH_FOLLOWS_MENU_KEY = :"ui.speech_follows_menu"
    DEFAULT_OPTION_THEME = 0
    DEFAULT_CATEGORY_THEME = 3
    DEFAULT_CURSOR_THEME = 0
    DEFAULT_SMALL_TEXT = 1
    DEFAULT_MENU_FRAME = "default_transparent"
    DEFAULT_SPEECH_FOLLOWS_MENU = 1
    WINDOWSKIN_DIR = File.join(KantoReloaded::ROOT, "Graphics", "Windowskins")
    WINDOWSKIN_LOGICAL_DIR = "Mods/KantoReloaded/Graphics/Windowskins"
    LEGACY_THEME_MIGRATION = "prototype_theme_fields_v1"

    class << self
      def boot
        register_settings
        install_small_text_hook
        install_frame_hooks
        register_frame_callbacks
        register_events
        migrate_legacy_theme_values
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Options UI boot failed", e, channel: :ui) if defined?(KantoReloaded::Log)
        false
      end

      def color_theme(index)
        COLOR_THEMES[index.to_i] || COLOR_THEMES[DEFAULT_OPTION_THEME]
      end

      def cursor_theme(index)
        CURSOR_THEMES[index.to_i] || CURSOR_THEMES[DEFAULT_CURSOR_THEME]
      end

      def theme_names
        COLOR_THEMES.map { |entry| _INTL(entry[:name]) }
      end

      def cursor_theme_names
        CURSOR_THEMES.map { |entry| _INTL(entry[:name]) }
      end

      def option_theme_index
        setting_value(OPTION_THEME_KEY, DEFAULT_OPTION_THEME)
      end

      def category_theme_index
        setting_value(CATEGORY_THEME_KEY, DEFAULT_CATEGORY_THEME)
      end

      def cursor_theme_index
        setting_value(CURSOR_THEME_KEY, DEFAULT_CURSOR_THEME)
      end

      def small_text?
        setting_value(SMALL_TEXT_KEY, DEFAULT_SMALL_TEXT) == 1
      end

      def menu_frames
        return @menu_frames if @menu_frames
        return @menu_frames = [] unless Dir.exist?(WINDOWSKIN_DIR)
        @menu_frames = Dir[File.join(WINDOWSKIN_DIR, "*.png")].sort_by do |path|
          natural_sort_key(File.basename(path))
        end.map do |path|
          basename = File.basename(path, ".png")
          {
            :name => basename,
            :label => windowskin_label(basename),
            :path => "#{WINDOWSKIN_LOGICAL_DIR}/#{basename}",
            :dark => dark_windowskin?(basename)
          }
        end
      rescue
        []
      end

      def menu_frame_names
        menu_frames.map { |entry| _INTL(entry[:label]) }
      end

      def default_menu_frame_index
        menu_frames.index { |entry| entry[:name].to_s.downcase == DEFAULT_MENU_FRAME } || 0
      end

      def current_menu_frame_index
        clamp_menu_frame_index(setting_value(MENU_FRAME_KEY, default_menu_frame_index))
      end

      def menu_frame_path(index = current_menu_frame_index)
        entry = menu_frames[clamp_menu_frame_index(index)]
        entry ? entry[:path] : ""
      end

      def speech_follows_menu?
        setting_value(SPEECH_FOLLOWS_MENU_KEY, DEFAULT_SPEECH_FOLLOWS_MENU) == 1
      end

      def current_speech_frame_index
        skins = defined?(::Settings::SPEECH_WINDOWSKINS) ? ::Settings::SPEECH_WINDOWSKINS : []
        index = ($PokemonSystem.textskin rescue 0).to_i
        [[index, 0].max, [skins.length - 1, 0].max].min
      end

      def current_menu_frame_dark?
        entry = menu_frames[current_menu_frame_index]
        entry ? !!entry[:dark] : true
      rescue
        true
      end

      def frame_signature
        [current_menu_frame_index, speech_follows_menu?]
      end

      def option_text_colors
        entry = color_theme(option_theme_index)
        return readable_text_colors if !current_menu_frame_dark? && entry[:id] == :white
        [entry[:base], entry[:shadow]]
      end

      def category_text_colors
        entry = color_theme(category_theme_index)
        return readable_text_colors if !current_menu_frame_dark? && entry[:id] == :white
        [entry[:base], entry[:shadow]]
      end

      def cursor_colors
        entry = cursor_theme(cursor_theme_index)
        [entry[:fill], entry[:border]]
      end

      def theme_signature
        [option_theme_index, category_theme_index, cursor_theme_index, small_text?, frame_signature]
      end

      def apply_frame_settings
        return false unless defined?(MessageConfig)
        path = menu_frame_path
        MessageConfig.pbSetSystemFrame(path) unless path.empty?
        if speech_follows_menu?
          MessageConfig.pbSetSpeechFrame(path) unless path.empty?
        else
          MessageConfig.pbSetSpeechFrame(vanilla_speech_frame_path)
        end
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to apply menu frame settings", e, channel: :ui) if defined?(KantoReloaded::Log)
        false
      end

      def refresh_option_scene_skins(scene)
        return false unless scene && defined?(MessageConfig)
        apply_frame_settings
        sprites = scene.instance_variable_get(:@sprites) rescue nil
        return false unless sprites.is_a?(Hash)
        system_skin = MessageConfig.pbGetSystemFrame
        speech_skin = MessageConfig.pbGetSpeechFrame
        ["title", "option"].each do |key|
          sprite = sprites[key]
          next unless sprite && sprite.respond_to?(:setSkin)
          sprite.setSkin(system_skin)
          sprite.apply_theme if sprite.respond_to?(:apply_theme)
          sprite.refresh if sprite.respond_to?(:refresh)
        end
        textbox = sprites["textbox"]
        textbox.setSkin(speech_skin) if textbox && textbox.respond_to?(:setSkin)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to refresh option scene frames", e, channel: :ui) if defined?(KantoReloaded::Log)
        false
      end

      def visible_options(master)
        visible = []
        collapsed = false
        Array(master).each do |option|
          if defined?(CollapsibleHeader) && option.is_a?(CollapsibleHeader)
            collapsed = option.collapsed
            visible << option
          elsif !collapsed
            visible << option
          end
        end
        visible
      end

      def build_window(options, x, y, width, height)
        Window_KROption.new(options, x, y, width, height)
      end

      def prepare_collapsible_options(scene, options)
        return Array(options) unless scene && defined?(CollapsibleHeader)
        master = Array(options).map do |option|
          option = adapt_speech_frame_option(option)
          label = legacy_heading_label(option)
          collapsed = !legacy_heading_expanded_by_default?(label)
          label ? CollapsibleHeader.new(_INTL(label), option_description(option), :collapsed => collapsed) : option
        end
        headers = master.select { |option| option.is_a?(CollapsibleHeader) }
        if headers.empty?
          scene.instance_variable_set(:@PokemonOptions, master)
          return master
        end
        scene.instance_variable_set(:@kr_options_master, master)
        headers.each do |header|
          header.toggle_proc = proc { KantoReloaded::Options.rebuild_collapsible_options(scene) }
        end
        visible = visible_options(master)
        scene.instance_variable_set(:@PokemonOptions, visible)
        visible
      end

      def rebuild_collapsible_options(scene)
        return false unless scene
        sprites = scene.instance_variable_get(:@sprites) rescue nil
        master = scene.instance_variable_get(:@kr_options_master) rescue nil
        return false unless sprites && sprites["option"] && master
        window = sprites["option"]
        selected = window.instance_variable_get(:@options)[window.index] rescue nil
        visible = visible_options(master)
        scene.instance_variable_set(:@PokemonOptions, visible)
        window.instance_variable_set(:@options, visible)
        window.instance_variable_set(:@optvalues, Array.new(visible.length, 0))
        selected_index = selected ? visible.index(selected) : nil
        window.index = selected_index || [[window.index, visible.length].min, 0].max
        visible.each_with_index do |option, index|
          window.setValueNoRefresh(index, (option.get || 0))
        rescue
          window.setValueNoRefresh(index, 0)
        end
        window.refresh
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to rebuild collapsible options", e, channel: :ui) if defined?(KantoReloaded::Log)
        false
      end

      def migrate_legacy_theme_values
        return false unless defined?($PokemonSystem) && $PokemonSystem
        marker_root = theme_migration_root
        return true if marker_root[LEGACY_THEME_MIGRATION]
        mappings = {
          OPTION_THEME_KEY => :@kanto_reloaded_option_theme,
          CATEGORY_THEME_KEY => :@kanto_reloaded_category_theme,
          CURSOR_THEME_KEY => :@kanto_reloaded_cursor_theme
        }
        mappings.each do |key, variable|
          next if KantoReloaded::Settings.stored?(key)
          next unless $PokemonSystem.instance_variable_defined?(variable)
          KantoReloaded::Settings.set(key, $PokemonSystem.instance_variable_get(variable), :notify => false)
        end
        marker_root[LEGACY_THEME_MIGRATION] = true
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Legacy UI theme migration failed", e, channel: :ui) if defined?(KantoReloaded::Log)
        false
      end

      private

      def register_settings
        return unless defined?(KantoReloaded::Settings)
        KantoReloaded::Settings.register_category(:interface, {
          :name => "Interface",
          :description => "Kanto Reloaded interface colors and behavior.",
          :priority => 20,
          :owner => :kanto_reloaded
        })
        KantoReloaded::Settings.register_category(:gameplay, {
          :name => "Gameplay",
          :description => "Kanto Reloaded gameplay systems and behavior.",
          :priority => 25,
          :owner => :kanto_reloaded
        })
        KantoReloaded::Settings.register_category(:quality_of_life, {
          :name => "Quality of Life",
          :description => "Kanto Reloaded convenience and accessibility settings.",
          :priority => 30,
          :owner => :kanto_reloaded
        })
        KantoReloaded::Settings.register_category(:economy, {
          :name => "Economy",
          :description => "Kanto Reloaded shops, prices, and economy systems.",
          :priority => 35,
          :owner => :kanto_reloaded
        })
        KantoReloaded::Settings.register_category(:utility, {
          :name => "Developer / Utility",
          :description => "Kanto Reloaded developer, maintenance, and file-management tools.",
          :priority => 40,
          :owner => :kanto_reloaded
        })
        KantoReloaded::Settings.register(OPTION_THEME_KEY, theme_definition(
          "Option Color", theme_names, DEFAULT_OPTION_THEME, 10,
          "Color used for option labels and values."
        ))
        KantoReloaded::Settings.register(CATEGORY_THEME_KEY, theme_definition(
          "Category Color", theme_names, DEFAULT_CATEGORY_THEME, 20,
          "Color used for category headings."
        ))
        KantoReloaded::Settings.register(CURSOR_THEME_KEY, theme_definition(
          "Cursor Color", cursor_theme_names, DEFAULT_CURSOR_THEME, 30,
          "Color used for the selected option cursor."
        ))
        KantoReloaded::Settings.register(SMALL_TEXT_KEY, {
          :name => "Global Small Text",
          :description => "Uses the small system font globally.",
          :type => :toggle,
          :category => :interface,
          :scope => :global,
          :owner => :kanto_reloaded,
          :value_style => :integer,
          :default => DEFAULT_SMALL_TEXT,
          :priority => 40
        })
        frames = menu_frame_names
        unless frames.empty?
          KantoReloaded::Settings.register(MENU_FRAME_KEY, {
            :name => "Menu Frame",
            :description => "Window border used for menus and option screens.",
            :type => :enum,
            :category => :interface,
            :scope => :global,
            :owner => :kanto_reloaded,
            :values => frames,
            :default => default_menu_frame_index,
            :priority => 50
          })
        end
        KantoReloaded::Settings.register(SPEECH_FOLLOWS_MENU_KEY, {
          :name => "Speech Follows Menu",
          :description => "When On, speech and dialogue boxes use the selected menu frame.",
          :type => :toggle,
          :category => :interface,
          :scope => :global,
          :owner => :kanto_reloaded,
          :value_style => :integer,
          :default => DEFAULT_SPEECH_FOLLOWS_MENU,
          :priority => 60
        })
      end

      def install_small_text_hook
        return false unless defined?(KantoReloaded::Hooks)
        KantoReloaded::Hooks.wrap(Object, :pbSetSystemFont, :global_small_text) do |hook, bitmap, *_args|
          if KantoReloaded::Options.small_text? && respond_to?(:pbSetSmallFont, true)
            __send__(:pbSetSmallFont, bitmap)
          else
            hook.call
          end
        end
      end

      def install_frame_hooks
        return false unless defined?(KantoReloaded::Hooks) && defined?(MessageConfig)
        KantoReloaded::Hooks.wrap(
          MessageConfig, :pbDefaultSystemFrame, :menu_frame_default, :singleton => true
        ) do |hook, *_args|
          path = KantoReloaded::Options.resolved_menu_frame_path
          path.empty? ? hook.call : path
        end
        KantoReloaded::Hooks.wrap(
          MessageConfig, :pbDefaultSpeechFrame, :speech_follows_menu_default, :singleton => true
        ) do |hook, *_args|
          if KantoReloaded::Options.speech_follows_menu?
            path = KantoReloaded::Options.resolved_menu_frame_path
            path.empty? ? hook.call : path
          else
            hook.call
          end
        end
        KantoReloaded::Hooks.wrap(
          MessageConfig, :pbSetSystemFrame, :menu_frame_set, :singleton => true
        ) do |hook, _value, *_args|
          path = KantoReloaded::Options.menu_frame_path
          hook.call(path.empty? ? _value : path)
        end
        KantoReloaded::Hooks.wrap(
          MessageConfig, :pbSetSpeechFrame, :speech_follows_menu_set, :singleton => true
        ) do |hook, value, *_args|
          path = KantoReloaded::Options.menu_frame_path
          hook.call(KantoReloaded::Options.speech_follows_menu? && !path.empty? ? path : value)
        end
        true
      end

      def register_frame_callbacks
        return false unless defined?(KantoReloaded::Settings)
        KantoReloaded::Settings.register_on_change(
          MENU_FRAME_KEY, :apply_menu_frame, :owner => :kanto_reloaded, :invoke => true
        ) { |_value| KantoReloaded::Options.apply_frame_settings }
        KantoReloaded::Settings.register_on_change(
          SPEECH_FOLLOWS_MENU_KEY, :apply_speech_frame, :owner => :kanto_reloaded, :invoke => true
        ) { |_value| KantoReloaded::Options.apply_frame_settings }
        true
      end

      def theme_definition(name, values, default, priority, description)
        {
          :name => name,
          :description => description,
          :type => :enum,
          :category => :interface,
          :scope => :global,
          :owner => :kanto_reloaded,
          :values => values,
          :default => default,
          :priority => priority
        }
      end

      def register_events
        return if @events_registered || !defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(:kanto_reloaded_save_loaded, :options_theme_migration, priority: 350) do |_context|
          KantoReloaded::Options.migrate_legacy_theme_values
          KantoReloaded::Options.apply_frame_settings
        end
        KantoReloaded::Events.on(:kanto_reloaded_save_new_game, :options_theme_defaults, priority: 350) do |_context|
          KantoReloaded::Options.migrate_legacy_theme_values
          KantoReloaded::Options.apply_frame_settings
        end
        @events_registered = true
      end

      def setting_value(key, fallback)
        return fallback unless defined?(KantoReloaded::Settings)
        KantoReloaded::Settings.get(key, fallback).to_i
      rescue
        fallback
      end

      def clamp_menu_frame_index(index)
        [[index.to_i, 0].max, [menu_frames.length - 1, 0].max].min
      end

      def resolved_menu_frame_path
        path = menu_frame_path
        return "" if path.empty?
        receiver = Object.new
        receiver.respond_to?(:pbResolveBitmap, true) ? (receiver.send(:pbResolveBitmap, path) || "") : path
      rescue
        ""
      end
      public :resolved_menu_frame_path

      def vanilla_speech_frame_path
        skins = defined?(::Settings::SPEECH_WINDOWSKINS) ? ::Settings::SPEECH_WINDOWSKINS : []
        return "" if skins.empty?
        index = current_speech_frame_index
        "Graphics/Windowskins/#{skins[index]}"
      rescue
        ""
      end

      def readable_text_colors
        [Color.new(48, 48, 48), Color.new(224, 224, 224)]
      end

      def natural_sort_key(value)
        value.to_s.downcase.split(/(\d+)/).map { |part| part =~ /\A\d+\z/ ? part.to_i : part }
      end

      def windowskin_label(basename)
        case basename
        when /\A(?:RLD|KR|HR) Choice (\d+)a\z/i then "RLD #{$1} Dark"
        when /\A(?:RLD|KR|HR) Choice (\d+)\z/i then "RLD #{$1}"
        when /\Adefault_transparent\z/i then "RLD Transparent Dark"
        when /\Adefault_opaque\z/i then "RLD Opaque Dark"
        else
          label = basename.to_s.split(/[_\s]+/).map { |part| part[0, 1].to_s.upcase + part[1..-1].to_s }.join(" ")
          dark_windowskin?(basename) ? "#{label} Dark" : label
        end
      end

      def dark_windowskin?(basename)
        lower = basename.to_s.downcase
        ["default_transparent", "default_opaque"].include?(lower) || lower.end_with?("a")
      end

      def adapt_speech_frame_option(option)
        return option if defined?(SpeechFrameAdapter) && option.is_a?(SpeechFrameAdapter)
        return option unless option.respond_to?(:name) && option.name.to_s == _INTL("Speech Frame")
        SpeechFrameAdapter.new(option)
      rescue
        option
      end

      def legacy_heading_label(option)
        return nil unless option.respond_to?(:name)
        match = option.name.to_s.match(/\A\s*###\s*(.*?)\s*###\s*\z/)
        return nil unless match
        label = match[1].to_s.strip
        return nil if label.empty? || label.casecmp("EMPTY").zero?
        label
      rescue
        nil
      end

      def legacy_heading_expanded_by_default?(label)
        ["GLOBAL", "PER-SAVE FILE"].include?(label.to_s.strip.upcase)
      end

      def option_description(option)
        option.respond_to?(:description) ? option.description.to_s : ""
      rescue
        ""
      end

      def theme_migration_root
        return @fallback_theme_migrations ||= {} unless defined?(KantoReloaded::SaveData)
        root = KantoReloaded::SaveData.system(:settings)
        value = root["ui_migrations"] || root[:ui_migrations]
        unless value.is_a?(Hash)
          value = {}
          root["ui_migrations"] = value
        end
        value
      end
    end

    if defined?(Option)
      class Spacer < Option
        attr_reader :name
        def initialize; super(""); @name = ""; end
        def non_interactive?; true; end
        def get; 0; end
        def set(_value); end
        def values; [""]; end
        def next(current); current; end
        def prev(current); current; end
      end

      class HiddenOption < Spacer
      end

      class CategoryHeader < Option
        attr_reader :name
        def initialize(name, description = ""); super(description); @name = name; end
        def non_interactive?; true; end
        def get; 0; end
        def set(_value); end
        def values; [""]; end
        def next(current); current; end
        def prev(current); current; end
        def format(_value); "--- #{@name} ---"; end
      end

      class CollapsibleHeader < CategoryHeader
        attr_reader :collapsed
        attr_accessor :toggle_proc
        def initialize(name, description = "", options = {})
          super(name, description)
          @collapsed = !!options[:collapsed]
          @toggle_proc = nil
        end
        def non_interactive?; false; end
        def toggle
          @collapsed = !@collapsed
          @toggle_proc.call if @toggle_proc
        end
        def display_name; @collapsed ? "+ #{@name} +" : "- #{@name} -"; end
      end

      class ActionButton < Option
        attr_reader :name
        def initialize(name, action_proc, description = "")
          super(description)
          @name = name
          @action_proc = action_proc
        end
        def get; 0; end
        def set(_value); end
        def activate; @action_proc.call if @action_proc; end
        def next(current); current; end
        def prev(current); current; end
        def values; [""]; end
      end

      class TextDisplayOption < Option
        attr_reader :name
        def initialize(name, value_proc, description = "")
          super(description)
          @name = name
          @value_proc = value_proc
        end
        def non_interactive?; true; end
        def get; 0; end
        def set(_value); end
        def values; [current_text]; end
        def next(current); current; end
        def prev(current); current; end
        def current_text; (@value_proc.call rescue "").to_s; end
      end

      class DisabledOption < TextDisplayOption
        def initialize(name, value_proc, description = "")
          super(name, value_proc, description)
        end
        def disabled?; true; end
      end

      class SpeechFrameAdapter < NumberOption
        attr_reader :name, :description

        def initialize(original)
          @original = original
          @name = original.name
          @description = original.respond_to?(:description) ? original.description : ""
          super(
            @name, original.optstart, original.optend,
            proc { get }, proc { |value| set(value) }
          )
        end

        def get
          return 0 if KantoReloaded::Options.speech_follows_menu?
          @original.get
        end

        def set(value)
          return if KantoReloaded::Options.speech_follows_menu?
          @original.set(value)
        end

        def current_text
          _INTL("Uses Menu")
        end

        def next(current)
          return locked(current) if KantoReloaded::Options.speech_follows_menu?
          @original.next(current)
        end

        def prev(current)
          return locked(current) if KantoReloaded::Options.speech_follows_menu?
          @original.prev(current)
        end

        private

        def locked(current)
          pbPlayBuzzerSE rescue nil
          KantoReloaded::PopupWindow.message(_INTL("Speech Frame follows Menu Frame right now."))
          current
        end
      end
    end
  end
end

if defined?(Window_PokemonOption)
  class Window_KROption < Window_PokemonOption
    LABEL_FRAC = 9
    ROW_FRAC = 20

    def initialize(options, x, y, width, height)
      @kr_theme_signature = nil
      super(options, x, y, width, height)
      pbSetSystemFont(self.contents) if self.contents
      apply_theme
    end

    def apply_theme
      pbSetSystemFont(self.contents) if self.contents
      base, shadow = KantoReloaded::Options.option_text_colors
      @baseColor = base
      @shadowColor = shadow
      @nameBaseColor = base
      @nameShadowColor = shadow
      @selBaseColor = base
      @selShadowColor = shadow
      @kr_theme_signature = KantoReloaded::Options.theme_signature
      refresh rescue nil
    end

    def update
      old_index = self.index
      suppress_horizontal = self.active && action_option_at?(self.index) &&
        (Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT))
      if suppress_horizontal
        was_active = self.active
        self.active = false
        super
        self.active = was_active
      else
        super
      end
      apply_theme if @kr_theme_signature != KantoReloaded::Options.theme_signature
      refresh_availability
      move_off_non_interactive(old_index)
      update_kr_mouse

      if self.active && self.index < @options.length
        option = @options[self.index]
        if option.is_a?(KantoReloaded::Options::CollapsibleHeader) && Input.trigger?(Input::USE)
          option.toggle
          refresh
          return
        end
        if option.is_a?(KantoReloaded::Options::ActionButton) &&
           !dynamic_disabled?(option) && Input.trigger?(Input::USE)
          option.activate
          @mustUpdateOptions = false
          refresh
          return
        end
      end
      refresh_cursor_pulse if self.active && ((Graphics.frame_count rescue 0) % 4).zero?
    end

    def drawCursor(index, rect)
      if self.index == index
        fill_base, border_base = KantoReloaded::Options.cursor_colors
        pulse = Math.sin((Graphics.frame_count rescue 0) * Math::PI / 20.0) * 0.5 + 0.5
        fill = KantoReloaded::UI::Draw.with_alpha(fill_base, 90 + (pulse * 80).to_i)
        border = KantoReloaded::UI::Draw.with_alpha(border_base, 155 + (pulse * 80).to_i)
        KantoReloaded::UI::Draw.rounded_rect(
          self.contents, rect.x + 4, rect.y - 1, rect.width - 8, rect.height - 4, 4, fill, border
        )
      end
      Rect.new(rect.x + 16, rect.y, rect.width - 16, rect.height)
    end

    def drawItem(index, count, rect)
      return if dont_draw_item(index)
      if index == @options.length
        rect = drawCursor(index, rect)
        pbDrawShadowText(self.contents, rect.x, rect.y, rect.width, rect.height,
                         _INTL("Confirm"), Color.new(248, 248, 248), Color.new(72, 80, 88))
        return
      end
      return if index > @options.length
      option = @options[index]
      return unless option

      return if spacer_option?(option)
      return draw_category_header(option, index, rect) if category_option?(option)
      return draw_category_header(option, index, rect) if legacy_heading?(option)
      return draw_disabled_option(option, index, rect) if dynamic_disabled?(option)

      case option
      when KantoReloaded::Options::CollapsibleHeader
        draw_collapsible_header(option, index, rect)
      when KantoReloaded::Options::CategoryHeader
        draw_category_header(option, index, rect)
      when KantoReloaded::Options::DisabledOption
        draw_text_display(option, index, rect, true)
      when KantoReloaded::Options::TextDisplayOption
        draw_text_display(option, index, rect)
      when KantoReloaded::Options::ActionButton
        draw_action_button(option, index, rect)
      when KantoReloaded::Options::SpeechFrameAdapter
        if KantoReloaded::Options.speech_follows_menu?
          draw_text_display(option, index, rect)
        else
          draw_number(option, index, rect)
        end
      else
        if defined?(ButtonOption) && option.is_a?(ButtonOption)
          draw_action_button(option, index, rect)
        elsif defined?(ButtonsOption) && option.is_a?(ButtonsOption)
          draw_enum(option, index, rect)
        elsif defined?(EnumOption) && option.is_a?(EnumOption)
          draw_enum(option, index, rect)
        elsif defined?(NumberOption) && option.is_a?(NumberOption)
          draw_number(option, index, rect)
        elsif slider_option?(option)
          draw_slider(option, index, rect)
        else
          super(index, count, rect)
        end
      end
    end

    private

    def availability_signature
      @options.map do |option|
        option.respond_to?(:disabled?) ? !!option.disabled? : false
      end
    rescue
      []
    end

    def refresh_availability
      signature = availability_signature
      return if signature == @kr_availability_signature
      @kr_availability_signature = signature
      refresh
    end

    def dynamic_disabled?(option)
      option.respond_to?(:disabled?) && option.disabled?
    rescue
      false
    end

    def refresh_cursor_pulse
      return unless self.contents && self.index && self.index >= 0
      rect = itemRect(self.index)
      return if rect.width <= 0 || rect.height <= 0
      self.contents.fill_rect(rect.x, rect.y, rect.width, rect.height, Color.new(0, 0, 0, 0))
      drawItem(self.index, itemCount, rect)
    rescue
      refresh
    end

    def spacer_option?(option)
      option.is_a?(KantoReloaded::Options::Spacer) ||
        (defined?(SpacerOption) && option.is_a?(SpacerOption))
    end

    def category_option?(option)
      defined?(CategoryHeaderOption) && option.is_a?(CategoryHeaderOption)
    end

    def legacy_heading?(option)
      return false unless option.respond_to?(:name)
      option.name.to_s =~ /\A\s*#{Regexp.escape("###")}.*#{Regexp.escape("###")}\s*\z/
    rescue
      false
    end

    def slider_option?(option)
      (defined?(SliderOption) && option.is_a?(SliderOption)) ||
        option.class.name.to_s.include?("Slider")
    rescue
      false
    end

    def non_interactive?(option)
      option.respond_to?(:non_interactive?) && option.non_interactive?
    end

    def move_off_non_interactive(old_index)
      return unless self.active && self.index < @options.length
      return unless non_interactive?(@options[self.index])
      direction = self.index >= old_index ? 1 : -1
      direction = 1 if direction == 0
      candidate = self.index
      (@options.length + 1).times do
        candidate += direction
        break if candidate < 0 || candidate > @options.length
        if candidate == @options.length || !non_interactive?(@options[candidate])
          self.index = candidate
          @selected_position = candidate < @options.length ? self[candidate] : 0
          @mustUpdateDescription = true
          return
        end
      end
    rescue
      nil
    end

    def update_kr_mouse
      return unless self.active
      wheel = KantoReloaded::MouseInput.wheel_delta
      unless wheel == 0
        move_with_mouse_wheel(wheel < 0 ? 1 : -1)
        return
      end
      position = KantoReloaded::MouseInput.active_position
      return unless position
      target = mouse_item_at(position[0], position[1])
      return if target.nil?
      if target != self.index
        @index = target
        @selected_position = target < @options.length ? self[target] : 0
        @mustUpdateDescription = true
        refresh
        pbPlayCursorSE rescue nil
      end
      return unless KantoReloaded::MouseInput.mouse_triggered?
      activate_mouse_item(target)
    rescue StandardError => e
      KantoReloaded::Log.exception("Options mouse handling failed", e, channel: :ui) if defined?(KantoReloaded::Log)
    end

    def mouse_item_at(mouse_x, mouse_y)
      border_x = (self.borderX rescue 32) / 2
      border_y = (self.borderY rescue 32) / 2
      itemCount.times do |index|
        rect = itemRect(index)
        next if rect.width <= 0 || rect.height <= 0
        next if index < @options.length && non_interactive?(@options[index])
        x = self.x + border_x + rect.x
        y = self.y + border_y + rect.y
        return index if mouse_x >= x && mouse_x < x + rect.width && mouse_y >= y && mouse_y < y + rect.height
      end
      nil
    end

    def activate_mouse_item(index)
      return if index >= @options.length
      option = @options[index]
      return if non_interactive?(option)
      activated_action = false
      if option.is_a?(KantoReloaded::Options::CollapsibleHeader)
        option.toggle
        return
      elsif option.respond_to?(:activate)
        option.activate
        activated_action = true
      else
        self[index] = option.next(self[index])
      end
      @selected_position = self[index]
      @mustUpdateOptions = !activated_action
      @mustUpdateDescription = true
      refresh
    end

    def move_with_mouse_wheel(direction)
      candidate = self.index
      itemCount.times do
        candidate += direction
        candidate = 0 if candidate >= itemCount
        candidate = itemCount - 1 if candidate < 0
        next if candidate < @options.length && non_interactive?(@options[candidate])
        break
      end
      return if candidate == self.index
      self.index = candidate
      @selected_position = candidate < @options.length ? self[candidate] : 0
      @mustUpdateDescription = true
      pbPlayCursorSE rescue nil
      refresh
    end

    def action_option_at?(index)
      return false if index.nil? || index < 0 || index >= @options.length
      option = @options[index]
      return true if option.is_a?(KantoReloaded::Options::ActionButton)
      defined?(ButtonOption) && option.is_a?(ButtonOption)
    rescue
      false
    end

    def label_width(rect)
      rect.width * LABEL_FRAC / ROW_FRAC
    end

    def category_colors
      KantoReloaded::Options.category_text_colors
    end

    def display_name(option)
      return option.format(0).to_s if option.respond_to?(:format)
      option.name.to_s.gsub(/\A\s*#+\s*|\s*#+\s*\z/, "")
    end

    def draw_centered_label(label, index, rect, base, shadow)
      rect = drawCursor(index, rect)
      text_width = self.contents.text_size(label.to_s).width rescue rect.width
      x = rect.x + [(rect.width - text_width) / 2, 0].max
      pbDrawShadowText(self.contents, x, rect.y, rect.width, rect.height, label.to_s, base, shadow)
    end

    def draw_category_header(option, index, rect)
      base, shadow = category_colors
      draw_centered_label(display_name(option), index, rect, base, shadow)
    end

    def draw_collapsible_header(option, index, rect)
      base, shadow = category_colors
      draw_centered_label(option.display_name, index, rect, base, shadow)
    end

    def draw_action_button(option, index, rect)
      draw_centered_label("[ #{option.name} ]", index, rect, @selBaseColor, @selShadowColor)
    end

    def draw_disabled_option(option, index, rect)
      rect = drawCursor(index, rect)
      label_w = label_width(rect)
      base = Color.new(144, 150, 158)
      shadow = Color.new(54, 58, 64)
      pbDrawShadowText(
        self.contents, rect.x, rect.y, label_w, rect.height,
        option.name, base, shadow
      )
      pbDrawShadowText(
        self.contents,
        centered_value_x(_INTL("Unavailable"), rect, label_w),
        rect.y,
        self.contents.text_size(_INTL("Unavailable")).width + 4,
        rect.height,
        _INTL("Unavailable"), base, shadow
      )
    end

    def centered_value_x(value, rect, label_w)
      area_x = rect.x + label_w
      area_w = rect.width - label_w
      value_w = self.contents.text_size(value.to_s).width
      area_x + [(area_w - value_w) / 2, 0].max
    rescue
      rect.x + label_w
    end

    def draw_text_display(option, index, rect, disabled = false)
      rect = drawCursor(index, rect)
      label_w = label_width(rect)
      base = disabled ? Color.new(144, 150, 158) : @nameBaseColor
      shadow = disabled ? Color.new(54, 58, 64) : @nameShadowColor
      pbDrawShadowText(self.contents, rect.x, rect.y, label_w, rect.height, option.name, base, shadow)
      pbDrawShadowText(self.contents, rect.x + label_w, rect.y, rect.width - label_w, rect.height,
                       option.current_text, base, shadow)
    end

    def draw_enum(option, index, rect)
      rect = drawCursor(index, rect)
      label_w = label_width(rect)
      pbDrawShadowText(self.contents, rect.x, rect.y, label_w, rect.height,
                       option.name, @nameBaseColor, @nameShadowColor)
      values = Array(option.values)
      return if values.empty?
      current = [[(self[index] || 0).to_i, 0].max, values.length - 1].min
      draw_cycling_value(values[current].to_s, current <= 0, current >= values.length - 1, rect, label_w)
    end

    def draw_number(option, index, rect)
      rect = drawCursor(index, rect)
      label_w = label_width(rect)
      pbDrawShadowText(self.contents, rect.x, rect.y, label_w, rect.height,
                       option.name, @nameBaseColor, @nameShadowColor)
      value = option.optstart + (self[index] || 0).to_i
      draw_cycling_value(value.to_s, value <= option.optstart, value >= option.optend, rect, label_w)
    end

    def draw_cycling_value(value, at_min, at_max, rect, label_w)
      area_x = rect.x + label_w
      area_w = rect.width - label_w
      arrow_w = self.contents.text_size("<").width
      value_w = self.contents.text_size(value).width
      gap = 6
      display_w = arrow_w + gap + value_w + gap + arrow_w
      start_x = area_x + [(area_w - display_w) / 2, 0].max
      pbDrawShadowText(self.contents, start_x, rect.y, arrow_w + gap, rect.height,
                       "<", @selBaseColor, @selShadowColor) unless at_min
      pbDrawShadowText(self.contents, start_x + arrow_w + gap, rect.y, value_w + 4, rect.height,
                       value, @selBaseColor, @selShadowColor)
      pbDrawShadowText(self.contents, start_x + arrow_w + gap + value_w + gap, rect.y, arrow_w + 4, rect.height,
                       ">", @selBaseColor, @selShadowColor) unless at_max
    end

    def draw_slider(option, index, rect)
      rect = drawCursor(index, rect)
      label_w = label_width(rect)
      pbDrawShadowText(self.contents, rect.x, rect.y, label_w, rect.height,
                       option.name, @nameBaseColor, @nameShadowColor)
      actual = (self[index] || 0).to_f
      min_v = option.optstart.to_f
      max_v = option.optend.to_f
      range = max_v - min_v
      range = 1.0 if range == 0.0
      pct = [[(actual - min_v) / range, 0.0].max, 1.0].min
      value_text = actual.to_i == actual ? actual.to_i.to_s : actual.to_s
      value_w = self.contents.text_size(value_text).width + 8
      area_x = rect.x + label_w
      area_w = rect.width - label_w
      full_bar_len = [area_w - value_w - 14, 60].max
      bar_len = [full_bar_len / 2, 60].max
      content_w = bar_len + 6 + value_w
      bar_x = area_x + [(area_w - content_w) / 2, 0].max
      bar_y = rect.y - 2 + rect.height / 2
      self.contents.fill_rect(bar_x, bar_y, bar_len, 4, @baseColor)
      tick_x = bar_x + ((bar_len - 8) * pct).round
      self.contents.fill_rect(tick_x, rect.y - 8 + rect.height / 2, 8, 16, @selBaseColor)
      pbDrawShadowText(self.contents, bar_x + bar_len + 6, rect.y, value_w, rect.height,
                       value_text, @selBaseColor, @selShadowColor)
    end
  end
end

KantoReloaded::Options.boot if defined?(KantoReloaded::Options)
