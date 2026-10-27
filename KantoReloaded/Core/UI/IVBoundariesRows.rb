# encoding: utf-8
#==============================================================================
# Kanto Reloaded: IV Boundaries' description box
#==============================================================================
# His picks (2026-10-25, the sheet ivb-round2-page): on the preset chips and
# the three ranges the description box says what the range means and shows
# the live preview, Six Bars (Q19): HP to Speed, each track shading the
# allowed range, a sample's fill, a 31 in gold. The sample is worked out
# from six fixed fractions, so the bars glide as a handle moves instead of
# jumping. The other rows keep the screen's own description.
#==============================================================================

return unless defined?(Reloaded::SettingsScreen) && defined?(Reloaded::SettingsScreen::RangeOption)

module Reloaded
  module IVBoundariesRows
    PF = ::KIF::PixelFont
    P = Reloaded::Pixel
    SAMPLE = [0.62, 0.18, 0.99, 0.02, 0.81, 0.37].freeze
    STAT_NAMES = ["HP", "Attack", "Defense", "Sp. Atk", "Sp. Def", "Speed"].freeze
    TEXTS = { :wild => "Fought or caught: Each IV rolls from {1} to {2}.",
              :egg  => "New Eggs roll {1} to {2}. Inherited IVs inside it stay.",
              :gift => "Gifts and trades: Each IV rolls from {1} to {2}." }.freeze
    CAPTIONS = { :wild => "LIVE PREVIEW: A FRESH CATCH", :egg => "LIVE PREVIEW: A NEW EGG",
                 :gift => "LIVE PREVIEW: A NEW GIFT", :any => "LIVE PREVIEW: ANY NEW POKÉMON" }.freeze

    def self.sample(lo, hi)
      return SAMPLE.map { |u| lo + (u * (hi - lo + 1)).floor }
    end

    module Screen
      def paint_description(base, top, c)
        r = (@focus == :list || @query) ? current : nil
        o = r && r.opt
        ivb = Reloaded::IVBoundaries
        mine = o && o.respond_to?(:kr_key) && o.kr_key.to_s.start_with?("iv_boundaries.")
        return super unless mine && !@dropdown && (o.is_a?(Reloaded::SettingsScreen::RangeOption) || o.is_a?(Reloaded::SettingsScreen::PickChipsOption))
        y0 = self.class::LIST_Y1 + 4
        description_box(base, c, y0)
        if o.is_a?(Reloaded::SettingsScreen::PickChipsOption)
          i = o.cursor
          title = o.title
          text = o.description.to_s
          p = ivb::PRESETS[i]
          lo, hi = p ? p[1, 2] : ivb.shown(:wild)
          cap = CAPTIONS[:any]
        else
          src = o.group
          lo, hi = o.values
          title = o.title
          text = _INTL(TEXTS[src], lo, hi)
          cap = CAPTIONS[src]
        end
        left_w = 226
        tw = P.text(top, 14, y0 + 1, left_w, 26, PF.fit(PF::ROW, title.to_s, left_w - 70), c[:head], PF::ROW)
        P.pill(top, 14 + tw + 8, y0 + 7, _INTL("THIS SAVE"), c[:pill], c[:txt], false)
        lines = P.small_wrap(top, text, left_w)
        lines.first(2).each_with_index { |ln, n| P.small(top, 14, y0 + 28 + n * self.class::DESC_DY, left_w, self.class::DESC_DY, ln, c[:txt]) }
        P.text(top, 14, y0 + 68, left_w, 12, _INTL(cap), c[:acc], PF::TINY)
        ivb_bars(top, c, y0, lo, hi)
      end

      # Six Bars: the range shaded on each track, the sample's fill, a 31 in gold
      def ivb_bars(top, c, y0, lo, hi)
        vals = Reloaded::IVBoundariesRows.sample(lo, hi)
        bx0 = 302
        bx1 = 470
        kx = ->(v) { bx0 + (v * (bx1 - bx0) / 31.0).round }
        6.times do |i|
          ry = y0 + 9 + i * 12
          P.text(top, 250, ry, 50, 11, _INTL(STAT_NAMES[i]), c[:dim], PF::TINY)
          P.ui.rbox(top, bx0, ry + 3, bx1, ry + 8, 2, c[:dark])
          P.ui.rbox(top, kx[lo], ry + 3, kx[hi], ry + 8, 2, Reloaded::Palette.mix(c[:dark], c[:selb], 0.30))
          v = vals[i]
          gold = v == 31
          P.ui.rbox(top, bx0, ry + 3, [kx[v], bx0 + 4].max, ry + 8, 2, gold ? c[:gold] : c[:selb])
          P.text(top, 474, ry, 24, 11, v.to_s, gold ? c[:gold] : c[:txt], PF::TINY, 1)
        end
      end
    end

    Reloaded::SettingsScreen.prepend(Screen)
  end
end
