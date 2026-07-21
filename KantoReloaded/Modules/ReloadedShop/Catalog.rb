#==============================================================================
# Kanto Reloaded - Reloaded Shop Catalog
#==============================================================================

begin
  require "json"
rescue LoadError
end

module KantoReloaded
  module ReloadedShop
    module Catalog
      SCHEMA_VERSION = 1
      SAVE_OWNER = :reloaded_shop
      EXPORT_FILE = "ReloadedShopCatalog.json"

      class << self
        def state
          bucket = if defined?(KantoReloaded::SaveData)
                     KantoReloaded::SaveData.module_data(SAVE_OWNER)
                   else
                     @fallback ||= {}
                   end
          normalize_state!(bucket)
          bucket
        end

        def categories
          state["categories"].sort_by { |entry| entry["order"].to_i }.
            map { |entry| entry.dup }
        end

        def category_name(id)
          entry = categories.find { |row| row["id"] == id.to_s }
          entry ? entry["name"] : id.to_s
        end

        def entries(stock, adapter)
          runtime = runtime_rows(stock, adapter)
          custom_rows(adapter).each do |row|
            runtime << row unless runtime.any? { |known| known[:id] == row[:id] }
          end
          category_order = {}
          categories.each_with_index { |entry, index| category_order[entry["id"]] = index }
          runtime.select { |row| row[:enabled] }.sort_by do |row|
            [
              category_order.fetch(row[:category], categories.length),
              row[:order].to_i,
              row[:name].to_s.downcase
            ]
          end
        end

        def editor_entries(adapter = nil)
          source = Defaults::KIF_ITEM_IDS
          rows = runtime_rows(source, adapter || default_adapter, true)
          custom_rows(adapter || default_adapter).each do |row|
            rows << row unless rows.any? { |known| known[:id] == row[:id] }
          end
          rows
        end

        def find_entry(item, stock = nil, adapter = nil)
          id = normalize_item_id(item)
          return nil unless id
          entries(stock || Defaults::KIF_ITEM_IDS, adapter || default_adapter).
            find { |entry| entry[:id] == id }
        end

        def favorite?(item)
          state["favorites"].include?(item_key(item))
        end

        def toggle_favorite(item)
          key = item_key(item)
          return false unless key
          values = state["favorites"]
          values.include?(key) ? values.delete(key) : values << key
          true
        end

        def update_item(item, values)
          key = item_key(item)
          return false unless key
          current = state["entries"][key] ||= {}
          values.each do |name, value|
            normalized = name.to_s
            next unless %w[category order buy_price sell_price enabled added].include?(normalized)
            current[normalized] = value
          end
          true
        end

        def add_item(item, category = nil)
          data = item_data(item)
          return false unless data
          bucket = state
          key = data.id.to_s
          bucket["hidden"].delete(key)
          existing = bucket["entries"][key] ||= {}
          existing["added"] = true
          existing["enabled"] = true
          existing["category"] = valid_category(category, bucket) ||
                                 valid_category(
                                   Defaults.category_for(data.id), bucket
                                 ) ||
                                 bucket["categories"].first["id"]
          existing["order"] ||= next_order(existing["category"], bucket)
          true
        end

        def remove_item(item)
          data = item_data(item)
          return false unless data
          key = data.id.to_s
          if state["entries"].dig(key, "added")
            state["entries"].delete(key)
          else
            state["hidden"] << key unless state["hidden"].include?(key)
          end
          state["favorites"].delete(key)
          true
        end

        def restore_item(item)
          key = item_key(item)
          return false unless key
          state["hidden"].delete(key)
          state["entries"].delete(key)
          true
        end

        def add_category(name)
          clean = sanitize_name(name)
          return nil if clean.empty?
          bucket = state
          ordered = bucket["categories"]
          base = clean.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
          base = "category" if base.empty?
          id = base
          suffix = 2
          known = ordered.map { |entry| entry["id"] }
          while known.include?(id)
            id = "#{base}_#{suffix}"
            suffix += 1
          end
          ordered << {
            "id" => id, "name" => clean, "order" => ordered.length
          }
          id
        end

        def rename_category(id, name)
          clean = sanitize_name(name)
          return false if clean.empty?
          entry = state["categories"].find { |row| row["id"] == id.to_s }
          return false unless entry
          entry["name"] = clean
          true
        end

        def move_category(id, amount)
          ordered = categories
          index = ordered.index { |row| row["id"] == id.to_s }
          return false unless index
          target = [[index + amount.to_i, 0].max, ordered.length - 1].min
          return false if target == index
          row = ordered.delete_at(index)
          ordered.insert(target, row)
          ordered.each_with_index { |entry, order| entry["order"] = order }
          state["categories"] = ordered
          true
        end

        def remove_category(id)
          key = id.to_s
          return false if categories.length <= 1
          removed = state["categories"].find { |row| row["id"] == key }
          return false unless removed
          fallback = categories.find { |row| row["id"] != key }
          state["categories"].delete(removed)
          state["entries"].each_value do |entry|
            entry["category"] = fallback["id"] if entry["category"] == key
          end
          reorder_categories!
          true
        end

        def reset!
          bucket = state
          bucket.clear
          normalize_state!(bucket)
          true
        end

        def export
          return [false, _INTL("JSON support is unavailable.")] unless defined?(JSON)
          ensure_export_directory
          payload = {
            "format" => "Kanto Reloaded Reloaded Shop",
            "schema_version" => SCHEMA_VERSION,
            "catalog" => deep_copy(state)
          }
          File.binwrite(export_path, JSON.generate(payload))
          [true, _INTL("RLD Shop catalog exported to {1}.", EXPORT_FILE)]
        rescue StandardError => e
          log_exception("RLD Shop export failed", e)
          [false, _INTL("RLD Shop catalog export failed.")]
        end

        def import
          return [false, _INTL("JSON support is unavailable.")] unless defined?(JSON)
          return [false, _INTL("{1} was not found.", EXPORT_FILE)] unless
            File.exist?(export_path)
          payload = JSON.parse(File.binread(export_path))
          imported = payload.is_a?(Hash) ? payload["catalog"] : nil
          return [false, _INTL("The RLD Shop catalog is invalid.")] unless
            imported.is_a?(Hash)
          normalized = deep_copy(imported)
          normalize_state!(normalized)
          bucket = state
          bucket.clear
          normalized.each { |key, value| bucket[key] = value }
          [true, _INTL("RLD Shop catalog imported from {1}.", EXPORT_FILE)]
        rescue StandardError => e
          log_exception("RLD Shop import failed", e)
          [false, _INTL("RLD Shop catalog import failed.")]
        end

        def export_path
          File.join(KantoReloaded::ROOT, "Exports", EXPORT_FILE)
        end

        private

        def normalize_state!(bucket)
          bucket["schema_version"] = SCHEMA_VERSION
          bucket["categories"] = normalize_categories(bucket["categories"])
          bucket["entries"] = {} unless bucket["entries"].is_a?(Hash)
          normalized_entries = {}
          bucket["entries"].each do |key, value|
            next unless value.is_a?(Hash)
            data = item_data(key.to_sym)
            next unless data
            next if important_owned?(data)
            normalized_entries[data.id.to_s] = normalize_entry(value)
          end
          bucket["entries"] = normalized_entries
          bucket["hidden"] = Array(bucket["hidden"]).map(&:to_s).uniq
          bucket["favorites"] = Array(bucket["favorites"]).map(&:to_s).uniq
          bucket
        end

        def normalize_entry(value)
          result = {}
          category = value["category"] || value[:category]
          result["category"] = category.to_s unless category.nil?
          %w[order buy_price sell_price].each do |key|
            raw = value[key] || value[key.to_sym]
            result[key] = [raw.to_i, 0].max unless raw.nil?
          end
          %w[enabled added].each do |key|
            raw = value.has_key?(key) ? value[key] : value[key.to_sym]
            result[key] = !!raw unless raw.nil?
          end
          result
        end

        def normalize_categories(value)
          source = value.is_a?(Array) && !value.empty? ?
            value : Defaults.categories
          seen = {}
          result = []
          source.each do |entry|
            next unless entry.is_a?(Hash)
            id = (entry["id"] || entry[:id]).to_s
            next if id.empty? || seen[id]
            name = sanitize_name(entry["name"] || entry[:name] || id)
            seen[id] = true
            result << { "id" => id, "name" => name, "order" => result.length }
          end
          result = Defaults.categories if result.empty?
          result
        end

        def runtime_rows(stock, adapter, include_hidden = false)
          seen = {}
          Array(stock).each_with_index.each_with_object([]) do |(runtime_id, index), rows|
            data = item_data(runtime_id)
            next unless data
            key = data.id.to_s
            next if seen[key]
            seen[key] = true
            next if !include_hidden && state["hidden"].include?(key)
            overlay = state["entries"][key] || {}
            next if important_owned?(data) && !include_hidden
            row = build_row(data, runtime_id, index, overlay, adapter, false)
            row[:hidden] = state["hidden"].include?(key)
            rows << row
          end
        end

        def custom_rows(adapter)
          state["entries"].each_with_object([]) do |(key, overlay), rows|
            next unless overlay.is_a?(Hash) && overlay["added"]
            next if state["hidden"].include?(key)
            data = item_data(key.to_sym)
            next unless data
            runtime = data.id_number rescue data.id
            runtime = data.id if !runtime || runtime.to_i <= 0
            rows << build_row(
              data, runtime, overlay["order"] || 0, overlay, adapter, true
            )
          end
        end

        def build_row(data, runtime_id, default_order, overlay, adapter, added)
          base_buy = safe_price(adapter, runtime_id, false, data.price)
          base_sell = safe_price(adapter, runtime_id, true, data.price / 2)
          {
            :id => data.id,
            :runtime_id => runtime_id,
            :name => display_name(adapter, runtime_id, data),
            :description => data.description.to_s,
            :category => valid_category(overlay["category"]) ||
                         valid_category(Defaults.category_for(data.id)) ||
                         categories.first["id"],
            :order => overlay.has_key?("order") ? overlay["order"].to_i : default_order,
            :buy_price => overlay["buy_price"].nil? ?
                            base_buy : [overlay["buy_price"].to_i, 0].max,
            :sell_price => overlay["sell_price"].nil? ?
                             base_sell : [overlay["sell_price"].to_i, 0].max,
            :enabled => overlay.has_key?("enabled") ? !!overlay["enabled"] : true,
            :added => added || !!overlay["added"],
            :hidden => false,
            :important => data.is_important?,
            :pocket => data.pocket.to_i
          }
        end

        def display_name(adapter, runtime_id, data)
          return data.name.to_s unless adapter && adapter.respond_to?(:getDisplayName)
          adapter.getDisplayName(runtime_id).to_s
        rescue StandardError
          data.name.to_s
        end

        def safe_price(adapter, item, selling, fallback)
          return fallback.to_i unless adapter && adapter.respond_to?(:getPrice)
          adapter.getPrice(item, selling).to_i
        rescue StandardError
          fallback.to_i
        end

        def important_owned?(data)
          data.is_important? && defined?($PokemonBag) && $PokemonBag &&
            $PokemonBag.pbHasItem?(data.id)
        rescue StandardError
          false
        end

        def item_data(item)
          GameData::Item.try_get(item) rescue nil
        end

        def normalize_item_id(item)
          data = item_data(item)
          data ? data.id : nil
        end

        def item_key(item)
          id = normalize_item_id(item)
          id ? id.to_s : nil
        end

        def valid_category(value, bucket = nil)
          key = value.to_s
          rows = bucket ? bucket["categories"] : categories
          rows.any? { |entry| entry["id"] == key } ? key : nil
        end

        def next_order(category, bucket = nil)
          source = bucket || state
          values = source["entries"].values.select do |entry|
            entry["category"] == category
          end.map { |entry| entry["order"].to_i }
          values.empty? ? 0 : values.max + 1
        end

        def sanitize_name(value)
          value.to_s.gsub(/[\r\n\t]+/, " ").gsub(/\s+/, " ").strip[0, 32]
        end

        def reorder_categories!
          ordered = categories
          ordered.each_with_index { |entry, index| entry["order"] = index }
          state["categories"] = ordered
        end

        def default_adapter
          defined?(PokemonMartAdapter) ? PokemonMartAdapter.new : nil
        end

        def ensure_export_directory
          directory = File.dirname(export_path)
          Dir.mkdir(directory) unless Dir.exist?(directory)
          true
        end

        def deep_copy(value)
          Marshal.load(Marshal.dump(value))
        end

        def log_exception(message, error)
          KantoReloaded::Log.exception(
            message, error, channel: :modules
          ) if defined?(KantoReloaded::Log)
        end
      end
    end
  end
end
