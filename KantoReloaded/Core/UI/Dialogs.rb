#==============================================================================
# Kanto Reloaded: popups
#==============================================================================
# Kanto Reloaded's own popups, in the pixel style and the screen's theme,
# instead of the game's message and choice windows (approved mockups M1,
# C1, C2 and the colour pickers):
#
#   Dialogs.menu(scene, title, labels, descriptions)  index, or nil on Back;
#                                                     a label can be [input,
#                                                     text]: its button icon
#   Dialogs.ask(scene, title, text, segments, buttons) the button chosen;
#                                                     segments: coloured lines
#                                                     under the text
#   Dialogs.confirm(scene, title, text, yes, no)      true / false
#   Dialogs.notice(scene, title, text)                shows it until OK
#   Dialogs.number(scene, title, value, min, max, step, unit)
#                                                     the value, or nil; icon:
#                                                     an item's picture beside
#                                                     it, note: proc(value) a
#                                                     line under it, format:
#                                                     proc(value) its words
#                                                     (money: ₽5,000)
#   Dialogs.frame(bitmap, colours, x, y, w, h, title) a popup of a screen's own
#                                                     (dimmed behind, the
#                                                     plate, its title)
#   Dialogs.drawn(scene, count, choice) { |b, c, choice| }
#                                                     buttons on a popup the
#                                                     block draws (frame, then
#                                                     button_row); the button
#                                                     chosen
#   Dialogs.picker(scene, title, values, index, swatch)
#                                                     index, or nil; swatch
#                                                     :text or :cursor draws
#                                                     each colour
#
# The scene gives an overlay bitmap (scene.overlay) and its colours
# (scene.palette). Each popup dims the screen and runs its own loop.
# Controller first: Up/Down or Left/Right move, A chooses, B backs out. The
# mouse too (Pointer): a click on a row or button chooses it, the wheel
# moves (in a number: up adds), a right click backs out.
#==============================================================================

