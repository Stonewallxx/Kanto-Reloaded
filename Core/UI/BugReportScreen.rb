#==============================================================================
# Kanto Reloaded: Make a Bug Report
#==============================================================================
# Design 1 (Settings layout), two sections:
#
#   What Happened   a note typed straight in (A opens the naming screen on a
#                   controller), and the screenshot: This Screen (the map as
#                   it was when the Pause Menu opened), the Last Screenshot,
#                   or None, with a preview
#   What's in It    each part ticked off (Logs, Settings, Mods, Hooks, Save
#                   Check, Recent Steps, this session's Errors) and Include
#                   the Save (Off by default)
#
# Make Report (Y, or the box at the top right) saves the zip (Bundle) and
# shows Report Made. Opened from the next start's offer after a crash, the
# crash comes along into the report.
#
#   Reloaded::BugReportScreen.open                        # Kanto Reloaded > Bug Report
#   Reloaded::BugReportScreen.open(:crash => details)     # after a crash
#==============================================================================

return unless defined?(Reloaded::SplitScreen) && defined?(Reloaded::BugReport)

module Reloaded
  class BugReportScreen
    include Reloaded::SplitScreen

    BR = Reloaded::BugReport
    SECTIONS = [[:what, "What Happened"], [:inside, "What's in It"]].freeze
    SHOTS = ["This Screen", "Last Screenshot", "None"].freeze
    NOTE_MAX = 200
    THUMB_W = 160
    THUMB_H = 120
    BOX_W = 132                   # Make Report, top right

    attr_reader :entry

    def self.open(crash: nil)
      return new(crash).main
    end

    def initialize(crash = nil)
      frame_init
      @crash = crash
      @section = 0
      @sel = 0
      @focus = :list
      @note = ""
      @shot = BR.screen ? 0 : (BR.last_screenshot ? 1 : 2)
      @slots = ["Off"] + Reloaded::Saves.slots
      @save = 0
      @logs = BR::Bundle.logs.length
      @mods = BR::Bundle.mods
      @errors = BR::Bundle.quiet_errors
      @slot = BR::Bundle.current_slot
    end

    def main
      open_sprites
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        tick_description
        break if handle_input == :close
      end
      return @made
    ensure
      @thumb.dispose if @thumb && !(@thumb.disposed? rescue true)
      dispose_sprites
    end

    def refresh
      draw_screen if @sprite && !@sprite.disposed?
    end

    def entry=(state)
      @entry = state
    end

    def entry_changed
      refresh
    end

    # For tests.
    attr_reader :note, :made

    private

    def section_id
      return SECTIONS[@section][0]
    end

    # The rows of the section: [id, label, value]
    def rows
      if section_id == :what
        return [[:note, _INTL("Note"), nil], [:shot, _INTL("Screenshot"), _INTL(SHOTS[@shot])]]
      end
      out = [[:logs, _INTL("Logs"), @logs == 1 ? _INTL("1 File") : _INTL("{1} Files", @logs)],
             [:settings, _INTL("Settings"), _INTL("KR and KIF")],
             [:mods, _INTL("Mods"), _INTL("{1}, Load Order", @mods.length)],
             [:hooks, _INTL("Hooks"), _INTL("Summary")],
             [:check, _INTL("Save Check"), @slot ? @slot.to_s : _INTL("None")],
             [:steps, _INTL("Recent Steps"), _INTL("{1} Steps", BR::Trail.steps.length)],
             [:errors, _INTL("Errors"), @errors.empty? ? _INTL("None") : _INTL("{1} This Session", @errors.length)],
             [:save, _INTL("Include the Save"), @save.zero? ? _INTL("Off") : @slots[@save]]]
      return out
    end

    def row
      return rows[@sel]
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      pt = Reloaded::Pointer
      if pointer_hover
        if (i = pt.hit(@side_hits)) && i != @section && @focus == :side
          pick_section(i)
        elsif (k = pt.hit(@row_hits)) && (k != @sel || @focus != :list)
          @sel = k
          @focus = :list
          pbPlayCursorSE
          refresh
        end
      end
      return close_screen if pt.right?
      if pt.left?
        handled, result = hint_click
        return result if handled
        return make_report if pt.inside?(*right_box)
        if (i = pt.hit(@side_hits))
          pick_section(i)
          @focus = :list
        elsif (k = pt.hit(@row_hits))
          @sel = k
          @focus = :list
          press
        end
        return nil
      end
      if Input.trigger?(Input::X)                 # a controller's Y
        return make_report
      elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        if @focus == :side
          pick_section((@section + dir) % SECTIONS.length)
        else
          n = rows.length
          target = @sel + dir
          if target < 0 || target >= n
            return nil unless fresh?(dir)
            target = dir < 0 ? n - 1 : 0
          end
          @sel = target
          pbPlayCursorSE
          refresh
        end
      elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
        dir = Input.trigger?(Input::RIGHT) ? 1 : -1
        if @focus == :side
          if dir > 0
            @focus = :list
            pbPlayCursorSE
            refresh
          end
        elsif !change(dir) && dir < 0
          to_sections
        end
      elsif Input.trigger?(Input::USE)
        @focus == :side ? enter_list : press
      elsif Input.trigger?(Input::BACK)
        return @focus == :side ? close_screen : to_sections
      end
      return nil
    end

    def pick_section(i)
      @section = i
      @sel = 0
      @scroll = 0
      pbPlayCursorSE
      refresh
    end

    def enter_list
      pbPlayDecisionSE
      @focus = :list
      refresh
    end

    def to_sections
      pbPlayCancelSE
      @focus = :side
      refresh
      return nil
    end

    def close_screen
      pbPlayCloseMenuSE
      return :close
    end

    # Left / Right on a choice: true when it changed.
    def change(dir)
      case row && row[0]
      when :shot
        @shot = (@shot + dir) % SHOTS.length
      when :save
        @save = (@save + dir) % @slots.length
      else
        return false
      end
      pbPlayCursorSE
      refresh
      return true
    end

    def press
      case row && row[0]
      when :note then edit_note
      when :shot, :save then change(1)
      when :errors then show_errors
      else pbPlayBuzzerSE
      end
      return nil
    end

    def edit_note
      pbPlayDecisionSE
      text, how = Reloaded::TextEntry.run(self, _INTL("What Happened"), @note, NOTE_MAX, :prompt => _INTL("What Happened"))
      @note = text.to_s if how == :enter
      refresh
    end

    def show_errors
      return pbPlayBuzzerSE if @errors.empty?
      pbPlayDecisionSE
      text = @errors.first(6).map { |e| "• " + e.sub(/\A\d\d:\d\d:\d\d /, "") }.join("\n")
      text += "\n" + _INTL("And {1} more.", @errors.length - 6) if @errors.length > 6
      Reloaded::Dialogs.notice(self, _INTL("Errors This Session"), text)
      refresh
    end

    # Y: the report, then Report Made; the screen closes after.
    def make_report
      pbPlayDecisionSE
      making
      shot = case @shot
             when 0 then BR.screen
             when 1 then BR.last_screenshot
             end
      save = @save.zero? ? nil : @slots[@save]
      result = BR::Bundle.make(:note => @note, :screenshot => shot, :save => save, :crash => @crash)
      BR::Crash.mark_reported if @crash
      @made = result[:path]
      mod = @crash && @crash[:owner] && defined?(Reloaded::Profiler::Owners) && Reloaded::Profiler::Owners.mod?(@crash[:owner].to_s) ? @crash[:owner] : nil
      BR.report_made(result, :mod => mod)
      return :close
    rescue StandardError => e
      Reloaded::Log.exception("The bug report couldn't be made", e, :bug_report)
      Reloaded::Dialogs.notice(self, _INTL("Bug Report"), _INTL("That didn't work: {1}", e.message))
      refresh
      return nil
    end

    # "Making the report..." while the zip is written (a moment, with the
    # Save Check).
    def making
      c = palette
      o = @overlay_sprite.bitmap
      P.ui.rbox(o, 156, 170, 356, 210, 8, c[:panel2], c[:selb])
      P.text(o, 156, 178, 200, 24, _INTL("Making the report..."), c[:txt], nil, 2)
      Graphics.update
      o.clear
    end

    #--------------------------------------------------------------------------
    # Painting
    #--------------------------------------------------------------------------
    def right_w
      return BOX_W
    end

    def draw_screen
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      base.fill_rect(0, 0, W, H, c[:bg])
      @cursor_rect = nil
      @row_hits = []
      paint_title_bar(base, c)
      P.text(top, 0, 2, W, 28, _INTL("Bug Report"), c[:title], PF::TITLE, 2)
      paint_make_box(base, top, c)
      entries = SECTIONS.map { |_id, name| { :name => _INTL(name), :tile => [:dot, [120, 230, 150]] } }
      paint_sidebar(base, top, c, entries, @section, @focus == :side)
      P.ui.rbox(base, LIST_X0, LIST_Y0, LIST_X1, LIST_Y1, 6, c[:panel])
      section_id == :what ? paint_what(base, top, c) : paint_inside(base, top, c)
      paint_description(base, top, c)
      paint_hints(base, c)
      place_cursor
    end

    def paint_make_box(base, top, c)
      x0, y0, x1, y1 = right_box
      hover = @hover_box == :right
      P.ui.rbox(base, x0, y0, x1, y1, 5, c[:light] ? dark_fill(palette[:green]) : Color.new(24, 60, 36), hover ? c[:selb] : palette[:green])
      P.text(top, x0, y0, x1 - x0, 24, _INTL("Make Report"), palette[:green], nil, 2)
      key = button(:X)
      kw = Reloaded::ButtonIcons.width(key, Reloaded::Prompts.style) rescue 0
      Reloaded::ButtonIcons.draw(top, x0 - 6 - kw, 8, key, c, Reloaded::Prompts.style) rescue nil
    end

    def paint_what(base, top, c)
      y = LIST_Y0 + 6
      P.heading(top, LIST_X0 + 10, LIST_X1 - 10, y, _INTL("What Happened"), c[:head], c[:line])
      y += 18
      if @crash
        P.small(top, LIST_X0 + 12, y, LIST_X1 - LIST_X0 - 24, 16, fit_small(top, _INTL("The crash: {1} in {2}", @crash[:error].to_s.split(":").first, @crash[:where]), LIST_X1 - LIST_X0 - 24), palette[:red])
        y += 16
      end
      # the note, in its box
      bx0 = LIST_X0 + 8
      bx1 = LIST_X1 - 8
      on = @focus == :list && @sel == 0
      @row_hits << [0, bx0, y, bx1, y + 44]
      if @entry
        Reloaded::TextEntry.draw_field(base, top, c, @entry, bx0 + 2, y + 10, bx1 - bx0 - 4, 24)
      else
        P.ui.rbox(base, bx0, y, bx1, y + 44, 5, c[:dark], c[:line])
        lines = @note.empty? ? [_INTL("What were you doing, and what went wrong?")] : P.wrap(@note, bx1 - bx0 - 20).first(2)
        lines.each_with_index { |ln, k| P.text(top, bx0 + 10, y + 1 + k * 20, bx1 - bx0 - 20, 22, ln, @note.empty? ? c[:dim] : c[:txt]) }
        @cursor_rect = [bx0, y, bx1 - bx0, 45] if on
      end
      y += 50
      # the screenshot choice
      @row_hits << [1, LIST_X0 + 4, y, LIST_X1 - 8, y + ROW_H - 2]
      @cursor_rect = [LIST_X0 + 4, y, LIST_X1 - 8 - LIST_X0 - 4 + 1, ROW_H - 1] if @focus == :list && @sel == 1
      P.text(top, NAME_X, y, 150, ROW_H - 2, _INTL("Screenshot"), c[:opt], PF::ROW)
      value = _INTL(SHOTS[@shot])
      vw = P.width(PF::ROW, value)
      P.ui.tri(top, VAL_X1 - vw - 14, y + 9, :l, c[:dim], 3)
      P.text(top, VAL_X1 - vw - 4, y, vw, ROW_H - 2, value, c[:txt], PF::ROW)
      P.ui.tri(top, VAL_X1, y + 9, :r, c[:dim], 3)
      y += ROW_H + 4
      paint_thumb(base, top, c, LIST_X0 + 10, y)
    end

    # The screenshot chosen, small, with what it is beside it.
    def paint_thumb(base, top, c, x, y)
      src = case @shot
            when 0 then BR.screen
            when 1 then thumb_file(BR.last_screenshot)
            end
      words = case @shot
              when 0 then src ? _INTL("The screen as it was when you opened the Pause Menu. Or the last screenshot, or none.") : _INTL("There's no screen yet: Open the Pause Menu first.")
              when 1 then src ? _INTL("Your newest screenshot.") : _INTL("No screenshots yet.")
              else _INTL("No picture goes in the report.")
              end
      P.ui.rbox(base, x - 1, y - 1, x + THUMB_W, y + THUMB_H, 2, c[:dark], c[:line])
      top.stretch_blt(Rect.new(x, y, THUMB_W, THUMB_H), src, Rect.new(0, 0, src.width, src.height)) if src
      tx = x + THUMB_W + 12
      P.small_wrap(top, words, LIST_X1 - 12 - tx).first(6).each_with_index do |ln, k|
        P.small(top, tx, y + k * 16, LIST_X1 - 12 - tx, 16, ln, c[:dim])
      end
    end

    def thumb_file(path)
      return nil unless path
      return @thumb if @thumb_for == path && @thumb && !(@thumb.disposed? rescue true)
      @thumb.dispose if @thumb && !(@thumb.disposed? rescue true)
      @thumb_for = path
      @thumb = (Bitmap.new(path) rescue nil)
      return @thumb
    end

    def paint_inside(base, top, c)
      items = rows.map { |r| [:row, r] }      # the sidebar names the section: no heading, so all of it fits
      sel = @sel
      shown, total, avail = layout_items(items, sel)
      shown.each do |i, y|
        kind, x = items[i]
        if kind == :head
          P.heading(top, LIST_X0 + 10, LIST_X1 - 10, y + 4, x.to_s, c[:head], c[:line])
          next
        end
        k = i
        id, label, value = x
        @row_hits << [k, LIST_X0 + 4, y, LIST_X1 - 8, y + ROW_H - 2]
        @cursor_rect = [LIST_X0 + 4, y, LIST_X1 - 8 - LIST_X0 - 4 + 1, ROW_H - 1] if @focus == :list && @sel == k
        tick(top, NAME_X - 2, y + 4, id, c)
        P.text(top, NAME_X + 20, y, 150, ROW_H - 2, label, c[:opt], PF::ROW)
        colour = id == :errors && !@errors.empty? ? palette[:amber] : c[:txt]
        if id == :save
          vw = P.width(PF::ROW, value)
          P.ui.tri(top, VAL_X1 - vw - 14, y + 9, :l, c[:dim], 3)
          P.text(top, VAL_X1 - vw - 4, y, vw, ROW_H - 2, value, colour, PF::ROW)
          P.ui.tri(top, VAL_X1, y + 9, :r, c[:dim], 3)
        else
          P.text(top, NAME_X + 150, y, VAL_X1 - NAME_X - 150, ROW_H - 2, value, colour, PF::ROW, 1)
        end
      end
      paint_list_scrollbar(base, c, total, avail)
      P.small(top, LIST_X0 + 12, LIST_Y1 - 16, LIST_X1 - LIST_X0 - 24, 14, _INTL("User names are taken out of paths."), c[:dim])
    end

    # A tick for what goes in; Include the Save's is empty while it's Off.
    def tick(top, x, y, id, c)
      on = id != :save || !@save.zero?
      colour = on ? palette[:green] : c[:dim]
      P.ui.rbox(top, x, y, x + 15, y + 15, 8, dark_fill(colour), colour)
      return unless on
      [[3, 7], [4, 8], [5, 9], [6, 8], [7, 7], [8, 6], [9, 5], [10, 4]].each { |dx, dy| top.fill_rect(x + dx, y + dy, 2, 2, colour) }
    end

    def paint_description(base, top, c)
      r = row
      return paint_description_box(base, top, c, _INTL(SECTIONS[@section][1]), section_words, @section) if @focus == :side || r.nil?
      title, text, pills = describe(r)
      paint_description_box(base, top, c, title, text, [@section, @sel], pills || [])
    end

    def section_words
      return section_id == :what ? _INTL("Your note and a picture of what happened.") : _INTL("Everything in the report, ticked off. The file goes in Kanto Reloaded's Bug Reports folder.")
    end

    # [title, text, pills]
    def describe(r)
      id = r[0]
      case id
      when :note then return [_INTL("What Happened"), _INTL("Type straight in: What you were doing and what went wrong. A opens the naming screen.")]
      when :shot then return [_INTL("Screenshot"), _INTL("This Screen is the screen as it was when you opened the Pause Menu. Or your last screenshot, or none.")]
      when :logs then return [_INTL("Logs"), _INTL("Kanto Reloaded's log and the one before it, KIF's session and error logs, and the game's errorlog.")]
      when :settings then return [_INTL("Settings"), _INTL("Kanto Reloaded's settings, controls, layouts and features, and KIF's settings.")]
      when :mods then return [_INTL("Mods"), _INTL("Every mod: On or off, loaded or not, its version and author, and the order they load in.")]
      when :hooks then return [_INTL("Hooks"), _INTL("Where Kanto Reloaded changes the game, and any other code on the same methods.")]
      when :check then return [_INTL("Save Check"), @slot ? _INTL("The Save Checker's report on {1}.", @slot) : _INTL("No save to check yet.")]
      when :steps then return [_INTL("Recent Steps"), _INTL("The last 100 things that happened: Maps, battles, menus, saves and errors, as a timeline.")]
      when :errors
        text = @errors.empty? ? _INTL("No errors this session.") : _INTL("Errors that didn't close the game, listed in the report. A shows them.")
        return [_INTL("Errors"), text]
      when :save
        pill = [[_INTL("OFF BY DEFAULT"), c_dark, palette[:dim]]]
        if @save.zero?
          return [_INTL("Include the Save"), _INTL("Adds a copy of a save, so the bug can be played again. Your save itself isn't changed."), pill]
        end
        slot = @slots[@save]
        size = SaveCheck.size_words(File.size(Reloaded::Saves.path(slot))) rescue "?"
        return [_INTL("Include the Save"), _INTL("Adds a copy of {1} ({2}), so the bug can be played again. Your save itself isn't changed.", slot, size), pill]
      end
      return [r[1], ""]
    end

    def c_dark
      return palette[:dark]
    end

    def fit_small(b, text, w)
      P.small_font(b)
      return text if b.text_size(text).width <= w
      text = text[0...-1] while text.length > 1 && b.text_size(text + "...").width > w
      return text + "..."
    end

    def hint_pairs
      if @entry
        return [[button(:C), _INTL("Type")], [button(:B), _INTL("Cancel")]] if Reloaded::Prompts.controller?
        return [[nil, _INTL("Type")], [Reloaded::Controls::Inputs.key(40), _INTL("Done")], [Reloaded::Controls::Inputs.key(41), _INTL("Cancel")]]
      end
      out = [[:ud, _INTL("Select")]]
      if @focus == :list
        case row && row[0]
        when :note then out << [button(:C), _INTL("Naming Screen"), :press]
        when :shot, :save then out << [:lr, _INTL("Change")]
        when :errors then out << [button(:C), _INTL("Show"), :press] unless @errors.empty?
        end
      end
      out << [button(:X), _INTL("Make Report"), :make_report]
      out << [button(:B), @focus == :list ? _INTL("Sections") : _INTL("Back")]
      return out
    end
  end
end
