# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Effectiveness on PIF's own Fight menu and target window
#==============================================================================
# His picks (2026-11-05; sheets pif-eff-designs, pif-eff-targets), the EBDX
# version's pieces on the screen PIF draws when EBDX's battles are Off:
#
#   the cursor     PIF's own picked-move button (cursor_fight.png, its right
#                  half for the move's type) recoloured in the move's colour:
#                  its band the colour, its frame a deeper shade of it, the
#                  white kept. A move that does the usual damage keeps PIF's
#   multiplier     the Colour Pill inside the picked move at its right end,
#                  where the dots sit on the others (his pick, 2026-11-05:
#                  under the PP it was pressed against the PP and the frame)
#   move dots      a dot in its colour on each move not picked (x 172, y 22
#                  on the button); none for neutral and status moves
#   ally warning   the "!" at the picked move's left end when it would hurt
#                  your partner (his pick: the left, clear of the pill)
#   target pills   Double Battles: each target's name above the picked
#                  move, 25 px over it
#   target window  each picked button (cursor_target.png's right half) in
#                  its target's colour: its frame the colour, its fill a
#                  lighter shade. Buttons not picked stay as PIF draws them
#
# The recoloured pictures take the place of PIF's on the picked button
# (Sprite#bitmap), PIF's own put back for the moment PIF reads a move
# name's colour from it (refreshButtonNames) and whenever nothing shows.
# The pills, dots and "!" are on one picture over the menu, redrawn when
# the pick changes; the moves are worked out when the Fight menu opens and
# when a button like Mega Evolution is pressed.
#==============================================================================

