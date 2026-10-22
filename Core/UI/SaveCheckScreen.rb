#==============================================================================
# Kanto Reloaded: the Save Checker's screens
#==============================================================================
# The report card (design 2, Report Card) and its pages, in Kanto
# Reloaded's look:
#
#   Report           the verdict, then the six checks. A opens a check
#                    (Missing Content and Mod Data are pages of their own,
#                    the rest say more in a box); X: Fix Safely; Save the
#                    Report
#   Missing Content  (design 1) each Pokémon, item, move and ability the
#                    game hasn't got, where it is and its fix; A changes the
#                    fix (Keep Aside, Remove); X: Fix All Safely
#   Mod Data         (design 1) each mod with data in the save, its size,
#                    NEEDED TO LOAD or SAFE TO REMOVE; A: what it keeps in
#                    the save; Make It Loadable when a mod the save needs
#                    isn't installed, else Back Up Now
#   Inspector        with KIF's DEBUG option on, A on what a mod keeps:
#                    its save values as a tree (SaveInspector, read-only)
#
#   Reloaded::SaveCheckScreen.open(path)                    # a save
#   Reloaded::SaveCheckScreen.open(path, :backup => true)   # a backup
# Returns true when the save changed (a fix).
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont) && defined?(Reloaded::SaveCheck)

