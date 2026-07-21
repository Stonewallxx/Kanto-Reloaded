#==============================================================================
# Kanto Reloaded - Autosort Bag
#==============================================================================
# Save-backed Bag ordering with narrow post-store and Bag-window hooks.
# Native KIF item storage always runs first and retains its return value.
#==============================================================================

module KantoReloaded
  module AutosortBag
    SAVE_SYSTEM = :autosort_bag
    SEPARATOR = :__SEPARATOR__

    SETTINGS_ACTION = :autosort_bag_settings
    ENABLED_SETTING = :autosort_bag_enabled
    RECENT_SETTING = :autosort_bag_always_move_recent
    MANUAL_SETTING = :autosort_bag_manual_button
    MODE_PREFIX = "autosort_bag_mode_"

    MODES = [:off, :custom, :alphabetical].freeze
    MODE_LABELS = ["Off", "Custom List", "Alphabetical"].freeze
    RECENT_POLICIES = [:off, :first, :last].freeze
    RECENT_LABELS = ["Off", "First", "Last"].freeze

    POCKETS = {
      1 => :items,
      2 => :medicine,
      3 => :pok_balls,
      4 => :tms_hms,
      5 => :berries,
      6 => :mail,
      7 => :battle_items,
      8 => :key_items
    }.freeze
    POCKET_LABELS = {
      :items => "Items",
      :medicine => "Medicine",
      :pok_balls => "Pokeballs",
      :tms_hms => "TM/HMs",
      :berries => "Berries",
      :mail => "Mail",
      :battle_items => "Battle Items",
      :key_items => "Key Items"
    }.freeze
    POCKET_ALIASES = {
      :items => :items,
      :medicine => :medicine,
      :pokeballs => :pok_balls,
      :poke_balls => :pok_balls,
      :pok_balls => :pok_balls,
      :tm_hms => :tms_hms,
      :tms_hms => :tms_hms,
      :berries => :berries,
      :mail => :mail,
      :battle_items => :battle_items,
      :key_items => :key_items
    }.freeze
    POCKET_INDEXES = POCKETS.each_with_object({}) do |(index, key), result|
      result[key] = index
    end.freeze
    NATIVE_SORTED_POCKETS = [:tms_hms, :berries].freeze

    LEGACY_LIST_FILE = "AutosortBag_list.kro"
    LEGACY_FAVORITES_FILE = "AutosortBag_favorites.kro"
    EXPORT_FILE = "AutosortBag_lists.txt"
    LEGACY_FILE_LIMIT = 4 * 1024 * 1024

    class << self
      def install
        settings_ready = register_settings
        hooks_ready = register_hooks
        events_ready = register_events
        migrate_legacy! if trainer_ready?
        state = settings_ready && hooks_ready && events_ready ?
          "ready" : "partially unavailable"
        KantoReloaded::Log.info(
          "Installed Autosort Bag module (#{state})", :modules
        ) if defined?(KantoReloaded::Log)
        settings_ready && hooks_ready && events_ready
      rescue StandardError => e
        log_exception("Autosort Bag install failed", e)
        false
      end

      def enabled?
        truthy_setting(ENABLED_SETTING, 1)
      end

      def manual_button_enabled?
        truthy_setting(MANUAL_SETTING, 1)
      end

      def recent_policy
        index = KantoReloaded::Settings.get(RECENT_SETTING, 0).to_i
        index = [[index, 0].max, RECENT_POLICIES.length - 1].min
        RECENT_POLICIES[index]
      rescue StandardError
        :off
      end

      def mode(pocket)
        key = pocket_key(pocket)
        return :off unless key
        default = default_mode_index(key)
        index = KantoReloaded::Settings.get(mode_setting_key(key), default).to_i
        index = [[index, 0].max, MODES.length - 1].min
        MODES[index]
      rescue StandardError
        :off
      end

      def pocket_key(value)
        return POCKETS[value] if value.is_a?(Integer)
        token = value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_")
        token = token.gsub(/\A_+|_+\z/, "").to_sym
        key = POCKET_ALIASES[token]
        POCKET_INDEXES.has_key?(key) ? key : nil
      rescue StandardError
        nil
      end

      def pocket_index(value)
        return value if value.is_a?(Integer) && POCKETS.has_key?(value)
        POCKET_INDEXES[pocket_key(value)]
      rescue StandardError
        nil
      end

      def pocket_name(value)
        key = pocket_key(value)
        return value.to_s unless key
        POCKET_LABELS[key] || key.to_s
      rescue StandardError
        value.to_s
      end

      def list_for(pocket)
        key = pocket_key(pocket)
        return [] unless key
        entries = lists[key] || []
        entries.map { |entry| entry.is_a?(Array) ? entry.dup : entry }
      rescue StandardError
        []
      end

      def favorites_for(pocket)
        key = pocket_key(pocket)
        return [] unless key
        Array(favorites[key]).dup
      rescue StandardError
        []
      end

      def set_list(pocket, entries, apply: true)
        key = pocket_key(pocket)
        return false unless key
        normalized = normalize_list(entries)
        data = lists
        data[key] = normalized
        return false unless state_set(:lists, data)

        allowed = normalized.reject { |entry| separator?(entry) }
        set_favorites(key, favorites_for(key).select { |item|
          allowed.include?(item)
        }, apply: false)
        apply_pocket(key) if apply
        true
      rescue StandardError => e
        log_exception("Autosort list save failed", e)
        false
      end

      def set_favorites(pocket, entries, apply: true)
        key = pocket_key(pocket)
        return false unless key
        normalized = normalize_item_ids(entries)
        data = favorites
        data[key] = normalized
        return false unless state_set(:favorites, data)
        apply_pocket(key) if apply
        true
      rescue StandardError => e
        log_exception("Autosort favorites save failed", e)
        false
      end

      def reset_pocket(pocket)
        key = pocket_key(pocket)
        return false unless key
        default_entries = KantoReloaded::AutosortBag::Defaults.lists[key] || []
        set_list(key, default_entries, apply: false)
        set_favorites(key, [], apply: false)
        apply_pocket(key)
        true
      rescue StandardError => e
        log_exception("Autosort pocket reset failed", e)
        false
      end

      def apply_pocket(pocket, bag = current_bag)
        key = pocket_key(pocket)
        index = pocket_index(key)
        return false unless bag && key && index
        selected_mode = mode(key)
        case selected_mode
        when :custom
          sort_custom(bag, index)
        when :alphabetical
          sort_alphabetically(bag, index)
        else
          false
        end
      rescue StandardError => e
        log_exception("Autosort pocket apply failed", e)
        false
      end

      def apply_all(bag = current_bag)
        return false unless bag
        changed = false
        POCKETS.each_key do |index|
          changed = apply_pocket(index, bag) || changed
        end
        changed
      rescue StandardError => e
        log_exception("Autosort all-pockets apply failed", e)
        false
      end

      def after_store(bag, item, quantity_before, result)
        return result unless result && enabled?
        item_data = GameData::Item.try_get(item) rescue nil
        return result unless item_data
        index = item_data.pocket.to_i
        key = pocket_key(index)
        return result unless key

        selected_mode = mode(key)
        policy = recent_policy
        if policy == :off
          case selected_mode
          when :custom
            sort_custom(bag, index) if quantity_before.to_i <= 0
          when :alphabetical
            sort_alphabetically(bag, index) if quantity_before.to_i <= 0
          end
          return result
        end

        case selected_mode
        when :custom
          sort_custom(bag, index)
        when :alphabetical
          sort_alphabetically(bag, index)
        end
        remember_recent_baseline(bag, key, index, selected_mode)
        case policy
        when :first
          move_received_item(bag, index, item_data.id, true)
        when :last
          move_received_item(bag, index, item_data.id, false)
        end
        result
      rescue StandardError => e
        log_exception("Autosort post-store processing failed", e)
        result
      end

      def prepare_bag_scene(scene, choosing)
        sprites = scene.instance_variable_get(:@sprites)
        window = sprites["itemlist"] if sprites.is_a?(Hash)
        return false unless window
        window.instance_variable_set(
          :@kr_autosort_manual_allowed, !choosing
        )
        unless choosing
          window.instance_variable_set(:@kr_autosort_recent_seen, {})
          observe_recent_pocket(window)
        end
        true
      rescue StandardError => e
        log_exception("Autosort Bag scene setup failed", e)
        false
      end

      def handle_bag_window_update(window)
        observe_recent_pocket(window)
        return false unless manual_button_enabled?
        return false unless window.instance_variable_get(
          :@kr_autosort_manual_allowed
        )
        return false if window.respond_to?(:active) && !window.active
        return false if window.respond_to?(:sorting) && window.sorting
        return false if window.respond_to?(:disposed?) && window.disposed?
        return false unless defined?(Input) && Input.const_defined?(:SPECIAL)
        return false unless Input.trigger?(Input::SPECIAL)
        manual_sort(window)
      rescue StandardError => e
        log_exception("Autosort manual input failed", e)
        false
      end

      def observe_recent_pocket(window)
        return false unless window.instance_variable_get(
          :@kr_autosort_manual_allowed
        )
        bag = window.instance_variable_get(:@bag)
        index = window.respond_to?(:pocket) ? window.pocket : nil
        key = pocket_key(index)
        return false unless bag && key
        states = recent_positions
        state = recent_position_state(states[key])
        return false unless state

        seen_this_session = window.instance_variable_get(
          :@kr_autosort_recent_seen
        )
        seen_this_session = {} unless seen_this_session.is_a?(Hash)
        if state[:seen] && !seen_this_session[key]
          restore_recent_baseline(bag, key, index, state)
          states.delete(key)
          state_set(:recent_positions, states)
          window.refresh if window.respond_to?(:refresh)
          seen_this_session[key] = true
          window.instance_variable_set(
            :@kr_autosort_recent_seen, seen_this_session
          )
          return true
        end

        unless state[:seen]
          state[:seen] = true
          states[key] = state
          state_set(:recent_positions, states)
        end
        seen_this_session[key] = true
        window.instance_variable_set(
          :@kr_autosort_recent_seen, seen_this_session
        )
        false
      rescue StandardError => e
        log_exception("Autosort recent-item observation failed", e)
        false
      end

      def clear_recent_positions(restore = true, bag = current_bag)
        states = recent_positions
        if restore && bag
          states.each do |key, state|
            restore_recent_baseline(
              bag, key, pocket_index(key), state
            )
          end
        end
        state_set(:recent_positions, {})
        true
      rescue StandardError => e
        log_exception("Autosort recent-item cleanup failed", e)
        false
      end

      def manual_sort(window)
        bag = window.instance_variable_get(:@bag)
        index = window.respond_to?(:pocket) ? window.pocket : nil
        key = pocket_key(index)
        return false unless bag && key

        case mode(key)
        when :custom
          sort_custom(bag, index)
        when :alphabetical
          sort_alphabetically(bag, index)
        else
          pbPlayBuzzerSE if defined?(pbPlayBuzzerSE)
          KantoReloaded::Toast.warning(
            _INTL("{1} pocket sorting is off.", pocket_name(key))
          )
          return false
        end

        window.refresh if window.respond_to?(:refresh)
        pbPlayDecisionSE if defined?(pbPlayDecisionSE)
        KantoReloaded::Toast.success(
          _INTL("{1} pocket sorted.", pocket_name(key))
        )
        true
      rescue StandardError => e
        log_exception("Autosort manual sort failed", e)
        false
      end

      def open_editor
        return false unless defined?(KantoReloaded::AutosortBag::EditorScene)
        runner = proc { KantoReloaded::AutosortBag::EditorScene.new.main }
        defined?(pbFadeOutIn) ? pbFadeOutIn(&runner) : runner.call
        true
      rescue StandardError => e
        log_exception("Autosort list editor failed to open", e)
        KantoReloaded::Toast.error(_INTL("Sorting Lists could not be opened."))
        false
      end

      def sort_all_now
        bag = current_bag
        unless bag
          KantoReloaded::Toast.warning(
            _INTL("The Bag is not available.")
          )
          return false
        end
        apply_all(bag)
        KantoReloaded::Toast.success(
          _INTL("All active pocket policies were applied.")
        )
        true
      rescue StandardError => e
        log_exception("Autosort all-pockets action failed", e)
        KantoReloaded::Toast.error(
          _INTL("The Bag could not be sorted.")
        )
        false
      end

      def export_lists
        path = export_path
        return [false, _INTL("The export folder could not be created.")] unless
          ensure_export_directory

        lines = [
          "# Kanto Reloaded Autosort Bag",
          "# Format Version: 2",
          "# One item ID per line.",
          "# Prefix an item with * to mark it as a favorite.",
          "# Use -- NAME -- for an editor separator.",
          ""
        ]
        lines << "[Settings]"
        lines << "Autosort New Items = #{enabled? ? 'On' : 'Off'}"
        lines << "Always Move Recent = #{RECENT_LABELS[
          RECENT_POLICIES.index(recent_policy) || 0
        ]}"
        lines << "Manual Sort Button = #{
          manual_button_enabled? ? 'On' : 'Off'
        }"
        POCKETS.each_value do |key|
          lines << "#{pocket_name(key)} = #{MODE_LABELS[
            MODES.index(mode(key)) || 0
          ]}"
        end
        lines << ""
        POCKETS.each_value do |key|
          favorite_set = favorites_for(key).each_with_object({}) do |item, set|
            set[item] = true
          end
          lines << "[#{pocket_name(key)}]"
          list_for(key).each do |entry|
            if separator?(entry)
              lines << "-- #{separator_name(entry)} --"
            else
              prefix = favorite_set[entry] ? "* " : ""
              lines << "#{prefix}#{entry}"
            end
          end
          lines << ""
        end
        File.binwrite(path, lines.join("\r\n"))
        KantoReloaded::Log.info(
          "Exported Autosort Bag configuration to #{EXPORT_FILE}", :modules
        ) if defined?(KantoReloaded::Log)
        [true, _INTL("Autosort configuration exported to {1}.", EXPORT_FILE)]
      rescue StandardError => e
        log_exception("Autosort configuration export failed", e)
        [false, _INTL("Autosort configuration export failed.")]
      end

      def import_lists
        path = export_path
        return [false, _INTL("{1} was not found.", EXPORT_FILE)] unless
          File.exist?(path)
        text = decode_text(File.binread(path))
        parsed_lists = {}
        parsed_favorites = {}
        parsed_settings = {}
        current = nil
        ignored = 0

        text.each_line do |raw_line|
          line = raw_line.to_s.strip
          next if line.empty? || line.start_with?("#", "//")
          if line =~ /\A\[([^\]]+)\]\z/
            section = Regexp.last_match(1).to_s.strip
            current = normalize_setting_token(section) == "settings" ?
              :settings : pocket_key(section)
            parsed_lists[current] ||= [] if current
            parsed_favorites[current] ||= [] if current
            next
          end
          next unless current

          if current == :settings
            setting = parse_imported_setting(line)
            if setting
              parsed_settings[setting[0]] = setting[1]
            else
              ignored += 1
            end
            next
          end

          if line =~ /\A--\s*(.*?)\s*--\z/
            parsed_lists[current] << [
              SEPARATOR, sanitize_separator_name(Regexp.last_match(1))
            ]
            next
          end

          line.split(/[;,]/).each do |token|
            value = token.to_s.strip
            favorite = value.start_with?("*")
            value = value[1..-1].to_s.strip if favorite
            item = normalize_item_id(value)
            unless item && item_in_pocket?(item, current)
              ignored += 1
              next
            end
            parsed_lists[current] << item unless
              parsed_lists[current].include?(item)
            parsed_favorites[current] << item if favorite &&
              !parsed_favorites[current].include?(item)
          end
        end

        parsed_lists.delete(:settings)
        parsed_favorites.delete(:settings)
        return [false, _INTL("No valid Autosort configuration was found.")] if
          parsed_lists.empty? && parsed_settings.empty?
        parsed_lists.each do |key, entries|
          set_list(key, entries, apply: false)
          set_favorites(key, parsed_favorites[key] || [], apply: false)
        end
        parsed_settings.each do |key, value|
          KantoReloaded::Settings.set(key, value)
        end
        apply_all
        suffix = ignored > 0 ? _INTL(" {1} invalid entries were ignored.", ignored) : ""
        [true, _INTL("Autosort configuration imported.") + suffix]
      rescue StandardError => e
        log_exception("Autosort configuration import failed", e)
        [false, _INTL("Autosort configuration import failed.")]
      end

      def migrate_legacy!
        migrate_legacy_settings
        migrate_removed_recent_modes
        migrate_legacy_files
        true
      rescue StandardError => e
        log_exception("Autosort legacy migration failed", e)
        false
      end

      def separator?(entry)
        entry.is_a?(Array) && entry[0].to_sym == SEPARATOR
      rescue StandardError
        false
      end

      def separator_name(entry)
        separator?(entry) ? sanitize_separator_name(entry[1]) : "SEPARATOR"
      end

      def item_name(item)
        data = GameData::Item.try_get(item) rescue nil
        data ? data.name : item.to_s
      rescue StandardError
        item.to_s
      end

      def bag_items_for(pocket)
        bag = current_bag
        index = pocket_index(pocket)
        return [] unless bag && index
        Array(bag.pockets[index]).map { |slot| normalize_item_id(slot[0]) }.
          compact.uniq
      rescue StandardError
        []
      end

      private

      def register_settings
        return false unless defined?(KantoReloaded::Settings)
        register_settings_action
        register_main_settings
        register_pocket_settings
        register_setting_callbacks
        true
      end

      def register_settings_action
        KantoReloaded::Settings.register(SETTINGS_ACTION, {
          :name => "Autosort Bag",
          :description => "Configure automatic Bag ordering, pocket policies, and custom lists.",
          :type => :button,
          :category => :quality_of_life,
          :owner => :kanto_reloaded,
          :priority => 1000,
          :on_press => proc {
            KantoReloaded::SettingsUI.open_module(:autosort_bag)
          }
        })
      end

      def register_main_settings
        visible = module_visible(:autosort_bag)
        definitions = [
          [:autosort_bag_pockets, {
            :name => "Per-Pocket Sorting",
            :description => "Choose an ordering policy for each Bag pocket.",
            :type => :button, :priority => 10,
            :on_press => proc {
              KantoReloaded::SettingsUI.open_module(:autosort_bag_pockets)
            }
          }],
          [:autosort_bag_lists, {
            :name => "Sorting Lists",
            :description => "Edit custom ordering lists, separators, and favorite items.",
            :type => :button, :priority => 20,
            :on_press => proc { KantoReloaded::AutosortBag.open_editor }
          }],
          [:autosort_bag_export, {
            :name => "Export Configuration",
            :description => "Export settings, pocket policies, sorting lists, and favorites to text.",
            :type => :button, :priority => 30,
            :on_press => proc {
              success, message = KantoReloaded::AutosortBag.export_lists
              success ? KantoReloaded::Toast.success(message) :
                KantoReloaded::Toast.error(message)
            }
          }],
          [:autosort_bag_import, {
            :name => "Import Configuration",
            :description => "Import settings, pocket policies, sorting lists, and favorites from text.",
            :type => :button, :priority => 40,
            :on_press => proc {
              next unless KantoReloaded::PopupWindow.confirm(
                _INTL("Import Autosort configuration from {1}?", EXPORT_FILE),
                :default => false
              )
              success, message = KantoReloaded::AutosortBag.import_lists
              success ? KantoReloaded::Toast.success(message) :
                KantoReloaded::Toast.error(message)
            }
          }],
          [:autosort_bag_sort_all, {
            :name => "Sort All Pockets Now",
            :description => "Immediately apply every active pocket sorting policy.",
            :type => :button, :priority => 50,
            :on_press => proc { KantoReloaded::AutosortBag.sort_all_now }
          }],
          [ENABLED_SETTING, {
            :name => "Autosort New Items",
            :description => "Apply each pocket's policy after items are received.",
            :type => :toggle, :default => 1, :priority => 60
          }],
          [RECENT_SETTING, {
            :name => "Always Move Recent",
            :description => "Temporarily move received items first or last until the pocket is viewed and the Bag is reopened.",
            :type => :enum, :values => RECENT_LABELS,
            :default => 0, :priority => 70
          }],
          [MANUAL_SETTING, {
            :name => "Manual Sort Button",
            :description => "Use the Special input to apply Custom List or Alphabetical sorting in the Bag.",
            :type => :toggle, :default => 1, :priority => 80
          }]
        ]
        definitions.each do |key, data|
          KantoReloaded::Settings.register(key, data.merge(
            :category => :quality_of_life,
            :owner => :autosort_bag,
            :value_style => :integer,
            :visible_if => visible
          ))
        end
      end

      def register_pocket_settings
        visible = module_visible(:autosort_bag_pockets)
        POCKETS.each do |index, key|
          KantoReloaded::Settings.register(mode_setting_key(key), {
            :name => pocket_name(index),
            :description => "Choose how this pocket is ordered.",
            :type => :enum,
            :values => MODE_LABELS,
            :default => default_mode_index(key),
            :priority => index * 10,
            :category => :quality_of_life,
            :owner => :autosort_bag_pockets,
            :value_style => :integer,
            :visible_if => visible
          })
        end
      end

      def register_setting_callbacks
        KantoReloaded::Settings.register_on_change(
          ENABLED_SETTING, :autosort_bag_master_apply,
          :owner => :autosort_bag
        ) do |value|
          KantoReloaded::AutosortBag.apply_all if truthy_value?(value)
        end
        KantoReloaded::Settings.register_on_change(
          RECENT_SETTING, :autosort_bag_recent_clear,
          :owner => :autosort_bag
        ) do |value|
          if value.to_i == 0
            KantoReloaded::AutosortBag.clear_recent_positions
          end
        end
        POCKETS.each_value do |key|
          KantoReloaded::Settings.register_on_change(
            mode_setting_key(key), :"autosort_bag_apply_#{key}",
            :owner => :autosort_bag
          ) do |_value|
            KantoReloaded::AutosortBag.apply_pocket(key)
          end
        end
      end

      def register_hooks
        return false unless defined?(KantoReloaded::Hooks)
        results = []

        if defined?(PokemonBag)
          results << KantoReloaded::Hooks.wrap(
            PokemonBag, :pbStoreItem, :autosort_bag_after_store
          ) do |hook, item, *_arguments|
            before = pbQuantity(item) rescue 0
            result = hook.call
            KantoReloaded::AutosortBag.after_store(
              self, item, before, result
            )
          end
        else
          results << false
        end

        if defined?(PokemonBag_Scene)
          results << KantoReloaded::Hooks.wrap(
            PokemonBag_Scene, :pbStartScene, :autosort_bag_scene_context
          ) do |hook, _bag, choosing = false, *_arguments|
            result = hook.call
            KantoReloaded::AutosortBag.prepare_bag_scene(self, choosing)
            result
          end
        else
          results << false
        end

        if defined?(Window_PokemonBag)
          results << KantoReloaded::Hooks.wrap(
            Window_PokemonBag, :update, :autosort_bag_manual_input
          ) do |hook, *_arguments|
            result = hook.call
            KantoReloaded::AutosortBag.handle_bag_window_update(self)
            result
          end
        else
          results << false
        end

        results.all?
      end

      def register_events
        return false unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(
          :kanto_reloaded_save_loaded,
          :autosort_bag_legacy_migration,
          :priority => 320
        ) do |_context|
          KantoReloaded::AutosortBag.migrate_legacy!
        end
        KantoReloaded::Events.on(
          :kanto_reloaded_save_new_game,
          :autosort_bag_legacy_migration,
          :priority => 320
        ) do |_context|
          KantoReloaded::AutosortBag.migrate_legacy!
        end
        true
      end

      def sort_custom(bag, index)
        slots = pocket_slots(bag, index)
        return false unless slots
        priority = {}
        rank = 0
        list_for(index).each do |entry|
          next if separator?(entry)
          priority[entry] ||= rank
          rank += 1
        end
        favorite_rank = rank_hash(favorites_for(index))
        sorted = stable_sort(slots) do |slot, original_index|
          item = normalize_item_id(slot[0])
          if favorite_rank.has_key?(item)
            [0, favorite_rank[item], "", original_index]
          elsif priority.has_key?(item)
            [1, priority[item], normalized_item_name(item), original_index]
          else
            [2, 0, normalized_item_name(item), original_index]
          end
        end
        slots.replace(sorted)
        true
      end

      def sort_alphabetically(bag, index)
        slots = pocket_slots(bag, index)
        return false unless slots
        favorite_rank = rank_hash(favorites_for(index))
        sorted = stable_sort(slots) do |slot, original_index|
          item = normalize_item_id(slot[0])
          if favorite_rank.has_key?(item)
            [0, favorite_rank[item], "", original_index]
          else
            [1, 0, normalized_item_name(item), original_index]
          end
        end
        slots.replace(sorted)
        true
      end

      def move_received_item(bag, index, item, first)
        slots = pocket_slots(bag, index)
        return false unless slots
        item_id = normalize_item_id(item)
        position = slots.index do |slot|
          normalize_item_id(slot[0]) == item_id
        end
        return false unless position
        slot = slots.delete_at(position)
        first ? slots.unshift(slot) : slots.push(slot)
        true
      end

      def remember_recent_baseline(bag, key, index, selected_mode)
        slots = pocket_slots(bag, index)
        return false unless slots
        current = normalize_item_ids(slots.map { |slot| slot[0] })
        states = recent_positions
        previous = recent_position_state(states[key])
        baseline = current

        if previous && ![:custom, :alphabetical].include?(selected_mode)
          baseline = previous[:order].select { |item| current.include?(item) }
          baseline.concat(current.reject { |item| baseline.include?(item) })
        end

        states[key] = { :order => baseline, :seen => false }
        state_set(:recent_positions, states)
      end

      def restore_recent_baseline(bag, key, index, state)
        if [:custom, :alphabetical].include?(mode(key))
          return apply_pocket(key, bag)
        end

        slots = pocket_slots(bag, index)
        return false unless slots
        rank = rank_hash(state[:order])
        sorted = stable_sort(slots) do |slot, original_index|
          item = normalize_item_id(slot[0])
          if rank.has_key?(item)
            [0, rank[item], original_index]
          else
            [1, 0, original_index]
          end
        end
        slots.replace(sorted)
        true
      end

      def recent_positions
        value = state_get(:recent_positions, {})
        return {} unless value.is_a?(Hash)
        value.each_with_object({}) do |(raw_key, raw_state), result|
          key = pocket_key(raw_key)
          state = recent_position_state(raw_state)
          result[key] = state if key && state
        end
      end

      def recent_position_state(value)
        return nil unless value.is_a?(Hash)
        order = value[:order] || value["order"]
        seen = value.has_key?(:seen) ? value[:seen] : value["seen"]
        normalized_order = normalize_item_ids(order)
        return nil if normalized_order.empty?
        { :order => normalized_order, :seen => !!seen }
      end

      def promote_favorites(bag, index)
        slots = pocket_slots(bag, index)
        return false unless slots
        favorite_rank = rank_hash(favorites_for(index))
        return false if favorite_rank.empty?
        sorted = stable_sort(slots) do |slot, original_index|
          item = normalize_item_id(slot[0])
          favorite_rank.has_key?(item) ?
            [0, favorite_rank[item], original_index] :
            [1, 0, original_index]
        end
        slots.replace(sorted)
        true
      end

      def stable_sort(entries)
        entries.each_with_index.sort_by do |entry, index|
          yield(entry, index)
        end.map(&:first)
      end

      def pocket_slots(bag, index)
        return nil unless bag.respond_to?(:pockets)
        pockets = bag.pockets
        return nil unless pockets && pockets[index].is_a?(Array)
        pockets[index]
      end

      def lists
        value = state_get(:lists, nil)
        unless value.is_a?(Hash)
          value = normalize_list_hash(
            KantoReloaded::AutosortBag::Defaults.lists
          )
          state_set(:lists, value)
        end
        value
      end

      def favorites
        value = state_get(:favorites, nil)
        unless value.is_a?(Hash)
          value = {}
          state_set(:favorites, value)
        end
        value
      end

      def normalize_list_hash(value)
        result = {}
        value.each do |raw_key, entries|
          key = pocket_key(raw_key)
          key ||= pocket_key(raw_key.to_i) if raw_key.to_s =~ /\A\d+\z/
          next unless key
          result[key] = normalize_list(entries)
        end if value.is_a?(Hash)
        result
      end

      def normalize_favorites_hash(value)
        result = {}
        value.each do |raw_key, entries|
          key = pocket_key(raw_key)
          key ||= pocket_key(raw_key.to_i) if raw_key.to_s =~ /\A\d+\z/
          next unless key
          result[key] = normalize_item_ids(entries)
        end if value.is_a?(Hash)
        result
      end

      def normalize_list(entries)
        result = []
        seen = {}
        Array(entries).each do |entry|
          if separator?(entry)
            result << [SEPARATOR, separator_name(entry)]
            next
          end
          item = normalize_item_id(entry)
          next unless item || entry
          item ||= entry.to_s.upcase.to_sym
          next if seen[item]
          seen[item] = true
          result << item
        end
        result
      end

      def normalize_item_ids(entries)
        result = []
        Array(entries).each do |entry|
          item = normalize_item_id(entry)
          next unless item
          result << item unless result.include?(item)
        end
        result
      end

      def normalize_item_id(value)
        raw = value.is_a?(Array) ? value[0] : value
        text = raw.to_s.sub(/\A:/, "").strip
        return nil if text.empty?
        id = text.upcase.to_sym
        data = GameData::Item.try_get(id) rescue nil
        data ? data.id : nil
      rescue StandardError
        nil
      end

      def item_in_pocket?(item, pocket)
        data = GameData::Item.try_get(item) rescue nil
        data && data.pocket.to_i == pocket_index(pocket)
      rescue StandardError
        false
      end

      def normalized_item_name(item)
        item_name(item).to_s.downcase
      end

      def rank_hash(entries)
        Array(entries).each_with_index.each_with_object({}) do |(item, index), hash|
          hash[item] ||= index
        end
      end

      def mode_setting_key(pocket)
        :"#{MODE_PREFIX}#{pocket_key(pocket)}"
      end

      def default_mode_index(key)
        NATIVE_SORTED_POCKETS.include?(key) ? 0 : 1
      end

      def module_visible(owner)
        proc do |context|
          next false unless context.is_a?(Hash)
          module_id = context[:module] || context["module"]
          owner_id = context[:owner] || context["owner"]
          (module_id || owner_id).to_sym == owner
        rescue StandardError
          false
        end
      end

      def parse_imported_setting(line)
        return nil unless line.to_s =~ /\A([^=]+?)\s*=\s*(.*?)\s*\z/
        name = Regexp.last_match(1).to_s.strip
        value = Regexp.last_match(2).to_s.strip
        name_token = normalize_setting_token(name)
        case name_token
        when "autosort_new_items", "autosort_bag_enabled"
          parsed = parse_toggle_value(value)
          return parsed.nil? ? nil : [ENABLED_SETTING, parsed]
        when "always_move_recent", "autosort_bag_always_move_recent"
          index = label_index(RECENT_LABELS, value)
          return index.nil? ? nil : [RECENT_SETTING, index]
        when "manual_sort_button", "autosort_bag_manual_button"
          parsed = parse_toggle_value(value)
          return parsed.nil? ? nil : [MANUAL_SETTING, parsed]
        end

        pocket = pocket_key(name)
        return nil unless pocket
        index = label_index(MODE_LABELS, value)
        index.nil? ? nil : [mode_setting_key(pocket), index]
      rescue StandardError
        nil
      end

      def parse_toggle_value(value)
        token = normalize_setting_token(value)
        return 1 if ["on", "true", "yes", "1"].include?(token)
        return 0 if ["off", "false", "no", "0"].include?(token)
        nil
      end

      def label_index(labels, value)
        token = normalize_setting_token(value)
        Array(labels).index do |label|
          normalize_setting_token(label) == token
        end
      end

      def normalize_setting_token(value)
        value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_").
          gsub(/\A_+|_+\z/, "")
      end

      def migrate_legacy_settings
        return false if state_get(:legacy_settings_migrated, false)
        mappings = {
          :autosort_enabled => ENABLED_SETTING,
          :autosort_button_enabled => MANUAL_SETTING
        }
        imported = 0
        mappings.each do |old_key, new_key|
          value = KantoReloaded::Settings.get(old_key, nil)
          next if value.nil?
          KantoReloaded::Settings.set(new_key, value)
          imported += 1
        end
        migrated_recent = []
        POCKETS.each_value do |key|
          value = KantoReloaded::Settings.get(:"autosort_#{key}", nil)
          next if value.nil?
          mode_value = value.to_i
          if mode_value >= 3
            migrated_recent << mode_value
            mode_value = 0
          end
          KantoReloaded::Settings.set(
            mode_setting_key(key), [[mode_value, 0].max, 2].min
          )
          imported += 1
        end
        apply_migrated_recent_policy(migrated_recent)
        state_set(:legacy_settings_migrated, true)
        KantoReloaded::Log.info(
          "Autosort Bag legacy settings imported=#{imported}", :modules
        ) if defined?(KantoReloaded::Log)
        imported > 0
      end

      def migrate_removed_recent_modes
        return false if state_get(:recent_modes_migrated, false)
        migrated_recent = []
        POCKETS.each_value do |key|
          setting_key = mode_setting_key(key)
          next unless KantoReloaded::Settings.stored?(setting_key)
          value = KantoReloaded::Settings.get(setting_key, 0).to_i
          next unless value >= 3
          migrated_recent << value
          KantoReloaded::Settings.set(setting_key, 0)
        end
        apply_migrated_recent_policy(migrated_recent)
        state_set(:recent_modes_migrated, true)
        !migrated_recent.empty?
      end

      def apply_migrated_recent_policy(values)
        return false if Array(values).empty?
        return false if KantoReloaded::Settings.stored?(RECENT_SETTING)
        policy = Array(values).any? { |value| value.to_i == 4 } ? 2 : 1
        KantoReloaded::Settings.set(RECENT_SETTING, policy)
        true
      end

      def migrate_legacy_files
        return false if state_get(:legacy_files_migrated, false)
        imported = false
        list_data = read_legacy_marshal(LEGACY_LIST_FILE)
        if list_data.is_a?(Hash)
          state_set(:lists, normalize_list_hash(list_data))
          imported = true
        end
        favorite_data = read_legacy_marshal(LEGACY_FAVORITES_FILE)
        if favorite_data.is_a?(Hash)
          state_set(:favorites, normalize_favorites_hash(favorite_data))
          imported = true
        end
        state_set(:legacy_files_migrated, true)
        apply_all if imported
        KantoReloaded::Log.info(
          "Autosort Bag legacy files imported=#{imported}", :modules
        ) if defined?(KantoReloaded::Log)
        imported
      end

      def read_legacy_marshal(filename)
        path = File.join(File.dirname(KantoReloaded::ROOT), filename)
        return nil unless File.exist?(path)
        return nil if File.size(path).to_i > LEGACY_FILE_LIMIT
        data = Marshal.load(File.binread(path))
        data.is_a?(Hash) ? data : nil
      rescue StandardError => e
        log_exception("Autosort legacy #{filename} import failed", e)
        nil
      end

      def export_path
        File.join(KantoReloaded::ROOT, "Exports", EXPORT_FILE)
      end

      def ensure_export_directory
        directory = File.dirname(export_path)
        Dir.mkdir(directory) unless Dir.exist?(directory)
        Dir.exist?(directory)
      rescue StandardError
        false
      end

      def decode_text(data)
        text = data.to_s
        if text.bytes[0, 2] == [255, 254]
          text = text.byteslice(2..-1).force_encoding("UTF-16LE").encode("UTF-8")
        elsif text.bytes[0, 2] == [254, 255]
          text = text.byteslice(2..-1).force_encoding("UTF-16BE").encode("UTF-8")
        else
          text = text.sub(/\A\xEF\xBB\xBF/n, "")
          text = text.force_encoding("UTF-8")
        end
        text
      rescue StandardError
        data.to_s
      end

      def sanitize_separator_name(value)
        text = value.to_s.gsub(/[\r\n\t]/, " ").strip
        text = "SEPARATOR" if text.empty?
        text[0, 24].upcase
      end

      def current_bag
        return $PokemonBag if defined?($PokemonBag) && $PokemonBag
        return $bag if defined?($bag) && $bag
        nil
      end

      def state_get(key, fallback = nil)
        KantoReloaded::SaveData.get(
          SAVE_SYSTEM, key, fallback, section: :systems
        )
      end

      def state_set(key, value)
        KantoReloaded::SaveData.set(
          SAVE_SYSTEM, key, value, section: :systems
        )
      end

      def trainer_ready?
        defined?($Trainer) && $Trainer
      rescue StandardError
        false
      end

      def truthy_setting(key, fallback)
        truthy_value?(KantoReloaded::Settings.get(key, fallback))
      rescue StandardError
        fallback.to_i == 1
      end

      def truthy_value?(value)
        value == true ||
          (value.respond_to?(:to_i) && value.to_i == 1)
      end

      def log_exception(message, error)
        KantoReloaded::Log.exception(
          message, error, channel: :modules
        ) if defined?(KantoReloaded::Log)
      end
    end
  end
end

KantoReloaded::AutosortBag.install if defined?(KantoReloaded::AutosortBag)
