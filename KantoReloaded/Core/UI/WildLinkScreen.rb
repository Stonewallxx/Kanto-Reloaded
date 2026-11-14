# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Wild Link screen
#==============================================================================
# His pick (2026-11-14, sheets wl-screen, wl-screen-states): Design 2, Bonus
# Meters. Area Encounters becomes Wild Link while it's On:
#
#   the title bar  a pill for each way the Pokémon here are met (Land, Cave,
#                  Surf, Fishing, Rock Smash) on the left; the weather here
#                  as a chip on the right (the Weather System's, its icon)
#   the list       Seen and Caught for the tab, then a row each: the
#                  Pokémon's picture (a shadow until seen), a ball once
#                  caught, its name (??? unseen), its levels, the weather's
#                  icon by the ones it raised, its share; a rod's rows under
#                  its name; Weather Signals (the place's Weather Visitors)
#                  under their heading; the Rare Signal last, Locked until
#                  every land Pokémon here is seen
#   the plate      in the Pokémon's type colour (grey unseen): its picture,
#                  name, Caught / Seen / Not Seen and types, the red line;
#                  Search Level with a bar to its next step, the chain; then
#                  Current Bonuses, each with a meter toward its cap (shiny
#                  toward 1 in 10), or with X the Search Level steps (done in
#                  green, next in gold); the footer says what Search can do
#                  (Search for Abra, Not Seen Yet, Needs the Poké Radar...)
#   the Rare Signal locked: a gold plate, Seen Here with its bar, what opens it
#
# Buttons: Up/Down the rows, Left/Right the tabs, A searches (the screen
# closes and the search starts), X Current Bonuses / Search Level Steps, B
# closes. The mouse: a tab or a row clicked picks it (the picked row again
# searches), the wheel scrolls, a right click closes.
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont) && defined?(Reloaded::PartyPaint)

