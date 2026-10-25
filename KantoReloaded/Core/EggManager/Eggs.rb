# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Egg Manager's Eggs
#==============================================================================
# Every Egg in the party and the boxes (the Transfer Box is shared by every
# save, so it's left out), each as an Entry: the Egg, its box (-1 for the
# party) and its place there. Found when asked (the screen, the menus'
# counts); never on a step.
#
#   state     :ready (an Egg in a box at its last step, or a party Egg
#             under 100 steps), :hatching (the party), :incubating, :paused
#   section   the list's (his pick): Ready, then Gift (not from the Day
#             Care) wherever it is, then Party or PC; each Egg once
#   moving    to the party (room needed), to a box (the Egg Box first,
#             else the current box, else the first with room)
#==============================================================================

module Reloaded
  module EggManager
    Entry = Struct.new(:pkmn, :box, :slot) do
      def party?; box == -1; end
    end

    module Eggs
      SECTIONS = [:ready, :party, :pc, :gift].freeze

      module_function

      def storage
        return $PokemonStorage
      end

      def transfer?(box)
        return defined?(::StorageTransferBox) && box.is_a?(::StorageTransferBox) ? true : false
      end

      # The boxes Eggs can be in: [index, box]
      def each_box
        st = storage
        return unless st
        (0...st.maxBoxes).each do |i|
          b = (st[i] rescue nil)
          next if b.nil? || transfer?(b)
          yield i, b
        end
      end

      def party
        return $Trainer && $Trainer.party ? $Trainer.party.compact : []
      end

      # Every Egg: the party's first, then each box in order
      def all
        out = []
        party.each_with_index { |p, i| out << Entry.new(p, -1, i) if egg?(p) }
        st = storage
        each_box do |i, _b|
          (0...st.maxPokemon(i)).each do |k|
            p = st[i, k]
            out << Entry.new(p, i, k) if egg?(p)
          end
        end
        return out
      rescue StandardError => e
        Reloaded::Log.exception("The Egg Manager couldn't list the Eggs", e, :egg_manager)
        return []
      end

      def egg?(p)
        return p && p.respond_to?(:egg?) && p.egg? ? true : false
      end

      # Where an Egg (or any Pokémon) is now, or nil
      def locate(pkmn)
        return nil unless pkmn
        i = party.index { |p| p.equal?(pkmn) }
        return Entry.new(pkmn, -1, i) if i
        st = storage
        found = nil
        each_box do |b, _box|
          break if found
          (0...st.maxPokemon(b)).each do |k|
            next unless st[b, k].equal?(pkmn)
            found = Entry.new(pkmn, b, k)
            break
          end
        end
        return found
      end

      #------------------------------------------------------------------------
      # An Egg's steps
      #------------------------------------------------------------------------
      def steps(pkmn)
        return pkmn.steps_to_hatch.to_i
      end

      # Its whole count (a fusion's is its two parts' average, the game's own)
      def total(pkmn)
        t = (pkmn.species_data.hatch_steps rescue 0).to_i
        return [t, steps(pkmn), 1].max
      end

      def progress(pkmn)
        t = total(pkmn)
        return [[(t - steps(pkmn)).to_f / t, 0.0].max, 1.0].min
      end

      # PIF's own words for how close it is (the Summary's)
      STAGES = [[1275, "Sounds can be heard coming from inside! It will hatch soon!"],
                [2550, "It appears to move occasionally. It may be close to hatching."],
                [10200, "What will hatch from this? It doesn't seem close to hatching."],
                [nil, "It looks like this Egg will take a long time to hatch."]].freeze

      def stage_words(pkmn)
        left = steps(pkmn)
        return _INTL(STAGES.find { |lim, _w| lim.nil? || left < lim }[1])
      end

      #------------------------------------------------------------------------
      # State and sections
      #------------------------------------------------------------------------
      def ready?(entry)
        s = steps(entry.pkmn)
        return entry.party? ? s < EggManager::SOON : s <= 1
      end

      def state(entry)
        return :ready if ready?(entry)
        return :hatching if entry.party?
        return Incubators.number(entry.pkmn) ? :incubating : :paused
      end

      def gift?(pkmn)
        return (pkmn.obtain_text rescue nil).to_s != EggManager::DAY_CARE_TEXT
      end

      def section(entry)
        return :ready if ready?(entry)
        return :gift if gift?(entry.pkmn)
        return entry.party? ? :party : :pc
      end

      # In sections (empty ones left out), each sorted: [[section, [entries]], ...]
      def sections(list = all, sort = EggManager.sort)
        groups = list.group_by { |e| section(e) }
        return SECTIONS.map { |s| [s, sorted(groups[s] || [], sort)] }.reject { |_s, l| l.empty? }
      end

      # Steps: fewest first; Place: the party, then box by box
      def sorted(list, sort = EggManager.sort)
        case EggManager::SORTS[sort]
        when "Place" then return list.sort_by { |e| [e.box, e.slot] }
        else return list.sort_by { |e| [steps(e.pkmn), e.box, e.slot] }
        end
      end

      #------------------------------------------------------------------------
      # Boxes
      #------------------------------------------------------------------------
      def box_name(i)
        n = (storage[i].name rescue nil).to_s
        return n.empty? ? _INTL("Box {1}", i + 1) : n
      end

      def free_places(i)
        st = storage
        return (0...st.maxPokemon(i)).count { |k| st[i, k].nil? }
      rescue StandardError
        return 0
      end

      def free_slot(i)
        st = storage
        return (0...st.maxPokemon(i)).find { |k| st[i, k].nil? }
      rescue StandardError
        return nil
      end

      # Where an Egg sent to the PC goes: the Egg Box when it has room, else
      # the current box, else the first with room (nil: every box is full)
      def room_box(preferred = EggManager.egg_box)
        return preferred if preferred && free_slot(preferred)
        st = storage
        cur = (st.currentBox rescue 0).to_i
        ok = cur >= 0 && cur < st.maxBoxes && !transfer?(st[cur]) && free_slot(cur)
        return cur if ok
        found = nil
        each_box { |i, _b| found ||= i if free_slot(i) }
        return found
      rescue StandardError
        return nil
      end

      # Where the game's pbStoreCaught would put a Pokémon (the Ask Card's
      # "Goes to"): the current box, else the first with room
      def store_box
        return room_box(nil)
      end

      def pc_full?
        return room_box(nil).nil?
      end

      #------------------------------------------------------------------------
      # Moving Eggs
      #------------------------------------------------------------------------
      # A party Egg (or any Pokémon) into a box: [box, slot], or nil
      def to_box(entry, box = nil)
        return nil unless entry && entry.party?
        target = box || room_box
        return nil unless target
        k = free_slot(target)
        return nil unless k
        pk = entry.pkmn
        $Trainer.party.delete_at($Trainer.party.index { |p| p.equal?(pk) })
        storage[target, k] = pk
        return [target, k]
      rescue StandardError => e
        Reloaded::Log.exception("The Egg Manager couldn't move a Pokémon to the PC", e, :egg_manager)
        return nil
      end

      # A boxed Egg into the party (its incubator freed): true, or why not
      def to_party(entry)
        return _INTL("It's already in your party.") if entry.party?
        return _INTL("Your party is full.") if party.length >= 6
        pk = entry.pkmn
        Incubators.release(pk)
        storage[entry.box, entry.slot] = nil
        $Trainer.party.push(pk)
        return true
      rescue StandardError => e
        Reloaded::Log.exception("The Egg Manager couldn't move an Egg to the party", e, :egg_manager)
        return _INTL("It couldn't be moved.")
      end
    end
  end
end
