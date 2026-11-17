# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Shiny Log screen
#==============================================================================
# His pick (2026-11-16, sheets sl-screen, sl-states): Design 1, Rebuilt, his
# 2026-10-18 List and Detail pick on today's plate frame:
#
#   the title bar  the shiny count in gold on the left, the sort on the right
#   the list       a row per shiny, newest first: its picture (its own
#                  colours, as the player's icons show them), its name, the
#                  date and place under it; a Poké Ball on the ones that
#                  joined you, GOT AWAY or KNOCKED OUT on the rest; the
#                  Earlier Shinies line last (counted before the Log, not
#                  owned any more)
#   the plate      in the Pokémon's type colour: its picture in its own
#                  colours on a plate of its own, its name, how it ended as a
#                  badge (CAUGHT, GOT AWAY, KNOCKED OUT, HATCHED, RECEIVED,
#                  GAMBLED; "ASH CAUGHT IT" in co-op), its types and level,
#                  the red line; Found, Where, How (With in co-op), and Took
#                  for a wild one (Unknown when it was rebuilt)
#   Your Shinies   under the plate: the total, the longest hunt, the first
#                  found
#
# Buttons: Up/Down the rows, X Newest / Oldest, B closes. The mouse: a row
# clicked picks it, the wheel scrolls, a right click closes.
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont) && defined?(Reloaded::PartyPaint)

