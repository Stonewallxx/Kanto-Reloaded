#==============================================================================
# Kanto Reloaded (Dev): the Hook Check's Update Alert
#==============================================================================
# The chosen design: when KIF Beta's version changed since the last check, a
# notice over the load screen with the counts (Broken, Changed Upstream,
# Shared Methods, Settings Missing, OK), where the report is, and Open
# Results or Close (was Later; his call, 2026-10-21). When everything is
# OK, a short green notice that A closes.
#==============================================================================

# Needs the results screen (and so the pixel UI).
return unless defined?(Reloaded::HookCheck::Screen)

module Reloaded
  module HookCheck
    module Alert
      PF = ::KIF::PixelFont
      P = Reloaded::Pixel
      W = 512
      H = 384
      X0 = 96
      X1 = 416
      RED   = Screen::RED
      GOLD  = Screen::GOLD
      BLUE  = Screen::BLUE
      GREEN = Screen::GREEN

      class << self
        # Shows the notice over whatever is on screen; Open Results opens the
        # results screen.
        def show(run)
          @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
          @viewport.z = 100_500
          @sprite = Sprite.new(@viewport)
          @sprite.bitmap = Bitmap.new(W, H)
          choice = 0
          redraw = true
          open = false
          loop do
            if redraw
              draw(run, choice)
              redraw = false
            end
            Graphics.update
            Input.update
            pt = Reloaded::Pointer
            if run.all_ok?
              break if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK) || pt.left? || pt.right?
              next
            end
            if pt.moved? && (i = pt.hit(@hits)) && i != choice
              choice = i
              pbPlayCursorSE
              redraw = true
            end
            if pt.left? && (i = pt.hit(@hits))
              open = i == 0
              break
            elsif pt.right? || Input.trigger?(Input::BACK)
              break
            elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
              choice = 1 - choice
              pbPlayCursorSE
              redraw = true
            elsif Input.trigger?(Input::USE)
              open = choice == 0
              break
            end
          end
          open ? pbPlayDecisionSE : pbPlayCancelSE
          dispose
          Screen.open(run) if open
        ensure
          dispose
        end

        private

        def dispose
          @sprite.bitmap.dispose if @sprite && !@sprite.disposed? && @sprite.bitmap
          @sprite.dispose if @sprite && !@sprite.disposed?
          @viewport.dispose if @viewport && !@viewport.disposed?
          @sprite = @viewport = nil
        end

        def draw(run, choice)
          c = Reloaded::Palette.map_menu   # Theme Mode: Dark, or Light for Light and Frost
          o = @sprite.bitmap
          o.clear
          o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 140))
          ok = run.all_ok?
          y0 = ok ? 110 : 64
          y1 = ok ? 268 : 318
          edge = shade(border(run), c)   # the popups' Header Plate, in the finding's colour
          Reloaded::Dialogs.send(:panel, o, c, X0, y0, X1 - X0, y1 - y0, edge)
          title = run.first ? _INTL("Hook Check") : _INTL("KIF Updated")
          sub = run.first ? _INTL("First check on {1}", run.version) : _INTL("{1} to {2}", run.previous, run.version)
          Reloaded::Dialogs.send(:title_bar, o, c, X0, y0, X1 - X0, title, edge, edge, edge)
          P.small(o, X0, y0 + 38, X1 - X0, 16, sub, c[:dim], 2)
          o.fill_rect(X0 + 12, y0 + 56, X1 - X0 - 24, 1, c[:line])
          report = _INTL("Report: {1}", Report.short(run.report))
          @hits = []
          if ok
            P.text(o, X0, y0 + 62, X1 - X0, 24, _INTL("All {1} Hooks OK", run.hooks.length), shade(GREEN, c), PF::ROW, 2)
            P.small(o, X0, y0 + 90, X1 - X0, 16, _INTL("Takeovers, locks and settings are OK too."), c[:txt], 2)
            P.small(o, X0, y0 + 110, X1 - X0, 16, report, c[:dim], 2)
            hints(o, c, [[button(:C), _INTL("OK")]])
            return
          end
          rows = [[_INTL("Broken"), run.count(:broken), RED], [_INTL("Changed Upstream"), run.count(:changed), GOLD],
                  [_INTL("Shared Methods"), run.count(:shared), BLUE], [_INTL("Settings Missing"), run.count(:missing), RED],
                  [_INTL("OK"), run.ok_hooks, GREEN]]
          x = X0 + 24
          w = X1 - X0 - 48
          rows.each_with_index do |(label, n, colr), i|
            y = y0 + 60 + i * 22
            P.ui.rbox(o, x, y + 6, x + 8, y + 14, 4, shade(colr, c))
            P.text(o, x + 16, y, w - 60, 22, label, c[:txt], PF::TEXT)
            P.text(o, x + w - 44, y, 44, 22, n.to_s, n > 0 && !colr.equal?(GREEN) ? shade(colr, c) : c[:dim], PF::TEXT, 2)
          end
          o.fill_rect(X0 + 12, y0 + 176, X1 - X0 - 24, 1, c[:line])
          P.small(o, X0, y0 + 184, X1 - X0, 16, report, c[:dim], 2)
          [[_INTL("Open Results"), X0 + 20], [_INTL("Close"), X1 - 150]].each_with_index do |(label, bx), i|
            by = y0 + 210
            @hits << [i, bx, by, bx + 130, by + 28]
            if i == choice
              Reloaded::Dialogs.send(:button, o, c, bx, by, bx + 130, by + 28, true)
              P.text(o, bx, by + 2, 130, 24, label, c[:strong], PF::TEXT, 2)
            else
              Reloaded::Dialogs.send(:button, o, c, bx, by, bx + 130, by + 28, false)
              P.text(o, bx, by + 2, 130, 24, label, c[:txt], PF::TEXT, 2)
            end
          end
          hints(o, c, [[:lr, _INTL("Choose")], [button(:C), _INTL("Select")], [button(:B), _INTL("Close")]])
        end

        # A finding colour (one of the constants) on Light: the palette's deeper
        # tone of it
        def shade(colour, c)
          return colour unless c[:light]
          { RED => :red, GOLD => :gold, BLUE => :blue, GREEN => :green }.each { |k, v| return c[v] if k.equal?(colour) }
          return colour
        end

        # The most serious finding's colour: red for something broken or
        # missing, gold for a method KIF changed, blue when other code on
        # the same methods is all there is to see, green when all is OK.
        def border(run)
          return RED if run.count(:broken) > 0 || run.count(:missing) > 0
          return GOLD if run.count(:changed) > 0
          return BLUE if run.count(:shared) > 0
          return GREEN
        end
        public :border

        def hints(o, c, pairs)
          P.hints(o, o, c, pairs, Reloaded::Prompts.style)
        end

        def button(sym)
          return Reloaded::Prompts.input(sym) || Reloaded::Prompts.name(sym)
        end
      end
    end
  end
end
