# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Field Strip
#==============================================================================
# Design 1, Chips (his pick, 2026-10-28): over the battle menu's left while
# you choose (Q19), each effect on the field a chip in its type's colour
# with the turns it has left in gold; the foe's side's end in a red FOE tag;
# endless weather and terrain show the gold infinity mark (Q20). The whole
# field's first, then yours, then the foe's; two lines at most, growing up,
# then a +N MORE chip (Battle Info's Field tab has them all).
#
# Drawn when a command box opens and only when the field changed since (a
# signature of what it shows); nothing runs per frame. Above EBDX's command
# row, or PIF's command box. A Battle Menu setting, Field Strip, On.
#==============================================================================

module Reloaded
  module FieldStrip
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    W = 512
    H = 384
    CHIP_H = 16
    LINES = 2
    X0 = 8
    ROOM = 300                   # how far right the chips go
    EBDX_BOTTOM = 300            # the lowest line's top: over EBDX's command row
    PIF_BOTTOM = 268             # over PIF's command box (it starts at 288)
    FOE_TAG = "FOE"
    INF = [".###...###.", "#...#.#...#", "#....#....#", "#...#.#...#", ".###...###."].freeze   # the Overworld Menu's ∞, 1 px

    class << self
      def show(scene, battle)
        items = strip_items(battle)
        if items.empty?
          hide
          return
        end
        ebdx = ebdx?(scene)
        c = Reloaded::Palette.map_menu
        sig = [items, ebdx, c[:light] ? 1 : 0, Reloaded::Settings.get(:"interface.theme")]
        make unless @sprite && !@sprite.disposed?
        if sig != @sig
          @sig = sig
          draw(c, items, ebdx ? EBDX_BOTTOM : PIF_BOTTOM)
        end
        @sprite.visible = true
      rescue StandardError => e
        Reloaded::Log.exception("The Field Strip couldn't be drawn", e, :battle_menu)
        hide
      end

      def hide
        @sprite.visible = false if @sprite && !@sprite.disposed?
      end

      def dispose
        if @sprite && !@sprite.disposed?
          @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
          @sprite.dispose
        end
        @viewport.dispose if @viewport && !@viewport.disposed?
        @sprite = @viewport = @sig = nil
      end

      def visible?
        return @sprite && !@sprite.disposed? && @sprite.visible ? true : false
      end

      def bitmap
        return @sprite && !@sprite.disposed? ? @sprite.bitmap : nil
      end

      def ebdx?(scene)
        cw = scene.instance_variable_get(:@commandWindow)
        return defined?(::CommandWindowEBDX) && cw.is_a?(::CommandWindowEBDX) ? true : false
      end

      # Over the battle (its viewports are 99,999), under the Battle Menu
      # made after it
      def make
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 99_999
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = Bitmap.new(W, H)
        @sprite.visible = false
      end

      # The Reader's field, endless weather and terrain marked :inf
      def strip_items(battle)
        return Reloaded::BattleMenu::Reader.field_items(battle).map do |words, n, side, type|
          [words, n.nil? && side == :field && type ? :inf : n, side, type]
        end
      end

      def draw(c, items, bottom)
        b = @sprite.bitmap
        b.clear
        flow(b, c, items, X0, X0 + ROOM, bottom)
      end

      def chip_w(words, num, side)
        w = P.width(PF::TINY, words.upcase) + 12
        w += (num == :inf ? 11 : P.width(PF::TINY, num.to_s)) + 5 if num
        w += P.width(PF::TINY, FOE_TAG) + 10 if side == 1
        return w
      end

      # A chip: its words in the effect's colour on a dark (pale) plate, the
      # turns in gold, the foe's ending in a red FOE tag
      def chip(b, c, x, y, words, num, type, side)
        w = chip_w(words, num, side)
        fill = Color.new(c[:panel2].red, c[:panel2].green, c[:panel2].blue, c[:light] ? 240 : 232)
        P.ui.rbox(b, x, y, x + w, y + CHIP_H, 4, fill, c[:line])
        lx = x + 6
        ink = type ? Reloaded::PartyPaint.ink(c, Reloaded::PartyScreen.type_rgb(type)) : c[:strong]
        lx += P.text(b, lx, y, 300, CHIP_H + 1, words.upcase, ink, PF::TINY)
        if num == :inf
          infinity(b, lx + 5, y + 6, c[:gold])
        elsif num
          P.text(b, lx + 5, y, 40, CHIP_H + 1, num.to_s, c[:gold], PF::TINY)
        end
        if side == 1
          tw = P.width(PF::TINY, FOE_TAG) + 6
          mix = Reloaded::Palette.mix(c[:panel2], c[:red], c[:light] ? 0.25 : 0.4)
          P.ui.rbox(b, x + w - tw - 3, y + 2, x + w - 3, y + CHIP_H - 2, 3, mix)
          P.text(b, x + w - tw - 3, y + 1, tw, CHIP_H - 2, FOE_TAG, c[:light] ? c[:red] : c[:strong], PF::TINY, 2)
        end
        return w
      end

      def infinity(b, x, y, col)
        INF.each_with_index { |ln, r| ln.each_char.with_index { |ch, k| b.fill_rect(x + k, y + r, 1, 1, col) if ch == "#" } }
      end

      def more_w(n)
        return P.width(PF::TINY, _INTL("+{1} MORE", n)) + 12
      end

      def more_chip(b, c, x, y, n)
        w = more_w(n)
        fill = Color.new(c[:panel2].red, c[:panel2].green, c[:panel2].blue, c[:light] ? 240 : 232)
        P.ui.rbox(b, x, y, x + w, y + CHIP_H, 4, fill, c[:line])
        P.text(b, x, y, w, CHIP_H + 1, _INTL("+{1} MORE", n), c[:dim], PF::TINY, 2)
      end

      # Chips in lines between x0 and x1, the first at y, the next ones
      # going up; what doesn't fit becomes a +N MORE chip at the end
      def flow(b, c, items, x0, x1, y)
        width = proc { |it| chip_w(it[0], it[1], it[2]) + 4 }
        lines = [[]]
        used = 0
        left = items.dup
        until left.empty?
          w = width.call(left.first)
          if used + w > x1 - x0 + 4 && !lines.last.empty?
            break if lines.length >= LINES
            lines << []
            used = 0
          end
          lines.last << left.shift
          used += w
        end
        unless left.empty?
          while !lines.last.empty? && lines.last.sum { |it| width.call(it) } + more_w(left.length + 1) + 4 > x1 - x0 + 4
            left.unshift(lines.last.pop)
          end
          lines.last << [:more, left.length]
        end
        lines.each_with_index do |line, r|
          ly = y - r * (CHIP_H + 4)
          x = x0
          line.each do |it|
            if it[0] == :more
              more_chip(b, c, x, ly, it[1])
              x += more_w(it[1]) + 4
            else
              chip(b, c, x, ly, it[0], it[1], it[3], it[2])
              x += width.call(it)
            end
          end
        end
      end
    end
  end
end
