#==============================================================================
# Kanto Reloaded: the saves (the Save Manager's and Load Screen's model)
#==============================================================================
# Everything the Save Manager and the Load Screen know about save files,
# without loading any of them into the game:
#
#   Saves.slots                     the save files there are ("File A"...)
#   Saves.preview(path)             what a save holds (trainer, map, play
#                                   time, party...) and its health
#   Saves.backups(slot)             its backups, newest first (KIF Beta's
#                                   backups\<slot> folder)
#   Saves.restore_backup / name_backup
#   Saves.archive(slot)             to the Deleted tab (DELETED SAVES, as old
#                                   Kanto Reloaded kept it), restore_archive,
#                                   delete_archive
#   Saves.note / tag                a save's note and color tag
#
# A preview reads the whole file (PIF has no small header), with PIF's raw
# reader (SaveData.get_data_from_file, through SaveFile: a backup KIF packed
# reads too): it never rewrites the file, unlike read_from_file. Previews are kept until the file
# changes, and the light part of each (no party) in Kanto Reloaded\Save
# Previews.json, so the backup lists fill in at once next time.
#
# Health: Healthy (it reads as a save the game can load), Check (it reads,
# but uses something the game hasn't got, a mod that's off maybe, or parts
# aren't what the game expects, or it has Pokémon, items or moves the game
# hasn't got: the Save Checker's quick part), Damaged (cut short, empty or
# garbled). The Save Checker (Core/SaveCheck) is the full check.
#
# Notes and color tags are in Kanto Reloaded\Save Notes.json, by slot, with
# the save's player id: a new save in the same slot doesn't inherit them.
#==============================================================================

