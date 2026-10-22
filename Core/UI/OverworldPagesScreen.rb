#==============================================================================
# Kanto Reloaded: the Overworld Menu's page editor
#==============================================================================
# Edit Pages (X in the Overworld Menu, or the Overworld Menu page in KIF
# Settings), in the Settings layout: the pages on the left (Main, Toggles,
# Info and your own, then Add Page), the entries on the right, the one
# highlighted explained below.
#
#   a page    A goes to its entries; Y renames it, resets it, or removes it
#             (your own pages only)
#   an entry  A puts it on the page or takes it off; X picks it up, Up/Down
#             carry it, anything else puts it down
#
# Every entry there is can go on any page. The pages are the same in every
# save (Reloaded::OverworldMenu.layout); each change is kept at once.
#==============================================================================

return unless defined?(Reloaded::SplitScreen)

module Reloaded
  class OverworldPagesScreen
    include Reloaded::SplitScreen

    OM = Reloaded::OverworldMenu
    # The headings Not on It is split under, in this order (his call,
    # 2026-10-20); Add a Setting sits under Settings
    GROUP_NAMES = { :action => "Actions", :toggle => "Toggles", :info => "Readouts", :add => "Settings" }.freeze
    # The last row of every page's list: any setting from KIF Settings
    ADD_SETTING = Reloaded::OverworldMenu::Entry.new("__add_setting__", "Add a Setting", :add, nil, 0, nil, nil, nil, nil,
      "Any setting or button from KIF Settings, as a row on this page. A opens KIF Settings to pick one.")

    attr_reader :entry

    def self.open(page = 0)
      return new(page).main
    end

    def initialize(page = 0)
      frame_init
      @section = [[page.to_i, 0].max, OM.pages.length - 1].min
      @sel = 0
      @focus = :side
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
      return true
    ensure
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

    private

    def page
      return OM.pages[@section]
    end

    def add_slot?
      return @section == OM.pages.length
    end

    # [[entry, on the page?]]: the page's entries in their order, then the
    # rest, then Add a Setting (settings are picked in KIF Settings)
    def rows
      return [] unless page
      on = page["entries"].map { |k| OM.entry(k) }.compact
      off = OM.entries.reject { |e| page["entries"].include?(e.key) }
      out = on.map { |e| [e, true] } + off.map { |e| [e, false] }
      out << [ADD_SETTING, false] if defined?(Reloaded::SettingsScreen) && Reloaded::OverworldMenu::SettingRows.available?
      return out
    end

    def row
      return rows[@sel]
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      return move_input if @moving
      pt = Reloaded::Pointer
      if pointer_hover
        if (i = pt.hit(@side_hits)) && @focus == :side && i != @section
          pick_section(i)
        elsif (k = pt.hit(@row_hits)) && (k != @sel || @focus != :list)
          @sel = k
          @focus = :list
          pbPlayCursorSE
          refresh
        end
      end
      return close_screen if pt.right? && @focus == :side
      return to_sections if pt.right?
      if pt.left?
        handled, result = hint_click
        return result if handled
        if (i = pt.hit(@side_hits))
          pick_section(i) if i != @section
          add_slot? ? add_page : enter_list
        elsif (k = pt.hit(@row_hits))
          @sel = k
          @focus = :list
          toggle
        end
        return nil
      end
      if (w = pt.wheel) != 0
        @focus == :side ? pick_section((@section + w) % side_count) : step(w, true)
        return nil
      end
      if Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        fresh = Input.trigger?(Input::DOWN) || Input.trigger?(Input::UP)
        @focus == :side ? pick_section((@section + dir) % side_count) : step(dir, fresh)
      elsif Input.trigger?(Input::RIGHT) && @focus == :side
        enter_list unless add_slot?
      elsif Input.trigger?(Input::LEFT) && @focus == :list
        to_sections
      elsif Input.trigger?(Input::USE)
        if @focus == :side
          add_slot? ? add_page : enter_list
        else
          toggle
        end
      elsif Input.trigger?(Input::ACTION) && @focus == :list    # X on a controller
        pick_up
      elsif Input.trigger?(Input::X) && @focus == :side && !add_slot?    # Y on a controller
        page_menu
      elsif Input.trigger?(Input::BACK)
        return @focus == :side ? close_screen : to_sections
      end
      return nil
    end

    def side_count
      return OM.pages.length + (OM.pages.length < OM::PAGE_MAX ? 1 : 0)
    end

    def step(dir, fresh)
      n = rows.length
      return if n == 0
      target = @sel + dir
      if target < 0 || target >= n
        return unless fresh
        target %= n
      end
      @sel = target
      pbPlayCursorSE
      refresh
    end

    def pick_section(i)
      @section = i
      @sel = 0
      @scroll = 0
      pbPlayCursorSE
      refresh
    end

    def enter_list
      return if add_slot? || rows.empty?
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
      pbPlayCloseMenuSE if defined?(pbPlayCloseMenuSE)
      return :close
    end

    # A: on the page (at its end) or off it. Add a Setting: KIF Settings in
    # pick mode, and the setting picked goes on the page.
    def toggle
      r = row
      return unless r
      e, on = r
      return add_setting if e.equal?(ADD_SETTING)
      if on
        page["entries"].delete(e.key)
      else
        page["entries"] << e.key
      end
      OM.save_layout
      pbPlayDecisionSE
      refresh
    end

    def add_setting
      pbPlayDecisionSE
      key = nil
      hidden { key = Reloaded::SettingsScreen.pick }
      if key && !page["entries"].include?(key)
        page["entries"] << key
        OM.save_layout
        @sel = rows.index { |x, _on| x.key == key } || @sel
      end
      refresh
    end

    def pick_up
      r = row
      unless r && r[1]
        pbPlayBuzzerSE
        return
      end
      @moving = r[0].key
      pbPlayDecisionSE
      refresh
    end

    # Up/Down carry the entry along the page; anything else puts it down.
    def move_input
      list = page["entries"]
      if Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
        dir = Input.repeat?(Input::UP) ? -1 : 1
        i = list.index(@moving)
        j = i + dir
        return nil if i.nil? || j < 0 || j >= list.length
        list[i], list[j] = list[j], list[i]
        OM.save_layout
        @sel = rows.index { |e, _on| e.key == @moving } || @sel
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::USE) || Input.trigger?(Input::BACK) || Input.trigger?(Input::ACTION) ||
            Reloaded::Pointer.left? || Reloaded::Pointer.right?
        @moving = nil
        pbPlayDecisionSE
        refresh
      end
      return nil
    end

    # Y on a page: Rename, Reset, Remove.
    def page_menu
      pg = page
      own = !OM.builtin?(pg)
      labels = [_INTL("Rename"), _INTL("Reset")]
      descs = [_INTL("Give the page another name."),
               own ? _INTL("Takes everything off the page.") : _INTL("Puts back every entry this page starts with, in its first order.")]
      if own
        labels << _INTL("Remove")
        descs << _INTL("Removes the page. Its entries stay on the others.")
      end
      pbPlayDecisionSE
      i = Reloaded::Dialogs.menu(self, OM.page_name(pg), labels, descs)
      refresh
      case i
      when 0
        name = ask_name(_INTL("Rename the Page"), OM.page_name(pg))
        OM.rename_page(pg, name) if name && !name.strip.empty?
      when 1
        OM.reset_page(pg) if Reloaded::Dialogs.confirm(self, _INTL("Reset {1}?", OM.page_name(pg)), descs[1], _INTL("Reset"), _INTL("Cancel"), false)
      when 2
        if Reloaded::Dialogs.confirm(self, _INTL("Remove {1}?", OM.page_name(pg)), descs[2], _INTL("Remove"), _INTL("Cancel"), false)
          OM.remove_page(pg)
          @section = [@section, OM.pages.length - 1].min
        end
      end
      @sel = 0
      refresh
    end

    def add_page
      if OM.pages.length >= OM::PAGE_MAX
        pbPlayBuzzerSE
        return
      end
      pbPlayDecisionSE
      name = ask_name(_INTL("Name the New Page"), "")
      return refresh unless name
      OM.add_page(name)                 # no name: Page 4
      @section = OM.pages.length - 1
      @sel = 0
      @focus = :list
      refresh
    end

    # A name typed in the description box ("" for none), or nil when it
    # was stopped.
    def ask_name(label, initial)
      text, how = Reloaded::TextEntry.run(self, label, initial, OM::NAME_MAX, :prompt => label)
      @entry = nil
      refresh
      return how == :enter ? text.to_s : nil
    end

    #--------------------------------------------------------------------------
    # Painting
    #--------------------------------------------------------------------------
    def draw_screen
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.fill_rect(0, 0, W, H, c[:bg])
      top.clear
      @cursor_rect = nil
      @row_hits = []
      paint_title_bar(base, c)
      P.text(top, 0, 2, W, 28, _INTL("Overworld Menu Pages"), c[:title], PF::TITLE, 2)
      entries = OM.pages.each_with_index.map do |pg, i|
        { :name => OM.page_name(pg), :tile => [:dot, OM.builtin?(pg) ? [130, 190, 250] : [120, 230, 150]] }
      end
      entries << { :name => _INTL("Add Page"), :tile => [:dot, [150, 160, 175]], :faded => true } if OM.pages.length < OM::PAGE_MAX
      paint_sidebar(base, top, c, entries, @section, @focus == :side)
      P.ui.rbox(base, LIST_X0, LIST_Y0, LIST_X1, LIST_Y1, 6, c[:panel])
      paint_list(base, top, c)
      paint_description(base, top, c)
      paint_hints(base, c)
      place_cursor
    end

    def paint_list(base, top, c)
      if add_slot?
        P.small(top, LIST_X0 + 12, LIST_Y0 + 10, LIST_X1 - LIST_X0 - 24, 16, _INTL("A names a new page."), c[:dim])
        return
      end
      list = rows
      on_count = list.count { |_e, on| on }
      items = []
      items << [:head, _INTL("On This Page")]
      items << [:note, _INTL("Nothing yet. Add some from the list below.")] if on_count == 0
      list.each_with_index { |(e, on), i| items << [:row, i] if on }
      # the rest, under a heading for each type (rows lists them in this order)
      group = nil
      list.each_with_index do |(e, on), i|
        next if on
        if e.kind != group
          group = e.kind
          items << [:head, _INTL(GROUP_NAMES[group] || group.to_s.capitalize)]
        end
        items << [:row, i]
      end
      sel_item = items.index { |kind, x| kind == :row && x == @sel }
      shown, total, avail = layout_items(items, @focus == :list ? sel_item : nil)
      shown.each do |k, y|
        kind, x = items[k]
        if kind == :head
          P.heading(top, LIST_X0 + 10, LIST_X1 - 10, y + 5, x.to_s, c[:head], c[:line])
          next
        end
        if kind == :note
          P.small(top, NAME_X, y, LIST_X1 - NAME_X - 12, ROW_H - 2, x.to_s, c[:dim])
          next
        end
        e, on = list[x]
        @row_hits << [x, LIST_X0 + 4, y, LIST_X1 - 8, y + ROW_H - 2]
        if @focus == :list && @sel == x
          @cursor_rect = [LIST_X0 + 4, y, LIST_X1 - 8 - LIST_X0 - 4 + 1, ROW_H - 1]
        end
        if e.equal?(ADD_SETTING)
          plus(top, NAME_X - 2, y + 5, c)
        else
          tick(top, NAME_X - 2, y + 5, on, c)
        end
        name_colour = @moving == e.key ? GREEN : (on ? c[:opt] : c[:dim])
        room = VAL_X1 - NAME_X - 24 - (@moving == e.key ? 24 : 0)
        P.text(top, NAME_X + 22, y, room, ROW_H - 2, PF.fit(PF::ROW, e.name.to_s, room), name_colour, PF::ROW)
        if @moving == e.key
          P.ui.tri(top, VAL_X1 - 70, y + 4, :u, GREEN, 3)
          P.ui.tri(top, VAL_X1 - 70, y + 14, :d, GREEN, 3)
        end
      end
      paint_list_scrollbar(base, c, total, avail)
    end

    # Add a Setting's mark: a plus in a ring
    def plus(top, x, y, c)
      P.ui.rbox(top, x, y, x + 15, y + 15, 8, Color.new(c[:selb].red / 4, c[:selb].green / 4, c[:selb].blue / 4), c[:selb])
      top.fill_rect(x + 4, y + 7, 8, 2, c[:selb])
      top.fill_rect(x + 7, y + 4, 2, 8, c[:selb])
    end

    def tick(top, x, y, on, c)
      colour = on ? GREEN : c[:dim]
      P.ui.rbox(top, x, y, x + 15, y + 15, 8, Color.new(colour.red / 4, colour.green / 4, colour.blue / 4), colour)
      return unless on
      [[3, 7], [4, 8], [5, 9], [6, 8], [7, 7], [8, 6], [9, 5], [10, 4]].each { |dx, dy| top.fill_rect(x + dx, y + dy, 2, 2, colour) }
    end

    def paint_description(base, top, c)
      if @entry
        y0 = LIST_Y1 + 4
        description_box(base, c, y0)
        P.text(top, 14, y0 + 1, W - 28, 26, @entry.label.to_s, c[:head], PF::ROW)
        Reloaded::TextEntry.draw_field(base, top, c, @entry, 14, y0 + 34, W - 28, 24)
        return
      end
      if @focus == :side || row.nil?
        if add_slot?
          return paint_description_box(base, top, c, _INTL("Add Page"), _INTL("A new page of your own, up to {1} pages in all. You choose what goes on it.", OM::PAGE_MAX), :add)
        end
        pg = page
        words = OM.builtin?(pg) ? _INTL("Edit Page renames or resets it.") : _INTL("Your own page. Edit Page renames, resets or removes it.")
        return paint_description_box(base, top, c, OM.page_name(pg), _INTL("{1} entries on it. ", pg["entries"].length) + words, [:page, @section])
      end
      e, on = row
      return paint_description_box(base, top, c, e.name, e.description.to_s, [:entry, e.key]) if e.equal?(ADD_SETTING)
      pills = [[on ? _INTL("ON THIS PAGE") : _INTL("OFF THIS PAGE"), dark_fill(on ? GREEN : AMBER), on ? GREEN : AMBER]]
      paint_description_box(base, top, c, e.name, e.description.to_s, [:entry, e.key], pills)
    end

    def hint_pairs
      return [[:ud, _INTL("Move")], [button(:C), _INTL("Done")]] if @moving
      return [[button(:C), _INTL("Type")], [button(:B), _INTL("Cancel")]] if @entry && Reloaded::Prompts.controller?
      return [[nil, _INTL("Type")]] if @entry
      if @focus == :side
        return [[:ud, _INTL("Pages")], [button(:C), _INTL("Add Page"), :add_page], [button(:B), _INTL("Close"), :close_screen]] if add_slot?
        return [[:ud, _INTL("Pages")], [button(:C), _INTL("Entries"), :enter_list], [button(:X), _INTL("Edit Page"), :page_menu],
                [button(:B), _INTL("Close"), :close_screen]]
      end
      r = row
      add = r && r[0].equal?(ADD_SETTING)
      out = [[:ud, _INTL("Choose")], [button(:C), r && r[1] ? _INTL("Remove") : (add ? _INTL("Pick a Setting") : _INTL("Add")), :toggle]]
      out << [button(:A), _INTL("Move"), :pick_up] if r && r[1]
      out << [button(:B), _INTL("Pages"), :to_sections]
      return out
    end
  end
end
