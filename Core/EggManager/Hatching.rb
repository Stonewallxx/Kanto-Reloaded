# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Egg Manager's hatching
#==============================================================================
# Takes over KIF's Hatch to PC Prompt (990_KIF/F-UI-08_HatchToPC, his pick
# Q11): after a Pokémon hatches in the party (the scene and its nickname
# done), Hatched Pokémon decides:
#
#   Stay        it stays in the party
#   Ask         the Ask Card (UI/EggPopups.rb, his pick): Keep in Party
#               (the default, and B) or Send to PC, where it would go;
#               every box full: Send to PC dimmed, "Every Box Is Full"
#   Send to PC  it goes by itself, and a toast says which box
#
# As KIF's did: never when it's the only Pokémon in the party that isn't an
# Egg, and it stays when every box is full. One that hatched in a box (an
# incubator's) stays there. Either way its incubator is freed.
#
# Also here: the Hatch Speed Helper's question (Flame Body or Magma Armor
# in the party, and who in the boxes has it).
#==============================================================================

module Reloaded
  module EggManager
    module Hatching
      HELPERS = [:FLAMEBODY, :MAGMAARMOR].freeze

      class << self
        def install
          h = Reloaded::Hooks
          if Object.private_method_defined?(:pbHatch) || Object.method_defined?(:pbHatch)
            h.around(FEATURE, Object, :pbHatch, :id => :egg_manager_hatch) do |original, pokemon, *args|
              ret = original.call(pokemon, *args)
              Reloaded::EggManager::Hatching.after(pokemon)
              ret
            end
          end
          # the game's messages kept quiet while the Egg Manager says it its
          # own way (EggManager.quietly)
          if Object.private_method_defined?(:pbMessage) || Object.method_defined?(:pbMessage)
            h.around(FEATURE, Object, :pbMessage, :id => :egg_manager_quiet) do |original, *args, &blk|
              next 0 if Reloaded::EggManager.quiet?
              original.call(*args, &blk)
            end
          end
          return true
        end

        # After a Pokémon hatched: its incubator freed; in the party, Hatched
        # Pokémon decides
        def after(pokemon)
          return if pokemon.nil? || pokemon.egg?
          Incubators.release(pokemon)
          party = Eggs.party
          idx = party.index { |p| p.equal?(pokemon) }
          return unless idx
          return if party.each_with_index.count { |p, i| i != idx && !p.egg? } == 0
          case EggManager.hatched
          when :pc
            send_to_pc(pokemon, true)
          when :ask
            choice = defined?(Reloaded::HatchAsk) ? Reloaded::HatchAsk.ask(pokemon) : :keep
            send_to_pc(pokemon, true) if choice == :send
          end
        rescue StandardError => e
          Reloaded::Log.exception("The Egg Manager couldn't place a hatched Pokémon", e, :egg_manager)
        end

        # To the PC as the game stores a caught one (the current box, else
        # the first with room): its box, or nil (every box full)
        def send_to_pc(pokemon, notify = false)
          box = $PokemonStorage.pbStoreCaught(pokemon)
          return nil if box.nil? || box < 0
          i = $Trainer.party.index { |p| p.equal?(pokemon) }
          $Trainer.party.delete_at(i) if i
          toast(pokemon, box) if notify
          return box
        end

        def toast(pokemon, box)
          return unless defined?(Reloaded::Toast)
          icon = Reloaded::PartyIcons.species_bitmap(pokemon.species) rescue nil
          Reloaded::Toast.show(_INTL("{1} was sent to the PC.", pokemon.name), :icon => icon,
                               :pill => [_INTL("BOX {1}", box + 1), :gold])
        end

        #----------------------------------------------------------------------
        # The Hatch Speed Helper
        #----------------------------------------------------------------------
        def helper?(p)
          return false if p.nil? || p.egg?
          return HELPERS.any? { |a| p.hasAbility?(a) }
        rescue StandardError
          return false
        end

        # One in the party (as the game checks it every step)
        def helper_in_party?
          return false unless $Trainer
          list = $Trainer.respond_to?(:pokemon_party) ? $Trainer.pokemon_party : Eggs.party
          return list.any? { |p| helper?(p) }
        end

        # The first in the boxes: an Entry, or nil (the screen asks once)
        def helper_in_pc
          st = $PokemonStorage
          found = nil
          Eggs.each_box do |b, _box|
            break if found
            (0...st.maxPokemon(b)).each do |k|
              p = st[b, k]
              next unless helper?(p)
              found = Entry.new(p, b, k)
              break
            end
          end
          return found
        rescue StandardError
          return nil
        end
      end
    end
  end
end
