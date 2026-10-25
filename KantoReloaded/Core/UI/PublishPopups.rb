#==============================================================================
# Kanto Reloaded: Publish a Mod's popups
#==============================================================================
# His picks (2026-10-25), as drawn over Design 2:
#
#   Description, Reviewer Notes   T2: a box of a few lines to type in
#   Tags                          A3 Two Columns: the 12 catalog tags (Mod
#                                 Manager 2.0's) with tick boxes; a tag a
#                                 mod.json had that isn't one of them stays
#   Pull Request Preview          B1 As the Reviewer Sees It: KIF's own
#                                 pull request text, drawn (Up / Down scroll)
#   Publish?                      C1 Ask Card: KIF's question word for word,
#                                 the update, the folder and the catalog
#   After Publishing              D1 Result Popups: the window is open
#                                 (green), run it yourself (amber), it didn't
#                                 open (red), each with KIF's words
#==============================================================================

return unless defined?(Reloaded::PublishScreen)

module Reloaded
  class PublishScreen
    TAGS_COL = 6
    TAG_ROW = 22

    private

    #--------------------------------------------------------------------------
    # T2: the box Description and Reviewer Notes are typed in
    #--------------------------------------------------------------------------
    def paint_box(c)
      b = overlay
      w = 440
      lines_shown = 4
      h = 40 + 18 + lines_shown * 18 + 14 + 10
      x = (W - w) / 2
      y = (H - h) / 2
      DL.frame(b, c, x, y, w, h, @box_title)
      note = @box_title == _INTL("Description") ? _INTL("One or two lines.") : _INTL("Optional.")
      P.small(b, x, y + 38, w, 18, note, c[:dim], 2)
      bx0 = x + 14
      by0 = y + 58
      P.ui.rbox(b, bx0, by0, x + w - 14, by0 + lines_shown * 18 + 8, 5, c[:dark], c[:selb])
      lines = P.small_wrap(b, @entry.text, w - 44)
      lines = [""] if lines.empty?
      shown = lines.last(lines_shown)                 # the end stays in view
      shown.each_with_index { |ln, k| P.small(b, bx0 + 8, by0 + 4 + k * 18, w - 44, 18, ln, c[:txt]) }
      if @entry.text.empty?
        P.small(b, bx0 + 14, by0 + 4, w - 50, 18, @entry.label, c[:dim])
      end
      @probe = Bitmap.new(8, 8) if @probe.nil? || @probe.disposed?
      lw = shown.last.to_s.empty? ? 0 : P.small(@probe, 0, 0, w, 18, shown.last, c[:txt])
      b.fill_rect(bx0 + 10 + lw, by0 + 7 + (shown.length - 1) * 18, 2, 13, c[:selb]) if @entry.caret_visible?
    end

    #--------------------------------------------------------------------------
    # A3: the tags, two columns of tick boxes
    #--------------------------------------------------------------------------
    def pick_tags
      list = ::KIF::ModPublish::TAGS
      sel = Array(mod.json["tags"]).map(&:to_s)
      before = sel.dup
      i = 0
      done = list.length                              # the Done button
      @popup_open = true
      redraw = true
      loop do
        if redraw
          paint_tags(overlay, palette, list, sel, i)
          redraw = false
        end
        Graphics.update
        Input.update
        update_frame
        pt = Reloaded::Pointer
        if pt.moved? && (k = pt.hit(@tag_hits)) && k != i
          i = k
          pbPlayCursorSE
          redraw = true
        end
        if pt.left? && (k = pt.hit(@tag_hits))
          break if k == done
          i = k
          toggle_tag(sel, list[k])
          redraw = true
        elsif pt.right? || Input.trigger?(Input::BACK)
          pbPlayCancelSE
          break
        elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
          i = (i + (Input.repeat?(Input::DOWN) ? 1 : -1)) % (done + 1)
          pbPlayCursorSE
          redraw = true
        elsif (Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)) && i < done
          i = (i + TAGS_COL) % (TAGS_COL * 2)
          i = done - 1 if i >= done
          pbPlayCursorSE
          redraw = true
        elsif Input.trigger?(Input::USE)
          if i == done
            pbPlayDecisionSE
            break
          end
          toggle_tag(sel, list[i])
          redraw = true
        end
      end
      @popup_open = false
      overlay.clear
      # as KIF: the tags in the list's order, any it doesn't know first
      sel = sel.sort_by { |g| list.index(g) || -1 }
      if sel != before
        mod.json["tags"] = sel
        changed!
      else
        refresh
      end
    end

    def toggle_tag(sel, tag)
      sel.include?(tag) ? sel.delete(tag) : sel << tag
      pbPlayDecisionSE
    end

    def paint_tags(b, c, list, sel, i)
      w = 330
      h = 40 + 18 + TAGS_COL * TAG_ROW + 50
      x = (W - w) / 2
      y = (H - h) / 2
      DL.frame(b, c, x, y, w, h, _INTL("Tags"))
      P.small(b, x, y + 38, w, 18, _INTL("Choose to switch one on or off."), c[:dim], 2)
      cw = (w - 30) / 2
      @tag_hits = []
      list.each_with_index do |t, k|
        cx = x + 12 + (k / TAGS_COL) * (cw + 6)
        ry = y + 60 + (k % TAGS_COL) * TAG_ROW
        on = sel.include?(t)
        @tag_hits << [k, cx, ry, cx + cw, ry + TAG_ROW - 1]
        DL.send(:cursor_row, b, c, cx, ry, cx + cw, ry + TAG_ROW - 1) if k == i
        P.ui.rbox(b, cx + 8, ry + 5, cx + 20, ry + 17, 3, on ? tone(c, BLUE) : c[:dark], on ? nil : c[:line])
        tick_mark(b, cx + 10, ry + 7, c[:dark]) if on
        P.text(b, cx + 28, ry - 1, cw - 32, TAG_ROW, _INTL(t), k == i ? c[:strong] : c[:txt])
      end
      DL.button_row(b, c, x, w, y + h - 36, [_INTL("Done")], i == list.length ? 0 : -1)
      bw = [P.width(PF::TEXT, _INTL("Done")) + 28, 72].max
      @tag_hits << [list.length, x + (w - bw) / 2, y + h - 36, x + (w + bw) / 2, y + h - 12]
    end

    def tick_mark(b, x, y, col)
      [[0, 3], [1, 4], [2, 5], [3, 4], [4, 3], [5, 2], [6, 1]].each { |dx, dy| b.fill_rect(x + dx, y + dy, 2, 2, col) }
    end

    #--------------------------------------------------------------------------
    # B1: the pull request as the reviewer sees it
    #--------------------------------------------------------------------------
    def show_preview
      title, body = PB.request(mod, ans, results[1])
      lines = preview_lines(body)
      scroll = 0
      @popup_open = true
      redraw = true
      loop do
        if redraw
          @preview_max = paint_preview(overlay, palette, title, lines, scroll)
          redraw = false
        end
        Graphics.update
        Input.update
        update_frame
        pt = Reloaded::Pointer
        step = Input.repeat?(Input::DOWN) ? 16 : (Input.repeat?(Input::UP) ? -16 : 0)
        step = pt.wheel * 32 if pt.wheel != 0
        if step != 0
          to = [[scroll + step, 0].max, @preview_max].min
          if to != scroll
            scroll = to
            redraw = true
          end
        elsif pt.right? || pt.left? || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
          pbPlayCancelSE
          break
        end
      end
      @popup_open = false
      overlay.clear
      refresh
    end

    # KIF's body as lines to draw: [:head, text], [:box, ticked, text],
    # [:field, label, text], [:bullet, text], [:text, text], [:foot, text],
    # [:gap]
    def preview_lines(body)
      wn = Reloaded::WhatsNew
      out = []
      body.to_s.each_line do |raw|
        line = raw.rstrip
        if line.empty? then out << [:gap]
        elsif (m = line.match(/\A##\s+(.*)\z/)) then out << [:head, m[1]]
        elsif (m = line.match(/\A-\s+\[([ xX])\]\s+(.*)\z/)) then out << [:box, m[1] != " ", plain(m[2])]
        elsif (m = line.match(/\A-\s+\*\*([^*]+?)\*\*\s*(.*)\z/)) then out << [:field, m[1], plain(m[2])]
        elsif (m = line.match(/\A-\s+(.*)\z/)) then out << [:bullet, plain(m[1])]
        elsif line =~ /\A_.*_\z/ then out << [:foot, plain(line)]
        else out << [:text, plain(line)]
        end
      end
      out.pop while out.last == [:gap]
      return out
    end

    def plain(text)
      return Reloaded::WhatsNew.inline(text).map(&:first).join
    end

    # The popup; returns how far it can scroll
    def paint_preview(b, c, title, lines, scroll)
      x = 16
      y = 14
      w = W - 32
      h = H - 28
      DL.frame(b, c, x, y, w, h, _INTL("Pull Request Preview"))
      lx = x + 16
      lw = w - 44
      top_y = y + 40
      bottom_y = y + h - 24
      probe = Bitmap.new(8, 8)
      items = [[:title, title]] + lines
      yy = top_y + 2 - scroll
      items.each do |kind, a, bb|
        wrapped = case kind
                  when :box then P.small_wrap(probe, bb, lw - 18)
                  when :field then P.small_wrap(probe, "#{a} #{bb}", lw - 14)
                  when :bullet, :text, :foot then P.small_wrap(probe, a, lw - 14)
                  else []
                  end
        hh = case kind
             when :title then 24
             when :head then 20
             when :gap then 6
             else wrapped.length * 16 + 2
             end
        if yy >= top_y && yy + hh <= bottom_y
          case kind
          when :title then P.text(b, lx, yy, lw, 24, PF.fit(PF::TEXT, a, lw), c[:strong])
          when :head then P.heading(b, lx, x + w - 24, yy + 5, a, tone(c, BLUE), c[:line])
          when :field
            P.ui.rbox(b, lx + 4, yy + 7, lx + 7, yy + 10, 1, c[:dim])
            lab_w = P.small(b, lx + 14, yy, lw, 16, a, c[:strong])
            first = wrapped[0].to_s.sub(/\A#{Regexp.escape(a)}\s*/, "")
            P.small(b, lx + 14 + lab_w + 4, yy, lw - lab_w, 16, first, c[:txt])
            wrapped.drop(1).each_with_index { |ln, k| P.small(b, lx + 14, yy + (k + 1) * 16, lw - 14, 16, ln, c[:txt]) }
          when :box
            P.ui.rbox(b, lx + 2, yy + 2, lx + 13, yy + 13, 3, a ? tone(c, GREEN) : c[:dark], a ? nil : c[:line])
            tick_mark(b, lx + 4, yy + 4, c[:dark]) if a
            wrapped.each_with_index { |ln, k| P.small(b, lx + 18, yy + k * 16, lw - 18, 16, ln, a ? c[:txt] : c[:dim]) }
          when :bullet
            P.ui.rbox(b, lx + 4, yy + 7, lx + 7, yy + 10, 1, tone(c, AMBER))
            wrapped.each_with_index { |ln, k| P.small(b, lx + 14, yy + k * 16, lw - 14, 16, ln, tone(c, AMBER)) }
          when :text then wrapped.each_with_index { |ln, k| P.small(b, lx, yy + k * 16, lw, 16, ln, c[:txt]) }
          when :foot then wrapped.each_with_index { |ln, k| P.small(b, lx, yy + k * 16, lw, 16, ln, c[:dim]) }
          end
        end
        yy += hh
      end
      probe.dispose
      total = yy + scroll - (top_y + 2)
      room = bottom_y - top_y
      max = [total - room, 0].max
      if max > 0
        b.fill_rect(x + w - 10, top_y + 4, 2, room - 8, c[:line])
        bar = [(room - 8) * room / [total, 1].max, 12].max
        b.fill_rect(x + w - 10, top_y + 4 + (room - 8 - bar) * scroll / max, 2, bar, c[:dim])
      end
      P.small(b, x, y + h - 22, w, 18, max > 0 ? _INTL("Up / Down: Scroll, B: Back") : _INTL("B: Back"), c[:dim], 2)
      return max
    end

    #--------------------------------------------------------------------------
    # C1, then D1: Publish
    #--------------------------------------------------------------------------
    def publish
      return pbPlayBuzzerSE unless checked?
      unless results[0].empty?                        # problems: the check
        pbPlayBuzzerSE
        return go_step(2)
      end
      unless ans["own"]                               # KIF stops on No
        pbPlayBuzzerSE
        @sel[3] = 0
        return refresh
      end
      m = mod
      choice = DL.drawn(self, 2, 0) { |b, c, ch| paint_confirm(b, c, m, ch) }
      return refresh unless choice == 0
      result = PB.publish(m, ans)
      case result
      when :started
        result_popup(GREEN, _INTL("Publish Window Open"),
                     _INTL("The publish window is open. Follow its steps; it may ask to install Git or the GitHub CLI first."),
                     [_INTL("Catalog contributors publish straight away: Players get the mod at their next catalog check."),
                      _INTL("Everyone else gets a pull request, which opens in the browser; it is checked and reviewed before the mod goes live.")],
                     [_INTL("OK")])
      when :manual
        go = result_popup(AMBER, _INTL("Run It Yourself"),
                          _INTL("Open a terminal and run the command saved in Cache/Publish/command.txt (in the game folder)."),
                          [], [_INTL("Open Folder"), _INTL("OK")])
        explore(File.join(::KIF::ModPublish.root, "Cache", "Publish")) if go == 0
      else
        go = result_popup(RED, _INTL("The Window Didn't Open"),
                          _INTL("The publish window couldn't be opened (see Logs/KIF_log.txt). The script is Tools/publish_mod in the game folder."),
                          [], [_INTL("Open Folder"), _INTL("OK")])
        explore(File.join(::KIF::ModPublish.root, ::KIF::ModPublish::TOOLS)) if go == 0
      end
      refresh
    end

    def explore(path)
      system("explorer \"#{path.to_s.tr("/", "\\")}\"")
    rescue StandardError
      pbPlayBuzzerSE
    end

    # C1: KIF's question word for word, then the update, the folder and
    # where it goes, each on a line
    def paint_confirm(b, c, m, choice)
      w = DL::TEXT_W + 20
      text = _INTL("A window opens that signs you in to GitHub in your browser (the first time) and uploads the mod. The game stays open.")
      lines = P.wrap(text, w - 32)
      segs = []
      if m.old
        segs << [[_INTL("Update: "), c[:dim]], [m.old.version, c[:txt]], [" > ", c[:dim]], [m.version, tone(c, GREEN)]]
      else
        segs << [[_INTL("New Mod: "), c[:dim]], [m.version, tone(c, BLUE)]]
      end
      segs << [[_INTL("Folder: "), c[:dim]], [PB.folder_of(m), c[:txt]]]
      segs << [[_INTL("To: "), c[:dim]], [::KIF::ModPublish::REPO, c[:txt]]]
      h = 40 + lines.length * 18 + segs.length * 18 + 8 + 48
      x = (W - w) / 2
      y = (H - h) / 2
      DL.frame(b, c, x, y, w, h, _INTL("Publish {1} {2}?", m.name, m.version))
      lines.each_with_index { |ln, i| P.text(b, x + 16, y + 40 + i * 18, w - 32, 18, ln, c[:txt], nil, 2) }
      ly = y + 46 + lines.length * 18
      probe = Bitmap.new(8, 8)
      segs.each_with_index do |seg, k|
        tw = seg.sum { |t, _col| P.small(probe, 0, 0, w, 18, t, c[:txt]) }
        lx = x + (w - tw) / 2
        seg.each { |t, col| lx += P.small(b, lx, ly + k * 18, w, 18, t, col) }
      end
      probe.dispose
      DL.button_row(b, c, x, w, y + h - 36, [_INTL("Publish"), _INTL("Cancel")], choice)
    end

    # D1: what happened, in its colour (the plate's edge and title)
    def result_popup(rgb, title, text, extra, buttons)
      return DL.drawn(self, buttons.length, 0) do |b, c, choice|
        tint = tone(c, rgb)
        w = DL::TEXT_W + 20
        probe = Bitmap.new(8, 8)
        lines = P.wrap(text, w - 32)
        ex = extra.map { |t| P.small_wrap(probe, t, w - 46) }
        probe.dispose
        h = 40 + lines.length * 18 + ex.sum { |l| l.length * 16 + 6 } + 8 + 48
        x = (W - w) / 2
        y = (H - h) / 2
        DL.send(:dim, b)
        DL.send(:panel, b, c, x, y, w, h, tint)
        DL.send(:title_bar, b, c, x, y, w, title, tint)
        lines.each_with_index { |ln, i| P.text(b, x + 16, y + 40 + i * 18, w - 32, 18, ln, c[:txt], nil, 2) }
        yy = y + 48 + lines.length * 18
        ex.each do |ls|
          P.ui.rbox(b, x + 20, yy + 6, x + 24, yy + 10, 2, tint)
          ls.each_with_index { |ln, k| P.small(b, x + 30, yy + k * 16, w - 46, 16, ln, c[:txt]) }
          yy += ls.length * 16 + 6
        end
        DL.button_row(b, c, x, w, y + h - 36, buttons, choice)
      end
    end
  end
end
