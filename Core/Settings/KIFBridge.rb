#==============================================================================
# Kanto Reloaded: KIF Settings bridge and the Reloaded Settings toggle
#==============================================================================
# Reloaded Settings (Reloaded Systems, always its first row; On by default)
# picks the settings screen:
#   On   Kanto Reloaded's improved KIF Settings (Core/UI/SettingsScreen.rb)
#   Off  KIF Settings exactly as KIF Beta ships it
# Either way, KIF Settings' sidebar starts with a Kanto Reloaded section
# holding every Kanto Reloaded setting as one of KIF's own rows (one
# heading per Kanto Reloaded page), so they work in both screens.
#
# How the rows get there (990_KIF/000_Core/015-017):
#   - KIF::Options.add(:kanto_reloaded, scope) { option }: one builder per
#     setting, which returns nil while the setting is hidden
#   - the section entry in KIF::SettingsScreen::SECTIONS (rebuilt each
#     time the screen rebuilds, so it follows features switching on/off)
#   - KIF places rows by name, so a name used twice gets a unique name and
#     a RENAMES entry that shows the plain name under its heading. A name
#     KIF also lists in its own sections shows there too, as the same row
#     (Speech Frame takes PIF's place in Graphics > Text that way)
#   - KIF works out defaults by reading each option with a new
#     $PokemonSystem; Kanto Reloaded's options give their own default
#
# Everything Kanto Reloaded adds lives in this one section. Pages shown only
# with KIF's DEBUG option on (the Timing Profiler's headings, Developer
# Tools) come last, and an open screen gains or loses them when it rebuilds
# (DEBUG switched in Settings, Advanced).
#==============================================================================