module Reloaded
  class ShinyLogScreen
    include Reloaded::Frame

    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    SL = Reloaded::ShinyLog
    BOTTOM = H - P::HINT_H - 6
    LX0 = 6                          # the list's box
    LX1 = 206
    LIST_Y = 40
    ROW_H = 31
    PX0 = 212                        # the plate
    PX1 = W - 6
    PY0 = 36
    PB = 258                         # the plate's bottom; Your Shinies under it
    BOX = 100                        # the picture's own plate
    GOLD = Color.new(240, 200, 80)
    EARLIER = :earlier

    def self.open(pid = nil, z = nil)
      screen = new(pid, z)
      if defined?(pbFadeOutIn)
        z ? pbFadeOutIn(z + 1) { screen.main } : pbFadeOutIn { screen.main }
      else
        screen.main
      end
      return screen
    end

    attr_reader :sel, :oldest

    def initialize(pid = nil, z = nil)
      frame_init
      @z = z
      @pics = {}
      @oldest = false
      @top = 0
      build
      @sel = (pid && @rows.index { |r| r != EARLIER && r["pid"] == pid.to_i }) || 0
      follow
    end

    def build
      @rows = SL.sorted(@oldest)
      @rows += [EARLIER] if SL.earlier > 0
    end

    def main
      open_sprites
      @viewport.z = @z if @z
      @icons = {}
      @shown = {}
      @big = Sprite.new(@viewport)
      @big.z = 2
      @big.visible = false
      @charm = Sprite.new(@viewport)
      @charm.z = 2
      @charm.visible = false
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        @icons.each_value { |s| s.update if s.respond_to?(:update) && !s.disposed? }
        break if handle_input == :close
      end
      return nil
    ensure
      (@icons || {}).each_value { |s| s.dispose unless s.disposed? }
      [@big, @charm].each { |s| s.dispose if s && !s.disposed? }
      (@big_anims || []).each { |a| a.dispose if a.respond_to?(:dispose) && !(a.respond_to?(:disposed?) && a.disposed?) }
      @pics.each_value { |bm| bm.dispose if bm && !bm.disposed? }
      (@made || {}).clear
      dispose_sprites
    end

    def refresh
      draw if @sprite && !@sprite.disposed?
    end

    def row
      return @rows[@sel]
    end

    def visible_rows
      return (BOTTOM - 4 - LIST_Y) / ROW_H
    end

    def follow
      @top = @sel if @sel < @top
      @top = @sel - visible_rows + 1 if @sel >= @top + visible_rows
      @top = [[@top, 0].max, [@rows.length - visible_rows, 0].max].min
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def hint_pairs
      return [[button(:B), _INTL("Back"), :close_now]] if @rows.empty?
      [[:ud, _INTL("Choose")], [button(:A), _INTL("Sort"), :flip_sort], [button(:B), _INTL("Back"), :close_now]]
    end

    def handle_input
      handled, result = mouse_input
      return result if handled
      if Input.trigger?(Input::BACK)
        return close_now
      elsif Input.trigger?(Input::ACTION)
        flip_sort
      elsif Input.repeat?(Input::UP) then move(-1)
      elsif Input.repeat?(Input::DOWN) then move(1)
      end
      return nil
    end

    def move(d)
      return if @rows.length < 2
      @sel = (@sel + d) % @rows.length
      follow
      pbPlayCursorSE
      refresh
    end

    # Newest / Oldest (the picked row stays picked)
    def flip_sort
      return nil if @rows.empty?
      was = row
      @oldest = !@oldest
      build
      @sel = @rows.index { |r| r.equal?(was) || (r != EARLIER && was != EARLIER && r["pid"] == was["pid"]) } || 0
      @top = 0
      follow
      pbPlayCursorSE
      refresh
      return nil
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
      if (i = pt.hit(@row_hits || [])) && i != @sel
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

    def gold(c)
      return c[:gold] || GOLD
    end

    def draw
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      PP.paint_background(base, c)
      PP.paint_title(top, c, _INTL("Shiny Log"))
      n = SL.count
      P.text(top, 10, 7, 140, 18, n == 1 ? _INTL("1 Shiny") : _INTL("{1} Shinies", SL.num(n)), gold(c), PF::TEXT)
      P.small(top, W - 150, 8, 140, 16, @oldest ? _INTL("Sort: Oldest") : _INTL("Sort: Newest"), c[:dim], 1)
      PP.chamfer_grad(base, LX0, 36, LX1, BOTTOM, 8, c[:panel2], mix(c[:panel2], c[:dark], 0.3), c[:line])
      @shown = {}
      @big.visible = false
      @charm.visible = false
      @cursor_rect = nil
      @row_hits = []
      if @rows.empty?
        empty(base, top, c)
      else
        list(base, top, c)
        r = row
        r == EARLIER ? earlier_plate(base, top, c) : plate_for(base, top, c, r)
        totals(base, top, c)
      end
      @icons.each { |k, s| s.visible = @shown[k] ? true : false }
      paint_hints(base, c)
      place_cursor
    end

    def list(base, top, c)
      y = LIST_Y
      @rows[@top, visible_rows].to_a.each_with_index do |r, k|
        i = @top + k
        @cursor_rect = [LX0 + 4, y, LX1 - LX0 - 8, ROW_H] if i == @sel
        @row_hits << [i, LX0 + 4, y, LX1 - 4, y + ROW_H - 1]
        r == EARLIER ? earlier_row(top, c, y) : row_for(top, c, r, y)
        y += ROW_H
      end
    end

    def row_for(top, c, e, y)
      cy = y + ROW_H / 2
      icon(e, 24, cy, 28)
      right = LX1 - 10
      if SL.owned_ending?(e)
        P.poke_ball(top, right - 9, y + 5, 9)
        right -= 14
      elsif SL.wild_ending?(e)
        # got away, knocked out, or a co-op partner's catch (their name)
        word = case e["end"]
               when "fainted" then _INTL("KNOCKED OUT")
               when "caught" then PF.fit(PF::TINY, e["by"].to_s.upcase, 70)
               else _INTL("GOT AWAY")
               end
        ww = P.width(PF::TINY, word)
        P.text(top, right - ww, y + 4, ww, 14, word, e["end"] == "fainted" ? (c[:red] || c[:dim]) : c[:dim], PF::TINY)
        right -= ww + 6
      end
      name = SL.species_name(e["sp"].to_s.to_sym)
      name = e["nm"].to_s if name.empty?
      P.text(top, 42, y, right - 42, 18, PF.fit(PF::TEXT, name, right - 44), c[:txt], PF::TEXT)
      sub = [SL.date_words(e["t"]), e["pl"].to_s].reject(&:empty?).join(", ")
      P.small(top, 42, y + 16, LX1 - 52, 16, fit_small(top, sub, LX1 - 52), c[:dim])
    end

    def fit_small(b, text, w)
      P.small_font(b)
      return text if b.text_size(text).width <= w
      text = text[0...-1] while text.length > 1 && b.text_size(text + "...").width > w
      return text + "..."
    end

    def earlier_row(top, c, y)
      charm(@charm, 24, y + ROW_H / 2, 0.6)
      P.text(top, 42, y, 120, 18, _INTL("Earlier Shinies"), c[:txt], PF::TEXT)
      P.small(top, 42, y + 16, 140, 16, _INTL("Details Unknown"), c[:dim])
      P.small(top, LX1 - 60, y + 1, 50, 16, "x#{SL.earlier}", gold(c), 1)
    end

    def type_rgb(t)
      return defined?(Reloaded::PartyScreen::TYPE_RGB) && Reloaded::PartyScreen::TYPE_RGB[t] || [150, 160, 175]
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

    def row_words(top, c, x, y, w, label, value, color)
      P.small(top, x, y, w, 18, label, c[:dim])
      P.small(top, x, y, w, 18, fit_small(top, value.to_s, w - 60), color, 1)
    end

    def plate_for(base, top, c, e)
      d = (::GameData::Species.get(e["sp"].to_s.to_sym) rescue nil)
      x0 = PX0
      x1 = PX1
      y0 = PY0
      line_y = y0 + 112
      col = d ? Color.new(*type_rgb(d.type1)) : Color.new(150, 160, 175)
      plate(base, c, col, x0, y0, x1, PB, line_y)
      bx = x0 + 10
      by = y0 + 8
      PP.chamfer_grad(base, bx, by, bx + BOX, by + BOX, 8, mix(c[:dark], c[:panel2], 0.4), c[:dark], mix(c[:line], gold(c), 0.55))
      sprite(e, bx + BOX / 2, by + BOX / 2)
      nx = bx + BOX + 10
      nw = x1 - nx - 10
      name = d ? d.name.to_s : e["nm"].to_s
      P.text(top, nx, y0 + 8, nw, 22, PF.fit(PF::ROW, name, nw), c[:strong], PF::ROW)
      tone = c[SL::ENDING_TONES[e["end"].to_s] || :dim] || c[:dim]
      fill = c[:light] ? mix(c[:panel2], tone, 0.22) : mix(c[:panel2], tone, 0.28)
      P.pill(top, nx, y0 + 34, PF.fit(PF::TINY, SL.ending_words(e), nw - 12), fill, tone, false)
      [d.type1, d.type2].compact.uniq.each_with_index { |ty, i| small_type(top, ty, nx + i * 20, y0 + 56) } if d
      P.small(top, nx, y0 + 76, nw, 16, "Lv #{e['lv'].to_i}", c[:txt])
      sx = x0 + 12
      ww = x1 - x0 - 24
      rows = [[_INTL("Found"), SL.date_words(e["t"], true)], [_INTL("Where"), e["pl"].to_s.empty? ? _INTL("Unknown") : e["pl"].to_s],
              [_INTL("How"), SL.how_words(e)]]
      rows << [_INTL("With"), e["with"].to_s] unless e["with"].to_s.empty?
      if SL.wild_ending?(e)
        rows << [_INTL("Took"), e["took"].nil? ? _INTL("Unknown") : (e["took"].to_i == 1 ? _INTL("1 Encounter") : _INTL("{1} Encounters", SL.num(e["took"])))]
      end
      rows.first(5).each_with_index do |(l, v), i|
        row_words(top, c, sx, line_y + 8 + i * 20, ww, l, v, v == _INTL("Unknown") ? c[:dim] : c[:txt])
      end
    end

    def earlier_plate(base, top, c)
      x0 = PX0
      x1 = PX1
      y0 = PY0
      line_y = y0 + 50
      plate(base, c, GOLD, x0, y0, x1, PB, line_y)
      charm(@big, x0 + 30, y0 + 25, 1)
      P.text(top, x0 + 58, y0 + 4, x1 - x0 - 66, 22, _INTL("Earlier Shinies"), gold(c), PF::ROW)
      n = SL.earlier
      P.text(top, x0 + 58, y0 + 27, 160, 18, n == 1 ? _INTL("1 Shiny") : _INTL("{1} Shinies", n), c[:txt], PF::TEXT)
      sx = x0 + 12
      ww = x1 - x0 - 24
      words = P.small_wrap(top, _INTL("Shinies you met before the Shiny Log started that aren't with you any more. Your Trainer Card counts them; their details weren't kept."), ww)
      words.first(6).each_with_index { |ln, i| P.small(top, sx, line_y + 10 + i * 18, ww, 18, ln, c[:txt]) }
    end

    COLS = [[0, 70], [70, 116], [186, 108]].freeze

    def totals(base, top, c)
      y0 = PB + 6
      PP.chamfer_grad(base, PX0, y0, PX1, BOTTOM, 8, c[:panel2], mix(c[:panel2], c[:dark], 0.3), c[:line])
      P.heading(top, PX0 + 12, PX1 - 12, y0 + 7, _INTL("Your Shinies"), c[:head], c[:line])
      list = SL.entries
      longest = list.map { |e| e["took"].to_i }.max.to_i
      first = list.map { |e| e["t"].to_i }.select { |t| t > 0 }.min
      stats = [[SL.num(SL.count), _INTL("Shinies")], [longest > 0 ? SL.num(longest) : "-", _INTL("Longest Hunt")],
               [first ? SL.date_words(first) : "-", _INTL("First Found")]]
      stats.each_with_index do |(v, l), i|
        x, cw = COLS[i]
        P.text(top, PX0 + x, y0 + 26, cw, 22, v, v == "-" ? c[:dim] : gold(c), PF::ROW, 2)
        P.small(top, PX0 + x, y0 + 50, cw, 16, l, c[:dim], 2)
      end
    end

    def empty(base, top, c)
      P.text(top, LX0, 150, LX1 - LX0, 20, _INTL("No Shinies Yet"), c[:dim], PF::TEXT, 2)
      words = P.small_wrap(top, _INTL("Every shiny you meet goes here, caught or not."), LX1 - LX0 - 24)
      words.each_with_index { |ln, i| P.small(top, LX0 + 12, 174 + i * 18, LX1 - LX0 - 24, 18, ln, c[:dim], 2) }
      plate(base, c, Color.new(150, 160, 175), PX0, PY0, PX1, PB, PY0 + 50)
      totals(base, top, c)
    end

    #--------------------------------------------------------------------------
    # Pictures: the shiny's own (the one owned, or one made from the entry)
    #--------------------------------------------------------------------------
    def pokemon(e)
      (@made ||= {})[e["pid"]] ||= SL.pokemon_for(e)
    end

    # Its icon, as the player's icons show it (Big Icons, KIF's shiny icons)
    def icon(e, cx, cy, box)
      key = e["pid"]
      s = @icons[key]
      unless s
        pk = pokemon(e)
        s = pk ? (Reloaded::PartyIcons.icon(pk, @viewport, 2) rescue nil) : nil
        return unless s
        @icons[key] = s
        (@arts ||= {})[key] = s.bitmap ? Reloaded::PartyIcons.art_rect(s.bitmap, [s.src_rect.height, 1].max) : nil
      end
      r = (@arts || {})[key]
      return unless r
      s.zoom_x = s.zoom_y = box.to_f / [r.width, r.height, 1].max
      s.ox = r.x + r.width / 2
      s.oy = r.y + r.height / 2
      s.x = cx
      s.y = cy
      @shown[key] = true
    end

    # Its battle sprite in its own colours, fitted to the picture's plate
    def sprite(e, cx, cy)
      bm = big_bitmap(e)
      return unless bm
      f = [bm.height, 1].max
      @big.bitmap = bm
      @big.src_rect = Rect.new(0, 0, [f, bm.width].min, f)
      @big.zoom_x = @big.zoom_y = [(BOX - 6).to_f / f, 1.0].min
      @big.ox = [f, bm.width].min / 2
      @big.oy = f / 2
      @big.x = cx
      @big.y = cy
      @big.visible = true
    end

    def big_bitmap(e)
      @bigs ||= {}
      return @bigs[e["pid"]] if @bigs.key?(e["pid"])
      pk = pokemon(e)
      anim = pk && defined?(::GameData::Species) ? (::GameData::Species.sprite_bitmap_from_pokemon(pk) rescue nil) : nil
      (@big_anims ||= []) << anim if anim
      @bigs[e["pid"]] = anim ? (anim.respond_to?(:bitmap) ? anim.bitmap : anim) : nil
    rescue StandardError => err
      Reloaded::Log.warning_once("The Shiny Log couldn't draw a shiny's picture: #{err.message}", :shiny_log)
      @bigs[e["pid"]] = nil
    end

    def charm(spr, cx, cy, zoom)
      bm = pic("Graphics/Items/SHINYCHARM")
      return unless spr && bm
      spr.bitmap = bm
      spr.src_rect = Rect.new(0, 0, bm.width, bm.height)
      spr.zoom_x = spr.zoom_y = zoom
      spr.ox = bm.width / 2
      spr.oy = bm.height / 2
      spr.x = cx
      spr.y = cy
      spr.visible = true
    end
  end
end
