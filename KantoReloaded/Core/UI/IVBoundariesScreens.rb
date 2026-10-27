# encoding: utf-8
#==============================================================================
# Kanto Reloaded: IV Boundaries' popups
#==============================================================================
# The looks he picked (2026-10-25; the sheet ivb-round2-popups):
#
#   Two Spinners   A on Wild, Eggs or Gifts (Q20 Design 2): Floor and
#                  Ceiling side by side, Up/Down change the lit number,
#                  Left/Right switch, a band under them and what the range
#                  means; on Hard the floor is dim with a padlock and the
#                  line says Hard keeps it at 0. A Done, B Cancel
#   Use Preset?    a preset chosen over your own ranges (Q10): "Use Strong
#                  for All Three?", yours under it, Use Strong / Keep Mine
#
# Hard's notice ("Hard Keeps Floors at 0") is the chip pick's own, with
# the preset's :locked_text. Each on the settings screen's overlay.
#==============================================================================

return unless defined?(Reloaded::Pixel) && defined?(::KIF::PixelFont)

module Reloaded
  module IVBoundariesScreen
    PF = ::KIF::PixelFont
    P = Reloaded::Pixel
    PP = Reloaded::PartyPaint
    DG = Reloaded::Dialogs
    IVB = Reloaded::IVBoundaries
    W = 512
    H = 384

    class << self
      #------------------------------------------------------------------------
      # Two Spinners: [floor, ceiling], or nil on Cancel
      #------------------------------------------------------------------------
      def spinners(scene, src)
        lo, hi = IVB.shown(src)
        hard = IVB.hard?
        lit = hard ? 1 : 0
        redraw = true
        loop do
          if redraw
            draw_spinners(scene.overlay, scene.palette, src, lo, hi, lit, hard)
            redraw = false
          end
          Graphics.update
          Input.update
          if Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
            d = Input.repeat?(Input::UP) ? 1 : -1
            if lit == 0
              to = (lo + d).clamp(0, IVB::IV_MAX)
              hi = to if to > hi
              moved = to != lo
              lo = to
            else
              to = (hi + d).clamp(0, IVB::IV_MAX)
              lo = to if to < lo && !hard
              to = [to, lo].max
              moved = to != hi
              hi = to
            end
            if moved
              pbPlayCursorSE
              redraw = true
            end
          elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
            to = Input.trigger?(Input::LEFT) ? 0 : 1
            if to == lit
              next
            elsif to == 0 && hard
              pbPlayBuzzerSE
            else
              lit = to
              pbPlayCursorSE
              redraw = true
            end
          elsif Input.trigger?(Input::USE) || Reloaded::Pointer.left?
            pbPlayDecisionSE
            return [lo, hi]
          elsif Input.trigger?(Input::BACK) || Reloaded::Pointer.right?
            pbPlayCancelSE
            return nil
          end
        end
      ensure
        b = scene.overlay
        b.clear if b && !b.disposed?
      end

      def draw_spinners(b, c, src, lo, hi, lit, hard)
        w = 320
        h = 176
        x = (W - w) / 2
        y = (H - P::HINT_H - h) / 2
        DG.frame(b, c, x, y, w, h, _INTL("{1} IVs", _INTL(IVB::SOURCE_NAMES[src])))
        [[_INTL("Floor"), lo], [_INTL("Ceiling"), hi]].each_with_index do |(label, v), i|
          cx = x + w / 4 + i * w / 2
          on = i == lit
          locked = i == 0 && hard
          P.text(b, cx - 60, y + 42, 120, 16, label, locked ? c[:dim] : c[:head], PF::TEXT, 2)
          PP.chamfer(b, cx - 34, y + 68, cx + 34, y + 104, 7, on ? c[:sel] : Reloaded::Palette.mix(c[:panel2], c[:bg], 0.45),
                     on ? c[:selb] : c[:line])
          P.text(b, cx - 34, y + 70, 68, 32, v.to_s, locked ? c[:dim] : (on ? c[:strong] : c[:txt]), PF::ROW, 2)
          if on
            P.ui.tri(b, cx - 5, y + 60, :u, c[:selb], 5)
            P.ui.tri(b, cx - 5, y + 108, :d, c[:selb], 5)
          end
          padlock(b, cx + 40, y + 82, c[:dim]) if locked
        end
        P.text(b, x + w / 2 - 10, y + 70, 20, 32, _INTL("to"), c[:dim], PF::TEXT, 2)
        tx0 = x + 30
        tx1 = x + w - 30
        ty = y + 128
        kx = ->(v) { tx0 + (v * (tx1 - tx0) / IVB::IV_MAX.to_f).round }
        P.ui.rbox(b, tx0, ty, tx1, ty + 4, 2, c[:dark])
        P.ui.rbox(b, kx[lo], ty, kx[hi], ty + 4, 2, c[:selb])
        line = hard ? [_INTL("Hard Keeps the Floor at 0."), c[:red]] : [_INTL("Each IV rolls from {1} to {2}.", lo, hi), c[:dim]]
        P.small(b, x, y + h - 30, w, 16, line[0], line[1], 2)
        hints(b, c, [[:ud, _INTL("Change")], [:lr, _INTL("Floor / Ceiling")], [button(:C), _INTL("Done")], [button(:B), _INTL("Cancel")]])
      end

      #------------------------------------------------------------------------
      # A preset over your own ranges: true to use it
      #------------------------------------------------------------------------
      def replace_ask(index)
        p = IVB::PRESETS[index.to_i]
        return true unless p
        name = _INTL(p[0])
        scene = defined?(Reloaded::SettingsScreen) ? Reloaded::SettingsScreen.showing : nil
        return true unless scene && scene.respond_to?(:overlay)
        c = scene.palette
        yours = IVB::SOURCES.map { |src| lo, hi = IVB.shown(src); "#{_INTL(IVB::SOURCE_NAMES[src])} #{lo}-#{hi}" }.join(", ")
        segments = [[_INTL("Yours: "), c[:dim]], [yours, c[:txt], true]]
        choice = DG.ask(scene, _INTL("Use {1} for All Three?", name),
                        _INTL("Every range becomes {1}-{2}. Your own ranges are kept under Custom.", p[1], p[2]),
                        segments, [_INTL("Use {1}", name), _INTL("Keep Mine")], 0)
        return choice == 0
      end

      #------------------------------------------------------------------------
      # Pieces
      #------------------------------------------------------------------------
      def button(sym)
        return Reloaded::Prompts.input(sym) || Reloaded::Prompts.name(sym)
      end

      # The popup's own hint line, over the dimmed screen's
      def hints(b, c, pairs)
        style = Reloaded::Prompts.style
        b.fill_rect(0, H - P::HINT_H, W, P::HINT_H, c[:panel2])
        b.fill_rect(0, H - P::HINT_H, W, 1, c[:line])
        P.draw_hints(b, (W - P.hints_width(b, pairs, style)) / 2, H - P::HINT_H, c, pairs, style)
      end

      def padlock(b, x, y, col)
        b.fill_rect(x + 1, y, 5, 1, col)
        b.fill_rect(x, y + 1, 1, 3, col)
        b.fill_rect(x + 6, y + 1, 1, 3, col)
        b.fill_rect(x - 1, y + 4, 9, 6, col)
      end
    end
  end
end
