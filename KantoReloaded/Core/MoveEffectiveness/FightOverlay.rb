# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Effectiveness (EBDX) on EBDX's Fight menu
#==============================================================================
# What one Fight menu shows (his picks, 2026-10-30; sheets move-eff-round3,
# -dots2, -colours): made in FightWindowEBDX#generateButtons, after EBDX
# draws its buttons. Each button's picture holds both its halves (EBDX
# shows the left one while the move is picked, the right one when not):
#
#   picked half    the Colour Pill in the 33 px between the category icon
#                  and the PP (y 47), the "!" inside the frame's top right
#                  (184, 13) when your partner would be hurt
#   other half     the dot under where the "!" sits (184, 29), r 4 with a
#                  dark edge; none for neutral and status moves
#   pills          Double Battles: one row per move (each target's name,
#                  outlined in its colour), above the picked move
#
# A button picture that isn't EBDX's own size (a metric's other graphics)
# gets nothing drawn in it; the ring and pills still show.
#==============================================================================

module Reloaded
  module MoveEffectiveness
    class FightOverlay
      P = Reloaded::Pixel
      PF = ::KIF::PixelFont
      PP = Reloaded::PartyPaint
      HALF = 198                       # a button half's width (EBDX: Bitmap.new(198 * 2, 74))
      BUTTON_H = 74
      PILL_X = 105                     # the category icon's right edge (65 + 38) + 2
      PP_RIGHT = 191                   # EBDX's PP: right-aligned in 0...191
      PILL_Y = 47
      PILL_H = 19
      MARK = [184, 13]                 # the "!", inside the picked half's frame
      DOT = [HALF + 184, 29]           # the dot, under it on the other half
      EDGE = Color.new(20, 22, 28)
      WHITE = Color.new(255, 255, 255)
      BLACK = Color.new(0, 0, 0)
      PILL_ROW_H = 19
      PILL_GAP = 4
      PILL_RISE = 25                   # the pills' row above the picked button's top, clear of the ring's glow

      def initialize(viewport)
        @viewport = viewport
        @right = (viewport.respond_to?(:rect) ? viewport.rect.width : 512) - 2
        @row = Sprite.new(viewport)
        @row.z = 200
        @row.visible = false
        @rows = []
        @colours = []
        @buttons = []
        @bounds = []
      end

      # The menu's moves worked out and drawn. false: nothing to show (it
      # failed, logged)
      def build(win)
        clear
        battle = win.instance_variable_get(:@battle)
        battler = win.instance_variable_get(:@battler)
        buttons = win.instance_variable_get(:@button)
        return false unless battle && battler && buttons
        me = Reloaded::MoveEffectiveness
        @pills = me.setting?(PILLS) && (battle.pbSideSize(0) > 1 || battle.pbSideSize(1) > 1)
        @warning = me.setting?(WARNING)
        u = battler.dup
        win.instance_variable_get(:@nummoves).to_i.times do |i|
          spr = buttons["#{i}"]
          move = battler.moves[i]
          next unless spr && move && !spr.disposed?
          @buttons[i] = spr
          s = Reloaded::Matchup.summary(battle, battler, move, u)
          @colours[i] = me.level_colour(s[:best]) unless s[:best].nil?
          draw_button(spr.bitmap, move, s, me) if spr.bitmap.width == HALF * 2 && spr.bitmap.height == BUTTON_H
          @rows[i] = pill_row(s) if @pills
        end
        @index = nil
        return true
      rescue StandardError => e
        Reloaded::Log.exception("Effectiveness (EBDX): the Fight menu couldn't be worked out", e, FEATURE)
        clear
        return false
      end

      # A new pick: the ring in its colour (nil: Cursor Color), its pills
      def pick(index, ring)
        return if index == @index || @broken || @row.disposed?
        @index = index
        ring.colour = @colours[index] if ring.respond_to?(:colour=)
        @row.bitmap = @rows[index]
        @row.visible = false
      rescue StandardError => e
        broken(e)
      end

      # The pills follow the picked button (EBDX lifts it)
      def follow(index)
        return if @broken || @row.disposed?
        bm = @rows[index]
        spr = @buttons[index]
        return @row.visible = false if bm.nil? || spr.nil? || spr.disposed? || !spr.visible || spr.bitmap.disposed?
        bx, by = (@bounds[index] ||= Reloaded::BattleCursor.solid(spr.bitmap, 0, 0, HALF, BUTTON_H))
        x = spr.x - spr.ox + bx + 2
        x = @right - bm.width if x + bm.width > @right
        x = 2 if x < 2
        @row.x = x
        @row.y = spr.y - spr.oy + by - PILL_RISE
        @row.visible = true
      rescue StandardError => e
        broken(e)
      end

      # Something went wrong mid-menu: the pills hide until the next Fight
      # menu, the battle goes on (logged once)
      def broken(e)
        @broken = true
        hide
        Reloaded::Log.exception("Effectiveness (EBDX): the Fight menu's targets", e, FEATURE)
      end

      def hide
        @row.visible = false unless @row.disposed?
      end

      def clear
        @rows.each { |b| b.dispose if b && !b.disposed? }
        @rows = []
        @colours = []
        @buttons = []
        @bounds = []
        @index = nil
        @broken = false
        @row.bitmap = nil unless @row.disposed?
        hide
      end

      def dispose
        clear
        @row.dispose unless @row.disposed?
      end

      private

      #------------------------------------------------------------------------
      # Into the button's picture
      #------------------------------------------------------------------------
      def draw_button(b, move, s, me)
        val = s[:best]
        col = val.nil? ? nil : me.level_colour(val)
        if col && me.setting?(MULTIPLIER)
          room = PP_RIGHT - pp_width(b, move) - 3 - PILL_X
          w = pill_width(val)
          pill(b, PILL_X + [(room - w) / 2, 0].max, PILL_Y, val, col)
        end
        warn_mark(b, *MARK) if @warning && s[:warn]
        if col && me.setting?(DOTS) && !move.statusMove?
          PP.disc(b, DOT[0], DOT[1], 5, EDGE)
          PP.disc(b, DOT[0], DOT[1], 4, col)
        end
      end

      # EBDX's PP words in its small font
      def pp_width(b, move)
        pbSetSmallFont(b)
        w = b.text_size("#{move.pp}/#{move.total_pp}").width
        pbSetSystemFont(b)
        return w
      end

      # The Colour Pill: the colour, the words in a deeper or paler tone of
      # it (Battle Scene's picked command words, CommandRow#picked_ink)
      def pill(b, x, y, val, col)
        P.ui.rbox(b, x, y, x + pill_width(val), y + PILL_H, 5, col)
        words(b, x + 4, y, val, on_tone(col))
      end

      def pill_width(val)
        return words_width(val) + 8
      end

      # x4, x2, x0 in the text font; x1/2 and x1/4 as an "x" and a small
      # stacked fraction (the words don't fit the 33 px)
      def words(b, x, y, val, ink)
        den = fraction(val)
        unless den
          P.text(b, x, y - 1, words_width(val) + 2, PILL_H + 2, Reloaded::Matchup.text(val), ink, PF::TEXT)
          return
        end
        xw = P.width(PF::TEXT, "x")
        P.text(b, x, y - 1, xw + 1, PILL_H + 2, "x", ink, PF::TEXT)
        fx = x + xw + 1
        P.text(b, fx, y, 7, 9, "1", ink, PF::TINY, 2)
        b.fill_rect(fx, y + 9, 7, 1, ink)
        P.text(b, fx, y + 9, 7, 10, den, ink, PF::TINY, 2)
      end

      def words_width(val)
        return fraction(val) ? P.width(PF::TEXT, "x") + 8 : P.width(PF::TEXT, Reloaded::Matchup.text(val))
      end

      # "2" for x1/2, "4" for x1/4 (nil: not a fraction)
      def fraction(val)
        m = val.to_f / Reloaded::Matchup::NORMAL
        return m > 0 && m < 1 ? (1 / m).round.to_s : nil
      end

      def on_tone(col)
        light = 0.3 * col.red + 0.59 * col.green + 0.11 * col.blue > 150
        return light ? Reloaded::Palette.mix(col, BLACK, 0.62) : Reloaded::Palette.mix(col, WHITE, 0.78)
      end

      # The warning: a red disc with a white "!"
      def warn_mark(b, cx, cy)
        PP.disc(b, cx, cy, 6, WARN)
        b.fill_rect(cx, cy - 3, 1, 4, WHITE)
        b.fill_rect(cx, cy + 2, 1, 1, WHITE)
      end

      #------------------------------------------------------------------------
      # The pills above the picked move (Double Battles)
      #------------------------------------------------------------------------
      # Each target's name, outlined in its colour; your partner's red with
      # the "!" when it would be hurt, gray when it can't be. nil when the
      # move tells nothing (a status move that works on every target)
      def pill_row(s)
        per = s[:per]
        return nil if per.empty? || per.all? { |_b, v, _a| v.nil? }
        c = Reloaded::Palette.current
        me = Reloaded::MoveEffectiveness
        list = per.map do |b, v, ally|
          warn = ally && @warning && v && !::Effectiveness.ineffective?(v)
          edge = if v.nil? then Reloaded::BattleCursor.colour
                 elsif ally then me.ally_colour(v)
                 else me.level_colour(v)
                 end
          [name_of(b), edge || Reloaded::BattleCursor.colour, warn]
        end
        widths = list.map { |name, _e, warn| pill_w(name, warn) }
        bm = Bitmap.new(widths.sum + PILL_GAP * (list.length - 1), PILL_ROW_H)
        x = 0
        list.each_with_index do |(name, edge, warn), k|
          target_pill(bm, c, x, name, edge, warn)
          x += widths[k] + PILL_GAP
        end
        return bm
      end

      # The name the foe shows (an Illusion's disguise's)
      def name_of(b)
        d = Reloaded::BattleMenu::Notes.disguise(b)
        return (d ? d.name : b.name).to_s.upcase
      end

      def pill_w(name, warn)
        return 7 + (warn ? 14 : 0) + P.width(PF::TINY, name) + 7
      end

      def target_pill(b, c, x, name, edge, warn)
        w = pill_w(name, warn)
        fill = warn ? Reloaded::Palette.mix(c[:panel2], WARN, 0.28) : c[:panel2]
        P.ui.rbox(b, x, 0, x + w, PILL_ROW_H - 1, 6, warn ? WARN : edge)
        P.ui.rbox(b, x + 2, 2, x + w - 2, PILL_ROW_H - 3, 4, fill)
        warn_mark(b, x + 11, 9) if warn
        lead = warn ? 14 : 0
        P.text(b, x + 7 + lead, 1, w - 14 - lead + 2, PILL_ROW_H - 2, name, c[:strong], PF::TINY)
      end
    end
  end
end
