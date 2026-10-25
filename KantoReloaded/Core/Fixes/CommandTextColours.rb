#==============================================================================
# Fix: formatted command rows take their window's text colours
#==============================================================================
# PIF's Window_AdvancedCommandPokemon draws a plain row in the window's text
# colours (white on a dark frame, dark grey on a light one), but a row with
# formatting, like the pause menu's icon rows ("<icon=...>  Bag"), in the
# bitmap's default font colour: always white, so it can't be read on a light
# frame (Theme Mode Light or Frost, the light RLD frames). Each formatted row
# now starts with the window's colours (PIF's own shadowctag); colour tags in
# the row itself still win.
#==============================================================================

module Reloaded
  module Fixes
    module CommandTextColours
      def drawItem(index, count, rect)
        cmd = @commands ? @commands[index] : nil
        return super unless cmd.is_a?(String) && self.baseColor && self.shadowColor
        return super if toUnformattedText(cmd).gsub(/\n/, "") == cmd     # plain: drawn in them already
        @commands[index] = shadowctag(self.baseColor, self.shadowColor) + cmd
        begin
          return super
        ensure
          @commands[index] = cmd
        end
      end
    end
  end
end

Reloaded::Fixes.register(:command_text_colours,
                         "Formatted command rows (the pause menu's icon rows) take their window's text colors") do
  next false unless defined?(::Window_AdvancedCommandPokemon) && ::Window_AdvancedCommandPokemon.method_defined?(:drawItem)
  next false unless Object.private_method_defined?(:shadowctag) && Object.private_method_defined?(:toUnformattedText)
  Reloaded::Hooks.prepend(nil, ::Window_AdvancedCommandPokemon, Reloaded::Fixes::CommandTextColours,
                          :id => :fix_command_text_colours)
end