module Reloaded
  module MoveEffectiveness
    #--------------------------------------------------------------------------
    # PIF's pictures recoloured (the rules drawn on his sheets: scratchpad
    # recolour_cursor.py and recolour_target.py), kept for the session
    #--------------------------------------------------------------------------
    module Recolour
      LIMIT = 64                     # pictures kept before the list starts again
      WHITE = [255, 255, 255].freeze
      DEEP = 0.72                    # the cursor's frame: the colour this deep
      FILL = 0.22                    # a picked target's fill: the colour this much paler
      @cache = {}

      class << self
        # PIF's picked-move button (src's x, y, w, h) in col: each tone
        # between the frame's (the darkest) and the band's keeps its place
        # from the deeper shade to the colour, lighter ones go from the
        # colour towards white, white stays
        def move_cursor(src, x, y, w, h, col)
          return cached([:move, x, y, w, h], src, col) { make(src, x, y, w, h) { |px| cursor_map(px, col) } }
        end

        # PIF's picked target button in col: its frame the colour, its fill
        # a lighter shade, white stays
        def target_button(src, x, y, w, h, col)
          return cached([:target, x, y, w, h], src, col) { make(src, x, y, w, h) { |px| target_map(px, col) } }
        end

        # The pictures made so far are let go (a sprite still showing one
        # keeps it until it's done)
        def clear
          @cache = {}
        end

        def size
          return @cache.length
        end

        private

        def cached(where, src, col)
          key = where + [src.width, src.height, col.red.to_i, col.green.to_i, col.blue.to_i, dark?]
          pic = @cache[key]
          return pic if pic && !pic.disposed?
          @cache = {} if @cache.length >= LIMIT
          return @cache[key] = yield
        end

        # PIF's Dark Mode loads its own pictures when a game has them
        def dark?
          return respond_to?(:isDarkMode, true) && isDarkMode ? true : false
        rescue StandardError
          return false
        end

        # A copy of src's part, its coloured pixels changed through the map
        # the block makes from every pixel ([x, y, r, g, b, a], alpha > 0)
        def make(src, x, y, w, h)
          out = Bitmap.new(w, h)
          out.blt(0, 0, src, Rect.new(x, y, w, h))
          px = []
          h.times do |yy|
            w.times do |xx|
              c = out.get_pixel(xx, yy)
              px << [xx, yy, c.red.to_i, c.green.to_i, c.blue.to_i, c.alpha.to_i] if c.alpha > 0
            end
          end
          map = yield(px)
          made = {}
          px.each do |xx, yy, r, g, b, a|
            rgb = map[[r, g, b]]
            next unless rgb
            out.set_pixel(xx, yy, (made[[rgb, a]] ||= Color.new(rgb[0], rgb[1], rgb[2], a)))
          end
          return out
        end

        def cursor_map(px, col)
          solid = px.select { |p| p[5] > 200 && !whiteish?(p[2], p[3], p[4]) }
          return {} if solid.empty?
          dark = solid.map { |p| lum(p[2], p[3], p[4]) }.min
          span = [248 - dark, 1.0].max
          # the band: the most common tone lighter than the frame (PIF: a
          # vivid light tone of the type); it takes the colour itself
          counts = Hash.new(0)
          solid.each { |p| counts[[p[2], p[3], p[4]]] += 1 if (lum(p[2], p[3], p[4]) - dark) / span > 0.35 }
          band = counts.max_by { |_k, n| n }
          tb = band ? (lum(*band[0]) - dark) / span : 0.75
          tb = [[tb, 0.05].max, 0.95].min
          c = rgb(col)
          deep = c.map { |v| (v * DEEP).round }
          map = {}
          px.each do |p|
            key = [p[2], p[3], p[4]]
            next if map.key?(key) || whiteish?(*key)
            t = [[(lum(*key) - dark) / span, 0.0].max, 1.0].min
            map[key] = t <= tb ? mix(deep, c, t / tb) : mix(c, WHITE, (t - tb) / (1 - tb))
          end
          return map
        end

        def target_map(px, col)
          tones = px.reject { |p| whiteish?(p[2], p[3], p[4]) }
          return {} if tones.empty?
          ls = tones.map { |p| lum(p[2], p[3], p[4]) }
          lo = ls.min
          range = [ls.max - lo, 1.0].max
          c = rgb(col)
          fill = mix(c, WHITE, FILL)
          map = {}
          tones.each do |p|
            key = [p[2], p[3], p[4]]
            next if map.key?(key)
            map[key] = (lum(*key) - lo) / range < 0.5 ? c : fill
          end
          return map
        end

        def lum(r, g, b)
          return 0.3 * r + 0.59 * g + 0.11 * b
        end

        def whiteish?(r, g, b)
          lo, hi = [r, g, b].minmax
          return lo >= 236 && hi - lo <= 12
        end

        def rgb(col)
          return [col.red.to_i, col.green.to_i, col.blue.to_i]
        end

        def mix(a, b, t)
          return (0..2).map { |i| (a[i] + (b[i] - a[i]) * t).round }
        end
      end
    end

    # A sprite's picture and the part of it shown (assigning a picture
    # resets the part, so it's set again in full)
    def self.show_picture(spr, pic, x, y, w, h)
      spr.bitmap = pic unless spr.bitmap.equal?(pic)
      r = spr.src_rect
      r.x = x
      r.y = y
      r.width = w
      r.height = h
    end

    #--------------------------------------------------------------------------
    # PIF's Fight menu (FightMenuDisplay): what one menu shows
    #--------------------------------------------------------------------------
    class PifFight
      include Paint
      RISE = 32                      # the picture starts this far above the menu (the targets' pills)
      MARK = [172, 22]               # the dot on a button
      WARN_X = 20                    # the "!" on the picked button: its left end (the dot's place mirrored)
      PILL_RIGHT = 12                # the pill on the picked button: its right edge this far in
      PILL_TOP = 13                  # ... and its top (centred on the dot's row)
      PILL_RISE = 25                 # the targets' pills above the picked button
      PILL_LEFT = 6
      SPRITE = "kr_effectiveness"

      def initialize(win)
        @win = win
        buttons = win.instance_variable_get(:@buttons)
        vp = buttons && buttons[0] ? buttons[0].viewport : nil
        @overlay = Sprite.new(vp)
        @overlay.bitmap = Bitmap.new(Graphics.width, Graphics.height - win.y + RISE)
        @overlay.x = win.x
        @overlay.y = win.y - RISE
        @overlay.z = win.z + 7         # over PIF's names (+5) and box (+6)
        win.addSprite(SPRITE, @overlay)
        @overlay.visible = win.visible
        @rows = []
        @sums = []
        @colours = []
        @stale = true
      end

      # The Fight menu opened (or its Pokémon changed): worked out again on
      # the next refresh
      def stale!
        @stale = true
      end

      # PIF set its buttons for the pick (refreshSelection): worked out if
      # needed, then drawn
      def refresh
        me = Reloaded::MoveEffectiveness
        build if @stale || me.changes_key(@win) != @changes
        draw
      end

      # The picked button shows PIF's own picture (while PIF reads a name's
      # colour from it), then the recoloured one again
      def swapped?
        return !@swap.nil?
      end

      def unswap
        spr, x, y, w, h = @swap
        Reloaded::MoveEffectiveness.show_picture(spr, pif_bitmap, x, y, w, h) if spr && !spr.disposed?
      end

      def swap
        spr, _x, _y, w, h, pic = @swap
        Reloaded::MoveEffectiveness.show_picture(spr, pic, 0, 0, w, h) if spr && !spr.disposed? && !pic.disposed?
      end

      def dispose
        unswap if @swap
        @swap = nil
        clear_rows
        sprites = @win.instance_variable_get(:@sprites)
        sprites.delete(SPRITE) if sprites.is_a?(Hash)
        vis = @win.instance_variable_get(:@visibility)
        vis.delete(SPRITE) if vis.is_a?(Hash)
        unless @overlay.disposed?
          @overlay.bitmap.dispose if @overlay.bitmap && !@overlay.bitmap.disposed?
          @overlay.dispose
        end
      end

      private

      def pif_bitmap
        return @win.instance_variable_get(:@buttonBitmap).bitmap
      end

      # Each move against its targets, with your Pokémon as the Fight menu's
      # buttons would make it (Mega Evolution pressed: MoveEffectiveness.user)
      def build
        clear_rows
        me = Reloaded::MoveEffectiveness
        battler = @win.battler
        battle = battler.battle
        @pills = me.setting?(PILLS) && (battle.pbSideSize(0) > 1 || battle.pbSideSize(1) > 1)
        @warning = me.setting?(WARNING)
        u = me.user(@win, battler)
        battler.moves.each_with_index do |move, i|
          next unless move
          s = Reloaded::Matchup.summary(battle, battler, move, u)
          @sums[i] = s
          @colours[i] = s[:best].nil? ? nil : me.level_colour(s[:best])
          @rows[i] = pill_row(s) if @pills
        end
        @changes = me.changes_key(@win)
        @stale = false
      end

      def clear_rows
        @rows.each { |b| b.dispose if b && !b.disposed? }
        @rows = []
        @sums = []
        @colours = []
      end

      def draw
        me = Reloaded::MoveEffectiveness
        b = @overlay.bitmap
        b.clear
        buttons = @win.instance_variable_get(:@buttons)
        vis = @win.instance_variable_get(:@visibility) || {}
        moves = @win.battler.moves
        pic = pif_bitmap
        @swap = nil
        buttons.each_with_index do |spr, i|
          next unless spr && !spr.disposed?
          r = spr.src_rect
          place = [r.x, r.y, r.width, r.height]
          me.show_picture(spr, pic, *place) unless spr.bitmap.equal?(pic)
          s = @sums[i]
          next unless s && moves[i] && vis["button_#{i}"]
          col = @colours[i]
          bx = spr.x - @overlay.x
          by = spr.y - @overlay.y
          if i == @win.index
            if col
              @swap = [spr] + place + [Recolour.move_cursor(pic, *place, col)]
              swap
              if me.setting?(MULTIPLIER)
                w = pill_width(s[:best])
                pill(b, bx + r.width - PILL_RIGHT - w, by + PILL_TOP, s[:best], col)
              end
            end
            warn_mark(b, bx + WARN_X, by + MARK[1]) if @warning && s[:warn]
            row = @rows[i]
            b.blt([[bx + PILL_LEFT, 2].max, b.width - 2 - row.width].min, by - PILL_RISE, row, row.rect) if row
          elsif col && me.setting?(DOTS) && !moves[i].statusMove?
            dot(b, bx + MARK[0], by + MARK[1], col)
          end
        end
      end
    end

    #--------------------------------------------------------------------------
    # PIF's target window (TargetMenuDisplay): each picked button in its
    # target's colour
    #--------------------------------------------------------------------------
    module PifTargets
      class << self
        # PIF set its buttons for the pick (refreshButtons): the picked ones
        # with a colour get theirs, the rest PIF's own
        def paint(win)
          me = Reloaded::MoveEffectiveness
          buttons = win.instance_variable_get(:@buttons)
          ab = win.instance_variable_get(:@buttonBitmap)
          return unless buttons && ab
          pic = ab.bitmap
          battle = me.aiming
          cols = me.on? && battle ? me.target_colours_for(battle) : nil
          texts = win.instance_variable_get(:@texts) || []
          mode = win.instance_variable_get(:@mode)
          buttons.each_with_index do |spr, i|
            next unless spr && !spr.disposed?
            r = spr.src_rect
            place = [r.x, r.y, r.width, r.height]
            col = cols && cols[i]
            sel = texts[i] && ((mode == 0 && i == win.index) || mode == 1)
            if sel && col
              me.show_picture(spr, Recolour.target_button(pic, *place, col), 0, 0, place[2], place[3])
            elsif !spr.bitmap.equal?(pic)
              me.show_picture(spr, pic, *place)
            end
          end
        rescue StandardError => e
          Reloaded::Log.exception("Effectiveness: PIF's target window", e, FEATURE)
        end
      end
    end

    #--------------------------------------------------------------------------
    # The hooks
    #--------------------------------------------------------------------------
    module PifFightHooks
      def battler=(value)
        @kr_effect.stale! if @kr_effect
        super
      end

      def refreshSelection(*args)
        ret = super
        kr_effect_refresh
        return ret
      end

      # PIF takes each move name's colour from its button's picture: its
      # own, not the recoloured one
      def refreshButtonNames(*args)
        fx = @kr_effect
        return super unless fx && fx.swapped?
        fx.unswap
        begin
          return super
        ensure
          fx.swap
        end
      end

      def dispose(*args)
        kr_effect_drop
        super
      end

      private

      def kr_effect_refresh
        me = Reloaded::MoveEffectiveness
        unless me.on? && ::FightMenuDisplay::USE_GRAPHICS && @battler && @buttons && @buttonBitmap
          kr_effect_drop
          return
        end
        @kr_effect ||= Reloaded::MoveEffectiveness::PifFight.new(self)
        @kr_effect.refresh
      rescue StandardError => e
        # PIF's Fight menu goes on as it is
        Reloaded::Log.exception("Effectiveness: PIF's Fight menu", e, Reloaded::MoveEffectiveness::FEATURE)
        kr_effect_drop
      end

      def kr_effect_drop
        return unless @kr_effect
        fx = @kr_effect
        @kr_effect = nil
        fx.dispose
      rescue StandardError => e
        Reloaded::Log.exception("Effectiveness: PIF's Fight menu's end", e, Reloaded::MoveEffectiveness::FEATURE)
      end
    end

    module PifTargetHooks
      def refreshButtons(*args)
        ret = super
        Reloaded::MoveEffectiveness::PifTargets.paint(self)
        return ret
      end
    end
  end
end
