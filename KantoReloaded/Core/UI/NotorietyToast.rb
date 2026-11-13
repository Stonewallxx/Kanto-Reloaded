# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Notoriety's tier toast and symbols (Trainer Control)
#==============================================================================
# His pick (2026-11-01): Design 2's Notoriety Card with Design 3's details,
# a size up (70 px tall), on the toast's timing (3 seconds of real time):
#
#   the plate  60 x 58 in the tier's colour: the tier's diamonds, its name
#              under it
#   the words  NOTORIETY (on a drop: DOWN FROM and the tier left, in its
#              colour), the line large, what changes in the tier's colour
#   the tiers  Known, Feared, Infamous as pills: reached ones in their
#              colours, the rest grey with where they start (FEARED AT 10);
#              the new tier lights up a moment in (a drop's goes grey)
#   its sound  reaching a tier: Exclaim; a drop: Voltorb Flip's level drop
#              (his picks)
#
# The diamonds (his pick 2026-11-01, Diamond Count, in place of the Roman
# numerals): one for Known, two side by side for Feared, three in a triangle
# for Infamous, white on Dark and the tier's colour on Light; none under
# Known. His art in Graphics/Notoriety (known.png, feared.png, infamous.png,
# 32 x 32) takes their place when it's there. (The Trainer Card's row shows
# all three small, the tiers reached lit.)
#==============================================================================

module Reloaded
  module NotorietyToast
    H = 70
    TX = 76
    LIGHT_UP = 0.4                         # seconds before the new tier lights up
    SE_UP = "Exclaim"
    SE_DROP = "Voltorb Flip Level Dropped"
    # [x, y, radius] of each diamond from the plate's middle, by tier
    DIAMONDS = [[[0, -2, 10]], [[-9, -2, 8], [9, -2, 8]], [[0, -9, 7], [-9, 6, 7], [9, 6, 7]]].freeze
    # the line and what changes: reaching a tier, dropping from one
    UP = { :known => ["Word of your wins spreads...", "Every trainer adapts one more way."],
           :feared => ["Trainers start to fear you...", "Leaders field counters. Aces come fully built."],
           :infamous => ["Your name is infamous...", "Every trainer is 2 levels higher."] }.freeze
    DROP = { :known => ["Word of your loss spreads...", "Trainers adapt as they did before."],
             :feared => ["Word of your loss spreads...", "Leaders drop their counters. Aces lose their full builds."],
             :infamous => ["Word of your loss spreads...", "Trainers are back to their own levels."] }.freeze
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint

    class << self
      def tiers
        return Reloaded::TrainerControl::Notoriety::TIERS
      end

      def up(tier)
        return false unless tier
        c = Reloaded::Palette.map_menu
        return Reloaded::Toast.card(card(c, tier, nil, false), :later => [LIGHT_UP, card(c, tier, nil, true)], :se => SE_UP)
      end

      # from: the tier left; to: the one now (nil under Known)
      def drop(from, to)
        return false unless from
        c = Reloaded::Palette.map_menu
        return Reloaded::Toast.card(card(c, to, from, false), :later => [LIGHT_UP, card(c, to, from, true)], :se => SE_DROP)
      end

      def mix(a, b, t)
        return Reloaded::Palette.mix(a, b, t)
      end

      def small_w(str)
        @probe ||= Bitmap.new(8, 8)
        P.small_font(@probe)
        return @probe.text_size(str.to_s).width
      end

      def pill_w(label)
        return P.width(PF::TINY, label) + 12
      end

      # A pill in a tier's colour, or grey
      def pill(b, c, x, y, label, rgb)
        fill, ink = rgb ? PP.badge(c, rgb) : [c[:light] ? mix(c[:panel2], c[:dim], 0.22) : Color.new(36, 40, 48), c[:dim]]
        return P.pill(b, x, y, label, fill, ink, false)
      end

      #------------------------------------------------------------------------
      # A tier's symbol centred on cx, cy: his art, or its diamonds in col
      #------------------------------------------------------------------------
      def symbol(b, tier, cx, cy, col)
        return unless tier
        path = defined?(pbResolveBitmap) ? pbResolveBitmap("Graphics/Notoriety/#{tier.key}") : nil
        if path
          bm = Bitmap.new(path)
          b.blt(cx - bm.width / 2, cy - bm.height / 2, bm, Rect.new(0, 0, bm.width, bm.height))
          bm.dispose
          return
        end
        DIAMONDS[tier.index].each { |dx, dy, r| PP.diamond(b, cx + dx, cy + dy, r, col) }
      rescue StandardError
        nil
      end

      #------------------------------------------------------------------------
      # The card: now the tier you're at (nil: under Known), from the one a
      # loss left (nil when reaching a tier); lit: the change shown
      #------------------------------------------------------------------------
      def card(c, now, from, lit)
        drop = !from.nil?
        key = drop ? from.key : now.key
        line, what = (drop ? DROP : UP)[key]
        col = now ? PP.ink(c, now.rgb) : c[:dim]
        ladder = tiers.map do |t|
          on = now && t.index <= now.index
          on = false if !drop && !lit && t.key == now.key
          on = true if drop && !lit && t.key == from.key
          [on ? t.name.upcase : "#{t.name.upcase} AT #{t.wins}", on ? t.rgb : nil]
        end
        lw = ladder.sum { |l, _| pill_w(l) } + 4 * (ladder.length - 1)
        w = TX + [P.width(PF::TEXT, _INTL(line)), small_w(_INTL(what)), lw].max + 16
        o = Bitmap.new(w, H)
        PP.chamfer_grad(o, 0, 0, w, H, 11, mix(c[:panel], col, 0.16), c[:panel], mix(c[:line], col, 0.45))
        PP.chamfer_grad(o, 6, 6, 66, H - 6, 8, mix(c[:panel2], col, 0.6), mix(c[:panel2], c[:dark], 0.3), mix(c[:line], col, 0.6))
        symbol(o, now, 36, 30, c[:light] ? col : c[:strong])
        P.text(o, 6, 48, 60, 12, now ? now.name.upcase : _INTL("UNKNOWN"), c[:light] ? c[:txt] : col, PF::TINY, 2)
        if drop
          fw = P.text(o, TX, 5, 120, 12, _INTL("DOWN FROM"), c[:red], PF::TINY)
          P.text(o, TX + fw + 4, 5, 120, 12, from.name.upcase, PP.ink(c, from.rgb), PF::TINY)
        else
          P.text(o, TX, 5, 120, 12, _INTL("NOTORIETY"), c[:head], PF::TINY)
        end
        P.text(o, TX, 15, w - TX - 8, 18, _INTL(line), c[:strong], PF::TEXT)
        P.small(o, TX, 33, w - TX - 8, 14, _INTL(what), col)
        x = TX
        ladder.each { |l, rgb| x += pill(o, c, x, 50, l, rgb) + 4 }
        return o
      end
    end
  end
end
