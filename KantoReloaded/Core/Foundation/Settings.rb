#==============================================================================
# Kanto Reloaded Settings Registry
#==============================================================================
# Runtime setting definitions with per-save and global value storage.
# UI rendering and legacy Mod Settings Menu compatibility are separate layers.
#==============================================================================

module KantoReloaded
  module Settings
    TYPES = [:toggle, :enum, :number, :slider, :text, :button, :custom].freeze
    SCOPES = [:save, :global].freeze
    DEFAULT_SCOPE = :save
    DEFAULT_CATEGORY = :general
    STORAGE_SYSTEM = :settings

    @definitions = {}
    @categories = {}
    @callbacks = {}
    @callback_stack = {}
    @booted = false

    class << self
      def boot
        return true if @booted
        register_category(DEFAULT_CATEGORY, {
          :name => "General",
          :description => "General Kanto Reloaded settings.",
          :priority => 100,
          :owner => :kanto_reloaded
        })
        register_save_events
        @booted = true
        KantoReloaded::Log.info("Settings registry ready", :framework) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        @booted = false
        KantoReloaded::Log.exception("Settings registry boot failed", e, channel: :framework) if defined?(KantoReloaded::Log)
        false
      end

      def register(key, options = {})
        data = symbolize_keys(options)
        normalized_key = normalize_key(key)
        raise ArgumentError, "Setting key is empty" if normalized_key.nil?

        owner = normalize_owner(data[:owner] || :kanto_reloaded)
        existing = @definitions[normalized_key]
        if existing && existing[:owner] != owner
          log_warning("Setting #{normalized_key} is already owned by #{existing[:owner]}; rejected registration from #{owner}.")
          return nil
        end

        definition = build_definition(normalized_key, owner, data)
        ensure_category(definition[:category], owner)
        @definitions[normalized_key] = definition
        migrate_global_definition(definition)
        emit(:kanto_reloaded_setting_registered, :key => normalized_key, :definition => copy_definition(definition))
        copy_definition(definition)
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to register setting #{key}", e, channel: :settings) if defined?(KantoReloaded::Log)
        nil
      end

      def register_module(module_id, key, options = {})
        data = symbolize_keys(options)
        module_owner = normalize_owner(module_id)
        data[:owner] = module_owner
        data[:module] = module_owner
        register(module_key(module_owner, key), data)
      end

      def registered?(key)
        @definitions.has_key?(normalize_key(key))
      end

      def definition(key)
        value = @definitions[normalize_key(key)]
        value ? copy_definition(value) : nil
      end

      def definitions(options = {})
        filters = symbolize_keys(options)
        category = normalize_category(filters[:category]) if filters[:category]
        owner = normalize_owner(filters[:owner]) if filters[:owner]
        values = @definitions.values.select do |entry|
          (!category || entry[:category] == category) && (!owner || entry[:owner] == owner)
        end
        values.sort_by { |entry| [entry[:priority], entry[:name].downcase, entry[:key].to_s] }.map do |entry|
          copy_definition(entry)
        end
      end

      def registry
        definitions
      end

      def module_settings(module_id)
        definitions(:owner => normalize_owner(module_id))
      end

      def register_category(category_id, options = {})
        data = symbolize_keys(options)
        id = normalize_category(category_id)
        raise ArgumentError, "Category key is empty" if id.nil?
        owner = normalize_owner(data[:owner] || :kanto_reloaded)
        existing = @categories[id]
        if existing && existing[:owner] != owner
          # Categories are shared UI groupings; a later mod may use an existing
          # category but cannot silently redefine its metadata.
          return copy_category(existing)
        end
        entry = {
          :id => id,
          :name => nonempty_text(data[:name], titleize(id)),
          :description => data[:description].to_s,
          :priority => integer_value(data[:priority], 100),
          :owner => owner,
          :metadata => saveable_metadata(data[:metadata])
        }
        @categories[id] = entry
        copy_category(entry)
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to register settings category #{category_id}", e, channel: :settings) if defined?(KantoReloaded::Log)
        nil
      end

      def categories
        @categories.values.sort_by { |entry| [entry[:priority], entry[:name].downcase, entry[:id].to_s] }.map do |entry|
          copy_category(entry)
        end
      end

      def category(category_id)
        entry = @categories[normalize_category(category_id)]
        entry ? copy_category(entry) : nil
      end

      def get(key, fallback = nil)
        normalized_key = normalize_key(key)
        return fallback unless normalized_key
        found, value = stored_value(normalized_key)
        return deep_copy(value) if found
        definition = @definitions[normalized_key]
        return deep_copy(definition[:default]) if definition
        fallback
      end

      def get_module(module_id, key, fallback = nil)
        get(module_key(module_id, key), fallback)
      end

      def visible?(key, context = nil)
        entry = @definitions[normalize_key(key)]
        return false unless entry
        evaluate_condition(entry[:visible_if], context, entry)
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to evaluate setting visibility #{key}", e, channel: :settings) if defined?(KantoReloaded::Log)
        false
      end

      def enabled?(key, context = nil)
        entry = @definitions[normalize_key(key)]
        return false unless entry
        evaluate_condition(entry[:enabled_if], context, entry)
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to evaluate setting availability #{key}", e, channel: :settings) if defined?(KantoReloaded::Log)
        false
      end

      def set(key, value, options = {})
        normalized_key = normalize_key(key)
        return nil unless normalized_key
        return nil if save_writes_blocked?(normalized_key)
        data = symbolize_keys(options)
        definition = @definitions[normalized_key]
        normalized_value = definition ? normalize_value(definition, value) : value
        raise ArgumentError, "Setting value is not saveable" unless marshalable?(normalized_value)

        old_value = get(normalized_key, nil)
        changed = old_value != normalized_value || !stored?(normalized_key)
        return nil unless write_stored_value(normalized_key, normalized_value)
        notify_change(normalized_key, normalized_value, old_value) if changed && data.fetch(:notify, true)
        deep_copy(normalized_value)
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to set setting #{key}", e, channel: :settings) if defined?(KantoReloaded::Log)
        nil
      end

      def set_module(module_id, key, value, options = {})
        set(module_key(module_id, key), value, options)
      end

      def stored?(key)
        normalized_key = normalize_key(key)
        return false unless normalized_key
        values = values_storage_for(normalized_key)
        values.has_key?(normalized_key.to_s) || values.has_key?(normalized_key)
      end

      def reset(key, options = {})
        normalized_key = normalize_key(key)
        return false unless normalized_key
        return false if save_writes_blocked?(normalized_key)
        data = symbolize_keys(options)
        return false unless stored?(normalized_key)
        old_value = get(normalized_key, nil)
        return false unless delete_stored_value(normalized_key)
        new_value = get(normalized_key, nil)
        notify_change(normalized_key, new_value, old_value) if data.fetch(:notify, true)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to reset setting #{key}", e, channel: :settings) if defined?(KantoReloaded::Log)
        false
      end

      def reset_module(module_id, options = {})
        owner = normalize_owner(module_id)
        prefix = "#{owner}."
        registered_keys = @definitions.values.select do |definition|
          definition[:owner] == owner
        end.map { |definition| definition[:key] }
        namespaced_keys = all_stored_keys.select do |key|
          key.to_s.start_with?(prefix)
        end
        (registered_keys + namespaced_keys).uniq.count do |key|
          stored?(key) && reset(key, options)
        end
      end

      def register_on_change(key, callback_id = nil, options = {}, &block)
        return false unless block
        if callback_id.is_a?(Hash)
          options = callback_id
          callback_id = nil
        end
        data = symbolize_keys(options)
        normalized_key = normalize_key(key)
        return false unless normalized_key
        id = (callback_id || data[:id] || "callback_#{block.object_id}").to_s
        owner = normalize_owner(data[:owner] || :kanto_reloaded)
        @callbacks[normalized_key] ||= []
        @callbacks[normalized_key].reject! { |entry| entry[:id] == id }
        @callbacks[normalized_key] << { :id => id, :owner => owner, :block => block }
        invoke_callback(block, get(normalized_key, nil), nil, @definitions[normalized_key]) if data[:invoke]
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to register setting callback #{key}", e, channel: :settings) if defined?(KantoReloaded::Log)
        false
      end
      alias on_change register_on_change

      def remove_on_change(key, callback_id)
        normalized_key = normalize_key(key)
        list = @callbacks[normalized_key]
        return false unless list
        before = list.length
        list.reject! { |entry| entry[:id] == callback_id.to_s }
        list.length != before
      end

      def activate(key, *args)
        definition = @definitions[normalize_key(key)]
        return false unless definition && definition[:type] == :button
        handler = definition[:on_press]
        return false unless handler.respond_to?(:call)
        handler.call(*args)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Setting button #{key} failed", e, channel: :settings) if defined?(KantoReloaded::Log)
        false
      end

      def export_values(options = {})
        data = symbolize_keys(options)
        include_defaults = data.fetch(:include_defaults, true)
        result = {}
        if include_defaults
          @definitions.each_key { |key| result[key.to_s] = get(key, nil) }
        end
        save_values_storage.each { |key, value| result[key.to_s] = deep_copy(value) }
        global_values_storage.each { |key, value| result[key.to_s] = deep_copy(value) }
        result
      end

      def import_values(values, options = {})
        return 0 unless values.is_a?(Hash)
        data = symbolize_keys(options)
        overwrite = !!data[:overwrite]
        notify = !!data[:notify]
        imported = 0
        values.each do |key, value|
          normalized_key = normalize_key(key)
          next unless normalized_key
          next if stored?(normalized_key) && !overwrite
          result = set(normalized_key, value, :notify => notify)
          imported += 1 unless result.nil? && !value.nil?
        end
        imported
      end

      def apply_callbacks(reason = :refresh)
        @definitions.each_key do |key|
          invoke_callbacks(key, get(key, nil), nil)
        end
        emit(:kanto_reloaded_settings_applied, :reason => reason)
        true
      end

      def module_key(module_id, key)
        owner = normalize_owner(module_id)
        setting = normalize_key(key)
        return nil unless setting
        normalize_key("#{owner}.#{setting}")
      end

      private

      def build_definition(key, owner, data)
        type = normalize_type(data[:type] || :toggle)
        values = Array(data[:values]).map(&:to_s)
        raise ArgumentError, "Enum setting #{key} requires values" if type == :enum && values.empty?
        minimum = numeric_or_nil(data[:min].nil? ? data[:minimum] : data[:min])
        maximum = numeric_or_nil(data[:max].nil? ? data[:maximum] : data[:max])
        step = numeric_or_nil(data[:step].nil? ? data[:interval] : data[:step])
        raise ArgumentError, "Setting #{key} has an invalid range" if minimum && maximum && minimum > maximum
        raise ArgumentError, "Setting #{key} has an invalid step" if step && step <= 0

        definition = {
          :key => key,
          :name => nonempty_text(data[:name], titleize(key)),
          :description => data[:description].to_s,
          :type => type,
          :category => normalize_category(data[:category]) || DEFAULT_CATEGORY,
          :scope => normalize_scope(data[:scope]),
          :owner => owner,
          :module => data[:module] ? normalize_owner(data[:module]) : nil,
          :priority => integer_value(data[:priority], 100),
          :values => values,
          :minimum => minimum,
          :maximum => maximum,
          :step => step,
          :value_style => normalize_value_style(data[:value_style], data[:default]),
          :searchable => Array(data[:searchable]).map(&:to_s),
          :visible_if => callable_or_nil(data[:visible_if]),
          :enabled_if => callable_or_nil(data[:enabled_if]),
          :on_press => callable_or_nil(data[:on_press]),
          :coerce => callable_or_nil(data[:coerce]),
          :validate => callable_or_nil(data[:validate]),
          :metadata => saveable_metadata(data[:metadata])
        }
        definition[:default] = normalize_default(definition, data)
        definition
      end

      def normalize_default(definition, data)
        return nil if definition[:type] == :button
        raw = if data.has_key?(:default)
                data[:default]
              elsif definition[:type] == :toggle
                definition[:value_style] == :integer ? 0 : false
              elsif definition[:type] == :enum
                0
              elsif [:number, :slider].include?(definition[:type])
                definition[:minimum] || 0
              elsif definition[:type] == :text
                ""
              end
        normalize_value(definition, raw)
      end

      def normalize_value(definition, value)
        value = definition[:coerce].call(value) if definition[:coerce]
        normalized = case definition[:type]
                     when :toggle then normalize_toggle(value, definition[:value_style])
                     when :enum then normalize_enum(value, definition[:values])
                     when :number then normalize_number(value, definition, false)
                     when :slider then normalize_number(value, definition, true)
                     when :text then value.to_s
                     when :button then nil
                     else value
                     end
        if definition[:validate] && !definition[:validate].call(normalized)
          raise ArgumentError, "Setting value failed validation"
        end
        normalized
      end

      def normalize_toggle(value, style)
        truth = case value
                when true then true
                when false, nil then false
                when Numeric then value.to_f != 0.0
                else
                  text = value.to_s.strip.downcase
                  return style == :integer ? 1 : true if ["1", "true", "on", "yes", "enabled", "enable"].include?(text)
                  return style == :integer ? 0 : false if ["0", "false", "off", "no", "disabled", "disable", ""].include?(text)
                  raise ArgumentError, "Invalid toggle value"
                end
        style == :integer ? (truth ? 1 : 0) : truth
      end

      def normalize_enum(value, values)
        if value.is_a?(Integer) || value.to_s =~ /\A\d+\z/
          index = value.to_i
          raise ArgumentError, "Enum index is out of range" if index < 0 || index >= values.length
          return index
        end
        index = values.index { |entry| entry.casecmp(value.to_s).zero? }
        raise ArgumentError, "Unknown enum value" unless index
        index
      end

      def normalize_number(value, definition, apply_step)
        number = Float(value)
        minimum = definition[:minimum]
        maximum = definition[:maximum]
        number = minimum if minimum && number < minimum
        number = maximum if maximum && number > maximum
        if apply_step && definition[:step]
          origin = minimum || 0
          number = origin + (((number - origin) / definition[:step]).round * definition[:step])
          number = minimum if minimum && number < minimum
          number = maximum if maximum && number > maximum
        end
        integer_range = [minimum, maximum, definition[:step]].compact.all? { |entry| entry.is_a?(Integer) }
        integer_range ? number.to_i : number
      rescue ArgumentError, TypeError
        raise ArgumentError, "Invalid numeric value"
      end

      def notify_change(key, value, old_value)
        invoke_callbacks(key, value, old_value)
        emit(:kanto_reloaded_setting_changed, {
          :key => key,
          :value => deep_copy(value),
          :old_value => deep_copy(old_value),
          :definition => definition(key)
        })
      end

      def invoke_callbacks(key, value, old_value)
        return if @callback_stack[key]
        @callback_stack[key] = true
        Array(@callbacks[key]).dup.each do |entry|
          begin
            invoke_callback(entry[:block], value, old_value, @definitions[key])
          rescue StandardError => e
            KantoReloaded::Log.exception("Setting callback #{key}/#{entry[:id]} failed", e, channel: :settings) if defined?(KantoReloaded::Log)
          end
        end
      ensure
        @callback_stack.delete(key)
      end

      def invoke_callback(block, value, old_value, definition)
        arity = block.arity
        return block.call if arity == 0
        return block.call(value) if arity == 1
        return block.call(value, old_value) if arity == 2
        block.call(value, old_value, definition ? copy_definition(definition) : nil)
      end

      def evaluate_condition(condition, context, definition)
        return true unless condition
        arity = condition.arity
        result = if arity == 0
                   condition.call
                 elsif arity == 1
                   condition.call(context)
                 else
                   condition.call(context, copy_definition(definition))
                 end
        !!result
      end

      def register_save_events
        return unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(:kanto_reloaded_save_loaded, :settings_apply_loaded, priority: 200) do |_context|
          if defined?(KantoReloaded::Settings)
            KantoReloaded::Settings.__send__(:migrate_global_values)
            KantoReloaded::Settings.apply_callbacks(:save_loaded)
          end
        end
        KantoReloaded::Events.on(:kanto_reloaded_save_new_game, :settings_apply_new_game, priority: 200) do |_context|
          KantoReloaded::Settings.apply_callbacks(:new_game) if defined?(KantoReloaded::Settings)
        end
      end

      def save_values_storage
        return @fallback_values ||= {} unless defined?(KantoReloaded::SaveData)
        root = KantoReloaded::SaveData.system(STORAGE_SYSTEM)
        values = root["values"] || root[:values]
        unless values.is_a?(Hash)
          values = {}
          root["values"] = values
        end
        values
      end

      def global_values_storage
        return @fallback_global_values ||= {} unless defined?(KantoReloaded::GlobalSettings)
        KantoReloaded::GlobalSettings.values
      end

      def values_storage_for(key)
        setting_scope(key) == :global ? global_values_storage : save_values_storage
      end

      def stored_value(key)
        values = values_storage_for(key)
        return [true, values[key.to_s]] if values.has_key?(key.to_s)
        return [true, values[key]] if values.has_key?(key)
        [false, nil]
      end

      def write_stored_value(key, value)
        if setting_scope(key) == :global
          if defined?(KantoReloaded::GlobalSettings)
            return KantoReloaded::GlobalSettings.set(key, deep_copy(value))
          end
          global_values_storage[key.to_s] = deep_copy(value)
        else
          save_values_storage[key.to_s] = deep_copy(value)
        end
        true
      end

      def delete_stored_value(key)
        if setting_scope(key) == :global
          if defined?(KantoReloaded::GlobalSettings)
            return KantoReloaded::GlobalSettings.delete(key)
          end
          values = global_values_storage
        else
          values = save_values_storage
        end
        values.delete(key.to_s)
        values.delete(key)
        true
      end

      def all_stored_keys
        (save_values_storage.keys + global_values_storage.keys).uniq
      end

      def setting_scope(key)
        definition = @definitions[key]
        definition ? definition[:scope] : DEFAULT_SCOPE
      end

      def migrate_global_definition(definition)
        return false unless definition[:scope] == :global
        return false unless defined?(KantoReloaded::GlobalSettings)
        key = definition[:key]
        return false if KantoReloaded::GlobalSettings.stored?(key)
        found, value = value_from_storage(save_values_storage, key)
        return false unless found
        KantoReloaded::GlobalSettings.set(key, deep_copy(value))
      end

      def migrate_global_values
        return 0 unless defined?(KantoReloaded::GlobalSettings)
        pending = {}
        @definitions.each_value do |definition|
          next unless definition[:scope] == :global
          key = definition[:key]
          next if KantoReloaded::GlobalSettings.stored?(key)
          found, value = value_from_storage(save_values_storage, key)
          pending[key.to_s] = deep_copy(value) if found
        end
        migrated = KantoReloaded::GlobalSettings.merge_missing(pending)
        if migrated > 0 && defined?(KantoReloaded::Log)
          KantoReloaded::Log.info("Migrated #{migrated} Interface setting(s) to global storage", :settings)
        end
        migrated
      end

      def value_from_storage(values, key)
        return [true, values[key.to_s]] if values.has_key?(key.to_s)
        return [true, values[key]] if values.has_key?(key)
        [false, nil]
      end

      def save_writes_blocked?(key = nil)
        return false if key && setting_scope(key) == :global
        defined?(KantoReloaded::SaveData) && KantoReloaded::SaveData.write_blocked?
      rescue
        false
      end

      def ensure_category(category_id, owner)
        return if @categories.has_key?(category_id)
        register_category(category_id, :owner => owner)
      end

      def normalize_type(value)
        type = value.to_s.strip.downcase.to_sym
        TYPES.include?(type) ? type : :custom
      end

      def normalize_scope(value)
        scope = value.to_s.strip.downcase.to_sym
        SCOPES.include?(scope) ? scope : DEFAULT_SCOPE
      end

      def normalize_value_style(value, default)
        style = value.to_s.strip.downcase.to_sym
        return style if [:boolean, :integer].include?(style)
        default.is_a?(Integer) ? :integer : :boolean
      end

      def normalize_key(value)
        text = value.to_s.strip.downcase
        return nil if text.empty?
        normalized = text.gsub(/[^a-z0-9_.-]+/, "_").gsub(/\A[_.-]+|[_.-]+\z/, "")
        normalized.empty? ? nil : normalized.to_sym
      end

      def normalize_category(value)
        normalize_key(value)
      end

      def normalize_owner(value)
        normalize_key(value) || :unknown
      end

      def titleize(value)
        value.to_s.split(/[_.-]+/).map { |part| part.empty? ? part : part[0, 1].upcase + part[1..-1].to_s }.join(" ")
      end

      def nonempty_text(value, fallback)
        text = value.to_s.strip
        text.empty? ? fallback.to_s : text
      end

      def integer_value(value, fallback)
        value.nil? ? fallback : Integer(value)
      rescue
        fallback
      end

      def numeric_or_nil(value)
        return nil if value.nil?
        number = Float(value)
        number.to_i == number ? number.to_i : number
      rescue
        nil
      end

      def callable_or_nil(value)
        value.respond_to?(:call) ? value : nil
      end

      def saveable_metadata(value)
        value.is_a?(Hash) && marshalable?(value) ? deep_copy(value) : {}
      end

      def marshalable?(value)
        Marshal.dump(value)
        true
      rescue
        false
      end

      def symbolize_keys(value)
        return {} unless value.is_a?(Hash)
        result = {}
        value.each { |key, entry| result[key.to_s.downcase.to_sym] = entry }
        result
      end

      def copy_definition(entry)
        copy = entry.dup
        copy[:values] = Array(entry[:values]).dup
        copy[:searchable] = Array(entry[:searchable]).dup
        copy[:metadata] = deep_copy(entry[:metadata])
        copy[:default] = deep_copy(entry[:default])
        copy.freeze
      end

      def copy_category(entry)
        copy = entry.dup
        copy[:metadata] = deep_copy(entry[:metadata])
        copy.freeze
      end

      def deep_copy(value)
        return value if value.nil? || value == true || value == false
        return value if value.is_a?(Numeric) || value.is_a?(Symbol)
        return value.dup if value.is_a?(String)
        Marshal.load(Marshal.dump(value))
      rescue
        value
      end

      def emit(event, context = {})
        KantoReloaded::Events.emit(event, context) if defined?(KantoReloaded::Events)
      rescue StandardError => e
        KantoReloaded::Log.exception("Settings event #{event} failed", e, channel: :settings) if defined?(KantoReloaded::Log)
      end

      def log_warning(message)
        return unless defined?(KantoReloaded::Log)
        if KantoReloaded::Log.respond_to?(:warning_once)
          KantoReloaded::Log.warning_once(message, :settings, key: "settings:#{message}")
        else
          KantoReloaded::Log.warning(message, :settings)
        end
      end
    end
  end
end

KantoReloaded::Settings.boot if defined?(KantoReloaded::Settings)
