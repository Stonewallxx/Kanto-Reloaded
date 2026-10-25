#==============================================================================
# Kanto Reloaded: the title screen's logo
#==============================================================================
# PIF's Kanto title screen (GenOneStyle) shows Kanto Reloaded's logo in
# place of PIF's (his ask, 2026-10-25; his pick: PIF's Size): 256 wide, top
# centre, 4 pixels from the top (his ask: close to it), and it fades in
# from white as PIF's does. PIF's rainbow swirl that
# pulses behind its own logo is hidden (his call: no glow). PIF Hoenn's
# title keeps its own logo.
#
# The picture is Graphics/Titles/KantoReloadedLogo.png in the mod folder
# (Assets hands it to the game), trimmed to the art (his file's faint haze
# above it, left from taking its background out, is cut away). Title Screen Logo (Kanto Reloaded >
# Interface) Off shows PIF's.
#==============================================================================

module Reloaded
  module TitleLogo
    KEY = :"interface.title_logo"
    PICTURE = "Graphics/Titles/KantoReloadedLogo"
    TOP = 3                   # the art starts a pixel into the picture

    class << self
      def boot
        register_settings
        install
        return true
      end

      def register_settings
        Reloaded::Settings.register(KEY, :page => :interface, :priority => 97, :type => :toggle, :default => true,
          :name => "Title Screen Logo",
          :description => "Kanto Reloaded's logo on the title screen in place of PIF's. Off shows PIF's.")
      end

      def on?
        return Reloaded::Settings.get(KEY) ? true : false
      rescue StandardError
        return false
      end

      def install
        return true unless defined?(::GenOneStyle)
        Reloaded::Hooks.around(nil, ::GenOneStyle, :initialize, :id => :title_logo) do |original, *args|
          result = original.call(*args)
          Reloaded::TitleLogo.swap(original.receiver) if Reloaded::TitleLogo.on?
          result
        end
        return true
      end

      # The logo sprite gets Kanto Reloaded's picture, centred where PIF's
      # was; the swirl behind it is hidden
      def swap(screen)
        return if defined?(::Settings::HOENN) && ::Settings::HOENN
        sprites = screen.instance_variable_get(:@sprites)
        logo = sprites && sprites["logo"]
        return unless logo && !logo.disposed?
        pic = picture
        logo.bitmap = pic
        logo.x = (Graphics.width - pic.width) / 2
        logo.y = TOP
        back = sprites["logo_bg"]
        back.visible = false if back && !back.disposed?
      rescue StandardError => e
        Reloaded::Log.exception("The title screen's logo couldn't be shown", e, :interface)
      end

      # Through the game's own cache, as PIF loads its logo
      def picture
        return pbBitmap(PICTURE) if respond_to?(:pbBitmap, true)
        return Bitmap.new(PICTURE)
      end
    end
  end
end
