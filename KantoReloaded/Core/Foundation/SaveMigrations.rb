#======================================================
# KantoReloaded Save Migrations
# Author: Stonewall
#======================================================
# Transactional schema migrations for KantoReloaded and mod save namespaces.
#======================================================

module KantoReloaded
  module SaveMigrations
    @migrations = []
    @mod_migrations = []

    class << self
      def register(id, from:, to:, &block)
        register_entry(@migrations, :kanto_reloaded, id, from, to, block)
      end

      def register_mod(mod_id, id = nil, from:, to:, &block)
        owner = normalize_owner(mod_id)
        migration_id = id || "#{owner}_#{from}_to_#{to}"
        register_entry(@mod_migrations, owner, migration_id, from, to, block)
      end

      def migrate(bucket, target_version)
        original = deep_copy(bucket.is_a?(Hash) ? bucket : {})
        source_version = schema_version(original)
        target = target_version.to_i
        return result(:newer, original, source_version, target, []) if source_version > target

        working = deep_copy(original)
        applied = []
        begin
          working, applied = run_chain(working, source_version, target, @migrations, :kanto_reloaded)
        rescue StandardError => e
          return result(:failed, original, source_version, target, applied, e)
        end

        mod_failures = migrate_mod_namespaces(working)
        record_migration_metadata(working, applied, mod_failures)
        result(applied.empty? ? :current : :migrated, working, source_version, target, applied, nil, mod_failures)
      rescue StandardError => e
        result(:failed, bucket, 0, target_version.to_i, [], e)
      end

      def migrations
        @migrations.map { |entry| public_entry(entry) }
      end

      def mod_migrations(mod_id = nil)
        entries = mod_id.nil? ? @mod_migrations : @mod_migrations.select { |entry| entry[:owner] == normalize_owner(mod_id) }
        entries.map { |entry| public_entry(entry) }
      end

      private

      def register_entry(registry, owner, id, from, to, block)
        raise ArgumentError, "A migration block is required." unless block
        from_version = from.to_i
        to_version = to.to_i
        raise ArgumentError, "Save migrations must advance exactly one schema version." unless to_version == from_version + 1
        entry = {
          :owner => normalize_owner(owner),
          :id => id.to_s,
          :from => from_version,
          :to => to_version,
          :block => block
        }
        registry.reject! { |existing| existing[:owner] == entry[:owner] && existing[:id] == entry[:id] }
        conflict = registry.find do |existing|
          existing[:owner] == entry[:owner] && existing[:from] == entry[:from] && existing[:id] != entry[:id]
        end
        raise "Multiple migrations start at schema #{from_version} for #{entry[:owner]}." if conflict
        registry << entry
        registry.sort_by! { |item| [item[:owner], item[:from], item[:id]] }
        public_entry(entry)
      end

      def run_chain(value, from_version, target_version, registry, owner)
        current = from_version.to_i
        working = value
        applied = []
        while current < target_version.to_i
          migration = registry.find { |entry| entry[:owner] == normalize_owner(owner) && entry[:from] == current }
          raise "Missing save migration for #{owner}: #{current} -> #{current + 1}." unless migration
          replacement = migration[:block].call(working)
          working = replacement if replacement.is_a?(Hash)
          raise "Save migration #{migration[:id]} did not produce saveable data." unless marshalable?(working)
          current = migration[:to]
          set_schema_version(working, current, owner)
          applied << migration[:id]
        end
        [working, applied]
      end

      def migrate_mod_namespaces(bucket)
        mods = hash_value(bucket, :mods)
        return [] unless mods.is_a?(Hash)
        failures = []
        @mod_migrations.map { |entry| entry[:owner] }.uniq.each do |owner|
          key = mods.keys.find { |candidate| normalize_owner(candidate) == owner }
          next unless key && mods[key].is_a?(Hash)
          original = deep_copy(mods[key])
          current = schema_version(original)
          target = @mod_migrations.select { |entry| entry[:owner] == owner }.map { |entry| entry[:to] }.max.to_i
          next if current > target
          begin
            migrated, applied = run_chain(deep_copy(original), current, target, @mod_migrations, owner)
            mods[key] = migrated
            Array(applied).each { |id| append_completed(bucket, "#{owner}:#{id}") }
          rescue StandardError => e
            mods[key] = original
            failures << { :owner => owner, :error => e, :message => e.message.to_s }
          end
        end
        failures
      end

      def record_migration_metadata(bucket, applied, failures)
        Array(applied).each { |id| append_completed(bucket, id) }
        metadata = ensure_hash(bucket, :metadata)
        metadata["migration_failures"] = Array(failures).map do |failure|
          { "owner" => failure[:owner].to_s, "message" => failure[:message].to_s }
        end
      end

      def append_completed(bucket, id)
        metadata = ensure_hash(bucket, :metadata)
        values = Array(metadata["completed_migrations"]).map(&:to_s)
        values << id.to_s unless values.include?(id.to_s)
        metadata["completed_migrations"] = values
      end

      def ensure_hash(bucket, key)
        existing_key = bucket.key?(key) ? key : (bucket.key?(key.to_s) ? key.to_s : key)
        bucket[existing_key] = {} unless bucket[existing_key].is_a?(Hash)
        bucket[existing_key]
      end

      def hash_value(hash, key)
        hash[key] || hash[key.to_s]
      end

      def schema_version(hash)
        return 0 unless hash.is_a?(Hash)
        (hash[:_schema_version] || hash["_schema_version"] || hash[:schema_version] || hash["schema_version"] || 0).to_i
      end

      def set_schema_version(hash, version, owner = :kanto_reloaded)
        mod_namespace = normalize_owner(owner) != "kanto_reloaded"
        symbol_key = mod_namespace ? :_schema_version : :schema_version
        string_key = mod_namespace ? "_schema_version" : "schema_version"
        key = hash.key?(symbol_key) ? symbol_key : string_key
        hash[key] = version.to_i
      end

      def normalize_owner(value)
        value.to_s.strip.downcase
      end

      def result(status, bucket, from, to, applied, error = nil, mod_failures = [])
        {
          :status => status,
          :bucket => bucket,
          :from => from.to_i,
          :to => to.to_i,
          :applied => Array(applied).dup,
          :error => error,
          :mod_failures => Array(mod_failures).dup
        }
      end

      def public_entry(entry)
        entry.reject { |key, _value| key == :block }.dup
      end

      def marshalable?(value)
        Marshal.dump(value)
        true
      rescue
        false
      end

      def deep_copy(value)
        Marshal.load(Marshal.dump(value))
      end
    end
  end
end

KantoReloaded::SaveMigrations.register(:kanto_reloaded_schema_0_to_1, :from => 0, :to => 1) do |bucket|
  value = bucket.is_a?(Hash) ? bucket : {}
  value[:systems] ||= value.delete("systems") || {}
  value[:modules] ||= value.delete("modules") || {}
  value[:mods] ||= value.delete("mods") || {}
  value[:metadata] ||= value.delete("metadata") || {}
  value
end
