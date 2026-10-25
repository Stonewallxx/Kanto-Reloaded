#==============================================================================
# Kanto Reloaded: What's New
#==============================================================================
# Opened from the Load Screen's What's New row. His pick (2026-10-25,
# Design 2 Version Card, with his changes):
#
#   the left     the sources (Kanto Reloaded, KIF, every mod with notes; a
#                mod with its own icon shows it, ModIcons.rb), and under
#                them the Versions box: the source's versions by number,
#                a gold dot on one not read yet
#   the right    the version's card: UPDATE #1 (or VERSION 1.2.0) and its
#                date across the top in small blue capitals, its name, then
#                pills: the version (blue, a small v), Works On (green), a
#                hotfix (amber), NEW (gold) at the row's end; then its notes
#
# The notes are drawn as their Markdown has them (Reloaded::WhatsNew's
# blocks), whatever format the changelog is in: the version's top heading
# level is its sub-sections (## in his format, ### in Keep a Changelog),
# each in its colour (Added green, Fixed amber...), the next level down
# headers under them (his features), each level indented one step; dotted
# lines in the heading's colour join a sub-section to its headers (only
# between headers, his rule). Bullets and numbered lines at their depth,
# quotes with a bar, divider lines, paragraphs; bold drawn bold, italics
# pink, code amber. Links are plain words and web addresses never show (his
# call, for safety: Reloaded::WhatsNew leaves them out).
#
# Up / Down picks a version, Left / Right a source, A reads its notes (Up /
# Down then scroll them), B goes back. Closing it marks every version shown
# as read, so the Load Screen's NEW badge goes.
#==============================================================================

return unless defined?(Reloaded::SplitScreen)

