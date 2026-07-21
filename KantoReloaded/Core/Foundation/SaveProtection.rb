#==============================================================================
# Kanto Reloaded Save Protection
#==============================================================================
# Tracks the source of a loaded KR save bucket and creates a verified backup
# before a KR schema migration. KIF remains responsible for normal save writes.
#==============================================================================

module KantoReloaded
  module SaveProtection
    COPY_CHUNK_SIZE = 64 * 1024
    SOURCE_TRACK_LIMIT = 32

    @save_sources = {}
    @migration_backups = {}
    @installed = false

    class << self
      def install
        return true if @installed
        install_source_tracker
        @installed = true
        KantoReloaded::Log.info("Save migration protection ready", :save_data) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        @installed = false
        KantoReloaded::Log.exception("Save protection installation failed", e, channel: :save_data) if defined?(KantoReloaded::Log)
        false
      end

      def track_save_source(save_data, file_path)
        return save_data unless save_data.is_a?(Hash)
        bucket = save_data[:kanto_reloaded] || save_data["kanto_reloaded"]
        return save_data unless bucket.is_a?(Hash)
        source = File.expand_path(file_path.to_s)
        return save_data unless File.file?(source)
        @save_sources[bucket.object_id] = source
        trim_save_sources
        save_data
      rescue StandardError => e
        KantoReloaded::Log.exception("Save source tracking failed", e, channel: :save_data) if defined?(KantoReloaded::Log)
        save_data
      end

      def backup_before_migration(bucket, options = {})
        source = @save_sources[bucket.object_id]
        return { :status => :not_applicable } if source.to_s.empty? || !File.file?(source)
        from = options[:from].to_i
        to = options[:to].to_i
        key = migration_backup_key(source, from, to)
        return { :status => :already_created, :source => source } if @migration_backups[key]

        destination = backup_savefile(source)
        return { :status => :failed, :source => source } unless destination
        @migration_backups[key] = destination
        slot = safe_slot_name(File.basename(source, File.extname(source)))
        KantoReloaded::Log.info(
          "Created pre-migration save backup slot=#{slot} schema=#{from}->#{to}",
          :save_data
        ) if defined?(KantoReloaded::Log)
        { :status => :created, :source => source, :backup => destination }
      rescue StandardError => e
        KantoReloaded::Log.exception("Pre-migration save backup failed", e, channel: :save_data) if defined?(KantoReloaded::Log)
        { :status => :failed, :source => source, :error => e }
      end

      def backup_savefile(save_path)
        source = File.expand_path(save_path.to_s)
        return nil unless File.file?(source)
        slot = safe_slot_name(File.basename(source, File.extname(source)))
        root = File.join(File.dirname(source), "backups")
        slot_root = File.join(root, slot)
        ensure_directory(root)
        ensure_directory(slot_root)
        destination = unique_backup_path(slot_root, slot, File.extname(source))
        copy_file(source, destination)
        unless File.size(source) == File.size(destination)
          delete_file(destination)
          raise "Backup verification failed for slot #{slot}."
        end
        prune_backups(slot_root, File.extname(source))
        destination
      rescue StandardError => e
        KantoReloaded::Log.exception("Save backup failed for slot #{safe_slot_name(save_path)}", e, channel: :save_data) if defined?(KantoReloaded::Log)
        nil
      end

      private

      def install_source_tracker
        return false unless defined?(::SaveData) && defined?(KantoReloaded::Hooks)
        KantoReloaded::Hooks.wrap(
          ::SaveData, :read_from_file, :save_protection_source, :singleton => true
        ) do |hook, file_path, *_arguments|
          save_data = hook.call
          KantoReloaded::SaveProtection.track_save_source(save_data, file_path)
        end
      end

      def copy_file(source, destination)
        File.open(source, "rb") do |input|
          File.open(destination, "wb") do |output|
            while (chunk = input.read(COPY_CHUNK_SIZE))
              output.write(chunk)
            end
            output.flush
            output.fsync if output.respond_to?(:fsync)
          end
        end
      end

      def prune_backups(root, extension)
        limit = defined?(::Settings::SAVEFILE_NB_BACKUPS) ? ::Settings::SAVEFILE_NB_BACKUPS.to_i : 10
        limit = 1 if limit < 1
        backups = directory_files(root, extension).sort_by do |path|
          [(File.mtime(path).to_f rescue 0.0), File.basename(path)]
        end
        backups.first([backups.length - limit, 0].max).each { |path| delete_file(path) }
      rescue StandardError => e
        KantoReloaded::Log.exception("Save backup pruning failed", e, channel: :save_data) if defined?(KantoReloaded::Log)
      end

      def unique_backup_path(root, slot, extension)
        suffix = extension.to_s.empty? ? ".rxdata" : extension.to_s
        timestamp = Time.now.strftime("%Y%m%d-%H%M%S")
        base = File.join(root, "#{slot}_#{timestamp}")
        candidate = "#{base}#{suffix}"
        index = 2
        while File.exist?(candidate)
          candidate = "#{base}_#{index}#{suffix}"
          index += 1
        end
        candidate
      end

      def migration_backup_key(source, from, to)
        modified = File.mtime(source).to_f rescue 0.0
        [source.to_s.downcase, modified, from.to_i, to.to_i]
      end

      def trim_save_sources
        overflow = @save_sources.length - SOURCE_TRACK_LIMIT
        return if overflow <= 0
        @save_sources.keys.first(overflow).each { |key| @save_sources.delete(key) }
      end

      def safe_slot_name(value)
        basename = File.basename(value.to_s, File.extname(value.to_s))
        result = basename.gsub(/[^A-Za-z0-9_-]+/, "_")
        result.empty? ? "Save" : result
      rescue
        "Save"
      end

      def ensure_directory(path)
        Dir.mkdir(path) unless Dir.exist?(path)
      end

      def directory_files(root, extension)
        return [] unless Dir.exist?(root)
        suffix = extension.to_s.downcase
        Dir.entries(root).each_with_object([]) do |name, files|
          next if name == "." || name == ".."
          path = File.join(root, name)
          files << path if File.file?(path) && (suffix.empty? || name.downcase.end_with?(suffix))
        end
      end

      def delete_file(path)
        File.delete(path) if path && File.file?(path)
      rescue
        nil
      end
    end
  end
end

KantoReloaded::SaveProtection.install if defined?(KantoReloaded::SaveProtection)
