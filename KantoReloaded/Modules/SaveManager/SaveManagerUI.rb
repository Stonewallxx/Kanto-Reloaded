#==============================================================================
# Kanto Reloaded - Save Manager UI
#==============================================================================

module KantoReloaded
  module SaveManager
    module SaveManagerUI
      TABS = [[:active, "Active Saves"], [:archive, "Deleted Saves"]].freeze

      class << self
        def open(options = {})
          return { :changed => false } unless graphics_available?
          KantoReloaded::UI::Modal.with_modal { Scene.new(options).main }
        rescue StandardError => e
          KantoReloaded::Log.exception("Save Manager UI failed", e, channel: :save_manager) if defined?(KantoReloaded::Log)
          { :changed => false }
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
        HEADER_H = 56
        FOOTER_H = 28
        ROW_H = 26
        LIST_X = 8
        LIST_Y = HEADER_H + 4
        LIST_W = 224
        LIST_H = SCREEN_H - LIST_Y - FOOTER_H - 4
        DETAIL_X = LIST_X + LIST_W + 8
        DETAIL_W = SCREEN_W - DETAIL_X - 8
        VISIBLE_ROWS = (LIST_H - 12) / ROW_H
        PARTY_ICON_SIZE = 58
        PARTY_ICON_X = DETAIL_X + 44
        PARTY_ICON_Y = LIST_Y + 199
        PARTY_ICON_GAP_X = 84
        PARTY_ICON_GAP_Y = 62

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

        def initialize(options = {})
          @options = options.is_a?(Hash) ? options : {}
          @title_context = !!@options[:title]
          @active_slot = @options[:active_slot].to_s
          @focus_slot = @options[:focus_slot].to_s
          @tab_index = @options[:tab].to_s == "archive" ? 1 : 0
          @changed = false
          @party_icons = []
        end

        def main
          setup
          loop do
            Graphics.update
            Input.update
            result = handle_input
            break if result == :close
            draw_list if ((Graphics.frame_count rescue 0) % 4).zero?
          end
          { :changed => @changed, :tab => current_tab }
        ensure
          dispose
        end

        private

        def setup
          @viewport = Viewport.new(0, 0, SCREEN_W, SCREEN_H)
          @viewport.z = 999_999_000
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

        def load_rows(preferred_id = nil)
          selected_id = preferred_id || current_id
          rows = current_tab == :active ? SaveArchive.active_entries : SaveArchive.archived_entries
          @state = KantoReloaded::ListState::State.new(rows, :visible_rows => VISIBLE_ROWS)
          target = if selected_id
                     rows.index { |entry| entry[:id] == selected_id }
                   elsif current_tab == :active && !@focus_slot.empty?
                     rows.index { |entry| entry[:slot] == @focus_slot }
                   end
          @state.select(target) if target
          refresh_party_icons
        end

        def current_tab
          TABS[@tab_index][0]
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
          text(bitmap, 8, 0, SCREEN_W - 16, 24, _INTL("SAVE MANAGER"), BLUE, 1)
          TABS.each_with_index do |tab, index|
            width = 150
            x = (SCREEN_W - TABS.length * width) / 2 + index * width
            color = index == @tab_index ? WHITE : DIM
            label = index == @tab_index ? "[ #{tab[1]} ]" : tab[1]
            text(bitmap, x, 26, width, 22, _INTL(label), color, 1)
          end
          bitmap.fill_rect(0, HEADER_H - 1, SCREEN_W, 1, BORDER)
        end

        def draw_list
          bitmap = @list_sprite.bitmap
          bitmap.clear
          panel(bitmap, LIST_W, LIST_H)
          set_font(bitmap)
          if @state.empty?
            message = current_tab == :active ? _INTL("No active saves found.") : _INTL("No deleted saves found.")
            text(bitmap, 10, 104, LIST_W - 20, 24, message, DIM, 1)
            return
          end
          @state.visible.each_with_index do |entry, local|
            index = @state.scroll + local
            y = 6 + local * ROW_H
            selected = index == @state.index
            cursor(bitmap, y) if selected
            color = entry_disabled?(entry) ? DIM : (selected ? WHITE : GRAY)
            text(bitmap, 14, y - 2, LIST_W - 28, ROW_H, entry[:label], color)
          end
        end

        def draw_detail
          bitmap = @detail_sprite.bitmap
          bitmap.clear
          panel(bitmap, DETAIL_W, LIST_H)
          set_font(bitmap)
          entry = @state.current
          unless entry
            text(bitmap, 8, 106, DETAIL_W - 16, 24, _INTL("Select a save."), DIM, 1)
            return
          end
          metadata = entry[:metadata] || {}
          text(bitmap, 10, 6, DETAIL_W - 20, 24, entry[:slot].to_s.empty? ? _INTL("Archive") : entry[:slot], WHITE, 1)
          detail_row(bitmap, 32, _INTL("Trainer"), metadata[:trainer_name], BLUE)
          detail_row(bitmap, 52, _INTL("Location"), metadata[:location], GREEN)
          detail_row(bitmap, 72, _INTL("Saved"), metadata[:saved_at], GRAY)
          detail_row(bitmap, 92, _INTL("Play Time"), metadata[:play_time], GOLD)
          detail_row(bitmap, 112, _INTL("Files"), "#{entry[:file_count]} / #{SaveArchive.format_size(entry[:total_bytes])}", WHITE)
          status = detail_status(entry)
          text(bitmap, 10, 136, DETAIL_W - 20, 22, status[0], status[1], 1)
          if Array(metadata[:party]).empty?
            text(bitmap, 10, 225, DETAIL_W - 20, 22, _INTL("No party preview available."), DIM, 1)
          end
        end

        def detail_row(bitmap, y, label, value, color)
          text(bitmap, 12, y, 72, 20, label, GRAY)
          text(bitmap, 84, y, DETAIL_W - 96, 20, value.to_s, color, 2)
        end

        def detail_status(entry)
          if entry_disabled?(entry)
            [_INTL("CURRENT SAVE - ARCHIVE DISABLED"), RED]
          elsif entry[:kind] == :archive && !SaveArchive.restorable?(entry)
            [_INTL("DELETE ONLY - SAVE FILE NOT RECOGNIZED"), GOLD]
          elsif entry[:legacy]
            [_INTL("LEGACY ARCHIVE"), GOLD]
          elsif entry[:kind] == :archive
            [_INTL("READY TO RESTORE"), GREEN]
          else
            [_INTL("READY TO ARCHIVE"), GREEN]
          end
        end

        def draw_footer
          bitmap = @footer_sprite.bitmap
          bitmap.clear
          bitmap.fill_rect(0, 0, SCREEN_W, FOOTER_H, BG)
          bitmap.fill_rect(0, 0, SCREEN_W, 1, BORDER)
          entries = [
            KantoReloaded::HintText.confirm("Manage"),
            KantoReloaded::HintText.back("Back"),
            KantoReloaded::HintText.action("Open Folder")
          ]
          entries << KantoReloaded::HintText.special("Empty Deleted") if current_tab == :archive
          entries << KantoReloaded::HintText.other("Tab", "L/R")
          KantoReloaded::HintText.draw_footer(
            bitmap, entries, 8, 4, SCREEN_W - 16,
            :size => 14, :color => WHITE, :height => FOOTER_H,
            :y_offset => -4, :show_hint => false
          )
        end

        def handle_input
          mouse_index = update_mouse
          if mouse_index && KantoReloaded::MouseInput.mouse_triggered?
            open_actions
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
            change_tab(-1)
          elsif trigger?(:AUX2)
            change_tab(1)
          elsif trigger?(:ACTION)
            KantoReloaded::SaveManager.open_archive_folder
          elsif trigger?(:SPECIAL) && current_tab == :archive
            empty_deleted_saves
          elsif Input.trigger?(Input::USE)
            open_actions
          elsif Input.trigger?(Input::BACK)
            return :close
          end
          :continue
        end

        def move(amount)
          return unless @state.move(amount)
          pbPlayCursorSE rescue nil
          refresh_party_icons
          draw_list
          draw_detail
        end

        def change_tab(amount)
          @tab_index = (@tab_index + amount.to_i) % TABS.length
          pbPlayCursorSE rescue nil
          @focus_slot = ""
          load_rows
          draw_all
        end

        def open_actions
          entry = @state.current
          return unless entry
          if entry[:kind] == :active
            if entry_disabled?(entry)
              KantoReloaded::Toast.warning(_INTL("The currently loaded save cannot be archived while playing."))
              return
            end
            action = KantoReloaded::PopupWindow.choice(
              _INTL("Manage {1}.", entry[:slot]),
              [
                { :label => _INTL("Archive Save"), :value => :archive },
                { :label => _INTL("Open Save Folder"), :value => :folder },
                { :label => _INTL("Back"), :value => :back }
              ], :start_index => 2
            )
            archive_entry(entry) if action == :archive
            KantoReloaded::SaveManager.open_archive_folder if action == :folder
          else
            action = KantoReloaded::PopupWindow.choice(
              _INTL("Manage {1}.", entry[:label]),
              [
                {
                  :label => _INTL("Restore Save"), :value => :restore,
                  :enabled => SaveArchive.restorable?(entry),
                  :selectable => SaveArchive.restorable?(entry)
                },
                { :label => _INTL("Permanently Delete"), :value => :delete },
                { :label => _INTL("Open Deleted Saves Folder"), :value => :folder },
                { :label => _INTL("Back"), :value => :back }
              ], :start_index => 3
            )
            restore_entry(entry) if action == :restore
            delete_entry(entry) if action == :delete
            KantoReloaded::SaveManager.open_archive_folder if action == :folder
          end
          draw_all
        end

        def archive_entry(entry)
          count = entry[:file_count].to_i
          return unless KantoReloaded::PopupWindow.confirm(
            _INTL("Archive {1} and its {2} related file(s)?", entry[:slot], count),
            :default => false, :theme => :warning
          )
          return unless KantoReloaded::PopupWindow.confirm(
            _INTL("The save will be moved into Deleted Saves and removed from the title screen. Continue?"),
            :default => false, :theme => :warning
          )
          result = SaveArchive.archive(entry[:slot])
          if result[:ok]
            @changed = true
            load_rows
            refresh_party_icons
            KantoReloaded::Toast.success(_INTL("Archived {1} save file(s).", result[:count]))
          else
            KantoReloaded::Toast.error(_INTL(result[:message]))
          end
        end

        def restore_entry(entry)
          return unless KantoReloaded::PopupWindow.confirm(
            _INTL("Restore {1} to the active save folder?", entry[:slot]),
            :default => false
          )
          result = SaveArchive.restore(entry)
          if result[:ok]
            @changed = true
            load_rows
            refresh_party_icons
            KantoReloaded::Toast.success(_INTL("Restored {1} save file(s).", result[:count]))
          else
            KantoReloaded::Toast.error(_INTL(result[:message]))
          end
        end

        def delete_entry(entry)
          return unless KantoReloaded::PopupWindow.confirm(
            _INTL("Permanently delete {1} archived file(s)?", entry[:file_count]),
            :default => false, :theme => :error
          )
          return unless KantoReloaded::PopupWindow.confirm(
            _INTL("This cannot be undone. Are you absolutely sure?"),
            :default => false, :theme => :error
          )
          result = SaveArchive.permanently_delete(entry)
          if result[:ok]
            @changed = true
            load_rows
            refresh_party_icons
            KantoReloaded::Toast.success(_INTL("Permanently deleted {1} file(s).", result[:count]))
          else
            KantoReloaded::Toast.error(_INTL(result[:message]))
          end
        end

        def empty_deleted_saves
          info = SaveArchive.deleted_disk_info
          if info[:count].to_i <= 0
            KantoReloaded::Toast.warning(_INTL("Deleted Saves is already empty."))
            return
          end
          return unless KantoReloaded::PopupWindow.confirm(
            _INTL("Permanently delete all {1} archived files ({2})?", info[:count], SaveArchive.format_size(info[:bytes])),
            :default => false, :theme => :error
          )
          return unless KantoReloaded::PopupWindow.confirm(
            _INTL("Every deleted save archive will be lost. Are you absolutely sure?"),
            :default => false, :theme => :error
          )
          result = SaveArchive.empty_archive
          if result[:ok]
            @changed = true
            load_rows
            refresh_party_icons
            KantoReloaded::Toast.success(_INTL("Permanently deleted {1} archived file(s).", result[:count]))
          else
            KantoReloaded::Toast.error(_INTL(result[:message]))
          end
        end

        def entry_disabled?(entry)
          return false if @title_context || entry[:kind] != :active
          !@active_slot.empty? && entry[:slot].to_s == @active_slot
        end

        def refresh_party_icons
          dispose_party_icons
          entry = @state && @state.current
          party = entry ? Array((entry[:metadata] || {})[:party]).first(6) : []
          return if party.empty? || !defined?(PokemonIconSprite)
          party.each_with_index do |pokemon, index|
            icon = PokemonIconSprite.new(pokemon, @viewport)
            icon.icon_offset_x = 0 if icon.respond_to?(:icon_offset_x=)
            icon.icon_offset_y = 0 if icon.respond_to?(:icon_offset_y=)
            icon.setOffset(PictureOrigin::Center) if icon.respond_to?(:setOffset) && defined?(PictureOrigin)
            fit_party_icon(icon)
            icon.x = PARTY_ICON_X + (index % 3) * PARTY_ICON_GAP_X
            icon.y = PARTY_ICON_Y + (index / 3) * PARTY_ICON_GAP_Y
            icon.z = @viewport.z + 5
            @party_icons << icon
          end
        rescue StandardError => e
          dispose_party_icons
          KantoReloaded::Log.exception("Save Manager party preview failed", e, channel: :save_manager) if defined?(KantoReloaded::Log)
        end

        def fit_party_icon(icon)
          frame = icon.respond_to?(:src_rect) ? icon.src_rect : nil
          width = frame && frame.width.to_i > 0 ? frame.width.to_f : PARTY_ICON_SIZE.to_f
          height = frame && frame.height.to_i > 0 ? frame.height.to_f : PARTY_ICON_SIZE.to_f
          scale = [PARTY_ICON_SIZE / width, PARTY_ICON_SIZE / height, 1.0].min
          icon.zoom_x = scale
          icon.zoom_y = scale
        end

        def dispose_party_icons
          Array(@party_icons).each do |icon|
            icon.dispose if icon && !icon.disposed?
          rescue
            nil
          end
          @party_icons = []
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
            refresh_party_icons
            draw_list
            draw_detail
          end
          index
        end

        def current_id
          entry = @state && @state.current
          entry ? entry[:id] : nil
        end

        def panel(bitmap, width, height)
          KantoReloaded::UI::Draw.rounded_rect(bitmap, 0, 0, width, height, 5, PANEL, BORDER)
        end

        def cursor(bitmap, y)
          fill, border = KantoReloaded::Options.cursor_colors
          KantoReloaded::UI::Draw.rounded_rect(bitmap, 7, y + 2, LIST_W - 14, ROW_H - 3, 4, fill, border)
        rescue
          nil
        end

        def set_font(bitmap)
          pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
          bitmap.font.size = 15
        end

        def text(bitmap, x, y, width, height, value, color, align = 0)
          KantoReloaded::UI::Draw.plain_text(bitmap, x, y, width, height, value.to_s, color, align, 15)
        end

        def trigger?(name)
          KantoReloaded::UI::InputRouter.input_triggered?(name)
        rescue
          false
        end

        def dispose
          dispose_party_icons
          [@background, @header_sprite, @list_sprite, @detail_sprite, @footer_sprite].each do |sprite|
            next unless sprite
            if sprite.bitmap && !sprite.bitmap.disposed?
              sprite.bitmap.clear
              sprite.bitmap.dispose
            end
            sprite.dispose unless sprite.disposed?
          rescue
            nil
          end
          @viewport.dispose if @viewport && !@viewport.disposed?
          Graphics.update if defined?(Graphics)
        rescue
          nil
        end
      end
    end
  end
end
