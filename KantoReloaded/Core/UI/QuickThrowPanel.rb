# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Quick Throw panel and its popups
#==============================================================================
# Design 1, Centred Panel (his pick 2026-10-17, the Ball Advisor; redrawn in
# the kit and picked as drawn 2026-10-29, sheet bt-throw-1): in the Battle
# Menu panel's frame, every ball you have in the Bag's order, each with its
# picture, how many, a bar and its chance of catching the foe right now; the
# best one starred in gold, the Quick Throw ball badged. The description box
# under it says why the highlighted ball's chance is what it is, then the
# foe's HP, status and the turn.
#
#   A        throws the highlighted ball (the Master Ball asks first)
#   Y        sets it as the Quick Throw ball
#   LB / RB  the other foe (two out): the chances follow
#   B        closes it
# The mouse too: a click throws a row, the wheel moves, a right click closes.
#
# Locked (the foe underground, in the sky...): the reason in red, every row
# dimmed, only Back. A trainer battle with KIF's Rocket Mode On: the balls
# the trainer would block padlocked (popups row 7).
#
# The popups, picked as drawn (sheet bt-popups): No Poké Balls, No Room for
# It, Out of (the Quick Throw ball), Throw Your Master Ball? (Keep It first),
# Not in Trainer Battles. Over the battle when Quick Throw runs straight from
# the command box (Host).
#==============================================================================

