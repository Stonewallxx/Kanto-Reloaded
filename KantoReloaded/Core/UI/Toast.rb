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
# square frame: a Pokémon's icon); :pill's colour is :gold, :green, :red,
# :blue or :pink (the Theme Mode's tone of it). :hold keeps it until the
# next toast (or dispose): the startup checks' "Checking for Updates..."
# while the game waits on them. :sub is a second, smaller line in gold, and
# :coin a gold coin with a number in it in the icon's place:
#
#   Reloaded::Toast.show("Ten wins in a row!", :coin => "10",
#                        :sub => "A new Best Streak.")
#
# :se or :me plays a sound as it shows (a sound effect, or a jingle). A
# feature that draws its whole card itself (Trainer Control's tier and rank
# toasts) hands the bitmap over, on the same timing; :later swaps in another
# a moment in (the new tier lighting up), or each of a list in turn:
#
#   Reloaded::Toast.card(bitmap, :later => [0.4, lit], :se => "Exclaim")
#   Reloaded::Toast.card(bitmap, :later => [[0.4, pop], [0.5, lit]], :me => "BW_lvup")
#
# :icon_size 32 draws the icon at its full 32 pixels (a picture's first
# square frame), the words from x 44 (the Weather System's alerts, with a
# :sub line):
#
#   Reloaded::Toast.show("Rain Started", :icon => "Graphics/Pictures/Weather/mapRain_medium",
#                        :icon_size => 32, :sub => "Route 24, Moderate")
#
# queue shows a toast once the one up now has gone (at once when there's
# none): two after the same battle, one after the other.
#==============================================================================

return unless defined?(Reloaded::Pixel) && defined?(::KIF::PixelFont)

