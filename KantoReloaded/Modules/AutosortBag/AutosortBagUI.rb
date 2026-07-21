#==============================================================================
# Kanto Reloaded - Autosort Bag Editor
#==============================================================================
# KR-styled editor for per-pocket custom lists, favorites, and separators.
#==============================================================================

module KantoReloaded
  module AutosortBag
    class EditorScene
      SCREEN_W = 512
      SCREEN_H = 384
      TITLE_H = 36
      FOOTER_H = 30
      CONTENT_Y = TITLE_H + 2
      CONTENT_H = SCREEN_H - TITLE_H - FOOTER_H - 4
      LIST_X = 4
      LIST_W = 342
      DETAIL_X = LIST_X + LIST_W + 8
      DETAIL_W = SCREEN_W - DETAIL_X - 4
      ROW_H = 20
      LIST_PAD = 8
      VISIBLE_ROWS = (CONTENT_H - LIST_PAD * 2) / ROW_H

      BG_COLOR = Color.new(10, 20, 40)
      PANEL_BG = Color.new(18, 32, 62)
      PANEL_BORDER = Color.new(50, 90, 160)
      TITLE_BG = Color.new(12, 24, 50)
      WHITE = Color.new(255, 255, 255)
      GRAY = Color.new(180, 185, 205)
      DIM = Color.new(105, 112, 140)
      BLUE = Color.new(120, 190, 255)
      GOLD = Color.new(240, 205, 85)
      GREEN = Color.new(105, 224, 164)

      def main
        setup
        while @running
          Graphics.update
          Input.update
          @item_icon.update if @item_icon && !@item_icon.disposed?
          handle_input
          draw_list if ((Graphics.frame_count rescue 0) % 4).zero?
        end
      ensure
        dispose
      end

      private

      def setup
        @running = true
        @pocket_index = 1
        @selected = 0
        @scroll = 0
        @moving = false
        @move_snapshot = nil
        suspend_speedup

        @viewport = Viewport.new(0, 0, SCREEN_W, SCREEN_H)
        @viewport.z = 100_000
        @background = Sprite.new(@viewport)
        @background.bitmap = Bitmap.new(SCREEN_W, SCREEN_H)
        @background.bitmap.fill_rect(0, 0, SCREEN_W, SCREEN_H, BG_COLOR)

        @title_sprite = BitmapSprite.new(SCREEN_W, TITLE_H, @viewport)
        @list_sprite = BitmapSprite.new(LIST_W, CONTENT_H, @viewport)
        @detail_sprite = BitmapSprite.new(DETAIL_W, CONTENT_H, @viewport)
        @footer_sprite = BitmapSprite.new(SCREEN_W, FOOTER_H, @viewport)
        @list_sprite.x = LIST_X
        @list_sprite.y = CONTENT_Y
        @detail_sprite.x = DETAIL_X
        @detail_sprite.y = CONTENT_Y
        @footer_sprite.y = SCREEN_H - FOOTER_H

        create_item_icon
        load_pocket
      end

      def create_item_icon
        return unless defined?(ItemIconSprite)
        @item_icon = ItemIconSprite.new(
          DETAIL_X + DETAIL_W / 2, CONTENT_Y + 82, nil, @viewport
        )
        @item_icon.z = @viewport.z + 2
        @item_icon.setOffset(PictureOrigin::Center) if defined?(PictureOrigin)
        @item_icon.zoom_x = 1.5
        @item_icon.zoom_y = 1.5
      rescue StandardError
        @item_icon = nil
      end

      def load_pocket
        @pocket_key = AutosortBag.pocket_key(@pocket_index)
        @list = AutosortBag.list_for(@pocket_key)
        @favorites = AutosortBag.favorites_for(@pocket_key)
        @selected = [[@selected, 0].max, [@list.length - 1, 0].max].min
        @scroll = 0
        @moving = false
        @move_snapshot = nil
        ensure_visible
        draw_all
      end

      def draw_all
        draw_title
        draw_list
        draw_details
        draw_footer
      end

      def draw_title
        bitmap = @title_sprite.bitmap
        bitmap.clear
        bitmap.fill_rect(0, 0, SCREEN_W, TITLE_H, TITLE_BG)
        bitmap.fill_rect(0, TITLE_H - 1, SCREEN_W, 1, PANEL_BORDER)
        set_small_font(bitmap)
        draw_text(
          bitmap, 10, 3, SCREEN_W - 20, 26,
          _INTL("AUTOSORT BAG - {1}", AutosortBag.pocket_name(@pocket_index)),
          BLUE, 1
        )
      end

      def draw_list
        bitmap = @list_sprite.bitmap
        bitmap.clear
        draw_panel(bitmap, LIST_W, CONTENT_H)
        set_small_font(bitmap)

        visible = @list[@scroll, VISIBLE_ROWS] || []
        if visible.empty?
          draw_text(
            bitmap, LIST_PAD, 94, LIST_W - LIST_PAD * 2, 24,
            _INTL("No custom entries."), DIM, 1
          )
          return
        end

        visible.each_with_index do |entry, local_index|
          index = @scroll + local_index
          y = LIST_PAD + local_index * ROW_H
          draw_cursor(bitmap, y) if index == @selected
          color = row_color(entry, index)
          prefix = row_prefix(entry, index)
          draw_text(
            bitmap, LIST_PAD + 8, y - 5, LIST_W - LIST_PAD * 2 - 16,
            ROW_H + 2, "#{prefix}#{row_label(entry)}", color, 0
          )
        end
      end

      def draw_details
        bitmap = @detail_sprite.bitmap
        bitmap.clear
        draw_panel(bitmap, DETAIL_W, CONTENT_H)
        set_small_font(bitmap)

        entry = current_entry
        if AutosortBag.separator?(entry)
          update_item_icon(nil)
          draw_text(
            bitmap, 8, 58, DETAIL_W - 16, 24,
            AutosortBag.separator_name(entry), GOLD, 1
          )
          draw_wrapped(
            bitmap, _INTL("A visual divider used by the custom list editor."),
            10, 104, DETAIL_W - 20, GRAY
          )
        elsif entry
          update_item_icon(entry)
          draw_text(
            bitmap, 8, 118, DETAIL_W - 16, 24,
            AutosortBag.item_name(entry), WHITE, 1
          )
          draw_text(
            bitmap, 8, 140, DETAIL_W - 16, 20,
            entry.to_s, DIM, 1
          )
          favorite_text = @favorites.include?(entry) ?
            _INTL("Favorite") : _INTL("Standard")
          favorite_color = @favorites.include?(entry) ? GOLD : GRAY
          draw_text(
            bitmap, 8, 172, DETAIL_W - 16, 20,
            favorite_text, favorite_color, 1
          )
        else
          update_item_icon(nil)
        end

        mode_label = AutosortBag::MODE_LABELS[
          AutosortBag::MODES.index(AutosortBag.mode(@pocket_key)) || 0
        ]
        draw_text(
          bitmap, 8, CONTENT_H - 73, DETAIL_W - 16, 20,
          _INTL("Policy"), DIM, 1
        )
        draw_text(
          bitmap, 8, CONTENT_H - 53, DETAIL_W - 16, 20,
          mode_label, BLUE, 1
        )
        draw_text(
          bitmap, 8, CONTENT_H - 33, DETAIL_W - 16, 20,
          _INTL("{1} entries", @list.length), GRAY, 1
        )
      end

      def draw_footer
        bitmap = @footer_sprite.bitmap
        bitmap.clear
        bitmap.fill_rect(0, 0, SCREEN_W, FOOTER_H, TITLE_BG)
        bitmap.fill_rect(0, 0, SCREEN_W, 1, PANEL_BORDER)
        hints = if @moving
                  [
                    KantoReloaded::HintText.confirm("Place"),
                    KantoReloaded::HintText.back("Cancel"),
                    KantoReloaded::HintText.other("Place", "X"),
                    KantoReloaded::HintText.other("Move", :pocket)
                  ]
                else
                  [
                    KantoReloaded::HintText.confirm("Actions"),
                    KantoReloaded::HintText.back("Exit"),
                    KantoReloaded::HintText.action("Favorite"),
                    KantoReloaded::HintText.other("Move", "X"),
                    KantoReloaded::HintText.other("Pocket", :pocket)
                  ]
                end
        KantoReloaded::HintText.draw_footer(
          bitmap, hints, 8, 5, SCREEN_W - 16,
          :size => 14, :color => WHITE, :height => FOOTER_H,
          :y_offset => -5,
          :hint_entry => footer_list_hint
        )
      rescue StandardError
        nil
      end

      def draw_panel(bitmap, width, height)
        KantoReloaded::UI::Draw.rounded_rect(
          bitmap, 0, 0, width, height, 5, PANEL_BORDER
        )
        KantoReloaded::UI::Draw.rounded_rect(
          bitmap, 1, 1, width - 2, height - 2, 4, PANEL_BG
        )
      end

      def draw_cursor(bitmap, y)
        pulse = Math.sin(
          (Graphics.frame_count rescue 0) * Math::PI / 20.0
        ) * 0.5 + 0.5
        fill, border = cursor_colors
        alpha = [[fill.alpha.to_i + (pulse * 55).to_i, 255].min, 80].max
        fill = KantoReloaded::UI::Draw.with_alpha(fill, alpha)
        KantoReloaded::UI::Draw.rounded_rect(
          bitmap, LIST_PAD, y + 3, LIST_W - LIST_PAD * 2, ROW_H - 2,
          4, fill, border
        )
      end

      def cursor_colors
        return KantoReloaded::Options.cursor_colors if
          defined?(KantoReloaded::Options)
        [
          Color.new(100, 160, 220, 160),
          Color.new(60, 120, 180, 220)
        ]
      rescue StandardError
        [
          Color.new(100, 160, 220, 160),
          Color.new(60, 120, 180, 220)
        ]
      end

      def handle_input
        if list_footer_clicked?
          open_list_actions
          return
        end
        mouse_index = update_mouse
        if mouse_index && KantoReloaded::MouseInput.mouse_triggered?
          open_row_actions unless @moving
          return
        end

        wheel = KantoReloaded::MouseInput.wheel_delta
        if wheel != 0
          if @moving
            move_current_row(wheel < 0 ? 1 : -1)
          else
            move_selection(wheel < 0 ? 1 : -1)
          end
        elsif @moving
          handle_move_input
        elsif Input.repeat?(Input::UP)
          move_selection(-1)
        elsif Input.repeat?(Input::DOWN)
          move_selection(1)
        elsif Input.repeat?(Input::LEFT)
          change_pocket(-1)
        elsif Input.repeat?(Input::RIGHT)
          change_pocket(1)
        elsif Input.trigger?(Input::USE)
          open_row_actions
        elsif Input.trigger?(Input::ACTION)
          toggle_favorite
        elsif Input.const_defined?(:SPECIAL) &&
              Input.trigger?(Input::SPECIAL)
          open_list_actions
        elsif input_x_triggered?
          begin_move
        elsif Input.trigger?(Input::BACK)
          pbPlayCloseMenuSE rescue nil
          @running = false
        end
      end

      def footer_list_hint
        return KantoReloaded::HintText.other("", "") if @moving
        KantoReloaded::HintText.special("List")
      end

      def list_footer_clicked?
        return false if @moving
        position = KantoReloaded::MouseInput.active_position
        return false unless position &&
          KantoReloaded::MouseInput.mouse_triggered?
        KantoReloaded::HintText.controls_at?(
          @footer_sprite.bitmap, position[0], position[1],
          8, SCREEN_H - FOOTER_H + 5, SCREEN_W - 16,
          :height => FOOTER_H,
          :hint_entry => KantoReloaded::HintText.special("List")
        )
      rescue StandardError
        false
      end

      def handle_move_input
        if Input.repeat?(Input::UP)
          move_current_row(-1)
        elsif Input.repeat?(Input::DOWN)
          move_current_row(1)
        elsif Input.repeat?(Input::LEFT)
          move_current_row(-5)
        elsif Input.repeat?(Input::RIGHT)
          move_current_row(5)
        elsif Input.trigger?(Input::USE)
          finish_move
        elsif input_x_triggered?
          finish_move
        elsif Input.trigger?(Input::BACK)
          cancel_move
        end
      end

      def input_x_triggered?
        defined?(Input) && Input.const_defined?(:X) &&
          Input.trigger?(Input::X)
      rescue StandardError
        false
      end

      def update_mouse
        return nil if @moving
        position = KantoReloaded::MouseInput.active_position
        return nil unless position
        x = position[0].to_i
        y = position[1].to_i
        return nil unless x.between?(LIST_X, LIST_X + LIST_W - 1)
        return nil unless y.between?(CONTENT_Y + LIST_PAD,
                                     CONTENT_Y + CONTENT_H - LIST_PAD - 1)
        index = @scroll + ((y - CONTENT_Y - LIST_PAD) / ROW_H)
        return nil unless index >= 0 && index < @list.length
        if @selected != index
          @selected = index
          ensure_visible
          pbPlayCursorSE rescue nil
          draw_list
          draw_details
        end
        index
      end

      def move_selection(amount)
        return if @list.empty?
        old = @selected
        @selected = (@selected + amount) % @list.length
        return if old == @selected
        ensure_visible
        pbPlayCursorSE rescue nil
        draw_list
        draw_details
      end

      def change_pocket(amount)
        @pocket_index = ((@pocket_index - 1 + amount) %
          AutosortBag::POCKETS.length) + 1
        @selected = 0
        @scroll = 0
        pbPlayCursorSE rescue nil
        load_pocket
      end

      def open_row_actions
        return buzzer if @list.empty?
        entry = current_entry
        rows = [{ :label => _INTL("Move"), :value => :move }]
        if AutosortBag.separator?(entry)
          rows << { :label => _INTL("Rename Separator"), :value => :rename }
        end
        rows << {
          :label => _INTL("Insert Separator Below"), :value => :separator
        }
        rows << { :label => _INTL("Remove"), :value => :remove }
        rows << { :label => _INTL("Back"), :value => :back }
        action = KantoReloaded::PopupWindow.choice(
          _INTL("Edit {1}", row_label(entry)), rows
        )
        case action
        when :move then begin_move
        when :rename then rename_separator
        when :separator then insert_separator(@selected + 1)
        when :remove then remove_current
        end
        draw_all
      end

      def open_list_actions
        rows = [
          { :label => _INTL("Add Item"), :value => :add_item },
          { :label => _INTL("Add Separator"), :value => :add_separator },
          { :label => _INTL("Restore Pocket Defaults"), :value => :restore },
          { :label => _INTL("Clear Favorites"), :value => :clear_favorites,
            :enabled => !@favorites.empty? },
          { :label => _INTL("Back"), :value => :back }
        ]
        action = KantoReloaded::PopupWindow.choice(
          _INTL("{1} Sorting List", AutosortBag.pocket_name(@pocket_index)),
          rows
        )
        case action
        when :add_item then add_item
        when :add_separator then insert_separator(@list.length)
        when :restore then restore_defaults
        when :clear_favorites then clear_favorites
        end
        draw_all
      end

      def begin_move
        @move_snapshot = snapshot
        @moving = true
        pbPlayDecisionSE rescue nil
        draw_footer
      end

      def move_current_row(amount)
        return buzzer if @list.length < 2
        target = [[@selected + amount, 0].max, @list.length - 1].min
        return if target == @selected
        entry = @list.delete_at(@selected)
        @list.insert(target, entry)
        @selected = target
        ensure_visible
        pbPlayCursorSE rescue nil
        draw_list
        draw_details
      end

      def finish_move
        @move_snapshot = nil
        @moving = false
        commit
        pbPlayDecisionSE rescue nil
        draw_all
      end

      def cancel_move
        restore_snapshot(@move_snapshot)
        @move_snapshot = nil
        @moving = false
        pbPlayCancelSE rescue nil
        draw_all
      end

      def add_item
        existing = @list.reject { |entry| AutosortBag.separator?(entry) }
        candidates = all_pocket_items.reject { |item| existing.include?(item) }
        if candidates.empty?
          KantoReloaded::Toast.warning(
            _INTL("Every known item in this pocket is already listed.")
          )
          return
        end
        selected = nil
        with_editor_hidden do
          selected = ItemPickerScene.new(
            candidates, AutosortBag.pocket_name(@pocket_index)
          ).main
        end
        return unless selected.is_a?(Symbol)
        @list << selected
        @selected = @list.length - 1
        commit
        pbPlayDecisionSE rescue nil
      end

      def insert_separator(index)
        name = prompt_separator_name("SEPARATOR")
        return if name.nil?
        @list.insert(index, [AutosortBag::SEPARATOR, name])
        @selected = index
        commit
        pbPlayDecisionSE rescue nil
      end

      def rename_separator
        entry = current_entry
        return unless AutosortBag.separator?(entry)
        name = prompt_separator_name(AutosortBag.separator_name(entry))
        return if name.nil?
        @list[@selected] = [AutosortBag::SEPARATOR, name]
        commit
        pbPlayDecisionSE rescue nil
      end

      def prompt_separator_name(default_name)
        return "SEPARATOR" unless defined?(pbEnterText)
        value = nil
        with_editor_hidden do
          value = pbEnterText(
            _INTL("Separator name?"), 1, 24, default_name.to_s
          )
        end
        value = value.to_s.gsub(/[\r\n\t]/, " ").strip
        return nil if value.empty?
        value[0, 24].upcase
      rescue StandardError => e
        AutosortBag.send(
          :log_exception, "Autosort separator name prompt failed", e
        )
        nil
      end

      def toggle_favorite
        entry = current_entry
        return buzzer if !entry || AutosortBag.separator?(entry)
        if @favorites.include?(entry)
          @favorites.delete(entry)
        else
          @favorites << entry
        end
        commit
        pbPlayDecisionSE rescue nil
      end

      def remove_current
        entry = current_entry
        return unless entry
        prompt = AutosortBag.separator?(entry) ?
          _INTL("Remove the {1} separator?",
                AutosortBag.separator_name(entry)) :
          _INTL("Remove {1} from this sorting list?",
                AutosortBag.item_name(entry))
        return unless KantoReloaded::PopupWindow.confirm(
          prompt, :default => false
        )
        removed = @list.delete_at(@selected)
        @favorites.delete(removed) unless AutosortBag.separator?(removed)
        @selected = [@selected, @list.length - 1].min
        @selected = 0 if @selected < 0
        commit
        pbPlayDecisionSE rescue nil
      end

      def restore_defaults
        return unless KantoReloaded::PopupWindow.confirm(
          _INTL("Restore the default {1} sorting list?",
                AutosortBag.pocket_name(@pocket_index)),
          :default => false
        )
        defaults = KantoReloaded::AutosortBag::Defaults.lists
        @list = Array(defaults[@pocket_key]).map do |entry|
          entry.is_a?(Array) ? entry.dup : entry
        end
        @favorites = []
        @selected = 0
        commit
        KantoReloaded::Toast.success(
          _INTL("{1} defaults restored.",
                AutosortBag.pocket_name(@pocket_index))
        )
      end

      def clear_favorites
        return if @favorites.empty?
        return unless KantoReloaded::PopupWindow.confirm(
          _INTL("Clear all favorites in this pocket?"), :default => false
        )
        @favorites = []
        commit
        KantoReloaded::Toast.success(_INTL("Pocket favorites cleared."))
      end

      def snapshot
        {
          :list => @list.map { |entry| entry.is_a?(Array) ? entry.dup : entry },
          :favorites => @favorites.dup,
          :selected => @selected
        }
      end

      def restore_snapshot(value)
        return unless value.is_a?(Hash)
        @list = Array(value[:list]).map do |entry|
          entry.is_a?(Array) ? entry.dup : entry
        end
        @favorites = Array(value[:favorites]).dup
        @selected = value[:selected].to_i
        @selected = [[@selected, 0].max, [@list.length - 1, 0].max].min
        ensure_visible
      end

      def commit
        ordered_items = @list.reject { |entry| AutosortBag.separator?(entry) }
        @favorites = ordered_items.select { |item| @favorites.include?(item) }
        AutosortBag.set_list(@pocket_key, @list, apply: false)
        AutosortBag.set_favorites(
          @pocket_key, @favorites, apply: false
        )
        AutosortBag.apply_pocket(@pocket_key)
        ensure_visible
      end

      def all_pocket_items
        result = []
        GameData::Item.each do |item|
          next unless item.pocket.to_i == @pocket_index
          result << item.id
        end
        result.sort_by { |item| AutosortBag.item_name(item).to_s.downcase }
      rescue StandardError
        AutosortBag.bag_items_for(@pocket_key).sort_by do |item|
          AutosortBag.item_name(item).to_s.downcase
        end
      end

      def ensure_visible
        @scroll = @selected if @selected < @scroll
        if @selected >= @scroll + VISIBLE_ROWS
          @scroll = @selected - VISIBLE_ROWS + 1
        end
        max_scroll = [@list.length - VISIBLE_ROWS, 0].max
        @scroll = [[@scroll, 0].max, max_scroll].min
      end

      def current_entry
        @list[@selected]
      end

      def row_label(entry)
        return _INTL("[ {1} ]", AutosortBag.separator_name(entry)) if
          AutosortBag.separator?(entry)
        AutosortBag.item_name(entry)
      end

      def row_prefix(entry, index)
        return "" if AutosortBag.separator?(entry)
        return "* " if @favorites.include?(entry)
        index == @selected && @moving ? "> " : ""
      end

      def row_color(entry, index)
        return GOLD if AutosortBag.separator?(entry)
        return GOLD if @favorites.include?(entry)
        index == @selected ? WHITE : GRAY
      end

      def update_item_icon(item)
        return unless @item_icon && !@item_icon.disposed?
        @item_icon.item = item
        @item_icon.visible = !item.nil?
      rescue StandardError
        nil
      end

      def draw_wrapped(bitmap, text, x, y, width, color)
        lines = KantoReloaded::UI::Draw.wrap_lines(bitmap, text, width)
        lines.first(4).each_with_index do |line, index|
          draw_text(bitmap, x, y + index * 20, width, 20, line, color, 1)
        end
      end

      def draw_text(bitmap, x, y, width, height, text, color, align = 0)
        KantoReloaded::UI::Draw.plain_text(
          bitmap, x, y, width, height, text, color, align
        )
      end

      def set_small_font(bitmap)
        pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
      end

      def with_editor_hidden
        sprites = [
          @background, @title_sprite, @list_sprite, @detail_sprite,
          @footer_sprite, @item_icon
        ].compact
        visibility = sprites.map { |sprite| sprite.visible rescue true }
        old_z = @viewport.z
        sprites.each { |sprite| sprite.visible = false rescue nil }
        @viewport.z = 0
        Graphics.update
        yield
      ensure
        @viewport.z = old_z rescue 100_000
        sprites.each_with_index do |sprite, index|
          sprite.visible = visibility[index] rescue nil
        end
        Graphics.update rescue nil
      end

      def suspend_speedup
        @speedup_state_known = defined?($CanToggle) == "global-variable"
        @speedup_was_allowed = $CanToggle if @speedup_state_known
        @speed_mode_state_known = defined?($PokemonSystem) &&
          $PokemonSystem &&
          $PokemonSystem.respond_to?(:speedtoggle) &&
          $PokemonSystem.respond_to?(:speedtoggle=)
        if @speed_mode_state_known
          @speed_toggle_was = $PokemonSystem.speedtoggle
          $PokemonSystem.speedtoggle = 0
        end
        if respond_to?(:pbDisallowSpeedup, true)
          pbDisallowSpeedup
        elsif @speedup_state_known
          $CanToggle = false
        end
      rescue StandardError
        nil
      end

      def restore_speedup
        if @speed_mode_state_known && defined?($PokemonSystem) &&
           $PokemonSystem
          $PokemonSystem.speedtoggle = @speed_toggle_was
        end
        $CanToggle = @speedup_was_allowed if @speedup_state_known
      rescue StandardError
        nil
      end

      def buzzer
        pbPlayBuzzerSE rescue nil
        false
      end

      def dispose
        restore_speedup
        @item_icon.dispose if @item_icon && !@item_icon.disposed?
        [
          @footer_sprite, @detail_sprite, @list_sprite, @title_sprite,
          @background
        ].compact.each do |sprite|
          sprite.bitmap.dispose if sprite.bitmap && !sprite.bitmap.disposed?
          sprite.dispose unless sprite.disposed?
        rescue StandardError
          nil
        end
        @viewport.dispose if @viewport && !@viewport.disposed?
      rescue StandardError
        nil
      end
    end

    class ItemPickerScene
      SCREEN_W = 512
      SCREEN_H = 384
      TITLE_H = 36
      FOOTER_H = 30
      CONTENT_Y = TITLE_H + 2
      CONTENT_H = SCREEN_H - TITLE_H - FOOTER_H - 4
      LIST_X = 4
      LIST_W = 342
      DETAIL_X = LIST_X + LIST_W + 8
      DETAIL_W = SCREEN_W - DETAIL_X - 4
      ROW_H = 20
      LIST_PAD = 8
      VISIBLE_ROWS = (CONTENT_H - LIST_PAD * 2) / ROW_H

      BG_COLOR = Color.new(10, 20, 40)
      PANEL_BG = Color.new(18, 32, 62)
      PANEL_BORDER = Color.new(50, 90, 160)
      TITLE_BG = Color.new(12, 24, 50)
      WHITE = Color.new(255, 255, 255)
      GRAY = Color.new(180, 185, 205)
      DIM = Color.new(105, 112, 140)
      BLUE = Color.new(120, 190, 255)
      GOLD = Color.new(240, 205, 85)

      def initialize(items, pocket_name)
        @all_items = Array(items).uniq
        @pocket_name = pocket_name.to_s
        @query = ""
        @selected = 0
        @scroll = 0
      end

      def main
        setup
        loop do
          Graphics.update
          Input.update
          @item_icon.update if @item_icon && !@item_icon.disposed?
          result = handle_input
          return result unless result == :continue
          draw_list if ((Graphics.frame_count rescue 0) % 4).zero?
        end
      ensure
        dispose
      end

      private

      def setup
        @viewport = Viewport.new(0, 0, SCREEN_W, SCREEN_H)
        @viewport.z = 200_000
        @background = Sprite.new(@viewport)
        @background.bitmap = Bitmap.new(SCREEN_W, SCREEN_H)
        @background.bitmap.fill_rect(0, 0, SCREEN_W, SCREEN_H, BG_COLOR)
        @title_sprite = BitmapSprite.new(SCREEN_W, TITLE_H, @viewport)
        @list_sprite = BitmapSprite.new(LIST_W, CONTENT_H, @viewport)
        @detail_sprite = BitmapSprite.new(DETAIL_W, CONTENT_H, @viewport)
        @footer_sprite = BitmapSprite.new(SCREEN_W, FOOTER_H, @viewport)
        @list_sprite.x = LIST_X
        @list_sprite.y = CONTENT_Y
        @detail_sprite.x = DETAIL_X
        @detail_sprite.y = CONTENT_Y
        @footer_sprite.y = SCREEN_H - FOOTER_H
        create_item_icon
        rebuild_filter
      end

      def create_item_icon
        return unless defined?(ItemIconSprite)
        @item_icon = ItemIconSprite.new(
          DETAIL_X + DETAIL_W / 2, CONTENT_Y + 82, nil, @viewport
        )
        @item_icon.z = @viewport.z + 2
        @item_icon.setOffset(PictureOrigin::Center) if defined?(PictureOrigin)
        @item_icon.zoom_x = 1.5
        @item_icon.zoom_y = 1.5
      rescue StandardError
        @item_icon = nil
      end

      def rebuild_filter
        normalized = @query.to_s.strip.downcase
        @items = if normalized.empty?
                   @all_items.dup
                 else
                   @all_items.select do |item|
                     AutosortBag.item_name(item).to_s.downcase.include?(
                       normalized
                     ) || item.to_s.downcase.include?(normalized)
                   end
                 end
        @selected = [[@selected, 0].max, [@items.length - 1, 0].max].min
        @scroll = 0
        ensure_visible
        draw_all
      end

      def draw_all
        draw_title
        draw_list
        draw_details
        draw_footer
      end

      def draw_title
        bitmap = @title_sprite.bitmap
        bitmap.clear
        bitmap.fill_rect(0, 0, SCREEN_W, TITLE_H, TITLE_BG)
        bitmap.fill_rect(0, TITLE_H - 1, SCREEN_W, 1, PANEL_BORDER)
        set_small_font(bitmap)
        draw_text(
          bitmap, 10, 3, SCREEN_W - 20, 26,
          _INTL("ADD ITEM - {1}", @pocket_name), BLUE, 1
        )
      end

      def draw_list
        bitmap = @list_sprite.bitmap
        bitmap.clear
        draw_panel(bitmap, LIST_W, CONTENT_H)
        set_small_font(bitmap)
        visible = @items[@scroll, VISIBLE_ROWS] || []
        if visible.empty?
          draw_text(
            bitmap, LIST_PAD, 94, LIST_W - LIST_PAD * 2, 24,
            _INTL("No matching items."), DIM, 1
          )
          return
        end
        visible.each_with_index do |item, local_index|
          index = @scroll + local_index
          y = LIST_PAD + local_index * ROW_H
          draw_cursor(bitmap, y) if index == @selected
          draw_text(
            bitmap, LIST_PAD + 8, y - 5,
            LIST_W - LIST_PAD * 2 - 16, ROW_H + 2,
            AutosortBag.item_name(item),
            index == @selected ? WHITE : GRAY, 0
          )
        end
      end

      def draw_details
        bitmap = @detail_sprite.bitmap
        bitmap.clear
        draw_panel(bitmap, DETAIL_W, CONTENT_H)
        set_small_font(bitmap)
        item = current_item
        update_item_icon(item)
        if item
          draw_text(
            bitmap, 8, 118, DETAIL_W - 16, 24,
            AutosortBag.item_name(item), WHITE, 1
          )
          draw_text(
            bitmap, 8, 140, DETAIL_W - 16, 20,
            item.to_s, DIM, 1
          )
        end
        draw_text(
          bitmap, 8, CONTENT_H - 73, DETAIL_W - 16, 20,
          _INTL("Search"), DIM, 1
        )
        query_text = @query.empty? ? _INTL("All Items") : @query
        draw_text(
          bitmap, 8, CONTENT_H - 53, DETAIL_W - 16, 20,
          query_text, @query.empty? ? GRAY : GOLD, 1
        )
        draw_text(
          bitmap, 8, CONTENT_H - 33, DETAIL_W - 16, 20,
          _INTL("{1} matches", @items.length), BLUE, 1
        )
      end

      def draw_footer
        bitmap = @footer_sprite.bitmap
        bitmap.clear
        bitmap.fill_rect(0, 0, SCREEN_W, FOOTER_H, TITLE_BG)
        bitmap.fill_rect(0, 0, SCREEN_W, 1, PANEL_BORDER)
        hints = [
          KantoReloaded::HintText.confirm("Select"),
          KantoReloaded::HintText.back("Cancel"),
          KantoReloaded::HintText.action("Search"),
          KantoReloaded::HintText.special("Clear"),
          KantoReloaded::HintText.other("Jump", :pocket)
        ]
        KantoReloaded::HintText.draw_footer(
          bitmap, hints, 8, 5, SCREEN_W - 16,
          :size => 14, :color => WHITE, :height => FOOTER_H,
          :y_offset => -5,
          :hint_entry => KantoReloaded::HintText.other("", "")
        )
      rescue StandardError
        nil
      end

      def handle_input
        mouse_index = update_mouse
        if mouse_index && KantoReloaded::MouseInput.mouse_triggered?
          return choose_current
        end
        wheel = KantoReloaded::MouseInput.wheel_delta
        if wheel != 0
          move_selection(wheel < 0 ? 1 : -1)
        elsif Input.repeat?(Input::UP)
          move_selection(-1)
        elsif Input.repeat?(Input::DOWN)
          move_selection(1)
        elsif Input.repeat?(Input::LEFT)
          move_selection(-5)
        elsif Input.repeat?(Input::RIGHT)
          move_selection(5)
        elsif Input.trigger?(Input::USE)
          return choose_current
        elsif Input.trigger?(Input::ACTION)
          open_search
        elsif Input.const_defined?(:SPECIAL) &&
              Input.trigger?(Input::SPECIAL)
          clear_search
        elsif Input.trigger?(Input::BACK)
          pbPlayCancelSE rescue nil
          return nil
        end
        :continue
      end

      def update_mouse
        position = KantoReloaded::MouseInput.active_position
        return nil unless position
        x = position[0].to_i
        y = position[1].to_i
        return nil unless x.between?(LIST_X, LIST_X + LIST_W - 1)
        return nil unless y.between?(CONTENT_Y + LIST_PAD,
                                     CONTENT_Y + CONTENT_H - LIST_PAD - 1)
        index = @scroll + ((y - CONTENT_Y - LIST_PAD) / ROW_H)
        return nil unless index >= 0 && index < @items.length
        if @selected != index
          @selected = index
          ensure_visible
          pbPlayCursorSE rescue nil
          draw_list
          draw_details
        end
        index
      end

      def move_selection(amount)
        return buzzer if @items.empty?
        old = @selected
        if amount.abs == 1
          @selected = (@selected + amount) % @items.length
        else
          @selected = [[@selected + amount, 0].max, @items.length - 1].min
        end
        return if old == @selected
        ensure_visible
        pbPlayCursorSE rescue nil
        draw_list
        draw_details
      end

      def choose_current
        item = current_item
        return buzzer unless item
        pbPlayDecisionSE rescue nil
        item
      end

      def open_search
        return buzzer unless defined?(pbEnterText)
        value = nil
        with_picker_hidden do
          value = pbEnterText(
            _INTL("Search items?"), 0, 24, @query.to_s
          )
        end
        @query = value.to_s.gsub(/[\r\n\t]/, " ").strip[0, 24]
        @selected = 0
        rebuild_filter
        pbPlayDecisionSE rescue nil
      rescue StandardError => e
        AutosortBag.send(
          :log_exception, "Autosort item search failed", e
        )
        buzzer
      end

      def clear_search
        return buzzer if @query.empty?
        @query = ""
        @selected = 0
        rebuild_filter
        pbPlayDecisionSE rescue nil
      end

      def ensure_visible
        @scroll = @selected if @selected < @scroll
        if @selected >= @scroll + VISIBLE_ROWS
          @scroll = @selected - VISIBLE_ROWS + 1
        end
        max_scroll = [@items.length - VISIBLE_ROWS, 0].max
        @scroll = [[@scroll, 0].max, max_scroll].min
      end

      def current_item
        @items[@selected]
      end

      def update_item_icon(item)
        return unless @item_icon && !@item_icon.disposed?
        @item_icon.item = item
        @item_icon.visible = !item.nil?
      rescue StandardError
        nil
      end

      def draw_panel(bitmap, width, height)
        KantoReloaded::UI::Draw.rounded_rect(
          bitmap, 0, 0, width, height, 5, PANEL_BORDER
        )
        KantoReloaded::UI::Draw.rounded_rect(
          bitmap, 1, 1, width - 2, height - 2, 4, PANEL_BG
        )
      end

      def draw_cursor(bitmap, y)
        pulse = Math.sin(
          (Graphics.frame_count rescue 0) * Math::PI / 20.0
        ) * 0.5 + 0.5
        fill, border = cursor_colors
        alpha = [[fill.alpha.to_i + (pulse * 55).to_i, 255].min, 80].max
        fill = KantoReloaded::UI::Draw.with_alpha(fill, alpha)
        KantoReloaded::UI::Draw.rounded_rect(
          bitmap, LIST_PAD, y + 3, LIST_W - LIST_PAD * 2,
          ROW_H - 2, 4, fill, border
        )
      end

      def cursor_colors
        return KantoReloaded::Options.cursor_colors if
          defined?(KantoReloaded::Options)
        [
          Color.new(100, 160, 220, 160),
          Color.new(60, 120, 180, 220)
        ]
      rescue StandardError
        [
          Color.new(100, 160, 220, 160),
          Color.new(60, 120, 180, 220)
        ]
      end

      def draw_text(bitmap, x, y, width, height, text, color, align = 0)
        KantoReloaded::UI::Draw.plain_text(
          bitmap, x, y, width, height, text, color, align
        )
      end

      def set_small_font(bitmap)
        pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
      end

      def with_picker_hidden
        sprites = [
          @background, @title_sprite, @list_sprite, @detail_sprite,
          @footer_sprite, @item_icon
        ].compact
        visibility = sprites.map { |sprite| sprite.visible rescue true }
        old_z = @viewport.z
        sprites.each { |sprite| sprite.visible = false rescue nil }
        @viewport.z = 0
        Graphics.update
        yield
      ensure
        @viewport.z = old_z rescue 200_000
        sprites.each_with_index do |sprite, index|
          sprite.visible = visibility[index] rescue nil
        end
        Graphics.update rescue nil
      end

      def buzzer
        pbPlayBuzzerSE rescue nil
        :continue
      end

      def dispose
        @item_icon.dispose if @item_icon && !@item_icon.disposed?
        [
          @footer_sprite, @detail_sprite, @list_sprite, @title_sprite,
          @background
        ].compact.each do |sprite|
          sprite.bitmap.dispose if sprite.bitmap && !sprite.bitmap.disposed?
          sprite.dispose unless sprite.disposed?
        rescue StandardError
          nil
        end
        @viewport.dispose if @viewport && !@viewport.disposed?
      rescue StandardError
        nil
      end
    end
  end
end