module Reloaded
  class QuickThrowPanel
    include Reloaded::Frame
    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    DL = Reloaded::Dialogs
    BI = Reloaded::ButtonIcons
    QT = Reloaded::QuickThrow
    CC = Reloaded::CatchChance
    PW = 392          # the panel's width: the longest ball name (Perfect Ball), its star, the badge and the count fit
    PY = 4            # its top
    RH = 23           # a row
    MAX_ROWS = 10     # rows before the list scrolls
    DESC_H = 66       # the description box
    DIM = 70          # the battle behind, dimmed
    BAR_W = 34

    def initialize(ctx)
      frame_init
      @ctx = ctx
      @battle = ctx.battle
      @pictures = {}
      @index = 0
      @top = 0
      @foes = QT.foes(ctx)
      @foe = QT.default_foe(ctx)
      work_out
    end

    def main
      open_sprites
      @hint_sprite.visible = false          # the hints live in the description box
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        return nil if over?
        r = handle_input
        next if r.nil?
        return r == :close ? nil : r
      end
    ensure
      @pictures.each_value { |b| b.dispose if b && !b.disposed? }
      @pictures = {}
      dispose_sprites if @viewport
    end

    def over?
      return @battle.decision.to_i != 0
    rescue StandardError
      return false
    end

    # The rows for this foe, the best, the lock; the highlight on the
    # Quick Throw ball (else the best)
    def work_out
      @rows = @foe ? QT.rows(@battle, @foe, QT.balls) : []
      @best = @foe ? QT.best(@battle, @foe, @rows) : nil
      first = @rows.empty? ? nil : @rows[0][0]
      @locked = @foe && first ? QT.aim(@battle, @foe, first, @ctx.first_action) : nil
      @quick = QT.quick_ball
      at = @rows.index { |r| r[0] == @quick && !blocked?(r[0]) } || (@best ? @rows.index { |r| r[0] == @best[0] } : nil)
      @index = at || 0
      @top = 0
    end

    def current
      return @rows[@index]
    end

    # A ball the trainer would block (KIF's Rocket Mode)
    def blocked?(id)
      return !QT.lets_through?(@battle, id)
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      pt = Reloaded::Pointer
      if pt.moved? && (i = row_at) && i != @index
        @index = i
        refresh
      end
      if pt.left? && (i = row_at)
        @index = i
        return throw_it
      elsif pt.left? && (act = hint_hit)
        return send(act)
      elsif pt.right?
        pbPlayCancelSE
        return :close
      elsif pt.wheel != 0
        step(pt.wheel)
      elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
        step(Input.repeat?(Input::UP) ? -1 : 1, Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN))
      elsif (Input.trigger?(Input::L) || Input.trigger?(Input::R)) && @foes.length > 1
        switch_foe(Input.trigger?(Input::L) ? -1 : 1)
      elsif Input.trigger?(Input::USE)
        return throw_it
      elsif Input.trigger?(Input::X)
        set_quick
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        return :close
      end
      return nil
    end

    def step(dir, wrap = false)
      return if @rows.empty? || @locked
      to = @index + dir
      if to < 0 || to >= @rows.length
        return unless wrap
        to %= @rows.length
      end
      @index = to
      pbPlayCursorSE
      refresh
    end

    def switch_foe(dir)
      i = @foes.index { |b| b.equal?(@foe) } || 0
      @foe = @foes[(i + dir) % @foes.length]
      keep = current && current[0]
      work_out
      @index = @rows.index { |r| r[0] == keep } || @index
      pbPlayCursorSE
      refresh
    end

    # A: the highlighted ball at this foe (:bag), or nil
    def throw_it
      row = current
      if row.nil? || @locked || blocked?(row[0])
        pbPlayBuzzerSE
        return nil
      end
      if QT.protected?(row[0])
        return nil unless self.class.protected_ok?(self, row[0], @foe)
      else
        pbPlayDecisionSE
      end
      return QT.send_request(@ctx, row[0], @foe)
    end

    # Y: the Quick Throw ball from now on
    def set_quick
      row = current
      if row.nil? || @locked || blocked?(row[0]) || row[0] == @quick
        pbPlayBuzzerSE
        return
      end
      QT.save_ball(row[0])
      @quick = row[0]
      Reloaded::CatchGauge.refresh_all(@ctx.scene) if defined?(Reloaded::CatchGauge)   # the ring by the HP bar follows now
      pbPlayDecisionSE
      refresh
    end

    def back; pbPlayCancelSE; return :close; end

    def row_at
      return nil unless @row_hits
      return Reloaded::Pointer.hit(@row_hits)
    end

    def hint_hit
      return nil unless @hint_hits
      i = Reloaded::Pointer.hit(@hint_hits)
      return i ? @hint_acts[i] : nil
    end

    def hint_pairs
      return []
    end

    #--------------------------------------------------------------------------
    # Drawing
    #--------------------------------------------------------------------------
    def refresh
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      base.fill_rect(0, 0, W, H, Color.new(0, 0, 0, DIM))
      @top = @index if @index < @top
      @top = @index - MAX_ROWS + 1 if @index >= @top + MAX_ROWS
      shown = [[@rows.length, 1].max, MAX_ROWS].min
      px = (W - PW) / 2
      ph = 58 + shown * RH + 6
      DL.send(:panel, base, c, px, PY, PW, ph)
      DL.send(:title_bar, base, c, px, PY, PW, _INTL("Quick Throw"))
      paint_foe(top, c, px)
      paint_rows(top, c, px)
      paint_description(base, top, c, px, PY + ph + 4)
      place_cursor
    end

    # VS the foe under the title; LB and RB and a dot per foe when two are out
    def paint_foe(top, c, px)
      return unless @foe
      many = @foes.length > 1
      if many
        style = Reloaded::Prompts.style
        lb = Reloaded::Prompts.input(:L)
        rb = Reloaded::Prompts.input(:R)
        BI.draw(top, px + 12, PY + 10, lb, c, style) if lb
        BI.draw(top, px + PW - 12 - BI.width(rb, style), PY + 10, rb, c, style) if rb
      end
      label = _INTL("VS {1}", @foe.name.to_s.upcase)
      lw = P.width(PF::TINY, label)
      dots = many ? @foes.length * 8 + 4 : 0
      lx = W / 2 - (lw + dots) / 2
      P.text(top, lx, PY + 39, lw + 2, 16, label, c[:dim], PF::TINY)
      return unless many
      @foes.each_with_index { |f, i| PP.disc(top, lx + lw + 8 + i * 8, PY + 47, 2, f.equal?(@foe) ? c[:strong] : c[:line]) }
    end

    def paint_rows(top, c, px)
      @row_hits = []
      @cursor_rect = nil
      if @rows.empty?
        P.text(top, px, PY + 58, PW, RH, _INTL("No Poké Balls"), c[:dim], PF::TEXT, 2)
        return
      end
      @rows[@top, MAX_ROWS].each_with_index do |(id, n, res), k|
        i = @top + k
        ry = PY + 58 + k * RH
        @row_hits << [i, px + 6, ry - 1, px + PW - 6, ry + RH - 1]
        @cursor_rect = [px + 6, ry - 1, PW - 12, RH] if i == @index && !@locked
        off = @locked || QT.protected?(id) || blocked?(id)
        best = @best && @best[0] == id && !@locked
        icon(top, id, px + 12, ry - 1, 24, off ? 130 : 255)
        nx = px + 40
        if best
          PP.pixels(top, PP::STAR, nx, ry + 8, c[:gold])
          nx += 11
        end
        x1 = px + PW - 12
        # the right side: the chance, a bar (a padlock), how many
        count = "x#{n}"
        if QT.protected?(id) || blocked?(id)
          w = pill(top, c, x1, ry + 4, CC.percent(res), :dim)
          PP.pixels(top, PP::LOCK, x1 - w - 14, ry + 8, c[:dim])
          P.text(top, x1 - w - 70, ry, 50, RH, count, c[:dim], PF::TEXT, 1)
          stop = x1 - w - 20 - P.width(PF::TEXT, count)
        else
          w = pill(top, c, x1, ry + 4, CC.percent(res), @locked ? :dim : CC.tone(res))
          bx = x1 - w - 6 - BAR_W
          PP.bar(top, c, bx, ry + 10, BAR_W, res.chance || 0, @locked ? c[:dim] : c[CC.tone(res)], 3)
          P.text(top, bx - 52, ry, 46, RH, count, c[:dim], PF::TEXT, 1)
          stop = bx - 6 - P.width(PF::TEXT, count)
        end
        # the name, and the Quick Throw badge after it where it fits
        name = QT.item(id).name
        ink = off ? c[:dim] : (best ? c[:gold] : c[:opt])
        nx += P.text(top, nx, ry, stop - 4 - nx, RH, PF.fit(PF::TEXT, name, stop - 4 - nx), ink)
        badge = _INTL("QUICK THROW")
        pill(top, c, nx + 6, ry + 4, badge, :blue, false) if id == @quick && nx + 6 + P.width(PF::TINY, badge) + 12 <= stop - 2
      end
      P.ui.tri(top, px + PW - 8, PY + 56, :u, c[:dim], 3) if @top > 0
      P.ui.tri(top, px + PW - 8, PY + 58 + MAX_ROWS * RH - 2, :d, c[:dim], 3) if @top + MAX_ROWS < @rows.length
    end

    # Why, then the foe; the hints under them
    def paint_description(base, top, c, px, dy)
      edge = @locked ? mix(c[:line], c[:red], 0.5) : mix(c[:line], c[:acc], 0.35)
      PP.chamfer_grad(base, px, dy, px + PW, dy + DESC_H, 10, c[:panel2], mix(c[:panel2], c[:dark], 0.3), edge)
      lines = description
      lines.first(2).each_with_index do |(text, key), i|
        P.small(top, px + 12, dy + 6 + i * 17, PW - 24, 17, fit_small(top, text, PW - 24), c[key] || c[:txt])
      end
      top.fill_rect(px + 10, dy + 42, PW - 20, 1, c[:line])
      paint_box_hints(top, c, dy + 43)
    end

    # [[words, colour key], [words, colour key]]
    def description
      return [[_INTL("Locked: {1}", @locked[0]), :red], [@locked[1], :dim]] if @locked
      row = current
      return [[_INTL("Buy Poké Balls at any Poké Mart."), :dim]] unless row && @foe
      if @battle.trainerBattle? && QT.rocket_mode == QT::ROCKET_ONLY
        return [[_INTL("Rocket Mode lets Rocket Balls through."), :txt], [_INTL("The trainer blocks every other ball."), :dim]]
      end
      return [[self.class.why(row[0], row[2], @battle), :txt], [self.class.state(@foe, @battle), :dim]]
    end

    def paint_box_hints(top, c, y)
      pairs = []
      acts = []
      unless @locked
        pairs << [button(:C), _INTL("Throw")]; acts << :throw_it
        pairs << [button(:X), _INTL("Set as Quick Throw")]; acts << :set_quick
      end
      pairs << [button(:B), _INTL("Back")]; acts << :back
      style = Reloaded::Prompts.style
      font = nil
      w = P.hints_width(top, pairs, style)
      if w > PW - 16
        font = PF::TINY
        w = P.hints_width(top, pairs, style, font)
      end
      spans = []
      P.draw_hints(top, W / 2 - w / 2, y, c, pairs, style, nil, spans, font)
      @hint_hits = spans.map { |i, a, b| [i, a, y, b, y + P::HINT_H] }
      @hint_acts = acts
    end

    # A badge in a palette tone (BagLook's); its width
    def pill(b, c, x, y, label, key, right = true)
      tone = c[key] || c[:dim]
      fill = c[:light] ? mix(c[:panel2], tone, 0.22) : mix(c[:panel2], tone, 0.28)
      return P.pill(b, x, y, label, fill, tone, right)
    end

    def fit_small(b, text, w)
      s = text.to_s
      P.small_font(b)
      return s if b.text_size(s).width <= w
      s = s[0..-2] while s.length > 1 && b.text_size(s + "...").width > w
      return s + "..."
    end

    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    def icon(b, id, x, y, size, opacity = 255)
      path = (::GameData::Item.icon_filename(id) rescue nil)
      return unless path
      bm = @pictures.key?(path) ? @pictures[path] : (@pictures[path] = (Bitmap.new(pbResolveBitmap(path) || path) rescue nil))
      b.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, bm.width, bm.height), opacity) if bm
    end

    #==========================================================================
    # The words
    #==========================================================================
    STATUS_WORDS = { :SLEEP => "asleep", :POISON => "poisoned", :BURN => "burned", :PARALYSIS => "paralyzed",
                     :FROZEN => "frozen" }.freeze
    # What a status-setting ball does (PIF's New Balls.rb:74-97)
    GIVES = { :SLEEP => "puts it to sleep", :POISON => "poisons it", :BURN => "burns it", :PARALYSIS => "paralyzes it",
              :FROZEN => "freezes it" }.freeze

    class << self
      # Why a ball's chance is what it is (the description box's first line)
      def why(id, res, battle)
        name = Reloaded::QuickThrow.item(id).name
        return _INTL("{1} always catches. Quick Throw asks before using it.", name) if Reloaded::QuickThrow.protected?(id)
        return _INTL("{1} can't be worked out here.", name) if res.nil? || res.chance.nil?
        case res.why
        when :guaranteed then return _INTL("Guaranteed Catch is on: Every ball catches.")
        when :last_shiny then return _INTL("Your last {1} always catches a shiny.", name)
        when :certain then return _INTL("{1} catches it for sure.", name)
        when :unconditional then return _INTL("{1} always catches.", name)
        end
        if res.status_set && GIVES[res.status]
          return _INTL("{1} {2} first, for x{3}.", name, _INTL(GIVES[res.status]), [:SLEEP, :FROZEN].include?(res.status) ? "2.5" : "1.5")
        end
        m = Reloaded::CatchChance.mult_text(res.mult)
        more = res.mult && res.mult > 1.001
        case id
        when :NETBALL then return more ? _INTL("{1} works {2} on Water and Bug types.", name, m) : _INTL("{1} only helps on Water and Bug types.", name)
        when :DUSKBALL then return more ? _INTL("{1} works {2} at night and in caves.", name, m) : _INTL("{1} only helps at night and in caves.", name)
        when :QUICKBALL then return more ? _INTL("{1} works {2} on the first turn.", name, m) : _INTL("{1} only helps on the first turn.", name)
        when :TIMERBALL then return _INTL("{1} works {2} on turn {3}, up to x4.", name, m, battle.turnCount.to_i + 1)
        when :NESTBALL then return more ? _INTL("{1} works {2} on Pokémon level 30 and under.", name, m) : _INTL("{1} only helps on Pokémon level 30 and under.", name)
        when :POKEBALL then return _INTL("{1} has no bonus.", name)
        when :GREATBALL, :ULTRABALL then return _INTL("{1} works {2} everywhere.", name, m)
        end
        return more ? _INTL("{1} works {2} here.", name, m) : _INTL("{1} has no bonus here.", name)
      end

      # The foe's HP, status and the turn (the second line)
      def state(foe, battle)
        pct = foe.totalhp > 0 ? (100.0 * foe.hp / foe.totalhp).ceil : 0
        st = STATUS_WORDS[foe.status]
        words = st ? _INTL(st) : _INTL("no status")
        return _INTL("{1} at {2}% HP, {3}. Turn {4}.", foe.name, pct, words, battle.turnCount.to_i + 1)
      end

      #------------------------------------------------------------------------
      # The popups
      #------------------------------------------------------------------------
      # A screen to show them on: the Battle Menu's panel, or a Host over
      # the battle when Quick Throw runs straight from the command box
      def with_scene(ctx)
        return yield(ctx.screen) if ctx.screen
        host = Host.new
        begin
          host.open
          return yield(host)
        ensure
          host.close
        end
      end

      # A lock from the command box: its popup (rows 1, 2 and 5), else a toast
      def refuse(ctx, lock)
        kind, words = lock
        case kind
        when :none
          with_scene(ctx) do |sc|
            DL.ask(sc, _INTL("No Poké Balls"), _INTL("You have no balls left to throw."),
                   [[_INTL("Any Poké Mart sells them."), sc.palette[:dim]]], [_INTL("OK")])
          end
        when :room
          with_scene(ctx) do |sc|
            DL.notice(sc, _INTL("No Room for It"), _INTL("Your party and every PC box are full, so a caught Pokémon would have nowhere to go."))
          end
        when :trainer
          with_scene(ctx) do |sc|
            DL.notice(sc, _INTL("Not in Trainer Battles"),
                      _INTL("The trainer would block the ball and it would be lost. Quick Throw works in wild battles."))
          end
        else
          pbPlayBuzzerSE if defined?(pbPlayBuzzerSE)
          ctx.toast(words)
        end
        return nil
      end

      # The Quick Throw ball ran out (row 3): 0 throws the best instead, 1
      # chooses one in the panel, nil backs out
      def ran_out(sc, ball, pick, foe)
        name = Reloaded::QuickThrow.item(ball).name
        best = Reloaded::QuickThrow.item(pick[0]).name
        line = _INTL("{1}: {2} against {3}.", best, Reloaded::CatchChance.percent(pick[2]), foe.name)
        return DL.ask(sc, _INTL("Out of {1}s", name), _INTL("Throw your best ball instead?"),
                      [[line, sc.palette[Reloaded::CatchChance.tone(pick[2])] || sc.palette[:txt]]],
                      [_INTL("Throw {1}", best), _INTL("Choose a Ball")], 0, :back => nil)
      end

      # The Master Ball (row 4): Keep It first
      def protected_ok?(sc, ball, foe)
        name = Reloaded::QuickThrow.item(ball).name
        n = Reloaded::QuickThrow.count(ball)
        note = n <= 1 ? _INTL("It's your only one.") : _INTL("You have {1}.", n)
        title = _INTL("Throw Your {1}?", name)
        text = foe ? _INTL("It catches {1} for sure.", foe.name) : _INTL("It catches for sure.")
        return DL.ask(sc, title, text, [[note, sc.palette[:gold]]], [_INTL("Throw It"), _INTL("Keep It")], 1) == 0
      end
    end

    #--------------------------------------------------------------------------
    # The popups' screen over the battle (nothing of its own but the popup
    # layer)
    #--------------------------------------------------------------------------
    class Host
      include Reloaded::Frame

      def open
        frame_init
        open_sprites
        @hint_sprite.visible = false
      end

      def close
        dispose_sprites if @viewport
      end

      def hint_pairs
        return []
      end
    end
  end
end
