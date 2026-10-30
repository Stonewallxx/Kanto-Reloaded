#==============================================================================
# Kanto Reloaded: the toast
#==============================================================================
# A short line at the top of the screen for a moment, with no button: you
# keep going (his pick for Auto-Repel Reuse, 2026-10-21; the PokeVial's
# toasts, 2026-10-22). An icon, what happened, and a pill at its end, or a
# drawing of the caller's own there (the PokeVial's charges). Every toast
# goes after 3 seconds of real time, its last half second fading (his rule,
# 2026-10-29), whatever the game is doing: the map, a menu, the Bag, a
# battle, the game sped up. Checked each time the game draws a frame
# (Graphics.update). It shows over the map menus, under popups.
#
#   Reloaded::Toast.show("Used Another Super Repel", :icon => :SUPERREPEL,
#                        :pill => ["4 LEFT", :gold])
#   Reloaded::Toast.show("The PokeVial regained a charge.", :icon => "Graphics/PauseMenu/POKEVIAL",
#                        :paint => [width, proc { |b, x0, y0, colours| ... }])
#
# :icon is an item (its Bag icon), a picture's path, or a Bitmap (its first
# square frame: a Pokémon's icon); :pill's colour is :gold, :green or :red
# (the Theme Mode's tone of it). :hold keeps it until the next toast (or
# dispose): the startup checks' "Checking for Updates..." while the game
# waits on them.
#==============================================================================

return unless defined?(Reloaded::Pixel) && defined?(::KIF::PixelFont)

module Reloaded
  module Toast
    SECONDS = 3.0          # on screen, in real time
    FADE = 0.5             # its last half second fades
    H = 30
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    # Dark's pill fills (on Light, the pill is the palette's pale mix)
    FILLS = { :gold => Color.new(70, 58, 20), :green => Color.new(24, 60, 36), :red => Color.new(70, 26, 24) }.freeze

    class << self
      attr_reader :sprite

      def boot
        Reloaded::Hooks.prepend(nil, ::Graphics.singleton_class, FrameHook, :id => :toast_frames) if defined?(::Graphics)
        return true
      end

      # Seconds on a clock that only goes forward (real time)
      def now
        return Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def show(text, icon: nil, pill: nil, paint: nil, hold: false)
        dispose
        c = Reloaded::Palette.map_menu   # Theme Mode, as the map menus
        text = text.to_s
        tw = P.width(PF::TEXT, text)
        end_w = if paint then paint[0].to_i
                elsif pill then P.width(PF::TINY, pill[0].to_s) + 12
                else 0
                end
        lx = icon ? 34 : 12
        w = lx + tw + (end_w > 0 ? 10 + end_w : 0) + 10
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 100_300
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = Bitmap.new(w, H)
        @sprite.x = (Graphics.width - w) / 2
        @sprite.y = 10
        o = @sprite.bitmap
        P.ui.rbox(o, 0, 0, w - 1, H - 1, 7, c[:panel], c[:line])
        draw_icon(o, icon, 18, H / 2) if icon
        P.text(o, lx, 6, tw + 2, 18, text, c[:txt], PF::TEXT)
        if paint
          paint[1].call(o, w - 10 - end_w, 7, c)
        elsif pill
          tone = c[pill[1]] || c[:gold]
          fill = c[:light] ? Reloaded::Palette.mix(c[:panel2], tone, 0.22) : (FILLS[pill[1]] || FILLS[:gold])
          P.pill(o, w - 10, 7, pill[0].to_s, fill, tone, true)
        end
        @shown_at = hold ? nil : now
        return true
      rescue StandardError => e
        Reloaded::Log.exception("A toast couldn't be shown", e, :interface)
        dispose
        return false
      end

      # Shown and kept until the next one (:hold)
      def held?
        return @sprite && !@sprite.disposed? && @shown_at.nil? ? true : false
      end

      # Its fade from the time it's been up (any number of calls a frame)
      def update
        return unless @sprite && @shown_at
        left = SECONDS - (now - @shown_at)
        return dispose if left <= 0
        @sprite.opacity = [(255 * left / FADE).to_i, 255].min unless @sprite.disposed?
      end

      def dispose
        @sprite.bitmap.dispose if @sprite && !@sprite.disposed? && @sprite.bitmap
        @sprite.dispose if @sprite && !@sprite.disposed?
        @viewport.dispose if @viewport && !@viewport.disposed?
        @sprite = @viewport = @shown_at = nil
      end

      private

      # An item's Bag icon at 24 pixels, or a picture fitted in 24 by 24
      def draw_icon(o, icon, cx, cy)
        if icon.is_a?(Bitmap)
          f = [icon.height, 1].max
          o.stretch_blt(Rect.new(cx - 13, cy - 13, 26, 26), icon, Rect.new(0, 0, [f, icon.width].min, f))
          return
        end
        file = icon.is_a?(Symbol) ? (::GameData::Item.icon_filename(icon) rescue "Graphics/Items/#{icon}") : icon.to_s
        path = defined?(pbResolveBitmap) ? (pbResolveBitmap(file) || file) : file
        bm = Bitmap.new(path)
        if icon.is_a?(Symbol)
          w = h = 24
        else
          s = [24.0 / bm.width, 24.0 / bm.height].min
          w = (bm.width * s).round
          h = (bm.height * s).round
        end
        o.stretch_blt(Rect.new(cx - w / 2, cy - h / 2, w, h), bm, Rect.new(0, 0, bm.width, bm.height))
        bm.dispose
      rescue StandardError
        nil
      end
    end

    # Every frame the game draws, on any screen
    module FrameHook
      def update(*args)
        ret = super
        Reloaded::Toast.update if Reloaded::Toast.sprite
        ret
      end
    end
  end
end
