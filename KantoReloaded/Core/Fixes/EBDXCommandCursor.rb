#==============================================================================
# Fix: EBDX's battle menu cursor after Battle Info's INFO button
#==============================================================================
# KIF's EBDX cursor memory (660_EBDX/021_EBDX_CursorMemory.rb) keeps the
# picked command's value as the cursor's position for the next turn. Battle
# Info (ZZ_Cody/C-BATTLE-03) adds INFO as a fifth command with the value 50,
# so after the screen closes the cursor sat on no command, and choosing one
# crashed the battle (undefined method `>=' for nil). A position that isn't
# there now goes to the command with that value (INFO again), else the first.
#==============================================================================

module Reloaded
  module Fixes
    module EBDXCommandCursor
      def index=(value)
        list = @indexes
        if value.is_a?(Integer) && list.is_a?(Array) && !list.empty? &&
           (value < 0 || value >= list.length)
          value = list.index(value) || 0
        end
        super(value)
      end
    end
  end
end

Reloaded::Fixes.register(:ebdx_command_cursor,
                         "EBDX's battle menu cursor after Battle Info's INFO button (choosing a command crashed)") do
  next false unless defined?(::CommandWindowEBDX) && ::CommandWindowEBDX.method_defined?(:index=)
  Reloaded::Hooks.prepend(nil, ::CommandWindowEBDX, Reloaded::Fixes::EBDXCommandCursor,
                          :id => :fix_ebdx_command_cursor)
end