module Reloaded
  class WhatsNewScreen
    include Reloaded::SplitScreen

    PANEL_Y1 = H - 30
    VERSIONS_Y0 = H - 134        # the Versions box
    VERSION_DY = 22
    NOTE_DY = 22
    STEP = 14                    # a heading level's indent
    BULLET_X = LIST_X0 + 16
    TEXT_X = LIST_X0 + 30
    TEXT_W = LIST_X1 - 14 - TEXT_X
    GUIDE_X = LIST_X0 + 13       # the first level's dotted line
    CARD_H = 82
    WN = Reloaded::WhatsNew
    # His sub-sections, each in its colour
    TONES = { "before you update" => [240, 200, 80], "added" => [120, 230, 150], "changed" => [130, 190, 250],
              "fixed" => [240, 170, 60], "removed" => [240, 100, 90], "supported mods" => [170, 110, 250],
              "known issues" => [240, 130, 160] }.freeze
    PILL_VERSION = [130, 190, 250].freeze
    PILL_KIF = [120, 230, 150].freeze
    PILL_HOTFIX = [240, 170, 60].freeze
    PILL_NEW = [240, 200, 80].freeze
    MONTHS = %w[January February March April May June July August September October November December].freeze

    def self.open
      return new.main
    end

    def initialize
      frame_init
      @sources = WN.sources
      @fresh = {}          # what was new when it opened (stays NEW while it's open)
      @sources.each { |s| s[:versions].each { |v| @fresh[[s[:name], v.version]] = true if WN.new?(s[:name], v.version) } }
      @section = 0
      @sel = 0
      @scroll = 0
      @side_scroll = 0
      @version_top = 0
      @focus = :list
      @lines = nil
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
      WN.mark_seen
      return nil
    ensure
      dispose_sprites
    end

    def refresh
      draw_screen if @sprite && !@sprite.disposed?
    end

    private

    def source
      return @sources[@section]
    end

    def versions
      return source ? source[:versions] : []
    end

    def version
      return versions[@sel]
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      pt = Reloaded::Pointer
      if pointer_hover
        if (i = pt.hit(@side_hits)) && i != @section
          pick_source(i)
        elsif (k = pt.hit(@version_hits)) && k != @sel
          pick_version(k)
        end
      end
      return close_screen if pt.right?
      if (dir = pt.wheel) != 0
        scroll(dir * NOTE_DY)
        return nil
      end
      if pt.left?
        handled, result = hint_click
        return result if handled
        if (i = pt.hit(@side_hits))
          pick_source(i)
        elsif (k = pt.hit(@version_hits))
          pick_version(k)
        elsif pt.inside?(LIST_X0, LIST_Y0, LIST_X1, PANEL_Y1)
          read
        end
        return nil
      end
      if Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
        return nil if @sources.length < 2
        pick_source((@section + (Input.trigger?(Input::RIGHT) ? 1 : -1)) % @sources.length)
      elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        if @focus == :notes
          scroll(dir * NOTE_DY)
        elsif !versions.empty?
          target = @sel + dir
          if target < 0 || target >= versions.length
            return nil unless fresh?(dir)
            target = dir < 0 ? versions.length - 1 : 0
          end
          pick_version(target)
        end
      elsif Input.trigger?(Input::USE)
        read
      elsif Input.trigger?(Input::BACK)
        return back
      end
      return nil
    end

    def pick_source(i)
      @section = i
      @sel = 0
      @version_top = 0
      @scroll = 0
      @focus = :list
      @lines = nil
      pbPlayCursorSE
      refresh
    end

    def pick_version(k)
      @sel = k
      @scroll = 0
      @focus = :list
      @lines = nil
      pbPlayCursorSE
      refresh
    end

    # A: Up / Down scroll the version's notes.
    def read
      return pbPlayBuzzerSE unless version
      pbPlayDecisionSE
      @focus = :notes
      refresh
      return nil
    end

    def back
      if @focus == :notes
        pbPlayCancelSE
        @focus = :list
        @scroll = 0
        refresh
        return nil
      end
      return close_screen
    end

    def close_screen
      pbPlayCloseMenuSE
      return :close
    end

    def scroll(dy)
      most = [content_height - (PANEL_Y1 - LIST_Y0 - 8), 0].max
      @scroll = [[@scroll + dy, 0].max, most].min
      @focus = :notes if dy > 0 && version
      refresh
    end

    #--------------------------------------------------------------------------
    # The notes as lines: [kind, data, height]
    #--------------------------------------------------------------------------
    def lines
      return @lines if @lines
      v = version
      return @lines = [] unless v
      out = [[:card, v, CARD_H + 6]]
      blocks = v.blocks && !v.blocks.empty? ? v.blocks : WN.blocks(Array(v.notes).map { |t, d| "#{"  " * d.to_i}- #{t}" })
      base = blocks.select { |b| b.kind == :head }.map(&:level).min
      path = []                                   # the headings above, outermost first: [level, title]
      blocks.each do |b|
        if b.kind == :head
          level = b.level - base                  # 0 the sub-sections, 1 the headers under them...
          path = path.take(level)
          title = WN.words(b)
          out << (level.zero? ? [:section, title, HEAD_H] : [:header, [title, level, path.first && path.first[1]], 22])
          path << [level, title]
          next
        end
        steps = path.length
        if b.kind == :rule
          out << [:rule, steps, 12]
          next
        end
        indent = steps * STEP + b.depth.to_i * 14
        width = TEXT_W - indent - (b.kind == :quote ? 10 : 0)
        rich_wrap(b.segments, width).each_with_index do |ln, k|
          out << [:text, [b, ln, k.zero?, indent], NOTE_DY - (k.zero? ? 0 : 3)]
        end
      end
      return @lines = with_guides(out)
    end

    # His rule: a dotted line only where it leads to another header: from a
    # heading down to the last header under it, a tick into each. Adds the
    # guides to each line: [[x, kind, colour title]] (kind :full, :tick, :end)
    def with_guides(out)
      out = out.map { |kind, data, h| [kind, data, h, []] }
      out.each_with_index do |(kind, data, _h, _g), i|
        level = kind == :section ? 0 : (kind == :header ? data[1] : nil)
        next unless level
        colour = kind == :section ? data : data[2]
        last = nil
        (i + 1...out.length).each do |j|
          k2, d2 = out[j]
          l2 = k2 == :section ? 0 : (k2 == :header ? d2[1] : nil)
          break if l2 && l2 <= level
          last = j if l2 == level + 1
        end
        next unless last
        x = GUIDE_X + level * STEP
        (i + 1..last).each do |j|
          k2, d2 = out[j]
          child = k2 == :header && d2[1] == level + 1
          out[j][3] << [x, child ? (j == last ? :end : :tick) : :full, colour]
        end
      end
      return out
    end

    def content_height
      return lines.sum { |l| l[2] }
    end

    #--------------------------------------------------------------------------
    # Markdown's words, drawn
    #--------------------------------------------------------------------------
    def space_w
      return @space_w ||= [PF.width(PF::TEXT, "a a") - PF.width(PF::TEXT, "aa"), 3].max
    end

    def word_w(word, style)
      return PF.width(PF::TEXT, word) + (style == :bold ? 1 : 0)
    end

    # [[text, style]] => lines of them within width (a word wider than the
    # line is cut to fit)
    def rich_wrap(segments, width)
      out = [[]]
      x = 0
      segments.each do |text, style|
        text.to_s.split(/(\s+)/).each do |word|
          next if word.empty?
          if word =~ /\A\s+\z/
            unless x.zero?
              out.last << [" ", style]
              x += space_w
            end
            next
          end
          word = PF.fit(PF::TEXT, word, width) if word_w(word, style) > width
          w = word_w(word, style)
          if x > 0 && x + w > width
            out.last.pop while out.last.last && out.last.last[0] == " "
            out << []
            x = 0
          end
          out.last << [word, style]
          x += w
        end
      end
      return out.reject(&:empty?)
    end

    def style_colour(c, style, plain)
      case style
      when :bold then return c[:strong]
      when :italic then return c[:pink]
      when :code then return c[:amber]
      end
      return plain || c[:txt]
    end

    def draw_rich(top, c, x, y, line, plain = nil)
      line.each do |text, style|
        if text == " "
          x += space_w
          next
        end
        col = style_colour(c, style, plain)
        w = P.text(top, x, y, 480, NOTE_DY, text, col)
        if style == :bold                          # bold: the words again, a pixel along
          P.text(top, x + 1, y, 480, NOTE_DY, text, col)
          w += 1
        end
        x += w
      end
    end

    def tone(c, title)
      rgb = TONES[title.to_s.strip.downcase]
      return rgb ? Reloaded::PartyPaint.ink(c, rgb) : c[:head]
    end

    #--------------------------------------------------------------------------
    # Painting
    #--------------------------------------------------------------------------
    def draw_screen
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      base.fill_rect(0, 0, W, H, c[:bg])
      @cursor_rect = nil
      paint_title_bar(base, c)
      P.text(top, 0, 2, W, 28, _INTL("What's New"), c[:title], PF::TITLE, 2)
      entries = @sources.map do |s|
        { :name => s[:name], :tile => s[:name] == WN::KR ? :ball : nil,
          :dot => s[:versions].any? { |v| @fresh[[s[:name], v.version]] } ? palette[:gold] : nil }
      end
      paint_sidebar(base, top, c, entries, @sources.empty? ? nil : @section, false)
      paint_versions_box(base, top, c)
      paint_right(base, top, c)
      paint_hints(base, c)
      place_cursor
    end

    def side_y1
      return VERSIONS_Y0 - 6
    end

    # The source's versions by number (his ask: no hotfix words), a gold dot
    # on one not read yet; the cursor on the chosen one
    def paint_versions_box(base, top, c)
      P.ui.rbox(base, 6, VERSIONS_Y0, SIDE_X1, PANEL_Y1, 6, c[:panel2], c[:line])
      P.text(top, 14, VERSIONS_Y0 + 6, 150, 13, _INTL("VERSIONS"), c[:head], PF::TINY)
      @version_hits = []
      fit = (PANEL_Y1 - VERSIONS_Y0 - 24) / VERSION_DY
      @version_top = @sel - fit + 1 if @sel >= @version_top + fit
      @version_top = @sel if @sel < @version_top
      versions[@version_top, fit].to_a.each_with_index do |v, k|
        i = k + @version_top
        y = VERSIONS_Y0 + 22 + k * VERSION_DY
        @version_hits << [i, 10, y - 1, SIDE_X1 - 4, y + VERSION_DY - 3]
        @cursor_rect = [10, y - 1, SIDE_X1 - 14, VERSION_DY - 1] if i == @sel && @focus == :list
        P.text(top, 16, y, SIDE_X1 - 40, VERSION_DY - 2, "v#{v.version}", i == @sel ? c[:strong] : c[:txt])
        P.ui.rbox(top, SIDE_X1 - 14, y + 7, SIDE_X1 - 10, y + 11, 2, palette[:gold]) if @fresh[[source[:name], v.version]]
      end
      paint_scrollbar(base, c, SIDE_X1 - 5, versions.length, fit, @version_top, PANEL_Y1 - 4) if versions.length > fit
    end

    def paint_right(base, top, c)
      P.ui.rbox(base, LIST_X0, LIST_Y0, LIST_X1, PANEL_Y1, 6, c[:panel])
      if @sources.empty?
        P.text(top, LIST_X0 + 12, LIST_Y0 + 8, 300, 22, _INTL("No notes yet."), c[:dim])
        return
      end
      all = lines
      y = LIST_Y0 + 4 - @scroll
      all.each do |kind, data, h, guides|
        if y >= LIST_Y0 && y + h <= PANEL_Y1 - 2
          guides.each { |x, how, title| paint_guide(base, tone(c, title), x, y, h, how) }
          case kind
          when :card then paint_card(base, top, c, data, y)
          when :section then P.heading(top, LIST_X0 + 10, LIST_X1 - 14, y + 4, data.to_s, tone(c, data), c[:line])
          when :header then paint_header(base, top, c, data, y)
          when :rule then base.fill_rect(LIST_X0 + 14 + data * STEP, y + 6, LIST_X1 - LIST_X0 - 30 - data * STEP, 1, c[:line])
          when :text then paint_text(base, top, c, data, y)
          end
        end
        y += h
      end
      total = content_height
      room = PANEL_Y1 - LIST_Y0 - 8
      return unless total > room
      track = PANEL_Y1 - LIST_Y0 - 12
      bar = [track * room / total, 12].max
      pos = (track - bar) * @scroll / [total - room, 1].max
      base.fill_rect(LIST_X1 - 5, LIST_Y0 + 6, 2, track, c[:line])
      base.fill_rect(LIST_X1 - 5, LIST_Y0 + 6 + pos, 2, bar, c[:dim])
    end

    # Dotted, on even pixels so the dots line up from row to row
    def paint_guide(base, col, x, y, h, how)
      stop = how == :end ? y + 11 : y + h
      (y...stop).each { |yy| base.fill_rect(x, yy, 1, 1, col) if yy.even? }
      return if how == :full
      (x..(x + STEP - 3)).each { |xx| base.fill_rect(xx, y + 10, 1, 1, col) if xx.even? }
    end

    # A header under a sub-section (his features): in its sub-section's
    # colour, brighter, underlined
    def paint_header(base, top, c, data, y)
      title, level, section = data
      col = Reloaded::Palette.mix(tone(c, section), c[:strong], 0.35)
      x = LIST_X0 + 12 + level * STEP
      w = P.text(top, x, y + 1, LIST_X1 - x - 14, 22, PF.fit(PF::TEXT, title, LIST_X1 - x - 14), col)
      base.fill_rect(x, y + 19, w, 1, Reloaded::Palette.mix(tone(c, section), c[:line], 0.5))
    end

    # A bullet's dot, a number, a quote's bar; then its words
    def paint_text(base, top, c, data, y)
      b, line, first, indent = data
      x = TEXT_X + indent
      plain = nil
      case b.kind
      when :bullet
        P.ui.rbox(top, BULLET_X + indent, y + 8, BULLET_X + indent + 4, y + 12, 2, b.depth.to_i.zero? ? palette[:blue] : c[:dim]) if first
      when :number
        P.text(top, BULLET_X + indent - 4, y, 20, NOTE_DY, "#{b.number}.", palette[:blue]) if first
        x += 4
      when :quote
        base.fill_rect(BULLET_X + 1 + indent, y + 2, 2, NOTE_DY - 2, Reloaded::Palette.mix(c[:line], c[:dim], 0.5))
        x = BULLET_X + 12 + indent
        plain = c[:dim]
      when :para
        x = BULLET_X + indent
      end
      draw_rich(top, c, x, y, line, plain)
    end

    # The version's card: UPDATE #1 and its date across the top, its name,
    # the pills (NEW at the row's end)
    def paint_card(base, top, c, v, y)
      x0 = LIST_X0 + 8
      x1 = LIST_X1 - 10
      Reloaded::PartyPaint.chamfer(base, x0, y + 4, x1, y + CARD_H - 6, 8, Reloaded::Palette.mix(c[:panel2], c[:bg], 0.3), c[:line])
      head = v.update ? _INTL("UPDATE #") + v.update.to_s : _INTL("VERSION {1}", v.version)
      P.text(top, x0 + 12, y + 8, 200, 13, head, c[:head], PF::TINY)
      P.text(top, x1 - 210, y + 8, 198, 13, long_date(v.date).upcase, c[:head], PF::TINY, 1) if v.date
      title = v.name || source[:name]
      P.text(top, x0 + 12, y + 18, x1 - x0 - 24, 30, PF.fit(PF::TITLE, title, x1 - x0 - 24), c[:strong], PF::TITLE)
      px = x0 + 12
      pills = [["v#{v.version}", PILL_VERSION]]
      pills << [v.works_on.to_s.upcase, PILL_KIF] if v.works_on
      pills << [v.hotfix.to_s.upcase, PILL_HOTFIX] if v.hotfix
      pills.each { |label, rgb| px += pill(top, c, px, y + 54, label, rgb, false) + 5 }
      pill(top, c, x1 - 12, y + 54, _INTL("NEW"), PILL_NEW) if @fresh[[source[:name], v.version]]
    end

    def pill(top, c, x, y, label, rgb, right = true)
      fill, col = Reloaded::PartyPaint.badge(c, rgb)
      return P.pill(top, x, y, label, fill, col, right)
    end

    # "October 25, 2026" from "2026-10-25" (anything else as it is)
    def long_date(date)
      m = date.to_s.match(/(\d{4})-(\d\d)-(\d\d)/)
      return date.to_s unless m
      return "#{_INTL(MONTHS[m[2].to_i - 1])} #{m[3].to_i}, #{m[1]}"
    end

    def hint_pairs
      back = button(:B)
      out = [[:ud, @focus == :notes ? _INTL("Scroll") : _INTL("Choose")]]
      out << [:lr, _INTL("Sources")] if @sources.length > 1
      out << [button(:C), _INTL("Read"), :read] if @focus == :list && version
      return out + [[back, @focus == :notes ? _INTL("Versions") : _INTL("Back"), :back]]
    end
  end
end
