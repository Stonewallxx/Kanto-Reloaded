# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the startup checks' popups
#==============================================================================
# KIF Beta's version check and mod update check, drawn in Reloaded's look
# (Roadmap Designs topic startup-checks, his picks 2026-10-23). The checks
# are KIF's own and still run before the load screen; UpdateChecks.rb hooks
# them and calls these.
#
#   checking     Checking for Updates (design 1, Header Plate): a row for
#                KIF and one for Mods, each with a pill once it's done, or
#                what it's on and a gold bar
#   status       KIF's other waits (its own update download, installing
#                mods, Mods > Browse): the title, what it's on, a gold bar,
#                and B to cancel where KIF lets you
#   choose_kif   a new KIF (design 2, Choice List): the versions, Update Now,
#                What's New, Later, Skip This Version, and what the
#                highlighted one does
#   choose_mods  mod updates (design 2, Update All): each mod and its
#                versions, Update All, Open Updates, Later
#   notice /     KIF's messages and questions along the way, as Reloaded's
#   confirm      popups
#==============================================================================

return unless defined?(Reloaded::Dialogs) && defined?(::KIF::PixelFont)

module Reloaded
  module UpdateChecksScreen
    W = 512
    H = 384
    Z = 100_600               # the checking popup and KIF's waits; questions above them
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    D = Reloaded::Dialogs
    CONNECTING = %w[a an and as at but by for in nor of on or the to vs with].freeze
    KIF_CHOICES = ["Update Now", "What's New", "Later", "Skip This Version"].freeze
    MOD_BUTTONS = [[:all, "Update All"], [:open, "Open Updates"], [:later, "Later"]].freeze
    MAX_MODS = 6

    # A layer to draw on, above whatever is on screen (Dialogs draws on it
    # too: scene.overlay and scene.palette)
    class Layer
      attr_reader :overlay

      def initialize(z)
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = z
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = @overlay = Bitmap.new(W, H)
      end

      def palette
        return Reloaded::Palette.map_menu   # Theme Mode: Dark, or Light for Light and Frost
      end

      def disposed?
        return @sprite.nil? || @sprite.disposed?
      end

      def visible=(on)
        @sprite.visible = on unless disposed?
      end

      def dispose
        @overlay.dispose if @overlay && !@overlay.disposed?
        @sprite.dispose if @sprite && !@sprite.disposed?
        @viewport.dispose if @viewport && !@viewport.disposed?
        @sprite = @viewport = @overlay = nil
      end
    end

    class << self
      #------------------------------------------------------------------------
      # Checking for Updates
      #------------------------------------------------------------------------
      # rows: { :kif => row, :mods => row }; a row is [:done, pill, tone]
      # (tone :green, :gold or :dim), [:busy, what it's on, fraction or nil]
      # or [:wait, words]. Drawn and shown at once (the check that follows
      # may hold the game still).
      def checking(rows, hours = nil)
        @check = Layer.new(Z) if @check.nil? || @check.disposed?
        o = @check.overlay
        c = @check.palette
        o.clear
        o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))   # the load screen behind it
        w = 320
        h = hours ? 150 : 128
        x = (W - w) / 2
        y = (H - h) / 2 - 10
        D.send(:panel, o, c, x, y, w, h)
        D.send(:title_bar, o, c, x, y, w, _INTL("Checking for Updates"))
        check_row(o, c, x + 24, y + 46, w - 48, _INTL("KIF"), rows[:kif])
        o.fill_rect(x + 12, y + 74, w - 24, 1, c[:line])
        check_row(o, c, x + 24, y + 82, w - 48, _INTL("Mods"), rows[:mods])
        P.small(o, x, y + h - 26, w, 16, _INTL("Mods are checked every {1} hours.", hours), c[:dim], 2) if hours
      end

      def close_checking
        @check.dispose if @check
        @check = nil
      end

      def checking?
        return @check && !@check.disposed?
      end

      #------------------------------------------------------------------------
      # KIF's other waits
      #------------------------------------------------------------------------
      # (it takes the checking popup's place while it shows)
      def status(title, line, frac = nil, cancel = false)
        @check.visible = false if checking?
        @wait = Layer.new(Z + 10) if @wait.nil? || @wait.disposed?
        o = @wait.overlay
        c = @wait.palette
        o.clear
        o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 140)) unless checking?
        w = 340
        h = frac ? 104 : 86
        x = (W - w) / 2
        y = (H - h) / 2 - 10
        D.send(:panel, o, c, x, y, w, h)
        D.send(:title_bar, o, c, x, y, w, PF.fit(PF::TEXT, title_case(title), w - 24))
        P.small(o, x + 16, y + 44, w - 32, 18, line.to_s, c[:txt], 2)
        bar(o, c, x + 24, y + 72, w - 48, frac) if frac
        P.hints(o, o, c, [[button(:B), _INTL("Cancel")]], Reloaded::Prompts.style) if cancel
      end

      def hide_status
        @wait.dispose if @wait
        @wait = nil
        @check.visible = true if checking?
      end

      #------------------------------------------------------------------------
      # A new KIF: the Choice List. Returns 0 Update Now, 1 What's New,
      # 2 Later (B too), 3 Skip This Version.
      #------------------------------------------------------------------------
      def choose_kif(have, new, index = 0)
        descs = [_INTL("Downloads it now, then restarts the game."), _INTL("What changed in {1}.", new),
                 _INTL("Asks again the next time the game starts."),
                 _INTL("Won't ask about {1} again. Options > System > Check for Updates still finds it.", new)]
        hide_check = covering
        layer = Layer.new(Z + 20)
        sel = index
        hits = []
        draw = proc do
          o = layer.overlay
          c = layer.palette
          o.clear
          o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
          w = 320
          rh = 26
          h = 92 + KIF_CHOICES.length * rh + 60
          x = (W - w) / 2
          y = (H - P::HINT_H - h) / 2
          D.send(:panel, o, c, x, y, w, h)
          D.send(:title_bar, o, c, x, y, w, _INTL("KIF Update"))
          versions(o, c, x, y + 42, w, have, new)
          hits.clear
          KIF_CHOICES.each_with_index do |label, i|
            ry = y + 92 + i * rh
            hits << [i, x + 10, ry, x + w - 10, ry + rh - 2]
            D.send(:cursor_row, o, c, x + 10, ry, x + w - 10, ry + rh - 2) if i == sel
            P.text(o, x + 24, ry + 2, w - 48, 22, _INTL(label), i == sel ? c[:strong] : c[:txt], PF::TEXT)
          end
          o.fill_rect(x + 12, y + h - 60, w - 24, 1, c[:line])
          P.small_wrap(o, descs[sel], w - 32).first(2).each_with_index do |ln, k|
            P.small(o, x + 16, y + h - 54 + k * 16, w - 32, 16, ln, c[:dim])
          end
          P.hints(o, o, c, [[:ud, _INTL("Choose")], [button(:C), _INTL("Select")], [button(:B), _INTL("Later")]],
                  Reloaded::Prompts.style)
        end
        return run(layer, draw, KIF_CHOICES.length, 2, :vertical, hits, sel) { |i| sel = i } || 2
      ensure
        layer.dispose if layer
        uncover(hide_check)
      end

      #------------------------------------------------------------------------
      # Mod updates: rows [[name, installed version, new version], ...].
      # Returns :all, :open or :later (B too).
      #------------------------------------------------------------------------
      def choose_mods(rows)
        hide_check = covering
        layer = Layer.new(Z + 20)
        sel = 0
        hits = []
        shown = rows.first(rows.length > MAX_MODS ? MAX_MODS - 1 : MAX_MODS)
        more = rows.length - shown.length
        draw = proc do
          o = layer.overlay
          c = layer.palette
          o.clear
          o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
          w = 420
          rh = 26
          list_h = shown.length * rh + (more > 0 ? 20 : 0)
          h = 60 + list_h + 82
          x = (W - w) / 2
          y = (H - P::HINT_H - h) / 2
          D.send(:panel, o, c, x, y, w, h)
          D.send(:title_bar, o, c, x, y, w, _INTL("Mod Updates"))
          sub = rows.length == 1 ? _INTL("1 of your mods has an update.") : _INTL("{1} of your mods have updates.", rows.length)
          P.small(o, x, y + 38, w, 16, sub, c[:dim], 2)
          shown.each_with_index { |r, i| mod_row(o, c, x + 24, y + 60 + i * rh, w - 48, *r) }
          P.small(o, x, y + 60 + shown.length * rh, w, 16, _INTL("and {1} more", more), c[:dim], 2) if more > 0
          o.fill_rect(x + 12, y + h - 72, w - 24, 1, c[:line])
          bw = (w - 40 - 16) / 3
          hits.clear
          MOD_BUTTONS.each_with_index do |(_k, label), i|
            bx = x + 20 + i * (bw + 8)
            by = y + h - 62
            hits << [i, bx, by, bx + bw, by + 28]
            D.send(:button, o, c, bx, by, bx + bw, by + 28, i == sel)
            P.text(o, bx, by + 2, bw, 24, _INTL(label), i == sel ? c[:strong] : c[:txt], PF::TEXT, 2)
          end
          P.small(o, x, y + h - 28, w, 16, _INTL("Updated mods work from the next start."), c[:dim], 2)
          P.hints(o, o, c, [[:lr, _INTL("Choose")], [button(:C), _INTL("Select")], [button(:B), _INTL("Later")]],
                  Reloaded::Prompts.style)
        end
        i = run(layer, draw, MOD_BUTTONS.length, 2, :horizontal, hits, sel) { |k| sel = k }
        return MOD_BUTTONS[i || 2][0]
      ensure
        layer.dispose if layer
        uncover(hide_check)
      end

      #------------------------------------------------------------------------
      # KIF's messages and questions along the way
      #------------------------------------------------------------------------
      # A message: its lines kept (KIF's notes come three to a message)
      def notice(title, text)
        ask(title, text, [_INTL("OK")])
        return true
      end

      def confirm(title, text)
        return ask(title, text, [_INTL("Yes"), _INTL("No")]) == 0
      end

      # Title Case for KIF's sentence-case titles ("Reading the mod list"):
      # each word capitalised, the connecting words left as they are
      def title_case(text)
        words = text.to_s.split(" ")
        return words.each_with_index.map do |word, i|
          next word if i > 0 && CONNECTING.include?(word)
          next word if word =~ /\d/ || word != word.downcase
          word[0].upcase + word[1..-1]
        end.join(" ")
      end

      private

      def ask(title, text, buttons)
        hide_check = covering
        layer = Layer.new(Z + 30)
        sel = 0
        hits = []
        lines = text.to_s.split(/\r?\n/).flat_map { |ln| ln.strip.empty? ? [] : P.wrap(ln, 380 - 32) }.first(8)
        draw = proc do
          o = layer.overlay
          c = layer.palette
          o.clear
          o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
          w = 380
          h = 40 + lines.length * 18 + 52
          x = (W - w) / 2
          y = (H - P::HINT_H - h) / 2
          D.send(:panel, o, c, x, y, w, h)
          D.send(:title_bar, o, c, x, y, w, title)
          lines.each_with_index { |ln, i| P.text(o, x + 16, y + 40 + i * 18, w - 32, 18, ln, c[:txt], nil, 2) }
          widths = buttons.map { |label| [P.width(PF::TEXT, label) + 28, 80].max }
          total = widths.sum + 10 * (buttons.length - 1)
          bx = x + (w - total) / 2
          by = y + h - 38
          hits.clear
          buttons.each_with_index do |label, i|
            hits << [i, bx, by, bx + widths[i], by + 26]
            D.send(:button, o, c, bx, by, bx + widths[i], by + 26, i == sel)
            P.text(o, bx, by + 1, widths[i], 24, label, i == sel ? c[:strong] : c[:txt], PF::TEXT, 2)
            bx += widths[i] + 10
          end
          pairs = buttons.length > 1 ? [[:lr, _INTL("Choose")], [button(:C), _INTL("Select")]] : [[button(:C), _INTL("OK")]]
          P.hints(o, o, c, pairs, Reloaded::Prompts.style)
        end
        return run(layer, draw, buttons.length, buttons.length - 1, :horizontal, hits, sel) { |i| sel = i } || buttons.length - 1
      ensure
        layer.dispose if layer
        uncover(hide_check)
      end

      # A question hides the checking popup (and KIF's wait) behind it
      # while it's open: true when it did
      def covering
        hid = false
        [@check, @wait].each do |l|
          next unless l && !l.disposed?
          l.visible = false
          hid = true
        end
        return hid
      end

      def uncover(hid)
        return unless hid
        [@check, @wait].each { |l| l.visible = true if l && !l.disposed? }
      end

      # A popup's loop: Up/Down (vertical) or Left/Right (horizontal) move
      # through n choices from start, A picks, B gives back; the mouse picks
      # by hovering and clicking, a right click backs out. The block hears
      # each move.
      def run(layer, draw, n, back, dir, hits, start = 0)
        sel = start
        draw.call
        loop do
          Graphics.update
          Input.update
          pt = Reloaded::Pointer
          if pt.moved? && (i = pt.hit(hits)) && i != sel
            sel = i
            yield sel
            pbPlayCursorSE
            draw.call
          end
          if pt.left? && (i = pt.hit(hits))
            pbPlayDecisionSE
            return i
          elsif pt.right? || Input.trigger?(Input::BACK)
            pbPlayCancelSE
            return back
          elsif Input.trigger?(Input::USE)
            pbPlayDecisionSE
            return sel
          end
          step = 0
          if dir == :vertical
            step = 1 if Input.repeat?(Input::DOWN)
            step = -1 if Input.repeat?(Input::UP)
          else
            step = 1 if Input.repeat?(Input::RIGHT)
            step = -1 if Input.repeat?(Input::LEFT)
          end
          next if step == 0 || n < 2
          sel = (sel + step) % n
          yield sel
          pbPlayCursorSE
          draw.call
        end
      end

      # One check's row: its name, then a pill (done), what it's on and a bar
      # (busy), or a word (waiting)
      def check_row(o, c, x, y, w, name, row)
        P.text(o, x, y, 120, 22, name, c[:txt], PF::TEXT)
        kind, a, b = row
        case kind
        when :done
          tone = c[b] || c[:dim]
          fill = c[:light] ? Reloaded::Palette.mix(c[:panel2], tone, 0.22) : Reloaded::Palette.mix(c[:panel2], tone, 0.25)
          P.pill(o, x + w, y + 3, a.to_s, fill, tone, true)
        when :busy
          P.small(o, x, y, w, 20, a.to_s, c[:dim], 1)
          bar(o, c, x, y + 26, w, b) if b
        else
          P.small(o, x, y, w, 20, a.to_s, c[:dim], 1)
        end
      end

      def bar(o, c, x, y, w, frac, h = 6)
        frac = [[frac.to_f, 0].max, 1].min
        P.ui.rbox(o, x, y, x + w, y + h, h / 2, c[:dark], c[:line])
        fill = ((w - 2) * frac).to_i
        P.ui.rbox(o, x + 1, y + 1, x + 1 + fill, y + h - 1, (h - 2) / 2, c[:gold]) if fill > 1
      end

      # 1.1.0 (you have) to 1.2.0 (new)
      def versions(o, c, x, y, w, have, new)
        P.text(o, x, y, w / 2 - 20, 26, have.to_s, c[:dim], PF::ROW, 1)
        P.ui.tri(o, x + w / 2 - 4, y + 9, :r, c[:dim], 5)
        P.text(o, x + w / 2 + 14, y, w / 2 - 14, 26, new.to_s, c[:green], PF::ROW, 0)
        P.small(o, x, y + 26, w / 2 - 20, 14, _INTL("YOU HAVE"), c[:dim], 1)
        P.small(o, x + w / 2 + 14, y + 26, w / 2, 14, _INTL("NEW"), c[:dim], 0)
      end

      # A mod's name, then its versions: the one you have, to the new one
      def mod_row(o, c, x, y, w, name, from, to)
        to = to.to_s
        from = from.to_s
        tw = P.width(PF::TEXT, to)
        fw = P.width(PF::TEXT, from)
        P.text(o, x, y, w - tw - fw - 40, 22, PF.fit(PF::TEXT, name.to_s, w - tw - fw - 40), c[:txt], PF::TEXT)
        P.text(o, x + w - tw, y, tw + 2, 22, to, c[:green], PF::TEXT)
        P.ui.tri(o, x + w - tw - 14, y + 7, :r, c[:dim], 4)
        P.text(o, x + w - tw - 22 - fw, y, fw + 2, 22, from, c[:dim], PF::TEXT)
      end

      def button(sym)
        return Reloaded::Prompts.input(sym) || Reloaded::Prompts.name(sym)
      end
    end
  end
end
