# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Weather Forecast (Weather System)
#==============================================================================
# His pick (2026-11-13, sheets wx-forecast-1/2): Design 1, Forecast, Rebuilt.
#
#   the title bar  the season's chip on the left (its mark and name, not a
#                  button); NOW / NEXT on the right, X beside them
#   the map        the Town Map at 1:1, each place's weather as a 16 px icon
#                  on its tile, your spot marked, the Kanto Reloaded cursor
#                  on the place you're looking at (Johto and the Sevii
#                  Islands once you've been, as the game's Town Map)
#   the plate      lit in the weather's colour: its 32 px icon, the place,
#                  the weather and its strength's word, the red line, a
#                  10-step strength bar; Climate, Trend and Next (Now) or
#                  Climate, Replaces and Starts (Next); the Season; the
#                  types More Common; the place's two Weather Visitors (their
#                  Big Icons once seen in battle, shadows until then); when
#                  it changes
#
# Buttons: the arrows move between places, X Now / Next (the cursor sound),
# Y back to your place, B closes. The mouse: a place or a tab clicked picks
# it, a right click closes.
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont) && defined?(Reloaded::PartyPaint)

module Reloaded
  class WeatherForecastScreen
    include Reloaded::Frame

    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    BOTTOM = H - P::HINT_H - 6
    MX = 10                          # the map's box
    MY = 40
    MW = 286
    MH = BOTTOM - 44
    TILE = 16
    JOHTO_X = 352                    # the Town Map left of this is Johto (PIF's Town Map's line)
    SEVII_Y = 320                    # and below this the Sevii Islands
    PX0 = 306                        # the place's plate
    PX1 = W - 6
    PY0 = 36
    VISIT = 40                       # a Visitor's picture

    def self.open(tab = :now, z = nil)
      screen = new(tab, z)
      if defined?(pbFadeOutIn)
        z ? pbFadeOutIn(z + 1) { screen.main } : pbFadeOutIn { screen.main }
      else
        screen.main
      end
      return screen
    end

    attr_reader :tab, :sel

    def initialize(tab = :now, z = nil)
      frame_init
      @tab = tab == :next ? :next : :now
      @z = z
      @pics = {}
      @mons = {}
      Reloaded::Weather.ensure_started
      @places = visible_places
      @home = home_place
      @sel = @home || @places.keys.first
      @sx = @sy = 0
      center_on(@sel)
    end

    def main
      open_sprites
      @viewport.z = @z if @z
      @visit_sprites = Array.new(2) do
        s = Sprite.new(@viewport)
        s.z = 2
        s.visible = false
        s
      end
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        break if handle_input == :close
      end
      return nil
    ensure
      (@visit_sprites || []).each { |s| s.dispose unless s.disposed? }
      @mons.each_value { |bm, _r| bm.dispose if bm && !bm.disposed? }
      @pics.each_value { |bm| bm.dispose if bm && !bm.disposed? }
      dispose_sprites
    end

    def refresh
      draw if @sprite && !@sprite.disposed?
    end

    private

    #--------------------------------------------------------------------------
    # Places
    #--------------------------------------------------------------------------
    # { key => [tile x, tile y] } for places on the Town Map you can see
    def visible_places
      out = {}
      pl = Reloaded::Weather::Places
      pl.keys.each do |k|
        spot = pl[k].spot
        next unless spot && spot[0].to_i == 0
        x = spot[1].to_i
        y = spot[2].to_i
        next if x * TILE < JOHTO_X && !johto?
        next if y * TILE >= SEVII_Y && !sevii?
        out[k] = [x, y]
      end
      return out
    end

    def visited?(id)
      return defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:visitedMaps) && $PokemonGlobal.visitedMaps[id] ? true : false
    rescue StandardError
      return false
    end

    def johto?
      return visited?(248)                  # Goldenrod's train station (PIF's Town Map)
    end

    def sevii?
      return visited?(762) || visited?(526)  # One Island's road, Knot Island
    end

    # Your place, or the nearest one to your spot on the Town Map
    def home_place
      key = $game_map ? Reloaded::Weather::Places.of_map($game_map.map_id) : nil
      return key if key && @places[key]
      spot = player_spot
      return nil unless spot
      return @places.min_by { |_k, (x, y)| (x - spot[0]) ** 2 + (y - spot[1]) ** 2 }&.first
    end

    # Your spot on the Town Map (the map's own, else the last town you were in)
    def player_spot
      return @player_spot if defined?(@player_spot)
      @player_spot = nil
      meta = $game_map ? (::GameData::MapMetadata.try_get($game_map.map_id) rescue nil) : nil
      pos = meta && meta.respond_to?(:town_map_position) ? meta.town_map_position : nil
      @player_spot = [pos[1].to_i, pos[2].to_i] if pos && pos[0].to_i == 0
      if !@player_spot && defined?($Trainer) && $Trainer.respond_to?(:last_visited_town_map_location)
        last = $Trainer.last_visited_town_map_location
        m = last ? (::GameData::MapMetadata.try_get(last) rescue nil) : nil
        pos = m && m.respond_to?(:town_map_position) ? m.town_map_position : nil
        @player_spot = [pos[1].to_i, pos[2].to_i] if pos
      end
      return @player_spot
    rescue StandardError
      return nil
    end

    # The nearest place that way (a wide cone, straight ahead counting most)
    def neighbour(dx, dy)
      from = @places[@sel]
      return nil unless from
      best = nil
      score = nil
      @places.each do |k, (x, y)|
        next if k == @sel
        ax = x - from[0]
        ay = y - from[1]
        along = ax * dx + ay * dy
        next unless along > 0
        off = (ax * dy - ay * dx).abs
        next if off > along * 2
        s = along + off * 2
        if score.nil? || s < score
          best = k
          score = s
        end
      end
      return best
    end

    def center_on(key)
      spot = @places[key]
      return unless spot
      @sx = spot[0] * TILE + TILE / 2 - MW / 2
      @sy = spot[1] * TILE + TILE / 2 - MH / 2
      clamp_view
    end

    # Keeps the place in view (a margin of a tile and a half)
    def follow(key)
      spot = @places[key]
      return unless spot
      px = spot[0] * TILE
      py = spot[1] * TILE
      m = 24
      @sx = px - m if px - m < @sx
      @sx = px + TILE + m - MW if px + TILE + m > @sx + MW
      @sy = py - m if py - m < @sy
      @sy = py + TILE + m - MH if py + TILE + m > @sy + MH
      clamp_view
    end

    def clamp_view
      map = map_picture
      mw = map ? map.width : 820
      mh = map ? map.height : 628
      x0 = johto? ? 0 : JOHTO_X
      y1 = sevii? ? mh : [SEVII_Y, MH].max
      @sx = [[@sx, mw - MW].min, x0].max
      @sy = [[@sy, y1 - MH].min, 0].max
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      handled, result = mouse_input
      return result if handled
      if Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        return :close
      elsif Input.trigger?(Input::X)
        flip_tab
      elsif Input.trigger?(Input::Y)
        recenter
      elsif Input.repeat?(Input::UP) then step(0, -1)
      elsif Input.repeat?(Input::DOWN) then step(0, 1)
      elsif Input.repeat?(Input::LEFT) then step(-1, 0)
      elsif Input.repeat?(Input::RIGHT) then step(1, 0)
      end
      return nil
    end

    def step(dx, dy)
      k = neighbour(dx, dy)
      return unless k
      select(k)
    end

    def select(k)
      return if k == @sel
      @sel = k
      follow(k)
      pbPlayCursorSE
      refresh
    end

    def flip_tab
      @tab = @tab == :now ? :next : :now
      pbPlayCursorSE
      refresh
      return nil
    end

    def recenter
      return nil unless @home
      @sel = @home
      center_on(@home)
      pbPlayCursorSE
      refresh
      return nil
    end

    def mouse_input
      pt = Reloaded::Pointer
      return [true, close_now] if pt.right?
      return [false, nil] unless pt.left?
      handled, result = hint_click
      return [true, result] if handled
      if (t = pt.hit(@tab_hits || []))
        flip_tab if t != @tab
      elsif (k = pt.hit(@place_hits || []))
        select(k)
      end
      return [true, nil]
    end

    def close_now
      pbPlayCloseMenuSE
      return :close
    end

    def hint_pairs
      [[:ud, ""], [:lr, _INTL("Move")], [button(:X), @tab == :now ? _INTL("Next") : _INTL("Now"), :flip_tab],
       [button(:Y), _INTL("Recenter"), :recenter], [button(:B), _INTL("Close"), :close_now]]
    end

    #--------------------------------------------------------------------------
    # Drawing
    #--------------------------------------------------------------------------
    def pic(path)
      return @pics[path] if @pics.key?(path)
      @pics[path] = (Bitmap.new(path) rescue nil)
    end

    def map_picture
      post = defined?(isPostgame?) && (isPostgame? rescue false)
      return pic(post ? "Graphics/Pictures/map/map_postgame" : "Graphics/Pictures/map/map")
    end

    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    def which
      return @tab == :now ? "now" : "next"
    end

    def ink(c, type)
      return PP.ink(c, Reloaded::Weather::Display.rgb(type))
    end

    def draw
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      header(base, top, c)
      PP.chamfer_grad(base, 6, 36, 300, BOTTOM, 8, c[:panel2], mix(c[:panel2], c[:dark], 0.3), c[:line])
      town_map(base, top, c)
      place_plate(base, top, c)
      paint_hints(base, c)
      place_cursor
    end

    def header(base, top, c)
      ds = Reloaded::Weather::Display
      PP.paint_background(base, c)
      PP.paint_title(top, c, _INTL("Weather Forecast"))
      # the season (not a button)
      label = ds.season_name.upcase
      rgb = ds.season_rgb
      col = Color.new(*rgb)
      w = P.width(PF::TINY, label) + 26
      PP.chamfer_grad(base, 8, 6, 8 + w, 24, 5, mix(c[:panel2], col, 0.35), mix(c[:panel2], col, 0.18), mix(c[:line], col, 0.5))
      PP.pixels(top, ds.season_mark, 14, 10, col)
      P.text(top, 26, 8, w - 20, 14, label, PP.ink(c, rgb), PF::TINY)
      # Now / Next, X beside them
      x1 = W - 8
      tabs = [[_INTL("NOW"), :now], [_INTL("NEXT"), :next]]
      widths = tabs.map { |l, _k| P.width(PF::TINY, l) + 16 }
      x0 = x1 - widths.sum - 2
      x = x0
      @tab_hits = []
      tabs.each_with_index do |(l, k), i|
        on = k == @tab
        PP.chamfer_grad(base, x, 6, x + widths[i], 24, 5, on ? mix(c[:panel2], c[:selb], 0.62) : c[:panel2],
                        on ? mix(c[:panel2], c[:selb], 0.4) : c[:panel2], on ? c[:selb] : c[:line])
        P.text(top, x, 8, widths[i], 14, l, on ? c[:strong] : c[:dim], PF::TINY, 2)
        @tab_hits << [k, x, 6, x + widths[i], 24]
        x += widths[i] + 2
      end
      key = button(:X)
      style = Reloaded::Prompts.style
      Reloaded::ButtonIcons.draw(top, x0 - 4 - Reloaded::ButtonIcons.width(key, style, 18), 6, key, c, style, 18)
    end

    # The Town Map in its box, the weather on each place's tile and your
    # spot, all on the panels' layer (the cursor goes over them)
    def town_map(base, top, c)
      ds = Reloaded::Weather::Display
      base.fill_rect(MX, MY, MW, MH, Color.new(60, 166, 190))
      m = map_picture
      if m
        vw = [MW, m.width - @sx].min
        vh = [MH, m.height - @sy].min
        base.blt(MX, MY, m, Rect.new(@sx, @sy, vw, vh))
      end
      @place_hits = []
      @places.each do |k, (tx, ty)|
        px = MX + tx * TILE - @sx
        py = MY + ty * TILE - @sy
        next if px < MX || py < MY || px + TILE > MX + MW || py + TILE > MY + MH
        @place_hits << [k, px, py, px + TILE - 1, py + TILE - 1]
        type, n = ds.shown(k, which)
        next if type == :None
        ic = pic(ds.icon(type, n))
        base.stretch_blt(Rect.new(px, py, TILE, TILE), ic, Rect.new(0, 0, ic.height, ic.height)) if ic
      end
      spot = player_spot
      if spot
        hx = MX + spot[0] * TILE - @sx
        hy = MY + spot[1] * TILE - @sy
        head = pic("Graphics/Pictures/map/location_icon")
        if head && hx - 6 >= MX && hy - 6 >= MY && hx + 22 <= MX + MW && hy + 22 <= MY + MH
          base.blt(hx - 6, hy - 6, head, Rect.new(0, 0, head.width, head.height))
        end
      end
      sel = @places[@sel]
      if sel
        cx = MX + sel[0] * TILE - @sx
        cy = MY + sel[1] * TILE - @sy
        @cursor_rect = [cx - 4, cy - 4, TILE + 8, TILE + 8]
      else
        @cursor_rect = nil
      end
    end

    # Battle Records' plate, in the weather's colour
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

    def bar(base, c, x, y, w, n, color, segs = 10, h = 6)
      gap = 2
      sw = (w - gap * (segs - 1)) / segs
      segs.times { |i| base.fill_rect(x + i * (sw + gap), y, sw, h, i < n ? color : mix(c[:dark], c[:line], 0.4)) }
    end

    def row(top, c, x, y, w, label, value, color)
      P.small(top, x, y, w, 18, label, c[:dim])
      P.small(top, x, y, w, 18, value, color, 1)
    end

    # Rising, Fading or Steady: now against next
    def trend(c, now, nxt)
      ds = Reloaded::Weather::Display
      t0, n0 = now
      t1, n1 = nxt
      return [_INTL("Steady"), c[:txt]] if t0 == :None && t1 == :None
      return [_INTL("Rising"), c[:green]] if t0 == :None
      return [_INTL("Fading"), c[:amber] || c[:gold]] if ds.base(t0) != ds.base(t1)
      return [_INTL("Rising"), c[:green]] if n1 > n0
      return [_INTL("Fading"), c[:amber] || c[:gold]] if n1 < n0
      return [_INTL("Steady"), c[:txt]]
    end

    def place_plate(base, top, c)
      ds = Reloaded::Weather::Display
      pl = Reloaded::Weather::Places[@sel]
      @visit_sprites.each { |s| s.visible = false }
      return unless pl
      now = ds.shown(@sel, "now")
      nxt = ds.shown(@sel, "next")
      type, n = @tab == :now ? now : nxt
      x0 = PX0
      x1 = PX1
      y0 = PY0
      line_y = y0 + 50
      plate(base, c, ds.colour(type), x0, y0, x1, BOTTOM, line_y)
      ic = pic(ds.icon(type, n))
      top.blt(x0 + 10, y0 + 8, ic, Rect.new(0, 0, 32, 32)) if ic
      P.text(top, x0 + 48, y0 + 4, x1 - x0 - 56, 22, PF.fit(PF::ROW, pl.name, x1 - x0 - 56), c[:strong], PF::ROW)
      w = P.text(top, x0 + 48, y0 + 27, 110, 18, ds.name(type), ink(c, type), PF::TEXT)
      P.small(top, x0 + 54 + w, y0 + 28, x1 - x0 - 62 - w, 18, ds.strength_word(type, n), c[:txt])
      sx = x0 + 12
      w = x1 - x0 - 24
      bar(base, c, sx, line_y + 8, w, type == :None || type == :Rainbow ? 0 : n, ds.colour(type))
      y = line_y + 20
      soon = ds.in_words
      row(top, c, sx, y, w, _INTL("Climate"), _INTL(pl.climate.to_s), c[:txt])
      if @tab == :now
        tw, tc = trend(c, now, nxt)
        row(top, c, sx, y + 18, w, _INTL("Trend"), tw, tc)
        row(top, c, sx, y + 36, w, _INTL("Next"), _INTL("{1}, in {2}", ds.name(nxt[0]), soon), ink(c, nxt[0]))
      else
        row(top, c, sx, y + 18, w, _INTL("Replaces"), ds.name(now[0]), ink(c, now[0]))
        row(top, c, sx, y + 36, w, _INTL("Starts"), _INTL("In {1}", soon), c[:txt])
      end
      row(top, c, sx, y + 54, w, _INTL("Season"), ds.season_name, PP.ink(c, ds.season_rgb))
      more_common(top, c, sx, y + 78, w, type)
      visitors(base, top, c, sx, y + 120, w, type)
      base.fill_rect(sx, BOTTOM - 26, w, 1, c[:line])
      when_words = @tab == :now ? _INTL("Changes in {1}", soon) : _INTL("Starts in {1}", soon)
      P.small(top, sx, BOTTOM - 22, w, 18, when_words, c[:dim], 2)
    end

    def small_type(b, type, x, y)
      sheet = pic(PP::TYPES_SMALL)
      b.blt(x, y, sheet, Rect.new(0, PP.type_row(type) * 16, 16, 16)) if sheet
    end

    def more_common(top, c, x, y, w, type)
      P.heading(top, x, x + w, y, _INTL("More Common"), c[:head], c[:line])
      types = type == :None || type == :Rainbow ? [] : Reloaded::Weather::Encounters.more_types(Reloaded::Weather::Display.base(type))
      if types.empty?
        P.small(top, x, y + 15, w, 18, _INTL("Nothing Extra"), c[:dim])
        return
      end
      tx = x
      types.each do |t|
        small_type(top, t, tx, y + 16)
        label = (::GameData::Type.get(t).name rescue t.to_s.capitalize)
        tx += 18 + P.small(top, tx + 18, y + 15, 90, 18, label, c[:txt]) + 8
      end
    end

    # The place's two Visitors in this weather (grass, else water)
    def visitors(base, top, c, x, y, w, type)
      P.heading(top, x, x + w, y, _INTL("Weather Visitors"), c[:head], c[:line])
      en = Reloaded::Weather::Encounters
      list = []
      if type != :None && type != :Rainbow
        list = en.visitors(@sel, type, :land)
        list = en.visitors(@sel, type, :water) if list.empty?
      end
      if list.empty?
        words = type == :None || type == :Rainbow ? _INTL("None in Clear Weather") : _INTL("None Here")
        P.small(top, x, y + 15, w, 18, words, c[:dim])
        return
      end
      size = VISIT
      bw = (w - 6) / 2
      list.first(2).each_with_index do |sp, i|
        bx = x + i * (bw + 6)
        PP.chamfer_grad(base, bx, y + 15, bx + bw, y + 15 + size + 16, 6, mix(c[:panel2], c[:selb], 0.22), mix(c[:panel2], c[:selb], 0.1), c[:line])
        seen = en.seen?(sp)
        mon(@visit_sprites[i], sp, bx + bw / 2, y + 15 + size / 2, size - 2, !seen)
        name = seen ? (::GameData::Species.get(sp).name.to_s.upcase rescue sp.to_s) : "???"
        P.text(top, bx, y + 15 + size, bw, 14, PF.fit(PF::TINY, name, bw - 4), seen ? c[:txt] : c[:dim], PF::TINY, 2)
      end
    end

    # A Visitor's picture: its Big Icon (or small icon, as the player has
    # it) fitted to its box, a dark shadow until it's been seen
    def mon(spr, sp, cx, cy, size, shadow)
      unless @mons.key?(sp)
        bm = (Reloaded::PartyIcons.species_bitmap(sp) rescue nil)
        @mons[sp] = [bm, bm ? Reloaded::PartyIcons.art_rect(bm, [bm.height, 1].max) : nil]
      end
      bm, r = @mons[sp]
      return unless bm && r && spr
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