module Reloaded
  class SaveCheckScreen
    include Reloaded::Frame

    PF = ::KIF::PixelFont
    P = Reloaded::Pixel
    SC = Reloaded::SaveCheck
    GREEN = Color.new(120, 230, 150)
    RED   = Color.new(240, 100, 90)
    AMBER = Color.new(240, 170, 60)
    GOLD  = Color.new(240, 200, 80)
    STATE = { :ok => GREEN, :note => AMBER, :problem => RED, :damaged => RED }.freeze
    X0 = 8
    X1 = W - 8
    BANNER_Y = 38
    BANNER_H = 38
    LIST_Y0 = 84
    BTN_H = 28
    BTN_Y = H - P::HINT_H - BTN_H - 6
    LIST_Y1 = BTN_Y - 6
    ROW_H = { :report => 38, :missing => 46, :mods => 52, :mod => 40 }.freeze
    MOD_TILES = [[214, 52, 60], [120, 150, 235], [170, 110, 220], [235, 150, 60], [90, 190, 150], [230, 120, 180]].freeze

    attr_reader :changed

    def self.open(path, slot: nil, backup: false)
      return new(path, slot, backup).main
    end

    def initialize(path, slot = nil, backup = false)
      frame_init
      @path = path
      @slot = slot
      @backup = backup
      @mode = :report
      @sel = 0
      @top = 0
      @stack = []
      @changed = false
    end

    def main
      open_sprites
      checking
      run_check
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        break if handle_input == :close
      end
      return @changed
    ensure
      dispose_sprites
    end

    def refresh
      draw_screen if @sprite && !@sprite.disposed?
    end

    # For tests: the report shown, and the page.
    attr_reader :report, :mode

    private

    #--------------------------------------------------------------------------
    # The check
    #--------------------------------------------------------------------------
    # "Checking File A..." while the file's read (a big save takes a moment).
    def checking
      c = palette
      base = @sprite.bitmap
      base.clear
      @top_sprite.bitmap.clear
      base.fill_rect(0, 0, W, H, c[:bg])
      P.text(@top_sprite.bitmap, 0, H / 2 - 14, W, 28, _INTL("Checking {1} on a copy...", @slot || SC.slot_of(@path)), c[:dim], nil, 2)
      Graphics.update
    end

    def run_check
      @report = SC.run(@path, :slot => @slot, :backup => @backup)
      @slot ||= @report.slot
      @mod = @report.mods.find { |m| m.name == @mod.name } if @mod
      if @mode == :mod && !@mod
        @mode = :mods
        @stack.pop
      end
      if @mode == :missing && @report.missing.empty?
        @mode = :report
        @stack.clear
        @sel = 0
      end
      @sel = [[@sel, total - 1].min, 0].max
    end

    #--------------------------------------------------------------------------
    # What's on the page
    #--------------------------------------------------------------------------
    def rows
      case @mode
      when :report then return @report.checks
      when :missing then return @report.missing
      when :mods then return @report.mods
      else return mod_lines(@mod)
      end
    end

    # [[id, label]]
    def buttons
      case @mode
      when :report then return [[:fix, _INTL("Fix Safely")], [:save_report, _INTL("Save the Report")]]
      when :missing then return [[:fix, _INTL("Fix All Safely")], [:save_report, _INTL("Save the Report")]]
      end
      first = blocked.empty? ? [:back_up, _INTL("Back Up Now")] : [:make_loadable, _INTL("Make It Loadable")]
      return [first, [:save_report, _INTL("Save the Report")]]
    end

    def total
      return rows.length + buttons.length
    end

    def on_button?
      return @sel >= rows.length
    end

    def row_h
      return ROW_H[@mode]
    end

    def list_top
      return @mode == :mod ? LIST_Y0 + 16 : LIST_Y0
    end

    def fit
      return [(LIST_Y1 - 4 - list_top) / row_h, 1].max
    end

    # Mods a save needs that aren't installed (Make It Loadable's).
    def blocked
      return @report.mods.select { |m| m.needed && m.installed != true && !m.kr }
    end

    # What a mod keeps in the save, as lines: [state, title, under, right, right colour]
    def mod_lines(m)
      return [] unless m
      out = []
      holds = m.classes.values.flatten
      m.keys.each do |k|
        state = if !holds.include?(k) then :ok
                elsif m.installed == true then :note
                else :problem
                end
        under = if m.kr then _INTL("Its parts, plain values only.")
                elsif state == :ok then _INTL("Its own save value, plain values only.")
                else _INTL("Its own save value, with its objects in it.")
                end
        out << [state, ":#{k}", under, SC.size_words((m.bytes.to_f / [m.keys.length, 1].max).to_i), STATE[state]]
      end
      m.classes.each do |name, places|
        where = places.map { |p| place_words(p) }.uniq
        state = m.installed == true ? :note : :problem
        out << [state, name, _INTL("In {1}.", SC.join_words(where)), _INTL("Object"), state == :problem ? RED : AMBER]
      end
      m.added.each do |kind, id, n|
        under = _INTL("Becomes Missing Content without {1}.", m.name)
        right = n > 1 ? "#{SC.kind_words(kind)} ×#{n}" : SC.kind_words(kind)
        out << [:note, SC::Content.words(id), under, right, GOLD]
      end
      return out
    end

    def place_words(key)
      case key
      when :player then return _INTL("your trainer")
      when :bag then return _INTL("the Bag")
      when :storage_system then return _INTL("the PC")
      when :global_metadata then return _INTL("the game's data")
      end
      owner = SC::ModData.key_owner(key)
      return owner == :game ? _INTL("the game's data") : _INTL("{1}'s save value", owner)
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      pt = Reloaded::Pointer
      if pointer_hover && (i = pt.hit(@row_hits)) && i != @sel
        select(i)
      end
      return back if pt.right? || Input.trigger?(Input::BACK)
      if pt.left?
        handled, result = hint_click
        return result if handled
        if (i = pt.hit(@row_hits))
          @sel = i
          press
        end
        return nil
      end
      if (dir = pt.wheel) != 0
        select([[@sel + dir, 0].max, total - 1].min)
        return nil
      end
      if Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        step(Input.repeat?(Input::DOWN) ? 1 : -1)
      elsif on_button? && (Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT))
        b = (@sel - rows.length + (Input.trigger?(Input::RIGHT) ? 1 : -1)) % buttons.length
        select(rows.length + b)
      elsif Input.trigger?(Input::USE)
        press
      elsif Input.trigger?(Input::A)          # a controller's X
        do_button(buttons[0][0])
      end
      return nil
    end

    # Down from the last row goes to the buttons; Up from them comes back.
    def step(dir)
      nr = rows.length
      if on_button?
        return select(nr - 1) if dir < 0 && nr > 0
        return nil unless fresh?(dir)
        return select(0)
      end
      target = @sel + dir
      if target < 0
        return nil unless fresh?(dir)
        target = nr
      end
      select([target, nr].min)
    end

    def select(i)
      return if i == @sel
      @sel = i
      pbPlayCursorSE
      refresh
    end

    def back
      pbPlayCancelSE
      return :close if @stack.empty?
      @mode, @sel, @top, @mod = @stack.pop
      refresh
      return nil
    end

    def open_page(mode, mod = nil)
      pbPlayDecisionSE
      @stack << [@mode, @sel, @top, @mod]
      @mode = mode
      @mod = mod
      @sel = 0
      @top = 0
      refresh
    end

    def press
      return do_button(buttons[@sel - rows.length][0]) if on_button?
      row = rows[@sel]
      return pbPlayBuzzerSE unless row
      case @mode
      when :report
        if row.id == :missing && !@report.missing.empty? then open_page(:missing)
        elsif row.id == :mods && !@report.mods.empty? then open_page(:mods)
        else
          pbPlayDecisionSE
          text = row.details.to_s.empty? ? row.line.to_s : row.details.to_s
          Reloaded::Dialogs.notice(self, row.title, text.gsub(/^- /, "• "))
          refresh
        end
      when :missing then change_fix(row)
      when :mods then open_page(:mod, row)
      else
        inspect_here? ? inspect : pbPlayBuzzerSE
      end
      return nil
    end

    def do_button(id)
      case id
      when :fix then fix_safely
      when :save_report then save_report
      when :back_up then back_up
      when :make_loadable then make_loadable
      end
      refresh
      return nil
    end

    #--------------------------------------------------------------------------
    # Actions
    #--------------------------------------------------------------------------
    def fix_safely
      if @report.state == :damaged
        return notice(_INTL("Fix Safely"), _INTL("It can't be read, so it can't be fixed here. Its newest backup that reads whole is the way back: The Save Manager's Backups tab, or hold A on Continue."))
      end
      plan = @report.missing.select(&:fixable)
      if plan.empty?
        text = blocked.empty? ? _INTL("Nothing here needs Fix Safely.") : _INTL("Nothing here for Fix Safely. To load it without a mod that's gone, use Make It Loadable in Mod Data.")
        return notice(_INTL("Fix Safely"), text)
      end
      why = SC::Fix.refusal(@report)
      return notice(_INTL("Fix Safely"), why) if why
      kept = plan.count { |m| m.fix == :keep }
      parts = []
      parts << _INTL("{1} kept aside", kept) if kept > 0
      parts << _INTL("{1} removed", plan.length - kept) if plan.length > kept
      text = _INTL("{1}, after a backup named Before Save Check.", SC.join_words(parts))
      leaving = plan.select { |m| m.kind == :pokemon && m.party && m.fix == :keep }.map(&:name)
      text += " " + _INTL("{1} leaves the party.", SC.join_words(leaving)) unless leaving.empty?
      return unless Reloaded::Dialogs.confirm(self, _INTL("Fix Safely?"), text, _INTL("Fix"), _INTL("Cancel"), true)
      done = SC::Fix.content(@report, plan)
      @changed = true
      run_check
      notice(_INTL("Fixed"), _INTL("{1} kept aside and {2} removed. What's kept aside comes back when the game has it again.", done[:kept], done[:removed]))
    rescue StandardError => e
      failed(_INTL("Fix Safely"), e)
    end

    def save_report
      file = SC.write_report(@report)
      phone = Reloaded::Runtime.phone?        # no File Explorer: the path is copied instead
      choice = Reloaded::Dialogs.buttons_dialog(self, _INTL("Report Saved"),
                 _INTL("Saved as {1} in Kanto Reloaded's Logs, Save Checks folder.", File.basename(file)),
                 [phone ? _INTL("Copy the Path") : _INTL("Open Folder"), _INTL("OK")], 1)
      return unless choice == 0
      return copy_for_phone(File.expand_path(file), _INTL("Where the report is, ready to paste.")) if phone
      system("explorer \"#{File.dirname(file).tr("/", "\\")}\"")
    rescue StandardError => e
      failed(_INTL("Save the Report"), e)
    end

    def back_up
      return notice(_INTL("Back Up Now"), _INTL("This is a backup already.")) if @backup
      Reloaded::Saves.backup_now(@slot, _INTL("Kept {1}", Time.now.strftime("%b %-d %H.%M")))
      @changed = true
      notice(_INTL("Back Up Now"), _INTL("{1} is backed up, named so it's always kept.", @slot))
    rescue StandardError => e
      failed(_INTL("Back Up Now"), e)
    end

    def make_loadable
      why = SC::Fix.refusal(@report)
      return notice(_INTL("Make It Loadable"), why) if why
      names = SC.join_words(blocked.map(&:name))
      text = _INTL("A backup first, then {1} is written without {2}'s data, so it loads. To have it back, reinstall {2} and restore the backup named Before Make It Loadable.", @slot, names)
      return unless Reloaded::Dialogs.confirm(self, _INTL("Make It Loadable?"), text, _INTL("Make It Loadable"), _INTL("Cancel"), false)
      done = SC::Fix.make_loadable(@report)
      @changed = true
      run_check
      notice(_INTL("Loadable"), _INTL("{1} loads now. What was set aside is in Kanto Reloaded's Set Aside folder too.", @slot))
    rescue StandardError => e
      failed(_INTL("Make It Loadable"), e)
    end

    def change_fix(m)
      unless m.fixable
        return notice(m.name, _INTL("It's in {1}, so it stays where it is: Its mod looks after it.", m.where.sub(/\AIn /, "").sub(/\.\z/, "")))
      end
      pbPlayDecisionSE
      keep = case m.kind
             when :move then _INTL("Recommended. Kept, and taught back when the game has it again.")
             when :ability then _INTL("Recommended. Kept, and given back when the game has it again.")
             else _INTL("Recommended. Kept in the save, and back when the game has it again.")
             end
      keep += " " + _INTL("It leaves the party.") if m.kind == :pokemon && m.party
      remove = m.kind == :move ? _INTL("Forgotten for good (a backup is kept).") : _INTL("Gone for good (a backup is kept).")
      i = Reloaded::Dialogs.menu(self, _INTL("{1}: Fix", m.name), [_INTL("Keep Aside"), _INTL("Remove")], [keep, remove], m.fix == :remove ? 1 : 0)
      m.fix = i == 1 ? :remove : :keep if i
      refresh
    end

    def inspect_here?
      return Reloaded.debug? && @mode == :mod && !@mod.nil? && !@mod.keys.empty?
    end

    # The Inspector, on the mod's save values (read again, stand-ins and all).
    def inspect
      pbPlayDecisionSE
      keys = @mod.keys
      SC::Reader.open(@path) do |data, _missing|
        root = {}
        keys.each { |k| root[k] = data[k] }
        hidden { SaveInspector.new(@mod.name, root).main }
      end
      refresh
    rescue StandardError => e
      failed(_INTL("Inspector"), e)
    end

    def notice(title, text)
      Reloaded::Dialogs.notice(self, title, text)
      refresh
      return nil
    end

    def failed(title, e)
      Reloaded::Log.exception("Save Check: #{title} failed", e, :saves)
      notice(title, _INTL("That didn't work: {1}", e.message))
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
      @row_hits = []
      paint_title(base, top, c)
      paint_banner(base, top, c)
      P.ui.rbox(base, X0, LIST_Y0 - 4, X1, LIST_Y1, 6, c[:panel])
      P.heading(top, X0 + 10, X1 - 10, LIST_Y0, _INTL("What It Keeps in This Save"), c[:head], c[:line]) if @mode == :mod
      each_row do |row, y, on|
        case @mode
        when :report then paint_check(top, c, row, y, on)
        when :missing then paint_missing(base, top, c, row, y, on)
        when :mods then paint_mod(base, top, c, row, y, on)
        else paint_line(top, c, row, y, on)
        end
      end
      paint_footnote(top, c) if @mode == :missing
      paint_buttons(base, top, c)
      paint_hints(base, c)
      place_cursor
    end

    def paint_title(base, top, c)
      paint_title_bar(base, c)
      rgb = Reloaded::Saves.tag_rgb(Reloaded::Saves.tag(@slot.to_s)) rescue nil
      P.ui.rbox(top, 8, 8, 12, 24, 2, rgb ? Color.new(*rgb) : c[:line])
      P.text(top, 18, 2, 130, 26, PF.fit(PF::ROW, @slot.to_s, 130), c[:txt], PF::ROW)
      P.text(top, 0, 1, W, 28, _INTL("Save Check"), c[:title], PF::TITLE, 2)
      right = case @mode
              when :report then @backup ? _INTL("A Backup, on a Copy") : _INTL("Checked on a Copy")
              when :missing then _INTL("Missing Content")
              when :mods then _INTL("Mod Data")
              else @mod.name.to_s
              end
      P.text(top, W - 190, 6, 182, 20, PF.fit(PF::TEXT, right, 182), c[:dim], nil, 1)
    end

    # [title, line under it, colour] for the page.
    def banner_words
      case @mode
      when :report
        return [@report.verdict.to_s, @report.sub.to_s, STATE[@report.state] || RED]
      when :missing
        list = @report.missing
        colour = list.any? { |m| m.kind == :move } ? RED : AMBER
        return [_INTL("{1} Missing", title_counts(list)), _INTL("The game doesn't have them now. Keep Aside saves them."), colour]
      when :mods
        mods = @report.mods
        needed = mods.select(&:needed)
        n = mods.length == 1 ? _INTL("1 Mod") : _INTL("{1} Mods", mods.length)
        unless blocked.empty?
          return [_INTL("{1}, {2} Needed to Load", n, needed.length), _INTL("{1} can't load without {2}. Make It Loadable can fix that.", @slot, SC.join_words(blocked.map(&:name))), RED]
        end
        unless needed.empty?
          return [_INTL("{1}, {2} Needed to Load", n, needed.length), _INTL("{1} can't load without {2}. The others are safe to remove.", @slot, SC.join_words(needed.map(&:name))), AMBER]
        end
        return [_INTL("{1}, All Safe to Remove", n), _INTL("Each one keeps plain values only: Its data waits in the save."), GREEN]
      end
      m = @mod
      if m.needed
        return [_INTL("{1}: Needed to Load", m.name), _INTL("Keep {1} installed while you play this save.", m.name), AMBER] if m.installed == true
        return [_INTL("{1}: Needed to Load", m.name), _INTL("{1} can't load without it. Make It Loadable fixes that.", @slot), RED]
      end
      return [_INTL("{1}: Safe to Remove", m.name), m.kr ? _INTL("Plain values only. Its .kr copy brings the data back when it's installed again.") : _INTL("Plain values only. Its data waits in the save."), GREEN]
    end

    def paint_banner(base, top, c)
      title, sub, colour = banner_words
      P.ui.rbox(base, X0, BANNER_Y, X1, BANNER_Y + BANNER_H, 6, Color.new(colour.red / 6, colour.green / 6, colour.blue / 6), colour)
      w = X1 - X0 - 20
      P.text(top, X0 + 10, BANNER_Y - 2, w, 24, PF.fit(PF::ROW, title, w), colour, PF::ROW)
      P.small(top, X0 + 10, BANNER_Y + 20, w, 16, fit_small(top, sub, w), c[:txt])
    end

    # "2 Pokémon and 1 Item"
    def title_counts(list)
      parts = []
      { :pokemon => ["Pokémon", "Pokémon"], :item => ["Item", "Items"], :move => ["Move", "Moves"], :ability => ["Ability", "Abilities"] }.each do |kind, (one, many)|
        n = list.count { |m| m.kind == kind }
        parts << "#{n} #{_INTL(n == 1 ? one : many)}" if n > 0
      end
      return SC.join_words(parts)
    end

    # The rows that fit, the cursor on the selected one, and a scrollbar.
    def each_row
      list = rows
      @top = @sel if @sel < @top && @sel < list.length
      @top = @sel - fit + 1 if @sel < list.length && @sel >= @top + fit
      @top = [[@top, list.length - fit].min, 0].max
      list[@top, fit].to_a.each_with_index do |row, k|
        i = @top + k
        y = list_top + k * row_h
        on = i == @sel
        @row_hits << [i, X0 + 3, y, X1 - 3, y + row_h - 2]
        @cursor_rect = [X0 + 3, y, X1 - X0 - 6, row_h - 2] if on
        yield row, y, on
      end
      return unless list.length > fit
      track = LIST_Y1 - 6 - list_top
      bar = [track * fit / list.length, 12].max
      pos = (track - bar) * @top / [list.length - fit, 1].max
      @sprite.bitmap.fill_rect(X1 - 5, list_top, 2, track, palette[:line])
      @sprite.bitmap.fill_rect(X1 - 5, list_top + pos, 2, bar, palette[:dim])
    end

    # A circle: a tick (OK) or ! (a note, a problem).
    def status_icon(b, x, y, state, c)
      colour = STATE[state] || RED
      P.ui.rbox(b, x, y, x + 17, y + 17, 9, Color.new(colour.red / 4, colour.green / 4, colour.blue / 4), colour)
      if state == :ok
        [[4, 9], [5, 10], [6, 11], [7, 10], [8, 9], [9, 8], [10, 7], [11, 6], [12, 5]].each { |dx, dy| b.fill_rect(x + dx, y + dy, 2, 2, colour) }
      else
        b.fill_rect(x + 8, y + 4, 2, 6, colour)
        b.fill_rect(x + 8, y + 12, 2, 2, colour)
      end
    end

    def paint_check(top, c, row, y, on)
      status_icon(top, X0 + 10, y + 10, row.state, c)
      w = X1 - X0 - 56
      P.text(top, X0 + 36, y - 2, w, 24, PF.fit(PF::ROW, row.title, w), c[:txt], PF::ROW)
      P.small(top, X0 + 36, y + 19, w, 16, fit_small(top, row.line.to_s, w), on ? c[:txt] : c[:dim])
    end

    def kind_line(m)
      case m.kind
      when :pokemon then return _INTL("Pokémon")
      when :item then return m.qty.to_i > 1 ? _INTL("Item ×{1}", m.qty) : _INTL("Item")
      when :move then return _INTL("Move")
      else return _INTL("Ability")
      end
    end

    def paint_missing(base, top, c, m, y, on)
      red = m.party || m.kind == :move
      status_icon(top, X0 + 8, y + 13, red ? :problem : :note, c)
      P.ui.rbox(top, X0 + 32, y + 9, X0 + 55, y + 34, 4, c[:dark], c[:line])
      P.text(top, X0 + 32, y + 9, 24, 24, "?", c[:dim], PF::ROW, 2)
      P.text(top, X0 + 62, y, 150, 24, PF.fit(PF::ROW, m.name.to_s, 150), c[:txt], PF::ROW)
      P.small(top, X0 + 62, y + 22, 150, 16, kind_line(m), c[:dim])
      mx = X0 + 218
      mw = X1 - 112 - mx
      lines = P.small_wrap(top, m.where.to_s, mw).first(2)
      lines.each_with_index { |ln, k| P.small(top, mx, y + 6 + k * 15, mw, 16, ln, m.party ? RED : c[:txt]) }
      P.small(top, mx, y + 6 + lines.length * 15, mw, 16, _INTL("Can crash a battle."), RED) if m.kind == :move && lines.length < 2
      label, colour = if !m.fixable then [_INTL("Its Mod's"), c[:dim]]
                      elsif m.fix == :remove then [_INTL("Remove"), RED]
                      else [_INTL("Keep Aside"), c[:txt]]
                      end
      P.text(top, X1 - 112, y + 9, 100, 24, label, colour, PF::ROW, 1)
    end

    # Under the list: what Keep Aside does to a party member.
    def paint_footnote(top, c)
      list = @report.missing
      return if list.length > fit
      pk = list.find { |m| m.kind == :pokemon && m.party && m.fix == :keep && m.fixable }
      return unless pk
      y = list_top + list.length * row_h + 6
      P.small(top, X0 + 14, y, X1 - X0 - 28, 16, _INTL("{1} is in the party, so Keep Aside moves it out.", pk.name), RED)
    end

    def paint_mod(base, top, c, m, y, on)
      rgb = m.kr ? MOD_TILES[0] : MOD_TILES[1 + m.name.to_s.sum % (MOD_TILES.length - 1)]
      P.ui.rbox(top, X0 + 10, y + 5, X0 + 26, y + 21, 3, Color.new(*rgb))
      P.text(top, X0 + 10, y + 4, 17, 18, m.name.to_s[0, 1].upcase, Color.new(255, 255, 255), PF::TINY, 2)
      nw = P.width(PF::ROW, PF.fit(PF::ROW, m.name.to_s, 230))
      P.text(top, X0 + 32, y - 1, 240, 24, PF.fit(PF::ROW, m.name.to_s, 230), c[:txt], PF::ROW)
      P.small(top, X0 + 40 + nw, y + 5, 80, 16, SC.size_words(m.bytes), c[:dim])
      if m.needed
        P.pill(top, X1 - 12, y + 5, _INTL("NEEDED TO LOAD"), Color.new(70, 24, 22), RED)
      else
        P.pill(top, X1 - 12, y + 5, _INTL("SAFE TO REMOVE"), Color.new(24, 60, 36), GREEN)
      end
      words, colour = mod_words(m, c)
      P.small_wrap(top, words, X1 - X0 - 50).first(2).each_with_index do |ln, k|
        P.small(top, X0 + 32, y + 22 + k * 14, X1 - X0 - 50, 16, ln, colour)
      end
    end

    def mod_words(m, c)
      if m.needed
        what = SC.join_words(m.classes.keys.first(2))
        return [_INTL("Needed to load: It stores {1}, which the game can't read without {2}.", what, m.name), m.installed == true ? AMBER : RED]
      end
      return [_INTL("Safe to remove: Plain values only. Its .kr copy brings the data back when it's installed again."), c[:txt]] if m.kr
      text = _INTL("Safe to remove: Plain values only. Its data waits in the save.")
      text += " " + _INTL("It isn't installed now.") if m.installed != true
      return [text, c[:txt]]
    end

    def paint_line(top, c, line, y, on)
      state, title, under, right, colour = line
      status_icon(top, X0 + 10, y + 9, state, c)
      w = X1 - X0 - 150
      P.text(top, X0 + 36, y - 2, w, 24, PF.fit(PF::ROW, title.to_s, w), c[:txt], PF::ROW)
      P.small(top, X0 + 36, y + 19, X1 - X0 - 56, 16, fit_small(top, under.to_s, X1 - X0 - 56), c[:dim])
      P.text(top, X1 - 150, y, 138, 20, PF.fit(PF::TEXT, right.to_s, 138), colour, nil, 1)
    end

    def paint_buttons(base, top, c)
      list = buttons
      gap = 8
      bw = (X1 - X0 - gap) / list.length
      list.each_with_index do |(id, label), k|
        x = X0 + k * (bw + gap)
        i = rows.length + k
        first = k == 0
        off = first && off_button?(id)
        fill = first && !off ? Reloaded::Palette.mix(c[:selb], c[:dark], 0.35) : c[:dark]
        P.ui.rbox(base, x, BTN_Y, x + bw, BTN_Y + BTN_H, 6, fill, first && !off ? c[:selb] : c[:line])
        P.text(top, x, BTN_Y + 2, bw, 24, label, off ? c[:dim] : c[:txt], PF::ROW, 2)
        @row_hits << [i, x, BTN_Y, x + bw, BTN_Y + BTN_H]
        @cursor_rect = [x, BTN_Y, bw, BTN_H] if i == @sel
      end
    end

    # A first button with nothing to do here, drawn faded.
    def off_button?(id)
      case id
      when :fix then return @backup || @report.state == :damaged || @report.missing.none?(&:fixable)
      when :back_up then return @backup
      end
      return false
    end

    def fit_small(b, text, w)
      P.small_font(b)
      return text if b.text_size(text).width <= w
      text = text[0...-1] while text.length > 1 && b.text_size(text + "...").width > w
      return text + "..."
    end

    def hint_pairs
      pairs = [[:ud, _INTL("Choose")]]
      if on_button?
        pairs << [button(:C), _INTL("Select")]
      else
        a = case @mode
            when :missing then _INTL("Change Fix")
            when :mod then inspect_here? ? _INTL("Inspect") : nil
            else _INTL("Details")
            end
        pairs << [button(:C), a] if a
      end
      pairs << [button(:A), buttons[0][1]]
      pairs << [button(:B), _INTL("Back"), :back]
      return pairs
    end
  end

  #============================================================================
  # The Inspector: a save value's insides, as a tree (KIF's DEBUG option on)
  #============================================================================
  class SaveInspector
    include Reloaded::Frame

    PF = ::KIF::PixelFont
    P = Reloaded::Pixel
    ROW = 22
    Y0 = 40
    Y1 = H - P::HINT_H - 8

    def initialize(name, root)
      frame_init
      @name = name
      @path = []          # [[label, value]] from the root down
      @root = root
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
    ensure
      dispose_sprites
    end

    def refresh
      draw_screen if @sprite && !@sprite.disposed?
    end

    private

    def here
      return @path.empty? ? @root : @path.last[1]
    end

    # [[label, value]] inside a value.
    def children(v)
      case v
      when Hash then return v.map { |k, x| [k.inspect, x] }
      when Array then return v.each_with_index.map { |x, i| ["[#{i}]", x] }
      when Struct then return v.each_pair.map { |k, x| [k.to_s, x] }
      end
      return [] if Reloaded::SaveCheck.leaf?(v) || v.is_a?(Module)
      list = v.instance_variables.map { |iv| [iv.to_s, v.instance_variable_get(iv)] }
      list << ["(held)", v.kr_held] if v.is_a?(Reloaded::SaveCheck::Stub) && !v.kr_held.nil?
      return list
    end

    def summary(v)
      case v
      when Hash then return _INTL("{1} keys", v.length)
      when Array then return _INTL("{1} items", v.length)
      when String then return v.length > 40 ? v[0, 40].inspect + "..." : v.inspect
      end
      return v.inspect[0, 40] if Reloaded::SaveCheck.leaf?(v)
      return _INTL("stood in for") if v.is_a?(Reloaded::SaveCheck::Stub)
      return _INTL("{1} values", v.instance_variables.length)
    end

    def fit
      return (Y1 - Y0) / ROW
    end

    def handle_input
      list = children(here)
      if Input.trigger?(Input::BACK) || Reloaded::Pointer.right?
        pbPlayCancelSE
        return :close if @path.empty?
        @path.pop
        @sel = 0
        @top = 0
        refresh
      elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        return nil if list.empty?
        @sel = (@sel + (Input.repeat?(Input::DOWN) ? 1 : -1)) % list.length
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::USE)
        row = list[@sel]
        return pbPlayBuzzerSE if row.nil? || children(row[1]).empty?
        pbPlayDecisionSE
        @path << row
        @sel = 0
        @top = 0
        refresh
      end
      return nil
    end

    def draw_screen
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      base.fill_rect(0, 0, W, H, c[:bg])
      paint_title_bar(base, c)
      P.text(top, 0, 1, W, 28, _INTL("Inspector"), c[:title], PF::TITLE, 2)
      where = ([@name] + @path.map(&:first)).join(" > ")
      P.small(top, 10, 33, W - 20, 14, where, c[:dim])
      @cursor_rect = nil
      list = children(here)
      @top = @sel if @sel < @top
      @top = @sel - fit + 1 if @sel >= @top + fit
      list[@top, fit].to_a.each_with_index do |(label, v), k|
        y = Y0 + 8 + k * ROW
        @cursor_rect = [6, y, W - 12, ROW] if @top + k == @sel
        P.text(top, 12, y - 1, 170, 22, PF.fit(PF::TEXT, label, 170), c[:txt])
        klass = v.is_a?(Reloaded::SaveCheck::Stub) ? "#{v.class.name}*" : v.class.name.to_s
        P.text(top, 186, y - 1, 140, 22, PF.fit(PF::TEXT, klass, 140), v.is_a?(Reloaded::SaveCheck::Stub) ? Color.new(240, 100, 90) : c[:dim])
        P.text(top, 330, y - 1, W - 342, 22, PF.fit(PF::TEXT, summary(v), W - 342), c[:txt], nil, 1)
      end
      P.text(top, 12, Y0 + 8, 300, 22, _INTL("Nothing inside."), c[:dim]) if list.empty?
      paint_hints(base, c)
      place_cursor
    end

    def hint_pairs
      return [[:ud, _INTL("Choose")], [button(:C), _INTL("Open")], [button(:B), @path.empty? ? _INTL("Close") : _INTL("Up")]]
    end
  end
end
