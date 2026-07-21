#==============================================================================
# Kanto Reloaded - Save Manager Archive Service
#==============================================================================

module KantoReloaded
  module SaveManager
    module SaveArchive
      ARCHIVE_FOLDER = "DELETED SAVES"
      MANIFEST_FILE = "manifest.json"
      MANIFEST_VERSION = 1

      class << self
        def available?
          defined?(::SaveData) && ::SaveData.const_defined?(:SAVE_DIR) &&
            ::SaveData.respond_to?(:get_full_path)
        end

        def active_entries
          return [] unless available?
          save_slots.each_with_object([]) do |slot, entries|
            path = ::SaveData.get_full_path(slot)
            next unless File.file?(path)
            files = related_files(slot, save_root)
            entries << build_entry(
              :id => "active:#{slot}", :kind => :active, :slot => slot,
              :root => save_root, :files => file_records(files),
              :main_path => path, :archived_at => nil, :legacy => false
            )
          end
        rescue StandardError => e
          log_exception("Could not scan active saves", e)
          []
        end

        def archived_entries
          return [] unless available? && Dir.exist?(archive_root)
          entries = archive_directories
          entries.concat(legacy_loose_archives)
          entries.sort_by do |entry|
            [-(entry[:archived_time] || Time.at(0)).to_f, entry[:label].to_s.downcase]
          end
        rescue StandardError => e
          log_exception("Could not scan deleted saves", e)
          []
        end

        def archive(slot)
          normalized_slot = valid_slot(slot)
          return failure(:invalid_slot, "That save slot is not valid.") unless normalized_slot
          source_files = related_files(normalized_slot, save_root)
          main_path = ::SaveData.get_full_path(normalized_slot)
          return failure(:missing, "That save file no longer exists.") unless File.file?(main_path)
          return failure(:missing, "No related save files were found.") if source_files.empty?

          ensure_directory(archive_root)
          destination_root = unique_archive_directory(normalized_slot)
          ensure_directory(destination_root)
          records = file_records(source_files)
          manifest = {
            "schema_version" => MANIFEST_VERSION,
            "slot" => normalized_slot,
            "archived_at" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "files" => records
          }
          write_manifest(destination_root, manifest)
          moved = move_records(records, save_root, destination_root)
          entry = entry_from_directory(destination_root)
          success(:archived, moved.length, entry)
        rescue StandardError => e
          rollback_records(moved || [], destination_root, save_root)
          remove_empty_archive(destination_root)
          log_exception("Could not archive save #{safe_slot_label(slot)}", e)
          failure(:failed, "The save could not be archived. No files were intentionally removed.", e)
        end

        def restore(entry)
          return failure(:invalid_archive, "That deleted save is not restorable.") unless restorable?(entry)
          records = Array(entry[:files])
          source_root = File.expand_path(entry[:root].to_s)
          unless valid_archive_root?(source_root) && records.all? { |record| valid_record?(record) }
            return failure(:unsafe_archive, "That deleted save contains unsafe file paths and cannot be restored.")
          end
          collisions = records.select do |record|
            destination = direct_child(save_root, record["original_name"])
            destination.nil? || File.exist?(destination)
          end
          unless collisions.empty?
            return failure(
              :collision,
              "A save or backup with the same name already exists. Archive that active save before restoring this one."
            )
          end

          moved = move_records(records, source_root, save_root, true)
          remove_archive_container(entry)
          success(:restored, moved.length, nil)
        rescue StandardError => e
          rollback_records(moved || [], save_root, source_root, true)
          log_exception("Could not restore deleted save", e)
          failure(:failed, "The deleted save could not be restored. Moved files were rolled back where possible.", e)
        end

        def permanently_delete(entry)
          return failure(:invalid_archive, "That deleted save entry is no longer valid.") unless entry.is_a?(Hash)
          return failure(:unsafe_archive, "That deleted save contains unsafe file paths.") unless valid_archive_root?(entry[:root])
          return failure(:unsafe_archive, "That deleted save contains unsafe file paths.") unless Array(entry[:files]).all? { |record| valid_record?(record) }
          deleted = 0
          Array(entry[:files]).each do |record|
            path = archive_record_path(entry, record)
            next unless path && File.file?(path)
            File.delete(path)
            deleted += 1
          end
          remove_archive_container(entry)
          success(:deleted, deleted, nil)
        rescue StandardError => e
          log_exception("Could not permanently delete archived save", e)
          failure(:failed, "Some archived files could not be permanently deleted.", e)
        end

        def empty_archive
          deleted = 0
          failures = 0
          archived_entries.each do |entry|
            result = permanently_delete(entry)
            if result[:ok]
              deleted += result[:count].to_i
            else
              failures += 1
            end
          end
          return failure(:partial, "Some archived files could not be deleted.") if failures > 0
          success(:emptied, deleted, nil)
        end

        def deleted_disk_info
          entries = archived_entries
          {
            :groups => entries.length,
            :count => entries.inject(0) { |sum, entry| sum + entry[:file_count].to_i },
            :bytes => entries.inject(0) { |sum, entry| sum + entry[:total_bytes].to_i }
          }
        rescue
          { :groups => 0, :count => 0, :bytes => 0 }
        end

        def archive_root
          File.expand_path(File.join(save_root, ARCHIVE_FOLDER))
        end

        def save_root
          return File.expand_path(::SaveData::SAVE_DIR.to_s) if available?
          File.expand_path(".")
        end

        def format_size(bytes)
          value = bytes.to_i
          return "0 bytes" if value <= 0
          return "#{value} bytes" if value < 1024
          kilobytes = value / 1024.0
          return "#{kilobytes.round(1)} KB" if kilobytes < 1024
          megabytes = kilobytes / 1024.0
          return "#{megabytes.round(2)} MB" if megabytes < 1024
          "#{(megabytes / 1024.0).round(2)} GB"
        end

        def restorable?(entry)
          entry.is_a?(Hash) && entry[:kind] == :archive &&
            valid_archive_root?(entry[:root]) && !entry[:slot].to_s.empty? &&
            Array(entry[:files]).all? { |record| valid_record?(record) } &&
            Array(entry[:files]).any? do |record|
              record["original_name"].to_s == "#{entry[:slot]}.rxdata"
            end
        end

        private

        def save_slots
          auto = ::SaveData.const_defined?(:AUTO_SLOTS) ? Array(::SaveData::AUTO_SLOTS) : []
          manual = ::SaveData.const_defined?(:MANUAL_SLOTS) ? Array(::SaveData::MANUAL_SLOTS) : []
          (auto + manual).map(&:to_s).uniq
        end

        def valid_slot(value)
          text = value.to_s
          save_slots.include?(text) ? text : nil
        end

        def related_files(slot, root)
          return [] unless Dir.exist?(root)
          main_name = "#{slot}.rxdata"
          names = Dir.entries(root).select do |name|
            next false if name == "." || name == ".."
            next false unless related_filename?(slot, name)
            File.file?(File.join(root, name))
          end
          names.sort_by do |name|
            priority = name == main_name ? 0 : (name == "#{main_name}.bak" ? 1 : 2)
            [priority, name.downcase]
          end.map { |name| File.expand_path(File.join(root, name)) }
        end

        def related_filename?(slot, name)
          main_name = "#{slot}.rxdata"
          return true if name == main_name || name == "#{main_name}.bak"
          return false unless name.start_with?("#{slot} ") || name.start_with?("#{slot} - ")
          lowered = name.downcase
          lowered.end_with?(".rxdata") || lowered.end_with?(".rxdata.bak")
        end

        def file_records(paths)
          Array(paths).map do |path|
            {
              "original_name" => File.basename(path),
              "archived_name" => File.basename(path),
              "size" => (File.size(path) rescue 0),
              "modified_at" => ((File.mtime(path).utc.strftime("%Y-%m-%dT%H:%M:%SZ")) rescue "")
            }
          end
        end

        def build_entry(data)
          files = Array(data[:files])
          main_path = data[:main_path]
          metadata = read_save_metadata(main_path)
          archived_time = parse_time(data[:archived_at])
          slot = data[:slot].to_s
          label = if data[:kind] == :archive
                    stamp = archived_time ? archived_time.strftime("%Y-%m-%d %H:%M") : "Unknown date"
                    slot.empty? ? "Unrecognized Archive" : "#{slot} - #{stamp}"
                  else
                    slot
                  end
          {
            :id => data[:id].to_s,
            :kind => data[:kind],
            :slot => slot,
            :label => label,
            :root => File.expand_path(data[:root].to_s),
            :files => files,
            :file_count => files.length,
            :total_bytes => files.inject(0) { |sum, record| sum + record["size"].to_i },
            :archived_at => data[:archived_at].to_s,
            :archived_time => archived_time,
            :legacy => !!data[:legacy],
            :metadata => metadata,
            :main_path => main_path
          }
        end

        def read_save_metadata(path)
          result = {
            :trainer_name => "Unknown Trainer", :location => "Unknown Location",
            :play_time => "Unknown", :saved_at => "Unknown", :party => []
          }
          return result unless path && File.file?(path)
          save_data = ::SaveData.read_from_file(path)
          return result unless save_data.is_a?(Hash)
          player = save_data[:player] || save_data["player"]
          result[:trainer_name] = player.name.to_s if player && player.respond_to?(:name)
          result[:party] = Array(player.party).compact if player && player.respond_to?(:party)
          saved = player.last_time_saved if player && player.respond_to?(:last_time_saved)
          result[:saved_at] = saved.strftime("%Y-%m-%d %H:%M") if saved.respond_to?(:strftime)
          frames = save_data[:frame_count] || save_data["frame_count"]
          result[:play_time] = format_play_time(frames)
          factory = save_data[:map_factory] || save_data["map_factory"]
          map_id = factory.map.map_id if factory && factory.respond_to?(:map) && factory.map
          if map_id && defined?(pbGetMapNameFromId)
            result[:location] = pbGetMapNameFromId(map_id).to_s
          end
          result
        rescue StandardError => e
          log_exception("Could not inspect save metadata", e)
          result
        end

        def format_play_time(frames)
          return "Unknown" if frames.nil?
          frame_rate = defined?(Graphics) && Graphics.respond_to?(:frame_rate) ? Graphics.frame_rate.to_i : 40
          frame_rate = 40 if frame_rate <= 0
          seconds = frames.to_i / frame_rate
          hours = seconds / 3600
          minutes = (seconds / 60) % 60
          hours > 0 ? "#{hours}h #{minutes}m" : "#{minutes}m"
        rescue
          "Unknown"
        end

        def archive_directories
          Dir.entries(archive_root).each_with_object([]) do |name, entries|
            next if name == "." || name == ".."
            path = File.join(archive_root, name)
            next unless File.directory?(path)
            entry = entry_from_directory(path)
            entries << entry if entry
          end
        end

        def entry_from_directory(path)
          manifest = read_manifest(path)
          files = directory_file_records(path, manifest)
          return nil if files.empty?
          slot = manifest["slot"].to_s
          slot = infer_slot(files.map { |record| record["original_name"] }) if valid_slot(slot).nil?
          archived_at = manifest["archived_at"].to_s
          archived_at = (File.mtime(path).utc.strftime("%Y-%m-%dT%H:%M:%SZ") rescue "") if archived_at.empty?
          main_record = files.find { |record| record["original_name"] == "#{slot}.rxdata" }
          main_path = main_record ? File.join(path, main_record["archived_name"]) : nil
          build_entry(
            :id => "archive:#{File.basename(path)}", :kind => :archive,
            :slot => slot, :root => path, :files => files,
            :main_path => main_path, :archived_at => archived_at,
            :legacy => manifest.empty?
          )
        end

        def read_manifest(path)
          manifest_path = File.join(path, MANIFEST_FILE)
          return {} unless File.file?(manifest_path)
          value = KantoReloaded::Platform.parse_json(KantoReloaded::Platform.read_text(manifest_path))
          value.is_a?(Hash) ? value : {}
        rescue StandardError => e
          log_exception("Could not read deleted-save manifest", e)
          {}
        end

        def directory_file_records(path, manifest)
          known = {}
          Array(manifest["files"] || manifest[:files]).each do |record|
            next unless record.is_a?(Hash)
            archived_name = (record["archived_name"] || record[:archived_name]).to_s
            original_name = (record["original_name"] || record[:original_name]).to_s
            next if archived_name.empty? || original_name.empty?
            known[archived_name] = {
              "original_name" => original_name,
              "archived_name" => archived_name,
              "size" => (record["size"] || record[:size]).to_i,
              "modified_at" => (record["modified_at"] || record[:modified_at]).to_s
            }
          end
          Dir.entries(path).each_with_object([]) do |name, records|
            next if name == "." || name == ".." || name == MANIFEST_FILE
            file_path = File.join(path, name)
            next unless File.file?(file_path)
            record = known[name] || {
              "original_name" => name, "archived_name" => name,
              "size" => (File.size(file_path) rescue 0), "modified_at" => ""
            }
            record["size"] = File.size(file_path) rescue record["size"].to_i
            records << record
          end
        end

        def legacy_loose_archives
          names = Dir.entries(archive_root).select do |name|
            File.file?(File.join(archive_root, name)) && name != MANIFEST_FILE
          end
          consumed = {}
          entries = []
          save_slots.each do |slot|
            matches = names.select { |name| related_filename?(slot, name) }
            next if matches.empty?
            matches.each { |name| consumed[name] = true }
            records = matches.sort.map do |name|
              path = File.join(archive_root, name)
              {
                "original_name" => name, "archived_name" => name,
                "size" => (File.size(path) rescue 0), "modified_at" => ""
              }
            end
            main_path = File.join(archive_root, "#{slot}.rxdata")
            archived_at = (File.mtime(main_path).utc.strftime("%Y-%m-%dT%H:%M:%SZ") rescue "")
            entries << build_entry(
              :id => "legacy:#{slot}", :kind => :archive, :slot => slot,
              :root => archive_root, :files => records,
              :main_path => main_path, :archived_at => archived_at, :legacy => true
            )
          end
          unknown = names.reject { |name| consumed[name] }
          unless unknown.empty?
            records = unknown.map do |name|
              path = File.join(archive_root, name)
              {
                "original_name" => name, "archived_name" => name,
                "size" => (File.size(path) rescue 0), "modified_at" => ""
              }
            end
            entries << build_entry(
              :id => "legacy:unrecognized", :kind => :archive, :slot => "",
              :root => archive_root, :files => records, :main_path => nil,
              :archived_at => "", :legacy => true
            )
          end
          entries
        end

        def infer_slot(names)
          save_slots.find { |slot| names.include?("#{slot}.rxdata") }.to_s
        end

        def unique_archive_directory(slot)
          safe_slot = slot.gsub(/[^A-Za-z0-9_-]+/, "_")
          timestamp = Time.now.strftime("%Y%m%d-%H%M%S")
          base = File.join(archive_root, "#{safe_slot}-#{timestamp}")
          candidate = base
          index = 2
          while File.exist?(candidate)
            candidate = "#{base}-#{index}"
            index += 1
          end
          candidate
        end

        def write_manifest(root, manifest)
          payload = KantoReloaded::Platform.generate_json(manifest)
          path = File.join(root, MANIFEST_FILE)
          temporary = path + ".tmp"
          File.open(temporary, "wb") do |file|
            file.write(payload)
            file.flush
            file.fsync if file.respond_to?(:fsync) rescue nil
          end
          File.delete(path) if File.file?(path)
          File.rename(temporary, path)
          true
        ensure
          File.delete(temporary) if defined?(temporary) && File.file?(temporary) rescue nil
        end

        def move_records(records, source_root, destination_root, restoring = false)
          moved = []
          Array(records).each do |record|
            source_name = restoring ? record["archived_name"] : record["original_name"]
            destination_name = restoring ? record["original_name"] : record["archived_name"]
            source = direct_child(source_root, source_name)
            destination = direct_child(destination_root, destination_name)
            raise "Unsafe save path" unless source && destination
            next unless File.file?(source)
            raise "Save destination already exists" if File.exist?(destination)
            File.rename(source, destination)
            moved << record
          end
          moved
        rescue StandardError
          rollback_records(moved, destination_root, source_root, restoring)
          raise
        end

        def rollback_records(records, source_root, destination_root, restoring = false)
          Array(records).reverse_each do |record|
            source_name = restoring ? record["original_name"] : record["archived_name"]
            destination_name = restoring ? record["archived_name"] : record["original_name"]
            source = direct_child(source_root, source_name)
            destination = direct_child(destination_root, destination_name)
            File.rename(source, destination) if source && destination && File.file?(source) && !File.exist?(destination)
          rescue StandardError
            nil
          end
        end

        def archive_record_path(entry, record)
          return nil unless valid_archive_root?(entry[:root]) && valid_record?(record)
          direct_child(entry[:root], record["archived_name"])
        end

        def valid_record?(record)
          return false unless record.is_a?(Hash)
          original = record["original_name"].to_s
          archived = record["archived_name"].to_s
          !original.empty? && !archived.empty? &&
            File.basename(original) == original && File.basename(archived) == archived
        rescue
          false
        end

        def valid_archive_root?(root)
          candidate = File.expand_path(root.to_s)
          comparable(candidate) == comparable(archive_root) ||
            KantoReloaded::Platform.path_within?(candidate, archive_root)
        rescue
          false
        end

        def direct_child(root, name)
          return nil if name.to_s.empty? || File.basename(name.to_s) != name.to_s
          expanded_root = File.expand_path(root.to_s)
          path = File.expand_path(File.join(expanded_root, name.to_s))
          return nil unless comparable(File.dirname(path)) == comparable(expanded_root)
          path
        rescue
          nil
        end

        def comparable(path)
          value = File.expand_path(path.to_s).tr("\\", "/")
          if defined?(KantoReloaded::Platform) &&
             (KantoReloaded::Platform.windows? || KantoReloaded::Platform.proton?)
            value.downcase
          else
            value
          end
        end

        def remove_archive_container(entry)
          root = File.expand_path(entry[:root].to_s)
          return true if comparable(root) == comparable(archive_root)
          return false unless KantoReloaded::Platform.path_within?(root, archive_root)
          manifest = File.join(root, MANIFEST_FILE)
          File.delete(manifest) if File.file?(manifest)
          Dir.rmdir(root) if Dir.exist?(root) && (Dir.entries(root) - [".", ".."]).empty?
          true
        end

        def remove_empty_archive(root)
          return unless root && Dir.exist?(root)
          manifest = File.join(root, MANIFEST_FILE)
          File.delete(manifest) if File.file?(manifest)
          Dir.rmdir(root) if (Dir.entries(root) - [".", ".."]).empty?
        rescue
          nil
        end

        def ensure_directory(path)
          return true if Dir.exist?(path)
          parent = File.dirname(path)
          ensure_directory(parent) unless parent == path || Dir.exist?(parent)
          Dir.mkdir(path)
          true
        end

        def parse_time(value)
          text = value.to_s
          return nil if text.empty?
          Time.parse(text)
        rescue
          begin
            Time.utc(*text.scan(/\d+/).first(6).map(&:to_i))
          rescue
            nil
          end
        end

        def success(status, count, entry)
          { :ok => true, :status => status, :count => count.to_i, :entry => entry }
        end

        def failure(status, message, error = nil)
          { :ok => false, :status => status, :count => 0, :message => message.to_s, :error => error }
        end

        def safe_slot_label(value)
          text = value.to_s.gsub(/[^A-Za-z0-9 _-]+/, "")
          text.empty? ? "unknown" : text
        end

        def log_exception(message, error)
          KantoReloaded::Log.exception(message, error, channel: :save_manager) if defined?(KantoReloaded::Log)
        rescue
          nil
        end
      end
    end
  end
end
