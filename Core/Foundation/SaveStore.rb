#==============================================================================
# Kanto Reloaded: Save Store
#==============================================================================
# Kanto Reloaded's data inside each save: one save value, :reloaded, holding
# a section per feature.
#
#   data = Reloaded::SaveStore.section(:pc)       # a Hash, kept in the save
#   data["sort_lock"] = true
#
#   Reloaded::SaveStore.register(:pc, :version => 2,
#     :migrate => proc { |data, from_version| ... data })   # optional
#
# Upgrades are all or nothing: they run on a copy, and if one fails none
# apply; the old data is held in the save and tried again later (migrate).
#
# Only plain Ruby values go in a section (Hash, Array, String, Symbol,
# numbers, true/false/nil, Time), so a save stays loadable with Kanto
# Reloaded removed.
#
# Kept with KR off (his pick, 2026-10-25): the game only writes the save
# values of code that is loaded, so a save made with Kanto Reloaded switched
# off has no :reloaded value. The same Hash also hangs on the game's own
# $PokemonGlobal (@kr_reloaded): the game writes every field of its own
# objects, so it's still there after such a save, and comes back from it.
# One Marshal pass writes a shared object once, so the save doesn't grow.
# Last resort, for saves from before this: each time the game saves, a copy
# is written to <data_dir>\Saves\<save file>.kr, restored when a save
# without Kanto Reloaded's data is loaded and the copy is the same player's.
#
# The seal: the game counts every save ($game_system.save_count, with or
# without Kanto Reloaded). Each save Kanto Reloaded writes records that
# count. A save that comes back with a higher count was saved that many
# times without Kanto Reloaded: kept in "gaps" (Difficulty counts such a run
# as Debug). A save Kanto Reloaded hasn't seen before is "joined" instead.
# A test copy (Saves.make_test_copy) carries "test_copy" here, so it counts
# as Debug too, and the save it was copied from stays clean.
#==============================================================================

