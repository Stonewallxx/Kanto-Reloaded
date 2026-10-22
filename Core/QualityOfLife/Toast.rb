#==============================================================================
# Kanto Reloaded: Quality of Life: the toast
#==============================================================================
# A short line at the top of the map for a moment, with no button: you keep
# walking (his pick for Auto-Repel Reuse, 2026-10-21): an item's icon, what
# happened, and a gold badge ("4 LEFT"). It fades after about two and a
# half seconds; the map's own update moves it on (Scene_Map#update).
#==============================================================================

module Reloaded
  module QualityOfLife
    module Toast
      FRAMES = 150
      FADE = 30
      P = Reloaded::Pixel
      PF = ::KIF::PixelFont
      GOLD = Color.new(240, 200, 80)
      GOLD_FILL = Color.new(70, 58, 20)

      class << self
        attr_reader :sprite

        def install
          Reloaded::Hooks.prepend(Reloaded::QualityOfLife::FEATURE, "Scene_Map", MapUpdate, :id => :qol_toast) if defined?(::Scene_Map)
          return true
        end

        def show(item, text, badge)
          dispose
          c = Reloaded::Palette.current
          tw = P.width(PF::TEXT, text)
          bw = P.width(PF::TINY, badge) + 12
          w = 34 + tw + 10 + bw + 10
          h = 30
          @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
          @viewport.z = 99_500
          @sprite = Sprite.new(@viewport)
          @sprite.bitmap = Bitmap.new(w, h)
          @sprite.x = (Graphics.width - w) / 2
          @sprite.y = 10
          o = @sprite.bitmap
          P.ui.rbox(o, 0, 0, w - 1, h - 1, 7, c[:panel], c[:line])
          icon(o, item, 18, h / 2)
          P.text(o, 34, 6, tw + 2, 18, text, c[:txt], PF::TEXT)
          P.pill(o, w - 10, 7, badge, GOLD_FILL, GOLD, true)
          @left = FRAMES
          return true
        rescue StandardError => e
          Reloaded::Log.exception("A toast couldn't be shown", e, :quality_of_life)
          dispose
          return false
        end

        def update
          return unless @sprite
          @left -= 1
          @sprite.opacity = [@left * 255 / FADE, 255].min
          dispose if @left <= 0
        end

        def dispose
          @sprite.bitmap.dispose if @sprite && !@sprite.disposed? && @sprite.bitmap
          @sprite.dispose if @sprite && !@sprite.disposed?
          @viewport.dispose if @viewport && !@viewport.disposed?
          @sprite = @viewport = nil
        end

        private

        def icon(o, item, cx, cy)
          file = (::GameData::Item.icon_filename(item) rescue "Graphics/Items/#{item}")
          path = defined?(pbResolveBitmap) ? (pbResolveBitmap(file) || file) : file
          bm = Bitmap.new(path)
          o.stretch_blt(Rect.new(cx - 12, cy - 12, 24, 24), bm, Rect.new(0, 0, bm.width, bm.height))
          bm.dispose
        rescue StandardError
          nil
        end
      end

      module MapUpdate
        def update(*args)
          ret = super
          Reloaded::QualityOfLife::Toast.update
          ret
        end
      end
    end
  end
end
