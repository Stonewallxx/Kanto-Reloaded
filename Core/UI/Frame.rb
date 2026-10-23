#==============================================================================
# Kanto Reloaded: the frame of our settings-like screens
#==============================================================================
# What the improved KIF Settings and the Controls screen share (the Options
# layout is the template for every settings-like screen):
#
#   - layers: panels, the cursor, text, the hint strip, popups
#   - the Kanto Reloaded mod's pulsing cursor (place it with @cursor_rect)
#   - the hint line: centred, icons for buttons, scrolling when too long
#     (the screen answers hint_pairs)
#   - title-bar boxes, opened only by their buttons, shown beside them
#   - the description box's lines
#   - Option Dropdowns: running one, its hints, drawing it
#   - stepping aside for another screen (hidden)
#
# A screen includes Frame, calls frame_init in initialize, open_sprites /
# dispose_sprites around its loop, update_frame every frame, and paints on
# @sprite (panels) and @top_sprite (text).
#==============================================================================

module Reloaded
  module Frame
    W = 512
    H = 384
    BUTTON_W  = 112       # the title-bar boxes
    HINT_WAIT = 80        # frames the hint line waits at each end
    HINT_STEP = 2         # frames per pixel it scrolls
    DESC_LINES = 3        # description lines shown at once
    DESC_DY    = 17
    VALUE_X1   = W - 18             # a value's right edge (its right arrow's tip)
    VALUE_CX   = VALUE_X1 - 41      # the centre of the value column
    P = Reloaded::Pixel

    def frame_init
      @frame = 0
      @hint_tick = 0
      @hint_room = 0
    end

    # The colours this screen and its popups draw in: Dark, or Light for
    # Theme Mode Light and Frost (his rule, 2026-10-21: a full screen is
    # only ever Dark or Light; Glass shows it Dark, Frost Light).
    def palette
      return Reloaded::Palette.map_menu
    end

    # The popups' layer (Reloaded::Dialogs draws on it).
    def overlay
      return @overlay_sprite.bitmap
    end

    # Every frame (TextEntry calls it too): the cursor's pulse, and the hint
    # line scrolling when it's too long.
    def update_frame
      @frame += 1
      @cursor_sprite.opacity = P.cursor_opacity(@frame) if @cursor_sprite && @cursor_sprite.visible
      return unless @hint_room > 0
      @hint_tick += 1
      place_hints
    end

    # A phone has no File Explorer or browser to open: the text (a path, a
    # link) goes on the clipboard instead (his pick, 2026-10-21: Copy
    # Instead), and a short notice says so. When the clipboard can't be
    # used, the notice shows the text itself.
    def copy_for_phone(text, words)
      if Reloaded::ShareCodes.copy(text.to_s)
        Reloaded::Dialogs.notice(self, _INTL("Copied"), words)
      else
        Reloaded::Dialogs.notice(self, _INTL("Couldn't Copy"), text.to_s)
      end
    end

    # Another screen or message box takes over: this one steps aside.
    def hidden
      shown = sprites.select { |s| s.visible }
      shown.each { |s| s.visible = false }
      yield
    ensure
      (shown || []).each { |s| s.visible = true unless s.disposed? }
    end

    private

    # A badge's, pill's or banner's fill from its colour: the colour darkened
    # on Dark (div 4, or 6 for a banner), a pale tint of it on Light
    def dark_fill(colour, div = 4)
      c = palette
      return Reloaded::Palette.mix(c[:panel2], colour, div > 4 ? 0.14 : 0.22) if c[:light]
      return Color.new(colour.red / div, colour.green / div, colour.blue / div)
    end

    #--------------------------------------------------------------------------
    # Layers
    #--------------------------------------------------------------------------
    def open_sprites
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99_999
      @sprite = layer(0)                 # panels and boxes
      @cursor_sprite = Sprite.new(@viewport)
      @cursor_sprite.z = 1
      @cursor_sprite.visible = false
      @top_sprite = layer(2)             # text, values, badges
      @hint_sprite = Sprite.new(@viewport)   # the hint line (a strip that scrolls)
      @hint_sprite.bitmap = Bitmap.new(W, P::HINT_H)
      @hint_sprite.y = H - P::HINT_H
      @hint_sprite.z = 2
      @overlay_sprite = layer(3)         # popups
      @cursor_cache = {}
    end

    def layer(z)
      s = Sprite.new(@viewport)
      s.bitmap = Bitmap.new(W, H)
      s.z = z
      return s
    end

    def sprites
      return [@sprite, @cursor_sprite, @top_sprite, @hint_sprite, @overlay_sprite].compact.reject { |s| s.disposed? }
    end

    def dispose_sprites
      [@sprite, @top_sprite, @hint_sprite, @overlay_sprite].each do |s|
        next if s.nil? || s.disposed?
        s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
        s.dispose
      end
      @cursor_sprite.dispose if @cursor_sprite && !@cursor_sprite.disposed?
      (@cursor_cache || {}).each_value { |b| b.dispose unless b.disposed? }
      @cursor_cache = {}
      @viewport.dispose if @viewport && !@viewport.disposed?
      @sprite = @cursor_sprite = @top_sprite = @hint_sprite = @overlay_sprite = @viewport = nil
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def fresh?(dir)
      return Input.trigger?(dir > 0 ? Input::DOWN : Input::UP)
    end

    # A left click inside the box (game pixels).
    def clicked?(x0, y0, x1, y1)
      return Reloaded::Pointer.left? && Reloaded::Pointer.inside?(x0, y0, x1, y1)
    end

    # The title-bar boxes, for the mouse: left (Search), right (Presets,
    # Layouts).
    def left_box
      return [8, 4, 8 + BUTTON_W, 27]
    end

    def right_box
      return [W - 8 - right_w, 4, W - 8, 27]
    end

    # The right box's width (a screen whose label needs more room widens it).
    def right_w
      return BUTTON_W
    end

    # Every frame: when the mouse moved, what it's over in the title bar and
    # the hint line lights up. Returns true when it moved (the screen then
    # moves its cursor to the row under it).
    def pointer_hover
      pt = Reloaded::Pointer
      return false unless pt.moved?
      box = if pt.inside?(*left_box) then :left
            elsif pt.inside?(*right_box) then :right
            end
      hint = hint_at(pt.pos)
      hint = nil unless hint && hint_action(hint)
      if box != @hover_box || hint != @hover_hint
        @hover_box = box
        @hover_hint = hint
        refresh
      end
      return true
    end

    # The hint under the mouse (its place in the hint line), or nil.
    def hint_at(pos)
      return nil unless pos && @hint_sprite && !@hint_sprite.disposed? && pos[1] >= H - P::HINT_H
      x = pos[0] + @hint_sprite.src_rect.x
      span = (@hint_spans || []).find { |_i, x0, x1| x >= x0 - 3 && x <= x1 + 3 }
      return span ? span[0] : nil
    end

    # What clicking a hint does: its pair's third part (a method name or a
    # proc), or nil.
    def hint_action(i)
      pair = (@hint_pairs || [])[i]
      return pair ? pair[2] : nil
    end

    # A click on a hint: does it (returns what the action returns).
    def hint_click
      i = hint_at(Reloaded::Pointer.pos)
      act = i && hint_action(i)
      return [false, nil] unless act
      return [true, act.is_a?(Proc) ? act.call : send(act)]
    end

    #--------------------------------------------------------------------------
    # Option Dropdowns
    #--------------------------------------------------------------------------
    # Runs dd (a Reloaded::Dropdown) until a choice is picked (its index) or
    # it closes (nil). While it's open, @dropdown is set: the screen draws it
    # with paint_dropdown, explains the highlighted choice and shows
    # dropdown_hints. The block runs every frame (a description scrolling).
    def run_dropdown(dd)
      @dropdown = dd
      pbPlayDecisionSE
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        event = dropdown_hint || dd.update(pointer_hover)
        return dd.index if event == :pick
        return nil if event == :close
        refresh if event
        yield if block_given?
      end
    ensure
      @dropdown = nil
      refresh
    end

    # A click on the hint line's Pick or Close while a dropdown is open.
    def dropdown_hint
      return nil unless Reloaded::Pointer.left?
      i = hint_at(Reloaded::Pointer.pos)
      case i && hint_action(i)
      when :dropdown_pick  then return @dropdown.choose
      when :dropdown_close then return @dropdown.close
      end
      return nil
    end

    def dropdown_hints
      return [[:ud, _INTL("Choose")], [button(:C), _INTL("Pick"), :dropdown_pick],
              [button(:B), _INTL("Close"), :dropdown_close]]
    end

    # An open dropdown, on the popups' layer (cleared once it closes).
    def paint_dropdown(c)
      if @dropdown
        overlay.clear
        @dropdown.draw(overlay, c)
        @dropdown_shown = true
      elsif @dropdown_shown
        overlay.clear
        @dropdown_shown = false
      end
    end

    # Where a dropdown stays: inside the list panel.
    def dropdown_bounds(x0, y0, x1, y1)
      return [x0 + 4, y0 + 2, x1 - 4, y1 - 2]
    end

    #--------------------------------------------------------------------------
    # The title bar
    #--------------------------------------------------------------------------
    def paint_title_bar(base, c)
      base.fill_rect(0, 0, W, 32, c[:panel2])
      base.fill_rect(0, 31, W, 1, c[:line])
    end

    # A title-bar box at bx, w wide: its label (a magnifier first when
    # search is true), lit when active or under the mouse, faded when off.
    def title_box(base, top, c, bx, label, search: false, active: false, off: false, w: BUTTON_W)
      hover = !off && @hover_box == (bx < W / 2 ? :left : :right)
      P.ui.rbox(base, bx, 4, bx + w, 27, 5, c[:dark], active || hover ? c[:selb] : c[:line])
      fg = if active || hover then c[:txt]
           elsif off then Reloaded::Palette.mix(c[:dim], c[:dark], 0.45)
           else c[:dim]
           end
      icon = search ? 16 : 0
      label = P.pf.fit(P.pf::TEXT, label, w - 20 - icon)
      lw = P.width(P.pf::TEXT, label)
      lx = bx + (w - lw - icon) / 2 + icon
      magnifier(base, lx - 17, fg, c[:dark]) if search
      P.text(top, lx, 4, lw + 2, 24, label, fg)
    end

    # The buttons that open the two boxes: the left one's on its right, the
    # right one's on its left.
    def title_keys(top, c, left, right)
      style = Reloaded::Prompts.style
      Reloaded::ButtonIcons.draw(top, 8 + BUTTON_W + 6, 8, left, c, style) if left
      if right
        Reloaded::ButtonIcons.draw(top, W - 8 - right_w - 6 - Reloaded::ButtonIcons.width(right, style), 8, right, c, style)
      end
    end

    # The left box's button: Search's (Q/LB-style on a controller, D-style
    # on a keyboard), and the right box's: R.
    def left_key
      pr = Reloaded::Prompts
      return pr.input(pr.controller? ? :L : :Z)
    end

    def right_key
      return Reloaded::Prompts.input(:R)
    end

    def magnifier(base, ix, fg, hole)
      P.ui.rbox(base, ix, 9, ix + 9, 18, 4, fg)
      P.ui.rbox(base, ix + 2, 11, ix + 7, 16, 2, hole)
      3.times { |i| base.fill_rect(ix + 8 + i, 17 + i, 2, 2, fg) }
    end

    #--------------------------------------------------------------------------
    # The value column
    #--------------------------------------------------------------------------
    # Where values between arrows centre: the column, or left of it just far
    # enough for a value w wide (with its arrows) to fit.
    def value_centre(w)
      return [VALUE_CX, VALUE_X1 - 11 - w / 2].min
    end

    # Something else in the value column (OPEN, a badge), centred on it.
    def column_pill(top, cx, y, label, fill, color)
      w = P.width(P.pf::TINY, label) + 12
      P.pill(top, [cx - w / 2, VALUE_X1 - w].min, y, label, fill, color, false)
    end

    #--------------------------------------------------------------------------
    # The description box
    #--------------------------------------------------------------------------
    def description_box(base, c, y0)
      P.ui.rbox(base, 6, y0, W - 6, H - 30, 6, c[:panel2], c[:line])
    end

    def paint_lines(top, c, y0, lines, color = nil)
      lines.each_with_index do |ln, k|
        P.small(top, 14, y0 + 28 + k * DESC_DY, W - 34, DESC_DY, ln, color || c[:txt])
      end
    end

    #--------------------------------------------------------------------------
    # The hint line
    #--------------------------------------------------------------------------
    # A game button for a hint: its input (drawn as an icon), else its name.
    def button(sym)
      return Reloaded::Prompts.input(sym) || Reloaded::Prompts.name(sym)
    end

    # On its own strip, centred (it grows outward as hints are added). When
    # it's wider than the screen it waits, scrolls to its end, waits, and
    # scrolls back.
    def paint_hints(base, c)
      base.fill_rect(0, H - P::HINT_H, W, P::HINT_H, c[:panel2])
      base.fill_rect(0, H - P::HINT_H, W, 1, c[:line])
      pairs = hint_pairs
      style = Reloaded::Prompts.style
      used = P.hints_width(@hint_sprite.bitmap, pairs, style)
      w = [W, used + 20].max
      if @hint_sprite.bitmap.width != w
        @hint_sprite.bitmap.dispose
        @hint_sprite.bitmap = Bitmap.new(w, P::HINT_H)
      end
      b = @hint_sprite.bitmap
      b.clear
      @hint_pairs = pairs
      @hint_spans = []
      P.draw_hints(b, (w - used) / 2, 0, c, pairs, style, @hover_hint, @hint_spans)
      sig = [pairs.map { |p| p[0, 2] }, style]
      if sig != @hint_sig
        @hint_sig = sig
        @hint_tick = 0
      end
      @hint_room = w - W
      place_hints
    end

    def place_hints
      off = 0
      if @hint_room > 0
        run = @hint_room * HINT_STEP
        t = @hint_tick % (2 * (HINT_WAIT + run))
        off = if t < HINT_WAIT then 0
              elsif t < HINT_WAIT + run then (t - HINT_WAIT) / HINT_STEP
              elsif t < 2 * HINT_WAIT + run then @hint_room
              else @hint_room - (t - 2 * HINT_WAIT - run) / HINT_STEP
              end
      end
      @hint_sprite.src_rect.set(off, 0, W, P::HINT_H)
    end

    #--------------------------------------------------------------------------
    # The cursor
    #--------------------------------------------------------------------------
    # The Kanto Reloaded mod's cursor on @cursor_rect ([x, y, w, h]), pulsing.
    def place_cursor
      return unless @cursor_sprite
      if @cursor_rect.nil?
        @cursor_sprite.visible = false
        return
      end
      x, y, w, h = @cursor_rect
      @cursor_sprite.bitmap = cursor_bitmap(w, h)
      @cursor_sprite.x = x
      @cursor_sprite.y = y
      @cursor_sprite.opacity = P.cursor_opacity(@frame)
      @cursor_sprite.visible = true
    end

    def cursor_bitmap(w, h)
      s = Reloaded::Settings
      c = palette
      key = [w, h, s.get(:"interface.cursor_color"), s.get(:"interface.theme"), c[:light] ? 1 : 0]
      b = @cursor_cache[key]
      return b if b && !b.disposed?
      return @cursor_cache[key] = P.cursor_bitmap(w, h, nil, c)
    end
  end
end
