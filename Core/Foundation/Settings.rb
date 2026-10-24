#==============================================================================
# Kanto Reloaded: Settings
#==============================================================================
# The settings registry. Every Kanto Reloaded setting is one typed
# definition here; the Kanto Reloaded settings screen is built from them.
# (The game's and KIF's own settings stay in KIF's settings screen.)
#
# Scope
#   :global  a preference for every save: <mod folder>\Settings\Settings.json
#   :save    a rule for one save: the save's "settings" section (SaveStore)
#
# Types: :toggle (true/false), :enum (index into :values), :slider and
# :number (integers in min..max by step), :text (a string shown as-is),
# :button (runs :on_press), :custom.
# An :enum opens a dropdown of its values on A (Reloaded::Dropdown); with
# :long => true it opens a picker instead (its own centred popup), where
# :swatch => :text or :cursor shows each value's colour.
# :descriptions => [...] explains each value (one per value, in order): the
# dropdown shows the highlighted one's. :locked_choices => proc returning
# { index => reason } (or [index, ...]) marks values that can't be picked
# right now; they show locked in the dropdown and set refuses them.
# :reset => n drops a Global value stored by a Settings.json older than
# schema n, once, so the setting starts at its default again.
# :remap => [n, { old => new }] moves an :enum value stored by a
# Settings.json older than schema n to its new index, once (values were
# added in the middle of the list).
#
# A setting or page with :feature => :controls is shown only while that
# feature is On.
#
# :goes_to => :speed_up names the page a switch has its own settings on:
# the settings screen's Go to Settings (Y) jumps to that page's heading.
#
# Binds connect a setting to state the game already reads, so the game's
# own code keeps working:
#   Bind.system(:field)          $PokemonSystem.field (style :int for 0/1)
#   Bind.switch(ID) / .variable  $game_switches / $game_variables (per save)
#   Bind.custom(read, write)
#   Bind.direct(read, write)     another system keeps the value (features)
# Switch and variable binds live in the save already, so they are read and
# written directly. Every other bound value is stored here and pushed into
# the game's state at startup, on save load and on every change.
#
# Registering:
#   Reloaded::Settings.register_group(:general, :name => "General", :priority => 10)
#   Reloaded::Settings.register_page(:controls, :group => :general,
#     :name => "Controls", :icon => :controls, :feature => :controls)
#   Reloaded::Settings.register(:"controls.hold_time", :page => :controls,
#     :name => "Hold Time", :type => :slider, :min => 10, :max => 60,
#     :step => 5, :default => 25, :unit => " frames")
#==============================================================================

