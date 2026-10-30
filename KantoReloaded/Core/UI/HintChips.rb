# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Battle Scene's hint chips
#==============================================================================
# While you choose Fight, Bag, Pokémon or Run (his picks, 2026-10-29): the
# Battle Menu's button, and each Battle Menu shortcut you bound (Open Battle
# Info, Open Battle Favorite, Quick Throw), as chips in the Field Strip's
# look, in your controller's style. Only what works now (Quick Throw's while
# it's offered in this battle and there's a ball to throw). Right-aligned
# over EBDX's command row (the Field Strip on the left
# stops short of them), along the bottom of PIF's message box, or in the
# Corner Panel's left panel (that row draws them itself with draw).
#
# Drawn when a command box opens and only when what they show changed; a
# Battle Scene setting, Button Hints, On.
#==============================================================================

module Reloaded
  module HintChips
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    BI = Reloaded::ButtonIcons
    CHIP_H = 16
    ICON_H = 14
    GAP = 4
    EBDX_RIGHT = [504, 301].freeze         # over EBDX's row (the Field Strip's line)
    PIF_RIGHT = [248, 362].freeze          # PIF's message box, under "What will X do?"

    class << self
      # [input, words] for each hint, on the device in use
      def pairs
        bm = Reloaded::BattleMenu
        out = []
        menu = shown(:battle_menu) || Reloaded::Prompts.input(:A) || Reloaded::Prompts.name(:A)
        out << [menu, _INTL("Battle Menu")]
        if Reloaded::Prompts.controls?
          info = shown(:open_battle_info)
          out << [info, _INTL("Battle Info")] if info
          fav = shown(:open_battle_favorite)
          if fav
            e = bm.entry(bm.favorite_key) rescue nil
            out << [fav, e ? e.name.to_s : _INTL("Favorite")]
          end
          qt = shown(:quick_throw)
          out << [qt, _INTL("Quick Throw")] if qt && defined?(Reloaded::QuickThrow) && Reloaded::QuickThrow.hint?(@scene)
        end
        return out
      end

      # An action's own button, when Reloaded Controls has one bound
      def shown(id)
        return nil unless Reloaded::Prompts.controls?
        side = Reloaded::Prompts.controller? ? :pad : :keys
        token = Reloaded::Controls.bindings(id, side).first
        return token ? Reloaded::Controls.shown_input(token) : nil
      rescue StandardError
        return nil
      end

      def chip_w(input, words, style)
        return icon_w(input, style) + 5 + P.width(PF::TINY, words) + 12
      end

      def icon_w(input, style)
        t = input.to_s
        return BI.width(t, style, ICON_H) if Reloaded::Controls::Inputs.valid?(t)
        return P.cap_width(t)
      end

      def width(list = pairs, style = Reloaded::Prompts.style)
        return 0 if list.empty?
        return list.sum { |i, w| chip_w(i, w, style) } + GAP * (list.length - 1)
      end

      # The chips' left edge when they end at x1 (the Field Strip stops short
      # of it), kept until what they show changes
      def left_edge(spot)
        list = pairs
        style = Reloaded::Prompts.style
        sig = [list, style]
        @edge = [sig, spot[0] - width(list, style)] if @edge.nil? || @edge[0] != sig || @edge_x1 != spot[0]
        @edge_x1 = spot[0]
        return @edge[1]
      end

      # The chips on a bitmap, ending at x1 (the Corner Panel's, and this
      # sprite's own)
      def draw(b, c, x1, y, list = pairs, style = Reloaded::Prompts.style)
        x = x1 - width(list, style)
        fill = Color.new(c[:panel2].red, c[:panel2].green, c[:panel2].blue, c[:light] ? 240 : 232)
        list.each do |input, words|
          w = chip_w(input, words, style)
          P.ui.rbox(b, x, y, x + w, y + CHIP_H, 4, fill, c[:line])
          t = input.to_s
          iw = if Reloaded::Controls::Inputs.valid?(t)
                 BI.draw(b, x + 4, y + 1, t, c, style, ICON_H)
               else
                 cw = P.cap_width(t)
                 P.ui.rbox(b, x + 4, y + 1, x + 3 + cw, y + CHIP_H - 2, 3, c[:key] || c[:line])
                 P.text(b, x + 4, y, cw, CHIP_H, t, c[:txt], PF::TINY, 2)
                 cw
               end
          P.text(b, x + 4 + iw + 5, y, 200, CHIP_H + 1, words, c[:strong], PF::TINY)
          x += w + GAP
        end
      end

      # The sprite over a command box (not the Corner Panel's: it has its own)
      def show(scene)
        @scene = scene                       # whose battle the chips are for (Quick Throw's)
        ebdx = Reloaded::BattleScene.ebdx?(scene)
        if ebdx
          cw = scene.instance_variable_get(:@commandWindow)
          kind = cw.instance_variable_get(:@kr_scene)&.kind || Reloaded::BattleScene.row
          return hide if kind == :corner
          x1, y = EBDX_RIGHT
          y = Reloaded::CommandRow::SLIM_STRIP + 1 if kind == :slim
        else
          x1, y = PIF_RIGHT
        end
        list = pairs
        c = Reloaded::Palette.map_menu
        sig = [list, Reloaded::Prompts.style, x1, y, c[:light] ? 1 : 0, Reloaded::Settings.get(:"interface.theme")]
        make unless @sprite && !@sprite.disposed?
        if sig != @sig
          @sig = sig
          @sprite.bitmap.clear
          draw(@sprite.bitmap, c, x1, y, list)
        end
        @sprite.visible = true
      rescue StandardError => e
        Reloaded::Log.exception("Battle Scene: the hint chips couldn't be drawn", e, Reloaded::BattleScene::FEATURE)
        hide
      end

      def hide
        @sprite.visible = false if @sprite && !@sprite.disposed?
      end

      def visible?
        return @sprite && !@sprite.disposed? && @sprite.visible ? true : false
      end

      def bitmap
        return @sprite && !@sprite.disposed? ? @sprite.bitmap : nil
      end

      def dispose
        if @sprite && !@sprite.disposed?
          @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
          @sprite.dispose
        end
        @viewport.dispose if @viewport && !@viewport.disposed?
        @sprite = @viewport = @sig = @edge = @scene = nil
      end

      # Over the battle (its viewports are 99,999), under the Battle Menu
      def make
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 99_999
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        @sprite.visible = false
      end
    end
  end
end
