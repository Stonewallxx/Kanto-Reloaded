#==============================================================================
# Kanto Reloaded: the Quality of Life tools' screens
#==============================================================================
# Popups over whatever is on screen (KIF Settings, the Overworld Menu), in
# the designs he picked on 2026-10-21 (Tools/Designs/qa):
#   Pick a Pokémon   Party Rows: sprite, name, level and the tool's column
#   Nature Selector  the 25 natures grouped by the stat they raise (A to Z
#                    in each group, the ones with no change last), each
#                    stat now and with the highlighted nature beside them
#   Level Lock       Level Number: Lock At (Left and Right) and Unlock
#   Super Candy      One Panel: Raise To, and where each one would end up;
#                    then Party Raised, what happened
# Controller first (Up/Down, Left/Right, A, B); the mouse too.
#==============================================================================

module Reloaded
  module QualityOfLifeScreens
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    W = 512
    H = 384
    Z = 100_400
    GREEN = Color.new(120, 230, 150)
    GOLD  = Color.new(240, 200, 80)
    PINK  = Color.new(240, 130, 160)
    GOLD_FILL = Color.new(70, 58, 20)
    STATS = [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].freeze
    SHORT = ["Atk", "Def", "SpA", "SpD", "Spe"].freeze
    LONG  = ["Attack", "Defense", "Sp. Atk", "Sp. Def", "Speed"].freeze
    ROW_H = 34               # Party Rows
    NATURE_ROWS = 12
    NATURE_ROW_H = 18

    class << self
      #------------------------------------------------------------------------
      # The tools
      #------------------------------------------------------------------------
      def nature_selector
        return unless ready?
        open_layer
        sel = 0
        loop do
          sel = pick_pokemon(_INTL("Nature Selector"), sel) { |o, c, x, ry, w, pkmn| nature_column(o, c, x, ry, w, pkmn) }
          break if sel.nil?
          pkmn = party[sel]
          if pkmn.egg?
            pbPlayBuzzerSE
            next
          end
          pick_nature(pkmn)
        end
      ensure
        close_layer
      end

      def level_locks
        return unless ready?
        open_layer
        sel = 0
        loop do
          note = Reloaded::QualityOfLife.on?(:level_locking) ? nil : _INTL("Level Locking is Off: These locks are paused.")
          sel = pick_pokemon(_INTL("Level Lock Manager"), sel, note) { |o, c, x, ry, w, pkmn| lock_column(o, c, x, ry, w, pkmn) }
          break if sel.nil?
          pkmn = party[sel]
          if pkmn.egg?
            pbPlayBuzzerSE
            next
          end
          set_lock(pkmn)
        end
      ensure
        close_layer
      end

      def super_candy
        return unless ready?
        if defined?(::SWITCH_NO_LEVELS_MODE) && $game_switches && $game_switches[::SWITCH_NO_LEVELS_MODE]
          Reloaded::Notice.show(:title => _INTL("Super Candy"), :colour => GOLD, :buttons => [_INTL("OK")],
                                :body => _INTL("Levels don't change in this mode."))
          return
        end
        open_layer
        target = candy_panel
        if target
          close_layer
          results = Reloaded::QualityOfLife::SuperCandy.raise_party(target[1])
          open_layer
          candy_result(target, results)
        end
      ensure
        close_layer
      end

      # For tests: what's drawn.
      attr_reader :sprite

      #------------------------------------------------------------------------
      # Pick a Pokémon (Party Rows)
      #------------------------------------------------------------------------
      # The party index chosen, or nil on B. The block paints the tool's
      # column: (bitmap, colours, x, row y, width, pokemon).
      def pick_pokemon(title, sel, note = nil, &column)
        list = party
        w = 380
        h = 42 + list.length * ROW_H + 8 + (note ? 18 : 0)
        x = (W - w) / 2
        y = [(H - P::HINT_H - h) / 2, 4].max
        make_icons(list)
        hints = [[:ud, _INTL("Choose")], [button(:C), _INTL("Select")], [button(:B), _INTL("Close")]]
        return list_loop(list.length, sel) do |index|
          o, c = start_draw
          popup(o, c, x, y, w, h, title)
          @hits = []
          list.each_with_index do |pkmn, i|
            ry = y + 40 + i * ROW_H
            Reloaded::Dialogs.send(:cursor_row, o, c, x + 6, ry, x + w - 6, ry + ROW_H - 2) if i == index
            place_icon(i, x + 26, ry + ROW_H / 2, 28)
            name = pkmn.egg? ? _INTL("Egg") : pkmn.name.to_s
            P.text(o, x + 48, ry + 7, 100, 18, PF.fit(PF::TEXT, name, 100), c[:txt], PF::TEXT)
            unless pkmn.egg?
              # centred between the name's room and the tool's column (his ask, 2026-10-21)
              P.text(o, x + 148, ry + 10, 56, 12, _INTL("LV {1}", pkmn.level), tone(:gold), PF::TINY, 2)
              column.call(o, c, x, ry, w, pkmn) if column
            end
            @hits << [i, x + 6, ry, x + w - 6, ry + ROW_H - 2]
          end
          P.small(o, x, y + h - 24, w, 16, note, c[:dim], 2) if note
          P.hints(o, o, c, hints, Reloaded::Prompts.style)
        end
      end

      #------------------------------------------------------------------------
      # Nature Selector
      #------------------------------------------------------------------------
      def nature_column(o, c, x, ry, w, pkmn)
        n = pkmn.nature
        return unless n
        P.text(o, x + 204, ry + 7, 90, 18, n.name.to_s, c[:txt], PF::TEXT)
        tags(o, c, x + w - 14, ry + 9, n, :right)
      end

      def pick_nature(pkmn)
        order = nature_order
        now = pkmn.nature
        index = order.index { |n| now && n.id == now.id } || 0
        w = 440
        h = 42 + NATURE_ROWS * NATURE_ROW_H + 10
        x = (W - w) / 2
        y = (H - P::HINT_H - h) / 2
        lx1 = x + 250
        hints = [[:ud, _INTL("Choose")], [button(:C), _INTL("Set")], [button(:B), _INTL("Back")]]
        icon = make_icons([pkmn]).first
        loop do
          picked = list_loop(order.length, index, NATURE_ROWS) do |i, top|
            index = i
            o, c = start_draw
            popup(o, c, x, y, w, h, _INTL("{1}'s Nature", pkmn.name))
            @hits = []
            order[top, NATURE_ROWS].each_with_index do |n, k|
              ry = y + 40 + k * NATURE_ROW_H
              Reloaded::Dialogs.send(:cursor_row, o, c, x + 6, ry, lx1, ry + NATURE_ROW_H) if top + k == i
              tw = P.text(o, x + 14, ry + 1, 90, 16, n.name.to_s, c[:txt], PF::TEXT)
              P.pill(o, x + 18 + tw, ry + 1, _INTL("NOW"), now_fill, tone(:gold), false) if now && n.id == now.id
              tags(o, c, lx1 - 8, ry + 1, n, :right)
              @hits << [top + k, x + 6, ry, lx1, ry + NATURE_ROW_H]
            end
            # the scroll bar
            bx = lx1 + 4
            P.ui.rbox(o, bx, y + 42, bx + 3, y + 40 + NATURE_ROWS * NATURE_ROW_H, 1, c[:dark])
            t0 = y + 42 + NATURE_ROWS * NATURE_ROW_H * top / order.length
            P.ui.rbox(o, bx, t0, bx + 3, t0 + NATURE_ROWS * NATURE_ROW_H * NATURE_ROWS / order.length, 1, c[:selb])
            # the Pokémon, and its stats now and with this one
            px = lx1 + 16
            pw = x + w - 12 - px
            place_icon(0, px + pw / 2, y + 74, 56)
            P.text(o, px, y + 106, pw, 12, _INTL("LV {1}", pkmn.level), tone(:gold), PF::TINY, 2)
            a = stats_with(pkmn, now)
            b = stats_with(pkmn, order[i])
            5.times { |s| stat_line(o, c, px, y + 126 + s * 18, pw, s, a[s], b[s]) }
            P.hints(o, o, c, hints, Reloaded::Prompts.style)
          end
          return if picked.nil?
          chosen = order[picked]
          next if now && chosen.id == now.id
          set_nature(pkmn, chosen)
          now = pkmn.nature
          pbPlayDecisionSE
        end
      ensure
        clear_icons
      end

      def set_nature(pkmn, nature)
        pkmn.nature_for_stats = nil if pkmn.respond_to?(:nature_for_stats=)
        pkmn.nature = nature.id
        pkmn.calc_stats
        Reloaded::Log.info("Nature Selector: #{pkmn.name} is now #{nature.name}.", :quality_of_life)
      end

      # Grouped by the stat raised (Attack first), A to Z in each group, then
      # the ones with no change, A to Z (his pick, 2026-10-21)
      def nature_order
        all = []
        ::GameData::Nature.each { |n| all << n }
        raised = proc { |n| ch = n.stat_changes.find { |_s, v| v > 0 }; ch ? ch[0] : nil }
        list = []
        STATS.each { |s| list += all.select { |n| raised.call(n) == s }.sort_by { |n| n.name.to_s } }
        list += all.select { |n| raised.call(n).nil? }.sort_by { |n| n.name.to_s }
        return list
      end

      def stats_with(pkmn, nature)
        base = pkmn.baseStats
        ivs = pkmn.respond_to?(:calcIV) ? pkmn.calcIV : pkmn.iv
        mods = Hash.new(100)
        nature.stat_changes.each { |s, v| mods[s] += v } if nature
        return STATS.map { |s| pkmn.calcStat(base[s], pkmn.level, ivs[s], pkmn.ev[s], mods[s]) }
      rescue StandardError
        return [0] * 5
      end

      # "+Spe -SpA" (green, pink), or "No Change", ending at x (:right)
      def tags(o, c, x, y, nature, align = :left)
        up = nature.stat_changes.find { |_s, v| v > 0 }
        down = nature.stat_changes.find { |_s, v| v < 0 }
        parts = up && down ? [["+#{SHORT[STATS.index(up[0])]}", tone(:green)], ["-#{SHORT[STATS.index(down[0])]}", tone(:pink)]] :
                             [[_INTL("No Change"), c[:dim]]]
        ws = parts.map { |t, _| small_w(o, t) }
        total = ws.sum + 5 * (parts.length - 1)
        x0 = align == :right ? x - total : x
        parts.each_with_index do |(t, col), i|
          P.small(o, x0, y, ws[i] + 2, 16, t, col)
          x0 += ws[i] + 5
        end
      end

      def stat_line(o, c, x, y, w, i, now, new)
        P.small(o, x, y, 60, 16, _INTL(LONG[i]), c[:dim])
        if now == new
          P.small(o, x + w - 34, y, 34, 16, now.to_s, c[:txt], 1)
          return
        end
        col = new > now ? tone(:green) : tone(:pink)
        P.small(o, x + w - 80, y, 30, 16, now.to_s, c[:dim], 1)
        P.ui.tri(o, x + w - 44, y + 4, :r, col, 4)
        P.small(o, x + w - 34, y, 34, 16, new.to_s, col, 1)
      end

      #------------------------------------------------------------------------
      # Level Lock Manager
      #------------------------------------------------------------------------
      def lock_column(o, c, x, ry, w, pkmn)
        lv = Reloaded::QualityOfLife::LevelLocks.get(pkmn)
        unless lv
          P.small(o, x + w - 134, ry + 9, 120, 16, _INTL("Not Locked"), c[:dim], 1)
          return
        end
        tw = P.text(o, x + w - 74, ry + 9, 60, 14, _INTL("LV {1}", lv), tone(:gold), PF::TINY, 1)
        lock_icon(o, x + w - 14 - tw - 14, ry + 10, tone(:gold))
      end

      # Lock At (Left and Right: its level now to the highest) and Unlock
      def set_lock(pkmn)
        max = Reloaded::QualityOfLife.max_level
        lv = Reloaded::QualityOfLife::LevelLocks.get(pkmn) || pkmn.level
        row = 0
        w = 320
        h = 132
        x = (W - w) / 2
        y = (H - P::HINT_H - h) / 2
        hints = [[:lr, _INTL("Level")], [button(:C), _INTL("Set")], [button(:B), _INTL("Back")]]
        top = Sprite.new(@viewport)
        top.bitmap = Bitmap.new(W, H)
        top.z = 5
        redraw = true
        loop do
          if redraw
            o = top.bitmap
            c = Reloaded::Palette.map_menu   # Theme Mode: Dark, or Light for Light and Frost
            o.clear
            o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
            popup(o, c, x, y, w, h, _INTL("{1}'s Level Lock", pkmn.name))
            @hits = []
            [_INTL("Lock at"), _INTL("Unlock")].each_with_index do |label, i|
              ry = y + 42 + i * 28
              Reloaded::Dialogs.send(:cursor_row, o, c, x + 6, ry, x + w - 6, ry + 26) if i == row
              P.text(o, x + 16, ry + 5, 100, 18, label, c[:txt], PF::TEXT)
              @hits << [i, x + 6, ry, x + w - 6, ry + 26]
            end
            ry = y + 42
            P.ui.tri(o, x + 150, ry + 8, :l, c[:dim], 5)
            P.text(o, x + 162, ry + 5, w - 194, 18, _INTL("Lv {1}", lv), tone(:gold), PF::TEXT, 2)
            P.ui.tri(o, x + w - 30, ry + 8, :r, c[:dim], 5)
            P.small(o, x, y + h - 26, w, 16, _INTL("It gains no EXP past this level."), c[:dim], 2)
            P.hints(o, o, c, hints, Reloaded::Prompts.style)
            redraw = false
          end
          Graphics.update
          Input.update
          pt = Reloaded::Pointer
          if pt.moved? && (i = pt.hit(@hits)) && i != row
            row = i
            redraw = true
          end
          if Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
            row = 1 - row
            pbPlayCursorSE
            redraw = true
          elsif row == 0 && (Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT))
            step = Input.repeat?(Input::LEFT) ? -1 : 1
            to = [[lv + step, pkmn.level].max, max].min
            if to != lv
              lv = to
              pbPlayCursorSE
              redraw = true
            end
          elsif Input.trigger?(Input::USE) || (pt.left? && pt.hit(@hits))
            row = pt.hit(@hits) || row if pt.left?
            pbPlayDecisionSE
            if row == 0
              Reloaded::QualityOfLife::LevelLocks.set(pkmn, lv)
              # a lock set turns Level Locking On for the save, so it works at
              # once (his pick, 2026-10-21); Off still pauses every lock
              key = Reloaded::QualityOfLife.key(:level_locking)
              Reloaded::Settings.set(key, true) unless Reloaded::Settings.get(key)
            else
              Reloaded::QualityOfLife::LevelLocks.clear(pkmn)
            end
            return
          elsif Input.trigger?(Input::BACK) || pt.right?
            pbPlayCancelSE
            return
          end
        end
      ensure
        if top && !top.disposed?
          top.bitmap.dispose if top.bitmap
          top.dispose
        end
      end

      #------------------------------------------------------------------------
      # Super Candy
      #------------------------------------------------------------------------
      # [choice, level] to raise to, or nil. Raise To: the level cap, the
      # highest in the party, or a level of your own (Up and Down).
      def candy_panel
        list = party
        cap = Reloaded::QualityOfLife.level_cap
        highest = list.reject(&:egg?).map(&:level).max || 1
        max = Reloaded::QualityOfLife.max_level
        own = [[highest + 1, max].min, 1].max
        choice = 0
        # a lock Level Locking Off pauses, said as the Level Lock Manager says it
        paused = !Reloaded::QualityOfLife.on?(:level_locking) &&
                 list.any? { |p| !p.egg? && Reloaded::QualityOfLife::LevelLocks.get(p) }
        w = 380
        rh = 26
        h = 42 + 30 + 8 + list.length * rh + 30 + (paused ? 18 : 0)
        x = (W - w) / 2
        y = [(H - P::HINT_H - h) / 2, 4].max
        make_icons(list)
        redraw = true
        loop do
          target = [cap, highest, own][choice]
          if redraw
            o, c = start_draw
            popup(o, c, x, y, w, h, _INTL("Super Candy"))
            ry = y + 40
            Reloaded::Dialogs.send(:cursor_row, o, c, x + 6, ry, x + w - 6, ry + 26)
            P.text(o, x + 16, ry + 5, 100, 18, _INTL("Raise to"), c[:txt], PF::TEXT)
            words = [_INTL("Level Cap (Lv {1})", cap), _INTL("Highest in Party (Lv {1})", highest), _INTL("Lv {1}", own)][choice]
            P.ui.tri(o, x + 132, ry + 8, :l, c[:dim], 5)
            P.text(o, x + 144, ry + 5, w - 176, 18, PF.fit(PF::TEXT, words, w - 176), tone(:gold), PF::TEXT, 2)
            P.ui.tri(o, x + w - 30, ry + 8, :r, c[:dim], 5)
            o.fill_rect(x + 12, ry + 32, w - 24, 1, c[:line])
            list.each_with_index do |pkmn, i|
              py = ry + 38 + i * rh
              place_icon(i, x + 24, py + rh / 2, 22)
              name = pkmn.egg? ? _INTL("Egg") : pkmn.name.to_s
              P.text(o, x + 42, py + 4, 120, 18, PF.fit(PF::TEXT, name, 120), c[:txt], PF::TEXT)
              reach_column(o, c, x + w - 16, py + 5, pkmn, target) unless pkmn.egg?
            end
            P.small(o, x, y + h - 44, w, 16, _INTL("Level Locking is Off: Locks are paused."), c[:dim], 2) if paused
            P.small(o, x, y + h - 26, w, 16, _INTL("Moves and evolutions happen as they would."), c[:dim], 2)
            pairs = [[:lr, _INTL("Raise to")]]
            pairs << [:ud, _INTL("Level")] if choice == 2
            pairs += [[button(:C), _INTL("Raise")], [button(:B), _INTL("Close")]]
            P.hints(o, o, c, pairs, Reloaded::Prompts.style)
            redraw = false
          end
          Graphics.update
          Input.update
          @icons.each { |s| s.update if s && !s.disposed? }
          if Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
            choice = (choice + (Input.repeat?(Input::LEFT) ? -1 : 1)) % 3
            pbPlayCursorSE
            redraw = true
          elsif choice == 2 && (Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN))
            own = [[own + (Input.repeat?(Input::UP) ? 1 : -1), 1].max, max].min
            pbPlayCursorSE
            redraw = true
          elsif Input.trigger?(Input::USE) || Reloaded::Pointer.left?
            pbPlayDecisionSE
            return [choice, target]
          elsif Input.trigger?(Input::BACK) || Reloaded::Pointer.right?
            pbPlayCancelSE
            return nil
          end
        end
      end

      # where it would end up: "34 > 38" (green), a gold padlock where a
      # lock stops it, "Locked at Lv 35", or "Already There"
      def reach_column(o, c, x1, y, pkmn, target)
        to, why = Reloaded::QualityOfLife::SuperCandy.reach(pkmn, target)
        case why
        when :locked
          tw = P.small(o, x1 - 120, y, 120, 16, _INTL("Locked at Lv {1}", pkmn.level), tone(:gold), 1)
          lock_icon(o, x1 - tw - 14, y + 2, tone(:gold))
        when :already
          P.small(o, x1 - 120, y, 120, 16, _INTL("Already There"), c[:dim], 1)
        else
          P.small(o, x1 - 30, y, 30, 16, to.to_s, tone(:green), 1)
          P.ui.tri(o, x1 - 44, y + 4, :r, tone(:green), 4)
          P.small(o, x1 - 80, y, 30, 16, pkmn.level.to_s, c[:dim], 1)
          lock_icon(o, x1 - 100, y + 2, tone(:gold)) if why == :locked_at
        end
      end

      # Party Raised: each one's levels, a new move (pink) or evolution, the
      # locks (gold); A closes
      def candy_result(target, results)
        list = results
        w = 400
        rh = 24
        h = 42 + 18 + list.length * rh + 12
        x = (W - w) / 2
        y = [(H - P::HINT_H - h) / 2, 4].max
        make_icons(list.map { |r| r[:pokemon] })
        words = [_INTL("Up to the level cap, Lv {1}.", target[1]), _INTL("Up to the highest in the party, Lv {1}.", target[1]),
                 _INTL("Up to Lv {1}.", target[1])][target[0]]
        o, c = start_draw
        popup(o, c, x, y, w, h, _INTL("Party Raised"))
        P.small(o, x, y + 38, w, 16, words, c[:dim], 2)
        list.each_with_index do |r, i|
          ry = y + 58 + i * rh
          rx = x + 14
          rw = w - 28
          place_icon(i, rx + 14, ry + 11, 22)
          pkmn = r[:pokemon]
          P.text(o, rx + 32, ry + 2, 100, 18, PF.fit(PF::TEXT, pkmn.egg? ? _INTL("Egg") : pkmn.name.to_s, 100), c[:txt], PF::TEXT)
          case r[:result]
          when :egg
            next
          when :locked
            tw = P.small(o, rx + rw - 120, ry + 3, 120, 16, _INTL("Locked at Lv {1}", r[:from]), tone(:gold), 1)
            lock_icon(o, rx + rw - tw - 14, ry + 5, tone(:gold))
          when :already
            P.small(o, rx + rw - 120, ry + 3, 120, 16, _INTL("No Change"), c[:dim], 1)
          else
            P.small(o, rx + rw - 30, ry + 3, 30, 16, r[:to].to_s, tone(:green), 1)
            P.ui.tri(o, rx + rw - 44, ry + 7, :r, tone(:green), 4)
            P.small(o, rx + rw - 80, ry + 3, 30, 16, r[:from].to_s, c[:dim], 1)
            lock_icon(o, rx + rw - 100, ry + 5, tone(:gold)) if r[:result] == :lock_stop
            note = r[:evolved] ? _INTL("Evolved") : (r[:learned].empty? ? nil : _INTL("Learned {1}", r[:learned].join(", ")))
            P.small(o, rx + 122, ry + 3, rw - 228, 16, small_fit(o, note, rw - 228), tone(:pink)) if note
          end
        end
        P.hints(o, o, c, [[button(:C), _INTL("OK")]], Reloaded::Prompts.style)
        loop do
          Graphics.update
          Input.update
          @icons.each { |s| s.update if s && !s.disposed? }
          break if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK) || Reloaded::Pointer.left? || Reloaded::Pointer.right?
        end
        pbPlayDecisionSE
      end

      #------------------------------------------------------------------------
      # Pieces
      #------------------------------------------------------------------------
      def party
        t = $Trainer || ($player rescue nil)
        return t ? Array(t.party).compact : []
      rescue StandardError
        return []
      end

      def ready?
        return true unless party.empty?
        Reloaded::Notice.show(:title => _INTL("Quality of Life"), :colour => GOLD, :buttons => [_INTL("OK")],
                              :body => _INTL("Load a save to use this."))
        return false
      end

      def open_layer
        return if @viewport
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = Z
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = Bitmap.new(W, H)
        @sprite.z = 1
        @icons = []
      end

      def close_layer
        clear_icons
        @sprite.bitmap.dispose if @sprite && !@sprite.disposed? && @sprite.bitmap
        @sprite.dispose if @sprite && !@sprite.disposed?
        @viewport.dispose if @viewport && !@viewport.disposed?
        @sprite = @viewport = nil
      end

      def make_icons(list)
        clear_icons
        @icons = list.map { |pkmn| Reloaded::PartyIcons.icon(pkmn, @viewport, 3) }
        # the part of the first frame the Pokémon is in, so it fills its box
        @arts = @icons.map do |s|
          next nil unless s && s.bitmap
          Reloaded::PartyIcons.art_rect(s.bitmap, [s.src_rect.height, 1].max)
        end
        @icons.each { |s| s.visible = false if s }
        return @icons
      end

      def clear_icons
        (@icons || []).each { |s| s.dispose if s && !s.disposed? }
        @icons = []
      end

      # an icon's art fitted to a box x box square, its middle on x, y
      def place_icon(i, x, y, box)
        s = @icons[i]
        r = @arts && @arts[i]
        return unless s && r
        s.zoom_x = s.zoom_y = box.to_f / [r.width, r.height, 1].max
        s.ox = r.x + r.width / 2
        s.oy = r.y + r.height / 2
        s.x = x
        s.y = y
        s.visible = true
      end

      # the overlay, cleared and dimmed (or not, for a popup over a popup)
      def start_draw(dim = true)
        o = @sprite.bitmap
        c = Reloaded::Palette.map_menu   # Theme Mode: Dark, or Light for Light and Frost
        if dim
          o.clear
          o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
        end
        @icons.each { |s| s.visible = false if s } if dim
        return [o, c]
      end

      def popup(o, c, x, y, w, h, title)
        Reloaded::Dialogs.send(:panel, o, c, x, y, w, h)
        Reloaded::Dialogs.send(:title_bar, o, c, x, y, w, title)
      end

      # Up/Down through count rows (held stops at the ends, a fresh press
      # wraps), A chooses, B returns nil; the block draws (index, top row)
      def list_loop(count, index, visible = count)
        index = [[index, 0].max, [count - 1, 0].max].min
        top = [[index - visible / 2, count - visible].min, 0].max
        redraw = true
        loop do
          top = index if index < top
          top = index - visible + 1 if index >= top + visible
          if redraw
            yield index, top
            redraw = false
          end
          Graphics.update
          Input.update
          @icons.each { |s| s.update if s && !s.disposed? }
          pt = Reloaded::Pointer
          wheel = pt.wheel
          if pt.moved? && (i = pt.hit(@hits)) && i != index
            index = i
            redraw = true
          end
          if pt.left? && (i = pt.hit(@hits))
            pbPlayDecisionSE
            return i
          elsif pt.right? || Input.trigger?(Input::BACK)
            pbPlayCancelSE
            return nil
          elsif wheel != 0 && count > visible
            index = [[index + wheel, 0].max, count - 1].min
            redraw = true
          elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
            target = index + (Input.repeat?(Input::UP) ? -1 : 1)
            if target < 0 || target >= count
              next unless Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN)
              target %= count
            end
            index = target
            pbPlayCursorSE
            redraw = true
          elsif Input.trigger?(Input::USE)
            pbPlayDecisionSE
            return index
          end
        end
      end

      # A status colour in Theme Mode's look (deeper on Light)
      def tone(name)
        return Reloaded::Palette.map_menu[name]
      end

      # The NOW pill's fill: dark gold on Dark, a tint of gold on Light
      def now_fill
        c = Reloaded::Palette.map_menu
        return c[:light] ? Reloaded::Palette.mix(c[:panel2], c[:gold], 0.22) : GOLD_FILL
      end

      def button(sym)
        return Reloaded::Prompts.input(sym) || Reloaded::Prompts.name(sym)
      end

      def small_w(o, s)
        P.send(:small_font, o)
        return o.text_size(s.to_s).width
      end

      def small_fit(o, s, w)
        return s if small_w(o, s) <= w
        s = s.to_s
        s = s[0...-1] while s.length > 1 && small_w(o, s + "...") > w
        return s + "..."
      end

      # a padlock 9 x 11, top-left at x, y
      def lock_icon(o, x, y, col)
        o.fill_rect(x + 2, y, 5, 1, col)
        o.fill_rect(x + 1, y + 1, 1, 4, col)
        o.fill_rect(x + 7, y + 1, 1, 4, col)
        P.ui.rbox(o, x, y + 5, x + 9, y + 11, 1, col)
      end
    end
  end
end
