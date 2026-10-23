#==============================================================================
# Kanto Reloaded: the Save Manager
#==============================================================================
# Design 1 (Roadmap topic 1): three tabs, two panels each.
#
#   Active   the save files on the left (color tag, note, health badge);
#            the selected one's details on the right: trainer, location,
#            saved, play time, party, its Notes (Y edits) and a status
#            banner (a click opens the Save Checker). A: Edit Note, Color
#            Tag, Check This Save, Backups, Back Up Now, Delete (to the
#            Deleted tab), Open Folder
#   Backups  the selected save's backups, newest first (named ones in
#            gold); the selected backup's details, Restore (A), Name (Y)
#            and Check (X: the Save Checker on it). Left / Right: another
#            save's
#   Deleted  the saves you've deleted: Restore (to their slot, or the first
#            free one) or Delete Forever
#
# The save being played can't be deleted or restored over (do that from
# the title screen). Opened from Kanto Reloaded > Saves > Save Manager, and
# from the Load Screen. Its model is Reloaded::Saves (Library.rb).
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont)

module Reloaded
  class SaveManagerScreen
    include Reloaded::Frame

    PF = ::KIF::PixelFont
    P = Reloaded::Pixel
    TABS = [[:active, "Active"], [:backups, "Backups"], [:deleted, "Deleted"]].freeze
    TAB_W = 116
    TAB_Y = 30
    PANEL_Y0 = 56
    PANEL_Y1 = H - 30
    LEFT_X0 = 6
    LEFT_X1 = 222
    RIGHT_X0 = 228
    RIGHT_X1 = W - 6
    SAVE_ROW = 42
    BACKUP_ROW = 36
    LIST_Y = 62
    BACKUP_LIST_Y = 76
    HEALTH = { :healthy => ["HEALTHY", :green], :check => ["CHECK", :amber], :damaged => ["DAMAGED", :red] }.freeze
    PARTY_WAIT = 8          # frames the cursor rests before a party is read (a whole save file)
    PARTY_Y = 214           # the middle of the party's row, under the details
    S = Reloaded::Saves

    attr_reader :entry, :changed

    # from_title: opened from the Load Screen. Returns true when saves
    # changed (the Load Screen reads them again).
    def self.open(from_title = false, tab = :active, slot = nil)
      return new(from_title, tab, slot).main
    end

    def initialize(from_title = false, tab = :active, slot = nil)
      frame_init
      @from_title = from_title
      @tab = TABS.index { |t, _| t == tab } || 0
      @sel = 0
      @top = 0
      @changed = false
      @icons = []
      reload
      i = @saves.index { |s| s[:slot] == slot } if slot
      @save = i || 0
      @sel = @save if @tab == 0
    end

    def main
      open_sprites
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        @icons.each { |s| s.update unless s.disposed? }
        tick
        break if handle_input == :close
      end
      return @changed
    ensure
      dispose_icons
      dispose_sprites
      S.save_kept_previews
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

    #--------------------------------------------------------------------------
    # What's shown
    #--------------------------------------------------------------------------
    def reload
      @saves = S.slots.map { |slot| { :slot => slot, :path => S.path(slot) } }
      @saves.each { |s| s[:pv] = S.preview(s[:path], :party => false) }
      @archived = S.archived
      @backup_list = nil
      @party_for = nil
    end

    def tab
      return TABS[@tab][0]
    end

    def save_entry
      return @saves[@save]
    end

    def backups
      return [] unless save_entry
      return @backup_list ||= S.backups(save_entry[:slot]).map { |b| b.merge(:pv => nil) }
    end

    # The left list's entries, in this tab.
    def list
      case tab
      when :active then return @saves
      when :backups then return backups
      else return @archived
      end
    end

    def current
      return list[@sel]
    end

    def row_h
      return tab == :backups ? BACKUP_ROW : SAVE_ROW
    end

    def list_y
      return tab == :backups ? BACKUP_LIST_Y : LIST_Y
    end

    def fit
      return (PANEL_Y1 - 4 - list_y) / row_h
    end

    #--------------------------------------------------------------------------
    # Every frame: backups' previews fill in one at a time; the party shows
    # once the cursor rests
    #--------------------------------------------------------------------------
    def tick
      if tab == :backups && (b = backups[@top, fit].to_a.find { |x| x[:pv].nil? } || backups.find { |x| x[:pv].nil? })
        b[:pv] = S.preview(b[:path], :party => false)
        refresh
        return
      end
      @rest = @rest.to_i + 1
      return unless @rest == PARTY_WAIT
      show_party
    end

    def selection_moved
      @rest = 0
      dispose_icons
      @party_for = nil
    end

    def selected_file
      e = current
      return nil unless e
      return e[:path] if tab != :deleted
      return e[:file]
    end

    # The selected save's party, as the game's icons: one row, centred
    # under the details (small or big icons alike).
    def show_party
      file = selected_file
      return if file.nil? || @party_for == file
      @party_for = file
      dispose_icons
      pv = S.preview(file)
      @icons = Reloaded::PartyIcons.row(pv[:party], @viewport, (RIGHT_X0 + RIGHT_X1) / 2, PARTY_Y,
                                        RIGHT_X1 - RIGHT_X0 - 20)
    rescue StandardError => e
      Reloaded::Log.exception("A save's party couldn't be shown", e, :saves)
    end

    def dispose_icons
      Array(@icons).each { |s| s.dispose unless s.disposed? }
      @icons = []
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      pt = Reloaded::Pointer
      if pointer_hover && (i = pt.hit(@row_hits)) && i != @sel
        @sel = i
        selection_moved
        pbPlayCursorSE
        refresh
      end
      return close_screen if pt.right? || Input.trigger?(Input::BACK)
      if pt.left?
        handled, result = hint_click
        return result if handled
        if (t = pt.hit(@tab_hits))
          switch_tab(t - @tab)
        elsif tab == :active && current && pt.inside?(RIGHT_X0 + 10, PANEL_Y1 - 48, RIGHT_X1 - 10, PANEL_Y1 - 8)
          check_save(current)               # the health banner
        elsif (i = pt.hit(@row_hits))
          @sel = i
          selection_moved
          press
        end
        return nil
      end
      if (dir = pt.wheel) != 0
        move(dir)
        return nil
      end
      if Input.trigger?(Input::JUMPUP)
        switch_tab(-1)
      elsif Input.trigger?(Input::JUMPDOWN)
        switch_tab(1)
      elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        n = list.length
        return nil if n.zero?
        target = @sel + dir
        if target < 0 || target >= n
          return nil unless fresh?(dir)
          target = dir < 0 ? n - 1 : 0
        end
        @sel = target
        @save = @sel if tab == :active
        selection_moved
        pbPlayCursorSE
        refresh
      elsif tab == :backups && (Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT))
        other_save(Input.trigger?(Input::RIGHT) ? 1 : -1)
      elsif Input.trigger?(Input::USE)
        press
      elsif Input.trigger?(Input::X)          # a controller's Y
        y_button
      elsif Input.trigger?(Input::A) && tab == :backups     # a controller's X
        check_backup
      end
      return nil
    end

    def move(dir)
      n = list.length
      return if n.zero?
      @sel = [[@sel + dir, 0].max, n - 1].min
      @save = @sel if tab == :active
      selection_moved
      refresh
    end

    def close_screen
      pbPlayCloseMenuSE
      return :close
    end

    def switch_tab(dir)
      target = (@tab + dir) % TABS.length
      return if target == @tab
      pbPlayCursorSE
      @tab = target
      @sel = tab == :active ? @save : 0
      @top = 0
      selection_moved
      refresh
    end

    # Backups tab, Left / Right: another save's backups.
    def other_save(dir)
      return pbPlayBuzzerSE if @saves.length < 2
      pbPlayCursorSE
      @save = (@save + dir) % @saves.length
      @backup_list = nil
      @sel = 0
      @top = 0
      selection_moved
      refresh
    end

    def press
      case tab
      when :active then active_options
      when :backups then restore_backup
      else deleted_options
      end
      return nil
    end

    def y_button
      case tab
      when :active then edit_note
      when :backups then name_backup
      else pbPlayBuzzerSE
      end
      return nil
    end

    #--------------------------------------------------------------------------
    # Active
    #--------------------------------------------------------------------------
    def active_options
      e = current
      return pbPlayBuzzerSE unless e
      pbPlayDecisionSE
      phone = Reloaded::Runtime.phone?
      labels = [_INTL("Edit Note"), _INTL("Color Tag"), _INTL("Check This Save"), _INTL("Backups"), _INTL("Back Up Now"),
                _INTL("Delete"), phone ? _INTL("Copy the Path") : _INTL("Open Folder")]
      descs = [_INTL("A note shown here and on the Load Screen."), _INTL("A color to tell your saves apart."),
               _INTL("A full check of the save, on a copy: What's missing, each mod's data, and more."),
               _INTL("Every backup of this save, to restore or name."),
               _INTL("A backup of the save as it is now, named so it's always kept."),
               _INTL("To the Deleted tab, with its backups. You can restore it from there."),
               phone ? _INTL("Where the game's saves are, copied to paste.") : _INTL("The game's save folder, in File Explorer.")]
      case Reloaded::Dialogs.menu(self, e[:slot], labels, descs)
      when 0 then edit_note
      when 1 then colour_tag
      when 2 then check_save(e)
      when 3 then switch_tab(1)
      when 4 then back_up_now(e)
      when 5 then delete_save(e)
      when 6 then open_folder
      end
      refresh
    end

    # The Save Checker on a save (its health badge, or Check This Save).
    def check_save(e)
      return pbPlayBuzzerSE unless e && defined?(Reloaded::SaveCheckScreen)
      pbPlayDecisionSE
      changed = hidden { Reloaded::SaveCheckScreen.open(e[:path], :slot => e[:slot]) }
      after_check(changed)
    end

    # Backups tab, X: the Save Checker on the selected backup (before
    # restoring it).
    def check_backup
      b = current
      e = save_entry
      return pbPlayBuzzerSE unless b && e && defined?(Reloaded::SaveCheckScreen)
      pbPlayDecisionSE
      changed = hidden { Reloaded::SaveCheckScreen.open(b[:path], :slot => e[:slot], :backup => true) }
      after_check(changed)
    end

    def after_check(changed)
      if changed
        @changed = true
        keep = @sel
        reload
        @sel = [[keep, list.length - 1].min, 0].max
        @save = @sel if tab == :active
      end
      selection_moved
      refresh
    end

    def edit_note
      e = current
      return pbPlayBuzzerSE unless e && tab == :active
      pbPlayDecisionSE
      text, how = Reloaded::TextEntry.run(self, _INTL("Type a Note"), S.note(e[:slot], e[:pv]), 100, :prompt => _INTL("{1}'s Note", e[:slot]))
      if how == :enter
        S.set_note(e[:slot], text, e[:pv])
        @changed = true
      end
      refresh
    end

    def colour_tag
      e = current
      names = S::TAGS.map { |n, _| _INTL(n) }
      now = S::TAGS.index { |n, _| n == S.tag(e[:slot], e[:pv]) } || 0
      Reloaded::Dialogs.swatches[:save_tags] ||= proc do |b, _c, x, y, h, i|
        rgb = S::TAGS[i] && S::TAGS[i][1]
        P.ui.rbox(b, x, y + 5, x + 6, y + h - 5, 2, rgb ? Color.new(*rgb) : Color.new(90, 90, 100))
        8
      end
      i = Reloaded::Dialogs.picker(self, _INTL("Color Tag"), names, now, :save_tags)
      return unless i
      S.set_tag(e[:slot], S::TAGS[i][0], e[:pv])
      @changed = true
    end

    def back_up_now(e)
      S.backup_now(e[:slot], _INTL("Kept {1}", Time.now.strftime("%b %-d %H.%M")))
      @backup_list = nil
      Reloaded::Dialogs.notice(self, _INTL("Back Up Now"), _INTL("{1} is backed up, named so it's always kept.", e[:slot]))
      @changed = true
    rescue StandardError => e2
      failed(_INTL("Back Up Now"), e2)
    end

    def delete_save(e)
      return playing(e[:slot]) if e[:slot].to_s == S.playing.to_s
      text = _INTL("{1} and its backups go to the Deleted tab. You can restore it from there.", e[:slot])
      return unless Reloaded::Dialogs.confirm(self, _INTL("Delete {1}?", e[:slot]), text, _INTL("Delete"), _INTL("Keep It"), false)
      S.archive(e[:slot])
      @changed = true
      reload
      @sel = [[@sel, @saves.length - 1].min, 0].max
      @save = @sel
      selection_moved
    rescue StandardError => e2
      failed(_INTL("Delete"), e2)
    end

    # On a phone (no File Explorer) the folder's path is copied instead
    def open_folder
      return copy_for_phone(File.expand_path(S.dir), _INTL("Where the game's saves are, ready to paste.")) if Reloaded::Runtime.phone?
      path = S.dir.tr("/", "\\")
      system("explorer \"#{path}\"")
    rescue StandardError
      pbPlayBuzzerSE
    end

    def playing(slot)
      Reloaded::Dialogs.notice(self, _INTL("Save Manager"),
        _INTL("{1} is the save you're playing. Do this from the title screen (the Load Screen's Save Manager).", slot))
    end

    def failed(title, e)
      Reloaded::Log.exception("Save Manager: #{title} failed", e, :saves)
      Reloaded::Dialogs.notice(self, title, _INTL("That didn't work: {1}", e.message))
    end

    #--------------------------------------------------------------------------
    # Backups
    #--------------------------------------------------------------------------
    def restore_backup
      b = current
      e = save_entry
      return pbPlayBuzzerSE unless b && e
      return playing(e[:slot]) if e[:slot].to_s == S.playing.to_s
      pbPlayDecisionSE
      text = _INTL("{1} goes back to this backup ({2}). The save as it is now is kept as a backup named Before Restore.",
                   e[:slot], when_text(b[:time]))
      return unless Reloaded::Dialogs.confirm(self, _INTL("Restore This Backup?"), text, _INTL("Restore"), _INTL("Cancel"), false)
      S.restore_backup(e[:slot], b)
      @changed = true
      reload
      @sel = 0
      selection_moved
      Reloaded::Dialogs.notice(self, _INTL("Restored"), _INTL("{1} is back as it was then.", e[:slot]))
    rescue StandardError => e2
      failed(_INTL("Restore"), e2)
    end

    def name_backup
      b = current
      return pbPlayBuzzerSE unless b
      pbPlayDecisionSE
      text, how = Reloaded::TextEntry.run(self, _INTL("Type a Name"), b[:name].to_s, 30, :prompt => _INTL("Backup Name"))
      if how == :enter && !text.strip.empty?
        S.name_backup(b, text)
        @backup_list = nil
        @changed = true
      end
      refresh
    rescue StandardError => e
      failed(_INTL("Name"), e)
    end

    #--------------------------------------------------------------------------
    # Deleted
    #--------------------------------------------------------------------------
    def deleted_options
      a = current
      return pbPlayBuzzerSE unless a
      pbPlayDecisionSE
      labels = [_INTL("Restore"), _INTL("Delete Forever"), _INTL("Delete Every One")]
      descs = [restore_words(a), _INTL("Gone for good, with its backups. This can't be undone."),
               _INTL("Every save in the Deleted tab, gone for good.")]
      case Reloaded::Dialogs.menu(self, a[:slot], labels, descs)
      when 0
        slot = S.restore_archive(a)
        @changed = true
        reload
        @sel = [[@sel, @archived.length - 1].min, 0].max
        Reloaded::Dialogs.notice(self, _INTL("Restored"), _INTL("It's back as {1}.", slot))
      when 1
        return unless Reloaded::Dialogs.confirm(self, _INTL("Delete Forever?"), _INTL("{1} and its backups are gone for good.", a[:slot]),
                                                _INTL("Delete"), _INTL("Keep It"), false)
        S.delete_archive(a)
        reload
        @sel = [[@sel, @archived.length - 1].min, 0].max
      when 2
        return unless Reloaded::Dialogs.confirm(self, _INTL("Delete Every One?"),
                                                _INTL("{1} deleted saves and their backups are gone for good.", @archived.length),
                                                _INTL("Delete"), _INTL("Keep Them"), false)
        @archived.each { |x| S.delete_archive(x) }
        reload
        @sel = 0
      end
      selection_moved
      refresh
    rescue StandardError => e
      failed(_INTL("Deleted Saves"), e)
    end

    # Where it would go back to.
    def restore_words(a)
      return _INTL("Back as {1}.", a[:slot]) unless File.file?(S.path(a[:slot]))
      free = S.free_slot
      return _INTL("{1} is taken, so it comes back as {2}.", a[:slot], free) if free
      return _INTL("Every File slot is taken: Delete one first.")
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
      paint_title(base, top, c)
      P.ui.rbox(base, LEFT_X0, PANEL_Y0, LEFT_X1, PANEL_Y1, 6, c[:panel])
      P.ui.rbox(base, RIGHT_X0, PANEL_Y0, RIGHT_X1, PANEL_Y1, 6, c[:panel2], c[:line])
      case tab
      when :active then paint_saves(base, top, c); paint_save(base, top, c, current)
      when :backups then paint_backups(base, top, c); paint_backup(base, top, c, current)
      else paint_archived(base, top, c); paint_archive(base, top, c, current)
      end
      paint_hints(base, c)
      place_cursor
    end

    def paint_title(base, top, c)
      base.fill_rect(0, 0, W, PANEL_Y0 - 4, c[:panel2])
      base.fill_rect(0, PANEL_Y0 - 5, W, 1, c[:line])
      P.text(top, 0, 0, W, 28, _INTL("Save Manager"), c[:title], PF::TITLE, 2)
      x = (W - TAB_W * 3 - 12) / 2
      @tab_hits = []
      TABS.each_with_index do |(_id, label), i|
        on = i == @tab
        P.ui.rbox(base, x, TAB_Y, x + TAB_W, TAB_Y + 18, 4, on ? c[:selb] : c[:dark], on ? c[:selb] : c[:line])
        P.text(top, x, TAB_Y - 1, TAB_W, 20, _INTL(label), on ? c[:dark] : c[:dim], nil, 2)
        @tab_hits << [i, x, TAB_Y, x + TAB_W, TAB_Y + 18]
        x += TAB_W + 6
      end
    end

    # The left list: rows of h, the selected one under the cursor.
    def each_row(entries)
      @row_hits = []
      @top = @sel if @sel < @top
      @top = @sel - fit + 1 if @sel >= @top + fit
      entries[@top, fit].to_a.each_with_index do |e, k|
        i = @top + k
        y = list_y + k * row_h
        @row_hits << [i, LEFT_X0 + 3, y, LEFT_X1 - 3, y + row_h - 3]
        @cursor_rect = [LEFT_X0 + 3, y, LEFT_X1 - LEFT_X0 - 6, row_h - 2] if i == @sel && !@entry
        yield e, y
      end
      return unless entries.length > fit
      track = PANEL_Y1 - list_y - 8
      bar = [track * fit / entries.length, 12].max
      pos = (track - bar) * @top / [entries.length - fit, 1].max
      @sprite.bitmap.fill_rect(LEFT_X1 - 5, list_y, 2, track, palette[:line])
      @sprite.bitmap.fill_rect(LEFT_X1 - 5, list_y + pos, 2, bar, palette[:dim])
    end

    def empty(top, c, text)
      P.text(top, LEFT_X0 + 10, LIST_Y + 2, LEFT_X1 - LEFT_X0 - 20, 22, PF.fit(PF::TEXT, text, LEFT_X1 - LEFT_X0 - 20), c[:dim])
    end

    def tag_bar(top, slot_tag, x, y, h)
      rgb = S.tag_rgb(slot_tag)
      P.ui.rbox(top, x, y, x + 4, y + h, 2, rgb ? Color.new(*rgb) : palette[:line])
    end

    def health_pill(top, health, right, y)
      label, tone = HEALTH[health] || HEALTH[:damaged]
      colr = palette[tone]
      return P.pill(top, right, y, _INTL(label), dark_fill(colr), colr)
    end

    def paint_saves(_base, top, c)
      return empty(top, c, _INTL("No save files yet.")) if @saves.empty?
      each_row(@saves) do |e, y|
        tag_bar(top, S.tag(e[:slot], e[:pv]), LEFT_X0 + 8, y + 4, row_h - 10)
        pw = health_pill(top, e[:pv][:health], LEFT_X1 - 8, y + 5)
        room = LEFT_X1 - 8 - pw - 6 - (LEFT_X0 + 18)
        P.text(top, LEFT_X0 + 18, y, room, 22, PF.fit(PF::ROW, e[:slot], room), c[:opt], PF::ROW)
        note = S.note(e[:slot], e[:pv])
        line = note.empty? ? _INTL("No Note") : note
        P.small(top, LEFT_X0 + 18, y + 22, LEFT_X1 - LEFT_X0 - 30, 16, fit_small(top, line, LEFT_X1 - LEFT_X0 - 30), note.empty? ? c[:dim] : palette[:gold])
      end
    end

    # The right panel's top: tag bar, name, and something on the right.
    def detail_head(top, c, title, right, colour = nil)
      P.text(top, RIGHT_X0 + 18, PANEL_Y0 + 3, RIGHT_X1 - RIGHT_X0 - 120, 24, PF.fit(PF::ROW, title.to_s, RIGHT_X1 - RIGHT_X0 - 120), colour || c[:opt], PF::ROW)
      P.text(top, RIGHT_X1 - 160, PANEL_Y0 + 5, 150, 20, right.to_s, c[:dim], nil, 1) if right
    end

    # label ... value lines from y; returns the y after them.
    def fields(top, c, y, rows)
      rows.each do |label, value, colour|
        P.text(top, RIGHT_X0 + 10, y, 120, 22, _INTL(label), c[:dim])
        P.text(top, RIGHT_X0 + 120, y, RIGHT_X1 - RIGHT_X0 - 130, 22, PF.fit(PF::TEXT, value.to_s, RIGHT_X1 - RIGHT_X0 - 130), colour || c[:txt], nil, 1)
        y += 22
      end
      return y
    end

    def paint_save(base, top, c, e)
      return unless e
      pv = e[:pv]
      tg = S.tag(e[:slot], pv)
      tag_bar(top, tg, RIGHT_X0 + 8, PANEL_Y0 + 8, 18)
      detail_head(top, c, e[:slot], tg ? _INTL("Tag: {1}", _INTL(tg)) : nil)
      y = fields(top, c, PANEL_Y0 + 32, [["Trainer", pv[:name] || "?", pv[:gender] == :female ? palette[:pink] : palette[:blue]],
                                          ["Location", pv[:map] || "?", palette[:green]], ["Saved", when_text(pv[:saved_at] || File.mtime(e[:path]))],
                                          ["Play Time", play_time(pv[:seconds]), palette[:gold]]])
      y += 74                                   # the party's row (PARTY_Y)
      P.text(top, RIGHT_X0 + 10, y, 120, 14, _INTL("NOTES"), c[:head], PF::TINY)
      keyw = Reloaded::ButtonIcons.width(button(:X), Reloaded::Prompts.style)
      P.text(top, RIGHT_X1 - 50, y, 40, 14, _INTL("EDIT"), c[:dim], PF::TINY, 1)
      Reloaded::ButtonIcons.draw(top, RIGHT_X1 - 56 - keyw, y - 2, button(:X), c, Reloaded::Prompts.style)
      base.fill_rect(RIGHT_X0 + 10, y + 15, RIGHT_X1 - RIGHT_X0 - 20, 1, c[:line])
      if @entry
        Reloaded::TextEntry.draw_field(base, top, c, @entry, RIGHT_X0 + 10, y + 20, RIGHT_X1 - RIGHT_X0 - 20, 23)
      else
        note = S.note(e[:slot], pv)
        lines = note.empty? ? [_INTL("No note yet. Y writes one.")] : P.small_wrap(top, note, RIGHT_X1 - RIGHT_X0 - 24).first(2)
        lines.each_with_index { |ln, k| P.small(top, RIGHT_X0 + 10, y + 20 + k * 16, RIGHT_X1 - RIGHT_X0 - 20, 16, ln, note.empty? ? c[:dim] : c[:txt]) }
      end
      banner(base, top, c, *save_banner(e))
    end

    # [title, line under it, colour]
    def save_banner(e)
      pv = e[:pv]
      n = S.backups(e[:slot]).length
      keep = S.cap ? _INTL("KEEPING {1}", S.cap) : _INTL("KEEPING UNLIMITED")
      sub = _INTL("{1} BACKUPS · {2}", n, keep)
      return [_INTL("You're Playing This Save"), sub, palette[:blue]] if e[:slot].to_s == S.playing.to_s
      case pv[:health]
      when :healthy then return [_INTL("Healthy"), sub, palette[:green]]
      when :check then return [_INTL("Check: {1}", pv[:problem].to_s), sub, palette[:amber]]
      end
      good = S.newest_good_backup(e[:slot])
      line = good ? _INTL("NEWEST GOOD BACKUP: {1}", when_text(good[:time]).upcase) : _INTL("NO GOOD BACKUP")
      return [_INTL("Damaged: {1}", pv[:problem].to_s), line, palette[:red]]
    end

    def banner(base, top, c, title, sub, colour)
      y0 = PANEL_Y1 - 48
      P.ui.rbox(base, RIGHT_X0 + 10, y0, RIGHT_X1 - 10, PANEL_Y1 - 8, 5, dark_fill(colour, 6), colour)
      w = RIGHT_X1 - RIGHT_X0 - 36
      P.text(top, RIGHT_X0 + 18, y0 + 1, w, 22, PF.fit(PF::TEXT, title, w), colour, nil, 2)
      P.text(top, RIGHT_X0 + 18, y0 + 22, w, 14, sub.to_s, c[:dim], PF::TINY, 2)
    end

    def paint_backups(base, top, c)
      e = save_entry
      return empty(top, c, _INTL("No save files yet.")) unless e
      note = S.note(e[:slot], e[:pv])
      head = note.empty? ? e[:slot] : "#{e[:slot]}: #{note}"
      P.heading(top, LEFT_X0 + 10, LEFT_X1 - 10, PANEL_Y0 + 5, P.pf.fit(P.pf::TINY, head.upcase, LEFT_X1 - LEFT_X0 - 40), c[:head], c[:line])
      return P.text(top, LEFT_X0 + 10, BACKUP_LIST_Y + 2, 200, 22, _INTL("No backups yet."), c[:dim]) if backups.empty?
      each_row(backups) do |b, y|
        P.text(top, LEFT_X0 + 12, y, LEFT_X1 - LEFT_X0 - 24, 20, when_text(b[:time]), c[:opt])
        sub, colour = if b[:name] then ["\"#{b[:name]}\"", palette[:gold]]
                      elsif b[:pv] then [b[:pv][:map] || b[:pv][:problem].to_s, b[:pv][:health] == :damaged ? palette[:red] : c[:dim]]
                      else ["...", c[:dim]]
                      end
        sub = "#{sub} (#{_INTL("Autosave")})" if b[:auto] && !b[:name]
        P.small(top, LEFT_X0 + 12, y + 18, LEFT_X1 - LEFT_X0 - 24, 15, fit_small(top, sub, LEFT_X1 - LEFT_X0 - 28), colour)
      end
    end

    def paint_backup(base, top, c, b)
      return unless b
      pv = b[:pv] || S.preview(b[:path], :party => false)
      b[:pv] ||= pv
      title = b[:name] ? _INTL("Backup: {1}", b[:name]) : _INTL("Backup")
      P.text(top, RIGHT_X0, PANEL_Y0 + 3, RIGHT_X1 - RIGHT_X0, 24, PF.fit(PF::ROW, title, RIGHT_X1 - RIGHT_X0 - 16), b[:name] ? palette[:gold] : c[:opt], PF::ROW, 2)
      label, tone = HEALTH[pv[:health]] || HEALTH[:damaged]
      colour = palette[tone]
      fields(top, c, PANEL_Y0 + 32, [["Saved", when_text(b[:time])], ["Location", pv[:map] || "?", palette[:green]],
                                     ["Play Time", play_time(pv[:seconds]), palette[:gold]], ["Health", _INTL(label.capitalize), colour]])
      cap = S.cap ? _INTL("BACKUP CAP: {1} (NAMED ONES ARE KEPT)", S.cap) : _INTL("BACKUP CAP: UNLIMITED (NAMED ONES ARE KEPT)")
      P.text(top, RIGHT_X0, PANEL_Y1 - 66, RIGHT_X1 - RIGHT_X0, 14, cap, c[:dim], PF::TINY, 2)
      bw = 110
      gap = 12
      x = RIGHT_X0 + (RIGHT_X1 - RIGHT_X0 - bw * 2 - gap) / 2
      y = PANEL_Y1 - 44
      P.ui.rbox(base, x, y, x + bw, y + 26, 5, c[:selb])
      P.text(top, x, y + 1, bw, 24, _INTL("Restore"), c[:dark], PF::ROW, 2)
      P.ui.rbox(base, x + bw + gap, y, x + bw * 2 + gap, y + 26, 5, c[:dark], c[:line])
      P.text(top, x + bw + gap, y + 1, bw, 24, _INTL("Name"), c[:txt], PF::ROW, 2)
      if @entry
        Reloaded::TextEntry.draw_field(base, top, c, @entry, RIGHT_X0 + 10, PANEL_Y1 - 96, RIGHT_X1 - RIGHT_X0 - 20, 23)
      end
    end

    def paint_archived(_base, top, c)
      return empty(top, c, _INTL("No deleted saves.")) if @archived.empty?
      each_row(@archived) do |a, y|
        tag_bar(top, a[:tag], LEFT_X0 + 8, y + 4, row_h - 10)
        P.text(top, LEFT_X0 + 18, y, LEFT_X1 - LEFT_X0 - 28, 22, a[:slot], c[:opt], PF::ROW)
        P.small(top, LEFT_X0 + 18, y + 22, LEFT_X1 - LEFT_X0 - 30, 16, _INTL("Deleted {1}", when_text(a[:archived_at])), c[:dim])
      end
    end

    def paint_archive(base, top, c, a)
      return unless a
      pv = a[:file] ? S.preview(a[:file], :party => false) : {}
      tag_bar(top, a[:tag], RIGHT_X0 + 8, PANEL_Y0 + 8, 18)
      detail_head(top, c, a[:slot], a[:tag] ? _INTL("Tag: {1}", _INTL(a[:tag])) : nil)
      y = fields(top, c, PANEL_Y0 + 32, [["Trainer", pv[:name] || a[:name] || "?", palette[:blue]], ["Location", pv[:map] || a[:map] || "?", palette[:green]],
                                          ["Play Time", play_time(pv[:seconds] || a[:seconds]), palette[:gold]], ["Deleted", when_text(a[:archived_at])]])
      y += 74                                   # the party's row (PARTY_Y)
      if a[:note].to_s != ""
        P.text(top, RIGHT_X0 + 10, y, 120, 14, _INTL("NOTES"), c[:head], PF::TINY)
        base.fill_rect(RIGHT_X0 + 10, y + 15, RIGHT_X1 - RIGHT_X0 - 20, 1, c[:line])
        P.small_wrap(top, a[:note].to_s, RIGHT_X1 - RIGHT_X0 - 24).first(2).each_with_index do |ln, k|
          P.small(top, RIGHT_X0 + 10, y + 20 + k * 16, RIGHT_X1 - RIGHT_X0 - 20, 16, ln, c[:txt])
        end
      end
      words = restore_words(a)
      colour = words.start_with?(_INTL("Back as")) ? palette[:green] : (S.free_slot ? palette[:amber] : palette[:red])
      banner(base, top, c, words, _INTL("A: RESTORE / DELETE FOREVER"), colour)
    end

    #--------------------------------------------------------------------------
    # Words
    #--------------------------------------------------------------------------
    # "Today 3:42 PM", "Yesterday", "Oct 15"
    def when_text(time)
      return "?" unless time.is_a?(Time)
      clock = time.strftime("%l:%M %p").strip
      today = Time.now
      return _INTL("Today {1}", clock) if same_day?(time, today)
      return _INTL("Yesterday {1}", clock) if same_day?(time, today - 86_400)
      return time.strftime("%b %-d") if time.year == today.year
      return time.strftime("%b %-d %Y")
    end

    def same_day?(a, b)
      return a.year == b.year && a.yday == b.yday
    end

    # "41:12" (hours:minutes)
    def play_time(seconds)
      return "?" unless seconds
      return format("%d:%02d", seconds.to_i / 3600, seconds.to_i / 60 % 60)
    end

    def fit_small(b, text, w)
      P.small_font(b)
      return text if b.text_size(text).width <= w
      text = text[0...-1] while text.length > 1 && b.text_size(text + "...").width > w
      return text + "..."
    end

    def hint_pairs
      back = button(:B)
      tabs = [Reloaded::Prompts.input(:L) || button(:L), _INTL("Tabs")]
      if @entry
        return [[button(:C), _INTL("Type")], [back, _INTL("Cancel")]] if Reloaded::Prompts.controller?
        return [[nil, _INTL("Type")], [Reloaded::Controls::Inputs.key(40), _INTL("Done")], [Reloaded::Controls::Inputs.key(41), _INTL("Cancel")]]
      end
      case tab
      when :active
        return [[:ud, _INTL("Choose")], [button(:C), _INTL("Options"), :press], [button(:X), _INTL("Note"), :y_button], tabs,
                [back, _INTL("Close"), :close_screen]]
      when :backups
        out = [[:ud, _INTL("Choose")]]
        out << [:lr, _INTL("Save")] if @saves.length > 1
        return out + [[button(:C), _INTL("Restore"), :press], [button(:X), _INTL("Name"), :y_button], [button(:A), _INTL("Check"), :check_backup],
                      tabs, [back, _INTL("Back"), :close_screen]]
      end
      return [[:ud, _INTL("Choose")], [button(:C), _INTL("Options"), :press], tabs, [back, _INTL("Close"), :close_screen]]
    end
  end
end
