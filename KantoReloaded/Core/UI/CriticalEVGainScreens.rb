# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Critical EV Gain's popups
#==============================================================================
# The looks he picked (2026-10-25; the sheets cev-summary, cev-round2):
#
#   EV Gains       Party Board (Q14 Design 2): one popup, a row per Pokémon
#                  that earned EVs, its gain in each stat's cell, a
#                  critical's cell gold (normal and critical together); one
#                  that fainted before the win dimmed with a FAINTED pill;
#                  the key and one note at the foot (a Power item's boost,
#                  or where a full stat's critical went)
#   Toast          Summary set to Toast: "Pikachu: +3 Attack" with a
#                  CRITICAL pill, no button
#   EV Points      with KIF's EV Allocation On (the cev-points sheet, Design
#                  1 Three Columns): EARNED, CRITICAL (gold) and TO SPEND for
#                  each Pokémon, "Spend Them on the Summary's Skills Page" at
#                  the foot; the toast says "+3 EV Points"
#   The Mochi      the Fresh-Start Mochi asks first: its six EVs now, all
#                  back to 0, the Mochi used up; Reset or Keep (Keep first)
#
# Each on its own layer over whatever is on screen, in the Theme Mode's
# colours. A or B (or a click) closes the board.
#==============================================================================

return unless defined?(Reloaded::Pixel) && defined?(::KIF::PixelFont)

