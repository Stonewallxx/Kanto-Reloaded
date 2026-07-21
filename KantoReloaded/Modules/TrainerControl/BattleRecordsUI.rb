#==============================================================================
# Kanto Reloaded - Trainer Control Battle Records UI
#==============================================================================

module KantoReloaded
  module TrainerControl
    module BattleRecordsUI
      FILTERS = [
        [:all, "All Trainers"],
        [:regular, "Regular Trainers"],
        [:leader, "Gym Leaders"],
        [:rematch, "Rematches"]
      ].freeze
      SORTS = [
        [:name, "Name"],
        [:battles, "Total Battles"],
        [:win_rate, "Win Rate"],
        [:best_streak, "Best Streak"]
      ].freeze

      class << self
        def open
          return false unless graphics_available?
          KantoReloaded::UI::Modal.with_modal { Scene.new.main }
          true
        rescue StandardError => e
          KantoReloaded::Log.exception(
            "Trainer Records UI failed", e, channel: :trainer_control
          ) if defined?(KantoReloaded::Log)
          false
        ensure
          KantoReloaded::UI::Modal.drain_input if defined?(KantoReloaded::UI::Modal)
        end

        private

        def graphics_available?
          defined?(Graphics) && defined?(Input) && defined?(Viewport) &&
            defined?(BitmapSprite) && defined?(KantoReloaded::ListState)
        end
      end

      class Scene
        SCREEN_W = 512
        SCREEN_H = 384
        HEADER_H = 54
        FOOTER_H = 28
        ROW_H = 24
        LIST_X = 8
        LIST_Y = HEADER_H + 4
        LIST_W = 316
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
        GREEN = Color.new(105, 224, 164)
        RED = Color.new(235, 96, 116)
        GOLD = Color.new(240, 200, 80)

        def initialize
          @filter_index = 0
          @sort_index = 0
          @search_query = ""
        end

        def main
          setup
          loop do
            Graphics.update
            Input.update
            result = handle_input
            return if result == :close
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
          @header_sprite = BitmapSprite.new(SCREEN_W, HEADER_H, @viewport)
          @list_sprite = BitmapSprite.new(LIST_W, LIST_H, @viewport)
          @detail_sprite = BitmapSprite.new(DETAIL_W, LIST_H, @viewport)
          @footer_sprite = BitmapSprite.new(SCREEN_W, FOOTER_H, @viewport)
          @list_sprite.x = LIST_X
          @list_sprite.y = LIST_Y
          @detail_sprite.x = DETAIL_X
          @detail_sprite.y = LIST_Y
          @footer_sprite.y = SCREEN_H - FOOTER_H
          load_rows
          draw_all
        end

        def load_rows(preferred_key = nil)
          selected_key = preferred_key || current_key
          rows = record_and_memory_rows
          rows = apply_filter(rows)
          rows = apply_search(rows)
          rows = apply_sort(rows)
          @state = KantoReloaded::ListState::State.new(
            rows, :visible_rows => VISIBLE_ROWS
          )
          if selected_key
            index = rows.index { |record| record["key"] == selected_key }
            @state.select(index) if index
          end
        end

        def record_and_memory_rows
          KantoReloaded::TrainerControl::BattleRecords.all_records
        end

        def apply_filter(rows)
          filter = FILTERS[@filter_index][0]
          return rows if filter == :all
          rows.select { |record| record["scope"].to_s == filter.to_s }
        end

        def apply_search(rows)
          return rows if @search_query.empty?
          query = @search_query.downcase
          rows.select do |record|
            record["display_name"].to_s.downcase.include?(query) ||
              record["trainer_type"].to_s.downcase.include?(query)
          end
        end

        def apply_sort(rows)
          sort = SORTS[@sort_index][0]
          case sort
          when :battles
            rows.sort_by do |record|
              [-BattleRecords.total_battles(record), record["display_name"].to_s.downcase]
            end
          when :win_rate
            rows.sort_by do |record|
              [-BattleRecords.win_percentage(record), -BattleRecords.total_battles(record),
               record["display_name"].to_s.downcase]
            end
          when :best_streak
            rows.sort_by do |record|
              [-record["best_streak"].to_i, record["display_name"].to_s.downcase]
            end
          else
            rows.sort_by { |record| record["display_name"].to_s.downcase }
          end
        end

        def draw_all
          draw_header
          draw_list
          draw_detail
          draw_footer
        end

        def draw_header
          bitmap = @header_sprite.bitmap
          bitmap.clear
          bitmap.fill_rect(0, 0, SCREEN_W, HEADER_H, BG)
          set_font(bitmap)
          text(bitmap, 8, 0, SCREEN_W - 16, 24, _INTL("TRAINER RECORDS"), BLUE, 1)
          status = _INTL(
            "{1} | Sort: {2}",
            FILTERS[@filter_index][1], SORTS[@sort_index][1]
          )
          status = _INTL("{1} | Search: {2}", status, @search_query) unless @search_query.empty?
          text(bitmap, 8, 25, SCREEN_W - 16, 22, status, GOLD, 1)
          bitmap.fill_rect(0, HEADER_H - 1, SCREEN_W, 1, BORDER)
        end

        def draw_list
          bitmap = @list_sprite.bitmap
          bitmap.clear
          panel(bitmap, LIST_W, LIST_H)
          set_font(bitmap)
          if @state.empty?
            message = @search_query.empty? ?
              _INTL("No trainer records.") : _INTL("No matching records.")
            text(bitmap, 10, 96, LIST_W - 20, 24, message, DIM, 1)
            return
          end
          @state.visible.each_with_index do |record, local|
            index = @state.scroll + local
            y = 6 + local * ROW_H
            cursor(bitmap, y) if index == @state.index
            selected = index == @state.index
            text(
              bitmap, 14, y - 3, LIST_W - 112, ROW_H,
              record["display_name"], selected ? WHITE : GRAY
            )
            summary = _INTL(
              "{1}W {2}L  {3}%",
              record["wins"], record["losses"],
              BattleRecords.win_percentage(record)
            )
            text(bitmap, LIST_W - 112, y - 3, 96, ROW_H,
                 summary, rate_color(record), 2)
          end
        end

        def draw_detail
          bitmap = @detail_sprite.bitmap
          bitmap.clear
          panel(bitmap, DETAIL_W, LIST_H)
          set_font(bitmap)
          record = @state.current
          unless record
            text(bitmap, 8, 95, DETAIL_W - 16, 24,
                 _INTL("Select a record."), DIM, 1)
            return
          end
          text(bitmap, 8, 14, DETAIL_W - 16, 24,
               record["display_name"], WHITE, 1)
          text(bitmap, 8, 38, DETAIL_W - 16, 20,
               scope_name(record["scope"]), BLUE, 1)
          draw_stat(bitmap, 74, _INTL("Wins"), record["wins"], GREEN)
          draw_stat(bitmap, 98, _INTL("Losses"), record["losses"], RED)
          draw_stat(
            bitmap, 122, _INTL("Win Rate"),
            "#{BattleRecords.win_percentage(record)}%", rate_color(record)
          )
          draw_stat(
            bitmap, 146, _INTL("Battles"),
            BattleRecords.total_battles(record), WHITE
          )
          draw_stat(
            bitmap, 170, _INTL("Streak"),
            record["current_streak"], GOLD
          )
          draw_stat(
            bitmap, 194, _INTL("Best"),
            record["best_streak"], GOLD
          )
        end

        def draw_stat(bitmap, y, label, value, color)
          text(bitmap, 12, y, DETAIL_W - 24, 20, label, GRAY)
          text(bitmap, 12, y, DETAIL_W - 24, 20, value.to_s, color, 2)
        end

        def draw_footer
          bitmap = @footer_sprite.bitmap
          bitmap.clear
          bitmap.fill_rect(0, 0, SCREEN_W, FOOTER_H, BG)
          bitmap.fill_rect(0, 0, SCREEN_W, 1, BORDER)
          KantoReloaded::HintText.draw_footer(
            bitmap,
            [
              KantoReloaded::HintText.confirm("Details"),
              KantoReloaded::HintText.back("Back"),
              KantoReloaded::HintText.action("Search"),
              KantoReloaded::HintText.special("Sort"),
              KantoReloaded::HintText.other("Filter", "L/R")
            ],
            8, 4, SCREEN_W - 16,
            :size => 14, :color => WHITE, :height => FOOTER_H,
            :y_offset => -4, :show_hint => false
          )
        end

        def handle_input
          mouse_index = update_mouse
          if mouse_index && KantoReloaded::MouseInput.mouse_triggered?
            open_record_actions
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
            change_filter(-1)
          elsif trigger?(:AUX2)
            change_filter(1)
          elsif trigger?(:ACTION)
            search_records
          elsif trigger?(:SPECIAL)
            change_sort
          elsif Input.trigger?(Input::USE)
            open_record_actions
          elsif Input.trigger?(Input::BACK)
            return :close
          end
          :continue
        end

        def move(amount)
          return unless @state.move(amount)
          pbPlayCursorSE rescue nil
          draw_list
          draw_detail
        end

        def change_filter(amount)
          @filter_index = (@filter_index + amount.to_i) % FILTERS.length
          pbPlayCursorSE rescue nil
          load_rows
          draw_all
        end

        def change_sort
          @sort_index = (@sort_index + 1) % SORTS.length
          pbPlayCursorSE rescue nil
          load_rows
          draw_all
        end

        def search_records
          query = with_scene_hidden do
            pbEnterText(_INTL("Search trainer records"), 0, 32, @search_query)
          end
          return if query.nil?
          @search_query = query.to_s.strip
          pbPlayDecisionSE rescue nil
          load_rows
          draw_all
        rescue StandardError => e
          KantoReloaded::Log.exception(
            "Trainer record search failed", e, channel: :trainer_control
          ) if defined?(KantoReloaded::Log)
        end

        def open_record_actions
          record = @state.current
          return unless record
          result = KantoReloaded::PopupWindow.choice(
            _INTL(
              "{1}\n{2} wins, {3} losses, {4}% win rate.",
              record["display_name"], record["wins"], record["losses"],
              BattleRecords.win_percentage(record)
            ),
            [
              { :label => _INTL("Reset Record"), :value => :reset },
              { :label => _INTL("Back"), :value => :back }
            ],
            :start_index => 1
          )
          reset_selected(record) if result == :reset
          draw_all
        end

        def reset_selected(record)
          return unless KantoReloaded::PopupWindow.confirm(
            _INTL("Reset the record and memory for {1}?", record["display_name"]),
            :default => false
          )
          BattleRecords.delete(record["key"])
          TrainerMemory.delete(record["key"])
          load_rows
          KantoReloaded::Toast.success(_INTL("Trainer record and memory reset."))
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
            draw_list
            draw_detail
          end
          index
        end

        def with_scene_hidden
          visible = @viewport.visible rescue true
          @viewport.visible = false if @viewport
          2.times { Input.update rescue nil }
          yield
        ensure
          @viewport.visible = visible if @viewport
          KantoReloaded::UI::Modal.drain_input
          draw_all if @viewport
          Graphics.update if defined?(Graphics)
        end

        def current_key
          record = @state && @state.current
          record ? record["key"] : nil
        end

        def rate_color(record)
          percentage = BattleRecords.win_percentage(record)
          return GREEN if percentage > 50
          return RED if percentage < 50
          WHITE
        end

        def scope_name(scope)
          case scope.to_s
          when "leader" then _INTL("Gym Leader")
          when "rematch" then _INTL("Rematch")
          else _INTL("Regular Trainer")
          end
        end

        def panel(bitmap, width, height)
          KantoReloaded::UI::Draw.rounded_rect(
            bitmap, 0, 0, width, height, 5, PANEL, BORDER
          )
        end

        def cursor(bitmap, y)
          fill, border = KantoReloaded::Options.cursor_colors
          KantoReloaded::UI::Draw.rounded_rect(
            bitmap, 7, y + 2, LIST_W - 14, ROW_H - 3, 4, fill, border
          )
        rescue StandardError
          nil
        end

        def set_font(bitmap)
          pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
          bitmap.font.size = 15
        end

        def text(bitmap, x, y, width, height, value, color, align = 0)
          KantoReloaded::UI::Draw.plain_text(
            bitmap, x, y, width, height, value.to_s, color, align, 15
          )
        end

        def trigger?(name)
          KantoReloaded::UI::InputRouter.input_triggered?(name)
        rescue StandardError
          false
        end

        def dispose
          [@background, @header_sprite, @list_sprite, @detail_sprite,
           @footer_sprite].each do |sprite|
            next unless sprite
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
end
