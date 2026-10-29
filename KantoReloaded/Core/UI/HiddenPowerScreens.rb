# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Hidden Power's popups
#==============================================================================
# The looks he picked (2026-10-25; the sheets hp-researcher, hp-plates,
# hp-popups and hp-round2, the spin in hp-reel-spin.gif):
#
#   the researcher   Type Reel (Q10 Design 2): the Pokémon beside a reel of
#                    the 17 types, its own in the band. Spin ($5,000, green
#                    or red by your money) takes the money, decides the new
#                    type, and the reel spins two turns and slows onto it,
#                    about 2 seconds (A skips to it). Then "It landed on Ice,
#                    never Rock.", Again or Done. Not enough money: the line
#                    in red, Spin greyed and passed over, Keep picked
#   Unown            its ??? label: it hits every type the same, and nothing
#                    changes it
#   a plate          Use Several's notice: "Pikachu's Hidden Power Is Now
#                    Ice", ROCK > ICE, "The Icicle Plate was used up." (Q11:
#                    his Design 1, the plate used up)
#   the altar        a Pokémon that knows Hidden Power already: "Change
#                    Pikachu's Hidden Power?", free; the basket empty: a
#                    notice
#
# Each on its own layer over whatever is on screen (the map, the Party
# Screen), in the Theme Mode's colours. Controller first: Left/Right choose,
# A picks, B backs out; the mouse too.
#==============================================================================

return unless defined?(Reloaded::Pixel) && defined?(::KIF::PixelFont)

