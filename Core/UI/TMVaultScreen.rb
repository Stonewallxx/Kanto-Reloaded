# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the TM Vault's screen
#==============================================================================
# His picks (Roadmap Designs topic tm-vault, 2026-10-23), in the Party
# Screen's plate look:
#
#   the Vault    design 1, Plates: Search (type into it) and Sort in the
#                header; the Vault, Relearn and Checklist tabs; the Type
#                Filter's chips; the moves as slim plates lit in their type,
#                a star on Favorites, NEW on moves added since the last look;
#                the details panel lit in the move's type: the party (Knows
#                It, Can Learn, Can't; Left and Right pick who), the move,
#                Coverage for the one picked
#   Relearn      the picked Pokémon's moves to relearn (an Egg Move marked)
#   Checklist    design 4: each TM not had yet, with the kind of place the
#                game gives it (GROUND, STORE, GIFT), the Randomizer's note
#   Move Compare design 1, Side by Side: the new move, the four it can
#                replace (the one to forget ringed red), Coverage now and
#                after
#
# Buttons: Up / Down choose (Up from the top: the Type Filter), Left / Right
# the party, Confirm teaches, Action (X on a controller) the next tab, X (Y)
# Favorite, L Search, R Sort, Back closes (or clears the search). The mouse
# too: a click on a move teaches it, on a tab, chip or Pokémon picks it; the
# wheel scrolls.
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont) && defined?(Reloaded::PartyPaint)

