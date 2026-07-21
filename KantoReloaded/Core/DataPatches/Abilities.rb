#======================================================
# KantoReloaded Data Patch Abilities
# Author: Stonewall
#======================================================
# Direct runtime data patch target for base-game ability data.
#
# Responsibilities:
#   - Register the ability data patch target.
#   - Apply patched ability entries to GameData::Ability::DATA.
#   - Refresh the ability target after GameData.load_all refreshes base data.
#   - Restore KantoReloaded-managed ability entries before each rebuild.
#   - Provide safe text fallbacks for modded ability names and descriptions.
#
#======================================================

module KantoReloaded
  module DataPatchAbilities
    TARGET = "abilities".freeze

    ABILITY_FIELDS = [
      "id",
      "id_number",
      "name",
      "description"
    ].freeze

    @base_entries = {}
    @managed_symbols = []
    @managed_numbers = []

    class << self
      def install
        install_text_fallbacks
        register_target
        register_events
        KantoReloaded::Log.info("Installed KantoReloaded ability data patch bridge", :mods) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Ability data patch bridge install failed", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def register_target
        return unless defined?(KantoReloaded::DataPatches)
        refresh_base_entries
        KantoReloaded::DataPatches.register_target(
          TARGET,
          @base_entries,
          owner: :kanto_reloaded,
          description: "Runtime ability data patch target."
        )
      end

      def apply_all
        return false unless defined?(GameData::Ability)
        return true unless game_data_ready?
        restore_managed_entries
        touched_ids = patched_ability_ids
        applied = 0
        touched_ids.each do |id|
          raw_data = KantoReloaded::DataPatches.entry(TARGET, id)
          applied += 1 if apply_entry(id, raw_data)
        end
        log_applied(applied) if applied > 0
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to apply ability data patches", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      private

      def refresh_base_entries
        @base_entries = {}
        return unless defined?(GameData::Ability)
        GameData::Ability::DATA.each do |key, ability|
          next if key.is_a?(Integer)
          next unless ability.is_a?(GameData::Ability)
          @base_entries[key.to_s] = ability_to_hash(ability)
        end
        @base_entries
      end

      def ability_to_hash(ability)
        {
          "id" => ability.id.to_s,
          "id_number" => ability.id_number,
          "name" => ability.real_name,
          "description" => ability.real_description
        }
      end

      def restore_managed_entries
        return unless defined?(GameData::Ability)
        Array(@managed_numbers).each { |key| GameData::Ability::DATA.delete(key) }
        Array(@managed_symbols).each do |key|
          if @base_entries.key?(key.to_s)
            restore_base_entry(key.to_s)
          else
            GameData::Ability::DATA.delete(key)
          end
        end
        @managed_symbols = []
        @managed_numbers = []
      end

      def restore_base_entry(id)
        data = normalize_data(id, @base_entries[id])
        ability = GameData::Ability.new(data)
        GameData::Ability::DATA[data[:id]] = ability
        GameData::Ability::DATA[data[:id_number]] = ability
      end

      def apply_entry(id, raw_data)
        data = normalize_data(id, raw_data)
        return false unless validate_data(data)
        id_symbol = data[:id]
        id_number = data[:id_number]
        existing_number_owner = GameData::Ability::DATA[id_number]
        if existing_number_owner && existing_number_owner.id != id_symbol && !managed_number?(id_number)
          log_error("Ability patch #{id_symbol} cannot use id_number #{id_number}; it already belongs to #{existing_number_owner.id}.")
          return false
        end

        ability = GameData::Ability.new(data)
        ability.instance_variable_set(:@kanto_reloaded_data_patch, true)
        GameData::Ability::DATA[id_symbol] = ability
        GameData::Ability::DATA[id_number] = ability
        @managed_symbols << id_symbol unless @managed_symbols.include?(id_symbol)
        @managed_numbers << id_number unless @managed_numbers.include?(id_number)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to apply ability patch #{id}", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def normalize_data(id, raw_data)
        raw = stringify_keys(raw_data.is_a?(Hash) ? raw_data : {})
        base = base_entry(id)
        data = {}
        ABILITY_FIELDS.each { |field| data[field] = raw.key?(field) ? raw[field] : base[field] }
        data["id"] = id if blank?(data["id"])
        data["id_number"] = next_id_number if blank?(data["id_number"])
        data["name"] = data["id"].to_s if blank?(data["name"])
        data["description"] = "???" if blank?(data["description"])

        {
          :id => normalize_symbol(data["id"]),
          :id_number => data["id_number"].to_i,
          :name => data["name"].to_s,
          :description => data["description"].to_s
        }
      end

      def validate_data(data)
        unless data[:id_number].is_a?(Integer) && data[:id_number] > 0
          log_error("Ability patch #{data[:id]} has invalid id_number #{data[:id_number].inspect}.")
          return false
        end
        if blank?(data[:name])
          log_error("Ability patch #{data[:id]} has an empty name.")
          return false
        end
        true
      end

      def base_entry(id)
        key = normalize_symbol(id).to_s
        @base_entries[key] || {}
      end

      def next_id_number
        keys = []
        GameData::Ability::DATA.each_key { |key| keys << key if key.is_a?(Integer) }
        value = keys.empty? ? 1 : keys.max + 1
        value += 1 while GameData::Ability::DATA.key?(value)
        value
      end

      def patched_ability_ids
        return [] unless defined?(KantoReloaded::DataPatches)
        KantoReloaded::DataPatches.applied(TARGET).map { |patch| patch[:id] }.uniq
      rescue
        []
      end

      def managed_number?(key)
        @managed_numbers.include?(key)
      end

      def normalize_symbol(value)
        value.to_s.strip.upcase.gsub(/[^A-Z0-9_]+/, "_").to_sym
      end

      def stringify_keys(hash)
        result = {}
        hash.each { |key, value| result[key.to_s] = value }
        result
      rescue
        {}
      end

      def blank?(value)
        value.nil? || value.to_s.strip.empty?
      end

      def game_data_ready?
        defined?(GameData::Ability) &&
          GameData::Ability.const_defined?(:DATA) &&
          !GameData::Ability::DATA.empty?
      rescue
        false
      end

      def log_applied(count)
        message = "Applied #{count} ability data patch entr#{count == 1 ? 'y' : 'ies'}"
        if defined?(KantoReloaded::Log)
          if KantoReloaded::Log.respond_to?(:info_once)
            KantoReloaded::Log.info_once(message, :mods, key: "ability_data_patch_applied:#{count}")
          else
            KantoReloaded::Log.info(message, :mods)
          end
        end
      end

      def log_error(message)
        if defined?(KantoReloaded::Log)
          if KantoReloaded::Log.respond_to?(:error_once)
            KantoReloaded::Log.error_once(message, :mods, key: "ability_data_patch_error:#{message}")
          else
            KantoReloaded::Log.error(message, :mods)
          end
        end
      end

      def register_events
        return unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(:game_data_loaded, :ability_data_patch_target_refresh, priority: 50) do |_context|
          KantoReloaded::DataPatchAbilities.register_target if defined?(KantoReloaded::DataPatchAbilities)
        end
        KantoReloaded::Events.on(:data_patches_loaded, :ability_data_patch_bridge, priority: 100) do |_context|
          KantoReloaded::DataPatchAbilities.apply_all if defined?(KantoReloaded::DataPatchAbilities)
        end
      end

      def install_text_fallbacks
        return unless defined?(GameData::Ability)
        GameData::Ability.class_eval do
          def kanto_reloaded_data_patch_ability?
            !!@kanto_reloaded_data_patch
          end
        end
        KantoReloaded::Hooks.wrap(GameData::Ability, :name, :data_patch_ability_name) do |hook, *_args|
          kanto_reloaded_data_patch_ability? ? @real_name : hook.call
        end
        KantoReloaded::Hooks.wrap(GameData::Ability, :description, :data_patch_ability_description) do |hook, *_args|
          kanto_reloaded_data_patch_ability? ? @real_description : hook.call
        end
      end

    end
  end
end

KantoReloaded::DataPatchAbilities.install if defined?(KantoReloaded::DataPatchAbilities)
