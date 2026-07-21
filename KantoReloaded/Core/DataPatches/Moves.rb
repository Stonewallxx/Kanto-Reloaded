#======================================================
# KantoReloaded Data Patch Moves
# Author: Stonewall
#======================================================
# Direct runtime data patch target for base-game move data.
#
# Responsibilities:
#   - Register the move data patch target.
#   - Apply patched move entries to GameData::Move::DATA.
#   - Refresh the move target after GameData.load_all refreshes base data.
#   - Restore KantoReloaded-managed move entries before each rebuild.
#   - Provide safe text fallbacks for modded move names and descriptions.
#
#======================================================

module KantoReloaded
  module DataPatchMoves
    TARGET = "moves".freeze

    MOVE_FIELDS = [
      "id",
      "id_number",
      "name",
      "function_code",
      "base_damage",
      "type",
      "category",
      "accuracy",
      "total_pp",
      "effect_chance",
      "target",
      "priority",
      "flags",
      "description"
    ].freeze

    CATEGORY_VALUES = {
      "physical" => 0,
      "special" => 1,
      "status" => 2
    }.freeze

    @base_entries = {}
    @managed_symbols = []
    @managed_numbers = []

    class << self
      def install
        install_text_fallbacks
        register_target
        register_events
        KantoReloaded::Log.info("Installed KantoReloaded move data patch bridge", :mods) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Move data patch bridge install failed", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def register_target
        return unless defined?(KantoReloaded::DataPatches)
        refresh_base_entries
        KantoReloaded::DataPatches.register_target(
          TARGET,
          @base_entries,
          owner: :kanto_reloaded,
          description: "Runtime move data patch target."
        )
      end

      def apply_all
        return false unless defined?(GameData::Move)
        return true unless game_data_ready?
        restore_managed_entries
        touched_ids = patched_move_ids
        applied = 0
        touched_ids.each do |id|
          raw_data = KantoReloaded::DataPatches.entry(TARGET, id)
          applied += 1 if apply_entry(id, raw_data)
        end
        log_applied(applied) if applied > 0
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to apply move data patches", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      private

      def refresh_base_entries
        @base_entries = {}
        return unless defined?(GameData::Move)
        GameData::Move::DATA.each do |key, move|
          next if key.is_a?(Integer)
          next unless move.is_a?(GameData::Move)
          @base_entries[key.to_s] = move_to_hash(move)
        end
        @base_entries
      end

      def move_to_hash(move)
        {
          "id" => move.id.to_s,
          "id_number" => move.id_number,
          "name" => move.real_name,
          "function_code" => move.function_code,
          "base_damage" => move.base_damage,
          "type" => move.type ? move.type.to_s : nil,
          "category" => move.category,
          "accuracy" => move.accuracy,
          "total_pp" => move.total_pp,
          "effect_chance" => move.effect_chance,
          "target" => move.target ? move.target.to_s : nil,
          "priority" => move.priority,
          "flags" => move.flags,
          "description" => move.real_description
        }
      end

      def restore_managed_entries
        return unless defined?(GameData::Move)
        Array(@managed_numbers).each { |key| GameData::Move::DATA.delete(key) }
        Array(@managed_symbols).each do |key|
          if @base_entries.key?(key.to_s)
            restore_base_entry(key.to_s)
          else
            GameData::Move::DATA.delete(key)
          end
        end
        @managed_symbols = []
        @managed_numbers = []
      end

      def restore_base_entry(id)
        data = normalize_data(id, @base_entries[id])
        move = GameData::Move.new(data)
        GameData::Move::DATA[data[:id]] = move
        GameData::Move::DATA[data[:id_number]] = move
      end

      def apply_entry(id, raw_data)
        data = normalize_data(id, raw_data)
        return false unless validate_data(data)
        id_symbol = data[:id]
        id_number = data[:id_number]
        existing_number_owner = GameData::Move::DATA[id_number]
        if existing_number_owner && existing_number_owner.id != id_symbol && !managed_number?(id_number)
          log_error("Move patch #{id_symbol} cannot use id_number #{id_number}; it already belongs to #{existing_number_owner.id}.")
          return false
        end

        move = GameData::Move.new(data)
        move.instance_variable_set(:@kanto_reloaded_data_patch, true)
        GameData::Move::DATA[id_symbol] = move
        GameData::Move::DATA[id_number] = move
        @managed_symbols << id_symbol unless @managed_symbols.include?(id_symbol)
        @managed_numbers << id_number unless @managed_numbers.include?(id_number)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to apply move patch #{id}", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def normalize_data(id, raw_data)
        raw = stringify_keys(raw_data.is_a?(Hash) ? raw_data : {})
        base = base_entry(id)
        data = {}
        MOVE_FIELDS.each { |field| data[field] = raw.key?(field) ? raw[field] : base[field] }
        data["id"] = id if blank?(data["id"])
        data["id_number"] = next_id_number if blank?(data["id_number"])
        data["name"] = data["id"].to_s if blank?(data["name"])
        data["function_code"] = "000" if blank?(data["function_code"])
        data["base_damage"] = 0 if blank?(data["base_damage"])
        data["type"] = "NORMAL" if blank?(data["type"])
        data["category"] = data["base_damage"].to_i == 0 ? 2 : 0 if blank?(data["category"])
        data["accuracy"] = 100 if blank?(data["accuracy"])
        data["total_pp"] = 5 if blank?(data["total_pp"])
        data["effect_chance"] = 0 if blank?(data["effect_chance"])
        data["target"] = "NearOther" if blank?(data["target"])
        data["priority"] = 0 if blank?(data["priority"])
        data["flags"] = "" if data["flags"].nil?
        data["description"] = "???" if blank?(data["description"])

        {
          :id => normalize_symbol(data["id"]),
          :id_number => data["id_number"].to_i,
          :name => data["name"].to_s,
          :function_code => normalize_function_code(data["function_code"]),
          :base_damage => data["base_damage"].to_i,
          :type => normalize_symbol(data["type"]),
          :category => normalize_category(data["category"]),
          :accuracy => data["accuracy"].to_i,
          :total_pp => data["total_pp"].to_i,
          :effect_chance => data["effect_chance"].to_i,
          :target => resolve_data_id("GameData::Target", data["target"], :NearOther),
          :priority => data["priority"].to_i,
          :flags => data["flags"].to_s,
          :description => data["description"].to_s
        }
      end

      def validate_data(data)
        unless data[:id_number].is_a?(Integer) && data[:id_number] > 0
          log_error("Move patch #{data[:id]} has invalid id_number #{data[:id_number].inspect}.")
          return false
        end
        unless data_id_exists?("GameData::Type", data[:type])
          log_error("Move patch #{data[:id]} references unknown type #{data[:type]}.")
          return false
        end
        unless data_id_exists?("GameData::Target", data[:target])
          log_error("Move patch #{data[:id]} references unknown target #{data[:target]}.")
          return false
        end
        unless [0, 1, 2].include?(data[:category].to_i)
          log_error("Move patch #{data[:id]} has invalid category #{data[:category].inspect}.")
          return false
        end
        if data[:accuracy].to_i < 0 || data[:accuracy].to_i > 100
          log_error("Move patch #{data[:id]} has invalid accuracy #{data[:accuracy].inspect}.")
          return false
        end
        if data[:total_pp].to_i <= 0
          log_error("Move patch #{data[:id]} has invalid total_pp #{data[:total_pp].inspect}.")
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
        GameData::Move::DATA.each_key { |key| keys << key if key.is_a?(Integer) }
        value = keys.empty? ? 1 : keys.max + 1
        value += 1 while GameData::Move::DATA.key?(value)
        value
      end

      def patched_move_ids
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

      def normalize_function_code(value)
        value.to_s.strip.upcase
      end

      def normalize_category(value)
        return value.to_i if value.to_s =~ /\A-?\d+\z/
        CATEGORY_VALUES[value.to_s.strip.downcase] || 0
      end

      def stringify_keys(hash)
        result = {}
        hash.each { |key, value| result[key.to_s] = value }
        result
      rescue
        {}
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

      def normalize_lookup_key(value)
        value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "")
      end

      def blank?(value)
        value.nil? || value.to_s.strip.empty?
      end

      def data_id_exists?(class_name, value)
        klass = resolve_class(class_name)
        return true unless klass && klass.const_defined?(:DATA)
        klass::DATA.key?(value)
      rescue
        true
      end

      def game_data_ready?
        defined?(GameData::Move) &&
          GameData::Move.const_defined?(:DATA) &&
          !GameData::Move::DATA.empty? &&
          data_table_ready?("GameData::Type") &&
          data_table_ready?("GameData::Target")
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

      def log_applied(count)
        message = "Applied #{count} move data patch entr#{count == 1 ? 'y' : 'ies'}"
        if defined?(KantoReloaded::Log)
          if KantoReloaded::Log.respond_to?(:info_once)
            KantoReloaded::Log.info_once(message, :mods, key: "move_data_patch_applied:#{count}")
          else
            KantoReloaded::Log.info(message, :mods)
          end
        end
      end

      def log_error(message)
        if defined?(KantoReloaded::Log)
          if KantoReloaded::Log.respond_to?(:error_once)
            KantoReloaded::Log.error_once(message, :mods, key: "move_data_patch_error:#{message}")
          else
            KantoReloaded::Log.error(message, :mods)
          end
        end
      end

      def register_events
        return unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(:game_data_loaded, :move_data_patch_target_refresh, priority: 50) do |_context|
          KantoReloaded::DataPatchMoves.register_target if defined?(KantoReloaded::DataPatchMoves)
        end
        KantoReloaded::Events.on(:data_patches_loaded, :move_data_patch_bridge, priority: 100) do |_context|
          KantoReloaded::DataPatchMoves.apply_all if defined?(KantoReloaded::DataPatchMoves)
        end
      end

      def install_text_fallbacks
        return unless defined?(GameData::Move)
        GameData::Move.class_eval do
          def kanto_reloaded_data_patch_move?
            !!@kanto_reloaded_data_patch
          end
        end
        KantoReloaded::Hooks.wrap(GameData::Move, :name, :data_patch_move_name) do |hook, *_args|
          kanto_reloaded_data_patch_move? ? @real_name : hook.call
        end
        KantoReloaded::Hooks.wrap(GameData::Move, :description, :data_patch_move_description) do |hook, *_args|
          kanto_reloaded_data_patch_move? ? @real_description : hook.call
        end
      end

    end
  end
end

KantoReloaded::DataPatchMoves.install if defined?(KantoReloaded::DataPatchMoves)
