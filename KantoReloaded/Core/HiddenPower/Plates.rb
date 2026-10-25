# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Hidden Power's plates
#==============================================================================
# The 17 plates set the exact type of a Pokémon's Hidden Power (his pick,
# Q11: Design 1, and the plate is used up). Used from the Bag on any Pokémon
# but an Egg; Unown's stays neutral (its notice), and one that has the type
# already doesn't take the plate. Held, a plate still powers up its type.
#
#   Data      a Data Patch makes each one usable on a Pokémon and used up
#             (field_use 1), with a description that says so
#   The Bag   the plate's details show the party grid (his pick, Party
#             Grid): each Pokémon's type now in its colour, "Already Ice"
#   After     Use Several's notice: the type it became, the plate used up
#
# The new items made for Hidden Power that replace the plates later are a
# step of their own.
#==============================================================================

module Reloaded
  module HiddenPower
    module Plates
      TYPES = { :FISTPLATE => :FIGHTING, :SKYPLATE => :FLYING, :TOXICPLATE => :POISON, :EARTHPLATE => :GROUND,
                :STONEPLATE => :ROCK, :INSECTPLATE => :BUG, :SPOOKYPLATE => :GHOST, :IRONPLATE => :STEEL,
                :FLAMEPLATE => :FIRE, :SPLASHPLATE => :WATER, :MEADOWPLATE => :GRASS, :ZAPPLATE => :ELECTRIC,
                :MINDPLATE => :PSYCHIC, :ICICLEPLATE => :ICE, :DRACOPLATE => :DRAGON, :DREADPLATE => :DARK,
                :PIXIEPLATE => :FAIRY }.freeze
      FIELD_USE = 1                 # used on a Pokémon, then gone

      class << self
        def install
          patch_items
          register_handlers
        end

        def item_id(item)
          id = item.respond_to?(:id) ? item.id : item
          return id.is_a?(String) ? id.to_sym : id
        end

        # The type a plate sets, or nil for any other item
        def type_of(item)
          return TYPES[item_id(item)]
        end

        def description(type)
          name = (GameData::Type.get(type).name rescue type.to_s.capitalize)
          return _INTL("Makes a Pokémon's Hidden Power {1}-type, and it's used up. Held, it powers up {1}-type moves.", name)
        end

        def patch_items
          return unless defined?(Reloaded::DataPatches) && Reloaded::DataPatches.respond_to?(:register_internal_patch)
          TYPES.each do |item, type|
            Reloaded::DataPatches.register_internal_patch("items", item.to_s,
              { "field_use" => FIELD_USE, "description" => description(type) }, operation: "edit", owner: :hidden_power)
          end
        end

        def register_handlers
          return unless defined?(::ItemHandlers::UseOnPokemon)
          TYPES.each_key do |item|
            ::ItemHandlers::UseOnPokemon.add(item, proc { |it, pkmn, scene| Reloaded::HiddenPower::Plates.use(it, pkmn, scene) })
          end
        end

        # What it would do for a Pokémon: :egg, :unown, :already or :change
        def effect(item, pkmn)
          to = type_of(item)
          return :egg if pkmn.respond_to?(:egg?) && pkmn.egg?
          return :unown if Reloaded::HiddenPower.unown?(pkmn)
          return :already if Reloaded::HiddenPower.type_of(pkmn) == to
          return :change
        end

        # The handler: true when the plate was used (then the Bag takes it)
        def use(item, pkmn, scene)
          case effect(item, pkmn)
          when :egg, :already
            say(scene, _INTL("It won't have any effect."))
            return false
          when :unown
            Reloaded::HiddenPowerScreen.unown(pkmn) if defined?(Reloaded::HiddenPowerScreen)
            return false
          end
          to = type_of(item)
          from = Reloaded::HiddenPower.type_of(pkmn)
          Reloaded::HiddenPower.set(pkmn, to, :plate)
          if defined?(Reloaded::HiddenPowerScreen)
            Reloaded::HiddenPowerScreen.plate_notice(pkmn, from, to, item_id(item))
          else
            say(scene, _INTL("{1}'s Hidden Power is now {2}-type!", pkmn.name, Reloaded::HiddenPower.type_name(to)))
          end
          scene.pbRefresh if scene.respond_to?(:pbRefresh)
          return true
        end

        def say(scene, text)
          if scene.respond_to?(:pbDisplay)
            scene.pbDisplay(text)
          else
            pbMessage(text)
          end
        end
      end
    end
  end
end
