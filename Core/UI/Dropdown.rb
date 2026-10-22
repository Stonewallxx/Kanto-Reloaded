#==============================================================================
# Kanto Reloaded: Option Dropdowns
#==============================================================================
# A choice's list, dropped down from its value (Roadmap: Option Dropdowns,
# design 1, the Anchored Dropdown):
#
#   - under the value; above it when there's no room below; when neither
#     side has room, under it moved up just enough (over the value)
#   - the current choice marked NOW; locked choices dimmed, with a padlock
#   - up to 5 rows; longer lists scroll, with arrows and a scrollbar
#   - Up/Down move (a held direction stops at the ends, a fresh press goes
#     round), Left/Right a page, A picks, B closes
#   - the mouse: the row under it is highlighted, a click picks it, a click
#     on an arrow scrolls, a click outside or a right click closes, the
#     wheel scrolls
#
# A screen with its own loop (the improved KIF Settings) makes one, calls
# update every frame and draws it on its popups' layer:
#
#   dd = Reloaded::Dropdown.new(values, current, anchor, bounds, :locked => [2])
#   anchor  [x0, y0, x1, y1]: the value it drops from
#   bounds  [x0, y0, x1, y1]: where the list stays
#   dd.update  :pick (dd.index is the choice), :close, :move, :scroll,
#              :locked (a locked choice was picked) or nil
#   dd.draw(bitmap, colours)
#   dd.choose / dd.close   what A and B do (the hint line's Pick and Close)
#
# Dropdown.run(dd, bitmap, colours) does the loop for a screen that has none
# to share (KIF Settings as it ships). While one is open, a screen leaves
# out the values it would cut through (dd.covers?), so no half-covered text
# shows at its edges.
#==============================================================================

