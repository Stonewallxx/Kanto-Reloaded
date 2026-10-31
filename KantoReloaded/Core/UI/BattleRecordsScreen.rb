# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Battle Records screen (Trainer Control)
#==============================================================================
# His picks (Roadmap Designs topic trainer-control, 2026-10-31): Design 1,
# List and Record Plate, with the plate's Variant 1, MVPs and Bond Rewards,
# in the TM Vault's look:
#
#   the header   Search (type into it) on L, the title, Sort on R: Recent,
#                Name, Battles, Win Rate, Best Streak, Place, Next Step
#   the filters  All, Rivalries (trainers you can battle again), Leaders,
#                Pink Slips (wagered, won or lost), as chips
#   the list     each person: their face, name and class (while searching,
#                the place that matched, in gold), your record with them
#   the plate    lit in their class's colour: the whole trainer, their
#                class and name, the place they're at (his change: no
#                FIRST MET words); the ledger (wins,
#                losses, win rate, battles, streak, best); "Rematched 5
#                Times Before Records" on old saves; the Pink Slip's story;
#                the bond steps as three reward tiles (done gold, next
#                blue, later plain; trainers you can battle again); the
#                last battle (when, their team as Big Icons, where); the
#                MVPs (yours and theirs: the most knockouts on the other
#                side)
#
# Buttons: Up / Down choose, Left / Right the filter, L Search, R Sort, Back
# closes (or clears the search). The mouse too: a row, chip or header box
# clicked picks it; the wheel scrolls; a right click goes back.
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont) && defined?(Reloaded::PartyPaint)

