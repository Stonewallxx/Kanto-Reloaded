#==============================================================================
# Kanto Reloaded Digit Number Picker
#==============================================================================

module KantoReloaded
  module UI
    module NumberPicker
      SLOT_GAP = 0
      SLOT_HEIGHT = 20
      MIN_SLOT_WIDTH = 12
      MAX_SLOT_WIDTH = 18
      PANEL_HEIGHT = 114
      OK_HEIGHT = 22

      class << self
        def open(title, options = {})
          normalized = normalize_options(options)
          return fallback(title, normalized) unless graphics_available?
          Modal.with_modal { DigitScene.new(title, normalized).main }
        rescue StandardError => e
          if defined?(KantoReloaded::Log)
            KantoReloaded::Log.exception("Number Picker failed", e, channel: :ui)
          end
          nil
        ensure
          Modal.drain_input if defined?(Modal)
        end

        def normalize_options(options)
          source = options.is_a?(Hash) ? options : {}
          values = {}
          source.each do |key, value|
            normalized_key = key.to_sym rescue key
            values[normalized_key] = value
          end

          minimum = values.has_key?(:min) ? values[:min].to_i : 0
          maximum = values.has_key?(:max) ? values[:max].to_i : 100
          minimum, maximum = maximum, minimum if maximum < minimum
          initial = values.has_key?(:initial) ? values[:initial].to_i : minimum
          initial = [[initial, minimum].max, maximum].min
          required_digits = [minimum.abs.to_s.length, maximum.abs.to_s.length, 1].max
          requested_digits = values[:digits].to_i
          digits = [requested_digits, required_digits].max
          digits = required_digits if digits <= 0

          {
            :min => minimum,
            :max => maximum,
            :initial => initial,
            :digits => digits,
            :signed => minimum < 0,
            :label => values[:label].to_s,
            :value_prefix => values[:value_prefix].to_s,
            :width => (values[:width] || 340).to_i,
            :theme => normalize_theme(values[:theme]),
            :show_dim => values.has_key?(:show_dim) ? !!values[:show_dim] : true,
            :z => (values[:z] || 999_999_999).to_i,
            :on_change => values[:on_change]
          }
        end

        private

        def normalize_theme(value)
          key = (value || :hr).to_sym rescue :hr
          PopupWindow::THEMES.has_key?(key) ? key : :hr
        rescue
          :hr
        end

        def graphics_available?
          defined?(Graphics) && defined?(Input) && defined?(Viewport) &&
            defined?(Sprite) && defined?(Bitmap)
        end

        def fallback(title, options)
          return options[:initial] unless defined?(ChooseNumberParams)
          receiver = Object.new
          return options[:initial] unless receiver.respond_to?(:pbMessageChooseNumber, true)
          params = ChooseNumberParams.new
          params.setRange(options[:min], options[:max])
          params.setDefaultValue(options[:initial])
          cancel_value = options[:min] - 1
          params.setCancelValue(cancel_value)
          result = receiver.__send__(:pbMessageChooseNumber, title.to_s, params)
          result == cancel_value ? nil : result
        rescue
          options[:initial]
        end
      end

      class DigitScene
        def initialize(title, options)
          @title = title.to_s
          @options = options
          @theme = PopupWindow::THEMES[@options[:theme]] || PopupWindow::THEMES[:hr]
          @slot_count = @options[:digits]
          @digits = value_to_digits(@options[:initial])
          @signed = !!@options[:signed]
          @sign = @options[:initial].to_i < 0 ? -1 : 1
          @index = @slot_count - 1
          @error = nil
        end

        def main
          setup
          notify_change
          draw
          update_loop
        ensure
          dispose
        end

        private

        def setup
          calculate_layout
          @viewport = Viewport.new(0, 0, PopupWindow::SCREEN_W, PopupWindow::SCREEN_H)
          @viewport.z = @options[:z]
          @dim_sprite = Sprite.new(@viewport)
          @dim_sprite.bitmap = Bitmap.new(PopupWindow::SCREEN_W, PopupWindow::SCREEN_H)
          if @options[:show_dim]
            @dim_sprite.bitmap.fill_rect(
              0, 0, PopupWindow::SCREEN_W, PopupWindow::SCREEN_H,
              PopupWindow::DIM_BG
            )
          end
          @sprite = Sprite.new(@viewport)
          @sprite.bitmap = Bitmap.new(@width, @height)
          @sprite.x = (PopupWindow::SCREEN_W - @width) / 2
          @sprite.y = (PopupWindow::SCREEN_H - @height) / 2
          @sprite.z = @viewport.z
        end

        def calculate_layout
          measure = Bitmap.new(1, 1)
          pbSetSmallFont(measure) if defined?(pbSetSmallFont)
          title_width = (measure.text_size(@title).width rescue PopupWindow::MIN_W) +
                        PopupWindow::PAD * 2 + PopupWindow::TEXT_SAFETY_PAD
          label = display_label
          label_width = (measure.text_size(label).width rescue 0) +
                        PopupWindow::PAD * 2 + PopupWindow::TEXT_SAFETY_PAD
          @slot_width = [(measure.text_size("0").width rescue MIN_SLOT_WIDTH), 1].max
          @sign_width = @signed ? [(measure.text_size("+").width rescue MIN_SLOT_WIDTH), 1].max : 0
          @prefix_width = @options[:value_prefix].empty? ? 0 :
                          (measure.text_size(@options[:value_prefix]).width rescue 0)
          measure.dispose rescue nil
          desired_width = [@options[:width], title_width, label_width].max
          @width = [[desired_width, PopupWindow::MIN_W].max,
                    PopupWindow::MAX_W].min
          calculate_digit_positions
          @slots_y = 48
          @ok_y = 82
          @height = PANEL_HEIGHT
        end

        def calculate_digit_positions
          @digit_xs = Array.new(@slot_count)
          cursor = @width - 14
          (@slot_count - 1).downto(0) do |index|
            cursor -= @slot_width
            @digit_xs[index] = cursor
          end
          if @signed
            cursor -= @sign_width
            @sign_x = cursor
          end
          @prefix_x = cursor - @prefix_width
        end

        def update_loop
          loop do
            Graphics.update
            Input.update

            if trigger?(:BACK) || InputRouter.input_triggered?(:MOUSERIGHT)
              pbPlayCancelSE rescue nil
              return nil
            end

            mouse_result = update_mouse
            return mouse_result unless mouse_result == :continue

            if repeat?(:LEFT)
              move_selection(-1)
            elsif repeat?(:RIGHT)
              move_selection(1)
            elsif repeat?(:UP)
              adjust_selected_value(1) if adjustable_selected?
            elsif repeat?(:DOWN)
              adjust_selected_value(-1) if adjustable_selected?
            elsif trigger?(:USE)
              result = confirm_selection
              return result unless result == :continue
            end
            draw if ((Graphics.frame_count rescue 0) % 4).zero?
          end
        end

        def update_mouse
          position = InputRouter.active_position
          return :continue unless position
          local_x = position[0].to_i - @sprite.x
          local_y = position[1].to_i - @sprite.y
          hit = hit_test(local_x, local_y)
          if !hit.nil? && hit != @index
            @index = hit
            pbPlayCursorSE rescue nil
            draw
          end

          wheel = InputRouter.wheel_delta
          if wheel != 0 && adjustable_selected? && hit == @index
            adjust_selected_value(wheel > 0 ? 1 : -1)
          end

          return :continue unless InputRouter.mouse_triggered?
          return :continue if hit.nil?
          return submit if hit == @slot_count
          :continue
        rescue
          :continue
        end

        def hit_test(x, y)
          if y >= @slots_y - 4 && y < @slots_y + SLOT_HEIGHT
            if @signed && x >= @sign_x && x < @sign_x + @sign_width
              return -1
            end
            @slot_count.times do |index|
              slot_x = @digit_xs[index]
              return index if x >= slot_x && x < slot_x + @slot_width
            end
          end
          if x >= 12 && x < @width - 12 && y >= @ok_y && y < @ok_y + OK_HEIGHT
            return @slot_count
          end
          nil
        end

        def move_selection(amount)
          if digit_selected?
            target = @index + amount.to_i
            if @signed && target < 0
              @index = -1
            elsif target >= @slot_count
              @index = @signed ? -1 : 0
            else
              @index = target % @slot_count
            end
          elsif sign_selected?
            @index = amount.to_i < 0 ? @slot_count - 1 : 0
          else
            @index = amount.to_i < 0 ? @slot_count - 1 : 0
          end
          @error = nil
          pbPlayCursorSE rescue nil
          draw
        end

        def adjust_selected_value(amount)
          if sign_selected?
            @sign *= -1
          else
            @digits[@index] = (@digits[@index] + amount.to_i) % 10
          end
          @error = nil
          pbPlayCursorSE rescue nil
          notify_change
          draw
        end

        def confirm_selection
          if adjustable_selected?
            @index = @slot_count
            pbPlayCursorSE rescue nil
            draw
            return :continue
          end
          submit
        end

        def submit
          value = current_value
          unless valid_value?(value)
            @error = _INTL(
              "Choose a value from {1} to {2}.",
              @options[:min],
              @options[:max]
            )
            pbPlayBuzzerSE rescue nil
            draw
            return :continue
          end
          pbPlayDecisionSE rescue nil
          value
        end

        def valid_value?(value)
          value >= @options[:min] && value <= @options[:max]
        end

        def digit_selected?
          @index >= 0 && @index < @slot_count
        end

        def sign_selected?
          @signed && @index == -1
        end

        def adjustable_selected?
          digit_selected? || sign_selected?
        end

        def current_value
          absolute = @digits.inject(0) { |value, digit| value * 10 + digit.to_i }
          absolute == 0 ? 0 : absolute * @sign
        end

        def value_to_digits(value)
          text = value.to_i.abs.to_s.rjust(@slot_count, "0")
          text[-@slot_count, @slot_count].chars.map { |character| character.to_i }
        end

        def formatted_value
          current_value.to_i.to_s_formatted
        rescue StandardError
          current_value.to_i.to_s
        end

        def display_label
          value = @options[:label].to_s
          value.empty? ? _INTL("Value") : value
        end

        def notify_change
          callback = @options[:on_change]
          callback.call(current_value) if callback.respond_to?(:call)
        rescue StandardError => e
          if defined?(KantoReloaded::Log)
            KantoReloaded::Log.exception("Number Picker callback failed", e, channel: :ui)
          end
        end

        def draw
          bitmap = @sprite.bitmap
          bitmap.clear
          pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
          border = @theme[:border] || PopupWindow::PANEL_BORDER
          background = @theme[:background] || PopupWindow::PANEL_BG
          Draw.rounded_rect(bitmap, 0, 0, @width, @height,
                            PopupWindow::PANEL_RADIUS, border)
          Draw.rounded_rect(bitmap, 1, 1, @width - 2, @height - 2,
                            PopupWindow::PANEL_RADIUS - 1, background)
          Draw.plain_text(
            bitmap, 14, 3, @width - 28, 20,
            @title, @theme[:text] || PopupWindow::WHITE, 0
          )
          draw_label(bitmap)
          draw_digit_slots(bitmap)
          bitmap.fill_rect(
            14, 74, @width - 28, 1,
            @theme[:border] || PopupWindow::DIM
          )
          draw_ok_row(bitmap)
        end

        def draw_label(bitmap)
          color = @error ? PopupWindow::RED :
                  (@theme[:text] || PopupWindow::WHITE)
          Draw.plain_text(
            bitmap, 14, 25, @width - 28, 20,
            @error || display_label, color, 0
          )
        end

        def draw_digit_slots(bitmap)
          dim = @theme[:dim] || PopupWindow::DIM
          unless @options[:value_prefix].empty?
            Draw.plain_text(
              bitmap, @prefix_x, @slots_y, @prefix_width, SLOT_HEIGHT,
              @options[:value_prefix], dim, 0
            )
          end
          if @signed
            sign_color = sign_selected? ? pulsing_digit_color : dim
            Draw.plain_text(
              bitmap, @sign_x, @slots_y, @sign_width, SLOT_HEIGHT,
              @sign < 0 ? "-" : "+", sign_color, 0
            )
          end
          @digits.each_with_index do |digit, index|
            x = @digit_xs[index]
            color = index == @index ? pulsing_digit_color : dim
            Draw.plain_text(
              bitmap, x, @slots_y, @slot_width, SLOT_HEIGHT,
              digit.to_s, color, 0
            )
          end
        end

        def pulsing_digit_color
          pulse = Math.sin(
            (Graphics.frame_count rescue 0) * Math::PI / 20.0
          ) * 0.5 + 0.5
          value = 175 + (pulse * 80).to_i
          Color.new(value, value, value)
        rescue StandardError
          PopupWindow::WHITE
        end

        def draw_ok_row(bitmap)
          selected = @index == @slot_count
          if selected
            Draw.rounded_rect(
              bitmap, 12, @ok_y, @width - 24, OK_HEIGHT, 4,
              pulsing_cursor_fill, cursor_border
            )
          end
          Draw.plain_text(
            bitmap, 20, @ok_y - 6, @width - 40, OK_HEIGHT,
            _INTL("OK"),
            selected ? PopupWindow::WHITE : PopupWindow::GRAY,
            0
          )
        end

        def pulsing_cursor_fill
          base, _border = cursor_colors
          pulse = Math.sin((Graphics.frame_count rescue 0) * Math::PI / 20.0) * 0.5 + 0.5
          alpha = [[base.alpha.to_i + (pulse * 55).to_i, 255].min, 80].max
          Draw.with_alpha(base, alpha)
        rescue
          Color.new(100, 160, 220, 180)
        end

        def cursor_border
          _fill, border = cursor_colors
          border
        end

        def cursor_colors
          return KantoReloaded::Options.cursor_colors if defined?(KantoReloaded::Options)
          [Color.new(100, 160, 220, 160), Color.new(60, 120, 180, 220)]
        rescue
          [Color.new(100, 160, 220, 160), Color.new(60, 120, 180, 220)]
        end

        def trigger?(name)
          InputRouter.input_triggered?(name)
        end

        def repeat?(name)
          InputRouter.input_repeated?(name)
        end

        def dispose
          if @dim_sprite
            if @dim_sprite.bitmap && !@dim_sprite.bitmap.disposed?
              @dim_sprite.bitmap.dispose
            end
            @dim_sprite.dispose unless @dim_sprite.disposed?
          end
          if @sprite
            @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
            @sprite.dispose unless @sprite.disposed?
          end
          @viewport.dispose if @viewport && !@viewport.disposed?
        rescue
          nil
        end
      end
    end
  end

  NumberPicker = UI::NumberPicker unless const_defined?(:NumberPicker, false)

  class << self
    def number_picker(title, options = {})
      NumberPicker.open(title, options)
    end
  end
end
