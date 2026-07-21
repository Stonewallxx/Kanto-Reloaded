#==============================================================================
# Kanto Reloaded Global Settings
#==============================================================================
# Persists settings that apply across every save file. This storage is kept
# separate from the KR save bucket and is written immediately when changed.
#==============================================================================

module KantoReloaded
  module GlobalSettings
    SCHEMA_VERSION = 1
    FILE_NAME = "KantoReloadedSettings.json"

    @data = nil
    @loaded = false
    @storage_path = nil

    class << self
      def boot
        return true if @loaded
        @data = default_data
        path = storage_path
        recover_interrupted_write(path)
        if File.file?(path)
          parsed = KantoReloaded::Platform.parse_json(KantoReloaded::Platform.read_text(path))
          @data = normalize_data(parsed)
        end
        @loaded = true
        true
      rescue StandardError => e
        @data = default_data
        @loaded = true
        log_exception("Could not load global settings", e)
        false
      end

      def values
        boot unless @loaded
        deep_copy(@data["values"])
      end

      def stored?(key)
        boot unless @loaded
        @data["values"].has_key?(key.to_s)
      end

      def get(key, fallback = nil)
        boot unless @loaded
        values = @data["values"]
        return deep_copy(values[key.to_s]) if values.has_key?(key.to_s)
        fallback
      end

      def set(key, value)
        boot unless @loaded
        candidate = deep_copy(@data)
        candidate["values"][key.to_s] = deep_copy(value)
        return false unless persist(candidate)
        @data = candidate
        true
      rescue StandardError => e
        log_exception("Could not save global setting #{key}", e)
        false
      end

      def delete(key)
        boot unless @loaded
        return false unless @data["values"].has_key?(key.to_s)
        candidate = deep_copy(@data)
        candidate["values"].delete(key.to_s)
        return false unless persist(candidate)
        @data = candidate
        true
      rescue StandardError => e
        log_exception("Could not reset global setting #{key}", e)
        false
      end

      def merge_missing(entries)
        boot unless @loaded
        return 0 unless entries.is_a?(Hash)
        candidate = deep_copy(@data)
        added = 0
        entries.each do |key, value|
          normalized = key.to_s
          next if candidate["values"].has_key?(normalized)
          candidate["values"][normalized] = deep_copy(value)
          added += 1
        end
        return 0 if added == 0
        return 0 unless persist(candidate)
        @data = candidate
        added
      rescue StandardError => e
        log_exception("Could not migrate global settings", e)
        0
      end

      def storage_path
        return @storage_path if @storage_path
        folder = nil
        if defined?(RTP) && RTP.respond_to?(:getSaveFolder)
          folder = RTP.getSaveFolder rescue nil
        end
        if folder.to_s.empty? && defined?(KantoReloaded::Platform)
          folder = KantoReloaded::Platform.user_data_directory
        end
        folder = KantoReloaded::ROOT if folder.to_s.empty? && defined?(KantoReloaded::ROOT)
        folder = "." if folder.to_s.empty?
        @storage_path = File.expand_path(File.join(folder.to_s, FILE_NAME))
      end

      private

      def default_data
        {
          "schema_version" => SCHEMA_VERSION,
          "values" => {}
        }
      end

      def normalize_data(value)
        source = value.is_a?(Hash) ? value : {}
        values = source["values"] || source[:values]
        values = {} unless values.is_a?(Hash)
        normalized_values = {}
        values.each { |key, entry| normalized_values[key.to_s] = deep_copy(entry) }
        {
          "schema_version" => SCHEMA_VERSION,
          "values" => normalized_values
        }
      end

      def persist(candidate)
        path = storage_path
        ensure_directory(File.dirname(path))
        payload = KantoReloaded::Platform.generate_json(candidate)
        temporary = path + ".tmp"
        backup = path + ".bak"
        File.delete(temporary) if File.file?(temporary)
        File.open(temporary, "wb") do |file|
          file.write(payload)
          file.flush
          file.fsync if file.respond_to?(:fsync) rescue nil
        end
        raise "Global settings write produced an empty file" if File.size(temporary) <= 0

        moved_original = false
        begin
          File.delete(backup) if File.file?(backup)
          if File.file?(path)
            File.rename(path, backup)
            moved_original = true
          end
          File.rename(temporary, path)
        rescue StandardError
          File.rename(backup, path) if moved_original && !File.file?(path) && File.file?(backup)
          raise
        ensure
          File.delete(temporary) if File.file?(temporary)
        end
        File.delete(backup) if File.file?(backup) rescue nil
        true
      end

      def recover_interrupted_write(path)
        return true if File.file?(path)
        backup = path + ".bak"
        temporary = path + ".tmp"
        source = File.file?(backup) ? backup : temporary
        File.rename(source, path) if source
        true
      end

      def ensure_directory(path)
        return true if File.directory?(path)
        parent = File.dirname(path)
        ensure_directory(parent) unless parent == path || File.directory?(parent)
        Dir.mkdir(path) unless File.directory?(path)
        true
      end

      def deep_copy(value)
        return value if value.nil? || value == true || value == false
        return value if value.is_a?(Numeric) || value.is_a?(Symbol)
        return value.dup if value.is_a?(String)
        Marshal.load(Marshal.dump(value))
      rescue
        value
      end

      def log_exception(message, error)
        if defined?(KantoReloaded::Log)
          path = if defined?(KantoReloaded::Platform)
                   KantoReloaded::Platform.display_path(storage_path)
                 else
                   File.basename(storage_path)
                 end
          KantoReloaded::Log.exception("#{message} (#{path})", error, channel: :settings)
        end
      rescue
        nil
      end
    end
  end
end

KantoReloaded::GlobalSettings.boot if defined?(KantoReloaded::GlobalSettings)
