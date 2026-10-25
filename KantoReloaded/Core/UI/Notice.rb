#==============================================================================
# Kanto Reloaded: a notice
#==============================================================================
# The notice look chosen for the Update Alert, for anything that needs a
# word before going on (After a Crash, Report Made): over whatever is on
# screen, a panel with a coloured edge and title, a line or two under the
# title, what to say, one coloured line, and two or three buttons.
#
#   i = Reloaded::Notice.show(:title => "Bug Report Made", :colour => Reloaded::Notice::GREEN,
#                             :sub => "Bug Reports: KR Bug Report 2026-10-19 14-05.zip",
#                             :sub2 => "214 KB, logs, settings, mods and the Save Check",
#                             :body => "Send it in Kanto Reloaded's Discord...",
#                             :line => "Thank you: It helps get the bug fixed.", :line_colour => Reloaded::Notice::DIM,
#                             :buttons => ["Open the Folder", "Done"], :cancel => 1)
#   # => the button picked (B picks :cancel)
#==============================================================================

return unless defined?(Reloaded::Pixel) && defined?(::KIF::PixelFont)

module Reloaded
  module Notice
    PF = ::KIF::PixelFont
    P = Reloaded::Pixel
    W = 512
    H = 384
    X0 = 48
    X1 = 464
    RED   = Color.new(240, 100, 90)
    GOLD  = Color.new(240, 200, 80)
    GREEN = Color.new(120, 230, 150)
    BLUE  = Color.new(130, 190, 250)
    DIM   = :dim

    class << self
      # Returns the button picked; B (or a right click) picks :cancel (the
      # last button when not given).
      def show(title:, colour:, buttons:, sub: nil, sub2: nil, body: nil, line: nil, line_colour: nil, choice: 0, cancel: nil)
        cancel ||= buttons.length - 1
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 100_500
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = Bitmap.new(W, H)
        @args = { :title => title, :colour => colour, :buttons => buttons, :sub => sub, :sub2 => sub2, :body => body,
                  :line => line, :line_colour => line_colour }
        redraw = true
        picked = nil
        loop do
          if redraw
            draw(choice)
            redraw = false
          end
          Graphics.update
          Input.update
          pt = Reloaded::Pointer
          if pt.moved? && (i = pt.hit(@hits)) && i != choice
            choice = i
            pbPlayCursorSE
            redraw = true
          end
          if pt.left? && (i = pt.hit(@hits))
            picked = i
          elsif pt.right? || Input.trigger?(Input::BACK)
            picked = cancel
          elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
            choice = (choice + (Input.trigger?(Input::RIGHT) ? 1 : -1)) % buttons.length
            pbPlayCursorSE
            redraw = true
          elsif Input.trigger?(Input::USE)
            picked = choice
          end
          break if picked
        end
        picked == cancel ? pbPlayCancelSE : pbPlayDecisionSE
        return picked
      ensure
        dispose
      end

      # For tests: what's drawn.
      attr_reader :sprite

      private

      def dispose
        @sprite.bitmap.dispose if @sprite && !@sprite.disposed? && @sprite.bitmap
        @sprite.dispose if @sprite && !@sprite.disposed?
        @viewport.dispose if @viewport && !@viewport.disposed?
        @sprite = @viewport = nil
      end

      # A caller's colour (RED, GOLD, GREEN, BLUE) in the notice's look: the
      # palette's deeper tone of it on Light, as it is on Dark
      def tone(colour, c)
        return colour unless c[:light] && colour.is_a?(Color)
        rgb = [colour.red.to_i, colour.green.to_i, colour.blue.to_i]
        key = Reloaded::Palette::TONES.find { |_k, v| v == rgb }
        return key ? c[key[0]] : colour
      end

      def draw(choice)
        c = Reloaded::Palette.map_menu   # Theme Mode: Dark, or Light for Light and Frost
        a = @args.merge(:colour => tone(@args[:colour], c))
        o = @sprite.bitmap
        o.clear
        o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 140))
        w = X1 - X0
        body = a[:body] ? P.wrap(a[:body].to_s, w - 28) : []
        line = a[:line] ? P.small_wrap(o, a[:line].to_s, w - 28) : []
        sub2 = a[:sub2] ? P.small_wrap(o, a[:sub2].to_s, w - 20).first(2) : []
        height = 44 + (a[:sub] ? 18 : 0) + sub2.length * 16 + 12 + body.length * 18 + (line.empty? ? 0 : 6 + line.length * 16) + 52
        y0 = [(H - P::HINT_H - height) / 2, 8].max
        y1 = y0 + height
        # the popups' Header Plate in the notice's colour: its edge, the
        # plate's tint, the title and the line under it
        Reloaded::Dialogs.send(:panel, o, c, X0, y0, w, height, a[:colour])
        Reloaded::Dialogs.send(:title_bar, o, c, X0, y0, w, a[:title].to_s, a[:colour], a[:colour], a[:colour])
        y = y0 + 40
        if a[:sub]
          P.small(o, X0 + 10, y, w - 20, 16, fit(o, a[:sub].to_s, w - 20), c[:txt], 2)
          y += 18
        end
        sub2.each do |ln|
          P.small(o, X0 + 10, y, w - 20, 16, ln, c[:dim], 2)
          y += 16
        end
        o.fill_rect(X0 + 12, y + 4, w - 24, 1, c[:line])
        y += 12
        body.each do |ln|
          P.text(o, X0 + 14, y, w - 28, 18, ln, c[:txt])
          y += 18
        end
        unless line.empty?
          y += 6
          # never Color == Symbol: the engine's Color#== raises for anything not a Color
          lc = a[:line_colour]
          colour = lc.nil? || lc.is_a?(Symbol) ? c[:dim] : tone(lc, c)
          line.each do |ln|
            P.small(o, X0 + 14, y, w - 28, 16, ln, colour)
            y += 16
          end
        end
        paint_buttons(o, c, a[:buttons], choice, y1 - 40)
        P.hints(o, o, c, [[:lr, _INTL("Choose")], [button(:C), _INTL("Select")]], Reloaded::Prompts.style)
      end

      # Buttons as wide as their words need, sharing the row.
      def paint_buttons(o, c, labels, choice, by)
        gap = 8
        room = X1 - X0 - 28 - gap * (labels.length - 1)
        need = labels.map { |l| P.width(PF::TEXT, l.to_s) + 24 }
        extra = [(room - need.sum) / labels.length, 0].max
        widths = need.map { |n| n + extra }
        widths = widths.map { |n| n * room / widths.sum } if widths.sum > room
        @hits = []
        bx = X0 + 14
        labels.each_with_index do |label, i|
          bw = widths[i]
          @hits << [i, bx, by, bx + bw, by + 28]
          Reloaded::Dialogs.send(:button, o, c, bx, by, bx + bw, by + 28, i == choice)
          P.text(o, bx, by + 2, bw, 24, PF.fit(PF::TEXT, label, bw - 8), i == choice ? (c[:strong] || c[:white]) : c[:txt], PF::TEXT, 2)
          bx += bw + gap
        end
      end

      def fit(b, text, w)
        P.small_font(b)
        return text if b.text_size(text).width <= w
        text = text[0...-1] while text.length > 1 && b.text_size(text + "...").width > w
        return text + "..."
      end

      def button(sym)
        return Reloaded::Prompts.input(sym) || Reloaded::Prompts.name(sym)
      end
    end
  end
end
