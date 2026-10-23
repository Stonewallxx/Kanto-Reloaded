#==============================================================================
# Kanto Reloaded: the Party Screen's drawing
#==============================================================================
# His look (His Mix, 2026-10-21): a soft gradient with a dot grid, the
# header with Poke red under it, cut-corner cards lit in their type's colour
# with a slash of it behind the sprite, the details panel with its type
# band, a red line and the big type labels, outlined HP bars. Light (Theme
# Mode) gives the same in the Light frames' colours (Palette.map_menu).
# The screen's logic is in PartyScene.rb.
#==============================================================================

return unless defined?(::KIF::PixelFont)

module Reloaded
  module PartyPaint
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    W = 512
    H = 384
    CW = 152                  # a card
    CH = 96
    GX = 8                    # the cards' corner
    GY = 38
    GAP = 6
    DX = GX + 2 * CW + 14     # the details panel
    DW = W - 8 - DX
    DH = 3 * CH + 12
    LINE_Y = 137              # the panel's red line, from its top
    POKE_RED = Color.new(220, 60, 60)
    WHITE = Color.new(248, 248, 248)
    BLACK = Color.new(0, 0, 0)
    HP_EDGE = Color.new(150, 166, 188)
    HP_INNER = Color.new(16, 20, 28)
    GOLD_FILL = Color.new(70, 58, 20)
    TYPES_SMALL = "Graphics/OverworldMenu/typesSmall16"
    TYPES_BIG = "Graphics/Pictures/types"
    STATUS = { :SLEEP => ["SLP", [150, 160, 175]], :POISON => ["PSN", [190, 110, 220]], :BURN => ["BRN", [240, 130, 70]],
               :PARALYSIS => ["PAR", [240, 210, 70]], :FROZEN => ["FRZ", [120, 200, 240]] }.freeze
    NOTE_RGB = { "ABLE" => [120, 230, 150], "NOT ABLE" => [240, 110, 100], "LEARNED" => [130, 190, 250] }.freeze
    MALE = ["..####", "....##", "...#.#", ".##...", "#..#..", "#..#..", ".##..."].freeze
    FEMALE = [".###.", "#...#", "#...#", ".###.", "..#..", ".###.", "..#.."].freeze
    STAR = ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", "##...##"].freeze
    LOCK = [".###.", "#...#", "#...#", "#####", "##.##", "##.##", "#####"].freeze

    module_function

    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    def rgb(a)
      return Color.new(*a)
    end

    def slot_xy(i)
      return [GX + (i % 2) * (CW + GAP), GY + (i / 2) * (CH + GAP)]
    end

    #--------------------------------------------------------------------------
    # Pieces
    #--------------------------------------------------------------------------
    # top colour to bottom colour, a row at a time; inset gives each row's
    # [left, right] margin
    def grad(b, x0, y0, x1, y1, top, bottom, inset = nil)
      h = [y1 - y0, 1].max
      (y0...y1).each do |y|
        l, r = inset ? inset.call(y) : [0, 0]
        b.fill_rect(x0 + l, y, x1 - x0 - l - r, 1, mix(top, bottom, (y - y0).to_f / h))
      end
    end

    # a box with its top-left and bottom-right corners cut
    def chamfer(b, x0, y0, x1, y1, cut, fill, edge)
      (y0...y1).each do |y|
        l = [cut - (y - y0), 0].max
        r = [cut - (y1 - 1 - y), 0].max
        b.fill_rect(x0 + l, y, x1 - x0 - l - r, 1, edge)
      end
      return if fill.nil?
      (y0 + 1...y1 - 1).each do |y|
        l = [cut - (y - y0), 0].max
        r = [cut - (y1 - 1 - y), 0].max
        b.fill_rect(x0 + 1 + l, y, x1 - x0 - 2 - l - r, 1, fill)
      end
    end

    # a cut-corner box lit from the top
    def chamfer_grad(b, x0, y0, x1, y1, cut, top, bottom, edge)
      chamfer(b, x0, y0, x1, y1, cut, nil, edge)
      inset = proc { |y| [[cut - (y - y0), 0].max, [cut - (y1 - 1 - y), 0].max] }
      grad(b, x0 + 1, y0 + 1, x1 - 1, y1 - 1, top, bottom, inset)
    end

    # a cut-corner outline, 2 px, dashed every `dash` dots when given
    def chamfer_outline(b, x0, y0, x1, y1, cut, col, dash = nil)
      pts = []
      (x0 + cut..x1 - 1).each { |x| pts << [x, y0] }
      (y0..y1 - 1 - cut).each { |y| pts << [x1 - 1, y] }
      (0..cut).each { |k| pts << [x1 - 1 - k, y1 - 1 - cut + k] }
      (x0..x1 - 1 - cut).each { |x| pts << [x, y1 - 1] }
      (y0 + cut..y1 - 1).each { |y| pts << [x0, y] }
      (0..cut).each { |k| pts << [x0 + k, y0 + cut - k] }
      pts.each_with_index do |(x, y), i|
        next if dash && (i / dash).odd?
        b.fill_rect(x, y, 2, 2, col)
      end
    end

    def disc(b, cx, cy, r, col)
      (-r..r).each do |dy|
        w = Math.sqrt(r * r - dy * dy).round
        b.fill_rect(cx - w, cy + dy, 2 * w + 1, 1, col)
      end
    end

    def pixels(b, rows, x, y, col)
      rows.each_with_index { |ln, r| ln.each_char.with_index { |ch, k| b.fill_rect(x + k, y + r, 1, 1, col) if ch == "#" } }
    end

    # a badge's [fill, words]: dark with the colour's words, or on Light pale
    # with them deepened
    def badge(c, rgb_a)
      col = rgb(rgb_a)
      return [Color.new(rgb_a[0] / 4, rgb_a[1] / 4, rgb_a[2] / 4), col] unless c[:light]
      ink = mix(col, BLACK, 0.35)
      return [mix(c[:panel2], ink, 0.22), ink]
    end

    # an outlined bar (the HP bars, the steps and EXP bars)
    def bar(b, c, x, y, w, frac, col, h = 4)
      edge = c[:light] ? c[:line] : HP_EDGE
      inner = c[:light] ? mix(c[:line], BLACK, 0.4) : HP_INNER
      P.ui.rbox(b, x - 2, y - 2, x + w + 2, y + h + 2, 2, edge)
      P.ui.rbox(b, x - 1, y - 1, x + w + 1, y + h + 1, 1, inner)
      P.ui.rbox(b, x, y, x + w, y + h, 1, c[:dark])
      P.ui.rbox(b, x, y, x + [(w * frac).round, 2].max, y + h, 1, col) if frac > 0
    end

    def hp_colour(c, pkmn)
      f = pkmn.hp.to_f / [pkmn.totalhp, 1].max
      return f > 0.5 ? c[:green] : (f > 0.25 ? c[:amber] : c[:red])
    end

    def swap_badge(b, c, cx, cy)
      disc(b, cx, cy, 11, c[:selb])
      disc(b, cx, cy, 10, c[:sel])
      P.ui.tri(b, cx + 1, cy - 7, :r, WHITE, 4)
      b.fill_rect(cx - 5, cy - 3, 7, 2, WHITE)
      P.ui.tri(b, cx - 6, cy + 1, :l, WHITE, 4)
      b.fill_rect(cx - 1, cy + 4, 7, 2, WHITE)
    end

    #--------------------------------------------------------------------------
    # The background and header
    #--------------------------------------------------------------------------
    def paint_background(b, c)
      bottom = c[:light] ? mix(c[:bg], c[:acc], 0.15) : mix(c[:bg], BLACK, 0.4)
      grad(b, 0, 0, W, H, mix(c[:bg], c[:sel], 0.35), bottom)
      dot = mix(c[:bg], c[:line], 0.6)
      (40...H - P::HINT_H).step(12) { |y| (6...W).step(12) { |x| b.fill_rect(x, y, 1, 1, dot) } }
      grad(b, 0, 0, W, 30, mix(c[:panel], c[:selb], 0.25), c[:panel])
      b.fill_rect(0, 29, W, 2, POKE_RED)
    end

    def paint_title(top, c, title)
      P.text(top, 0, 4, W, 22, PF.fit(PF::ROW, title.to_s, W - 20), c[:title], PF::ROW, 2)
    end

    #--------------------------------------------------------------------------
    # A card
    #--------------------------------------------------------------------------
    # the card's colour: its type's, red when fainted, the line's for an Egg
    def tone(c, pkmn, types)
      return c[:line] if pkmn.egg?
      return c[:red] if pkmn.hp <= 0
      return rgb(Reloaded::PartyScreen.type_rgb(types[0]))
    end

    def paint_card_plate(b, c, x0, y0, pkmn, types, sel)
      x1 = x0 + CW
      y1 = y0 + CH
      cut = 12
      t = tone(c, pkmn, types)
      if sel
        chamfer(b, x0 - 3, y0 - 3, x1 + 3, y1 + 3, cut + 2, mix(c[:bg], c[:selb], 0.25), mix(c[:bg], c[:selb], 0.25))
        chamfer(b, x0 - 1, y0 - 1, x1 + 1, y1 + 1, cut + 1, mix(c[:bg], c[:selb], 0.6), mix(c[:bg], c[:selb], 0.6))
      end
      top = mix(c[:panel2], t, pkmn.egg? ? 0.1 : 0.5)
      bottom = mix(c[:panel2], c[:dark], 0.5)
      chamfer_grad(b, x0, y0, x1, y1, cut, top, bottom, sel ? c[:selb] : mix(c[:line], t, 0.4))
      return if pkmn.egg?
      (y0 + 2...y1 - 2).each do |y|
        under = mix(top, bottom, (y - y0).to_f / (y1 - y0))
        b.fill_rect(x0 + 8 + (y1 - y) / 3, y, 30, 1, mix(under, t, 0.45))
      end
      b.fill_rect(x0 + 13, y0 + 1, x1 - x0 - 16, 1, mix(t, WHITE, 0.4))
    end

    # An empty spot: a dashed outline saying EMPTY (his pick)
    def paint_empty(b, top, c, x, y)
      chamfer_outline(b, x, y, x + CW, y + CH, 12, mix(c[:line], c[:dim], 0.3), 4)
      P.text(top, x, y + CH / 2 - 6, CW, 12, _INTL("EMPTY"), c[:dim], PF::TINY, 2)
    end

    # A greyed-out card (can't be chosen for this), on the layer above its
    # sprite and words
    def grey_out(over, c, x, y)
      shade = c[:light] ? Color.new(c[:panel2].red, c[:panel2].green, c[:panel2].blue, 170) : Color.new(10, 12, 18, 150)
      chamfer(over, x, y, x + CW, y + CH, 12, shade, shade)
    end
  end
end
