#==============================================================================
# Kanto Reloaded: Global Small Text
#==============================================================================
# From the Kanto Reloaded mod: the game's large text is drawn in the small
# font everywhere, so more fits on screen. Off by default.
#
#   pbSetSystemFont     every game screen, message box and menu, EBDX's
#                       battle UI, and Kanto Reloaded's own screens use it;
#                       it sets the small font of KIF's chosen Game's Font
#                       instead
#   KIF::PixelFont      KIF Beta's own pixel-font screens (KIF Settings,
#                       Battle Info): the two large fonts (system and narrow
#                       26) are drawn with the small 22 instead
#
# Both run every time text is drawn, so the hooks are prepended methods that
# check one cached flag.
#==============================================================================

module Reloaded
  module GlobalSmallText
    KEY = :"interface.global_small_text"
    PIXEL_LARGE = [[:system, 26], [:narrow, 26]].freeze
    PIXEL_SMALL = [:small, 22].freeze

    @on = false

    class << self
      attr_reader :on

      def on=(value)
        @on = value ? true : false
      end

      def setup
        Reloaded::Settings.register(KEY, :page => :interface, :priority => 10,
          :name => "Global Small Text", :type => :toggle, :default => false,
          :description => "Draw the game's large text in the small font everywhere, so more fits on screen.",
          :apply => proc { |value, _restoring| Reloaded::GlobalSmallText.on = value })
        self.on = Reloaded::Settings.get(KEY)
        Reloaded::Hooks.prepend(nil, ::Object, FontHook, :id => :global_small_text)
        if defined?(::KIF::PixelFont)
          Reloaded::Hooks.prepend(nil, ::KIF::PixelFont.singleton_class, PixelFontHook, :id => :global_small_text_pixel)
        end
      end

      # The pixel font to draw with in place of the one a KIF screen asked for.
      def pixel_font(font)
        return font unless @on && PIXEL_LARGE.include?(font)
        return PIXEL_SMALL
      end
    end

    module FontHook
      private

      def pbSetSystemFont(bitmap)
        return super unless Reloaded::GlobalSmallText.on
        pbSetSmallFont(bitmap)
      end
    end

    # KIF::PixelFont reads every font through data(font), and caches each
    # letter by font in glyph_bitmap; both get the swapped font, so turning
    # the setting on or off never mixes letters from the two sizes.
    module PixelFontHook
      def data(font)
        super(Reloaded::GlobalSmallText.pixel_font(font))
      end

      def glyph_bitmap(font, code, glyph, color)
        super(Reloaded::GlobalSmallText.pixel_font(font), code, glyph, color)
      end
    end
  end
end

Reloaded::GlobalSmallText.setup
