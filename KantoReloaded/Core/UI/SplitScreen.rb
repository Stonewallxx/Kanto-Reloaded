#==============================================================================
# Kanto Reloaded: the sidebar, list and description screens
#==============================================================================
# What the Patch Viewer and the Timing Profiler's screens share, in the KIF
# Settings layout (the template for settings-like screens): a sidebar of
# entries on the left, a list of headings and rows on the right, and the
# description box under them, its text scrolling when it's long.
#
#   include Reloaded::SplitScreen
#   paint_sidebar(base, top, c, entries, @section, @focus == :side)
#     entries: [{ :name, :tile => :ball, [letter, [r, g, b]] or [:dot, [r, g, b]], :dot => Color, :faded => true }]
#   out, total, avail = layout_items(items, selected index in items)   # items: [[:head or :row, x]]
#   paint_description_box(base, top, c, title, text, key, pills)       # pills: [[label, fill, colour]]
#
# The screen calls tick_description every frame (a long text scrolls by
# itself; the right stick, or the mouse wheel over the box, scrolls it by
# hand, and it stays there until another row's: his ask, 2026-10-25).
#==============================================================================

# Needs Kanto Reloaded's pixel UI (KIF's pixel fonts).
return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont)

module Reloaded
  module SplitScreen
    include Reloaded::Frame

    PF = ::KIF::PixelFont
    SIDE_X1 = 174
    SIDE_Y0 = 40
    SIDE_DY = 20
    LIST_X0 = 180
    LIST_X1 = W - 6
    LIST_Y0 = 36
    LIST_Y1 = H - 120
    ROW_H   = 26
    HEAD_H  = 22
    NAME_X  = LIST_X0 + 12
    VAL_X1  = LIST_X1 - 12           # the right column's right edge
    DESC_STEP = 100                  # frames per description line
    DESC_HOLD = 3                    # steps on its first and last lines
    DESC_REPEAT = 8                  # frames a line while the right stick is held (after a wait)
    DESC_WAIT = 16
    TILE_TEXT = Color.new(248, 248, 248)
    # an entry's tile, by its place in the list
    TILES = [[76, 160, 90], [200, 80, 80], [80, 130, 210], [210, 150, 50], [150, 100, 200],
             [60, 170, 170], [200, 100, 160], [120, 120, 130]].freeze
    P = Reloaded::Pixel

    private

    def tile_colour(i)
      return TILES[i % TILES.length]
    end

    #--------------------------------------------------------------------------
    # The sidebar
    #--------------------------------------------------------------------------
    # active: the selected entry's index; cursor: the cursor is on it.
    def paint_sidebar(base, top, c, entries, active, cursor)
      P.ui.rbox(base, 6, LIST_Y0, SIDE_X1, side_y1, 6, c[:panel])
      @side_hits = []
      @side_scroll ||= 0
      fit = (side_y1 - 4 - SIDE_Y0) / SIDE_DY
      @side_scroll = active - fit + 1 if active && active >= @side_scroll + fit
      @side_scroll = active if active && active < @side_scroll
      faded = Reloaded::Palette.mix(c[:dim], c[:panel], 0.45)
      y = SIDE_Y0
      (entries[@side_scroll, fit] || []).each_with_index do |e, k|
        i = k + @side_scroll
        @side_hits << [i, 9, y - 1, SIDE_X1 - 3, y + SIDE_DY - 2]
        on = i == active
        @cursor_rect = [9, y - 1, SIDE_X1 - 3 - 9 + 1, SIDE_DY] if on && cursor && !@entry
        name = PF.utf8(e[:name].to_s)
        icon = e[:tile] == :ball ? nil : (defined?(Reloaded::ModIcons) && Reloaded::ModIcons.for(e[:name]))
        if e[:tile] == :ball
          P.poke_ball(top, 14, y + 2, 15)
        elsif icon                                  # a mod's own ball (Ghostly Possession's possessed one)
          Reloaded::ModIcons.draw(top, 14, y + 2, icon)
        elsif e[:tile].is_a?(Array) && e[:tile][0] == :dot
          P.ui.rbox(top, 17, y + 5, 25, y + 13, 4, Color.new(*e[:tile][1]))
        else
          letter, rgb = e[:tile] || [name[0].to_s.upcase, tile_colour(i)]
          P.ui.rbox(top, 14, y + 2, 28, y + 16, 3, Color.new(*rgb))
          P.glyph(top, 14, y + 2, 15, 15, letter.to_s, TILE_TEXT)
        end
        room = SIDE_X1 - 37                 # a dot sits at the name's end, as in the designs
        color = if on then c[:strong]
                elsif e[:faded] then faded
                else c[:dim]
                end
        P.text(top, 33, y + 2, room, 15, PF.fit(PF::TEXT, name, room), color)
        P.ui.rbox(top, SIDE_X1 - 7, y + 6, SIDE_X1 - 2, y + 11, 3, e[:dot]) if e[:dot]
        y += SIDE_DY
      end
      paint_scrollbar(base, c, SIDE_X1 - 5, entries.length, fit, @side_scroll, side_y1) if entries.length > fit
    end

    # The sidebar panel's bottom (a screen with something under it, such as
    # What's New's Versions box, raises it).
    def side_y1
      return LIST_Y1
    end

    # A thin bar at x for a list of total entries showing shown from offset.
    def paint_scrollbar(base, c, x, total, shown, offset, y1 = LIST_Y1)
      track = y1 - LIST_Y0 - 12
      bar = [track * shown / [total, 1].max, 12].max
      pos = (track - bar) * offset / [total - shown, 1].max
      base.fill_rect(x, LIST_Y0 + 6, 2, track, c[:line])
      base.fill_rect(x, LIST_Y0 + 6 + pos, 2, bar, c[:dim])
    end

    #--------------------------------------------------------------------------
    # The list
    #--------------------------------------------------------------------------
    # [[item index, y]] for what fits, the list's height and the room; the
    # selected item stays in view (with its heading when that's just above).
    def layout_items(items, sel)
      @scroll ||= 0
      avail = (LIST_Y1 - 4) - (LIST_Y0 + 4)
      ys = []
      y = 0
      items.each do |kind, _|
        ys << y
        y += kind == :head ? HEAD_H : ROW_H
      end
      total = y
      if sel
        top = ys[sel]
        top = ys[sel - 1] if sel > 0 && items[sel - 1][0] == :head
        @scroll = top if top < @scroll
        @scroll = ys[sel] + ROW_H - avail if ys[sel] + ROW_H > @scroll + avail
      end
      @scroll = [[@scroll, total - avail].min, 0].max
      out = []
      items.each_index do |i|
        h = items[i][0] == :head ? HEAD_H : ROW_H
        next if ys[i] < @scroll || ys[i] + h > @scroll + avail
        out << [i, LIST_Y0 + 4 + ys[i] - @scroll]
      end
      return [out, total, avail]
    end

    def paint_list_scrollbar(base, c, total, avail)
      paint_scrollbar(base, c, LIST_X1 - 5, total, avail, @scroll) if total > avail
    end

    #--------------------------------------------------------------------------
    # The description box
    #--------------------------------------------------------------------------
    # key: what its scrolling follows (a new key starts at the top).
    # pills: badges after the title, right-aligned ([label, fill, colour]).
    def paint_description_box(base, top, c, title, text, key, pills = [])
      y0 = LIST_Y1 + 4
      description_box(base, c, y0)
      x = W - 14
      pills.each { |label, fill, colour| x -= P.pill(top, x, y0 + 7, label, fill, colour) + 6 }
      room = x - 14 - 6
      P.text(top, 14, y0 + 1, room, 26, PF.fit(PF::ROW, title.to_s, room), c[:head], PF::ROW)
      lines = P.small_wrap(top, text.to_s, W - 30)
      lines = P.small_wrap(top, text.to_s, W - 46) if lines.length > DESC_LINES   # room for the arrows
      first = desc_first_line(key, lines.length)
      paint_lines(top, c, y0, lines[first, DESC_LINES])
      @desc_scrolls = lines.length > DESC_LINES
      return unless @desc_scrolls
      P.ui.tri(top, W - 22, y0 + 32, :u, first > 0 ? c[:dim] : c[:line], 3)
      P.ui.tri(top, W - 22, y0 + 72, :d, first + DESC_LINES < lines.length ? c[:dim] : c[:line], 3)
    end

    # A description longer than the box scrolls while it stays shown, as KIF
    # Settings' does (a new row or entry starts it again at its top).
    def desc_first_line(key, n)
      extra = n - DESC_LINES
      @desc_extra = [extra, 0].max
      return @desc_first = 0 if extra <= 0
      unless key.equal?(@desc_key) || (key.is_a?(Symbol) && key == @desc_key)
        @desc_key = key
        @desc_tick = 0
        @desc_manual = nil
      end
      return @desc_first = [@desc_manual, extra].min if @desc_manual
      step = @desc_tick.to_i / DESC_STEP
      pos = step % (extra + 2 * DESC_HOLD)
      return @desc_first = 0 if pos < DESC_HOLD
      return @desc_first = [pos - DESC_HOLD + 1, extra].min
    end

    def tick_description
      return unless @desc_scrolls
      return if scroll_description || @desc_manual       # by hand: it stays where it's put
      before = @desc_tick.to_i / DESC_STEP
      @desc_tick = @desc_tick.to_i + 1
      refresh if @desc_tick / DESC_STEP != before
    end

    # The right stick (up / down) or the wheel over the box: a line at a time
    def scroll_description
      dir = 0
      v = right_stick_y
      if v.abs >= stick_deadzone
        @desc_held = @desc_held.to_i + 1
        dir = v > 0 ? 1 : -1 if @desc_held == 1 || (@desc_held > DESC_WAIT && @desc_held % DESC_REPEAT == 0)
      else
        @desc_held = 0
      end
      pt = Reloaded::Pointer
      if dir == 0 && pt.inside?(6, LIST_Y1 + 4, W - 6, H - 30)
        dir = pt.wheel
      end
      return false if dir == 0
      return desc_scroll_by(dir)
    end

    # Moves the description dir lines (and keeps it there); false at an end
    def desc_scroll_by(dir)
      return false unless @desc_scrolls
      to = [[(@desc_manual || @desc_first).to_i + dir, 0].max, @desc_extra.to_i].min
      return false if to == (@desc_manual || @desc_first).to_i && !@desc_manual.nil?
      @desc_manual = to
      refresh
      return true
    end

    def right_stick_y
      c = defined?(::Input::Controller) ? ::Input::Controller : nil
      return 0.0 unless c && (c.connected? rescue false)
      axes = (c.raw_axes rescue nil)
      return axes && axes[3] ? axes[3].to_f : 0.0
    end

    def stick_deadzone
      return defined?(Reloaded::Controls) && Reloaded::Controls.respond_to?(:deadzone) ? Reloaded::Controls.deadzone : 0.5
    end
  end
end
