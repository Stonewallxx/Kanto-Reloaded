#==============================================================================
# Kanto Reloaded: KIF's Living title in Kanto Reloaded's look
#==============================================================================
# KIF 1.2's title screen (F-UI-12_LivingTitle: KIF's world scrolling behind
# a menu) with his picks (2026-10-25):
#
#   the logo     his, in place of PIF's (Title Screen Logo, as on PIF's own
#                title: 256 wide, 4 pixels from the top)
#   the menu     Floating Buttons: each choice a button of its own over the
#                world, the regular pulsing cursor on the chosen one (as the
#                Load Screen)
#   the versions PIF, KIF and KR on one line under the buttons, on a small
#                plate so they read over the world
#   Alphas       with Alpha Encounters installed (CharmingLoopy's; its
#                Pokemon#alpha?), now and then a wandering Pokemon is an
#                Alpha: half again as big, in a lighter red than the mod
#                gives one in battle (his pick: Big and Red, the tint more
#                see-through; then a little redder: three quarters). Ghostly Possession puts its possessed ones
#                there itself.
#
# KIF still runs the menu (Play, Options, Mods, Links, Quit, the Links
# list), its keys and its mouse, which picks from the buttons' places
# (@rects). Reloaded Title (Kanto Reloaded > Interface) Off: KIF's
# own menu, its version in the corner, no Alphas. PIF's Classic title is TitleLogo.rb's and
# TitleVersions.rb's.
#==============================================================================

