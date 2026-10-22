#==============================================================================
# Kanto Reloaded (Dev): the Hook Check results
#==============================================================================
# The chosen design (List and Detail): every problem in one list on the left
# with its result in colour (Broken, Missing, Changed, Shared); the right
# panel shows the selected one's target, file and feature, and what changed:
# why it broke, or the diff and what to check. Y (the game's X button) runs
# the check again, A opens the report. Opened from the Update Alert's Open
# Results, or KIF Settings > Kanto Reloaded > Developer Tools > Hook Check.
#==============================================================================

# Needs Kanto Reloaded's pixel UI (KIF's pixel fonts).
return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont)

module Reloaded
  module HookCheck
    class Screen
      include Reloaded::Frame

      PF = ::KIF::PixelFont
      LIST_X0 = 6
      LIST_X1 = 250
      DETAIL_X0 = 256
      PANEL_Y0 = 36
      PANEL_Y1 = H - 30
      ROW_Y0 = 42
      ROW_DY = 28
      TEXT_X = DETAIL_X0 + 10
      TEXT_W = W - 6 - 10 - TEXT_X
      LINE_DY = 15
      PROGRESS_W = 320
      DONE_WAIT = 90           # frames "Checked Again" stays (a button closes it sooner)
      RED   = Color.new(240, 100, 90)
      AMBER = Color.new(240, 170, 60)
      GOLD  = Color.new(240, 200, 70)
      BLUE  = Color.new(130, 190, 250)
      GREEN = Color.new(120, 230, 150)
      LABELS = { :broken => "Broken", :missing => "Missing", :changed => "Changed", :shared => "Shared" }.freeze
      COLORS = { :broken => RED, :missing => RED, :changed => AMBER, :shared => BLUE, :ok => GREEN }.freeze

      def self.open(run = nil)
        run ||= Reloaded::HookCheck.last || Reloaded::HookCheck.check(:manual)
        return new(run).main
      end

      def initialize(run)
        frame_init
        @run = run
        @sel = 0
        @top = 0
      end

      def main
        open_sprites
        refresh
        loop do
          Graphics.update
          Input.update
          update_frame
          break if handle_input == :close
        end
        return nil
      ensure
        dispose_sprites
      end

      def refresh
        draw_screen if @sprite && !@sprite.disposed?
      end

      private

      def rows
        return @run.problems
      end

      def current
        return rows[@sel]
      end

      #------------------------------------------------------------------------
      # Input
      #------------------------------------------------------------------------
      def handle_input
        pt = Reloaded::Pointer
        if pointer_hover && (i = pt.hit(@row_hits)) && i != @sel
          @sel = i
          pbPlayCursorSE
          refresh
        end
        return close_screen if pt.right?
        if (dir = pt.wheel) != 0
          scroll(dir)
          return nil
        end
        if pt.left?
          handled, result = hint_click
          return result if handled
          return run_again if pt.inside?(*right_box)
          if (i = pt.hit(@row_hits))
            @sel = i
            refresh
          end
          return nil
        end
        n = rows.length
        if (Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)) && n > 0
          dir = Input.repeat?(Input::DOWN) ? 1 : -1
          target = @sel + dir
          if target < 0 || target >= n
            return nil unless fresh?(dir)
            target = dir < 0 ? n - 1 : 0
          end
          @sel = target
          pbPlayCursorSE
          refresh
        elsif Input.trigger?(Input::USE)
          open_report
        elsif Input.trigger?(Input::X)            # a controller's Y
          run_again
        elsif Input.trigger?(Input::BACK)
          return close_screen
        end
        return nil
      end

      def close_screen
        pbPlayCloseMenuSE
        return :close
      end

      # A: the report, in the program that opens .md files.
      def open_report
        pbPlayDecisionSE
        @run.report ||= Report.write(@run)
        path = @run.report
        return nil unless path && File.file?(path)
        system("explorer \"#{File.expand_path(path).tr("/", "\\")}\"")
        return nil
      rescue StandardError => e
        Reloaded::Log.exception("The Hook Check report couldn't be opened", e, :dev)
        return nil
      end

      # Y: the check runs again, a bar showing it go (a frame per step, so
      # it is seen even though it's quick), then what it found, until a
      # button or DONE_WAIT frames.
      def run_again
        pbPlayDecisionSE
        @run = Reloaded::HookCheck.check(:manual) do |step, steps, label|
          paint_progress(step, steps, label)
          Graphics.update
        end
        @sel = [[@sel, rows.length - 1].min, 0].max
        refresh
        paint_progress(1, 1, nil, true)
        pbPlayDecisionSE
        DONE_WAIT.times do
          Graphics.update
          Input.update
          update_frame
          pt = Reloaded::Pointer
          break if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK) || Input.trigger?(Input::X) || pt.left? || pt.right?
        end
        overlay.clear
        return nil
      end

      # The Run Again popup: the bar and what the check is on, or (done)
      # what it found.
      def paint_progress(step, steps, label, done = false)
        c = palette
        o = overlay
        o.clear
        o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
        pw = PROGRESS_W
        if done
          parts = [[@run.count(:broken), _INTL("Broken"), RED], [@run.count(:changed), _INTL("Changed"), AMBER],
                   [@run.count(:shared), _INTL("Shared"), BLUE], [@run.count(:missing), _INTL("Missing"), RED]]
          segs = []
          parts.each_with_index do |(n, word, colr), i|
            segs << ["#{n} #{word}", n > 0 ? colr : c[:dim], true]
            segs << ["   ", c[:dim]] if i < parts.length - 1
          end
          report = _INTL("Report: {1}", Report.short(@run.report))
          # as wide as the counts and the report need, so neither wraps
          P.small_font(o)
          counts_w = segs.sum { |s| o.text_size(s[0]).width + (s[2] ? s[0].length : 0) }
          pw = [pw, counts_w + 32, o.text_size(report).width + 32].max.clamp(PROGRESS_W, W - 16)
        end
        x = (W - pw) / 2
        y = 136
        h = done ? 112 : 92
        P.ui.rbox(o, x, y, x + pw, y + h, 6, c[:panel2], c[:line])
        P.text(o, x, y + 6, pw, 26, done ? _INTL("Checked Again") : _INTL("Checking Hooks"), c[:title], PF::ROW, 2)
        o.fill_rect(x + 10, y + 34, pw - 20, 1, c[:line])
        bx0 = x + 20
        bx1 = x + pw - 20
        by = y + 46
        P.ui.rbox(o, bx0, by, bx1, by + 10, 4, c[:dark], c[:line])
        fill = (bx1 - bx0 - 2) * step / [steps, 1].max
        P.ui.rbox(o, bx0 + 1, by + 1, bx0 + 1 + fill, by + 9, 3, done ? GREEN : c[:selb]) if fill >= 6
        if done
          P.small_rich(o, x + 10, y + 64, pw - 20, 18, segs)
          P.small(o, x, y + 86, pw, 16, report, c[:dim], 2)
        else
          text = fit_small(o, _INTL("{1} of {2}: {3}", step, steps, label.to_s), pw - 24)
          P.small(o, x, y + 64, pw, 16, text, c[:dim], 2)
        end
      end

      # text cut to fit w in the small font, "..." at its end.
      def fit_small(b, text, w)
        P.small_font(b)
        return text if b.text_size(text).width <= w
        text = text[0...-1] while text.length > 1 && b.text_size(text + "...").width > w
        return text + "..."
      end

      def scroll(dir)
        fit = visible_rows
        return if rows.length <= fit
        @top = [[@top + dir, 0].max, rows.length - fit].min
        @sel = [[@sel, @top].max, @top + fit - 1].min
        refresh
      end

      def visible_rows
        return (PANEL_Y1 - 4 - ROW_Y0) / ROW_DY
      end

      #------------------------------------------------------------------------
      # Painting
      #------------------------------------------------------------------------
      def draw_screen
        c = palette
        base = @sprite.bitmap
        top = @top_sprite.bitmap
        base.clear
        top.clear
        base.fill_rect(0, 0, W, H, c[:bg])
        @cursor_rect = nil
        paint_title_bar(base, c)
        P.small(top, 8, 9, 150, 16, _INTL("KIF Beta {1}", @run.version), c[:dim])
        P.text(top, 0, 2, W, 28, _INTL("Hook Check"), c[:title], PF::TITLE, 2)
        title_box(base, top, c, W - 8 - BUTTON_W, _INTL("Run Again"))
        title_keys(top, c, nil, button(:X))
        paint_list(base, top, c)
        paint_detail(base, top, c)
        paint_hints(base, c)
        place_cursor
      end

      def paint_list(base, top, c)
        P.ui.rbox(base, LIST_X0, PANEL_Y0, LIST_X1, PANEL_Y1, 6, c[:panel])
        @row_hits = []
        list = rows
        if list.empty?
          n = @run.hooks.length
          P.text(top, LIST_X0, 60, LIST_X1 - LIST_X0, 24, _INTL("All {1} Hooks OK", n), GREEN, PF::ROW, 2)
          P.small_wrap(top, _INTL("Takeovers, locks and settings are OK too."), LIST_X1 - LIST_X0 - 24).each_with_index do |ln, k|
            P.small(top, LIST_X0, 90 + k * 17, LIST_X1 - LIST_X0, 16, ln, c[:txt], 2)
          end
          return
        end
        fit = visible_rows
        @top = @sel if @sel < @top
        @top = @sel - fit + 1 if @sel >= @top + fit
        list[@top, fit].to_a.each_with_index do |r, k|
          i = @top + k
          y = ROW_Y0 + k * ROW_DY
          @row_hits << [i, LIST_X0 + 3, y, LIST_X1 - 3, y + ROW_DY - 3]
          @cursor_rect = [LIST_X0 + 3, y, LIST_X1 - LIST_X0 - 6, ROW_DY - 2] if i == @sel
          colr = COLORS[r.kind]
          P.ui.rbox(top, LIST_X0 + 10, y + 9, LIST_X0 + 16, y + 15, 3, colr)
          P.text(top, LIST_X0 + 22, y + 2, 150, 22, PF.fit(PF::TEXT, r.id, 150), c[:opt], PF::TEXT)
          P.small(top, LIST_X1 - 70, y + 5, 62, 16, _INTL(LABELS[r.kind]), colr, 2)
        end
        return unless list.length > fit
        track = PANEL_Y1 - PANEL_Y0 - 12
        bar = [track * fit / list.length, 12].max
        pos = (track - bar) * @top / [list.length - fit, 1].max
        base.fill_rect(LIST_X1 - 5, PANEL_Y0 + 6, 2, track, c[:line])
        base.fill_rect(LIST_X1 - 5, PANEL_Y0 + 6 + pos, 2, bar, c[:dim])
      end

      def paint_detail(base, top, c)
        P.ui.rbox(base, DETAIL_X0, PANEL_Y0, W - 6, PANEL_Y1, 6, c[:panel2], c[:line])
        r = current
        return paint_summary(base, top, c) unless r
        colr = COLORS[r.kind]
        badge = _INTL(LABELS[r.kind]).upcase
        bw = P.pill(top, W - 14, PANEL_Y0 + 10, badge, Color.new(colr.red / 4, colr.green / 4, colr.blue / 4), colr)
        P.text(top, TEXT_X, PANEL_Y0 + 4, W - 14 - bw - 6 - TEXT_X, 24, PF.fit(PF::ROW, r.id, W - 14 - bw - 6 - TEXT_X), c[:head], PF::ROW)
        @y = PANEL_Y0 + 34
        if r.hook?
          field(top, c, _INTL("Target"), split_target(r.target))
          field(top, c, _INTL("File"), split_path(r.where || _INTL("Unknown")))
          field(top, c, _INTL("Feature"), [feature_name(r.feature)]) if r.kind == :broken
        else
          field(top, c, _INTL("Kind"), [_INTL(r.need)])
          field(top, c, _INTL("Used By"), split_path(r.where.to_s))
        end
        rule(base, c)
        case r.kind
        when :changed then paint_changed(top, c, r)
        when :shared then paint_others(top, c, r)
        else paragraph(top, [r.what, r.effect].compact.join(" "), c[:txt])
        end
      end

      def paint_summary(base, top, c)
        P.text(top, TEXT_X, PANEL_Y0 + 4, TEXT_W, 24, _INTL("KIF Beta {1}", @run.version), c[:head], PF::ROW)
        @y = PANEL_Y0 + 34
        field(top, c, _INTL("Checked"), [@run.previous ? _INTL("Against {1}", @run.previous) : _INTL("First check")])
        field(top, c, _INTL("Report"), split_path(Report.short(@run.report)))
        rule(base, c)
        paragraph(top, _INTL("Every hook, takeover, lock and setting Kanto Reloaded relies on is there and unchanged."), c[:txt])
      end

      def paint_changed(top, c, r)
        if r.diff
          P.small(top, TEXT_X, @y, TEXT_W, 14, _INTL("What Changed (+{1} -{2})", r.added, r.removed).upcase, c[:dim])
          @y += 18
          r.diff.each do |kind, line|
            next if kind == :same
            sign = kind == :add ? "+" : "-"         # the game's fonts have no minus sign
            colr = kind == :add ? GREEN : RED
            wrapped = P.small_wrap(top, line.to_s.strip, TEXT_W - 12)
            wrapped = [""] if wrapped.empty?
            wrapped.each_with_index do |ln, k|
              return more(top, c) if @y + LINE_DY > PANEL_Y1 - 22
              P.small(top, TEXT_X, @y, 12, 14, sign, colr) if k == 0
              P.small(top, TEXT_X + 12 + (k > 0 ? 8 : 0), @y, TEXT_W - 12, 16, ln, colr)
              @y += LINE_DY + 2
            end
          end
          @y += 6
        end
        paragraph(top, r.what, c[:txt]) if r.what
        paragraph(top, r.check, GOLD) if r.check
      end

      def paint_others(top, c, r)
        P.small(top, TEXT_X, @y, TEXT_W, 14, _INTL("On This Method, in Order").upcase, c[:dim])
        @y += 18
        Array(r.others).each_with_index do |o, i|
          text = "#{i + 1}  #{o[:who]} (#{o[:how]})"
          paragraph(top, text, o[:ours] ? c[:dim] : c[:txt], 0)
        end
      end

      # A label in small capitals and its lines.
      def field(top, c, label, lines)
        P.small(top, TEXT_X, @y, TEXT_W, 14, label.upcase, c[:dim])
        @y += 14
        lines.each do |ln|
          P.small(top, TEXT_X, @y, TEXT_W, 16, ln, c[:txt])
          @y += LINE_DY
        end
        @y += 4
      end

      def rule(base, c)
        @y += 2
        base.fill_rect(TEXT_X, @y, TEXT_W, 1, c[:line])
        @y += 6
      end

      def paragraph(top, text, color, gap = 6)
        return if text.to_s.empty?
        P.small_wrap(top, text.to_s.delete("`"), TEXT_W).each do |ln|
          return more(top, palette) if @y + LINE_DY > PANEL_Y1 - 22
          P.small(top, TEXT_X, @y, TEXT_W, 16, ln, color)
          @y += LINE_DY + 2
        end
        @y += gap
      end

      def more(top, c)
        P.small(top, TEXT_X, PANEL_Y1 - 20, TEXT_W, 16, _INTL("More in the report (A)"), c[:dim])
        @y = PANEL_Y1
        return nil
      end

      # "KIF::SettingsScreen" / ".pif_items" when it doesn't fit on one line.
      def split_target(target)
        t = target.to_s
        return [t] if P.width(PF::TEXT, t) <= TEXT_W * 9 / 10
        i = [t.rindex("#"), t.rindex(".")].compact.max
        return i ? [t[0...i], t[i..-1]] : [t]
      end

      def split_path(path)
        t = path.to_s
        return [t] if t.length <= 30
        i = t.rindex("/")
        return i ? [t[0..i], t[(i + 1)..-1]] : [t]
      end

      def feature_name(feature)
        return _INTL("Core hook") unless feature
        f = defined?(Reloaded::Features) ? Reloaded::Features.definition(feature) : nil
        return f ? f[:name].to_s : feature.to_s
      end

      def hint_pairs
        return [[:ud, _INTL("Select")], [button(:C), _INTL("Open Report"), :open_report],
                [button(:X), _INTL("Run Again"), :run_again], [button(:B), _INTL("Back"), :close_screen]]
      end
    end
  end
end