module Reloaded
  module Toast
    SECONDS = 3.0          # on screen, in real time
    FADE = 0.5             # its last half second fades
    H = 30
    H2 = 44                # with a second line
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    # Dark's pill fills (on Light, the pill is the palette's pale mix)
    FILLS = { :gold => Color.new(70, 58, 20), :green => Color.new(24, 60, 36), :red => Color.new(70, 26, 24),
              :blue => Color.new(32, 47, 62), :pink => Color.new(60, 32, 40) }.freeze

    class << self
      attr_reader :sprite

      def boot
        Reloaded::Hooks.prepend(nil, ::Graphics.singleton_class, FrameHook, :id => :toast_frames) if defined?(::Graphics)
        return true
      end

      # Something at the top of the screen a toast keeps clear of (Wild
      # Link's Chain HUD, top left): a block giving its [x, y, w, h] while
      # it's up, or nil. A toast that would cover it moves to its right, or
      # under it when there's no room
      def keep_clear(id, &rect)
        (@clear ||= {})[id] = rect
      end

      def place(w, h)
        x = (Graphics.width - w) / 2
        y = 10
        (@clear || {}).each_value do |rect|
          r = (rect.call rescue nil)
          next unless r
          rx, ry, rw, rh = r
          next unless x < rx + rw && x + w > rx && y < ry + rh && y + h > ry
          right = rx + rw + 8
          if right + w <= Graphics.width - 8
            x = right
          else
            y = ry + rh + 6
          end
        end
        return [x, y]
      end

      # Seconds on a clock that only goes forward (real time)
      def now
        return Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def show(text, icon: nil, pill: nil, paint: nil, hold: false, sub: nil, coin: nil, se: nil, me: nil, icon_size: nil)
        dispose
        c = Reloaded::Palette.map_menu   # Theme Mode, as the map menus
        text = text.to_s
        tw = P.width(PF::TEXT, text)
        sw = sub ? small_width(sub.to_s) : 0
        end_w = if paint then paint[0].to_i
                elsif pill then P.width(PF::TINY, pill[0].to_s) + 12
                else 0
                end
        big = icon && icon_size.to_i >= 32
        lx = coin ? 40 : (big ? 44 : (icon ? 34 : 12))
        h = sub || big ? H2 : H
        w = lx + [tw + (end_w > 0 ? 10 + end_w : 0), sw].max + (coin ? 14 : 10)
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 100_300
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = Bitmap.new(w, h)
        @sprite.x, @sprite.y = place(w, h)
        o = @sprite.bitmap
        P.ui.rbox(o, 0, 0, w - 1, h - 1, 7, c[:panel], c[:line])
        if coin
          draw_coin(o, c, 20, h / 2, 13, coin.to_s)
        elsif big
          draw_full_icon(o, icon, 6, (h - 32) / 2)
        elsif icon
          draw_icon(o, icon, 18, h / 2)
        end
        ty = sub ? 5 : 6
        P.text(o, lx, ty, tw + 2, 18, text, c[:txt], PF::TEXT)
        P.small(o, lx, 24, sw + 4, 16, sub.to_s, c[:gold]) if sub
        if paint
          paint[1].call(o, w - 10 - end_w, ty + 1, c)
        elsif pill
          fill, tone = pill_colours(c, pill[1])
          P.pill(o, w - 10, ty + 1, pill[0].to_s, fill, tone, true)
        end
        @shown_at = hold ? nil : now
        play(se, me)
        return true
      rescue StandardError => e
        Reloaded::Log.exception("A toast couldn't be shown", e, :interface)
        dispose
        return false
      end

      # A card the caller drew (the toast owns the bitmaps from here)
      def card(bitmap, later: nil, se: nil, me: nil)
        dispose
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 100_300
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = bitmap
        @sprite.x, @sprite.y = place(bitmap.width, bitmap.height)
        @later = later.nil? || later[0].is_a?(Array) ? (later && later.dup) : [later]
        @shown_at = now
        play(se, me)
        return true
      rescue StandardError => e
        Reloaded::Log.exception("A toast couldn't be shown", e, :interface)
        dispose
        return false
      end

      # Shown once the toast up now has gone (now, when there's none)
      def queue(&show)
        return show.call unless @sprite && !@sprite.disposed? && @shown_at
        (@queue ||= []) << show
        return true
      end

      def play(se, me)
        pbSEPlay(se) if se && defined?(pbSEPlay)
        pbMEPlay(me) if me && defined?(pbMEPlay)
      rescue StandardError
        nil
      end

      # A pill's [fill, words] in a tone: Dark's own fill, Light's pale mix
      def pill_colours(c, key)
        tone = c[key] || c[:gold]
        fill = c[:light] ? Reloaded::Palette.mix(c[:panel2], tone, 0.22) : (FILLS[key] || FILLS[:gold])
        return [fill, tone]
      end

      # Shown and kept until the next one (:hold)
      def held?
        return @sprite && !@sprite.disposed? && @shown_at.nil? ? true : false
      end

      # Its fade from the time it's been up (any number of calls a frame)
      def update
        return unless @sprite && @shown_at
        left = SECONDS - (now - @shown_at)
        if left <= 0
          dispose
          nxt = @queue && @queue.shift
          nxt.call if nxt
          return
        end
        while @later && !@later.empty? && SECONDS - left >= @later[0][0] && !@sprite.disposed?
          @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
          @sprite.bitmap = @later.shift[1]
        end
        @sprite.opacity = [(255 * left / FADE).to_i, 255].min unless @sprite.disposed?
      end

      def dispose
        @sprite.bitmap.dispose if @sprite && !@sprite.disposed? && @sprite.bitmap
        @sprite.dispose if @sprite && !@sprite.disposed?
        @viewport.dispose if @viewport && !@viewport.disposed?
        Array(@later).each { |_t, bm| bm.dispose if bm.is_a?(Bitmap) && !bm.disposed? }
        @sprite = @viewport = @shown_at = @later = nil
      end

      private

      def small_width(str)
        probe = Bitmap.new(8, 8)
        P.small_font(probe)
        return probe.text_size(str).width
      ensure
        probe.dispose if probe
      end

      # The gold coin, a number in it
      def draw_coin(o, c, cx, cy, r, text)
        pp = Reloaded::PartyPaint
        gold = c[:light] ? Color.new(214, 160, 30) : Color.new(240, 200, 80)
        pp.disc(o, cx, cy, r + 1, Reloaded::Palette.mix(gold, pp::BLACK, 0.45))
        pp.disc(o, cx, cy, r, gold)
        pp.disc(o, cx - 2, cy - 2, r - 4, Reloaded::Palette.mix(gold, pp::WHITE, 0.25))
        pp.disc(o, cx, cy, r - 3, gold)
        P.text(o, cx - r, cy - 7, 2 * r, 14, text, Color.new(70, 46, 8), PF::TINY, 2)
      end
      public :draw_coin                  # (Kanto Reloaded Debug's Result Notices draw it too)

      # A picture's first square frame at its full 32 pixels
      def draw_full_icon(o, icon, x, y)
        bm = icon.is_a?(Bitmap) ? icon : Bitmap.new(defined?(pbResolveBitmap) ? (pbResolveBitmap(icon.to_s) || icon.to_s) : icon.to_s)
        f = [[bm.height, bm.width].min, 1].max
        o.stretch_blt(Rect.new(x, y, 32, 32), bm, Rect.new(0, 0, f, f))
        bm.dispose unless icon.is_a?(Bitmap)
      rescue StandardError
        nil
      end

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
