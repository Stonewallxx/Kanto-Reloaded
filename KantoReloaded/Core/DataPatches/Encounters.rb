#======================================================
# KantoReloaded Data Patch Encounters
# Author: Stonewall
#======================================================
# Runtime data patch targets for wild encounter tables.
#
# Responsibilities:
#   - Register classic, remix, and randomized encounter data patch targets.
#   - Apply patched step chances and encounter tables to GameData encounters.
#   - Refresh targets after GameData.load_all refreshes base encounter data.
#   - Restore KantoReloaded-managed encounter entries before each rebuild.
#   - Keep encounter patches runtime-only without editing base encounter files.
#
#======================================================

module KantoReloaded
  module DataPatchEncounters
    TARGETS = {
      "encounters.classic" => "GameData::Encounter",
      "encounters.remix" => "GameData::EncounterModern",
      "encounters.randomized" => "GameData::EncounterRandom"
    }.freeze

    @base_entries = {}
    @managed_entries = {}
    @setup_patch_installed = false

    class << self
      def install
        refresh_base_entries
        register_targets
        register_events
        install_runtime_setup_patch
        KantoReloaded::Log.info("Installed KantoReloaded encounter data patch bridge", :mods) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Encounter data patch bridge install failed", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def register_targets
        return unless defined?(KantoReloaded::DataPatches)
        TARGETS.each do |target, _class_name|
          KantoReloaded::DataPatches.register_target(
            target,
            @base_entries[target] || {},
            owner: :kanto_reloaded,
            description: "Runtime #{target} data patch target.",
            defer_missing_entries: true
          )
        end
      end

      def apply_all
        return true unless game_data_ready?
        restore_managed_entries
        applied = {}
        TARGETS.each_key do |target|
          count = apply_target(target)
          applied[target] = count
          log_applied(target, count) if count > 0
        end
        install_runtime_setup_patch
        refresh_active_encounter_cache if applied.values.any? { |count| count.to_i > 0 }
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to apply encounter data patches", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def sync_runtime_cache(encounters, map_id)
        return false unless encounters
        version = encounter_version
        mode = encounter_mode_for(encounters)
        encounter_data = mode.get(map_id, version) if mode && mode.respond_to?(:get)
        fallback = false
        if !encounter_data && defined?(GameData::Encounter)
          encounter_data = GameData::Encounter.get(map_id, version)
          fallback = true
        end
        return false unless valid_encounter?(encounter_data)
        step_chances = {}
        encounter_data.step_chances.each { |type, value| step_chances[type] = value } if encounter_data.step_chances.respond_to?(:each)
        encounters.instance_variable_set(:@step_chances, step_chances)
        encounters.instance_variable_set(:@encounter_tables, Marshal.load(Marshal.dump(encounter_data.types)))
        log_runtime_cache_summary(mode, map_id, version, encounter_data, fallback)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to sync encounter cache for map #{map_id}", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      private

      def refresh_base_entries
        restore_managed_entries
        @base_entries = {}
        TARGETS.each do |target, class_name|
          @base_entries[target] = {}
          klass = resolve_class(class_name)
          next unless klass
          klass::DATA.each do |key, encounter|
            next unless valid_encounter?(encounter)
            entry_id = normalize_entry_id(encounter.map, encounter.version)
            @base_entries[target][entry_id] = encounter_to_hash(encounter)
          end
        end
        @base_entries
      end

      def apply_target(target)
        klass = target_class(target)
        return 0 unless klass
        applied = 0
        patched_entry_ids(target).each do |entry_id|
          raw_data = KantoReloaded::DataPatches.entry(target, entry_id)
          applied += 1 if apply_entry(target, klass, entry_id, raw_data)
        end
        applied
      end

      def restore_managed_entries
        return if @restoring_managed_entries
        @restoring_managed_entries = true
        TARGETS.each do |target, class_name|
          klass = resolve_class(class_name)
          next unless klass
          Array(@managed_entries[target]).each do |entry_id|
            base = (@base_entries[target] || {})[entry_id]
            if base
              register_encounter(klass, base)
            else
              klass::DATA.delete(entry_id.to_sym)
            end
          end
        end
        @managed_entries = {}
    @setup_patch_installed = false
      ensure
        @restoring_managed_entries = false
      end

      def apply_entry(target, klass, entry_id, raw_data)
        data = normalize_data(target, entry_id, raw_data)
        return false unless validate_data(target, entry_id, data)
        register_encounter(klass, data)
        @managed_entries[target] ||= []
        @managed_entries[target] << normalize_entry_id(data["map"], data["version"]) unless @managed_entries[target].include?(normalize_entry_id(data["map"], data["version"]))
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to apply encounter patch #{target}/#{entry_id}", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def register_encounter(klass, data)
        entry_id = normalize_entry_id(data["map"], data["version"])
        encounter = klass.new(
          :id => entry_id.to_sym,
          :map => data["map"].to_i,
          :version => data["version"].to_i,
          :step_chances => normalize_step_chances(data["step_chances"]),
          :types => normalize_types(data["types"])
        )
        encounter.instance_variable_set(:@kanto_reloaded_data_patch, true)
        klass::DATA[entry_id.to_sym] = encounter
        log_encounter_summary(klass, entry_id, encounter)
        encounter
      end

      def normalize_data(target, entry_id, raw_data)
        raw = stringify_keys(raw_data.is_a?(Hash) ? raw_data : {})
        base = (@base_entries[target] || {})[normalize_entry_id_from_value(entry_id)] || {}
        map = raw.key?("map") ? raw["map"] : (base["map"] || entry_id.to_s.split("_")[0])
        version = raw.key?("version") ? raw["version"] : (base["version"] || entry_id.to_s.split("_")[1] || 0)
        step_chances = raw.key?("step_chances") ? merge_hash(base["step_chances"], raw["step_chances"]) : base["step_chances"]
        types = raw.key?("types") ? merge_type_replacements(base["types"], raw["types"]) : base["types"]
        types = append_types(types, raw["add_types"]) if raw.key?("add_types")
        {
          "map" => map.to_i,
          "version" => version.to_i,
          "step_chances" => normalize_step_chances(step_chances),
          "types" => normalize_types(types)
        }
      end

      def validate_data(target, entry_id, data)
        if data["map"].to_i <= 0
          log_error("Encounter patch #{target}/#{entry_id} has invalid map #{data["map"].inspect}.")
          return false
        end
        stringify_keys(data["step_chances"]).each do |type, chance|
          type_id = normalize_encounter_type(type)
          unless data_id_exists?("GameData::EncounterType", type_id)
            log_error("Encounter patch #{target}/#{entry_id} references unknown encounter type #{type}.")
            return false
          end
          if chance.to_i < 0
            log_error("Encounter patch #{target}/#{entry_id} has invalid step chance #{type}=#{chance.inspect}.")
            return false
          end
        end
        stringify_keys(data["types"]).each do |type, entries|
          type_id = normalize_encounter_type(type)
          unless data_id_exists?("GameData::EncounterType", type_id)
            log_error("Encounter patch #{target}/#{entry_id} references unknown encounter table #{type}.")
            return false
          end
          Array(entries).each_with_index do |entry, index|
            chance, species, min_level, max_level = entry
            unless data_id_exists?("GameData::Species", species)
              log_error("Encounter patch #{target}/#{entry_id} #{type}[#{index}] references unknown species #{species}.")
              return false
            end
            if chance.to_i <= 0
              log_error("Encounter patch #{target}/#{entry_id} #{type}[#{index}] has invalid chance #{chance.inspect}.")
              return false
            end
            if min_level.to_i <= 0 || max_level.to_i <= 0 || min_level.to_i > max_level.to_i
              log_error("Encounter patch #{target}/#{entry_id} #{type}[#{index}] has invalid levels #{min_level.inspect}-#{max_level.inspect}.")
              return false
            end
          end
        end
        true
      end

      def encounter_to_hash(encounter)
        {
          "map" => encounter.map,
          "version" => encounter.version,
          "step_chances" => step_chances_to_hash(encounter.step_chances),
          "types" => types_to_hash(encounter.types)
        }
      end

      def step_chances_to_hash(hash)
        result = {}
        hash.each { |key, value| result[key.to_s] = value.to_i } if hash.respond_to?(:each)
        result
      end

      def types_to_hash(hash)
        result = {}
        hash.each do |type, entries|
          result[type.to_s] = Array(entries).map { |entry| encounter_entry_to_hash(entry) }
        end if hash.respond_to?(:each)
        result
      end

      def encounter_entry_to_hash(entry)
        {
          "chance" => entry[0].to_i,
          "species" => entry[1].to_s,
          "min_level" => entry[2].to_i,
          "max_level" => entry[3].to_i
        }
      rescue
        {}
      end

      def normalize_step_chances(value)
        result = {}
        stringify_keys(value.is_a?(Hash) ? value : {}).each do |key, chance|
          result[normalize_encounter_type(key)] = chance.to_i
        end
        result
      end

      def normalize_types(value)
        result = {}
        stringify_keys(value.is_a?(Hash) ? value : {}).each do |key, entries|
          normalized_entries = []
          Array(entries).each do |entry|
            normalized = normalize_encounter_entry(entry)
            normalized_entries << normalized if normalized
          end
          result[normalize_encounter_type(key)] = normalized_entries
        end
        result
      end

      def merge_type_replacements(base, incoming)
        result = stringify_keys(base.is_a?(Hash) ? base : {})
        stringify_keys(incoming.is_a?(Hash) ? incoming : {}).each do |type, entries|
          result[type] = Array(entries)
        end
        result
      end

      def append_types(base, incoming)
        result = stringify_keys(base.is_a?(Hash) ? base : {})
        stringify_keys(incoming.is_a?(Hash) ? incoming : {}).each do |type, entries|
          result[type] ||= []
          result[type] = Array(result[type]) + Array(entries)
        end
        result
      end

      def merge_hash(base, incoming)
        result = stringify_keys(base.is_a?(Hash) ? base : {})
        stringify_keys(incoming.is_a?(Hash) ? incoming : {}).each do |key, value|
          result[key] = value
        end
        result
      end

      def normalize_encounter_entry(entry)
        if entry.is_a?(Hash)
          raw = stringify_keys(entry)
          chance = raw["chance"] || raw["weight"] || raw["rarity"]
          species = raw["species"] || raw["id"]
          min_level = raw["min_level"] || raw["level"] || raw["min"]
          max_level = raw["max_level"] || raw["level"] || raw["max"] || min_level
        elsif entry.is_a?(Array)
          chance = entry[0]
          species = entry[1]
          min_level = entry[2]
          max_level = entry[3] || entry[2]
        else
          return nil
        end
        return nil if blank?(species)
        [chance.to_i, normalize_symbol(species), min_level.to_i, max_level.to_i]
      end

      def patched_entry_ids(target)
        return [] unless defined?(KantoReloaded::DataPatches)
        KantoReloaded::DataPatches.applied(target).map { |patch| patch[:id] }.uniq
      rescue
        []
      end

      def refresh_active_encounter_cache
        return unless defined?($PokemonEncounters) && $PokemonEncounters
        return unless defined?($game_map) && $game_map && $game_map.respond_to?(:map_id)
        sync_runtime_cache($PokemonEncounters, $game_map.map_id)
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to refresh active encounter cache", e, channel: :mods) if defined?(KantoReloaded::Log)
      end

      def install_runtime_setup_patch
        return true if @setup_patch_installed
        return false unless defined?(::PokemonEncounters)
        installed = KantoReloaded::Hooks.wrap(
          ::PokemonEncounters, :setup, :data_patch_encounter_setup
        ) do |hook, map_id, *_args|
          result = hook.call
          KantoReloaded::DataPatchEncounters.sync_runtime_cache(self, map_id) if defined?(KantoReloaded::DataPatchEncounters)
          result
        end
        return false unless installed
        @setup_patch_installed = true
        KantoReloaded::Log.debug_once("Installed KantoReloaded encounter setup cache bridge", :mods, key: "encounter_setup_cache_bridge") if defined?(KantoReloaded::Log) && KantoReloaded::Log.respond_to?(:debug_once)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to install encounter setup cache bridge", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def target_class(target)
        resolve_class(TARGETS[target])
      end

      def resolve_class(class_name)
        return nil if class_name.to_s.empty?
        class_name.to_s.split("::").inject(Object) do |scope, name|
          return nil unless scope.const_defined?(name)
          scope.const_get(name)
        end
      rescue
        nil
      end

      def encounter_mode_for(encounters)
        return encounters.send(:getEncounterMode) if encounters.respond_to?(:getEncounterMode, true)
        return GameData::Encounter if defined?(GameData::Encounter)
        nil
      rescue
        defined?(GameData::Encounter) ? GameData::Encounter : nil
      end

      def encounter_version
        return $PokemonGlobal.encounter_version.to_i if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:encounter_version)
        0
      rescue
        0
      end

      def valid_encounter?(value)
        value && value.respond_to?(:map) && value.respond_to?(:version) && value.respond_to?(:step_chances) && value.respond_to?(:types)
      end

      def normalize_entry_id(map, version)
        "#{map.to_i}_#{version.to_i}"
      end

      def normalize_entry_id_from_value(value)
        parts = value.to_s.strip.split("_")
        normalize_entry_id(parts[0] || 0, parts[1] || 0)
      end

      def stringify_keys(hash)
        result = {}
        hash.each { |key, value| result[key.to_s] = value } if hash.respond_to?(:each)
        result
      rescue
        {}
      end

      def normalize_symbol(value)
        value.to_s.strip.upcase.gsub(/[^A-Z0-9_]+/, "_").to_sym
      end

      def normalize_encounter_type(value)
        exact = value.is_a?(Symbol) ? value : value.to_s.to_sym
        if defined?(GameData::EncounterType) && GameData::EncounterType.const_defined?(:DATA)
          return exact if GameData::EncounterType::DATA.key?(exact)
          normalized_value = normalize_lookup_key(value)
          GameData::EncounterType::DATA.keys.each do |key|
            return key if normalize_lookup_key(key) == normalized_value
          end
        end
        exact
      rescue
        value.to_s.strip.to_sym
      end

      def normalize_lookup_key(value)
        value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "")
      end

      def blank?(value)
        value.nil? || value.to_s.strip.empty?
      end

      def game_data_ready?
        data_table_ready?("GameData::EncounterType") &&
          data_table_ready?("GameData::Species")
      rescue
        false
      end

      def data_table_ready?(class_name)
        klass = resolve_class(class_name)
        return true unless klass && klass.const_defined?(:DATA)
        !klass::DATA.empty?
      rescue
        false
      end

      def data_id_exists?(class_name, value)
        return true if value.nil?
        klass = resolve_class(class_name)
        return true unless klass && klass.const_defined?(:DATA)
        klass::DATA.key?(value)
      rescue
        true
      end

      def log_error(message)
        if defined?(KantoReloaded::Log)
          if KantoReloaded::Log.respond_to?(:error_once)
            KantoReloaded::Log.error_once(message, :mods, key: "encounter_data_patch_error:#{message}")
          else
            KantoReloaded::Log.error(message, :mods)
          end
        end
      end

      def log_encounter_summary(klass, entry_id, encounter)
        return unless defined?(KantoReloaded::Log)
        return unless KantoReloaded::Log.respond_to?(:debug)
        land = Array(encounter.types[:Land]).map { |entry| "#{entry[1]}:#{entry[2]}-#{entry[3]}@#{entry[0]}" }.join(", ")
        KantoReloaded::Log.debug("#{klass} encounter #{entry_id} Land=[#{land}]", :mods)
      rescue
      end

      def log_runtime_cache_summary(mode, map_id, version, encounter, fallback)
        return unless defined?(KantoReloaded::Log)
        return unless KantoReloaded::Log.respond_to?(:debug_once)
        land = Array(encounter.types[:Land]).map { |entry| "#{entry[1]}:#{entry[2]}-#{entry[3]}@#{entry[0]}" }.join(", ")
        key = "encounter_cache:#{mode}:#{map_id}:#{version}:#{encounter.version}:#{land}"
        source = fallback ? "fallback" : mode.to_s
        KantoReloaded::Log.debug_once("Encounter cache map=#{map_id} requested_version=#{version} data_version=#{encounter.version} source=#{source} Land=[#{land}]", :mods, key: key)
      rescue
      end

      def register_events
        return unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(:game_data_loaded, :encounter_data_patch_target_refresh, priority: 50) do |_context|
          if defined?(KantoReloaded::DataPatchEncounters)
            KantoReloaded::DataPatchEncounters.send(:refresh_base_entries)
            KantoReloaded::DataPatchEncounters.register_targets
          end
        end
        KantoReloaded::Events.on(:data_patches_loaded, :encounter_data_patch_bridge, priority: 100) do |_context|
          KantoReloaded::DataPatchEncounters.apply_all if defined?(KantoReloaded::DataPatchEncounters)
        end
      end

      def log_applied(target, count)
        message = "Applied #{count} #{target} data patch entr#{count == 1 ? 'y' : 'ies'}"
        if defined?(KantoReloaded::Log)
          if KantoReloaded::Log.respond_to?(:info_once)
            KantoReloaded::Log.info_once(message, :mods, key: "#{target}_data_patch_applied:#{count}")
          else
            KantoReloaded::Log.info(message, :mods)
          end
        end
      end

    end
  end
end

KantoReloaded::DataPatchEncounters.install if defined?(KantoReloaded::DataPatchEncounters)