module Reloaded
  class WildLinkScreen
    include Reloaded::Frame

    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    BOTTOM = H - P::HINT_H - 6
    LX0 = 6                          # the list's box
    LX1 = 300
    LIST_Y = 60
    ROW_H = 24
    HEAD_H = 16
    PX0 = 306                        # the plate
    PX1 = W - 6
    PY0 = 36
    GOLD = Color.new(240, 200, 80)
    UNSEEN = [150, 160, 175].freeze
    LABELS = { :shiny => "Shiny", :ivs => "Perfect IVs", :ha => "Hidden Ability", :egg => "Egg Move", :item => "Held Item",
               :level => "Level" }.freeze

    # The screen; what was picked to search ([row, way] or nil)
    def self.open(z = nil)
      screen = new(z)
      if defined?(pbFadeOutIn)
        z ? pbFadeOutIn(z + 1) { screen.main } : pbFadeOutIn { screen.main }
      else
        screen.main
      end
      return screen
    end

    attr_reader :result, :tab, :sel, :view

    def initialize(z = nil)
      frame_init
      @z = z
      @pics = {}
      @mons = {}
      @tabs = Reloaded::WildLink::Area.tabs
      surfing = $PokemonGlobal && $PokemonGlobal.respond_to?(:surfing) && $PokemonGlobal.surfing
      @tab = (surfing && @tabs.index { |id, *| id == :surf }) || 0
      @view = :bonuses
      @result = nil
      pick_first
    end

    def main
      open_sprites
      @viewport.z = @z if @z
      @icons = Array.new(14) do
        s = Sprite.new(@viewport)
        s.z = 2
        s.visible = false
        s
      end
      @big = Sprite.new(@viewport)
      @big.z = 2
      @big.visible = false
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        break if handle_input == :close
      end
      return nil
    ensure
      (@icons || []).each { |s| s.dispose unless s.disposed? }
      @big.dispose if @big && !@big.disposed?
      @mons.each_value { |bm, _r| bm.dispose if bm && !bm.disposed? }
      @pics.each_value { |bm| bm.dispose if bm && !bm.disposed? }
      dispose_sprites
    end

    def refresh
      draw if @sprite && !@sprite.disposed?
    end

    #--------------------------------------------------------------------------
    # The rows
    #--------------------------------------------------------------------------
    def rows
      t = @tabs[@tab]
      return t ? t[2] : []
    end

    def way
      t = @tabs[@tab]
      return t ? t[0] : nil
    end

    def row
      return rows[@sel]
    end

    # The tab's lines: [:head, words, rgb or nil] and [:row, index]
    def lines
      out = []
      visitor_head = false
      rows.each_with_index do |r, i|
        out << [:head, r[:heading], nil] if r[:heading]
        if r[:kind] == :visitor && !visitor_head
          out << [:head, _INTL("Weather Signals"), Reloaded::Weather::Display.rgb(r[:weather])] if defined?(Reloaded::Weather::Display)
          visitor_head = true
        end
        out << [:row, i]
      end
      return out
    end

    def line_h(l)
      return l[0] == :head ? HEAD_H : ROW_H
    end

    def list_h
      return BOTTOM - 4 - LIST_Y
    end

    def pick_first
      @sel = 0
      @top = 0
    end

    # The first line shown keeps the picked row in view
    def follow
      ls = lines
      at = ls.index { |l| l[0] == :row && l[1] == @sel } || 0
      at -= 1 while at > 0 && ls[at - 1][0] == :head
      @top = at if at < @top
      loop do
        used = ls[@top..(ls.index { |l| l[0] == :row && l[1] == @sel } || 0)].sum { |l| line_h(l) }
        break if used <= list_h || @top >= ls.length - 1
        @top += 1
      end
    end

    #--------------------------------------------------------------------------
    # What Search can do for the picked row: [can, words]
    #--------------------------------------------------------------------------
    BLOCKED = { :radar => "Needs the Poké Radar", :safari => "Not in the Safari Zone", :contest => "Not in the Bug Contest",
                :partner => "Not with a Partner", :dynamic => "The Randomizer Rolls Each One", :nuzlocke => "Waits for First Encounter",
                :off => "Wild Link Is Off" }.freeze

    def search_state(r = row)
      return [false, ""] unless r
      return [false, _INTL("{1} More to See", rare_left)] if r[:kind] == :rare && !r[:open]
      # the Rare Signal open: searchable unseen (only Wild Link finds it)
      unless seen?(r[:species]) || r[:kind] == :rare
        return [false, r[:kind] == :visitor ? _INTL("Not Seen Yet: While It's {1}", weather_word(r)) : _INTL("Not Seen Yet")]
      end
      why = Reloaded::WildLink.blocked
      return [false, _INTL(BLOCKED[why] || "Can't Search Here")] if why
      gate = defined?(Reloaded::WildLink::Fields) ? Reloaded::WildLink::Fields.gate(r, way) : nil
      return [false, gate] if gate
      return [true, _INTL("Search While It's {1}", weather_word(r))] if r[:kind] == :visitor
      return [true, _INTL("Search the Rare Signal")] if r[:kind] == :rare && !seen?(r[:species])
      return [true, _INTL("Search for {1}", species_name(r[:species]))]
    end

    def weather_word(r)
      return defined?(Reloaded::Weather::Display) ? Reloaded::Weather::Display.name(r[:weather]) : ""
    end

    def rare_left
      seen, all = Reloaded::WildLink::Area.seen_count(rows)
      return [all - seen, 0].max
    end

    def seen?(sp)
      return Reloaded::WildLink::Area.seen?(sp)
    end

    def caught?(sp)
      return Reloaded::WildLink::Area.caught?(sp)
    end

    def species_name(sp)
      return (::GameData::Species.get(sp).name.to_s rescue sp.to_s)
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def hint_pairs
      [[:ud, _INTL("Choose")], [:lr, _INTL("Method")], [button(:C), _INTL("Search"), :search],
       [button(:A), @view == :bonuses ? _INTL("Milestones") : _INTL("Bonuses"), :flip_view], [button(:B), _INTL("Back"), :close_now]]
    end

    def handle_input
      handled, result = mouse_input
      return result if handled
      if Input.trigger?(Input::BACK)
        return close_now
      elsif Input.trigger?(Input::USE)
        return search
      elsif Input.trigger?(Input::ACTION)
        flip_view
      elsif Input.repeat?(Input::UP) then move(-1)
      elsif Input.repeat?(Input::DOWN) then move(1)
      elsif Input.repeat?(Input::LEFT) then switch_tab(-1)
      elsif Input.repeat?(Input::RIGHT) then switch_tab(1)
      end
      return nil
    end

    def move(d)
      return if rows.empty?
      n = (@sel + d) % rows.length
      return if n == @sel
      @sel = n
      follow
      pbPlayCursorSE
      refresh
    end

    def switch_tab(d)
      return if @tabs.length < 2
      @tab = (@tab + d) % @tabs.length
      pick_first
      pbPlayCursorSE
      refresh
    end

    def flip_view
      @view = @view == :bonuses ? :steps : :bonuses
      pbPlayCursorSE
      refresh
      return nil
    end

    def search
      can, _words = search_state
      unless can
        pbPlayBuzzerSE
        return nil
      end
      pbPlayDecisionSE
      @result = [row, way]
      return :close
    end

    def close_now
      pbPlayCloseMenuSE
      return :close
    end

    def mouse_input
      pt = Reloaded::Pointer
      return [true, close_now] if pt.right?
      w = pt.wheel
      if w != 0
        move(w > 0 ? 1 : -1)
        return [true, nil]
      end
      return [false, nil] unless pt.left?
      handled, result = hint_click
      return [true, result] if handled
      if (t = pt.hit(@tab_hits || []))
        if t != @tab
          @tab = t
          pick_first
          pbPlayCursorSE
          refresh
        end
      elsif (i = pt.hit(@row_hits || []))
        return [true, search] if i == @sel
        @sel = i
        follow
        pbPlayCursorSE
        refresh
      end
      return [true, nil]
    end

    #--------------------------------------------------------------------------
    # Drawing
    #--------------------------------------------------------------------------
    def pic(path)
      return @pics[path] if @pics.key?(path)
      @pics[path] = (Bitmap.new(path) rescue nil)
    end

    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    def draw
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      header(base, top, c)
      PP.chamfer_grad(base, LX0, 36, LX1, BOTTOM, 8, c[:panel2], mix(c[:panel2], c[:dark], 0.3), c[:line])
      @icons.each { |s| s.visible = false } if @icons
      @big.visible = false if @big
      if rows.empty?
        P.text(top, LX0, 160, LX1 - LX0, 20, _INTL("No Wild Pokémon Here"), c[:dim], PF::TEXT, 2)
        @cursor_rect = nil
      else
        list(base, top, c)
        plate_for(base, top, c)
      end
      paint_hints(base, c)
      place_cursor
    end

    def header(base, top, c)
      PP.paint_background(base, c)
      PP.paint_title(top, c, _INTL("Wild Link"))
      x = 8
      @tab_hits = []
      @tabs.each_with_index do |(_id, label, _rows), i|
        l = _INTL(label).upcase
        w = P.width(PF::TINY, l) + 16
        on = i == @tab
        PP.chamfer_grad(base, x, 6, x + w, 24, 5, on ? mix(c[:panel2], c[:selb], 0.62) : c[:panel2],
                        on ? mix(c[:panel2], c[:selb], 0.4) : c[:panel2], on ? c[:selb] : c[:line])
        P.text(top, x, 8, w, 14, l, on ? c[:strong] : c[:dim], PF::TINY, 2)
        @tab_hits << [i, x, 6, x + w, 24]
        x += w + 2
      end
      weather_chip(base, top, c)
    end

    # The weather here (the Weather System's), as the Forecast's season chip
    def weather_chip(base, top, c)
      w = Reloaded::WildLink::Area.weather_here
      return unless w && defined?(Reloaded::Weather::Display)
      ds = Reloaded::Weather::Display
      type = w[1]
      label = ds.name(type).upcase
      col = ds.colour(type)
      cw = P.width(PF::TINY, label) + 30
      x1 = W - 8
      PP.chamfer_grad(base, x1 - cw, 6, x1, 24, 5, mix(c[:panel2], col, 0.35), mix(c[:panel2], col, 0.18), mix(c[:line], col, 0.5))
      ic = pic(ds.icon(type, w[2]))
      top.stretch_blt(Rect.new(x1 - cw + 6, 7, 16, 16), ic, Rect.new(0, 0, ic.height, ic.height)) if ic
      P.text(top, x1 - cw + 24, 8, cw - 26, 14, label, PP.ink(c, ds.rgb(type)), PF::TINY)
    end

    def list(base, top, c)
      seen, all = Reloaded::WildLink::Area.seen_count(rows)
      caught, _all = Reloaded::WildLink::Area.caught_count(rows)
      P.small(top, 14, 40, 280, 16, _INTL("Seen {1}/{2}", seen, all), c[:dim])
      P.small(top, 14, 40, 280, 16, _INTL("Caught {1}/{2}", caught, all), c[:dim], 1)
      base.fill_rect(12, 57, 282, 1, c[:line])
      @row_hits = []
      @cursor_rect = nil
      y = LIST_Y
      icon = 0
      lines[@top..-1].to_a.each do |l|
        h = line_h(l)
        break if y + h > LIST_Y + list_h
        if l[0] == :head
          col = l[2] ? PP.ink(c, l[2]) : c[:head]
          P.heading(top, 14, 294, y + 3, _INTL(l[1].to_s).upcase, col, l[2] ? mix(c[:line], Color.new(*l[2]), 0.5) : c[:line])
        else
          i = l[1]
          paint_row(base, top, c, rows[i], y, @icons[icon])
          icon += 1
          @row_hits << [i, 10, y, 296, y + ROW_H - 1]
          @cursor_rect = [10, y - 1, 286, ROW_H + 2] if i == @sel
        end
        y += h
      end
    end

    def paint_row(base, top, c, r, y, spr)
      cy = y + ROW_H / 2
      sp = r[:species]
      if r[:kind] == :rare && !r[:open]
        mon(spr, sp, 26, cy, 22, true)
        P.text(top, 46, y + 3, 130, 18, _INTL("Rare Signal"), c[:gold] || GOLD, PF::TEXT)
        P.small(top, 160, y + 4, 130, 16, _INTL("Locked"), c[:dim])
        P.small(top, 160, y + 4, 132, 16, _INTL("See All {1}", Reloaded::WildLink::Area.seen_count(rows)[1]), c[:dim], 1)
        return
      end
      st = caught?(sp) ? :caught : (seen?(sp) ? :seen : :unseen)
      mon(spr, sp, 26, cy, 22, st == :unseen)
      P.poke_ball(top, 38, cy - 5, 9) if st == :caught
      name = st == :unseen ? "???" : species_name(sp)
      ink = r[:kind] == :rare ? (c[:gold] || GOLD) : (st == :unseen ? c[:dim] : c[:txt])
      P.text(top, 50, y + 3, 110, 18, PF.fit(PF::TEXT, name, 106), ink, PF::TEXT)
      lv = r[:min] == r[:max] ? "Lv #{r[:min]}" : "Lv #{r[:min]}-#{r[:max]}"
      P.small(top, 160, y + 4, 70, 16, lv, c[:dim])
      if r[:kind] == :rare
        P.small(top, 250, y + 4, 42, 16, _INTL("Rare"), c[:gold] || GOLD, 1)
        return
      end
      wtype = r[:kind] == :visitor ? r[:weather] : (r[:boost] ? weather_type : nil)
      if wtype && defined?(Reloaded::Weather::Display)
        ic = pic(Reloaded::Weather::Display.icon(wtype, 6))
        top.stretch_blt(Rect.new(232, cy - 8, 16, 16), ic, Rect.new(0, 0, ic.height, ic.height)) if ic
      end
      ink = wtype && defined?(Reloaded::Weather::Display) ? PP.ink(c, Reloaded::Weather::Display.rgb(wtype)) : c[:txt]
      P.small(top, 250, y + 4, 42, 16, "#{r[:rate]}%", ink, 1)
    end

    def weather_type
      w = Reloaded::WildLink::Area.weather_here
      return w ? w[1] : nil
    end

    def type_rgb(t)
      return defined?(Reloaded::PartyScreen::TYPE_RGB) && Reloaded::PartyScreen::TYPE_RGB[t] || UNSEEN
    end

    def small_type(b, type, x, y)
      sheet = pic(PP::TYPES_SMALL)
      b.blt(x, y, sheet, Rect.new(0, PP.type_row(type) * 16, 16, 16)) if sheet
    end

    def plate(base, c, color, x0, y0, x1, y1, line_y, cut = 16)
      topc = mix(c[:panel], color, 0.4)
      bottom = mix(c[:panel], c[:dark], 0.4)
      PP.chamfer_grad(base, x0, y0, x1, y1, cut, topc, bottom, mix(c[:line], color, 0.5))
      from = x1 - 48
      to = x0 + 24
      (y0 + 1...y1 - 1).each do |y|
        t = (y - y0).to_f / (y1 - y0)
        left = x0 + 1 + [cut - (y - y0), 0].max
        right = x1 - 1 - [cut - (y1 - 1 - y), 0].max
        mid = from + (to - from) * t
        k = y < line_y ? 0.4 : 0.22 - 0.18 * (y - line_y).to_f / [y1 - line_y, 1].max
        tint = mix(mix(topc, bottom, t), color, k)
        [[0, 56], [40, 8]].each do |off, bw|
          a = [(mid + off - bw / 2.0).round, left].max
          e = [(mid + off + bw / 2.0).round, right].min
          base.fill_rect(a, y, e - a, 1, tint) if e > a
        end
      end
      base.fill_rect(x0 + 8, line_y, x1 - x0 - 16, 2, PP::POKE_RED)
    end

    def bar(base, c, x, y, w, n, color, segs = 10, h = 5)
      gap = 2
      sw = (w - gap * (segs - 1)) / segs
      segs.times { |i| base.fill_rect(x + i * (sw + gap), y, sw, h, i < n ? color : mix(c[:dark], c[:line], 0.4)) }
    end

    def row_words(top, c, x, y, w, label, value, color)
      P.small(top, x, y, w, 18, label, c[:dim])
      P.small(top, x, y, w, 18, value, color, 1)
    end

    def plate_for(base, top, c)
      r = row
      return unless r
      return rare_plate(base, top, c) if r[:kind] == :rare && !r[:open]
      sp = r[:species]
      d = (::GameData::Species.get(sp) rescue nil)
      st = caught?(sp) ? :caught : (seen?(sp) ? :seen : :unseen)
      sl = Reloaded::WildLink.search_level(sp)
      ch = Reloaded::WildLink.chain_for(sp, way, $game_map ? $game_map.map_id : 0)
      x0 = PX0
      x1 = PX1
      y0 = PY0
      line_y = y0 + 50
      col = st == :unseen || !d ? Color.new(*UNSEEN) : Color.new(*type_rgb(d.type1))
      plate(base, c, col, x0, y0, x1, BOTTOM, line_y)
      mon(@big, sp, x0 + 30, y0 + 25, 44, st == :unseen)
      P.text(top, x0 + 58, y0 + 4, x1 - x0 - 66, 22, PF.fit(PF::ROW, st == :unseen ? "???" : species_name(sp), x1 - x0 - 66), c[:strong], PF::ROW)
      words = { :caught => _INTL("Caught"), :seen => _INTL("Seen"), :unseen => _INTL("Not Seen") }[st]
      wcol = st == :caught ? c[:green] : (st == :seen ? c[:txt] : c[:dim])
      w = P.text(top, x0 + 58, y0 + 27, 90, 18, words, wcol, PF::TEXT)
      if st != :unseen && d
        [d.type1, d.type2].compact.uniq.each_with_index { |t, i| small_type(top, t, x0 + 64 + w + i * 20, y0 + 30) }
      end
      sx = x0 + 12
      ww = x1 - x0 - 24
      y = line_y + 8
      steps = Reloaded::WildLink::Bonuses::SL_STEPS
      nxt = steps.find { |s| s > sl }
      prev = steps.reverse.find { |s| s <= sl } || 0
      row_words(top, c, sx, y, ww, _INTL("Search Level"), sl.to_s, c[:strong])
      segs = nxt ? (((sl - prev).to_f / (nxt - prev)) * 10).floor : 10
      bar(base, c, sx, y + 19, ww, segs, c[:selb])
      P.small(top, sx, y + 25, ww, 16, nxt ? _INTL("Next at {1}", nxt) : _INTL("Every Step"), c[:dim], 1)
      row_words(top, c, sx, y + 42, ww, _INTL("Chain"), ch.to_s, ch > 0 ? (c[:gold] || GOLD) : c[:dim])
      y += 66
      @view == :bonuses ? meters(base, top, c, sx, y, ww, sp, sl, ch) : steps_list(top, c, sx, y, ww, sl)
      base.fill_rect(sx, BOTTOM - 26, ww, 1, c[:line])
      can, foot = search_state(r)
      P.small(top, sx, BOTTOM - 22, ww, 18, foot, can ? c[:txt] : c[:dim], 2)
    end

    def meters(base, top, c, x, y, w, sp, sl, ch)
      P.heading(top, x, x + w, y, _INTL("Current Bonuses"), c[:head], c[:line])
      Reloaded::WildLink::Bonuses.rows(sp, sl, ch).each_with_index do |(k, value, far, ok), i|
        yy = y + 13 + i * 22
        live = ok && far > 0
        P.small(top, x, yy, w, 18, _INTL(LABELS[k]), c[:dim])
        P.small(top, x, yy, w, 18, ok ? value : _INTL("None"), live ? c[:txt] : c[:dim], 1)
        base.fill_rect(x, yy + 17, w, 3, mix(c[:dark], c[:line], 0.4))
        base.fill_rect(x, yy + 17, (w * [far, 1].min).round, 3, c[:selb]) if live
      end
    end

    STEP_WORDS = ["Level +1", "A Shiny Roll", "1 Perfect IV", "2nd Egg Move", "2 Perfect IVs", "4 Shiny Rolls"].freeze
    def steps_list(top, c, x, y, w, sl)
      P.heading(top, x, x + w, y, _INTL("Search Level Steps"), c[:head], c[:line])
      steps = Reloaded::WildLink::Bonuses::SL_STEPS
      nxt = steps.find { |s| s > sl }
      steps.each_with_index do |s, i|
        yy = y + 14 + i * 18
        got = sl >= s
        col = got ? c[:green] : (s == nxt ? (c[:gold] || GOLD) : c[:dim])
        P.small(top, x, yy, 50, 18, "SL #{s}", col)
        P.small(top, x + 50, yy, w - 50, 18, _INTL(STEP_WORDS[i]), got ? c[:txt] : c[:dim])
      end
    end

    def rare_plate(base, top, c)
      x0 = PX0
      x1 = PX1
      y0 = PY0
      line_y = y0 + 50
      gold = c[:gold] || GOLD
      plate(base, c, GOLD, x0, y0, x1, BOTTOM, line_y)
      mon(@big, row[:species], x0 + 30, y0 + 25, 44, true)
      P.text(top, x0 + 58, y0 + 4, x1 - x0 - 66, 22, _INTL("Rare Signal"), gold, PF::ROW)
      P.text(top, x0 + 58, y0 + 27, 120, 18, _INTL("Locked"), c[:dim], PF::TEXT)
      sx = x0 + 12
      ww = x1 - x0 - 24
      seen, all = Reloaded::WildLink::Area.seen_count(rows)
      row_words(top, c, sx, line_y + 8, ww, _INTL("Seen Here"), "#{seen}/#{all}", c[:strong])
      bar(base, c, sx, line_y + 27, ww, seen, gold, [all, 1].max)
      words = P.small_wrap(top, _INTL("See every Pokémon that lives here and the Rare Signal opens: A Pokémon only Wild Link finds on this route."), ww)
      words.first(6).each_with_index { |ln, i| P.small(top, sx, line_y + 42 + i * 18, ww, 18, ln, c[:txt]) }
      base.fill_rect(sx, BOTTOM - 26, ww, 1, c[:line])
      P.small(top, sx, BOTTOM - 22, ww, 18, _INTL("{1} More to See", [all - seen, 0].max), c[:dim], 2)
    end

    # A Pokémon's picture: its Big Icon (or small icon, as the player has
    # it) fitted to its box, a dark shadow until it's been seen
    def mon(spr, sp, cx, cy, size, shadow)
      return unless spr
      unless @mons.key?(sp)
        bm = (Reloaded::PartyIcons.species_bitmap(sp) rescue nil)
        @mons[sp] = [bm, bm ? Reloaded::PartyIcons.art_rect(bm, [bm.height, 1].max) : nil]
      end
      bm, r = @mons[sp]
      return unless bm && r
      spr.bitmap = bm
      spr.src_rect = Rect.new(r.x, r.y, r.width, r.height)
      spr.zoom_x = spr.zoom_y = [size.to_f / [r.width, r.height, 1].max, 1.0].min
      spr.ox = r.width / 2
      spr.oy = r.height / 2
      spr.x = cx
      spr.y = cy
      spr.color = shadow ? Color.new(12, 14, 22) : Color.new(0, 0, 0, 0)
      spr.visible = true
    end
  end
end
