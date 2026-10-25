# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Randomizer's viewers
#==============================================================================
# His pick (2026-10-25, design sheet rnd-sub-viewers, Design 1: Settings
# Layout Reader):
#
#   Spoiler Log      cody's sections in the sidebar (each built when it's
#                    opened: the Pokémon data and the trainers take a
#                    moment), a line per row (old to new drawn as an arrow),
#                    the highlighted line in full below with LINE n OF m;
#                    Jump (L1) typed into the title bar (a dex number or a
#                    word, as his Jump finds it). The log of what the game
#                    uses now (his with_applied), after asking first.
#   Class Themes     each themed class and its types in their colours, what
#                    it means below
#   Entrance Log     cody's Town Map lines in Kanto Reloaded's frame (his
#                    lines and colours), the picked door explained under it,
#                    NEWEST on the newest, "12 Found, 109 to Go" in the title
#                    bar; A for the list of doors. The Town Map opens this one
#                    too while Entrances are on (his ER.show_log, hooked).
#==============================================================================

return unless defined?(Reloaded::SplitScreen)

module Reloaded
  #----------------------------------------------------------------------------
  # The reader: sections in the sidebar, a line per row
  #----------------------------------------------------------------------------
  class RandomizerViewer
    include Reloaded::SplitScreen

    LINE_H = 18

    attr_reader :entry

    class << self
      # :log, :themes or :entrances (the screen asked first, and said so when
      # there's nothing to show)
      def open(kind)
        case kind
        when :log
          r = ::KIF::Rand
          r.with_applied { new(r.sections, _INTL("Spoiler Log")).main }
        when :themes then RandomizerThemes.new.main
        when :entrances then RandomizerDoorLog.open
        end
      end

      # Why there's no Entrance Log to show, or nil
      def doors_missing
        er = ::KIF::Rand::ER
        return _INTL("Entrances aren't shuffled on this save.") unless er.active?
        s = er.state
        return _INTL("You haven't used a shuffled door yet.") unless s && s[:seen] && !s[:seen].empty?
        return nil
      rescue StandardError
        return _INTL("Entrances aren't shuffled on this save.")
      end
    end

    # sections: [[title, proc or lines], ...]
    def initialize(sections, title, seed = true)
      frame_init
      @sections = sections
      @title = title
      @seed = seed
      @lines = {}
      @section = 0
      @side_scroll = 0
      @sel = 0
      @first = 0
      @focus = sections.length == 1 ? :list : :side
    end

    def main
      open_sprites
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        break if handle_input == :close
        tick_description
      end
      return nil
    ensure
      dispose_sprites
    end

    def refresh
      draw_screen if @sprite && !@sprite.disposed?
    end

    def entry=(state)
      @entry = state
    end

    def entry_changed
      refresh
    end

    private

    def r
      return ::KIF::Rand
    end

    def raw_title(i = @section)
      return (@sections[i] || [""])[0].to_s
    end

    # A section's lines, built the first time it's opened
    def lines(i = @section)
      return @lines[i] if @lines[i]
      body = (@sections[i] || [])[1]
      list = body.is_a?(Array) ? body : r.section_lines(body)
      list = [_INTL("(Nothing here.)")] if list.empty?
      return @lines[i] = list.map { |l| PF.utf8(l.to_s) }
    rescue StandardError => e
      Reloaded::Log.exception("A spoiler log section couldn't be read", e, :randomizer)
      return @lines[i] = [_INTL("(This part couldn't be read.)")]
    end

    def fit
      return [(LIST_Y1 - 4 - (LIST_Y0 + 4)) / LINE_H, 1].max
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      return jump if (Input.trigger?(Input::JUMPUP) || Input.trigger?(Input::SPECIAL) || clicked?(*left_box)) && @focus == :list
      handled, result = mouse_input
      return result if handled
      return side_input if @focus == :side
      return list_input
    end

    def side_input
      n = @sections.length
      if Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        target = @section + dir
        if target < 0 || target >= n
          return nil unless fresh?(dir)
          target = dir < 0 ? n - 1 : 0
        end
        pick_section(target)
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::RIGHT) || Input.trigger?(Input::USE)
        open_list
      elsif Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        return :close
      end
      return nil
    end

    def list_input
      n = lines.length
      if Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        target = @sel + dir
        if target < 0 || target >= n
          return nil unless fresh?(dir)
          target = dir < 0 ? n - 1 : 0
        end
        @sel = target
        pbPlayCursorSE
        refresh
      elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
        target = [[@sel + (Input.repeat?(Input::RIGHT) ? fit : -fit), 0].max, n - 1].min
        return nil if target == @sel
        @sel = target
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::BACK)
        return back
      end
      return nil
    end

    def mouse_input
      pt = Reloaded::Pointer
      if pointer_hover && !@entry
        if (i = pt.hit(@side_hits)) && (i != @section || @focus != :side)
          pick_section(i) if i != @section
          @focus = :side
          pbPlayCursorSE
          refresh
        elsif (k = pt.hit(@row_hits)) && (k != @sel || @focus != :list)
          @focus = :list
          @sel = k
          refresh
        end
      end
      return [true, back] if pt.right?
      if (dir = pt.wheel) != 0
        @focus = :list
        @sel = [[@sel + dir, 0].max, lines.length - 1].min
        refresh
        return [true, nil]
      end
      return [false, nil] unless pt.left?
      handled, result = hint_click
      return [true, result] if handled
      if (i = pt.hit(@side_hits))
        pick_section(i) if i != @section
        open_list
      end
      return [true, nil]
    end

    def pick_section(i)
      @section = i
      @sel = 0
      @first = 0
    end

    def open_list
      @focus = :list
      lines                 # (built now: the Pokémon data and trainers take a moment)
      pbPlayDecisionSE
      refresh
      return nil
    end

    def back
      if @focus == :list && @sections.length > 1
        pbPlayCancelSE
        @focus = :side
        refresh
        return nil
      end
      pbPlayCloseMenuSE
      return :close
    end

    # Jump: a dex number ("25", "#025") or a word, typed into the title bar
    # (cody's find_row: from the line after this one, going round)
    def jump
      pbPlayDecisionSE
      text, how = Reloaded::TextEntry.run(self, _INTL("Jump to"), "", 24, :prompt => _INTL("A Dex Number or a Word"))
      refresh
      return nil unless how == :enter && !text.to_s.strip.empty?
      i = (r.find_row(lines, text, @sel) rescue nil)
      if i
        @sel = i
      else
        Reloaded::Dialogs.notice(self, _INTL("Jump"), _INTL("Nothing here matches \"{1}\".", text.to_s.strip))
      end
      refresh
      return nil
    end

    #--------------------------------------------------------------------------
    # Painting
    #--------------------------------------------------------------------------
    def draw_screen
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      base.fill_rect(0, 0, W, H, c[:bg])
      @cursor_rect = nil
      paint_title(base, top, c)
      entries = @sections.each_index.map { |i| { :name => Reloaded::Randomizer::Rows.title(raw_title(i)) } }
      paint_sidebar(base, top, c, entries, @section, @focus == :side)
      paint_list(base, top, c)
      paint_description(base, top, c)
      paint_hints(base, c)
      place_cursor
    end

    def paint_title(base, top, c)
      paint_title_bar(base, c)
      if @entry
        Reloaded::TextEntry.draw_field(base, top, c, @entry, 8, 4, W - 16, 23, 26)
        magnifier(base, 15, c[:txt], c[:dark])
        return
      end
      P.text(top, 0, 2, W, 28, @title, c[:title], PF::TITLE, 2)
      title_box(base, top, c, 8, _INTL("Jump"), :search => true, :off => @focus != :list)
      title_keys(top, c, left_key, nil)
      P.pill(top, W - 8, 8, _INTL("SEED {1}", r.format_seed), c[:pill], c[:txt]) if @seed
    end

    def paint_list(base, top, c)
      P.ui.rbox(base, LIST_X0, LIST_Y0, LIST_X1, LIST_Y1, 6, c[:panel])
      @row_hits = []
      list = lines
      @first = @sel if @sel < @first
      @first = @sel - fit + 1 if @sel >= @first + fit
      @first = [[@first, list.length - fit].min, 0].max
      (list[@first, fit] || []).each_with_index do |ln, k|
        i = @first + k
        y = LIST_Y0 + 4 + k * LINE_H
        @row_hits << [i, LIST_X0 + 4, y, LIST_X1 - 10, y + LINE_H - 1]
        @cursor_rect = [LIST_X0 + 4, y, LIST_X1 - LIST_X0 - 14, LINE_H] if i == @sel && @focus == :list && !@entry
        paint_line(top, c, ln, LIST_X0 + 12, y, LIST_X1 - 16)
      end
      paint_scrollbar(base, c, LIST_X1 - 5, list.length, fit, @first) if list.length > fit
    end

    # "#004 Charmander -> Pikachu": the number dim, an arrow for "->", cut
    # at x1
    def paint_line(top, c, ln, x, y, x1)
      segs = []
      if ln =~ /\A(#\d+) (.*)\z/
        segs << [$1 + " ", c[:dim]]
        ln = $2
      end
      ln.split(" -> ", -1).each_with_index do |part, i|
        segs << [:arrow, c[:dim]] if i > 0
        segs << [part, c[:txt]]
      end
      segs.each do |t, col|
        break if x >= x1
        if t == :arrow
          P.ui.tri(top, x + 2, y + LINE_H / 2 - 3, :r, col, 3)
          x += 11
          next
        end
        room = x1 - x
        s = PF.fit(PF::TEXT, t, room)
        P.text(top, x, y - 1, room, LINE_H, s, col)
        x += P.width(PF::TEXT, s)
      end
    end

    def paint_description(base, top, c)
      if @focus == :side
        title = Reloaded::Randomizer::Rows.title(raw_title)
        return paint_description_box(base, top, c, title, _INTL("Right or A opens this part of the log."), :"log_side_#{@section}")
      end
      ln = lines[@sel].to_s
      title, text = describe_line(raw_title, ln)
      pill = [[_INTL("LINE {1} OF {2}", @sel + 1, lines.length), c[:pill], c[:txt]]]
      paint_description_box(base, top, c, title, text, ln, pill)
    end

    # [title, text] for a line: what it means, by its section
    def describe_line(section, ln)
      a, b = ln.split(" -> ", 2)
      unless b
        head, rest = ln.split(": ", 2)
        return rest ? [head, rest] : [Reloaded::Randomizer::Rows.title(section), ln]
      end
      # (cody's section titles, as his log names them)
      case section
      when /\APok.mon swaps\z/i
        return [a, _INTL("Swap: {1} became {2} everywhere it would be met, wild or given, and in trainers' teams on Follow Wild.", a.sub(/\A#\d+ /, ""), b)]
      when /\AStarters\z/i
        return [a, _INTL("{1}'s ball holds {2}.", a, b)]
      when /\A(Items|TMs)\z/i
        return [a, _INTL("Every {1} the game gives is {2} now.", a, b)]
      when /\ATrades\z/i
        place, from = a.split(": ", 2)
        return [place, _INTL("The trade there gives {1} in place of {2}.", b, from.to_s)]
      when /\AGym types\z/i
        gym, from = a.split(": ", 2)
        return [gym, _INTL("{1} uses {2} now, in place of {3}.", gym, b, from.to_s)]
      when /\ATrainers\z/i
        who, old = a.split(": ", 2)
        return [who, _INTL("Their team: {1}. It was {2}.", b, old.to_s)]
      end
      return [a, ln.gsub(" -> ", ", now ")]
    end

    def hint_pairs
      pr = Reloaded::Prompts
      back = button(:B)
      if @entry
        if pr.controller?
          return [[button(:C), _INTL("Type")], [back, _INTL("Cancel")]]
        end
        enter = Reloaded::Controls::Inputs.key(40)
        esc = Reloaded::Controls::Inputs.key(41)
        return [[nil, _INTL("Type")], [enter, _INTL("Jump")], [esc, _INTL("Cancel")]]
      end
      return [[:ud, _INTL("Part")], [:lr, _INTL("Open"), :open_list], [back, _INTL("Back"), :back]] if @focus == :side
      return [[:ud, _INTL("Scroll")], [:lr, _INTL("Page")], [back, @sections.length > 1 ? _INTL("Parts") : _INTL("Back"), :back]]
    end
  end

  #----------------------------------------------------------------------------
  # Class Themes: each class and its types in their colours
  #----------------------------------------------------------------------------
  class RandomizerThemes
    include Reloaded::SplitScreen

    ROW = 20

    def initialize
      frame_init
      @sel = 0
      @first = 0
      @rows = themes
    end

    def main
      open_sprites
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        break if handle_input == :close
        tick_description
      end
      return nil
    ensure
      dispose_sprites
    end

    def refresh
      draw_screen if @sprite && !@sprite.disposed?
    end

    private

    def r
      return ::KIF::Rand
    end

    # [[class name, [types]]] sorted by name (cody's class_theme_lines, with
    # the types kept)
    def themes
      seen = {}
      out = []
      return out if waiting?
      r.trainer_type_keys.each do |k|
        th = r.class_theme(k)
        next unless th
        name = PF.utf8(r.class_label(k))
        next if seen[[name, th]]
        seen[[name, th]] = true
        out << [name, th]
      end
      return out.sort_by { |n, _t| n }
    rescue StandardError => e
      Reloaded::Log.exception("The Class Theme List couldn't be read", e, :randomizer)
      return []
    end

    # Shuffle Themes is On and the trainers haven't been randomized with it yet
    def waiting?
      return r.dget(:theme_shuffle) == 1 && !r.data[:theme_map]
    end

    def fit
      return [(LIST_Y1 - 4 - (LIST_Y0 + 4)) / ROW, 1].max
    end

    def handle_input
      pt = Reloaded::Pointer
      if pointer_hover && (k = pt.hit(@row_hits)) && k != @sel
        @sel = k
        refresh
      end
      return back if pt.right? || Input.trigger?(Input::BACK)
      if pt.left?
        handled, result = hint_click
        return result if handled
      end
      dir = pt.wheel
      dir = Input.repeat?(Input::DOWN) ? 1 : -1 if dir == 0 && (Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP))
      return nil if dir == 0 || @rows.empty?
      target = @sel + dir
      if target < 0 || target >= @rows.length
        return nil unless pt.wheel == 0 && fresh?(dir)
        target = dir < 0 ? @rows.length - 1 : 0
      end
      @sel = target
      pbPlayCursorSE
      refresh
      return nil
    end

    def back
      pbPlayCloseMenuSE
      return :close
    end

    def type_name(t)
      return (::GameData::Type.get(t).name rescue t.to_s)
    end

    def draw_screen
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      base.fill_rect(0, 0, W, H, c[:bg])
      @cursor_rect = nil
      paint_title_bar(base, c)
      P.text(top, 0, 2, W, 28, _INTL("Class Themes"), c[:title], PF::TITLE, 2)
      P.ui.rbox(base, 6, LIST_Y0, W - 6, LIST_Y1, 6, c[:panel])
      @row_hits = []
      if @rows.empty?
        msg = waiting? ? _INTL("Shuffle Themes is On: Each class gets its type when the trainers are randomized.") :
                         _INTL("No class has a theme: Class Themes is Off.")
        P.small_wrap(top, msg, W - 40).first(3).each_with_index { |l, k| P.small(top, 18, LIST_Y0 + 8 + k * 17, W - 36, 17, l, c[:dim]) }
      else
        @first = @sel if @sel < @first
        @first = @sel - fit + 1 if @sel >= @first + fit
        (@rows[@first, fit] || []).each_with_index do |(name, types), k|
          i = @first + k
          y = LIST_Y0 + 4 + k * ROW
          @row_hits << [i, 10, y, W - 16, y + ROW - 1]
          @cursor_rect = [10, y, W - 26, ROW] if i == @sel
          P.text(top, 18, y - 1, 260, ROW, name, c[:opt])
          x = W - 24
          types.reverse.each_with_index do |t, j|
            if j > 0
              x -= P.width(PF::TEXT, " / ")
              P.text(top, x, y - 1, 30, ROW, " / ", c[:dim])
            end
            s = type_name(t)
            x -= P.width(PF::TEXT, s)
            P.text(top, x, y - 1, 120, ROW, s, Reloaded::PartyPaint.ink(c, Reloaded::PartyScreen.type_rgb(t)))
          end
        end
        paint_scrollbar(base, c, W - 11, @rows.length, fit, @first) if @rows.length > fit
      end
      paint_description(base, top, c)
      paint_hints(base, c)
      place_cursor
    end

    def paint_description(base, top, c)
      shuffle = r.dget(:theme_shuffle) == 1 ? _INTL("Shuffle Themes is On: Each class got its type when the trainers were randomized.") :
                                              _INTL("Shuffle Themes is Off: Each class keeps its usual type.")
      tail = " " + _INTL("Gym Leaders follow the Gyms page.")
      row = @rows[@sel]
      unless row
        return paint_description_box(base, top, c, _INTL("Class Themes"), shuffle + tail, :themes_none)
      end
      name, types = row
      list = types.map { |t| type_name(t) }
      kinds = list.length > 1 ? _INTL("{1} or {2}", list[0...-1].join(", "), list[-1]) : list[0]
      text = _INTL("Every Pokémon a {1} brings has {2} as a type.", name, kinds)
      paint_description_box(base, top, c, name, "#{text} #{shuffle}#{tail}", row)
    end

    def hint_pairs
      return [[:ud, _INTL("Scroll")], [button(:B), _INTL("Back"), :back]]
    end
  end

  #----------------------------------------------------------------------------
  # The Entrance Log: cody's map lines in Kanto Reloaded's frame
  #----------------------------------------------------------------------------
  class RandomizerDoorLog
    include Reloaded::Frame

    MAP_X0 = 6
    MAP_Y0 = 36
    MAP_W  = W - 12
    MAP_H  = 256
    INFO_Y = MAP_Y0 + MAP_H + 4

    def self.open
      list = ::KIF::Rand::ER::LogMap.entries
      return RandomizerDoorLog.list_screen if list.empty?
      new(list).main
    end

    # The doors as lines, newest first (cody's show_list, in the reader)
    def self.list_screen
      er = ::KIF::Rand::ER
      s = er.state
      lines = s[:seen].reverse.map { |door_id, kind| er.describe(door_id, kind) }.reject(&:empty?)
      found, left = er::LogMap.counts
      lines << _INTL("Doors not yet found: {1}", left)
      RandomizerViewer.new([[_INTL("{1} Found, Newest First", found), lines]], _INTL("Entrance Log"), false).main
    end

    def initialize(list)
      frame_init
      @list = list
      @index = 0
      @side = nil
    end

    def main
      open_sprites
      start_map
      select(0, true)
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        update_map
        break if handle_input == :close
      end
      return nil
    ensure
      [@map_bm, @lines_bm, @sel_bm, @you_bm].each { |b| b.dispose if b && !b.disposed? }
      @map_sprite.bitmap.dispose if @map_sprite && !@map_sprite.disposed? && @map_sprite.bitmap
      @map_sprite.dispose if @map_sprite && !@map_sprite.disposed?
      dispose_sprites
    end

    def refresh
      draw_screen if @sprite && !@sprite.disposed?
    end

    private

    def lm
      return ::KIF::Rand::ER::LogMap
    end

    # The map hidden with the rest when another screen steps in
    def sprites
      return super + [@map_sprite].compact.reject(&:disposed?)
    end

    # cody's map, every door found so far, and the chosen one on a layer of
    # its own (pulsing)
    def start_map
      @map_bm = Bitmap.new(lm.map_file)
      @lines_bm = Bitmap.new(@map_bm.width, @map_bm.height)
      @sel_bm = Bitmap.new(@map_bm.width, @map_bm.height)
      colors = lm::COLORS
      @list.reverse_each { |e| lm.draw_line(@lines_bm, lm.points(e), colors[e[:pool]] || colors[:building], 2, false) }
      @list.reverse_each { |e| lm.draw_ends(@lines_bm, e, colors[e[:pool]] || colors[:building]) }
      @you_bm = (Bitmap.new("Graphics/Pictures/map/location_icon") rescue nil)
      @here = (lm.pos_of($game_map.map_id) rescue nil)
      @max_ox = [@map_bm.width - MAP_W, 0].max
      @max_oy = [@map_bm.height - MAP_H, 0].max
      @ox = 0
      @oy = 0
      @map_sprite = Sprite.new(@viewport)
      @map_sprite.bitmap = Bitmap.new(MAP_W, MAP_H)
      @map_sprite.x = MAP_X0
      @map_sprite.y = MAP_Y0
      @map_sprite.z = 1
    end

    def select(i, jump = false)
      @index = i
      @side = nil
      e = @list[i]
      @sel_bm.clear
      lm.draw_line(@sel_bm, lm.points(e), lm::SELECTED, 3)
      lm.draw_ends(@sel_bm, e, lm::SELECTED)
      aim(e, jump)
    end

    # The window on the line (or one end of it)
    def aim(e, jump = false)
      fx, fy = lm.focus(e, @side)
      @target = [[[fx - MAP_W / 2, 0].max, @max_ox].min, [[fy - MAP_H / 2, 0].max, @max_oy].min]
      @ox, @oy = @target if jump
    end

    # Every frame: the window glides to its target; the chosen line pulses
    def update_map
      return unless @map_sprite && !@map_sprite.disposed? && @map_sprite.visible
      if @target
        @ox = glide(@ox, @target[0])
        @oy = glide(@oy, @target[1])
      end
      b = @map_sprite.bitmap
      b.clear
      src = Rect.new(@ox, @oy, MAP_W, MAP_H)
      b.blt(0, 0, @map_bm, src)
      b.blt(0, 0, @lines_bm, src, 180)
      b.blt(0, 0, @sel_bm, src, 175 + (80 * Math.sin(@frame / 8.0)).round)
      if @you_bm && @here
        tile = lm::TILE
        b.blt(@here[0] * tile + tile / 2 - @you_bm.width / 2 - @ox, @here[1] * tile + tile / 2 - @you_bm.height / 2 - @oy, @you_bm,
              Rect.new(0, 0, @you_bm.width, @you_bm.height))
      end
    end

    def glide(cur, dest)
      step = (dest - cur) * 0.25
      step = (dest <=> cur) if step.abs < 1 && dest != cur
      return (cur + step).round
    end

    def handle_input
      pt = Reloaded::Pointer
      pointer_hover
      return back if Input.trigger?(Input::BACK) || pt.right?
      if pt.left?
        handled, result = hint_click
        return result if handled
      end
      if Input.trigger?(Input::USE)
        show_list
      elsif (Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP) || pt.wheel != 0) && @list.length > 1
        dir = pt.wheel != 0 ? pt.wheel : (Input.repeat?(Input::DOWN) ? 1 : -1)
        pbPlayCursorSE
        select((@index + dir) % @list.length)
        refresh
      elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
        # the door's end, then where it led, then the whole line (cody's)
        pbPlayCursorSE
        @side = { nil => :door, :door => :place, :place => nil }[@side]
        aim(@list[@index])
      end
      return nil
    end

    def back
      pbPlayCloseMenuSE
      return :close
    end

    def show_list
      pbPlayDecisionSE
      hidden { RandomizerDoorLog.list_screen }
      refresh
      return nil
    end

    def draw_screen
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      base.fill_rect(0, 0, W, H, c[:bg])
      @cursor_rect = nil
      paint_title_bar(base, c)
      P.text(top, 0, 2, W, 28, _INTL("Entrance Log"), c[:title], P.pf::TITLE, 2)
      found, left = lm.counts
      P.small(top, W - 210, 4, 200, 23, _INTL("{1} Found, {2} to Go", found, left), c[:dim], 1)
      P.ui.rbox(base, MAP_X0 - 2, MAP_Y0 - 2, MAP_X0 + MAP_W + 1, MAP_Y0 + MAP_H + 1, 4, c[:line])
      e = @list[@index]
      description_box(base, c, INFO_Y)
      colors = lm::COLORS
      col = colors[e[:pool]] || colors[:building]
      P.ui.rbox(top, 14, INFO_Y + 9, 23, INFO_Y + 18, 2, col)
      a, b = lm.line_text(e)
      x = W - 14
      x -= P.pill(top, x, INFO_Y + 6, _INTL("NEWEST"), c[:pill], c[:txt]) + 6 if @index == 0
      P.text(top, 30, INFO_Y + 1, x - 36, 24, P.pf.fit(P.pf::ROW, u8(a), x - 36), c[:head], P.pf::ROW)
      P.small(top, 30, INFO_Y + 25, W - 50, 16, u8(b), c[:dim])
      kind = e[:pool] == :dungeon ? _INTL("A dungeon door (purple on the map)") : _INTL("A building door (gold on the map)")
      P.small(top, 30, INFO_Y + 40, W - 50, 16, kind, c[:dim])
      paint_hints(base, c)
      place_cursor
    end

    def u8(s)
      return P.pf.utf8(s.to_s)
    end

    def hint_pairs
      return [[:ud, _INTL("Door")], [:lr, _INTL("Ends")], [button(:C), _INTL("List"), :show_list], [button(:B), _INTL("Back"), :back]]
    end
  end

  module Randomizer
    class << self
      # The Town Map's Entrance Log (cody's ER.show_log, while Entrances are
      # on): Kanto Reloaded's; nothing to show goes his way (his message)
      def install_viewers
        return unless defined?(::KIF::Rand::ER) && ::KIF::Rand::ER.respond_to?(:show_log)
        Reloaded::Hooks.around(FEATURE, ::KIF::Rand::ER.singleton_class, :show_log, :id => :randomizer_entrance_log) do |original, *args|
          next original.call(*args) if Reloaded::RandomizerViewer.doors_missing
          begin
            Reloaded::RandomizerDoorLog.open
          rescue StandardError => e
            Reloaded::Log.exception("The Entrance Log failed; KIF's instead", e, :randomizer)
            original.call(*args)
          end
        end
      end
    end
  end
end
