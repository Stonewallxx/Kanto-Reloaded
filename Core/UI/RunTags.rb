# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Run Tags
#==============================================================================
# A save's run as a row of pills (his pick, Run Tag Pills): its mode
# (CLASSIC, REMIX, EXPERT, SPECIES, RANDOMIZED or LEGENDARY, plain like ALL
# SAVES), its difficulty as the card shows it (EASY green, NORMAL blue,
# HARD red) and DEBUG in KR Debug's purple. The Load Screen and the Save
# Manager draw them; Settings' Shown As draws the last two (Difficulty).
#
#   tags = Reloaded::RunTags.parts(colours, preview)   # [[label, fill, ink], ...]
#   Reloaded::RunTags.draw(bitmap, tags, x, y)         # left to right: the width
#   Reloaded::RunTags.width(tags)
#==============================================================================

return unless defined?(Reloaded::Pixel) && defined?(::KIF::PixelFont)

module Reloaded
  module RunTags
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    GAP = 4
    PURPLE = [150, 96, 220].freeze      # KR Debug's (Difficulty::DEBUG_COLOUR)
    LEVELS = [["EASY", :green], ["NORMAL", :blue], ["HARD", :red]].freeze
    MODES = ["Classic", "Remix", "Expert", "Species"].freeze   # what Randomized overrides

    class << self
      # KR Debug's purple, Vivid (the theme's lightness)
      def purple(c)
        return Reloaded::PartyPaint.ink(c, PURPLE)
      end

      # A pill's fill from its colour: a quarter of it on Dark, a pale tint
      # on Light (as the health pills)
      def fill(c, colour)
        return Reloaded::Palette.mix(c[:panel2], colour, 0.22) if c[:light]
        return Color.new(colour.red / 4, colour.green / 4, colour.blue / 4)
      end

      # The mode a preview's run is (Saves.mode_of); a randomized run is
      # Randomized, also in a preview kept from before it said so
      def mode_name(pv)
        mode = pv[:mode].to_s
        mode = "Randomized" if pv[:randomized] && (mode.empty? || MODES.include?(mode))
        return mode.empty? ? "Classic" : mode
      end

      # A save's tags from its preview: mode, difficulty, DEBUG (none for a
      # save that can't be read)
      def parts(c, pv, mode: true)
        return [] unless pv && pv.has_key?(:mode)
        out = []
        out << [_INTL(mode_name(pv)).upcase, c[:pill], c[:txt]] if mode
        level = pv[:difficulty_index]
        out << level_part(c, level.to_i) if level && level.to_i.between?(0, 2)
        out << debug_part(c) if pv[:debug] || pv[:test_of]
        return out
      end

      def level_part(c, index)
        label, tone = LEVELS[index]
        return [_INTL(label), fill(c, c[tone]), c[tone]]
      end

      def debug_part(c)
        colour = purple(c)
        return [_INTL("DEBUG"), fill(c, colour), colour]
      end

      def width(parts)
        return 0 if parts.empty?
        return parts.sum { |label, _, _| P.width(PF::TINY, label) + 12 } + GAP * (parts.length - 1)
      end

      def draw(b, parts, x, y)
        x0 = x
        parts.each_with_index do |(label, fill, ink), i|
          x += GAP if i > 0
          x += P.pill(b, x, y, label, fill, ink, false)
        end
        return x - x0
      end
    end
  end
end