module Reloaded
  class Dropdown
    ROW     = 24      # a choice's row
    PAD     = 4       # above the first row and below the last
    ARROWS  = 8       # the scroll arrows' strips, top and bottom, when it scrolls
    VISIBLE = 5       # rows shown before it scrolls
    TEXT_X  = 12      # a choice's text, from the list's left edge
    BAR_W   = 3       # the scrollbar
    MIN_W   = 96
    P = Reloaded::Pixel

    attr_reader :index, :top, :current, :values, :rect, :visible

    # values: the choices' labels; current: the value now (marked NOW, the
    # highlight starts on it); locked: choices that can't be picked; cursor:
    # the highlight in Kanto Reloaded's Cursor Color (false: the screen's
    # selection colours, as KIF Settings draws its own).
    def initialize(values, current, anchor, bounds, locked: [], cursor: true)
      @values = values.map { |v| P.pf.utf8(v.to_s) }
      @current = current.to_i
      @index = [[@current, 0].max, @values.length - 1].min
      @locked = Array(locked)
      @cursor = cursor
      @hits = []
      @arrow_hits = []
      layout(anchor, bounds)
      @top = [[@index - @visible / 2, @values.length - @visible].min, 0].max
    end

    def locked?(i)
      return @locked.include?(i)
    end

    def scrolls?
      return @visible < @values.length
    end

    # True when the list opened under its value (or moved up over it).
    def below?
      return @below
    end

    # True when there was room on neither side: it covers its value.
    def over?
      return @over
    end

    # One frame's input. moved: whether the mouse moved this frame (pass it
    # when the screen already asked Pointer.moved?, which only answers once).
    def update(moved = nil)
      pt = Reloaded::Pointer
      moved = pt.moved? if moved.nil?
      if moved && (i = pt.hit(@hits)) && i != @index      # the mouse over a row highlights it
        @index = i
        pbPlayCursorSE
        return :move
      end
      if pt.left?
        if (i = pt.hit(@hits))
          return choose(i)
        elsif (dir = pt.hit(@arrow_hits))
          return scroll(dir)
        end
        return nil if pt.inside?(*@rect)
        return close
      elsif pt.right?
        return close
      elsif (wheel = pt.wheel) != 0
        return scroll(wheel)
      elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
        up = Input.repeat?(Input::UP)
        target = @index + (up ? -1 : 1)
        if target < 0 || target >= @values.length
          return nil unless Input.trigger?(up ? Input::UP : Input::DOWN)
          target %= @values.length
        end
        return move_to(target)
      elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
        step = Input.repeat?(Input::LEFT) ? -@visible : @visible
        return move_to([[@index + step, 0].max, @values.length - 1].min)
      elsif Input.trigger?(Input::USE)
        return choose(@index)
      elsif Input.trigger?(Input::BACK)
        return close
      end
      return nil
    end

    def draw(b, c)
      x0, y0, x1, y1 = @rect
      P.ui.rbox(b, x0, y0, x1, y1, 6, c[:panel2], c[:selb])
      ry0 = rows_y
      right = x1 - 8 - (scrolls? ? BAR_W + 5 : 0)      # where the text and badges end
      @hits = []
      @visible.times do |k|
        i = @top + k
        ry = ry0 + k * ROW
        @hits << [i, x0 + 4, ry, x1 - 4, ry + ROW - 2]
        highlight(b, c, x0 + 4, ry, right + 4, ry + ROW - 2) if i == @index
        locked = locked?(i)
        color = locked ? Reloaded::Palette.mix(c[:dim], c[:panel2], 0.3) : c[:opt]
        px = right
        px -= P.pill(b, px, ry + 4, now_label, now_fill(c), c[:selb], true) + 5 if i == @current
        if locked
          padlock(b, px - 7, ry + 5, c[:dim], i == @index ? highlight_fill(c) : c[:panel2])
          px -= 12
        end
        label = P.pf.fit(P.pf::TEXT, @values[i], px - (x0 + TEXT_X) - 4)
        P.text(b, x0 + TEXT_X, ry, px - (x0 + TEXT_X), ROW - 2, label, color)
      end
      @arrow_hits = []
      return unless scrolls?
      ax = (x0 + x1) / 2 - 3
      up = @top > 0
      down = @top + @visible < @values.length
      P.ui.tri(b, ax, y0 + 3, :u, up ? c[:selb] : c[:line], 3)
      P.ui.tri(b, ax, y1 - 7, :d, down ? c[:selb] : c[:line], 3)
      @arrow_hits << [-1, x0 + 4, y0, x1 - 4, ry0 - 1] if up
      @arrow_hits << [1, x0 + 4, ry0 + @visible * ROW - 1, x1 - 4, y1] if down
      track = @visible * ROW - 2
      bar = [track * @visible / @values.length, 8].max
      pos = (track - bar) * @top / [@values.length - @visible, 1].max
      tx = x1 - 6 - BAR_W
      b.fill_rect(tx, ry0, BAR_W, track, c[:line])
      b.fill_rect(tx, ry0 + pos, BAR_W, bar, c[:selb])
    end

    # True when the list covers any of this box: the screen leaves out what
    # it would only half cover (a row's value).
    def covers?(x0, y0, x1, y1)
      return x0 <= @rect[2] && x1 >= @rect[0] && y0 <= @rect[3] && y1 >= @rect[1]
    end

    # Runs dd until a choice is picked (its index) or it closes (nil).
    # bitmap: the layer it draws on; colours: the palette. The block, if
    # given, draws what goes with it (the highlighted choice explained)
    # each time it is drawn: |bitmap, dd|.
    def self.run(dd, bitmap, colours)
      redraw = true
      loop do
        if redraw
          bitmap.clear
          dd.draw(bitmap, colours)
          yield bitmap, dd if block_given?
          redraw = false
        end
        Graphics.update
        Input.update
        event = dd.update
        return dd.index if event == :pick
        return nil if event == :close
        redraw = true if event
      end
    ensure
      bitmap.clear if bitmap && !bitmap.disposed?
    end

    # Picks choice i (the highlighted one): :pick, or :locked (a buzz) when
    # it can't be picked.
    def choose(i = @index)
      @index = i
      follow
      if locked?(i)
        pbPlayBuzzerSE
        return :locked
      end
      pbPlayDecisionSE
      return :pick
    end

    def close
      pbPlayCancelSE
      return :close
    end

    private

    def now_label
      return _INTL("NOW")
    end

    def now_fill(c)
      return Reloaded::Palette.mix(c[:panel2], c[:selb], 0.27)
    end

    # The top of the first row.
    def rows_y
      return @rect[1] + PAD + (scrolls? ? ARROWS : 0)
    end

    def height_for(rows)
      return PAD * 2 + rows * ROW + (rows < @values.length ? ARROWS * 2 : 0)
    end

    # Under the anchor when it fits, else above it when that fits, else
    # under it moved up just enough to fit (over the value: NOW still marks
    # it); fewer rows only when the bounds are too short for them. As wide
    # as its longest choice and its badges (at least the anchor), centred
    # on the anchor.
    def layout(anchor, bounds)
      ax0, ay0, ax1, ay1 = anchor
      bx0, by0, bx1, by1 = bounds
      n = @values.length
      below_room = by1 - (ay1 + 1)
      above_room = (ay0 - 1) - by0
      @visible = [n, VISIBLE].min
      @visible -= 1 while @visible > 1 && height_for(@visible) > by1 - by0
      h = height_for(@visible)
      @below = h <= below_room || h > above_room
      y0 = @below ? [[ay1 + 1, by1 - h].min, by0].max : ay0 - 1 - h
      @over = @below && y0 <= ay1
      text_w = @values.map { |v| P.width(P.pf::TEXT, v) }.max.to_i
      w = TEXT_X + text_w + 10 + P.width(P.pf::TINY, now_label) + 12 + 8
      w += 12 if locked?(@current)
      w += BAR_W + 5 if scrolls?
      w = [[w, ax1 - ax0 + 1, MIN_W].max, bx1 - bx0].min
      x0 = [[(ax0 + ax1) / 2 - w / 2, bx0].max, bx1 - w].min
      @rect = [x0, y0, x0 + w, y0 + h]
    end

    def move_to(i)
      return nil if i == @index
      @index = i
      follow
      pbPlayCursorSE
      return :move
    end

    # The view follows the highlight.
    def follow
      @top = @index if @index < @top
      @top = @index - @visible + 1 if @index >= @top + @visible
    end

    # The wheel or an arrow: the view moves a row; the highlight stays in it
    # (on the row under the mouse when there is one).
    def scroll(dir)
      to = [[@top + dir, 0].max, [@values.length - @visible, 0].max].min
      return nil if to == @top
      under = Reloaded::Pointer.hit(@hits)
      @top = to
      @index = under ? [[under + dir, @top].max, @top + @visible - 1].min : [[@index, @top].max, @top + @visible - 1].min
      return :scroll
    end

    def highlight(b, c, x0, y0, x1, y1)
      P.ui.rbox(b, x0, y0, x1, y1, 4, highlight_fill(c), highlight_border(c))
    end

    def highlight_fill(c)
      return c[:sel] unless @cursor
      return Reloaded::Palette.over(c[:panel2], Reloaded::Palette.cursor[0])
    end

    def highlight_border(c)
      return c[:selb] unless @cursor
      return Reloaded::Palette.over(c[:panel2], Reloaded::Palette.cursor[1])
    end

    # A small padlock, 7 by 10, its top left at x, y; hole: the colour
    # behind it (its keyhole).
    def padlock(b, x, y, color, hole)
      b.fill_rect(x + 1, y, 5, 1, color)
      b.fill_rect(x + 1, y, 1, 4, color)
      b.fill_rect(x + 5, y, 1, 4, color)
      b.fill_rect(x, y + 4, 7, 6, color)
      b.fill_rect(x + 3, y + 6, 1, 2, hole)
    end
  end
end
