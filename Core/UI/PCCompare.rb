# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Reloaded PC's Compare (Step 6)
#==============================================================================
# More of the PC scene (UI/PCScene.rb), his Step 6 picks (2026-10-24):
# Actions Then Pick. Compare in a Pokémon's Actions (Kanto Reloaded's own,
# registered in Core/PC/ReloadedPC.rb), then the cursor picks the second
# from any box or the party: COMPARE WITH LAPRAS in the box name's place
# (Header Banner), the first one marked with the regular cursor in gold
# (his ask). A on another opens the Compare screen (A Table in the Middle):
# the two face each other on top; a row per stat, then the base stat total,
# IVs and EVs, with bars growing outward, the better one's bar and number
# in the row's own colour, the other's bar grey (his ask, 2026-10-25);
# nature (its + stat green, its - stat red), ability and item (in its Bag
# pocket's colour) under them; X shows their
# moves instead, in detail (his ask): type, category, power, accuracy, PP,
# and the highlighted move's description. A picks another to compare
# with, B goes back.
#==============================================================================

return unless defined?(Reloaded::PCScene)

module Reloaded
  module PCScene
    CMP_STATS = [[:totalhp, "HP"], [:attack, "ATK"], [:defense, "DEF"], [:spatk, "SPA"], [:spdef, "SPD"], [:speed, "SPE"]].freeze
    CMP_SHORT = { :HP => "HP", :ATTACK => "ATK", :DEFENSE => "DEF", :SPECIAL_ATTACK => "SPA", :SPECIAL_DEFENSE => "SPD",
                  :SPEED => "SPE" }.freeze
    CMP_BAR = 150
    # Each row's colour (his ask, then his changes): HP green, ATK and SPA
    # red, DEF and SPD blue (ATK and DEF the darker ones, SPD a lighter
    # blue), SPE pink, BASE a light tan, IVS orange, EVS purple, as [hue,
    # saturation, lift], drawn at the theme's one lightness (PartyPaint's
    # Vivid), lift above it
    CMP_TINTS = [[130, 0.80, 0.0], [0, 0.85, -0.12], [215, 0.85, -0.12], [0, 0.85, 0.0], [215, 0.85, 0.10], [330, 0.85, 0.0],
                 [36, 0.45, 0.12], [26, 0.95, 0.0], [275, 0.80, 0.0]].freeze
    CMP_ROW = 18
    CMP_Y = 104
    CMP_MOVE_H = 38           # a move's two lines on the moves page

    # Compare (the PC action): the cursor picks the second
    def kr_compare(pk)
      return false if @kr_fb || pk.nil? || pk.egg?
      @kr_compare = { :first => pk }
      refresh
      return true
    end

    private

    def comparing?
      return @kr_compare ? true : false
    end

    # A while picking: the one under the cursor against the first
    def compare_choose
      pk = under_cursor
      if pk.nil? || pk.egg? || pk.equal?(@kr_compare[:first])
        pbPlayBuzzerSE
        return :stay
      end
      @kr_compare = nil if compare_screen(@kr_compare[:first], pk) == :done
      refresh
      return :stay
    end

    def compare_cancel
      @kr_compare = nil
      pbPlayCancelSE
      refresh
      return :stay
    end

    # The Compare screen: :again (A, pick another) or :done (B)
    def compare_screen(a, b)
      @kr_cmp = { :a => a, :b => b, :moves => false }
      pbPlayDecisionSE
      refresh
      ret = :done
      loop do
        Graphics.update
        Input.update
        update
        pt = Reloaded::Pointer
        if Input.trigger?(Input::USE) || pt.left?
          pbPlayDecisionSE
          ret = :again
          break
        elsif Input.trigger?(Input::ACTION)
          pbPlayCursorSE
          @kr_cmp[:moves] = !@kr_cmp[:moves]
          @kr_cmp[:msel] = [0, 0]
          refresh
        elsif @kr_cmp[:moves] && (dir = repeat_dir)
          compare_move_cursor(dir)
        elsif Input.trigger?(Input::BACK) || pt.right?
          pbPlayCancelSE
          break
        end
      end
      return ret
    ensure
      @kr_cmp = nil
      dispose_compare_icons
    end

    #--------------------------------------------------------------------------
    # The first one's gold cursor (his ask: the regular cursor, in gold)
    #--------------------------------------------------------------------------
    def gold_value
      return (Reloaded::Palette::COLORS.index { |n, *_r| n == "Gold" } || 14) + 1
    end

    def place_gold(rect)
      return unless @kr_gold && !@kr_gold.disposed?
      unless rect
        @kr_gold.visible = false
        return
      end
      x, y, w, h = rect
      key = [w, h, palette[:light] ? 1 : 0]
      @kr_gold_cache ||= {}
      bm = @kr_gold_cache[key]
      bm = @kr_gold_cache[key] = P.cursor_bitmap(w, h, gold_value, palette) if bm.nil? || bm.disposed?
      @kr_gold.bitmap = bm
      @kr_gold.x = x
      @kr_gold.y = y
      @kr_gold.opacity = P.cursor_opacity(@frame)
      @kr_gold.visible = true
    end

    # Where the first one is on screen (its box shown, or the party)
    def gold_rect
      return nil unless @kr_compare
      first = @kr_compare[:first]
      if (i = (0...PokemonBox::BOX_SIZE).find { |k| box[k].equal?(first) }) && !@kr_party_only
        sx, sy, = slot_rect(i)
        return [sx + 1, sy + 1, CELL_W - 2, CELL_H - 2]
      end
      if (i = @storage.party.index { |p| p.equal?(first) })
        cx, = party_centre(i)
        x0 = cx - PARTY_STEP / 2 + 2
        return [x0, PARTY_Y + 16, PARTY_STEP - 4, 60]
      end
      return nil
    end

    def dispose_gold
      @kr_gold.dispose if @kr_gold && !@kr_gold.disposed?
      @kr_gold = nil
      (@kr_gold_cache || {}).each_value { |b| b.dispose if b && !b.disposed? }
      @kr_gold_cache = {}
    end

    #--------------------------------------------------------------------------
    # Drawing the Compare screen (his pick: A Table in the Middle)
    #--------------------------------------------------------------------------
    def draw_compare(base, top, c)
      PP.paint_background(base, c)
      PP.paint_title(top, c, _INTL("Compare"))
      a = @kr_cmp[:a]
      b = @kr_cmp[:b]
      compare_card(base, top, c, a, 6, :left)
      compare_card(base, top, c, b, W / 2 + 6, :right)
      @kr_cmp[:moves] ? compare_moves(top, c, a, b) : compare_rows(base, top, c, a, b)
    end

    # A card on top: the picture at the outer end, facing the other one
    def compare_card(base, top, c, pk, x0, side)
      w = W / 2 - 12
      tint = tone(pk)
      PP.chamfer_grad(base, x0, 34, x0 + w, 96, 10, mix(c[:panel], tint, 0.35), mix(c[:panel], c[:dark], 0.3), mix(c[:line], tint, 0.5))
      s = compare_icon(pk, side)
      place(s, side == :left ? x0 + 34 : x0 + w - 34, 64, 46, 1.0) if s
      tx = side == :left ? x0 + 70 : x0 + 10
      P.text(top, tx, 40, w - 80, 18, PF.fit(PF::TEXT, pk.name.to_s, w - 84), c[:txt], PF::TEXT)
      P.text(top, tx, 58, 100, 12, _INTL("Lv. {1}", pk.level), c[:gold], PF::TINY)
      sheet = picture(PP::TYPES_BIG)
      return unless sheet
      types_of(pk).each_with_index do |t, j|
        top.stretch_blt(Rect.new(tx + j * 42, 72, 40, 18), sheet, Rect.new(0, PP.type_row(t) * 28, 64, 28))
      end
    end

    def compare_icon(pk, side)
      @kr_cmp_icons ||= {}
      s, who = @kr_cmp_icons[side]
      return s if s && !s.disposed? && who.equal?(pk)
      s.dispose if s && !s.disposed?
      s = Reloaded::PartyIcons.icon(pk, @viewport, 2)
      @kr_cmp_icons[side] = [s, pk] if s
      return s
    end

    def dispose_compare_icons
      (@kr_cmp_icons || {}).each_value { |s, _pk| s.dispose if s && !s.disposed? }
      @kr_cmp_icons = {}
    end

    # The numbers: each stat, the base stat total, IVs and EVs
    def compare_values(pk)
      stats = CMP_STATS.map { |m, _l| (pk.send(m) rescue 0).to_i }
      bst = defined?(::KIF::BoxSort) ? ::KIF::BoxSort.value(pk, :bst).to_i : (pk.baseStats.values.sum rescue 0)
      ivs = (pk.iv.values.sum rescue 0).to_i
      evs = (pk.ev.values.sum rescue 0).to_i
      return stats + [bst, ivs, evs]
    end

    def compare_rows(base, top, c, a, b)
      labels = CMP_STATS.map { |_m, l| _INTL(l) } + [_INTL("BASE"), _INTL("IVS"), _INTL("EVS")]
      va = compare_values(a)
      vb = compare_values(b)
      cx = W / 2
      labels.each_with_index do |label, k|
        y = CMP_Y + k * CMP_ROW
        P.text(top, cx - 24, y, 48, 14, label, c[:dim], PF::TINY, 2)
        most = [va[k], vb[k], 1].max
        tint = row_tint(c, k)
        [[va[k], vb[k], -1], [vb[k], va[k], 1]].each do |v, o, dir|
          len = (v * CMP_BAR / most).clamp(2, CMP_BAR)
          lit = v > o
          col = lit ? tint : mix(c[:line], c[:txt], 0.35)
          bx = dir < 0 ? cx - 30 - len : cx + 30
          base.fill_rect(bx, y + 4, len, 6, col)
          vx = dir < 0 ? cx - 30 - len - 40 : cx + 30 + len + 4
          P.text(top, vx, y, 36, 14, v.to_s, lit ? tint : c[:txt], PF::TINY, dir < 0 ? 1 : 0)
        end
      end
      y = CMP_Y + labels.length * CMP_ROW + 4
      top.fill_rect(20, y, W - 40, 1, c[:line])
      about = [[_INTL("Nature"), nature_parts(c, a), nature_parts(c, b)],
               [_INTL("Ability"), [[(a.ability ? a.ability.name : "-").to_s, c[:txt]]], [[(b.ability ? b.ability.name : "-").to_s, c[:txt]]]],
               [_INTL("Item"), item_parts(c, a), item_parts(c, b)]]
      about.each_with_index do |(k, l, r), j|
        yy = y + 6 + j * 16
        P.text(top, cx - 30, yy, 60, 14, k, c[:dim], PF::TINY, 2)
        parts_line(top, cx - 40, yy, cx - 50, l, true)
        parts_line(top, cx + 40, yy, cx - 50, r, false)
      end
    end

    # A row's colour: its hue at the theme's one lightness
    def row_tint(c, k)
      hue, sat, lift = CMP_TINTS[k] || CMP_TINTS[0]
      return PP.hsl_color(hue, sat, (PP::INK_LIGHTNESS[c[:light] ? :light : :dark] + lift).clamp(0.0, 0.9))
    end

    # Words in colours on one line ([[words, colour]]), ending at x (right)
    # or starting there; the last part shortened to fit w
    def parts_line(b, x, y, w, parts, right)
      room = w
      parts = parts.map do |words, col|
        words = PF.fit(PF::TINY, words, room)
        room -= P.width(PF::TINY, words)
        [words, col]
      end
      total = parts.sum { |words, _col| P.width(PF::TINY, words) }
      x -= total if right
      parts.each do |words, col|
        ww = P.width(PF::TINY, words)
        P.text(b, x, y, ww + 2, 14, words, col, PF::TINY)
        x += ww
      end
    end

    # Modest (+SPA -ATK), the + stat green and the - stat red (his ask); a
    # neutral nature by its name alone
    def nature_parts(c, pk)
      n = pk.nature
      return [["-", c[:txt]]] unless n
      changes = n.respond_to?(:stat_changes) ? (n.stat_changes || []) : []
      up = changes.find { |_s, v| v > 0 }
      down = changes.find { |_s, v| v < 0 }
      return [[n.name.to_s, c[:txt]]] unless up && down
      return [[n.name.to_s + " (", c[:txt]], ["+" + (CMP_SHORT[up[0]] || up[0].to_s), c[:green]], [" ", c[:txt]],
              ["-" + (CMP_SHORT[down[0]] || down[0].to_s), c[:red]], [")", c[:txt]]]
    end

    # Its held item in its Bag pocket's colour (his ask; the Reloaded Bag's)
    def item_parts(c, pk)
      return [[_INTL("None"), c[:txt]]] unless pk.item
      id = pk.item.respond_to?(:id) ? pk.item.id : pk.item
      ink = defined?(Reloaded::BagLook) ? Reloaded::BagLook.item_colour(c, id) : c[:txt]
      return [[pk.item.name.to_s, ink]]
    end

    # X: the two's moves in detail (his ask): each with its type, category,
    # power, accuracy and PP; the highlighted one's description at the foot
    def compare_moves(top, c, a, b)
      sheet = picture(PP::TYPES_BIG)
      side_w = W / 2 - 20
      [[a, 10, 0], [b, W / 2 + 10, 1]].each do |pk, x0, side|
        moves = (pk.moves || []).first(4)
        moves.each_with_index do |m, k|
          y = CMP_Y + k * CMP_MOVE_H
          @cursor_rect = [x0 - 4, y - 2, side_w + 8, CMP_MOVE_H - 2] if @kr_cmp[:msel] == [side, k]
          type = (m.type rescue nil)
          top.stretch_blt(Rect.new(x0, y + 1, 36, 16), sheet, Rect.new(0, PP.type_row(type) * 28, 64, 28)) if sheet && type
          P.text(top, x0 + 42, y, side_w - 42, 18, PF.fit(PF::TEXT, m.name.to_s, side_w - 42), c[:txt])
          cat = (m.category rescue 2).to_i
          words, tint = [[_INTL("PHYSICAL"), c[:red]], [_INTL("SPECIAL"), c[:blue]], [_INTL("STATUS"), c[:dim]]][cat.clamp(0, 2)]
          pw = P.pill(top, x0, y + 18, words, tint, c[:dark], false).to_i
          power = (m.base_damage rescue 0).to_i
          acc = (m.accuracy rescue 0).to_i
          facts = [_INTL("POW {1}", power > 1 ? power : "-"), _INTL("ACC {1}", acc > 0 ? acc : "-"),
                   _INTL("PP {1}/{2}", (m.pp rescue 0), (m.total_pp rescue 0))]
          fx = x0 + [pw, 56].max + 6
          facts.each { |f| fx += P.text(top, fx, y + 19, 60, 12, f, c[:dim], PF::TINY) + 8 }
        end
        P.text(top, x0, CMP_Y + 4, side_w, 18, _INTL("No moves."), c[:dim]) if moves.empty?
      end
      # the highlighted move, explained
      side, k = @kr_cmp[:msel] || [0, 0]
      m = (([a, b][side].moves || [])[k] rescue nil)
      y0 = CMP_Y + 4 * CMP_MOVE_H + 6
      top.fill_rect(20, y0 - 4, W - 40, 1, c[:line])
      return unless m
      P.text(top, 24, y0, W - 48, 18, m.name.to_s, c[:txt])
      P.wrap((m.description rescue "").to_s, W - 48).first(3).each_with_index do |line, i|
        P.text(top, 24, y0 + 19 + i * 17, W - 48, 17, line, c[:dim])
      end
    end

    # On the moves: Up / Down through a side's moves, Left / Right between
    # the two
    def compare_move_cursor(dir)
      side, k = @kr_cmp[:msel] || [0, 0]
      lists = [@kr_cmp[:a], @kr_cmp[:b]].map { |pk| (pk.moves || []).first(4) }
      case dir
      when :up, :down
        n = lists[side].length
        return if n <= 1
        k = (k + (dir == :up ? -1 : 1)) % n
      else
        other = 1 - side
        return if lists[other].empty?
        side = other
        k = k.clamp(0, lists[side].length - 1)
      end
      @kr_cmp[:msel] = [side, k]
      pbPlayCursorSE
      refresh
    end

    def compare_hints
      if @kr_cmp[:moves]
        return [[:ud, _INTL("Choose")], [button(:A), _INTL("Stats")], [button(:C), _INTL("Pick Another")], [button(:B), _INTL("Back")]]
      end
      return [[button(:A), _INTL("Moves")], [button(:C), _INTL("Pick Another")], [button(:B), _INTL("Back")]]
    end
  end
end
