#==============================================================================
# Kanto Reloaded: Autosave as rows in KIF Settings (no separate window)
#==============================================================================
# PIF's Autosave setting opened its own "Autosave settings" window the moment
# it was switched On (When healing, When catching Pokémon, After trainer
# battles, Every x steps, then Confirm). In KIF Settings (both screens) it is
# now a heading of its own in Game, right after Saves:
#
#   AUTOSAVE
#     Autosave               On / Off (no window opens)
#     When Healing           while Autosave is On
#     When Catching Pokémon
#     After Trainer Battles
#     Every X Steps
#     Steps Between Saves    while Every X Steps is On (a number, 20 and up)
#
# The rows read and write the same switches and variables as PIF's window,
# keep PIF's On/Off order, and show only in a save (as PIF's do). PIF's own
# Autosave row is replaced by this one.
#==============================================================================

module Reloaded
  module AutosaveRows
    HEADING = "Autosave"
    NAMES = ["Autosave", "When Healing", "When Catching Pokémon", "After Trainer Battles", "Every X Steps",
             "Steps Between Saves"].freeze

    class << self
      def boot
        return true unless defined?(::KIF::SettingsScreen::SECTIONS) && defined?(::AUTOSAVE_ENABLED_SWITCH)
        place_heading
        Reloaded::Hooks.around(nil, ::KIF::SettingsScreen.singleton_class, :pif_items, :id => :autosave_rows) do |original, *args|
          items, extra, root = original.call(*args)
          [Reloaded::AutosaveRows.rows_into(items), extra, root]
        end
        describe
        return true
      end

      # PIF's items with its Autosave row swapped for these (in a save).
      def rows_into(items)
        items = items.reject { |it| it[:name] == "Autosave" }
        return items unless $game_switches && $game_variables
        return items + options.map { |name, opt| { :opt => opt, :scope => nil, :name => name, :mod => nil, :children => [] } }
      end

      # [[name, option], ...]: Autosave, and while it's On, what it saves on.
      def options
        on_off = [_INTL("On"), _INTL("Off")]
        sw = $game_switches
        out = [["Autosave", EnumOption.new(_INTL("Autosave"), on_off,
                                           proc { sw[::AUTOSAVE_ENABLED_SWITCH] ? 0 : 1 },
                                           proc { |v| sw[::AUTOSAVE_ENABLED_SWITCH] = v == 0 })]]
        return out unless sw[::AUTOSAVE_ENABLED_SWITCH]
        out << ["When Healing", EnumOption.new(_INTL("When Healing"), on_off,
                                               proc { $game_variables[::AUTOSAVE_HEALING_VAR].to_i == 0 ? 0 : 1 },
                                               proc { |v| $game_variables[::AUTOSAVE_HEALING_VAR] = v },
                                               _INTL("Saves when you heal at a Pokémon Center."))]
        out << switch_row("When Catching Pokémon", ::AUTOSAVE_CATCH_SWITCH, _INTL("Saves each time you catch a Pokémon."))
        out << switch_row("After Trainer Battles", ::AUTOSAVE_WIN_SWITCH, _INTL("Saves after each trainer battle."))
        steps = EnumOption.new(_INTL("Every X Steps"), on_off,
                               proc { sw[::AUTOSAVE_STEPS_SWITCH] ? 0 : 1 },
                               proc { |v|
                                 sw[::AUTOSAVE_STEPS_SWITCH] = v == 0
                                 $game_variables[::AUTOSAVE_STEPS_VAR] = ::DEFAULT_AUTOSAVE_STEPS if v == 0 && $game_variables[::AUTOSAVE_STEPS_VAR].to_i <= 0
                               },
                               _INTL("Saves every so many steps (Steps Between Saves)."))
        out << ["Every X Steps", steps]
        return out unless sw[::AUTOSAVE_STEPS_SWITCH]
        out << ["Steps Between Saves", NumberOption.new(_INTL("Steps Between Saves"), 20, 99_999,
                                                        proc { [$game_variables[::AUTOSAVE_STEPS_VAR].to_i, 20].max - 20 },
                                                        proc { |v| $game_variables[::AUTOSAVE_STEPS_VAR] = v + 20 },
                                                        _INTL("How many steps between saves. Low numbers can slow the game down."))]
        return out
      end

      private

      def switch_row(name, switch, desc)
        return [name, EnumOption.new(_INTL(name), [_INTL("On"), _INTL("Off")],
                                     proc { $game_switches[switch] ? 0 : 1 },
                                     proc { |v| $game_switches[switch] = v == 0 }, desc)]
      end

      # Game > Autosave, right after Saves (and Autosave out of Saves).
      def place_heading
        game = ::KIF::SettingsScreen::SECTIONS.find { |s| s[0] == :game }
        return unless game && game[3].is_a?(Array)
        groups = game[3]
        return if groups.any? { |heading, _| heading == HEADING }
        saves = groups.index { |heading, _| heading == "Saves" }
        groups[saves][1] = groups[saves][1] - ["Autosave"] if saves
        groups.insert(saves ? saves + 1 : groups.length, [HEADING, NAMES.dup])
      end

      # KIF's text for Autosave said it saves when healing; now it's the
      # switch for the moments below it.
      def describe
        texts = defined?(::KIF::SettingsScreen::DESCRIPTIONS) ? ::KIF::SettingsScreen::DESCRIPTIONS : nil
        return unless texts.is_a?(Hash) && !texts.frozen?
        texts["Autosave"] = ["The game saves by itself at the moments set below.", "No autosave."]
      end
    end
  end
end
