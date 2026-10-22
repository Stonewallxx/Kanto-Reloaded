#==============================================================================
# Kanto Reloaded: missing content
#==============================================================================
# Pokémon, items, moves and abilities a save holds that the game hasn't got
# now (the Expanded Dex isn't loaded, a mod that added them is off or gone).
# PIF shows a missing Pokémon as a Pikachu and a missing item as Unknown,
# but a missing move makes its lookup go round in circles until the game
# crashes, so a move is a problem and the rest are notes.
#
#   Reloaded::SaveCheck::Content.scan(data)                # everything
#   Reloaded::SaveCheck::Content.scan(data, :quick => true) # the party,
#        the boxes, the Day Care and the bag (the Load Screen's badge)
#
# Each is a Missing: kind (:pokemon :item :move :ability), id, name, where
# (in words), party (a party member, or something of one), fixable (Keep
# Aside or Remove can reach it), path (to it in the save), holder (the
# Pokémon a held item, move or ability belongs to), qty, fix (:keep or
# :remove, Keep Aside first).
#==============================================================================

module Reloaded
  module SaveCheck
    Missing = Struct.new(:kind, :id, :name, :where, :party, :fixable, :path, :holder, :qty, :fix, :order)

    module Content
      # The game's own values with no Pokémon or items in them.
      PASS = [:frame_count, :game_system, :pokemon_system, :switches, :self_switches, :game_screen,
              :map_factory, :game_player, :essentials_version, :game_version, :reloaded].freeze
      KINDS = [:pokemon, :item, :move, :ability].freeze

      class << self
        def scan(data, quick: false)
          out = []
          return out unless data.is_a?(Hash) && known_data?
          quick ? scan_quick(data, out) : scan_all(data, out)
          return out.sort_by { |m| m.order }
        end

        # The game's data is loaded (outside the game, it may not be).
        def known_data?
          return defined?(::GameData::Species::DATA) && defined?(::GameData::Item::DATA) && defined?(::GameData::Move::DATA) &&
                 !::GameData::Species::DATA.empty?
        end

        #----------------------------------------------------------------------
        # What the game has
        #----------------------------------------------------------------------
        # A species, or a fusion of two (PIF's B<body>H<head>, or head/body
        # by name or number, or head_x_body).
        def species_known?(sp)
          return true if sp.nil?
          data = ::GameData::Species::DATA
          return true if data.key?(sp)
          return part_known?(sp) if sp.is_a?(Integer)
          s = sp.to_s
          if (m = s.match(/\AB(\d+)H(\d+)\z/))
            return data.key?(m[1].to_i) && data.key?(m[2].to_i)
          end
          parts = s.include?("_x_") ? s.split("_x_") : (s.include?("/") ? s.split("/") : nil)
          return false unless parts && parts.length == 2
          return parts.all? { |p| p =~ /\A\d+\z/ ? data.key?(p.to_i) : data.key?(p.to_sym) }
        end

        def item_known?(item)
          return item.nil? || ::GameData::Item::DATA.key?(item)
        end

        def move_known?(move)
          return move.nil? || ::GameData::Move::DATA.key?(move)
        end

        def ability_known?(ability)
          return true if ability.nil? || !defined?(::GameData::Ability::DATA)
          return ::GameData::Ability::DATA.key?(ability)
        end

        def known?(kind, id)
          case kind
          when :pokemon then return species_known?(id)
          when :item then return item_known?(id)
          when :move then return move_known?(id)
          else return ability_known?(id)
          end
        end

        # A name to show for an id the game hasn't got: "FUECOCO" =>
        # "Fuecoco", "MEGA_RING" => "Mega Ring".
        def words(id)
          return id.to_s.split(/[_\s]+/).map(&:capitalize).join(" ")
        end

        # How many of each Pokémon, item and move the save holds (Mod Data:
        # what a mod added): { kind => { "ID" => count } }
        def ids_in(data)
          out = { :pokemon => Hash.new(0), :item => Hash.new(0), :move => Hash.new(0) }
          return out unless data.is_a?(Hash)
          count_item = lambda do |slot|
            item = slot.is_a?(Array) ? slot[0] : slot
            out[:item][item.to_s.upcase] += (slot.is_a?(Array) ? slot[1].to_i : 1) if item
          end
          data.each do |key, value|
            next if PASS.include?(key)
            SaveCheck.walk(value, [key]) do |obj, _path|
              if pokemon?(obj)
                out[:pokemon][ivar(obj, :@species).to_s.upcase] += 1
                item = ivar(obj, :@item)
                out[:item][item.to_s.upcase] += 1 if item
                Array(ivar(obj, :@moves)).each do |mv|
                  id = mv.nil? ? nil : ivar(mv, :@id)
                  out[:move][id.to_s.upcase] += 1 if id
                end
                :skip
              elsif bag?(obj)
                Array(ivar(obj, :@pockets)).each { |pocket| Array(pocket).each { |slot| count_item.call(slot) } }
                :skip
              elsif item_storage?(obj)
                Array(ivar(obj, :@items)).each { |slot| count_item.call(slot) }
                :skip
              elsif obj.is_a?(Stub)
                :skip
              end
            end
          end
          return out
        end

        private

        def part_known?(n)
          return true if ::GameData::Species::DATA.key?(n)
          return false unless defined?(::NB_POKEMON) && n > ::NB_POKEMON
          return species_known?(:"B#{n % ::NB_POKEMON}H#{n / ::NB_POKEMON}")
        end

        #----------------------------------------------------------------------
        # Looking
        #----------------------------------------------------------------------
        def scan_all(data, out)
          data.each do |key, value|
            next if PASS.include?(key)
            SaveCheck.walk(value, [key]) do |obj, path|
              if pokemon?(obj)
                check_pokemon(obj, path, data, out)
                :skip
              elsif bag?(obj)
                check_bag(obj, path, out)
                :skip
              elsif item_storage?(obj)
                check_item_storage(obj, path, out)
                :skip
              elsif obj.is_a?(Stub)
                :skip
              end
            end
          end
        end

        def scan_quick(data, out)
          player = data[:player]
          Array(ivar(player, :@party)).each_with_index { |pk, i| check_pokemon(pk, [:player, :@party, i], data, out) if pokemon?(pk) }
          Array(ivar(data[:storage_system], :@boxes)).each_with_index do |box, b|
            Array(ivar(box, :@pokemon)).each_with_index do |pk, s|
              check_pokemon(pk, [:storage_system, :@boxes, b, :@pokemon, s], data, out) if pokemon?(pk)
            end
          end
          Array(ivar(data[:global_metadata], :@daycare)).each_with_index do |slot, i|
            pk = slot.is_a?(Array) ? slot[0] : nil
            check_pokemon(pk, [:global_metadata, :@daycare, i, 0], data, out) if pokemon?(pk)
          end
          check_bag(data[:bag], [:bag], out) if bag?(data[:bag])
        end

        def pokemon?(obj)
          return defined?(::Pokemon) && obj.is_a?(::Pokemon)
        end

        def bag?(obj)
          return defined?(::PokemonBag) && obj.is_a?(::PokemonBag)
        end

        def item_storage?(obj)
          return defined?(::PCItemStorage) && obj.is_a?(::PCItemStorage)
        end

        def ivar(obj, name)
          return nil if obj.nil? || !obj.instance_variable_defined?(name)
          return obj.instance_variable_get(name)
        end

        # A Pokémon the game hasn't got goes as a whole (its item, moves and
        # ability with it); otherwise each of those on its own.
        def check_pokemon(pk, path, data, out)
          where, party, order = location(path, data)
          name = pokemon_name(pk)
          species = ivar(pk, :@species)
          movable = pokemon_place?(path)
          unless species_known?(species)
            out << Missing.new(:pokemon, species, name, where, party, movable, path, nil, 1, :keep, order + [0])
            return
          end
          item = ivar(pk, :@item)
          unless item_known?(item)
            out << Missing.new(:item, item, words(item), _INTL("{1}, held by {2}", where, name), party, true, path + [:@item], pk, 1, :keep, order + [1])
          end
          Array(ivar(pk, :@moves)).each_with_index do |mv, j|
            id = mv.nil? ? nil : ivar(mv, :@id)
            next if move_known?(id)
            out << Missing.new(:move, id, words(id), _INTL("{1}, {2}'s move", where, name), party, true, path + [:@moves, j], pk, 1, :keep, order + [2, j])
          end
          ability = ivar(pk, :@ability)
          unless ability_known?(ability)
            out << Missing.new(:ability, ability, words(ability), _INTL("{1}, {2}'s ability", where, name), party, true, path + [:@ability], pk, 1, :keep, order + [3])
          end
        end

        def check_bag(bag, path, out)
          Array(ivar(bag, :@pockets)).each_with_index do |pocket, p|
            Array(pocket).each_with_index do |slot, i|
              item = slot.is_a?(Array) ? slot[0] : slot
              next if item_known?(item)
              qty = slot.is_a?(Array) ? slot[1].to_i : 1
              out << Missing.new(:item, item, words(item), _INTL("Bag: {1}", pocket_name(p)), false, true, path + [:@pockets, p, i], nil, qty, :keep, [3, p, i])
            end
          end
        end

        def check_item_storage(storage, path, out)
          Array(ivar(storage, :@items)).each_with_index do |slot, i|
            item = slot.is_a?(Array) ? slot[0] : slot
            next if item_known?(item)
            qty = slot.is_a?(Array) ? slot[1].to_i : 1
            out << Missing.new(:item, item, words(item), _INTL("PC: Items"), false, true, path + [:@items, i], nil, qty, :keep, [4, i])
          end
        end

        # Where a Pokémon can be taken from: the party, a box or the Day Care.
        def pokemon_place?(path)
          return true if path[0] == :player && path[1] == :@party && path.length == 3
          return true if path[0] == :storage_system && path[1] == :@boxes && path.length == 5
          return true if path[0] == :global_metadata && path[1] == :@daycare && path.length == 4
          return false
        end

        # [words, party member?, sort order]
        def location(path, data)
          case path[0]
          when :player
            return [_INTL("Party, slot {1}", path[2] + 1), true, [0, path[2]]] if path[1] == :@party && path[2].is_a?(Integer)
          when :storage_system
            if path[1] == :@boxes && path[2].is_a?(Integer) && path[4].is_a?(Integer)
              box = (ivar(data[:storage_system], :@boxes)[path[2]] rescue nil)
              name = ivar(box, :@name).to_s
              name = _INTL("Box {1}", path[2] + 1) if name.strip.empty?
              return [_INTL("{1}, slot {2}", name, path[4] + 1), false, [2, path[2], path[4]]]
            end
          when :global_metadata
            return [_INTL("Day Care"), false, [1, path[2].to_i]] if path[1] == :@daycare
            return [_INTL("PC: Items"), false, [4]] if path[1] == :@pcItemStorage
          end
          owner = SaveCheck::ModData.key_owner(path[0]) rescue nil
          owner = nil if owner == :game
          return [owner ? _INTL("In {1}'s data", owner) : _INTL("In the game's data"), false, [5, path[0].to_s]]
        end

        def pokemon_name(pk)
          name = ivar(pk, :@name).to_s
          return name unless name.strip.empty?
          species = ivar(pk, :@species)
          return species_known?(species) ? (::GameData::Species.get(species).name rescue words(species)) : words(species)
        end

        def pocket_name(p)
          names = (::PokemonBag.pocketNames rescue nil)
          name = names.is_a?(Array) ? names[p].to_s : ""
          return name.empty? ? _INTL("Pocket {1}", p) : name
        end
      end
    end
  end
end
