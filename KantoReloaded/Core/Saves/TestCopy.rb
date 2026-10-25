#==============================================================================
# Kanto Reloaded: test copies
#==============================================================================
# A copy of a save to play with Kanto Reloaded off, to see whether a bug is
# Kanto Reloaded's. The copy goes in the first free File slot, marked in
# its Kanto Reloaded data ("test_copy": the slot it came from), on both
# places that data is kept, so the mark stays when the copy is saved with
# Kanto Reloaded off. Loaded with Kanto Reloaded, a test copy counts as
# Debug (Difficulty); the save it was copied from stays clean.
#
#   Reloaded::Saves.make_test_copy("File A")   # => "File D"
#   Reloaded::Saves.test_of(data)              # => "File A", or nil
#
# The Save Manager (A on a save) and the Bug Report's Test Copy section make
# them; the Save Manager lists them last, under Test Copies.
#==============================================================================

module Reloaded
  module Saves
    class << self
      # The copy of slot's file as it was last saved: the new slot. Raises
      # ArgumentError (its message for the player) when it can't.
      def make_test_copy(slot)
        source = path(slot)
        raise ArgumentError, "#{slot} isn't there" unless File.file?(source)
        dest = free_slot
        raise ArgumentError, "Every File slot is taken: Delete one first" unless dest
        data = Reloaded::SaveFile.load(source)
        raise ArgumentError, "#{slot} can't be read, so it can't be copied" unless data.is_a?(Hash) && data[:player]
        kr = Reloaded::SaveStore.value_in(data)
        kr = {} unless kr.is_a?(Hash)
        kr[Reloaded::SaveStore::TEST_COPY] = { "of" => slot.to_s, "at" => Time.now }
        data[Reloaded::SaveStore::SAVE_KEY] = kr
        global = data[:global_metadata]
        global.instance_variable_set(Reloaded::SaveStore::GLOBAL_FIELD, kr) if global && !global.frozen?
        # the game saves to the slot the player says (PIF's save_slot)
        data[:player].save_slot = dest if data[:player].respond_to?(:save_slot=)
        target = path(dest)
        write_safely(Marshal.dump(data), target)
        forget(target)
        Reloaded::Log.info("Test copy of #{slot} made: #{dest}", :saves)
        return dest
      end

      # The slot a save's data was copied from, if it's a test copy
      def test_of(data)
        kr = Reloaded::SaveStore.value_in(data)
        mark = kr.is_a?(Hash) ? kr[Reloaded::SaveStore::TEST_COPY] : nil
        return mark.is_a?(Hash) ? mark["of"].to_s : nil
      rescue StandardError
        return nil
      end
    end
  end
end