module Reloaded
  module Saves
    BACKUPS = "backups".freeze
    DELETED = "DELETED SAVES".freeze
    NOTES_FILE = "Save Notes.json".freeze
    PREVIEWS_FILE = "Save Previews.json".freeze
    MANIFEST = "manifest.json".freeze
    TAGS = [["None", nil], ["Red", [230, 80, 80]], ["Orange", [240, 150, 60]], ["Yellow", [235, 205, 70]],
            ["Green", [100, 200, 110]], ["Blue", [90, 150, 235]], ["Purple", [160, 110, 220]],
            ["Pink", [235, 120, 180]], ["Grey", [150, 150, 160]]].freeze
    PARTIES_KEPT = 12      # previews whose party (the game's objects) stays in memory
    SWITCH_REMIX = 974
    SWITCH_EXPERT = 772
    SWITCH_RANDOMIZED = 855
    SWITCH_SPECIES = 790          # PIF's single Pokémon mode
    SWITCH_LEGENDARY = 1129
    VAR_SPECIES = 251             # its Pokémon

    @previews = {}     # path => preview (with :party)
    @parties = []      # paths whose party is kept, oldest first

    class << self
      #------------------------------------------------------------------------
      # Slots
      #------------------------------------------------------------------------
      def dir
        return ::SaveData::SAVE_DIR.to_s if defined?(::SaveData::SAVE_DIR)
        return Reloaded::Paths.user_dir
      end

      # Every slot PIF knows (Auto 1, Auto 2, File A to File H).
      def all_slots
        auto = defined?(::SaveData::AUTO_SLOTS) ? ::SaveData::AUTO_SLOTS : []
        manual = defined?(::SaveData::MANUAL_SLOTS) ? ::SaveData::MANUAL_SLOTS : ("A".."H").map { |l| "File #{l}" }
        return manual + auto
      end

      # The slots with a save file, File A first.
      def slots
        return all_slots.select { |s| File.file?(path(s)) }
      end

      def path(slot)
        return ::SaveData.get_full_path(slot) if defined?(::SaveData) && ::SaveData.respond_to?(:get_full_path)
        return File.join(dir, "#{slot}.rxdata")
      end

      # The first File slot nobody uses, or nil.
      def free_slot
        manual = defined?(::SaveData::MANUAL_SLOTS) ? ::SaveData::MANUAL_SLOTS : ("A".."H").map { |l| "File #{l}" }
        return manual.find { |s| !File.file?(path(s)) }
      end

      # The save being played now (its slot), or nil at the title screen.
      # A game is only being played on the map: PIF's title screen holds a
      # save's $Trainer too (the one Continue shows), and so does the title
      # after Quit to Title.
      def playing
        return nil unless defined?(::Scene_Map) && $scene.is_a?(::Scene_Map)
        return nil unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:save_slot)
        return $Trainer.save_slot
      end

      #------------------------------------------------------------------------
      # Previews and health
      #------------------------------------------------------------------------
      # What a save file holds: { :name, :gender, :money, :badges, :owned,
      # :seen, :seconds, :map_id, :map, :saved_at, :difficulty (and
      # :difficulty_index: 0 Easy, 1 Normal, 2 Hard), :debug (the Debug Run
      # Tag), :mode (mode_of), :randomized, :test_of (a test copy: the slot
      # it was copied from), :player_id, :save_count, :party (the game's
      # Pokémon, or nil), :health (:healthy, :check, :damaged), :problem
      # (why) }.
      def preview(file, party: true)
        key = stamp(file)
        return { :health => :damaged, :problem => "The file isn't there." } unless key
        key = "#{key}|#{content_stamp}"
        cached = @previews[file]
        return cached if cached && cached[:stamp] == key && (cached[:party] || !party)
        light = kept_previews[key]
        return light.merge(:stamp => key) if light && !party
        data = read(file)
        pv = data.is_a?(Hash) && data[:health] ? data : summarize(data)
        pv[:stamp] = key
        remember(file, pv)
        return pv
      end

      # Health only (a preview without the party).
      def health(file)
        pv = preview(file, :party => false)
        return [pv[:health], pv[:problem]]
      end

      # The file as the game wrote it, or a preview of what's wrong.
      def read(file)
        return { :health => :damaged, :problem => "The file is empty." } if File.size(file).zero?
        data = Reloaded::SaveFile.load(file)
        return { :health => :check, :problem => "It's from an older version of the game; it updates when it's loaded." } if data.is_a?(Array)
        return { :health => :damaged, :problem => "It isn't a save the game can read." } unless data.is_a?(Hash) && data[:player]
        return data
      rescue NameError => e
        return { :health => :check, :problem => "It uses something the game hasn't got (#{e.name}); a mod that's off or gone, maybe." }
      rescue ArgumentError => e
        # Marshal's word for a class the game hasn't got
        if (m = e.message.match(%r{undefined class/module (\S+)}))
          return { :health => :check, :problem => "It uses something the game hasn't got (#{m[1]}); a mod that's off or gone, maybe." }
        end
        return { :health => :damaged, :problem => "It's cut short or garbled, so it can't be read." }
      rescue EOFError, TypeError, Zlib::Error
        return { :health => :damaged, :problem => "It's cut short or garbled, so it can't be read." }
      rescue StandardError => e
        return { :health => :damaged, :problem => "It can't be read: #{e.class}: #{e.message}." }
      end

      def summarize(data)
        p = data[:player]
        pv = { :health => :healthy }
        pv[:name] = (p.name rescue "?").to_s
        pv[:gender] = (p.female? ? :female : (p.male? ? :male : :other)) rescue :other
        pv[:money] = (p.money rescue 0).to_i
        pv[:badges] = (p.badge_count rescue 0).to_i
        pv[:owned] = (p.pokedex.owned_count rescue nil)
        pv[:seen] = (p.pokedex.seen_count rescue nil)
        rate = (::Graphics.frame_rate rescue 40).to_f
        pv[:seconds] = (data[:frame_count].to_i / [rate, 1].max).to_i
        pv[:map_id] = (data[:map_factory].map.map_id rescue nil)
        pv[:map] = map_name(pv[:map_id])
        pv[:saved_at] = (p.last_time_saved rescue nil)
        switches = data[:switches]
        sw = ->(id) { switches.respond_to?(:[]) && (switches[id] rescue false) ? true : false }
        # Shown As (the lowest used) and the Debug Run Tag (Difficulty.rb)
        if defined?(Reloaded::Difficulty)
          pv[:difficulty_index] = Reloaded::Difficulty.shown_in(p, sw)
          pv[:difficulty] = Reloaded::Difficulty.shown_name(pv[:difficulty_index])
          pv[:debug] = Reloaded::Difficulty.debug_in(data, sw)
        else
          pv[:difficulty] = difficulty(p)
          pv[:difficulty_index] = ((p.lowest_difficulty rescue nil) || (p.selected_difficulty rescue nil))
        end
        pv[:mode] = mode_of(sw, data[:variables])
        pv[:randomized] = sw.call(SWITCH_RANDOMIZED)
        pv[:test_of] = test_of(data) if respond_to?(:test_of)
        pv[:player_id] = (p.id rescue nil)
        pv[:save_count] = (data[:game_system].save_count rescue nil)
        pv[:version] = data[:game_version]
        pv[:party] = (Array(p.party).compact rescue [])
        if defined?(::SaveData) && ::SaveData.respond_to?(:valid?) && pv[:version].to_s == current_version &&
           !(::SaveData.valid?(data) rescue true)
          pv[:health] = :check
          pv[:problem] = "Some of its parts aren't what the game expects."
        end
        # the Save Checker's quick part: what the game hasn't got in the
        # party, the boxes, the Day Care and the bag (the badge only says so)
        if pv[:health] == :healthy && defined?(Reloaded::SaveCheck::Content)
          missing = (Reloaded::SaveCheck::Content.scan(data, :quick => true) rescue [])
          unless missing.empty?
            pv[:health] = :check
            pv[:problem] = Reloaded::SaveCheck.badge_problem(missing)
            pv[:missing] = missing.length
          end
        end
        return pv
      end

      # What the game has now (a mod switched on or off changes it), so a
      # kept preview's health is worked out again.
      def content_stamp
        return "" unless defined?(::GameData::Species::DATA)
        return "#{::GameData::Species::DATA.size}.#{(::GameData::Item::DATA.size rescue 0)}.#{(::GameData::Move::DATA.size rescue 0)}"
      end

      # Forget what's known about file (it changed).
      def forget(file)
        @previews.delete(file)
      end

      #------------------------------------------------------------------------
      # Backups (KIF Beta's: backups\<slot>\<slot>_<stamp>[_name].rxdata)
      #------------------------------------------------------------------------
      # Newest first: [{ :path, :time, :name (nil, or the name), :auto }]
      def backups(slot)
        folder = File.join(dir, BACKUPS, slot.to_s)
        return [] unless File.directory?(folder)
        pattern = /\A#{Regexp.escape(slot.to_s)}_(\d{14})(?:_(.+))?\.rxdata\z/
        list = Dir.children(folder).map do |f|
          m = f.match(pattern)
          next unless m
          name = m[2]
          auto = name == "autosave"
          { :path => File.join(folder, f), :time => stamp_time(m[1]), :stamp => m[1], :name => auto ? nil : name, :auto => auto }
        end
        return list.compact.sort_by { |b| b[:stamp] }.reverse
      end

      # Names a backup (kept whatever the Backup Cap). Returns the new path.
      def name_backup(backup, name)
        clean = clean_name(name)
        return backup[:path] if clean.empty?
        slot = File.basename(File.dirname(backup[:path]))
        target = File.join(File.dirname(backup[:path]), "#{slot}_#{backup[:stamp]}_#{clean}.rxdata")
        return target if target == backup[:path]
        raise ArgumentError, "Another backup from that moment has that name" if File.exist?(target)
        File.rename(backup[:path], target)
        return target
      end

      # The backup takes the save's place (unpacked: a save the game plays
      # from stays plain); the save is kept first, as a backup named "Before
      # Restore".
      def restore_backup(slot, backup)
        raise ArgumentError, "That's the save being played" if slot.to_s == playing.to_s
        target = path(slot)
        backup_now(slot, "Before Restore") if File.file?(target)
        write_safely(Reloaded::SaveFile.bytes(backup[:path]), target)
        forget(target)
        return true
      end

      # A backup of the save as it is now (named, so the Backup Cap keeps it),
      # packed as KIF packs its own.
      def backup_now(slot, name = nil)
        source = path(slot)
        return nil unless File.file?(source)
        folder = File.join(dir, BACKUPS, slot.to_s)
        Reloaded::Paths.ensure_dir(folder)
        clean = clean_name(name)
        # two backups in one second: the next free second, so neither is lost
        t = Time.now
        file = nil
        loop do
          stamp = t.strftime("%Y%m%d%H%M%S")
          file = File.join(folder, clean.empty? ? "#{slot}_#{stamp}.rxdata" : "#{slot}_#{stamp}_#{clean}.rxdata")
          break unless File.exist?(file)
          t += 1
        end
        write_safely(Reloaded::SaveFile.pack(Reloaded::SaveFile.bytes(source)), file)
        return file
      end

      # The newest backup that reads whole, or nil (for a damaged save).
      def newest_good_backup(slot)
        return backups(slot).find { |b| health(b[:path])[0] != :damaged }
      end

      # Backup Cap: plain backups (not named, not autosaves) beyond cap go to
      # the Recycle Bin, oldest first; one that can't go there is kept. nil
      # cap keeps them all. Returns how many went.
      def trim_backups(slot, cap)
        return 0 unless cap
        plain = backups(slot).select { |b| b[:name].nil? && !b[:auto] }
        extra = plain[cap..-1] || []
        gone = extra.count { |b| Reloaded::Paths.recycle(b[:path]) }
        if gone < extra.length
          Reloaded::Log.warning_once("The Backup Cap couldn't put backups in the Recycle Bin, so they were kept", :saves)
        end
        return gone
      end

      #------------------------------------------------------------------------
      # Archive (the Deleted tab): DELETED SAVES\<slot>-<stamp>\
      #------------------------------------------------------------------------
      # Moves the save, its backups and Kanto Reloaded's copy of its data
      # there, with a manifest (old Kanto Reloaded's, with more).
      def archive(slot)
        raise ArgumentError, "That's the save being played" if slot.to_s == playing.to_s
        source = path(slot)
        raise ArgumentError, "#{slot} isn't there" unless File.file?(source)
        pv = preview(source, :party => false)
        stamp = Time.now.strftime("%Y%m%d-%H%M%S")
        target = File.join(dir, DELETED, "#{slot}-#{stamp}")
        n = 1
        target = File.join(dir, DELETED, "#{slot}-#{stamp}-#{n += 1}") while File.exist?(target)
        Reloaded::Paths.ensure_dir(target)
        files = []
        moved = []
        begin
          related(slot).each do |file|
            name = File.basename(file)
            files << { "original_name" => name, "archived_name" => name, "size" => File.size(file),
                       "modified_at" => File.mtime(file).utc.strftime("%Y-%m-%dT%H:%M:%SZ") }
            File.rename(file, File.join(target, name))
            moved << [File.join(target, name), file]
          end
          backups_dir = File.join(dir, BACKUPS, slot.to_s)
          if File.directory?(backups_dir)
            File.rename(backups_dir, File.join(target, BACKUPS))
            moved << [File.join(target, BACKUPS), backups_dir]
          end
          kr = kr_copy(slot)
          if File.file?(kr)
            File.rename(kr, File.join(target, File.basename(kr)))
            moved << [File.join(target, File.basename(kr)), kr]
          end
          meta = notes_entry(slot)
          manifest = { "schema_version" => 1, "slot" => slot.to_s, "archived_at" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
                       "files" => files,
                       "kanto_reloaded" => { "note" => meta["note"], "tag" => meta["tag"], "player_id" => meta["player_id"],
                                             "backups" => moved.any? { |a, _| File.basename(a) == BACKUPS },
                                             "name" => pv[:name], "map" => pv[:map], "seconds" => pv[:seconds] } }
          Reloaded::Paths.write_atomic(File.join(target, MANIFEST), Reloaded::JSON.generate(manifest, true))
        rescue StandardError
          moved.reverse_each { |a, b| File.rename(a, b) rescue nil }
          # only what this made: the manifest, and the folder once it's empty
          # (a file that couldn't go back stays, and the log says where)
          File.delete(File.join(target, MANIFEST)) rescue nil
          left = remove_if_empty(target)
          Reloaded::Log.warning("Deleting #{slot} stopped halfway; files still in #{target}: #{left.join(", ")}", :saves) unless left.empty?
          raise
        end
        set_notes_entry(slot, nil)
        forget(source)
        return target
      end

      # The Deleted tab: newest first, [{ :dir, :slot, :archived_at (Time),
      # :file (the save inside), :note, :tag, :name, :map, :seconds, :old }]
      def archived
        root = File.join(dir, DELETED)
        return [] unless File.directory?(root)
        list = Dir.children(root).map do |d|
          folder = File.join(root, d)
          next unless File.directory?(folder)
          m = read_manifest(folder)
          next unless m
          slot = m["slot"].to_s
          kr = m["kanto_reloaded"].is_a?(Hash) ? m["kanto_reloaded"] : {}
          file = File.join(folder, "#{slot}.rxdata")
          { :dir => folder, :slot => slot, :archived_at => iso_time(m["archived_at"]) || File.mtime(folder),
            :file => File.file?(file) ? file : nil, :note => kr["note"], :tag => kr["tag"], :name => kr["name"],
            :map => kr["map"], :seconds => kr["seconds"], :old => !m.key?("kanto_reloaded") }
        end
        return list.compact.sort_by { |a| a[:archived_at].to_f }.reverse
      end

      # Back to its slot, or to the first free one when that's taken (the
      # files renamed to it). Returns the slot.
      def restore_archive(entry, slot = nil)
        slot ||= File.file?(path(entry[:slot])) ? free_slot : entry[:slot]
        raise ArgumentError, "Every File slot is taken" unless slot
        raise ArgumentError, "#{slot} is taken" if File.file?(path(slot))
        old = entry[:slot]
        # Every file's new place first: one that's taken stops the restore
        # before anything moves (nothing in the save folder is written over)
        plan = Dir.children(entry[:dir]).reject { |name| name == MANIFEST }.map do |name|
          to = if name == BACKUPS then File.join(dir, BACKUPS, slot)
               elsif name.end_with?(".kr") then kr_copy(slot)
               else File.join(dir, name.sub(/\A#{Regexp.escape(old)}/, slot))
               end
          [File.join(entry[:dir], name), to, name]
        end
        taken = plan.find { |_, to, name| File.exist?(to) && !name.end_with?(".kr") }
        raise ArgumentError, "#{File.basename(taken[1])} is already there" if taken
        moved = []
        begin
          plan.each do |from, to, name|
            Reloaded::Paths.ensure_dir(File.dirname(to))
            # an old copy of Kanto Reloaded's data for this slot (its save is
            # gone) is kept beside it, not replaced
            Reloaded::Paths.set_aside(to, ".old") if name.end_with?(".kr") && File.exist?(to)
            File.rename(from, to)
            moved << [to, from]
            rename_backups(to, old, slot) if name == BACKUPS && old != slot
          end
        rescue StandardError
          moved.reverse_each { |a, b| File.rename(a, b) rescue nil }
          raise
        end
        m = read_manifest(entry[:dir]) || {}
        kr = m["kanto_reloaded"].is_a?(Hash) ? m["kanto_reloaded"] : {}
        set_notes_entry(slot, kr["note"] || kr["tag"] ? { "note" => kr["note"], "tag" => kr["tag"], "player_id" => kr["player_id"] } : nil)
        File.delete(File.join(entry[:dir], MANIFEST)) rescue nil
        left = remove_if_empty(entry[:dir])
        Reloaded::Log.warning("#{slot} is back; these stayed in #{entry[:dir]}: #{left.join(", ")}", :saves) unless left.empty?
        return slot
      end

      def delete_archive(entry)
        remove_tree(entry[:dir])
        return true
      end

      #------------------------------------------------------------------------
      # Notes and color tags
      #------------------------------------------------------------------------
      def note(slot, pv = nil)
        return entry_for(slot, pv)["note"].to_s
      end

      def tag(slot, pv = nil)
        return entry_for(slot, pv)["tag"]
      end

      def set_note(slot, text, pv = nil)
        update_entry(slot, pv) { |e| e["note"] = text.to_s.strip.empty? ? nil : text.to_s.strip[0, 200] }
      end

      def set_tag(slot, tag, pv = nil)
        update_entry(slot, pv) { |e| e["tag"] = tag && TAGS.any? { |n, _| n == tag } && tag != "None" ? tag : nil }
      end

      # [r, g, b] or nil
      def tag_rgb(tag)
        row = TAGS.find { |n, _| n == tag.to_s }
        return row ? row[1] : nil
      end

      private

      def entry_for(slot, pv)
        e = notes_entry(slot)
        pv ||= (File.file?(path(slot)) ? preview(path(slot), :party => false) : nil)
        # a new save in the slot (another player) doesn't take the old one's note
        return {} if e["player_id"] && pv && pv[:player_id] && e["player_id"] != pv[:player_id]
        return e
      end

      def update_entry(slot, pv)
        e = entry_for(slot, pv).dup
        yield e
        pv ||= (File.file?(path(slot)) ? preview(path(slot), :party => false) : nil)
        e["player_id"] = pv[:player_id] if pv && pv[:player_id]
        set_notes_entry(slot, e["note"] || e["tag"] ? e : nil)
      end

      def notes
        file = File.join(Reloaded::Paths.data_dir, NOTES_FILE)
        return {} unless File.file?(file)
        data = Reloaded::JSON.parse(Reloaded::Paths.read_text(file).to_s)
        return data.is_a?(Hash) && data["slots"].is_a?(Hash) ? data["slots"] : {}
      rescue StandardError => e
        Reloaded::Log.exception("Save notes couldn't be read", e, :saves)
        return {}
      end

      def notes_entry(slot)
        e = notes[slot.to_s]
        return e.is_a?(Hash) ? e : {}
      end

      def set_notes_entry(slot, entry)
        all = notes
        entry ? all[slot.to_s] = entry : all.delete(slot.to_s)
        Reloaded::Paths.write_atomic(File.join(Reloaded::Paths.data_dir, NOTES_FILE),
                                     Reloaded::JSON.generate({ "version" => 1, "slots" => all }, true))
      end

      #------------------------------------------------------------------------
      # Files
      #------------------------------------------------------------------------
      # The save and the files that go with it: <slot>.rxdata, its .bak, and
      # safe saving's leftovers.
      def related(slot)
        base = File.basename(path(slot))
        return Dir.children(dir).select { |f| f == base || f.start_with?(base + ".") }.map { |f| File.join(dir, f) }
          .select { |f| File.file?(f) }
      end

      # Kanto Reloaded's copy of the save's data (SaveStore).
      def kr_copy(slot)
        return File.join(Reloaded::Paths.data_dir, "Saves", "#{File.basename(path(slot))}.kr")
      end

      def rename_backups(folder, old, slot)
        Dir.children(folder).each do |f|
          next unless f.start_with?("#{old}_")
          to = Reloaded::Paths.free_name(File.join(folder, f.sub(/\A#{Regexp.escape(old)}_/, "#{slot}_")))
          File.rename(File.join(folder, f), to)
        end
      end

      def read_manifest(folder)
        file = File.join(folder, MANIFEST)
        return nil unless File.file?(file)
        m = Reloaded::JSON.parse(Reloaded::Paths.read_text(file).to_s)
        return m.is_a?(Hash) && m["slot"] ? m : nil
      rescue StandardError
        return nil
      end

      # Delete Forever (the Deleted tab, after its question): one deleted
      # save's folder, and only a folder inside DELETED SAVES.
      def remove_tree(path)
        root = File.expand_path(File.join(dir, DELETED)).downcase
        full = File.expand_path(path)
        raise ArgumentError, "Only a folder in #{DELETED} is deleted for good" unless full.downcase.start_with?(root + "/")
        remove_tree_in(full)
      end

      def remove_tree_in(path)
        return unless File.exist?(path)
        if File.directory?(path)
          Dir.children(path).each { |c| remove_tree_in(File.join(path, c)) }
          Dir.rmdir(path)
        else
          File.delete(path)
        end
      end

      # A folder this code made, removed only when nothing is left in it.
      # Returns what's still inside (empty when it went).
      def remove_if_empty(path)
        return [] unless File.directory?(path)
        left = Dir.children(path)
        Dir.rmdir(path) if left.empty?
        return left
      rescue StandardError
        return Dir.children(path) rescue []
      end

      # Written through a temporary file that must read back as a whole save,
      # then put in place.
      def write_safely(bytes, to)
        tmp = to + Reloaded::SafeSave::TMP
        File.open(tmp, "wb") do |f|
          f.write(bytes)
          f.flush
          f.fsync rescue nil
        end
        unless File.size(tmp) == bytes.bytesize && Reloaded::SafeSave.whole?(tmp)
          File.delete(tmp) rescue nil
          raise IOError, "the copy didn't read back whole"
        end
        Reloaded::SafeSave.replace(tmp, to)
      end

      def clean_name(name)
        return name.to_s.gsub(/[\\\/:*?"<>|]/, "").strip[0, 40].to_s
      end

      def stamp(file)
        return nil unless File.file?(file)
        return "#{File.basename(file)}|#{File.size(file)}|#{File.mtime(file).to_i}"
      end

      # "2026-10-18T12:00:00Z" (the manifest's), or nil
      def iso_time(text)
        m = text.to_s.match(/\A(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)/)
        return m ? Time.utc(*m.captures.map(&:to_i)).localtime : nil
      end

      def stamp_time(s)
        return Time.local(s[0, 4].to_i, s[4, 2].to_i, s[6, 2].to_i, s[8, 2].to_i, s[10, 2].to_i, s[12, 2].to_i)
      rescue StandardError
        return nil
      end

      def map_name(id)
        return nil unless id
        name = defined?(pbGetMapNameFromId) ? (pbGetMapNameFromId(id) rescue nil) : nil
        return name.to_s.empty? ? "Map #{id}" : name.to_s
      end

      # The lowest difficulty the save has used, as PIF's own load screen
      # shows it (013_UI_Load.rb), else the one it's on
      def difficulty(p)
        index = (p.lowest_difficulty rescue nil) || (p.selected_difficulty rescue nil)
        return nil if index.nil?
        return (getDisplayDifficultyFromIndex(index) rescue nil) || ["Easy", "Normal", "Hard"][index.to_i]
      end

      def current_version
        return defined?(::Settings::GAME_VERSION_NUMBER) ? ::Settings::GAME_VERSION_NUMBER.to_s : ""
      end

      # The run's mode, as PIF's getCurrentGameModeSymbol reads it (each
      # later one wins): Classic, Remix, Expert, Species, Randomized,
      # Legendary. A randomized run says Randomized whatever it started as.
      def mode_of(sw, variables)
        mode = "Classic"
        mode = "Remix" if sw.call(SWITCH_REMIX)
        mode = "Expert" if sw.call(SWITCH_EXPERT)
        species = (variables[VAR_SPECIES] rescue nil)
        mode = "Species" if sw.call(SWITCH_SPECIES) && species.is_a?(Integer) && species > 0
        mode = "Randomized" if sw.call(SWITCH_RANDOMIZED)
        mode = "Legendary" if sw.call(SWITCH_LEGENDARY)
        return mode
      end

      # The newest previews in memory (their parties too); the light part
      # of every one in Save Previews.json.
      def remember(file, pv)
        @previews[file] = pv
        @parties.delete(file)
        @parties << file
        while @parties.length > PARTIES_KEPT
          old = @parties.shift
          @previews[old] = @previews[old].reject { |k, _| k == :party } if @previews[old]
        end
        light = pv.reject { |k, _| k == :party || k == :stamp }
        light[:saved_at] = light[:saved_at].to_i if light[:saved_at].is_a?(Time)
        kept = kept_previews
        kept[pv[:stamp]] = light
        @kept_dirty = true
        save_kept_previews if kept.length % 4 == 0 || light[:health] != :healthy
      end

      def kept_previews
        return @kept if @kept
        @kept = {}
        file = File.join(Reloaded::Paths.data_dir, PREVIEWS_FILE)
        if File.file?(file)
          data = Reloaded::JSON.parse(Reloaded::Paths.read_text(file).to_s) rescue nil
          (data.is_a?(Hash) ? data : {}).each do |k, v|
            next unless v.is_a?(Hash)
            pv = {}
            v.each { |a, b| pv[a.to_sym] = b }
            pv[:health] = pv[:health].to_s.to_sym
            pv[:gender] = pv[:gender].to_s.to_sym if pv[:gender]
            pv[:saved_at] = Time.at(pv[:saved_at].to_i) if pv[:saved_at]
            @kept[k] = pv
          end
        end
        return @kept
      end

      public

      # Writes the kept previews (the Save Manager calls it when it closes).
      def save_kept_previews
        return unless @kept && @kept_dirty
        alive = {}
        @kept.each do |k, v|
          alive[k] = v.map { |a, b| [a.to_s, b.is_a?(Symbol) ? b.to_s : (b.is_a?(Time) ? b.to_i : b)] }.to_h
        end
        Reloaded::Paths.write_atomic(File.join(Reloaded::Paths.data_dir, PREVIEWS_FILE), Reloaded::JSON.generate(alive))
        @kept_dirty = false
      rescue StandardError => e
        Reloaded::Log.exception("Save previews couldn't be kept", e, :saves)
      end

      # For tests: forget everything known.
      def reset
        @previews = {}
        @parties = []
        @kept = nil
        @kept_dirty = false
      end
    end
  end
end
