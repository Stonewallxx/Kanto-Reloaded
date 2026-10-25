#==============================================================================
# Kanto Reloaded: the Publish a Mod screen
#==============================================================================
# His picks (2026-10-25), as drawn: Design 2 Step Strip. The title, then
# four steps under it (L1 / R1 move between them), one panel, the
# description box:
#
#   1 Mod      your mods in Mods and ModDev, one row each (1a Mod List):
#              its ball or letter tile, name, folder, and NEW, UPDATE x TO y
#              or RAISE FROM x (the catalog has this version). One whose
#              mod.json can't be read says CAN'T READ and goes no further.
#   2 Details  mod.json: ID (only when it's wrong, as KIF), Name, Version
#              (Left / Right raise it, A types one), Author, Description,
#              Tags. Saved as you change them; a problem marks its row red.
#   3 Check    the catalog's own check: problems (A on one about a detail
#              goes to its row) and things the reviewer will look at
#   4 Publish  Permission, Tested in KIF, Reviewer Notes (remembered for the
#              mod), the Pull Request Preview, and Publish (4a Checklist
#              and Button)
#
# A mod with a copy in the ModDev Folder (Developer Tools) says MODDEV: it's
# checked and uploaded from that copy (Reloaded::Publish).
#
# Y opens the mod's folder; B leaves (everything is saved already). The
# popups are in PublishPopups.rb. Every word KIF's Publish a mod shows is
# here somewhere: in a row, the description box, a popup or a toast.
#==============================================================================

return unless defined?(Reloaded::SplitScreen) && defined?(Reloaded::Publish)

