#==============================================================================
# Kanto Reloaded: settings as Overworld Menu rows
#==============================================================================
# Any on/off or choice setting in KIF Settings (KIF's, PIF's and Kanto
# Reloaded's own) can be a row on an Overworld Menu page (his call,
# 2026-10-20), and so can its buttons, such as Change Controls, and its
# sliders and numbers (2026-10-21). Edit Pages > Add a Setting opens KIF
# Settings in pick mode; the row then works the setting itself: A flips an
# On/Off one's switch, a choice opens its dropdown, a slider or number its
# slider (Dropped Slider), and a button is pressed, as in KIF Settings.
#
# The Overworld Menu's own switch can't be picked (it would close the menu
# from inside it). A Kanto Reloaded setting whose page is hidden now (the
# Timing Profiler's and Developer Tools' with DEBUG off) is out of sight.
#
# A row's key is "setting:<section>/<heading>/<name>". A setting that isn't
# there now (its module Off, its mod removed) stays in the layout, out of
# sight. The settings are read the way KIF Settings reads them, once, and
# again after KIF Settings closes (a module switched there can change them).
#
# No setting starts on a page: every one is the player's to add.
#==============================================================================

module Reloaded
  module OverworldMenu
    module SettingRows
      PREFIX = "setting:"

      class << self
        def boot
          # KIF Settings as it ships: the index is read again once it closes
          # (the improved screen does the same in its own main)
          if defined?(::KifSettingsScreen)
            Reloaded::Hooks.prepend(nil, "KifSettingsScreen", SettingsClosed, :id => :overworld_menu_settings_closed)
          end
          # a save's own settings are only there in a game
          [:save_loaded, :new_game, :title_screen].each do |ev|
            Reloaded::Events.on(ev, :"overworld_menu_settings_#{ev}") { Reloaded::OverworldMenu::SettingRows.forget }
          end
          return true
        end

        def setting?(key)
          return key.to_s.start_with?(PREFIX)
        end

        def available?
          return defined?(::KifSettingsScreen) && defined?(::KIF::SettingsScreen) &&
                 ::KIF::SettingsScreen.respond_to?(:choices?) ? true : false
        end

        # What a row can work: an On/Off or choice setting, a slider or a
        # number, or a button. Not the rows that only open another page of
        # KIF Settings (a mod's page, the catalog), nor the Overworld Menu's
        # own switch.
        def fits_row?(r)
          return false unless r && r.kind == :opt && r.opt && !r.action
          return false if own_switch?(r.opt)
          return button?(r.opt) || fits?(r.opt) || number?(r.opt)
        end

        # The Overworld Menu's On/Off (Features, and its page's first row)
        def own_switch?(opt)
          return false unless defined?(Reloaded::KIFBridge) && Reloaded::KIFBridge.bridge_option?(opt)
          return [:"features.#{Reloaded::OverworldMenu::FEATURE}", :"#{Reloaded::OverworldMenu::FEATURE}.enabled"].include?(opt.kr_key)
        end

        # A slider or a number
        def number?(opt)
          return ::KIF::SettingsScreen.slider?(opt) || (defined?(::NumberOption) && opt.is_a?(::NumberOption)) ? true : false
        rescue StandardError
          return false
        end

        def button?(opt)
          return ::KIF::SettingsScreen.button?(opt) ? true : false
        rescue StandardError
          return false
        end

        # On/Off or a choice
        def fits?(opt)
          return false unless opt && ::KIF::SettingsScreen.choices?(opt)
          return false if ::KIF::SettingsScreen.button?(opt)
          return opt.values.is_a?(Array) && opt.values.length >= 2
        rescue StandardError
          return false
        end

        def key_for(row)
          return PREFIX + [row.section, row.heading, row.label.to_s.strip].compact.map(&:to_s).join("/")
        end

        # { key => KIF::SettingsScreen::Row }: every on/off and choice
        # setting and every button there is now, in KIF Settings' order
        def index
          return @index if @index
          @index = {}
          return @index unless available?
          screen = ::KifSettingsScreen.allocate
          screen.instance_variable_set(:@inloadscreen, false)
          screen.send(:rebuild)
          @screen = screen               # its PIF scenes own their options' procs
          (screen.instance_variable_get(:@rows) || {}).each do |sid, rows|
            next if [:modules, :mods, :presets].include?(sid)
            rows.each { |r| @index[key_for(r)] ||= r if fits_row?(r) }
          end
          return @index
        rescue StandardError => e
          Reloaded::Log.exception("The Overworld Menu couldn't read KIF Settings", e, :overworld_menu)
          return @index = {}
        end

        # Read the settings again next time (KIF Settings closed).
        def forget
          @index = nil
          @entries = nil
          @screen = nil
        end

        def row(key)
          return index[key.to_s]
        end

        # The key of the first setting with this name, or nil.
        def key_named(name)
          return index.keys.find { |k| k.split("/").last == name }
        end

        # An entry for the menu (Reloaded::OverworldMenu::Entry), or nil
        # when the setting isn't there now.
        def entry(key)
          key = key.to_s
          @entries ||= {}
          return @entries[key] if @entries.key?(key)
          r = row(key)
          return @entries[key] = nil unless r
          on = _INTL("On")
          off = _INTL("Off")
          e = Reloaded::OverworldMenu::Entry.new(key, r.label.to_s.strip, :setting, nil, 100, nil,
                proc { Reloaded::OverworldMenu::SettingRows.shown_now?(key) },
                proc { Reloaded::OverworldMenu::SettingRows.lock_reason(key) || true },
                nil, description(r))
          if button?(r.opt)
            e.handler = proc { |menu| menu.press_setting(e); nil }
            return @entries[key] = e
          end
          if number?(r.opt)
            start = r.opt.optstart.to_i
            step = r.opt.instance_variable_get(:@optinterval) || 1
            e.range = [start, r.opt.optend.to_i, step, unit(r.opt)]
            e.get = proc { Reloaded::OverworldMenu::SettingRows.value(key) + start }
            e.set = proc { |v| Reloaded::OverworldMenu::SettingRows.set(key, v - start) }
            return @entries[key] = e
          end
          vals = r.opt.values.map(&:to_s)
          if vals.length == 2 && vals.sort == [off, on].sort
            e.get = proc { vals[Reloaded::OverworldMenu::SettingRows.value(key)] == on }
            e.set = proc { |v| Reloaded::OverworldMenu::SettingRows.set(key, vals.index(v ? on : off)) }
          else
            e.values = vals
            e.get = proc { Reloaded::OverworldMenu::SettingRows.value(key) }
            e.set = proc { |i| Reloaded::OverworldMenu::SettingRows.set(key, i) }
            e.explain = proc { |i| Reloaded::OverworldMenu::SettingRows.choice_words(key, i) }
          end
          return @entries[key] = e
        end

        # There now, and a Kanto Reloaded setting's page showing (DEBUG
        # Off hides the Timing Profiler's and Developer Tools')
        def shown_now?(key)
          r = row(key)
          return false unless r
          return true unless defined?(Reloaded::KIFBridge) && Reloaded::KIFBridge.bridge_option?(r.opt)
          d = Reloaded::Settings.definition(r.opt.kr_key)
          return d && Reloaded::Settings.visible?(d[:key]) && Reloaded::Settings.page_visible?(d[:page]) ? true : false
        rescue StandardError
          return false
        end

        # A Kanto Reloaded number's unit ("%"), or ""
        def unit(opt)
          return "" unless defined?(Reloaded::KIFBridge) && Reloaded::KIFBridge.bridge_option?(opt)
          d = Reloaded::Settings.definition(opt.kr_key)
          return d ? d[:unit].to_s : ""
        end

        # The choices a mod has locked (KIF 0.21.52's Experiences), by index
        def locked_choices(key)
          r = row(key)
          return [] unless r && defined?(Reloaded::KIFDropdowns)
          return (Reloaded::KIFDropdowns.send(:locks, r.opt).keys rescue [])
        end

        def value(key)
          r = row(key)
          return r ? (r.opt.get rescue 0).to_i : 0
        end

        # Sets it as KIF Settings does, and what KIF Settings does on closing
        # after it (a new game mode reshuffles the trainers).
        def set(key, i)
          r = row(key)
          return false unless r && i
          mode = defined?(getTrainersDataMode) ? (getTrainersDataMode rescue nil) : nil
          r.opt.set(i)
          @screen.instance_variable_set(:@mode0, mode)
          @screen.send(:close_effects)
          return true
        rescue StandardError => e
          Reloaded::Log.exception("The Overworld Menu couldn't set #{key}", e, :overworld_menu)
          return false
        end

        # A button, pressed as KIF Settings presses it, and what KIF
        # Settings does after it (the caller hides its own screen).
        def press(key)
          r = row(key)
          return false unless r && button?(r.opt)
          mode = defined?(getTrainersDataMode) ? (getTrainersDataMode rescue nil) : nil
          r.opt.trigger
          @screen.instance_variable_set(:@mode0, mode)
          @screen.send(:close_effects)
          return true
        rescue StandardError => e
          Reloaded::Log.exception("The Overworld Menu couldn't press #{key}", e, :overworld_menu)
          return false
        end

        # "Set by <mod> while that mod is On." or nil
        def lock_reason(key)
          r = row(key)
          by = r && @screen ? @screen.send(:locked_by, r.opt) : nil
          return by ? _INTL("Set by {1} while that mod is On.", by) : nil
        rescue StandardError
          return nil
        end

        # What one choice of a setting means (KIF Settings' words).
        def choice_words(key, i)
          r = row(key)
          return "" unless r
          general = description(r)
          return Reloaded::KIFDropdowns.send(:explain, r.opt, i, general).to_s if defined?(Reloaded::KIFDropdowns)
          return general
        rescue StandardError
          return general.to_s
        end

        def description(r)
          return @screen ? @screen.send(:desc_of, r.opt).to_s : ""
        rescue StandardError
          return ""
        end
      end

      # KIF Settings closed: a module or a mod switched there can change
      # which settings there are.
      module SettingsClosed
        def main(*args)
          return super
        ensure
          Reloaded::OverworldMenu::SettingRows.forget
        end
      end
    end
  end
end