module Reloaded
  module HiddenPowerScreen
    PF = ::KIF::PixelFont
    P = Reloaded::Pixel
    PP = Reloaded::PartyPaint
    DG = Reloaded::Dialogs
    W = 512
    H = 384
    TYPES_SMALL = "Graphics/OverworldMenu/typesSmall16"    # KIF's 16 x 16 icons
    SPIN_FRAMES = 122             # about 2 seconds at the game's 60
    TURNS = 2                     # whole turns of the reel before it slows
    ROW_H = 22                    # a reel row

    # Dialogs' popups need a scene: this layer's bitmap and colours
    Layer = Struct.new(:overlay, :palette)

    class << self
      # For tests: what's drawn, and what's on show
      attr_reader :sprite, :state

      def price
        return Reloaded::HiddenPower::Researcher::PRICE
      end

      def money
        return $Trainer ? $Trainer.money.to_i : 0
      end

      def afford?
        return money >= price
      end

      #------------------------------------------------------------------------
      # The researcher's Type Reel: the number of spins
      #------------------------------------------------------------------------
      def reel(pkmn)
        open_layer
        @pkmn = pkmn
        make_icon(pkmn)
        @list = Reloaded::HiddenPower.pool
        @from = Reloaded::HiddenPower.type_of(pkmn)
        @pos = (@list.index(@from) || 0).to_f
        @state = :offer
        spins = 0
        choice = afford? ? 0 : 1
        redraw = true
        loop do
          if @state == :spin
            # input read after this frame's update: the press that started
            # the spin isn't a skip
            Graphics.update
            Input.update
            update_icon
            @frame += 1
            if Input.trigger?(Input::USE) || Reloaded::Pointer.left? || @frame >= SPIN_FRAMES
              @pos = @end.to_f
              @state = :done
              choice = 1
              redraw = true
            else
              @pos = @start + spin_rows(@frame)
              draw_reel(choice)
            end
            next
          end
          if redraw
            draw_reel(choice)
            redraw = false
          end
          Graphics.update
          Input.update
          update_icon
          pt = Reloaded::Pointer
          hit = pt.hit(@hits)
          if pt.moved? && hit && hit != choice && (hit == 1 || afford?)
            choice = hit
            pbPlayCursorSE
            redraw = true
          end
          picked = nil
          if pt.left? && hit
            picked = hit
          elsif pt.right? || Input.trigger?(Input::BACK)
            picked = 1
          elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
            target = Input.trigger?(Input::LEFT) ? 0 : 1
            if target == 0 && !afford?
              pbPlayBuzzerSE
            elsif target != choice
              choice = target
              pbPlayCursorSE
              redraw = true
            end
          elsif Input.trigger?(Input::USE)
            picked = choice
          end
          next unless picked
          if picked == 1
            pbPlayCancelSE
            break
          end
          unless afford?
            pbPlayBuzzerSE
            next
          end
          pbPlayDecisionSE
          spin!
          spins += 1
          choice = 1
          draw_reel(choice)
        end
        return spins
      ensure
        close_layer
      end

      # Paid and decided at the press: then the reel only shows it
      def spin!
        @from = Reloaded::HiddenPower.type_of(@pkmn)
        to = Reloaded::HiddenPower.roll(@from)
        $Trainer.money = money - price
        Reloaded::HiddenPower.set(@pkmn, to, :researcher)
        @to = to
        n = @list.length
        @start = (@list.index(@from) || 0).to_f
        @end = @start + TURNS * n + ((@list.index(to) || 0) - @start.to_i) % n
        @rows = @end - @start
        @frame = 0
        @state = :spin
      end

      # Rows turned by frame k: a short pick-up, then slowing to a stop
      def spin_rows(k)
        @speeds ||= begin
          list = (1..SPIN_FRAMES).map do |i|
            t = i.to_f / SPIN_FRAMES
            t < 0.1 ? t / 0.1 : ((1 - t) / 0.9)**1.6
          end
          total = list.sum
          run = 0.0
          list.map { |v| run += v / total }
        end
        return @rows * @speeds[[k, SPIN_FRAMES].min - 1]
      end

      #------------------------------------------------------------------------
      # Notices
      #------------------------------------------------------------------------
      # Unown: nothing changes its neutral Hidden Power
      def unown(pkmn, with_money = false)
        open_layer
        make_icon(pkmn)
        ok_loop { draw_unown(pkmn, with_money) }
      ensure
        close_layer
      end

      # After a plate (Use Several's notice): its new type, the plate used up
      def plate_notice(pkmn, from, to, item)
        open_layer
        ok_loop { draw_plate(pkmn, from, to, item) }
      ensure
        close_layer
      end

      # The altar, for a Pokémon that knows Hidden Power already: true to
      # change it (free)
      def altar_ask(pkmn, from, to)
        open_layer
        make_icon(pkmn)
        return two_loop { |choice| draw_altar(pkmn, from, to, choice) } == 0
      ensure
        close_layer
      end

      # The altar with nothing in the basket
      def basket_empty
        open_layer
        DG.notice(Layer.new(@sprite.bitmap, palette), _INTL("The Basket Is Empty"),
                  _INTL("Place a plate in the basket first. The room takes on its type, and the altar teaches that type of Hidden Power."))
      ensure
        close_layer
      end

      #------------------------------------------------------------------------
      # Loops
      #------------------------------------------------------------------------
      def ok_loop
        yield
        loop do
          Graphics.update
          Input.update
          update_icon
          pt = Reloaded::Pointer
          break if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK) || pt.right? || (pt.left? && pt.hit(@hits))
        end
        pbPlayDecisionSE
      end

      # Two buttons: 0 or 1 (B picks 1)
      def two_loop
        choice = 0
        yield choice
        loop do
          Graphics.update
          Input.update
          update_icon
          pt = Reloaded::Pointer
          hit = pt.hit(@hits)
          if pt.moved? && hit && hit != choice
            choice = hit
            pbPlayCursorSE
            yield choice
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
            yield choice
          elsif Input.trigger?(Input::USE)
            break
          end
        end
        choice == 1 ? pbPlayCancelSE : pbPlayDecisionSE
        return choice
      end

      #------------------------------------------------------------------------
      # The layer
      #------------------------------------------------------------------------
      def palette
        return Reloaded::Palette.map_menu
      end

      def open_layer
        close_layer
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 100_400
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = Bitmap.new(W, H)
        @hits = []
        @frame = 0
        @pictures = {}
      end

      def close_layer
        @icon.dispose if @icon && !@icon.disposed?
        @icon = nil
        @win.dispose if @win && !@win.disposed?
        @win = nil
        (@pictures || {}).each_value { |bm| bm.dispose if bm && !bm.disposed? }
        @pictures = {}
        @sprite.bitmap.dispose if @sprite && !@sprite.disposed? && @sprite.bitmap
        @sprite.dispose if @sprite && !@sprite.disposed?
        @viewport.dispose if @viewport && !@viewport.disposed?
        @sprite = @viewport = nil
      end

      def make_icon(pkmn)
        @icon = Reloaded::PartyIcons.icon(pkmn, @viewport, 1)
      end

      def update_icon
        @icon.update if @icon && !@icon.disposed?
      end

      def place_icon(cx, cy, size)
        return unless @icon
        Reloaded::PartyIcons.place(@icon, cx, cy)
        @icon.zoom_x = @icon.zoom_y = size / 64.0
      end

      def picture(path)
        return @pictures[path] if @pictures.key?(path)
        resolved = (pbResolveBitmap(path) rescue nil) || path
        @pictures[path] = (Bitmap.new(resolved) rescue nil)
      end

      #------------------------------------------------------------------------
      # Pieces
      #------------------------------------------------------------------------
      def mix(a, b, t)
        return Reloaded::Palette.mix(a, b, t)
      end

      def ink(c, type)
        return PP.ink(c, Reloaded::PartyScreen.type_rgb(type))
      end

      def type_name(type)
        return GameData::Type.get(type).name
      end

      def cash(n)
        return "$" + n.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
      end

      # The game's big type label (64 x 28, rounded: PartyPaint.type_sheet), or scaled
      def type_badge(b, type, x, y, w = 64, h = 28)
        bm = PP.type_sheet
        b.stretch_blt(Rect.new(x, y, w, h), bm, Rect.new(0, PP.type_row(type) * 28, 64, 28)) if bm
      end

      def small_type(b, type, x, y)
        bm = picture(TYPES_SMALL)
        b.blt(x, y, bm, Rect.new(0, PP.type_row(type) * 16, 16, 16)) if bm
      end

      # "ROCK > ICE": the two labels and a small arrow, centred on cx
      def change(b, c, cx, y, from, to, w = 64, h = 28)
        x = cx - (w + 18 + w) / 2
        type_badge(b, from, x, y, w, h)
        P.ui.tri(b, x + w + 6, y + h / 2 - 4, :r, c[:txt], 5)
        type_badge(b, to, x + w + 18, y, w, h)
      end

      # Your money, top right, always green (his rule: money is green, a
      # price green or red)
      def money_plate(b, c)
        w = 150
        x = W - w - 6
        DG.send(:panel, b, c, x, 6, w, 28)
        P.small(b, x + 12, 12, 60, 16, _INTL("Money"), c[:dim])
        P.text(b, x, 9, w - 12, 20, cash(money), c[:green], PF::TEXT, 1)
      end

      # Who: the icon, the name and the level
      def who(b, c, x, y, pkmn)
        place_icon(x + 22, y + 22, 44)
        P.text(b, x + 48, y + 2, 170, 24, PF.fit(PF::ROW, pkmn.name.to_s, 168), c[:strong], PF::ROW)
        P.small(b, x + 48, y + 24, 100, 16, _INTL("Lv. {1}", pkmn.level), c[:dim])
      end

      # Centred lines, wrapped to w (small: the small font); the y under them
      def lines_at(b, c, x, y, w, text, col, small = false)
        rows = small ? P.small_wrap(b, text, w - 28) : P.wrap(text, w - 28)
        rows.each do |ln|
          small ? P.small(b, x, y, w, 16, ln, col, 2) : P.text(b, x, y, w, 18, ln, col, PF::TEXT, 2)
          y += small ? 16 : 18
        end
        return y
      end

      # A button with a price after its word: the price green when you have
      # the money, red when you don't (his rule, 2026-10-24)
      def price_button(b, c, x0, y, x1, label, cost, on, off = false)
        DG.send(:button, b, c, x0, y, x1, y + 28, on && !off)
        words = off ? c[:dim] : (on ? c[:strong] : c[:txt])
        if cost
          pt = cash(cost)
          lw = P.width(PF::TEXT, label)
          pw = P.width(PF::TEXT, pt)
          tx = (x0 + x1) / 2 - (lw + 8 + pw) / 2
          P.text(b, tx, y + 2, lw + 2, 24, label, words, PF::TEXT)
          P.text(b, tx + lw + 8, y + 2, pw + 2, 24, pt, money >= cost ? c[:green] : c[:red], PF::TEXT)
        else
          P.text(b, x0, y + 2, x1 - x0, 24, label, words, PF::TEXT, 2)
        end
        @hits << [@hits.length, x0, y, x1, y + 28]
      end

      # Two buttons sharing a row, as wide as the popup allows
      def two_buttons(b, c, x, w, y, left, right, choice, left_off = false, right_off = false)
        gap = 8
        bw = (w - 28 - gap) / 2
        price_button(b, c, x + 14, y, x + 14 + bw, left[0], left[1], choice == 0, left_off)
        price_button(b, c, x + 14 + bw + gap, y, x + w - 14, right[0], right[1], choice == 1, right_off)
      end

      def ok_button(b, c, x, w, y)
        bw = 90
        DG.send(:button, b, c, x + (w - bw) / 2, y, x + (w + bw) / 2, y + 28, true)
        P.text(b, x + (w - bw) / 2, y + 2, bw, 24, _INTL("OK"), c[:strong], PF::TEXT, 2)
        @hits << [0, x + (w - bw) / 2, y, x + (w + bw) / 2, y + 28]
      end

      def hint_button(sym)
        return Reloaded::Prompts.input(sym) || Reloaded::Prompts.name(sym)
      end

      def hints(b, c, pairs)
        P.hints(b, b, c, pairs, Reloaded::Prompts.style)
      end

      #------------------------------------------------------------------------
      # Drawing
      #------------------------------------------------------------------------
      def draw_reel(choice)
        c = palette
        o = @sprite.bitmap
        o.clear
        @hits = []
        w = 360
        h = 232
        x = (W - w) / 2
        y = H - P::HINT_H - h - 8
        DG.frame(o, c, x, y, w, h, _INTL("Hidden Power"))
        money_plate(o, c)
        place_icon(x + 56, y + 78, 56)
        P.text(o, x + 6, y + 108, 100, 22, PF.fit(PF::ROW, @pkmn.name.to_s, 100), c[:strong], PF::ROW, 2)
        P.small(o, x + 6, y + 130, 100, 16, _INTL("Lv. {1}", @pkmn.level), c[:dim], 2)
        rx0 = x + 116
        rx1 = x + w - 16
        ry0 = y + 44
        fill = c[:light] ? mix(c[:panel2], PP::WHITE, 0.4) : mix(c[:dark], c[:panel2], 0.4)
        P.ui.rbox(o, rx0, ry0, rx1, ry0 + 5 * ROW_H + 6, 6, fill, c[:line])
        DG.send(:cursor_row, o, c, rx0 + 4, ry0 + 3 + 2 * ROW_H, rx1 - 4, ry0 + 3 + 3 * ROW_H - 1)
        draw_rows(o, c, rx0 + 4, ry0 + 3, rx1 - rx0 - 8)
        P.ui.tri(o, rx0 - 9, ry0 + 3 + 2 * ROW_H + 7, :r, c[:selb], 5)
        P.ui.tri(o, rx1 + 3, ry0 + 3 + 2 * ROW_H + 7, :l, c[:selb], 5)
        # the line halfway between the reel and the buttons (his ask)
        msg = if @state == :done
                [_INTL("It landed on {1}, never {2}.", type_name(@to), type_name(@from)), c[:txt]]
              elsif @state == :offer && !afford?
                [_INTL("Not Enough Money: A spin costs {1}.", cash(price)), c[:red]]
              else
                [_INTL("A spin lands on a new type, never {1}.", type_name(@state == :spin ? @from : Reloaded::HiddenPower.type_of(@pkmn))), c[:dim]]
              end
        lines_at(o, c, x, y + 170, w, msg[0], msg[1], true)
        by = y + h - 38
        case @state
        when :spin
          two_buttons(o, c, x, w, by, [_INTL("Spin"), price], [_INTL("Keep"), nil], -1, true, true)
          hints(o, c, [[hint_button(:C), _INTL("Skip")]])
        when :done
          two_buttons(o, c, x, w, by, [_INTL("Again"), price], [_INTL("Done"), nil], choice, !afford?)
          hints(o, c, [[:lr, _INTL("Choose")], [hint_button(:C), _INTL("OK")], [hint_button(:B), _INTL("Back")]])
        else
          two_buttons(o, c, x, w, by, [_INTL("Spin"), price], [_INTL("Keep"), nil], choice, !afford?)
          hints(o, c, [[:lr, _INTL("Choose")], [hint_button(:C), _INTL("OK")], [hint_button(:B), _INTL("Back")]])
        end
      end

      # The reel's rows on a window of their own, so the ones half out are
      # cut off; each type lit as it passes through the band
      def draw_rows(o, c, wx, wy, ww)
        wh = 5 * ROW_H
        @win = Bitmap.new(ww, wh) unless @win && !@win.disposed? && @win.width == ww
        @win.clear
        n = @list.length
        return if n == 0
        base = @pos.floor
        frac = @pos - base
        (-3..3).each do |d|
          t = @list[(base + d) % n]
          ry = ((2 + d - frac) * ROW_H).round
          lit = (d - frac).abs < 0.5
          small_type(@win, t, 10, ry + 3)
          P.text(@win, 34, ry, 140, ROW_H, type_name(t), lit ? ink(c, t) : mix(c[:dim], c[:panel2], 0.35), PF::TEXT)
        end
        o.blt(wx, wy, @win, Rect.new(0, 0, ww, wh))
      end

      def draw_unown(pkmn, with_money)
        c = palette
        o = @sprite.bitmap
        o.clear
        @hits = []
        w = 380
        h = 194
        x = (W - w) / 2
        y = H - P::HINT_H - h - 10
        DG.frame(o, c, x, y, w, h, _INTL("Hidden Power"))
        money_plate(o, c) if with_money
        who(o, c, x + 16, y + 42, pkmn)
        type_badge(o, Reloaded::HiddenPower::NEUTRAL, x + w - 82, y + 50)
        ly = lines_at(o, c, x, y + 90, w, _INTL("Unown's Hidden Power hits every type the same."), c[:txt])
        lines_at(o, c, x, ly + 2, w, _INTL("A spin can't change it, and neither can a plate."), c[:dim], true)
        ok_button(o, c, x, w, y + h - 36)
        hints(o, c, [[hint_button(:C), _INTL("OK")]])
      end

      def draw_plate(pkmn, from, to, item)
        c = palette
        o = @sprite.bitmap
        o.clear
        @hits = []
        w = 360
        h = 150
        x = (W - w) / 2
        y = (H - P::HINT_H - h) / 2
        DG.frame(o, c, x, y, w, h, _INTL("{1}'s Hidden Power Is Now {2}", pkmn.name, type_name(to)))
        change(o, c, x + w / 2, y + 46, from, to)
        name = (GameData::Item.get(item).name rescue item.to_s)
        P.text(o, x, y + 80, w, 18, _INTL("The {1} was used up.", name), c[:txt], PF::TEXT, 2)
        ok_button(o, c, x, w, y + h - 36)
        hints(o, c, [[hint_button(:C), _INTL("OK")]])
      end

      def draw_altar(pkmn, from, to, choice)
        c = palette
        o = @sprite.bitmap
        o.clear
        @hits = []
        w = 380
        h = 172
        x = (W - w) / 2
        y = H - P::HINT_H - h - 10
        DG.frame(o, c, x, y, w, h, _INTL("Change {1}'s Hidden Power?", pkmn.name))
        who(o, c, x + 16, y + 42, pkmn)
        change(o, c, x + w - 92, y + 50, from, to)
        ly = lines_at(o, c, x, y + 90, w, _INTL("{1} already knows Hidden Power.", pkmn.name), c[:txt])
        lines_at(o, c, x, ly + 2, w, _INTL("The room's {1} can make it {1}-type, for free.", type_name(to)), c[:dim], true)
        two_buttons(o, c, x, w, y + h - 38, [_INTL("Change"), nil], [_INTL("Keep"), nil], choice)
        hints(o, c, [[:lr, _INTL("Choose")], [hint_button(:C), _INTL("OK")], [hint_button(:B), _INTL("Back")]])
      end
    end
  end
end
