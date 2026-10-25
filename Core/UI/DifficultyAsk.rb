# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Difficulty's question when lowering
#==============================================================================
# His pick (Design 1, 2026-10-25): a Header Plate popup over the settings
# screen, only when a change would lower Shown As (Difficulty.rb):
#
#   Lower to Easy?
#   Easy's changes start now. You can raise it again any time, but your
#   card keeps the lowest you've used.
#   Your Card Shows: Normal   After: Easy        (each in its colour)
#                 [ Lower ]  [ Keep Hard ]       (Keep, the default)
#
# Off the settings screen (KIF's own, the Overworld Menu) it's the game's
# own yes/no question.
#==============================================================================

module Reloaded
  module DifficultyAsk
    class << self
      # true: lower to index
      def lower(index)
        d = Reloaded::Difficulty
        name = d.shown_name(index)
        scene = defined?(Reloaded::SettingsScreen) ? Reloaded::SettingsScreen.showing : nil
        unless scene && scene.respond_to?(:overlay)
          return true unless defined?(pbConfirmMessage)
          return pbConfirmMessage(_INTL("Lower to {1}? Your card keeps the lowest you've used, so it will show {1} from now on.", name))
        end
        c = scene.palette
        segments = [[_INTL("Your Card Shows: "), c[:dim]], [d.shown_name, c[d.tone], true],
                    [_INTL("   After: "), c[:dim]], [name, c[d.tone(index)], true]]
        choice = Reloaded::Dialogs.ask(scene, _INTL("Lower to {1}?", name),
                                       _INTL("{1}'s changes start now. You can raise it again any time, but your card keeps the lowest you've used.", name),
                                       segments, [_INTL("Lower"), _INTL("Keep {1}", d.shown_name(d.level))], 1)
        return choice == 0
      end
    end
  end
end
