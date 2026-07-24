#==============================================================================
# Kanto Reloaded - Reloaded PC Storage Actions
#==============================================================================
# Contextual Pokemon, box, and multi-selection actions for the Reloaded PC.
#==============================================================================

module KantoReloaded
  module StorageActions
    CANCEL = :__kr_storage_cancel

    @pokemon_actions = {}
    @box_actions = {}
    @multi_actions = {}
    @accepted_confirmation_depth = 0
    @popup_bridge_depth = 0

    REVERSE_METADATA_FIELDS = [
      :exp_when_fused_body, :exp_when_fused_head,
      :head_shinyimprovpif, :body_shinyimprovpif,
      :head_shiny, :body_shiny,
      :head_shinyr, :body_shinyr,
      :head_shinyg, :body_shinyg,
      :head_shinyb, :body_shinyb,
      :head_shinyhue, :body_shinyhue,
      :head_shinykrs, :body_shinykrs
    ].freeze

    class Access
      attr_reader :scene

      def initialize(scene)
        @scene = scene
      end

      def reloaded?
        @scene.respond_to?(:kr_storage)
      end

      def storage
        return @scene.kr_storage if reloaded?
        screen = @scene.respond_to?(:screen) ? @scene.screen : nil
        return screen.storage if screen && screen.respond_to?(:storage)
        defined?($PokemonStorage) ? $PokemonStorage : nil
      end

      def storage_screen
        return @scene.kr_storage_screen if reloaded?
        @scene.respond_to?(:screen) ? @scene.screen : nil
      end

      def current_box
        storage.currentBox
      end

      def current_location
        return @scene.kr_current_location if reloaded?
        [current_box, 0]
      end

      def focused_pokemon
        return @scene.kr_focused_pokemon if reloaded?
        pokemon(current_location)
      end

      def held_pokemon
        reloaded? ? @scene.kr_held_pokemon : nil
      end

      def held_source
        reloaded? ? @scene.kr_held_source : nil
      end

      def cursor_mode
        reloaded? ? @scene.kr_cursor_mode : :default
      end

      def selected_locations
        reloaded? ? @scene.kr_selected_locations : []
      end

      def visible_box_locations
        return @scene.kr_visible_box_locations if reloaded?
        capacity = storage.maxPokemon(current_box)
        (0...capacity).map { |index| [current_box, index] }
      end

      def pokemon(location)
        return nil unless location && storage
        storage[location[0], location[1]]
      rescue StandardError
        nil
      end

      def refresh
        if reloaded?
          @scene.kr_refresh
        elsif @scene.respond_to?(:pbHardRefresh)
          @scene.pbHardRefresh
        elsif @scene.respond_to?(:pbRefresh)
          @scene.pbRefresh
        end
      rescue StandardError => e
        StorageActions.log_exception("Reloaded PC refresh failed", e)
      end

      def jump_to(location)
        return false unless location
        return @scene.kr_jump_to_location(location) if reloaded?
        box = location[0].to_i
        return false if box < 0
        storage.currentBox = box
        @scene.pbJumpToBox(box) if @scene.respond_to?(:pbJumpToBox)
        true
      rescue StandardError => e
        StorageActions.log_exception("Reloaded PC jump failed", e)
        false
      end

      def with_hidden(&block)
        return @scene.kr_with_scene_hidden(&block) if reloaded?
        yield
      end

      def clear_held
        @scene.kr_clear_held_pokemon if reloaded?
      end

      def set_held(pokemon, source = nil)
        reloaded? && @scene.kr_set_held_pokemon(pokemon, source)
      end

      def set_selected(locations)
        @scene.kr_set_selected_locations(locations) if reloaded?
      end

      def clear_selected
        @scene.kr_clear_selected_locations if reloaded?
      end

      def pick_up
        @scene.kr_pick_up_current if reloaded?
      end

      def place_or_swap
        @scene.kr_place_or_swap if reloaded?
      end

      def show_summary
        @scene.kr_show_summary if reloaded?
      end

      def pick_up_group(locations, pivot)
        @scene.kr_pick_up_group(locations, pivot) if reloaded?
      end

      def release_group(locations)
        @scene.kr_release_group(locations) if reloaded?
      end

      def begin_fusion(item)
        reloaded? && @scene.kr_begin_fusion(item)
      end

      def fusion_pending?
        reloaded? && @scene.kr_fusion_pending?
      end

      def fusion_item
        reloaded? ? @scene.kr_fusion_item : nil
      end

      def cancel_fusion
        @scene.kr_cancel_fusion if reloaded?
      end
    end

    class SceneAdapter < PokemonStorageScene
      attr_writer :progress_overlay

      def initialize(access, forced_command = nil, options = {})
        super()
        @access = access
        @storage = access.storage
        @forced_command = forced_command
        @silent = !!options[:silent]
        @scene = self
        @sprites = {}
      end

      def attach_screen(screen)
        @screen = screen
      end

      def pbShowCommands(message, commands, index = 0)
        unless @forced_command.nil?
          command = @forced_command
          @forced_command = nil
          return command
        end
        rows = Array(commands).each_with_index.map do |label, command_index|
          { :label => label.to_s, :value => command_index }
        end
        value = KantoReloaded::PopupWindow.choice(
          message.to_s, rows, :start_index => index.to_i
        )
        value.is_a?(Integer) ? value : -1
      end

      def pbDisplay(message)
        text = message.to_s
        @last_display_message = text
        if @progress_overlay &&
            KantoReloaded::StorageActions.progress_message?(text)
          @progress_overlay.pulse
          return nil
        end
        return text if KantoReloaded::StorageActions.number_prompt_message?(text)
        KantoReloaded::PopupWindow.message(text) unless @silent
        nil
      end

      def pbChooseNumber(helptext, params)
        title = helptext.to_s
        title = @last_display_message.to_s if title.empty?
        result = KantoReloaded.number_picker(
          title,
          :min => params.minNumber,
          :max => params.maxNumber,
          :initial => params.initialNumber,
          :digits => params.maxDigits
        )
        result.nil? ? params.cancelNumber : result
      end

      def pbChooseBox(message)
        StorageActions.choose_box_index(@access, message)
      end

      def pbJumpToBox(box)
        @access.jump_to([box, 0])
      end

      def pbChangeBackground(wallpaper)
        @storage.boxes[@storage.currentBox].background = wallpaper
        @access.refresh
      end

      def pbBoxName(helptext, minchars, maxchars)
        box = @storage.boxes[@storage.currentBox]
        value = nil
        @access.with_hidden do
          value = pbEnterBoxName(
            helptext, minchars, maxchars, box.name.to_s
          )
        end
        box.name = value.to_s unless value.nil? || value.to_s.empty?
        @access.refresh
      end

      def pbToggleSortBox
        box = @storage.boxes[@storage.currentBox]
        box.sortlock = !box.sortlock?
        @access.refresh
      end

      def pbToggleExportBox
        box = @storage.boxes[@storage.currentBox]
        box.exportlock = !box.exportlock?
        @access.refresh
      end

      def pbChooseItem(bag)
        result = nil
        @access.with_hidden do
          scene = PokemonBag_Scene.new
          screen = PokemonBagScreen.new(scene, bag)
          result = screen.pbChooseItemScreen(
            proc { |item| GameData::Item.get(item).can_hold? }
          )
        end
        result
      end

      def pbSetHeldPokemon(pokemon)
        @access.set_held(pokemon)
      end

      def pbHardRefresh(*_arguments)
        @access.refresh unless @silent
      end

      def pbRefresh(*_arguments)
        @access.refresh unless @silent
      end

      def pbKurayRefresh(*_arguments)
        @access.refresh unless @silent
      end

      def pbRefreshSingle(_selection)
        @access.refresh unless @silent
      end

      def pbUpdateOverlay(*_arguments); end
      def pbUpdateSelectionRect(*_arguments); end
      def pbWithdraw(*_arguments); end
      def pbStore(*_arguments); end
      def pbHold(*_arguments); end
      def pbPlace(*_arguments); end
      def pbSwap(*_arguments); end
      def pbRelease(*_arguments); end
      def pbReleaseMulti(*_arguments); end
      def pbReleaseInstant(*_arguments); end
      def setFusing(*_arguments); end
      def update; end
    end

    class << self
      def install
        return true unless defined?(KantoReloaded::Hooks)
        normal = KantoReloaded::Hooks.wrap(
          Object, :pbConfirmMessage,
          :pc_storage_confirmation_bridge, :required => false
        ) do |invocation, *arguments|
          if KantoReloaded::StorageActions.confirmation_accepted?
            true
          elsif KantoReloaded::StorageActions.popup_bridge_active?
            KantoReloaded::PopupWindow.confirm(
              arguments[0].to_s, :default => true
            )
          else
            invocation.call(*arguments)
          end
        end
        serious = KantoReloaded::Hooks.wrap(
          Object, :pbConfirmMessageSerious,
          :pc_storage_serious_confirmation_bridge, :required => false
        ) do |invocation, *arguments|
          if KantoReloaded::StorageActions.confirmation_accepted?
            true
          elsif KantoReloaded::StorageActions.popup_bridge_active?
            KantoReloaded::PopupWindow.confirm(
              arguments[0].to_s, :default => false
            )
          else
            invocation.call(*arguments)
          end
        end
        normal || serious
      rescue StandardError => e
        log_exception("Reloaded PC confirmation bridge failed", e)
        false
      end

      def confirmation_accepted?
        @accepted_confirmation_depth.to_i > 0
      end

      def popup_bridge_active?
        @popup_bridge_depth.to_i > 0
      end

      def with_confirmation_accepted
        @accepted_confirmation_depth = @accepted_confirmation_depth.to_i + 1
        yield
      ensure
        @accepted_confirmation_depth = [
          @accepted_confirmation_depth.to_i - 1, 0
        ].max
      end

      def with_popup_bridge
        @popup_bridge_depth = @popup_bridge_depth.to_i + 1
        yield
      ensure
        @popup_bridge_depth = [@popup_bridge_depth.to_i - 1, 0].max
      end

      def progress_message?(message)
        value = message.to_s.strip
        value == "..." || value =~ /\AUnfusing\b/i
      rescue StandardError
        false
      end

      def number_prompt_message?(message)
        message.to_s =~ /\(\s*-?\d+\s*-\s*-?\d+\s*\)/
      rescue StandardError
        false
      end

      def register_pokemon_action(id, options = {}, &handler)
        register_action(@pokemon_actions, id, options, &handler)
      end

      def register_box_action(id, options = {}, &handler)
        register_action(@box_actions, id, options, &handler)
      end

      def register_multi_action(id, options = {}, &handler)
        register_action(@multi_actions, id, options, &handler)
      end

      def unregister_pokemon_action(id)
        !!@pokemon_actions.delete(id.to_sym)
      end

      def unregister_box_action(id)
        !!@box_actions.delete(id.to_sym)
      end

      def unregister_multi_action(id)
        !!@multi_actions.delete(id.to_sym)
      end

      def open_context(scene)
        access = Access.new(scene)
        return open_header(access) if access.current_location[0] == :header
        return open_held_group(access) if scene.kr_held_group_count > 0
        pokemon = access.held_pokemon || access.focused_pokemon
        return false unless pokemon
        held = !access.held_pokemon.nil?
        rows = pokemon_rows(access, pokemon, held)
        choice = KantoReloaded::PopupWindow.choice(pokemon.name.to_s, rows)
        dispatch_pokemon(access, pokemon, held, choice)
      rescue StandardError => e
        log_exception("Reloaded PC Pokemon action failed", e)
        KantoReloaded.toast_error(_INTL("That PC action failed."))
        false
      end

      def open_multi(scene, pivot = nil)
        access = Access.new(scene)
        locations = access.selected_locations.select { |entry| access.pokemon(entry) }
        return false if locations.empty?
        rows = [
          row(_INTL("Move"), :move),
          row(_INTL("Deselect"), :deselect),
          row(_INTL("Release"), :release)
        ]
        rows << row(_INTL("Export"), :export) if export_allowed?
        rows.concat(custom_rows(@multi_actions, access, nil, locations))
        rows << row(_INTL("Cancel"), CANCEL)
        choice = KantoReloaded::PopupWindow.choice(
          _INTL("Selected {1} Pokemon", locations.length), rows
        )
        case choice
        when :move
          access.pick_up_group(locations, pivot || locations.first)
        when :deselect
          access.set_selected(locations.reject { |entry| entry == pivot })
        when :release
          access.release_group(locations)
        when :export
          export_locations(access, locations)
        else
          dispatch_custom(@multi_actions, choice, access, nil, locations)
        end
        true
      rescue StandardError => e
        log_exception("Reloaded PC multi action failed", e)
        KantoReloaded.toast_error(_INTL("That group action failed."))
        false
      end

      def open_header(access_or_scene)
        access = access_or_scene.is_a?(Access) ? access_or_scene : Access.new(access_or_scene)
        box = access.storage.boxes[access.current_box]
        rows = [
          row(_INTL("Choose Box"), :choose_box),
          row(_INTL("Rename Box"), :rename_box),
          row(_INTL("Wallpaper"), :wallpaper),
          row(_INTL("Sort This Box"), :sort_box),
          row(_INTL("Box Management"), :box_management)
        ]
        rows.concat(custom_rows(@box_actions, access, nil, nil))
        rows << row(_INTL("Cancel"), CANCEL)
        choice = KantoReloaded::PopupWindow.choice(box.name.to_s, rows)
        case choice
        when :choose_box then choose_box(access)
        when :rename_box then rename_box(access)
        when :wallpaper then choose_wallpaper(access)
        when :sort_box
          KantoReloaded::StorageTools.open_sort(access, :current) if defined?(KantoReloaded::StorageTools)
        when :box_management
          KantoReloaded::StorageTools.open_box_management(access.scene) if defined?(KantoReloaded::StorageTools)
        else
          dispatch_custom(@box_actions, choice, access, nil, nil)
        end
        true
      end

      def choose_box_index(access, title = nil)
        rows = access.storage.boxes.each_with_index.map do |box, index|
          count = box.respond_to?(:nitems) ? box.nitems : box.compact.length
          row(_INTL("{1} ({2}/{3})", box.name, count, box.length), index)
        end
        result = KantoReloaded::PopupWindow.choice(
          title || _INTL("Choose Box"), rows,
          :start_index => access.current_box
        )
        result.is_a?(Integer) ? result : -1
      end

      def choose_box(access)
        index = choose_box_index(access)
        access.jump_to([index, 0]) if index >= 0
        index
      end

      def rename_box(access)
        box = access.storage.boxes[access.current_box]
        value = nil
        access.with_hidden do
          value = pbEnterBoxName(
            _INTL("Box name?"), 1, 12, box.name.to_s
          )
        end
        return false if value.nil? || value.to_s.empty?
        box.name = value.to_s
        access.refresh
        KantoReloaded.toast_success(_INTL("Box renamed."))
        true
      end

      def choose_wallpaper(access)
        papers = access.storage.availableWallpapers
        current = access.storage.boxes[access.current_box].background
        start = papers[1].index(current) || 0
        rows = papers[0].each_with_index.map do |name, index|
          row(name, papers[1][index])
        end
        selected = KantoReloaded::PopupWindow.choice(
          _INTL("Choose Wallpaper"), rows, :start_index => start
        )
        return false unless selected.is_a?(Integer)
        access.storage.boxes[access.current_box].background = selected
        access.refresh
        true
      end

      def native_controller(access, forced_command = nil, options = {})
        adapter = SceneAdapter.new(access, forced_command, options)
        controller = PokemonStorageScreen.new(adapter, access.storage)
        adapter.attach_screen(controller)
        [controller, adapter]
      end

      def run_box_command(access, command_index)
        controller, = native_controller(access, command_index)
        with_popup_bridge { controller.pbBoxCommands }
        access.refresh
        true
      rescue StandardError => e
        log_exception("KIF box command failed", e)
        KantoReloaded.toast_error(_INTL("That KIF tool failed."))
        false
      end

      def export_allowed?
        return true if defined?($DEBUG) && $DEBUG
        return true unless defined?($PokemonSystem) && $PokemonSystem
        !$PokemonSystem.respond_to?(:debugfeature) ||
          $PokemonSystem.debugfeature.to_i != 1
      rescue StandardError
        false
      end

      def all_locations(storage, include_party = true)
        locations = []
        if include_party
          storage.party.each_index { |index| locations << [-1, index] }
        end
        (0...storage.maxBoxes).each do |box|
          (0...storage.maxPokemon(box)).each do |index|
            locations << [box, index] if storage[box, index]
          end
        end
        locations
      end

      def location_label(access, location)
        return _INTL("Party Slot {1}", location[1] + 1) if location[0] == -1
        box = access.storage.boxes[location[0]]
        _INTL("{1}, Slot {2}", box.name, location[1] + 1)
      end

      def log_exception(message, error)
        KantoReloaded::Log.exception(
          message, error, :channel => :pc_organization
        ) if defined?(KantoReloaded::Log)
      end

      def complete_held_fusion(scene)
        access = Access.new(scene)
        return false unless access.fusion_pending?
        pokemon = access.held_pokemon
        target = access.focused_pokemon
        target_location = access.current_location
        unless valid_fusion_target?(pokemon, target, target_location)
          pbPlayBuzzerSE rescue nil
          return false
        end
        item = access.fusion_item
        return missing_splicer_warning unless splicer_owned?(item)
        selected_head = nil
        access.with_hidden do
          selected_head = selectFusion(
            target, pokemon, super_splicer?(item)
          )
        end
        return false if selected_head.nil? || selected_head == -1
        selected_base = selected_head.equal?(target) ? pokemon : target
        return false unless KantoReloaded::PopupWindow.confirm(
          _INTL("Fuse the two Pokemon?")
        )
        playing_bgm = $game_system.getPlayingBGM rescue nil
        result = access.with_hidden do
          pbFuse(selected_head, selected_base, item)
        end
        return false unless result
        access.storage[target_location[0], target_location[1]] = selected_head
        access.clear_held
        $PokemonBag.pbDeleteItem(item) if finite_splicer?(item)
        pbBGMPlay(playing_bgm) if playing_bgm
        access.refresh
        KantoReloaded.toast_success(_INTL("The Pokemon were fused."))
        true
      rescue StandardError => e
        log_exception("Reloaded PC held fusion failed", e)
        return missing_splicer_warning unless splicer_owned?(item)
        warning(_INTL("The fusion could not be completed."))
      end

      private

      def register_action(registry, id, options, &handler)
        raise ArgumentError, "Storage action handler is required" unless handler
        data = options.is_a?(Hash) ? options.dup : {}
        label = data[:label].to_s.strip
        raise ArgumentError, "Storage action label is required" if label.empty?
        key = id.to_sym
        registry[key] = {
          :id => key,
          :label => label,
          :priority => data.fetch(:priority, 100).to_i,
          :enabled => data[:enabled],
          :handler => handler
        }
        true
      end

      def row(label, value, enabled = true)
        { :label => label, :value => value, :enabled => enabled }
      end

      def custom_rows(registry, access, pokemon, locations)
        registry.values.sort_by { |entry| [entry[:priority], entry[:label]] }.map do |entry|
          enabled = custom_enabled?(entry, access, pokemon, locations)
          row(entry[:label], entry[:id], enabled)
        end
      end

      def custom_enabled?(entry, access, pokemon, locations)
        predicate = entry[:enabled]
        return true unless predicate.respond_to?(:call)
        predicate.call(access.scene, pokemon, locations) != false
      rescue StandardError => e
        log_exception("Storage action availability failed", e)
        false
      end

      def dispatch_custom(registry, id, access, pokemon, locations)
        entry = registry[id]
        return false unless entry && custom_enabled?(entry, access, pokemon, locations)
        entry[:handler].call(access.scene, pokemon, locations)
        true
      end

      def pokemon_rows(access, pokemon, held)
        if held && access.fusion_pending?
          return [
            row(_INTL("Cancel Fusion"), :cancel_fusion),
            row(_INTL("Summary"), :summary),
            row(_INTL("Cancel"), CANCEL)
          ]
        end
        location = held ? access.held_source : access.current_location
        rows = []
        rows << row(access.focused_pokemon ? _INTL("Swap") : _INTL("Place"), :place) if held
        rows << row(_INTL("Move"), :move) unless held
        rows << row(_INTL("Summary"), :summary)
        if location
          rows << row(location[0] == -1 ? _INTL("Store") : _INTL("Withdraw"), :transfer)
        end
        rows << row(_INTL("Item"), :item)
        rows << row(_INTL("Mark"), :mark)
        rows << row(_INTL("Nickname"), :nickname)
        rows << row(_INTL("Fusion"), :fusion)
        rows << row(_INTL("Kuray Actions"), :kuray_actions)
        rows << row(_INTL("Release"), :release)
        rows << row(_INTL("Debug"), :debug) if defined?($DEBUG) && $DEBUG
        rows.concat(custom_rows(@pokemon_actions, access, pokemon, nil))
        rows << row(_INTL("Cancel"), CANCEL)
        rows
      end

      def dispatch_pokemon(access, pokemon, held, choice)
        location = held ? access.held_source : access.current_location
        case choice
        when :place then access.place_or_swap
        when :cancel_fusion then access.cancel_fusion
        when :move then access.pick_up
        when :summary then access.show_summary
        when :transfer
          location && location[0] == -1 ? store(access, pokemon, location, held) :
            withdraw(access, pokemon, location, held)
        when :item then change_item(access, pokemon)
        when :mark then edit_markings(access, pokemon)
        when :nickname then rename_pokemon(access, pokemon)
        when :fusion then open_fusion(access, pokemon, location, held)
        when :kuray_actions then run_kuray_actions(access, pokemon, location, held)
        when :release then release(access, pokemon, location, held)
        when :debug then run_debug(access, pokemon, location, held)
        else
          dispatch_custom(@pokemon_actions, choice, access, pokemon, nil)
        end
      end

      def open_held_group(access)
        count = access.scene.kr_held_group_count
        rows = [row(_INTL("Place"), :place), row(_INTL("Cancel"), CANCEL)]
        choice = KantoReloaded::PopupWindow.choice(
          _INTL("{1} Pokemon selected", count), rows
        )
        access.scene.kr_place_held_group if choice == :place
        true
      end

      def store(access, pokemon, location, held)
        return warning(_INTL("Please remove the Mail.")) if has_mail?(pokemon)
        if able?(pokemon) && party_able_count(access.storage) <= (held ? 0 : 1)
          return warning(_INTL("That's your last Pokemon!"))
        end
        box = choose_box_index(access, _INTL("Deposit in which Box?"))
        return false if box < 0
        index = access.storage.pbFirstFreePos(box)
        return warning(_INTL("That Box is full.")) if index < 0
        prepare_for_box(pokemon)
        access.storage[box, index] = pokemon
        held ? access.clear_held : access.storage.pbDelete(location[0], location[1])
        access.refresh
        KantoReloaded.toast_success(_INTL("{1} was stored.", pokemon.name))
        true
      end

      def withdraw(access, pokemon, location, held)
        if access.storage.party_full?
          return warning(_INTL("Your party is full!")) unless access.reloaded?
          unless held
            return false unless access.set_held(pokemon, location)
            access.storage.pbDelete(location[0], location[1])
          end
          access.jump_to([-1, 0])
          KantoReloaded.toast_warning(
            _INTL("Party full. Choose a Pokemon to swap.")
          )
          return true
        end
        access.storage.party << pokemon
        held ? access.clear_held : access.storage.pbDelete(location[0], location[1])
        access.storage.party.compact!
        access.refresh
        KantoReloaded.toast_success(_INTL("{1} joined your party.", pokemon.name))
        true
      end

      def change_item(access, pokemon)
        return warning(_INTL("Eggs can't hold items.")) if pokemon.egg?
        return warning(_INTL("Please remove the Mail.")) if has_mail?(pokemon)
        if pokemon.item
          item = pokemon.item
          return false unless KantoReloaded::PopupWindow.confirm(
            _INTL("Take the {1}?", item.name)
          )
          return warning(_INTL("The Bag is full.")) unless $PokemonBag.pbStoreItem(item)
          pokemon.item = nil
          access.refresh
          KantoReloaded.toast_success(_INTL("Took the {1}.", item.name))
          return true
        end
        _controller, adapter = native_controller(access)
        item_id = adapter.pbChooseItem($PokemonBag)
        return false unless item_id
        item = GameData::Item.get(item_id)
        pokemon.item = item_id
        $PokemonBag.pbDeleteItem(item_id)
        access.refresh
        KantoReloaded.toast_success(_INTL("{1} is now holding {2}.", pokemon.name, item.name))
        true
      end

      def edit_markings(access, pokemon)
        original = pokemon.markings.to_i
        markings = original
        loop do
          rows = (0...6).map do |index|
            active = (markings & (1 << index)) != 0
            row(_INTL("Mark {1}: {2}", index + 1, active ? "On" : "Off"), index)
          end
          rows << row(_INTL("Save"), :save)
          rows << row(_INTL("Cancel"), CANCEL)
          choice = KantoReloaded::PopupWindow.choice(_INTL("Pokemon Markings"), rows)
          if choice.is_a?(Integer)
            markings ^= (1 << choice)
          elsif choice == :save
            pokemon.markings = markings
            access.refresh
            KantoReloaded.toast_success(_INTL("Markings updated."))
            return true
          else
            pokemon.markings = original
            return false
          end
        end
      end

      def rename_pokemon(access, pokemon)
        return warning(_INTL("You cannot rename an Egg.")) if pokemon.egg?
        species_name = pokemon.species_data.name.to_s
        value = nil
        access.with_hidden do
          value = pbEnterPokemonName(
            _INTL("{1}'s nickname?", species_name), 0,
            Pokemon::MAX_NAME_SIZE, pokemon.name.to_s, pokemon
          )
        end
        return false if value.nil?
        pokemon.name = value.to_s.empty? ? species_name : value.to_s
        access.refresh
        KantoReloaded.toast_success(_INTL("Pokemon renamed to {1}.", pokemon.name))
        true
      end

      def release(access, pokemon, location, held)
        return warning(_INTL("Rental Pokemon cannot be released.")) if rental?(pokemon)
        return warning(_INTL("Eggs cannot be released.")) if pokemon.egg?
        return warning(_INTL("Please remove the Mail.")) if has_mail?(pokemon)
        if location && location[0] == -1 && able?(pokemon) &&
            party_able_count(access.storage) <= (held ? 0 : 1)
          return warning(_INTL("That's your last Pokemon!"))
        end
        return false unless KantoReloaded::PopupWindow.confirm(
          _INTL("Release {1}?", pokemon.name), :serious => true
        )
        held ? access.clear_held : access.storage.pbDelete(location[0], location[1])
        access.refresh
        KantoReloaded.toast_success(_INTL("{1} was released.", pokemon.name))
        true
      end

      def open_fusion(access, pokemon, location, held)
        if fused?(pokemon)
          rows = [row(_INTL("Unfuse"), :unfuse)]
          rows << row(_INTL("Reverse"), :reverse)
          rows << row(_INTL("Cancel"), CANCEL)
          choice = KantoReloaded::PopupWindow.choice(_INTL("Fusion"), rows)
          return unfuse(access, pokemon, location) if choice == :unfuse
          return reverse(access, pokemon) if choice == :reverse
          return false
        end
        fuse(access, pokemon, location, held)
      end

      def fuse(access, pokemon, location, held)
        return warning(_INTL("It's impossible to fuse an Egg!")) if pokemon.egg?
        candidates = all_locations(access.storage).any? do |candidate_location|
          candidate = access.pokemon(candidate_location)
          valid_fusion_target?(pokemon, candidate, candidate_location)
        end
        return warning(_INTL("No other Pokemon can be fused.")) unless candidates
        item = choose_splicer
        return false unless item
        access.pick_up unless held
        return false unless access.held_pokemon.equal?(pokemon)
        return false unless access.begin_fusion(item)
        KantoReloaded.toast(
          _INTL("Select another Pokemon to fuse with {1}.", pokemon.name)
        )
        true
      rescue StandardError => e
        log_exception("Reloaded PC fusion failed", e)
        return missing_splicer_warning unless any_splicer_available?
        warning(_INTL("The fusion could not be completed."))
      end

      def unfuse(access, pokemon, location)
        item = choose_splicer
        return false unless item
        return false unless KantoReloaded::PopupWindow.confirm(
          _INTL("Unfuse {1}?", pokemon.name)
        )
        _controller, adapter = native_controller(access)
        result = KantoReloaded::PopupWindow.progress(
          _INTL("Unfusing {1}", pokemon.name), :show_dim => true
        ) do |progress|
          adapter.progress_overlay = progress
          with_confirmation_accepted do
            pbUnfuse(pokemon, adapter, super_splicer?(item), location)
          end
        end
        $PokemonBag.pbDeleteItem(item) if result && finite_splicer?(item)
        access.refresh
        result
      rescue StandardError => e
        log_exception("Reloaded PC unfusion failed", e)
        return missing_splicer_warning unless splicer_owned?(item)
        warning(_INTL("The Pokemon could not be unfused."))
      end

      def reverse(access, pokemon)
        return warning(_INTL("You have no DNA Reverser.")) unless reverser_available?
        return false unless KantoReloaded::PopupWindow.confirm(
          _INTL("Reverse {1}?", pokemon.name)
        )
        original_species = pokemon.species
        metadata = reverse_metadata_snapshot(pokemon)
        begin
          with_native_reverse_scene do
            access.with_hidden { reverseFusion(pokemon) }
          end
        rescue StandardError
          restore_reverse_metadata(pokemon, metadata) if
            pokemon.species == original_species
          raise
        end
        if $PokemonBag.pbQuantity(:INFINITEREVERSERS) <= 0
          $PokemonBag.pbDeleteItem(:DNAREVERSER)
        end
        access.refresh
        KantoReloaded.toast_success(_INTL("{1} was reversed.", pokemon.name))
        true
      rescue StandardError => e
        log_exception("Reloaded PC reverse fusion failed", e)
        return missing_reverser_warning unless reverser_available?
        warning(_INTL("The fusion could not be reversed."))
      end

      def with_native_reverse_scene
        system = defined?($PokemonSystem) ? $PokemonSystem : nil
        previous = nil
        changed = false
        if defined?(::EBDXToggle) && ::EBDXToggle.enabled? && system &&
            system.respond_to?(:mp_ebdx_enabled) &&
            system.respond_to?(:mp_ebdx_enabled=)
          previous = system.mp_ebdx_enabled
          system.mp_ebdx_enabled = 0
          changed = true
        end
        yield
      ensure
        system.mp_ebdx_enabled = previous if changed && system
      end

      def reverse_metadata_snapshot(pokemon)
        REVERSE_METADATA_FIELDS.each_with_object({}) do |field, result|
          next unless pokemon.respond_to?(field)
          value = pokemon.__send__(field)
          result[field] = value.clone rescue value
        end
      end

      def restore_reverse_metadata(pokemon, metadata)
        metadata.each do |field, value|
          setter = :"#{field}="
          pokemon.__send__(setter, value) if pokemon.respond_to?(setter)
        end
      rescue StandardError => e
        log_exception("Reloaded PC reverse metadata rollback failed", e)
      end

      def run_kuray_actions(access, pokemon, location, held)
        controller, = native_controller(access)
        selected = location || access.current_location
        with_popup_bridge do
          controller.pbKurayAct(selected, held ? pokemon : nil)
        end
        access.refresh
        true
      end

      def run_debug(access, pokemon, location, held)
        return false unless defined?($DEBUG) && $DEBUG
        controller, = native_controller(access)
        with_popup_bridge do
          controller.pbPokemonDebug(
            pokemon, location || access.current_location, held ? pokemon : nil
          )
        end
        access.refresh
        true
      end

      def export_locations(access, locations)
        return warning(_INTL("Exporting is disabled.")) unless export_allowed?
        _controller, adapter = native_controller(access, nil, :silent => true)
        ordered = locations.sort_by { |location| [location[0], -location[1]] }
        ordered.each do |location|
          next unless access.pokemon(location)
          adapter.pbExport(location, nil, 0)
        end
        access.clear_selected
        access.refresh
        KantoReloaded.toast_success(_INTL("Pokemon exported."))
        true
      rescue StandardError => e
        log_exception("Reloaded PC export failed", e)
        warning(_INTL("The Pokemon could not be exported."))
      end

      def choose_splicer
        entries = []
        infinite2 = $PokemonBag.pbQuantity(:INFINITESPLICERS2)
        infinite = $PokemonBag.pbQuantity(:INFINITESPLICERS)
        super_count = $PokemonBag.pbQuantity(:SUPERSPLICERS)
        dna_count = $PokemonBag.pbQuantity(:DNASPLICERS)
        if infinite2 > 0 || infinite > 0
          item = infinite2 > 0 ? :INFINITESPLICERS2 : :INFINITESPLICERS
          entries << row(_INTL("Infinite Splicers"), item)
        end
        entries << row(_INTL("Super Splicers ({1})", super_count), :SUPERSPLICERS) if super_count > 0
        entries << row(_INTL("DNA Splicers ({1})", dna_count), :DNASPLICERS) if dna_count > 0
        return missing_splicer_warning if entries.empty?
        entries << row(_INTL("Cancel"), CANCEL)
        value = KantoReloaded::PopupWindow.choice(_INTL("Use which splicers?"), entries)
        value == CANCEL ? nil : value
      end

      def valid_fusion_target?(pokemon, target, location)
        return false unless pokemon && target && location.is_a?(Array)
        return false if location[0] == :header || target.equal?(pokemon)
        return false if target.egg? || fused?(target)
        true
      rescue StandardError
        false
      end

      def super_splicer?(item)
        item == :SUPERSPLICERS || item == :INFINITESPLICERS2
      end

      def finite_splicer?(item)
        item == :SUPERSPLICERS || item == :DNASPLICERS
      end

      def splicer_owned?(item)
        return false unless item
        $PokemonBag.pbQuantity(item) > 0
      rescue StandardError
        false
      end

      def any_splicer_available?
        [:INFINITESPLICERS2, :INFINITESPLICERS,
         :SUPERSPLICERS, :DNASPLICERS].any? do |item|
          splicer_owned?(item)
        end
      end

      def missing_splicer_warning
        warning(_INTL("You have no DNA Splicers or other splicers."))
      end

      def missing_reverser_warning
        warning(_INTL("You have no DNA Reverser."))
      end

      def reverser_available?
        $PokemonBag.pbQuantity(:DNAREVERSER) > 0 ||
          $PokemonBag.pbQuantity(:INFINITEREVERSERS) > 0
      rescue StandardError
        false
      end

      def fused?(pokemon)
        return pokemon.isFusion? if pokemon.respond_to?(:isFusion?)
        pokemon.species_data.id_number.to_i > NB_POKEMON
      rescue StandardError
        false
      end

      def prepare_for_box(pokemon)
        pokemon.time_form_set = nil if pokemon.respond_to?(:time_form_set=)
        if pokemon.respond_to?(:isSpecies?) && pokemon.isSpecies?(:SHAYMIN) &&
            pokemon.respond_to?(:form=)
          pokemon.form = 0
        end
        pokemon.heal if (!defined?($game_temp) || !$game_temp ||
          !$game_temp.respond_to?(:fromkurayshop) || !$game_temp.fromkurayshop)
      end

      def has_mail?(pokemon)
        pokemon.respond_to?(:mail) && pokemon.mail
      rescue StandardError
        false
      end

      def rental?(pokemon)
        pokemon.owner.name.to_s == "RENTAL"
      rescue StandardError
        false
      end

      def able?(pokemon)
        pokemon && !pokemon.egg? && pokemon.hp.to_i > 0
      rescue StandardError
        false
      end

      def party_able_count(storage)
        storage.party.count { |entry| able?(entry) }
      end

      def warning(message)
        pbPlayBuzzerSE rescue nil
        KantoReloaded.toast_warning(message)
        false
      end

      public :export_locations
    end
  end
end

KantoReloaded::StorageActions.install if defined?(KantoReloaded::StorageActions)

module KantoReloaded
  module PCOrganization
    class << self
      def register_pokemon_action(id, options = {}, &handler)
        KantoReloaded::StorageActions.register_pokemon_action(id, options, &handler)
      end

      def register_box_action(id, options = {}, &handler)
        KantoReloaded::StorageActions.register_box_action(id, options, &handler)
      end

      def register_multi_action(id, options = {}, &handler)
        KantoReloaded::StorageActions.register_multi_action(id, options, &handler)
      end

      def unregister_pokemon_action(id)
        KantoReloaded::StorageActions.unregister_pokemon_action(id)
      end

      def unregister_box_action(id)
        KantoReloaded::StorageActions.unregister_box_action(id)
      end

      def unregister_multi_action(id)
        KantoReloaded::StorageActions.unregister_multi_action(id)
      end
    end
  end
end
