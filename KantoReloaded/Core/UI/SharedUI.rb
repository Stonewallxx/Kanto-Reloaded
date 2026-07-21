#==============================================================================
# Kanto Reloaded Shared UI
#==============================================================================
# Shared drawing, input, modal popup, toast, and hint footer APIs.
#==============================================================================

module KantoReloaded
  module UI
    module QuickMenuStyle
      HEADER_HEIGHT = 22
      ROW_HEIGHT = 18
      PADDING = 6
      MAX_ROWS = 10

      BACKGROUND = Color.new(16, 20, 38, 225)
      HEADER = Color.new(22, 26, 54, 255)
      BORDER = Color.new(55, 75, 160, 255)
      SELECTION = Color.new(44, 64, 148, 215)
      WHITE = Color.new(255, 255, 255)
      GRAY = Color.new(158, 163, 190)
      DIM = Color.new(88, 93, 118)
      GOLD = Color.new(228, 188, 58)
      GREEN = Color.new(64, 200, 64)
      SHADOW = Color.new(0, 0, 0, 0)

      module_function

      def draw_panel(bitmap, width, height, title)
        bitmap.fill_rect(0, 0, width, height, BACKGROUND)
        bitmap.fill_rect(0, 0, width, HEADER_HEIGHT, HEADER)
        bitmap.fill_rect(0, 0, width, 1, BORDER)
        bitmap.fill_rect(0, 0, 1, height, BORDER)
        bitmap.fill_rect(width - 1, 0, 1, height, BORDER)
        bitmap.fill_rect(0, height - 1, width, 1, BORDER)
        bitmap.fill_rect(0, HEADER_HEIGHT - 1, width, 1, BORDER)
        pbSetSmallFont(bitmap)
        bitmap.font.size = 15
        pbDrawShadowText(bitmap, PADDING, 4, width - PADDING * 2,
                         HEADER_HEIGHT - 6, title.to_s, WHITE, SHADOW, 1)
      end
    end

    module Draw
      TRANSPARENT = Color.new(0, 0, 0, 0)

      module_function

      def with_alpha(color, alpha)
        Color.new(color.red, color.green, color.blue, alpha)
      rescue
        Color.new(255, 255, 255, alpha)
      end

      def rounded_rect(bitmap, x, y, width, height, radius, fill, border = nil)
        return unless bitmap && width > 0 && height > 0
        radius = [[radius.to_i, width / 2, height / 2].min, 0].max
        bitmap.fill_rect(x + radius, y, width - radius * 2, height, fill)
        bitmap.fill_rect(x, y + radius, radius, height - radius * 2, fill)
        bitmap.fill_rect(x + width - radius, y + radius, radius, height - radius * 2, fill)
        quarter_circle(bitmap, x + radius, y + radius, radius, fill, :top_left)
        quarter_circle(bitmap, x + width - radius - 1, y + radius, radius, fill, :top_right)
        quarter_circle(bitmap, x + radius, y + height - radius - 1, radius, fill, :bottom_left)
        quarter_circle(bitmap, x + width - radius - 1, y + height - radius - 1, radius, fill, :bottom_right)
        return unless border
        bitmap.fill_rect(x + radius, y, width - radius * 2, 2, border)
        bitmap.fill_rect(x + radius, y + height - 2, width - radius * 2, 2, border)
        bitmap.fill_rect(x, y + radius, 2, height - radius * 2, border)
        bitmap.fill_rect(x + width - 2, y + radius, 2, height - radius * 2, border)
      end

      def quarter_circle(bitmap, center_x, center_y, radius, color, corner)
        (0..radius).each do |dx|
          (0..radius).each do |dy|
            next unless dx * dx + dy * dy <= radius * radius
            px = center_x + ([:top_right, :bottom_right].include?(corner) ? dx : -dx)
            py = center_y + ([:bottom_left, :bottom_right].include?(corner) ? dy : -dy)
            bitmap.fill_rect(px, py, 1, 1, color)
          end
        end
      end

      def plain_text(bitmap, x, y, width, height, text, color, align = 0, size = nil)
        return unless bitmap
        old_size = bitmap.font.size rescue nil
        bitmap.font.size = size if size
        draw_x = x
        draw_align = 0
        case align
        when 1
          draw_x = x + width / 2
          draw_align = 2
        when 2
          draw_x = x + width
          draw_align = 1
        end
        pbDrawTextPositions(
          bitmap,
          [[text.to_s, draw_x, y, draw_align, color, TRANSPARENT]]
        )
        bitmap.font.size = old_size if size && old_size
      rescue
        bitmap.draw_text(x, y, width, height, text.to_s, align) rescue nil
      ensure
        bitmap.font.size = old_size if size && old_size rescue nil
      end

      def wrap_lines(bitmap, text, width)
        lines = []
        text.to_s.split(/\n/, -1).each do |paragraph|
          words = paragraph.split(/\s+/)
          if words.empty?
            lines << ""
            next
          end
          current = ""
          words.each do |word|
            candidate = current.empty? ? word : "#{current} #{word}"
            if !current.empty? && bitmap.text_size(candidate).width > width
              lines << current
              current = word
            else
              current = candidate
            end
          end
          lines << current unless current.empty?
        end
        lines.empty? ? [""] : lines
      rescue
        [text.to_s]
      end
    end

    module InputRouter
      MOUSE_BUTTONS = [:MOUSELEFT, :MOUSERIGHT, :MOUSEMIDDLE].freeze
      KEYBOARD_BUTTONS = [:UP, :DOWN, :LEFT, :RIGHT, :USE, :BACK, :ACTION, :SPECIAL,
                          :JUMPUP, :JUMPDOWN, :AUX1, :AUX2].freeze

      class << self
        attr_reader :last_method

        def update
          position = raw_position
          moved = position && @last_position && position != @last_position
          mouse_active = moved || mouse_button_active? || wheel_active?
          keyboard_active = keyboard_active?
          @last_method = :keyboard if keyboard_active
          @last_method = :mouse if mouse_active
          @last_position = position if position
          @active_position = mouse_active ? position : nil
          @active_position
        rescue
          @active_position = nil
        end

        def active_position
          update
        end

        def raw_position
          if defined?(Input) && Input.respond_to?(:mouse_x) && Input.respond_to?(:mouse_y)
            return [Input.mouse_x, Input.mouse_y]
          end
          return Mouse.getMousePos if defined?(Mouse) && Mouse.respond_to?(:getMousePos)
          nil
        rescue
          nil
        end

        def mouse_triggered?
          input_triggered?(:MOUSELEFT)
        end

        def wheel_delta
          return Input.scroll_v.to_i if defined?(Input) && Input.respond_to?(:scroll_v)
          return -1 if input_repeated?(:SCROLLUP)
          return 1 if input_repeated?(:SCROLLDOWN)
          0
        rescue
          0
        end

        def input_triggered?(name)
          return false unless defined?(Input) && Input.const_defined?(name)
          Input.trigger?(Input.const_get(name)) rescue false
        end

        def input_repeated?(name)
          return false unless defined?(Input) && Input.const_defined?(name)
          Input.repeat?(Input.const_get(name)) rescue false
        end

        private

        def keyboard_active?
          KEYBOARD_BUTTONS.any? { |name| input_triggered?(name) || input_repeated?(name) }
        end

        def mouse_button_active?
          MOUSE_BUTTONS.any? { |name| input_triggered?(name) }
        end

        def wheel_active?
          wheel_delta != 0
        end
      end
    end

    module Modal
      class << self
        def active?
          @depth.to_i > 0
        end

        def with_modal
          @depth = @depth.to_i + 1
          yield
        ensure
          @depth = [@depth.to_i - 1, 0].max
        end

        def drain_input
          2.times { Input.update rescue nil }
          30.times do
            break unless held?(:USE) || held?(:BACK) || held?(:MOUSELEFT)
            Graphics.update rescue nil
            Input.update rescue nil
          end
        rescue
          nil
        end

        private

        def held?(name)
          return false unless defined?(Input) && Input.const_defined?(name)
          Input.press?(Input.const_get(name)) rescue false
        end
      end
    end

    module PopupWindow
      SCREEN_W = 512
      SCREEN_H = 384
      MAX_W = SCREEN_W * 3 / 4
      MAX_H = SCREEN_H * 3 / 4
      MIN_W = 220
      MIN_H = 84
      PAD = 14
      ROW_H = 24
      LINE_H = 24
      MESSAGE_LINE_H = 26
      TEXT_SAFETY_PAD = 12
      LIST_JUMP = 3
      PANEL_RADIUS = 5

      WHITE = Color.new(255, 255, 255)
      GRAY = Color.new(175, 180, 200)
      DIM = Color.new(105, 110, 135)
      BLUE = Color.new(120, 190, 255)
      GREEN = Color.new(105, 224, 164)
      RED = Color.new(235, 96, 116)
      GOLD = Color.new(240, 200, 80)
      PANEL_BG = Color.new(8, 14, 28, 235)
      PANEL_BORDER = Color.new(60, 80, 130)
      DIM_BG = Color.new(0, 0, 0, 120)

      THEMES = {
        :hr => {
          :title => BLUE,
          :text => WHITE,
          :border => PANEL_BORDER,
          :background => PANEL_BG
        },
        :success => {
          :title => GREEN,
          :text => GREEN,
          :border => Color.new(50, 150, 90),
          :background => PANEL_BG
        },
        :warning => {
          :title => GOLD,
          :text => GOLD,
          :border => Color.new(180, 135, 40),
          :background => PANEL_BG
        },
        :error => {
          :title => RED,
          :text => RED,
          :border => Color.new(180, 60, 70),
          :background => PANEL_BG
        }
      }.freeze

      class << self
        def message(text, options = {})
          open(:message, text, [], options)
        end

        def dynamic_message(text_source, options = {})
          source = text_source.respond_to?(:call) ? text_source : proc { text_source.to_s }
          open(:message, source, [], options.merge(:dynamic_text => true))
        end

        def confirm(text, options = {})
          default_yes = !!options[:default]
          rows = [
            { :label => options[:yes_label] || _INTL("Yes"), :value => true },
            { :label => options[:no_label] || _INTL("No"), :value => false }
          ]
          open(:choice, text, rows, options.merge(:start_index => default_yes ? 0 : 1)) == true
        end

        def choice(title, commands, options = {})
          open(:choice, title, Array(commands), options)
        end

        def command(title, commands, options = {})
          choice(title, commands, options)
        end

        def carousel(title, entries, options = {})
          rows = Array(entries)
          return -1 if rows.empty?
          return fallback(:choice, title, rows) unless graphics_available?
          Modal.with_modal { CarouselScene.new(title, rows, options).main }
        rescue StandardError => e
          KantoReloaded::Log.exception("Shared UI carousel failed", e, channel: :ui) if defined?(KantoReloaded::Log)
          fallback(:choice, title, rows || [])
        ensure
          Modal.drain_input
        end

        def paged_summary(title, pages, options = {})
          entries = Array(pages)
          return -1 if entries.empty?
          return fallback(:choice, title, entries) unless graphics_available?
          Modal.with_modal { PagedSummaryScene.new(title, entries, options).main }
        rescue StandardError => e
          KantoReloaded::Log.exception("Shared UI paged summary failed", e, channel: :ui) if defined?(KantoReloaded::Log)
          fallback(:choice, title, entries || [])
        ensure
          Modal.drain_input
        end

        def open(kind, title, rows, options = {})
          return fallback(kind, title, rows) unless graphics_available?
          Modal.with_modal { PopupScene.new(kind, title, rows, options).main }
        rescue StandardError => e
          KantoReloaded::Log.exception("Shared UI popup failed", e, channel: :ui) if defined?(KantoReloaded::Log)
          fallback(kind, title, rows)
        ensure
          Modal.drain_input
        end

        private

        def graphics_available?
          defined?(Graphics) && defined?(Input) && defined?(Viewport) && defined?(Sprite) && defined?(Bitmap)
        end

        def fallback(kind, title, rows)
          resolved_title = title.respond_to?(:call) ? title.call : title
          return pbMessage(resolved_title.to_s) if kind == :message && defined?(pbMessage)
          if defined?(pbMessage)
            labels = rows.map { |row| row.is_a?(Hash) ? (row[:label] || row["label"]).to_s : row.to_s }
            index = pbMessage(resolved_title.to_s, labels, -1)
            selected = rows[index] if index && index >= 0
            return selected[:value] if selected.is_a?(Hash) && selected.has_key?(:value)
            return index
          end
          kind == :choice ? -1 : nil
        rescue
          kind == :choice ? -1 : nil
        end
      end

      class PopupScene
        def initialize(kind, title, rows, options)
          @kind = kind
          @title_source = title if title.respond_to?(:call)
          @title = resolve_title(title)
          @rows = Array(rows).each_with_index.map { |row, index| normalize_row(row, index) }
          @options = options.is_a?(Hash) ? options : {}
          theme_key = (@options[:theme] || :hr).to_sym rescue :hr
          @theme = THEMES[theme_key] || THEMES[:hr]
          @index = first_enabled_index(@options.fetch(:start_index, 0))
          @scroll = 0
          @text_scroll = 0
        end

        def main
          setup
          result = update_loop
          result
        ensure
          dispose
        end

        private

        def setup
          @viewport = Viewport.new(0, 0, SCREEN_W, SCREEN_H)
          @viewport.z = (@options[:z] || 999_999_999).to_i
          @dim_sprite = Sprite.new(@viewport)
          @dim_sprite.bitmap = Bitmap.new(SCREEN_W, SCREEN_H)
          @dim_sprite.bitmap.fill_rect(0, 0, SCREEN_W, SCREEN_H, DIM_BG) unless @options[:show_dim] == false
          calculate_layout
          @sprite = Sprite.new(@viewport)
          @sprite.bitmap = Bitmap.new(@width, @height)
          @sprite.x = (SCREEN_W - @width) / 2
          @sprite.y = (SCREEN_H - @height) / 2
          @sprite.z = @viewport.z
          draw
        end

        def calculate_layout
          measure = Bitmap.new(1, 1)
          pbSetSmallFont(measure) if defined?(pbSetSmallFont)
          title_width = (measure.text_size(@title).width rescue MIN_W) + PAD * 2 + TEXT_SAFETY_PAD
          preferred = @options[:width] ? @options[:width].to_i : title_width
          preferred = [[preferred, MIN_W].max, MAX_W].min
          @lines = Draw.wrap_lines(measure, @title, preferred - PAD * 2)
          row_width = @rows.map do |row|
            (measure.text_size(row[:label]).width rescue MIN_W) + PAD * 2 + TEXT_SAFETY_PAD
          end.max || MIN_W
          @width = [[preferred, row_width, MIN_W].max, MAX_W].min
          @lines = Draw.wrap_lines(measure, @title, @width - PAD * 2)
          line_h = choice? ? LINE_H : MESSAGE_LINE_H
          message_h = [@lines.length * line_h, line_h].max
          rows_h = choice? ? @rows.length * ROW_H : 0
          gap = choice? ? 4 : 12
          desired_h = (choice? ? 4 : PAD) + message_h + gap + rows_h + PAD
          @height = [[desired_h, MIN_H].max, MAX_H].min
          @content_y = choice? ? 4 : PAD
          @rows_y = @content_y + message_h + 4
          @visible_rows = choice? ? [[(@height - @rows_y - PAD) / ROW_H, 1].max, @rows.length].min : 0
          @visible_text_lines = choice? ? @lines.length : [(@height - PAD * 2 - gap) / MESSAGE_LINE_H, 1].max
          measure.dispose rescue nil
          ensure_visible
        end

        def update_loop
          loop do
            Graphics.update
            Input.update
            return nil if close_requested?
            dynamic_changed = refresh_dynamic_title
            if !choice?
              return nil if trigger?(:USE) || trigger?(:BACK) || InputRouter.mouse_triggered?
            else
              mouse_result = update_mouse
              return mouse_result unless mouse_result == :continue
              if repeat?(:UP)
                move(-1)
              elsif repeat?(:DOWN)
                move(1)
              elsif repeat?(:LEFT)
                move(-LIST_JUMP)
              elsif repeat?(:RIGHT)
                move(LIST_JUMP)
              elsif trigger?(:USE)
                row = @rows[@index]
                return row[:value] if row && row[:enabled] && row[:selectable]
              elsif trigger?(:BACK)
                return -1
              end
            end
            draw if dynamic_changed || ((Graphics.frame_count rescue 0) % 4).zero?
          end
        end

        def resolve_title(source)
          source.respond_to?(:call) ? source.call.to_s : source.to_s
        rescue
          ""
        end

        def refresh_dynamic_title
          return false unless @title_source
          next_title = resolve_title(@title_source)
          return false if next_title == @title
          @title = next_title
          @lines = Draw.wrap_lines(@sprite.bitmap, @title, @width - PAD * 2)
          @text_scroll = [[@text_scroll, 0].max, [@lines.length - @visible_text_lines, 0].max].min
          true
        rescue
          false
        end

        def close_requested?
          callback = @options[:close_if]
          callback.respond_to?(:call) && callback.call
        rescue
          false
        end

        def update_mouse
          delta = InputRouter.wheel_delta
          move(delta < 0 ? 1 : -1) unless delta == 0
          position = InputRouter.active_position
          return :continue unless position
          local_x = position[0] - @sprite.x
          local_y = position[1] - @sprite.y
          return :continue if local_x < 0 || local_x >= @width || local_y < @rows_y
          local_row = (local_y - @rows_y) / ROW_H
          return :continue if local_row < 0 || local_row >= @visible_rows
          row = @scroll + local_row
          return :continue if row >= @rows.length ||
                              !@rows[row][:enabled] ||
                              !@rows[row][:selectable]
          if @index != row
            @index = row
            ensure_visible
            pbPlayCursorSE rescue nil
            draw
          end
          InputRouter.mouse_triggered? ? @rows[@index][:value] : :continue
        end

        def move(amount)
          return if @rows.empty?
          old = @index
          @rows.length.times do
            @index = (@index + amount) % @rows.length
            break if @rows[@index][:enabled] && @rows[@index][:selectable]
          end
          if old != @index
            ensure_visible
            pbPlayCursorSE rescue nil
            draw
          end
        end

        def draw
          bitmap = @sprite.bitmap
          bitmap.clear
          pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
          border = @theme[:border] || PANEL_BORDER
          background = @theme[:background] || PANEL_BG
          Draw.rounded_rect(bitmap, 0, 0, @width, @height, PANEL_RADIUS, border)
          Draw.rounded_rect(bitmap, 1, 1, @width - 2, @height - 2, PANEL_RADIUS - 1, background)
          if choice?
            @lines.each_with_index do |line, line_index|
              Draw.plain_text(
                bitmap, 10, @content_y - 4 + line_index * LINE_H,
                @width - 20, LINE_H, line, @theme[:title] || BLUE, 1
              )
            end
          else
            visible = @lines[@text_scroll, @visible_text_lines] || []
            visible.each_with_index do |line, line_index|
              align = @options[:center_text] ? 1 : 0
              Draw.plain_text(
                bitmap, PAD, PAD + line_index * MESSAGE_LINE_H,
                @width - PAD * 2, MESSAGE_LINE_H, line,
                @theme[:text] || WHITE, align
              )
            end
            return
          end
          visible = @rows[@scroll, @visible_rows] || []
          visible.each_with_index do |row, local_index|
            index = @scroll + local_index
            y = @rows_y + local_index * ROW_H
            if index == @index
              pulse = Math.sin((Graphics.frame_count rescue 0) * Math::PI / 20.0) * 0.5 + 0.5
              base, border = cursor_colors
              fill = Draw.with_alpha(base, [[base.alpha.to_i + (pulse * 55).to_i, 255].min, 80].max)
              Draw.rounded_rect(bitmap, 10, y + 2, @width - 20, 20, 4, fill, border)
            end
            color = row[:enabled] ? (index == @index ? WHITE : GRAY) : DIM
            align = row[:align].nil? ? 0 : row[:align]
            x = align == 1 ? 12 : 18
            Draw.plain_text(
              bitmap, x, y - 5, @width - x - 18, 22,
              row[:label], color, align
            )
          end
        end

        def normalize_row(row, index)
          unless row.is_a?(Hash)
            return {
              :label => row.to_s, :enabled => true, :selectable => true,
              :align => nil, :value => index
            }
          end
          enabled = row.fetch(:enabled, row.fetch("enabled", !row[:disabled] && !row["disabled"]))
          selectable = row.fetch(:selectable, row.fetch("selectable", enabled))
          value = row.has_key?(:value) ? row[:value] : (row.has_key?("value") ? row["value"] : index)
          {
            :label => (row[:label] || row[:name] || row["label"] || row["name"]).to_s,
            :enabled => !!enabled,
            :selectable => !!selectable,
            :align => row.has_key?(:align) ? row[:align] : row["align"],
            :value => value
          }
        end

        def first_enabled_index(preferred)
          preferred = preferred.to_i
          if @rows[preferred] && @rows[preferred][:enabled] &&
             @rows[preferred][:selectable]
            return preferred
          end
          @rows.index { |row| row[:enabled] && row[:selectable] } || 0
        end

        def ensure_visible
          return unless choice?
          @scroll = @index if @index < @scroll
          @scroll = @index - @visible_rows + 1 if @index >= @scroll + @visible_rows
          @scroll = [[@scroll, 0].max, [@rows.length - @visible_rows, 0].max].min
        end

        def cursor_colors
          return KantoReloaded::Options.cursor_colors if defined?(KantoReloaded::Options)
          [Color.new(100, 160, 220, 160), Color.new(60, 120, 180, 220)]
        rescue
          [Color.new(100, 160, 220, 160), Color.new(60, 120, 180, 220)]
        end

        def choice?
          @kind == :choice
        end

        def trigger?(name)
          InputRouter.input_triggered?(name)
        end

        def repeat?(name)
          InputRouter.input_repeated?(name)
        end

        def dispose
          if @dim_sprite
            @dim_sprite.bitmap.dispose if @dim_sprite.bitmap && !@dim_sprite.bitmap.disposed?
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

      class PagedSummaryScene
        DETAIL_H = 20
        MIN_DETAILS = 3

        def initialize(title, pages, options)
          @title = title.to_s
          @pages = Array(pages).map { |page| normalize_page(page) }
          @options = options.is_a?(Hash) ? options : {}
          @page_index = normalized_start_index(@options.fetch(:start_index, 0))
          theme_key = (@options[:theme] || :hr).to_sym rescue :hr
          @theme = THEMES[theme_key] || THEMES[:hr]
        end

        def main
          setup
          update_loop
        ensure
          dispose
        end

        private

        def setup
          @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
          @viewport.z = (@options[:z] || 999_999_999).to_i
          @dim_sprite = Sprite.new(@viewport)
          @dim_sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
          unless @options[:show_dim] == false
            @dim_sprite.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, DIM_BG)
          end
          calculate_layout
          @sprite = Sprite.new(@viewport)
          @sprite.bitmap = Bitmap.new(@width, @height)
          @sprite.x = (Graphics.width - @width) / 2
          @sprite.y = (Graphics.height - @height) / 2
          @sprite.z = @viewport.z
          draw
        end

        def calculate_layout
          measure = Bitmap.new(1, 1)
          pbSetSmallFont(measure) if defined?(pbSetSmallFont)
          labels = [@title]
          @pages.each do |page|
            labels << page[:label]
            labels.concat(page[:details].map { |detail| detail_measure_text(detail) })
          end
          text_width = labels.inject(MIN_W) do |maximum, label|
            [maximum, (measure.text_size(label).width rescue MIN_W) + PAD * 2 + TEXT_SAFETY_PAD].max
          end
          @width = [[(@options[:width] || text_width).to_i, MIN_W].max, MAX_W].min
          @detail_count = [@pages.map { |page| page[:details].length }.max.to_i, MIN_DETAILS].max
          desired_height = 38 + 24 + @detail_count * DETAIL_H + 10 + 24 + 10
          @height = [[desired_height, MIN_H].max, MAX_H].min
          @summary_y = 36
          @details_y = @summary_y + 26
          @ok_y = @height - 34
          measure.dispose rescue nil
        end

        def update_loop
          loop do
            Graphics.update
            Input.update
            mouse_result = update_mouse
            return mouse_result unless mouse_result == :continue
            if repeat?(:LEFT)
              move(-1)
            elsif repeat?(:RIGHT)
              move(1)
            elsif trigger?(:USE)
              pbPlayDecisionSE rescue nil
              return current_page[:value]
            elsif trigger?(:BACK)
              pbPlayCancelSE rescue nil
              return -1
            end
            draw if ((Graphics.frame_count rescue 0) % 4).zero?
          end
        end

        def update_mouse
          delta = InputRouter.wheel_delta
          move(delta < 0 ? 1 : -1) unless delta == 0
          position = InputRouter.active_position
          return :continue unless position && InputRouter.mouse_triggered?
          local_x = position[0] - @sprite.x
          local_y = position[1] - @sprite.y
          return :continue if local_x < 0 || local_x >= @width ||
                              local_y < 0 || local_y >= @height
          if @pages.length > 1 && local_y >= 0 && local_y < @summary_y
            move(local_x < @width / 2 ? -1 : 1)
            return :continue
          end
          pbPlayDecisionSE rescue nil
          current_page[:value]
        end

        def move(amount)
          return if @pages.length <= 1
          next_index = @page_index + amount.to_i
          next_index = 0 if next_index < 0
          next_index = @pages.length - 1 if next_index >= @pages.length
          return if next_index == @page_index
          @page_index = next_index
          pbPlayCursorSE rescue nil
          draw
        end

        def draw
          bitmap = @sprite.bitmap
          bitmap.clear
          pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
          border = @theme[:border] || PANEL_BORDER
          background = @theme[:background] || PANEL_BG
          Draw.rounded_rect(bitmap, 0, 0, @width, @height, PANEL_RADIUS, border)
          Draw.rounded_rect(bitmap, 1, 1, @width - 2, @height - 2,
                            PANEL_RADIUS - 1, background)
          Draw.plain_text(bitmap, PAD, 4, @width - PAD * 2, 26, @title,
                          @theme[:title] || BLUE, 1)
          draw_page_arrows(bitmap)
          Draw.plain_text(bitmap, 30, @summary_y, @width - 60, 22,
                          current_page[:label], WHITE, 1)
          current_page[:details].each_with_index do |detail, index|
            draw_detail(bitmap, detail, @details_y + index * DETAIL_H)
          end
          draw_ok(bitmap)
        end

        def draw_page_arrows(bitmap)
          return unless @pages.length > 1
          title_width = bitmap.text_size(@title).width rescue (@width / 2)
          left_x = [(@width - title_width) / 2 - 24, 8].max
          right_x = [(@width + title_width) / 2, @width - 32].min
          color = @theme[:title] || GREEN
          if @page_index > 0
            Draw.plain_text(bitmap, left_x, 4, 20, 26, "<", color, 1, 20)
          end
          if @page_index < @pages.length - 1
            Draw.plain_text(bitmap, right_x, 4, 20, 26, ">", color, 1, 20)
          end
        end

        def draw_ok(bitmap)
          pulse = Math.sin((Graphics.frame_count rescue 0) * Math::PI / 20.0) * 0.5 + 0.5
          base, border = cursor_colors
          fill = Draw.with_alpha(
            base,
            [[base.alpha.to_i + (pulse * 55).to_i, 255].min, 80].max
          )
          Draw.rounded_rect(bitmap, 10, @ok_y + 1, @width - 20, 20, 4, fill, border)
          Draw.plain_text(bitmap, 18, @ok_y - 6, @width - 36, 22,
                          _INTL("OK"), WHITE, 1)
        end

        def draw_detail(bitmap, detail, y)
          unless detail.is_a?(Hash)
            Draw.plain_text(bitmap, 22, y, @width - 44, DETAIL_H,
                            detail.to_s, GRAY, 0)
            return
          end
          label = detail[:label].to_s
          normal = detail[:normal].to_s
          critical = detail[:critical].to_s
          right_x = @width - 22
          unless critical.empty?
            width = bitmap.text_size(critical).width rescue 28
            Draw.plain_text(bitmap, right_x - width, y, width, DETAIL_H,
                            critical, GREEN, 2)
            right_x -= width + 12
          end
          unless normal.empty?
            width = bitmap.text_size(normal).width rescue 28
            Draw.plain_text(bitmap, right_x - width, y, width, DETAIL_H,
                            normal, WHITE, 2)
            right_x -= width + 12
          end
          Draw.plain_text(bitmap, 22, y, [right_x - 28, 0].max, DETAIL_H,
                          label, GRAY, 0)
        end

        def normalize_page(page)
          unless page.is_a?(Hash)
            return { :label => page.to_s, :details => [], :value => true }
          end
          label = page[:label] || page[:name] || page["label"] || page["name"]
          details = page[:details] || page[:detail] || page["details"] || page["detail"]
          value = if page.has_key?(:value)
                    page[:value]
                  elsif page.has_key?("value")
                    page["value"]
                  else
                    true
                  end
          {
            :label => label.to_s,
            :details => Array(details).map { |detail| normalize_detail(detail) }.compact,
            :value => value
          }
        end

        def normalize_detail(detail)
          return detail.to_s unless detail.is_a?(Hash)
          label = detail[:label] || detail[:name] || detail["label"] || detail["name"]
          normal = detail[:normal] || detail["normal"]
          critical = detail[:critical] || detail["critical"]
          return nil if label.to_s.empty? && normal.to_s.empty? && critical.to_s.empty?
          {
            :label => label.to_s,
            :normal => normal.to_s,
            :critical => critical.to_s
          }
        end

        def detail_measure_text(detail)
          return detail.to_s unless detail.is_a?(Hash)
          [detail[:label], detail[:normal], detail[:critical]].map(&:to_s).
            reject(&:empty?).join("  ")
        end

        def current_page
          @pages[@page_index] || { :label => "", :details => [], :value => true }
        end

        def normalized_start_index(value)
          return 0 if @pages.empty?
          [[value.to_i, 0].max, @pages.length - 1].min
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
            @dim_sprite.bitmap.dispose if @dim_sprite.bitmap && !@dim_sprite.bitmap.disposed?
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

      class CarouselScene
        WIDTH = 320
        HEIGHT = 236
        ICON_Y = 88

        def initialize(title, rows, options)
          @title = title.to_s
          @sources = Array(rows)
          @options = options.is_a?(Hash) ? options : {}
          @index = normalized_start_index(@options.fetch(:start_index, 0))
        end

        def main
          setup
          update_loop
        ensure
          dispose
        end

        private

        def setup
          @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
          @viewport.z = (@options[:z] || 999_999_999).to_i
          @dim_sprite = Sprite.new(@viewport)
          @dim_sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
          @dim_sprite.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, DIM_BG) unless @options[:show_dim] == false
          @width = [[(@options[:width] || WIDTH).to_i, MIN_W].max, Graphics.width * 3 / 4].min
          @height = [[(@options[:height] || HEIGHT).to_i, 180].max, Graphics.height * 3 / 4].min
          @sprite = Sprite.new(@viewport)
          @sprite.bitmap = Bitmap.new(@width, @height)
          @sprite.x = (Graphics.width - @width) / 2
          @sprite.y = (Graphics.height - @height) / 2
          create_item_icon
          refresh
        end

        def create_item_icon
          return unless defined?(ItemIconSprite)
          @item_icon = ItemIconSprite.new(@sprite.x + @width / 2, @sprite.y + ICON_Y, current_item, @viewport)
          @item_icon.z = @viewport.z + 2
          @item_icon.setOffset(PictureOrigin::Center) if defined?(PictureOrigin)
          @item_icon.zoom_x = 1.5
          @item_icon.zoom_y = 1.5
        rescue
          @item_icon = nil
        end

        def update_loop
          loop do
            Graphics.update
            Input.update
            @item_icon.update if @item_icon && !@item_icon.disposed?
            mouse_result = update_mouse
            return mouse_result unless mouse_result == :continue
            if repeat?(:LEFT)
              move(-1)
            elsif repeat?(:RIGHT)
              move(1)
            elsif trigger?(:USE)
              return current_value if selectable?(current_source)
              pbPlayBuzzerSE rescue nil
            elsif trigger?(:ACTION)
              perform_action
            elsif trigger?(:BACK)
              pbPlayCancelSE rescue nil
              return -1
            end
          end
        end

        def update_mouse
          delta = InputRouter.wheel_delta
          move(delta < 0 ? 1 : -1) unless delta == 0
          position = InputRouter.active_position
          left_click = InputRouter.mouse_triggered?
          right_click = InputRouter.input_triggered?(:MOUSERIGHT)
          return :continue unless position && (left_click || right_click)
          local_x = position[0] - @sprite.x
          local_y = position[1] - @sprite.y
          return :continue if local_x < 0 || local_x >= @width || local_y < 0 || local_y >= @height
          if right_click
            perform_action
            return :continue
          end
          if local_x < 72
            move(-1)
          elsif local_x >= @width - 72
            move(1)
          elsif local_y >= 42 && local_y < @height - 38
            return current_value if selectable?(current_source)
            pbPlayBuzzerSE rescue nil
          end
          :continue
        end

        def move(amount)
          return if @sources.length <= 1
          @index = (@index + amount) % @sources.length
          pbPlayCursorSE rescue nil
          refresh
        end

        def perform_action
          callback = @options[:on_action]
          unless callback.respond_to?(:call)
            pbPlayBuzzerSE rescue nil
            return
          end
          callback.call(current_value, current_source)
          pbPlayDecisionSE rescue nil
          refresh
        rescue StandardError => e
          KantoReloaded::Log.exception("Popup carousel action failed", e, channel: :ui) if defined?(KantoReloaded::Log)
          pbPlayBuzzerSE rescue nil
        end

        def refresh
          if @item_icon && !@item_icon.disposed?
            @item_icon.item = current_item
            @item_icon.visible = !current_item.nil?
          end
          draw
        end

        def draw
          bitmap = @sprite.bitmap
          bitmap.clear
          pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
          Draw.rounded_rect(bitmap, 0, 0, @width, @height, PANEL_RADIUS, PANEL_BORDER)
          Draw.rounded_rect(bitmap, 1, 1, @width - 2, @height - 2, PANEL_RADIUS - 1, PANEL_BG)
          Draw.plain_text(bitmap, PAD, 5, @width - PAD * 2, 26, @title, BLUE, 1)
          Draw.plain_text(bitmap, 18, ICON_Y - 13, 42, 26, "<", WHITE, 1, 26)
          Draw.plain_text(bitmap, @width - 60, ICON_Y - 13, 42, 26, ">", WHITE, 1, 26)
          Draw.plain_text(bitmap, PAD, 126, @width - PAD * 2, 26, current_label, current_color, 1)
          details = current_details
          details.each_with_index do |line, index|
            Draw.plain_text(bitmap, PAD, 151 + index * 20, @width - PAD * 2, 20, line, detail_color(line), 1, 16)
          end
          draw_footer(bitmap)
        end

        def draw_footer(bitmap)
          return unless defined?(KantoReloaded::UI::HintText)
          hints = [KantoReloaded::UI::HintText.confirm("Select"), KantoReloaded::UI::HintText.back("Back")]
          action_label = value_for(current_source, :action_label).to_s
          hints << KantoReloaded::UI::HintText.action(action_label) unless action_label.empty?
          KantoReloaded::UI::HintText.draw(bitmap, hints, PAD, @height - 28, @width - PAD * 2, :size => 14)
        rescue
          nil
        end

        def current_source
          @sources[@index] || {}
        end

        def current_value
          source = current_source
          return @index unless source.is_a?(Hash)
          source.has_key?(:value) ? source[:value] : (source.has_key?("value") ? source["value"] : @index)
        end

        def current_item
          value_for(current_source, :item)
        end

        def current_label
          value = value_for(current_source, :label)
          value = value_for(current_source, :name) if value.nil? || value.to_s.empty?
          value.to_s
        end

        def current_details
          value = value_for(current_source, :details)
          value = value_for(current_source, :detail) if value.nil?
          Array(value).map(&:to_s).reject(&:empty?).first(2)
        end

        def selectable?(source)
          value = value_for(source, :selectable)
          value.nil? ? true : !!value
        end

        def current_color
          selectable?(current_source) ? WHITE : DIM
        end

        def detail_color(line)
          line.to_s.upcase.include?("BLOCKED") ? Color.new(235, 110, 110) : GRAY
        end

        def value_for(source, key)
          return nil unless source.is_a?(Hash)
          value = source.has_key?(key) ? source[key] : source[key.to_s]
          value.respond_to?(:call) ? value.call : value
        end

        def normalized_start_index(value)
          return 0 if @sources.empty?
          [[value.to_i, 0].max, @sources.length - 1].min
        end

        def trigger?(name)
          InputRouter.input_triggered?(name)
        end

        def repeat?(name)
          InputRouter.input_repeated?(name)
        end

        def dispose
          @item_icon.dispose if @item_icon && !@item_icon.disposed?
          if @dim_sprite
            @dim_sprite.bitmap.dispose if @dim_sprite.bitmap && !@dim_sprite.bitmap.disposed?
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

    module Toast
      class << self
        def show(text, options = {})
          PopupWindow.message(text, options)
        end
        alias message show

        def success(text, options = {})
          show(text, options.merge(:theme => :success))
        end

        def warning(text, options = {})
          show(text, options.merge(:theme => :warning))
        end

        def error(text, options = {})
          show(text, options.merge(:theme => :error))
        end

        def ok(text, options = {})
          show(text, options.merge(:theme => :success))
        end

        def custom(title, rows = [], options = {})
          entries = Array(rows)
          return PopupWindow.message(title, options) if entries.empty?
          PopupWindow.choice(title, entries, options)
        end

        def rows(title, rows, options = {})
          entries = Array(rows).compact
          entries << {
            :label => options[:ok_label] || _INTL("OK"),
            :value => true,
            :align => 1
          }
          PopupWindow.choice(
            title.to_s, entries,
            options.merge(:start_index => entries.length - 1)
          )
          true
        rescue StandardError
          false
        end
      end
    end

    module HintText
      ORDER = { :confirm => 0, :back => 1, :action => 2, :special => 3, :other => 4 }.freeze
      BUTTON_LABELS = {
        :confirm => "C",
        :back => "B",
        :action => "A",
        :special => "Z",
        :left => "<",
        :right => ">",
        :page => "< >",
        :pocket => "< >",
        :sort => "L",
        :quick => "R",
        :menu => "C"
      }.freeze

      class << self
        def confirm(label = "Confirm")
          entry(:confirm, label, "C")
        end

        def back(label = "Back")
          entry(:back, label, "B")
        end

        def action(label = "Action")
          entry(:action, label, "A")
        end

        def special(label = "Special")
          entry(:special, label, "Z")
        end

        def other(label, button = nil)
          entry(:other, label, button || "")
        end

        def entry(type, label, button = nil)
          { :type => type.to_sym, :label => label.to_s, :button => button }
        end

        def status(text, color = nil, options = {})
          return nil if text.nil? || text.to_s.empty?
          {
            :text => text.to_s,
            :color => color || options[:color] || Color.new(238, 242, 246)
          }
        end

        def format(entries, _options = {})
          ordered(entries).map do |value|
            button = button_label(value[:button])
            button.empty? ? value[:label].to_s : "#{value[:label]} (#{button})"
          end.join("   ")
        end

        def draw(bitmap, entries, x, y, width, options = {})
          color = options[:color] || Color.new(238, 242, 246)
          size = options[:size] || 16
          Draw.plain_text(bitmap, x, y, width, options[:height] || 24, format(entries), color, options[:align] || 1, size)
        end

        def draw_footer(bitmap, entries, x, y, width, options = {})
          pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
          bitmap.font.size = (options[:size] || 16).to_i if bitmap.respond_to?(:font) && bitmap.font
          hint = options[:hint_entry] || other(options[:hint_label] || "Hints", "Z")
          hint_text = format([hint])
          hint_width = [bitmap.text_size(hint_text).width + 8, width / 3].min
          center_width = [width - hint_width - 8, 0].max
          footer_y = y + options.fetch(:y_offset, 0).to_i
          statuses = normalize_statuses(options[:statuses])
          if statuses.empty?
            draw(bitmap, entries, x, footer_y, center_width, options.merge(:align => 1))
          else
            draw_statuses(bitmap, statuses, x, footer_y, center_width, options)
          end
          unless options[:show_hint] == false
            draw(bitmap, [hint], x + width - hint_width, footer_y, hint_width, options.merge(:align => 2))
          end
        rescue
          draw(bitmap, entries, x, y, width, options)
        end

        def triggered?
          InputRouter.input_triggered?(:SPECIAL)
        end

        def open_popup(title, entries, options = {})
          rows = ordered(entries)
          rows.reject! { |value| value[:label].to_s.start_with?("Sort:") }
          return false if rows.empty?
          statuses = normalize_statuses(options[:statuses])
          statuses.reject! { |value| value[:text].to_s.start_with?("Sort:") }
          width = controls_popup_width(rows)
          Toast.rows(
            "Controls", controls_popup_rows(rows),
            options.merge(
              :statuses => statuses,
              :width => width,
              :row_width => width
            )
          )
        end

        def controls_at?(bitmap, mouse_x, mouse_y, x, y, width, options = {})
          label = format([options[:hint_entry] || other(options[:hint_label] || "Hints", "Z")])
          label_width = bitmap.text_size(label).width + 8
          mouse_x >= x + width - label_width && mouse_x < x + width &&
            mouse_y >= y && mouse_y < y + (options[:height] || 24)
        rescue
          false
        end

        private

        def button_label(button)
          return "" if button.nil?
          return BUTTON_LABELS[button] || button.to_s if button.is_a?(Symbol)
          button.to_s
        end

        def normalize_statuses(statuses)
          Array(statuses).compact.map do |value|
            if value.is_a?(Hash)
              text = value[:text] || value["text"] || value[:label] || value["label"]
              next nil if text.nil? || text.to_s.empty?
              { :text => text.to_s, :color => value[:color] || value["color"] || Color.new(238, 242, 246) }
            else
              { :text => value.to_s, :color => Color.new(238, 242, 246) }
            end
          end.compact
        rescue
          []
        end

        def draw_statuses(bitmap, statuses, x, y, width, options)
          separator = " | "
          pieces = []
          statuses.each_with_index do |status, index|
            pieces << status
            pieces << { :text => separator, :color => options[:color] || Color.new(238, 242, 246) } if index < statuses.length - 1
          end
          total_width = pieces.inject(0) { |sum, piece| sum + bitmap.text_size(piece[:text]).width }
          cursor_x = x + [[(width - total_width) / 2, 0].max, width].min
          pieces.each do |piece|
            pbDrawTextPositions(bitmap, [[piece[:text], cursor_x, y, 0, piece[:color], Draw::TRANSPARENT]])
            cursor_x += bitmap.text_size(piece[:text]).width
          end
        rescue
          nil
        end

        def controls_popup_width(rows)
          scratch = Bitmap.new(1, 1)
          pbSetSmallFont(scratch) if defined?(pbSetSmallFont)
          scratch.font.size = 18 if scratch.respond_to?(:font) && scratch.font
          text_width = rows.inject(0) do |maximum, row|
            [maximum, scratch.text_size(format([row])).width].max
          end
          scratch.dispose unless scratch.disposed?
          [[text_width + 64, 292].max, 384].min
        rescue StandardError
          320
        end

        def controls_popup_rows(rows)
          rows.map do |row|
            {
              :label => format([row]),
              :selectable => false,
              :value => nil
            }
          end
        rescue StandardError
          []
        end

        def ordered(entries)
          Array(entries).each_with_index.sort_by do |value, index|
            entry_value = value.is_a?(Hash) ? value : other(value.to_s)
            [ORDER.fetch(entry_value[:type].to_sym, ORDER[:other]), index]
          end.map { |value, _index| value.is_a?(Hash) ? value : other(value.to_s) }
        end
      end
    end
  end

  MouseInput = UI::InputRouter unless const_defined?(:MouseInput, false)
  PopupWindow = UI::PopupWindow unless const_defined?(:PopupWindow, false)
  Toast = UI::Toast unless const_defined?(:Toast, false)
  HintText = UI::HintText unless const_defined?(:HintText, false)

  class << self
    def message(text, options = {})
      return PopupWindow.message(text.to_s, options) if const_defined?(:PopupWindow, false)
      receiver = Object.new
      receiver.__send__(:pbMessage, text.to_s) if receiver.respond_to?(:pbMessage, true)
      true
    rescue StandardError => e
      KantoReloaded::Log.exception("Message display failed", e, channel: :ui) if defined?(KantoReloaded::Log)
      false
    end

    def confirm(text, options = {})
      return PopupWindow.confirm(text.to_s, options) if const_defined?(:PopupWindow, false)
      receiver = Object.new
      return false unless receiver.respond_to?(:pbMessage, true)
      labels = [defined?(_INTL) ? _INTL("No") : "No", defined?(_INTL) ? _INTL("Yes") : "Yes"]
      receiver.__send__(:pbMessage, text.to_s, labels, options[:default] == true ? 1 : 0) == 1
    rescue StandardError => e
      KantoReloaded::Log.exception("Confirmation display failed", e, channel: :ui) if defined?(KantoReloaded::Log)
      false
    end

    def toast(text, options = {})
      return Toast.show(text.to_s, options) if const_defined?(:Toast, false)
      message(text, options)
    rescue StandardError => e
      KantoReloaded::Log.exception("Toast display failed", e, channel: :ui) if defined?(KantoReloaded::Log)
      false
    end

    def toast_success(text, options = {})
      return Toast.success(text.to_s, options) if const_defined?(:Toast, false)
      message(text, options.merge(:theme => :success))
    end

    def toast_warning(text, options = {})
      return Toast.warning(text.to_s, options) if const_defined?(:Toast, false)
      message(text, options.merge(:theme => :warning))
    end

    def toast_error(text, options = {})
      return Toast.error(text.to_s, options) if const_defined?(:Toast, false)
      message(text, options.merge(:theme => :error))
    end
  end
end
