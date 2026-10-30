#==============================================================================
# Fix: EBDX's Fight menu covers the picked move
#==============================================================================
# EBDX lifts the picked move 20 px to show its type and PP (660_EBDX/
# 007_EBDX_UIWidgets.rb, FightWindowEBDX#update), but every move button has
# the same z (102, #generateButtons), so the button made after it (the one
# below) covers its bottom: the type and PP are cut off. The picked button
# goes on top (104) and the effectiveness words over it (105), set only when
# the pick changes. Always on (his pick, 2026-10-29), Battle Scene or not.
#==============================================================================

module Reloaded
  module Fixes
    module EBDXMoveLayers
      def update
        super
        return if @kr_layer == @index || @button.nil? || @button.empty?
        @kr_layer = @index
        @button.each do |key, spr|
          next if spr.nil? || spr.disposed?
          spr.z = key.to_i == @index ? 104 : 102
        end
        @typeInd.z = 105 if @typeInd && !@typeInd.disposed?
      end

      def generateButtons(*args)
        @kr_layer = nil
        super
      end
    end
  end
end

Reloaded::Fixes.register(:ebdx_move_layers, "EBDX's Fight menu: The move below covered the picked move's type and PP") do
  next false unless defined?(::FightWindowEBDX) && ::FightWindowEBDX.method_defined?(:update) &&
                    ::FightWindowEBDX.method_defined?(:generateButtons)
  Reloaded::Hooks.prepend(nil, ::FightWindowEBDX, Reloaded::Fixes::EBDXMoveLayers, :id => :fix_ebdx_move_layers)
end
