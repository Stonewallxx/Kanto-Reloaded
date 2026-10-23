# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Speed Indicator
#==============================================================================
# Speed-Up's corner toast (his pick 2026-10-23: Design 3, the toast, made
# smaller than Design 1): a fast-forward mark and the speed in a pill, in the
# top-right corner, for a moment when the speed you set changes. Gold while
# sped up; at 1x a play mark and a grey pill. It says the speed running: in a
# settings screen, the 2x it's held to there. Messages at 1x doesn't show.
# Over the map, battles and menus, under popups. Speed-Up says when (show,
# sync, update: SpeedUp.indicate).
#==============================================================================

return unless defined?(Reloaded::Pixel) && defined?(::KIF::PixelFont)

module Reloaded
  module SpeedUpIndicator
    SECONDS = 1.2
    FADE = 0.3
    H = 22
    MARGIN = 8
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    GOLD_FILL = Color.new(70, 58, 20)

    class << self
      attr_reader :sprite

      # Shows the speed for a moment
      def show(speed)
        return hide unless Reloaded::Settings.get(:"speed_up.indicator")
        draw(speed)
      rescue StandardError => e
        Reloaded::Log.exception("The Speed Indicator couldn't be shown", e, :interface)
        hide
      end

      # A box already showing says this speed instead, for the time it has
      # left; none showing stays so
      def sync(speed)
        return unless @sprite
        left = @until
        draw(speed)
        @until = left
      rescue StandardError => e
        Reloaded::Log.exception("The Speed Indicator couldn't be shown", e, :interface)
        hide
      end

      # Each frame: fades out in real time
      def update
        fade
      end

      def hide
        @sprite.bitmap.dispose if @sprite && !@sprite.disposed? && @sprite.bitmap
        @sprite.dispose if @sprite && !@sprite.disposed?
        @viewport.dispose if @viewport && !@viewport.disposed?
        @sprite = @viewport = nil
      end

      # Its width for a speed
      def width(speed)
        return 6 + 11 + 5 + pill_w(speed) + 5
      end

      # Paints it into b at x, y in the colours c (the screen's own: the map
      # menus' Theme Mode)
      def paint(b, c, speed, x = 0, y = 0)
        w = width(speed)
        fast = speed > 1
        P.ui.rbox(b, x, y, x + w - 1, y + H - 1, 6, c[:panel], c[:line])
        mark(b, x + 6, y + H / 2, fast ? c[:gold] : c[:dim], fast)
        tone = fast ? c[:gold] : c[:dim]
        fill = c[:light] ? Reloaded::Palette.mix(c[:panel2], tone, 0.22) : (fast ? GOLD_FILL : c[:dark])
        P.pill(b, x + w - 5, y + (H - 16) / 2, label(speed), fill, tone, true)
        return w
      end

      private

      def label(speed)
        return "X#{speed}"
      end

      def pill_w(speed)
        return P.width(PF::TINY, label(speed)) + 12
      end

      # Fast-forward (two triangles) or play (one), its left at x, centred
      # on cy
      def mark(b, x, cy, col, fast)
        (fast ? 2 : 1).times do |k|
          5.times { |r| b.fill_rect(x + k * 6 + r, cy - 5 + r, 1, 11 - r * 2, col) }
        end
      end

      def draw(speed)
        hide
        c = Reloaded::Palette.map_menu
        w = width(speed)
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 100_300
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = Bitmap.new(w, H)
        @sprite.x = Graphics.width - MARGIN - w
        @sprite.y = MARGIN
        paint(@sprite.bitmap, c, speed)
        @until = now + SECONDS
      end

      # Fades out in real time (the game's steps run faster when sped up)
      def fade
        return unless @sprite
        return hide if @sprite.disposed?
        left = @until - now
        return hide if left <= 0
        @sprite.opacity = left < FADE ? (255 * left / FADE).to_i : 255
      end

      def now
        return Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
