#======================================================
# KantoReloaded Data Patches
# Author: Stonewall
#======================================================
# Runtime data patch collector and JSON-style data registry.
#
# Responsibilities:
#   - Scan enabled mods for DataPatches/**/*.json files.
#   - Validate supported patch operations before applying them.
#   - Apply safe runtime JSON-style patches without editing base files.
#   - Expose patched data through KantoReloaded::DataPatches.
#
#======================================================

begin
  require "json"
rescue LoadError, StandardError
end

module KantoReloaded
  module DataPatches
    SUPPORTED_OPERATIONS = ["add", "edit", "merge", "replace"].freeze
    PATCH_FOLDER = "DataPatches".freeze

    @targets = {}
    @data = {}
    @patches = []
    @internal_patches = []
    @applied = []
    @errors = []
    @warnings = []
    @last_summary_signature = nil

    class << self
      def register_target(target, initial_data = {}, owner: :kanto_reloaded, description: nil, defer_missing_entries: false)
        key = normalize_target(target)
        return nil if key.empty?
        @targets[key] = {
          :target => key,
          :owner => owner.to_s,
          :description => description.to_s,
          :defer_missing_entries => !!defer_missing_entries,
          :initial_data => deep_dup(initial_data.is_a?(Hash) ? initial_data : {})
        }
        @data[key] = deep_dup(@targets[key][:initial_data])
        key
      rescue StandardError => e
        KantoReloaded::Log.exception("Data patch target registration failed for #{target}", e, channel: :mods) if defined?(KantoReloaded::Log)
        nil
      end

      def rebuild(mods = nil)
        reset_runtime
        active_mods = mods || kif_active_mods
        Array(active_mods).each { |mod| scan_mod(mod) }
        detect_patch_conflicts
        apply_patches
        log_summary
        emit(:data_patches_loaded)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Data patch rebuild failed", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def install_game_data_load_hook
        return false unless defined?(GameData)
        KantoReloaded::Hooks.wrap(
          GameData, :load_all, :data_patches_load_all, :singleton => true
        ) do |hook, *_args|
          result = hook.call
          KantoReloaded::DataPatches.rebuild_after_game_data_load if defined?(KantoReloaded::DataPatches)
          result
        end
      rescue StandardError => e
        KantoReloaded::Log.exception("Data patch GameData.load_all hook install failed", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def rebuild_after_game_data_load
        emit(:game_data_loaded)
        active_mods = kif_active_mods
        rebuild(active_mods)
        if defined?(KantoReloaded::Log) && KantoReloaded::Log.respond_to?(:info_once)
          KantoReloaded::Log.info_once(
            "Rebuilt data patches after GameData.load_all",
            :mods,
            key: "data_patches_after_game_data_load"
          )
        end
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Data patch rebuild after GameData.load_all failed", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def data(target = nil)
        return deep_dup(@data) if target.nil?
        deep_dup(@data[normalize_target(target)] || {})
      end

      def entry(target, id)
        value = (@data[normalize_target(target)] || {})[normalize_id(id)]
        deep_dup(value)
      end

      def patches(target = nil)
        list = target.nil? ? @patches : @patches.select { |patch| patch[:target] == normalize_target(target) }
        list = list.reject { |patch| hidden_patch?(patch) }
        list.map { |patch| patch.dup }
      end

      def patches_all(target = nil)
        list = target.nil? ? @patches : @patches.select { |patch| patch[:target] == normalize_target(target) }
        list.map { |patch| patch.dup }
      end

      def applied(target = nil)
        list = target.nil? ? @applied : @applied.select { |patch| patch[:target] == normalize_target(target) }
        list = list.reject { |patch| hidden_patch?(patch) }
        list.map { |patch| patch.dup }
      end

      def applied_all(target = nil)
        list = target.nil? ? @applied : @applied.select { |patch| patch[:target] == normalize_target(target) }
        list.map { |patch| patch.dup }
      end

      def errors
        @errors.reject { |entry| entry[:hidden] }.map(&:dup)
      end

      def warnings
        @warnings.reject { |entry| entry[:hidden] }.map(&:dup)
      end

      def summary
        visible_patches = @patches.reject { |patch| hidden_patch?(patch) }
        visible_applied = @applied.reject { |patch| hidden_patch?(patch) }
        visible_errors = @errors.reject { |entry| entry[:hidden] }
        visible_warnings = @warnings.reject { |entry| entry[:hidden] }
        {
          :targets => @data.keys.length,
          :patches => visible_patches.length,
          :applied => visible_applied.length,
          :errors => visible_errors.length,
          :warnings => visible_warnings.length
        }
      end

      def register_internal_patch(target, id, data, operation: "add", owner: :kanto_reloaded, source: nil, hidden: true)
        entry = {
          "target" => target,
          "operation" => operation,
          "id" => id,
          "data" => data
        }
        owner_id = normalize_id(owner)
        owner_id = "kanto_reloaded" if owner_id.empty?
        source_path = source.to_s.empty? ? "KantoReloaded/internal/#{owner_id}" : source.to_s
        mod = { :id => owner_id, :name => "Kanto Reloaded" }
        patch = build_patch(mod, source_path, entry, 0)
        patch[:key] = "internal:#{owner_id}:#{patch[:target]}:#{patch[:id]}"
        patch[:internal] = true
        patch[:hidden] = !!hidden
        @internal_patches.reject! { |existing| existing[:key] == patch[:key] }
        if patch[:errors].empty?
          @internal_patches << patch
          true
        else
          patch[:errors].each { |error| add_error(nil, patch[:file], patch[:index], error, patch) }
          false
        end
      rescue StandardError => e
        KantoReloaded::Log.exception("Internal data patch registration failed for #{target}/#{id}", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      private

      def kif_active_mods
        return [] unless defined?(::ModManager) && ::ModManager.respond_to?(:registry)
        ids = if ::ModManager.respond_to?(:load_order)
                Array(::ModManager.load_order)
              elsif ::ModManager.respond_to?(:enabled_mods)
                Array(::ModManager.enabled_mods)
              else
                ::ModManager.registry.keys
              end
        ids.each_with_object([]) do |mod_id, result|
          next if ::ModManager.respond_to?(:enabled?) && !::ModManager.enabled?(mod_id)
          info = ::ModManager.registry[mod_id]
          next unless info
          result << {
            :id => (info.respond_to?(:id) ? info.id : mod_id).to_s,
            :name => (info.respond_to?(:name) ? info.name : mod_id).to_s,
            :version => (info.respond_to?(:version) ? info.version : "0.0.0").to_s,
            :folder_path => (info.respond_to?(:folder_path) ? info.folder_path : "").to_s
          }
        end
      rescue StandardError => e
        KantoReloaded::Log.exception("Could not read enabled KIF mods for data patches", e, channel: :mods) if defined?(KantoReloaded::Log)
        []
      end

      def reset_runtime
        @data = {}
        @targets.each do |target, config|
          @data[target] = deep_dup(config[:initial_data])
        end
        @patches = @internal_patches.map { |patch| deep_dup(patch) }
        @applied = []
        @errors = []
        @warnings = []
      end

      def scan_mod(mod)
        folder = if defined?(KantoReloaded::Platform)
                   KantoReloaded::Platform.normalize_path(mod[:folder_path])
                 else
                   mod[:folder_path].to_s.gsub("\\", "/")
                 end
        return if folder.empty?
        pattern = File.join(folder, PATCH_FOLDER, "**", "*.json")
        paths = if defined?(KantoReloaded::Platform)
                  KantoReloaded::Platform.glob(pattern)
                else
                  Dir[pattern].sort
                end
        paths.each do |path|
          read_patch_file(mod, path)
        end
      end

      def read_patch_file(mod, path)
        unless json_available?
          add_error(mod, path, nil, "JSON is not available in this runtime.")
          return
        end
        raw = if defined?(KantoReloaded::Platform)
                KantoReloaded::Platform.read_text(path)
              else
                File.read(path)
              end
        parsed = parse_json(raw)
        entries = extract_patch_entries(parsed, path)
        entries.each_with_index do |entry, index|
          patch = build_patch(mod, path, entry, index)
          if patch[:errors].empty?
            @patches << patch
          else
            patch[:errors].each { |error| add_error(mod, path, index, error) }
          end
        end
      rescue StandardError => e
        add_error(mod, path, nil, "Could not parse data patch file: #{e.class}: #{e}")
      end

      def extract_patch_entries(parsed, path)
        if parsed.is_a?(Array)
          return parsed
        end
        unless parsed.is_a?(Hash)
          return [{ "errors" => ["Patch file must contain an object, array, or patches array."] }]
        end
        patch_entries = hash_value(parsed, "patches")
        if patch_entries.is_a?(Array)
          default_target = hash_value(parsed, "target")
          return patch_entries.map do |entry|
            if entry.is_a?(Hash) && default_target && !hash_key?(entry, "target")
              merged = entry.dup
              merged["target"] = default_target
              merged
            else
              entry
            end
          end
        end
        [parsed]
      rescue
        [{ "errors" => ["Patch file could not be read: #{path}"] }]
      end

      def build_patch(mod, path, entry, index)
        errors = []
        errors.concat(Array(hash_value(entry, "errors"))) if entry.is_a?(Hash) && hash_value(entry, "errors")
        unless entry.is_a?(Hash)
          errors << "Patch entry must be an object."
          entry = {}
        end

        target_value = hash_value(entry, "target")
        operation_value = hash_value(entry, "operation")
        target = normalize_target(target_value)
        operation = normalize_operation(operation_value)
        id = normalize_id(hash_value(entry, "id"))
        data = hash_value(entry, "data")

        errors << "Missing required field: target" if target.empty?
        errors << "Missing required field: operation" if operation.empty?
        errors << "Unsupported operation: #{operation_value}" unless operation.empty? || SUPPORTED_OPERATIONS.include?(operation)
        errors << "Missing required field: id" if id.empty?
        errors << "Missing required field: data" if data.nil?
        errors << "data must be an object" if !data.nil? && !data.is_a?(Hash)

        {
          :key => patch_key(mod, path, index),
          :mod_id => normalize_id(mod[:id]),
          :mod_name => mod[:name].to_s,
          :target => target,
          :operation => operation,
          :id => id,
          :data => deep_dup(data.is_a?(Hash) ? data : {}),
          :file => path.to_s.gsub("\\", "/"),
          :index => index,
          :errors => errors,
          :warnings => [],
          :applied => false
        }
      end

      def patch_key(mod, path, index)
        "#{normalize_id(mod[:id])}:#{path.to_s.gsub("\\", "/")}:#{index}"
      end

      def detect_patch_conflicts
        grouped = {}
        @patches.each do |patch|
          grouped[[patch[:target], patch[:id]]] ||= []
          grouped[[patch[:target], patch[:id]]] << patch
        end
        grouped.each_value do |patches|
          detect_entry_conflicts(patches)
        end
      end

      def detect_entry_conflicts(patches)
        add_or_replace = patches.select { |patch| ["add", "replace"].include?(patch[:operation]) }
        if add_or_replace.length > 1
          add_or_replace.each do |patch|
            patch[:errors] << "Conflicting #{patch[:operation]} patch for #{patch[:target]}/#{patch[:id]}."
          end
        end

        field_map = {}
        patches.each do |patch|
          next unless ["edit", "merge"].include?(patch[:operation])
          patch[:data].keys.each do |field|
            field_map[field.to_s] ||= []
            field_map[field.to_s] << patch
          end
        end
        field_map.each do |field, entries|
          next unless entries.length > 1
          entries.each do |patch|
            warning = "Multiple patches modify #{patch[:target]}/#{patch[:id]}.#{field}; load order decides the final value."
            patch[:warnings] << warning
            add_warning(patch, warning)
          end
        end
      end

      def apply_patches
        @patches.each do |patch|
          if patch[:errors].empty?
            apply_patch(patch)
          else
            patch[:errors].each { |error| add_error(nil, patch[:file], patch[:index], error, patch) }
          end
        end
      end

      def apply_patch(patch)
        target_data = (@data[patch[:target]] ||= {})
        case patch[:operation]
        when "add"
          if target_data.key?(patch[:id])
            add_error(nil, patch[:file], patch[:index], "Cannot add existing entry #{patch[:target]}/#{patch[:id]}.", patch)
            return false
          end
          target_data[patch[:id]] = deep_dup(patch[:data])
        when "edit"
          existing = target_data[patch[:id]]
          unless existing.is_a?(Hash)
            return defer_patch(patch) if defer_missing_entry?(patch)
            add_error(nil, patch[:file], patch[:index], "Cannot edit missing entry #{patch[:target]}/#{patch[:id]}.", patch)
            return false
          end
          missing_fields = patch[:data].keys.reject { |field| existing.key?(field) }
          unless missing_fields.empty?
            add_error(nil, patch[:file], patch[:index], "Cannot edit missing field(s): #{missing_fields.join(", ")}.", patch)
            return false
          end
          patch[:data].each { |field, value| existing[field] = deep_dup(value) }
        when "merge"
          existing = target_data[patch[:id]]
          unless existing.is_a?(Hash)
            return defer_patch(patch) if defer_missing_entry?(patch)
            add_error(nil, patch[:file], patch[:index], "Cannot merge into missing entry #{patch[:target]}/#{patch[:id]}.", patch)
            return false
          end
          deep_merge!(existing, patch[:data])
        when "replace"
          target_data[patch[:id]] = deep_dup(patch[:data])
        else
          add_error(nil, patch[:file], patch[:index], "Unsupported operation: #{patch[:operation]}.", patch)
          return false
        end
        patch[:applied] = true
        @applied << patch
        true
      end

      def defer_missing_entry?(patch)
        config = @targets[patch[:target]]
        return false unless config && config[:defer_missing_entries]
        return false unless config[:initial_data].is_a?(Hash) && config[:initial_data].empty?
        true
      end

      def defer_patch(patch)
        patch[:deferred] = true
        false
      end

      def add_error(mod, path, index, message, patch = nil)
        entry = {
          :mod_id => patch ? patch[:mod_id] : normalize_id(mod && mod[:id]),
          :file => path.to_s.gsub("\\", "/"),
          :index => index,
          :message => message.to_s,
          :hidden => patch ? hidden_patch?(patch) : false
        }
        @errors << entry
        return unless defined?(KantoReloaded::Log)
        text = "Data patch error #{entry[:file]}#{index.nil? ? "" : "##{index}"}: #{entry[:message]}"
        if KantoReloaded::Log.respond_to?(:error_once)
          KantoReloaded::Log.error_once(text, :mods, key: "data_patch_error:#{entry[:file]}:#{index}:#{entry[:message]}")
        else
          KantoReloaded::Log.error(text, :mods)
        end
      end

      def add_warning(patch, message)
        entry = {
          :mod_id => patch[:mod_id],
          :file => patch[:file],
          :index => patch[:index],
          :message => message.to_s,
          :hidden => hidden_patch?(patch)
        }
        @warnings << entry
        return unless defined?(KantoReloaded::Log)
        text = "Data patch warning #{entry[:file]}##{entry[:index]}: #{entry[:message]}"
        if KantoReloaded::Log.respond_to?(:warning_once)
          KantoReloaded::Log.warning_once(text, :mods, key: "data_patch_warning:#{entry[:file]}:#{entry[:index]}:#{entry[:message]}")
        else
          KantoReloaded::Log.warning(text, :mods)
        end
      end

      def log_summary
        data = summary
        signature = summary_signature
        return if @last_summary_signature == signature
        @last_summary_signature = signature
        KantoReloaded::Log.summary(
          :data_patch_targets => data[:targets],
          :data_patches_found => data[:patches],
          :data_patches_applied => data[:applied],
          :data_patch_warnings => data[:warnings],
          :data_patch_errors => data[:errors]
        ) if defined?(KantoReloaded::Log)
        KantoReloaded::Log.info(
          "Data patches: #{data[:applied]}/#{data[:patches]} applied, #{data[:warnings]} warning(s), #{data[:errors]} error(s)",
          :mods
        ) if defined?(KantoReloaded::Log)
      end

      def summary_signature
        visible_patches = @patches.reject { |patch| hidden_patch?(patch) }
        visible_errors = @errors.reject { |entry| entry[:hidden] }
        visible_warnings = @warnings.reject { |entry| entry[:hidden] }
        [
          visible_patches.map { |patch| "#{patch[:key]}:#{patch[:operation]}:#{patch[:target]}:#{patch[:id]}:#{patch[:applied]}" }.sort.join("|"),
          visible_errors.map { |entry| "#{entry[:file]}:#{entry[:index]}:#{entry[:message]}" }.sort.join("|"),
          visible_warnings.map { |entry| "#{entry[:file]}:#{entry[:index]}:#{entry[:message]}" }.sort.join("|")
        ].join("||")
      end

      def emit(event_name)
        return unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.emit(event_name, {
          :event => event_name,
          :summary => summary,
          :patches => patches,
          :applied => applied,
          :errors => errors,
          :warnings => warnings
        })
      rescue StandardError => e
        KantoReloaded::Log.exception("Data patch event #{event_name} failed", e, channel: :mods) if defined?(KantoReloaded::Log)
      end

      def normalize_target(value)
        value.to_s.strip.downcase.gsub(/[^a-z0-9_.:-]+/, "_")
      end

      def normalize_operation(value)
        value.to_s.strip.downcase
      end

      def normalize_id(value)
        value.to_s.strip
      end

      def hash_value(hash, key)
        return nil unless hash.is_a?(Hash)
        return hash[key] if hash.key?(key)
        symbol_key = key.to_s.to_sym
        return hash[symbol_key] if hash.key?(symbol_key)
        nil
      end

      def hash_key?(hash, key)
        return false unless hash.is_a?(Hash)
        hash.key?(key) || hash.key?(key.to_s.to_sym)
      end

      def json_available?
        return KantoReloaded::Platform.json_available? if defined?(KantoReloaded::Platform)
        defined?(::JSON) || (defined?(::ModManager::JSON) && ::ModManager::JSON.respond_to?(:parse))
      end

      def parse_json(raw)
        return KantoReloaded::Platform.parse_json(raw) if defined?(KantoReloaded::Platform)
        return ::JSON.parse(raw) if defined?(::JSON)
        ::ModManager::JSON.parse(raw)
      end

      def hidden_patch?(patch)
        !!(patch && patch[:hidden])
      end

      def deep_dup(value)
        Marshal.load(Marshal.dump(value))
      rescue
        value.is_a?(Hash) ? value.dup : value
      end

      def deep_merge!(base, incoming)
        incoming.each do |key, value|
          if base[key].is_a?(Hash) && value.is_a?(Hash)
            deep_merge!(base[key], value)
          else
            base[key] = deep_dup(value)
          end
        end
        base
      end
    end
  end
end

KantoReloaded::DataPatches.install_game_data_load_hook if defined?(KantoReloaded::DataPatches)