module Reloaded
  module LivingTitle
    KEY = :"interface.title_menu"
    BUTTON_W = 176
    BUTTON_H = 24
    GAP = 6
    MENU_Y = 168
    PLATE_H = 20              # the versions' plate
    PLATE_GAP = 8             # between the buttons and it
    ALPHA_CHANCE = 10         # one wanderer in this many is an Alpha
    ALPHA_ZOOM = 1.5
    ALPHA_TONE = [75, -94, -94].freeze   # the Alpha mod's (100, -125, -125) at three quarters
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont if defined?(::KIF::PixelFont)

    class << self
      def boot
        register_settings
        install
        return true
      end

      def register_settings
        Reloaded::Settings.register(KEY, :page => :interface, :priority => 98, :type => :toggle, :default => true,
          :name => "Reloaded Title",
          :description => "KIF's title screen in Kanto Reloaded's look: Buttons with the pulsing cursor, the versions under them, and Alphas among the Pokémon with Alpha Encounters. Off shows KIF's own.")
      end

      def on?
        return Reloaded::Settings.get(KEY) ? true : false
      rescue StandardError
        return false
      end

      def install
        return true unless defined?(::KifLivingTitle) && defined?(::KIF::PixelFont)
        h = Reloaded::Hooks
        h.around(nil, ::KifLivingTitle, :setup_ui, :id => :living_title_ui) do |original, *args|
          result = original.call(*args)
          Reloaded::LivingTitle.setup(original.receiver)
          result
        end
        h.around(nil, ::KifLivingTitle, :draw_menu, :id => :living_title_menu) do |original, *args|
          next original.call(*args) unless Reloaded::LivingTitle.on?
          Reloaded::LivingTitle.draw(original.receiver)
        end
        h.around(nil, ::KifLivingTitle, :update, :id => :living_title_pulse) do |original, *args|
          result = original.call(*args)
          Reloaded::LivingTitle.pulse(original.receiver)
          result
        end
        h.around(nil, ::KifLivingTitle, :dress, :id => :living_title_alphas) do |original, *args|
          result = original.call(*args)
          Reloaded::LivingTitle.dress(args[0])
          result
        end
        h.around(nil, ::KifLivingTitle, :dispose, :id => :living_title_close) do |original, *args|
          Reloaded::LivingTitle.close(original.receiver)
          original.call(*args)
        end
        return true
      end

      # After KIF made the logo and the menu: his logo in PIF's place, the
      # cursor, the menu drawn again with it
      def setup(screen)
        sprites = screen.instance_variable_get(:@sprites)
        return unless sprites
        swap_logo(sprites) if Reloaded::TitleLogo.on?
        return unless on?
        cursor = Sprite.new(screen.instance_variable_get(:@viewport))
        cursor.z = 899                       # under the menu's words (the menu is 900)
        cursor.visible = false
        sprites["kr_cursor"] = cursor
        screen.send(:draw_menu)
      rescue StandardError => e
        Reloaded::Log.exception("The title screen couldn't take Kanto Reloaded's look", e, :interface)
      end

      # KIF draws PIF's logo in two parts at 0.78: the swirl behind (logo0)
      # and the words (logo1)
      def swap_logo(sprites)
        logo = sprites["logo1"]
        return unless logo && !logo.disposed?
        pic = Reloaded::TitleLogo.picture
        logo.bitmap = pic
        logo.zoom_x = logo.zoom_y = 1.0
        logo.x = (Graphics.width - pic.width) / 2
        logo.y = Reloaded::TitleLogo::TOP
        back = sprites["logo0"]
        back.visible = false if back && !back.disposed?
      end

      # The menu (his pick: Floating Buttons), in place of KIF's draw_menu
      def draw(screen)
        b = screen.instance_variable_get(:@bitmaps)[:menu]
        return unless b && !b.disposed?
        b.clear
        c = Reloaded::Palette.map_menu
        list = screen.entries
        index = screen.index
        w = [BUTTON_W, list.map { |_id, label| P.width(PF::ROW, label.to_s) + 40 }.max.to_i].max
        bottom = b.height - P::HINT_H - PLATE_GAP - PLATE_H - 8
        step = [BUTTON_H + GAP, (bottom - MENU_Y) / [list.length, 1].max].min
        # 24 tall, 6 apart (his pick's spacing); a long Links list closes up
        gap = step >= BUTTON_H + GAP ? GAP : [step / 6, 2].max
        h = step - gap
        x0 = (b.width - w) / 2
        rects = []
        list.each_with_index do |(_id, label), i|
          y = MENU_Y + i * step
          # the chosen one's plate is the cursor, under its words
          P.ui.rbox(b, x0, y, x0 + w, y + h, 5, see(c[:panel2], 230), c[:line]) unless i == index && screen.sprites["kr_cursor"]
          P.text(b, x0, y, w, h, PF.fit(PF::ROW, label.to_s, w - 16), i == index ? c[:title] : c[:opt], PF::ROW, 2)
          rects << Rect.new(x0, y, w, h)
        end
        screen.instance_variable_set(:@rects, rects)
        place_cursor(screen, rects[index])
        versions(b, c, MENU_Y + list.length * step - gap + PLATE_GAP)
        pairs = [[:ud, _INTL("Choose")], [button(:C), _INTL("Select")]]
        pairs << [button(:B), _INTL("Back")] if screen.menu == :links
        P.hints(b, b, c, pairs, Reloaded::Prompts.style)
        return nil
      end

      # PIF, KIF and KR on one line, centred under the buttons (his pick):
      # white, green and red on Dark; the theme's words, green and red on
      # Light
      def versions(b, c, y)
        parts = Reloaded::TitleVersions.parts(:kanto)
        if c[:light]
          tones = [c[:txt], Reloaded::PartyPaint.ink(c, [110, 232, 130]), Reloaded::PartyPaint.ink(c, [255, 104, 96])]
          parts = parts.each_with_index.map { |(words, colour), i| [words, tones[i] || colour] }
        end
        gap = 14
        widths = parts.map { |words, _c| P.width(PF::TEXT, words) }
        total = widths.sum + gap * (parts.length - 1)
        x = (b.width - total) / 2
        P.ui.rbox(b, x - 10, y, x + total + 10, y + PLATE_H, 5, see(c[:panel2], 210), see(c[:line], 210))
        parts.each_with_index do |(words, colour), i|
          P.text(b, x, y, widths[i] + 2, PLATE_H, words, colour, PF::TEXT)
          x += widths[i] + gap
        end
      end

      # A wanderer KIF just dressed (a species picked, its sheet set): now
      # and then an Alpha, with Alpha Encounters (walkers only: not the two
      # that fuse, the diggers or the flyers). The size and red stay until
      # it's dressed again.
      def dress(actor)
        s = actor.sprite
        alpha = on? && alphas? && actor.kind == :walk && rand(ALPHA_CHANCE) == 0
        actor.instance_variable_set(:@kr_alpha, alpha)
        zoom = alpha ? ALPHA_ZOOM : 1.0
        s.zoom_x = s.zoom_y = zoom
        actor.shadow.zoom_x = actor.shadow.zoom_y = zoom
        s.tone = alpha ? Tone.new(*ALPHA_TONE) : Tone.new(0, 0, 0)
      rescue StandardError => e
        Reloaded::Log.warning_once("A title screen Alpha couldn't be dressed: #{e.message}", :interface)
      end

      # Alpha Encounters is installed: its Pokemon have alpha?
      def alphas?
        return defined?(::Pokemon) && ::Pokemon.method_defined?(:alpha?) ? true : false
      end

      # The regular cursor on the chosen button, pulsing as everywhere
      def place_cursor(screen, rect)
        sprites = screen.instance_variable_get(:@sprites)
        cursor = sprites && sprites["kr_cursor"]
        return unless cursor && !cursor.disposed?
        unless rect
          cursor.visible = false
          return
        end
        size = [rect.width + 6, rect.height + 4]
        if screen.instance_variable_get(:@kr_cursor_size) != size
          old = cursor.bitmap
          cursor.bitmap = P.cursor_bitmap(*size)
          old.dispose if old && !old.disposed?
          screen.instance_variable_set(:@kr_cursor_size, size)
        end
        cursor.x = rect.x - 3
        cursor.y = rect.y - 2
        cursor.visible = true
      end

      def pulse(screen)
        sprites = screen.instance_variable_get(:@sprites)
        cursor = sprites && sprites["kr_cursor"]
        return unless cursor && !cursor.disposed? && cursor.visible
        cursor.opacity = P.cursor_opacity(Graphics.frame_count)
      rescue StandardError
        nil
      end

      # KIF disposes the sprites; the cursor's picture is Kanto Reloaded's
      def close(screen)
        sprites = screen.instance_variable_get(:@sprites)
        cursor = sprites && sprites["kr_cursor"]
        return unless cursor && !cursor.disposed?
        cursor.bitmap.dispose if cursor.bitmap && !cursor.bitmap.disposed?
      rescue StandardError
        nil
      end

      def button(sym)
        return Reloaded::Prompts.input(sym) || Reloaded::Prompts.name(sym)
      end

      def see(colour, alpha)
        return Color.new(colour.red, colour.green, colour.blue, alpha)
      end
    end
  end
end