module Reloaded
  class BattleRecordsScreen
    include Reloaded::Frame

    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    TC = Reloaded::TrainerControl
    RC = Reloaded::TrainerControl::Records
    BOND = Reloaded::TrainerControl::Bond
    PICS = Reloaded::TrainerControl::Pictures
    ROW_H = 36
    LX0 = 6
    LY0 = 58
    LX1 = 238
    PX0 = 244
    PY0 = 36
    PX1 = W - 6
    BOTTOM = H - P::HINT_H - 6
    SEARCH_BOX = [6, 4, 146, 26].freeze
    SORT_BOX = [W - 146, 4, W - 6, 26].freeze
    TILE_H = 46
    TILE_ICON = 20

    def self.open(filter = :all)
      screen = new(filter)
      defined?(pbFadeOutIn) ? pbFadeOutIn { screen.main } : screen.main
      return screen
    end

    attr_reader :entry, :sel, :filter, :query

    def initialize(filter = :all)
      frame_init
      @filter = RC::FILTERS.index(filter) || 0
      @sel = 0
      @scroll = 0
      @query = nil
      @rows = nil
      @faces = {}
      @trainers = {}
      @mons = {}
      @pictures = {}
      @owned = {}
      @mvp_icon = nil
      @mvp_pid = nil
    end

    def main
      open_sprites
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        @mvp_icon.update if @mvp_icon && !@mvp_icon.disposed? && @mvp_icon.respond_to?(:update)
        break if handle_input == :close
      end
      return nil
    ensure
      dispose_pictures
      dispose_sprites
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

    def rows
      @rows ||= RC.list(RC::FILTERS[@filter], @query, TC.sort)
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
      elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
        set_filter(@filter + (Input.trigger?(Input::RIGHT) ? 1 : -1))
      elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        move(Input.repeat?(Input::DOWN) ? 1 : -1)
      end
      return nil
    end

    def move(dir)
      n = rows.length
      return if n == 0
      target = @sel + dir
      if target < 0 || target >= n
        return unless fresh?(dir)
        target = dir < 0 ? n - 1 : 0
      end
      return if target == @sel
      @sel = target
      pbPlayCursorSE
      refresh
    end

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
      if (i = pt.hit(@chip_hits || []))
        set_filter(i)
      elsif (k = pt.hit(@row_hits || [])) && k != @sel
        @sel = k
        pbPlayCursorSE
        refresh
      end
      return [true, nil]
    end

    def set_filter(i)
      i %= RC::FILTERS.length
      return if i == @filter
      @filter = i
      @sel = 0
      @scroll = 0
      pbPlayCursorSE
      changed!
    end

    def cycle_sort
      TC.sort = TC.sort + 1
      pbPlayCursorSE
      @sel = 0
      changed!
      return nil
    end

    def search
      pbPlayDecisionSE
      text, _how = Reloaded::TextEntry.run(self, _INTL("Type to Search"), @query || "", 20,
                                           :prompt => _INTL("Search Battle Records"), :down => true) do |t|
        @query = t.strip.empty? ? nil : t.strip
        @sel = 0
        changed!
      end
      @query = text.to_s.strip.empty? ? nil : text.strip
      @sel = 0
      changed!
      return nil
    end

    # Back: the search cleared, else close
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

    def hint_filter
      set_filter(@filter + 1)
      return nil
    end

    def left_box
      return SEARCH_BOX
    end

    def right_box
      return SORT_BOX
    end

    def hint_pairs
      back = button(:B)
      return [[button(:C), _INTL("Type")], [back, _INTL("Done")]] if @entry
      return [[:ud, _INTL("Choose")], [:lr, _INTL("Filter"), :hint_filter], [back, @query ? _INTL("Clear") : _INTL("Close"), :hint_back]]
    end

    #--------------------------------------------------------------------------
    # Pictures (kept while the screen is open)
    #--------------------------------------------------------------------------
    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    def picture(path)
      return @pictures[path] if @pictures.key?(path)
      resolved = defined?(pbResolveBitmap) ? (pbResolveBitmap(path) || path) : path
      @pictures[path] = (Bitmap.new(resolved) rescue nil)
      return @pictures[path]
    end

    def face_pic(b, type, x, y, size)
      bm = (@faces.key?(type) ? @faces[type] : (@faces[type] = PICS.face(type)))
      b.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, bm.width, bm.height)) if bm
    end

    # The whole trainer fitted in a box (its height or width at most size)
    def trainer_pic(b, type, cx, bottom, size)
      bm, bounds = (@trainers[type] ||= begin
        pic = PICS.bitmap(type)
        [pic, pic ? PICS.bounds(pic) : nil]
      end)
      return unless bm
      l, t, r, bt, _hx = bounds
      w = r - l
      h = bt - t
      z = size.to_f / [w, h, 1].max
      dw = (w * z).round
      dh = (h * z).round
      b.stretch_blt(Rect.new(cx - dw / 2, bottom - dh, dw, dh), bm, Rect.new(l, t, w, h))
    end

    # A species' picture (Big Pokémon Icons as the player has them) fitted
    # in size, its art's middle on cx, cy
    def mon(b, species, cx, cy, size)
      bm, r = (@mons[species] ||= begin
        pic = species == :EGG ? Reloaded::PartyIcons.egg_bitmap : Reloaded::PartyIcons.species_bitmap(species.to_s.to_sym)
        [pic, pic ? Reloaded::PartyIcons.art_rect(pic, [pic.height, 1].max) : nil]
      end)
      return unless bm
      z = size.to_f / [r.width, r.height, 1].max
      w = (r.width * z).round
      h = (r.height * z).round
      b.stretch_blt(Rect.new(cx - w / 2, cy - h / 2, w, h), bm, r)
    end

    def item_pic(b, item, x, y, size)
      file = (::GameData::Item.icon_filename(item.to_s.to_sym) rescue nil) || "Graphics/Items/#{item}"
      bm = picture(file)
      b.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, bm.width, bm.height)) if bm
    end

    def dispose_pictures
      [@faces.values, @trainers.values.map(&:first), @mons.values.map(&:first), @pictures.values].flatten.each do |bm|
        bm.dispose if bm && !bm.disposed?
      end
      @faces = {}
      @trainers = {}
      @mons = {}
      @pictures = {}
      drop_mvp_icon
    end

    # Your MVP as it is now (its evolution, fusion, look), found by its
    # personal ID in the party and the boxes; nil once it's gone
    def owned(pid)
      return @owned[pid] if @owned.key?(pid)
      found = ($Trainer ? $Trainer.party.compact : []).find { |pk| pk.personalID.to_s == pid }
      st = $PokemonStorage
      if found.nil? && st
        st.maxBoxes.times do |b|
          (st.maxPokemon(b) rescue 0).times do |i|
            pk = (st[b, i] rescue nil)
            next unless pk && pk.personalID.to_s == pid
            found = pk
            break
          end
          break if found
        end
      end
      return @owned[pid] = found
    rescue StandardError
      return @owned[pid] = nil
    end

    def drop_mvp_icon
      @mvp_icon.dispose if @mvp_icon && !@mvp_icon.disposed?
      @mvp_icon = nil
      @mvp_pid = nil
    end

    def sprites
      return super + [@mvp_icon].compact.reject(&:disposed?)
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
      @mvp_icon.visible = false if @mvp_icon && !@mvp_icon.disposed?
      PP.paint_background(base, c)
      draw_header(base, top, c)
      draw_chips(base, top, c, 8, 36)
      draw_list(base, top, c)
      draw_plate(base, top, c, current)
      paint_hints(base, c)
      place_cursor
    end

    # The TM Vault's header: Search on L, the title, Sort on R; while
    # typing, the field across the top
    def draw_header(base, top, c)
      if @entry
        Reloaded::TextEntry.draw_field(base, top, c, @entry, 8, 4, W - 16, 23, 26)
        magnifier(base, 15, c[:txt], c[:dark])
        return
      end
      PP.paint_title(top, c, _INTL("Battle Records"))
      style = Reloaded::Prompts.style
      x0, y0, x1, y1 = SEARCH_BOX
      lit = @query || @hover_box == :left
      PP.chamfer_grad(base, x0, y0, x1, y1, 6, mix(c[:panel2], c[:selb], lit ? 0.4 : 0.15), c[:panel2], lit ? c[:selb] : c[:line])
      P.text(top, x0 + 8, y0 + 1, x1 - x0 - 12, 20, PF.fit(PF::TEXT, @query || _INTL("Search"), x1 - x0 - 12), @query ? c[:txt] : c[:dim], PF::TEXT)
      Reloaded::ButtonIcons.draw(top, x1 + 4, 6, left_key, c, style, 18)
      x0, y0, x1, y1 = SORT_BOX
      lit = @hover_box == :right
      PP.chamfer_grad(base, x0, y0, x1, y1, 6, mix(c[:panel2], c[:selb], lit ? 0.4 : 0.15), c[:panel2], lit ? c[:selb] : c[:line])
      # (a long one shows its name alone: R beside it says what it is)
      label = _INTL("Sort: {1}", _INTL(RC::SORTS[TC.sort]))
      label = _INTL(RC::SORTS[TC.sort]) if P.width(PF::TEXT, label) > x1 - x0 - 8
      P.text(top, x0, y0 + 1, x1 - x0, 20, PF.fit(PF::TEXT, label, x1 - x0 - 8), c[:txt], PF::TEXT, 2)
      key = right_key
      Reloaded::ButtonIcons.draw(top, x0 - 4 - Reloaded::ButtonIcons.width(key, style, 18), 6, key, c, style, 18)
    end

    # The filters as chips (the picked one lit by its fill)
    def draw_chips(base, top, c, x, y)
      @chip_hits = []
      RC::FILTER_WORDS.each_with_index do |words, i|
        label = _INTL(words).upcase
        w = P.width(PF::TINY, label) + 12
        on = i == @filter
        PP.chamfer_grad(base, x, y, x + w, y + 18, 5, on ? mix(c[:panel2], c[:selb], 0.62) : c[:panel2],
                        on ? mix(c[:panel2], c[:selb], 0.4) : c[:panel2], c[:line])
        P.text(top, x, y + 2, w, 14, label, on ? c[:strong] : c[:dim], PF::TINY, 2)
        @chip_hits << [i, x, y, x + w, y + 18]
        x += w + 4
      end
    end

    def wl(rec)
      return "#{rec["wins"].to_i}-#{rec["losses"].to_i}"
    end

    def wl_color(c, rec)
      w = rec["wins"].to_i
      l = rec["losses"].to_i
      return c[:green] if w > l
      return c[:red] if w < l
      return c[:dim]
    end

    def shown_name(rec)
      return (rec["shown"] || rec["name"]).to_s
    end

    def empty_words
      return _INTL("Nothing matches \"{1}\".", @query) if @query
      return _INTL("No battles yet. Every trainer you battle gets a record here.") if RC.people.empty?
      case RC::FILTERS[@filter]
      when :rivalries then return _INTL("No rivalries yet. Trainers you can battle again show here.")
      when :leaders then return _INTL("No leaders battled yet. Gym Leaders, the Elite Four, Champions and Rocket bosses show here.")
      when :pink_slips then return _INTL("No Pink Slips wagered yet.")
      end
      return ""
    end

    def draw_list(base, top, c)
      PP.chamfer_grad(base, LX0, LY0, LX1, BOTTOM, 10, c[:panel2], mix(c[:panel2], c[:dark], 0.3), c[:line])
      @row_hits = []
      list = rows
      if list.empty?
        P.small_wrap(top, empty_words, LX1 - LX0 - 24).first(5).each_with_index do |ln, i|
          P.small(top, LX0 + 12, LY0 + 8 + i * 16, LX1 - LX0 - 24, 16, ln, c[:dim])
        end
        return
      end
      visible = (BOTTOM - LY0 - 6) / ROW_H
      @scroll = @sel if @sel < @scroll
      @scroll = @sel - visible + 1 if @sel >= @scroll + visible
      @scroll = [[@scroll, list.length - visible].min, 0].max
      list[@scroll, visible].each_with_index do |rec, k|
        i = @scroll + k
        y = LY0 + 4 + k * ROW_H
        @cursor_rect = [LX0 + 4, y, LX1 - LX0 - 14, ROW_H - 1] if i == @sel && !@entry
        face_pic(top, rec["type"], LX0 + 9, y + 4, 28)
        P.text(top, LX0 + 44, y + 1, 130, 20, PF.fit(PF::TEXT, shown_name(rec), 130), c[:txt], PF::TEXT)
        place = @query ? RC.match_place(rec, @query) : nil
        if place
          P.text(top, LX0 + 45, y + 21, 130, 12, PF.fit(PF::TINY, place.upcase, 130), c[:gold], PF::TINY)
        else
          P.text(top, LX0 + 45, y + 21, 130, 12, PF.fit(PF::TINY, RC.class_name(rec["type"]).upcase, 130), c[:head], PF::TINY)
        end
        P.text(top, LX1 - 70, y + 7, 54, 22, wl(rec), wl_color(c, rec), PF::ROW, 1)
        @row_hits << [i, LX0 + 4, y, LX1 - 10, y + ROW_H - 1]
      end
      return if list.length <= visible
      track = visible * ROW_H - 4
      bar = [track * visible / list.length, 10].max
      pos = (track - bar) * @scroll / [list.length - visible, 1].max
      base.fill_rect(LX1 - 7, LY0 + 6, 2, track, c[:line])
      base.fill_rect(LX1 - 7, LY0 + 6 + pos, 2, bar, c[:dim])
    end

    #--------------------------------------------------------------------------
    # The record plate
    #--------------------------------------------------------------------------
    def tone_of(c, rec)
      t = rec ? TC.theme_type(rec["type"], rec["team"]) : nil
      rgb = t ? (Reloaded::PartyScreen.type_rgb(t) rescue nil) : nil
      return rgb ? PP.rgb(rgb) : c[:acc]
    end

    # The Party Screen's plate: lit in a colour, its two bands, the red line
    # (the TM Vault's panel_plate)
    def plate(base, c, col, x0, y0, x1, y1, line_y, cut = 16)
      topc = mix(c[:panel], col, 0.4)
      bottom = mix(c[:panel], c[:dark], 0.4)
      PP.chamfer_grad(base, x0, y0, x1, y1, cut, topc, bottom, mix(c[:line], col, 0.5))
      from = x1 - 48
      to = x0 + 24
      (y0 + 1...y1 - 1).each do |y|
        t = (y - y0).to_f / (y1 - y0)
        left = x0 + 1 + [cut - (y - y0), 0].max
        right = x1 - 1 - [cut - (y1 - 1 - y), 0].max
        mid = from + (to - from) * t
        k = y < line_y ? 0.4 : 0.22 - 0.18 * (y - line_y).to_f / [y1 - line_y, 1].max
        tint = mix(mix(topc, bottom, t), col, k)
        [[0, 56], [40, 8]].each do |off, bw|
          a = [(mid + off - bw / 2.0).round, left].max
          e = [(mid + off + bw / 2.0).round, right].min
          base.fill_rect(a, y, e - a, 1, tint) if e > a
        end
      end
      base.fill_rect(x0 + 8, line_y, x1 - x0 - 16, 2, PP::POKE_RED)
    end

    def draw_plate(base, top, c, rec)
      x0 = PX0
      y0 = PY0
      x1 = PX1
      line_y = y0 + 62
      plate(base, c, tone_of(c, rec), x0, y0, x1, BOTTOM, line_y)
      return drop_mvp_icon unless rec
      w = x1 - x0 - 24
      sx = x0 + 12
      trainer_pic(top, rec["type"], x0 + 38, line_y - 3, 54)
      tx = x0 + 74
      room = x1 - tx - 10
      # (his change: the place they're at stays, without the FIRST MET words)
      where = RC.place((rec["first"] || rec["last"] || {})["map"])
      P.text(top, tx, y0 + (where.empty? ? 20 : 11), room, 22, PF.fit(PF::ROW, RC.title(rec), room), c[:strong], PF::ROW)
      P.small(top, tx, y0 + 35, room, 16, where, c[:txt]) unless where.empty?
      y = line_y + 6
      y += ledger(top, c, sx, y, w + 8, rec)
      if (note = before_line(rec))
        P.text(top, sx, y + 1, w, 12, note.upcase, c[:dim], PF::TINY)
        y += 14
      end
      if rec["pink"].is_a?(Hash)
        y += pink_story(top, c, sx, y, rec)
      end
      y = reward_tiles(base, top, c, sx, y + 3, w, rec) if BOND.can_reach?(rec)
      y += last_battle(top, c, sx, y + 2, w, rec) + 3 if rec["last"] && !Array(rec["team"]).empty?
      mvp_rows(top, c, sx, y, w, rec)
    end

    # A stat's name in small capitals over its number: three columns, two
    # rows (the third column the widest: WIN RATE 100%)
    def ledger(top, c, x, y, w, rec, row_h = 18)
      cols = [[x, 66], [x + 76, 66], [x + 152, w - 152]]
      w_, l_ = rec["wins"].to_i, rec["losses"].to_i
      pct = RC.rate(rec)
      cells = [[_INTL("Wins"), w_, c[:green]], [_INTL("Losses"), l_, l_ > 0 ? c[:red] : c[:dim]],
               [_INTL("Win Rate"), "#{pct}%", pct > 50 ? c[:green] : (pct < 50 ? c[:red] : c[:txt])],
               [_INTL("Battles"), w_ + l_, c[:txt]],
               [_INTL("Streak"), rec["streak"].to_i, rec["streak"].to_i > 0 ? c[:gold] : c[:dim]],
               [_INTL("Best"), rec["best"].to_i, c[:txt]]]
      cells.each_with_index do |(label, value, col), i|
        cx, cw = cols[i % 3]
        cy = y + (i / 3) * row_h
        P.text(top, cx, cy + 1, cw, 16, label.upcase, c[:head], PF::TINY)
        P.text(top, cx, cy, cw, 18, value.to_s, col, PF::TEXT, 1)
      end
      return 2 * row_h
    end

    # PIF's rematches from before records (old saves)
    def before_line(rec)
      n = rec["before"].to_i
      return nil if n <= 0
      return n == 1 ? _INTL("Rematched Once Before Records") : _INTL("Rematched {1} Times Before Records", n)
    end

    # "WON THEIR GRAVELER" (green) or "LOST YOUR PIDGEOTTO" (red), the
    # Pokémon beside it: its height
    def pink_story(top, c, x, y, rec)
      pink = rec["pink"]
      sp = pink["species"].to_s
      name = (::GameData::Species.get(sp.to_sym).name rescue sp).upcase
      label = pink["won"] ? _INTL("WON THEIR {1}", name) : _INTL("LOST YOUR {1}", name)
      col = pink["won"] ? c[:green] : c[:red]
      fill, ink = PP.badge(c, [col.red.to_i, col.green.to_i, col.blue.to_i])
      pw = P.pill(top, x, y + 2, label, fill, ink, false)
      mon(top, sp, x + pw + 14, y + 9, 20)
      return 20
    end

    def tile_words(top, c, x, y, w, str, color)
      P.text(top, x, y, w, 12, PF.fit(PF::TINY, str.upcase, w), color, PF::TINY, 2)
    end

    def reward_name(kind, reward)
      case kind
      when :gift then return (reward && reward["item"] ? (::GameData::Item.get(reward["item"].to_sym).name rescue reward["item"]) : _INTL("Gift"))
      when :tutor then return (reward && reward["move"] ? (::GameData::Move.get(reward["move"].to_sym).name rescue reward["move"]) : _INTL("Tutor"))
      end
      return _INTL("Egg")
    end

    # The bond steps as three tiles showing the rewards: the class gift's
    # item, the tutor's move (a "?" until it's taught), the Egg. Done: a
    # gold fill; the next: a blue fill; later: the panel's own; no borders.
    # The y under them.
    def reward_tiles(base, top, c, x, y, w, rec)
      kind_n, at_n, left = BOND.next_step(rec)
      right = left == 1 ? _INTL("{1} in 1 Win", BOND.word(kind_n)) : _INTL("{1} in {2} Wins", BOND.word(kind_n), left)
      rw = P.small(top, x, y - 2, w, 16, right, c[:blue], 1)
      P.heading(top, x, x + w - rw - 8, y, _INTL("Bond Steps"), c[:dim], c[:line])
      ty = y + 16
      tw = (w - 8) / 3
      h = TILE_H
      icon = TILE_ICON
      BOND.shown(rec).each_with_index do |(kind, at), i|
        tx = x + i * (tw + 4)
        done = rec["wins"].to_i >= at
        nxt = at == at_n
        reward = BOND.reward(rec, at)
        tint = done ? c[:gold] : (nxt ? c[:blue] : nil)
        fill_top = tint ? mix(c[:panel2], tint, c[:light] ? 0.30 : 0.34) : mix(c[:panel2], c[:dark], c[:light] ? 0.10 : 0.35)
        fill_bottom = mix(fill_top, c[:dark], c[:light] ? 0.06 : 0.3)
        PP.chamfer_grad(base, tx, ty, tx + tw, ty + h, 6, fill_top, fill_bottom, fill_top)
        ink = done ? c[:gold] : (nxt ? c[:blue] : c[:dim])
        P.text(top, tx, ty + 2, tw, 12, BOND.word(kind).upcase, ink, PF::TINY, 2)
        cx = tx + tw / 2
        cy = ty + 14 + (h - 30) / 2
        if kind == :egg
          mon(top, :EGG, cx, cy, icon)
        elsif kind == :gift && reward && reward["item"]
          item_pic(top, reward["item"], cx - icon / 2, cy - icon / 2, icon)
        elsif kind == :tutor && reward && reward["move"]
          type = (::GameData::Move.get(reward["move"].to_sym).type rescue :NORMAL)
          item_pic(top, "machine_#{type}", cx - icon / 2, cy - icon / 2, icon)
        else
          PP.disc(top, cx, cy, icon / 2 - 1, mix(fill_top, c[:dark], c[:light] ? 0.18 : 0.45))
          P.text(top, cx - 10, cy - 9, 20, 18, "?", nxt ? c[:strong] : c[:dim], PF::TEXT, 2)
        end
        words = done ? reward_name(kind, reward) : _INTL("At {1} Wins", at)
        tile_words(top, c, tx + 3, ty + h - 14, tw - 6, words, done || nxt ? c[:txt] : c[:dim])
      end
      return ty + h + 2
    end

    def when_words(time)
      return "" unless time.is_a?(Time)
      now = Time.now
      today = Time.local(now.year, now.month, now.day)
      return _INTL("Today") if time >= today
      return _INTL("Yesterday") if time >= today - 86_400
      return _INTL("{1} Days Ago", ((today - time) / 86_400.0).ceil)
    end

    # The last battle: when on the heading, their team as Big Icons with
    # levels, where beside the team (on the heading's line when the team
    # leaves no room); its height
    def last_battle(top, c, x, y, w, rec, cell = 39, size = 22)
      team = Array(rec["team"]).first(6)
      where = RC.place(rec["last"]["map"])
      used = team.length * cell
      P.small_font(top)
      pw = where.empty? ? 0 : top.text_size(where).width
      beside = used + pw + 12 <= w
      heading = _INTL("Last Battle: {1}", when_words(rec["last"]["time"]))
      if !beside && pw > 0
        rw = P.small(top, x, y - 2, w, 16, where, c[:txt], 1)
        P.heading(top, x, x + w - rw - 8, y, heading, c[:dim], c[:line])
      else
        P.heading(top, x, x + w, y, heading, c[:dim], c[:line])
      end
      team.each_with_index do |(sp, lv), i|
        cx = x - 4 + i * cell + cell / 2
        mon(top, sp, cx, y + 15 + size / 2, size)
        P.text(top, cx - cell / 2, y + 15 + size + 1, cell, 12, _INTL("Lv. {1}", lv), c[:gold], PF::TINY, 2)
      end
      P.small(top, x + w - pw - 2, y + 15 + (size + 12) / 2 - 8, pw + 4, 16, where, c[:txt]) if beside && pw > 0
      return 15 + size + 13
    end

    # A badge of a set width (the MVP rows' badges line up)
    def fixed_pill(b, c, x, y, label, key, w)
      tone = c[key]
      fill = c[:light] ? mix(c[:panel2], tone, 0.22) : mix(c[:panel2], tone, 0.28)
      P.ui.rbox(b, x, y, x + w, y + 15, 4, fill)
      P.text(b, x, y, w, 16, label, tone, PF::TINY, 2)
    end

    # The MVPs: your Pokémon with the most knockouts on them (as it is now:
    # found by its personal ID), and theirs with the most on yours. No
    # "Your"/"Their" words: the badges say YOU and the trainer's name.
    def mvp_rows(top, c, x, y, w, rec, row_h = 18, icon = 18)
      you, them = RC.mvp(rec)
      return drop_mvp_icon if you.nil? && them.nil?
      return drop_mvp_icon if y + 15 + row_h > BOTTOM - 4
      P.heading(top, x, x + w, y, _INTL("MVP"), c[:dim], c[:line])
      y += 15
      labels = [[_INTL("YOU"), :blue], [shown_name(rec).upcase, :red]]
      pill_w = labels.map { |l, _k| P.width(PF::TINY, l) + 12 }.max
      kept_icon = false
      [you, them].each_with_index do |e, i|
        next unless e
        ry = y + i * row_h
        break if ry + row_h > BOTTOM - 2
        label, key = labels[i]
        fixed_pill(top, c, x, ry + (row_h - 15) / 2, label, key, pill_w)
        icx = x + pill_w + 6 + icon / 2
        icy = ry + row_h / 2
        if i == 0
          pk = owned(e["pid"].to_s)
          name = pk ? pk.name.to_s : e["name"].to_s
          kept_icon = mvp_icon(pk, e["pid"].to_s, icx, icy, icon) if pk
          mon(top, e["species"], icx, icy, icon) unless kept_icon
          kos = e["kos"].to_i
        else
          name = (::GameData::Species.get(e[0].to_s.to_sym).name rescue e[0].to_s)
          mon(top, e[0], icx, icy, icon)
          kos = e[1].to_i
        end
        nx = x + pill_w + 12 + icon
        words = kos == 1 ? _INTL("1 KO") : _INTL("{1} KOs", kos)
        kw = P.text(top, x, ry + (row_h - 20) / 2, w, 20, words, c[:gold], PF::TEXT, 1)
        rm = x + w - kw - 8 - nx
        P.text(top, nx, ry + (row_h - 20) / 2, rm, 20, PF.fit(PF::TEXT, name, rm), c[:txt], PF::TEXT)
      end
      drop_mvp_icon unless kept_icon
    end

    # Your MVP's own icon (the game's: its look, Ghostly Possession's
    # possessed one too), made once per record shown
    def mvp_icon(pk, pid, cx, cy, box)
      if @mvp_pid != pid
        drop_mvp_icon
        @mvp_icon = Reloaded::PartyIcons.icon(pk, @viewport, 2)
        @mvp_pid = pid
        @mvp_rect = @mvp_icon && @mvp_icon.bitmap ? Reloaded::PartyIcons.art_rect(@mvp_icon.bitmap, [@mvp_icon.src_rect.height, 1].max) : nil
      end
      s = @mvp_icon
      r = @mvp_rect
      return false unless s && r && !s.disposed?
      s.zoom_x = s.zoom_y = box.to_f / [r.width, r.height, 1].max
      s.ox = r.x + r.width / 2
      s.oy = r.y + r.height / 2
      s.x = cx
      s.y = cy
      s.visible = true
      return true
    end
  end
end
