#==============================================================================
# Kanto Reloaded: extra actions (controls of our own, unbound at first)
#==============================================================================
# Shortcuts the game has no button for. They start with no key or button,
# so nothing changes until the player gives them one in Controls:
#
#   Run Toggle   flips walking and running (PIF's Default Movement setting)
#   Bicycle      gets on or off the Bicycle (or the Race Bike)
#   Poké Radar   uses the Poké Radar
#
# They work on the map only, when the player could open the Ready Menu (no
# message, no event running, the menu not shut by a cutscene). A press while
# the player is walking waits until they stop, as the game's own buttons do.
# The items go through the game's own field use, with its checks and
# messages ("Can't use that here."); without the item a press just buzzes.
#==============================================================================

module Reloaded
  module Controls
    module ExtraActions
      # [id, name, description]
      ACTIONS = [
        [:run_toggle, "Run Toggle", "Switches between walking and running with one press (the Default Movement setting)."],
        [:bicycle,    "Bicycle",    "Gets on or off your Bicycle straight away."],
        [:poke_radar, "Poké Radar", "Uses the Poké Radar straight away."]
      ].freeze
      BIKES = [:BICYCLE, :RACEBIKE, :MACHBIKE, :ACROBIKE].freeze

      # Scene_Map: after the game's own update, the extra actions.
      module MapUpdate
        def update
          super
          Reloaded::Controls::ExtraActions.on_map(self) if Reloaded::Controls.active?
        end
      end

      class << self
        def boot
          ACTIONS.each_with_index do |(id, name, desc), i|
            Controls.register(id, :name => name, :area => :overworld, :group => "Shortcuts",
                                  :description => desc, :priority => 200 + i)
          end
          Reloaded::Hooks.prepend(nil, "Scene_Map", MapUpdate, :id => :controls_extra_actions)
          Reloaded::Hooks.needs(:field, :runstyle, :id => :controls_run_toggle)     # PIF's Default Movement
          return true
        end

        # Once per map update: a press is kept until the player can act.
        def on_map(scene)
          return unless $scene == scene
          ACTIONS.each { |id, _, _| @pending = id if Controls.trigger?(id) }
          return unless @pending && can_act?
          id = @pending
          @pending = nil
          run(id)
        end

        def run(id)
          case id
          when :run_toggle then toggle_run
          when :bicycle    then use_item(BIKES.find { |item| has_item?(item) })
          when :poke_radar then use_item(has_item?(:POKERADAR) ? :POKERADAR : nil)
          end
        end

        private

        def can_act?
          return false if $game_temp && $game_temp.respond_to?(:message_window_showing) && $game_temp.message_window_showing
          return false if defined?(pbMapInterpreterRunning?) && pbMapInterpreterRunning?
          return false if $game_player && $game_player.moving?
          return false if $game_system && $game_system.respond_to?(:menu_disabled) && $game_system.menu_disabled
          return true
        end

        def toggle_run
          return unless $PokemonSystem && $PokemonSystem.respond_to?(:runstyle=)
          $PokemonSystem.runstyle = $PokemonSystem.runstyle.to_i == 1 ? 0 : 1
          pbPlayCursorSE if defined?(pbPlayCursorSE)
        end

        def has_item?(item)
          return false unless $PokemonBag && defined?(GameData::Item) && GameData::Item.exists?(item)
          return $PokemonBag.pbHasItem?(item)
        end

        def use_item(item)
          return (pbPlayBuzzerSE if defined?(pbPlayBuzzerSE)) unless item
          $game_player.straighten if $game_player && $game_player.respond_to?(:straighten)
          pbUseKeyItemInField(item)
        end
      end
    end
  end
end
