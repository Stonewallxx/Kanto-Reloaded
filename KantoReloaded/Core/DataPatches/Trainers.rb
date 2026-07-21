#======================================================
# KantoReloaded Data Patch Trainers
# Author: Stonewall
#======================================================
# Direct runtime data patch targets for base-game trainer parties.
#
# Responsibilities:
#   - Register trainer data patch targets for classic, remix, and expert data.
#   - Apply patched trainer metadata and parties to GameData trainer records.
#   - Restore KantoReloaded-managed trainer entries before each rebuild.
#   - Validate trainer patch references before runtime registration.
#   - Normalize trainer Pokemon data into the engine's expected structure.
#
#======================================================

module KantoReloaded
  module DataPatchTrainers
    TARGETS = {
      "trainers.classic" => "GameData::Trainer",
      "trainers.remix" => "GameData::TrainerModern",
      "trainers.expert" => "GameData::TrainerExpert"
    }.freeze

    TRAINER_FIELDS = [
      "id",
      "id_number",
      "trainer_type",
      "name",
      "version",
      "items",
      "bag_items",
      "lose_text",
      "loseText_rematch",
      "loseText_rematch_double",
      "battleText",
      "preRematchText",
      "preRematchText_caught",
      "preRematchText_evolved",
      "preRematchText_fused",
      "preRematchText_unfused",
      "preRematchText_reversed",
      "preRematchText_gift",
      "infoText",
      "rematch_lose_text",
      "rematch_double_lose_text",
      "battle_text",
      "pre_rematch_text",
      "pre_rematch_caught_text",
      "pre_rematch_evolved_text",
      "pre_rematch_fused_text",
      "pre_rematch_unfused_text",
      "pre_rematch_reversed_text",
      "pre_rematch_gift_text",
      "trainer_info",
      "info_text",
      "pokemon",
      "edit_pokemon",
      "replace_pokemon",
      "add_pokemon"
    ].freeze

    POKEMON_FIELDS = [
      "species",
      "level",
      "form",
      "name",
      "moves",
      "moves_hard",
      "moves_easy",
      "ability",
      "ability_index",
      "item",
      "held_item",
      "gender",
      "nature",
      "iv",
      "ev",
      "happiness",
      "shininess",
      "shadowness",
      "poke_ball"
    ].freeze

    @base_entries = {}
    @managed_keys = {}
    @managed_numbers = {}
    MISSING_VALUE = Object.new.freeze
    OPTIONAL_TRAINER_FIELDS = [
      "loseText_rematch",
      "loseText_rematch_double",
      "battleText",
      "preRematchText",
      "preRematchText_caught",
      "preRematchText_evolved",
      "preRematchText_fused",
      "preRematchText_unfused",
      "preRematchText_reversed",
      "preRematchText_gift",
      "infoText"
    ].freeze

    class << self
      def install
        refresh_base_entries
        register_targets
        register_events
        KantoReloaded::Log.info("Installed KantoReloaded trainer data patch bridge", :mods) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Trainer data patch bridge install failed", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def register_targets
        return unless defined?(KantoReloaded::DataPatches)
        TARGETS.each_key do |target|
          KantoReloaded::DataPatches.register_target(
            target,
            @base_entries[target] || {},
            owner: :kanto_reloaded,
            description: "Runtime trainer party data patch target.",
            defer_missing_entries: true
          )
        end
      end

      def refresh_base_entries
        TARGETS.each do |target, class_name|
          klass = resolve_class(class_name)
          restore_managed_entries(target, klass) if trainer_class?(klass)
        end
        @base_entries = {}
        TARGETS.each do |target, class_name|
          @base_entries[target] = {}
          klass = resolve_class(class_name)
          next unless trainer_class?(klass)
          klass::DATA.each do |key, trainer|
            next if key.is_a?(Integer)
            next unless valid_trainer?(trainer)
            entry_id = trainer_entry_id(trainer.trainer_type, trainer.real_name, trainer.version)
            @base_entries[target][entry_id] = trainer_to_hash(trainer)
          end
        end
        @base_entries
      end

      def apply_all
        total = 0
        TARGETS.each do |target, class_name|
          klass = resolve_class(class_name)
          next unless trainer_class?(klass)
          next unless game_data_ready?(klass)
          restore_managed_entries(target, klass)
          count = apply_target(target, klass)
          total += count
          log_applied(target, count) if count > 0
        end
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to apply trainer data patches", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def apply_target(target, klass)
        applied = 0
        patched_trainer_ids(target).each do |entry_id|
          raw_data = KantoReloaded::DataPatches.entry(target, entry_id)
          validate_missing_trainer_target(target, entry_id)
          applied += 1 if apply_entry(target, klass, entry_id, raw_data)
        end
        applied
      end

      def restore_managed_entries(target, klass)
        return if @restoring_managed_entries
        @restoring_managed_entries = true
        Array(@managed_numbers[target]).each { |key| klass::DATA.delete(key) }
        Array(@managed_keys[target]).each do |key|
          entry_id = array_key_to_entry_id(key)
          if @base_entries[target] && @base_entries[target][entry_id]
            register_trainer(target, klass, @base_entries[target][entry_id], managed: false)
          else
            klass::DATA.delete(key)
          end
        end
        @managed_numbers[target] = []
        @managed_keys[target] = []
      ensure
        @restoring_managed_entries = false
      end

      def apply_entry(target, klass, entry_id, raw_data)
        data = normalize_data(target, entry_id, raw_data)
        return false unless data
        key = data[:id]
        id_number = data[:id_number]
        existing_number_owner = klass::DATA[id_number]
        if existing_number_owner && existing_number_owner.id != key && !managed_number?(target, id_number)
          log_error("Trainer patch #{entry_id} cannot use id_number #{id_number}; it already belongs to #{existing_number_owner.id.inspect}.")
          return false
        end
        register_trainer(target, klass, data, managed: true)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to apply trainer patch #{target}/#{entry_id}", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def register_trainer(target, klass, data, managed:)
        trainer = klass.new(data)
        trainer.instance_variable_set(:@kanto_reloaded_data_patch, true) if managed
        klass::DATA[data[:id]] = trainer
        klass::DATA[data[:id_number]] = trainer
        if managed
          @managed_keys[target] ||= []
          @managed_numbers[target] ||= []
          @managed_keys[target] << data[:id] unless @managed_keys[target].include?(data[:id])
          @managed_numbers[target] << data[:id_number] unless @managed_numbers[target].include?(data[:id_number])
        end
        trainer
      end

      def normalize_data(target, entry_id, raw_data)
        raw = stringify_keys(raw_data.is_a?(Hash) ? raw_data : {})
        base = base_entry(target, entry_id)
        data = {}
        TRAINER_FIELDS.each { |field| data[field] = raw.key?(field) ? raw[field] : base[field] }
        parsed_id = parse_entry_id(entry_id)
        data["trainer_type"] = parsed_id[0] if blank?(data["trainer_type"]) && parsed_id
        data["name"] = parsed_id[1] if blank?(data["name"]) && parsed_id
        data["version"] = parsed_id[2] if blank?(data["version"]) && parsed_id
        data["trainer_type"] = "TRAINER" if blank?(data["trainer_type"])
        data["name"] = "Unnamed" if blank?(data["name"])
        data["version"] = 0 if blank?(data["version"])
        data["items"] = data["bag_items"] if raw.key?("bag_items") && !raw.key?("items")
        apply_text_aliases(data, raw)
        data["id_number"] = next_id_number(target_class_for(target)) if blank?(data["id_number"])
        context = "#{target}/#{entry_id}"
        trainer_type = resolve_valid_data_id("GameData::TrainerType", data["trainer_type"], context, "trainer type", required: true)
        return nil unless trainer_type
        party = normalize_party(data["pokemon"], context)
        party = replace_party_slots(party, data["replace_pokemon"], context)
        party = edit_party_slots(party, data["edit_pokemon"], context)
        party = add_party_members(party, data["add_pokemon"], context)
        {
          :id => [trainer_type, data["name"].to_s, data["version"].to_i],
          :id_number => data["id_number"].to_i,
          :trainer_type => trainer_type,
          :name => data["name"].to_s,
          :version => data["version"].to_i,
          :items => normalize_valid_data_id_list("GameData::Item", data["items"], context, "trainer bag item"),
          :lose_text => blank?(data["lose_text"]) ? "..." : data["lose_text"].to_s,
          :pokemon => party,
          :loseText_rematch => blank?(data["loseText_rematch"]) ? nil : data["loseText_rematch"].to_s,
          :loseText_rematch_double => blank?(data["loseText_rematch_double"]) ? nil : data["loseText_rematch_double"].to_s,
          :battleText => blank?(data["battleText"]) ? nil : data["battleText"].to_s,
          :preRematchText => blank?(data["preRematchText"]) ? nil : data["preRematchText"].to_s,
          :preRematchText_caught => blank?(data["preRematchText_caught"]) ? nil : data["preRematchText_caught"].to_s,
          :preRematchText_evolved => blank?(data["preRematchText_evolved"]) ? nil : data["preRematchText_evolved"].to_s,
          :preRematchText_fused => blank?(data["preRematchText_fused"]) ? nil : data["preRematchText_fused"].to_s,
          :preRematchText_unfused => blank?(data["preRematchText_unfused"]) ? nil : data["preRematchText_unfused"].to_s,
          :preRematchText_reversed => blank?(data["preRematchText_reversed"]) ? nil : data["preRematchText_reversed"].to_s,
          :preRematchText_gift => blank?(data["preRematchText_gift"]) ? nil : data["preRematchText_gift"].to_s,
          :infoText => blank?(data["infoText"]) ? nil : data["infoText"].to_s
        }
      end

      def normalize_party(value, context)
        Array(value).each_with_index.map { |entry, index| normalize_pokemon(entry, nil, "#{context} pokemon[#{index}]") }.compact
      end

      def replace_party_slots(party, replacements, context)
        result = Array(party).map { |entry| deep_dup(entry) }
        Array(replacements).each do |entry|
          raw = stringify_keys(entry.is_a?(Hash) ? entry : {})
          slot = raw.key?("slot") ? raw["slot"].to_i : nil
          if slot.nil? || slot < 0 || slot >= result.length
            log_warning("Trainer patch #{context} ignored replace_pokemon entry with invalid slot #{raw["slot"].inspect}.")
            next
          end
          pokemon = normalize_pokemon(raw["data"] || raw["pokemon"] || raw, nil, "#{context} replace_pokemon[#{slot}]")
          result[slot] = pokemon if pokemon
        end
        result.compact
      end

      def edit_party_slots(party, edits, context)
        result = Array(party).map { |entry| deep_dup(entry) }
        Array(edits).each do |entry|
          raw = stringify_keys(entry.is_a?(Hash) ? entry : {})
          slot = raw.key?("slot") ? raw["slot"].to_i : nil
          if slot.nil? || slot < 0 || slot >= result.length
            log_warning("Trainer patch #{context} ignored edit_pokemon entry for missing slot #{raw["slot"].inspect}. Use add_pokemon to append new party members.")
            next
          end
          patch = raw["data"] || raw["pokemon"] || raw
          result[slot] = normalize_pokemon(patch, result[slot], "#{context} edit_pokemon[#{slot}]")
        end
        result.compact
      end

      def add_party_members(party, additions, context)
        result = Array(party).map { |entry| deep_dup(entry) }
        Array(additions).each_with_index do |entry, index|
          if result.length >= Settings::MAX_PARTY_SIZE
            log_warning("Trainer patch #{context} ignored add_pokemon[#{index}] because the party is already full.")
            break
          end
          pokemon = normalize_pokemon(entry, nil, "#{context} add_pokemon[#{index}]")
          result << pokemon if pokemon
        end
        result
      end

      def normalize_pokemon(value, base = nil, context = "trainer pokemon")
        raw = stringify_keys(value.is_a?(Hash) ? value : {})
        base_data = stringify_keys(base.is_a?(Hash) ? base : {})
        data = {}
        POKEMON_FIELDS.each { |field| data[field] = raw.key?(field) ? raw[field] : base_data[field] }
        return nil if blank?(data["species"])
        species = resolve_valid_data_id("GameData::Species", data["species"], context, "species", required: true)
        return nil unless species
        result = {
          :species => species,
          :level => int_value(data["level"], int_value(base_data["level"], 1))
        }
        if result[:level].to_i <= 0
          log_error("Trainer patch #{context} has invalid Pokemon level #{result[:level].inspect}.")
          return nil
        end
        result[:form] = data["form"].to_i unless blank?(data["form"])
        result[:name] = data["name"].to_s unless blank?(data["name"])
        result[:moves] = normalize_valid_data_id_list("GameData::Move", data["moves"], context, "move") if data.key?("moves") || raw.key?("moves")
        result[:moves_hard] = normalize_valid_data_id_list("GameData::Move", data["moves_hard"], context, "hard-mode move") if data.key?("moves_hard") || raw.key?("moves_hard")
        result[:moves_easy] = normalize_valid_data_id_list("GameData::Move", data["moves_easy"], context, "easy-mode move") if data.key?("moves_easy") || raw.key?("moves_easy")
        unless blank?(data["ability"])
          ability = resolve_valid_data_id("GameData::Ability", data["ability"], context, "ability")
          result[:ability] = ability if ability
        end
        result[:ability_index] = data["ability_index"].to_i unless blank?(data["ability_index"])
        data["item"] = data["held_item"] if blank?(data["item"]) && !blank?(data["held_item"])
        unless blank?(data["item"])
          item = resolve_valid_data_id("GameData::Item", data["item"], context, "held item")
          result[:item] = item if item
        end
        result[:gender] = normalize_gender(data["gender"]) unless blank?(data["gender"])
        unless blank?(data["nature"])
          nature = resolve_valid_data_id("GameData::Nature", data["nature"], context, "nature")
          result[:nature] = nature if nature
        end
        result[:iv] = normalize_stat_hash(data["iv"], context, "iv") if data["iv"].is_a?(Hash)
        result[:ev] = normalize_stat_hash(data["ev"], context, "ev") if data["ev"].is_a?(Hash)
        result[:happiness] = data["happiness"].to_i unless blank?(data["happiness"])
        result[:shininess] = truthy?(data["shininess"]) unless blank?(data["shininess"])
        result[:shadowness] = truthy?(data["shadowness"]) unless blank?(data["shadowness"])
        result[:poke_ball] = data["poke_ball"].to_s unless blank?(data["poke_ball"])
        result
      end

      def trainer_to_hash(trainer)
        result = {
          "id" => trainer_entry_id(trainer.trainer_type, trainer.real_name, trainer.version),
          "id_number" => trainer.id_number,
          "trainer_type" => trainer.trainer_type.to_s,
          "name" => trainer.real_name.to_s,
          "version" => trainer.version.to_i,
          "items" => Array(trainer.items).map(&:to_s),
          "lose_text" => trainer.real_lose_text.to_s,
          "pokemon" => Array(trainer.pokemon).map { |entry| pokemon_to_hash(entry) }
        }
        OPTIONAL_TRAINER_FIELDS.each do |field|
          value = optional_trainer_value(trainer, field)
          result[field] = value unless value.equal?(MISSING_VALUE)
        end
        result
      end

      def optional_trainer_value(trainer, field)
        method_name = field.to_sym
        return trainer.public_send(method_name) if trainer.respond_to?(method_name)
        variable = :"@#{field}"
        return trainer.instance_variable_get(variable) if trainer.instance_variable_defined?(variable)
        MISSING_VALUE
      rescue
        MISSING_VALUE
      end

      def apply_text_aliases(data, raw)
        apply_alias(data, raw, "rematch_lose_text", "loseText_rematch")
        apply_alias(data, raw, "rematch_double_lose_text", "loseText_rematch_double")
        apply_alias(data, raw, "battle_text", "battleText")
        apply_alias(data, raw, "pre_rematch_text", "preRematchText")
        apply_alias(data, raw, "pre_rematch_caught_text", "preRematchText_caught")
        apply_alias(data, raw, "pre_rematch_evolved_text", "preRematchText_evolved")
        apply_alias(data, raw, "pre_rematch_fused_text", "preRematchText_fused")
        apply_alias(data, raw, "pre_rematch_unfused_text", "preRematchText_unfused")
        apply_alias(data, raw, "pre_rematch_reversed_text", "preRematchText_reversed")
        apply_alias(data, raw, "pre_rematch_gift_text", "preRematchText_gift")
        apply_alias(data, raw, "trainer_info", "infoText")
        apply_alias(data, raw, "info_text", "infoText")
      end

      def apply_alias(data, raw, alias_key, engine_key)
        data[engine_key] = data[alias_key] if raw.key?(alias_key) && !raw.key?(engine_key)
      end

      def pokemon_to_hash(entry)
        hash = {}
        return hash unless entry.is_a?(Hash)
        POKEMON_FIELDS.each do |field|
          key = field.to_sym
          next unless entry.key?(key)
          value = entry[key]
          hash[field] = value.is_a?(Symbol) ? value.to_s : value
        end
        hash
      end

      def base_entry(target, entry_id)
        (@base_entries[target] || {})[normalize_entry_id_from_value(entry_id)] || {}
      end

      def patched_trainer_ids(target)
        patched_trainer_patches(target).map { |patch| patch[:id] }.uniq
      rescue
        []
      end

      def patched_trainer_patches(target)
        return [] unless defined?(KantoReloaded::DataPatches)
        KantoReloaded::DataPatches.applied(target)
      rescue
        []
      end

      def target_class_for(target)
        resolve_class(TARGETS[target])
      end

      def trainer_class?(klass)
        klass && klass.const_defined?(:DATA) && klass.respond_to?(:new)
      end

      def valid_trainer?(trainer)
        trainer && trainer.respond_to?(:trainer_type) && trainer.respond_to?(:real_name) &&
          trainer.respond_to?(:version) && trainer.respond_to?(:pokemon)
      end

      def trainer_entry_id(trainer_type, name, version)
        "#{normalize_symbol(trainer_type)}|#{name}|#{version.to_i}"
      end

      def array_key_to_entry_id(key)
        return "" unless key.is_a?(Array)
        trainer_entry_id(key[0], key[1], key[2] || 0)
      end

      def parse_entry_id(value)
        parts = value.to_s.split("|", 3)
        return nil if parts.length < 2
        [parts[0], parts[1], (parts[2] || 0).to_i]
      end

      def normalize_entry_id_from_value(value)
        parsed = parse_entry_id(value)
        return trainer_entry_id(parsed[0], parsed[1], parsed[2]) if parsed
        value.to_s
      end

      def next_id_number(klass)
        return 1 unless trainer_class?(klass)
        keys = []
        klass::DATA.each_key { |key| keys << key if key.is_a?(Integer) }
        value = keys.empty? ? 1 : keys.max + 1
        value += 1 while klass::DATA.key?(value)
        value
      end

      def managed_number?(target, key)
        Array(@managed_numbers[target]).include?(key)
      end

      def validate_missing_trainer_target(target, entry_id)
        return unless base_entry(target, entry_id).empty?
        operations = patched_trainer_patches(target).select { |patch| patch[:id] == entry_id }.map { |patch| patch[:operation] }
        return if operations.include?("add")
        log_warning("Trainer patch #{target}/#{entry_id} targets a missing trainer. Use operation add for new trainers, or check the trainer type/name/version.")
      rescue
      end

      def normalize_stat_hash(value, context = "trainer pokemon", label = "stat")
        raw = stringify_keys(value.is_a?(Hash) ? value : {})
        result = {}
        valid_keys = stat_ids.map(&:to_s)
        raw.keys.each do |key|
          next if valid_keys.include?(key.to_s.upcase)
          log_warning("Trainer patch #{context} ignored unknown #{label} stat #{key.inspect}.")
        end
        stat_ids.each do |stat|
          string_id = stat.to_s
          raw_value = raw.key?(string_id) ? raw[string_id] : raw[string_id.downcase]
          next if raw_value.nil?
          amount = raw_value.to_i
          if amount < 0
            log_warning("Trainer patch #{context} clamped negative #{label}.#{stat}=#{raw_value.inspect} to 0.")
            amount = 0
          end
          result[stat] = amount
        end
        result
      end

      def stat_ids
        ids = []
        GameData::Stat.each_main { |stat| ids << stat.id } if defined?(GameData::Stat)
        ids.empty? ? [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED] : ids
      rescue
        [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
      end

      def normalize_data_id_list(class_name, value)
        Array(value).map { |entry| resolve_data_id(class_name, entry, nil) }.compact.reject { |entry| entry.to_s.empty? }
      end

      def normalize_valid_data_id_list(class_name, value, context, label)
        Array(value).map do |entry|
          resolve_valid_data_id(class_name, entry, context, label)
        end.compact.reject { |entry| entry.to_s.empty? }
      end

      def resolve_valid_data_id(class_name, value, context, label, required: false)
        return nil if blank?(value)
        resolved = resolve_data_id(class_name, value, nil)
        return resolved if data_id_exists?(class_name, resolved)
        message = "Trainer patch #{context} references unknown #{label} #{value.inspect}."
        required ? log_error(message) : log_warning(message)
        nil
      end

      def data_id_exists?(class_name, value)
        klass = resolve_class(class_name)
        return true unless klass && klass.const_defined?(:DATA)
        klass::DATA.key?(value)
      rescue
        true
      end

      def resolve_data_id(class_name, value, default = nil)
        return default if blank?(value)
        klass = resolve_class(class_name)
        exact = value.is_a?(Symbol) ? value : value.to_s.to_sym
        return exact if klass && klass.const_defined?(:DATA) && klass::DATA.key?(exact)
        normalized_value = normalize_lookup_key(value)
        if klass && klass.const_defined?(:DATA)
          klass::DATA.keys.each do |key|
            next if key.is_a?(Integer)
            return key if normalize_lookup_key(key) == normalized_value
          end
        end
        normalize_symbol(value)
      rescue
        blank?(value) ? default : normalize_symbol(value)
      end

      def resolve_class(class_name)
        class_name.to_s.split("::").inject(Object) do |scope, name|
          return nil unless scope.const_defined?(name)
          scope.const_get(name)
        end
      rescue
        nil
      end

      def normalize_gender(value)
        normalized = value.to_s.strip.downcase
        return 0 if ["m", "male", "0"].include?(normalized)
        return 1 if ["f", "female", "1"].include?(normalized)
        value.to_i
      end

      def truthy?(value)
        return value if value == true || value == false
        ["true", "yes", "on", "1"].include?(value.to_s.strip.downcase)
      end

      def int_value(value, default)
        return default if blank?(value)
        value.to_i
      end

      def normalize_symbol(value)
        value.to_s.strip.upcase.gsub(/[^A-Z0-9_]+/, "_").to_sym
      end

      def normalize_lookup_key(value)
        value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "")
      end

      def stringify_keys(hash)
        result = {}
        hash.each { |key, value| result[key.to_s] = value } if hash.respond_to?(:each)
        result
      rescue
        {}
      end

      def deep_dup(value)
        Marshal.load(Marshal.dump(value))
      rescue
        value.is_a?(Hash) ? value.dup : value
      end

      def blank?(value)
        value.nil? || value.to_s.strip.empty?
      end

      def game_data_ready?(klass)
        trainer_class?(klass) &&
          !klass::DATA.empty? &&
          data_table_ready?("GameData::TrainerType") &&
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

      def register_events
        return unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(:game_data_loaded, :trainer_data_patch_target_refresh, priority: 50) do |_context|
          if defined?(KantoReloaded::DataPatchTrainers)
            KantoReloaded::DataPatchTrainers.send(:refresh_base_entries)
            KantoReloaded::DataPatchTrainers.register_targets
          end
        end
        KantoReloaded::Events.on(:data_patches_loaded, :trainer_data_patch_bridge, priority: 100) do |_context|
          KantoReloaded::DataPatchTrainers.apply_all if defined?(KantoReloaded::DataPatchTrainers)
        end
      end

      def log_applied(target, count)
        return unless defined?(KantoReloaded::Log)
        KantoReloaded::Log.info("Applied #{count} #{target} data patch #{count == 1 ? 'entry' : 'entries'}", :mods)
      end

      def log_error(message)
        if defined?(KantoReloaded::Log)
          if KantoReloaded::Log.respond_to?(:error_once)
            KantoReloaded::Log.error_once(message, :mods, key: "trainer_data_patch_error:#{message}")
          else
            KantoReloaded::Log.error(message, :mods)
          end
        end
      end

      def log_warning(message)
        if defined?(KantoReloaded::Log)
          if KantoReloaded::Log.respond_to?(:warning_once)
            KantoReloaded::Log.warning_once(message, :mods, key: "trainer_data_patch_warning:#{message}")
          else
            KantoReloaded::Log.warning(message, :mods)
          end
        end
      end

    end
  end
end

KantoReloaded::DataPatchTrainers.install if defined?(KantoReloaded::DataPatchTrainers)
