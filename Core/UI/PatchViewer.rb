#==============================================================================
# Kanto Reloaded: the Patch Viewer
#==============================================================================
# Every mod's data patches, in the Settings layout (Roadmap topic 30, design
# 1): the mods on the left in load order, the selected mod's rows on the
# right (a target, how many entries, Added / Edited / Rejected), its status
# on its heading (OK, N CONFLICT, N REJECTED), and the description box
# saying what the row means in plain words. Search on the left of the title
# bar, Load Order on the right; A lists a row's entries (Details).
#
# Hot Reload (Y, only with KIF's DEBUG option on): the patches again without
# a restart, and a report of what changed and any new errors.
#
# Opened from Kanto Reloaded > Data Patches > Patch Viewer. The words come
# from Reloaded::DataPatches::Overview.
#==============================================================================

# Needs Kanto Reloaded's pixel UI (KIF's pixel fonts).
return unless defined?(Reloaded::SplitScreen)

module Reloaded
  class PatchViewer
    include Reloaded::SplitScreen       # the sidebar, list and description box (Core/UI/SplitScreen.rb)

    COUNT_X1 = VAL_X1 - 96           # the count's right edge (room for Rejected)
    LOAD_ORDER_W = 132               # the right box, so Load Order fits
    RELOAD_W = 372
    WORDS = { :added => "Added", :edited => "Edited", :rejected => "Rejected" }.freeze
    COLORS = { :added => GREEN, :edited => BLUE, :rejected => RED }.freeze

    attr_reader :entry

    def self.open
      return new.main
    end

    def initialize
      frame_init
      @overview = Reloaded::DataPatches::Overview.new
      @section = 0
      @side_scroll = 0
      @sel = 0
      @scroll = 0
      @focus = :side
      @query = nil
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

    # TextEntry (Search) asks for these.
    def entry=(state)
      @entry = state
    end

    def entry_changed
      refresh
    end

    private

    def sections
      return @overview.sections
    end

    def section
      return sections[@section]
    end

    # What the list shows: the selected mod (its heading and rows), or with
    # a search, every mod's matching rows under its heading.
    # [[:head, section] or [:row, row]]
    def items
      return @items if @items
      list = []
      shown = @query ? sections : [section].compact
      shown.each do |s|
        rows = @query ? s.rows.select { |r| @overview.matches?(r, @query) } : s.rows
        next if rows.empty?
        list << [:head, s]
        rows.each { |r| list << [:row, r] }
      end
      return @items = list
    end

    def rows
      return items.select { |kind, _| kind == :row }.map { |_, r| r }
    end

    def current
      return rows[@sel]
    end

    def query=(text)
      text = text.to_s.strip
      @query = text.empty? ? nil : text
      @items = nil
      @sel = 0
      @scroll = 0
    end

    def found?(s)
      return s.rows.any? { |r| @overview.matches?(r, @query) }
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      return search if Input.trigger?(Input::JUMPUP) || Input.trigger?(Input::SPECIAL) || clicked?(*left_box)
      return load_order if Input.trigger?(Input::R) || clicked?(*right_box)
      return hot_reload if Input.trigger?(Input::X) && Reloaded.debug?      # a controller's Y
      handled, result = mouse_input
      return result if handled
      return side_input if @focus == :side
      return list_input
    end

    def side_input
      n = sections.length
      if (Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)) && n > 0 && !@query
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        target = @section + dir
        if target < 0 || target >= n
          return nil unless fresh?(dir)
          target = dir < 0 ? n - 1 : 0
        end
        return nil if target == @section
        pick_section(target)
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::RIGHT) || Input.trigger?(Input::USE)
        open_list
      elsif Input.trigger?(Input::BACK)
        return back
      end
      return nil
    end

    def list_input
      n = rows.length
      if (Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)) && n > 0
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        target = @sel + dir
        if target < 0 || target >= n
          return nil unless fresh?(dir)
          target = dir < 0 ? n - 1 : 0
        end
        @sel = target
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::USE)
        details
      elsif Input.trigger?(Input::BACK) || (Input.trigger?(Input::LEFT) && !@query)
        return back
      end
      return nil
    end

    def mouse_input
      pt = Reloaded::Pointer
      if pointer_hover && !@entry
        if (i = pt.hit(@side_hits))
          hover_section(i)
        elsif (k = pt.hit(@row_hits))
          hover_row(k)
        end
      end
      return [true, back] if pt.right?
      dir = pt.wheel
      if dir != 0
        pt.inside?(LIST_X0, LIST_Y0, LIST_X1, LIST_Y1) ? step_row(dir) : step_section(dir)
        return [true, nil]
      end
      return [false, nil] unless pt.left?
      handled, result = hint_click
      return [true, result] if handled
      if (i = pt.hit(@side_hits))
        click_section(i)
      elsif (k = pt.hit(@row_hits))
        hover_row(k)
        details
      end
      return [true, nil]
    end

    def pick_section(i)
      @section = i
      @items = nil
      @sel = 0
      @scroll = 0
    end

    def hover_section(i)
      return if @query || (i == @section && @focus == :side)
      pick_section(i)
      @focus = :side
      pbPlayCursorSE
      refresh
    end

    def hover_row(k)
      return if @focus == :list && @sel == k
      @focus = :list
      @sel = k
      pbPlayCursorSE
      refresh
    end

    def click_section(i)
      self.query = nil if @query
      pick_section(i) if i != @section
      @focus = :side
      open_list
    end

    def step_row(dir)
      return if rows.empty?
      @focus = :list
      @sel = [[@sel + dir, 0].max, rows.length - 1].min
      refresh
    end

    def step_section(dir)
      return if @query || sections.empty?
      target = [[@section + dir, 0].max, sections.length - 1].min
      return if target == @section
      pick_section(target)
      @focus = :side
      refresh
    end

    # The hint line's Open, Right or A on a mod: its rows.
    def open_list
      return pbPlayBuzzerSE if rows.empty?
      @focus = :list
      pbPlayDecisionSE
      refresh
      return nil
    end

    # B: out of the rows, the search, or the screen.
    def back
      if @focus == :list && !@query
        pbPlayCancelSE
        @focus = :side
        refresh
        return nil
      end
      if @query
        pbPlayCancelSE
        self.query = nil
        @focus = :side
        refresh
        return nil
      end
      pbPlayCloseMenuSE
      return :close
    end

    # Search, as KIF Settings' works: typed straight into the title bar, the
    # list following as you type; a controller's A opens the naming screen.
    def search
      pbPlayDecisionSE
      text, _how = Reloaded::TextEntry.run(self, _INTL("Type to Search"), @query || "", 30,
                                           :prompt => _INTL("Search Data Patches"), :down => true) { |t| self.query = t }
      self.query = text
      @focus = @query && !rows.empty? ? :list : :side
      refresh
      return nil
    end

    # A: every entry of the row, and what happened to it.
    def details
      r = current
      return pbPlayBuzzerSE unless r
      pbPlayDecisionSE
      list = @overview.entries(r)
      Reloaded::Dialogs.menu(self, _INTL("{1} {2}", r.label, _INTL(WORDS[r.kind])), list.map { |e| e[0] }, list.map { |e| e[1] })
      refresh
      return nil
    end

    # The order patches apply in; a pick opens that mod.
    def load_order
      pbPlayDecisionSE
      if sections.empty?
        Reloaded::Dialogs.notice(self, _INTL("Load Order"), _INTL("No mod has data patches."))
        refresh
        return nil
      end
      labels = sections.map { |s| "#{s.order}. #{s.name}" }
      descs = sections.map do |s|
        how = s.code ? _INTL("From its scripts.") : _INTL("Loads {1} of {2}.", ordinal(s.order), sections.length)
        _INTL("{1} When two mods change the same thing, the lower one in this list wins.", how)
      end
      i = Reloaded::Dialogs.menu(self, _INTL("Load Order"), labels, descs, @section)
      if i
        self.query = nil
        pick_section(i)
        @focus = :side
      end
      refresh
      return nil
    end

    def right_w
      return LOAD_ORDER_W
    end

    def ordinal(n)
      suffix = (11..13).include?(n % 100) ? "th" : { 1 => "st", 2 => "nd", 3 => "rd" }.fetch(n % 10, "th")
      return "#{n}#{suffix}"
    end

    #--------------------------------------------------------------------------
    # Hot Reload
    #--------------------------------------------------------------------------
    # Y (KIF's DEBUG option on): the patches again, then what changed.
    def hot_reload
      return nil unless Reloaded.debug?
      pbPlayDecisionSE
      overview = Reloaded::DataPatches::Overview
      before = overview.snapshot
      seconds = Reloaded::DataPatches.reload
      report = overview.changes(before, overview.snapshot)
      key = section && section.key
      @overview = overview.new
      @items = nil
      @section = sections.index { |s| s.key == key } || [[@section, sections.length - 1].min, 0].max
      @sel = [[@sel, rows.length - 1].min, 0].max
      @focus = :side if rows.empty?
      refresh
      show_reload(report, seconds)
      return nil
    end

    # The report, until A, B or a click.
    def show_reload(report, seconds)
      paint_reload(report, seconds)
      loop do
        Graphics.update
        Input.update
        update_frame
        pt = Reloaded::Pointer
        if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK) || pt.left? || pt.right?
          pbPlayDecisionSE
          break
        end
      end
      overlay.clear
    end

    def paint_reload(report, seconds)
      c = palette
      o = overlay
      o.clear
      o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
      lines = reload_lines(report)
      errors = report[:new_errors].first(3).flat_map { |e| P.small_wrap(o, e, RELOAD_W - 36).first(2) }
      h = 58 + lines.length * 24 + (errors.empty? ? 0 : errors.length * 16 + 6) + 46
      x = (W - RELOAD_W) / 2
      y = (H - h) / 2
      P.ui.rbox(o, x, y, x + RELOAD_W, y + h, 6, c[:panel2], c[:selb])
      P.text(o, x, y + 4, RELOAD_W, 26, _INTL("Patches Reloaded"), c[:title], PF::ROW, 2)
      mods = report[:mods]
      who = if mods.length == 1 then mods.first
            elsif mods.empty? then _INTL("Nothing changed")
            else _INTL("{1} mods", mods.length)
            end
      took = seconds < 0.05 ? _INTL("under 0.1 seconds") : _INTL("{1} seconds", format("%.1f", seconds))
      P.small(o, x, y + 30, RELOAD_W, 16, _INTL("{1}, {2}, no restart", who, took), c[:dim], 2)
      o.fill_rect(x + 10, y + 50, RELOAD_W - 20, 1, c[:line])
      ly = y + 56
      lines.each do |label, value, colr|
        P.text(o, x + 18, ly, RELOAD_W - 36, 22, label, c[:txt])
        P.text(o, x + 18, ly, RELOAD_W - 36, 22, value, colr, nil, 1)
        ly += 24
      end
      errors.each_with_index do |ln, k|
        P.small(o, x + 18, ly + 4 + k * 16, RELOAD_W - 36, 16, ln, RED)
      end
      bw = 110
      bx = x + (RELOAD_W - bw) / 2
      by = y + h - 36
      P.ui.rbox(o, bx, by, bx + bw, by + 24, 5, c[:selb])
      P.text(o, bx, by, bw, 24, _INTL("OK"), c[:dark], nil, 2)
    end

    # [label, value, colour]: each target that changed, then what was
    # rejected; "Nothing changed" when nothing did.
    def reload_lines(report)
      out = report[:targets].first(6).map do |target, n|
        parts = []
        parts << _INTL("{1} added", n[:added]) if n[:added] > 0
        parts << _INTL("{1} changed", n[:changed]) if n[:changed] > 0
        parts << _INTL("{1} removed", n[:removed]) if n[:removed] > 0
        colr = n[:changed] == 0 && n[:removed] == 0 ? GREEN : BLUE
        [Reloaded::DataPatches.label(target), parts.join(", "), colr]
      end
      more = report[:targets].length - 6
      out << [_INTL("And More"), _INTL("{1} more", more), BLUE] if more > 0
      news = report[:new_errors].length
      out << [_INTL("Rejected"), _INTL("{1} new", news), RED] if news > 0
      out << [_INTL("Fixed"), _INTL("{1} fewer rejected", report[:fixed]), GREEN] if report[:fixed] > 0
      out << [_INTL("Nothing Changed"), "", palette[:dim]] if out.empty?
      return out
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
      paint_side(base, top, c)
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
        if @query
          n = rows.length
          P.small(top, W - 120, 4, 100, 23, n == 1 ? _INTL("1 Found") : _INTL("{1} Found", n), c[:dim], 1)
        end
        return
      end
      P.text(top, 0, 2, W, 28, _INTL("Data Patches"), c[:title], PF::TITLE, 2)
      title_box(base, top, c, 8, @query || _INTL("Search"), :search => true, :active => !@query.nil?)
      title_box(base, top, c, W - 8 - right_w, _INTL("Load Order"), :off => sections.empty?, :w => right_w)
      title_keys(top, c, left_key, right_key)
    end

    def paint_side(base, top, c)
      entries = sections.map do |x|
        { :name => x.name, :tile => x.own? ? :ball : nil, :faded => @query && !found?(x) }
      end
      paint_sidebar(base, top, c, entries, @query ? nil : @section, @focus == :side)
    end

    def paint_list(base, top, c)
      P.ui.rbox(base, LIST_X0, LIST_Y0, LIST_X1, LIST_Y1, 6, c[:panel])
      @row_hits = []
      if items.empty?
        w = LIST_X1 - LIST_X0 - 24
        P.text(top, LIST_X0 + 12, LIST_Y0 + 8, w, 22, PF.fit(PF::TEXT, empty_message, w), c[:dim])
        return
      end
      sel = current && items.index { |kind, it| kind == :row && it.equal?(current) }
      out, total, avail = layout_items(items, sel)
      out.each do |i, y|
        kind, it = items[i]
        if kind == :head
          paint_heading(top, c, it, y)
          next
        end
        k = rows.index(it)
        @row_hits << [k, LIST_X0 + 4, y, LIST_X1 - 8, y + ROW_H - 2]
        selected = k == @sel && @focus == :list && !@entry
        @cursor_rect = [LIST_X0 + 4, y, (LIST_X1 - 8) - (LIST_X0 + 4) + 1, ROW_H - 1] if selected
        count = it.kind == :added ? "+#{it.count}" : it.count.to_s
        cw = PF.width(PF::ROW, count)
        P.text(top, NAME_X, y, COUNT_X1 - cw - 10 - NAME_X, ROW_H - 2, PF.fit(PF::ROW, it.label, COUNT_X1 - cw - 10 - NAME_X), c[:opt], PF::ROW)
        P.text(top, COUNT_X1 - cw, y, cw + 2, ROW_H - 2, count, c[:opt], PF::ROW)
        P.text(top, COUNT_X1 + 6, y, VAL_X1 - COUNT_X1 - 6, ROW_H - 2, _INTL(WORDS[it.kind]), COLORS[it.kind], PF::ROW, 1)
      end
      paint_list_scrollbar(base, c, total, avail)
    end

    # A mod's heading: its name, a line, its status.
    def paint_heading(top, c, s, y)
      label, colr = case s.status
                    when :rejected then [_INTL("{1} REJECTED", s.rejected), RED]
                    when :conflict then [s.conflicts == 1 ? _INTL("1 CONFLICT") : _INTL("{1} CONFLICTS", s.conflicts), AMBER]
                    else [_INTL("OK"), GREEN]
                    end
      pw = P.pill(top, VAL_X1, y + 2, label, dark_fill(colr), colr)
      P.heading(top, LIST_X0 + 10, VAL_X1 - pw - 6, y + 3, s.name, c[:head], c[:line])
    end

    def empty_message
      return _INTL("Nothing matches \"{1}\".", @query) if @query
      return _INTL("No mod has data patches.")
    end

    def paint_description(base, top, c)
      title, text, key = description
      paint_description_box(base, top, c, title, text, key)
    end

    # [title, text, what its scrolling follows]
    def description
      if sections.empty?
        return [_INTL("Data Patches"),
                _INTL("Mods change the game's data with JSON files in their DataPatches folder: Items, moves, abilities, species, trainers, encounters and outfits. None of your mods has any."),
                :empty]
      end
      r = (@focus == :list || @query) ? current : nil
      return [r.label, @overview.describe(r), r] if r
      s = section
      return [s.name, @overview.describe_section(s), s]
    end

    def hint_pairs
      pr = Reloaded::Prompts
      back = button(:B)
      if @entry
        if pr.controller?
          return [[button(:C), _INTL("Type")], [:d, _INTL("Results")], [back, _INTL("Done")]]
        end
        enter = Reloaded::Controls::Inputs.key(40)
        esc = Reloaded::Controls::Inputs.key(41)
        return [[nil, _INTL("Type to Search")], [enter, _INTL("Results")], [esc, _INTL("Done")]]
      end
      reload = Reloaded.debug? ? [[button(:X), _INTL("Reload"), :hot_reload]] : []
      out = @query ? _INTL("Clear") : _INTL("Back")
      return reload + [[back, _INTL("Close"), :back]] if sections.empty?
      if @focus == :side
        return [[:ud, _INTL("Mod")], [:lr, _INTL("Open"), :open_list]] + reload + [[back, @query ? out : _INTL("Close"), :back]]
      end
      return [[:ud, _INTL("Select")], [button(:C), _INTL("Details"), :details]] + reload + [[back, out, :back]]
    end
  end
end
