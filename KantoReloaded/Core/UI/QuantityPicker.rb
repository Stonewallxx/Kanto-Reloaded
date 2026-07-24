#==============================================================================
# Kanto Reloaded - Reloaded Quantity and Confirmation Picker
#==============================================================================
# Shared position-for-position port of Hoenn Reloaded's quantity/confirmation UI.
#==============================================================================

module KantoReloaded
  module UI
    module NumberPicker
      DEFAULT_STEP = 1
      DEFAULT_LARGE_STEP = 10
      ROW_H = 20
      CHOICE_H = 22

      class << self
        def quantity(title, options = {})
          values = options.merge(
            :min => options.has_key?(:min) ? options[:min] : 1
          )
          values[:value_prefix] = "x" unless values.has_key?(:value_prefix)
          values[:show_max_label] = true unless values.has_key?(:show_max_label)
          open_quantity(title, values)
        end

        def open_quantity(title, options = {})
          normalized = normalize_options(options)
          KantoReloaded::UI::Modal.with_modal do
            PickerScene.new(title, normalized).main
          end
        rescue StandardError => e
          log_exception("Reloaded Mart quantity popup failed", e)
          nil
        ensure
          KantoReloaded::UI::Modal.drain_input
        end

        def confirm(title, options = {})
          normalized = normalize_options(options)
          KantoReloaded::UI::Modal.with_modal do
            ConfirmationScene.new(title, normalized).main
          end
        rescue StandardError => e
          log_exception("Reloaded Mart confirmation popup failed", e)
          false
        ensure
          KantoReloaded::UI::Modal.drain_input
        end

        def normalize_options(options)
          values = {}
          (options || {}).each do |key, value|
            normalized_key = key.to_sym rescue key
            values[normalized_key] = value
          end
          minimum = values.has_key?(:min) ? values[:min].to_i : 0
          maximum = values.has_key?(:max) ? values[:max].to_i : 100
          minimum, maximum = maximum, minimum if maximum < minimum
          values[:min] = minimum
          values[:max] = maximum
          values[:step] = positive_step(values[:step], DEFAULT_STEP)
          values[:large_step] = positive_step(
            values[:large_step], DEFAULT_LARGE_STEP
          )
          initial = values.has_key?(:initial) ? values[:initial] : minimum
          values[:initial] = [[initial.to_i, minimum].max, maximum].min
          values[:wrap] = true unless values.has_key?(:wrap)
          values[:show_max_label] = !!values[:show_max_label]
          values[:show_unit_price] = !!values[:show_unit_price]
          values[:allow_max_shortcut] = !!values[:allow_max_shortcut]
          values[:value_prefix] = values[:value_prefix].to_s
          values[:value_suffix] = values[:value_suffix].to_s
          values[:label] = values[:label].to_s
          values[:free_label] = (values[:free_label] || _INTL("FREE")).to_s
          values[:theme] = (values[:theme] || :hr).to_sym rescue :hr
          values[:theme] = :hr unless
            KantoReloaded::PopupWindow::THEMES[values[:theme]]
          values[:show_dim] = true unless values.has_key?(:show_dim)
          values[:z] = (values[:z] || 999_999_999).to_i
          values[:width] ||= 340
          values
        end

        private

        def positive_step(value, fallback)
          amount = value.to_i
          amount > 0 ? amount : fallback
        rescue StandardError
          fallback
        end

        def log_exception(message, error)
          KantoReloaded::Log.exception(
            message, error, channel: :ui
          ) if defined?(KantoReloaded::Log)
        end
      end

      class PickerScene
        def initialize(title, options)
          @title = title.to_s
          @options = options
          @theme = KantoReloaded::PopupWindow::THEMES[@options[:theme]] ||
                   KantoReloaded::PopupWindow::THEMES[:hr]
          @value = @options[:initial]
          @sprites = {}
        end

        def main
          setup
          notify_change
          draw
          loop do
            Graphics.update
            Input.update
            draw if pulse_redraw?
            if Input.trigger?(Input::BACK) ||
                input_triggered?(:MOUSERIGHT)
              pbPlayCancelSE if defined?(pbPlayCancelSE)
              return nil
            elsif Input.trigger?(Input::SPECIAL)
              show_controls_popup
            elsif Input.trigger?(Input::USE)
              result = submit
              return result unless result == :continue
            elsif Input.repeat?(Input::UP)
              adjust(@options[:step], true)
            elsif Input.repeat?(Input::DOWN)
              adjust(-@options[:step], true)
            elsif Input.repeat?(Input::RIGHT)
              adjust(@options[:large_step], false)
            elsif Input.repeat?(Input::LEFT)
              adjust(-@options[:large_step], false)
            elsif max_shortcut_triggered?
              set_value(@options[:max])
            end
            mouse_result = update_mouse
            return mouse_result unless mouse_result == :continue
          end
        ensure
          dispose
        end

        def setup
          popup = KantoReloaded::PopupWindow
          @w = [[@options[:width].to_i, popup::MIN_W].max, popup::MAX_W].min
          @has_preview_row = preview_row?
          @label_present = !@options[:label].empty?
          @quantity_y = @label_present ? 49 : 27
          @unit_y = @label_present ? 25 : 21
          @preview_y = @label_present ? 49 : 38
          @separator_y = if @has_preview_row
                           @label_present ? 78 : 60
                         else
                           @quantity_y + 25
                         end
          @choice_y = @separator_y + 8
          @h = @choice_y + CHOICE_H * choice_count + 10
          @x = (popup::SCREEN_W - @w) / 2
          @y = (popup::SCREEN_H - @h) / 2
          @viewport = Viewport.new(0, 0, popup::SCREEN_W, popup::SCREEN_H)
          @viewport.z = @options[:z]
          @sprites["dim"] = Sprite.new(@viewport)
          @sprites["dim"].bitmap = Bitmap.new(popup::SCREEN_W, popup::SCREEN_H)
          if @options[:show_dim]
            @sprites["dim"].bitmap.fill_rect(
              0, 0, popup::SCREEN_W, popup::SCREEN_H, popup::DIM_BG
            )
          end
          @sprites["picker"] = Sprite.new(@viewport)
          @sprites["picker"].x = @x
          @sprites["picker"].y = @y
          @sprites["picker"].z = @options[:z]
          @sprites["picker"].bitmap = Bitmap.new(@w, @h)
        end

        def draw
          bitmap = @sprites["picker"].bitmap
          bitmap.clear
          draw_panel(bitmap)
          pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
          plain_text(
            bitmap, 14, 3, @w - 28, ROW_H,
            fit_text(bitmap, @title, @w - 28), theme_text
          )
          draw_item_row(bitmap) if @label_present
          draw_quantity_row(bitmap)
          draw_preview_row(bitmap) if @has_preview_row
          bitmap.fill_rect(
            14, @separator_y, @w - 28, 1,
            @theme[:border] || KantoReloaded::PopupWindow::DIM
          )
          draw_choice_rows(bitmap)
        end

        def draw_item_row(bitmap)
          plain_text(
            bitmap, 14, 25, @w - 28, ROW_H,
            fit_text(bitmap, @options[:label], @w - 28), theme_text
          )
        end

        def draw_quantity_row(bitmap)
          color = at_max? && @options[:show_max_label] ?
            KantoReloaded::PopupWindow::BLUE : theme_text
          plain_text(
            bitmap, 14, @quantity_y, (@w - 28) / 2,
            ROW_H, value_text, color
          )
        end

        def draw_preview_row(bitmap)
          preview_text, preview_color = preview
          unit_text = unit_price_text
          unless unit_text.empty?
            plain_text(
              bitmap, @w / 2, @unit_y, @w / 2 - 14,
              ROW_H, unit_text, theme_dim, 2
            )
          end
          unless preview_text.empty?
            plain_text(
              bitmap, @w / 2, @preview_y, @w / 2 - 14,
              ROW_H, preview_text, preview_color, 2
            )
          end
        end

        def draw_choice_rows(bitmap)
          draw_selection(bitmap, 12, @choice_y, @w - 24, CHOICE_H)
          plain_text(
            bitmap, 20, @choice_y - 6, @w - 40,
            CHOICE_H, _INTL("OK"), theme_text
          )
        end

        def choice_count
          1
        end

        def adjust(amount, allow_wrap)
          candidate = @value + amount.to_i
          if allow_wrap && @options[:wrap]
            candidate = @options[:min] if candidate > @options[:max]
            candidate = @options[:max] if candidate < @options[:min]
          end
          set_value(candidate)
        end

        def set_value(value)
          next_value = [[value.to_i, @options[:min]].max, @options[:max]].min
          return if next_value == @value
          @value = next_value
          pbPlayCursorSE if defined?(pbPlayCursorSE)
          notify_change
          draw
        end

        def submit
          validator = @options[:validator]
          if validator.respond_to?(:call)
            result = validator.call(@value)
            unless result.nil? || result == true
              reason = result == false ?
                _INTL("This value is unavailable.") : result.to_s
              KantoReloaded::Toast.warning(reason) if defined?(KantoReloaded::Toast)
              draw
              return :continue
            end
          end
          pbPlayDecisionSE if defined?(pbPlayDecisionSE)
          @value
        rescue StandardError => e
          KantoReloaded::Log.exception(
            "Reloaded Mart quantity validation failed", e, channel: :ui
          ) if defined?(KantoReloaded::Log)
          :continue
        end

        def update_mouse
          scroll = KantoReloaded::MouseInput.wheel_delta
          if scroll > 0
            adjust(@options[:step], true)
          elsif scroll < 0
            adjust(-@options[:step], true)
          end
          position = KantoReloaded::MouseInput.active_position
          return :continue unless position
          local_x = position[0].to_i - @x
          local_y = position[1].to_i - @y
          if input_triggered?(:MOUSERIGHT)
            pbPlayCancelSE if defined?(pbPlayCancelSE)
            return nil
          end
          return :continue unless input_triggered?(:MOUSELEFT)
          if local_x >= 12 && local_x < @w - 12 &&
             local_y >= @choice_y && local_y < @choice_y + CHOICE_H
            return submit
          end
          :continue
        rescue StandardError
          :continue
        end

        def preview
          value = if @options[:preview].respond_to?(:call)
                    @options[:preview].call(@value)
                  elsif @options.has_key?(:unit_price)
                    @options[:unit_price].to_i * @value
                  end
          return ["", theme_text] if value.nil?
          if value.is_a?(Hash)
            return [
              value[:text].to_s,
              value[:color] || preview_color(value[:value])
            ]
          end
          if value.is_a?(Array)
            return [value[0].to_s, value[1] || theme_text]
          end
          numeric = value.is_a?(Numeric) ? value.to_i : nil
          text = numeric.nil? ? value.to_s : format_currency(numeric)
          [text, preview_color(numeric)]
        rescue StandardError
          ["", theme_text]
        end

        def preview_color(value)
          color = @options[:preview_color]
          return color.call(value, @value) if color.respond_to?(:call)
          return color if color
          value.to_i <= 0 ? KantoReloaded::PopupWindow::GREEN : theme_text
        rescue StandardError
          theme_text
        end

        def format_currency(value)
          if value.to_i == 0 && !@options[:free_label].empty?
            return @options[:free_label]
          end
          formatter = @options[:currency_formatter]
          return formatter.call(value.to_i).to_s if formatter.respond_to?(:call)
          value.to_i.to_s
        rescue StandardError
          value.to_s
        end

        def unit_price_text
          return "" unless @options.has_key?(:unit_price)
          label = (@options[:unit_label] || _INTL("Each")).to_s
          "#{label}: #{format_currency(@options[:unit_price].to_i)}"
        end

        def preview_row?
          @options[:show_unit_price] ||
            @options.has_key?(:unit_price) ||
            @options[:preview].respond_to?(:call)
        rescue StandardError
          false
        end

        def value_text
          if at_max? && @options[:show_max_label]
            "MAX (#{@value})#{@options[:value_suffix]}"
          else
            "#{@options[:value_prefix]}#{@value}#{@options[:value_suffix]}"
          end
        end

        def at_max?
          @value == @options[:max]
        end

        def notify_change
          callback = @options[:on_change]
          callback.call(@value) if callback.respond_to?(:call)
        rescue StandardError
          nil
        end

        def max_shortcut_triggered?
          @options[:allow_max_shortcut] && Input.const_defined?(:ACTION) &&
            Input.trigger?(Input::ACTION)
        rescue StandardError
          false
        end

        def show_controls_popup
          entries = [
            KantoReloaded::HintText.confirm("Choose"),
            KantoReloaded::HintText.back,
            KantoReloaded::HintText.other("Step", "Up/Down"),
            KantoReloaded::HintText.other("Large Step", :page)
          ]
          if @options[:allow_max_shortcut]
            entries << KantoReloaded::HintText.action("Maximum")
          end
          KantoReloaded::HintText.open_popup("Controls", entries)
          draw
        rescue StandardError
          draw
        end

        def draw_panel(bitmap)
          popup = KantoReloaded::PopupWindow
          border = @theme[:border] || popup::PANEL_BORDER
          background = @theme[:background] || popup::PANEL_BG
          KantoReloaded::UI::Draw.rounded_rect(
            bitmap, 0, 0, @w, @h, popup::PANEL_RADIUS, border
          )
          KantoReloaded::UI::Draw.rounded_rect(
            bitmap, 1, 1, @w - 2, @h - 2,
            [popup::PANEL_RADIUS - 1, 1].max, background
          )
        end

        def draw_selection(bitmap, x, y, width, height)
          KantoReloaded::UI::Draw.rounded_rect(
            bitmap, x, y, width, height, 4,
            pulsing_cursor_fill, cursor_border
          )
        end

        def plain_text(bitmap, x, y, width, height, text, color, align = 0)
          KantoReloaded::UI::Draw.plain_text(
            bitmap, x, y, width, height, text, color, align
          )
        end

        def pulsing_cursor_fill
          base, _border = cursor_colors
          pulse = Math.sin(
            (Graphics.frame_count rescue 0) * Math::PI / 20.0
          ) * 0.5 + 0.5
          alpha = [[base.alpha.to_i + (pulse * 55).to_i, 255].min, 80].max
          KantoReloaded::UI::Draw.with_alpha(base, alpha)
        end

        def cursor_border
          _fill, border = cursor_colors
          border
        end

        def cursor_colors
          return KantoReloaded::Options.cursor_colors if
            defined?(KantoReloaded::Options)
          [
            Color.new(100, 160, 220, 160),
            Color.new(60, 120, 180, 220)
          ]
        end

        def theme_text
          @theme[:text] || KantoReloaded::PopupWindow::WHITE
        end

        def theme_dim
          @theme[:dim] || KantoReloaded::PopupWindow::GRAY
        end

        def fit_text(bitmap, text, width)
          value = text.to_s
          return value if bitmap.text_size(value).width <= width
          while !value.empty? &&
                bitmap.text_size("#{value}...").width > width
            value = value[0...-1]
          end
          "#{value}..."
        rescue StandardError
          text.to_s
        end

        def pulse_redraw?
          ((Graphics.frame_count rescue 0) % 4).zero?
        end

        def input_triggered?(name)
          Input.const_defined?(name) && Input.trigger?(Input.const_get(name))
        rescue StandardError
          false
        end

        def dispose
          @sprites.each_value do |sprite|
            sprite.bitmap.dispose if sprite.bitmap && !sprite.bitmap.disposed?
            sprite.dispose unless sprite.disposed?
          end
          @sprites.clear
          @viewport.dispose if @viewport && !@viewport.disposed?
        rescue StandardError
          nil
        end
      end

      class ConfirmationScene < PickerScene
        def initialize(title, options)
          super
          @selected_choice = options[:default] == false ? 1 : 0
        end

        def main
          setup
          draw
          loop do
            Graphics.update
            Input.update
            draw if pulse_redraw?
            if Input.trigger?(Input::BACK) ||
                input_triggered?(:MOUSERIGHT)
              pbPlayCancelSE if defined?(pbPlayCancelSE)
              return false
            elsif Input.trigger?(Input::SPECIAL)
              show_confirmation_controls
            elsif Input.trigger?(Input::USE)
              pbPlayDecisionSE if defined?(pbPlayDecisionSE)
              return @selected_choice == 0
            elsif Input.trigger?(Input::UP)
              move_choice(-1)
            elsif Input.trigger?(Input::DOWN)
              move_choice(1)
            end
            result = update_confirmation_mouse
            return result unless result == :continue
          end
        ensure
          dispose
        end

        def choice_count
          2
        end

        def draw_choice_rows(bitmap)
          [_INTL("Yes"), _INTL("No")].each_with_index do |label, index|
            y = @choice_y + index * CHOICE_H
            if index == @selected_choice
              draw_selection(bitmap, 12, y, @w - 24, CHOICE_H)
            end
            plain_text(
              bitmap, 20, y - 6, @w - 40, CHOICE_H, label,
              index == @selected_choice ? theme_text : theme_dim
            )
          end
        end

        def move_choice(amount)
          @selected_choice = (@selected_choice + amount.to_i) % choice_count
          pbPlayCursorSE if defined?(pbPlayCursorSE)
          draw
        end

        def update_confirmation_mouse
          position = KantoReloaded::MouseInput.active_position
          return :continue unless position
          local_x = position[0].to_i - @x
          local_y = position[1].to_i - @y
          if input_triggered?(:MOUSERIGHT)
            pbPlayCancelSE if defined?(pbPlayCancelSE)
            return false
          end
          return :continue unless local_x >= 12 && local_x < @w - 12
          index = (local_y - @choice_y) / CHOICE_H
          return :continue unless index >= 0 && index < choice_count
          if index != @selected_choice
            @selected_choice = index
            pbPlayCursorSE if defined?(pbPlayCursorSE)
            draw
          end
          if input_triggered?(:MOUSELEFT)
            pbPlayDecisionSE if defined?(pbPlayDecisionSE)
            return @selected_choice == 0
          end
          :continue
        rescue StandardError
          :continue
        end

        def show_confirmation_controls
          KantoReloaded::HintText.open_popup(
            "Controls",
            [
              KantoReloaded::HintText.confirm("Choose"),
              KantoReloaded::HintText.back,
              KantoReloaded::HintText.other("Select", "Up/Down")
            ]
          )
          draw
        rescue StandardError
          draw
        end
      end
    end
  end
end
