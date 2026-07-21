#======================================================
# KantoReloaded Save Data
# Author: Stonewall
#======================================================
# Central save bucket for KantoReloaded systems and mods.
#
# Responsibilities:
#   - Register one KantoReloaded save entry with the base SaveData system.
#   - Give mods a namespaced place to store persistent data.
#   - Keep KantoReloaded save data away from random vanilla object fields.
#   - Validate stored values before they are written to the save file.
#
#======================================================

module KantoReloaded
  module SaveData
    SAVE_KEY = :kanto_reloaded
    SCHEMA_VERSION = 1

    @data = nil
    @registered = false
    @write_blocked = false
    @write_block_reason = nil
    @original_bucket = nil

    class << self
      def data
        @data ||= empty_bucket
      end

      def empty_bucket
        {
          :schema_version => SCHEMA_VERSION,
          :systems => {},
          :modules => {},
          :mods => {},
          :metadata => initial_metadata
        }
      end

      def load(value)
        reset_write_protection
        source_version = bucket_schema_version(value)
        if source_version < SCHEMA_VERSION
          emit(:kanto_reloaded_save_migration_started, :from => source_version, :to => SCHEMA_VERSION)
          backup = if defined?(KantoReloaded::SaveProtection)
                     KantoReloaded::SaveProtection.backup_before_migration(
                       value,
                       :from => source_version,
                       :to => SCHEMA_VERSION
                     )
                   else
                     { :status => :not_applicable }
                   end
          if backup[:status] == :failed
            block_writes(value, :migration_backup_failed)
            @data = normalize_bucket(value)
            error = backup[:error] || RuntimeError.new("The save could not be backed up before migration.")
            KantoReloaded::Log.exception("KantoReloaded save migration backup failed", error, channel: :save_data) if defined?(KantoReloaded::Log)
            emit(:kanto_reloaded_save_migration_failed, :from => source_version, :to => SCHEMA_VERSION, :error => error)
            warn_incompatible_save(
              "KantoReloaded could not back up this save before updating it. KantoReloaded data will not be overwritten during this session."
            )
            return @data
          end
        end
        migration = if defined?(KantoReloaded::SaveMigrations)
                      KantoReloaded::SaveMigrations.migrate(value, SCHEMA_VERSION)
                    else
                      { :status => :current, :bucket => value, :applied => [], :mod_failures => [] }
                    end
        if migration[:status] == :newer
          block_writes(value, :newer_schema)
          @data = normalize_bucket(value)
          warn_incompatible_save(
            "This save was created by a newer Kanto Reloaded version. Update Kanto Reloaded before saving again."
          )
        elsif migration[:status] == :failed
          block_writes(value, :migration_failed)
          @data = normalize_bucket(value)
          error = migration[:error] || RuntimeError.new("Unknown migration failure")
          KantoReloaded::Log.exception("KantoReloaded save migration failed", error, channel: :save_data) if defined?(KantoReloaded::Log)
          emit(:kanto_reloaded_save_migration_failed, :from => source_version, :to => SCHEMA_VERSION, :error => error)
          warn_incompatible_save(
            "KantoReloaded save data could not be updated. KantoReloaded data will not be overwritten during this session."
          )
        else
          @data = normalize_bucket(migration[:bucket])
          log_migration_result(migration)
        end
        KantoReloaded::Log.debug("Loaded KantoReloaded save bucket", :save_data) if defined?(KantoReloaded::Log)
        emit(:kanto_reloaded_save_loaded, :data => @data)
        @data
      rescue StandardError => e
        KantoReloaded::Log.exception("KantoReloaded save bucket failed to load", e, channel: :save_data) if defined?(KantoReloaded::Log)
        @data = empty_bucket
      end

      def dump
        if write_blocked?
          KantoReloaded::Log.warning_once(
            "Preserved KantoReloaded save bucket because writes are blocked (#{@write_block_reason}).",
            :save_data,
            key: "kanto_reloaded_save_write_blocked:#{@write_block_reason}"
          ) if defined?(KantoReloaded::Log)
          return deep_copy(@original_bucket)
        end
        @data = normalize_bucket(@data)
        refresh_metadata!
        emit(:kanto_reloaded_save_saving, :data => @data)
        KantoReloaded::Log.debug("Dumped KantoReloaded save bucket", :save_data) if defined?(KantoReloaded::Log)
        @data
      rescue StandardError => e
        KantoReloaded::Log.exception("KantoReloaded save bucket failed to dump", e, channel: :save_data) if defined?(KantoReloaded::Log)
        empty_bucket
      end

      def namespace(owner, section: :mods)
        owner_key = normalize_owner(owner)
        section_hash(section)[owner_key] ||= {}
      end

      def system(system_id)
        namespace(system_id, section: :systems)
      end

      def mod(mod_id)
        namespace(mod_id, section: :mods)
      end

      def module_data(module_id)
        namespace(module_id, section: :modules)
      end

      def metadata
        deep_copy(metadata_hash)
      end

      def metadata_value(key, default = nil)
        value = metadata_hash[normalize_key(key)]
        value.nil? ? default : deep_copy(value)
      end

      def created_with_version
        metadata_value(:created_with_version, "0.0.0")
      end

      def last_saved_with_version
        metadata_value(:last_saved_with_version, "0.0.0")
      end

      def refresh_metadata!
        current = metadata_hash
        current["game"] = game_id
        current["created_at"] = timestamp if current["created_at"].to_s.empty?
        if current["created_with_version"].to_s.empty?
          current["created_with_version"] = kanto_reloaded_version
        end
        current["updated_at"] = timestamp
        current["last_saved_with_version"] = kanto_reloaded_version
        current["base_version"] = base_version
        current["platform"] = platform_label
        current["enabled_mods"] = enabled_mod_snapshot
        metadata
      rescue StandardError => e
        KantoReloaded::Log.exception("KantoReloaded save metadata refresh failed", e, channel: :save_data) if defined?(KantoReloaded::Log)
        metadata
      end

      def get(owner, key, default = nil, section: :mods)
        bucket = namespace(owner, section: section)
        normalized_key = normalize_key(key)
        return bucket[normalized_key] if bucket.has_key?(normalized_key)
        default
      end

      def set(owner, key, value, section: :mods)
        unless marshalable?(value)
          KantoReloaded::Log.warning(
            "Rejected non-saveable value for #{section}/#{owner}/#{key} (#{value.class})",
            :save_data
          ) if defined?(KantoReloaded::Log)
          return false
        end
        namespace(owner, section: section)[normalize_key(key)] = value
        true
      end

      def delete(owner, key = nil, section: :mods)
        if key.nil?
          section_hash(section).delete(normalize_owner(owner))
        else
          namespace(owner, section: section).delete(normalize_key(key))
        end
      end

      def has?(owner, key, section: :mods)
        namespace(owner, section: section).has_key?(normalize_key(key))
      end

      def clear(owner = nil, section: :mods)
        if owner.nil?
          section_hash(section).clear
        else
          delete(owner, section: section)
        end
      end

      def registered?
        @registered
      end

      def write_blocked?
        !!@write_blocked
      end

      def write_block_reason
        @write_block_reason
      end

      def new_game_bucket
        reset_write_protection
        @data = empty_bucket
        emit(:kanto_reloaded_save_new_game, :data => @data)
        @data
      end

      def register_with_base_save_data
        return false unless defined?(::SaveData)
        return true if @registered
        ::SaveData.register(SAVE_KEY) do
          save_value { KantoReloaded::SaveData.dump }
          load_value { |value| KantoReloaded::SaveData.load(value) }
          new_game_value { KantoReloaded::SaveData.new_game_bucket }
        end
        @registered = true
        KantoReloaded::Log.info("Registered KantoReloaded save bucket", :save_data) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("KantoReloaded save bucket registration failed", e, channel: :save_data) if defined?(KantoReloaded::Log)
        false
      end

      private

      def section_hash(section)
        bucket = data
        section_key = normalize_section(section)
        bucket[section_key] ||= {}
      end

      def normalize_bucket(value)
        source = value.is_a?(Hash) ? value : {}
        {
          :schema_version => SCHEMA_VERSION,
          :systems => normalize_section_hash(source[:systems] || source["systems"]),
          :modules => normalize_section_hash(source[:modules] || source["modules"]),
          :mods => normalize_section_hash(source[:mods] || source["mods"]),
          :metadata => normalize_metadata(source[:metadata] || source["metadata"])
        }
      end

      def bucket_schema_version(value)
        return 0 unless value.is_a?(Hash)
        (value[:schema_version] || value["schema_version"] || 0).to_i
      end

      def reset_write_protection
        @write_blocked = false
        @write_block_reason = nil
        @original_bucket = nil
      end

      def block_writes(value, reason)
        @write_blocked = true
        @write_block_reason = reason.to_sym
        @original_bucket = deep_copy(value.is_a?(Hash) ? value : {})
      end

      def log_migration_result(result)
        applied = Array(result[:applied])
        unless applied.empty?
          KantoReloaded::Log.info_once(
            "Migrated KantoReloaded save schema: #{applied.join(', ')}",
            :save_data,
            key: "kanto_reloaded_save_migrated:#{applied.join(':')}"
          ) if defined?(KantoReloaded::Log)
          emit(:kanto_reloaded_save_migrated, :from => result[:from], :to => result[:to], :migrations => applied)
        end
        Array(result[:mod_failures]).each do |failure|
          error = failure[:error] || RuntimeError.new(failure[:message].to_s)
          owner = failure[:owner].to_s
          KantoReloaded::Log.exception("Save migration failed for mod #{owner}", error, channel: :mods) if defined?(KantoReloaded::Log)
          emit(:kanto_reloaded_save_migration_failed, :owner => owner, :error => error)
        end
      end

      def warn_incompatible_save(message)
        if KantoReloaded.respond_to?(:message)
          KantoReloaded.message(message.to_s, :theme => :warning)
        elsif defined?(Kernel) && Kernel.respond_to?(:pbMessage)
          Kernel.pbMessage(message.to_s)
        end
      rescue StandardError => e
        KantoReloaded::Log.exception("Save compatibility warning failed", e, channel: :save_data) if defined?(KantoReloaded::Log)
      end

      def normalize_metadata(value)
        normalized = initial_metadata
        return normalized unless value.is_a?(Hash)
        value.each do |key, entry|
          next unless marshalable?(entry)
          normalized[normalize_key(key)] = entry
        end
        normalized
      end

      def normalize_section_hash(value)
        return {} unless value.is_a?(Hash)
        normalized = {}
        value.each do |owner, owner_data|
          next unless owner_data.is_a?(Hash)
          normalized[normalize_owner(owner)] = normalize_value_hash(owner_data)
        end
        normalized
      end

      def normalize_value_hash(value)
        normalized = {}
        value.each { |key, entry| normalized[normalize_key(key)] = entry } if value.is_a?(Hash)
        normalized
      end

      def normalize_owner(owner)
        owner.to_s.strip.downcase
      end

      def normalize_key(key)
        key.to_s
      end

      def normalize_section(section)
        key = section.to_s
        return :systems if key == "systems"
        return :modules if key == "modules"
        :mods
      end

      def metadata_hash
        data[:metadata] ||= initial_metadata
      end

      def initial_metadata
        now = timestamp
        version = kanto_reloaded_version
        {
          "game" => game_id,
          "created_at" => now,
          "updated_at" => now,
          "created_with_version" => version,
          "last_saved_with_version" => version,
          "base_version" => base_version,
          "platform" => platform_label,
          "enabled_mods" => enabled_mod_snapshot
        }
      end

      def timestamp
        Time.now.strftime("%Y-%m-%d %H:%M:%S")
      rescue
        ""
      end

      def kanto_reloaded_version
        KantoReloaded.version rescue "0.0.0"
      end

      def base_version
        return ::Settings::IF_VERSION.to_s if defined?(::Settings::IF_VERSION)
        return ::Settings::GAME_VERSION.to_s if defined?(::Settings::GAME_VERSION)
        return ::Settings::GAME_VERSION_NUMBER.to_s if defined?(::Settings::GAME_VERSION_NUMBER)
        path = File.join(KantoReloaded::Platform::GAME_ROOT, "Data", "VERSION") if defined?(KantoReloaded::Platform)
        value = File.file?(path) ? File.read(path).to_s.strip : ""
        value.empty? ? "0.0.0" : value
      rescue
        "0.0.0"
      end

      def game_id
        "kif"
      rescue
        "kif"
      end

      def platform_label
        defined?(KantoReloaded::Platform) ? KantoReloaded::Platform.label.to_s : "Other"
      rescue
        "Other"
      end

      def enabled_mod_snapshot
        return [] unless defined?(::ModManager) && ::ModManager.respond_to?(:registry)
        ids = ::ModManager.respond_to?(:enabled_mods) ? ::ModManager.enabled_mods : ::ModManager.registry.keys
        Array(ids).map do |id|
          info = ::ModManager.registry[id]
          next unless info
          version = info.respond_to?(:version) ? info.version : "0.0.0"
          { "id" => id.to_s, "version" => version.to_s }
        end.compact
      rescue
        []
      end

      def deep_copy(value)
        Marshal.load(Marshal.dump(value))
      rescue
        value
      end

      def marshalable?(value)
        Marshal.dump(value)
        true
      rescue
        false
      end

      def emit(event_name, context)
        KantoReloaded::Events.emit(event_name, context) if defined?(KantoReloaded::Events)
      rescue StandardError => e
        KantoReloaded::Log.exception("KantoReloaded save event #{event_name} failed", e, channel: :save_data) if defined?(KantoReloaded::Log)
      end
    end
  end
end

KantoReloaded::SaveData.register_with_base_save_data if defined?(KantoReloaded::SaveData)
