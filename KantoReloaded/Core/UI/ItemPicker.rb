#==============================================================================
# Kanto Reloaded Item Picker
#==============================================================================

module KantoReloaded
  module UI
    module ItemPicker
      POCKET_NAMES = {
        1 => "Items",
        2 => "Medicine",
        3 => "Pokeballs",
        4 => "TM/HMs",
        5 => "Berries",
        6 => "Mail",
        7 => "Battle Items",
        8 => "Key Items"
      }.freeze

      class << self
        def pick(options = {})
          return nil unless defined?(GameData::Item)
          Scene.new(options).main
        rescue StandardError => e
          KantoReloaded::Log.exception(
            "Item Picker failed", e, channel: :ui
          ) if defined?(KantoReloaded::Log)
          nil
        end
      end

      class Scene
        SCREEN_W = 512
        SCREEN_H = 384
        TITLE_H = 30
        TABS_H = 24
        FOOTER_H = 28
        ROW_H = 24
        LIST_X = 8
        LIST_Y = TITLE_H + TABS_H + 4
        LIST_W = 322
        LIST_H = SCREEN_H - LIST_Y - FOOTER_H - 4
        DETAIL_X = LIST_X + LIST_W + 8
        DETAIL_W = SCREEN_W - DETAIL_X - 8
        VISIBLE_ROWS = (LIST_H - 12) / ROW_H

        BG = Color.new(18, 22, 34)
        PANEL = Color.new(28, 34, 52)
        BORDER = Color.new(60, 80, 130)
        WHITE = Color.new(255, 255, 255)
        GRAY = Color.new(175, 180, 200)
        DIM = Color.new(105, 110, 135)
        BLUE = Color.new(120, 190, 255)
        GOLD = Color.new(240, 200, 80)

        def initialize(options)
          @options = options.is_a?(Hash) ? options : {}
          @excluded = Array(@options[:exclude]).map { |id| normalize_id(id) }.compact
          @title = (@options[:title] || _INTL("SELECT ITEM")).to_s
          @pocket = [[(@options[:pocket] || 1).to_i, 1].max, 8].min
          @search_query = ""
        end

        def main
          setup
          loop do
            Graphics.update
            Input.update
            @icon.update if @icon && !@icon.disposed?
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
          @viewport.z = 999_999
          @background = Sprite.new(@viewport)
          @background.bitmap = Bitmap.new(SCREEN_W, SCREEN_H)
          @background.bitmap.fill_rect(0, 0, SCREEN_W, SCREEN_H, BG)
          @title_sprite = BitmapSprite.new(SCREEN_W, TITLE_H + TABS_H, @viewport)
          @list_sprite = BitmapSprite.new(LIST_W, LIST_H, @viewport)
          @detail_sprite = BitmapSprite.new(DETAIL_W, LIST_H, @viewport)
          @footer_sprite = BitmapSprite.new(SCREEN_W, FOOTER_H, @viewport)
          @list_sprite.x = LIST_X
          @list_sprite.y = LIST_Y
          @detail_sprite.x = DETAIL_X
          @detail_sprite.y = LIST_Y
          @footer_sprite.y = SCREEN_H - FOOTER_H
          create_icon
          load_rows
          draw_all
        end

        def create_icon
          return unless defined?(ItemIconSprite)
          @icon = ItemIconSprite.new(
            DETAIL_X + DETAIL_W / 2, LIST_Y + 72, nil, @viewport
          )
          @icon.setOffset(PictureOrigin::Center) if defined?(PictureOrigin)
          @icon.zoom_x = 1.5
          @icon.zoom_y = 1.5
        rescue StandardError
          @icon = nil
        end

        def load_rows
          rows = []
          GameData::Item.each do |item|
            next unless item.pocket.to_i == @pocket
            next if @excluded.include?(normalize_id(item.id))
            rows << item
          end
          unless @search_query.empty?
            query = @search_query.downcase
            rows.select! do |item|
              item.name.to_s.downcase.include?(query) ||
                item.id.to_s.downcase.include?(query)
            end
          end
          rows.sort_by! { |item| item.name.to_s.downcase }
          @state = KantoReloaded::ListState::State.new(
            rows, :visible_rows => VISIBLE_ROWS
          )
          refresh_icon
        end

        def draw_all
          draw_header
          draw_list
          draw_detail
          draw_footer
        end

        def draw_header
          bitmap = @title_sprite.bitmap
          bitmap.clear
          bitmap.fill_rect(0, 0, SCREEN_W, TITLE_H + TABS_H, BG)
          set_font(bitmap)
          text(bitmap, 8, 1, SCREEN_W - 16, 24, @title, BLUE, 1)
          bitmap.fill_rect(0, TITLE_H - 1, SCREEN_W, 1, BORDER)
          label = POCKET_NAMES[@pocket] || _INTL("Pocket {1}", @pocket)
          unless @search_query.empty?
            label = _INTL("{1} | Search: {2}", label, @search_query)
          end
          text(bitmap, 8, TITLE_H, SCREEN_W - 16, 22,
               "L  #{label}  R", GOLD, 1)
        end

        def draw_list
          bitmap = @list_sprite.bitmap
          bitmap.clear
          panel(bitmap, LIST_W, LIST_H)
          set_font(bitmap)
          if @state.empty?
            text(bitmap, 10, 90, LIST_W - 20, 24,
                 @search_query.empty? ?
                   _INTL("No available items.") :
                   _INTL("No matching items."),
                 DIM, 1)
            return
          end
          @state.visible.each_with_index do |item, local|
            index = @state.scroll + local
            y = 6 + local * ROW_H
            cursor(bitmap, y) if index == @state.index
            text(bitmap, 14, y - 3, LIST_W - 28, ROW_H,
                 item.name, index == @state.index ? WHITE : GRAY)
          end
        end

        def draw_detail
          bitmap = @detail_sprite.bitmap
          bitmap.clear
          panel(bitmap, DETAIL_W, LIST_H)
          set_font(bitmap)
          item = @state.current
          return unless item
          text(bitmap, 8, 113, DETAIL_W - 16, 24, item.name, WHITE, 1)
          text(bitmap, 8, 135, DETAIL_W - 16, 20,
               POCKET_NAMES[item.pocket.to_i] || "", BLUE, 1)
          lines = KantoReloaded::UI::Draw.wrap_lines(
            bitmap, item.description.to_s, DETAIL_W - 20
          )
          lines[0, 6].each_with_index do |line, index|
            text(bitmap, 10, 165 + index * 18, DETAIL_W - 20, 18,
                 line, GRAY)
          end
        end

        def draw_footer
          bitmap = @footer_sprite.bitmap
          bitmap.clear
          bitmap.fill_rect(0, 0, SCREEN_W, FOOTER_H, BG)
          bitmap.fill_rect(0, 0, SCREEN_W, 1, BORDER)
          KantoReloaded::HintText.draw_footer(
            bitmap,
            [
              KantoReloaded::HintText.confirm("Select"),
              KantoReloaded::HintText.back("Cancel"),
              KantoReloaded::HintText.action("Search"),
              KantoReloaded::HintText.other("Page", :page),
              KantoReloaded::HintText.other("Pocket", "L/R")
            ],
            8, 4, SCREEN_W - 16,
            :size => 14, :color => WHITE, :height => FOOTER_H,
            :y_offset => -4,
            :show_hint => @options.fetch(:show_hint, true)
          )
        end

        def handle_input
          mouse_index = update_mouse
          if mouse_index && KantoReloaded::MouseInput.mouse_triggered?
            return selected_id
          end
          wheel = KantoReloaded::MouseInput.wheel_delta
          if wheel != 0
            move(wheel < 0 ? 1 : -1)
          elsif Input.repeat?(Input::UP)
            move(-1)
          elsif Input.repeat?(Input::DOWN)
            move(1)
          elsif Input.repeat?(Input::LEFT)
            move(-5)
          elsif Input.repeat?(Input::RIGHT)
            move(5)
          elsif trigger?(:AUX1)
            change_pocket(-1)
          elsif trigger?(:AUX2)
            change_pocket(1)
          elsif trigger?(:ACTION)
            search_items
          elsif Input.trigger?(Input::USE)
            return selected_id
          elsif Input.trigger?(Input::BACK)
            return nil
          end
          :continue
        end

        def move(amount)
          if @state.move(amount)
            pbPlayCursorSE if defined?(pbPlayCursorSE)
            refresh_icon
            draw_list
            draw_detail
          end
        end

        def change_pocket(amount)
          @pocket = ((@pocket - 1 + amount) % 8) + 1
          pbPlayCursorSE if defined?(pbPlayCursorSE)
          load_rows
          draw_all
        end

        def search_items
          query = with_picker_hidden do
            pbEnterText(
              _INTL("Search items"), 0, 32, @search_query
            )
          end
          return if query.nil?
          @search_query = query.to_s.strip
          pbPlayDecisionSE if defined?(pbPlayDecisionSE)
          load_rows
          draw_all
        rescue StandardError => e
          KantoReloaded::Log.exception(
            "Item Picker search failed", e, channel: :ui
          ) if defined?(KantoReloaded::Log)
        end

        def with_picker_hidden
          visible = @viewport.visible rescue true
          @viewport.visible = false if @viewport
          drain_action_input
          Graphics.update if defined?(Graphics)
          yield
        ensure
          @viewport.visible = visible if @viewport
          KantoReloaded::UI::Modal.drain_input
          draw_all if @viewport
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

        def update_mouse
          position = KantoReloaded::MouseInput.active_position
          return nil unless position
          x, y = position
          return nil unless x >= LIST_X && x < LIST_X + LIST_W
          return nil unless y >= LIST_Y + 6 && y < LIST_Y + LIST_H - 6
          local = (y - LIST_Y - 6) / ROW_H
          index = @state.scroll + local
          return nil if index < 0 || index >= @state.rows.length
          if index != @state.index
            @state.select(index)
            refresh_icon
            draw_list
            draw_detail
          end
          index
        end

        def selected_id
          item = @state.current
          item ? item.id : nil
        end

        def refresh_icon
          return unless @icon
          item = @state.current
          @icon.item = item ? item.id : nil
        rescue StandardError
          nil
        end

        def panel(bitmap, width, height)
          KantoReloaded::UI::Draw.rounded_rect(
            bitmap, 0, 0, width, height, 5, PANEL, BORDER
          )
        end

        def cursor(bitmap, y)
          fill, border = if defined?(KantoReloaded::Options)
                           KantoReloaded::Options.cursor_colors
                         else
                           [Color.new(70, 110, 190, 170), BORDER]
                         end
          KantoReloaded::UI::Draw.rounded_rect(
            bitmap, 7, y + 2, LIST_W - 14, ROW_H - 3, 4, fill, border
          )
        end

        def set_font(bitmap)
          pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
          bitmap.font.size = 15
        end

        def text(bitmap, x, y, width, height, value, color, align = 0)
          KantoReloaded::UI::Draw.plain_text(
            bitmap, x, y, width, height, value, color, align, 15
          )
        end

        def normalize_id(value)
          data = GameData::Item.try_get(value) rescue nil
          data ? data.id : nil
        end

        def trigger?(name)
          KantoReloaded::UI::InputRouter.input_triggered?(name)
        rescue StandardError
          false
        end

        def dispose
          @icon.visible = false if @icon rescue nil
          @icon.dispose if @icon && !@icon.disposed? rescue nil
          [@background, @title_sprite, @list_sprite, @detail_sprite,
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
            sprite.dispose unless sprite.disposed? rescue nil
          end
          @viewport.dispose if @viewport && !@viewport.disposed?
          Graphics.update if defined?(Graphics)
        rescue StandardError
          nil
        end
      end
    end
  end

  ItemPicker = UI::ItemPicker unless const_defined?(:ItemPicker, false)
end