module Reloaded
  module KIFBridge
    SECTION = :kanto_reloaded
    LABEL = "Kanto Reloaded"
    COLOUR = [214, 52, 60]      # KIF's own screen: a red tile; the improved screen draws a Poke Ball instead
    TOGGLE = :"systems.reloaded_settings"

    # Mixed into the bridge options: the setting they show, its default and
    # a description that adds why it is locked.
    module KROption
      attr_accessor :kr_key, :kr_default

      def description
        d = Reloaded::Settings.definition(@kr_key)
        return super unless d
        text = _INTL(d[:description].to_s)
        lock = Reloaded::Settings.lock_reason(@kr_key)
        text += " " + _INTL("Locked: {1}.", lock) if lock
        return text
      end
    end

    class << self
      def register_settings
        Reloaded::Settings.register(TOGGLE, :page => :systems, :priority => -1000,   # always first
          :name => "Reloaded Settings", :type => :toggle, :default => true, :preset => false,
          :description => "Use Kanto Reloaded's improved settings screen. Off shows KIF Settings as KIF ships it. Applies the next time Options opens.")
      end

      # True when Options should open the improved screen.
      def improved?
        return false if @vanilla
        return Reloaded::Settings.get(TOGGLE) ? true : false
      end

      # Runs the block with KIF Settings as it ships (the improved screen's
      # fallback if it fails).
      def vanilla
        @vanilla = true
        return yield
      ensure
        @vanilla = false
      end

      def boot
        unless defined?(::KIF::Options) && defined?(::KIF::SettingsScreen::SECTIONS)
          Reloaded::Log.info("KIF Settings isn't here; Kanto Reloaded's rows weren't added", :settings)
          return true
        end
        define_option_classes
        ::KIF::Options.register_menu(SECTION, LABEL, "Kanto Reloaded's settings.",
                                     Color.new(248, 248, 248), Color.new(64, 64, 64), LABEL)
        @keys = []
        refresh_section
        Reloaded::Hooks.prepend(nil, "KifSettingsScreen", ScreenRebuild, :id => :kif_bridge_rebuild)
        Reloaded::Hooks.prepend(nil, ::KifSettingsScreen.singleton_class, ScreenChoice, :id => :kif_bridge_choice) if defined?(::KifSettingsScreen)
        if ::KIF::SettingsScreen.respond_to?(:defaults_for)
          Reloaded::Hooks.prepend(nil, ::KIF::SettingsScreen.singleton_class, Defaults, :id => :kif_bridge_defaults)
        end
        # KIF's own descriptions go by name: a Kanto Reloaded row with one of
        # KIF's names (Speech Frame) keeps its own description
        if ::KIF::SettingsScreen.respond_to?(:description_for)
          Reloaded::Hooks.around(nil, ::KIF::SettingsScreen.singleton_class, :description_for,
                                 :id => :kif_bridge_descriptions) do |original, opt|
            Reloaded::KIFBridge.bridge_option?(opt) ? nil : original.call(opt)
          end
        end
        return true
      end

      # The Kanto Reloaded section, first in the sidebar: one heading per
      # page with a visible setting, its rows in page order.
      def refresh_section
        add_missing_builders
        headings = []
        @names = {}
        renames = ::KIF::SettingsScreen.const_defined?(:RENAMES) ? ::KIF::SettingsScreen::RENAMES : nil
        Reloaded::Settings.groups.each do |g|
          Reloaded::Settings.pages(g[:id]).each do |page|
            names = Reloaded::Settings.keys(page[:id]).map do |key|
              name = unique_name(key, page)
              renames[name] = _INTL(Reloaded::Settings.definition(key)[:name]) if renames && name != base_name(key)
              name
            end
            headings << [_INTL(page[:name]), names] unless names.empty?
          end
        end
        sections = ::KIF::SettingsScreen::SECTIONS
        entry = [SECTION, LABEL, COLOUR, headings]
        index = sections.index { |s| s[0] == SECTION }
        index ? sections[index] = entry : sections.insert(0, entry)
      end

      # KIF Settings, open on the Kanto Reloaded section at a heading's
      # first row (the Timing Profiler's Settings box).
      def open_heading(heading)
        return unless defined?(::KifSettingsScreen)
        screen = ::KifSettingsScreen.new(false, SECTION)
        list = screen.send(:rows)
        opts = screen.send(:opt_rows)
        i = opts.index { |r| list[r].heading.to_s == heading.to_s }
        if i
          screen.instance_variable_set(:@sel, i)
          screen.instance_variable_set(:@focus, :list)
        end
        screen.main
      end

      # The KIF option for a setting, or nil while it (or its page) is
      # hidden. KIF puts a row no section names in Game > Other, so a hidden
      # page's settings mustn't be built at all.
      def option_for(key)
        d = Reloaded::Settings.definition(key)
        return nil unless d && Reloaded::Settings.visible?(key) && Reloaded::Settings.page_visible?(d[:page])
        page = Reloaded::Settings.page(d[:page])
        name = unique_name(key, page)
        desc = _INTL(d[:description].to_s)
        s = Reloaded::Settings
        option = case d[:type]
                 when :toggle
                   KRToggle.new(name, [_INTL("Off"), _INTL("On")], proc { s.get(key) ? 1 : 0 },
                                proc { |v| s.set(key, v.to_i == 1) }, desc)
                 when :enum
                   KREnum.new(name, d[:values].map { |v| _INTL(v) }, proc { s.get(key) }, proc { |v| s.set(key, v) }, desc)
                 when :slider
                   min = d[:min] || 0
                   KRSlider.new(name, min, d[:max] || 100, d[:step] || 1, proc { s.get(key) - min },
                                proc { |v| s.set(key, v + min) }, desc)
                 when :number
                   min = d[:min] || 0
                   KRNumber.new(name, min, d[:max] || 999_999, proc { s.get(key) - min },
                                proc { |v| s.set(key, v + min) }, desc)
                 when :button
                   KRButton.new(name, proc { s.press(key) }, desc)
                 end
        return nil unless option
        option.kr_key = key
        option.kr_default = default_for_option(d)
        return option
      end

      def bridge_option?(option)
        return option.respond_to?(:kr_key) && !option.kr_key.nil?
      end

      private

      def define_option_classes
        return if const_defined?(:KRToggle, false)
        const_set(:KRToggle, Class.new(::EnumOption) { include KROption })
        const_set(:KREnum, Class.new(::EnumOption) { include KROption })
        const_set(:KRSlider, Class.new(::SliderOption) { include KROption })
        const_set(:KRNumber, Class.new(::NumberOption) { include KROption })
        const_set(:KRButton, Class.new(::ButtonOption) { include KROption })
      end

      # A builder for every setting that has none yet (all of them at boot;
      # any registered later on the next refresh).
      def add_missing_builders
        @keys ||= []
        Reloaded::Settings.groups.each do |g|
          all_pages(g[:id]).each do |page|
            all_keys(page[:id]).each { |key| add_builder(key) unless @keys.include?(key) }
          end
        end
      end

      def add_builder(key)
        d = Reloaded::Settings.definition(key)
        @keys << key
        return if [:text, :custom].include?(d[:type])
        ::KIF::Options.add(SECTION, d[:scope] == :save ? :save : :global) { Reloaded::KIFBridge.option_for(key) }
      end

      def default_for_option(d)
        case d[:type]
        when :toggle then return d[:default] ? 1 : 0
        when :enum then return d[:default].to_i
        when :slider, :number then return d[:default].to_i - (d[:min] || 0)
        end
        return nil
      end

      # The setting's name, made unique (KIF places rows by name).
      def base_name(key)
        return _INTL(Reloaded::Settings.definition(key)[:name])
      end

      def unique_name(key, page)
        @names ||= {}
        return @names[key] if @names[key]
        name = base_name(key)
        taken = @names.values
        name = "#{name} (#{_INTL(page[:name])})" if taken.include?(name)
        name = "#{name} #{key}" if taken.include?(name)
        @names[key] = name
        return name
      end

      # Every page and setting, hidden ones too (builders decide visibility).
      def all_pages(group_id)
        return Reloaded::Settings.instance_variable_get(:@pages).values.select { |p| p[:group] == group_id }
      end

      def all_keys(page_id)
        defs = Reloaded::Settings.instance_variable_get(:@definitions).values.select { |d| d[:page] == page_id }
        return defs.sort_by { |d| [d[:priority], d[:name]] }.map { |d| d[:key] }
      end
    end

    # The Kanto Reloaded section follows the settings that are showing now.
    module ScreenRebuild
      def rebuild
        Reloaded::Hooks.guard(nil, :kif_bridge_rebuild) { Reloaded::KIFBridge.refresh_section }
        super
      end
    end

    # Options opens the improved screen while Reloaded Settings is on.
    module ScreenChoice
      def new(*args, &block)
        if equal?(::KifSettingsScreen) && Reloaded::KIFBridge.improved? && defined?(Reloaded::SettingsScreen)
          begin
            return Reloaded::SettingsScreen.new(*args, &block)
          rescue Exception => e
            raise if Reloaded::Hooks.passthrough?(e)
            Reloaded::Log.exception("The improved settings screen didn't open; KIF Settings instead", e, :settings)
          end
        end
        super
      end
    end

    # KIF works out defaults by reading options with a new $PokemonSystem;
    # Kanto Reloaded's options say their own.
    module Defaults
      def defaults_for(opts)
        out = super
        opts.each do |o|
          next unless Reloaded::KIFBridge.bridge_option?(o) && !o.kr_default.nil?
          out[o] = o.kr_default
        end
        return out
      end
    end
  end
end

Reloaded::KIFBridge.register_settings