module Reloaded
  class PublishScreen
    include Reloaded::SplitScreen

    PB = Reloaded::Publish
    DL = Reloaded::Dialogs
    PP = Reloaded::PartyPaint
    STEPS = ["Mod", "Details", "Check", "Publish"].freeze
    GREEN = [120, 230, 150].freeze
    BLUE = [130, 190, 250].freeze
    AMBER = [240, 170, 60].freeze
    RED = [240, 100, 90].freeze
    STRIP_Y0 = 38
    PANEL_Y0 = 68
    BODY_Y0 = 100                     # the rows under the panel's name line
    ROW_X0 = 26
    ROW_X1 = W - 26
    CHECK_WAIT = 30                   # frames after a change before the check runs again
    TOAST_FRAMES = 150
    DETAIL_NAMES = { :id => "ID", :name => "Name", :version => "Version", :author => "Author",
                     :desc => "Description", :tags => "Tags" }.freeze
    PUBLISH_NAMES = { :own => "Permission", :tested => "Tested in KIF", :notes => "Reviewer Notes",
                      :preview => "Pull Request" }.freeze

    attr_reader :entry

    def self.open
      return new.main
    end

    def initialize
      frame_init
      @mods = PB.mods
      @mod_i = 0
      @step = 0
      @sel = [0, 0, 0, 0]
      @check_top = 0
      @results = {}             # a mod's path => [problems, things to look at]
      @start = {}               # a mod's version when it was first opened here
      @answers = {}
      @check_at = nil
      @toast = nil
    end

    def main
      open_sprites
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        tick
        break if handle_input == :close
        tick_description
      end
      return nil
    ensure
      @probe.dispose if @probe && !@probe.disposed?
      dispose_sprites
    end

    def refresh
      draw_screen if @sprite && !@sprite.disposed?
    end

    # TextEntry asks for these
    def entry=(state)
      @entry = state
    end

    def entry_changed
      refresh
    end

    private

    def mod
      return @mods[@mod_i]
    end

    def tone(c, rgb)
      return PP.ink(c, rgb)
    end

    #--------------------------------------------------------------------------
    # The state
    #--------------------------------------------------------------------------
    def ans
      return @answers[mod.id] ||= PB.answers(mod.id)
    end

    def results
      return @results[mod.path] || [[], []]
    end

    def checked?
      return mod && @results.key?(mod.path) && @check_at.nil?
    end

    def run_check
      @check_at = nil
      return unless mod && mod.readable?
      @results[mod.path] = PB.check(mod)
      @check_top = 0
    end

    # The rows a problem points at
    def marked
      return results[0].map { |e| PB.field_of(e) }.compact
    end

    def ready?
      return checked? && results[0].empty? && ans["own"]
    end

    # Every frame: the toast's time, and the check a moment after a change
    def tick
      if @toast
        @toast[1] -= 1
        if @toast[1] <= 0
          @toast = nil
          refresh
        end
      end
      if @check_at && @frame >= @check_at
        run_check
        refresh
      end
    end

    # mod.json changed: saved at once (his pick), checked a moment later
    def changed!
      show_toast(_INTL("mod.json couldn't be saved (see Logs/KIF_log.txt).")) unless PB.save(mod)
      PB.relink(mod)
      @check_at = @frame + CHECK_WAIT
      refresh
    end

    def show_toast(text)
      @toast = [text, TOAST_FRAMES]
    end

    def remember!
      PB.remember(mod.id, ans)
    end

    def detail_rows
      rows = []
      rows << :id if mod.id !~ ::KIF::ModCheck::ID
      return rows + [:name, :version, :author, :desc, :tags]
    end

    def publish_rows
      return [:own, :tested, :notes, :preview, :publish]
    end

    def check_items
      errs, warns = results
      return errs.map { |e| [:problem, e] } + warns.map { |w| [:warn, w] }
    end

    def count
      case @step
      when 0 then return @mods.length
      when 1 then return detail_rows.length
      when 2 then return check_items.length
      else return publish_rows.length
      end
    end

    def row_id
      case @step
      when 1 then return detail_rows[@sel[1]]
      when 3 then return publish_rows[@sel[3]]
      end
      return nil
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      return nil if @mods.empty? && !(Input.trigger?(Input::BACK) || Reloaded::Pointer.right?)
      pt = Reloaded::Pointer
      if pointer_hover && (i = pt.hit(@row_hits || [])) && i != current_sel
        set_sel(i)
        pbPlayCursorSE
        refresh
      end
      if pt.left?
        handled, r = hint_click
        return r if handled
        if (s = pt.hit(@strip_hits || []))
          return go_step(s)
        end
        if (i = pt.hit(@row_hits || []))
          set_sel(i)
          return press
        end
        return nil
      end
      return :close if pt.right? || Input.trigger?(Input::BACK)
      if Input.trigger?(Input::JUMPUP)
        return @step == 0 ? pbPlayBuzzerSE : go_step(@step - 1)
      elsif Input.trigger?(Input::JUMPDOWN)
        return @step == STEPS.length - 1 ? pbPlayBuzzerSE : go_step(@step + 1)
      end
      if Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        move(Input.repeat?(Input::DOWN) ? 1 : -1)
      elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
        side(Input.repeat?(Input::RIGHT) ? 1 : -1)
      elsif Input.trigger?(Input::USE)
        return press
      elsif Input.trigger?(Input::X)
        open_folder
      end
      return nil
    end

    def current_sel
      return @step == 0 ? @mod_i : @sel[@step]
    end

    def set_sel(i)
      @step == 0 ? @mod_i = i : @sel[@step] = i
    end

    def move(dir)
      n = count
      return pbPlayBuzzerSE if n == 0
      i = current_sel + dir
      if i < 0 || i >= n
        return unless fresh?(dir)                   # a held direction stops at the ends
        i %= n
      end
      set_sel(i)
      @sel[1] = @sel[2] = @sel[3] = 0 if @step == 0
      pbPlayCursorSE
      refresh
    end

    def go_step(s)
      return if s == @step
      if s > 0 && !(mod && mod.readable?)
        return pbPlayBuzzerSE
      end
      pbPlayCursorSE
      @start[mod.path] ||= mod.version if s > 0
      @step = s
      @sel[s] = [@sel[s], count - 1].min if s > 0
      @sel[s] = 0 if @sel[s] < 0
      unless @step == 0 || @results.key?(mod.path)       # first look at this mod: its check
        refresh
        Graphics.update
        run_check
      end
      refresh
      return nil
    end

    # Left / Right: the version's raises, or a Yes / No
    def side(dir)
      case row_id
      when :version
        start = @start[mod.path] ||= mod.version
        values = ([start] + PB.raises(mod, start)).uniq
        i = values.index(mod.version)
        to = i ? values[(i + dir) % values.length] : values[dir > 0 ? 1 : 0]
        return pbPlayBuzzerSE if to.nil? || to == mod.version
        mod.json["version"] = to
        pbPlayCursorSE
        changed!
      when :own, :tested
        ans[row_id.to_s] = !ans[row_id.to_s]
        remember!
        pbPlayCursorSE
        refresh
      else
        pbPlayBuzzerSE
      end
    end

    def press
      case @step
      when 0 then return go_step(1)
      when 1 then return press_detail
      when 2 then return press_check
      else return press_publish
      end
    end

    def press_detail
      case row_id
      when :id
        type_row(:id, _INTL("ID (a-z, 0-9, _ and -). It never changes once published:"), mod.json["id"], 40) { |v| mod.json["id"] = v.downcase }
      when :name then type_row(:name, _INTL("Mod Name:"), mod.json["name"], 40) { |v| mod.json["name"] = v }
      when :version then type_row(:version, _INTL("Version (like 1.0 or 1.2.3):"), mod.version, 20) { |v| mod.json["version"] = v }
      when :author then type_row(:author, _INTL("Author:"), mod.json["author"], 40) { |v| mod.json["author"] = v }
      when :desc then type_box(_INTL("Description"), _INTL("Description (One or Two Lines):"), mod.description, 300) { |v| mod.json["description"] = v }
      when :tags then pick_tags
      end
      return nil
    end

    # A on a problem about a detail: that row
    def press_check
      kind, text = check_items[@sel[2]]
      field = kind == :problem ? PB.field_of(text) : nil
      i = field && detail_rows.index(field)
      return pbPlayBuzzerSE unless i
      @sel[1] = i
      go_step(1)
    end

    def press_publish
      case row_id
      when :own, :tested then side(1)
      when :notes
        type_box(_INTL("Reviewer Notes"), _INTL("Notes for the Reviewer (Optional):"), ans["notes"], 500, true) do |v|
          ans["notes"] = v
          remember!
        end
      when :preview then show_preview
      when :publish then publish
      end
      return nil
    end

    # Typing in the row (his pick T2: the short ones)
    def type_row(row, prompt, initial, max)
      @entry_row = row
      text, how = Reloaded::TextEntry.run(self, prompt, initial.to_s, max, :prompt => prompt)
      @entry_row = nil
      return refresh unless how == :enter
      v = text.to_s.strip
      return refresh if v.empty?                    # as KIF: an empty answer changes nothing
      old_id = mod.id
      yield v
      @answers[mod.id] ||= @answers[old_id] if row == :id
      changed!
    end

    # Description and Reviewer Notes: a box of their own (T2); empty is
    # kept for the notes (they're optional)
    def type_box(title, prompt, initial, max, empty_ok = false)
      @box_title = title
      text, how = Reloaded::TextEntry.run(self, prompt, initial.to_s, max, :prompt => prompt)
      @box_title = nil
      return refresh unless how == :enter
      v = text.to_s.strip
      return refresh if v.empty? && !empty_ok
      yield v
      empty_ok ? refresh : changed!
    end

    # The folder that goes up: the ModDev Folder's copy when there is one
    def open_folder
      return pbPlayBuzzerSE unless mod
      system("explorer \"#{mod.source.tr("/", "\\")}\"")
    rescue StandardError
      pbPlayBuzzerSE
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
      overlay.clear unless @popup_open             # a popup of the screen's own draws there itself
      base.fill_rect(0, 0, W, H, c[:bg])
      @cursor_rect = nil
      @row_hits = []
      paint_title_bar(base, c)
      P.text(top, 0, 2, W, 28, _INTL("Publish a Mod"), c[:title], PF::TITLE, 2)
      paint_strip(base, top, c)
      P.ui.rbox(base, 6, PANEL_Y0, W - 6, LIST_Y1, 6, c[:panel])
      if @mods.empty?
        paint_no_mods(base, top, c)
      else
        send([:paint_mods, :paint_details, :paint_check, :paint_publish][@step], base, top, c)
      end
      paint_toast(top, c) if @toast
      paint_hints(base, c)
      place_cursor
      paint_box(c) if @entry && @box_title
    end

    def paint_strip(base, top, c)
      x = 14
      w = (W - 28 - 3 * 8) / 4
      @strip_hits = []
      STEPS.each_with_index do |name, i|
        on = i == @step
        done = i < @step
        P.ui.rbox(base, x, STRIP_Y0, x + w, STRIP_Y0 + 24, 6, on ? c[:sel] : c[:panel], on ? c[:selb] : c[:line])
        if done                                     # New Game Setup's tick (his ask)
          [[0, 3], [1, 4], [2, 5], [3, 4], [4, 3], [5, 2], [6, 1]].each { |dx, dy| top.fill_rect(x + 9 + dx, STRIP_Y0 + 7 + dy, 2, 2, c[:green]) }
        else
          P.ui.rbox(base, x + 6, STRIP_Y0 + 5, x + 20, STRIP_Y0 + 19, 7, on ? c[:head] : c[:line])
          P.text(top, x + 6, STRIP_Y0 + 3, 15, 18, (i + 1).to_s, c[:dark], PF::TINY, 2)
        end
        P.text(top, x + 26, STRIP_Y0 + 1, w - 30, 24, _INTL(name), on ? c[:strong] : (done ? c[:txt] : c[:dim]))
        @strip_hits << [i, x, STRIP_Y0, x + w, STRIP_Y0 + 24]
        x += w + 8
      end
    end

    # The mod's name, then its pills at the right (NEW, or the catalog's
    # version and UPDATE)
    def paint_name_line(top, c, text)
      P.text(top, 18, PANEL_Y0 + 4, W - 220, 24, PF.fit(PF::ROW, text, W - 220), c[:strong], PF::ROW)
      x = W - 18
      label, rgb = state_pill(mod)
      x -= P.pill(top, x, PANEL_Y0 + 10, short_state(mod), tone(c, rgb), c[:dark]) + 4
      x -= P.pill(top, x, PANEL_Y0 + 10, _INTL("CATALOG {1}", mod.old.version), c[:pill], c[:txt]) + 4 if mod.old
      P.pill(top, x, PANEL_Y0 + 10, _INTL("MODDEV"), c[:pill], c[:txt]) if mod.copy
    end

    def state_pill(m)
      return [_INTL("CAN'T READ"), RED] unless m.readable?
      case m.state
      when :new then return [_INTL("NEW"), BLUE]
      when :raise then return [_INTL("RAISE FROM {1}", m.old.version), AMBER]
      else return [_INTL("UPDATE {1} TO {2}", m.old.version, m.version), GREEN]
      end
    end

    def short_state(m)
      return { :new => _INTL("NEW"), :raise => _INTL("RAISE"), :update => _INTL("UPDATE") }[m.state]
    end

    def mod_icon(top, m, x, y, i)
      icon = Reloaded::ModIcons.for(m.id) || Reloaded::ModIcons.for(m.name)
      if !m.readable?
        P.ui.rbox(top, x, y, x + 14, y + 14, 3, Color.new(*RED))
        P.glyph(top, x, y, 15, 15, "!", TILE_TEXT)
      elsif m.id == "KantoReloaded"
        P.poke_ball(top, x, y, 15)
      elsif icon
        Reloaded::ModIcons.draw(top, x, y, icon)
      else
        P.ui.rbox(top, x, y, x + 14, y + 14, 3, Color.new(*tile_colour(i)))
        P.glyph(top, x, y, 15, 15, PF.utf8(m.name)[0].to_s.upcase, TILE_TEXT)
      end
    end

    # Step 1: the mods
    def paint_mods(base, top, c)
      fit = (LIST_Y1 - PANEL_Y0 - 8) / (ROW_H + 4)
      @mods_top = 0 if @mods_top.nil?
      @mods_top = @mod_i - fit + 1 if @mod_i >= @mods_top + fit
      @mods_top = @mod_i if @mod_i < @mods_top
      y = PANEL_Y0 + 6
      @mods[@mods_top, fit].each_with_index do |m, k|
        i = k + @mods_top
        on = i == @mod_i
        @row_hits << [i, 12, y, W - 12, y + ROW_H + 2]
        @cursor_rect = [12, y, W - 24, ROW_H + 2] if on
        mod_icon(top, m, 22, y + 6, i)
        label, rgb = state_pill(m)
        pw = P.width(PF::TINY, label) + 12
        pw += P.width(PF::TINY, _INTL("MODDEV")) + 16 if m.copy
        nw = P.text(top, 44, y + 2, W - 80 - pw - 60, ROW_H, PF.fit(PF::TEXT, m.name, W - 80 - pw - 60), on ? c[:strong] : c[:txt])
        P.small(top, 44 + nw + 8, y + 6, 80, 18, m.where, c[:dim])
        sw = P.pill(top, W - 22, y + 7, label, tone(c, rgb), c[:dark])
        P.pill(top, W - 22 - sw - 4, y + 7, _INTL("MODDEV"), c[:pill], c[:txt]) if m.copy
        y += ROW_H + 4
      end
      paint_scrollbar(base, c, W - 11, @mods.length, fit, @mods_top, LIST_Y1 - 4) if @mods.length > fit
      m = mod
      text = if !m.readable? then _INTL("{1}'s mod.json can't be read. Fix it in a text editor first.", File.basename(m.path))
             elsif m.description.empty? then _INTL("No description yet: Add one in Details.")
             else m.description
             end
      label, rgb = state_pill(m)
      pills = [[m.where.upcase, c[:pill], c[:txt]], [m.readable? ? short_state(m) : label, tone(c, rgb), c[:dark]]]
      pills.unshift([_INTL("MODDEV"), c[:pill], c[:txt]]) if m.copy
      text = _INTL("{1} Checked and uploaded from its copy in the ModDev Folder.", text) if m.copy && m.readable?
      paint_description_box(base, top, c, m.name, text, :"mod_#{@mod_i}", pills)
    end

    def paint_no_mods(base, top, c)
      P.text(top, 6, 120, W - 12, 24, _INTL("No mod folders found in Mods or ModDev."), c[:dim], nil, 2)
      paint_description_box(base, top, c, _INTL("No Mods"), _INTL("Put a mod's folder in Mods (or in ModDev next to the game), then open Publish a Mod again."), :none)
    end

    # A row: its name, then its value at the right (arrows round a value
    # that Left / Right change)
    def row(base, top, c, y, i, name, value, arrows: false, mark: false)
      on = i == @sel[@step]
      @row_hits << [i, ROW_X0 - 8, y, ROW_X1 + 8, y + ROW_H]
      @cursor_rect = [ROW_X0 - 8, y, ROW_X1 - ROW_X0 + 16, ROW_H] if on
      base.fill_rect(ROW_X0 - 12, y + 5, 2, ROW_H - 10, tone(c, RED)) if mark
      nw = P.text(top, ROW_X0, y + 1, 230, ROW_H, name, on ? c[:strong] : c[:txt])
      return nw unless value
      vc = on ? c[:strong] : c[:txt]
      if arrows
        vw = PF.width(PF::TEXT, value)
        cx = value_centre(vw)
        P.text(top, cx - vw / 2, y + 1, vw + 2, ROW_H, value, vc)
        P.ui.tri(top, cx - vw / 2 - 12, y + 9, :l, on ? c[:txt] : c[:dim], 4)
        P.ui.tri(top, cx + vw / 2 + 5, y + 9, :r, on ? c[:txt] : c[:dim], 4)
      else
        room = ROW_X1 - (ROW_X0 + nw + 16)
        v = PF.fit(PF::TEXT, value, room)
        vw = PF.width(PF::TEXT, v)
        P.text(top, ROW_X1 - vw, y + 1, vw + 2, ROW_H, v, vc)
      end
      return nw
    end

    # Step 2: mod.json's details
    def paint_details(base, top, c)
      m = mod
      paint_name_line(top, c, m.name)
      marks = marked
      y = BODY_Y0
      detail_rows.each_with_index do |id, i|
        name = _INTL(DETAIL_NAMES[id])
        typing = @entry && !@box_title && @entry_row == id
        value = case id
                when :id then m.json["id"].to_s
                when :name then m.json["name"].to_s
                when :version then m.version
                when :author then m.json["author"].to_s.empty? ? _INTL("(none)") : m.json["author"].to_s
                when :desc then m.description.empty? ? _INTL("(none)") : m.description
                end
        nw = row(base, top, c, y, i, name, typing || id == :tags ? nil : value, :arrows => id == :version, :mark => marks.include?(id))
        if typing
          x0 = ROW_X0 + nw + 20
          Reloaded::TextEntry.draw_field(base, top, c, @entry, x0, y + 1, ROW_X1 - x0, ROW_H - 2)
        elsif id == :tags
          tags = Array(m.json["tags"]).map(&:to_s)
          x = ROW_X1
          if tags.empty?
            P.text(top, ROW_X1 - 100, y + 1, 100, ROW_H, _INTL("none"), c[:dim], nil, 1)
          else
            tags.reverse.each { |t| x -= P.pill(top, x, y + 5, t.upcase, tone(c, BLUE), c[:dark]) + 4 }
          end
        end
        y += ROW_H
      end
      title, text = detail_words(detail_rows[@sel[1]])
      paint_description_box(base, top, c, title, text, :"detail_#{@sel[1]}")
    end

    def detail_words(id)
      m = mod
      problem = results[0].find { |e| PB.field_of(e) == id }
      text = case id
             when :id then _INTL("ID (a-z, 0-9, _ and -). It never changes once published.")
             when :name then _INTL("The mod's name.")
             when :version
               ups = PB.raises(m, @start[m.path] || m.version).join(", ")
               m.old ? _INTL("Version {1}. The catalog has {2}. Left or Right raises it ({3}); A types one, like 1.0 or 1.2.3.", m.version, m.old.version, ups) :
                       _INTL("Version {1}. Left or Right raises it ({2}); A types one, like 1.0 or 1.2.3.", m.version, ups)
             when :author then _INTL("Who made it.")
             when :desc then m.description.empty? ? _INTL("One or two lines on what it does.") : m.description
             else _INTL("What kind of mod it is (Mod Manager 2.0's tags): A chooses them.")
             end
      text = "#{text} #{capital(problem)}." if problem && id != :desc
      return [_INTL(DETAIL_NAMES[id] || "Details"), text]
    end

    def capital(text)
      t = text.to_s
      return t.empty? ? t : t[0].upcase + t[1..-1]
    end

    # Step 3: the catalog's check
    def paint_check(base, top, c)
      P.text(top, 18, PANEL_Y0 + 4, 300, 24, _INTL("The Catalog's Check"), c[:strong], PF::ROW)
      errs, warns = results
      kind, words = if !checked? then [:wait, _INTL("Checking...")]
                    elsif !errs.empty? then [:problem, errs.length == 1 ? _INTL("1 Problem to Fix") : _INTL("{1} Problems to Fix", errs.length)]
                    elsif !warns.empty? then [:warn, _INTL("Passed, {1} to Look At", warns.length)]
                    else [:ok, _INTL("Passed")]
                    end
      check_line(base, top, c, 22, BODY_Y0, W - 50, kind, words, false)
      items = check_items
      fit = (LIST_Y1 - 4 - BODY_Y0 - ROW_H) / ROW_H
      sel = @sel[2]
      @check_top = sel - fit + 1 if sel >= @check_top + fit
      @check_top = sel if sel < @check_top
      y = BODY_Y0 + ROW_H
      items[@check_top, fit].to_a.each_with_index do |(k, t), j|
        i = j + @check_top
        @row_hits << [i, 32, y, W - 22, y + ROW_H]
        check_line(base, top, c, 38, y, W - 66, k, k == :problem ? capital(t) : t, i == sel)
        y += ROW_H
      end
      paint_scrollbar(base, c, W - 11, items.length, fit, @check_top, LIST_Y1 - 4) if items.length > fit
      k, t = items[sel]
      title, text = if k == :problem
                      [_INTL("Problem"), _INTL("{1}. Problems must be fixed before the mod can be published; problems in the files need fixing in the mod's folder (Folder opens it).", capital(t))]
                    elsif k == :warn
                      [_INTL("Worth a Look"), _INTL("{1}. The check passed. The reviewer will read these closely; say why the mod needs them in the notes.", t)]
                    else
                      [_INTL("Check"), _INTL("The catalog's own check, run on the folder as it would be uploaded. Everything it finds is in Logs/KIF_log.txt too.")]
                    end
      paint_description_box(base, top, c, title, text, :"check_#{sel}")
    end

    def check_line(base, top, c, x, y, w, kind, text, sel)
      col = { :ok => GREEN, :problem => RED, :warn => AMBER, :wait => BLUE }[kind]
      tc = tone(c, col)
      P.ui.rbox(base, x, y + 6, x + 12, y + 18, 6, tc)
      P.text(top, x, y + 2, 13, 20, { :ok => "+", :problem => "x", :warn => "!", :wait => "." }[kind], c[:dark], PF::TINY, 2)
      P.text(top, x + 18, y + 1, w - 18, ROW_H, PF.fit(PF::TEXT, text, w - 18), sel ? c[:strong] : (kind == :ok ? c[:txt] : tc))
      @cursor_rect = [x - 6, y, w + 12, ROW_H] if sel
    end

    # Step 4: the pull request's questions and Publish
    def paint_publish(base, top, c)
      m = mod
      paint_name_line(top, c, "#{m.name} #{m.version}")
      y = BODY_Y0
      publish_rows.each_with_index do |id, i|
        if id == :publish
          paint_button(base, top, c, y + 8, i)
          next
        end
        typing_notes = id == :notes && @entry && @box_title
        value = case id
                when :own then ans["own"] ? _INTL("Yes") : _INTL("No")
                when :tested then ans["tested"] ? _INTL("Yes") : _INTL("Not Yet")
                when :notes then ans["notes"].to_s.empty? ? _INTL("(none)") : ans["notes"].to_s
                end
        row(base, top, c, y, i, _INTL(PUBLISH_NAMES[id]), typing_notes ? nil : value, :arrows => [:own, :tested].include?(id))
        P.pill(top, ROW_X1, y + 5, _INTL("PREVIEW"), c[:pill], c[:txt]) if id == :preview
        y += ROW_H
      end
      title, text = publish_words(publish_rows[@sel[3]])
      paint_description_box(base, top, c, title, text, :"publish_#{@sel[3]}")
    end

    def paint_button(base, top, c, y, i)
      on = i == @sel[3]
      ok = ready?
      label = if !checked? then _INTL("Checking...")
              elsif !results[0].empty? then _INTL("Fix the Problems First")
              elsif !ans["own"] then _INTL("Permission Needed")
              else _INTL("Publish {1} {2}", mod.name, mod.version)
              end
      x0 = 18
      x1 = W - 18
      fill = ok ? tone(c, GREEN) : Reloaded::Palette.mix(c[:panel2], c[:line], 0.5)
      P.ui.rbox(base, x0, y, x1, y + 30, 6, fill)
      fg = ok ? c[:dark] : c[:dim]
      label = PF.fit(PF::TEXT, label, x1 - x0 - 40)
      lw = PF.width(PF::TEXT, label)
      cx = (x0 + x1) / 2
      padlock(top, cx - lw / 2 - 14, y + 10, fg) unless ok
      P.text(top, cx - lw / 2 + (ok ? 0 : 2), y + 4, lw + 2, 22, label, fg)
      @row_hits << [i, x0, y, x1, y + 30]
      @cursor_rect = [x0 - 2, y - 2, x1 - x0 + 4, 34] if on
    end

    def publish_words(id)
      case id
      when :own
        return [_INTL("Permission"), _INTL("Did you make this mod, or do you have its author's permission to share it (credited in mod.json)? Without it, the mod can't be published. Remembered for this mod.")]
      when :tested
        return [_INTL("Tested in KIF"), _INTL("Did you test it in KIF (it loads, a battle works, the game saves and loads)? Remembered for this mod.")]
      when :notes
        return [_INTL("Reviewer Notes"), _INTL("Notes for the reviewer (optional): Say why the mod needs anything the check said to look at. Remembered for this mod.")]
      when :preview
        return [_INTL("Pull Request"), _INTL("The pull request as the reviewer will see it.")]
      end
      return [_INTL("Publish"), _INTL("A window opens that signs you in to GitHub in your browser (the first time) and uploads the mod. The game stays open.")]
    end

    # Not saved: a red toast, rounded and placed like Kanto Reloaded's
    # toasts (his pick)
    def paint_toast(top, c)
      text = @toast[0]
      tw = P.width(PF::TEXT, text) + 30
      tx = (W - tw) / 2
      P.ui.rbox(top, tx, 10, tx + tw - 1, 39, 7, Reloaded::Palette.mix(c[:panel2], tone(c, RED), 0.35), tone(c, RED))
      P.text(top, tx, 16, tw, 18, text, c[:strong], nil, 2)
    end

    def hint_pairs
      back = button(:B)
      return [[back, _INTL("Back"), :close_hint]] if @mods.empty?
      return [["Enter", _INTL("Done")], ["Esc", _INTL("Stop")], [button(:C), _INTL("Naming Screen")]] if @entry
      out = [[:ud, _INTL("Choose")]]
      case @step
      when 0
        out << [button(:X), _INTL("Folder"), :open_folder]
        out << [button(:R), _INTL("Next Step"), :next_hint] if mod.readable?
      when 1
        id = row_id
        out << [:lr, _INTL("Raise")] if id == :version
        out << [button(:C), id == :tags ? _INTL("Choose") : _INTL("Type"), :press]
        out << [button(:L), _INTL("Back a Step"), :prev_hint] << [button(:R), _INTL("Next Step"), :next_hint]
      when 2
        k, t = check_items[@sel[2]]
        out << [button(:C), _INTL("Go to It"), :press] if k == :problem && PB.field_of(t)
        out << [button(:X), _INTL("Folder"), :open_folder]
        out << [button(:L), _INTL("Back a Step"), :prev_hint] << [button(:R), _INTL("Next Step"), :next_hint]
      else
        id = row_id
        out << [:lr, _INTL("Change")] if [:own, :tested].include?(id)
        verb = { :own => _INTL("Change"), :tested => _INTL("Change"), :notes => _INTL("Type"), :preview => _INTL("Open"), :publish => _INTL("Publish") }[id]
        out << [button(:C), verb, :press]
        out << [button(:L), _INTL("Back a Step"), :prev_hint]
      end
      return out + [[back, _INTL("Back"), :close_hint]]
    end

    def next_hint
      return go_step(@step + 1)
    end

    def prev_hint
      return go_step(@step - 1)
    end

    def close_hint
      return :close
    end
  end
end