module Reloaded
  module CriticalEVGainScreen
    PF = ::KIF::PixelFont
    P = Reloaded::Pixel
    PP = Reloaded::PartyPaint
    DG = Reloaded::Dialogs
    CEV = Reloaded::CriticalEVGain
    W = 512
    H = 384
    ROW_H = 34
    CELL_W = 44
    GOLD = [240, 200, 80].freeze
    RED = [240, 100, 90].freeze
    POINT_COLS = [["EARNED", 60], ["CRITICAL", 76], ["TO SPEND", 84]].freeze   # the points board's columns (label, width)

    class << self
      # For tests: what's drawn
      attr_reader :sprite

      def palette
        return Reloaded::Palette.map_menu
      end

      # The Pokémon a picture is drawn from: a mod's look can stand in
      # (Ghostly Possession's possessed fusion); the name stays its own
      def look_of(pkmn)
        return pkmn
      end

      #------------------------------------------------------------------------
      # EV Gains: the Party Board
      #------------------------------------------------------------------------
      def board(list)
        return if list.nil? || list.empty?
        open_layer
        @list = list.first(6)
        @icons = @list.map { |r| Reloaded::PartyIcons.icon(look_of(r[:pokemon]), @viewport, 1) }
        draw_board
        loop do
          Graphics.update
          Input.update
          @icons.each { |s| s.update if s && !s.disposed? }
          pt = Reloaded::Pointer
          break if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK) || pt.left? || pt.right?
        end
        pbPlayDecisionSE
      ensure
        close_layer
      end

      # Nothing to show yet (the Overworld Menu's EV Gains before a win)
      def nothing
        Reloaded::Toast.show(_INTL("No EVs Gained Yet This Session"))
      end

      def toast(list)
        list = Array(list).select { |r| CEV.crit_total(r) > 0 }
        return if list.empty?
        r = list.first
        if r[:crit_points].to_i > 0
          text = _INTL("{1}: +{2} EV Points", r[:pokemon].name, r[:crit_points])
        else
          i = r[:crit].index(r[:crit].max)
          text = _INTL("{1}: +{2} {3}", r[:pokemon].name, r[:crit].sum, CEV::STAT_NAMES[i])
        end
        text += " " + _INTL("(+{1} More)", list.length - 1) if list.length > 1
        bm = (Reloaded::PartyIcons.species_bitmap(look_of(r[:pokemon]).species) rescue nil)
        Reloaded::Toast.show(text, :icon => bm, :pill => [_INTL("CRITICAL"), :gold])
      end

      def draw_board
        return draw_points_board if @list.any? { |r| r[:points] }
        c = palette
        o = @sprite.bitmap
        o.clear
        n = @list.length
        crits = @list.count { |r| CEV.crit_total(r) > 0 }
        w = 456
        h = 40 + 18 + n * ROW_H + (crits > 0 ? 34 : 8)
        x = (W - w) / 2
        y = (H - P::HINT_H - h) / 2
        DG.frame(o, c, x, y, w, h, _INTL("EV Gains"))
        cx0 = x + 168
        6.times { |k| P.text(o, cx0 + k * CELL_W, y + 42, CELL_W - 4, 12, CEV::STAT_SHORT[k], c[:head], PF::TINY, 2) }
        fill_g, = PP.badge(c, GOLD)
        gold = PP.ink(c, GOLD)
        @list.each_with_index do |r, i|
          ry = y + 58 + i * ROW_H
          o.fill_rect(x + 12, ry - 2, w - 24, 1, c[:line]) if i > 0
          place_icon(i, x + 28, ry + 14, 34)
          name = PF.fit(PF::TEXT, r[:pokemon].name.to_s, 110)
          if r[:fainted]
            P.text(o, x + 50, ry - 4, 110, 20, name, c[:dim], PF::TEXT)
            P.pill(o, x + 50, ry + 16, _INTL("FAINTED"), *PP.badge(c, RED), false)
          else
            P.text(o, x + 50, ry, 110, ROW_H - 4, name, c[:txt], PF::TEXT)
          end
          6.times do |k|
            nrm = r[:normal][k].to_i
            cr = r[:crit][k].to_i
            bx = cx0 + k * CELL_W
            if cr > 0
              PP.chamfer(o, bx, ry + 3, bx + CELL_W - 4, ry + ROW_H - 7, 5, fill_g, gold)
              P.text(o, bx, ry + 1, CELL_W - 4, ROW_H - 8, "+#{nrm + cr}", gold, PF::TEXT, 2)
            elsif nrm > 0
              ::KIF::PixelUI.rbox(o, bx, ry + 3, bx + CELL_W - 4, ry + ROW_H - 7, 4,
                                  c[:light] ? Reloaded::Palette.mix(c[:panel2], c[:segon], 0.18) : Reloaded::Palette.mix(c[:dark], c[:panel2], 0.4))
              P.text(o, bx, ry + 1, CELL_W - 4, ROW_H - 8, "+#{nrm}", c[:txt], PF::TEXT, 2)
            end
          end
        end
        if crits > 0
          o.fill_rect(x + 12, y + h - 30, w - 24, 1, c[:line])
          PP.chamfer(o, x + 18, y + h - 20, x + 32, y + h - 10, 3, fill_g, gold)
          kw = P.small(o, x + 38, y + h - 23, 80, 18, _INTL("Critical"), c[:dim])
          item, text, col = note(c)
          note_line(o, c, x + 38 + kw.to_i + 18, y + h - 22, w - 80 - kw.to_i, item, text, col) if text
        end
        pairs = [[hint_button(:C), _INTL("OK")]]
        P.hints(o, o, c, pairs, Reloaded::Prompts.style)
      end

      # With EV Allocation (his pick, Three Columns): the points each earned,
      # a critical's in gold, and those waiting to be spent; the foot points
      # to the Summary (the key first when there's a critical)
      def draw_points_board
        c = palette
        o = @sprite.bitmap
        o.clear
        n = @list.length
        crits = @list.count { |r| r[:crit_points].to_i > 0 }
        w = 456
        h = 40 + 18 + n * ROW_H + 34
        x = (W - w) / 2
        y = (H - P::HINT_H - h) / 2
        DG.frame(o, c, x, y, w, h, _INTL("EV Gains"))
        cx = x + 190
        POINT_COLS.each { |label, cw| P.text(o, cx, y + 42, cw - 4, 12, _INTL(label), c[:head], PF::TINY, 2); cx += cw + 8 }
        fill_g, = PP.badge(c, GOLD)
        gold = PP.ink(c, GOLD)
        @list.each_with_index do |r, i|
          ry = y + 58 + i * ROW_H
          o.fill_rect(x + 12, ry - 2, w - 24, 1, c[:line]) if i > 0
          place_icon(i, x + 28, ry + 14, 34)
          name = PF.fit(PF::TEXT, r[:pokemon].name.to_s, 110)
          if r[:fainted]
            P.text(o, x + 50, ry - 4, 110, 20, name, c[:dim], PF::TEXT)
            P.pill(o, x + 50, ry + 16, _INTL("FAINTED"), *PP.badge(c, RED), false)
          else
            P.text(o, x + 50, ry, 110, ROW_H - 4, name, c[:txt], PF::TEXT)
          end
          bx = x + 190
          if r[:points].to_i > 0
            ::KIF::PixelUI.rbox(o, bx, ry + 3, bx + 56, ry + ROW_H - 7, 4,
                                c[:light] ? Reloaded::Palette.mix(c[:panel2], c[:segon], 0.18) : Reloaded::Palette.mix(c[:dark], c[:panel2], 0.4))
            P.text(o, bx, ry + 1, 56, ROW_H - 8, "+#{r[:points]}", c[:txt], PF::TEXT, 2)
          end
          bx += 68
          if r[:crit_points].to_i > 0
            PP.chamfer(o, bx, ry + 3, bx + 72, ry + ROW_H - 7, 5, fill_g, gold)
            P.text(o, bx, ry + 1, 72, ROW_H - 8, "+#{r[:crit_points]}", gold, PF::TEXT, 2)
          end
          bx += 84
          P.text(o, bx, ry + 1, 80, ROW_H - 8, r[:pool].to_i.to_s, c[:dim], PF::TEXT, 2)
        end
        o.fill_rect(x + 12, y + h - 30, w - 24, 1, c[:line])
        tx = x + 18
        if crits > 0
          PP.chamfer(o, x + 18, y + h - 20, x + 32, y + h - 10, 3, fill_g, gold)
          kw = P.small(o, x + 38, y + h - 23, 80, 18, _INTL("Critical"), c[:dim])
          tx = x + 38 + kw.to_i + 18
        end
        P.small(o, tx, y + h - 22, x + w - 18 - tx, 18, _INTL("Spend Them on the Summary's Skills Page"), c[:dim])
        P.hints(o, o, c, [[hint_button(:C), _INTL("OK")]], Reloaded::Prompts.style)
      end

      # One note at the foot: where a full stat's critical went, else the
      # Power item that doubled a critical's chance
      def note(c)
        moved = @list.find { |r| r[:moved] }
        if moved
          from, to, n = moved[:moved]
          return [nil, _INTL("{1}'s {2} Is Full: {3} Went to {4}", moved[:pokemon].name, CEV::STAT_NAMES[from], n, CEV::STAT_NAMES[to]),
                  c[:amber] || PP.ink(c, GOLD)]
        end
        boosted = @list.find { |r| (i = CEV::POWER_ITEMS.index(r[:item])) && r[:crit][i].to_i > 0 }
        if boosted
          i = CEV::POWER_ITEMS.index(boosted[:item])
          name = (GameData::Item.get(boosted[:item]).name rescue boosted[:item].to_s)
          return [boosted[:item], _INTL("{1}: {2} Chance x2", name, CEV::STAT_NAMES[i]), c[:dim]]
        end
        return [nil, nil, nil]
      end

      def note_line(b, c, x, y, w, item, text, col)
        if item
          item_icon(b, item, x, y + 1, 16)
          x += 20
          w -= 20
        end
        P.small(b, x, y, w, 18, PF.fit(PF::TINY, text, w), col)
      end

      def item_icon(b, id, x, y, size)
        file = (GameData::Item.icon_filename(id) rescue "Graphics/Items/#{id}")
        path = (pbResolveBitmap(file) rescue nil) || file
        bm = Bitmap.new(path)
        b.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, bm.width, bm.height))
        bm.dispose
      rescue StandardError
        nil
      end

      #------------------------------------------------------------------------
      # The Fresh-Start Mochi's question: true to reset
      #------------------------------------------------------------------------
      def mochi_ask(pkmn, item_name)
        open_layer
        choice = 1                               # Keep first: it wipes training
        draw_mochi(pkmn, item_name, choice)
        loop do
          Graphics.update
          Input.update
          pt = Reloaded::Pointer
          hit = pt.hit(@hits)
          if pt.moved? && hit && hit != choice
            choice = hit
            pbPlayCursorSE
            draw_mochi(pkmn, item_name, choice)
          end
          if pt.left? && hit
            choice = hit
            break
          elsif pt.right? || Input.trigger?(Input::BACK)
            choice = 1
            break
          elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
            target = Input.trigger?(Input::LEFT) ? 0 : 1
            next if target == choice
            choice = target
            pbPlayCursorSE
            draw_mochi(pkmn, item_name, choice)
          elsif Input.trigger?(Input::USE)
            break
          end
        end
        choice == 0 ? pbPlayDecisionSE : pbPlayCancelSE
        return choice == 0
      ensure
        close_layer
      end

      def draw_mochi(pkmn, item_name, choice)
        c = palette
        o = @sprite.bitmap
        o.clear
        @hits = []
        w = 380
        h = 182
        x = (W - w) / 2
        y = (H - P::HINT_H - h) / 2
        DG.frame(o, c, x, y, w, h, _INTL("Reset {1}'s EVs?", pkmn.name))
        ev = CEV::STATS.map { |s| pkmn.ev[s].to_i }
        cw = 52
        x0 = x + (w - 6 * cw - 5 * 4) / 2
        6.times do |k|
          cx = x0 + k * (cw + 4)
          P.text(o, cx, y + 44, cw, 12, CEV::STAT_SHORT[k], c[:head], PF::TINY, 2)
          ::KIF::PixelUI.rbox(o, cx, y + 58, cx + cw, y + 82, 5,
                              c[:light] ? Reloaded::Palette.mix(c[:panel2], PP::WHITE, 0.5) : Reloaded::Palette.mix(c[:dark], c[:panel2], 0.4), c[:line])
          P.text(o, cx, y + 59, cw, 22, ev[k].to_s, ev[k] > 0 ? c[:txt] : c[:dim], PF::TEXT, 2)
        end
        P.text(o, x, y + 92, w, 18, _INTL("All six go back to 0: {1} EVs of training.", ev.sum), c[:txt], PF::TEXT, 2)
        P.small(o, x, y + 112, w, 16, _INTL("The {1} is used up.", item_name), c[:dim], 2)
        gap = 8
        bw = (w - 28 - gap) / 2
        [[_INTL("Reset"), 0], [_INTL("Keep"), 1]].each do |label, i|
          bx = x + 14 + i * (bw + gap)
          on = choice == i
          DG.send(:button, o, c, bx, y + h - 38, bx + bw, y + h - 10, on)
          P.text(o, bx, y + h - 36, bw, 24, label, on ? c[:strong] : c[:txt], PF::TEXT, 2)
          @hits << [i, bx, y + h - 38, bx + bw, y + h - 10]
        end
        pairs = [[:lr, _INTL("Choose")], [hint_button(:C), _INTL("OK")], [hint_button(:B), _INTL("Back")]]
        P.hints(o, o, c, pairs, Reloaded::Prompts.style)
      end

      #------------------------------------------------------------------------
      # The layer
      #------------------------------------------------------------------------
      def hint_button(sym)
        return Reloaded::Prompts.input(sym) || Reloaded::Prompts.name(sym)
      end

      def open_layer
        close_layer
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 100_400
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = Bitmap.new(W, H)
        @icons = []
        @hits = []
      end

      def close_layer
        (@icons || []).each { |s| s.dispose if s && !s.disposed? }
        @icons = []
        @sprite.bitmap.dispose if @sprite && !@sprite.disposed? && @sprite.bitmap
        @sprite.dispose if @sprite && !@sprite.disposed?
        @viewport.dispose if @viewport && !@viewport.disposed?
        @sprite = @viewport = nil
      end

      def place_icon(i, cx, cy, size)
        s = @icons[i]
        return unless s
        Reloaded::PartyIcons.place(s, cx, cy)
        s.zoom_x = s.zoom_y = size / 64.0
      end
    end
  end
end
