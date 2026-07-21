#======================================================
# KantoReloaded Data Patch Trainer Types
# Author: Stonewall
#======================================================
# Direct runtime data patch target for base-game trainer type AI data.
#
# Responsibilities:
#   - Register the trainer type data patch target.
#   - Apply patched trainer type metadata, reward money, and AI fields.
#   - Refresh the trainer type target after GameData.load_all refreshes base data.
#   - Restore KantoReloaded-managed trainer type entries before each rebuild.
#
#======================================================

module KantoReloaded
  module DataPatchTrainerTypes
    TARGET = "trainer_types".freeze

    TRAINER_TYPE_FIELDS = [
      "id",
      "id_number",
      "name",
      "base_money",
      "money",
      "reward_money",
      "battle_BGM",
      "victory_ME",
      "intro_ME",
      "gender",
      "skill_level",
      "ai_skill_level",
      "skill_code",
      "ai_flags"
    ].freeze

    @base_entries = {}
    @managed_symbols = []
    @managed_numbers = []

    class << self
      def install
        register_target
        register_events
        KantoReloaded::Log.info("Installed KantoReloaded trainer type data patch bridge", :mods) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Trainer type data patch bridge install failed", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def register_target
        return unless defined?(KantoReloaded::DataPatches)
        refresh_base_entries
        KantoReloaded::DataPatches.register_target(
          TARGET,
          @base_entries,
          owner: :kanto_reloaded,
          description: "Runtime trainer type AI and skill data patch target.",
          defer_missing_entries: true
        )
      end

      def apply_all
        return false unless defined?(GameData::TrainerType)
        return true unless game_data_ready?
        restore_managed_entries
        applied = 0
        patched_trainer_type_ids.each do |id|
          raw_data = KantoReloaded::DataPatches.entry(TARGET, id)
          applied += 1 if apply_entry(id, raw_data)
        end
        log_applied(applied) if applied > 0
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to apply trainer type data patches", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      private

      def refresh_base_entries
        @base_entries = {}
        return unless defined?(GameData::TrainerType)
        GameData::TrainerType::DATA.each do |key, trainer_type|
          next if key.is_a?(Integer)
          next unless trainer_type.is_a?(GameData::TrainerType)
          @base_entries[key.to_s] = trainer_type_to_hash(trainer_type)
        end
        @base_entries
      end

      def trainer_type_to_hash(trainer_type)
        {
          "id" => trainer_type.id.to_s,
          "id_number" => trainer_type.id_number,
          "name" => trainer_type.real_name,
          "base_money" => trainer_type.base_money,
          "battle_BGM" => trainer_type.battle_BGM,
          "victory_ME" => trainer_type.victory_ME,
          "intro_ME" => trainer_type.intro_ME,
          "gender" => trainer_type.gender,
          "skill_level" => trainer_type.skill_level,
          "skill_code" => trainer_type.skill_code
        }
      end

      def restore_managed_entries
        return unless defined?(GameData::TrainerType)
        Array(@managed_numbers).each { |key| GameData::TrainerType::DATA.delete(key) }
        Array(@managed_symbols).each do |key|
          if @base_entries.key?(key.to_s)
            restore_base_entry(key.to_s)
          else
            GameData::TrainerType::DATA.delete(key)
          end
        end
        @managed_symbols = []
        @managed_numbers = []
      end

      def restore_base_entry(id)
        data = normalize_data(id, @base_entries[id])
        trainer_type = GameData::TrainerType.new(data)
        GameData::TrainerType::DATA[data[:id]] = trainer_type
        GameData::TrainerType::DATA[data[:id_number]] = trainer_type
      end

      def apply_entry(id, raw_data)
        data = normalize_data(id, raw_data)
        id_symbol = data[:id]
        id_number = data[:id_number]
        existing_number_owner = GameData::TrainerType::DATA[id_number]
        if existing_number_owner && existing_number_owner.id != id_symbol && !managed_number?(id_number)
          log_error("Trainer type patch #{id_symbol} cannot use id_number #{id_number}; it already belongs to #{existing_number_owner.id}.")
          return false
        end

        trainer_type = GameData::TrainerType.new(data)
        trainer_type.instance_variable_set(:@kanto_reloaded_data_patch, true)
        GameData::TrainerType::DATA[id_symbol] = trainer_type
        GameData::TrainerType::DATA[id_number] = trainer_type
        @managed_symbols << id_symbol unless @managed_symbols.include?(id_symbol)
        @managed_numbers << id_number unless @managed_numbers.include?(id_number)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to apply trainer type patch #{id}", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def normalize_data(id, raw_data)
        raw = stringify_keys(raw_data.is_a?(Hash) ? raw_data : {})
        base = base_entry(id)
        data = {}
        TRAINER_TYPE_FIELDS.each { |field| data[field] = raw.key?(field) ? raw[field] : base[field] }
        data["id"] = id if blank?(data["id"])
        data["id_number"] = next_id_number if blank?(data["id_number"])
        data["name"] = data["id"].to_s if blank?(data["name"])
        data["base_money"] = data["money"] if raw.key?("money")
        data["base_money"] = data["reward_money"] if raw.key?("reward_money")
        data["base_money"] = 30 if blank?(data["base_money"])
        data["gender"] = 2 if blank?(data["gender"])
        data["skill_level"] = data["ai_skill_level"] if raw.key?("ai_skill_level") && !raw.key?("skill_level")
        data["skill_level"] = data["base_money"] if blank?(data["skill_level"])
        data["skill_code"] = data["ai_flags"] if raw.key?("ai_flags") && !raw.key?("skill_code")

        {
          :id => normalize_symbol(data["id"]),
          :id_number => data["id_number"].to_i,
          :name => data["name"].to_s,
          :base_money => clamp_int(data["base_money"], 0, 999_999),
          :battle_BGM => blank?(data["battle_BGM"]) ? nil : data["battle_BGM"].to_s,
          :victory_ME => blank?(data["victory_ME"]) ? nil : data["victory_ME"].to_s,
          :intro_ME => blank?(data["intro_ME"]) ? nil : data["intro_ME"].to_s,
          :gender => clamp_int(data["gender"], 0, 2),
          :skill_level => clamp_int(data["skill_level"], 0, 255),
          :skill_code => normalize_skill_code(data["skill_code"])
        }
      end

      def base_entry(id)
        key = normalize_symbol(id).to_s
        @base_entries[key] || {}
      end

      def next_id_number
        keys = []
        GameData::TrainerType::DATA.each_key { |key| keys << key if key.is_a?(Integer) }
        value = keys.empty? ? 1 : keys.max + 1
        value += 1 while GameData::TrainerType::DATA.key?(value)
        value
      end

      def patched_trainer_type_ids
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

      def normalize_skill_code(value)
        return nil if blank?(value)
        code = if value.is_a?(Array)
                 value.map { |entry| entry.to_s }.join("")
               else
                 value.to_s
               end
        normalized = code.gsub(/[^A-Za-z0-9_]/, "")
        normalized.empty? ? nil : normalized
      end

      def clamp_int(value, min, max)
        int = value.to_i
        int = min if int < min
        int = max if int > max
        int
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
        defined?(GameData::TrainerType) &&
          GameData::TrainerType.const_defined?(:DATA) &&
          !GameData::TrainerType::DATA.empty?
      rescue
        false
      end

      def log_applied(count)
        message = "Applied #{count} trainer type data patch entr#{count == 1 ? 'y' : 'ies'}"
        if defined?(KantoReloaded::Log)
          if KantoReloaded::Log.respond_to?(:info_once)
            KantoReloaded::Log.info_once(message, :mods, key: "trainer_type_data_patch_applied:#{count}")
          else
            KantoReloaded::Log.info(message, :mods)
          end
        end
      end

      def log_error(message)
        if defined?(KantoReloaded::Log)
          if KantoReloaded::Log.respond_to?(:error_once)
            KantoReloaded::Log.error_once(message, :mods, key: "trainer_type_data_patch_error:#{message}")
          else
            KantoReloaded::Log.error(message, :mods)
          end
        end
      end

      def register_events
        return unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(:game_data_loaded, :trainer_type_data_patch_target_refresh, priority: 50) do |_context|
          KantoReloaded::DataPatchTrainerTypes.register_target if defined?(KantoReloaded::DataPatchTrainerTypes)
        end
        KantoReloaded::Events.on(:data_patches_loaded, :trainer_type_data_patch_bridge, priority: 100) do |_context|
          KantoReloaded::DataPatchTrainerTypes.apply_all if defined?(KantoReloaded::DataPatchTrainerTypes)
        end
      end

    end
  end
end

KantoReloaded::DataPatchTrainerTypes.install if defined?(KantoReloaded::DataPatchTrainerTypes)
