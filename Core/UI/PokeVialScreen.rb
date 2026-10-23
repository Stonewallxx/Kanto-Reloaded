# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the PokeVial's dialog, refill dialog and toasts
#==============================================================================
# The looks he picked (2026-10-17 and 2026-10-22; mockups in
# Tools/Designs/pokevial):
#
#   the dialog       Confirm Dialog: a Header Plate popup, the vial at the
#                    plate's left and the charges at its right, the Heal
#                    Preview (each Pokémon, its HP and what a charge does
#                    for it), Use PokeVial and Back. Used, it shows the
#                    party healed and a charge fewer.
#   can't use        the Use button dimmed with why: No Charges Left, All
#                    Healthy, or the cooldown counting down (Ready in 4:32,
#                    a line filling under it). Cooldown Wait Toast: a toast
#                    instead of the dialog.
#   refill           Ask: "Refill PokeVial?" with the missing charges, the
#                    cost and your Money, Refill and Not Now
#   charges          little Poké Balls, the empty ones muted
#   toasts           more capacity (+1, green), an item used from the Bag
#                    (the charges), already full (FULL, gold)
#
# Its own layer over whatever is on screen (the Pause Menu, the Overworld
# Menu, the nurse's message), in the Theme Mode's colours.
#==============================================================================

return unless defined?(Reloaded::Pixel) && defined?(::KIF::PixelFont)

