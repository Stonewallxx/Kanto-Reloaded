#======================================================
# KantoReloaded Data Patch Items
# Author: Stonewall
#======================================================
# Direct runtime data patch target for base-game item data.
#
# Responsibilities:
#   - Register the item data patch target.
#   - Apply patched item entries to GameData::Item::DATA.
#   - Refresh the item target after GameData.load_all refreshes base data.
#   - Restore KantoReloaded-managed item entries before each rebuild.
#   - Provide safe text fallbacks for modded item names and descriptions.
#
#======================================================

module KantoReloaded
  module DataPatchItems
    TARGET = "items".freeze

    ITEM_FIELDS = [
      "id",
      "id_number",
      "name",
      "name_plural",
      "pocket",
      "price",
      "description",
      "field_use",
      "battle_use",
      "type",
      "move"
    ].freeze

    @base_entries = {}
    @managed_symbols = []
    @managed_numbers = []

    class << self
      def install
        install_text_fallbacks
        register_target
        register_events
        KantoReloaded::Log.info("Installed KantoReloaded item data patch bridge", :mods) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Item data patch bridge install failed", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def register_target
        return unless defined?(KantoReloaded::DataPatches)
        refresh_base_entries
        KantoReloaded::DataPatches.register_target(
          TARGET,
          @base_entries,
          owner: :kanto_reloaded,
          description: "Runtime item data patch target."
        )
      end

      def apply_all
        return false unless defined?(GameData::Item)
        return true unless game_data_ready?
        restore_managed_entries
        patches = patched_item_patches
        visible_ids = patches.reject { |patch| hidden_patch?(patch) }.map { |patch| patch[:id] }.uniq
        touched_ids = patches.map { |patch| patch[:id] }.uniq
        applied = 0
        touched_ids.each do |id|
          raw_data = KantoReloaded::DataPatches.entry(TARGET, id)
          next unless apply_entry(id, raw_data)
          applied += 1 if visible_ids.include?(id)
        end
        log_applied(applied) if applied > 0
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to apply item data patches", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      private

      def refresh_base_entries
        @base_entries = {}
        return unless defined?(GameData::Item)
        GameData::Item::DATA.each do |key, item|
          next if key.is_a?(Integer)
          next unless item.is_a?(GameData::Item)
          @base_entries[key.to_s] = item_to_hash(item)
        end
        @base_entries
      end

      def item_to_hash(item)
        {
          "id" => item.id.to_s,
          "id_number" => item.id_number,
          "name" => item.real_name,
          "name_plural" => item.real_name_plural,
          "pocket" => item.pocket,
          "price" => item.price,
          "description" => item.real_description,
          "field_use" => item.field_use,
          "battle_use" => item.battle_use,
          "type" => item.type,
          "move" => item.move ? item.move.to_s : nil
        }
      end

      def restore_managed_entries
        return unless defined?(GameData::Item)
        Array(@managed_numbers).each { |key| GameData::Item::DATA.delete(key) }
        Array(@managed_symbols).each do |key|
          if @base_entries.key?(key.to_s)
            restore_base_entry(key.to_s)
          else
            GameData::Item::DATA.delete(key)
          end
        end
        @managed_symbols = []
        @managed_numbers = []
      end

      def restore_base_entry(id)
        data = normalize_data(id, @base_entries[id])
        item = GameData::Item.new(data)
        GameData::Item::DATA[data[:id]] = item
        GameData::Item::DATA[data[:id_number]] = item
      end

      def apply_entry(id, raw_data)
        data = normalize_data(id, raw_data)
        return false unless validate_data(data)
        id_symbol = data[:id]
        id_number = data[:id_number]
        existing_number_owner = GameData::Item::DATA[id_number]
        if existing_number_owner && existing_number_owner.id != id_symbol && !managed_number?(id_number)
          log_error("Item patch #{id_symbol} cannot use id_number #{id_number}; it already belongs to #{existing_number_owner.id}.")
          return false
        end

        item = GameData::Item.new(data)
        item.instance_variable_set(:@kanto_reloaded_data_patch, true)
        GameData::Item::DATA[id_symbol] = item
        GameData::Item::DATA[id_number] = item
        @managed_symbols << id_symbol unless @managed_symbols.include?(id_symbol)
        @managed_numbers << id_number unless @managed_numbers.include?(id_number)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to apply item patch #{id}", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def normalize_data(id, raw_data)
        raw = stringify_keys(raw_data.is_a?(Hash) ? raw_data : {})
        base = base_entry(id)
        data = {}
        ITEM_FIELDS.each { |field| data[field] = raw.key?(field) ? raw[field] : base[field] }
        data["id"] = id if blank?(data["id"])
        data["id_number"] = next_id_number if blank?(data["id_number"])
        data["name"] = data["id"].to_s if blank?(data["name"])
        data["name_plural"] = data["name"] if blank?(data["name_plural"])
        data["description"] = "???" if blank?(data["description"])

        {
          :id => normalize_symbol(data["id"]),
          :id_number => data["id_number"].to_i,
          :name => data["name"].to_s,
          :name_plural => data["name_plural"].to_s,
          :pocket => data["pocket"].to_i,
          :price => data["price"].to_i,
          :description => data["description"].to_s,
          :field_use => data["field_use"].to_i,
          :battle_use => data["battle_use"].to_i,
          :type => data["type"].to_i,
          :move => blank?(data["move"]) ? nil : normalize_symbol(data["move"])
        }
      end

      def validate_data(data)
        unless data[:id_number].is_a?(Integer) && data[:id_number] > 0
          log_error("Item patch #{data[:id]} has invalid id_number #{data[:id_number].inspect}.")
          return false
        end
        if data[:move] && !data_id_exists?("GameData::Move", data[:move])
          log_error("Item patch #{data[:id]} references unknown move #{data[:move]}.")
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
        GameData::Item::DATA.each_key { |key| keys << key if key.is_a?(Integer) }
        value = keys.empty? ? 1 : keys.max + 1
        value += 1 while GameData::Item::DATA.key?(value)
        value
      end

      def patched_item_patches
        return [] unless defined?(KantoReloaded::DataPatches)
        if KantoReloaded::DataPatches.respond_to?(:applied_all)
          return KantoReloaded::DataPatches.applied_all(TARGET)
        end
        KantoReloaded::DataPatches.applied(TARGET)
      rescue
        []
      end

      def hidden_patch?(patch)
        !!(patch && patch[:hidden])
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
        defined?(GameData::Item) &&
          GameData::Item.const_defined?(:DATA) &&
          !GameData::Item::DATA.empty?
      rescue
        false
      end

      def data_id_exists?(class_name, value)
        klass = resolve_class(class_name)
        return true unless klass && klass.const_defined?(:DATA)
        klass::DATA.key?(value)
      rescue
        true
      end

      def resolve_class(class_name)
        class_name.to_s.split("::").inject(Object) do |scope, name|
          return nil unless scope.const_defined?(name)
          scope.const_get(name)
        end
      rescue
        nil
      end

      def log_applied(count)
        message = "Applied #{count} item data patch entr#{count == 1 ? 'y' : 'ies'}"
        if defined?(KantoReloaded::Log)
          if KantoReloaded::Log.respond_to?(:info_once)
            KantoReloaded::Log.info_once(message, :mods, key: "item_data_patch_applied:#{count}")
          else
            KantoReloaded::Log.info(message, :mods)
          end
        end
      end

      def log_error(message)
        if defined?(KantoReloaded::Log)
          if KantoReloaded::Log.respond_to?(:error_once)
            KantoReloaded::Log.error_once(message, :mods, key: "item_data_patch_error:#{message}")
          else
            KantoReloaded::Log.error(message, :mods)
          end
        end
      end

      def register_events
        return unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(:game_data_loaded, :item_data_patch_target_refresh, priority: 50) do |_context|
          KantoReloaded::DataPatchItems.register_target if defined?(KantoReloaded::DataPatchItems)
        end
        KantoReloaded::Events.on(:data_patches_loaded, :item_data_patch_bridge, priority: 100) do |_context|
          KantoReloaded::DataPatchItems.apply_all if defined?(KantoReloaded::DataPatchItems)
        end
      end

      private

      def install_text_fallbacks
        return unless defined?(GameData::Item)
        GameData::Item.class_eval do
          def kanto_reloaded_data_patch_item?
            !!@kanto_reloaded_data_patch
          end
        end
        KantoReloaded::Hooks.wrap(GameData::Item, :name, :data_patch_item_name) do |hook, *_args|
          kanto_reloaded_data_patch_item? ? @real_name : hook.call
        end
        KantoReloaded::Hooks.wrap(GameData::Item, :name_plural, :data_patch_item_name_plural) do |hook, *_args|
          kanto_reloaded_data_patch_item? ? @real_name_plural : hook.call
        end
        KantoReloaded::Hooks.wrap(GameData::Item, :description, :data_patch_item_description) do |hook, *_args|
          kanto_reloaded_data_patch_item? ? @real_description : hook.call
        end
      end

    end
  end
end

KantoReloaded::DataPatchItems.install if defined?(KantoReloaded::DataPatchItems)
