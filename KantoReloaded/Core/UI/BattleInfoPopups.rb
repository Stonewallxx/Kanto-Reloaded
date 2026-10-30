# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Battle Info's Abilities and Moves popups
#==============================================================================
# His picks, 2026-10-29 (sheets battle-info-abil and battle-info-moves), on
# a Pokémon's tab:
#
#   A   Abilities: Double Abilities' card, with an Abilities tab (its
#       ability, a fusion's two with Double Abilities, KIF-ER's Ability 2)
#       and an Innates tab (KIF-ER's), Left and Right between them; with no
#       innates, no tabs. A foe's not seen yet is ???, and says when it shows.
#   Y   Moves: Every Move Explained: each move's type, name, category,
#       power, accuracy, PP and words. A foe's once it has used them (its PP
#       as its most).
#
# B (or A, or a click) closes them. A list too long for the screen (a
# KIF-ER fusion's six innates) scrolls with Up and Down (the wheel too).
# Drawn solid on the popups' layer, the Pokémon's icons under it.
#==============================================================================

module Reloaded
  class BattleInfoScreen
    POP_W = 480
    POP_LINE = 19
    MOVE_LINE = 18

    def open_abilities
      bt = @battle.battlers[tab] if tab.is_a?(Integer)
      return nil unless bt
      pbPlayDecisionSE
      pages = ability_pages(bt)
      popup_loop(pages.length) { |on| paint_abilities(palette, bt, pages, on) }
      return nil
    end

    def open_moves
      bt = @battle.battlers[tab] if tab.is_a?(Integer)
      return nil unless bt
      pbPlayDecisionSE
      popup_loop(1) { |_on| paint_moves(palette, bt) }
      return nil
    end

    private

    # Until B, A or a click (a click on a tab turns to it); Left and Right
    # (LB and RB too) turn the tabs; Up and Down scroll a long one (the
    # painter says how far it can: @pop_scroll_max)
    def popup_loop(count)
      on = 0
      @pop_scroll = 0
      redraw = true
      loop do
        if redraw
          overlay.clear
          @pop_tab_hits = []
          @pop_scroll_max = 0
          yield on
          redraw = false
        end
        Graphics.update
        Input.update
        update_frame
        break if over?
        pt = Reloaded::Pointer
        dir = pt.wheel != 0 ? -pt.wheel : (Input.repeat?(Input::UP) ? -1 : (Input.repeat?(Input::DOWN) ? 1 : 0))
        if count > 1 && pt.left? && (i = pt.hit(@pop_tab_hits)) && i != on
          on = i
          @pop_scroll = 0
          pbPlayCursorSE
          redraw = true
        elsif count > 1 && (Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT) || Input.trigger?(Input::L) || Input.trigger?(Input::R))
          on = (on + (Input.repeat?(Input::LEFT) || Input.trigger?(Input::L) ? -1 : 1)) % count
          @pop_scroll = 0
          pbPlayCursorSE
          redraw = true
        elsif dir != 0 && @pop_scroll_max > 0
          to = (@pop_scroll + dir).clamp(0, @pop_scroll_max)
          next if to == @pop_scroll
          @pop_scroll = to
          pbPlayCursorSE
          redraw = true
        elsif Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || pt.right? || pt.left?
          pbPlayCancelSE
          break
        end
      end
    ensure
      overlay.clear if @overlay_sprite && !@overlay_sprite.disposed?
    end

    #--------------------------------------------------------------------------
    # Abilities
    #--------------------------------------------------------------------------
    # [[tab label, rows]]: a row is [name or nil (not seen yet), tag, words]
    def ability_pages(bt)
      known = RD.known?(@battle, bt)
      main = []
      pair = double_pair(bt)
      if pair
        look = Reloaded::DoubleAbilitiesLook
        er = Reloaded::DoubleAbilities.elite_redux?(bt.pokemon)
        pair.each do |side, id|
          name = look.ability_name(id, er)
          seen = known || NT.ability_shown?(@battle, bt, name) || (id == bt.ability_id && NT.ability_known?(@battle, bt))
          main << [seen ? name : nil, look.side_tag(side), seen ? look.ability_text(id, er) : _INTL("Shown once the battle reveals it.")]
        end
      elsif NT.ability_known?(@battle, bt)
        main << [bt.abilityName.to_s, _INTL("ABILITY"), ability_words(bt.ability_id)]
      else
        main << [nil, _INTL("ABILITY"), _INTL("Shown once the battle reveals it.")]
      end
      innates = []
      NT.other_abilities(@battle, bt).each do |label, name, words|
        next if pair && label == "ABILITY 2"        # KIF-ER's Ability 2 is the pair's other one
        if label == "INNATE"
          innates << [name, label, name ? words.to_s : _INTL("Shown once it activates.")]
        else
          main << [name, label, name ? words.to_s : _INTL("Shown once the battle reveals it.")]
        end
      end
      pages = [[_INTL("ABILITIES"), main]]
      pages << [_INTL("INNATES"), innates] unless innates.empty?
      return pages
    end

    # A fusion's two abilities with Double Abilities On (head first), or nil
    def double_pair(bt)
      da = Reloaded::DoubleAbilities if defined?(Reloaded::DoubleAbilities)
      return nil unless da && defined?(Reloaded::DoubleAbilitiesLook) && da.on? && bt.pokemon
      return da.pair(bt.pokemon)
    rescue StandardError
      return nil
    end

    def ability_words(id)
      return (GameData::Ability.get(id).description.to_s rescue "")
    end

    def paint_abilities(c, bt, pages, on)
      rows = pages[on][1]
      tabs = pages.length > 1
      blocks = rows.map { |name, label, words| [name, label, P.wrap(words.to_s, POP_W - 40).first(3)] }
      height = proc { |blk| 38 + blk[2].length * POP_LINE }
      head = 40 + (tabs ? 30 : 0)
      room = H - 16 - head - 32
      # too many to fit (six innates): the ones from @pop_scroll that fit
      if blocks.sum(&height) > room
        fit = 0
        used = 0
        blocks.reverse_each { |blk| break if used + height.call(blk) > room; used += height.call(blk); fit += 1 }
        @pop_scroll_max = blocks.length - fit
        @pop_scroll = @pop_scroll.clamp(0, @pop_scroll_max)
        shown = []
        used = 0
        blocks[@pop_scroll..-1].each { |blk| break if used + height.call(blk) > room; used += height.call(blk); shown << blk }
        scrolled = true
      else
        shown = blocks
        scrolled = false
      end
      h = scrolled ? H - 16 : head + shown.sum(&height) + 32
      b, px, py = popup_frame(c, _INTL("{1}'s Abilities", bt.name), h)
      pop_tabs(b, c, py + 42, pages.map(&:first), on) if tabs
      known = RD.known?(@battle, bt)
      y = py + head + 4
      shown.each_with_index do |(name, label, lines), i|
        P.text(b, px + 20, y, 340, 28, name ? PF.fit(PF::TITLE, name, 330) : "???", name ? c[:head] : c[:dim], PF::TITLE)
        pill(b, c, px + 26 + P.width(PF::TITLE, PF.fit(PF::TITLE, name, 330)), y + 8, _INTL("REVEALED"), :green) if name && !known
        pop_tag(b, c, px + POP_W - 16, y + 4, label)
        lines.each_with_index { |ln, k| P.text(b, px + 20, y + 31 + k * POP_LINE, POP_W - 40, POP_LINE, ln, name ? c[:txt] : c[:dim]) }
        y += 38 + lines.length * POP_LINE
        b.fill_rect(px + 12, y - 6, POP_W - 24, 1, c[:line]) if i < shown.length - 1
      end
      if scrolled
        # the scroll bar at the right edge
        top_y = py + head + 4
        track = h - head - 32 - 8
        len = [track * shown.length / blocks.length, 12].max
        at = (track - len) * @pop_scroll / [@pop_scroll_max, 1].max
        P.ui.rbox(b, px + POP_W - 8, top_y, px + POP_W - 5, top_y + track, 1, c[:line])
        P.ui.rbox(b, px + POP_W - 8, top_y + at, px + POP_W - 5, top_y + at + len, 1, c[:selb])
      end
      pairs = []
      pairs << [:lr, _INTL("Tabs")] if tabs
      pairs << [:ud, _INTL("Scroll")] if scrolled
      pairs << [button(:B), _INTL("Close")]
      pop_hints(b, c, py + h - 28, pairs)
    end

    #--------------------------------------------------------------------------
    # Moves
    #--------------------------------------------------------------------------
    def paint_moves(c, bt)
      known = RD.known?(@battle, bt)
      used = NT.moves_used(@battle, bt)
      blocks = bt.moves.compact.first(4).map do |m|
        on = known || used.include?(m.id)
        words = on ? (GameData::Move.get(m.id).description.to_s rescue "") : _INTL("Not used yet.")
        [m, on, P.small_wrap(overlay, words, POP_W - 40).first(2)]
      end
      h = 40 + blocks.sum { |_m, _o, lines| 34 + lines.length * MOVE_LINE } + 32
      b, px, py = popup_frame(c, _INTL("{1}'s Moves", bt.name), h)
      y = py + 44
      blocks.each_with_index do |(m, on, lines), i|
        if on
          type = RD.calc_type(m, bt)
          small_type(b, type, px + 20, y + 4)
          nw = P.text(b, px + 42, y, 170, 24, PF.fit(PF::TEXT, m.name.to_s, 160), type_ink(c, type))
          category(b, m.category, px + 42 + nw + 8, y + 3)
          move_facts(b, c, px + POP_W - 20, y, m, known)
        else
          P.text(b, px + 20, y, 100, 24, "???", c[:dim])
        end
        lines.each_with_index { |ln, k| P.small(b, px + 20, y + 25 + k * MOVE_LINE, POP_W - 40, MOVE_LINE, ln, on ? c[:txt] : c[:dim]) }
        y += 34 + lines.length * MOVE_LINE
        b.fill_rect(px + 12, y - 5, POP_W - 24, 1, c[:line]) if i < blocks.length - 1
      end
      pop_hints(b, c, py + h - 28, [[button(:B), _INTL("Close")]])
    end

    # POWER, ACC and PP (a foe's PP as its most), ending at x1
    def move_facts(b, c, x1, y, m, known)
      pow = m.baseDamage.to_i > 1 ? m.baseDamage.to_s : "-"
      acc = m.accuracy.to_i > 0 ? m.accuracy.to_s : "-"
      pp = known ? "#{m.pp}/#{m.total_pp}" : m.total_pp.to_s
      x = x1
      [[_INTL("PP"), pp], [_INTL("ACC"), acc], [_INTL("POWER"), pow]].each do |label, v|
        vw = P.width(PF::TEXT, v)
        P.text(b, x - vw, y, vw + 2, 22, v, c[:txt])
        lw = P.width(PF::TINY, label)
        P.text(b, x - vw - 4 - lw, y + 3, lw + 2, 16, label, c[:dim], PF::TINY)
        x -= vw + 4 + lw + 14
      end
    end

    #--------------------------------------------------------------------------
    # Pieces
    #--------------------------------------------------------------------------
    # The card: dimmed behind, the plate, its title in the big font
    def popup_frame(c, title, h)
      b = overlay
      px = (W - POP_W) / 2
      py = [(H - h) / 2, 8].max
      Reloaded::Dialogs.frame(b, c, px, py, POP_W, h, "")
      P.text(b, px + 8, py + 4, POP_W - 16, 26, PF.fit(PF::TITLE, title, POP_W - 28), c[:title], PF::TITLE, 2)
      return [b, px, py]
    end

    # The popup's tabs, centred under its title
    def pop_tabs(b, c, y, labels, on)
      widths = labels.map { |l| P.width(PF::TINY, l) + 24 }
      x = W / 2 - (widths.sum + 4 * (labels.length - 1)) / 2
      labels.each_with_index do |l, i|
        lit = i == on
        PP.chamfer_grad(b, x, y, x + widths[i], y + 21, 6, lit ? mix(c[:panel2], c[:selb], 0.55) : mix(c[:panel2], c[:panel], 0.4),
                        lit ? mix(c[:panel2], c[:selb], 0.25) : c[:panel2], lit ? c[:selb] : c[:line])
        P.text(b, x, y, widths[i], 21, l, lit ? c[:strong] : c[:dim], PF::TINY, 2)
        @pop_tab_hits << [i, x, y, x + widths[i], y + 21]
        x += widths[i] + 4
      end
    end

    # An ABILITY, INNATE, HEAD or BODY badge, its right edge at x (the
    # Abilities Card's, Double Abilities)
    def pop_tag(b, c, x, y, label)
      P.small_font(b)
      w = b.text_size(label).width + 14
      P.ui.rbox(b, x - w, y, x, y + 19, 5, c[:pill])
      P.small(b, x - w, y, w, 20, label, c[:txt], 2)
    end

    def pop_hints(b, c, y, pairs)
      pr = Reloaded::Prompts
      w = P.hints_width(b, pairs, pr.style, PF::TEXT)
      P.draw_hints(b, W / 2 - w / 2, y, c, pairs, pr.style, nil, nil, PF::TEXT)
    end
  end
end