module Reloaded
  module Dialogs
    MENU_W   = 300
    MENU_ROW = 24
    MENU_MAX = 8          # rows before the list scrolls
    TEXT_W   = 380
    PICK_W   = 250
    PICK_ROW = 22
    PICK_MAX = 9
    SCREEN_W = 512
    SCREEN_H = 384
    CUT      = 12         # the frame's cut corners (top left, bottom right)

    class << self
      #------------------------------------------------------------------------
      # M1: a centred list of actions; the highlighted one explained below
      #------------------------------------------------------------------------
      def menu(scene, title, labels, descriptions = [], index = 0)
        return nil if labels.empty?
        index = [[index, 0].max, labels.length - 1].min
        result = list_loop(scene, labels.length, index, MENU_MAX) do |i, top|
          draw_menu(scene.overlay, scene.palette, title, labels, descriptions, i, top)
        end
        return result
      end

      #------------------------------------------------------------------------
      # Colour and long-list picker
      #------------------------------------------------------------------------
      # More swatches for pickers: name => proc(bitmap, colours, x, row y,
      # row height, value index) that draws one before the value and returns
      # its width (Window Frames draws each frame).
      def swatches
        @swatches ||= {}
      end

      def picker(scene, title, values, index = 0, swatch = nil)
        return nil if values.empty?
        return list_loop(scene, values.length, index.to_i, PICK_MAX) do |i, top|
          draw_picker(scene.overlay, scene.palette, title, values, i, top, swatch)
        end
      end

      #------------------------------------------------------------------------
      # C1 / C2: a message with a row of buttons
      #------------------------------------------------------------------------
      def confirm(scene, title, text, yes = nil, no = nil, default_yes = true)
        buttons = [yes || _INTL("Yes"), no || _INTL("No")]
        return buttons_dialog(scene, title, text, buttons, default_yes ? 0 : 1) == 0
      end

      def notice(scene, title, text, ok = nil)
        buttons_dialog(scene, title, text, [ok || _INTL("OK")], 0)
        return true
      end

      # A question with buttons, and coloured lines under it (segments as
      # Pixel.small_rich takes them). The chosen button's index.
      def ask(scene, title, text, segments, buttons, choice = 0)
        return buttons_dialog(scene, title, text, buttons, choice, segments)
      end

      # A popup the block draws (bitmap, colours, the chosen button), its
      # count buttons drawn with button_row: the chosen one's index
      def drawn(scene, count, choice = 0, &painter)
        return buttons_dialog(scene, nil, nil, Array.new(count), choice, nil, painter)
      end

      # The chosen button's index; Back picks the last one.
      def buttons_dialog(scene, title, text, buttons, choice = 0, segments = nil, painter = nil)
        redraw = true
        loop do
          if redraw
            if painter
              painter.call(scene.overlay, scene.palette, choice)
            else
              draw_buttons(scene.overlay, scene.palette, title, text, buttons, choice, segments)
            end
            redraw = false
          end
          Graphics.update
          Input.update
          pt = Reloaded::Pointer
          if pt.moved? && (i = pt.hit(@hits)) && i != choice    # the mouse over a button picks it
            choice = i
            pbPlayCursorSE
            redraw = true
          end
          if pt.left? && (i = pt.hit(@hits))       # a click does it
            pbPlayDecisionSE
            return i
          elsif pt.right?
            pbPlayCancelSE
            return buttons.length - 1
          elsif buttons.length > 1 && (Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT))
            choice = (choice + (Input.trigger?(Input::LEFT) ? -1 : 1)) % buttons.length
            pbPlayCursorSE
            redraw = true
          elsif Input.trigger?(Input::USE)
            pbPlayDecisionSE
            return choice
          elsif Input.trigger?(Input::BACK)
            pbPlayCancelSE
            return buttons.length - 1
          end
        end
      ensure
        clear(scene)
      end

      #------------------------------------------------------------------------
      # A number: Left/Right one step, Up/Down ten steps
      #------------------------------------------------------------------------
      def number(scene, title, value, min, max, step = 1, unit = "", icon: nil, note: nil, format: nil)
        min ||= 0
        max ||= 999_999
        step = [step.to_i, 1].max
        value = [[value.to_i, min].max, max].min
        redraw = true
        loop do
          if redraw
            draw_number(scene.overlay, scene.palette, title, value, min, max, unit, icon, note, format)
            redraw = false
          end
          Graphics.update
          Input.update
          delta = 0
          delta = -step if Input.repeat?(Input::LEFT)
          delta = step if Input.repeat?(Input::RIGHT)
          delta = -step * 10 if Input.repeat?(Input::DOWN)
          delta = step * 10 if Input.repeat?(Input::UP)
          delta = -step * Reloaded::Pointer.wheel if delta == 0      # the wheel: up adds
          if Reloaded::Pointer.right?
            pbPlayCancelSE
            return nil
          elsif Reloaded::Pointer.left?
            pbPlayDecisionSE
            return value
          elsif delta != 0
            target = [[value + delta, min].max, max].min
            if target != value
              value = target
              pbPlayCursorSE
              redraw = true
            end
          elsif Input.trigger?(Input::USE)
            pbPlayDecisionSE
            return value
          elsif Input.trigger?(Input::BACK)
            pbPlayCancelSE
            return nil
          end
        end
      ensure
        clear(scene)
      end

      # A popup a screen draws itself (the Bag's Quick Items slots): the
      # screen dimmed, the plate and its title; content starts at y + 40
      def frame(b, c, x, y, w, h, title)
        dim(b)
        panel(b, c, x, y, w, h)
        title_bar(b, c, x, y, w, title)
      end

      # A popup's buttons, centred across x..x + w at by; the chosen one lit
      def button_row(b, c, x, w, by, buttons, choice)
        widths = buttons.map { |label| [P.width(P.pf::TEXT, label) + 28, 72].max }
        total = widths.inject(0) { |sum, bw| sum + bw } + 10 * (buttons.length - 1)
        bx = x + (w - total) / 2
        @hits = []
        buttons.each_with_index do |label, i|
          @hits << [i, bx, by, bx + widths[i], by + 24]
          button(b, c, bx, by, bx + widths[i], by + 24, i == choice)
          P.text(b, bx, by, widths[i], 24, label, i == choice ? c[:strong] : c[:txt], nil, 2)
          bx += widths[i] + 10
        end
      end

      # Where a popup's clicks land: [[index, x0, y0, x1, y1], ...]
      def hits=(list)
        @hits = list
      end

      def hit
        return Reloaded::Pointer.hit(@hits || [])
      end

      private

      P = Reloaded::Pixel

      # Up/Down through count rows (a held direction stops at the ends; a
      # fresh press wraps), A chooses, B returns nil. The block draws.
      def list_loop(scene, count, index, visible)
        top = [[index - visible / 2, count - visible].min, 0].max
        redraw = true
        loop do
          top = index if index < top
          top = index - visible + 1 if index >= top + visible
          if redraw
            yield index, top
            redraw = false
          end
          Graphics.update
          Input.update
          pt = Reloaded::Pointer
          wheel = pt.wheel
          if pt.moved? && (i = pt.hit(@hits)) && i != index     # the mouse over a row picks it
            index = i
            pbPlayCursorSE
            redraw = true
          end
          if pt.left? && (i = pt.hit(@hits))       # a click chooses it
            pbPlayDecisionSE
            return i
          elsif pt.right?
            pbPlayCancelSE
            return nil
          elsif wheel != 0                         # the wheel scrolls; the row under the mouse is picked
            to = [[top + wheel, 0].max, [count - visible, 0].max].min
            next if to == top
            under = pt.hit(@hits)
            top = to
            index = under ? [[under + wheel, top].max, top + visible - 1].min : [[index, top].max, top + visible - 1].min
            redraw = true
          elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
            target = index + (Input.repeat?(Input::UP) ? -1 : 1)
            if target < 0 || target >= count
              next unless Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN)
              target %= count
            end
            index = target
            pbPlayCursorSE
            redraw = true
          elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
            index = [[index + (Input.repeat?(Input::LEFT) ? -visible : visible), 0].max, count - 1].min
            pbPlayCursorSE
            redraw = true
          elsif Input.trigger?(Input::USE)
            pbPlayDecisionSE
            return index
          elsif Input.trigger?(Input::BACK)
            pbPlayCancelSE
            return nil
          end
        end
      ensure
        clear(scene)
      end

      def clear(scene)
        b = scene.overlay
        b.clear if b && !b.disposed?
      end

      def dim(b)
        b.clear
        b.fill_rect(0, 0, SCREEN_W, SCREEN_H, Color.new(0, 0, 0, 120))
      end

      #------------------------------------------------------------------------
      # The popup look: Header Plate (his pick, 2026-10-22, Tools/Designs/popups
      # design 2, title centred, no accent bar), after the Party Screen's
      # angled plates
      #------------------------------------------------------------------------
      def mix(a, b, t)
        return Reloaded::Palette.mix(a, b, t)
      end

      # A cut-corner plate (edge: a notice's own colour instead)
      def panel(b, c, x, y, w, h, edge = nil)
        Reloaded::PartyPaint.chamfer(b, x, y, x + w, y + h, CUT, c[:panel2], edge || mix(c[:line], c[:acc], 0.35))
      end

      # The title, centred on a plate of its own across the frame's top, lit
      # from the top, the Poke red line under it (tint, ink and line: a
      # notice's own colour). Content starts at y + 40.
      def title_bar(b, c, x, y, w, title, tint = nil, ink = nil, line = nil)
        tint ||= c[:acc]
        Reloaded::PartyPaint.chamfer_grad(b, x + 4, y + 3, x + w - 4, y + 32, 9, mix(c[:panel2], tint, 0.30),
                                          mix(c[:panel2], tint, 0.12), mix(c[:line], tint, 0.45))
        P.text(b, x + 8, y + 4, w - 16, 26, P.pf.fit(P.pf::ROW, title.to_s, w - 28), ink || c[:title], P.pf::ROW, 2)
        b.fill_rect(x + 4, y + 34, w - 8, 2, line || Reloaded::PartyPaint::POKE_RED)
      end

      # The selected row of a popup list wears the regular cursor (only what
      # is a plate itself, a button, has cut corners; his call, 2026-10-22).
      def cursor_row(b, c, x0, y0, x1, y1, cursor = nil)
        fill, border = Reloaded::Palette.cursor(cursor, c)
        P.ui.rbox(b, x0, y0, x1, y1, 4, Reloaded::Palette.over(c[:panel2], fill), Reloaded::Palette.over(c[:panel2], border))
      end

      # A popup's button: the chosen one in the cursor's colours
      def button(b, c, x0, y0, x1, y1, on)
        if on
          Reloaded::PartyPaint.chamfer(b, x0, y0, x1, y1, 7, c[:sel], c[:selb])
        else
          Reloaded::PartyPaint.chamfer(b, x0, y0, x1, y1, 7, mix(c[:panel2], c[:bg], 0.45), c[:line])
        end
      end

      def draw_menu(b, c, title, labels, descriptions, index, top)
        dim(b)
        rows = [labels.length, MENU_MAX].min
        w = MENU_W
        # room for the longest description (up to 3 lines)
        lines = descriptions.map { |d| P.wrap(d.to_s, w - 28).length }.max.to_i.clamp(0, 3)
        desc_h = lines > 0 ? lines * 18 + 8 : 0
        h = 40 + rows * MENU_ROW + 8 + desc_h
        x = (SCREEN_W - w) / 2
        y = (SCREEN_H - h) / 2
        panel(b, c, x, y, w, h)
        title_bar(b, c, x, y, w, title)
        # [input, text] rows: the inputs' icons in a column, their text lined up after it
        style = Reloaded::Prompts.style
        icons = labels.map { |l| l.is_a?(Array) && l[0] ? Reloaded::ButtonIcons.width(l[0], style, 18) : 0 }.max
        @hits = []
        rows.times do |r|
          i = top + r
          ry = y + 40 + r * MENU_ROW
          @hits << [i, x + 6, ry, x + w - 6, ry + MENU_ROW - 2]
          cursor_row(b, c, x + 6, ry, x + w - 6, ry + MENU_ROW - 2) if i == index
          label = labels[i]
          lx = x + 18
          if label.is_a?(Array)
            token, label = label
            if token
              iw = Reloaded::ButtonIcons.width(token, style, 18)
              Reloaded::ButtonIcons.draw(b, lx + (icons - iw) / 2, ry + 2, token, c, style, 18)
              lx += icons + 8
            end
          end
          P.text(b, lx, ry, w - (lx - x) - 18, MENU_ROW - 2, label.to_s, c[:opt])
        end
        P.ui.tri(b, x + w / 2 - 4, y + 37, :u, c[:dim], 3) if top > 0
        P.ui.tri(b, x + w / 2 - 4, y + 40 + rows * MENU_ROW, :d, c[:dim], 3) if top + rows < labels.length
        return if lines == 0
        b.fill_rect(x + 10, y + h - desc_h - 4, w - 20, 1, c[:line])
        P.wrap(descriptions[index].to_s, w - 28).first(lines).each_with_index do |line, i|
          P.text(b, x + 14, y + h - desc_h + i * 18, w - 28, 18, line, c[:dim])
        end
      end

      def draw_picker(b, c, title, values, index, top, swatch)
        dim(b)
        rows = [values.length, PICK_MAX].min
        w = PICK_W
        h = 40 + rows * PICK_ROW + 10
        x = (SCREEN_W - w) / 2
        y = (SCREEN_H - h) / 2
        panel(b, c, x, y, w, h)
        title_bar(b, c, x, y, w, title)
        @hits = []
        rows.times do |r|
          i = top + r
          ry = y + 40 + r * PICK_ROW
          @hits << [i, x + 6, ry, x + w - 6, ry + PICK_ROW - 2]
          if i == index
            swatch == :cursor ? cursor_row(b, c, x + 6, ry, x + w - 6, ry + PICK_ROW - 2, i) :
                                cursor_row(b, c, x + 6, ry, x + w - 6, ry + PICK_ROW - 2)
          end
          lx = x + 16
          case swatch
          when :text
            color = Reloaded::Palette.text_color(i)
            P.ui.rbox(b, lx, ry + 5, lx + 10, ry + 15, 2, color)
            lx += 18
            P.text(b, lx, ry, w - (lx - x) - 10, PICK_ROW - 2, values[i].to_s, color)
          when :cursor
            fill, border = Reloaded::Palette.cursor(i)
            P.ui.rbox(b, lx, ry + 4, lx + 30, ry + PICK_ROW - 6, 4, Reloaded::Palette.over(c[:panel2], fill),
                      Reloaded::Palette.over(c[:panel2], border))
            lx += 40
            P.text(b, lx, ry, w - (lx - x) - 10, PICK_ROW - 2, values[i].to_s, c[:txt])
          else
            drawer = swatch ? swatches[swatch] : nil
            if drawer
              lx += swatch_width(drawer, b, c, lx, ry, i) + 8
              P.text(b, lx, ry, w - (lx - x) - 10, PICK_ROW - 2, values[i].to_s, c[:opt])
            else
              P.text(b, lx, ry, w - 32, PICK_ROW - 2, values[i].to_s, c[:opt])
            end
          end
        end
        P.ui.tri(b, x + w / 2 - 4, y + 37, :u, c[:dim], 3) if top > 0
        P.ui.tri(b, x + w / 2 - 4, y + h - 8, :d, c[:dim], 3) if top + rows < values.length
      end

      def swatch_width(drawer, b, c, x, y, i)
        return drawer.call(b, c, x, y, PICK_ROW, i).to_i
      rescue StandardError => e
        Reloaded::Log.exception("A picker swatch failed", e, :ui)
        return 0
      end

      def draw_buttons(b, c, title, text, buttons, choice, segments = nil)
        dim(b)
        w = TEXT_W
        lines = P.wrap(text.to_s, w - 32).first(6)
        rich = segments ? rich_lines(b, segments, w - 32) : 0
        h = 40 + lines.length * 18 + (rich > 0 ? rich * 18 + 6 : 0) + 48
        x = (SCREEN_W - w) / 2
        y = (SCREEN_H - h) / 2
        panel(b, c, x, y, w, h)
        title_bar(b, c, x, y, w, title)
        lines.each_with_index { |line, i| P.text(b, x + 16, y + 40 + i * 18, w - 32, 18, line, c[:txt], nil, 2) }
        P.small_rich(b, x + 16, y + 46 + lines.length * 18, w - 32, 18, segments) if rich > 0
        button_row(b, c, x, w, y + h - 36, buttons, choice)
      end

      # How many lines coloured segments take (measured on a scratch draw).
      def rich_lines(b, segments, w)
        probe = Bitmap.new(w, 200)
        n = P.small_rich(probe, 0, 0, w, 18, segments)
        probe.dispose
        return n
      end

      # With an icon (an item, the Bag's Toss): its picture in a box on the
      # left, the number centred on the rest, the note under it
      def draw_number(b, c, title, value, min, max, unit, icon = nil, note = nil, format = nil)
        dim(b)
        w = icon || note ? 300 : 280
        h = icon || note ? 150 : 130
        x = (SCREEN_W - w) / 2
        y = (SCREEN_H - h) / 2
        panel(b, c, x, y, w, h)
        title_bar(b, c, x, y, w, title)
        nx = x
        nw = w
        if icon
          P.ui.rbox(b, x + 16, y + 46, x + 72, y + 102, 6, c[:light] ? mix(c[:panel2], Reloaded::PartyPaint::WHITE, 0.5) : mix(c[:dark], c[:panel], 0.3), c[:line])
          item_picture(b, icon, x + 20, y + 50, 48)
          nx = x + 72
          nw = w - 72
        end
        words = format || proc { |v| v.to_s + unit.to_s }
        label = words.call(value).to_s
        tw = P.width(P.pf::ROW, label)
        cx = nx + nw / 2
        P.text(b, nx, y + 46, nw, 30, label, c[:txt], P.pf::ROW, 2)
        P.ui.tri(b, cx - tw / 2 - 16, y + 56, :l, value > min ? c[:selb] : c[:line], 5)
        P.ui.tri(b, cx + tw / 2 + 6, y + 56, :r, value < max ? c[:selb] : c[:line], 5)
        P.small(b, nx, y + 82, nw, 16, note.call(value).to_s, c[:dim], 2) if note
        P.text(b, x, y + h - 30, w, 20, _INTL("{1} to {2}", words.call(min), words.call(max)), c[:dim], nil, 2)
      end

      def item_picture(b, id, x, y, size)
        file = (::GameData::Item.icon_filename(id) rescue "Graphics/Items/#{id}")
        path = defined?(pbResolveBitmap) ? (pbResolveBitmap(file) || file) : file
        bm = Bitmap.new(path)
        b.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, bm.width, bm.height))
        bm.dispose
      rescue StandardError
        nil
      end
    end
  end
end
