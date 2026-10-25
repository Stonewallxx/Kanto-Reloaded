# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Bag's Custom List editor
#==============================================================================
# His pick (Roadmap Designs topic bag, popup 4, 2026-10-23): Full Screen,
# like the Bag. Opened from Kanto Reloaded > Bag > Edit Custom Lists.
#
#   the header   Search (L; type into it) and Defaults (R: the pocket's list
#                back to old Kanto Reloaded's)
#   the pockets  the eight pockets' icons, the open one lit, its name;
#                Left and Right change pocket
#   the list     the pocket's Custom List: headings of your own, and items,
#                in your Bag in the pocket's colour with how many, the rest
#                dim; Favorites starred
#   the details  lit in the item's colour: its name, IN THE BAG or not, and
#                where the pocket shows it
#
# A opens an entry's actions, X (Action) moves it (a gold edge and MOVING,
# as the Bag's Move: Up and Down carry it, A puts it down, B puts it back),
# Y adds an item, B is done. Every change is the save's list straight away,
# and a pocket on Custom List sorts again.
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(Reloaded::BagLook)

module Reloaded
  class BagListScreen
    include Reloaded::Frame
    include Reloaded::BagLook

    SEARCH_BOX = [6, 4, 132, 26].freeze
    DEFAULTS_BOX = [W - 132, 4, W - 6, 26].freeze
    BAR_Y = 34
    LIST_Y0 = 66
    LIST_Y1 = 245
    ROW_H = 25
    HEAD_H = 18
    LIST_X = 14
    LIST_W = W - 38
    DETAILS_Y = 249

    def self.open(pocket = nil)
      unless Reloaded::Bag.data
        pbPlayBuzzerSE if defined?(pbPlayBuzzerSE)
        return nil
      end
      pocket ||= ($PokemonBag && $PokemonBag.respond_to?(:lastpocket) ? $PokemonBag.lastpocket.to_i : 1)
      pocket = 1 unless Reloaded::Bag.pockets.include?(pocket)
      screen = new(pocket)
      defined?(pbFadeOutIn) ? pbFadeOutIn { screen.main } : screen.main
      return screen
    end

    attr_reader :entry, :sel, :pocket, :query

    def initialize(pocket = 1)
      frame_init
      @pocket = pocket
      @sel = 0
      @scroll = 0
      @query = nil
      @moving = nil
      @pictures = {}
      @rows = nil
    end

    def main
      open_sprites
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        Reloaded::Toast.update if defined?(Reloaded::Toast)
        break if handle_input == :close
      end
      return nil
    ensure
      dispose_sprites
      @pictures.each_value { |b| b.dispose if b && !b.disposed? }
      @pictures = {}
    end

    def entry=(state)
      @entry = state
    end

    def entry_changed
      changed!
    end

    def refresh
      draw if @sprite && !@sprite.disposed?
    end

    # [[:heading, name, index] | [:item, id, index]]: index is the entry's
    # place in the list (a search shows only the items that match)
    def rows
      @rows ||= build_rows
    end

    def current
      return rows[@sel]
    end

    private

    def changed!
      @rows = nil
      @sel = [[@sel, rows.length - 1].min, 0].max
      refresh
    end

    def list
      return @moving ? @moving[2] : B.custom_list(@pocket)
    end

    def build_rows
      out = []
      list.each_with_index do |e, i|
        if B.heading?(e)
          out << [:heading, B.heading_name(e), i] unless @query
        elsif @query.nil? || match?(e)
          out << [:item, e.to_sym, i]
        end
      end
      return out
    end

    def match?(id)
      q = @query.to_s.downcase
      it = B.item_data(id)
      words = [display_name(id), it ? it.name : id.to_s].map { |w| w.to_s.downcase }
      return words.any? { |w| w.start_with?(q) || w.split(/[\s\-]+/).any? { |part| part.start_with?(q) } }
    end

    def quantity(id)
      return ($PokemonBag ? $PokemonBag.pbQuantity(id) : 0).to_i
    rescue StandardError
      return 0
    end

    # The list with one change: written to the save (a Custom List pocket
    # sorts again)
    def save_list(entries)
      B.set_list(@pocket, entries, B.mode(@pocket) == 1)
    end

    def pocket_label(pocket = @pocket)
      return B.file_pocket_name(pocket)
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      return moving_input if @moving
      return search if Input.trigger?(Input::JUMPUP) || Input.trigger?(Input::SPECIAL) || clicked?(*SEARCH_BOX)
      return defaults if Input.trigger?(Input::JUMPDOWN) || clicked?(*DEFAULTS_BOX)
      handled, result = mouse_input
      return result if handled
      if Input.trigger?(Input::BACK)
        return hint_back
      elsif Input.trigger?(Input::USE)
        actions
      elsif Input.trigger?(Input::ACTION)
        start_move
      elsif Input.trigger?(Input::X)
        add_item
      elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
        step_pocket(Input.trigger?(Input::RIGHT) ? 1 : -1)
      elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        step_row(Input.repeat?(Input::DOWN) ? 1 : -1)
      end
      return nil
    end

    def step_row(dir)
      n = rows.length
      return if n == 0
      target = @sel + dir
      if target < 0 || target >= n
        return unless fresh?(dir)
        target = dir < 0 ? n - 1 : 0
      end
      @sel = target
      pbPlayCursorSE
      refresh
    end

    def step_pocket(dir)
      return pbPlayBuzzerSE if @query
      list = B.pockets
      @pocket = list[((list.index(@pocket) || 0) + dir) % list.length]
      @sel = 0
      @scroll = 0
      pbPlayCursorSE
      changed!
    end

    def set_pocket(p)
      return if p == @pocket || @query
      @pocket = p
      @sel = 0
      @scroll = 0
      pbPlayCursorSE
      changed!
    end

    def hint_back
      if @query
        pbPlayCancelSE
        @query = nil
        changed!
        return nil
      end
      pbPlayCloseMenuSE
      return :close
    end

    def search
      pbPlayDecisionSE
      text, _how = Reloaded::TextEntry.run(self, _INTL("Type to Search"), @query || "", 20,
                                           :prompt => _INTL("Search the List"), :down => true) do |t|
        @query = t.strip.empty? ? nil : t.strip
        @sel = 0
        changed!
      end
      @query = text.to_s.strip.empty? ? nil : text.strip
      @sel = 0
      changed!
      return nil
    end

    # The mouse: pointing at a row picks it, a click opens its actions, on a
    # pocket opens it; the wheel scrolls; a right click goes back
    def mouse_input
      pt = Reloaded::Pointer
      if pointer_hover && !@entry && (k = pt.hit(@row_hits || [])) && k != @sel
        @sel = k
        refresh
      end
      return [true, hint_back] if pt.right?
      dir = pt.wheel
      if dir != 0
        n = rows.length
        if n > 0
          @sel = (@sel + dir).clamp(0, n - 1)
          refresh
        end
        return [true, nil]
      end
      return [false, nil] unless pt.left?
      handled, result = hint_click
      return [true, result] if handled
      if (p = pt.hit(@pocket_hits || []))
        set_pocket(p)
      elsif (k = pt.hit(@row_hits || []))
        @sel = k
        actions
      end
      return [true, nil]
    end

    def left_box
      return SEARCH_BOX
    end

    def right_box
      return DEFAULTS_BOX
    end

    def hint_actions
      actions
      return nil
    end

    def hint_move
      start_move
      return nil
    end

    def hint_add
      add_item
      return nil
    end

    #--------------------------------------------------------------------------
    # Moving: the Bag's Move look; the list changes only when it's put down
    #--------------------------------------------------------------------------
    def start_move
      r = current
      return pbPlayBuzzerSE unless r && @query.nil?
      pbPlayDecisionSE
      work = B.custom_list(@pocket).dup
      @moving = [r[2], r[2], work]   # [from, at, the list while moving]
      changed!
    end

    def moving_input
      from, at, work = @moving
      if Input.trigger?(Input::USE) || Input.trigger?(Input::ACTION)
        pbPlayDecisionSE
        save_list(work)
        finish_move(at)
      elsif Input.trigger?(Input::BACK) || Reloaded::Pointer.right?
        pbPlayCancelSE
        finish_move(from)
      elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        to = at + (Input.repeat?(Input::DOWN) ? 1 : -1)
        return nil unless to.between?(0, work.length - 1)
        work.insert(to, work.delete_at(at))
        @moving[1] = to
        @sel = to
        pbPlayCursorSE
        @rows = nil
        refresh
      end
      return nil
    end

    def finish_move(index)
      @moving = nil
      @rows = nil
      @sel = rows.index { |r| r[2] == index } || 0
      refresh
    end

    #--------------------------------------------------------------------------
    # An entry's actions, Add Item, Defaults
    #--------------------------------------------------------------------------
    def actions
      r = current
      return pbPlayBuzzerSE unless r
      pbPlayDecisionSE
      labels = []
      notes = []
      map = []
      add = proc { |l, n, a| labels << l; notes << n; map << a }
      if @query.nil?
        add.call(_INTL("Move"), _INTL("Carry it up or down the list."), :move)
      end
      if r[0] == :heading
        add.call(_INTL("Rename Heading"), _INTL("Type a new name for it."), :rename)
        add.call(_INTL("Remove Heading"), _INTL("Take the heading out; the items under it stay."), :remove)
      else
        add.call(_INTL("Remove From List"), _INTL("{1} sorts it after the list, A to Z.", pocket_label), :remove)
      end
      add.call(_INTL("Add a Heading Above"), _INTL("A heading of your own above this one; it sorts nothing."), :heading) if @query.nil?
      add.call(_INTL("Cancel"), _INTL("Back to the list."), :cancel)
      title = r[0] == :heading ? r[1] : display_name(r[1])
      choice = with_hints([[:ud, _INTL("Choose")], [button(:C), _INTL("Pick")], [button(:B), _INTL("Back")]]) do
        Reloaded::Dialogs.menu(self, title, labels, notes, 0)
      end
      case choice && map[choice]
      when :move then start_move
      when :rename then rename_heading(r)
      when :remove then remove_entry(r)
      when :heading then add_heading(r[2])
      end
      refresh
    end

    def remove_entry(r)
      entries = B.custom_list(@pocket)
      entries.delete_at(r[2])
      save_list(entries)
      changed!
    end

    def add_heading(at)
      name = ask_name("")
      return if name.empty?
      entries = B.custom_list(@pocket)
      entries.insert(at, B.heading(name))
      save_list(entries)
      @rows = nil
      @sel = rows.index { |x| x[2] == at } || @sel
      changed!
    end

    def rename_heading(r)
      name = ask_name(r[1])
      return if name.empty?
      entries = B.custom_list(@pocket)
      entries[r[2]] = B.heading(name)
      save_list(entries)
      changed!
    end

    # Typed straight into the header (a controller's A opens the naming
    # screen)
    def ask_name(initial)
      text, how = Reloaded::TextEntry.run(self, _INTL("Heading Name"), initial.to_s, B::HEADING_MAX, :prompt => _INTL("Name the Heading"))
      refresh
      return how == :cancel ? "" : text.to_s.gsub(%r{#|//}, "").strip
    end

    # Y: one of the pocket's items not on the list yet, after the highlighted
    # entry (his pick, small popup design 2: a list to search). Those you
    # have first, then A to Z; L, Y or a click on the field types into it.
    def add_item
      return pbPlayBuzzerSE if @query
      have = B.custom_list(@pocket)
      ids = pocket_items.reject { |id| have.include?(id.to_s) }
      return pbPlayBuzzerSE if ids.empty?
      pbPlayDecisionSE
      ids = ids.sort_by { |id| [quantity(id) > 0 ? 0 : 1, display_name(id).downcase] }
      @adding = { :all => ids, :list => ids, :query => nil, :sel => 0, :scroll => 0, :after => current }
      picked = adding_loop
      @adding = nil
      overlay.clear
      refresh
      return unless picked
      at = current ? current[2] + 1 : have.length
      have.insert(at, picked.to_s)
      save_list(have)
      @rows = nil
      @sel = rows.index { |x| x[2] == at } || @sel
      changed!
    end

    ADD_ROWS = 9
    ADD_ROW_H = 24

    def adding_loop
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        a = @adding
        pt = Reloaded::Pointer
        if pt.moved? && (k = pt.hit(@add_hits || [])) && k != a[:sel]
          a[:sel] = k
          refresh
        end
        if pt.left?
          if pt.inside?(*(@add_field || [0, 0, 0, 0]))
            add_search
          elsif (k = pt.hit(@add_hits || []))
            pbPlayDecisionSE
            return a[:list][k]
          end
        elsif pt.right? || Input.trigger?(Input::BACK)
          pbPlayCancelSE
          return nil unless a[:query]
          a[:query] = nil
          add_filter
        elsif (d = pt.wheel) != 0
          add_step(d, false)
        elsif Input.trigger?(Input::X) || Input.trigger?(Input::JUMPUP) || Input.trigger?(Input::SPECIAL)
          add_search
        elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
          add_step(Input.repeat?(Input::DOWN) ? 1 : -1, true)
        elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
          add_step((Input.repeat?(Input::RIGHT) ? 1 : -1) * ADD_ROWS, false)
        elsif Input.trigger?(Input::USE)
          id = a[:list][a[:sel]]
          unless id
            pbPlayBuzzerSE
            next
          end
          pbPlayDecisionSE
          return id
        end
      end
    end

    def add_step(dir, wrap)
      a = @adding
      n = a[:list].length
      return if n == 0
      to = a[:sel] + dir
      if to < 0 || to >= n
        to = wrap && fresh?(dir) ? (dir < 0 ? n - 1 : 0) : to.clamp(0, n - 1)
      end
      return if to == a[:sel]
      a[:sel] = to
      pbPlayCursorSE
      refresh
    end

    # Typed straight into the popup's field (a controller's A opens the
    # naming screen); the list follows as you type
    def add_search
      pbPlayDecisionSE
      a = @adding
      text, _how = Reloaded::TextEntry.run(self, _INTL("Type to Search"), a[:query] || "", 20, :prompt => _INTL("Search the Items"), :down => true) do |t|
        a[:query] = t.strip.empty? ? nil : t.strip
        add_filter
      end
      a[:query] = text.to_s.strip.empty? ? nil : text.strip
      add_filter
    end

    # A word starting with what's typed, as the Bag's Search
    def add_filter
      a = @adding
      q = a[:query].to_s.downcase
      a[:list] = q.empty? ? a[:all] : a[:all].select { |id| display_name(id).downcase.split(/[\s\-]+/).any? { |w| w.start_with?(q) } }
      a[:sel] = 0
      a[:scroll] = 0
      refresh
    end

    def pocket_items
      out = []
      ::GameData::Item.each { |it| out << it.id if it.pocket.to_i == @pocket && it.name.to_s !~ /unknown/i }
      return out.uniq
    rescue StandardError
      return []
    end

    # "5 items, 2 headings"
    def count_words(entries)
      heads = entries.count { |e| B.heading?(e) }
      items = entries.length - heads
      words = items == 1 ? _INTL("1 item") : _INTL("{1} items", items)
      words += heads == 1 ? _INTL(", 1 heading") : _INTL(", {1} headings", heads) if heads > 0
      return words
    end

    # R: old Kanto Reloaded's list for the pocket again, after asking what
    # changes (his pick, small popup design 2)
    def defaults
      pbPlayDecisionSE
      c = palette
      segs = [[count_words(B.custom_list(@pocket)), c[:txt], true], [_INTL(" become "), c[:dim]],
              [count_words(B.default_list(@pocket)), c[:txt], true]]
      ok = with_hints([[:lr, _INTL("Choose")], [button(:C), _INTL("OK")], [button(:B), _INTL("Keep Mine")]]) do
        Reloaded::Dialogs.ask(self, _INTL("Restore the Defaults?"),
                              _INTL("{1}'s list goes back to the one Kanto Reloaded starts with.", pocket_label), segs,
                              [_INTL("Restore"), _INTL("Keep Mine")], 1) == 0
      end
      if ok
        save_list(B.default_list(@pocket))
        @sel = 0
        @scroll = 0
      end
      changed!
      return nil
    end

    def with_hints(pairs)
      before = @popup_hints
      @popup_hints = pairs
      refresh
      return yield
    ensure
      @popup_hints = before
    end

    #--------------------------------------------------------------------------
    # Drawing
    #--------------------------------------------------------------------------
    def draw
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      @cursor_rect = nil
      PP.paint_background(base, c)
      draw_header(base, top, c)
      draw_pockets(base, top, c)
      draw_list(base, top, c)
      draw_details(base, top, c)
      paint_hints(base, c)
      place_cursor
      draw_adding(overlay, c) if @adding
    end

    # Add Item: the list to search, over the editor
    def draw_adding(b, c)
      a = @adding
      Reloaded::Dialogs.send(:dim, b)
      w = 330
      x = (W - w) / 2
      y = 14
      h = H - P::HINT_H - 22
      Reloaded::Dialogs.frame(b, c, x, y, w, h, _INTL("Add to {1}", pocket_label))
      fx = x + 12
      fy = y + 42
      @add_field = [fx, fy, fx + w - 24, fy + 23]
      if @entry
        Reloaded::TextEntry.draw_field(b, b, c, @entry, fx, fy, w - 24, 23, 26)
      else
        P.ui.rbox(b, fx, fy, fx + w - 24, fy + 23, 5, c[:dark], c[:line])
        P.text(b, fx + 26, fy, w - 60, 23, a[:query] || _INTL("Type to Search"), a[:query] ? c[:txt] : c[:dim])
      end
      # the magnifier (Frame's, at the field's height)
      P.ui.rbox(b, fx + 7, fy + 5, fx + 16, fy + 14, 4, c[:dim])
      P.ui.rbox(b, fx + 9, fy + 7, fx + 14, fy + 12, 2, c[:dark])
      3.times { |i| b.fill_rect(fx + 15 + i, fy + 13 + i, 2, 2, c[:dim]) }
      list = a[:list]
      @add_hits = []
      if list.empty?
        P.small(b, x, fy + 34, w, 16, _INTL("Nothing matches \"{1}\".", a[:query]), c[:dim], 2)
      else
        a[:scroll] = a[:sel] if a[:sel] < a[:scroll]
        a[:scroll] = a[:sel] - ADD_ROWS + 1 if a[:sel] >= a[:scroll] + ADD_ROWS
        list[a[:scroll], ADD_ROWS].each_with_index do |id, k|
          i = a[:scroll] + k
          ry = fy + 30 + k * ADD_ROW_H
          Reloaded::Dialogs.send(:cursor_row, b, c, x + 8, ry, x + w - 8, ry + ADD_ROW_H - 2) if i == a[:sel] && !@entry
          item_icon(b, id, x + 14, ry - 1, 24)
          have = quantity(id) > 0
          right = x + w - 18
          if have
            qt = "x#{quantity(id)}"
            qw = P.width(PF::TEXT, qt)
            P.text(b, right - qw, ry, qw, ADD_ROW_H - 2, qt, c[:dim], PF::TEXT)
            right -= qw + 8
          end
          col = have ? item_ink(c, id) : mix(c[:dim], c[:panel2], 0.25)
          P.text(b, x + 44, ry, right - x - 44, ADD_ROW_H - 2, PF.fit(PF::TEXT, display_name(id), right - x - 44), col, PF::TEXT)
          @add_hits << [i, x + 8, ry, x + w - 8, ry + ADD_ROW_H - 2]
        end
        P.ui.tri(b, x + w / 2 - 4, fy + 27, :u, c[:dim], 3) if a[:scroll] > 0
        P.ui.tri(b, x + w / 2 - 4, fy + 30 + ADD_ROWS * ADD_ROW_H, :d, c[:dim], 3) if a[:scroll] + ADD_ROWS < list.length
      end
      after = a[:after]
      where = if after.nil? then _INTL("It goes first on the list.")
              elsif after[0] == :heading then _INTL("It goes under the heading {1}.", after[1])
              else _INTL("It goes after {1}.", display_name(after[1]))
              end
      P.small(b, x, y + h - 22, w, 16, PF.fit(PF::TEXT, where, w - 20), c[:dim], 2)
    end

    def draw_header(base, top, c)
      if @entry && !@adding
        Reloaded::TextEntry.draw_field(base, top, c, @entry, 8, 4, W - 16, 23, 26)
        magnifier(base, 15, c[:txt], c[:dark])
        return
      end
      PP.paint_title(top, c, _INTL("Custom Lists"))
      [[SEARCH_BOX, @query || _INTL("Search"), :left], [DEFAULTS_BOX, _INTL("Defaults"), :right]].each do |(x0, y0, x1, y1), label, side|
        lit = @hover_box == side || (side == :left && @query)
        PP.chamfer_grad(base, x0, y0, x1, y1, 6, mix(c[:panel2], c[:selb], lit ? 0.4 : 0.15), c[:panel2], lit ? c[:selb] : c[:line])
        col = side == :left && !@query ? c[:dim] : c[:txt]
        P.text(top, x0, y0 + 1, x1 - x0, 20, PF.fit(PF::TEXT, label, x1 - x0 - 10), col, PF::TEXT, 2)
        key = side == :left ? left_key : right_key
        kw = Reloaded::ButtonIcons.width(key, Reloaded::Prompts.style, 18)
        Reloaded::ButtonIcons.draw(top, side == :left ? x1 + 4 : x0 - 4 - kw, 6, key, c, Reloaded::Prompts.style, 18)
      end
    end

    def draw_pockets(base, top, c)
      @pocket_hits = []
      B.pockets.each do |i|
        x = 10 + (i - 1) * 32
        if i == @pocket && @query.nil?
          PP.chamfer_grad(base, x - 3, BAR_Y - 1, x + 31, BAR_Y + 29, 6, mix(c[:panel2], c[:selb], 0.55),
                          mix(c[:panel2], c[:selb], 0.25), c[:selb])
        end
        pocket_icon(top, i, x, BAR_Y, 28, @query && i != @pocket)
        @pocket_hits << [i, x - 3, BAR_Y - 1, x + 31, BAR_Y + 29]
      end
      label = pocket_label
      lw = P.width(PF::TEXT, label)
      rx = W - 22
      P.ui.tri(top, rx + 4, BAR_Y + 9, :r, c[:dim], 5)
      P.text(top, rx - 4 - lw, BAR_Y + 2, lw, 24, label, c[:txt], PF::TEXT)
      P.ui.tri(top, rx - 18 - lw, BAR_Y + 9, :l, c[:dim], 5)
    end

    def row_height(r)
      return r[0] == :heading ? HEAD_H : ROW_H
    end

    def draw_list(base, top, c)
      PP.chamfer_grad(base, 6, LIST_Y0, W - 6, LIST_Y1, 10, c[:panel2], mix(c[:panel2], c[:dark], 0.3), c[:line])
      @row_hits = []
      list = rows
      if list.empty?
        msg = @query ? _INTL("Nothing on the list matches \"{1}\".", @query) : _INTL("Nothing on {1}'s list yet. Add Item puts one on it.", pocket_label)
        P.small(top, LIST_X, LIST_Y0 + 8, LIST_W, 16, msg, c[:dim])
        return
      end
      space = LIST_Y1 - LIST_Y0 - 4
      @scroll = [[@scroll.to_i, @sel].min, 0].max
      @scroll += 1 while @scroll < @sel && list[@scroll..@sel].sum { |r| row_height(r) } > space
      total = list.sum { |r| row_height(r) }
      y = LIST_Y0 + 2
      shown = 0
      moving_at = @moving ? @moving[1] : nil
      list[@scroll..-1].to_a.each_with_index do |r, k|
        h = row_height(r)
        break if y + h > LIST_Y0 + 2 + space
        shown += h
        i = @scroll + k
        @cursor_rect = [LIST_X - 4, y, LIST_W + 8, h - 1] if i == @sel && !@entry && moving_at.nil?
        moving = moving_at && r[2] == moving_at
        if moving
          PP.chamfer_outline(top, LIST_X - 5, y - 1, LIST_X + LIST_W + 5, y + h, 6, c[:gold])
        end
        if r[0] == :heading
          right = LIST_X + LIST_W
          right -= P.pill(top, right, y + (h - 15) / 2, _INTL("MOVING"), *PP.badge(c, [240, 200, 80]), true) + 8 if moving
          P.heading(top, LIST_X, right, y + 3, r[1], c[:head], c[:line])
        else
          item_row(top, c, LIST_X, y, LIST_W, r[1], moving)
        end
        @row_hits << [i, LIST_X, y, LIST_X + LIST_W, y + h - 1]
        y += h
      end
      return unless total > space
      track = space - 2
      bar = [track * space / total, 10].max
      above = list[0...@scroll].sum { |r| row_height(r) }
      pos = (track - bar) * above / [total - shown, 1].max
      base.fill_rect(LIST_X + LIST_W + 6, LIST_Y0 + 2, 2, track, c[:line])
      base.fill_rect(LIST_X + LIST_W + 6, LIST_Y0 + 2 + [pos, track - bar].min, 2, bar, c[:dim])
    end

    # In the Bag: the pocket's colour and how many; not: dim
    def item_row(top, c, x, y, w, id, moving = false)
      it = B.item_data(id)
      qty = quantity(id)
      PP.pixels(top, PP::STAR, x, y + (ROW_H - 7) / 2, c[:gold]) if B.favorite?(id)
      right = x + w
      if machine?(it)
        small_type(top, ::GameData::Move.get(it.move).type, right - 16, y + (ROW_H - 16) / 2)
        right -= 20
        lw = P.width(PF::TINY, it.name)
        P.text(top, right - lw, y + (ROW_H - 16) / 2 + 1, lw, 16, it.name, c[:dim], PF::TINY)
        right -= lw + 8
      else
        item_icon(top, id, right - 24, y, 24)
        right -= 30
      end
      if qty > 0 && !(it && it.respond_to?(:is_important?) && it.is_important?)
        qt = "x#{qty}"
        qw = P.width(PF::TEXT, qt)
        P.text(top, right - qw, y + 1, qw, ROW_H - 2, qt, c[:dim], PF::TEXT)
        right -= qw + 8
      end
      right -= P.pill(top, right, y + (ROW_H - 15) / 2, _INTL("MOVING"), *PP.badge(c, [240, 200, 80]), true) + 8 if moving
      nx = x + 11
      col = qty > 0 ? item_ink(c, id) : mix(c[:dim], c[:panel2], 0.25)
      P.text(top, nx, y + 1, right - nx, ROW_H - 2, PF.fit(PF::TEXT, display_name(id), right - nx), col, PF::TEXT)
    end

    def draw_details(base, top, c)
      r = current
      py0 = DETAILS_Y
      py1 = H - P::HINT_H - 5
      unless r
        PP.chamfer_grad(base, 6, py0, W - 6, py1, 12, c[:panel2], mix(c[:panel2], c[:dark], 0.4), c[:line])
        return
      end
      if r[0] == :heading
        plate(base, c, c[:selb], 6, py0, W - 6, py1, 12)
        P.text(top, 18, py0 + 5, 360, 22, PF.fit(PF::ROW, r[1], 360), c[:strong], PF::ROW)
        pill(top, c, 18, py0 + 32, _INTL("HEADING"), :blue)
        text = @moving ? moving_words : _INTL("A heading of your own: It marks a part of {1}'s list and sorts nothing.", pocket_label)
        P.small_wrap(top, text, 470).first(3).each_with_index { |ln, i| P.small(top, 18, py0 + 52 + i * 15, 470, 15, ln, c[:txt]) }
        return
      end
      id = r[1]
      plate(base, c, PP.rgb(item_rgb(id)), 6, py0, W - 6, py1, 12)
      have = quantity(id) > 0
      if @moving
        P.text(top, 18, py0 + 5, 360, 22, PF.fit(PF::ROW, _INTL("Moving {1}", display_name(id)), 360), c[:strong], PF::ROW)
        P.small_wrap(top, moving_words, 360).first(3).each_with_index { |ln, i| P.small(top, 18, py0 + 34 + i * 16, 360, 16, ln, c[:txt]) }
      else
        P.text(top, 18, py0 + 5, 360, 22, PF.fit(PF::ROW, display_name(id), 360), c[:strong], PF::ROW)
        pill(top, c, 18, py0 + 32, have ? _INTL("IN THE BAG") : _INTL("NOT IN THE BAG"), have ? :green : :dim)
        P.small_wrap(top, where_words(r), 360).first(3).each_with_index { |ln, i| P.small(top, 18, py0 + 52 + i * 15, 360, 15, ln, c[:txt]) }
      end
      P.ui.rbox(base, W - 92, py0 + 8, W - 18, py0 + 70, 6,
                c[:light] ? mix(c[:panel2], PP::WHITE, 0.5) : mix(c[:dark], c[:panel], 0.3), c[:line])
      item_icon(top, id, W - 79, py0 + 15, 48)
    end

    def moving_words
      return _INTL("Up and Down move it through {1}'s list. A puts it here; B puts it back where it was.", pocket_label)
    end

    # Where the pocket shows it: between the items around it on the list
    def where_words(r)
      items = list.each_with_index.reject { |e, _i| B.heading?(e) }
      k = items.index { |_e, i| i == r[2] }
      before = k && k > 0 ? display_name(items[k - 1][0]) : nil
      after = k && items[k + 1] ? display_name(items[k + 1][0]) : nil
      return _INTL("Whenever it's in the Bag, {1} shows it here: After {2}, before {3}.", pocket_label, before, after) if before && after
      return _INTL("Whenever it's in the Bag, {1} shows it first, before {2}.", pocket_label, after) if after
      return _INTL("Whenever it's in the Bag, {1} shows it after {2}, the last on the list.", pocket_label, before) if before
      return _INTL("It's the only item on {1}'s list.", pocket_label)
    end

    def hint_pairs
      return @popup_hints if @popup_hints
      back = button(:B)
      return [[button(:C), _INTL("Type")], [back, _INTL("Done")]] if @entry
      if @adding
        return [[:ud, _INTL("Choose")], [button(:C), _INTL("Add")], [button(:X), _INTL("Search")],
                [back, @adding[:query] ? _INTL("Clear") : _INTL("Back")]]
      end
      return [[:ud, _INTL("Move")], [button(:C), _INTL("Put Here")], [back, _INTL("Cancel")]] if @moving
      out = [[:ud, _INTL("Choose")]]
      out << [:lr, _INTL("Pockets")] if @query.nil?
      out << [button(:C), _INTL("Actions"), :hint_actions] if current
      out << [button(:A), _INTL("Move"), :hint_move] if current && @query.nil?
      out << [button(:X), _INTL("Add Item"), :hint_add] if @query.nil?
      out << [back, @query ? _INTL("Clear") : _INTL("Done"), :hint_back]
      return out
    end
  end
end
