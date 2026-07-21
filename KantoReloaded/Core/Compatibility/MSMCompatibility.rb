#==============================================================================
# Kanto Reloaded Mod Settings Menu Compatibility
#==============================================================================
# Translates the legacy ModSettingsMenu API into KantoReloaded::Settings and
# imports legacy values once without editing or requiring the old MSM mod.
#==============================================================================

module KantoReloaded
  module MSMCompatibility
    MIGRATION_ID = "msm_values_v1"
    LEGACY_OWNER = :legacy_msm
    DISABLED_OPTION_KEYS = [:modsettings_colors, :quality_assurance].freeze
    DEFAULT_CATEGORIES = [
      ["Interface", 10, "UI, menus, text speed, visual interface"],
      ["Major Systems", 20, "Major gameplay systems"],
      ["Quality of Life", 30, "Convenience features and shortcuts"],
      ["Battle Mechanics", 40, "Battle mechanics and move behavior"],
      ["Economy", 50, "Money, shops, loot, and prizes"],
      ["Difficulty", 60, "Difficulty and challenge settings"],
      ["Encounters", 70, "Wild encounters and spawn rates"],
      ["Training & Stats", 80, "Experience, EVs, IVs, and stats"],
      ["Multiplayer Addons", 85, "Multiplayer-related additions"],
      ["Uncategorized", 900, "Settings without an assigned category"],
      ["Debug & Developer", 999, "Testing and developer options"]
    ].freeze

    @legacy_registry = []
    @legacy_categories = nil
    @booted = false
    @bridges_installed = false
    @syncing_from_msm = false

    class LegacyOption
      attr_reader :name, :values, :optstart, :optend, :description

      def initialize(key, definition)
        @key = key
        @name = definition[:name]
        @values = Array(definition[:values])
        @optstart = definition[:minimum]
        @optend = definition[:maximum]
        @description = definition[:description]
        @type = definition[:type]
        @step = definition[:step] || 1
      end

      def get
        KantoReloaded::Settings.get(@key)
      end

      def set(value)
        KantoReloaded::Settings.set(@key, value)
      end

      def activate
        KantoReloaded::Settings.activate(@key)
      end

      def next(current)
        if @type == :button
          activate
          return current
        end
        return [current.to_i + 1, 1].min if @type == :toggle
        return [current.to_i + 1, @values.length - 1].min if @type == :enum
        value = current.to_f + @step.to_f
        value = @optend if @optend && value > @optend
        integer_result?(value) ? value.to_i : value
      end

      def prev(current)
        return current if @type == :button
        return [current.to_i - 1, 0].max if [:toggle, :enum].include?(@type)
        value = current.to_f - @step.to_f
        value = @optstart if @optstart && value < @optstart
        integer_result?(value) ? value.to_i : value
      end

      private

      def integer_result?(value)
        value.to_i == value && [@optstart, @optend, @step].compact.all? { |entry| entry.is_a?(Integer) }
      end
    end

    class LegacyCategoryList < Array
      def <<(entry)
        result = super(entry)
        KantoReloaded::MSMCompatibility.sync_category(entry)
        result
      end

      def push(*entries)
        entries.each { |entry| self << entry }
        self
      end
    end

    module ShimAPI
      def kanto_reloaded_compatibility_shim?
        true
      end

      def registry
        KantoReloaded::MSMCompatibility.legacy_registry
      end

      def categories
        KantoReloaded::MSMCompatibility.legacy_categories
      end

      def register(key, options = {})
        KantoReloaded::MSMCompatibility.register_legacy(key, options)
      end

      def register_toggle(key, name, description = "", default = 0, category = nil)
        register(key, {
          :name => name, :description => description, :type => :toggle,
          :default => default, :category => category
        })
      end

      def register_enum(key, name, values, default_index = 0, description = "", category = nil)
        register(key, {
          :name => name, :description => description, :type => :enum,
          :values => values, :default => default_index, :category => category
        })
      end

      def register_number(key, name, start_value, end_value, default, description = "", category = nil)
        register(key, {
          :name => name, :description => description, :type => :number,
          :min => start_value, :max => end_value, :default => default,
          :category => category
        })
      end

      def register_slider(key, name, start_value, end_value, interval, default, description = "", category = nil)
        register(key, {
          :name => name, :description => description, :type => :slider,
          :min => start_value, :max => end_value, :interval => interval,
          :default => default, :category => category
        })
      end

      def register_option(option, key = nil, category = nil, searchable_items = nil)
        KantoReloaded::MSMCompatibility.register_legacy_option(option, key, category, searchable_items)
      end

      def register_pending(key, options = {})
        $MOD_SETTINGS_PENDING_REGISTRATIONS ||= []
        $MOD_SETTINGS_PENDING_REGISTRATIONS << proc { ModSettingsMenu.register(key, options) }
        true
      end

      def get(key)
        KantoReloaded::Settings.get(key, nil)
      end

      def set(key, value)
        KantoReloaded::Settings.set(key, value)
      end

      def storage
        KantoReloaded::MSMCompatibility.legacy_storage
      end

      def fallback_storage
        storage
      end

      def ensure_storage
        true
      end

      def set_storage(values)
        KantoReloaded::Settings.import_values(values, :overwrite => true, :notify => true)
      end

      def register_on_change(key, &block)
        normalized_key = KantoReloaded::MSMCompatibility.send(:normalize_key, key)
        callbacks = KantoReloaded::MSMCompatibility.legacy_callbacks
        callbacks[normalized_key] ||= []
        callbacks[normalized_key] << block
        KantoReloaded::Settings.register_on_change(
          key,
          "legacy_msm_#{block.object_id}",
          :owner => KantoReloaded::MSMCompatibility::LEGACY_OWNER,
          &block
        )
      end

      def invoke_on_change(key, value)
        KantoReloaded::MSMCompatibility.invoke_legacy_callbacks(key, value)
      end

      def on_change_registry
        KantoReloaded::MSMCompatibility.legacy_callbacks
      end

      def valid_category?(name)
        categories.any? { |entry| entry[:name].to_s == name.to_s }
      end

      def toggle_category(name)
        entry = categories.find { |category| category[:name].to_s == name.to_s }
        entry[:collapsed] = !entry[:collapsed] if entry
      end

      def category_collapsed?(name)
        entry = categories.find { |category| category[:name].to_s == name.to_s }
        entry ? !!entry[:collapsed] : false
      end

      def restore_category_states
        categories.each { |entry| entry[:collapsed] = true }
      end

      def debug_log(message)
        KantoReloaded::Log.debug(message.to_s, :legacy_msm) if defined?(KantoReloaded::Log)
      end
    end

    class << self
      def boot
        return true if @booted
        $MOD_SETTINGS_PENDING_REGISTRATIONS ||= []
        register_events
        unless managed_msm_expected?
          install_shim
          drain_pending_registrations
        end
        @booted = true
        KantoReloaded::Log.info("MSM compatibility ready", :framework) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        @booted = false
        KantoReloaded::Log.exception("MSM compatibility boot failed", e, channel: :framework) if defined?(KantoReloaded::Log)
        false
      end

      def activate
        if defined?(::ModSettingsMenu)
          if active_msm_implementation?
            install_active_bridges
            remove_disabled_active_options
            reconcile_active_msm
          else
            install_shim
          end
        else
          install_shim
        end
        drain_pending_registrations unless active_msm_implementation?
        migrate_once
        sync_kr_values_to_active_msm if active_msm_implementation?
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("MSM compatibility activation failed", e, channel: :framework) if defined?(KantoReloaded::Log)
        false
      end

      def install_shim
        unless defined?(::ModSettingsMenu)
          Object.const_set(:ModSettingsMenu, Module.new)
        end
        mod = Object.const_get(:ModSettingsMenu)
        mod.const_set(:NOCATEGORY, "__nocategory__") unless mod.const_defined?(:NOCATEGORY, false)
        mod.extend(ShimAPI) unless mod.singleton_class.ancestors.include?(ShimAPI)
        true
      end

      def active_msm_implementation?
        return false unless defined?(::ModSettingsMenu)
        singleton = class << ::ModSettingsMenu; self; end
        singleton.instance_methods(false).include?(:register) &&
          !singleton.instance_methods(false).include?(:kanto_reloaded_compatibility_shim?)
      rescue
        false
      end

      def legacy_registry
        @legacy_registry ||= []
      end

      def legacy_categories
        return @legacy_categories if @legacy_categories
        @legacy_categories = LegacyCategoryList.new
        DEFAULT_CATEGORIES.each do |name, priority, description|
          @legacy_categories << {
            :name => name,
            :priority => priority,
            :description => description,
            :collapsed => true
          }
        end
        @legacy_categories
      end

      def legacy_storage
        result = {}
        KantoReloaded::Settings.export_values.each do |key, value|
          result[key.to_sym] = value
        end
        result
      end

      def legacy_callbacks
        @legacy_callbacks ||= {}
      end

      def invoke_legacy_callbacks(key, value)
        Array(legacy_callbacks[normalize_key(key)]).each { |callback| callback.call(value) }
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Legacy MSM callback #{key} failed", e, channel: :settings) if defined?(KantoReloaded::Log)
        false
      end

      def register_legacy(key, options = {})
        return nil if disabled_option_key?(key)
        data = symbolize_keys(options)
        legacy_type = normalize_legacy_type(data[:type])
        apply_legacy_defaults!(data, legacy_type)
        category_name = normalized_category_name(data[:category])
        category_entry = legacy_categories.find { |entry| entry[:name].to_s == category_name }
        sync_category(category_entry || {
          :name => category_name,
          :priority => 900,
          :description => "Legacy Mod Settings Menu category"
        })
        translated = data.merge(
          :type => legacy_type,
          :owner => LEGACY_OWNER,
          :category => category_name,
          :value_style => legacy_type == :toggle ? :integer : data[:value_style],
          :step => data[:step] || data[:interval],
          :searchable => data[:searchable] || data[:searchable_items]
        )
        definition = KantoReloaded::Settings.register(key, translated)
        return nil unless definition

        existing = legacy_registry.find { |entry| normalize_key(entry[:key]) == normalize_key(key) }
        option = LegacyOption.new(normalize_key(key), definition)
        entry = {
          :key => normalize_key(key),
          :option => option,
          :category => category_name,
          :searchable_items => translated[:searchable]
        }
        existing ? existing.replace(entry) : legacy_registry << entry
        option
      end

      def register_legacy_option(option, key = nil, category = nil, searchable_items = nil)
        key ||= "legacy_option_#{option.object_id}"
        data = infer_option_definition(option, key, category, searchable_items)
        registered = register_legacy(key, data)
        registered ? option : nil
      end

      def sync_category(entry)
        return nil unless entry.is_a?(Hash)
        data = symbolize_keys(entry)
        name = normalized_category_name(data[:name])
        existing = KantoReloaded::Settings.category(name)
        description = data[:description].to_s
        priority = data[:priority]
        if existing && existing[:owner] == LEGACY_OWNER
          if description.empty? || description == "Legacy Mod Settings Menu category"
            description = existing[:description].to_s
          end
          priority = existing[:priority] if priority.nil?
        end
        KantoReloaded::Settings.register_category(name, {
          :name => name,
          :description => description,
          :priority => integer_value(priority, 900),
          :owner => LEGACY_OWNER,
          :metadata => { "legacy_msm" => true }
        })
      end

      def migrate_once
        return { :status => :already_complete, :imported => 0 } if migration_complete?
        sources = legacy_value_sources
        merged = {}
        sources.each { |_name, values| values.each { |key, value| merged[key] = value } }
        imported = KantoReloaded::Settings.import_values(merged, :overwrite => false, :notify => false)
        write_migration_marker(imported, sources.map(&:first))
        KantoReloaded::Settings.apply_callbacks(:msm_migration) if imported > 0
        log_migration(imported, sources.map(&:first))
        { :status => :complete, :imported => imported, :sources => sources.map(&:first) }
      rescue StandardError => e
        KantoReloaded::Log.exception("Legacy MSM settings migration failed", e, channel: :settings) if defined?(KantoReloaded::Log)
        { :status => :failed, :imported => 0, :error => e }
      end

      def migration_complete?
        marker = migration_markers[MIGRATION_ID]
        marker.is_a?(Hash) && marker["status"] == "complete"
      rescue
        false
      end

      def migration_status
        marker = migration_markers[MIGRATION_ID]
        marker.is_a?(Hash) ? deep_copy(marker) : nil
      end

      def sync_value_from_active(key, value)
        @syncing_from_msm = true
        KantoReloaded::Settings.set(key, value)
      ensure
        @syncing_from_msm = false
      end

      def sync_values_from_active(values, overwrite = false)
        return 0 unless values.is_a?(Hash)
        @syncing_from_msm = true
        KantoReloaded::Settings.import_values(values, :overwrite => overwrite, :notify => false)
      ensure
        @syncing_from_msm = false
      end

      def sync_setting_to_active(context)
        return if @syncing_from_msm
        return unless active_msm_implementation?
        key = context[:key]
        value = context[:value]
        storage = ::ModSettingsMenu.storage rescue nil
        if storage.is_a?(Hash)
          storage[key] = value
          storage[key.to_s] = value if storage.has_key?(key.to_s)
        end
        ::ModSettingsMenu.invoke_on_change(key, value) if ::ModSettingsMenu.respond_to?(:invoke_on_change)
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to mirror KR setting #{context[:key]} to MSM", e, channel: :settings) if defined?(KantoReloaded::Log)
      end

      def after_active_call(method_name, args, result)
        registration_key = registration_key_for(method_name, args)
        if disabled_option_key?(registration_key)
          remove_disabled_active_options
          return result
        end
        case method_name.to_sym
        when :set
          sync_value_from_active(args[0], args[1])
        when :set_storage
          sync_values_from_active(args[0], false)
          sync_kr_values_to_active_msm
        when :register
          register_legacy(args[0], args[1] || {})
        when :register_toggle
          register_legacy(args[0], {
            :name => args[1], :description => args[2], :type => :toggle,
            :default => args[3], :category => args[4]
          })
        when :register_enum
          register_legacy(args[0], {
            :name => args[1], :values => args[2], :default => args[3],
            :description => args[4], :category => args[5], :type => :enum
          })
        when :register_number
          register_legacy(args[0], {
            :name => args[1], :min => args[2], :max => args[3],
            :default => args[4], :description => args[5], :category => args[6],
            :type => :number
          })
        when :register_slider
          register_legacy(args[0], {
            :name => args[1], :min => args[2], :max => args[3], :interval => args[4],
            :default => args[5], :description => args[6], :category => args[7],
            :type => :slider
          })
        when :register_option
          register_legacy_option(result || args[0], args[1], args[2], args[3])
        end
        result
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to bridge MSM #{method_name}", e, channel: :settings) if defined?(KantoReloaded::Log)
        result
      end

      private

      def remove_disabled_active_options
        return false unless defined?(::ModSettingsMenu) && ::ModSettingsMenu.respond_to?(:registry)
        registry = ::ModSettingsMenu.registry
        return false unless registry.respond_to?(:delete_if)
        registry.delete_if do |entry|
          key = entry.is_a?(Hash) ? (entry[:key] || entry["key"]) : nil
          disabled_option_key?(key)
        end
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Could not remove disabled MSM options", e, channel: :settings) if defined?(KantoReloaded::Log)
        false
      end

      def disabled_option_key?(key)
        DISABLED_OPTION_KEYS.include?(normalize_key(key))
      end

      def registration_key_for(method_name, args)
        method_name.to_sym == :register_option ? args[1] : args[0]
      rescue
        nil
      end

      def managed_msm_expected?
        return false unless defined?(::ModManager)
        return false unless ::ModManager.respond_to?(:registry) && ::ModManager.respond_to?(:enabled?)
        registry = ::ModManager.registry
        registered = registry && (registry.has_key?("mod_settings_menu") || registry.has_key?(:mod_settings_menu))
        registered && ::ModManager.enabled?("mod_settings_menu")
      rescue
        false
      end

      def install_active_bridges
        return true if @bridges_installed
        methods = [
          :set, :set_storage, :register, :register_toggle, :register_enum,
          :register_number, :register_slider, :register_option
        ]
        methods.each { |method_name| wrap_active_method(method_name) }
        @bridges_installed = true
        true
      end

      def wrap_active_method(method_name)
        KantoReloaded::Hooks.wrap(
          ::ModSettingsMenu,
          method_name,
          "msm_compatibility_#{method_name}",
          :singleton => true
        ) do |hook, *args|
          result = hook.call
          KantoReloaded::MSMCompatibility.after_active_call(method_name, args, result)
        end
      end

      def reconcile_active_msm
        remove_disabled_active_options
        Array(::ModSettingsMenu.categories).each { |entry| sync_category(entry) }
        Array(::ModSettingsMenu.registry).each do |entry|
          next unless entry.is_a?(Hash)
          key = entry[:key] || entry["key"]
          next if key.nil? || KantoReloaded::Settings.registered?(key)
          next if disabled_option_key?(key)
          option = entry[:option] || entry["option"]
          data = infer_option_definition(
            option,
            key,
            entry[:category] || entry["category"],
            entry[:searchable_items] || entry["searchable_items"]
          )
          register_legacy(key, data)
        end
      end

      def infer_option_definition(option, key, category, searchable_items)
        name = option.respond_to?(:name) ? option.name : key.to_s
        description = option.respond_to?(:description) ? option.description : ""
        class_name = option ? option.class.name.to_s : ""
        current = legacy_current_value(key)
        data = {
          :name => name,
          :description => description,
          :category => category,
          :default => current,
          :searchable => searchable_items
        }
        if class_name.include?("Button") || (option && option.respond_to?(:activate) && !option.respond_to?(:get))
          data[:type] = :button
          data[:on_press] = proc { option.activate }
        elsif class_name.include?("Slider")
          data[:type] = :slider
          data[:min] = option.respond_to?(:optstart) ? option.optstart : 0
          data[:max] = option.respond_to?(:optend) ? option.optend : 100
          data[:interval] = option.instance_variable_get(:@optinterval) rescue 1
          data[:default] = data[:min] if current.nil?
        elsif class_name.include?("Number")
          data[:type] = :number
          data[:min] = option.respond_to?(:optstart) ? option.optstart : 0
          data[:max] = option.respond_to?(:optend) ? option.optend : 100
          data[:default] = data[:min] if current.nil?
        elsif option && option.respond_to?(:values)
          values = Array(option.values).map(&:to_s)
          if values.map(&:downcase) == ["off", "on"]
            data[:type] = :toggle
            data[:default] = current.nil? ? 0 : current
          else
            data[:type] = :enum
            data[:values] = values
            data[:default] = current.nil? ? 0 : current
          end
        else
          data[:type] = :custom
        end
        data
      end

      def legacy_current_value(key)
        return nil unless defined?(::ModSettingsMenu) && ::ModSettingsMenu.respond_to?(:get)
        ::ModSettingsMenu.get(key)
      rescue
        nil
      end

      def sync_kr_values_to_active_msm
        storage = ::ModSettingsMenu.storage rescue nil
        return false unless storage.is_a?(Hash)
        KantoReloaded::Settings.export_values(:include_defaults => false).each do |key, value|
          symbol_key = normalize_key(key)
          storage[symbol_key] = value
          storage[key.to_s] = value if storage.has_key?(key.to_s)
        end
        true
      end

      def drain_pending_registrations
        queue = defined?($MOD_SETTINGS_PENDING_REGISTRATIONS) ? $MOD_SETTINGS_PENDING_REGISTRATIONS : nil
        return 0 unless queue.is_a?(Array)
        count = 0
        while !queue.empty? && count < 10_000
          callback = queue.shift
          begin
            callback.call if callback.respond_to?(:call)
          rescue StandardError => e
            KantoReloaded::Log.exception("Legacy MSM pending registration failed", e, channel: :settings) if defined?(KantoReloaded::Log)
          end
          count += 1
        end
        count
      end

      def legacy_value_sources
        sources = []
        file_values = read_legacy_file
        sources << ["mod_settings_file", file_values] if file_values.is_a?(Hash) && !file_values.empty?

        if defined?(::ModSettingsMenu) && ::ModSettingsMenu.respond_to?(:storage)
          storage = ::ModSettingsMenu.storage rescue nil
          sources << ["mod_settings_menu", storage] if storage.is_a?(Hash) && !storage.empty?
        end

        pokemon_system_values = pokemon_system_storage
        if pokemon_system_values.is_a?(Hash) && !pokemon_system_values.empty?
          sources << ["pokemon_system", pokemon_system_values]
        end
        sources
      end

      def pokemon_system_storage
        return nil unless defined?($PokemonSystem) && $PokemonSystem
        if $PokemonSystem.instance_variable_defined?(:@mod_settings)
          return $PokemonSystem.instance_variable_get(:@mod_settings)
        end
        return $PokemonSystem.mod_settings if $PokemonSystem.respond_to?(:mod_settings)
        nil
      rescue
        nil
      end

      def read_legacy_file
        return nil unless defined?(RTP) && RTP.respond_to?(:getSaveFolder)
        receiver = Object.new
        loader_available = receiver.respond_to?(:kurayjson_load, true)
        return nil unless loader_available
        folder = RTP.getSaveFolder rescue nil
        return nil if folder.to_s.empty?
        path = File.join(folder.to_s, "Mod_Settings.kro")
        exists = if defined?(KantoReloaded::Platform)
                   KantoReloaded::Platform.exist?(path)
                 else
                   File.exist?(path)
                 end
        return nil unless exists
        value = receiver.send(:kurayjson_load, path)
        value.is_a?(Hash) ? value : nil
      rescue StandardError => e
        KantoReloaded::Log.exception("Could not read legacy MSM settings file", e, channel: :settings) if defined?(KantoReloaded::Log)
        nil
      end

      def migration_markers
        root = KantoReloaded::SaveData.system(:settings)
        markers = root["legacy_migrations"] || root[:legacy_migrations]
        unless markers.is_a?(Hash)
          markers = {}
          root["legacy_migrations"] = markers
        end
        markers
      end

      def write_migration_marker(imported, sources)
        migration_markers[MIGRATION_ID] = {
          "status" => "complete",
          "imported" => imported.to_i,
          "sources" => Array(sources).map(&:to_s),
          "completed_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S")
        }
      end

      def register_events
        return unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(:kanto_reloaded_save_loaded, :msm_compatibility_activate, priority: 300) do |_context|
          KantoReloaded::MSMCompatibility.activate if defined?(KantoReloaded::MSMCompatibility)
        end
        KantoReloaded::Events.on(:kanto_reloaded_save_new_game, :msm_compatibility_new_game, priority: 300) do |_context|
          KantoReloaded::MSMCompatibility.activate if defined?(KantoReloaded::MSMCompatibility)
        end
        KantoReloaded::Events.on(:kanto_reloaded_setting_changed, :msm_compatibility_value_sync, priority: 300) do |context|
          KantoReloaded::MSMCompatibility.sync_setting_to_active(context) if defined?(KantoReloaded::MSMCompatibility)
        end
      end

      def normalized_category_name(value)
        text = value.to_s.strip
        text.empty? ? "Uncategorized" : text
      end

      def normalize_legacy_type(value)
        type = value.to_s.strip.downcase.to_sym
        [:toggle, :enum, :number, :slider, :button].include?(type) ? type : :toggle
      end

      def apply_legacy_defaults!(data, type)
        case type
        when :toggle
          data[:default] = 0 if data[:default].nil?
        when :enum
          data[:values] = ["Option 1", "Option 2"] if Array(data[:values]).empty?
          data[:default] = 0 if data[:default].nil?
        when :number, :slider
          data[:min] = 0 if data[:min].nil?
          data[:max] = 100 if data[:max].nil?
          data[:interval] = 1 if type == :slider && data[:interval].nil? && data[:step].nil?
          data[:default] = data[:min] if data[:default].nil?
        when :button
          data[:on_press] ||= proc { false }
        end
        data
      end

      def normalize_key(value)
        text = value.to_s.strip.downcase.gsub(/[^a-z0-9_.-]+/, "_")
        text.to_sym
      end

      def symbolize_keys(value)
        return {} unless value.is_a?(Hash)
        result = {}
        value.each { |key, entry| result[key.to_s.downcase.to_sym] = entry }
        result
      end

      def integer_value(value, fallback)
        value.nil? ? fallback : Integer(value)
      rescue
        fallback
      end

      def deep_copy(value)
        Marshal.load(Marshal.dump(value))
      rescue
        value
      end

      def log_migration(imported, sources)
        return unless defined?(KantoReloaded::Log)
        source_text = sources.empty? ? "none" : sources.join(", ")
        KantoReloaded::Log.info_once(
          "MSM migration complete: imported #{imported} value(s); sources: #{source_text}",
          :settings,
          key: "msm_migration_complete"
        )
      end
    end
  end
end

KantoReloaded::MSMCompatibility.boot if defined?(KantoReloaded::MSMCompatibility)
