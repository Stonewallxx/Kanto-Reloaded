#==============================================================================
# Kanto Reloaded - Reloaded Shop Catalog Editor
#==============================================================================

module KantoReloaded
  module ReloadedShop
    class EditorScene
      SCREEN_W = 512
      SCREEN_H = 384
      TITLE_H = 30
      FOOTER_H = 28
      CONTENT_Y = TITLE_H + 4
      CONTENT_H = SCREEN_H - CONTENT_Y - FOOTER_H - 4
      CATEGORY_X = 6
      CATEGORY_W = 154
      ITEM_X = CATEGORY_X + CATEGORY_W + 6
      ITEM_W = SCREEN_W - ITEM_X - 6
      ROW_H = 22
      PAD = 7
      TEXT_SIZE = 17
      HINT_SIZE = 14
      ITEM_PRICE_X = 216
      ITEM_PRICE_W = ITEM_W - ITEM_PRICE_X - 12
      ITEM_NAME_W = ITEM_PRICE_X - 20
      VISIBLE_ROWS = (CONTENT_H - 25 - PAD) / ROW_H

      BG = Color.new(18, 22, 34)
      PANEL = Color.new(28, 34, 52)
      BORDER = Color.new(60, 80, 130)
      WHITE = Color.new(255, 255, 255)
      GRAY = Color.new(175, 180, 200)
      DIM = Color.new(105, 110, 135)
      BLUE = Color.new(120, 190, 255)
      GOLD = Color.new(240, 200, 80)
      GREEN = Color.new(100, 215, 80)
      RED = Color.new(220, 80, 80)

      def initialize(adapter = nil)
        @adapter = adapter || (PokemonMartAdapter.new if defined?(PokemonMartAdapter))
      end

      def main
        setup
        while @running
          Graphics.update
          Input.update
          handle_input
          draw_lists if ((Graphics.frame_count rescue 0) % 4).zero?
        end
        true
      ensure
        dispose
      end

      private

      def setup
        @running = true
        @focus = :items
        @viewport = Viewport.new(0, 0, SCREEN_W, SCREEN_H)
        @viewport.z = 999_999
        @background = Sprite.new(@viewport)
        @background.bitmap = Bitmap.new(SCREEN_W, SCREEN_H)
        @background.bitmap.fill_rect(0, 0, SCREEN_W, SCREEN_H, BG)
        @title_sprite = BitmapSprite.new(SCREEN_W, TITLE_H, @viewport)
        @category_sprite = BitmapSprite.new(CATEGORY_W, CONTENT_H, @viewport)
        @item_sprite = BitmapSprite.new(ITEM_W, CONTENT_H, @viewport)
        @footer_sprite = BitmapSprite.new(SCREEN_W, FOOTER_H, @viewport)
        @category_sprite.x = CATEGORY_X
        @category_sprite.y = CONTENT_Y
        @item_sprite.x = ITEM_X
        @item_sprite.y = CONTENT_Y
        @footer_sprite.y = SCREEN_H - FOOTER_H
        reload_categories
        draw_all
      end

      def reload_categories(preferred = nil)
        preferred ||= current_category_id
        rows = Catalog.categories
        index = rows.index { |entry| entry["id"] == preferred } || 0
        @category_state = KantoReloaded::ListState::State.new(
          rows, :visible_rows => VISIBLE_ROWS, :index => index
        )
        reload_items
      end

      def reload_items(preferred = nil)
        preferred ||= current_item_id
        category = current_category_id
        rows = Catalog.editor_entries(@adapter).select do |entry|
          entry[:category] == category
        end.sort_by { |entry| [entry[:order].to_i, entry[:name].to_s.downcase] }
        index = rows.index { |entry| entry[:id] == preferred } || 0
        @item_state = KantoReloaded::ListState::State.new(
          rows, :visible_rows => VISIBLE_ROWS, :index => index
        )
      end

      def draw_all
        draw_title
        draw_lists
        draw_footer
      end

      def draw_title
        bitmap = @title_sprite.bitmap
        bitmap.clear
        bitmap.fill_rect(0, 0, SCREEN_W, TITLE_H, BG)
        bitmap.fill_rect(0, TITLE_H - 1, SCREEN_W, 1, BORDER)
        set_font(bitmap)
        text(bitmap, 8, 0, SCREEN_W - 16, 25,
             _INTL("RELOADED SHOP CATALOG EDITOR"), BLUE, 1)
      end

      def draw_lists
        draw_categories
        draw_items
      end

      def draw_categories
        bitmap = @category_sprite.bitmap
        bitmap.clear
        panel(bitmap, CATEGORY_W, CONTENT_H)
        set_font(bitmap)
        text(bitmap, PAD, 0, CATEGORY_W - PAD * 2, 22,
             _INTL("CATEGORIES"), @focus == :categories ? BLUE : DIM, 1)
        @category_state.visible.each_with_index do |entry, local|
          index = @category_state.scroll + local
          y = 25 + local * ROW_H
          cursor(bitmap, y, CATEGORY_W) if @focus == :categories &&
                                          index == @category_state.index
          color = index == @category_state.index ? WHITE : GRAY
          text(bitmap, 12, y - 4, CATEGORY_W - 24, ROW_H,
               fit(bitmap, entry["name"], CATEGORY_W - 26), color)
        end
      end

      def draw_items
        bitmap = @item_sprite.bitmap
        bitmap.clear
        panel(bitmap, ITEM_W, CONTENT_H)
        set_font(bitmap)
        text(bitmap, PAD, 0, ITEM_W - PAD * 2, 22,
             _INTL("SHOP CONTENTS"), @focus == :items ? BLUE : DIM, 1)
        if @item_state.empty?
          text(bitmap, 12, 90, ITEM_W - 24, 24,
               _INTL("No items in this category."), DIM, 1)
          return
        end
        @item_state.visible.each_with_index do |entry, local|
          index = @item_state.scroll + local
          y = 25 + local * ROW_H
          cursor(bitmap, y, ITEM_W) if @focus == :items &&
                                      index == @item_state.index
          marker = entry[:hidden] ? "- " : (entry[:enabled] ? "" : "x ")
          color = entry[:hidden] ? RED : (entry[:enabled] ? WHITE : DIM)
          text(bitmap, 12, y - 5, ITEM_NAME_W, ROW_H,
               fit(bitmap, "#{marker}#{entry[:name]}", ITEM_NAME_W - 3), color)
          text(bitmap, ITEM_PRICE_X, y - 5, ITEM_PRICE_W, ROW_H,
               _INTL("${1}", formatted(entry[:buy_price])), GOLD, 2)
        end
      end

      def draw_footer
        bitmap = @footer_sprite.bitmap
        bitmap.clear
        bitmap.fill_rect(0, 0, SCREEN_W, FOOTER_H, BG)
        bitmap.fill_rect(0, 0, SCREEN_W, 1, BORDER)
        hints = [
          KantoReloaded::HintText.confirm("Actions"),
          KantoReloaded::HintText.back("Exit"),
          KantoReloaded::HintText.action("Add"),
          KantoReloaded::HintText.other("Panel", :pocket)
        ]
        KantoReloaded::HintText.draw_footer(
          bitmap, hints, 8, 0, SCREEN_W - 16,
          :size => HINT_SIZE, :color => WHITE, :height => FOOTER_H,
          :y_offset => 0, :show_hint => false
        )
      end

      def handle_input
        update_mouse
        wheel = KantoReloaded::MouseInput.wheel_delta
        if wheel != 0
          move_selection(wheel < 0 ? 1 : -1)
        elsif Input.repeat?(Input::UP)
          move_selection(-1)
        elsif Input.repeat?(Input::DOWN)
          move_selection(1)
        elsif Input.trigger?(Input::LEFT)
          change_focus(:categories)
        elsif Input.trigger?(Input::RIGHT)
          change_focus(:items)
        elsif Input.trigger?(Input::ACTION)
          @focus == :categories ? add_category : add_item
        elsif Input.trigger?(Input::USE)
          @focus == :categories ? category_actions : item_actions
        elsif Input.trigger?(Input::BACK)
          pbPlayCloseMenuSE if defined?(pbPlayCloseMenuSE)
          @running = false
        end
      end

      def update_mouse
        position = KantoReloaded::MouseInput.active_position
        return unless position
        x, y = position
        return unless y >= CONTENT_Y + 25 && y < CONTENT_Y + CONTENT_H - PAD
        if x >= CATEGORY_X && x < CATEGORY_X + CATEGORY_W
          @focus = :categories
          local = (y - CONTENT_Y - 25) / ROW_H
          index = @category_state.scroll + local
          if index >= 0 && index < @category_state.rows.length
            changed = index != @category_state.index
            @category_state.select(index)
            reload_items if changed
            category_actions if KantoReloaded::MouseInput.mouse_triggered?
          end
        elsif x >= ITEM_X && x < ITEM_X + ITEM_W
          @focus = :items
          local = (y - CONTENT_Y - 25) / ROW_H
          index = @item_state.scroll + local
          if index >= 0 && index < @item_state.rows.length
            @item_state.select(index)
            item_actions if KantoReloaded::MouseInput.mouse_triggered?
          end
        end
        draw_lists
      end

      def move_selection(amount)
        state = @focus == :categories ? @category_state : @item_state
        return unless state.move(amount)
        pbPlayCursorSE if defined?(pbPlayCursorSE)
        reload_items if @focus == :categories
        draw_lists
      end

      def change_focus(value)
        return if @focus == value
        @focus = value
        pbPlayCursorSE if defined?(pbPlayCursorSE)
        draw_all
      end

      def category_actions
        category = @category_state.current
        return unless category
        action = KantoReloaded::PopupWindow.choice(
          category["name"],
          [
            { :label => _INTL("Rename"), :value => :rename },
            { :label => _INTL("Move Up"), :value => :up },
            { :label => _INTL("Move Down"), :value => :down },
            { :label => _INTL("Delete Category"), :value => :delete }
          ]
        )
        case action
        when :rename then rename_category(category)
        when :up
          Catalog.move_category(category["id"], -1)
          reload_categories(category["id"])
        when :down
          Catalog.move_category(category["id"], 1)
          reload_categories(category["id"])
        when :delete then delete_category(category)
        end
        draw_all
      end

      def add_category
        name = with_editor_hidden do
          pbEnterText(_INTL("Category name?"), 1, 24, "")
        end
        id = Catalog.add_category(name)
        if id
          reload_categories(id)
          KantoReloaded::Toast.success(_INTL("Category added."))
        end
        draw_all
      rescue StandardError
        nil
      end

      def rename_category(category)
        name = with_editor_hidden do
          pbEnterText(
            _INTL("Category name?"), 1, 24, category["name"]
          )
        end
        Catalog.rename_category(category["id"], name)
        reload_categories(category["id"])
      rescue StandardError
        nil
      end

      def delete_category(category)
        return unless KantoReloaded::PopupWindow.confirm(
          _INTL("Delete {1}? Its items will move to another category.",
                category["name"]), :default => false
        )
        if Catalog.remove_category(category["id"])
          reload_categories
          KantoReloaded::Toast.success(_INTL("Category deleted."))
        else
          KantoReloaded::Toast.warning(
            _INTL("The final category cannot be deleted.")
          )
        end
      end

      def item_actions
        item = @item_state.current
        return unless item
        visibility_label = item[:enabled] ?
          _INTL("Disable Item") : _INTL("Enable Item")
        remove_label = item[:hidden] ?
          _INTL("Restore Item") : _INTL("Remove Item")
        action = KantoReloaded::PopupWindow.choice(
          item[:name],
          [
            { :label => _INTL("Set Buy Price"), :value => :buy },
            { :label => _INTL("Set Sell Price"), :value => :sell },
            { :label => _INTL("Move Category"), :value => :category },
            { :label => visibility_label, :value => :enabled },
            { :label => _INTL("Move Up"), :value => :up },
            { :label => _INTL("Move Down"), :value => :down },
            { :label => remove_label, :value => :remove }
          ]
        )
        case action
        when :buy then set_price(item, :buy_price)
        when :sell then set_price(item, :sell_price)
        when :category then move_item_category(item)
        when :enabled
          Catalog.update_item(item[:id], "enabled" => !item[:enabled])
        when :up then move_item(item, -1)
        when :down then move_item(item, 1)
        when :remove
          item[:hidden] ? Catalog.restore_item(item[:id]) :
            remove_item(item)
        end
        reload_items(item[:id])
        draw_all
      end

      def add_item
        excluded = Catalog.editor_entries(@adapter).map { |entry| entry[:id] }
        item = with_editor_hidden do
          KantoReloaded::ItemPicker.pick(
            :title => _INTL("ADD SHOP ITEM"), :exclude => excluded,
            :show_hint => false
          )
        end
        return unless item
        Catalog.add_item(item, current_category_id)
        reload_items(item)
        KantoReloaded::Toast.success(_INTL("Item added to RLD Shop."))
        draw_all
      end

      def set_price(item, field)
        current = item[field].to_i
        label = field == :buy_price ? _INTL("Buy Price") : _INTL("Sell Price")
        value = KantoReloaded::NumberPicker.open(
          label,
          :label => item[:name],
          :value_prefix => "$",
          :min => 0,
          :max => 9_999_999,
          :initial => current,
          :digits => 7,
          :width => 340
        )
        Catalog.update_item(item[:id], field => value) unless value.nil?
      end

      def move_item_category(item)
        rows = Catalog.categories.map do |category|
          { :label => category["name"], :value => category["id"] }
        end
        category = KantoReloaded::PopupWindow.choice(
          _INTL("Move {1}", item[:name]), rows
        )
        return unless category.is_a?(String)
        Catalog.update_item(
          item[:id], "category" => category,
          "order" => Catalog.editor_entries(@adapter).count {
            |entry| entry[:category] == category
          }
        )
        reload_categories(category)
      end

      def move_item(item, amount)
        rows = @item_state.rows.dup
        index = rows.index { |entry| entry[:id] == item[:id] }
        return unless index
        target = [[index + amount, 0].max, rows.length - 1].min
        return if target == index
        row = rows.delete_at(index)
        rows.insert(target, row)
        rows.each_with_index do |entry, order|
          Catalog.update_item(entry[:id], "order" => order)
        end
      end

      def remove_item(item)
        return unless KantoReloaded::PopupWindow.confirm(
          _INTL("Remove {1} from RLD Shop?", item[:name]),
          :default => false
        )
        Catalog.remove_item(item[:id])
      end

      def current_category_id
        category = @category_state && @category_state.current
        category ? category["id"] : nil
      end

      def current_item_id
        item = @item_state && @item_state.current
        item ? item[:id] : nil
      end

      def panel(bitmap, width, height)
        KantoReloaded::UI::Draw.rounded_rect(
          bitmap, 0, 0, width, height, 5, PANEL, BORDER
        )
      end

      def cursor(bitmap, y, width)
        fill, border = if defined?(KantoReloaded::Options)
                         KantoReloaded::Options.cursor_colors
                       else
                         [Color.new(60, 105, 185, 175), BORDER]
                       end
        KantoReloaded::UI::Draw.rounded_rect(
          bitmap, 5, y + 1, width - 10, ROW_H - 2, 4, fill, border
        )
      end

      def set_font(bitmap)
        pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
        bitmap.font.size = TEXT_SIZE
      end

      def text(bitmap, x, y, width, height, value, color, align = 0)
        KantoReloaded::UI::Draw.plain_text(
          bitmap, x, y, width, height, value, color, align, TEXT_SIZE
        )
      end

      def with_editor_hidden
        visible = @viewport.visible rescue true
        @viewport.visible = false if @viewport
        drain_action_input
        Graphics.update if defined?(Graphics)
        yield
      ensure
        @viewport.visible = visible if @viewport
        KantoReloaded::UI::Modal.drain_input
        draw_all if @running
        Graphics.update if defined?(Graphics)
      end

      def drain_action_input
        2.times { Input.update rescue nil }
        30.times do
          held = defined?(Input::ACTION) &&
                 (Input.press?(Input::ACTION) rescue false)
          break unless held
          Graphics.update rescue nil
          Input.update rescue nil
        end
      rescue StandardError
        nil
      end

      def fit(bitmap, value, width)
        result = value.to_s
        return result if bitmap.text_size(result).width <= width
        result = result[0...-1] while result.length > 1 &&
          bitmap.text_size("#{result}...").width > width
        "#{result}..."
      rescue StandardError
        value.to_s
      end

      def formatted(value)
        value.to_i.to_s_formatted
      rescue StandardError
        value.to_i.to_s
      end

      def dispose
        [@background, @title_sprite, @category_sprite, @item_sprite,
         @footer_sprite].each do |sprite|
          next unless sprite
          sprite.visible = false rescue nil
          begin
            if sprite.bitmap && !sprite.bitmap.disposed?
              sprite.bitmap.clear
              sprite.bitmap.dispose
            end
          rescue StandardError
            nil
          end
          begin
            sprite.dispose unless sprite.disposed?
          rescue StandardError
            nil
          end
        end
        begin
          @viewport.dispose if @viewport && !@viewport.disposed?
        rescue StandardError
          nil
        end
        Graphics.update if defined?(Graphics)
      rescue StandardError
        nil
      end
    end
  end
end
