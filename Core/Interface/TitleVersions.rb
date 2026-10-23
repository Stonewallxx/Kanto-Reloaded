#==============================================================================
# Kanto Reloaded: the title screen's versions
#==============================================================================
# The title screen's "v.6.8.2" (top right) gives way to the three versions,
# one to a line in small text, in the same corner (his ask, 2026-10-21):
#
#                                                       PIF 6.8.2 (white)
#                                                       KIF 1.0.3 (green)
#                                                        KR 2.0.0 (red)
#
# (KIF was blue first: it blended into the title's blue. They were above
# PRESS ANY KEY first, on one line.)
#
# On PIF's Kanto title screen (GenOneStyle) and its Hoenn one
# (HoennIntroScreen, with PIF Hoenn's version). Hooked: the game draws its
# line, which is cleared and replaced.
#==============================================================================

module Reloaded
  module TitleVersions
    TOP = 4                   # the first line's top
    RIGHT = 8                 # from the screen's right edge
    LINE = 15                 # a line's height
    WHITE = Color.new(248, 248, 248)
    GREEN = Color.new(110, 232, 130)
    RED = Color.new(255, 104, 96)
    SCREENS = [["GenOneStyle", :kanto], ["HoennIntroScreen", :hoenn]].freeze

    class << self
      def boot
        install
        return true
      end

      def install
        SCREENS.each do |klass, kind|
          next unless ::Object.const_defined?(klass)
          Reloaded::Hooks.around(nil, klass, :showUIElements, :id => :"title_versions_#{kind}") do |original, *args|
            result = original.call(*args)
            Reloaded::TitleVersions.show(original.receiver, kind)
            result
          end
          Reloaded::Hooks.around(nil, klass, :dispose, :id => :"title_versions_#{kind}_close") do |original, *args|
            Reloaded::TitleVersions.hide(original.receiver)
            original.call(*args)
          end
        end
        return true
      end

      # [[words, colour]]: PIF's version (PIF Hoenn's on its screen), KIF
      # Beta's and Kanto Reloaded's
      def parts(kind = :kanto)
        pif = if kind == :hoenn && defined?(::Settings::HOENN_VERSION_NUMBER) then ::Settings::HOENN_VERSION_NUMBER
              elsif defined?(::Settings::GAME_VERSION_NUMBER) then ::Settings::GAME_VERSION_NUMBER
              end
        out = []
        out << ["PIF #{pif}", WHITE] if pif
        out << ["KIF #{::KIF::PORT_VERSION}", GREEN] if defined?(::KIF::PORT_VERSION)
        out << ["KR #{Reloaded.version}", RED]
        return out
      end

      # The game's own line cleared, these in its place
      def show(screen, kind)
        ::Kernel.pbClearText if ::Kernel.respond_to?(:pbClearText)
        hide(screen)
        s = Sprite.new(screen.instance_variable_get(:@viewport))
        s.bitmap = Bitmap.new(Graphics.width, TOP + LINE * 3 + 4)
        s.y = 0
        s.z = 99_999
        draw(s.bitmap, parts(kind))
        screen.instance_variable_set(:@kr_versions, s)
      rescue StandardError => e
        Reloaded::Log.exception("The title screen's versions couldn't be shown", e, :interface)
      end

      def hide(screen)
        s = screen.instance_variable_get(:@kr_versions)
        return unless s
        s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
        s.dispose unless s.disposed?
        screen.instance_variable_set(:@kr_versions, nil)
      end

      # One to a line, right-aligned in the top right corner (no shadow or
      # outline: his call)
      def draw(b, parts)
        p = Reloaded::Pixel
        p.small_font(b)
        parts.each_with_index do |(text, colour), i|
          p.small(b, 0, TOP + i * LINE, b.width - RIGHT, LINE, text, colour, 1)
        end
      end
    end
  end
end
