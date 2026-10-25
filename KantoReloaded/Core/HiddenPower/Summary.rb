# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Hidden Power (Summary)
#==============================================================================
# Out of battle, Hidden Power shows the Pokémon's own type and power
# wherever the move shows (his picks 2026-10-25: Q15 Wherever the Move
# Shows; Q8 the power stays PIF's 30 to 70 from the IVs). Always on with
# Kanto Reloaded.
#
#   PIF's Summary   the Moves page, a move's details (its power) and the
#                   move-learn page (drawPageFour, drawPageFourSelecting,
#                   drawSelectedMove): while a page draws, the move data it
#                   reads shows Hidden Power as the Pokémon on the page has
#                   it (Battle.showing). The Pokémon is read as each move is
#                   drawn, so Ghostly Possession's possessed look (it shows
#                   the fusion while the page draws) shows the fusion's
#   KR's screens    the Party Screen's teaching panel and move bars, the TM
#                   Vault, the PC's Compare: through type_for / power_for
#
# An Egg's Hidden Power isn't told: its moves show the move's own type.
#
#   Reloaded::HiddenPower::Summary.type_for(pkmn, move)   a move's type for
#   Reloaded::HiddenPower::Summary.power_for(pkmn, move)  this Pokémon (a
#       move, its data or its id), the move's own when it can't be told
#==============================================================================

module Reloaded
  module HiddenPower
    module Summary
      PAGES = [[:drawPageFour, :hidden_power_summary_moves], [:drawPageFourSelecting, :hidden_power_summary_learn],
               [:drawSelectedMove, :hidden_power_summary_details]].freeze

      class << self
        #----------------------------------------------------------------------
        # Kanto Reloaded's own screens
        #----------------------------------------------------------------------
        def type_for(pkmn, move)
          return Reloaded::HiddenPower.move_type(own(pkmn), move)
        rescue StandardError
          return plain(move).type
        end

        def power_for(pkmn, move)
          return Reloaded::HiddenPower.move_power(own(pkmn), move)
        rescue StandardError
          return plain(move).base_damage
        end

        # Whose Hidden Power shows: not an Egg's
        def own(pkmn)
          return nil if pkmn.nil? || (pkmn.respond_to?(:egg?) && pkmn.egg?)
          return pkmn
        end

        def plain(move)
          return move.is_a?(Symbol) || move.is_a?(String) ? ::GameData::Move.get(move) : move
        end

        #----------------------------------------------------------------------
        # PIF's Summary
        #----------------------------------------------------------------------
        # Runs a page's drawing with Hidden Power as the scene's Pokémon has it
        def drawing(scene)
          return Reloaded::HiddenPower::Battle.showing(proc { |data| shown_for(scene, data) }) { yield }
        end

        # Hidden Power's data as the Pokémon on the page has it (its type and
        # power), else nil
        def shown_for(scene, data)
          return nil unless Reloaded::HiddenPower.hidden_power_move?(data.id)
          pkmn = own(scene.instance_variable_get(:@pokemon))
          return nil unless pkmn
          type = Reloaded::HiddenPower.type_of(pkmn)
          return Reloaded::HiddenPower::Battle.shown(data, type, Reloaded::HiddenPower.move_power(pkmn, data))
        end

        def install
          return true unless defined?(::PokemonSummary_Scene)
          PAGES.each do |name, id|
            next unless ::PokemonSummary_Scene.method_defined?(name) || ::PokemonSummary_Scene.private_method_defined?(name)
            Reloaded::Hooks.around(nil, ::PokemonSummary_Scene, name, :id => id) do |original, *args|
              Reloaded::HiddenPower::Summary.drawing(original.receiver) { original.call(*args) }
            end
          end
          return true
        end
      end
    end
  end
end
