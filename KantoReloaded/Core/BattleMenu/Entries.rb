# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Battle Menu's own entries
#==============================================================================
# Main's entries (his picks, 2026-10-28): Battle Info and the Turn Log.
# Quick Throw joins them with Quick Throw and Catch Chances (Wave 6) and
# becomes the default Favorite then.
#==============================================================================

module Reloaded
  module BattleMenu
    module Entries
      module_function

      def register_all
        bm = Reloaded::BattleMenu
        bm.register(:battle_info, :owner => OWNER, :name => "Battle Info", :icon => :SCOPELENS, :priority => 10,
          :description => "Stats and effects for every Pokémon, your matchups and the field.",
          :handler => proc { |ctx| Reloaded::BattleMenu.open_info(ctx) })
        bm.register(:turn_log, :owner => OWNER, :name => "Turn Log", :icon => :TOWNMAP, :priority => 30,
          :description => "What happened each turn: Moves, damage, status changes and fainting.",
          :status => proc { |ctx| [_INTL("Turn {1}", ctx.battle.turnCount.to_i + 1), :blue] },
          :handler => proc { |ctx| Reloaded::BattleMenu.open_info(ctx, :log) })
      end
    end
  end
end
