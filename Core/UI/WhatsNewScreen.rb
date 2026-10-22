#==============================================================================
# Kanto Reloaded: What's New
#==============================================================================
# Opened from the Load Screen's What's New row (Roadmap topic 1, design 1):
# the sources on the left (Kanto Reloaded, KIF Beta, mods with notes), a
# Versions box under them (Kanto Reloaded's and KIF Beta's versions now),
# and on the right the selected source's versions (NEW until read) with the
# selected version's notes under them, full height with a scrollbar.
#
# Up / Down picks a version, Left / Right a source, A reads its notes (Up /
# Down then scroll them), B goes back. Closing it marks every version shown
# as read, so the Load Screen's NEW badge goes. The notes come from
# Reloaded::WhatsNew (Core/Saves/WhatsNew.rb).
#==============================================================================

return unless defined?(Reloaded::SplitScreen)

module Reloaded
  class WhatsNewScreen
    include Reloaded::SplitScreen

    PANEL_Y1 = H - 30
    VERSIONS_Y0 = H - 112        # the Versions box
    NOTE_DY = 22
    BULLET_X = LIST_X0 + 16
    TEXT_X = LIST_X0 + 30
    TEXT_W = LIST_X1 - 14 - TEXT_X
    WN = Reloaded::WhatsNew

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
      @focus = :list
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
        elsif (k = pt.hit(@row_hits)) && k != @sel
          @sel = k
          @focus = :list
          @scroll = 0
          pbPlayCursorSE
          refresh
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
        elsif (k = pt.hit(@row_hits))
          @sel = k
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
          @sel = target
          @scroll = 0
          pbPlayCursorSE
          refresh
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
      @scroll = 0
      @focus = :list
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
    # The right side: versions, then the selected one's notes
    #--------------------------------------------------------------------------
    # [[kind, x, height]]: :head, :version, :note ([text, depth])
    def lines
      return [] unless source
      out = [[:head, source[:name], HEAD_H]]
      versions.each_with_index { |v, i| out << [:version, i, ROW_H] }
      v = version
      return out unless v
      out << [:head, _INTL("In {1}", v.version), HEAD_H + 6]
      v.notes.each do |text, depth|
        wrapped = P.wrap(text.to_s, TEXT_W - depth * 14)
        wrapped = [""] if wrapped.empty?
        wrapped.each_with_index { |ln, k| out << [:note, [ln, depth, k.zero?], NOTE_DY - (k.zero? ? 0 : 3)] }
      end
      out << [:note, [_INTL("No notes for this version."), 0, false], NOTE_DY] if v.notes.empty?
      return out
    end

    def content_height
      return lines.sum { |_k, _x, h| h }
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
          :dot => s[:versions].any? { |v| @fresh[[s[:name], v.version]] } ? GOLD_DOT : nil }
      end
      paint_sidebar(base, top, c, entries, @sources.empty? ? nil : @section, false)
      paint_versions_box(base, top, c)
      paint_right(base, top, c)
      paint_hints(base, c)
      place_cursor
    end

    GOLD_DOT = Color.new(240, 200, 80)

    def side_y1
      return VERSIONS_Y0 - 6
    end

    def paint_versions_box(base, top, c)
      P.ui.rbox(base, 6, VERSIONS_Y0, SIDE_X1, PANEL_Y1, 6, c[:panel2], c[:line])
      P.text(top, 14, VERSIONS_Y0 + 6, 150, 13, _INTL("VERSIONS"), c[:head], PF::TINY)
      rows = [[WN::KR, Reloaded.version]]
      rows << [WN::KIF, WN.kif_version] if WN.kif_version
      rows.each_with_index do |(name, v), k|
        y = VERSIONS_Y0 + 22 + k * 22
        P.small(top, 14, y, SIDE_X1 - 28, 18, name, c[:txt])
        P.small(top, 14, y, SIDE_X1 - 24, 18, v.to_s, BLUE, 1)
      end
    end

    def paint_right(base, top, c)
      P.ui.rbox(base, LIST_X0, LIST_Y0, LIST_X1, PANEL_Y1, 6, c[:panel])
      @row_hits = []
      if @sources.empty?
        P.text(top, LIST_X0 + 12, LIST_Y0 + 8, 300, 22, _INTL("No notes yet."), c[:dim])
        return
      end
      all = lines
      # the selected version stays in view while picking versions
      if @focus == :list
        y = 0
        all.each do |kind, x, h|
          break if kind == :version && x == @sel
          y += h
        end
        room = PANEL_Y1 - LIST_Y0 - 8
        @scroll = y + ROW_H - room if y + ROW_H - @scroll > room
        @scroll = [@scroll, 0].max
      end
      y = LIST_Y0 + 4 - @scroll
      all.each do |kind, x, h|
        if y >= LIST_Y0 && y + h <= PANEL_Y1 - 2
          case kind
          when :head then P.heading(top, LIST_X0 + 10, LIST_X1 - 14, y + 4, x.to_s, c[:head], c[:line])
          when :version then paint_version(top, c, x, y)
          when :note then paint_note(top, c, x, y)
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

    def paint_version(top, c, i, y)
      v = versions[i]
      @row_hits << [i, LIST_X0 + 4, y, LIST_X1 - 8, y + ROW_H - 2]
      @cursor_rect = [LIST_X0 + 4, y, (LIST_X1 - 8) - (LIST_X0 + 4) + 1, ROW_H - 1] if i == @sel && @focus == :list
      P.text(top, NAME_X, y, 170, ROW_H - 2, _INTL("Version {1}", v.version), c[:opt], PF::ROW)
      P.text(top, LIST_X0 + 190, y, 80, ROW_H - 2, date_text(v.date), c[:dim], PF::ROW)
      P.pill(top, LIST_X1 - 14, y + 5, _INTL("NEW"), Color.new(60, 50, 10), GOLD_DOT) if @fresh[[source[:name], v.version]]
    end

    def paint_note(top, c, x, y)
      text, depth, first = x
      bx = BULLET_X + depth * 14
      P.ui.rbox(top, bx, y + 8, bx + 4, y + 12, 2, depth.zero? ? BLUE : c[:dim]) if first
      P.text(top, TEXT_X + depth * 14, y, TEXT_W - depth * 14, NOTE_DY, text, depth.zero? ? c[:txt] : c[:dim])
    end

    # "Today", "Oct 20", "Oct 20 2025" from "2026-10-20"
    def date_text(date)
      m = date.to_s.match(/(\d{4})-(\d\d)-(\d\d)/)
      return date.to_s unless m
      t = Time.local(m[1].to_i, m[2].to_i, m[3].to_i)
      now = Time.now
      return _INTL("Today") if t.year == now.year && t.yday == now.yday
      return t.strftime(t.year == now.year ? "%b %-d" : "%b %-d %Y")
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
