# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the rank-up toast (Trainer Control's Rematch Ranks)
#==============================================================================
# His pick (2026-11-01, "#3, but in #2 form"): the Promotion Card, the tier
# toast's size (70 px tall), on the toast's timing (3 seconds of real time),
# after any toast already up:
#
#   the plate  60 x 58 in the rank's colour: the trainer's face, the rank's
#              insignia on its corner (Seasoned one chevron, Veteran two,
#              Elite three, Master a star)
#   the words  PROMOTED (the rank's colour) and their class over their name
#   the stars  four, the ranks reached lit; the new one pops in at twice its
#              size a moment in, then lights (the insignia with it), over
#              NOW A VETERAN (NOW ELITE...) in the rank's colour; your
#              record with them left of the stars, in green
#   its sound  BW_lvup (his pick)
#==============================================================================

module Reloaded
  module RankToast
    H = 70
    TX = 76
    POP = 0.4                              # seconds before the new star pops in
    LIT = 0.5                              # and before it settles, lit
    ME = "BW_lvup"
    STAR = [".....#.....", "....###....", "....###....", "###########", ".#########.", "..#######..", "..#######..", ".####.####.",
            ".###...###.", ".#.......#."].freeze
    STAR_S = ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", ".#...#."].freeze
    STAR_STEP = 14
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint

    class << self
      # rec: the trainer's record; rank: the one just reached
      def promoted(rec, rank)
        return false unless rec && rank
        c = Reloaded::Palette.map_menu
        face = Reloaded::TrainerControl::Pictures.face(rec["type"])
        cards = [:none, :pop, :lit].map { |star| card(c, rec, rank, face, star) }
        return Reloaded::Toast.queue { Reloaded::Toast.card(cards[0], :later => [[POP, cards[1]], [LIT, cards[2]]], :me => ME) }
      ensure
        face.dispose if face && !face.disposed?
      end

      def mix(a, b, t)
        return Reloaded::Palette.mix(a, b, t)
      end

      def label(rank)
        return rank.index.odd? ? _INTL("NOW A {1}", _INTL(rank.name).upcase) : _INTL("NOW {1}", _INTL(rank.name).upcase)
      end

      # A chevron pointing up, its tip at (cx, y)
      def chevron(b, cx, y, col)
        (0..3).each do |dx|
          b.fill_rect(cx - dx, y + dx, 1, 2, col)
          b.fill_rect(cx + dx, y + dx, 1, 2, col) if dx > 0
        end
      end

      # The rank's insignia on a round badge centred on cx, cy
      def insignia(b, c, rank, cx, cy, rad)
        fill, col = PP.badge(c, rank.rgb)
        PP.disc(b, cx, cy, rad, fill)
        if rank.index >= 3
          PP.pixels(b, STAR_S, cx - 3, cy - 3, col)
          return
        end
        n = rank.index + 1
        y = cy - ((n - 1) * 3 + 5) / 2
        n.times { |i| chevron(b, cx, y + i * 3, col) }
      end

      def pattern(b, rows, x, y, col, s)
        rows.each_with_index { |ln, r| ln.each_char.with_index { |ch, k| b.fill_rect(x + k * s, y + r * s, s, s, col) if ch == "#" } }
      end

      # The card; star: :none (the new rank not shown yet), :pop, :lit
      def card(c, rec, rank, face, star)
        col = PP.ink(c, rank.rgb)
        words = label(rank)
        record = "#{rec["wins"].to_i}-#{rec["losses"].to_i}"
        name = rec["name"].to_s
        cls = Reloaded::TrainerControl::Records.class_name(rec["type"]).to_s.upcase
        promoted = _INTL("PROMOTED")
        stars_w = 4 * STAR_STEP - 3
        name_w = [P.width(PF::ROW, name), P.width(PF::TINY, "#{promoted} #{cls}") + 4].max
        right_w = [P.width(PF::ROW, record) + 12 + stars_w, P.width(PF::TINY, words)].max
        w = TX + name_w + 28 + right_w + 16
        o = Bitmap.new(w, H)
        PP.chamfer_grad(o, 0, 0, w, H, 11, mix(c[:panel], col, 0.16), c[:panel], mix(c[:line], col, 0.45))
        PP.chamfer_grad(o, 6, 6, 66, H - 6, 8, mix(c[:panel2], col, 0.6), mix(c[:panel2], c[:dark], 0.3), mix(c[:line], col, 0.6))
        o.stretch_blt(Rect.new(12, 11, 48, 48), face, Rect.new(0, 0, face.width, face.height)) if face
        insignia(o, c, rank, 58, 54, 9) if star != :none
        pw = P.text(o, TX, 12, 120, 12, promoted, col, PF::TINY)
        P.text(o, TX + pw + 5, 12, 160, 12, cls, c[:head], PF::TINY)
        P.text(o, TX - 1, 25, name_w + 4, 22, name, c[:strong], PF::ROW)
        sx = w - 16 - stars_w
        off = mix(c[:panel], c[:dim], c[:light] ? 0.35 : 0.4)
        4.times do |i|
          x = sx + i * STAR_STEP
          if i == rank.index && star == :pop
            pattern(o, STAR, x + 5 - 11, 10, col, 2)
          else
            lit = i < rank.index || (i == rank.index && star != :none)
            pattern(o, STAR, x, 16, lit ? col : off, 1)
          end
        end
        lw = P.width(PF::TINY, words)
        P.text(o, w - 16 - lw, 36, lw + 2, 12, words, col, PF::TINY)
        rw = P.width(PF::ROW, record)
        P.text(o, [sx, w - 16 - lw].min - 12 - rw, 20, rw + 2, 22, record, c[:green], PF::ROW)
        return o
      end
    end
  end
end