module Reloaded
  module SaveStore
    SAVE_KEY = :reloaded
    SCHEMA = 1
    BACKUP_FOLDER = "Saves"
    GLOBAL_FIELD = :@kr_reloaded    # the same data on $PokemonGlobal (kept with KR off)
    TEST_COPY = "test_copy"         # a test copy's mark (Saves.make_test_copy)

    @sections = {}       # id => { :version, :migrate }
    @data = nil          # the loaded save's value (nil at the title screen)

    class << self
      def boot
        ::SaveData.register(SAVE_KEY) do
          ensure_class :Hash
          save_value { Reloaded::SaveStore.__send__(:to_save) }
          load_value { |value| Reloaded::SaveStore.__send__(:from_save, value) }
          # Also called when an existing save has no :reloaded value.
          new_game_value { Reloaded::SaveStore.__send__(:missing_or_new) }
        end
        Reloaded::Events.on(:title_screen, :save_store, 5) { @data = nil }
        Reloaded::Events.on(:saved, :save_store, 50) { |context| write_backup(context[:path]) }
        return true
      end

      def register(id, options = {})
        @sections[id.to_s] = { :version => options[:version] || 1, :migrate => options[:migrate] }
        return true
      end

      # True while a save is loaded (or a new game is running).
      def loaded?
        return !@data.nil?
      end

      # The feature's data in the loaded save (an empty Hash the first time).
      # Nil at the title screen.
      def section(id)
        return nil unless @data
        sections = (@data["sections"] ||= {})
        return (sections[id.to_s] ||= {})
      end

      # Kanto Reloaded's data in a save file's values (its :reloaded value,
      # or, saved with Kanto Reloaded off, the copy on its global metadata)
      def value_in(data)
        return nil unless data.is_a?(Hash)
        value = data[SAVE_KEY]
        return value if value.is_a?(Hash) && !value.empty?
        kept = global_copy(data[:global_metadata])
        return kept || value
      end

      # Saves written without Kanto Reloaded since it last saved this one:
      # [{ "saves", "count" (the game's), "found_at", "since" }] (empty: none)
      def gaps
        return @data ? Array(@data["gaps"]) : []
      end

      def played_without?
        return !gaps.empty?
      end

      # A test copy (Saves.make_test_copy): { "of" => the slot it was
      # copied from, "at" }, or nil
      def test_copy
        value = @data ? @data[TEST_COPY] : nil
        return value.is_a?(Hash) ? value : nil
      end

      def backup_path(save_path)
        dir = Reloaded::Paths.ensure_dir(File.join(Reloaded::Paths.data_dir, BACKUP_FOLDER))
        return File.join(dir, File.basename(save_path.to_s) + ".kr")
      end

      # Sections registered now: id => version (the Save Checker's).
      def registered
        out = {}
        @sections.each { |id, info| out[id] = info[:version] }
        return out
      end

      # The upgrades a save's Kanto Reloaded data (its :reloaded value)
      # needs: [[section id, from version, to version]], in order.
      def pending_upgrades(value)
        return [] unless value.is_a?(Hash)
        versions = value["versions"].is_a?(Hash) ? value["versions"] : {}
        sections = value["sections"].is_a?(Hash) ? value["sections"] : {}
        out = []
        @sections.each do |id, info|
          stored = versions[id].to_i
          stored = info[:version] if stored == 0 && !sections.has_key?(id)
          out << [id, stored, info[:version]] if stored < info[:version] && info[:migrate]
        end
        return out
      end

      private

      def fresh
        @data = { "schema" => SCHEMA, "versions" => {}, "sections" => {} }
        stamp_versions
        return @data
      end

      def global_copy(global)
        return nil if global.nil? || !global.instance_variable_defined?(GLOBAL_FIELD)
        value = global.instance_variable_get(GLOBAL_FIELD)
        return value.is_a?(Hash) && !value.empty? ? value : nil
      rescue Exception
        return nil
      end

      # The same Hash on $PokemonGlobal, so the game keeps it with KR off
      def attach
        g = $PokemonGlobal
        g.instance_variable_set(GLOBAL_FIELD, @data) if g && @data && !g.frozen?
      rescue Exception => e
        Reloaded::Log.exception("Couldn't keep Kanto Reloaded's data with the game's own", e, :save)
      end

      def save_count(system)
        return system && system.respond_to?(:save_count) ? system.save_count.to_i : nil
      rescue Exception
        return nil
      end

      # Saves made without Kanto Reloaded since its last one (the seal), or
      # the first time it sees this save
      def check_seal(incoming, came_with_data)
        return unless incoming.is_a?(Hash)
        count = save_count(incoming[:game_system])
        return unless count
        seal = @data["seal"]
        if seal.is_a?(Hash) && seal["count"]
          missed = count - seal["count"].to_i
          return unless missed > 0
          gaps = (@data["gaps"] ||= [])
          # once per gap: the game asks twice for a save with no :reloaded
          # value, and the same file can be loaded again before KR saves it
          return if gaps.any? { |g| g["count"] == count }
          gaps << { "saves" => missed, "count" => count, "found_at" => Time.now, "since" => seal["saved_at"] }
          Reloaded::Log.warning("This save was saved #{missed} time(s) without Kanto Reloaded since #{seal["saved_at"]}", :save)
        elsif !came_with_data
          @data["joined"] ||= { "count" => count, "at" => Time.now }
        end
      end

      # The game asks for a new game value both for a new game and for a save
      # that has no :reloaded value; only the second has incoming save data.
      def missing_or_new
        return fresh unless Reloaded::Lifecycle.incoming_save_data
        return from_save(nil)
      end

      def to_save
        fresh unless @data
        # Lets features copy live state into their sections first.
        Reloaded::Events.emit(:saving)
        @data["player_id"] = player_id($Trainer)
        @data["saved_at"] = Time.now
        # the game has already counted this save (Game.save)
        count = save_count($game_system)
        @data["seal"] = { "count" => count, "saved_at" => @data["saved_at"], "version" => (Reloaded.version rescue nil) } if count
        stamp_versions
        attach
        return @data
      end

      def from_save(value)
        incoming = Reloaded::Lifecycle.incoming_save_data
        if !value.is_a?(Hash) || value.empty?
          kept = incoming.is_a?(Hash) ? global_copy(incoming[:global_metadata]) : nil
          if kept
            Reloaded::Log.warning("The save has no Kanto Reloaded value (saved with it switched off?); its data came back from the game's own", :save)
            value = kept
          else
            restored = restore_backup
            value = restored if restored
          end
        end
        @data = value.is_a?(Hash) && !value.empty? ? value : nil
        came_with_data = !@data.nil?
        fresh unless @data
        @data["sections"] ||= {}
        @data["versions"] ||= {}
        migrate
        check_seal(incoming, came_with_data)
        return @data
      end

      # Upgrades, all or nothing (Hoenn Reloaded's Save Migrations): every
      # section whose stored version is older runs its migrate proc on a copy,
      # and the save takes the results only when all of them worked. When one
      # fails, none apply: each of those sections' old data is held in the
      # save ("held", with the version it was and why), the sections start
      # empty, and the held data is tried again on later loads (a newer
      # Kanto Reloaded may upgrade it). Nothing is lost either way.
      def migrate
        (@data["held"] ||= {})
        retry_held
        pending = pending_upgrades(@data)
        unless pending.empty?
          copy = Marshal.load(Marshal.dump(@data["sections"]))
          failed = nil
          pending.each do |id, from, to|
            begin
              copy[id] = @sections[id][:migrate].call(copy[id] || {}, from) || {}
            rescue Exception => e
              failed = [id, e]
              break
            end
          end
          if failed
            id, e = failed
            Reloaded::Log.exception("Upgrading save data for #{id} failed; none of the upgrades were applied and the old data is held", e, :save)
            pending.each do |pid, from, _to|
              @data["held"][pid] = { "version" => from, "data" => @data["sections"][pid] || {},
                                     "error" => "#{e.class}: #{e.message}"[0, 300], "at" => Time.now }
              @data["sections"][pid] = {}
            end
          else
            @data["sections"] = copy
            pending.each { |pid, from, to| Reloaded::Log.info("Save data for #{pid} upgraded from version #{from} to #{to}", :save) }
          end
        end
        stamp_versions
      end

      # Held data from a failed upgrade, tried again (all or nothing). A
      # section that has new data since keeps it, and its held data stays.
      def retry_held
        held = @data["held"]
        return if held.empty?
        ids = held.keys.select { |id| @sections[id] && @sections[id][:migrate] }
        return if ids.empty?
        results = {}
        ids.each do |id|
          h = held[id]
          results[id] = Marshal.load(Marshal.dump(h["data"] || {}))
          results[id] = @sections[id][:migrate].call(results[id], h["version"].to_i) || {} if h["version"].to_i < @sections[id][:version]
        end
        results.each do |id, data|
          next unless (@data["sections"][id] || {}).empty?
          @data["sections"][id] = data
          held.delete(id)
          Reloaded::Log.info("Held save data for #{id} upgraded at last", :save)
        end
      rescue Exception => e
        Reloaded::Log.exception("Held save data still couldn't be upgraded", e, :save)
      end

      def stamp_versions
        @sections.each { |id, info| @data["versions"][id] = info[:version] }
      end

      def player_id(trainer)
        return nil unless trainer && trainer.respond_to?(:id)
        return trainer.id
      rescue Exception
        return nil
      end

      def write_backup(save_path)
        return unless @data && save_path
        Reloaded::Paths.write_atomic(backup_path(save_path), Marshal.dump(@data))
      rescue Exception => e
        Reloaded::Log.exception("Could not write the save backup copy", e, :save)
      end

      # The backup copy of the save being loaded, if it belongs to the same
      # player.
      def restore_backup
        path = Reloaded::Lifecycle.last_save_path
        incoming = Reloaded::Lifecycle.incoming_save_data
        return nil unless path && incoming.is_a?(Hash)
        file = backup_path(path)
        return nil unless File.file?(file)
        data = File.open(file, "rb") { |f| Marshal.load(f) }
        return nil unless data.is_a?(Hash)
        if data["player_id"] && data["player_id"] != player_id(incoming[:player])
          Reloaded::Log.info("Save backup copy for #{File.basename(path)} belongs to another player; not used", :save)
          return nil
        end
        Reloaded::Log.warning("#{File.basename(path)} has no Kanto Reloaded data (saved with it switched off?); restored the backup copy from #{data["saved_at"]}", :save)
        return data
      rescue Exception => e
        Reloaded::Log.exception("Could not read the save backup copy", e, :save)
        return nil
      end
    end
  end
end
