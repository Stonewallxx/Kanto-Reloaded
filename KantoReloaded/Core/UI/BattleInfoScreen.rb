# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Battle Info
#==============================================================================
# Design 1, Tabs on Top (his pick, 2026-10-28; cody's Battle Info idea,
# rebuilt): a tab per Pokémon in the battle (yours first, a green or red
# dot), then Matchup, Field and Turn Log, in small capitals.
#
#   a Pokémon   who it is (HP, status), its stat stages (pips, the change,
#               its multiplier), other mods' abilities under them (KIF-ER's
#               innates: one kind headed Innates, mixed kinds Other Abilities
#               with each row's kind in a badge), then its types as they are
#               now, ability and held item (a foe's ??? until the battle
#               shows them), effects with the turns they have left, and a
#               foe's Moves Used
#   Matchup     your Pokémon's moves against each foe (Up and Down: your
#               other Pokémon), then each foe's types as seen
#   Field       the whole field, your side, the foe's side
#   Turn Log    every turn of this battle, the latest first (Up and Down
#               scroll)
# Left and Right (LB and RB too) turn the tabs; the mouse clicks a tab and
# scrolls the log. Dark or Light only. Ghostly Possession marks a possessed
# Pokémon through icon_for and name_mark.
#==============================================================================

module Reloaded
  class BattleInfoScreen
    include Reloaded::Frame
    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    RD = Reloaded::BattleMenu::Reader
    NT = Reloaded::BattleMenu::Notes
    TL = Reloaded::BattleMenu::TurnLog
    TAB_Y = 35
    PAGE_Y = 62
    LOG_ROW = 24
    LOG_HEAD = 14

    def initialize(ctx, tab = nil)
      frame_init
      @ctx = ctx
      @battle = ctx.battle
      @battlers = RD.battlers(@battle)
      @tabs = @battlers.map { |b| b.index } + [:matchup, :field, :log]
      # a tab to open on (:log, :matchup, :field), else the Pokémon choosing
      @tab = tab.is_a?(Symbol) && @tabs.include?(tab) ? @tabs.index(tab) : (@tabs.index(ctx.index) || 0)
      @me = @battlers.find { |b| b.index == ctx.index && RD.own?(b) } || @battlers.find { |b| RD.own?(b) }
      @scroll = 0
      @pictures = {}
      @icons = []
    end

    def main
      open_sprites
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        @icons.each { |s| s.update if s && !s.disposed? }
        break if over?
        break if handle_input == :close
      end
      return nil
    ensure
      clear_icons
      @pictures.each_value { |b| b.dispose if b && !b.disposed? }
      @pictures = {}
      dispose_sprites if @viewport
    end

    def over?
      return @battle.decision.to_i != 0
    rescue StandardError
      return false
    end

    def tab
      return @tabs[@tab]
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      pt = Reloaded::Pointer
      if pt.left? && (i = pt.hit(@tab_hits || []))
        go(i - @tab) if i != @tab
      elsif pt.left? && hint_click[0]
        return @closing ? :close : nil
      elsif pt.right? || Input.trigger?(Input::BACK)
        pbPlayCancelSE
        return :close
      elsif pt.wheel != 0
        scroll(pt.wheel) if tab == :log
      elsif Input.repeat?(Input::LEFT) || Input.trigger?(Input::L)
        go(-1)
      elsif Input.repeat?(Input::RIGHT) || Input.trigger?(Input::R)
        go(1)
      elsif tab.is_a?(Integer) && Input.trigger?(Input::USE)
        open_abilities
      elsif tab.is_a?(Integer) && Input.trigger?(Input::X)
        open_moves
      elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
        dir = Input.repeat?(Input::UP) ? -1 : 1
        if tab == :log
          scroll(dir)
        elsif tab == :matchup
          next_mon(dir)
        end
      elsif pointer_hover
        nil
      end
      return nil
    end

    def go(dir)
      @tab = (@tab + dir) % @tabs.length
      @scroll = 0
      pbPlayCursorSE
      refresh
    end

    def scroll(dir)
      to = [[@scroll + dir, 0].max, [@log_lines.to_i - @log_room.to_i, 0].max].min
      return if to == @scroll
      @scroll = to
      pbPlayCursorSE
      refresh
    end

    # Matchup: your next Pokémon on the field
    def next_mon(dir)
      own = @battlers.select { |b| RD.own?(b) }
      return if own.length < 2
      i = own.index(@me) || 0
      @me = own[(i + dir) % own.length]
      pbPlayCursorSE
      refresh
    end

    def back_hint
      @closing = true
      pbPlayCancelSE
      return :close
    end

    def hint_pairs
      case tab
      when :matchup
        pairs = [[:lr, _INTL("Tabs")]]
        pairs << [:ud, _INTL("Your Pokémon")] if @battlers.count { |b| RD.own?(b) } > 1
        return pairs + [[button(:B), _INTL("Back"), :back_hint]]
      when :log then return [[:lr, _INTL("Tabs")], [:ud, _INTL("Scroll")], [button(:B), _INTL("Back"), :back_hint]]
      when :field then return [[:lr, _INTL("Tabs")], [button(:B), _INTL("Back"), :back_hint]]
      end
      return [[:lr, _INTL("Tabs")], [button(:C), _INTL("Abilities"), :open_abilities], [button(:X), _INTL("Moves"), :open_moves],
              [button(:B), _INTL("Back"), :back_hint]]
    end

    #--------------------------------------------------------------------------
    # Drawing
    #--------------------------------------------------------------------------
    def refresh
      c = palette
      clear_icons
      @sprite.bitmap.clear
      @top_sprite.bitmap.clear
      PP.paint_background(base, c)
      PP.paint_title(top, c, _INTL("Battle Info"))
      paint_tabs(c)
      y1 = H - P::HINT_H - 6
      case tab
      when :matchup then matchup_page(c, 8, PAGE_Y, W - 8, y1)
      when :field then field_page(c, 8, PAGE_Y, W - 8, y1)
      when :log then log_page(c, 8, PAGE_Y, W - 8, y1)
      else
        bt = @battle.battlers[tab]
        mon_page(c, bt, 8, PAGE_Y, W - 8, y1) if bt
      end
      paint_hints(base, c)
    end

    def base; @sprite.bitmap; end
    def top; @top_sprite.bitmap; end

    def tab_label(t)
      case t
      when :matchup then return _INTL("Matchup")
      when :field then return _INTL("Field")
      when :log then return _INTL("Turn Log")
      end
      return @battle.battlers[t].name.to_s
    end

    # The tabs, centred; a Pokémon's with a dot (green yours, red a foe's).
    # Names shorten when they don't all fit (triple battles).
    def paint_tabs(c)
      labels = @tabs.map { |t| tab_label(t).upcase }
      dots = @tabs.map { |t| t.is_a?(Integer) ? (RD.own?(@battle.battlers[t]) ? c[:green] : c[:red]) : nil }
      gap = 4
      widths = labels.each_with_index.map { |l, i| P.width(PF::TINY, l) + (dots[i] ? 22 : 16) }
      room = W - 16 - gap * (widths.length - 1)
      while widths.sum > room
        k = widths.each_index.select { |i| dots[i] }.max_by { |i| widths[i] }
        break unless k && widths[k] > 40
        labels[k] = PF.fit(PF::TINY, labels[k], widths[k] - 26)
        widths[k] = P.width(PF::TINY, labels[k]) + 22
      end
      x = (W - widths.sum - gap * (widths.length - 1)) / 2
      @tab_hits = []
      @tabs.each_with_index do |_t, i|
        w = widths[i]
        lit = i == @tab
        PP.chamfer_grad(base, x, TAB_Y, x + w, TAB_Y + 21, 6, lit ? mix(c[:panel2], c[:selb], 0.55) : mix(c[:panel2], c[:panel], 0.4),
                        lit ? mix(c[:panel2], c[:selb], 0.25) : c[:panel2], lit ? c[:selb] : c[:line])
        tx = x + 8
        if dots[i]
          PP.disc(top, tx + 2, TAB_Y + 10, 2, dots[i])
          tx += 8
        end
        P.text(top, tx, TAB_Y, w, 21, labels[i], lit ? c[:strong] : c[:dim], PF::TINY)
        @tab_hits << [i, x, TAB_Y, x + w, TAB_Y + 21]
        x += w + gap
      end
    end

    #--------------------------------------------------------------------------
    # Pieces
    #--------------------------------------------------------------------------
    def mix(a, b, t); Reloaded::Palette.mix(a, b, t); end
    def type_ink(c, t); PP.ink(c, Reloaded::PartyScreen.type_rgb(t)); end

    def picture(path)
      return @pictures[path] if @pictures.key?(path)
      @pictures[path] = (Bitmap.new(pbResolveBitmap(path) || path) rescue nil)
    end

    def item_icon(b, id, x, y, size)
      bm = picture((GameData::Item.icon_filename(id) rescue "Graphics/Items/000"))
      b.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, bm.width, bm.height)) if bm
    end

    def small_type(b, type, x, y)
      sheet = picture(PP::TYPES_SMALL)
      b.blt(x, y, sheet, Rect.new(0, PP.type_row(type) * 16, 16, 16)) if sheet && type
      return 16
    end

    def big_type(b, type, x, y)
      sheet = PP.type_sheet
      b.stretch_blt(Rect.new(x, y, 38, 17), sheet, Rect.new(0, PP.type_row(type) * 28, 64, 28)) if sheet && type
      return 38
    end

    def category(b, cat, x, y)
      sheet = picture("Graphics/Pictures/category")
      b.stretch_blt(Rect.new(x, y, 38, 17), sheet, Rect.new(0, cat.to_i * 28, 64, 28)) if sheet
      return 38
    end

    # A badge in a palette tone
    def pill(b, c, x, y, label, tone_key, right = false)
      return cbadge(b, c, x, y, label, tone_key, right) if tone_key.is_a?(Array)
      tone = c[tone_key] || c[:dim]
      fill = c[:light] ? mix(c[:panel2], tone, 0.22) : mix(c[:panel2], tone, 0.28)
      return P.pill(b, x, y, label, fill, tone, right)
    end

    # A badge in a colour (a status's)
    def cbadge(b, c, x, y, label, rgb, right = false)
      fill, words = PP.badge(c, rgb)
      words = PP.ink(c, rgb) unless c[:light]
      return P.pill(b, x, y, label, fill, words, right)
    end

    def heading(b, c, x0, x1, y, label)
      P.heading(b, x0, x1, y, label, c[:head], c[:line])
    end

    # The Pokémon whose picture shows: a disguised foe's disguise (Ghostly
    # Possession shows a possessed one's look here)
    def icon_for(pkmn)
      return pkmn
    end

    # Drawn after a Pokémon's name on its tab (Ghostly Possession's badge);
    # returns its width
    def name_mark(top, c, pkmn, x, y)
      return 0
    end

    def mon_icon(pkmn, cx, cy, size = nil)
      return nil unless pkmn && defined?(Reloaded::PartyIcons)
      s = Reloaded::PartyIcons.icon(icon_for(pkmn), @viewport, 2)   # over the words, under a popup
      return nil unless s
      Reloaded::PartyIcons.place(s, cx, cy)
      s.zoom_x = s.zoom_y = s.zoom_x * size / 64.0 if size
      @icons << s
      return s
    end

    def clear_icons
      @icons.each { |s| s.dispose if s && !s.disposed? }
      @icons = []
    end

    def battler_pokemon(bt)
      return NT.disguise(bt) || bt.pokemon
    end

    def hp_text(bt)
      return "#{bt.hp}/#{bt.totalhp}" if RD.known?(@battle, bt)
      return "#{(100.0 * bt.hp / [bt.totalhp, 1].max).ceil}%"
    end

    def hp_colour(c, bt)
      f = bt.hp.to_f / [bt.totalhp, 1].max
      return f > 0.5 ? c[:green] : (f > 0.25 ? c[:amber] : c[:red])
    end

    def status_pill(b, c, x, y, bt, right = false)
      st = PP::STATUS[bt.status]
      return 0 unless st
      return cbadge(b, c, x, y, st[0], st[1], right)
    end

    def turns_label(n)
      return n == 1 ? _INTL("1 TURN") : _INTL("{1} TURNS", n)
    end

    # A plate lit in a colour, with the Party Screen's two bands
    def plate(b, c, col, x0, y0, x1, y1, cut = 14)
      topc = mix(c[:panel], col, 0.4)
      bottom = mix(c[:panel], c[:dark], 0.4)
      PP.chamfer_grad(b, x0, y0, x1, y1, cut, topc, bottom, mix(c[:line], col, 0.5))
      from = x1 - 48
      to = x0 + 24
      ly = y0 + (y1 - y0) / 3
      (y0 + 1...y1 - 1).each do |y|
        t = (y - y0).to_f / (y1 - y0)
        left = x0 + 1 + [cut - (y - y0), 0].max
        right = x1 - 1 - [cut - (y1 - 1 - y), 0].max
        mid = from + (to - from) * t
        k = y < ly ? 0.4 : 0.22 - 0.18 * (y - ly).to_f / [y1 - ly, 1].max
        tint = mix(mix(topc, bottom, t), col, k)
        [[0, 56], [40, 8]].each do |off, bw|
          a = [(mid + off - bw / 2.0).round, left].max
          bb = [(mid + off + bw / 2.0).round, right].min
          b.fill_rect(a, y, bb - a, 1, tint) if bb > a
        end
      end
    end

    def plain_plate(b, c, x0, y0, x1, y1, cut = 10)
      PP.chamfer_grad(b, x0, y0, x1, y1, cut, c[:panel2], mix(c[:panel2], c[:dark], 0.3), c[:line])
    end

    # Six pips, one lit per stage from the left, in the stat's colour (the
    # unlit ones a faint tint of it)
    def pips(b, c, x, y, stage, tint)
      unlit = c[:light] ? mix(c[:panel2], c[:line], 0.6) : mix(c[:dark], c[:line], 0.5)
      6.times do |k|
        col = k < stage.abs ? tint : mix(unlit, tint, 0.30)
        P.ui.rbox(b, x + k * 9, y, x + k * 9 + 6, y + 6, 1, col)
      end
    end

    # An effect: its words (a move's in its type's colour), its tag, the
    # turns left at the right end
    def effect_row(c, x, x1, y, row)
      words, n, tag, type = row
      tw = n ? P.width(PF::TINY, turns_label(n)) + 18 : 0
      gw = tag ? P.width(PF::TINY, tag) + 18 : 0
      words = PF.fit(PF::TEXT, words, x1 - x - tw - gw)
      nw = P.text(top, x, y, x1 - x - tw - gw, 22, words, type ? type_ink(c, type) : c[:txt])
      pill(top, c, x + nw + 6, y + 4, tag, :amber) if tag
      pill(top, c, x1, y + 4, turns_label(n), :gold, true) if n
    end

    #--------------------------------------------------------------------------
    # A Pokémon's tab
    #--------------------------------------------------------------------------
    def mon_page(c, bt, x0, y0, x1, y1)
      types = RD.types_seen(bt)
      plate(base, c, PP.rgb(Reloaded::PartyScreen.type_rgb(types[0])), x0, y0, x1, y1)
      pkmn = battler_pokemon(bt)
      mon_icon(pkmn, x0 + 34, y0 + 30)
      nw = P.text(top, x0 + 66, y0 + 4, 180, 26, PF.fit(PF::ROW, bt.name.to_s, 180), c[:strong], PF::ROW)
      nw += name_mark(top, c, bt.pokemon, x0 + 66 + nw + 4, y0 + 8)
      P.text(top, x0 + 66 + nw + 8, y0 + 8, 60, 20, _INTL("Lv. {1}", bt.level), c[:dim])
      st = PP::STATUS[bt.status]
      sw = st ? P.width(PF::TINY, st[0]) + 12 : 0
      hp = hp_text(bt)
      hw = P.width(PF::TEXT, hp)
      bar_w = 250 - 68 - hw - 8 - (sw > 0 ? sw + 6 : 0)
      PP.bar(top, c, x0 + 68, y0 + 36, bar_w, bt.hp.to_f / [bt.totalhp, 1].max, hp_colour(c, bt))
      P.text(top, x0 + 68 + bar_w + 8, y0 + 28, hw + 2, 20, hp, c[:txt])
      status_pill(top, c, x0 + 250, y0 + 31, bt, true)
      # the stat stages (closer together when innates follow); its abilities
      # (a second one under the first: his ask, 2026-10-29) on the right
      main, innates = ability_pages(bt).map { |pg| pg[1] }
      innates ||= []
      extra = innates.map { |name, label, _w| [label, name] }
      step = extra.empty? ? 24 : 21
      sx = x0 + 14
      RD::STATS.each_with_index { |(stat, label), i| stage_row(c, sx, y0 + 58 + i * step, stat, label, bt.stages[stat].to_i) }
      other_abilities(c, bt, extra, sx, x0 + 252, y0 + 58 + 7 * step + 4, y1) unless extra.empty?
      # the right column
      rx = x0 + 266
      rw = x1 - 12 - rx
      heading(top, c, rx, x1 - 12, y0 + 8, _INTL("Types"))
      tx = rx
      types.each { |t| tx += big_type(top, t, tx, y0 + 22) + 4 }
      heading(top, c, rx, x1 - 12, y0 + 46, main.length > 1 ? _INTL("Abilities") : _INTL("Ability"))
      known = RD.known?(@battle, bt)
      main.first(2).each_with_index do |(name, label, _w), k|
        ay = y0 + 58 + k * 20
        tagw = main.length > 1 ? P.width(PF::TINY, label) + 18 : 0
        if name
          room = rw - tagw - 6 - (known ? 0 : P.width(PF::TINY, _INTL("REVEALED")) + 18)
          aw = P.text(top, rx, ay, room, 22, PF.fit(PF::TEXT, name.to_s, room), c[:txt])
          pill(top, c, rx + aw + 6, ay + 4, _INTL("REVEALED"), :green) unless known
        else
          aw = P.text(top, rx, ay, 40, 22, "???", c[:dim])
          pill(top, c, rx + aw + 6, ay + 4, _INTL("NOT SEEN YET"), :dim)
        end
        pill(top, c, x1 - 12, ay + 4, label, :blue, true) if main.length > 1
      end
      y0 += 20 if main.length > 1            # the rest of the column moves down a row
      heading(top, c, rx, x1 - 12, y0 + 86, _INTL("Held Item"))
      item = NT.item_text(@battle, bt)
      if item.nil?
        aw = P.text(top, rx, y0 + 98, 40, 22, "???", c[:dim])
        pill(top, c, rx + aw + 6, y0 + 102, _INTL("NOT SEEN YET"), :dim)
      elsif bt.item && item == bt.itemName
        item_icon(top, bt.item_id, rx, y0 + 100, 18)
        P.text(top, rx + 22, y0 + 98, rw - 22, 22, PF.fit(PF::TEXT, item, rw - 22), c[:txt])
      else
        P.text(top, rx, y0 + 98, rw, 22, item, c[:dim])
      end
      heading(top, c, rx, x1 - 12, y0 + 126, _INTL("Effects"))
      rows = RD.effects(bt)
      room = known ? (y1 - 8 - (y0 + 138)) / 22 : 3
      if rows.empty?
        P.text(top, rx, y0 + 138, rw, 22, _INTL("None"), c[:dim])
      else
        shown = rows.first(room)
        shown.each_with_index { |r, k| effect_row(c, rx, x1 - 12, y0 + 138 + k * 22, r) }
        P.text(top, x1 - 12, y0 + 138 + room * 22 - 6, 0, 13, _INTL("+{1} MORE", rows.length - room), c[:dim], PF::TINY, 1) if rows.length > room
      end
      return if known
      my = y0 + 138 + [[rows.length, room].min, 1].max * 22 + 8
      heading(top, c, rx, x1 - 12, my, _INTL("Moves Used"))
      used = NT.moves_used(@battle, bt)
      if used.empty?
        P.text(top, rx, my + 12, rw, 20, _INTL("None Yet"), c[:dim])
        return
      end
      used.first([(y1 - my - 14) / 20, 1].max).each_with_index do |m, k|
        d = (GameData::Move.get(m) rescue nil)
        next unless d
        small_type(top, d.type, rx, my + 14 + k * 20)
        P.text(top, rx + 22, my + 12 + k * 20, rw - 22, 20, PF.fit(PF::TEXT, d.name, rw - 22), type_ink(c, d.type))
      end
    end

    # A stat stage's row: its name, six pips, the change, its multiplier
    # (his picks, 2026-10-29): the name and the pips in the stat's colour
    # (the Reloaded PC Compare's; dimmer at 0), the change green or red, the
    # multiplier coloured by how far it moves the stat (x1 white)
    def stage_row(c, x, y, stat, label, stage)
      tint = stat_tint(c, stat)
      P.text(top, x, y, 96, 22, _INTL(label), stage == 0 ? mix(tint, c[:panel], c[:light] ? 0.35 : 0.45) : tint)
      pips(top, c, x + 92, y + 8, stage, tint)
      tone = stage > 0 ? c[:green] : (stage < 0 ? c[:red] : c[:dim])
      P.text(top, x + 152, y, 28, 22, stage > 0 ? "+#{stage}" : stage.to_s, tone, PF::TEXT, 1)
      m = RD.multiplier(stage, [:ACCURACY, :EVASION].include?(stat))
      P.text(top, x + 182, y, 54, 22, RD.mult_text(m), mult_ink(c, m), PF::TEXT, 1)
    end

    # Each stat's colour: the Reloaded PC Compare's [hue, saturation, lift]
    # (ATK and SPA red, DEF and SPD blue, SPE pink), Accuracy gold and
    # Evasion purple, at the theme's one lightness
    STAT_TINT = { :ATTACK => [0, 0.85, -0.12], :DEFENSE => [215, 0.85, -0.12], :SPECIAL_ATTACK => [0, 0.85, 0.0],
                  :SPECIAL_DEFENSE => [215, 0.85, 0.10], :SPEED => [330, 0.85, 0.0], :ACCURACY => [45, 0.90, 0.05],
                  :EVASION => [275, 0.80, 0.0] }.freeze

    def stat_tint(c, stat)
      hue, sat, lift = STAT_TINT[stat] || [0, 0.0, 0.0]
      return PP.hsl_color(hue, sat, (PP::INK_LIGHTNESS[c[:light] ? :light : :dark] + lift).clamp(0.0, 0.9))
    end

    # Green above x1, white at x1; x0.75 and x0.67 yellow, x0.6 and x0.5
    # orange, lower red
    def mult_ink(c, m)
      return c[:green] if m > 1
      return c[:txt] if m == 1
      return c[:gold] if m >= 0.66
      return PP.hsl_color(26, 0.95, PP::INK_LIGHTNESS[c[:light] ? :light : :dark]) if m >= 0.5
      return c[:red]
    end

    # Other mods' abilities (his Q14 pick, drawn 2026-10-28): one kind is
    # headed Innates; mixed kinds Other Abilities, each row's kind at its end
    def other_abilities(c, bt, rows, x0, x1, y, y1)
      kinds = rows.map { |r| r[0] }.uniq
      heading(top, c, x0, x1, y, kinds == ["INNATE"] ? _INTL("Innates") : _INTL("Other Abilities"))
      known = RD.known?(@battle, bt)
      rows.each_with_index do |(label, name), k|
        ry = y + 12 + k * 20
        break if ry + 20 > y1
        if name
          w = P.text(top, x0, ry, x1 - x0 - 70, 20, PF.fit(PF::TEXT, name, x1 - x0 - 70), c[:txt])
          pill(top, c, x0 + w + 6, ry + 3, _INTL("REVEALED"), :green) unless known || kinds.length > 1
        else
          P.text(top, x0, ry, 40, 20, "???", c[:dim])
        end
        pill(top, c, x1, ry + 3, label, :blue, true) if kinds.length > 1
      end
    end

    #--------------------------------------------------------------------------
    # Matchup
    #--------------------------------------------------------------------------
    def matchup_page(c, x0, y0, x1, y1)
      plain_plate(base, c, x0, y0, x1, y1)
      me = @me
      foes = @battlers.reject { |b| RD.own?(b) }
      unless me && !foes.empty?
        P.text(top, x0, y0 + 20, x1 - x0, 22, _INTL("Nothing to Match Up"), c[:dim], PF::TEXT, 2)
        return
      end
      title = _INTL("{1}'s Moves", me.name)
      mon_icon(battler_pokemon(me), x0 + 24, y0 + 16, 40)
      tw = P.text(top, x0 + 46, y0 + 4, 200, 22, PF.fit(PF::TEXT, title, 200), c[:strong])
      if @battlers.count { |b| RD.own?(b) } > 1
        P.ui.tri(top, x0 + 46 + tw + 8, y0 + 9, :u, c[:dim], 3)
        P.ui.tri(top, x0 + 46 + tw + 8, y0 + 15, :d, c[:dim], 3)
      end
      colw = [86, (x1 - x0 - 236) / foes.length].min
      cols = foes.each_index.map { |i| x1 - 14 - (foes.length - i) * colw }
      foes.each_with_index do |f, i|
        if colw >= 80
          P.text(top, cols[i], y0 + 7, colw, 16, PF.fit(PF::TINY, f.name.to_s.upcase, colw - 4), c[:dim], PF::TINY, 2)
        else
          mon_icon(battler_pokemon(f), cols[i] + colw / 2, y0 + 16, 34)
        end
      end
      top.fill_rect(x0 + 10, y0 + 28, x1 - x0 - 20, 1, c[:line])
      cat_x = [x0 + 168, cols[0] - 44].min
      me.moves.compact.first(4).each_with_index do |m, r|
        y = y0 + 34 + r * 26
        type = RD.calc_type(m, me)
        small_type(top, type, x0 + 12, y + 4)
        P.text(top, x0 + 34, y, cat_x - x0 - 38, 24, PF.fit(PF::TEXT, m.name.to_s, cat_x - x0 - 38), type_ink(c, type))
        category(top, m.category, cat_x, y + 3)
        foes.each_with_index do |f, i|
          cx = cols[i] + colw / 2
          mult = RD.effectiveness(m, me, f)
          if mult.nil?
            P.text(top, cols[i], y, colw, 24, "-", c[:dim], PF::TEXT, 2)
            next
          end
          tone = mult > 1 ? :green : (mult == 0 ? :dim : (mult < 1 ? :red : :txt))
          label = RD.mult_label(mult)
          w = P.width(PF::TINY, label) + 12
          pill(top, c, cx - w / 2, y + 5, label, tone)
        end
      end
      foe_types(c, foes, x0, x1, y0 + 34 + 4 * 26 + 6, y1)
    end

    # The foes' types as seen (his pick, 2026-10-29: By Multiplier): each
    # foe's name centred in its column, its first type's label left of it
    # and its second right; then a row per multiplier (x4, x2, x½, x¼, x0)
    # with the attacking types in PIF's battle type icons
    MULT_ROWS = [[4.0, "x4", :green], [2.0, "x2", :green], [0.5, "x½", :red], [0.25, "x¼", :red], [0.0, "x0", :dim]].freeze

    def foe_types(c, foes, x0, x1, py, y1)
      heading(top, c, x0 + 12, x1 - 12, py, _INTL("Foes' Types, as Seen"))
      half = (x1 - x0 - 24) / foes.length
      foes.each_with_index do |f, i|
        fx = x0 + 12 + i * half
        y = py + 14
        name = PF.fit(PF::TEXT, f.name.to_s, half - 100)
        nw = P.width(PF::TEXT, name)
        cx = fx + (half - 6) / 2
        P.text(top, cx - nw / 2, y, nw + 2, 20, name, c[:txt])
        types = RD.types_seen(f)
        big_type(top, types[0], cx - nw / 2 - 6 - 38, y + 2) if types[0]
        big_type(top, types[1], cx + nw / 2 + 6, y + 2) if types[1]
        y += 24
        pr = RD.profile(f)
        all = pr[:weak] + pr[:resist] + pr[:immune]
        MULT_ROWS.each do |m, label, tone|
          list = all.select { |_t, v| v == m }.map(&:first)
          next if list.empty?
          break if y + 20 > y1
          P.text(top, fx, y, 26, 20, label, c[tone])
          lx = fx + 30
          list.each do |t|
            if lx + 19 > fx + half - 6
              lx = fx + 30
              y += 21
            end
            battle_type(top, t, lx, y + 1)
            lx += 21
          end
          y += 22
        end
      end
    end

    # PIF's battle type icons (its databoxes', 19 x 19)
    BATTLE_TYPES = "Graphics/Pictures/Battle/typesSmall"

    def battle_type(b, type, x, y)
      sheet = picture(BATTLE_TYPES)
      b.blt(x, y, sheet, Rect.new(0, PP.type_row(type) * 19, 19, 19)) if sheet && type
      return 19
    end

    #--------------------------------------------------------------------------
    # Field
    #--------------------------------------------------------------------------
    # (his pick, 2026-10-29: Two Columns, so a busy field fits): the whole
    # field in two columns, then your side and the foe's side by side. Turns
    # green on your side, red on the foe's, gold for the whole field; an
    # endless one's pill in the Theme's accent with the infinity mark
    def field_page(c, x0, y0, x1, y1)
      plain_plate(base, c, x0, y0, x1, y1)
      items = RD.field_items(@battle)
      cw = (x1 - x0 - 36) / 2
      y = y0 + 8
      heading(top, c, x0 + 12, x1 - 12, y, _INTL("Whole Field"))
      y += 14
      list = items.select { |i| i[2] == :field }
      if list.empty?
        P.text(top, x0 + 14, y, 300, 22, _INTL("No Weather or Terrain"), c[:dim])
        y += 22
      end
      list.each_with_index { |row, k| field_row(c, x0 + 14 + (k % 2) * (cw + 12), y + (k / 2) * 22, cw, row, :field) }
      y += ((list.length + 1) / 2) * 22 + 6
      [[0, _INTL("Your Side")], [1, _INTL("Foe's Side")]].each_with_index do |(side, label), col|
        sx = x0 + 12 + col * (cw + 12)
        heading(top, c, sx, sx + cw, y, label)
        rows = items.select { |i| i[2] == side }
        if rows.empty?
          P.text(top, sx + 2, y + 14, cw, 20, _INTL("Nothing"), c[:dim])
          next
        end
        rows.each_with_index do |row, k|
          break if y + 14 + k * 22 + 22 > y1 - 4
          field_row(c, sx + 2, y + 14 + k * 22, cw - 2, row, side)
        end
      end
    end

    def field_row(c, x, y, w, row, side)
      words, n, _s, t = row
      small_type(top, t, x, y + 3) if t
      tw = n ? P.width(PF::TINY, turns_label(n)) + 16 : 27
      P.text(top, x + 20, y, w - 22 - tw, 22, PF.fit(PF::TEXT, words, w - 24 - tw), t ? type_ink(c, t) : c[:txt])
      if n
        pill(top, c, x + w, y + 4, turns_label(n), Reloaded::FieldStrip.turns_tone(side), true)
      else
        infinity_pill(c, x + w, y + 4)
      end
    end

    # An endless one's badge: the infinity mark in a pill, in the Theme's accent
    def infinity_pill(c, x1, y)
      w = 23
      fill = c[:light] ? mix(c[:panel2], c[:acc], 0.22) : mix(c[:panel2], c[:acc], 0.28)
      P.ui.rbox(top, x1 - w, y, x1, y + 15, 4, fill)
      Reloaded::FieldStrip.infinity(top, x1 - w + 6, y + 5, c[:acc])
    end

    #--------------------------------------------------------------------------
    # Turn Log
    #--------------------------------------------------------------------------
    # Lines: [:head, turn] or [:row, row], the latest turn first
    def log_lines
      log = TL.rows(@battle)
      out = []
      log.keys.sort.reverse.each do |t|
        next if log[t].empty?
        out << [:head, t]
        log[t].each { |r| out << [:row, r] }
      end
      return out
    end

    def log_page(c, x0, y0, x1, y1)
      plain_plate(base, c, x0, y0, x1, y1)
      lines = log_lines
      if lines.empty?
        P.text(top, x0, y0 + 20, x1 - x0, 22, _INTL("Nothing Has Happened Yet"), c[:dim], PF::TEXT, 2)
        @log_lines = 0
        return
      end
      # how many lines fit from each start (headings are shorter)
      @log_lines = lines.length
      room_h = y1 - y0 - 12
      fit = 0
      h = 0
      lines.reverse_each do |kind, _v|
        lh = kind == :head ? LOG_HEAD + 4 : LOG_ROW
        break if h + lh > room_h
        h += lh
        fit += 1
      end
      @log_room = fit
      @scroll = [[@scroll, 0].max, [lines.length - fit, 0].max].min
      y = y0 + 8
      lines[@scroll..-1].each do |kind, v|
        lh = kind == :head ? LOG_HEAD + 4 : LOG_ROW
        break if y + lh > y1 - 4
        if kind == :head
          heading(top, c, x0 + 12, x1 - 18, y + 2, v == 0 ? _INTL("Start of Battle") : _INTL("Turn {1}", v))
        else
          event_row(top, c, x0 + 12, x1 - 18, y, v)
        end
        y += lh
      end
      # the scroll bar
      return if lines.length <= fit
      track = y1 - y0 - 16
      len = [track * fit / lines.length, 12].max
      at = (track - len) * @scroll / [lines.length - fit, 1].max
      P.ui.rbox(base, x1 - 10, y0 + 8, x1 - 7, y1 - 8, 1, c[:line])
      P.ui.rbox(base, x1 - 10, y0 + 8 + at, x1 - 7, y0 + 8 + at + len, 1, c[:selb])
    end

    # One event: who, what (a move in its type's colour), at whom; the
    # result badges at the end. The words make room for the badges (the
    # target's name gives way first).
    def event_row(b, c, x0, x1, y, row)
      name, pkmn, _own = row[:who]
      mon_icon(pkmn, x0 + 12, y + 11, 28)
      rx = x1 - 4
      Array(row[:pills]).reverse.each do |label, tone|
        w = P.width(PF::TINY, label) + 12
        break if rx - w < x0 + 120
        rx -= pill(b, c, rx, y + 4, label, tone, true) + 4
      end
      room = rx - 6
      x = x0 + 28
      x += P.text(b, x, y, room - x, 22, PF.fit(PF::TEXT, name.to_s, [room - x, 1].max), c[:txt]) + 6
      if row[:words]
        words = row[:words].to_s
        x += P.text(b, x, y, [room - x, 1].max, 22, PF.fit(PF::TEXT, words, [room - x, 1].max), row[:type] ? type_ink(c, row[:type]) : c[:txt])
        tgt = row[:target]
        if tgt && room - x - 16 >= P.width(PF::TEXT, tgt[0].to_s)
          P.ui.tri(b, x + 6, y + 8, :r, c[:dim], 4)
          P.text(b, x + 16, y, room - x - 16, 22, tgt[0].to_s, c[:txt])
        end
      elsif row[:plain]
        P.text(b, x, y, [room - x, 1].max, 22, PF.fit(PF::TEXT, row[:plain].to_s, [room - x, 1].max), c[:dim])
      end
    end
  end
end
