#==============================================================================
# Kanto Reloaded - Reloaded PC Storage Tools
#==============================================================================
# Storage-wide tools opened from the Reloaded PC Input Z menu.
#==============================================================================

module KantoReloaded
  module StorageTools
    CANCEL = :__kr_storage_tools_cancel
    ANY = :__kr_storage_any

    SORT_FIELDS = [
      [:species_name, "Species Name"],
      [:nickname, "Nickname"],
      [:dex_number, "Pokedex Number"],
      [:level, "Level"],
      [:total_hp, "Current HP Stat"],
      [:attack, "Current Attack Stat"],
      [:defense, "Current Defense Stat"],
      [:special_attack, "Current Sp. Atk Stat"],
      [:special_defense, "Current Sp. Def Stat"],
      [:speed, "Current Speed Stat"],
      [:bst, "Base Stat Total (BST)"],
      [:base_hp, "Base HP"],
      [:base_attack, "Base Attack"],
      [:base_defense, "Base Defense"],
      [:base_special_attack, "Base Sp. Atk"],
      [:base_special_defense, "Base Sp. Def"],
      [:base_speed, "Base Speed"],
      [:caught_date, "Caught Date"],
      [:shiny, "Shiny"],
      [:ot, "Original Trainer"],
      [:gender, "Gender"],
      [:ability, "Ability"],
      [:nature, "Nature"],
      [:held_item, "Held Item"],
      [:type_1, "First Type"],
      [:type_2, "Second Type"],
      [:caught_map, "Caught Map"],
      [:happiness, "Happiness"],
      [:experience, "Experience"],
      [:markings, "Markings"],
      [:total_ivs, "Total IVs"],
      [:total_evs, "Total EVs"],
      [:hatch_steps, "Egg Hatch Progress"],
      [:fusion, "Fusion Status"],
      [:form, "Species Form"]
    ].freeze

    class << self
      def install
        return false unless defined?(KantoReloaded::PCOrganization)
        KantoReloaded::PCOrganization.register_menu_command(
          :find_pokemon, :label => _INTL("Find Pokemon"), :priority => 10
        ) { |scene| open_find(scene) }
        KantoReloaded::PCOrganization.register_menu_command(
          :sort_organize, :label => _INTL("Sort & Organize"), :priority => 20
        ) { |scene| open_sort_organize(scene) }
        KantoReloaded::PCOrganization.register_menu_command(
          :box_management, :label => _INTL("Box Management"), :priority => 30
        ) { |scene| open_box_management(scene) }
        KantoReloaded::PCOrganization.register_menu_command(
          :selection_tools, {
            :label => _INTL("Selection Tools"),
            :priority => 40,
            :enabled => proc { |scene| selection_tools_available?(scene) }
          }
        ) { |scene| open_selection_tools(scene) }
        KantoReloaded::PCOrganization.register_menu_command(
          :kif_tools, :label => _INTL("KIF Tools"), :priority => 50
        ) { |scene| open_kif_tools(scene) }
        true
      rescue StandardError => e
        log_exception("Reloaded PC tools install failed", e)
        false
      end

      def open_find(scene)
        access = access_for(scene)
        criteria = default_criteria
        loop do
          choice = KantoReloaded::PopupWindow.choice(
            _INTL("Find Pokemon"), find_rows(access, criteria)
          )
          case choice
          when :name then criteria[:name] = enter_text(access, _INTL("Name or species"), criteria[:name])
          when :type then criteria[:type] = choose_type(access, criteria[:type])
          when :level then choose_level_range(criteria)
          when :shiny then criteria[:shiny] = choose_three_state(_INTL("Shiny"), criteria[:shiny])
          when :egg then criteria[:egg] = choose_three_state(_INTL("Egg"), criteria[:egg])
          when :fusion then criteria[:fusion] = choose_three_state(_INTL("Fusion"), criteria[:fusion])
          when :item then criteria[:item] = choose_held_item(access, criteria[:item])
          when :ability then criteria[:ability] = enter_text(access, _INTL("Ability name"), criteria[:ability])
          when :move then criteria[:move] = enter_text(access, _INTL("Move name"), criteria[:move])
          when :ot then criteria[:ot] = enter_text(access, _INTL("Original Trainer"), criteria[:ot])
          when :marking then criteria[:marking] = choose_marking(criteria[:marking])
          when :location then criteria[:location] = choose_location(access, criteria[:location])
          when :search then break if show_results(access, criteria)
          when :reset then criteria = default_criteria
          else break
          end
        end
        true
      rescue StandardError => e
        log_exception("Reloaded PC search failed", e)
        warning(_INTL("Pokemon search failed."))
      end

      def open_sort_organize(scene)
        access = access_for(scene)
        loop do
          rows = [
            row(_INTL("Sort Pokemon"), :sort),
            row(_INTL("Compact Current Box"), :compact_current),
            row(_INTL("Compact All Unlocked Boxes"), :compact_all),
            row(_INTL("Back"), CANCEL)
          ]
          case KantoReloaded::PopupWindow.choice(_INTL("Sort & Organize"), rows)
          when :sort then open_sort(access)
          when :compact_current then compact(access, :current)
          when :compact_all then compact(access, :all)
          else break
          end
        end
        true
      end

      def open_sort(access_or_scene, preset_scope = nil)
        access = access_or_scene.is_a?(KantoReloaded::StorageActions::Access) ?
          access_or_scene : access_for(access_or_scene)
        rows = SORT_FIELDS.map { |id, label| row(_INTL(label), id) }
        rows << row(_INTL("Cancel"), CANCEL)
        field = KantoReloaded::PopupWindow.choice(_INTL("Sort Pokemon By"), rows)
        return false if field == CANCEL || field.nil?
        scope = preset_scope || choose_sort_scope(access)
        return false unless scope
        direction = KantoReloaded::PopupWindow.choice(
          _INTL("Sort Order"), [
            row(_INTL("Ascending"), :ascending),
            row(_INTL("Descending"), :descending),
            row(_INTL("Cancel"), CANCEL)
          ]
        )
        return false if direction == CANCEL || direction.nil?
        label = SORT_FIELDS.assoc(field)
        return false unless KantoReloaded::PopupWindow.confirm(
          _INTL("Sort by {1}?", label ? label[1] : field.to_s)
        )
        apply_sort(access, field, scope, direction)
      rescue StandardError => e
        log_exception("Reloaded PC sort failed", e)
        warning(_INTL("The Pokemon could not be sorted."))
      end

      def open_box_management(scene)
        access = access_for(scene)
        loop do
          box = access.storage.boxes[access.current_box]
          rows = [
            row(_INTL("Choose Box"), :choose),
            row(_INTL("Storage Overview"), :overview),
            row(_INTL("Rename Box"), :rename),
            row(_INTL("Wallpaper"), :wallpaper),
            row(_INTL("Buy Box"), :buy),
            row(box.sortlock? ? _INTL("Unlock Sorting") : _INTL("Lock Sorting"), :sort_lock),
            row(box.exportlock? ? _INTL("Unlock Exporting") : _INTL("Lock Exporting"), :export_lock),
            row(_INTL("Back"), CANCEL)
          ]
          choice = KantoReloaded::PopupWindow.choice(box.name.to_s, rows)
          case choice
          when :choose then KantoReloaded::StorageActions.choose_box(access)
          when :overview then storage_overview(access)
          when :rename then KantoReloaded::StorageActions.rename_box(access)
          when :wallpaper then KantoReloaded::StorageActions.choose_wallpaper(access)
          when :buy then KantoReloaded::StorageActions.run_box_command(access, 5)
          when :sort_lock then KantoReloaded::StorageActions.run_box_command(access, 3)
          when :export_lock then KantoReloaded::StorageActions.run_box_command(access, 4)
          else break
          end
        end
        true
      rescue StandardError => e
        log_exception("Reloaded PC box management failed", e)
        warning(_INTL("Box Management failed."))
      end

      def open_selection_tools(scene)
        access = access_for(scene)
        return warning(_INTL("Multi Select mode is required.")) unless selection_tools_available?(scene)
        loop do
          selected = access.selected_locations
          rows = [
            row(_INTL("Select All Visible"), :visible),
            row(_INTL("Select Entire Box"), :all),
            row(_INTL("Invert Selection"), :invert),
            row(_INTL("Clear Selection"), :clear),
            row(_INTL("Move Selected ({1})", selected.length), :move, !selected.empty?),
            row(_INTL("Sort Selected ({1})", selected.length), :sort, selected.length > 1),
            row(_INTL("Release Selected ({1})", selected.length), :release, !selected.empty?),
            row(_INTL("Export Selected ({1})", selected.length), :export,
                !selected.empty? && KantoReloaded::StorageActions.export_allowed?),
            row(_INTL("Back"), CANCEL)
          ]
          choice = KantoReloaded::PopupWindow.choice(_INTL("Selection Tools"), rows)
          case choice
          when :visible
            locations = access.visible_box_locations.select { |entry| access.pokemon(entry) }
            access.set_selected(locations)
          when :all
            locations = current_box_locations(access).select { |entry| access.pokemon(entry) }
            access.set_selected(locations)
          when :invert
            occupied = current_box_locations(access).select { |entry| access.pokemon(entry) }
            access.set_selected(occupied.reject { |entry| selected.include?(entry) })
          when :clear
            access.clear_selected
          when :move
            access.pick_up_group(selected, selected.first)
            break
          when :sort
            open_sort(access, :selected)
          when :release
            access.clear_selected if access.release_group(selected)
            break
          when :export
            KantoReloaded::StorageActions.export_locations(access, selected)
            break
          else break
          end
        end
        true
      rescue StandardError => e
        log_exception("Reloaded PC selection tools failed", e)
        warning(_INTL("Selection Tools failed."))
      end

      def open_kif_tools(scene)
        access = access_for(scene)
        allowed = KantoReloaded::StorageActions.export_allowed?
        rows = []
        if allowed
          rows.concat([
            row(_INTL("Export Current Box"), :export_box),
            row(_INTL("Export All"), :export_all),
            row(_INTL("Import"), :import),
            row(_INTL("Import Randomly"), :import_random)
          ])
        end
        rows << row(_INTL("Back"), CANCEL)
        choice = KantoReloaded::PopupWindow.choice(_INTL("KIF Tools"), rows)
        case choice
        when :export_box then KantoReloaded::StorageActions.run_box_command(access, 9)
        when :export_all then KantoReloaded::StorageActions.run_box_command(access, 10)
        when :import then KantoReloaded::StorageActions.run_box_command(access, 11)
        when :import_random then KantoReloaded::StorageActions.run_box_command(access, 12)
        end
        true
      rescue StandardError => e
        log_exception("Reloaded PC KIF tools failed", e)
        warning(_INTL("That KIF tool failed."))
      end

      def selection_tools_available?(scene)
        scene.respond_to?(:kr_cursor_mode) && scene.kr_cursor_mode == :multiselect
      rescue StandardError
        false
      end

      private

      def access_for(scene)
        KantoReloaded::StorageActions::Access.new(scene)
      end

      def row(label, value, enabled = true)
        { :label => label, :value => value, :enabled => enabled }
      end

      def default_criteria
        {
          :name => "", :type => ANY, :min_level => nil, :max_level => nil,
          :shiny => ANY, :egg => ANY, :fusion => ANY, :item => ANY,
          :ability => "", :move => "", :ot => "", :marking => ANY,
          :location => :all
        }
      end

      def find_rows(access, criteria)
        [
          row(_INTL("Name: {1}", text_value(criteria[:name])), :name),
          row(_INTL("Type: {1}", type_label(criteria[:type])), :type),
          row(_INTL("Level: {1}", level_label(criteria)), :level),
          row(_INTL("Shiny: {1}", state_label(criteria[:shiny])), :shiny),
          row(_INTL("Egg: {1}", state_label(criteria[:egg])), :egg),
          row(_INTL("Fusion: {1}", state_label(criteria[:fusion])), :fusion),
          row(_INTL("Held Item: {1}", item_label(criteria[:item])), :item),
          row(_INTL("Ability: {1}", text_value(criteria[:ability])), :ability),
          row(_INTL("Move: {1}", text_value(criteria[:move])), :move),
          row(_INTL("OT: {1}", text_value(criteria[:ot])), :ot),
          row(_INTL("Marking: {1}", marking_label(criteria[:marking])), :marking),
          row(_INTL("Location: {1}", location_filter_label(access, criteria[:location])), :location),
          row(_INTL("Search"), :search),
          row(_INTL("Reset Filters"), :reset),
          row(_INTL("Back"), CANCEL)
        ]
      end

      def enter_text(access, title, initial)
        value = nil
        access.with_hidden do
          value = pbEnterText(title, 0, 32, initial.to_s)
        end
        value.nil? ? initial.to_s : value.to_s.strip
      end

      def choose_type(access, current)
        ids = storage_entries(access).map do |_location, pokemon|
          next if pokemon.egg?
          pokemon_types(pokemon)
        end.flatten.compact.uniq
        rows = [row(_INTL("Any"), ANY)]
        ids.sort_by { |id| type_name(id) }.each do |id|
          rows << row(type_name(id), id)
        end
        rows << row(_INTL("Cancel"), CANCEL)
        start_index = current == ANY ? 0 : (ids.index(current).to_i + 1)
        value = KantoReloaded::PopupWindow.choice(
          _INTL("Filter by Type"), rows, :start_index => start_index
        )
        value == CANCEL || value.nil? ? current : value
      end

      def choose_level_range(criteria)
        choice = KantoReloaded::PopupWindow.choice(
          _INTL("Level Filter"), [
            row(_INTL("Any Level"), :any),
            row(_INTL("Exact Level"), :exact),
            row(_INTL("Level Range"), :range),
            row(_INTL("Cancel"), CANCEL)
          ]
        )
        if choice == :any
          criteria[:min_level] = nil
          criteria[:max_level] = nil
        elsif choice == :exact
          value = KantoReloaded.number_picker(
            _INTL("Exact Level"), :min => 1, :max => max_level,
            :initial => criteria[:min_level] || 1, :digits => 3
          )
          criteria[:min_level] = value
          criteria[:max_level] = value
        elsif choice == :range
          minimum = KantoReloaded.number_picker(
            _INTL("Minimum Level"), :min => 1, :max => max_level,
            :initial => criteria[:min_level] || 1, :digits => 3
          )
          return unless minimum
          maximum = KantoReloaded.number_picker(
            _INTL("Maximum Level"), :min => minimum, :max => max_level,
            :initial => [criteria[:max_level] || max_level, minimum].max,
            :digits => 3
          )
          return unless maximum
          criteria[:min_level] = minimum
          criteria[:max_level] = maximum
        end
      end

      def choose_three_state(title, current)
        rows = [
          row(_INTL("Any"), ANY), row(_INTL("Yes"), true),
          row(_INTL("No"), false), row(_INTL("Cancel"), CANCEL)
        ]
        value = KantoReloaded::PopupWindow.choice(title, rows)
        value == CANCEL || value.nil? ? current : value
      end

      def choose_held_item(access, current)
        items = storage_entries(access).map do |_location, pokemon|
          pokemon.item && pokemon.item.id
        rescue StandardError
          nil
        end.compact.uniq
        rows = [row(_INTL("Any"), ANY), row(_INTL("No Held Item"), :none)]
        items.sort_by { |id| item_name(id) }.each do |id|
          rows << row(item_name(id), id)
        end
        rows << row(_INTL("Cancel"), CANCEL)
        value = KantoReloaded::PopupWindow.choice(_INTL("Filter by Held Item"), rows)
        value == CANCEL || value.nil? ? current : value
      end

      def choose_marking(current)
        rows = [row(_INTL("Any"), ANY), row(_INTL("Any Mark"), :marked),
                row(_INTL("No Marks"), :unmarked)]
        (0...6).each { |index| rows << row(_INTL("Mark {1}", index + 1), index) }
        rows << row(_INTL("Cancel"), CANCEL)
        value = KantoReloaded::PopupWindow.choice(_INTL("Filter by Marking"), rows)
        value == CANCEL || value.nil? ? current : value
      end

      def choose_location(access, current)
        rows = [row(_INTL("All Storage"), :all), row(_INTL("Party"), :party),
                row(_INTL("Current Box"), :current)]
        access.storage.boxes.each_with_index do |box, index|
          rows << row(box.name.to_s, index)
        end
        rows << row(_INTL("Cancel"), CANCEL)
        value = KantoReloaded::PopupWindow.choice(_INTL("Filter by Location"), rows)
        value == CANCEL || value.nil? ? current : value
      end

      def show_results(access, criteria)
        matches = storage_entries(access).select do |location, pokemon|
          matches_criteria?(access, location, pokemon, criteria)
        end
        return warning(_INTL("No matching Pokemon were found.")) if matches.empty?
        rows = matches.map do |location, pokemon|
          name = pokemon.egg? ? _INTL("Egg") : pokemon.name.to_s
          level = pokemon.egg? ? "" : _INTL(" Lv. {1}", pokemon.level)
          row(_INTL("{1}{2} - {3}", name, level,
                    KantoReloaded::StorageActions.location_label(access, location)), location)
        end
        rows << row(_INTL("Cancel"), CANCEL)
        selected = KantoReloaded::PopupWindow.choice(
          _INTL("Found {1} Pokemon", matches.length), rows
        )
        return false unless selected.is_a?(Array)
        unless access.jump_to(selected)
          KantoReloaded.toast(
            KantoReloaded::StorageActions.location_label(access, selected)
          )
        end
        true
      end

      def matches_criteria?(access, location, pokemon, criteria)
        egg = pokemon.egg?
        return false unless location_matches?(access, location, criteria[:location])
        return false unless state_matches?(pokemon.shiny?, criteria[:shiny])
        return false unless state_matches?(egg, criteria[:egg])
        return false unless state_matches?(fused?(pokemon), criteria[:fusion])
        if criteria[:min_level] && pokemon.level.to_i < criteria[:min_level].to_i
          return false
        end
        if criteria[:max_level] && pokemon.level.to_i > criteria[:max_level].to_i
          return false
        end
        query = criteria[:name].to_s.downcase
        unless query.empty?
          names = egg ? [_INTL("Egg")] : [pokemon.name, species_name(pokemon)]
          return false unless names.any? { |name| name.to_s.downcase.include?(query) }
        end
        if criteria[:type] != ANY
          return false if egg || !pokemon_types(pokemon).include?(criteria[:type])
        end
        return false unless item_matches?(pokemon, criteria[:item])
        return false unless text_matches?(egg ? "" : ability_name(pokemon), criteria[:ability])
        moves = egg ? "" : pokemon.moves.map { |move| move.name.to_s }.join(" ")
        return false unless text_matches?(moves, criteria[:move])
        return false unless text_matches?(owner_name(pokemon), criteria[:ot])
        marking_matches?(pokemon.markings.to_i, criteria[:marking])
      rescue StandardError
        false
      end

      def choose_sort_scope(access)
        rows = [
          row(_INTL("Current Box"), :current),
          row(_INTL("Each Unlocked Box"), :each_unlocked),
          row(_INTL("Across All Unlocked Boxes"), :across_unlocked)
        ]
        selected = access.selected_locations
        rows << row(_INTL("Selected Pokemon"), :selected) if selected.length > 1 &&
          selected.all? { |location| location[0] >= 0 }
        rows << row(_INTL("Cancel"), CANCEL)
        value = KantoReloaded::PopupWindow.choice(_INTL("Sort Scope"), rows)
        value == CANCEL ? nil : value
      end

      def apply_sort(access, field, scope, direction)
        case scope
        when :current
          return warning(_INTL("This Box is locked from sorting.")) if sort_locked?(access, access.current_box)
          sort_box(access, access.current_box, field, direction)
        when :each_unlocked
          unlocked_boxes(access).each { |box| sort_box(access, box, field, direction) }
        when :across_unlocked
          sort_across_boxes(access, unlocked_boxes(access), field, direction)
        when :selected
          sort_selected(access, field, direction)
        else
          return false
        end
        access.refresh
        KantoReloaded.toast_success(_INTL("Pokemon sorted."))
        true
      end

      def sort_box(access, box_index, field, direction)
        box = access.storage.boxes[box_index]
        pokemon = box.pokemon.compact
        sorted = stable_sort(pokemon, field, direction)
        box.pokemon.each_index { |index| box.pokemon[index] = sorted[index] }
      end

      def sort_across_boxes(access, boxes, field, direction)
        pokemon = boxes.flat_map { |index| access.storage.boxes[index].pokemon.compact }
        sorted = stable_sort(pokemon, field, direction)
        boxes.each do |index|
          box = access.storage.boxes[index]
          box.pokemon.each_index { |slot| box.pokemon[slot] = sorted.shift }
        end
      end

      def sort_selected(access, field, direction)
        locations = access.selected_locations.select do |location|
          location[0] >= 0 && access.pokemon(location)
        end.sort_by { |location| [location[0], location[1]] }
        return warning(_INTL("Select at least two boxed Pokemon.")) if locations.length < 2
        sorted = stable_sort(locations.map { |location| access.pokemon(location) }, field, direction)
        locations.each_with_index do |location, index|
          access.storage[location[0], location[1]] = sorted[index]
        end
      end

      def stable_sort(pokemon, field, direction)
        normal = []
        eggs = []
        pokemon.each_with_index do |entry, index|
          target = entry.egg? ? eggs : normal
          target << [entry, index, sort_key(entry, field)]
        end
        normal.sort! do |left, right|
          comparison = compare_values(left[2], right[2])
          comparison *= -1 if direction == :descending
          comparison = left[1] <=> right[1] if comparison == 0
          comparison
        end
        if field == :hatch_steps
          eggs.sort! do |left, right|
            comparison = compare_values(left[2], right[2])
            comparison *= -1 if direction == :descending
            comparison = left[1] <=> right[1] if comparison == 0
            comparison
          end
        end
        (normal + eggs).map { |entry| entry[0] }
      end

      def sort_key(pokemon, field)
        data = pokemon.species_data
        case field
        when :species_name then species_name(pokemon).downcase
        when :nickname then pokemon.name.to_s.downcase
        when :dex_number then (pokemon.dexNum rescue data.id_number).to_i
        when :level then pokemon.level.to_i
        when :total_hp then pokemon.totalhp.to_i
        when :attack then pokemon.attack.to_i
        when :defense then pokemon.defense.to_i
        when :special_attack then pokemon.spatk.to_i
        when :special_defense then pokemon.spdef.to_i
        when :speed then pokemon.speed.to_i
        when :bst then data.base_stats.values.inject(0) { |sum, value| sum + value.to_i }
        when :base_hp then base_stat(data, :HP)
        when :base_attack then base_stat(data, :ATTACK)
        when :base_defense then base_stat(data, :DEFENSE)
        when :base_special_attack then base_stat(data, :SPECIAL_ATTACK)
        when :base_special_defense then base_stat(data, :SPECIAL_DEFENSE)
        when :base_speed then base_stat(data, :SPEED)
        when :caught_date then pokemon.timeReceived.to_s
        when :shiny then pokemon.shiny? ? 1 : 0
        when :ot then owner_name(pokemon).downcase
        when :gender then pokemon.gender.to_i
        when :ability then ability_name(pokemon).downcase
        when :nature then (pokemon.nature.name.to_s.downcase rescue "")
        when :held_item then pokemon.item ? pokemon.item.name.to_s.downcase : ""
        when :type_1 then type_name(pokemon_types(pokemon)[0]).downcase
        when :type_2 then type_name(pokemon_types(pokemon)[1]).downcase
        when :caught_map then pokemon.obtain_map.to_i
        when :happiness then pokemon.happiness.to_i
        when :experience then pokemon.exp.to_i
        when :markings then pokemon.markings.to_i
        when :total_ivs then stat_total(pokemon.iv)
        when :total_evs then stat_total(pokemon.ev)
        when :hatch_steps then pokemon.steps_to_hatch.to_i
        when :fusion then fused?(pokemon) ? 1 : 0
        when :form then pokemon.form.to_i
        else species_name(pokemon).downcase
        end
      rescue StandardError
        0
      end

      def compare_values(left, right)
        result = left <=> right
        result.nil? ? left.to_s <=> right.to_s : result
      end

      def compact(access, scope)
        boxes = scope == :current ? [access.current_box] : unlocked_boxes(access)
        if scope == :current && sort_locked?(access, access.current_box)
          return warning(_INTL("This Box is locked from sorting."))
        end
        return false unless KantoReloaded::PopupWindow.confirm(
          scope == :current ? _INTL("Compact this Box?") :
            _INTL("Compact all unlocked Boxes?")
        )
        boxes.each do |index|
          box = access.storage.boxes[index]
          pokemon = box.pokemon.compact
          box.pokemon.each_index { |slot| box.pokemon[slot] = pokemon[slot] }
        end
        access.refresh
        KantoReloaded.toast_success(_INTL("Storage compacted."))
        true
      end

      def storage_overview(access)
        rows = access.storage.boxes.each_with_index.map do |box, index|
          flags = []
          flags << _INTL("Sort Locked") if box.sortlock?
          flags << _INTL("Export Locked") if box.exportlock?
          suffix = flags.empty? ? "" : " - #{flags.join(', ')}"
          row(_INTL("{1} ({2}/{3}){4}", box.name, box.nitems, box.length, suffix), index)
        end
        rows << row(_INTL("Cancel"), CANCEL)
        selected = KantoReloaded::PopupWindow.choice(
          _INTL("Storage Overview"), rows, :start_index => access.current_box
        )
        access.jump_to([selected, 0]) if selected.is_a?(Integer)
      end

      def storage_entries(access)
        KantoReloaded::StorageActions.all_locations(access.storage).map do |location|
          pokemon = access.pokemon(location)
          pokemon ? [location, pokemon] : nil
        end.compact
      end

      def current_box_locations(access)
        (0...access.storage.maxPokemon(access.current_box)).map do |index|
          [access.current_box, index]
        end
      end

      def unlocked_boxes(access)
        (0...access.storage.maxBoxes).reject { |index| sort_locked?(access, index) }
      end

      def sort_locked?(access, index)
        access.storage.boxes[index].sortlock?
      rescue StandardError
        false
      end

      def location_matches?(access, location, filter)
        return true if filter == :all
        return location[0] == -1 if filter == :party
        return location[0] == access.current_box if filter == :current
        filter.is_a?(Integer) && location[0] == filter
      end

      def state_matches?(actual, filter)
        filter == ANY || actual == filter
      end

      def item_matches?(pokemon, filter)
        return true if filter == ANY
        return pokemon.item.nil? if filter == :none
        pokemon.item && pokemon.item.id == filter
      rescue StandardError
        false
      end

      def text_matches?(text, query)
        query.to_s.empty? || text.to_s.downcase.include?(query.to_s.downcase)
      end

      def marking_matches?(markings, filter)
        return true if filter == ANY
        return markings != 0 if filter == :marked
        return markings == 0 if filter == :unmarked
        filter.is_a?(Integer) && (markings & (1 << filter)) != 0
      end

      def text_value(value)
        value.to_s.empty? ? _INTL("Any") : value.to_s
      end

      def state_label(value)
        return _INTL("Any") if value == ANY
        value ? _INTL("Yes") : _INTL("No")
      end

      def marking_label(value)
        return _INTL("Any") if value == ANY
        return _INTL("Any Mark") if value == :marked
        return _INTL("No Marks") if value == :unmarked
        _INTL("Mark {1}", value.to_i + 1)
      end

      def type_label(value)
        value == ANY ? _INTL("Any") : type_name(value)
      end

      def item_label(value)
        return _INTL("Any") if value == ANY
        return _INTL("None") if value == :none
        item_name(value)
      end

      def level_label(criteria)
        minimum = criteria[:min_level]
        maximum = criteria[:max_level]
        return _INTL("Any") unless minimum && maximum
        return minimum.to_s if minimum == maximum
        _INTL("{1}-{2}", minimum, maximum)
      end

      def location_filter_label(access, value)
        return _INTL("All Storage") if value == :all
        return _INTL("Party") if value == :party
        return _INTL("Current Box") if value == :current
        return access.storage.boxes[value].name.to_s if value.is_a?(Integer) && access.storage.boxes[value]
        _INTL("All Storage")
      end

      def species_name(pokemon)
        pokemon.speciesName.to_s
      rescue StandardError
        pokemon.species_data.name.to_s
      end

      def owner_name(pokemon)
        pokemon.owner.name.to_s
      rescue StandardError
        ""
      end

      def ability_name(pokemon)
        pokemon.ability.name.to_s
      rescue StandardError
        ""
      end

      def pokemon_types(pokemon)
        [pokemon.type1, pokemon.type2].compact.uniq
      rescue StandardError
        []
      end

      def type_name(id)
        return "" if id.nil?
        GameData::Type.get(id).name.to_s
      rescue StandardError
        id.to_s
      end

      def item_name(id)
        GameData::Item.get(id).name.to_s
      rescue StandardError
        id.to_s
      end

      def base_stat(data, id)
        data.base_stats[id].to_i
      rescue StandardError
        0
      end

      def stat_total(values)
        return 0 unless values
        values.values.inject(0) { |sum, value| sum + value.to_i }
      rescue StandardError
        0
      end

      def fused?(pokemon)
        return pokemon.isFusion? if pokemon.respond_to?(:isFusion?)
        pokemon.species_data.id_number.to_i > NB_POKEMON
      rescue StandardError
        false
      end

      def max_level
        defined?(Settings::MAXIMUM_LEVEL) ? Settings::MAXIMUM_LEVEL : 100
      rescue StandardError
        100
      end

      def warning(message)
        pbPlayBuzzerSE rescue nil
        KantoReloaded.toast_warning(message)
        false
      end

      def log_exception(message, error)
        KantoReloaded::Log.exception(
          message, error, :channel => :pc_organization
        ) if defined?(KantoReloaded::Log)
      end
    end
  end
end

KantoReloaded::StorageTools.install if defined?(KantoReloaded::StorageTools)