module Reloaded
  module PokeVialScreen
    PF = ::KIF::PixelFont
    P = Reloaded::Pixel
    PP = Reloaded::PartyPaint
    DG = Reloaded::Dialogs
    PV = Reloaded::PokeVial
    W = 512
    H = 384
    DIALOG_W = 380
    ROW_H = 34
    REFILL_W = 320
    TONES = { :green => :green, :pink => :pink, :blue => :blue, :healthy => :green, :dim => :dim }.freeze

    @balls = {}

    class << self
      # For tests: what's drawn, and the icon sprites.
      attr_reader :sprite, :icons

      #------------------------------------------------------------------------
      # Choosing the PokeVial (the Pause Menu's tile, the Overworld Menu's row)
      #------------------------------------------------------------------------
      def choose
        PV.sync_capacity
        if PV.cooldown_left > 0 && PV.uses > 0 && PV.setting(:cooldown_wait).to_i == 1
          cooldown_toast
          pbPlayBuzzerSE if defined?(pbPlayBuzzerSE)
          return false
        end
        return dialog
      end

      # The dialog: true when a charge was used
      def dialog
        open_layer
        @mons = PV.party.reject(&:egg?).first(6)
        make_icons
        used = false
        choice = PV.use_state == true ? 0 : 1
        redraw = true
        loop do
          if redraw
            draw_dialog(choice, used)
            redraw = false
          end
          Graphics.update
          Input.update
          @frame += 1
          @icons.each { |s| s.update if s && !s.disposed? }
          state = PV.use_state
          if state.is_a?(Array) && state[1] == :cooldown && @frame % 20 == 0
            redraw = true                             # the countdown
          elsif state == true && @was_waiting
            redraw = true                             # ready now
          end
          @was_waiting = state.is_a?(Array) && state[1] == :cooldown
          pt = Reloaded::Pointer
          hit = pt.hit(@hits)
          if pt.moved? && hit && hit != choice && (hit == 1 || state == true)
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
            if target == 0 && state != true
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
          before = @mons.map { |p| PV.gains?(p) }
          if state != true || !PV.use!(:menu)
            pbPlayBuzzerSE
            next
          end
          @healed = before
          used = true
          play_heal
          choice = 1
          redraw = true
        end
        return used
      ensure
        close_layer
      end

      # Ask (Pokémon Center Refill): true to refill
      def ask_refill
        open_layer
        choice = 0
        redraw = true
        picked = nil
        loop do
          afford = PV.refill_cost <= PV.money
          choice = 1 unless afford
          if redraw
            draw_refill(choice, afford)
            redraw = false
          end
          Graphics.update
          Input.update
          pt = Reloaded::Pointer
          hit = pt.hit(@hits)
          if pt.moved? && hit && hit != choice && (hit == 1 || afford)
            choice = hit
            pbPlayCursorSE
            redraw = true
          end
          if pt.left? && hit
            picked = hit
          elsif pt.right? || Input.trigger?(Input::BACK)
            picked = 1
          elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
            target = Input.trigger?(Input::LEFT) ? 0 : 1
            if target == 0 && !afford
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
          if picked == 0 && !afford
            pbPlayBuzzerSE
            picked = nil
            next
          end
          break
        end
        if picked == 0
          pbSEPlay("Mart buy item") rescue nil
          return true
        end
        pbPlayCancelSE
        return false
      ensure
        close_layer
      end

      #------------------------------------------------------------------------
      # Toasts
      #------------------------------------------------------------------------
      def toast(text, full: false, red_pill: nil)
        pill = full ? [_INTL("FULL"), :gold] : (red_pill ? [red_pill, :red] : nil)
        return Reloaded::Toast.show(text, :icon => PV::ICON, :pill => pill)
      end

      # What happened, and the charges now
      def charges_toast(text)
        full = PV.uses
        total = PV.configured_max_uses
        w = total * 9 + (total - 1) * 2 + 12
        paint = proc do |b, x0, y0, c|
          P.ui.rbox(b, x0, y0, x0 + w, y0 + 15, 7, c[:dark], c[:line])
          balls(b, c, x0 + w - 6, y0 + 8, full, total, 9, 2)
        end
        return Reloaded::Toast.show(text, :icon => PV::ICON, :paint => [w, paint])
      end

      # More capacity (his pick, Design 1): "+1" in green
      def capacity_toast(max, gained)
        return Reloaded::Toast.show(_INTL("PokeVial now holds {1} charges", max), :icon => PV::ICON,
                                    :pill => ["+#{gained}", :green])
      end

      # Cooldown Wait Toast (Design 3): when it'll be ready, and what's left
      def cooldown_toast
        return Reloaded::Toast.show(_INTL("PokeVial ready in {1}", PV.clock(PV.cooldown_left)), :icon => PV::ICON,
                                    :pill => [_INTL("{1} LEFT", PV.uses), :gold])
      end

      #------------------------------------------------------------------------
      # The charges: little Poké Balls, the last one ending at x1, middle on
      # cy; the empty ones muted. Returns the width.
      #------------------------------------------------------------------------
      def balls(b, c, x1, cy, full, total, size = 11, gap = 3)
        total = total.to_i
        w = total * size + [total - 1, 0].max * gap
        total.times do |i|
          bm = ball_bitmap(c, size, i < full)
          b.blt(x1 - w + i * (size + gap), cy - size / 2, bm, Rect.new(0, 0, size, size))
        end
        return w
      end

      private

      def ball_bitmap(c, size, lit)
        k = [size, lit, c[:light] ? 1 : 0]
        bm = @balls[k]
        return bm if bm && !bm.disposed?
        bm = Bitmap.new(size, size)
        if lit
          P.poke_ball(bm, 0, 0, size)
        else
          hollow = Reloaded::Palette.mix(c[:line], c[:dim], 0.55)
          muted = { :ink => hollow, :red => c[:dark], :white => Reloaded::Palette.mix(c[:dark], hollow, 0.35) }
          size.times do |r|
            size.times do |x|
              part = P.send(:ball_pixel, x, r, size)
              bm.fill_rect(x, r, 1, 1, muted[part]) if part
            end
          end
        end
        return @balls[k] = bm
      end

      def open_layer
        close_layer
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 100_400
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = Bitmap.new(W, H)
        @icons = []
        @hits = []
        @frame = 0
        @was_waiting = false
        @healed = nil
      end

      def close_layer
        (@icons || []).each { |s| s.dispose if s && !s.disposed? }
        @icons = []
        @sprite.bitmap.dispose if @sprite && !@sprite.disposed? && @sprite.bitmap
        @sprite.dispose if @sprite && !@sprite.disposed?
        @viewport.dispose if @viewport && !@viewport.disposed?
        @sprite = @viewport = nil
      end

      def make_icons
        @icons = @mons.map { |pkmn| Reloaded::PartyIcons.icon(pkmn, @viewport, 1) }
        @arts = @icons.map do |s|
          next nil unless s && s.bitmap
          Reloaded::PartyIcons.art_rect(s.bitmap, [s.src_rect.height, 1].max)
        end
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
      end

      # The game's healing sound, as the old Kanto Reloaded's and Hoenn
      # Reloaded's PokeVial played (his pick, 2026-10-23)
      def play_heal
        pbSEPlay("Recovery")
      rescue StandardError
        nil
      end

      def vial(o, x, y, w = 20, h = 24)
        bm = Bitmap.new(PV::ICON)
        o.stretch_blt(Rect.new(x, y, w, h), bm, Rect.new(0, 0, bm.width, bm.height))
        bm.dispose
      rescue StandardError
        nil
      end

      def button(o, c, x0, y0, x1, y1, label, on, off = false, tint = nil)
        DG.send(:button, o, c, x0, y0, x1, y1, on)
        colour = tint || (off ? c[:dim] : (on ? (c[:strong] || c[:white]) : c[:txt]))
        P.text(o, x0, y0 + 2, x1 - x0, 24, PF.fit(PF::TEXT, label, x1 - x0 - 8), colour, PF::TEXT, 2)
        @hits << [@hits.length, x0, y0, x1, y1]
      end

      def hint_button(sym)
        return Reloaded::Prompts.input(sym) || Reloaded::Prompts.name(sym)
      end

      #------------------------------------------------------------------------
      # Drawing
      #------------------------------------------------------------------------
      def draw_dialog(choice, used)
        c = Reloaded::Palette.map_menu
        o = @sprite.bitmap
        o.clear
        @hits = []
        DG.send(:dim, o)
        w = DIALOG_W
        n = [@mons.length, 1].max
        h = 40 + 18 + n * ROW_H + 44
        x = (W - w) / 2
        y = [(H - P::HINT_H - h) / 2, 4].max
        DG.send(:panel, o, c, x, y, w, h)
        DG.send(:title_bar, o, c, x, y, w, _INTL("PokeVial"))
        vial(o, x + 12, y + 6)
        balls(o, c, x + w - 12, y + 17, PV.uses, PV.configured_max_uses)
        top = y + 40
        P.text(o, x + 18, top, 150, 14, _INTL("HEAL PREVIEW"), c[:head], PF::TINY)
        mode = [_INTL("FULL HEAL"), _INTL("HP ONLY"), _INTL("NO REVIVE")][PV::HEAL_MODES.index(PV.heal_mode).to_i]
        P.text(o, x + w - 168, top, 150, 14, mode, c[:dim], PF::TINY, 1)
        @mons.each_with_index do |pkmn, i|
          ry = top + 18 + i * ROW_H
          place_icon(i, x + 30, ry + ROW_H / 2, 28)
          P.text(o, x + 52, ry - 1, 120, 18, PF.fit(PF::TEXT, pkmn.name.to_s, 118), c[:txt], PF::TEXT)
          frac = pkmn.hp.to_f / [pkmn.totalhp, 1].max
          PP.bar(o, c, x + 54, ry + 20, 92, frac, PP.hp_colour(c, pkmn))
          P.small(o, x + 156, ry + 13, 70, 16, "#{pkmn.hp}/#{pkmn.totalhp}", c[:txt])
          words, tone = PV.preview(pkmn)
          words, tone = [_INTL("Healed"), :green] if used && @healed && @healed[i]
          P.small(o, x + 200, ry + 4, w - 218, 16, words, tone == :dim ? c[:dim] : (c[TONES[tone]] || c[:txt]), 1)
        end
        if @mons.empty?
          P.text(o, x, top + 20, w, 18, _INTL("No Pokémon to heal."), c[:dim], PF::TEXT, 2)
        end
        by = y + h - 38
        state = PV.use_state
        if state == true
          button(o, c, x + 40, by, x + 200, by + 28, _INTL("Use PokeVial"), choice == 0)
        else
          # No Charges Left in red (his ask); the rest dimmed
          tint = state[1] == :empty ? c[:red] : nil
          button(o, c, x + 40, by, x + 200, by + 28, state[0], false, true, tint)
          if state[1] == :cooldown
            o.fill_rect(x + 52, by + 23, ((200 - 40 - 24) * PV.cooldown_done).round, 2, c[:selb])
          end
        end
        button(o, c, x + 214, by, x + w - 40, by + 28, used ? _INTL("Done") : _INTL("Back"), choice == 1)
        pairs = [[:lr, _INTL("Choose")], [hint_button(:C), _INTL("Select")], [hint_button(:B), _INTL("Back")]]
        P.hints(o, o, c, pairs, Reloaded::Prompts.style)
      end

      def draw_refill(choice, afford)
        c = Reloaded::Palette.map_menu
        o = @sprite.bitmap
        o.clear
        @hits = []
        w = REFILL_W
        h = 172
        x = (W - w) / 2
        y = 36
        DG.send(:panel, o, c, x, y, w, h)
        DG.send(:title_bar, o, c, x, y, w, _INTL("Refill PokeVial?"))
        vial(o, x + 12, y + 6)
        total = PV.configured_max_uses
        size = 15
        gap = 7
        bw = total * size + (total - 1) * gap
        balls(o, c, x + (w + bw) / 2, y + 56, PV.uses, total, size, gap)
        miss = PV.missing
        words = miss == 1 ? _INTL("1 Charge Missing") : _INTL("{1} Charges Missing", miss)
        P.text(o, x, y + 72, w, 20, words, c[:txt], PF::TEXT, 2)
        cost = PV.refill_cost
        if cost <= 0
          P.small(o, x + 10, y + 94, w - 20, 16, _INTL("Free"), c[:green], 2)
        else
          # the costs in red, your Money in green (red when it's not enough)
          P.small_rich(o, x + 10, y + 94, w - 20, 16,
                       [["$#{money(PV.setting(:cost_per_charge))}", c[:red], true], [_INTL(" Each: "), c[:dim]],
                        ["$#{money(cost)}", c[:red], true], [_INTL(" (Money: "), c[:dim]],
                        ["$#{money(PV.money)}", afford ? c[:green] : c[:red], true], [")", c[:dim], true]])
        end
        by = y + h - 40
        button(o, c, x + 30, by, x + w / 2 - 4, by + 28, _INTL("Refill"), choice == 0 && afford, !afford)
        button(o, c, x + w / 2 + 4, by, x + w - 30, by + 28, _INTL("Not Now"), choice == 1)
      end

      def money(n)
        return n.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
      end
    end
  end
end