module Reloaded
  module Settings
    TYPES  = [:toggle, :enum, :slider, :number, :text, :button, :custom].freeze
    SCOPES = [:global, :save].freeze
    GLOBAL_FILE = "Settings.json"
    SCHEMA_VERSION = 5     # 2: the colour settings start at Theme; 3, 4: the frame lists changed order; 5: Backup Cap gained 15 and 20
    SAVE_SECTION = :settings
    SAVE_LOCK_TEXT = "Load a save to change this"

    #--------------------------------------------------------------------------
    # Binds
    #--------------------------------------------------------------------------
    class Bind
      attr_reader :kind
      attr_reader :field        # a system bind's $PokemonSystem field

      # style: :raw (value as-is), :int (toggle <-> 0/1), :int_inverted
      # (toggle <-> 1/0), or a [to_game, from_game] pair of procs.
      def self.system(field, style = :raw)
        reader = proc { $PokemonSystem && $PokemonSystem.respond_to?(field) ? $PokemonSystem.send(field) : nil }
        writer = proc { |value| $PokemonSystem.send("#{field}=", value) if $PokemonSystem && $PokemonSystem.respond_to?("#{field}=") }
        bind = new(:mirror, reader, writer, style, true)
        bind.instance_variable_set(:@field, field.to_sym)
        return bind
      end

      def self.switch(id, inverted = false)
        reader = proc { $game_switches ? $game_switches[id] : nil }
        writer = proc { |value| $game_switches[id] = value if $game_switches }
        return new(:live, reader, writer, inverted ? :bool_inverted : :raw)
      end

      def self.variable(id)
        reader = proc { $game_variables ? $game_variables[id] : nil }
        writer = proc { |value| $game_variables[id] = value if $game_variables }
        return new(:live, reader, writer, :raw)
      end

      # A custom bind is mirrored (stored by the registry) unless live is true.
      def self.custom(reader, writer, live = false)
        return new(live ? :live : :mirror, reader, writer, :raw)
      end

      # Read and written straight through, at any time, never stored by the
      # registry: for values another system already keeps (feature switches).
      def self.direct(reader, writer)
        return new(:direct, reader, writer, :raw)
      end

      def initialize(kind, reader, writer, style, system = false)
        @kind = kind
        @reader = reader
        @writer = writer
        @style = style
        @system = system
      end

      def live?
        return @kind == :live
      end

      def direct?
        return @kind == :direct
      end

      # Stored by the registry and pushed into the game's state.
      def mirror?
        return @kind == :mirror
      end

      # Bound to $PokemonSystem, which stays the same object for the session
      # (loading a save doesn't replace it).
      def system?
        return @system
      end

      # Returns [found, value]. found is false when the game's state isn't
      # there yet.
      def read
        raw = @reader.call
        return [false, nil] if raw.nil?
        return [true, from_game(raw)]
      end

      def write(value)
        @writer.call(to_game(value))
      end

      private

      def to_game(value)
        case @style
        when :int           then value ? 1 : 0
        when :int_inverted  then value ? 0 : 1
        when :bool_inverted then !value
        when Array          then @style[0].call(value)
        else value
        end
      end

      def from_game(raw)
        case @style
        when :int           then raw.to_i != 0
        when :int_inverted  then raw.to_i == 0
        when :bool_inverted then !raw
        when Array          then @style[1].call(raw)
        else raw
        end
      end
    end

    @groups = {}
    @pages = {}
    @definitions = {}
    @callbacks = {}
    @global = nil
    @save_active = false
    @dirty = false
    @pushed = {}      # the value last written into the game's state, per Global setting
    @pending_adopt = []
    @system_ready = false

    class << self
      #------------------------------------------------------------------------
      # Boot and lifecycle
      #------------------------------------------------------------------------
      def boot
        Reloaded::SaveStore.register(SAVE_SECTION)
        Reloaded::Events.on(:system_ready, :settings, 10) { apply_global }
        Reloaded::Events.on(:title_screen, :settings, 10) { @save_active = false }
        Reloaded::Events.on(:save_loaded, :settings, 10) { |context| load_save(context) }
        Reloaded::Events.on(:saving, :settings, 10) { store_mirrors }
        Reloaded::Events.on(:saved, :settings, 10) { flush }
        at_exit { flush rescue nil }
        return true
      end

      # Some game code changes a Global setting's state directly. Adopts any
      # such change so the registry doesn't push the old value back.
      # system_only limits it to $PokemonSystem settings.
      def sync_from_game(system_only = false)
        @definitions.each_value do |d|
          next unless d[:scope] == :global && d[:bind] && d[:bind].mirror?
          next if system_only && !d[:bind].system?
          next unless @pushed.has_key?(d[:key])
          found, value = d[:bind].read
          next unless found
          value = safe_normalize(d, value)
          next if value == @pushed[d[:key]]
          global["values"][d[:key].to_s] = value
          @pushed[d[:key]] = value
          @dirty = true
        end
      end

      # True while a save is loaded (or a new game is running). Save settings
      # are locked at the title screen.
      def save_active?
        return @save_active
      end

      # Writes Global settings to disk if anything changed since the last write.
      def flush
        return true unless @dirty
        data = global.dup
        data["values"] = data["values"].sort.to_h
        Reloaded::Paths.write_atomic(global_path, Reloaded::JSON.generate(data, true))
        @dirty = false
        return true
      rescue Exception => e
        Reloaded::Log.exception("Could not write #{GLOBAL_FILE}", e, :settings)
        return false
      end

      #------------------------------------------------------------------------
      # Groups and pages
      #------------------------------------------------------------------------
      def register_group(id, options = {})
        @groups[id.to_sym] = {
          :id          => id.to_sym,
          :name        => options[:name] || titleize(id),
          :priority    => options[:priority] || 100,
          :description => options[:description].to_s
        }
      end

      def register_page(id, options = {})
        group = (options[:group] || :general).to_sym
        raise ArgumentError, "Page #{id} names unknown group #{group}" unless @groups[group]
        @pages[id.to_sym] = {
          :id          => id.to_sym,
          :group       => group,
          :name        => options[:name] || titleize(id),
          :icon        => (options[:icon] || id).to_sym,
          :description => options[:description].to_s,
          :priority    => options[:priority] || 100,
          :visible     => options[:visible],
          :feature     => options[:feature] ? options[:feature].to_sym : nil
        }
      end

      def groups
        return @groups.values.sort_by { |g| [g[:priority], g[:name]] }
      end

      def group(id)
        return @groups[id.to_sym]
      end

      # Pages of a group that have at least one visible setting.
      def pages(group_id = nil)
        list = @pages.values
        list = list.select { |p| p[:group] == group_id.to_sym } if group_id
        list = list.select { |p| page_visible?(p) }
        return list.sort_by { |p| [p[:priority], p[:name]] }
      end

      def page(id)
        return @pages[id.to_sym]
      end

      def page_visible?(page)
        page = @pages[page] if page.is_a?(Symbol)
        return false unless page
        return false if page[:feature] && !Reloaded::Features.on?(page[:feature])
        return false if page[:visible] && !safe_call(page[:visible])
        return keys(page[:id]).any?
      end

      #------------------------------------------------------------------------
      # Definitions
      #------------------------------------------------------------------------
      def register(key, options = {})
        key = key.to_sym
        page = (options[:page] || :general).to_sym
        raise ArgumentError, "Setting #{key} names unknown page #{page}" unless @pages[page]
        type = (options[:type] || :toggle).to_sym
        raise ArgumentError, "Setting #{key} has unknown type #{type}" unless TYPES.include?(type)
        scope = (options[:scope] || :global).to_sym
        raise ArgumentError, "Setting #{key} has unknown scope #{scope}" unless SCOPES.include?(scope)
        values = Array(options[:values]).map { |v| v.to_s }
        raise ArgumentError, "Enum setting #{key} has no values" if type == :enum && values.empty?
        definition = {
          :key         => key,
          :page        => page,
          :name        => options[:name] || titleize(key.to_s.split(".").last),
          :description => options[:description].to_s,
          :type        => type,
          :scope       => scope,
          :values      => values,
          :descriptions => Array(options[:descriptions]).map { |v| v.to_s },
          :locked_choices => options[:locked_choices],
          :long        => !!options[:long],
          :swatch      => options[:swatch] ? options[:swatch].to_sym : nil,
          :reset       => options[:reset],
          :remap       => options[:remap],
          :min         => options[:min],
          :max         => options[:max],
          :step        => options[:step] || 1,
          :unit        => options[:unit].to_s,
          :format      => options[:format],
          :bind        => options[:bind],
          :needs       => options[:needs] ? options[:needs].to_sym : nil,
          :needs_text  => options[:needs_text],
          :lock        => options[:lock],
          :soft_lock   => options[:soft_lock],
          :visible     => options[:visible],
          :feature     => options[:feature] ? options[:feature].to_sym : @pages[page][:feature],
          :apply       => options[:apply],
          :preview     => options[:preview],
          :on_press    => options[:on_press],
          :goes_to     => options[:goes_to] ? options[:goes_to].to_sym : nil,
          :commit      => options[:commit],
          :text        => options[:text],
          :added       => options[:added],
          :searchable  => Array(options[:searchable]).map { |s| s.to_s.downcase },
          :preset      => options.has_key?(:preset) ? !!options[:preset] : true,
          :priority    => options[:priority] || 100,
          :owner       => (options[:owner] || :kanto_reloaded).to_sym
        }
        definition[:default] = normalize(definition, options.has_key?(:default) ? options[:default] : fallback_default(definition))
        @definitions[key] = definition
        adopt_global(definition) if scope == :global
        return key
      end

      def registered?(key)
        return @definitions.has_key?(key.to_sym)
      end

      def definition(key)
        return @definitions[key.to_sym]
      end

      # Every registered setting, shown or not.
      def all_keys
        return @definitions.keys
      end

      # Keys on a page in display order, skipping hidden settings.
      def keys(page_id)
        list = @definitions.values.select { |d| d[:page] == page_id.to_sym && visible?(d[:key]) }
        return list.sort_by { |d| [d[:priority], d[:name]] }.map { |d| d[:key] }
      end

      def visible?(key)
        d = @definitions[key.to_sym]
        return false unless d
        return false if d[:feature] && !Reloaded::Features.on?(d[:feature])
        return true unless d[:visible]
        return !!safe_call(d[:visible])
      end

      #------------------------------------------------------------------------
      # Values
      #------------------------------------------------------------------------
      def get(key)
        d = @definitions[key.to_sym]
        return nil unless d
        return nil if d[:type] == :button
        if d[:bind] && !d[:bind].mirror?
          return d[:default] if d[:bind].live? && !@save_active
          found, value = d[:bind].read
          return found ? safe_normalize(d, value) : d[:default]
        end
        store = store_for(d)
        return d[:default] unless store
        return store.has_key?(d[:key].to_s) ? store[d[:key].to_s] : d[:default]
      end

      # Sets a value and returns true when it changed. Locked settings are only
      # changed when force is true (for presets that unlock what they need).
      def set(key, value, force = false)
        d = @definitions[key.to_sym]
        return false unless d && d[:type] != :button && d[:type] != :text
        return false if !force && locked?(key)
        new_value = normalize(d, value)
        return false if !force && locked_choices(key).has_key?(choice_index(d, new_value))
        old_value = get(key)
        return false if new_value == old_value
        write_value(d, new_value)
        run_apply(d, new_value)
        notify(d, new_value, old_value)
        return true
      rescue Exception => e
        Reloaded::Log.exception("Could not set #{key}", e, :settings)
        return false
      end

      def reset(key)
        d = @definitions[key.to_sym]
        return false unless d
        return set(key, d[:default])
      end

      def reset_page(page_id)
        return keys(page_id).count { |key| !locked?(key) && reset(key) }
      end

      def reset_all(scope = nil)
        list = @definitions.values
        list = list.select { |d| d[:scope] == scope.to_sym } if scope
        return list.count { |d| !locked?(d[:key]) && reset(d[:key]) }
      end

      def default(key)
        d = @definitions[key.to_sym]
        return d ? d[:default] : nil
      end

      def changed?(key)
        d = @definitions[key.to_sym]
        return false unless d && valued?(d)
        return get(key) != d[:default]
      end

      def valued?(definition)
        return [:toggle, :enum, :slider, :number].include?(definition[:type])
      end

      # Steps an enum, slider or number by delta steps; for a toggle, Left
      # (negative) is Off and Right is On. Returns true when the value changed.
      def step(key, delta)
        d = @definitions[key.to_sym]
        return false unless d
        value = get(key)
        case d[:type]
        when :toggle
          return set(key, delta > 0)
        when :enum
          target = value + delta
          return false if target < 0 || target >= d[:values].length
          return set(key, target)
        when :slider, :number
          target = value + delta * d[:step]
          target = d[:min] if d[:min] && target < d[:min]
          target = d[:max] if d[:max] && target > d[:max]
          return set(key, target)
        end
        return false
      end

      def press(key)
        d = @definitions[key.to_sym]
        return false unless d && d[:type] == :button && d[:on_press] && !locked?(key)
        d[:on_press].call
        return true
      rescue Exception => e
        raise if e.is_a?(SystemExit) || (defined?(Reset) && e.is_a?(Reset))   # the game closing or resetting
        Reloaded::Log.exception("Setting button #{key} failed", e, :settings)
        return false
      end

      # Text shown for the current (or a given) value.
      def display(key, value = :current)
        d = @definitions[key.to_sym]
        return "" unless d
        value = get(key) if value == :current
        return d[:format].call(value).to_s if d[:format]
        case d[:type]
        when :toggle          then return value ? _INTL("On") : _INTL("Off")
        when :enum            then return _INTL(d[:values][value].to_s)
        when :slider, :number then return value.to_s + d[:unit]
        when :text            then return d[:text].respond_to?(:call) ? d[:text].call.to_s : d[:text].to_s
        end
        return ""
      end

      # Values of settings with a :commit action, taken when the screen opens.
      def snapshot
        result = {}
        @definitions.each_value { |d| result[d[:key]] = get(d[:key]) if d[:commit] }
        return result
      end

      # Runs :commit for each setting that changed since the snapshot: work
      # that should happen once when the player leaves the screen, not on
      # every key press.
      def commit(snapshot)
        snapshot.each do |key, old_value|
          d = @definitions[key]
          value = get(key)
          next if value == old_value
          begin
            d[:commit].call(value, old_value)
          rescue Exception => e
            Reloaded::Log.exception("Committing #{key} failed", e, :settings)
          end
        end
        flush
      end

      def on_change(key, id, &block)
        list = (@callbacks[key.to_sym] ||= [])
        list.reject! { |entry| entry[0] == id }
        list << [id, block]
        return true
      end

      #------------------------------------------------------------------------
      # Locks
      #------------------------------------------------------------------------
      # Why the setting can't be changed right now, or nil when it can.
      def lock_reason(key)
        d = @definitions[key.to_sym]
        return nil unless d
        return _INTL(SAVE_LOCK_TEXT) if d[:scope] == :save && !@save_active
        if d[:needs] && !needs_met?(get(d[:needs]))
          return d[:needs_text] || _INTL("Turn on {1} first", @definitions[d[:needs]] ? @definitions[d[:needs]][:name] : d[:needs])
        end
        [d[:lock], d[:soft_lock]].each do |rule|
          next unless rule
          reason = safe_call(rule)
          return reason.to_s if reason && !reason.to_s.empty?
        end
        return nil
      end

      def locked?(key)
        return !lock_reason(key).nil?
      end

      # An :enum's (or a toggle's: 0 Off, 1 On) values that can't be picked
      # right now: { index => reason } (the reason may be empty).
      def locked_choices(key)
        d = @definitions[key.to_sym]
        rule = d && d[:locked_choices]
        return {} unless rule
        found = rule.respond_to?(:call) ? safe_call(rule) : rule
        out = {}
        if found.is_a?(Hash)
          found.each { |i, why| out[i.to_i] = why.to_s }
        else
          Array(found).each { |i| out[i.to_i] = "" }
        end
        return out
      end

      # What value i of a choice does (:descriptions), or nil.
      def choice_description(key, i)
        d = @definitions[key.to_sym]
        text = d && d[:descriptions][i]
        return text.nil? || text.empty? ? nil : _INTL(text)
      end

      # A lock that a preset must respect: no save loaded, or the setting's
      # own rule (:lock). Dependencies aren't: :needs and :soft_lock depend
      # on other settings a preset sets too.
      def hard_lock_reason(key)
        d = @definitions[key.to_sym]
        return nil unless d
        return _INTL(SAVE_LOCK_TEXT) if d[:scope] == :save && !@save_active
        if d[:lock]
          reason = safe_call(d[:lock])
          return reason.to_s if reason && !reason.to_s.empty?
        end
        return nil
      end

      # A toggle that is on, or a number or enum above zero.
      def needs_met?(value)
        return value > 0 if value.is_a?(Numeric)
        return !!value
      end

      #------------------------------------------------------------------------
      # Search, "New" badges and pins
      #------------------------------------------------------------------------
      # Settings whose name, page name or search words contain the text.
      def search(text)
        query = text.to_s.strip.downcase
        return [] if query.empty?
        results = []
        groups.each do |g|
          pages(g[:id]).each do |p|
            keys(p[:id]).each do |key|
              d = @definitions[key]
              haystack = ([d[:name], p[:name]] + d[:searchable]).join(" ").downcase
              results << key if haystack.include?(query)
            end
          end
        end
        return results
      end

      def new?(key)
        d = @definitions[key.to_sym]
        return false unless d && d[:added]
        return !global_list("seen").include?(key.to_s)
      end

      def page_new?(page_id)
        return keys(page_id).any? { |key| new?(key) }
      end

      def mark_seen(key)
        return unless new?(key)
        global_list("seen") << key.to_s
        @dirty = true
      end

      def pinned?(key)
        return global_list("pins").include?(key.to_s)
      end

      def toggle_pin(key)
        list = global_list("pins")
        list.include?(key.to_s) ? list.delete(key.to_s) : list << key.to_s
        @dirty = true
        return pinned?(key)
      end

      def pins
        return global_list("pins").map { |k| k.to_sym }.select { |k| @definitions[k] && visible?(k) }
      end

      #------------------------------------------------------------------------
      # Export / import (presets and share codes)
      #------------------------------------------------------------------------
      # Values for a preset or share code. Settings registered with
      # :preset => false and hidden settings are left out.
      def export_values(scope = nil)
        result = {}
        @definitions.each_value do |d|
          next unless valued?(d) && d[:preset] && visible?(d[:key])
          next if scope && d[:scope] != scope.to_sym
          result[d[:key].to_s] = get(d[:key])
        end
        return result
      end

      # Applies values from a preset. Returns the number of settings changed.
      # Unknown keys, Save settings at the title screen and settings locked by
      # their own rule are skipped.
      def import_values(values)
        changed = 0
        values.each do |key, value|
          d = @definitions[key.to_sym]
          next unless d && valued?(d) && d[:preset] && visible?(key)
          next if hard_lock_reason(key)
          changed += 1 if set(key, value, true)
        end
        return changed
      end

      private

      #------------------------------------------------------------------------
      # Save integration
      #------------------------------------------------------------------------
      def save_store
        return Reloaded::SaveStore.section(SAVE_SECTION)
      end

      # A save (or a new game) was loaded: apply its Save settings, then push
      # Global settings into anything that lives in per-save objects.
      def load_save(context)
        @save_active = true
        store = save_store || {}
        @definitions.each_value do |d|
          next unless d[:scope] == :save
          next if d[:bind] && !d[:bind].mirror?
          key = d[:key].to_s
          unless store.has_key?(key) || context[:new_game]
            found, value = adopt_from_incoming_save(d)
            store[key] = safe_normalize(d, value) if found
          end
          value = store.has_key?(key) ? store[key] : d[:default]
          d[:bind].write(value) if d[:bind]
          run_apply(d, value, true)
        end
        sync_from_game(true)
        @definitions.each_value do |d|
          next unless d[:scope] == :global && d[:bind] && d[:bind].mirror?
          key = d[:key].to_s
          unless global["values"].has_key?(key)
            found, value = d[:bind].read
            if found
              global["values"][key] = safe_normalize(d, value)
              @pushed[d[:key]] = global["values"][key]
              @dirty = true
              next
            end
          end
          push(d, get(d[:key]))
        end
      end

      # Copies mirrored Save settings from the game's state into the save.
      def store_mirrors
        store = save_store
        return unless store
        @definitions.each_value do |d|
          next unless d[:scope] == :save && d[:bind] && d[:bind].mirror?
          found, value = d[:bind].read
          store[d[:key].to_s] = safe_normalize(d, value) if found
        end
      end

      # A save from before this setting existed: take the bound value from the
      # save's own $PokemonSystem.
      def adopt_from_incoming_save(definition)
        data = Reloaded::Lifecycle.incoming_save_data
        return [false, nil] unless data.is_a?(Hash) && definition[:bind]
        system = data[:pokemon_system]
        return definition[:bind].read unless system
        previous = $PokemonSystem
        begin
          $PokemonSystem = system
          return definition[:bind].read
        ensure
          $PokemonSystem = previous
        end
      rescue Exception
        return [false, nil]
      end

      #------------------------------------------------------------------------
      # Global storage
      #------------------------------------------------------------------------
      def global_path
        return File.join(Reloaded::Paths.settings_dir, GLOBAL_FILE)
      end

      # The Global settings file's contents, read on first use.
      def global
        load_global unless @global
        return @global
      end

      def load_global
        @global = { "schema" => SCHEMA_VERSION, "values" => {}, "seen" => [], "pins" => [] }
        @file_schema = SCHEMA_VERSION
        text = Reloaded::Paths.read_text(global_path)
        return if text.nil? || text.strip.empty?
        parsed = Reloaded::JSON.parse(text)
        return unless parsed.is_a?(Hash)
        @file_schema = parsed["schema"].to_i
        @global["values"] = parsed["values"] if parsed["values"].is_a?(Hash)
        @global["seen"] = parsed["seen"].map { |s| s.to_s } if parsed["seen"].is_a?(Array)
        @global["pins"] = parsed["pins"].map { |s| s.to_s } if parsed["pins"].is_a?(Array)
      rescue Exception => e
        kept = Reloaded::Paths.set_aside(global_path)
        Reloaded::Log.exception("Could not read #{GLOBAL_FILE}; using defaults (the file was kept as #{kept ? File.basename(kept) : "it was"})", e, :settings)
      end

      def global_list(name)
        return (global[name] ||= [])
      end

      def store_for(definition)
        return global["values"] if definition[:scope] == :global
        return @save_active ? save_store : nil
      end

      # A Global setting seen for the first time takes the value the game
      # already has, so nothing changes for the player.
      def adopt_global(definition)
        key = definition[:key].to_s
        values = global["values"]
        if values.has_key?(key) && definition[:reset] && @file_schema.to_i < definition[:reset].to_i
          values.delete(key)       # stored before the setting's reset: back to its default
          @dirty = true
        end
        remap = definition[:remap]
        if values.has_key?(key) && remap && @file_schema.to_i < remap[0].to_i && remap[1].has_key?(values[key].to_i)
          values[key] = remap[1][values[key].to_i]    # stored before values were added: the same choice, moved
          @dirty = true
        end
        if values.has_key?(key)
          values[key] = safe_normalize(definition, values[key])
          return
        end
        return unless definition[:bind] && definition[:bind].mirror?
        if @system_ready
          found, value = definition[:bind].read
          if found
            values[key] = safe_normalize(definition, value)
            @dirty = true
          end
        else
          @pending_adopt << definition[:key]
        end
      end

      # The game set up $PokemonSystem at startup.
      def apply_global
        @system_ready = true
        @pending_adopt.each do |key|
          d = @definitions[key]
          found, value = d[:bind].read
          next unless found
          global["values"][key.to_s] = safe_normalize(d, value)
          @dirty = true
        end
        @pending_adopt = []
        @definitions.each_value do |d|
          next unless d[:scope] == :global
          value = get(d[:key])
          push(d, value) if d[:bind] && d[:bind].mirror?
          run_apply(d, value, true)
        end
        flush
      end

      # Writes a Global setting into the game's state and remembers what was
      # written, so sync_from_game can tell when the game changed it.
      def push(definition, value)
        definition[:bind].write(value)
        @pushed[definition[:key]] = value if definition[:scope] == :global
      end

      def write_value(definition, value)
        if definition[:bind] && !definition[:bind].mirror?
          definition[:bind].write(value)
          return
        end
        store = store_for(definition)
        raise "No save is loaded" unless store
        store[definition[:key].to_s] = value
        @dirty = true if definition[:scope] == :global
        push(definition, value) if definition[:bind]
      end

      def run_apply(definition, value, restoring = false)
        return unless definition[:apply]
        definition[:apply].call(value, restoring)
      rescue Exception => e
        Reloaded::Log.exception("Applying #{definition[:key]} failed", e, :settings)
      end

      def notify(definition, value, old_value)
        Array(@callbacks[definition[:key]]).each do |id, block|
          begin
            block.call(value, old_value)
          rescue Exception => e
            Reloaded::Log.exception("Setting callback #{definition[:key]}/#{id} failed", e, :settings)
          end
        end
        Reloaded::Events.emit(:setting_changed, { :key => definition[:key], :value => value, :old_value => old_value })
      end

      #------------------------------------------------------------------------
      # Normalizing values
      #------------------------------------------------------------------------
      def fallback_default(definition)
        case definition[:type]
        when :toggle          then return false
        when :enum            then return 0
        when :slider, :number then return definition[:min] || 0
        when :text            then return ""
        end
        return nil
      end

      # A toggle's or an enum's value as its choice's index (a toggle: 0 Off,
      # 1 On); nil for the other types.
      def choice_index(definition, value)
        return value ? 1 : 0 if definition[:type] == :toggle
        return value.to_i if definition[:type] == :enum
        return nil
      end

      def normalize(definition, value)
        case definition[:type]
        when :toggle
          return value != 0 if value.is_a?(Numeric)
          return ["true", "on", "1", "yes"].include?(value.to_s.downcase) if value.is_a?(String)
          return !!value
        when :enum
          index = value.is_a?(String) && value !~ /\A\d+\z/ ? definition[:values].index(value) : value.to_i
          index = 0 if index.nil? || index < 0 || index >= definition[:values].length
          return index
        when :slider, :number
          number = value.to_i
          number = definition[:min] if definition[:min] && number < definition[:min]
          number = definition[:max] if definition[:max] && number > definition[:max]
          return number
        when :text
          return value.to_s
        end
        return value
      end

      def safe_normalize(definition, value)
        return normalize(definition, value)
      rescue Exception
        return definition[:default]
      end

      def safe_call(callable)
        return callable.call
      rescue Exception => e
        Reloaded::Log.warning_once("Settings condition failed: #{e.class}: #{e.message}", :settings)
        return nil
      end

      def titleize(value)
        return value.to_s.split(/[_\s]+/).map { |part| part[0, 1].upcase + part[1..-1].to_s }.join(" ")
      end
    end
  end
end
