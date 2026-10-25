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
# Everything Kanto Reloaded adds lives in this one section, but for a group
# with a section of its own: KR Debug, after it, Stonewall's alone, there
# only with the Kanto Reloaded Debug mod installed (Debug Mode, Developer
# Tools). Pages a modder might use (the Timing Profiler's headings) stay in
# Kanto Reloaded's, last, shown with KIF's DEBUG option on.
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
      # page with a visible setting, its rows in page order. A group with a
      # section of its own (KR Debug, while the Kanto Reloaded Debug mod is
      # here) follows it, and goes while it has nothing to show.
      def refresh_section
        add_missing_builders
        headings = []
        own = []
        @names = {}
        renames = ::KIF::SettingsScreen.const_defined?(:RENAMES) ? ::KIF::SettingsScreen::RENAMES : nil
        Reloaded::Settings.groups.each do |g|
          list = g[:section] ? [] : headings
          Reloaded::Settings.pages(g[:id]).each do |page|
            names = Reloaded::Settings.keys(page[:id]).map do |key|
              name = unique_name(key, page)
              renames[name] = _INTL(Reloaded::Settings.definition(key)[:name]) if renames && name != base_name(key)
              name
            end
            list << [_INTL(page[:name]), names] unless names.empty?
          end
          own << [g, list] if g[:section]
        end
        sections = ::KIF::SettingsScreen::SECTIONS
        entry = [SECTION, LABEL, COLOUR, headings]
        index = sections.index { |s| s[0] == SECTION }
        index ? sections[index] = entry : sections.insert(0, entry)
        at = sections.index { |s| s[0] == SECTION }
        own.each do |g, list|
          i = sections.index { |s| s[0] == g[:id] }
          if list.empty?
            sections.delete_at(i) if i
            next
          end
          e = [g[:id], _INTL(g[:name]), g[:section], list]
          if i
            sections[i] = e
            at = i
          else
            at += 1
            sections.insert(at, e)
          end
        end
      end

      # A screen copies the sections when it opens, before its first rebuild:
      # a group's own section (KR Debug) that came or went since is put in
      # its list (after Kanto Reloaded's) or taken out, the cursor kept on
      # the section it was on. The rest of its list stays as the screen
      # made it (the improved screen leaves Presets out).
      def sync_sections(screen)
        list = screen.instance_variable_get(:@sections)
        return unless list.is_a?(Array)
        on = screen.instance_variable_get(:@section).to_i
        current = list[on] && list[on][0]
        Reloaded::Settings.groups.each do |g|
          next unless g[:section]
          entry = ::KIF::SettingsScreen::SECTIONS.find { |x| x[0] == g[:id] }
          i = list.index { |x| x[0] == g[:id] }
          if entry && !i
            at = (list.index { |x| x[0] == SECTION } || -1) + 1
            list.insert(at, [entry[0], entry[1], entry[2]])
          elsif !entry && i
            list.delete_at(i)
          end
        end
        k = list.index { |x| x[0] == current }
        screen.instance_variable_set(:@section, k || [on, list.length - 1].min)
      end

      # KIF Settings, open at a heading's first row (the Timing Profiler's
      # Settings box), in the section the heading is in (Kanto Reloaded's, or
      # its group's own: KR Debug). section picks one when two have a
      # heading of that name (the Egg Manager's).
      def open_heading(heading, section = nil)
        return unless defined?(::KifSettingsScreen)
        unless section
          page = Reloaded::Settings.instance_variable_get(:@pages).values.find { |pg| _INTL(pg[:name]) == heading.to_s }
          g = page && Reloaded::Settings.group(page[:group])
          section = g && g[:section] ? g[:id] : SECTION
        end
        screen = ::KifSettingsScreen.new(false, section)
        # the improved screen: the heading is in one of Kanto Reloaded's sections
        return screen.main if section == SECTION && screen.respond_to?(:open_at_heading) && screen.open_at_heading(heading)
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
        ::KIF::Options.add(menu_for(d), d[:scope] == :save ? :save : :global) { Reloaded::KIFBridge.option_for(key) }
      end

      # The KIF menu a setting's rows belong to: its group's own section's
      # (registered the first time), else Kanto Reloaded's
      def menu_for(d)
        g = Reloaded::Settings.group(Reloaded::Settings.page(d[:page])[:group])
        return SECTION unless g && g[:section]
        @menus ||= {}
        unless @menus[g[:id]]
          ::KIF::Options.register_menu(g[:id], _INTL(g[:name]), _INTL(g[:description].to_s),
                                       Color.new(248, 248, 248), Color.new(64, 64, 64), _INTL(g[:name]))
          @menus[g[:id]] = true
        end
        return g[:id]
      end

      def default_for_option(d)
        return nil if d[:no_default] || d[:read_only]      # no Default dot, X does nothing
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
        Reloaded::Hooks.guard(nil, :kif_bridge_rebuild) do
          Reloaded::KIFBridge.refresh_section
          Reloaded::KIFBridge.sync_sections(self)
        end
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
