#==============================================================================
# Kanto Reloaded: Keep Aside, and back again
#==============================================================================
# What the Save Checker kept aside (Fix.content, :keep) waits in Kanto
# Reloaded's part of the save (section :save_check, "kept"). Each time a
# save loads, whatever the game has again goes back:
#
#   a Pokémon    into the PC (the first free box slot)
#   an item      into the Bag
#   a move       onto its Pokémon (found by its personal ID), if it has room
#   an ability   onto its Pokémon
#
# The rest keeps waiting. Once the map shows, a message says what came back.
#==============================================================================

module Reloaded
  module SaveCheck
    module KeptAside
      class << self
        def install
          Reloaded::Events.on(:save_loaded, :save_check_kept_aside, 60) { give_back }
          if defined?(::Events) && ::Events.respond_to?(:onMapUpdate) && !::Events.instance_variable_get(:@kr_kept_aside)
            ::Events.instance_variable_set(:@kr_kept_aside, true)
            ::Events.onMapUpdate += proc { |_sender, _e| Reloaded::SaveCheck::KeptAside.announce }
          end
          return true
        end

        # What's waiting in the loaded save: [{ "kind", "id", "name", ... }]
        def waiting
          section = Reloaded::SaveStore.section(SECTION)
          list = section ? section["kept"] : nil
          return list.is_a?(Array) ? list : []
        end

        # Everything the game has again goes back. Returns the words for
        # each ("Fuecoco (in the PC)").
        def give_back
          list = waiting
          return [] if list.empty?
          back = []
          list.reject! do |e|
            words = case e["kind"]
                    when "pokemon" then back_pokemon(e)
                    when "item" then back_item(e)
                    when "move" then back_move(e)
                    when "ability" then back_ability(e)
                    end
            back << words if words
            !words.nil?
          end
          unless back.empty?
            @announce = back
            Reloaded::Log.info("Kept aside, now back: #{back.join(", ")}", :saves)
          end
          return back
        rescue StandardError => e
          Reloaded::Log.exception("Kept-aside content couldn't be given back", e, :saves)
          return []
        end

        # On the map, once: what came back.
        def announce
          return unless @announce
          return unless defined?(::Scene_Map) && $scene.is_a?(::Scene_Map)
          return if (pbMapInterpreterRunning? rescue false)
          list = @announce
          @announce = nil
          pbMessage(_INTL("Back from Keep Aside, now the game has them again: {1}.", SaveCheck.join_words(list)))
        rescue StandardError => e
          Reloaded::Log.exception("Kept-aside message", e, :saves)
        end

        # For tests: what would be announced.
        def pending_words
          return @announce
        end

        private

        def back_pokemon(e)
          return nil unless Content.species_known?(e["id"].to_s.to_sym) && $PokemonStorage
          pk = Marshal.load(e["dump"].to_s)
          result = $PokemonStorage.pbStoreCaught(pk)
          return nil if result.nil? || result == false || result == -1
          return _INTL("{1} (in the PC)", e["name"])
        end

        def back_item(e)
          id = e["id"].to_s.to_sym
          return nil unless Content.item_known?(id) && $PokemonBag
          return nil unless $PokemonBag.pbStoreItem(id, [e["qty"].to_i, 1].max)
          return _INTL("{1} (in the Bag)", e["name"])
        end

        def back_move(e)
          id = e["id"].to_s.to_sym
          pk = find_pokemon(e["pokemon"])
          return nil unless pk && Content.move_known?(id) && defined?(::Pokemon::Move)
          moves = pk.instance_variable_get(:@moves)
          return nil if !moves.is_a?(Array) || moves.length >= 4
          moves << ::Pokemon::Move.new(id)
          return _INTL("{1} (on {2})", e["name"], name_of(pk))
        end

        def back_ability(e)
          id = e["id"].to_s.to_sym
          pk = find_pokemon(e["pokemon"])
          return nil unless pk && Content.ability_known?(id)
          pk.instance_variable_set(:@ability, id)
          return _INTL("{1} (on {2})", e["name"], name_of(pk))
        end

        # A Pokémon in the party or the boxes, by its personal ID.
        def find_pokemon(pid)
          return nil if pid.nil?
          list = []
          list.concat(Array($Trainer.instance_variable_get(:@party))) if $Trainer
          if $PokemonStorage
            Array($PokemonStorage.instance_variable_get(:@boxes)).each do |box|
              list.concat(Array(box.instance_variable_get(:@pokemon))) if box
            end
          end
          return list.find { |pk| pk && pk.instance_variable_get(:@personalID) == pid }
        end

        def name_of(pk)
          name = pk.instance_variable_get(:@name).to_s
          return name.empty? ? Content.words(pk.instance_variable_get(:@species)) : name
        end
      end
    end
  end
end
