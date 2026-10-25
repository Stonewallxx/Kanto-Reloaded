# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Reloaded PC's Party Presets (Step 5)
#==============================================================================
# Teams saved by name in the save (SaveStore section "pc"): each member is
# a reference (its personal ID), never a copy, so nothing can be duplicated;
# its name and level at the time are kept only to say who's missing.
#
#   section("pc")["presets"] = [{ "name" => "Gym 4: Erika",
#                                 "members" => [personalID, ...],
#                                 "seen" => [["Charmander", 16], ...] }, ...]
#
# Swap In (his picks, 2026-10-24: Trade Places; They Go to the Boxes): the
# party becomes the preset, in its order. Each member in a box trades places
# with a party member that isn't in the preset; party members left over go
# to the first free places from the box shown on; a member in a box with no
# one to trade with leaves its place empty. Members that are gone (released,
# traded, fused into another) or in the Transfer Box are skipped and named.
# It's all worked out before anything moves, and it doesn't happen when it
# would leave no Pokémon that can battle, when a party member going to a box
# holds Mail (PIF's rule), or when the boxes have no room.
#==============================================================================

module Reloaded
  module PC
    module Presets
      SECTION = :pc
      MAX = 30

      Plan = Struct.new(:ok, :reason, :party, :moves, :missing, :transfer)

      class << self
        def list
          data = Reloaded::SaveStore.section(SECTION)
          return [] unless data
          return (data["presets"] ||= [])
        end

        def full?
          return list.length >= MAX
        end

        # A new preset of the party as it is (the name given, or Team N)
        def add(name, party)
          return nil if full? || party.empty?
          name = name.to_s.strip
          name = _INTL("Team {1}", list.length + 1) if name.empty?
          preset = { "name" => name }
          fill(preset, party)
          list << preset
          return preset
        end

        def save_party(i, party)
          return false unless list[i] && !party.empty?
          fill(list[i], party)
          return true
        end

        def rename(i, name)
          name = name.to_s.strip
          return false unless list[i] && !name.empty?
          list[i]["name"] = name
          return true
        end

        def delete(i)
          return list.delete_at(i) ? true : false
        end

        def fill(preset, party)
          preset["members"] = party.map { |pk| pk.personalID }
          preset["seen"] = party.map { |pk| [pk.name.to_s, pk.level.to_i] }
        end

        # Where every Pokémon is, by personal ID: [box, index] ([-1, i] in
        # the party, :transfer in the Transfer Box); the first one found wins
        def places(storage)
          out = {}
          storage.party.each_with_index { |pk, i| out[pk.personalID] ||= [-1, i] if pk }
          storage.maxBoxes.times do |b|
            box = storage[b]
            next unless box
            transfer = defined?(::StorageTransferBox) && box.is_a?(::StorageTransferBox)
            storage.maxPokemon(b).times do |i|
              pk = storage[b, i]
              next unless pk
              out[pk.personalID] ||= transfer ? :transfer : [b, i]
            end
          end
          return out
        end

        # Each member: [the Pokémon or nil, where it is, [name, level]]
        def members(preset, storage, where = nil)
          where ||= places(storage)
          seen = preset["seen"] || []
          return (preset["members"] || []).each_with_index.map do |pid, k|
            at = where[pid]
            pk = at.is_a?(Array) ? storage[at[0], at[1]] : nil
            [pk, at, seen[k] || ["?", 0]]
          end
        end

        # Is it the party now (the same Pokémon in any order, not counting
        # members that are gone)? members: from members(), if already made
        def party?(preset, party, storage, members = nil)
          members ||= members(preset, storage)
          ids = members.map { |pk, _a, _s| pk && pk.personalID }.compact
          return !ids.empty? && ids.sort == party.map { |pk| pk.personalID }.sort
        end

        # Swap In, worked out: nothing has moved yet
        def plan(preset, storage, from_box)
          where = places(storage)
          list = members(preset, storage, where)
          found = list.select { |pk, at, _s| pk && at.is_a?(Array) }
          missing = list.select { |pk, at, _s| pk.nil? && at != :transfer }.map { |_p, _a, s| s }
          transfer = list.select { |_p, at, _s| at == :transfer }.map { |_p, _a, s| s }
          plan = Plan.new(false, nil, [], [], missing, transfer)
          found = found.first(::Settings::MAX_PARTY_SIZE)
          if found.empty? || found.none? { |pk, _a, _s| pk.able? }
            plan.reason = :none_able
            return plan
          end
          new_party = found.map { |pk, _a, _s| pk }
          incoming = found.reject { |_pk, at, _s| at[0] == -1 }
          outgoing = storage.party.reject { |pk| new_party.any? { |m| m.equal?(pk) } }
          if (mail = outgoing.find { |pk| pk.mail })
            plan.reason = [:mail, mail]
            return plan
          end
          moves = []
          incoming.each_with_index do |(_pk, at, _s), k|
            moves << [outgoing[k], at[0], at[1]] if outgoing[k]       # trade places
          end
          extra = outgoing[incoming.length..-1] || []
          freed = incoming[outgoing.length..-1] || []                   # no one to trade with: their places empty
          spots = free_places(storage, from_box, extra.length, incoming.first(outgoing.length).map { |_p, at, _s| at }, freed.map { |_p, at, _s| at })
          if spots.length < extra.length
            plan.reason = :no_room
            return plan
          end
          extra.each_with_index { |pk, k| moves << [pk, spots[k][0], spots[k][1]] }
          plan.ok = true
          plan.party = new_party
          plan.moves = moves
          return plan
        end

        # Free box places from a box on (the Transfer Box never), counting
        # the places members leave and not the ones others take
        def free_places(storage, from_box, n, taken, freed)
          return [] if n <= 0
          out = []
          boxes = (0...storage.maxBoxes).to_a
          boxes = boxes.rotate(boxes.index(from_box) || 0)
          boxes.each do |b|
            box = storage[b]
            next if box.nil? || (defined?(::StorageTransferBox) && box.is_a?(::StorageTransferBox))
            storage.maxPokemon(b).times do |i|
              empty = storage[b, i].nil? || freed.include?([b, i])
              out << [b, i] if empty && !taken.include?([b, i]) && !out.include?([b, i])
              return out if out.length >= n
            end
          end
          return out
        end

        # Does it: the boxes first (every place a member leaves is filled or
        # emptied), then the party in the preset's order
        def apply(plan, storage)
          new_party = plan.party
          new_party.each do |pk|
            storage.boxes.each_with_index do |box, b|
              next unless box
              storage.maxPokemon(b).times { |i| storage[b, i] = nil if storage[b, i].equal?(pk) }
            end
          end
          plan.moves.each { |pk, b, i| storage[b, i] = pk }
          storage.party.clear
          new_party.each { |pk| storage.party.push(pk) }
          return true
        end

        # "Ditto (Lv. 20)", "Ditto (Lv. 20) and Abra (Lv. 12)"
        def names(seen)
          words = seen.map { |name, level| _INTL("{1} (Lv. {2})", name, level) }
          return words.first.to_s if words.length <= 1
          return _INTL("{1} and {2}", words[0...-1].join(", "), words[-1])
        end
      end
    end
  end
end
