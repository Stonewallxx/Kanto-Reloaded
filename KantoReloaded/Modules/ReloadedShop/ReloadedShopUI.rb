#==============================================================================
# Kanto Reloaded - Reloaded Mart Purchase UI
#==============================================================================
# This scene intentionally mirrors Hoenn Reloaded's ReloadedMartBuyScene.
# KIF catalog and transaction behavior remain owned by the KR backend.
#==============================================================================

module KantoReloaded
  module ReloadedShop
    class BuyScene
      SW = 512
      SH = 384
      TITLE_H = 24
      POCKET_H = 22
      FOOTER_H = 22
      INFO_H = 112
      PAD = 8
      LIST_Y = TITLE_H + POCKET_H
      LIST_H = SH - TITLE_H - POCKET_H - INFO_H - FOOTER_H
      ROW_H = 24

      BG_COLOR = Color.new(18, 22, 34, 255)
      PANEL_BG = Color.new(28, 34, 52)
      PANEL_BORDER = Color.new(60, 80, 130)
      ROW_HOVER = Color.new(36, 44, 68, 255)
      WHITE = Color.new(255, 255, 255)
      GRAY = Color.new(175, 180, 200)
      DIM = Color.new(105, 110, 135)
      SHADOW = Color.new(10, 12, 22)
      GOLD = Color.new(240, 200, 80)
      GREEN = Color.new(100, 215, 80)
      RED = Color.new(220, 80, 80)
      BLUE = Color.new(120, 190, 255)
      FOOTER_BG = Color.new(20, 24, 40)
      POCKET_BG = Color.new(25, 30, 48)
      INFO_BG = Color.new(22, 28, 46)
      INFO_BORDER = Color.new(55, 75, 125)
      SEP = Color.new(50, 65, 110)

      SORT_MODES = [:name, :price_low, :price_high, :custom].freeze
      MONEY_ANIMATION_SECONDS = 0.45
      QUANTITY_ANIMATION_SECONDS = 0.45

      @@last_pocket_index = 0
      @@last_entry_index = 0
      @@last_sort_mode = 0
      @@last_quick_buy = false

      def initialize(stock, adapter)
        @stock = Array(stock)
        @adapter = adapter
        @pockets = []
        @pocket_index = @@last_pocket_index
        @entry_index = @@last_entry_index
        @scroll = 0
        @sort_index = @@last_sort_mode
        @quick_buy = @@last_quick_buy
        @money_display = money
        @money_start = money
        @money_target = money
        @money_frame = 0
        @money_duration = 0
        @qty_display = 0.0
        @qty_target = 0
        @qty_start = 0.0
        @qty_frame = 0
        @qty_duration = 0
        @banner_offset = 0.0
        @cursor_redraw_frame = 0
        @info_scroll = 0
        @last_mx = nil
        @last_my = nil
      end

      def main
        start_scene
        return false if @pockets.empty?
        loop do
          Graphics.update
          Input.update
          @icon_sprite.update if @icon_sprite && !@icon_sprite.disposed?
          tick_money_anim
          tick_qty_anim
          tick_banner
          tick_cursor
          handle_category_input
          handle_entry_input
          handle_mode_input
          handle_mouse
          if hint_triggered?
            show_hint_popup
          elsif Input.trigger?(Input::USE)
            purchase_current
          elsif Input.trigger?(Input::BACK)
            pbPlayCancelSE if defined?(pbPlayCancelSE)
            remember_cursor
            break
          end
        end
        true
      ensure
        end_scene
      end

      private

      def start_scene
        Graphics.freeze
        setup_sprites
        rebuild_pockets
        if @pockets.empty?
          draw_all
          Graphics.transition(8)
          KantoReloaded::PopupWindow.message(
            _INTL("The Reloaded Mart has nothing in stock right now.")
          )
          return
        end
        @pocket_index = clamp(@pocket_index, 0, @pockets.length - 1)
        entries = current_entries
        @entry_index = clamp(@entry_index, 0, [entries.length - 1, 0].max)
        @list_state = KantoReloaded::ListState::State.new(
          entries,
          :visible_rows => rows_per_page,
          :index => @entry_index,
          :wrap => true
        )
        sync_list_state
        snap_quantity
        draw_all
        Graphics.transition(8)
      end

      def end_scene
        remember_cursor
        Graphics.freeze
        teardown
        Graphics.transition(8)
      rescue StandardError
        teardown
      end

      def setup_sprites
        @viewport = Viewport.new(0, 0, SW, SH)
        @viewport.z = 100_000
        @bg_sprite = Sprite.new(@viewport)
        @bg_sprite.bitmap = Bitmap.new(SW, SH)
        @bg_sprite.bitmap.fill_rect(0, 0, SW, SH, BG_COLOR)
        @title_sprite = new_sprite(0, 0, SW, TITLE_H)
        @pocket_sprite = new_sprite(0, TITLE_H, SW, POCKET_H)
        @list_sprite = new_sprite(0, LIST_Y, SW, LIST_H)
        @info_sprite = new_sprite(0, LIST_Y + LIST_H, SW, INFO_H)
        @footer_sprite = new_sprite(0, SH - FOOTER_H, SW, FOOTER_H)
        @icon_sprite = ItemIconSprite.new(
          SW - PAD - 48, LIST_Y + LIST_H + 52, nil, @viewport
        ) rescue nil
        if @icon_sprite
          @icon_sprite.z = 20
          @icon_sprite.zoom_x = 1.5
          @icon_sprite.zoom_y = 1.5
        end
      end

      def new_sprite(x, y, width, height)
        sprite = Sprite.new(@viewport)
        sprite.z = 10
        sprite.x = x
        sprite.y = y
        sprite.bitmap = Bitmap.new(width, [height, 1].max)
        sprite
      end

      def teardown
        [@footer_sprite, @info_sprite, @list_sprite, @pocket_sprite,
         @title_sprite, @bg_sprite].each do |sprite|
          next unless sprite
          sprite.bitmap.dispose if sprite.bitmap && !sprite.bitmap.disposed?
          sprite.dispose unless sprite.disposed?
        end
        @icon_sprite.dispose if @icon_sprite && !@icon_sprite.disposed?
        @viewport.dispose if @viewport && !@viewport.disposed?
        @viewport = nil
      rescue StandardError
        nil
      end

      def rebuild_pockets(selected_id = nil)
        selected_id ||= selected_entry && selected_entry[:id]
        all_rows = Catalog.entries(@stock, @adapter)
        categories = Catalog.categories
        @pockets = categories.each_with_object([]) do |category, groups|
          rows = all_rows.select { |row| row[:category] == category["id"] }
          next if rows.empty?
          groups << {
            :id => category["id"],
            :name => category["name"].to_s.upcase,
            :entries => sort_entries(rows)
          }
        end
        @pocket_index = clamp(@pocket_index, 0, [@pockets.length - 1, 0].max)
        entries = current_entries
        selected_index = entries.index { |entry| entry[:id] == selected_id }
        @entry_index = selected_index || clamp(
          @entry_index, 0, [entries.length - 1, 0].max
        )
        @list_state = KantoReloaded::ListState::State.new(
          entries,
          :visible_rows => rows_per_page,
          :index => @entry_index,
          :wrap => true
        )
        sync_list_state
      end

      def sort_entries(rows)
        favorites, standard = rows.partition { |row| Catalog.favorite?(row[:id]) }
        sorter = proc do |source|
          case SORT_MODES[@sort_index]
          when :price_low
            source.sort_by { |row| [row[:buy_price].to_i, row[:name].to_s.downcase] }
          when :price_high
            source.sort_by { |row| [-row[:buy_price].to_i, row[:name].to_s.downcase] }
          when :custom
            source.sort_by { |row| [row[:order].to_i, row[:name].to_s.downcase] }
          else
            source.sort_by { |row| row[:name].to_s.downcase }
          end
        end
        sorter.call(favorites) + sorter.call(standard)
      end

      def current_entries
        return [] if @pockets.empty?
        @pockets[@pocket_index][:entries] || []
      end

      def selected_entry
        current_entries[@entry_index]
      end

      def rows_per_page
        (LIST_H / ROW_H).floor
      end

      def sync_list_state
        return unless @list_state
        @entry_index = @list_state.index
        @scroll = @list_state.scroll
      end

      def reset_entry_state(index = 0)
        @list_state = KantoReloaded::ListState::State.new(
          current_entries,
          :visible_rows => rows_per_page,
          :index => index,
          :wrap => true
        )
        sync_list_state
        @info_scroll = 0
        snap_quantity
      end

      def remember_cursor
        @@last_pocket_index = @pocket_index
        @@last_entry_index = @entry_index
        @@last_sort_mode = @sort_index
        @@last_quick_buy = @quick_buy
      end

      def snap_quantity
        @qty_display = selected_entry ? quantity(selected_entry) : 0
        @qty_target = @qty_display
        @qty_start = @qty_display
        @qty_frame = 0
        @qty_duration = 0
        refresh_icon
      end

      def handle_category_input
        return if @pockets.empty?
        if Input.repeat?(Input::LEFT)
          change_pocket(-1)
        elsif Input.repeat?(Input::RIGHT)
          change_pocket(1)
        end
      end

      def change_pocket(amount)
        pbPlayCursorSE if defined?(pbPlayCursorSE)
        @pocket_index = (@pocket_index + amount) % @pockets.length
        reset_entry_state
        draw_pocket_nav
        draw_list
        draw_info
      end

      def handle_entry_input
        return if current_entries.empty? || !@list_state
        moved = false
        moved = @list_state.move(-1) if Input.repeat?(Input::UP)
        moved = @list_state.move(1) if Input.repeat?(Input::DOWN)
        return unless moved
        pbPlayCursorSE if defined?(pbPlayCursorSE)
        sync_list_state
        @info_scroll = 0
        snap_quantity
        draw_list
        draw_info
      end

      def handle_mode_input
        if trigger?(:AUX1)
          selected_id = selected_entry && selected_entry[:id]
          pbPlayCursorSE if defined?(pbPlayCursorSE)
          @sort_index = (@sort_index + 1) % SORT_MODES.length
          rebuild_pockets(selected_id)
          snap_quantity
          draw_content
        elsif trigger?(:AUX2)
          pbPlayCursorSE if defined?(pbPlayCursorSE)
          @quick_buy = !@quick_buy
          draw_footer
        elsif Input.trigger?(Input::ACTION)
          entry = selected_entry
          return unless entry
          Catalog.toggle_favorite(entry[:id])
          rebuild_pockets(entry[:id])
          snap_quantity
          draw_content
        end
      end

      def handle_mouse
        mx, my = KantoReloaded::MouseInput.active_position
        wheel = KantoReloaded::MouseInput.wheel_delta
        if wheel != 0
          if my && my >= LIST_Y + LIST_H && my < SH - FOOTER_H
            scroll_info(wheel < 0 ? 1 : -1)
          else
            move_from_wheel(wheel < 0 ? 1 : -1)
          end
          return
        end
        return unless mx && my
        clicked = KantoReloaded::MouseInput.mouse_triggered?
        if my >= TITLE_H && my < TITLE_H + POCKET_H && clicked
          change_pocket(mx < SW / 2 ? -1 : 1)
          return
        end
        if my >= LIST_Y && my < LIST_Y + LIST_H
          index = @scroll + ((my - LIST_Y) / ROW_H).floor
          if index >= 0 && index < current_entries.length &&
             index != @entry_index
            @list_state.select(index)
            sync_list_state
            @info_scroll = 0
            snap_quantity
            draw_list
            draw_info
          end
          purchase_current if clicked && index == @entry_index
        elsif my >= SH - FOOTER_H && clicked && controls_mouse_at?(mx, my)
          show_hint_popup
        end
      end

      def move_from_wheel(amount)
        return unless @list_state && @list_state.move(amount)
        pbPlayCursorSE if defined?(pbPlayCursorSE)
        sync_list_state
        @info_scroll = 0
        snap_quantity
        draw_list
        draw_info
      end

      def scroll_info(amount)
        entry = selected_entry
        return unless entry
        max_scroll = info_scroll_max(entry)
        previous = @info_scroll
        @info_scroll = clamp(@info_scroll + amount, 0, max_scroll)
        return if previous == @info_scroll
        pbPlayCursorSE if defined?(pbPlayCursorSE)
        draw_info
      end

      def purchase_current
        entry = selected_entry
        return buzzer unless entry
        maximum = max_quantity(entry)
        if maximum <= 0
          message = entry[:buy_price].to_i > money ?
            _INTL("You don't have enough money.") :
            _INTL("There isn't enough room in the Bag.")
          return display_error(message)
        end
        quantity_to_buy = if @quick_buy
                            maximum
                          elsif maximum == 1
                            1
                          else
                            KantoReloaded::NumberPicker.quantity(
                              _INTL("Choose Quantity"),
                              :label => entry[:name],
                              :min => 1,
                              :max => maximum,
                              :initial => 1,
                              :step => 1,
                              :large_step => 10,
                              :wrap => true,
                              :show_max_label => true,
                              :allow_max_shortcut => true,
                              :unit_price => entry[:buy_price].to_i,
                              :show_unit_price => true,
                              :currency_formatter => proc { |value|
                                value.to_i <= 0 ?
                                  _INTL("FREE") :
                                  _INTL("${1}", formatted(value))
                              },
                              :preview_color => proc { |total, _quantity|
                                total.to_i <= 0 ? GREEN : RED
                              }
                            )
                          end
        return unless quantity_to_buy && quantity_to_buy > 0
        total = entry[:buy_price].to_i * quantity_to_buy
        if ReloadedShop.confirm_purchases?
          confirmed = KantoReloaded::NumberPicker.confirm(
            _INTL("Confirm Purchase?"),
            :label => entry[:name],
            :min => 1,
            :max => quantity_to_buy,
            :initial => quantity_to_buy,
            :value_prefix => "x",
            :unit_price => entry[:buy_price].to_i,
            :show_unit_price => true,
            :preview => proc { |_value| total },
            :currency_formatter => proc { |value|
              value.to_i <= 0 ?
                _INTL("FREE") :
                _INTL("${1}", formatted(value))
            },
            :preview_color => proc { |amount, _value|
              amount.to_i <= 0 ? GREEN : RED
            },
            :default => true
          )
          return unless confirmed
        end
        complete_purchase(entry, quantity_to_buy, total)
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Reloaded Mart purchase failed", e, channel: :modules
        ) if defined?(KantoReloaded::Log)
        display_error(_INTL("The transaction could not be completed."))
      end

      def complete_purchase(entry, requested, total)
        return display_error(_INTL("You don't have enough money.")) if money < total
        added = 0
        requested.times do
          break unless @adapter.addItem(entry[:runtime_id])
          added += 1
        end
        if added != requested
          added.times { @adapter.removeItem(entry[:runtime_id]) }
          return display_error(_INTL("There isn't enough room in the Bag."))
        end
        @adapter.setMoney(money - total)
        award_premier_ball(entry, requested)
        pbSEPlay("Mart buy item") if defined?(pbSEPlay)
        play_purchase_animation(entry[:id])
      end

      def award_premier_ball(entry, bought)
        data = GameData::Item.try_get(entry[:id]) rescue nil
        return unless data && data.is_poke_ball? && bought.to_i >= 10
        bonus = GameData::Item.try_get(:PREMIERBALL) rescue nil
        @adapter.addItem(bonus.id) if bonus
      rescue StandardError
        nil
      end

      def max_quantity(entry)
        return 0 unless entry
        data = GameData::Item.try_get(entry[:id]) rescue nil
        return 0 unless data
        return 1 if data.is_important? && quantity(entry) <= 0
        maximum = defined?(Settings::BAG_MAX_PER_SLOT) ?
          Settings::BAG_MAX_PER_SLOT : 999
        maximum = [maximum, maximum - quantity(entry)].min unless
          data.is_important?
        price = entry[:buy_price].to_i
        maximum = [maximum, money / price].min if price > 0
        maximum = [maximum, 0].max
        maximum
      rescue StandardError
        0
      end

      def play_purchase_animation(selected_id)
        fps = (Graphics.frame_rate rescue 40).to_f
        @money_start = @money_display
        @money_target = money
        @money_frame = 0
        @money_duration = (fps * MONEY_ANIMATION_SECONDS).round
        rebuild_pockets(selected_id)
        @qty_start = @qty_display
        @qty_target = selected_entry ? quantity(selected_entry) : 0
        @qty_frame = 0
        @qty_duration = (fps * QUANTITY_ANIMATION_SECONDS).round
        draw_content
        [@money_duration, @qty_duration].max.times do
          Graphics.update
          Input.update
          tick_money_anim
          tick_qty_anim
          tick_banner
          tick_cursor
        end
        @money_display = @money_target
        @qty_display = @qty_target
        draw_content
      end

      def draw_all
        draw_title
        draw_content
      end

      def draw_content
        draw_pocket_nav
        draw_list
        draw_info
        draw_footer
      end

      def draw_title
        bitmap = @title_sprite.bitmap
        bitmap.clear
        bitmap.fill_rect(0, 0, SW, TITLE_H, FOOTER_BG)
        banner = banner_text
        return if banner.empty?
        pbSetSmallFont(bitmap)
        bitmap.font.size = 16
        x = PAD - @banner_offset.to_i
        width = bitmap.text_size(banner).width + 80
        while x < SW
          no_shadow_text(bitmap, x, 6, width, 16, banner, GOLD)
          x += width
        end
      end

      def draw_pocket_nav
        bitmap = @pocket_sprite.bitmap
        bitmap.clear
        bitmap.fill_rect(0, 0, SW, POCKET_H, POCKET_BG)
        bitmap.fill_rect(0, POCKET_H - 1, SW, 1, SEP)
        return if @pockets.empty?
        pbSetSmallFont(bitmap)
        pocket = @pockets[@pocket_index]
        shadow_text(bitmap, PAD, -1, 102, POCKET_H, "RLD Mart", BLUE)
        shadow_text(
          bitmap, 102, -1, SW - 204, POCKET_H,
          "#{pocket[:name]}  (#{@pocket_index + 1}/#{@pockets.length})",
          WHITE, 1
        )
        shadow_text(
          bitmap, 0, -1, SW - PAD, POCKET_H,
          _INTL("${1}", formatted(@money_display)), GREEN, 2
        )
      end

      def draw_list
        bitmap = @list_sprite.bitmap
        bitmap.clear
        bitmap.fill_rect(0, 0, SW, LIST_H, PANEL_BG)
        entries = current_entries
        return if entries.empty?
        pbSetSmallFont(bitmap)
        entries[@scroll, rows_per_page].to_a.each_with_index do |entry, index|
          real_index = @scroll + index
          y = index * ROW_H
          selected = real_index == @entry_index
          if selected
            draw_cursor(bitmap, PAD, y + 2, SW - PAD * 2, ROW_H - 4)
          else
            bitmap.fill_rect(
              PAD, y + 2, SW - PAD * 2, ROW_H - 4, ROW_HOVER
            )
          end
          draw_entry_row(bitmap, entry, y, selected)
        end
        draw_scrollbar(bitmap, entries.length, rows_per_page)
        bitmap.fill_rect(0, LIST_H - 1, SW, 1, SEP)
      end

      def draw_entry_row(bitmap, entry, y, selected)
        favorite = Catalog.favorite?(entry[:id])
        name = "#{favorite ? '* ' : ''}#{entry[:name]}"
        color = selected ? WHITE : (favorite ? GOLD : GRAY)
        price = entry[:buy_price].to_i
        price_text = price <= 0 ? "FREE" : _INTL("${1}", formatted(price))
        price_color = price <= 0 ? GREEN : (selected ? GOLD : GRAY)
        right = SW - PAD - 4
        price_width = bitmap.text_size(price_text).width
        name_width = [right - price_width - PAD - 18, 24].max
        shadow_text(
          bitmap, PAD + 6, y, name_width, ROW_H,
          trim_text(bitmap, name, name_width), color
        )
        shadow_text(bitmap, 0, y, right, ROW_H, price_text, price_color, 2)
      end

      def draw_info
        bitmap = @info_sprite.bitmap
        bitmap.clear
        bitmap.fill_rect(0, 0, SW, INFO_H, INFO_BG)
        bitmap.fill_rect(0, INFO_H - 1, SW, 1, INFO_BORDER)
        entry = selected_entry
        unless entry
          @icon_sprite.item = nil if @icon_sprite
          no_shadow_text(
            bitmap, PAD, INFO_H / 2 - 8, SW - PAD * 2, 20,
            _INTL("Nothing to buy here."), DIM
          )
          return
        end
        icon_x = SW - PAD - 96
        draw_icon_box(bitmap, icon_x, 4, 96, 96)
        refresh_icon
        pbSetSmallFont(bitmap)
        no_shadow_text(
          bitmap, PAD, 4, icon_x - PAD * 2 - 4, 20,
          entry[:name], WHITE
        )
        no_shadow_text(
          bitmap, PAD, 4, icon_x - PAD - 10, 20,
          _INTL("In Bag: {1}", @qty_display.round), GRAY, 2
        )
        bitmap.fill_rect(PAD + 2, 27, icon_x - PAD - 4, 1, SEP)
        bitmap.font.size = 16
        width = icon_x - PAD * 2 - 4
        lines = wrap_text(entry[:description], width, bitmap)
        max_scroll = [lines.length - 4, 0].max
        @info_scroll = clamp(@info_scroll, 0, max_scroll)
        y = 34
        lines[@info_scroll, 4].to_a.each do |line|
          no_shadow_text(bitmap, PAD, y, width, 18, line, GRAY)
          y += 18
        end
        draw_info_scroll_arrows(
          bitmap, PAD, 34, width, @info_scroll, max_scroll
        )
      end

      def draw_footer
        bitmap = @footer_sprite.bitmap
        bitmap.clear
        bitmap.fill_rect(0, 0, SW, FOOTER_H, FOOTER_BG)
        pbSetSmallFont(bitmap)
        bitmap.font.size = 16
        KantoReloaded::HintText.draw_footer(
          bitmap, hint_entries, PAD, 2, SW - PAD * 2,
          :size => 16,
          :color => WHITE,
          :align => 0,
          :height => FOOTER_H,
          :y_offset => -5,
          :hint_label => "Controls",
          :statuses => hint_statuses
        )
      end

      def hint_entries
        [
          KantoReloaded::HintText.confirm("Buy"),
          KantoReloaded::HintText.back,
          KantoReloaded::HintText.action("Favorite"),
          KantoReloaded::HintText.other("Sort: #{sort_label}", :sort),
          KantoReloaded::HintText.other(
            "Quick Buy: #{@quick_buy ? 'On' : 'Off'}", :quick
          )
        ]
      end

      def hint_statuses
        statuses = [
          KantoReloaded::HintText.status("Sort: #{sort_label}", BLUE)
        ]
        statuses << KantoReloaded::HintText.status(
          "Quick-Buy Mode", GREEN
        ) if @quick_buy
        statuses
      end

      def show_hint_popup
        pbPlayDecisionSE if defined?(pbPlayDecisionSE)
        KantoReloaded::HintText.open_popup(
          "RLD Mart Hints", hint_entries, :statuses => hint_statuses
        )
        draw_all
      rescue StandardError
        draw_all
      ensure
        KantoReloaded::UI::Modal.drain_input
      end

      def hint_triggered?
        KantoReloaded::HintText.triggered?
      rescue StandardError
        false
      end

      def controls_mouse_at?(mouse_x, mouse_y)
        KantoReloaded::HintText.controls_at?(
          @footer_sprite.bitmap,
          mouse_x,
          mouse_y - (SH - FOOTER_H),
          PAD,
          2,
          SW - PAD * 2,
          :size => 16,
          :height => FOOTER_H,
          :hint_label => "Controls"
        )
      rescue StandardError
        false
      end

      def sort_label
        case SORT_MODES[@sort_index]
        when :price_low then "Price Low"
        when :price_high then "Price High"
        when :custom then "Custom"
        else "Name"
        end
      end

      def draw_scrollbar(bitmap, total, visible)
        return if total <= visible
        track_h = LIST_H - 4
        bar_h = [((visible.to_f / total) * track_h).round, 6].max
        bar_y = ((@scroll.to_f / [total - visible, 1].max) *
                 (track_h - bar_h)).round
        bitmap.fill_rect(SW - 5, 2, 3, track_h, DIM)
        bitmap.fill_rect(SW - 5, 2 + bar_y, 3, bar_h, GRAY)
      end

      def draw_info_scroll_arrows(bitmap, x, _y, width, scroll, max_scroll)
        return if max_scroll <= 0
        arrow_x = x + width + 4
        draw_tiny_scroll_arrow(bitmap, arrow_x, 31, :up, GOLD) if scroll > 0
        draw_tiny_scroll_arrow(
          bitmap, arrow_x, INFO_H - 11, :down, GOLD
        ) if scroll < max_scroll
      end

      def draw_tiny_scroll_arrow(bitmap, x, y, direction, color)
        if direction == :up
          bitmap.fill_rect(x, y, 1, 1, color)
          bitmap.fill_rect(x - 1, y + 1, 3, 1, color)
          bitmap.fill_rect(x - 2, y + 2, 5, 1, color)
        else
          bitmap.fill_rect(x - 2, y, 5, 1, color)
          bitmap.fill_rect(x - 1, y + 1, 3, 1, color)
          bitmap.fill_rect(x, y + 2, 1, 1, color)
        end
      end

      def tick_money_anim
        return if @money_duration <= 0 || @money_frame >= @money_duration
        @money_frame += 1
        t = @money_frame.to_f / @money_duration
        eased = 1.0 - ((1.0 - t) * (1.0 - t))
        @money_display = (
          @money_start + (@money_target - @money_start) * eased
        ).round
        draw_pocket_nav
      end

      def tick_qty_anim
        return if @qty_duration <= 0 || @qty_frame >= @qty_duration
        @qty_frame += 1
        t = @qty_frame.to_f / @qty_duration
        eased = 1.0 - ((1.0 - t) * (1.0 - t))
        @qty_display = @qty_start + (@qty_target - @qty_start) * eased
        draw_info
      end

      def tick_banner
        banner = banner_text
        return if banner.empty?
        width = @title_sprite.bitmap.text_size(banner).width + 80
        @banner_offset = (@banner_offset + 0.8) % [width, 1].max
        draw_title
      end

      def tick_cursor
        @cursor_redraw_frame = (@cursor_redraw_frame + 1) % 4
        return unless @cursor_redraw_frame == 0
        draw_list
        draw_footer
      end

      def banner_text
        ""
      end

      def draw_cursor(bitmap, x, y, width, height)
        fill_base, border_base = if defined?(KantoReloaded::Options)
                                   KantoReloaded::Options.cursor_colors
                                 else
                                   [
                                     Color.new(100, 160, 220, 160),
                                     Color.new(60, 120, 180, 220)
                                   ]
                                 end
        pulse = Math.sin(
          (Graphics.frame_count rescue 0) * Math::PI / 20.0
        ) * 0.5 + 0.5
        fill_alpha = [[fill_base.alpha.to_i + (pulse * 55).to_i, 255].min, 80].max
        border_alpha = [[border_base.alpha.to_i + (pulse * 25).to_i, 255].min, 100].max
        fill = Color.new(
          fill_base.red, fill_base.green, fill_base.blue, fill_alpha
        )
        border = Color.new(
          border_base.red, border_base.green, border_base.blue, border_alpha
        )
        KantoReloaded::UI::Draw.rounded_rect(
          bitmap, x, y, width, height, 4, fill, border
        )
      rescue StandardError
        bitmap.fill_rect(
          x, y, width, height, Color.new(100, 160, 220, 170)
        )
      end

      def draw_icon_box(bitmap, x, y, width, height)
        bitmap.fill_rect(x, y, width, height, Color.new(15, 18, 30))
        bitmap.fill_rect(x, y, width, 1, INFO_BORDER)
        bitmap.fill_rect(x, y + height - 1, width, 1, INFO_BORDER)
        bitmap.fill_rect(x, y, 1, height, INFO_BORDER)
        bitmap.fill_rect(x + width - 1, y, 1, height, INFO_BORDER)
      end

      def refresh_icon
        return unless @icon_sprite
        entry = selected_entry
        @icon_sprite.item = entry ? entry[:id] : nil
      rescue StandardError
        nil
      end

      def money
        @adapter.getMoney.to_i
      rescue StandardError
        0
      end

      def quantity(entry)
        @adapter.getQuantity(entry[:runtime_id]).to_i
      rescue StandardError
        0
      end

      def info_scroll_max(entry)
        bitmap = @info_sprite.bitmap
        width = SW - PAD - 96 - PAD * 2 - 4
        [wrap_text(entry[:description], width, bitmap).length - 4, 0].max
      rescue StandardError
        0
      end

      def display_error(message)
        buzzer
        KantoReloaded::PopupWindow.message(message, :theme => :error)
        draw_content
        false
      end

      def buzzer
        pbPlayBuzzerSE if defined?(pbPlayBuzzerSE)
      end

      def trigger?(name)
        Input.const_defined?(name) && Input.trigger?(Input.const_get(name))
      rescue StandardError
        false
      end

      def formatted(value)
        value.to_i.to_s_formatted
      rescue StandardError
        value.to_i.to_s
      end

      def shadow_text(bitmap, x, y, width, height, value, color, align = 0)
        pbDrawShadowText(
          bitmap, x, y, width, height, value.to_s, color, SHADOW, align
        )
      rescue StandardError
        nil
      end

      def no_shadow_text(bitmap, x, y, width, height, value, color, align = 0)
        pbDrawShadowText(
          bitmap, x, y, width, height, value.to_s, color,
          Color.new(0, 0, 0, 0), align
        )
      rescue StandardError
        nil
      end

      def trim_text(bitmap, value, max_width)
        result = value.to_s
        return result if bitmap.text_size(result).width <= max_width
        while !result.empty? &&
              bitmap.text_size("#{result}...").width > max_width
          result = result[0...-1]
        end
        "#{result}..."
      rescue StandardError
        value.to_s
      end

      def wrap_text(value, width, bitmap)
        lines = []
        line = ""
        value.to_s.split(/\s+/).each do |word|
          candidate = line.empty? ? word : "#{line} #{word}"
          if bitmap.text_size(candidate).width <= width
            line = candidate
          else
            lines << line unless line.empty?
            line = word
          end
        end
        lines << line unless line.empty?
        lines.empty? ? [""] : lines
      rescue StandardError
        [value.to_s]
      end

      def clamp(value, minimum, maximum)
        [[value.to_i, minimum].max, maximum].min
      end
    end
  end
end