module Reloaded
  class TMVaultScreen
    include Reloaded::Frame

    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    TV = Reloaded::TMVault
    TABS = [:vault, :relearn, :checklist].freeze
    LIST_X = 10
    LIST_W = 224
    ROW_H = 28
    PX0 = 244
    PY0 = 36
    PX1 = W - 6
    CATEGORY = "Graphics/Pictures/category"
    MAX_CHIPS = 11
    KIND_PILLS = { :ground => ["GROUND", :green], :store => ["STORE", :gold], :gift => ["GIFT", :blue] }.freeze
    CHECK_WORDS = { :knows => ["Knows It", :blue], :learn => ["Can Learn", :green], :cant => ["Can't", :dim] }.freeze
    SEARCH_BOX = [6, 4, 132, 26].freeze
    SORT_BOX = [W - 132, 4, W - 6, 26].freeze

    def self.open(tab = :vault, pkmn = nil)
      screen = new(tab, pkmn)
      defined?(pbFadeOutIn) ? pbFadeOutIn { screen.main } : screen.main
      return screen
    end

    attr_reader :entry, :sel, :member, :type_filter, :query

    def initialize(tab = :vault, pkmn = nil)
      frame_init
      @tab = TABS.index(tab) || 0
      @party = ($Trainer && $Trainer.party ? $Trainer.party : []).compact
      @member = pkmn && @party.index(pkmn) ? @party.index(pkmn) : 0
      @sel = 0
      @scroll = 0
      @type_filter = nil
      @chips = false
      @query = nil
      @mode = :list
      @pictures = {}
      @icons = []
      @rows = nil
    end

    def main
      open_sprites
      make_icons
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        @icons.each { |s| s.update if s.respond_to?(:update) && !s.disposed? }
        break if handle_input == :close
      end
      TV.seen!
      return nil
    ensure
      dispose_icons
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

    def tab
      return TABS[@tab]
    end

    # What the list shows now: move ids (the Checklist: [item, move, kind])
    def rows
      @rows ||= build_rows
    end

    def current
      r = rows[@sel]
      return tab == :checklist && r ? r[1] : r
    end

    private

    def changed!
      @rows = nil
      @sel = [[@sel, rows.length - 1].min, 0].max
      refresh
    end

    def pkmn
      return @party[@member]
    end

    def md(move)
      return ::GameData::Move.get(move)
    end

    def build_rows
      if tab == :checklist
        return TV.checklist.select { |_it, mv, _k| match?(mv) }
      end
      list = tab == :vault ? TV.moves : TV.relearnable(pkmn)
      list = list.select { |m| match?(m) && (@type_filter.nil? || md(m).type == @type_filter) }
      return sorted(list)
    end

    def match?(move)
      return true if @query.nil? || @query.empty?
      return md(move).name.downcase.include?(@query.downcase)
    rescue StandardError
      return false
    end

    def type_order(t)
      return (::GameData::Type.get(t).icon_position rescue 99)
    end

    # Favorites first (the Vault), then by the sort
    def sorted(list)
      p = pkmn
      keyed = list.map do |m|
        d = md(m)
        key = case TV::SORTS[TV.sort]
              when "Type" then [type_order(d.type), d.name]
              when "Category" then [d.category.to_i, d.name]
              when "Recent" then [-TV.added_at(m), d.name]
              when "Level Learned" then [TV.level_learned(p, m) || 999, d.name]
              else [d.name]
              end
        fav = tab == :vault && TV.favorite?(m) ? 0 : 1
        [[fav] + key, m]
      end
      return keyed.sort_by(&:first).map(&:last)
    end

    # The types the list has (for the chips), in the game's order
    def types_present
      list = tab == :vault ? TV.moves : TV.relearnable(pkmn)
      return list.select { |m| match?(m) }.map { |m| md(m).type }.uniq.sort_by { |t| type_order(t) }
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      return search if Input.trigger?(Input::JUMPUP) || Input.trigger?(Input::SPECIAL) || clicked?(*SEARCH_BOX)
      return cycle_sort if Input.trigger?(Input::JUMPDOWN) || clicked?(*SORT_BOX)
      handled, result = mouse_input
      return result if handled
      if Input.trigger?(Input::BACK)
        return hint_back
      elsif Input.trigger?(Input::ACTION)
        next_tab
      elsif @chips
        chips_input
      else
        list_input
      end
      return nil
    end

    def list_input
      n = rows.length
      if Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        if dir < 0 && @sel == 0 && fresh?(dir) && tab != :checklist
          @chips = true
          pbPlayCursorSE
          return refresh
        end
        return if n == 0
        target = @sel + dir
        if target < 0 || target >= n
          return unless fresh?(dir)
          target = dir < 0 ? n - 1 : 0
        end
        @sel = target
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
        step_member(Input.trigger?(Input::RIGHT) ? 1 : -1)
      elsif Input.trigger?(Input::USE)
        teach
      elsif Input.trigger?(Input::X)
        favorite
      end
    end

    def chips_input
      if Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
        list = [nil] + types_present
        i = (list.index(@type_filter) || 0) + (Input.trigger?(Input::RIGHT) ? 1 : -1)
        @type_filter = list[i % list.length]
        @sel = 0
        @scroll = 0
        pbPlayCursorSE
        changed!
      elsif Input.trigger?(Input::DOWN) || Input.trigger?(Input::USE)
        @chips = false
        pbPlayCursorSE
        refresh
      end
    end

    # The mouse: pointing at a row, tab, chip or Pokémon picks it; a click
    # on a row teaches it; the wheel scrolls; a right click goes back
    def mouse_input
      pt = Reloaded::Pointer
      if pointer_hover && !@entry && (k = pt.hit(@row_hits || [])) && (k != @sel || @chips)
        @sel = k
        @chips = false
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
      if (i = pt.hit(@tab_hits || []))
        set_tab(i)
      elsif (t = pt.hit(@chip_hits || []))
        @type_filter = t == :all ? nil : t
        @sel = 0
        changed!
      elsif (m = pt.hit(@party_hits || []))
        @member = m
        pbPlayCursorSE
        changed!
      elsif (k = pt.hit(@row_hits || []))
        @sel = k
        teach
      end
      return [true, nil]
    end

    def step_member(dir)
      return pbPlayBuzzerSE if @party.length < 2
      @member = (@member + dir) % @party.length
      pbPlayCursorSE
      changed!
    end

    def next_tab
      set_tab((@tab + 1) % TABS.length)
    end

    def set_tab(i)
      return if i == @tab
      @tab = i
      @sel = 0
      @scroll = 0
      @type_filter = nil
      @chips = false
      pbPlayCursorSE
      changed!
    end

    # The Checklist stays in the game's order (its numbers)
    def cycle_sort
      return pbPlayBuzzerSE if tab == :checklist
      TV.sort = TV.sort + 1
      pbPlayCursorSE
      changed!
      return nil
    end

    def favorite
      m = current
      return pbPlayBuzzerSE unless m && tab == :vault
      TV.toggle_favorite(m)
      pbPlayDecisionSE
      @rows = nil
      @sel = rows.index(m) || 0
      refresh
    end

    def search
      pbPlayDecisionSE
      text, _how = Reloaded::TextEntry.run(self, _INTL("Type to Search"), @query || "", 20,
                                           :prompt => _INTL("Search the TM Vault"), :down => true) do |t|
        @query = t.strip.empty? ? nil : t.strip
        @sel = 0
        changed!
      end
      @query = text.to_s.strip.empty? ? nil : text.strip
      @sel = 0
      changed!
      return nil
    end

    # Back: the search cleared, else the Type Filter's chips left, else close
    def hint_back
      if @query
        pbPlayCancelSE
        @query = nil
        changed!
        return nil
      end
      if @chips
        @chips = false
        pbPlayCancelSE
        refresh
        return nil
      end
      pbPlayCloseMenuSE
      return :close
    end

    def hint_teach
      teach
      return nil
    end

    def hint_tabs
      next_tab
      return nil
    end

    def hint_favorite
      favorite
      return nil
    end

    #--------------------------------------------------------------------------
    # Teaching
    #--------------------------------------------------------------------------
    def teach
      m = current
      p = pkmn
      return pbPlayBuzzerSE unless m && p && tab != :checklist
      name = md(m).name
      if p.egg?
        return Reloaded::Dialogs.notice(self, name, _INTL("Eggs can't be taught any moves."))
      end
      if tab == :vault
        case TV.compat(m, p)
        when :knows then return Reloaded::Dialogs.notice(self, name, _INTL("{1} already knows {2}.", p.name, name))
        when :cant then return Reloaded::Dialogs.notice(self, name, _INTL("{1} can't learn {2}.", p.name, name))
        end
      end
      if p.moves.length < ::Pokemon::MAX_MOVES
        return unless Reloaded::Dialogs.confirm(self, name, _INTL("Teach {1} to {2}?", name, p.name), _INTL("Teach"), _INTL("Cancel"))
        TV.teach(p, m)
        learned(p, name)
      else
        forget = compare(p, m)
        return if forget.nil?
        old = md(p.moves[forget].id).name
        TV.teach(p, m, forget)
        learned(p, name, old)
      end
      changed!
    end

    def learned(p, name, old = nil)
      pbMEPlay("Pkmn move learnt") rescue nil
      text = old ? _INTL("{1} forgot {2} and learned {3}.", p.name, old, name) : _INTL("{1} learned {2}.", p.name, name)
      Reloaded::Dialogs.notice(self, name, text)
    end

    # Move Compare: the move to forget (its index), or nil
    def compare(p, m)
      @mode = :compare
      @cmp = [p, m, 0]
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        pt = Reloaded::Pointer
        if pointer_hover && (k = pt.hit(@cmp_hits || [])) && k != @cmp[2]
          @cmp[2] = k
          refresh
        end
        if pt.left? && (k = pt.hit(@cmp_hits || []))
          pbPlayDecisionSE
          return k
        elsif pt.left?
          handled, result = hint_click
          return result if handled && result != :none
        end
        if pt.right? || Input.trigger?(Input::BACK)
          pbPlayCancelSE
          return nil
        elsif Input.trigger?(Input::USE)
          pbPlayDecisionSE
          return @cmp[2]
        elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
          @cmp[2] = (@cmp[2] + (Input.repeat?(Input::DOWN) ? 1 : -1)) % p.moves.length
          pbPlayCursorSE
          refresh
        end
      end
    ensure
      @mode = :list
      @cmp = nil
      refresh
    end

    def hint_forget
      return @cmp ? @cmp[2] : :none
    end

    def hint_cancel
      return nil
    end

    #--------------------------------------------------------------------------
    # Drawing
    #--------------------------------------------------------------------------
    def picture(path)
      return @pictures[path] if @pictures.key?(path)
      resolved = defined?(pbResolveBitmap) ? (pbResolveBitmap(path) || path) : path
      @pictures[path] = (Bitmap.new(resolved) rescue nil)
      return @pictures[path]
    end

    def draw
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      @cursor_rect = nil
      PP.paint_background(base, c)
      if @mode == :compare
        @icons.each { |s| s.visible = false }
        draw_compare(base, top, c)
      else
        draw_header(base, top, c)
        draw_tabs(base, top, c)
        draw_list(base, top, c)
        draw_panel(base, top, c)
      end
      paint_hints(base, c)
      place_cursor
    end

    def draw_header(base, top, c)
      if @entry
        Reloaded::TextEntry.draw_field(base, top, c, @entry, 8, 4, W - 16, 23, 26)
        magnifier(base, 15, c[:txt], c[:dark])
        return
      end
      PP.paint_title(top, c, _INTL("TM Vault"))
      x0, y0, x1, y1 = SEARCH_BOX
      lit = @query || @hover_box == :left
      PP.chamfer_grad(base, x0, y0, x1, y1, 6, mix(c[:panel2], c[:selb], lit ? 0.4 : 0.15), c[:panel2], lit ? c[:selb] : c[:line])
      P.text(top, x0 + 8, y0 + 1, x1 - x0 - 12, 20, PF.fit(PF::TEXT, @query || _INTL("Search"), x1 - x0 - 12), @query ? c[:txt] : c[:dim], PF::TEXT)
      Reloaded::ButtonIcons.draw(top, x1 + 4, 6, left_key, c, Reloaded::Prompts.style, 18)
      x0, y0, x1, y1 = SORT_BOX
      lit = @hover_box == :right
      PP.chamfer_grad(base, x0, y0, x1, y1, 6, mix(c[:panel2], c[:selb], lit ? 0.4 : 0.15), c[:panel2], lit ? c[:selb] : c[:line])
      sort = tab == :checklist ? _INTL("Number") : _INTL(TV::SORTS[TV.sort])
      P.text(top, x0, y0 + 1, x1 - x0, 20, _INTL("Sort: {1}", sort), c[:txt], PF::TEXT, 2)
      key = right_key
      Reloaded::ButtonIcons.draw(top, x0 - 4 - Reloaded::ButtonIcons.width(key, Reloaded::Prompts.style, 18), 6, key, c, Reloaded::Prompts.style, 18)
    end

    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    # The header's plates, for the mouse (Frame lights the one under it)
    def left_box
      return SEARCH_BOX
    end

    def right_box
      return SORT_BOX
    end

    def draw_tabs(base, top, c)
      labels = [_INTL("VAULT {1}", TV.moves.length), _INTL("RELEARN"), _INTL("CHECKLIST {1}", TV.checklist.length)]
      tw = (LIST_W + 4 - 8) / 3
      @tab_hits = []
      labels.each_with_index do |l, i|
        tx = 8 + i * (tw + 4)
        on = i == @tab
        PP.chamfer_grad(base, tx, 36, tx + tw, 56, 6, on ? mix(c[:panel2], c[:selb], 0.55) : c[:panel2],
                        on ? mix(c[:panel2], c[:selb], 0.3) : mix(c[:panel2], c[:dark], 0.4), on ? c[:selb] : c[:line])
        P.text(top, tx, 39, tw, 14, l, on ? c[:strong] : c[:dim], PF::TINY, 2)
        @tab_hits << [i, tx, 36, tx + tw, 56]
      end
    end

    def small_type(b, type, x, y)
      sheet = picture(PP::TYPES_SMALL)
      b.blt(x, y, sheet, Rect.new(0, type_order(type) * 16, 16, 16)) if sheet
    end

    def big_type(b, type, x, y)
      sheet = picture(PP::TYPES_BIG)
      b.stretch_blt(Rect.new(x, y, 38, 17), sheet, Rect.new(0, type_order(type) * 28, 64, 28)) if sheet
      return 38
    end

    def big_category(b, cat, x, y)
      sheet = picture(CATEGORY)
      b.stretch_blt(Rect.new(x, y, 38, 17), sheet, Rect.new(0, cat.to_i * 28, 64, 28)) if sheet
      return 38
    end

    def disc(b, move, x, y, size = 22)
      bm = picture(TV.disc_icon(move))
      b.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, bm.width, bm.height)) if bm
    end

    def pill(b, c, x, y, label, tone_key, right = false)
      tone = c[tone_key] || c[:dim]
      fill = c[:light] ? mix(c[:panel2], tone, 0.22) : mix(c[:panel2], tone, 0.28)
      return P.pill(b, x, y, label, fill, tone, right)
    end

    def star(b, x, y, col)
      PP.pixels(b, PP::STAR, x, y, col)
    end

    def gold(c)
      return c[:gold]
    end

    # The Type Filter: ALL, then each type the list has (the picked one
    # underlined; the chips lit while Up moved there)
    def draw_chips(base, top, c, y)
      x = 8
      on_all = @type_filter.nil?
      PP.chamfer_grad(base, x, y, x + 30, y + 18, 5, on_all ? mix(c[:panel2], c[:selb], 0.5) : c[:panel2], c[:panel2],
                      @chips && on_all ? c[:strong] : (on_all ? c[:selb] : c[:line]))
      P.text(top, x, y + 2, 30, 14, _INTL("ALL"), on_all ? c[:strong] : c[:dim], PF::TINY, 2)
      @chip_hits = [[:all, x, y, x + 30, y + 18]]
      types = types_present
      i0 = [(types.index(@type_filter) || 0) - MAX_CHIPS + 1, 0].max
      types[i0, MAX_CHIPS].to_a.each_with_index do |t, i|
        ix = x + 36 + i * 17
        small_type(top, t, ix, y + 1)
        if t == @type_filter
          base.fill_rect(ix - 1, y - 1, 18, 1, @chips ? c[:strong] : c[:selb]) if @chips
          top.fill_rect(ix, y + 18, 16, 2, @chips ? c[:strong] : c[:selb])
        end
        @chip_hits << [t, ix, y, ix + 16, y + 18]
      end
    end

    def draw_list(base, top, c)
      list = rows
      y0 = tab == :checklist ? 62 : 84
      draw_chips(base, top, c, 60) if tab != :checklist
      @row_hits = []
      if list.empty?
        msg = if @query then _INTL("Nothing matches \"{1}\".", @query)
              elsif tab == :vault then _INTL("Nothing here yet. Every TM you find, and every move a tutor teaches, comes here.")
              elsif tab == :relearn then pkmn ? _INTL("{1} has no moves to relearn.", pkmn.name) : _INTL("No Pokémon.")
              else _INTL("You've had every TM and HM.")
              end
        P.small_wrap(top, msg, LIST_W - 8).first(4).each_with_index { |ln, i| P.small(top, LIST_X + 4, y0 + 4 + i * 16, LIST_W - 8, 16, ln, c[:dim]) }
        return
      end
      visible = (H - P::HINT_H - 6 - y0) / ROW_H
      @scroll = @sel if @sel < @scroll
      @scroll = @sel - visible + 1 if @sel >= @scroll + visible
      @scroll = [[@scroll, list.length - visible].min, 0].max
      list[@scroll, visible].each_with_index do |r, k|
        i = @scroll + k
        y = y0 + k * ROW_H
        sel = i == @sel && !@chips
        tab == :checklist ? checklist_row(base, top, c, LIST_X, y, r, sel) : move_row(base, top, c, LIST_X, y, r, sel)
        @row_hits << [i, LIST_X, y, LIST_X + LIST_W, y + ROW_H - 4]
      end
      if list.length > visible
        track = visible * ROW_H - 6
        bar = [track * visible / list.length, 10].max
        pos = (track - bar) * @scroll / [list.length - visible, 1].max
        base.fill_rect(LIST_X + LIST_W + 3, y0, 2, track, c[:line])
        base.fill_rect(LIST_X + LIST_W + 3, y0 + pos, 2, bar, c[:dim])
      end
    end

    def row_plate(base, c, x, y, col, sel, h = 24)
      PP.chamfer(base, x - 2, y - 2, x + LIST_W + 2, y + h + 2, 8, mix(c[:bg], c[:selb], 0.35), mix(c[:bg], c[:selb], 0.35)) if sel
      PP.chamfer_grad(base, x, y, x + LIST_W, y + h, 6, mix(c[:panel2], col, sel ? 0.5 : 0.28), mix(c[:panel2], c[:dark], 0.45),
                      sel ? c[:selb] : mix(c[:line], col, 0.4))
    end

    def move_row(base, top, c, x, y, m, sel)
      d = md(m)
      col = PP.rgb(Reloaded::PartyScreen.type_rgb(d.type))
      row_plate(base, c, x, y, col, sel)
      base.fill_rect(x + 3, y + 3, 3, 18, col)
      if tab == :vault
        star(top, x + 10, y + 8, TV.favorite?(m) ? gold(c) : mix(c[:panel2], c[:line], 0.6))
      end
      nx = x + 22
      label = tab == :vault ? TV.label(m) : level_label(m)
      room = LIST_W - 22 - 70
      nw = P.text(top, nx, y + 2, room, 20, PF.fit(PF::TEXT, d.name, room), sel ? c[:strong] : c[:txt], PF::TEXT)
      pill(top, c, nx + nw + 6, y + 4, _INTL("NEW"), :green) if tab == :vault && TV.new?(m) && nx + nw + 40 < x + LIST_W - 66
      P.text(top, x + LIST_W - 66, y + 4, 40, 16, label, c[:dim], PF::TINY, 1)
      small_type(top, d.type, x + LIST_W - 22, y + 4)
    end

    # Relearn: the level it's learned at, else EGG for an Egg Move
    def level_label(m)
      lv = TV.level_learned(pkmn, m)
      return _INTL("LV {1}", lv) if lv && lv > 0
      return TV.egg_move?(pkmn, m) ? _INTL("EGG") : ""
    end

    def checklist_row(base, top, c, x, y, r, sel)
      item, m, kind = r
      d = md(m)
      col = PP.rgb(Reloaded::PartyScreen.type_rgb(d.type))
      row_plate(base, c, x, y, col, sel)
      disc(top, m, x + 4, y + 1)
      pill_label, tone = KIND_PILLS[kind]
      room = LIST_W - 30 - 26 - (pill_label ? P.width(PF::TINY, pill_label) + 18 : 0)
      P.text(top, x + 30, y + 2, room, 20, PF.fit(PF::TEXT, d.name, room), sel ? c[:strong] : c[:txt], PF::TEXT)
      pill(top, c, x + LIST_W - 26, y + 5, _INTL(pill_label), tone, true) if pill_label
      small_type(top, d.type, x + LIST_W - 22, y + 4)
    end

    # The details panel, lit in the move's type with the Party Screen's
    # bands (his look)
    def panel_plate(base, c, col, line_y)
      x0 = PX0; y0 = PY0; x1 = PX1; y1 = H - P::HINT_H - 6
      cut = 16
      top = mix(c[:panel], col, 0.4)
      bottom = mix(c[:panel], c[:dark], 0.4)
      PP.chamfer_grad(base, x0, y0, x1, y1, cut, top, bottom, mix(c[:line], col, 0.5))
      from = x1 - 48
      to = x0 + 24
      (y0 + 1...y1 - 1).each do |y|
        t = (y - y0).to_f / (y1 - y0)
        left = x0 + 1 + [cut - (y - y0), 0].max
        right = x1 - 1 - [cut - (y1 - 1 - y), 0].max
        mid = from + (to - from) * t
        k = y < line_y ? 0.4 : 0.22 - 0.18 * (y - line_y).to_f / (y1 - line_y)
        tint = mix(mix(top, bottom, t), col, k)
        [[0, 56], [40, 8]].each do |off, bw|
          a = [(mid + off - bw / 2.0).round, left].max
          b = [(mid + off + bw / 2.0).round, right].min
          base.fill_rect(a, y, b - a, 1, tint) if b > a
        end
      end
      base.fill_rect(x0 + 8, line_y, x1 - x0 - 16, 2, PP::POKE_RED)
    end

    def draw_panel(base, top, c)
      m = current
      col = m ? PP.rgb(Reloaded::PartyScreen.type_rgb(md(m).type)) : c[:line]
      if tab == :checklist
        @icons.each { |s| s.visible = false }
        panel_plate(base, c, col, PY0 + 34)
        return unless m
        P.text(top, PX0 + 14, PY0 + 8, 200, 20, rows[@sel][0].id.to_s, c[:dim], PF::TEXT)
        move_info(top, c, PX0 + 14, PY0 + 44, PX1 - PX0 - 28, m)
        if TV.randomized?
          P.small_wrap(top, _INTL("Randomizer On: It may be somewhere else."), PX1 - PX0 - 28).first(2).each_with_index do |ln, i|
            P.small(top, PX0 + 14, H - P::HINT_H - 44 + i * 14, PX1 - PX0 - 28, 14, ln, c[:dim])
          end
        end
        return
      end
      panel_plate(base, c, col, PY0 + 66)
      party_strip(base, top, c, m)
      return unless m
      move_info(top, c, PX0 + 14, PY0 + 74, PX1 - PX0 - 28, m)
      coverage_lines(top, c, PX0 + 14, PY0 + 214, PX1 - PX0 - 28, m)
    end

    # The party across the panel's top: each one's icon, and what it can do
    # with the move (Relearn: how many it has); the picked one lit
    def party_strip(base, top, c, m)
      @party_hits = []
      n = @party.length
      return if n == 0
      step = (PX1 - PX0 - 16) / n
      words = @party.map { |p| strip_word(p, m) }
      two = words.any? { |w, _t| P.width(PF::TINY, w) > step - 4 && w.include?(" ") }
      @party.each_with_index do |p, i|
        cx = PX0 + 8 + i * step + step / 2
        if i == @member
          PP.chamfer_grad(base, cx - step / 2 + 2, PY0 + 4, cx + step / 2 - 2, PY0 + 60, 6, mix(c[:panel2], c[:selb], 0.4),
                          mix(c[:panel2], c[:selb], 0.15), c[:selb])
        end
        fit_icon(i, cx, two ? PY0 + 19 : PY0 + 24, two ? 28 : 34)
        word, tone = words[i]
        col = c[tone] || c[:dim]
        lines = two && P.width(PF::TINY, word) > step - 4 ? word.split(" ", 2) : [word]
        lines.each_with_index do |ln, k|
          ly = two ? PY0 + 36 + k * 11 : PY0 + 46
          ly += 5 if two && lines.length == 1
          P.text(top, cx - step / 2, ly, step, 12, ln, col, PF::TINY, 2)
        end
        @party_hits << [i, cx - step / 2, PY0 + 4, cx + step / 2, PY0 + 60]
      end
    end

    # What each one in the party can do with the move (Relearn: how many
    # it has to relearn): [words, tone]
    def strip_word(p, m)
      return [_INTL("Egg"), :dim] if p.egg?
      if tab == :relearn
        k = TV.relearnable(p).length
        return [k == 1 ? _INTL("1 Move") : _INTL("{1} Moves", k), k > 0 ? :green : :dim]
      end
      return ["", :dim] unless m
      word, tone = CHECK_WORDS[TV.compat(m, p)]
      return [_INTL(word), tone]
    end

    # The move: its name, type, category and numbers (onto a second row
    # when they don't fit), its description (the last line ending in ...
    # when there's more)
    def move_info(top, c, x, y, w, m, lines = 4)
      d = md(m)
      P.text(top, x, y, w, 22, PF.fit(PF::ROW, d.name, w), c[:strong], PF::ROW)
      bx = x
      by = y + 27
      bx += big_type(top, d.type, bx, y + 26) + 4
      bx += big_category(top, d.category, bx, y + 26) + 6
      [_INTL("POW {1}", d.base_damage.to_i > 1 ? d.base_damage : "--"),
       _INTL("ACC {1}", d.accuracy.to_i > 0 ? d.accuracy : "--"),
       _INTL("PP {1}", d.total_pp)].each do |label|
        pw = P.width(PF::TINY, label) + 12
        if bx + pw > x + w
          bx = x
          by += 20
        end
        P.pill(top, bx, by, label, c[:pill], c[:txt], false)
        bx += pw + 6
      end
      dy = by - (y + 27)
      desc_lines(top, d.description.to_s, w, lines - dy / 20).each_with_index { |ln, i| P.small(top, x, y + 48 + dy + i * 16, w, 16, ln, c[:txt]) }
    end

    def desc_lines(b, text, w, n)
      lines = P.small_wrap(b, text, w)
      return lines if lines.length <= n
      out = lines.first(n)
      last = out[-1]
      P.small_font(b)
      last = last.sub(/\s*\S+\z/, "") while !last.empty? && b.text_size(last + "...").width > w
      out[-1] = last + "..."
      return out
    end

    def type_row(top, types, x, y, room)
      types.each_with_index do |t, i|
        break if (i + 1) * 18 > room
        small_type(top, t, x + i * 18, y)
      end
      return [types.length * 18, room].min
    end

    def type_names(types)
      names = types.map { |t| (::GameData::Type.get(t).name rescue t.to_s) }
      return names.length < 2 ? names[0].to_s : _INTL("{1} and {2}", names[0..-2].join(", "), names[-1])
    end

    # Coverage for the one picked: the types its moves hit hard now, and
    # what this move adds
    def coverage_lines(top, c, x, y, w, m)
      p = pkmn
      return unless p && !p.egg?
      P.heading(top, x, x + w, y, _INTL("Coverage ({1})", p.name), c[:dim], c[:line])
      now, after = TV.coverage(p, m)
      learns = !p.hasMove?(m) && (tab == :relearn || TV.compat(m, p) == :learn)
      added = learns ? after - now : []
      used = type_row(top, now, x, y + 16, w)
      unless added.empty?
        P.text(top, x + used + 2, y + 15, 12, 16, "+", c[:green], PF::TEXT)
        type_row(top, added, x + used + 14, y + 16, w - used - 14)
      end
      words = if p.hasMove?(m) then _INTL("{1} knows it already.", p.name)
              elsif !learns then _INTL("{1} can't learn it.", p.name)
              elsif added.empty? then _INTL("{1} adds nothing new.", md(m).name)
              else _INTL("{1} adds {2}.", md(m).name, type_names(added))
              end
      P.small_wrap(top, words, w).first(2).each_with_index { |ln, i| P.small(top, x, y + 34 + i * 14, w, 14, ln, added.empty? ? c[:dim] : c[:green]) }
    end

    # Move Compare (design 1, Side by Side)
    def draw_compare(base, top, c)
      p, m, sel = @cmp
      d = md(m)
      PP.paint_title(top, c, _INTL("Teach {1} to {2}?", d.name, p.name))
      col = PP.rgb(Reloaded::PartyScreen.type_rgb(d.type))
      x0 = 8; y0 = 36; x1 = 250; y1 = 262
      cut = 16
      topc = mix(c[:panel], col, 0.4)
      PP.chamfer_grad(base, x0, y0, x1, y1, cut, topc, mix(c[:panel], c[:dark], 0.4), mix(c[:line], col, 0.5))
      base.fill_rect(x0 + 8, y0 + 34, x1 - x0 - 16, 2, PP::POKE_RED)
      P.text(top, x0 + 14, y0 + 8, 200, 14, _INTL("NEW MOVE"), c[:head], PF::TINY)
      move_info(top, c, x0 + 14, y0 + 42, x1 - x0 - 28, m, 6)
      @cmp_hits = []
      p.moves.each_with_index do |mv, i|
        old_plate(base, top, c, 258, 36 + i * 57, W - 6 - 258, 51, mv.id, i == sel)
        @cmp_hits << [i, 258, 36 + i * 57, W - 6, 36 + i * 57 + 51]
      end
      PP.chamfer_grad(base, 8, 268, W - 6, H - P::HINT_H - 6, 10, c[:panel2], mix(c[:panel2], c[:dark], 0.4), c[:line])
      now, after = TV.coverage(p, m, sel)
      P.heading(top, 20, W - 20, 274, _INTL("Coverage"), c[:dim], c[:line])
      [[_INTL("Now"), now], [_INTL("After"), after]].each_with_index do |(label, list), r|
        P.text(top, 20, 290 + r * 20, 50, 16, label, c[:dim], PF::TEXT)
        type_row(top, list, 72, 290 + r * 20, W - 100)
      end
      added = after - now
      lost = now - after
      old = md(p.moves[sel].id).name
      words = added.empty? ? _INTL("{1} adds nothing new.", d.name) : _INTL("{1} adds {2}.", d.name, type_names(added))
      words += " " + (lost.empty? ? _INTL("Forgetting {1} loses none.", old) : _INTL("Forgetting {1} loses {2}.", old, type_names(lost)))
      P.small(top, 20, 332, W - 40, 14, PF.fit(PF::TINY, words, W - 40), lost.empty? ? c[:green] : c[:amber])
    end

    def old_plate(base, top, c, x, y, w, h, move, forget)
      d = md(move)
      col = PP.rgb(Reloaded::PartyScreen.type_rgb(d.type))
      PP.chamfer(base, x - 2, y - 2, x + w + 2, y + h + 2, 9, mix(c[:bg], c[:red], 0.4), mix(c[:bg], c[:red], 0.4)) if forget
      PP.chamfer_grad(base, x, y, x + w, y + h, 8, mix(c[:panel2], col, forget ? 0.45 : 0.28), mix(c[:panel2], c[:dark], 0.45),
                      forget ? c[:red] : mix(c[:line], col, 0.4))
      P.text(top, x + 10, y + 3, w - 80, 20, d.name, forget ? c[:strong] : c[:txt], PF::TEXT)
      pill(top, c, x + w - 8, y + 5, _INTL("FORGET"), :red, true) if forget
      small_type(top, d.type, x + 10, y + h - 20)
      big_category(top, d.category, x + 30, y + h - 21)
      stats = _INTL("POW {1} ACC {2} PP {3}", d.base_damage.to_i > 1 ? d.base_damage : "--", d.accuracy.to_i > 0 ? d.accuracy : "--", d.total_pp)
      P.small(top, x + 72, y + h - 21, w - 80, 16, stats, c[:dim])
    end

    def hint_pairs
      back = button(:B)
      if @entry
        return [[button(:C), _INTL("Type")], [back, _INTL("Done")]]
      end
      if @mode == :compare
        return [[:ud, _INTL("Choose")], [button(:C), _INTL("Forget This"), :hint_forget], [back, _INTL("Cancel"), :hint_cancel]]
      end
      close = @query ? _INTL("Clear") : _INTL("Close")
      if @chips
        return [[:lr, _INTL("Type")], [:d, _INTL("List")], [back, _INTL("Back"), :hint_back]]
      end
      out = [[:ud, _INTL("Choose")]]
      if tab == :checklist
        return out + [[button(:A), _INTL("Tabs"), :hint_tabs], [back, close, :hint_back]]
      end
      out << [:lr, _INTL("Party")]
      out << [button(:X), _INTL("Favorite"), :hint_favorite] if tab == :vault
      out << [button(:A), _INTL("Tabs"), :hint_tabs]
      out << [button(:C), _INTL("Teach"), :hint_teach]
      out << [back, close, :hint_back]
      return out
    end

    #--------------------------------------------------------------------------
    # The party's icons (Big Pokémon Icons as the player has them)
    #--------------------------------------------------------------------------
    def make_icons
      @icons = @party.map { |p| Reloaded::PartyIcons.icon(p, @viewport, 3) }
      @icon_rects = @icons.map { |s| s && s.bitmap ? Reloaded::PartyIcons.art_rect(s.bitmap, [s.src_rect.height, 1].max) : nil }
      @icons.each { |s| s.visible = false if s }
    end

    # The art (its pixels, not the frame) box wide, its middle on cx, cy
    def fit_icon(i, cx, cy, box)
      s = @icons[i]
      r = (@icon_rects || [])[i]
      return unless s && r && !s.disposed?
      s.zoom_x = s.zoom_y = box.to_f / [r.width, r.height, 1].max
      s.ox = r.x + r.width / 2
      s.oy = r.y + r.height / 2
      s.x = cx
      s.y = cy
      s.visible = true
    end

    def dispose_icons
      (@icons || []).each { |s| s.dispose if s && !s.disposed? }
      @icons = []
      @icon_rects = []
    end

    def sprites
      return super + (@icons || []).compact.reject(&:disposed?)
    end
  end
end
