# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Fresh-Start Mochi
#==============================================================================
# His pick (2026-10-25, with Keep Fused EVs): a way to clear a Pokémon's
# EVs. The mainline item: all six EVs back to 0, used up, used from the Bag
# on any Pokémon but an Egg. It asks first (the Mochi's question: Reset or
# Keep, Keep first). $10,000 at the Celadon Department Store's vitamin
# counter (Map433, beside HP Up and Protein), while Critical EV Gain is on.
#
# The item is Kanto Reloaded's own (an internal Data Patch), its icon in
# Graphics/Items. Its description is made at boot, before the game's data
# loads: nothing here reads GameData then.
#==============================================================================

module Reloaded
  module CriticalEVGain
    module Mochi
      ID = :FRESHSTARTMOCHI
      PRICE = 10_000
      SHOP_MAP = 433                        # the Celadon Department Store's vitamin floor
      SHOP_WITH = :PROTEIN                  # the counter that sells the vitamins

      class << self
        def install
          register_item
          register_handler
          install_shop
        end

        def register_item
          return unless defined?(Reloaded::DataPatches) && Reloaded::DataPatches.respond_to?(:register_internal_patch)
          Reloaded::DataPatches.register_internal_patch("items", ID.to_s,
            { "name" => "Fresh-Start Mochi", "name_plural" => "Fresh-Start Mochi", "pocket" => 2, "price" => PRICE,
              "description" => "A soft rice cake that puts a Pokémon's training back at the start: All six of its EVs go back to 0.",
              "field_use" => 1, "battle_use" => 0, "type" => 0 }, owner: :critical_ev_gain)
        end

        def register_handler
          return unless defined?(::ItemHandlers::UseOnPokemon)
          ::ItemHandlers::UseOnPokemon.add(ID, proc { |item, pkmn, scene| Reloaded::CriticalEVGain::Mochi.use(item, pkmn, scene) })
        end

        def total(pkmn)
          return Reloaded::CriticalEVGain::STATS.sum { |s| pkmn.ev[s].to_i }
        end

        # The handler: true when it reset the EVs (then the Bag takes it)
        def use(item, pkmn, scene)
          if (pkmn.respond_to?(:egg?) && pkmn.egg?) || total(pkmn) == 0
            say(scene, _INTL("It won't have any effect."))
            return false
          end
          name = (GameData::Item.get(item).name rescue "Fresh-Start Mochi")
          ok = if defined?(Reloaded::CriticalEVGainScreen)
                 Reloaded::CriticalEVGainScreen.mochi_ask(pkmn, name)
               else
                 pbConfirmMessage(_INTL("Reset {1}'s EVs?", pkmn.name))
               end
          return false unless ok
          Reloaded::CriticalEVGain::STATS.each { |s| pkmn.ev[s] = 0 }
          pkmn.calc_stats if pkmn.respond_to?(:calc_stats)
          scene.pbRefresh if scene.respond_to?(:pbRefresh)
          say(scene, _INTL("{1}'s EVs are back to 0.", pkmn.name))
          return true
        end

        def say(scene, text)
          return scene.pbDisplay(text) if scene.respond_to?(:pbDisplay)
          pbMessage(text)
        end

        # The vitamin counter's stock gets the Mochi
        def install_shop
          return unless Object.private_method_defined?(:pbPokemonMart) || Object.method_defined?(:pbPokemonMart)
          Reloaded::Hooks.around(Reloaded::CriticalEVGain::FEATURE, Object, :pbPokemonMart, :id => :cev_mochi_shop) do |original, *args|
            stock = args[0]
            if Reloaded::CriticalEVGain::Mochi.sells_here?(stock)
              args = args.dup
              args[0] = stock + [Reloaded::CriticalEVGain::Mochi::ID]
            end
            original.call(*args)
          end
        end

        def sells_here?(stock)
          return false unless stock.is_a?(Array) && $game_map && $game_map.map_id == SHOP_MAP
          return stock.include?(SHOP_WITH) && !stock.include?(ID)
        end
      end
    end
  end
end
